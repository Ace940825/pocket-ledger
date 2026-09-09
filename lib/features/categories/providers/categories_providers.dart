import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../data/category_repository.dart';

/// 分类仓储。
final Provider<CategoryRepository> categoryRepositoryProvider =
    Provider<CategoryRepository>(
  (Ref ref) => CategoryRepository(ref.watch(appDatabaseProvider)),
);

/// 全部（未删除）分类，按当前账本实时监听。分类管理页与筛选器复用。
final AutoDisposeStreamProvider<List<Category>> allCategoriesProvider =
    StreamProvider.autoDispose<List<Category>>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref.watch(categoriesDaoProvider).watchAll(bookId);
});
