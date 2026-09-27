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

  /// 含已软删除记录的完整列表（用于「显示已删除账单」开关）。
  ///
  /// 不按 `deleted` 过滤，其余排序与 [watch] 一致。
  Stream<List<Reimbursement>> watchAll(String bookId) {
    return (_db.select(_db.reimbursements)
          ..where((Reimbursements t) => t.bookId.equals(bookId))
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
    bool excludeFromStats = false,
    String? accountId,
    String? toAccountId,
    String? transactionId,
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
              excludeFromStats: Value<bool>(excludeFromStats),
              accountId: Value<String?>(accountId),
              toAccountId: Value<String?>(toAccountId),
              transactionId: Value<String?>(transactionId),
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
          excludeFromStats: excludeFromStats,
          accountId: accountId,
          toAccountId: toAccountId,
          transactionId: transactionId,
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
    bool excludeFromStats = false,
    String? accountId,
    String? toAccountId,
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
          excludeFromStats: Value<bool>(excludeFromStats),
          accountId: Value<String?>(accountId),
          toAccountId: Value<String?>(toAccountId),
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
          excludeFromStats: excludeFromStats,
          accountId: accountId,
          toAccountId: toAccountId,
        ),
      );
    });
  }

  /// 按关联流水查看报销记录（流水详情弹窗「是否报销」同步用）。
  Stream<Reimbursement?> watchByTransactionId(String transactionId) {
    return (_db.select(_db.reimbursements)
          ..where((Reimbursements t) => t.transactionId.equals(transactionId))
          ..where((Reimbursements t) => t.deleted.equals(false))
          ..limit(1))
        .watchSingleOrNull();
  }

  /// 按关联流水量取一条未删除的报销记录（报销收款抵扣用，一次性读取）。
  Future<Reimbursement?> byTransaction(String transactionId) {
    return (_db.select(_db.reimbursements)
          ..where((Reimbursements t) =>
              t.transactionId.equals(transactionId) & t.deleted.equals(false))
          ..orderBy(<OrderClauseGenerator<Reimbursements>>[
            (Reimbursements t) => OrderingTerm.desc(t.occurredAt),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  /// 实时监听被某笔「报销收入」流水抵扣的全部报销记录
  /// （流水详情弹窗「关联账单」反向展示用）。
  Stream<List<Reimbursement>> watchByIncomeTransactionId(String incomeId) {
    return (_db.select(_db.reimbursements)
          ..where((Reimbursements t) =>
              t.incomeTransactionId.equals(incomeId) &
              t.deleted.equals(false))
          ..orderBy(<OrderClauseGenerator<Reimbursements>>[
            (Reimbursements t) => OrderingTerm.desc(t.occurredAt),
          ]))
        .watch();
  }

  /// 报销收款抵扣：从该笔报销的待收金额中核销 [allocMinor]。
  ///
  /// - 覆盖完整笔（alloc ≥ 待收金额）→ 状态转「已报销」+ receivedAt；
  /// - 部分覆盖 → 待收金额（amountMinor）扣减 alloc，状态保持「待报销」；
  /// - [incomeTransactionId]：本次抵扣对应的「报销收入」流水，写回记录用于
  ///   账单明细弹窗反向展示「关联账单」。
  Future<void> deduct(
    String id,
    int allocMinor, {
    String? incomeTransactionId,
  }) async {
    if (allocMinor <= 0) return;
    final Reimbursement? row = await (_db.select(_db.reimbursements)
          ..where((Reimbursements t) =>
              t.id.equals(id) & t.deleted.equals(false)))
        .getSingleOrNull();
    if (row == null) {
      throw const NotFoundFailure('报销记录不存在');
    }
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final bool full = allocMinor >= row.amountMinor;
    final int remaining = row.amountMinor - allocMinor;
    await _db.transaction<void>(() async {
      await (_db.update(_db.reimbursements)
            ..where((Reimbursements t) => t.id.equals(id)))
          .write(
        full
            ? ReimbursementsCompanion(
                status: const Value<ReimbursementStatus>(
                    ReimbursementStatus.reimbursed),
                receivedAt: Value<int?>(now),
                incomeTransactionId: incomeTransactionId == null
                    ? const Value<String?>.absent()
                    : Value<String?>(incomeTransactionId),
                updatedAt: Value<int>(now),
                dirty: const Value<bool>(true),
              )
            : ReimbursementsCompanion(
                amountMinor: Value<int>(remaining),
                incomeTransactionId: incomeTransactionId == null
                    ? const Value<String?>.absent()
                    : Value<String?>(incomeTransactionId),
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
        payload: full
            ? <String, Object?>{
                'status': ReimbursementStatus.reimbursed.index,
                'receivedAt': now,
              }
            : <String, Object?>{'amountMinor': remaining},
      );
    });
  }

  /// 流水明细「是否报销」开关：
  /// 是 → 已报销 + receivedAt=now；否 → 待报销 + 清空 receivedAt。
  /// 状态真实翻转时同步联动报销账户余额（核销 / 恢复垫付）。
  Future<void> setReimbursed(String id, bool reimbursed) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final Reimbursement? record = await (_db.select(_db.reimbursements)
          ..where((Reimbursements t) => t.id.equals(id)))
        .getSingleOrNull();
    if (record == null) return;
    final ReimbursementStatus status = reimbursed
        ? ReimbursementStatus.reimbursed
        : ReimbursementStatus.pending;
    await _db.transaction<void>(() async {
      await (_db.update(_db.reimbursements)
            ..where((Reimbursements t) => t.id.equals(id)))
          .write(
        ReimbursementsCompanion(
          status: Value<ReimbursementStatus>(status),
          receivedAt: Value<int?>(reimbursed ? now : null),
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
        payload: <String, Object?>{
          'status': status.index,
          'receivedAt': reimbursed ? now : null,
        },
      );
      await _adjustBalanceForStatusChange(
        record.status,
        status,
        accountId: record.accountId,
        amountMinor: record.amountMinor,
      );
    });
  }

  /// 推进状态（报销页手动标记已报销 / 退回待报销），
  /// 状态真实翻转时同步联动报销账户余额（核销 / 恢复垫付）。
  Future<void> advanceStatus(
    String id,
    ReimbursementStatus status,
  ) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final Reimbursement? record = await (_db.select(_db.reimbursements)
          ..where((Reimbursements t) => t.id.equals(id)))
        .getSingleOrNull();
    if (record == null) return;
    await _db.transaction<void>(() async {
      await (_db.update(_db.reimbursements)
            ..where((Reimbursements t) => t.id.equals(id)))
          .write(
        ReimbursementsCompanion(
          status: Value<ReimbursementStatus>(status),
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
      await _adjustBalanceForStatusChange(
        record.status,
        status,
        accountId: record.accountId,
        amountMinor: record.amountMinor,
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

  /// 核销报销账户的垫付挂账（应收桶）。
  ///
  /// 报销收入以 income 流水直接进收款账户（计入收支），报销账户侧不再
  /// 生成「转出」流水，而是按抵扣金额直接调减余额——保持「待收垫付」口径：
  /// 垫付时 +实付，收回时 -实收，账户余额 = 尚未收回的垫付。
  /// `adjustBalance` 内部置 dirty=1，随账户同步推送。
  Future<void> writeOffReceivable(String accountId, int amountMinor) async {
    if (amountMinor <= 0) return;
    await _db.accountsDao.adjustBalance(
      accountId,
      -amountMinor,
      DateTime.now().toUtc().millisecondsSinceEpoch,
    );
  }

  /// 垫付挂账：把实付金额挂到报销账户（应收桶），与 [writeOffReceivable]
  /// 对偶。用于「记报销收入时为无报销账户的历史账单补建记录」的场景——
  /// 这类账单落账时没挂过余额，须先补挂再核销，余额才等于待收垫付。
  Future<void> hangAdvance(String accountId, int amountMinor) async {
    if (amountMinor <= 0) return;
    await _db.accountsDao.adjustBalance(
      accountId,
      amountMinor,
      DateTime.now().toUtc().millisecondsSinceEpoch,
    );
  }

  /// 状态手动流转联动报销账户余额（维持「余额 = 待收垫付」不变量）：
  /// 待报销 → 已报销：垫付收回，核销 -amount；
  /// 已报销 → 待报销：垫付恢复，+amount。
  /// 抵扣链路（[deduct]）不走这里——那次核销由记账侧 writeOffReceivable 处理。
  Future<void> _adjustBalanceForStatusChange(
    ReimbursementStatus before,
    ReimbursementStatus after, {
    required String? accountId,
    required int amountMinor,
  }) async {
    if (accountId == null || before == after) return;
    final int delta = switch ((before, after)) {
      (
        ReimbursementStatus.pending,
        ReimbursementStatus.reimbursed
      ) =>
        -amountMinor,
      (
        ReimbursementStatus.reimbursed,
        ReimbursementStatus.pending
      ) =>
        amountMinor,
      _ => 0,
    };
    if (delta == 0) return;
    await _db.accountsDao.adjustBalance(
      accountId,
      delta,
      DateTime.now().toUtc().millisecondsSinceEpoch,
    );
  }

  /// 恢复一条已软删除的报销记录（「显示已删除账单」里的「恢复」操作）。
  Future<void> restore(String id) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.transaction<void>(() async {
      await (_db.update(_db.reimbursements)
            ..where((Reimbursements t) => t.id.equals(id)))
          .write(
        const ReimbursementsCompanion(
          deleted: Value<bool>(false),
          dirty: Value<bool>(true),
        ),
      );
      await enqueueSyncOp(
        _db,
        table: 'reimbursements',
        recordId: id,
        opType: SyncOpType.update,
        updatedAt: now,
        payload: <String, Object?>{'deleted': false},
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
    bool excludeFromStats = false,
    String? accountId,
    String? toAccountId,
    String? transactionId,
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
      'excludeFromStats': excludeFromStats,
      'accountId': accountId,
      'toAccountId': toAccountId,
      if (transactionId != null) 'transactionId': transactionId,
    };
  }
}
