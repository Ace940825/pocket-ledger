import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import '../app_database.dart';

part 'categories_dao.g.dart';

/// 分类数据访问
@DriftAccessor(tables: <Type>[Categories])
class CategoriesDao extends DatabaseAccessor<AppDatabase>
    with _$CategoriesDaoMixin {
  CategoriesDao(super.attachedDatabase);

  /// 实时监听指定类型的分类
  Stream<List<Category>> watchByType(String bookId, CategoryType type) {
    return (select(categories)
          ..where(($CategoriesTable tbl) =>
              tbl.bookId.equals(bookId) &
              tbl.type.equals(type.index) &
              tbl.isArchived.equals(false),)
          ..orderBy([
            ($CategoriesTable tbl) => OrderingTerm.asc(tbl.sortOrder),
          ]))
        .watch();
  }

  Stream<List<Category>> watchAll(String bookId) {
    return (select(categories)
          ..where(($CategoriesTable tbl) =>
              tbl.bookId.equals(bookId) & tbl.deleted.equals(false),)
          ..orderBy([
            ($CategoriesTable tbl) => OrderingTerm.asc(tbl.sortOrder),
          ]))
        .watch();
  }

  Future<Category?> getById(String id) {
    return (select(categories)
          ..where(($CategoriesTable tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> insertCategory(CategoriesCompanion companion) {
    return into(categories).insert(companion);
  }

  Future<bool> updateCategory(CategoriesCompanion companion) {
    return update(categories).replace(companion);
  }

  Future<int> softDelete(String id, int updatedAt) {
    return (update(categories)
          ..where(($CategoriesTable tbl) => tbl.id.equals(id)))
        .write(
      CategoriesCompanion(
        deleted: const Value<bool>(true),
        isArchived: const Value<bool>(true),
        dirty: const Value<bool>(true),
        updatedAt: Value<int>(updatedAt),
      ),
    );
  }

  /// 批量写入默认分类，仅在首次初始化时调用。
  Future<void> seedDefaults(String bookId, List<CategoriesCompanion> items) {
    return batch((Batch batch) {
      batch.insertAll(categories, items);
    });
  }
}
