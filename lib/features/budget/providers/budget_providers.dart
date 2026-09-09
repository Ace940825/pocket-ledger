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
