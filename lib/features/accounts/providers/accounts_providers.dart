import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../investment/data/investment_repository.dart';
import '../../investment/providers/investment_providers.dart';
import '../data/account_repository.dart';

/// 账户仓储实例。供账户页、资产详情页等需要新增/编辑/删除账户的页面注入。
final Provider<AccountRepository> accountRepositoryProvider =
    Provider<AccountRepository>(
  (Ref ref) => AccountRepository(ref.watch(appDatabaseProvider)),
);

/// 按 ID 监听单个账户。资产详情页顶部卡片用它展示当前账户名称/类型/余额。
final AutoDisposeStreamProviderFamily<Account?, String> accountByIdProvider =
    StreamProvider.autoDispose.family<Account?, String>(
  (Ref ref, String id) => ref.watch(accountsDaoProvider).watchById(id),
);

/// 指定账户在某一年内的流水（含转账的转入侧、借还关联流水）。
///
/// 复用 [TransactionsDao.watchByAccountWithLendLinks] 监听该账户**全部**
/// 流水并**并入借还关联流水**（借还本金 / 还债 / 收债的资金侧挂在资金
/// 账户上，但其关联借还记录指定了本账户时，本账户详情也应可见——否则
/// 借还账户「有余额、无流水」）。然后在 Dart 层按本地年份过滤：切换
/// 年份时无需重新订阅数据库，流水变化时仍自动刷新。
final AutoDisposeStreamProviderFamily<List<Transaction>,
        ({String accountId, int year})> accountTransactionsByYearProvider =
    StreamProvider.autoDispose
        .family<List<Transaction>, ({String accountId, int year})>(
  (Ref ref, ({String accountId, int year}) params) {
    final String bookId = ref.watch(currentBookIdProvider);
    final DateTime startLocal = DateTime(params.year);
    final DateTime endLocal = DateTime(params.year + 1);
    final int startAt = startLocal.toUtc().millisecondsSinceEpoch;
    final int endAt = endLocal.toUtc().millisecondsSinceEpoch;

    return ref
        .watch(transactionsDaoProvider)
        .watchByAccountWithLendLinks(
          bookId: bookId,
          accountId: params.accountId,
        )
        .map(
          (List<Transaction> list) => list
              .where(
                (Transaction t) =>
                    t.occurredAt >= startAt && t.occurredAt < endAt,
              )
              .toList(growable: false),
        );
  },
);

/// 资产详情页「有账单日的负债账户」专用：取数范围比
/// [accountTransactionsByYearProvider] **早一个月**（上一年 12 月 1 日起）。
///
/// 原因：1 月账单的周期是「上一年 12 月账单日次日 ～ 1 月账单日」，
/// 只按自然年取会把 12 月的消费漏出 1 月账单；本年 12 月账单日之后的
/// 交易属于次年 1 月账单，由账单周期分组（[groupTransactionsByStatement]）
/// 自然滤掉，不会串到本年列表。
final AutoDisposeStreamProviderFamily<List<Transaction>,
        ({String accountId, int year})> accountTransactionsForStatementProvider =
    StreamProvider.autoDispose
        .family<List<Transaction>, ({String accountId, int year})>(
  (Ref ref, ({String accountId, int year}) params) {
    final String bookId = ref.watch(currentBookIdProvider);
    // 上一年 12 月 1 日 00:00（本地）～ 下一年 1 月 1 日（排他）。
    final int startAt =
        DateTime(params.year - 1, 12).toUtc().millisecondsSinceEpoch;
    final int endAt =
        DateTime(params.year + 1).toUtc().millisecondsSinceEpoch;

    return ref
        .watch(transactionsDaoProvider)
        .watchByAccountWithLendLinks(
          bookId: bookId,
          accountId: params.accountId,
        )
        .map(
          (List<Transaction> list) => list
              .where(
                (Transaction t) =>
                    t.occurredAt >= startAt && t.occurredAt < endAt,
              )
              .toList(growable: false),
        );
  },
);

final AutoDisposeStreamProvider<List<Account>> accountsProvider =
    StreamProvider.autoDispose<List<Account>>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref.watch(accountsDaoProvider).watchByBook(bookId);
});

/// 隐藏资产列表（账户设置 → 隐藏资产列表进入）：实时监听当前账本下
/// 状态为 [AccountStatus.hidden] 的账户，恢复（取消隐藏）后自动从列表消失。
final AutoDisposeStreamProvider<List<Account>> hiddenAccountsProvider =
    StreamProvider.autoDispose<List<Account>>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref
      .watch(accountsDaoProvider)
      .watchByStatus(bookId, AccountStatus.hidden);
});

/// 封存资产列表（账户设置 → 封存资产列表进入）：实时监听当前账本下
/// 状态为 [AccountStatus.sealed] 的账户，恢复（取消封存）后自动从列表消失。
final AutoDisposeStreamProvider<List<Account>> sealedAccountsProvider =
    StreamProvider.autoDispose<List<Account>>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref
      .watch(accountsDaoProvider)
      .watchByStatus(bookId, AccountStatus.sealed);
});
/// 指定账户的**全部**流水（不限年份，含转账转入侧，已去重、排除软删）。
///
/// 用途：账户详情页「账单迁移 / 账单清理 / 金额校验」需要跨年全量流水，
/// [accountTransactionsByYearProvider] 按年过滤不满足，故单独提供此 provider。
/// 取数口径与 [accountTransactionsByYearProvider] 一致（复用
/// [TransactionsDao.watchByAccount]），仅去掉年份裁剪。
final AutoDisposeStreamProviderFamily<List<Transaction>, String>
    accountAllTransactionsProvider =
    StreamProvider.autoDispose.family<List<Transaction>, String>(
  (Ref ref, String accountId) {
    final String bookId = ref.watch(currentBookIdProvider);
    return ref
        .watch(transactionsDaoProvider)
        .watchByAccount(bookId: bookId, accountId: accountId);
  },
);

/// 净资产 = 所有账户「展示余额」之和。
///
/// 展示余额：证券/投资类账户 = 现金余额 + 名下持仓市值；其余账户 = 现金余额。
/// 负债方向账户（信用卡/借入等）正余额即欠款，从净资产里扣。
/// 口径集中在 [displayBalanceWithMarket]，避免与账户列表/详情页分叉。
/// 合并「账户」与「持仓」两个流（均为 AsyncValue）实时重算，持仓变动即刷新。
final AutoDisposeProvider<AsyncValue<int>> netAssetsProvider =
    Provider.autoDispose<AsyncValue<int>>((Ref ref) {
  final AsyncValue<List<Account>> accountsAv = ref.watch(accountsProvider);
  final AsyncValue<List<InvestmentHolding>> holdingsAv =
      ref.watch(investmentListProvider);
  return accountsAv.when(
    data: (List<Account> list) => holdingsAv.when(
      data: (List<InvestmentHolding> holdings) {
        final Map<String, int> mv = _marketByAccount(holdings);
        int net = 0;
        for (final Account a in list) {
          final int display = displayBalanceWithMarket(a, mv);
          net += a.type.isLiabilitySide ? -display : display;
        }
        return AsyncData<int>(net);
      },
      loading: () => const AsyncLoading<int>(),
      error: (Object e, StackTrace st) => AsyncError<int>(e, st),
    ),
    loading: () => const AsyncLoading<int>(),
    error: (Object e, StackTrace st) => AsyncError<int>(e, st),
  );
});

final AutoDisposeProvider<AsyncValue<int>> totalAssetsProvider =
    Provider.autoDispose<AsyncValue<int>>((Ref ref) {
  final AsyncValue<List<Account>> accountsAv = ref.watch(accountsProvider);
  final AsyncValue<List<InvestmentHolding>> holdingsAv =
      ref.watch(investmentListProvider);
  return accountsAv.when(
    data: (List<Account> list) => holdingsAv.when(
      data: (List<InvestmentHolding> holdings) {
        final Map<String, int> mv = _marketByAccount(holdings);
        int total = 0;
        for (final Account a in list) {
          if (a.type.isLiabilitySide) continue;
          final int display = displayBalanceWithMarket(a, mv);
          if (display > 0) total += display;
        }
        return AsyncData<int>(total);
      },
      loading: () => const AsyncLoading<int>(),
      error: (Object e, StackTrace st) => AsyncError<int>(e, st),
    ),
    loading: () => const AsyncLoading<int>(),
    error: (Object e, StackTrace st) => AsyncError<int>(e, st),
  );
});

/// 总负债（所有负债方向账户的「展示余额」正部分之和，正数）。
final AutoDisposeProvider<AsyncValue<int>> totalLiabilitiesProvider =
    Provider.autoDispose<AsyncValue<int>>((Ref ref) {
  final AsyncValue<List<Account>> accountsAv = ref.watch(accountsProvider);
  final AsyncValue<List<InvestmentHolding>> holdingsAv =
      ref.watch(investmentListProvider);
  return accountsAv.when(
    data: (List<Account> list) => holdingsAv.when(
      data: (List<InvestmentHolding> holdings) {
        final Map<String, int> mv = _marketByAccount(holdings);
        int total = 0;
        for (final Account a in list) {
          if (!a.type.isLiabilitySide) continue;
          final int display = displayBalanceWithMarket(a, mv);
          if (display > 0) total += display;
        }
        return AsyncData<int>(total);
      },
      loading: () => const AsyncLoading<int>(),
      error: (Object e, StackTrace st) => AsyncError<int>(e, st),
    ),
    loading: () => const AsyncLoading<int>(),
    error: (Object e, StackTrace st) => AsyncError<int>(e, st),
  );
});

/// 按账户 ID 聚合持仓市值（分）；空账户 ID 或零市值忽略。
Map<String, int> _marketByAccount(List<InvestmentHolding> holdings) {
  final Map<String, int> mv = <String, int>{};
  for (final InvestmentHolding h in holdings) {
    final String? accId = h.accountId;
    if (accId == null) continue;
    mv[accId] = (mv[accId] ?? 0) + h.marketValueMinor;
  }
  return mv;
}

/// 分类 ID → 分类的映射，供流水平铺展示时避免 N 次查询。
final AutoDisposeStreamProvider<Map<String, Category>> categoryMapProvider =
    StreamProvider.autoDispose<Map<String, Category>>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref.watch(categoriesDaoProvider).watchAll(bookId).map(
        (List<Category> list) => <String, Category>{
          for (final Category c in list) c.id: c,
        },
      );
});

final AutoDisposeStreamProvider<List<Category>> expenseCategoriesProvider =
    StreamProvider.autoDispose<List<Category>>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref
      .watch(categoriesDaoProvider)
      .watchByType(bookId, CategoryType.expense);
});

final AutoDisposeStreamProvider<List<Category>> incomeCategoriesProvider =
    StreamProvider.autoDispose<List<Category>>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref
      .watch(categoriesDaoProvider)
      .watchByType(bookId, CategoryType.income);
});
