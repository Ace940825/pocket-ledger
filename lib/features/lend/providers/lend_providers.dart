import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../data/lend_repository.dart';

final Provider<LendRepository> lendRepositoryProvider = Provider<LendRepository>(
  (Ref ref) => LendRepository(ref.watch(appDatabaseProvider)),
);

final AutoDisposeStreamProvider<List<LendRecord>> lendListProvider =
    StreamProvider.autoDispose<List<LendRecord>>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref.watch(lendRepositoryProvider).watch(bookId);
});
