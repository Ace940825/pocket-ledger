import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../database/sync_enqueue.dart';
import '../../../domain/enums.dart';
import '../../ledger/data/transaction_repository.dart';

/// 借还仓储。借出 / 借入与还款进度跟踪，复用统一同步入队。
class LendRepository {
  const LendRepository(this._db, this._txnRepo);

  final AppDatabase _db;
  final TransactionRepository _txnRepo;

  Stream<List<LendRecord>> watch(String bookId) {
    return (_db.select(_db.lendRecords)
          ..where(
            (LendRecords t) =>
                t.bookId.equals(bookId) & t.deleted.equals(false),
          )
          ..orderBy([(LendRecords t) => OrderingTerm.desc(t.occurredAt)]))
        .watch();
  }

  Future<String> add({
    required String bookId,
    required LendDirection direction,
    required LendStatus status,
    required String counterparty,
    required int amountMinor,
    int repaidMinor = 0,
    required int occurredAt,
    int? dueAt,
    String? note,
    String? accountId,
    String? toAccountId,
    int feeMinor = 0,
    int discountMinor = 0,
  }) {
    if (counterparty.trim().isEmpty) {
      throw const ValidationFailure('对方不能为空');
    }
    if (amountMinor <= 0) throw const ValidationFailure('金额必须大于 0');

    final String id = const Uuid().v7();
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;

    return _db.transaction<String>(() async {
      await _db.into(_db.lendRecords).insert(
            LendRecordsCompanion(
              id: Value<String>(id),
              bookId: Value<String>(bookId),
              direction: Value<LendDirection>(direction),
              status: Value<LendStatus>(status),
              counterparty: Value<String>(counterparty.trim()),
              amountMinor: Value<int>(amountMinor),
              repaidMinor: Value<int>(repaidMinor),
              occurredAt: Value<int>(occurredAt),
              dueAt: Value<int?>(dueAt),
              note: Value<String?>(note),
              accountId: Value<String?>(accountId),
              toAccountId: Value<String?>(toAccountId),
              feeMinor: Value<int>(feeMinor),
              discountMinor: Value<int>(discountMinor),
              updatedAt: Value<int>(now),
              dirty: const Value<bool>(true),
            ),
          );
      await enqueueSyncOp(
        _db,
        table: 'lend_records',
        recordId: id,
        opType: SyncOpType.insert,
        updatedAt: now,
        payload: <String, Object?>{
          'direction': direction.index,
          'status': status.index,
          'counterparty': counterparty.trim(),
          'amountMinor': amountMinor,
          'repaidMinor': repaidMinor,
          'occurredAt': occurredAt,
          'dueAt': dueAt,
          'note': note,
          'accountId': accountId,
          'toAccountId': toAccountId,
          'feeMinor': feeMinor,
          'discountMinor': discountMinor,
        },
      );
      return id;
    });
  }

  Future<void> update({
    required String id,
    required LendDirection direction,
    required LendStatus status,
    required String counterparty,
    required int amountMinor,
    int repaidMinor = 0,
    required int occurredAt,
    int? dueAt,
    String? note,
    String? accountId,
    String? toAccountId,
    int feeMinor = 0,
    int discountMinor = 0,
  }) {
    if (counterparty.trim().isEmpty) {
      throw const ValidationFailure('对方不能为空');
    }
    if (amountMinor <= 0) throw const ValidationFailure('金额必须大于 0');

    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    return _db.transaction<void>(() async {
      await (_db.update(_db.lendRecords)
            ..where((LendRecords t) => t.id.equals(id)))
          .write(
        LendRecordsCompanion(
          direction: Value<LendDirection>(direction),
          status: Value<LendStatus>(status),
          counterparty: Value<String>(counterparty.trim()),
          amountMinor: Value<int>(amountMinor),
          repaidMinor: Value<int>(repaidMinor),
          occurredAt: Value<int>(occurredAt),
          dueAt: Value<int?>(dueAt),
          note: Value<String?>(note),
          accountId: Value<String?>(accountId),
          toAccountId: Value<String?>(toAccountId),
          feeMinor: Value<int>(feeMinor),
          discountMinor: Value<int>(discountMinor),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );
      await enqueueSyncOp(
        _db,
        table: 'lend_records',
        recordId: id,
        opType: SyncOpType.update,
        updatedAt: now,
        payload: <String, Object?>{
          'direction': direction.index,
          'status': status.index,
          'counterparty': counterparty.trim(),
          'amountMinor': amountMinor,
          'repaidMinor': repaidMinor,
          'occurredAt': occurredAt,
          'dueAt': dueAt,
          'note': note,
          'accountId': accountId,
          'toAccountId': toAccountId,
          'feeMinor': feeMinor,
          'discountMinor': discountMinor,
        },
      );
    });
  }

  /// 核心冲销逻辑（**不开启事务**，必须由调用方包在事务里）：
  /// 把 [amountMinor] 按发生时间从早到晚，分摊到 [direction]+[counterparty] 名下
  /// 所有「进行中(ongoing)」债务记录的剩余本金上，更新每条的
  /// [LendRecords.repaidMinor]，并在足量时把状态置为「已结清(settled)」。
  ///
  /// **不创建新记录**，仅冲减已有债务；每条被改动的记录都逐条入队同步。
  /// 找不到未结清债务、或金额超过剩余债务时会抛 [ValidationFailure]，从而让
  /// 外层事务整体回滚。
  ///
  /// [notFoundHint] / [overHint] 用于区分「减免」与「还款」两套报错文案。
  Future<void> _offsetDebts({
    required String bookId,
    required LendDirection direction,
    required String counterparty,
    required int amountMinor,
    required String notFoundHint,
    required String overHint,
  }) async {
    if (counterparty.trim().isEmpty) {
      throw const ValidationFailure('对方不能为空');
    }
    if (amountMinor <= 0) throw const ValidationFailure('金额必须大于 0');

    final String trimmed = counterparty.trim();
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;

    final List<LendRecord> records = await (_db.select(_db.lendRecords)
          ..where(
            (LendRecords t) =>
                t.bookId.equals(bookId) &
                t.direction.equals(direction.index) &
                t.counterparty.equals(trimmed) &
                t.deleted.equals(false) &
                t.status.equals(LendStatus.ongoing.index),
          )
          ..orderBy([(LendRecords t) => OrderingTerm.asc(t.occurredAt)]))
        .get();

    if (records.isEmpty) {
      throw ValidationFailure(notFoundHint);
    }

    int remaining = amountMinor;
    for (final LendRecord r in records) {
      if (remaining <= 0) break;
      // 剩余债务 = 本金 − 优惠（减免）− 已还；优惠在借入/借出时已把
      // 债务净额减少，冲销与结清判断都必须把它算进去。
      final int left = r.amountMinor - r.discountMinor - r.repaidMinor;
      if (left <= 0) continue;
      final int apply = remaining < left ? remaining : left;
      final int newRepaid = r.repaidMinor + apply;
      final LendStatus newStatus =
          newRepaid + r.discountMinor >= r.amountMinor
              ? LendStatus.settled
              : r.status;

      await (_db.update(_db.lendRecords)
            ..where((LendRecords t) => t.id.equals(r.id)))
          .write(
        LendRecordsCompanion(
          repaidMinor: Value<int>(newRepaid),
          status: Value<LendStatus>(newStatus),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );
      await enqueueSyncOp(
        _db,
        table: 'lend_records',
        recordId: r.id,
        opType: SyncOpType.update,
        updatedAt: now,
        payload: <String, Object?>{
          'direction': r.direction.index,
          'status': newStatus.index,
          'counterparty': trimmed,
          'amountMinor': r.amountMinor,
          'repaidMinor': newRepaid,
          'occurredAt': r.occurredAt,
          'dueAt': r.dueAt,
          'note': r.note,
          'accountId': r.accountId,
          'toAccountId': r.toAccountId,
          'feeMinor': r.feeMinor,
          'discountMinor': r.discountMinor,
        },
      );
      remaining -= apply;
    }

    if (remaining > 0) {
      throw ValidationFailure(overHint);
    }
  }

  /// 债务削减 / 减免：按 [counterparty] 找到该方向下所有未结清记录并冲减，
  /// 不影响资产账户余额（借出方向为坏账计提、借入方向为债务削减，均无真实资金流动）。不新增记录。
  Future<void> debtReduction({
    required String bookId,
    required LendDirection direction,
    required String counterparty,
    required int amountMinor,
    required int occurredAt,
    String? note,
  }) {
    final String dirLabel = direction == LendDirection.borrowIn ? '借入' : '借出';
    return _db.transaction<void>(() async {
      await _offsetDebts(
        bookId: bookId,
        direction: direction,
        counterparty: counterparty,
        amountMinor: amountMinor,
        notFoundHint: '未找到$dirLabel给「${counterparty.trim()}」的未结清记录',
        overHint: '减免金额超过剩余债务',
      );
    });
  }

  /// 还债 / 收债：按 [counterparty] 冲销该方向下所有未结清债务，
  /// 真正减少剩余应收 / 应付（**不新增借还记录**），状态足额时转为「已结清」。
  ///
  /// 当 [accountId] 给定时，会**同时写一条真实的资金流水**，让钱包余额随之变化
  /// （与「借还冲销」处于同一个 DB 事务，保证原子性）：
  /// - 借入方向（还债）：现金从账户流出 → 支出(expense)，余额减少；
  /// - 借出方向（收债）：现金流入账户 → 收入(income)，余额增加。
  ///
  /// [accountId] 为 null / 空时退化为「只冲销债务、不动余额」的旧行为。
  Future<void> repay({
    required String bookId,
    required LendDirection direction,
    required String counterparty,
    required int amountMinor,
    required int occurredAt,
    String? note,
    String? accountId,
  }) {
    final String verb = direction == LendDirection.borrowIn ? '还债' : '收债';
    final TxnType txnType =
        direction == LendDirection.borrowIn ? TxnType.expense : TxnType.income;

    return _db.transaction<void>(() async {
      await _offsetDebts(
        bookId: bookId,
        direction: direction,
        counterparty: counterparty,
        amountMinor: amountMinor,
        notFoundHint: '未找到可$verb的「${counterparty.trim()}」未结清债务',
        overHint: '$verb金额超过剩余未结清债务',
      );

      if (accountId != null && accountId.isNotEmpty) {
        final String trimmed = counterparty.trim();
        final String? userNote = note?.trim();
        final String txnNote = userNote == null || userNote.isEmpty
            ? '$verb-$trimmed'
            : '$verb-$trimmed\n$userNote';
        await _txnRepo.add(
          bookId: bookId,
          type: txnType,
          amountMinor: amountMinor,
          accountId: accountId,
          occurredAt: occurredAt,
          note: txnNote,
          sourceModule: SourceModule.lend,
        );
      }
    });
  }

  Future<void> remove(String id) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.transaction<void>(() async {
      await (_db.update(_db.lendRecords)
            ..where((LendRecords t) => t.id.equals(id)))
          .write(
        const LendRecordsCompanion(
          deleted: Value<bool>(true),
          dirty: Value<bool>(true),
        ),
      );
      await enqueueSyncOp(
        _db,
        table: 'lend_records',
        recordId: id,
        opType: SyncOpType.delete,
        updatedAt: now,
      );
    });
  }
}
