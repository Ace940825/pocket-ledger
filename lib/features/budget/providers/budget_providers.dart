import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../categories/providers/categories_providers.dart';
import '../data/budget_repository.dart';

final Provider<BudgetRepository> budgetRepositoryProvider =
    Provider<BudgetRepository>(
  (Ref ref) => BudgetRepository(ref.watch(appDatabaseProvider)),
);

final StreamProvider<List<Budget>> budgetListProvider =
    StreamProvider<List<Budget>>(
  (Ref ref) => ref
      .watch(budgetRepositoryProvider)
      .watch(ref.watch(currentBookIdProvider)),
);

/// 按账本取预算行（预算表带 bookId）。
/// 预算主页的跨账本网格与预算分类页（任意账本）共用。
final AutoDisposeStreamProviderFamily<List<Budget>, String>
    bookBudgetsProvider =
    StreamProvider.autoDispose.family<List<Budget>, String>(
  (Ref ref, String bookId) => ref.watch(budgetRepositoryProvider).watch(bookId),
);

/// 单条预算的已用金额查询键。
///
/// 用 Dart 3 record 而不是自定义类：record 自带结构化相等语义，
/// 相同区间的多个预算行会自动命中同一个 family 实例，不会重复建监听。
/// [type] 第 32 批加入：支出预算查支出流水（已用），收入目标查收入流水（已得）。
typedef BudgetSpentKey = ({
  int start,
  int end,
  String? categoryId,
  TxnType type,
});

final AutoDisposeStreamProviderFamily<int, BudgetSpentKey> budgetSpentProvider =
    StreamProvider.autoDispose.family<int, BudgetSpentKey>(
  (Ref ref, BudgetSpentKey key) =>
      ref.watch(budgetRepositoryProvider).watchSpent(
            bookId: ref.watch(currentBookIdProvider),
            startAt: key.start,
            endAt: key.end,
            categoryId: key.categoryId,
            type: key.type,
          ),
);

/// 首页预算模块卡片的汇总数据（第 32 批重写口径）。
///
/// - 总预算 = 匹配方向与周期的预算行 amountMinor 之和
/// - 已用 = 逐条预算精确求和：每条预算按其自身生效区间与（分类预算时的）分类，
///   复用 budgetSpentProvider 实时聚合，与预算页单条进度口径完全一致
/// - 剩余 = 总预算 − 已用；支出为负表示超支，收入为负表示超额达成
///
/// **周期口径（第 32 批修「月年累计」bug）**：只取**当月月度预算**
/// （period=monthly 且 year/periodIndex=当前年月），与预算主页「N月预算」
/// 月视图严格同口径。旧口径 Σ 全部预算行不分月/年——用户 10 月支出预算
/// 10,000 + 2026 年收入目标 1,000 会在首页累计成 11,000（图证）。
/// 年/季度预算不属于月度卡，在预算页年视图查看；首页天然是「当月实况」，
/// 不跟随预算页的周期浏览状态（跨页耦合）。
///
/// **方向口径**：预算表无方向字段，按分类归属判定——
/// - expense：overall 行 + 支出分类行（与预算页「支出预算」同口径）
/// - income：收入分类行（与预算页「收入目标」同口径）
typedef BudgetSummary = ({int total, int spent, int remaining});

/// 首页预算模块卡片汇总，按收支方向分（第 32 批）。
///
/// 替代旧汇总 provider（Σ 全部行、无方向）——旧口径月年累计、收支混计，
/// 见 [BudgetSummary] 文档。
final ProviderFamily<BudgetSummary, CategoryType> monthBudgetSummaryProvider =
    Provider.family<BudgetSummary, CategoryType>((
  Ref ref,
  CategoryType direction,
) {
  final AsyncValue<List<Budget>> budgets = ref.watch(budgetListProvider);
  final List<Budget> all = budgets.valueOrNull ?? const <Budget>[];
  // 方向分类需要分类表（预算表无方向字段，按 categoryId 归属分类类型判定）。
  final List<Category> categories =
      ref.watch(allCategoriesProvider).valueOrNull ?? const <Category>[];
  final Map<String, Category> catById = <String, Category>{
    for (final Category c in categories) c.id: c,
  };
  final BudgetRepository repo = ref.watch(budgetRepositoryProvider);
  final DateTime now = DateTime.now();
  final List<Budget> list = all
      .where(
        (Budget b) =>
            b.period == BudgetPeriod.monthly &&
            b.year == now.year &&
            b.periodIndex == now.month,
      )
      .toList(growable: false);

  int total = 0;
  int spent = 0;
  for (final Budget b in list) {
    final CategoryType? catType = b.scope == BudgetScope.category
        ? catById[b.categoryId]?.type
        : CategoryType.expense; // overall 行按支出口径（收入目标无总闸行）
    if (catType != direction) continue;
    total += b.amountMinor;
    final ({int start, int end}) range = repo.rangeOf(b);
    final AsyncValue<int> v = ref.watch(
      budgetSpentProvider(
        (
          start: range.start,
          end: range.end,
          categoryId: b.categoryId,
          type: direction == CategoryType.income
              ? TxnType.income
              : TxnType.expense,
        ),
      ),
    );
    spent += v.valueOrNull ?? 0;
  }
  return (total: total, spent: spent, remaining: total - spent);
});
