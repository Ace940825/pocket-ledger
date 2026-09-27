import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';
import '../../reimbursement/data/reimbursement_repository.dart';
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
  ///
  /// [fromAmountMinor] 仅用于转账：表示转出（扣款）账户实际被扣除的金额。
  /// 当手续费 / 优惠存在时，转出方扣款金额与转入方到账金额不一致，
  /// 此时 [amountMinor] 为转入到账金额，[fromAmountMinor] 为转出扣款金额。
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
    int? fromAmountMinor,
    int? feeMinor,
    int? discountMinor,
    List<String>? tags,
    bool excludeFromStats = false,
    bool excludeFromBudget = false,
    bool isReimbursable = false,
    String? reimbursementAccountId,
    List<String>? attachmentUrls,
  }) {
    if (amountMinor <= 0) {
      throw const ValidationFailure('金额必须大于 0');
    }
    if (type == TxnType.transfer && toAccountId == null) {
      throw const ValidationFailure('转账必须指定转入账户');
    }

    // 防御性钳制：非转账流水优惠不允许超过金额，
    // 否则「实付 = amount - discount」为负，统计/余额都会算反。
    // 转账的实付 = amount + fee - discount，由调用方校验扣款 > 0。
    final int rawDiscount = discountMinor ?? 0;
    final int safeDiscount =
        type == TxnType.transfer || rawDiscount <= amountMinor
            ? rawDiscount
            : amountMinor;

    final String id = const Uuid().v7();
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final String? tagsJson =
        (tags == null || tags.isEmpty) ? null : jsonEncode(tags);
    final String? attachmentUrlsJson = _encodeAttachmentUrls(attachmentUrls);

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
          feeMinor: Value<int>(feeMinor ?? 0),
          discountMinor: Value<int>(safeDiscount),
          tags: Value<String?>(tagsJson),
          attachmentUrls: Value<String?>(attachmentUrlsJson),
          excludeFromStats: Value<bool>(excludeFromStats),
          excludeFromBudget: Value<bool>(excludeFromBudget),
          isReimbursable: Value<bool>(isReimbursable),
          reimbursementAccountId: Value<String?>(reimbursementAccountId),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );

      await _applyBalanceDelta(
        type,
        accountId,
        toAccountId,
        amountMinor,
        now,
        fromAmountMinor: fromAmountMinor,
        discountMinor: safeDiscount,
        reimbursementAccountId: reimbursementAccountId,
      );
      final Map<String, Object?> payload = <String, Object?>{
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
        'tags': tagsJson,
        'excludeFromStats': excludeFromStats,
        'excludeFromBudget': excludeFromBudget,
        'isReimbursable': isReimbursable,
        'reimbursementAccountId': reimbursementAccountId,
        'attachmentUrls': attachmentUrlsJson,
      };
      if (fromAmountMinor != null) {
        payload['fromAmountMinor'] = fromAmountMinor;
      }
      if (relatedId != null) {
        payload['relatedId'] = relatedId;
      }
      if (transferGroupId != null) {
        payload['transferGroupId'] = transferGroupId;
      }
      payload['feeMinor'] = feeMinor ?? 0;
      payload['discountMinor'] = discountMinor ?? 0;
      await _enqueue(
        tableName: 'transactions',
        recordId: id,
        opType: SyncOpType.insert,
        updatedAt: now,
        payload: payload,
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
    int? feeMinor,
    int? discountMinor,
    List<String>? attachmentUrls,
  }) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final TxnType newType = type ?? original.type;
    final int newAmount = amountMinor ?? original.amountMinor;
    final String newAccountId = accountId ?? original.accountId;
    final int newFee = feeMinor ?? original.feeMinor;
    final int rawDiscount = discountMinor ?? original.discountMinor;
    // 防御性钳制：非转账流水优惠不允许超过金额（实付 ≥ 0）；
    // 转账的实付 = amount + fee - discount，由下方「扣款金额必须大于 0」校验兜底。
    final int newDiscount =
        newType == TxnType.transfer || rawDiscount <= newAmount
            ? rawDiscount
            : newAmount;
    final List<String>? newAttachmentList =
        attachmentUrls ?? _decodeAttachmentUrls(original.attachmentUrls);
    final String? newAttachmentUrls = _encodeAttachmentUrls(newAttachmentList);

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

    // 转账：转出方实际扣款金额 = 到账金额 + 手续费 - 优惠。
    final int? oldFromAmountMinor = original.type == TxnType.transfer
        ? original.amountMinor + original.feeMinor - original.discountMinor
        : null;
    final int? newFromAmountMinor =
        newType == TxnType.transfer ? newAmount + newFee - newDiscount : null;
    if (newFromAmountMinor != null && newFromAmountMinor <= 0) {
      throw const ValidationFailure('扣款金额必须大于 0');
    }

    await _db.transaction<void>(() async {
      // 1. 回滚旧流水对余额的影响
      await _revertBalanceDelta(
        original.type,
        original.accountId,
        original.toAccountId,
        original.amountMinor,
        now,
        fromAmountMinor: oldFromAmountMinor,
        discountMinor: original.discountMinor,
        reimbursementAccountId: original.reimbursementAccountId,
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
          attachmentUrls: Value<String?>(newAttachmentUrls),
          tags: Value<String?>(original.tags),
          sourceModule: Value<SourceModule>(identity.sourceModule),
          relatedId: Value<String?>(original.relatedId),
          transferGroupId: Value<String?>(identity.transferGroupId),
          feeMinor: Value<int>(newFee),
          discountMinor: Value<int>(newDiscount),
          excludeFromStats: Value<bool>(original.excludeFromStats),
          excludeFromBudget: Value<bool>(original.excludeFromBudget),
          isReimbursable: Value<bool>(original.isReimbursable),
          reimbursementAccountId:
              Value<String?>(original.reimbursementAccountId),
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
        fromAmountMinor: newFromAmountMinor,
        discountMinor: newDiscount,
        reimbursementAccountId: original.reimbursementAccountId,
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
          'tags': original.tags,
          'excludeFromStats': original.excludeFromStats,
          'excludeFromBudget': original.excludeFromBudget,
          'isReimbursable': original.isReimbursable,
          'reimbursementAccountId': original.reimbursementAccountId,
          'attachmentUrls': newAttachmentUrls,
          'feeMinor': newFee,
          'discountMinor': newDiscount,
        },
      );
    });
  }

  /// 按 ID 批量取流水（保持传入顺序，跳过不存在 / 已删除的 ID）。
  /// 报销收款抵扣按用户勾选顺序分摊账单时使用。
  Future<List<Transaction>> getByIds(List<String> ids) async {
    if (ids.isEmpty) return const <Transaction>[];
    final List<Transaction> rows = await (_db.select(_db.transactions)
          ..where(
            (Transactions t) => t.id.isIn(ids) & t.deleted.equals(false),
          ))
        .get();
    final Map<String, Transaction> byId = <String, Transaction>{
      for (final Transaction t in rows) t.id: t,
    };
    return <Transaction>[
      for (final String id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  /// 账单迁移：把使用 [fromId] 分类的全部流水改挂到 [toId] 分类。
  ///
  /// 仅修改 categoryId，不影响金额与账户余额，因此无需调整余额 delta。
  /// 返回被迁移的流水笔数。
  Future<int> reassignCategory(String fromId, String toId) async {    final List<String> ids =
        await _db.transactionsDao.findIdsByCategory(fromId);
    if (ids.isEmpty) return 0;
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.transaction<void>(() async {
      await _db.transactionsDao.reassignCategory(fromId, toId, now);
      for (final String id in ids) {
        await _enqueue(
          tableName: 'transactions',
          recordId: id,
          opType: SyncOpType.update,
          updatedAt: now,
          payload: <String, Object?>{'categoryId': toId},
        );
      }
    });
    return ids.length;
  }

  /// 软删除。物理删除无法同步，必须标记后随同步推送。
  ///
  /// 同时级联软删关联的报销记录：报销是这笔流水的另一视图，
  /// 删流水时必须一并移除，否则「报销账户页」会残留游离的待报销记录
  /// （删除报销记录也走本方法，双向保持同步）。
  Future<void> remove(String id) async {
    final Transaction? txn = await _db.transactionsDao.getById(id);
    if (txn == null) {
      throw const NotFoundFailure('流水不存在');
    }

    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;

    await _db.transaction<void>(() async {
      final int? fromAmountMinor = txn.type == TxnType.transfer
          ? txn.amountMinor + txn.feeMinor - txn.discountMinor
          : null;
      await _revertBalanceDelta(
        txn.type,
        txn.accountId,
        txn.toAccountId,
        txn.amountMinor,
        now,
        fromAmountMinor: fromAmountMinor,
        discountMinor: txn.discountMinor,
        reimbursementAccountId: txn.reimbursementAccountId,
      );
      await _db.transactionsDao.softDelete(id, now);
      await _enqueue(
        tableName: 'transactions',
        recordId: id,
        opType: SyncOpType.delete,
        updatedAt: now,
      );

      // 级联软删关联报销记录（bill.detail「是否报销」随之消失）。
      final List<Reimbursement> linked =
          await (_db.select(_db.reimbursements)
                ..where((Reimbursements t) => t.transactionId.equals(id))
                ..where((Reimbursements t) => t.deleted.equals(false)))
              .get();
      if (linked.isNotEmpty) {
        await (_db.update(_db.reimbursements)
              ..where((Reimbursements t) => t.transactionId.equals(id))
              ..where((Reimbursements t) => t.deleted.equals(false)))
            .write(
          const ReimbursementsCompanion(
            deleted: Value<bool>(true),
            dirty: Value<bool>(true),
          ),
        );
        for (final Reimbursement r in linked) {
          await _enqueue(
            tableName: 'reimbursements',
            recordId: r.id,
            opType: SyncOpType.delete,
            updatedAt: now,
          );
        }
      }

      // 级联恢复被这笔「报销收入」抵扣的账单（反向抵扣）。
      // 按抵扣台账（incomeAllocs）逐笔恢复：已报销 → 退回待报销
      // （金额=被抵扣额）、待报销 → 待收金额加回；报销账户垫付余额同步加回。
      // 「是否报销」开关 / 垫付中合计 / 已报销计数随之全局同步。
      if (txn.type == TxnType.income &&
          txn.sourceModule == SourceModule.reimbursement) {
        final List<Reimbursement> candidates = await (_db.select(
          _db.reimbursements,
        )..where((Reimbursements t) =>
            t.bookId.equals(txn.bookId) & t.deleted.equals(false)))
            .get();
        for (final Reimbursement r in candidates) {
          final List<ReimbAllocEntry> entries =
              List<ReimbAllocEntry>.of(parseReimbAllocs(r.incomeAllocs));
          final int idx =
              entries.indexWhere((ReimbAllocEntry e) => e.incomeId == id);
          if (idx < 0) {
            continue;
          }
          final int alloc = entries[idx].allocMinor;
          entries.removeAt(idx);
          final bool wasReimbursed =
              r.status == ReimbursementStatus.reimbursed;
          // 已报销：amountMinor=账单总额，账单总额 − 剩余台账合计 = 被删笔
          // 抵扣额，恢复后待收金额 = 被抵扣额；
          // 待报销：部分抵扣时 amountMinor 已减过，加回即可。
          final int restoredAmount =
              wasReimbursed ? alloc : r.amountMinor + alloc;
          final String? restJson = encodeReimbAllocs(entries);
          await (_db.update(_db.reimbursements)
                ..where((Reimbursements t) => t.id.equals(r.id)))
              .write(
            ReimbursementsCompanion(
              amountMinor: Value<int>(restoredAmount),
              status: wasReimbursed
                  ? const Value<ReimbursementStatus>(
                      ReimbursementStatus.pending)
                  : const Value<ReimbursementStatus>.absent(),
              receivedAt: wasReimbursed
                  ? const Value<int?>(null)
                  : const Value<int?>.absent(),
              incomeTransactionId: r.incomeTransactionId == id
                  ? const Value<String?>(null)
                  : const Value<String?>.absent(),
              incomeAllocs: Value<String?>(restJson),
              updatedAt: Value<int>(now),
              dirty: const Value<bool>(true),
            ),
          );
          await _enqueue(
            tableName: 'reimbursements',
            recordId: r.id,
            opType: SyncOpType.update,
            updatedAt: now,
            payload: <String, Object?>{
              'amountMinor': restoredAmount,
              if (wasReimbursed) 'status': ReimbursementStatus.pending.index,
              'incomeAllocs': restJson,
            },
          );
          // 垫付重新挂账：抵扣时核销过报销账户余额，删除收入后按台账加回。
          if (r.accountId != null) {
            await _db.accountsDao.adjustBalance(r.accountId!, alloc, now);
          }
        }
      }
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
    int? feeMinor,
    int? discountMinor,
    List<String>? attachmentUrls,
  }) {
    if (fromAccountId == toAccountId) {
      throw const ValidationFailure('转出与转入账户不能相同');
    }

    final int fromAmountMinor =
        amountMinor + (feeMinor ?? 0) - (discountMinor ?? 0);
    if (fromAmountMinor <= 0) {
      throw const ValidationFailure('扣款金额必须大于 0');
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
        note: _buildTransferNote(note, feeMinor, discountMinor),
        currency: currency,
        sourceModule: SourceModule.transfer,
        transferGroupId: groupId,
        fromAmountMinor: fromAmountMinor,
        feeMinor: feeMinor,
        discountMinor: discountMinor,
        attachmentUrls: attachmentUrls,
      ),
    );
  }

  /// 拼接转账备注中的手续费 / 优惠元信息。
  String? _buildTransferNote(String? note, int? feeMinor, int? discountMinor) {
    final List<String> parts = <String>[];
    if (feeMinor != null && feeMinor > 0) {
      parts.add('手续费：${Money.fromMinor(feeMinor).format()}');
    }
    if (discountMinor != null && discountMinor > 0) {
      parts.add('优惠：${Money.fromMinor(discountMinor).format()}');
    }
    if (parts.isEmpty) return note;
    final String meta = parts.join(' ');
    final String? trimmed = note?.trim();
    if (trimmed == null || trimmed.isEmpty) return meta;
    return '$meta\n$trimmed';
  }

  /// 应用余额变动。转账只调整两个账户，不改变净资产。
  ///
  /// 支出按**实付金额**（`amountMinor - discountMinor`）扣减余额：
  /// `amountMinor` 存的是优惠前原价，优惠部分并不实际支出
  /// （对齐小青账：¥85 消费优惠 ¥45，实际只扣 ¥40）。
  ///
  /// 可报销支出（[reimbursementAccountId] 非空）同时把实付金额**挂到报销账户**
  /// （应收桶）：垫付发生时 +实付，报销收款核销时再转出，增删改均可回滚。
  Future<void> _applyBalanceDelta(
    TxnType type,
    String accountId,
    String? toAccountId,
    int amountMinor,
    int now, {
    int? fromAmountMinor,
    int discountMinor = 0,
    String? reimbursementAccountId,
  }) async {
    switch (type) {
      case TxnType.income:
        await _db.accountsDao.adjustBalance(accountId, amountMinor, now);
      case TxnType.expense:
        final int actual = amountMinor - discountMinor;
        await _db.accountsDao.adjustBalance(
            accountId, actual > 0 ? -actual : 0, now);
        if (reimbursementAccountId != null && actual > 0) {
          await _db.accountsDao.adjustBalance(
              reimbursementAccountId, actual, now);
        }
      case TxnType.transfer:
        final int debit = fromAmountMinor ?? amountMinor;
        await _db.accountsDao.adjustBalance(accountId, -debit, now);
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
    int now, {
    int? fromAmountMinor,
    int discountMinor = 0,
    String? reimbursementAccountId,
  }) async {
    switch (type) {
      case TxnType.income:
        await _db.accountsDao.adjustBalance(accountId, -amountMinor, now);
      case TxnType.expense:
        final int actual = amountMinor - discountMinor;
        await _db.accountsDao.adjustBalance(
            accountId, actual > 0 ? actual : 0, now);
        if (reimbursementAccountId != null && actual > 0) {
          await _db.accountsDao.adjustBalance(
              reimbursementAccountId, -actual, now);
        }
      case TxnType.transfer:
        final int debit = fromAmountMinor ?? amountMinor;
        await _db.accountsDao.adjustBalance(accountId, debit, now);
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

/// 把图片路径列表编码为 JSON 字符串（空列表 / null 记为 null）。
String? _encodeAttachmentUrls(List<String>? list) =>
    (list == null || list.isEmpty) ? null : jsonEncode(list);

/// 把存储的 JSON 字符串解码回图片路径列表（容错：非列表 / 空串返回 null）。
List<String>? _decodeAttachmentUrls(String? json) {
  if (json == null || json.isEmpty) return null;
  try {
    final Object? decoded = jsonDecode(json);
    if (decoded is List) return decoded.cast<String>();
  } catch (_) {
    // 历史脏数据不应让读取中断。
  }
  return null;
}
