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
