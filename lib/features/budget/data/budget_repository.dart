import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failures.dart';
import '../../../core/utils/date_utils.dart';
import '../../../database/app_database.dart';
import '../../../database/sync_enqueue.dart';
import '../../../domain/enums.dart';

/// 预算仓储。
///
/// 预算本身不存「已用多少」，而是每次按周期区间实时聚合流水。
/// 这样做的好处是：补录、修改、删除历史流水后，预算进度自动是对的，
/// 不需要任何回填任务；代价只是一次带索引的 SUM 查询。
class BudgetRepository {
  const BudgetRepository(this._db);

  final AppDatabase _db;

  Stream<List<Budget>> watch(String bookId) {
    return (_db.select(_db.budgets)
          ..where(
            (Budgets t) => t.bookId.equals(bookId) & t.deleted.equals(false),
          )
          ..orderBy(<OrderClauseGenerator<Budgets>>[
            (Budgets t) => OrderingTerm.asc(t.scope),
            (Budgets t) => OrderingTerm.desc(t.year),
          ]))
        .watch();
  }

  /// 指定区间内某类型流水合计（分）。[categoryId] 为 null 时统计全部。
  ///
  /// [type] 默认支出（预算已用口径）；第 32 批首页「收入目标」卡复用同一
  /// 查询查收入（已得口径）——收入侧 discount 恒 0，实付口径不受影响。
  /// 口径 = 实付（amount − discount）+ 不计预算的流水排除（excludeFromBudget）。
  Stream<int> watchSpent({
    required String bookId,
    required int startAt,
    required int endAt,
    String? categoryId,
    TxnType type = TxnType.expense,
  }) {
    final $TransactionsTable t = _db.transactions;
    // 实付口径（与收支统计一致）：amount 存优惠前原价，优惠部分不计入支出
    final Expression<int> total = (t.amountMinor - t.discountMinor).sum();

    Expression<bool> predicate = t.bookId.equals(bookId) &
        t.deleted.equals(false) &
        t.excludeFromBudget.equals(false) &
        t.type.equals(type.index) &
        t.occurredAt.isBiggerOrEqualValue(startAt) &
        t.occurredAt.isSmallerThanValue(endAt);
    if (categoryId != null) {
      predicate = predicate & t.categoryId.equals(categoryId);
    }

    return (_db.selectOnly(t)
          ..addColumns(<Expression<Object>>[total])
          ..where(predicate))
        .map((TypedResult row) => row.read(total) ?? 0)
        .watchSingle();
  }

  /// 预算生效区间。直接复用共享的日期工具，避免各处重算周期边界。
  ({int start, int end}) rangeOf(Budget budget) => budgetRange(
        year: budget.year,
        periodIndex: budget.periodIndex,
        monthly: budget.period == BudgetPeriod.monthly,
        quarterly: budget.period == BudgetPeriod.quarterly,
      );

  Future<String> add({
    required String bookId,
    required BudgetScope scope,
    required BudgetPeriod period,
    required int amountMinor,
    required int year,
    required int periodIndex,
    String? categoryId,
    bool alertEnabled = true,
    int alertThreshold = 80,
  }) {
    _validate(
      scope: scope,
      amountMinor: amountMinor,
      categoryId: categoryId,
      alertThreshold: alertThreshold,
    );

    final String id = const Uuid().v7();
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;

    return _db.transaction<String>(() async {
      await _db.into(_db.budgets).insert(
            BudgetsCompanion(
              id: Value<String>(id),
              bookId: Value<String>(bookId),
              scope: Value<BudgetScope>(scope),
              period: Value<BudgetPeriod>(period),
              amountMinor: Value<int>(amountMinor),
              categoryId: Value<String?>(
                scope == BudgetScope.category ? categoryId : null,
              ),
              year: Value<int>(year),
              periodIndex: Value<int>(periodIndex),
              alertEnabled: Value<bool>(alertEnabled),
              alertThreshold: Value<int>(alertThreshold),
              updatedAt: Value<int>(now),
              dirty: const Value<bool>(true),
            ),
          );
      await enqueueSyncOp(
        _db,
        table: 'budgets',
        recordId: id,
        opType: SyncOpType.insert,
        updatedAt: now,
        payload: <String, Object?>{
          'scope': scope.index,
          'period': period.index,
          'amountMinor': amountMinor,
          'categoryId': scope == BudgetScope.category ? categoryId : null,
          'year': year,
          'periodIndex': periodIndex,
          'alertEnabled': alertEnabled,
          'alertThreshold': alertThreshold,
        },
      );
      return id;
    });
  }

  Future<void> update({
    required String id,
    required BudgetScope scope,
    required BudgetPeriod period,
    required int amountMinor,
    required int year,
    required int periodIndex,
    String? categoryId,
    bool alertEnabled = true,
    int alertThreshold = 80,
  }) {
    _validate(
      scope: scope,
      amountMinor: amountMinor,
      categoryId: categoryId,
      alertThreshold: alertThreshold,
    );

    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    return _db.transaction<void>(() async {
      await (_db.update(_db.budgets)..where((Budgets t) => t.id.equals(id)))
          .write(
        BudgetsCompanion(
          scope: Value<BudgetScope>(scope),
          period: Value<BudgetPeriod>(period),
          amountMinor: Value<int>(amountMinor),
          categoryId: Value<String?>(
            scope == BudgetScope.category ? categoryId : null,
          ),
          year: Value<int>(year),
          periodIndex: Value<int>(periodIndex),
          alertEnabled: Value<bool>(alertEnabled),
          alertThreshold: Value<int>(alertThreshold),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );
      await enqueueSyncOp(
        _db,
        table: 'budgets',
        recordId: id,
        opType: SyncOpType.update,
        updatedAt: now,
        payload: <String, Object?>{
          'scope': scope.index,
          'period': period.index,
          'amountMinor': amountMinor,
          'categoryId': scope == BudgetScope.category ? categoryId : null,
          'year': year,
          'periodIndex': periodIndex,
          'alertEnabled': alertEnabled,
          'alertThreshold': alertThreshold,
        },
      );
    });
  }

  Future<void> remove(String id) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.transaction<void>(() async {
      await (_db.update(_db.budgets)..where((Budgets t) => t.id.equals(id)))
          .write(
        const BudgetsCompanion(
          deleted: Value<bool>(true),
          dirty: Value<bool>(true),
        ),
      );
      await enqueueSyncOp(
        _db,
        table: 'budgets',
        recordId: id,
        opType: SyncOpType.delete,
        updatedAt: now,
      );
    });
  }

  void _validate({
    required BudgetScope scope,
    required int amountMinor,
    required String? categoryId,
    required int alertThreshold,
  }) {
    // 0 金额合法（第 31 批）：一级分类「自动汇总」占位行——添加一级
    // 分类时允许不填金额，展示按 Σ二级 合计（见 _BudgetGroupData
    // .effectiveMinor 的 0 回退）。负值仍拒绝；二级分类行由编辑器强制
    // 填正数（budget_editor 的 amountOptional 只对一级新增放行）。
    if (amountMinor < 0) throw const ValidationFailure('预算额度不能为负');
    if (scope == BudgetScope.category &&
        (categoryId == null || categoryId.isEmpty)) {
      throw const ValidationFailure('分类预算必须选择分类');
    }
    if (alertThreshold < 1 || alertThreshold > 200) {
      throw const ValidationFailure('提醒阈值需在 1 - 200 之间');
    }
  }
}
