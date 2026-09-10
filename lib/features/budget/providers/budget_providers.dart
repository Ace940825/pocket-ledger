import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../ledger/providers/ledger_providers.dart';
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
/// MVP 简化（避免在首页跑 N 个 family stream 合成）：
/// - 总预算 = 所有未删除预算的 amountMinor 之和
/// - 已用 = 本月总支出（不做 per-budget 的精确分摊）
/// - 剩余 = 总预算 − 已用；为负表示超支
///
/// TODO(精度)：未来用 budgetSpentProvider 逐条预算精确求和"已用"。
typedef BudgetSummary = ({int total, int spent, int remaining});

final Provider<BudgetSummary> currentMonthBudgetSummaryProvider =
    Provider<BudgetSummary>(
  (Ref ref) {
    final AsyncValue<List<Budget>> budgets = ref.watch(budgetListProvider);
    final List<Budget> list = budgets.valueOrNull ?? const <Budget>[];
    final int total = list.fold<int>(
      0,
      (int s, Budget b) => s + b.amountMinor,
    );
    final int spent = ref.watch(monthExpenseProvider).valueOrNull ?? 0;
    return (total: total, spent: spent, remaining: total - spent);
  },
);
