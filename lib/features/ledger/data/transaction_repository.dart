import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import 'transaction_edit_rules.dart';

/// 记账仓储。
///
/// 职责边界：
/// - 保证"流水写入 + 账户余额调整 + 同步入队"三者的**原子性**（同一个 DB 事务）
/// - 只写本地库，不发起任何网络请求。同步由 SyncEngine 异步接管。
class TransactionRepository {
  const TransactionRepository(this._db);

  final AppDatabase _db;

  /// 新增一条流水。返回新记录的 ID。
  Future<String> add({
    required String bookId,
    required TxnType type,
    required int amountMinor,
    required String accountId,
    required int occurredAt,
    String? toAccountId,
    String? categoryId,
    String? note,
    String currency = 'CNY',
    SourceModule sourceModule = SourceModule.ledger,
    String? relatedId,
    String? transferGroupId,
  }) {
    if (amountMinor <= 0) {
      throw const ValidationFailure('金额必须大于 0');
    }
    if (type == TxnType.transfer && toAccountId == null) {
      throw const ValidationFailure('转账必须指定转入账户');
    }

    final String id = const Uuid().v7();
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;

    return _db.transaction<String>(() async {
      await _db.transactionsDao.insertTx(
        TransactionsCompanion(
          id: Value<String>(id),
          bookId: Value<String>(bookId),
          type: Value<TxnType>(type),
          amountMinor: Value<int>(amountMinor),
          currency: Value<String>(currency),
          accountId: Value<String>(accountId),
          toAccountId: Value<String?>(toAccountId),
          categoryId: Value<String?>(categoryId),
          occurredAt: Value<int>(occurredAt),
          note: Value<String?>(note),
          sourceModule: Value<SourceModule>(sourceModule),
          relatedId: Value<String?>(relatedId),
          transferGroupId: Value<String?>(transferGroupId),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );

      await _applyBalanceDelta(type, accountId, toAccountId, amountMinor, now);
      await _enqueue(
        tableName: 'transactions',
        recordId: id,
        opType: SyncOpType.insert,
        updatedAt: now,
        payload: <String, Object?>{
          'bookId': bookId,
          'type': type.index,
          'amountMinor': amountMinor,
          'currency': currency,
          'accountId': accountId,
          'toAccountId': toAccountId,
          'categoryId': categoryId,
          'occurredAt': occurredAt,
          'note': note,
          'sourceModule': sourceModule.index,
        },
      );

      return id;
    });
  }

  /// 更新一条流水。
  ///
  /// 若金额或账户变更，会先回滚旧流水对余额的影响，再应用新的。
  ///
  /// **`type` 的三个从属字段会被重新推导**（见 [resolveEditIdentity]）：
  /// `sourceModule` / `toAccountId` / `transferGroupId` 都会跟着新类型走。
  /// 这是必需的 —— 早先只改 `type` 不推导，导致「退款改成收入」后
  /// 仍按退款抵扣支出（`支出:¥88.00 收入:¥0.00` 那类对不上的数字）。
  ///
  /// [sourceModule] 用于调用方**显式**指定来源（编辑页的「这是退款」开关）。
  Future<void> updateTransaction({
    required Transaction original,
    TxnType? type,
    int? amountMinor,
    String? accountId,
    String? toAccountId,
    String? categoryId,
    String? note,
    int? occurredAt,
    SourceModule? sourceModule,
  }) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final TxnType newType = type ?? original.type;
    final int newAmount = amountMinor ?? original.amountMinor;
    final String newAccountId = accountId ?? original.accountId;

    if (newAmount <= 0) {
      throw const ValidationFailure('金额必须大于 0');
    }

    // 与 add() 保持一致的校验：转账必须有转入账户。
    final String? requestedToAccountId = toAccountId ?? original.toAccountId;
    final TransactionEditIdentity identity = resolveEditIdentity(
      newType: newType,
      currentSourceModule: original.sourceModule,
      currentToAccountId: requestedToAccountId,
      currentTransferGroupId: original.transferGroupId,
      overrideSourceModule: sourceModule,
    );
    if (newType == TxnType.transfer && identity.toAccountId == null) {
      throw const ValidationFailure('转账必须指定转入账户');
    }

    await _db.transaction<void>(() async {
      // 1. 回滚旧流水对余额的影响
      await _revertBalanceDelta(
        original.type,
        original.accountId,
        original.toAccountId,
        original.amountMinor,
        now,
      );

      // 2. 写入新值。
      //
      // ⚠️ `updateTx` 走的是 `INSERT OR REPLACE`，**companion 里没给的列
      // 会被写回默认值/NULL**。所以这里必须给出完整的一行
      // （含 bookId / currency / tags / attachmentUrls / relatedId），
      // 否则一次编辑就会把货币、标签、票据图片默默清空。
      await _db.transactionsDao.updateTx(
        TransactionsCompanion(
          id: Value<String>(original.id),
          bookId: Value<String>(original.bookId),
          type: Value<TxnType>(newType),
          amountMinor: Value<int>(newAmount),
          currency: Value<String>(original.currency),
          accountId: Value<String>(newAccountId),
          toAccountId: Value<String?>(identity.toAccountId),
          categoryId: Value<String?>(categoryId ?? original.categoryId),
          occurredAt: Value<int>(occurredAt ?? original.occurredAt),
          note: Value<String?>(note ?? original.note),
          attachmentUrls: Value<String?>(original.attachmentUrls),
          tags: Value<String?>(original.tags),
          sourceModule: Value<SourceModule>(identity.sourceModule),
          relatedId: Value<String?>(original.relatedId),
          transferGroupId: Value<String?>(identity.transferGroupId),
          deleted: Value<bool>(original.deleted),
          updatedAt: Value<int>(now),
          syncedAt: Value<int?>(original.syncedAt),
          dirty: const Value<bool>(true),
        ),
      );

      // 3. 应用新流水对余额的影响
      await _applyBalanceDelta(
        newType,
        newAccountId,
        identity.toAccountId,
        newAmount,
        now,
      );

      await _enqueue(
        tableName: 'transactions',
        recordId: original.id,
        opType: SyncOpType.update,
        updatedAt: now,
        payload: <String, Object?>{
          'bookId': original.bookId,
          'type': newType.index,
          'amountMinor': newAmount,
          'currency': original.currency,
          'accountId': newAccountId,
          'toAccountId': identity.toAccountId,
          'categoryId': categoryId ?? original.categoryId,
          'occurredAt': occurredAt ?? original.occurredAt,
          'note': note ?? original.note,
          // 必须是推导后的值：否则云端会把「撒谎的旧标记」同步回来。
          'sourceModule': identity.sourceModule.index,
        },
      );
    });
  }

  /// 软删除。物理删除无法同步，必须标记后随同步推送。
  Future<void> remove(String id) async {
    final Transaction? txn = await _db.transactionsDao.getById(id);
    if (txn == null) {
      throw const NotFoundFailure('流水不存在');
    }

    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;

    await _db.transaction<void>(() async {
      await _revertBalanceDelta(
        txn.type,
        txn.accountId,
        txn.toAccountId,
        txn.amountMinor,
        now,
      );
      await _db.transactionsDao.softDelete(id, now);
      await _enqueue(
        tableName: 'transactions',
        recordId: id,
        opType: SyncOpType.delete,
        updatedAt: now,
      );
    });
  }

  /// 转账：**只写一条**流水（`accountId = 转出方`，`toAccountId = 转入方`）。
  ///
  /// 为什么不再写「转入腿」：`TransactionsDao.watchByAccount` 的取数条件是
  /// `accountId = A OR toAccountId = A`，**单条腿已经能同时出现在两个账户的明细里**，
  /// 第二条腿纯属冗余。而它带来的两个问题都很致命：
  ///
  /// 1. **重复记账**：两条腿（`accountId`/`toAccountId` 互换）对账户 A 都命中，
  ///    同一笔转账在 A 的明细里出现两次，月汇总被重复累加；
  /// 2. **方向丢失**：两条腿在字段上完全对称（`{from,to}` 与 `{to,from}`），
  ///    从数据里**根本推不出钱是转出还是转入**，于是「转账转入计入收入」这类
  ///    统计口径无法实现。
  ///
  /// 只写一条腿后：转出方由 `accountId` 标识，转入方由 `toAccountId` 标识，
  /// 相对某个账户的方向即可用 `accountId == 该账户 ? 转出 : 转入` 判定
  /// （见 `transferDirectionOf`）。
  ///
  /// 历史上已经写下的成对数据仍由 `dedupeAccountTransfers` 在读路径去重。
  Future<String> transfer({
    required String bookId,
    required String fromAccountId,
    required String toAccountId,
    required int amountMinor,
    required int occurredAt,
    String? note,
    String currency = 'CNY',
  }) {
    if (fromAccountId == toAccountId) {
      throw const ValidationFailure('转出与转入账户不能相同');
    }

    final String groupId = const Uuid().v7();

    return _db.transaction<String>(
      () => add(
        bookId: bookId,
        type: TxnType.transfer,
        amountMinor: amountMinor,
        accountId: fromAccountId,
        toAccountId: toAccountId,
        occurredAt: occurredAt,
        note: note,
        currency: currency,
        sourceModule: SourceModule.transfer,
        transferGroupId: groupId,
      ),
    );
  }

  /// 应用余额变动。转账只调整两个账户，不改变净资产。
  Future<void> _applyBalanceDelta(
    TxnType type,
    String accountId,
    String? toAccountId,
    int amountMinor,
    int now,
  ) async {
    switch (type) {
      case TxnType.income:
        await _db.accountsDao.adjustBalance(accountId, amountMinor, now);
      case TxnType.expense:
        await _db.accountsDao.adjustBalance(accountId, -amountMinor, now);
      case TxnType.transfer:
        await _db.accountsDao.adjustBalance(accountId, -amountMinor, now);
        if (toAccountId != null) {
          await _db.accountsDao.adjustBalance(toAccountId, amountMinor, now);
        }
    }
  }

  /// 回滚余额变动（更新与删除时调用）
  Future<void> _revertBalanceDelta(
    TxnType type,
    String accountId,
    String? toAccountId,
    int amountMinor,
    int now,
  ) async {
    switch (type) {
      case TxnType.income:
        await _db.accountsDao.adjustBalance(accountId, -amountMinor, now);
      case TxnType.expense:
        await _db.accountsDao.adjustBalance(accountId, amountMinor, now);
      case TxnType.transfer:
        await _db.accountsDao.adjustBalance(accountId, amountMinor, now);
        if (toAccountId != null) {
          await _db.accountsDao.adjustBalance(toAccountId, -amountMinor, now);
        }
    }
  }

  Future<void> _enqueue({
    required String tableName,
    required String recordId,
    required SyncOpType opType,
    required int updatedAt,
    Map<String, Object?>? payload,
  }) async {
    final int createdAt = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.pendingOpsDao.enqueue(
      PendingOpsCompanion(
        targetTable: Value<String>(tableName),
        recordId: Value<String>(recordId),
        opType: Value<SyncOpType>(opType),
        payload: Value<String?>(
          payload == null ? null : jsonEncode(payload),
        ),
        updatedAt: Value<int>(updatedAt),
        createdAt: Value<int>(createdAt),
      ),
    );
  }
}
