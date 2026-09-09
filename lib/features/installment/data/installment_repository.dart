import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failures.dart';
import '../../../core/utils/date_utils.dart';
import '../../../database/app_database.dart';
import '../../../database/sync_enqueue.dart';
import '../../../domain/enums.dart';

/// 分期仓储。计划（[InstallmentPlans]）与每期明细（[InstallmentPeriods]）成对维护。
///
/// 关键设计：创建计划时**一次性生成全部期数明细**，而不是每月动态推算。
/// 理由有两点：一是用户经常需要修改某一期的金额（提前还款、减免手续费），
/// 有实体行才好改；二是明细落库后「下一期该还多少、逾期了几期」都是简单查询，
/// 不必在 UI 层重复做日期运算。
class InstallmentRepository {
  const InstallmentRepository(this._db);

  final AppDatabase _db;

  Stream<List<InstallmentPlan>> watchPlans(String bookId) {
    return (_db.select(_db.installmentPlans)
          ..where(
            (InstallmentPlans t) =>
                t.bookId.equals(bookId) & t.deleted.equals(false),
          )
          ..orderBy(<OrderClauseGenerator<InstallmentPlans>>[
            (InstallmentPlans t) => OrderingTerm.asc(t.isFinished),
            (InstallmentPlans t) => OrderingTerm.asc(t.firstDueAt),
          ]))
        .watch();
  }

  Stream<List<InstallmentPeriod>> watchPeriods(String planId) {
    return (_db.select(_db.installmentPeriods)
          ..where(
            (InstallmentPeriods t) =>
                t.planId.equals(planId) & t.deleted.equals(false),
          )
          ..orderBy(<OrderClauseGenerator<InstallmentPeriods>>[
            (InstallmentPeriods t) => OrderingTerm.asc(t.periodIndex),
          ]))
        .watch();
  }

  /// 创建计划并生成每期明细。
  ///
  /// 均摊余数放在**最后一期**：例如 1000 元分 3 期，前两期各 333.33，
  /// 末期 333.34，保证各期之和严格等于总额，不会因四舍五入丢分。
  Future<String> addPlan({
    required String bookId,
    required String title,
    required int totalMinor,
    required int totalPeriods,
    int feePerPeriodMinor = 0,
    required int firstDueAt,
    String? accountId,
    String? note,
  }) {
    if (title.trim().isEmpty) throw const ValidationFailure('分期名称不能为空');
    if (totalMinor <= 0) throw const ValidationFailure('总金额必须大于 0');
    if (totalPeriods <= 0 || totalPeriods > 120) {
      throw const ValidationFailure('期数需在 1 - 120 之间');
    }

    final String planId = const Uuid().v7();
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final DateTime firstDue =
        DateTime.fromMillisecondsSinceEpoch(firstDueAt, isUtc: true).toLocal();

    final int base = totalMinor ~/ totalPeriods;
    final int remainder = totalMinor - base * totalPeriods;

    return _db.transaction<String>(() async {
      await _db.into(_db.installmentPlans).insert(
            InstallmentPlansCompanion(
              id: Value<String>(planId),
              bookId: Value<String>(bookId),
              title: Value<String>(title.trim()),
              totalMinor: Value<int>(totalMinor),
              totalPeriods: Value<int>(totalPeriods),
              feePerPeriodMinor: Value<int>(feePerPeriodMinor),
              firstDueAt: Value<int>(firstDueAt),
              accountId: Value<String?>(accountId),
              note: Value<String?>(note),
              updatedAt: Value<int>(now),
              dirty: const Value<bool>(true),
            ),
          );

      for (int i = 0; i < totalPeriods; i++) {
        final String periodId = const Uuid().v7();
        final int amount = base + (i == totalPeriods - 1 ? remainder : 0);
        final int dueAt =
            addMonths(firstDue, i).toUtc().millisecondsSinceEpoch;

        await _db.into(_db.installmentPeriods).insert(
              InstallmentPeriodsCompanion(
                id: Value<String>(periodId),
                planId: Value<String>(planId),
                periodIndex: Value<int>(i + 1),
                amountMinor: Value<int>(amount + feePerPeriodMinor),
                dueAt: Value<int>(dueAt),
                updatedAt: Value<int>(now),
                dirty: const Value<bool>(true),
              ),
            );
        await enqueueSyncOp(
          _db,
          table: 'installment_periods',
          recordId: periodId,
          opType: SyncOpType.insert,
          updatedAt: now,
          payload: <String, Object?>{
            'planId': planId,
            'periodIndex': i + 1,
            'amountMinor': amount + feePerPeriodMinor,
            'dueAt': dueAt,
          },
        );
      }

      await enqueueSyncOp(
        _db,
        table: 'installment_plans',
        recordId: planId,
        opType: SyncOpType.insert,
        updatedAt: now,
        payload: <String, Object?>{
          'title': title.trim(),
          'totalMinor': totalMinor,
          'totalPeriods': totalPeriods,
          'feePerPeriodMinor': feePerPeriodMinor,
          'firstDueAt': firstDueAt,
          'accountId': accountId,
          'note': note,
        },
      );
      return planId;
    });
  }

  /// 标记某期已还 / 撤销已还，并同步刷新计划的已还期数与完结标记。
  Future<void> togglePeriodPaid(String periodId, {required bool paid}) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;

    await _db.transaction<void>(() async {
      final InstallmentPeriod? period = await (_db
                .select(_db.installmentPeriods)
            ..where((InstallmentPeriods t) => t.id.equals(periodId)))
          .getSingleOrNull();
      if (period == null) throw const NotFoundFailure('分期明细不存在');

      await (_db.update(_db.installmentPeriods)
            ..where((InstallmentPeriods t) => t.id.equals(periodId)))
          .write(
        InstallmentPeriodsCompanion(
          paidAt: paid ? Value<int?>(now) : const Value<int?>(null),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );
      await enqueueSyncOp(
        _db,
        table: 'installment_periods',
        recordId: periodId,
        opType: SyncOpType.update,
        updatedAt: now,
        payload: <String, Object?>{'paidAt': paid ? now : null},
      );

      await _refreshPlanProgress(period.planId, now);
    });
  }

  /// 依据明细实际状态回写计划进度。
  ///
  /// 不用「+1 / -1」增量更新，因为撤销、批量改期、同步合并都可能让计数漂移；
  /// 直接按明细重算是唯一可靠的口径。
  Future<void> _refreshPlanProgress(String planId, int now) async {
    final List<InstallmentPeriod> periods = await (_db
              .select(_db.installmentPeriods)
          ..where(
            (InstallmentPeriods t) =>
                t.planId.equals(planId) & t.deleted.equals(false),
          ))
        .get();

    final int paidCount =
        periods.where((InstallmentPeriod p) => p.paidAt != null).length;
    final bool finished = periods.isNotEmpty && paidCount == periods.length;

    await (_db.update(_db.installmentPlans)
          ..where((InstallmentPlans t) => t.id.equals(planId)))
        .write(
      InstallmentPlansCompanion(
        paidPeriods: Value<int>(paidCount),
        isFinished: Value<bool>(finished),
        updatedAt: Value<int>(now),
        dirty: const Value<bool>(true),
      ),
    );
    await enqueueSyncOp(
      _db,
      table: 'installment_plans',
      recordId: planId,
      opType: SyncOpType.update,
      updatedAt: now,
      payload: <String, Object?>{
        'paidPeriods': paidCount,
        'isFinished': finished,
      },
    );
  }

  Future<void> removePlan(String planId) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.transaction<void>(() async {
      await (_db.update(_db.installmentPlans)
            ..where((InstallmentPlans t) => t.id.equals(planId)))
          .write(
        const InstallmentPlansCompanion(
          deleted: Value<bool>(true),
          dirty: Value<bool>(true),
        ),
      );
      await (_db.update(_db.installmentPeriods)
            ..where((InstallmentPeriods t) => t.planId.equals(planId)))
          .write(
        const InstallmentPeriodsCompanion(
          deleted: Value<bool>(true),
          dirty: Value<bool>(true),
        ),
      );
      await enqueueSyncOp(
        _db,
        table: 'installment_plans',
        recordId: planId,
        opType: SyncOpType.delete,
        updatedAt: now,
      );
    });
  }
}
