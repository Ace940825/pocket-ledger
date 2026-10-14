import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../providers/app_providers.dart';
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
    bookBudgetsProvider = StreamProvider.autoDispose.family<List<Budget>, String>(
  (Ref ref, String bookId) =>
      ref.watch(budgetRepositoryProvider).watch(bookId),
);

/// 单条预算的已用金额查询键。
///
/// 用 Dart 3 record 而不是自定义类：record 自带结构化相等语义，
/// 相同区间的多个预算行会自动命中同一个 family 实例，不会重复建监听。
typedef BudgetSpentKey = ({int start, int end, String? categoryId});

final AutoDisposeStreamProviderFamily<int, BudgetSpentKey> budgetSpentProvider =
    StreamProvider.autoDispose.family<int, BudgetSpentKey>(
  (Ref ref, BudgetSpentKey key) =>
      ref.watch(budgetRepositoryProvider).watchSpent(
            bookId: ref.watch(currentBookIdProvider),
            startAt: key.start,
            endAt: key.end,
            categoryId: key.categoryId,
          ),
);

/// 首页「本月预算」卡片的汇总数据。
///
/// - 总预算 = 所有未删除预算的 amountMinor 之和
/// - 已用 = 逐条预算精确求和：每条预算按其自身生效区间与（分类预算时的）分类，
///   复用 budgetSpentProvider 实时聚合，与预算页单条进度口径完全一致
/// - 剩余 = 总预算 − 已用；为负表示超支
///
/// 注：预算间区间可能重叠，重叠部分会按「独立预算」语义分别计入，
/// 与预算页各 tile 进度求和的结果一致。
typedef BudgetSummary = ({int total, int spent, int remaining});

final Provider<BudgetSummary> currentMonthBudgetSummaryProvider =
    Provider<BudgetSummary>(
  (Ref ref) {
    final AsyncValue<List<Budget>> budgets = ref.watch(budgetListProvider);
    final List<Budget> list = budgets.valueOrNull ?? const <Budget>[];
    final BudgetRepository repo = ref.watch(budgetRepositoryProvider);
    final int total = list.fold<int>(
      0,
      (int s, Budget b) => s + b.amountMinor,
    );
    final int spent = list.fold<int>(0, (int s, Budget b) {
      final ({int start, int end}) range = repo.rangeOf(b);
      final AsyncValue<int> v = ref.watch(
        budgetSpentProvider(
          (
            start: range.start,
            end: range.end,
            categoryId: b.categoryId,
          ),
        ),
      );
      return s + (v.valueOrNull ?? 0);
    });
    return (total: total, spent: spent, remaining: total - spent);
  },
);
