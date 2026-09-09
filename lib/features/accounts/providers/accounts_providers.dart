import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';

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
