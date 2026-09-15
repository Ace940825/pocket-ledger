import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../features/ledger/providers/ledger_providers.dart';
import '../../../providers/app_providers.dart';
import '../data/lend_repository.dart';

final Provider<LendRepository> lendRepositoryProvider =
    Provider<LendRepository>(
  (Ref ref) => LendRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(transactionRepositoryProvider),
  ),
);

final AutoDisposeStreamProvider<List<LendRecord>> lendListProvider =
    StreamProvider.autoDispose<List<LendRecord>>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref.watch(lendRepositoryProvider).watch(bookId);
});

/// 借出（应收）进行中合计：别人欠我的、还没收回来的金额。
final AutoDisposeStreamProvider<int> lendOutOngoingProvider =
    StreamProvider.autoDispose<int>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref.watch(lendRepositoryProvider).watch(bookId).map(
        (List<LendRecord> records) => records
            .where((LendRecord r) =>
                r.direction == LendDirection.lendOut &&
                r.status == LendStatus.ongoing)
            .fold<int>(0, (int sum, LendRecord r) => sum + r.amountMinor),
      );
});

/// 借入（应付）进行中合计：我欠别人的、还没还上的金额。
final AutoDisposeStreamProvider<int> borrowInOngoingProvider =
    StreamProvider.autoDispose<int>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref.watch(lendRepositoryProvider).watch(bookId).map(
        (List<LendRecord> records) => records
            .where((LendRecord r) =>
                r.direction == LendDirection.borrowIn &&
                r.status == LendStatus.ongoing)
            .fold<int>(0, (int sum, LendRecord r) => sum + r.amountMinor),
      );
});
