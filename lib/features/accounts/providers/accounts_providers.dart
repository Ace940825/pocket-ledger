import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
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

/// 指定账户在某一年内的流水（含转账的转入侧）。
///
/// 复用 [TransactionsDao.watchByAccount] 监听该账户**全部**流水，
/// 然后在 Dart 层按本地年份过滤。这样切换年份时无需重新订阅数据库，
/// 同时仍能在流水变化时自动刷新。
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
        .watchByAccount(bookId: bookId, accountId: params.accountId)
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

/// 净资产 = 所有账户余额之和（信用卡余额为负，自动体现负债）
final AutoDisposeStreamProvider<int> netAssetsProvider =
    StreamProvider.autoDispose<int>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref.watch(accountsDaoProvider).watchNetAssets(bookId);
});

final AutoDisposeStreamProvider<int> totalAssetsProvider =
    StreamProvider.autoDispose<int>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref.watch(accountsDaoProvider).watchTotalAssets(bookId);
});

/// 总负债（所有信用卡账户欠款之和，正数）。
final AutoDisposeStreamProvider<int> totalLiabilitiesProvider =
    StreamProvider.autoDispose<int>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref.watch(accountsDaoProvider).watchTotalLiabilities(bookId);
});

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
