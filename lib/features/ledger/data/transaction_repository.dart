import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';

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
  Future<void> updateTransaction({
    required Transaction original,
    TxnType? type,
    int? amountMinor,
    String? accountId,
    String? toAccountId,
    String? categoryId,
    String? note,
    int? occurredAt,
  }) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final TxnType newType = type ?? original.type;
    final int newAmount = amountMinor ?? original.amountMinor;
    final String newAccountId = accountId ?? original.accountId;
    final String? newToAccountId = toAccountId ?? original.toAccountId;

    if (newAmount <= 0) {
      throw const ValidationFailure('金额必须大于 0');
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

      // 2. 写入新值
      await _db.transactionsDao.updateTx(
        TransactionsCompanion(
          id: Value<String>(original.id),
          type: Value<TxnType>(newType),
          amountMinor: Value<int>(newAmount),
          accountId: Value<String>(newAccountId),
          toAccountId: Value<String?>(newToAccountId),
          categoryId: Value<String?>(categoryId ?? original.categoryId),
          note: Value<String?>(note ?? original.note),
          occurredAt: Value<int>(occurredAt ?? original.occurredAt),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );

      // 3. 应用新流水对余额的影响
      await _applyBalanceDelta(
        newType,
        newAccountId,
        newToAccountId,
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
          'toAccountId': newToAccountId,
          'categoryId': categoryId ?? original.categoryId,
          'occurredAt': occurredAt ?? original.occurredAt,
          'note': note ?? original.note,
          'sourceModule': original.sourceModule.index,
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

  /// 转账：在一个事务内写入两条流水，保证成对出现。
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

    return _db.transaction<String>(() async {
      final String outId = await add(
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
      );

      // 转入方记录一条配对流水，便于账户明细完整展示
      final String inId = const Uuid().v7();
      await _db.transactionsDao.insertTx(
        TransactionsCompanion(
          id: Value<String>(inId),
          bookId: Value<String>(bookId),
          type: const Value<TxnType>(TxnType.transfer),
          amountMinor: Value<int>(amountMinor),
          currency: Value<String>(currency),
          accountId: Value<String>(toAccountId),
          toAccountId: Value<String>(fromAccountId),
          occurredAt: Value<int>(occurredAt),
          note: Value<String?>(note),
          sourceModule: const Value<SourceModule>(SourceModule.transfer),
          transferGroupId: Value<String>(groupId),
          updatedAt: Value<int>(DateTime.now().toUtc().millisecondsSinceEpoch),
          dirty: const Value<bool>(true),
        ),
      );

      return outId;
    });
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
