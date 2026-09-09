import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../database/sync_enqueue.dart';
import '../../../domain/enums.dart';

/// 报销仓储。
///
/// 报销与「垫付」强相关：先由个人账户垫付支出，后续从公司收回。
/// 因此本表只跟踪应收进度与状态流转，真实资金流仍记在流水表里，
/// 通过 [Reimbursements.transactionId] 关联，避免同一笔钱被重复计入报表。
class ReimbursementRepository {
  const ReimbursementRepository(this._db);

  final AppDatabase _db;

  Stream<List<Reimbursement>> watch(String bookId) {
    return (_db.select(_db.reimbursements)
          ..where(
            (Reimbursements t) =>
                t.bookId.equals(bookId) & t.deleted.equals(false),
          )
          ..orderBy(<OrderClauseGenerator<Reimbursements>>[
            (Reimbursements t) => OrderingTerm.desc(t.occurredAt),
          ]))
        .watch();
  }

  Future<String> add({
    required String bookId,
    required String title,
    required ReimbursementStatus status,
    required int amountMinor,
    required String payer,
    required int occurredAt,
    String? target,
    int? receivedAt,
    String? note,
  }) {
    _validate(title: title, payer: payer, amountMinor: amountMinor);

    final String id = const Uuid().v7();
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;

    return _db.transaction<String>(() async {
      await _db.into(_db.reimbursements).insert(
            ReimbursementsCompanion(
              id: Value<String>(id),
              bookId: Value<String>(bookId),
              title: Value<String>(title.trim()),
              status: Value<ReimbursementStatus>(status),
              amountMinor: Value<int>(amountMinor),
              payer: Value<String>(payer.trim()),
              target: Value<String?>(target),
              occurredAt: Value<int>(occurredAt),
              receivedAt: Value<int?>(receivedAt),
              note: Value<String?>(note),
              updatedAt: Value<int>(now),
              dirty: const Value<bool>(true),
            ),
          );
      await enqueueSyncOp(
        _db,
        table: 'reimbursements',
        recordId: id,
        opType: SyncOpType.insert,
        updatedAt: now,
        payload: _payload(
          title: title,
          status: status,
          amountMinor: amountMinor,
          payer: payer,
          target: target,
          occurredAt: occurredAt,
          receivedAt: receivedAt,
          note: note,
        ),
      );
      return id;
    });
  }

  Future<void> update({
    required String id,
    required String title,
    required ReimbursementStatus status,
    required int amountMinor,
    required String payer,
    required int occurredAt,
    String? target,
    int? receivedAt,
    String? note,
  }) {
    _validate(title: title, payer: payer, amountMinor: amountMinor);

    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    return _db.transaction<void>(() async {
      await (_db.update(_db.reimbursements)
            ..where((Reimbursements t) => t.id.equals(id)))
          .write(
        ReimbursementsCompanion(
          title: Value<String>(title.trim()),
          status: Value<ReimbursementStatus>(status),
          amountMinor: Value<int>(amountMinor),
          payer: Value<String>(payer.trim()),
          target: Value<String?>(target),
          occurredAt: Value<int>(occurredAt),
          receivedAt: Value<int?>(receivedAt),
          note: Value<String?>(note),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );
      await enqueueSyncOp(
        _db,
        table: 'reimbursements',
        recordId: id,
        opType: SyncOpType.update,
        updatedAt: now,
        payload: _payload(
          title: title,
          status: status,
          amountMinor: amountMinor,
          payer: payer,
          target: target,
          occurredAt: occurredAt,
          receivedAt: receivedAt,
          note: note,
        ),
      );
    });
  }

  /// 推进状态。收款完成时自动补上 receivedAt，省去用户手动选日期。
  Future<void> advanceStatus(
    String id,
    ReimbursementStatus status,
  ) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.transaction<void>(() async {
      await (_db.update(_db.reimbursements)
            ..where((Reimbursements t) => t.id.equals(id)))
          .write(
        ReimbursementsCompanion(
          status: Value<ReimbursementStatus>(status),
          receivedAt: status == ReimbursementStatus.received
              ? Value<int?>(now)
              : const Value<int?>.absent(),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );
      await enqueueSyncOp(
        _db,
        table: 'reimbursements',
        recordId: id,
        opType: SyncOpType.update,
        updatedAt: now,
        payload: <String, Object?>{'status': status.index},
      );
    });
  }

  Future<void> remove(String id) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.transaction<void>(() async {
      await (_db.update(_db.reimbursements)
            ..where((Reimbursements t) => t.id.equals(id)))
          .write(
        const ReimbursementsCompanion(
          deleted: Value<bool>(true),
          dirty: Value<bool>(true),
        ),
      );
      await enqueueSyncOp(
        _db,
        table: 'reimbursements',
        recordId: id,
        opType: SyncOpType.delete,
        updatedAt: now,
      );
    });
  }

  void _validate({
    required String title,
    required String payer,
    required int amountMinor,
  }) {
    if (title.trim().isEmpty) throw const ValidationFailure('报销事由不能为空');
    if (payer.trim().isEmpty) throw const ValidationFailure('垫付人不能为空');
    if (amountMinor <= 0) throw const ValidationFailure('金额必须大于 0');
  }

  Map<String, Object?> _payload({
    required String title,
    required ReimbursementStatus status,
    required int amountMinor,
    required String payer,
    required int occurredAt,
    String? target,
    int? receivedAt,
    String? note,
  }) {
    return <String, Object?>{
      'title': title.trim(),
      'status': status.index,
      'amountMinor': amountMinor,
      'payer': payer.trim(),
      'target': target,
      'occurredAt': occurredAt,
      'receivedAt': receivedAt,
      'note': note,
    };
  }
}
