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

/// 借出（应收）进行中合计：别人欠我的、还没收回来的金额
/// （本金 − 优惠 − 已还；优惠在借出时已减免部分应收）。
final AutoDisposeStreamProvider<int> lendOutOngoingProvider =
    StreamProvider.autoDispose<int>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref.watch(lendRepositoryProvider).watch(bookId).map(
        (List<LendRecord> records) => records
            .where((LendRecord r) =>
                r.direction == LendDirection.lendOut &&
                r.status == LendStatus.ongoing)
            .fold<int>(
              0,
              (int sum, LendRecord r) =>
                  sum + r.amountMinor - r.discountMinor - r.repaidMinor,
            ),
      );
});

/// 借入（应付）进行中合计：我欠别人的、还没还上的金额
/// （本金 − 优惠 − 已还；优惠在借入时已减免部分应付）。
final AutoDisposeStreamProvider<int> borrowInOngoingProvider =
    StreamProvider.autoDispose<int>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref.watch(lendRepositoryProvider).watch(bookId).map(
        (List<LendRecord> records) => records
            .where((LendRecord r) =>
                r.direction == LendDirection.borrowIn &&
                r.status == LendStatus.ongoing)
            .fold<int>(
              0,
              (int sum, LendRecord r) =>
                  sum + r.amountMinor - r.discountMinor - r.repaidMinor,
            ),
      );
});

/// 指定方向下，可选的「应收 / 应付」真实账户。
/// 借入/借出页选择对方账户时，只展示对应分类的账户，不显示资金、投资、负债等账户。
/// - [LendDirection.lendOut]：应收类账户（别人欠我）。
/// - [LendDirection.borrowIn]：应付类账户（我欠别人）。
final AutoDisposeStreamProviderFamily<List<Account>, LendDirection>
    lendAccountsProvider = StreamProvider.autoDispose
        .family<List<Account>, LendDirection>(
            (Ref ref, LendDirection direction) {
  final String bookId = ref.watch(currentBookIdProvider);
  final AccountCategory target = direction == LendDirection.lendOut
      ? AccountCategory.receivable
      : AccountCategory.payable;
  return ref.watch(accountsDaoProvider).watchByBook(bookId).map(
        (List<Account> list) => list
            .where((Account a) => !a.deleted && a.type.category == target)
            .toList(growable: false),
      );
});

/// 指定方向下，按对方账户聚合的未结清金额。
/// - [LendDirection.lendOut]：各应收账户余额。
/// - [LendDirection.borrowIn]：各应付账户余额。
/// Key 为对方账户名，Value 为剩余未结清金额（分），按金额降序排列。
final AutoDisposeStreamProviderFamily<Map<String, int>, LendDirection>
    lendCounterpartyBalancesProvider = StreamProvider.autoDispose
        .family<Map<String, int>, LendDirection>(
            (Ref ref, LendDirection direction) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref.watch(lendRepositoryProvider).watch(bookId).map(
    (List<LendRecord> records) {
      final Map<String, int> result = <String, int>{};
      for (final LendRecord r in records) {
        if (r.direction != direction || r.status != LendStatus.ongoing) {
          continue;
        }
        final String trimmed = r.counterparty.trim();
        if (trimmed.isEmpty) continue;
        result[trimmed] = (result[trimmed] ?? 0) +
            r.amountMinor -
            r.discountMinor -
            r.repaidMinor;
      }
      return Map<String, int>.fromEntries(
        result.entries.toList()
          ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
              b.value.compareTo(a.value)),
      );
    },
  );
});
