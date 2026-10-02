import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../data/savings_repository.dart';

final Provider<SavingsRepository> savingsRepositoryProvider =
    Provider<SavingsRepository>(
  (Ref ref) => SavingsRepository(ref.watch(appDatabaseProvider)),
);

final StreamProvider<List<SavingsGoal>> savingsListProvider =
    StreamProvider<List<SavingsGoal>>(
  (Ref ref) => ref
      .watch(savingsRepositoryProvider)
      .watch(ref.watch(currentBookIdProvider)),
);

/// 「归档」Tab：已归档（停止）的储蓄计划。
final StreamProvider<List<SavingsGoal>> savingsArchivedProvider =
    StreamProvider<List<SavingsGoal>>(
  (Ref ref) => ref
      .watch(savingsRepositoryProvider)
      .watchArchived(ref.watch(currentBookIdProvider)),
);

/// 某计划的逐期存入台账（详情页期卡「已存入 / 未存入」标记）。
final StreamProviderFamily<List<SavingsDeposit>, String>
    savingsDepositsProvider = StreamProvider.family<List<SavingsDeposit>,
        String>(
  (Ref ref, String goalId) =>
      ref.watch(savingsRepositoryProvider).watchDeposits(goalId),
);
