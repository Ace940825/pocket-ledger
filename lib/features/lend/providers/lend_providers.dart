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

/// 借出（应收）进行中合计：**未指定借出账户**的未结清金额
/// （本金 − 优惠 − 已还；优惠在借出时已减免部分应收）。
/// 指定了借出账户的记录已含在该账户余额里（账户页同组展示），
/// 这里不再重复统计，避免组内双计（报销「待收回报销」同款口径）。
final AutoDisposeStreamProvider<int> lendOutOngoingProvider =
    StreamProvider.autoDispose<int>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref.watch(lendRepositoryProvider).watch(bookId).map(
        (List<LendRecord> records) => records
            .where((LendRecord r) =>
                r.direction == LendDirection.lendOut &&
                r.status == LendStatus.ongoing &&
                (r.accountId == null || r.accountId!.isEmpty))
            .fold<int>(
              0,
              (int sum, LendRecord r) =>
                  sum + r.amountMinor - r.discountMinor - r.repaidMinor,
            ),
      );
});

/// 借入（应付）进行中合计：**未指定借入账户**的未结清金额
/// （本金 − 优惠 − 已还；优惠在借入时已减免部分应付）。
/// 指定了借入账户的记录已含在该账户余额里，不再重复统计。
final AutoDisposeStreamProvider<int> borrowInOngoingProvider =
    StreamProvider.autoDispose<int>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref.watch(lendRepositoryProvider).watch(bookId).map(
        (List<LendRecord> records) => records
            .where((LendRecord r) =>
                r.direction == LendDirection.borrowIn &&
                r.status == LendStatus.ongoing &&
                (r.accountId == null || r.accountId!.isEmpty))
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

/// 指定方向下，**未指定借入/借出账户**的记录按对方账户聚合的未结清金额
/// （指定了账户的记录已在账户余额里，账户页不再重复展示，避免双计）。
/// - [LendDirection.lendOut]：未指定账户的各应收余额。
/// - [LendDirection.borrowIn]：未指定账户的各应付余额。
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
        // 未指定借入/借出账户的记录才进汇总（指定账户的已在账户余额里）。
        if (r.accountId != null && r.accountId!.isNotEmpty) {
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
