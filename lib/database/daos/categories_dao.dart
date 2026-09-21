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
          ..where(
            ($CategoriesTable tbl) =>
                tbl.bookId.equals(bookId) &
                tbl.type.equals(type.index) &
                tbl.isArchived.equals(false),
          )
          ..orderBy([
            ($CategoriesTable tbl) => OrderingTerm.asc(tbl.sortOrder),
          ]))
        .watch();
  }

  Stream<List<Category>> watchAll(String bookId) {
    return (select(categories)
          ..where(
            ($CategoriesTable tbl) =>
                tbl.bookId.equals(bookId) & tbl.deleted.equals(false),
          )
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

  /// 封存分类。仅置 isArchived = true，保留数据与流水关联，可恢复。
  Future<int> archive(String id, int updatedAt) {
    return (update(categories)
          ..where(($CategoriesTable tbl) => tbl.id.equals(id)))
        .write(
      CategoriesCompanion(
        isArchived: const Value<bool>(true),
        dirty: const Value<bool>(true),
        updatedAt: Value<int>(updatedAt),
      ),
    );
  }

  /// 解封分类（撤销 [archive]）。
  Future<int> unarchive(String id, int updatedAt) {
    return (update(categories)
          ..where(($CategoriesTable tbl) => tbl.id.equals(id)))
        .write(
      CategoriesCompanion(
        isArchived: const Value<bool>(false),
        dirty: const Value<bool>(true),
        updatedAt: Value<int>(updatedAt),
      ),
    );
  }

  /// 更新单个分类的排序值（分类排序用）。
  Future<int> setSortOrder(String id, int sortOrder, int updatedAt) {
    return (update(categories)
          ..where(($CategoriesTable tbl) => tbl.id.equals(id)))
        .write(
      CategoriesCompanion(
        sortOrder: Value<int>(sortOrder),
        dirty: const Value<bool>(true),
        updatedAt: Value<int>(updatedAt),
      ),
    );
  }

  /// 将某父分类下的直接子分类整体改挂到另一个父分类（保持两级结构）。
  Future<int> reparentChildren(
    String oldParentId,
    String newParentId,
    int updatedAt,
  ) {
    return (update(categories)
          ..where(($CategoriesTable tbl) => tbl.parentId.equals(oldParentId)))
        .write(
      CategoriesCompanion(
        parentId: Value<String?>(newParentId),
        dirty: const Value<bool>(true),
        updatedAt: Value<int>(updatedAt),
      ),
    );
  }

  /// 取某父分类下子分类的最大 sortOrder，用于追加排序。
  Future<int> maxChildSortOrder(String parentId) {
    final Expression<int> maxExpr = categories.sortOrder.max();
    return (selectOnly(categories)..where(categories.parentId.equals(parentId)))
        .map((TypedResult row) => row.read(maxExpr))
        .getSingle()
        .then((int? v) => v ?? 0);
  }

  /// 取某类型下一级分类的最大 sortOrder，用于子分类升主时追加排序。
  Future<int> maxRootSortOrder(String bookId, int type) {
    final Expression<int> maxExpr = categories.sortOrder.max();
    return (selectOnly(categories)
          ..addColumns(<Expression<Object>>[maxExpr])
          ..where(
            categories.bookId.equals(bookId) &
                categories.type.equals(type) &
                categories.parentId.isNull() &
                categories.deleted.equals(false),
          ))
        .map((TypedResult row) => row.read(maxExpr))
        .getSingle()
        .then((int? v) => v ?? 0);
  }

  /// 列出某父分类的直接子分类 ID（改挂时同步同步队列用）。
  Future<List<String>> childIds(String parentId) {
    return (selectOnly(categories)
          ..addColumns(<Expression<Object>>[categories.id])
          ..where(categories.parentId.equals(parentId)))
        .map((TypedResult row) => row.read(categories.id)!)
        .get();
  }

  /// 批量写入默认分类，仅在首次初始化时调用。
  Future<void> seedDefaults(String bookId, List<CategoriesCompanion> items) {
    return batch((Batch batch) {
      batch.insertAll(categories, items);
    });
  }
}
