import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../database/sync_enqueue.dart';
import '../../../domain/enums.dart';

/// 借还仓储。借出 / 借入与还款进度跟踪，复用统一同步入队。
class LendRepository {
  const LendRepository(this._db);

  final AppDatabase _db;

  Stream<List<LendRecord>> watch(String bookId) {
    return (_db.select(_db.lendRecords)
          ..where(
            (LendRecords t) => t.bookId.equals(bookId) & t.deleted.equals(false),
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

  /// 坏账损失：按 [counterparty] 找到该方向下所有未结清记录，
  /// 按发生时间从早到晚递增 [repaidMinor]，直到用完 [amountMinor]。
  ///
  /// 不创建新记录，也不影响资产账户余额；仅减少剩余债权 / 债务。
  Future<void> badDebtLoss({
    required String bookId,
    required LendDirection direction,
    required String counterparty,
    required int amountMinor,
    required int occurredAt,
    String? note,
  }) {
    if (counterparty.trim().isEmpty) {
      throw const ValidationFailure('对方不能为空');
    }
    if (amountMinor <= 0) throw const ValidationFailure('金额必须大于 0');

    final String trimmed = counterparty.trim();
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final String dirLabel =
        direction == LendDirection.borrowIn ? '借入' : '借出';

    return _db.transaction<void>(() async {
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
        throw ValidationFailure('未找到$dirLabel给「$trimmed」的未结清记录');
      }

      int remaining = amountMinor;
      for (final LendRecord r in records) {
        if (remaining <= 0) break;
        final int left = r.amountMinor - r.repaidMinor;
        if (left <= 0) continue;
        final int apply = remaining < left ? remaining : left;
        final int newRepaid = r.repaidMinor + apply;
        final LendStatus newStatus =
            newRepaid >= r.amountMinor ? LendStatus.settled : r.status;

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
        throw const ValidationFailure('坏账损失金额超过剩余债务');
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
