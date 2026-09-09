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
        },
      );
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
