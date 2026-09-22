import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import '../app_database.dart';

part 'tags_dao.g.dart';

/// 分组 + 其下标签的联合视图，供选择器与管理页直接消费。
class TagGroupRow {
  const TagGroupRow(this.category, this.tags);

  final TagCategory category;
  final List<Tag> tags;
}

/// 标签数据访问。
///
/// 标签库为纯本地数据（不进同步白名单），读写只走本地库。
@DriftAccessor(tables: <Type>[TagCategories, Tags])
class TagsDao extends DatabaseAccessor<AppDatabase> with _$TagsDaoMixin {
  TagsDao(super.attachedDatabase);

  /// 实时监听某作用域下的「分组 → 标签」结构。
  ///
  /// 用 [leftOuterJoin] 一次性把分组与标签拉出来：没有标签的分组也会返回
  /// （[Tag.tags] 为空列表），保证「空分组也要显示」的交互成立。
  /// 标签按 [Tag.sortOrder] 升序，分组按 [TagCategory.sortOrder] 升序。
  Stream<List<TagGroupRow>> watchGroups(TagScope scope, String bookId) {
    // join() 在 drift 2.31 返回 JoinedSelectStatement<HasResultSet, dynamic>，
    // where/orderBy 直接收表达式（不接收 tbl 回调），用 var 接推断类型。
    final query = select(tagCategories).join([
      leftOuterJoin(
        tags,
        tags.categoryId.equalsExp(tagCategories.id) &
            tags.deleted.equals(false),
      ),
    ])
      ..where(
        tagCategories.scope.equals(scope.index) &
            tagCategories.bookId.equals(bookId) &
            tagCategories.deleted.equals(false),
      )
      ..orderBy([OrderingTerm.asc(tagCategories.sortOrder)]);

    return query.watch().map((List<TypedResult> rows) {
      final List<TagCategory> cats = <TagCategory>[];
      final Map<String, List<Tag>> tagMap = <String, List<Tag>>{};
      for (final TypedResult row in rows) {
        final TagCategory cat = row.readTable(tagCategories);
        if (!cats.any((TagCategory c) => c.id == cat.id)) cats.add(cat);
        tagMap.putIfAbsent(cat.id, () => <Tag>[]);
        final Tag? tag = row.readTableOrNull(tags);
        if (tag != null) tagMap[cat.id]!.add(tag);
      }
      cats.sort((TagCategory a, TagCategory b) => a.sortOrder.compareTo(b.sortOrder));
      return cats.map((TagCategory c) {
        final List<Tag> ts = tagMap[c.id]!
          ..sort((Tag a, Tag b) => a.sortOrder.compareTo(b.sortOrder));
        return TagGroupRow(c, ts);
      }).toList();
    });
  }

  /// 实时监听某作用域下全部标签（扁平，含分组信息），用于搜索与选择态回显。
  Stream<List<Tag>> watchTags(TagScope scope, String bookId) {
    return (select(tags)
          ..where(
            ($TagsTable tbl) =>
                tbl.scope.equals(scope.index) &
                tbl.bookId.equals(bookId) &
                tbl.deleted.equals(false),
          )
          ..orderBy([($TagsTable tbl) => OrderingTerm.asc(tbl.sortOrder)]))
        .watch();
  }

  Future<TagCategory?> getCategoryById(String id) {
    return (select(tagCategories)
          ..where(($TagCategoriesTable tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  Future<Tag?> getTagById(String id) {
    return (select(tags)..where(($TagsTable tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  // ───────────────────────── 分组（类别） ─────────────────────────

  Future<void> insertCategory(TagCategoriesCompanion companion) {
    return into(tagCategories).insert(companion);
  }

  Future<bool> updateCategory(TagCategoriesCompanion companion) {
    return update(tagCategories).replace(companion);
  }

  /// 软删除分组（连同其下标签一并软删）。
  Future<void> deleteCategory(String id, int updatedAt) {
    return batch((Batch batch) {
      batch.update(
        tagCategories,
        const TagCategoriesCompanion(
          deleted: Value<bool>(true),
          dirty: Value<bool>(true),
        ),
        where: (TagCategories tbl) => tbl.id.equals(id),
      );
      batch.update(
        tags,
        const TagsCompanion(
          deleted: Value<bool>(true),
          dirty: Value<bool>(true),
        ),
        where: (Tags tbl) => tbl.categoryId.equals(id),
      );
    });
  }

  /// 重命名分组（仅改 name / updatedAt / dirty）。
  Future<int> renameCategory(String id, String name, int updatedAt) {
    return (update(tagCategories)
          ..where(($TagCategoriesTable tbl) => tbl.id.equals(id)))
        .write(
      TagCategoriesCompanion(
        name: Value<String>(name),
        updatedAt: Value<int>(updatedAt),
        dirty: const Value<bool>(true),
      ),
    );
  }

  /// 批量写入分组排序（拖拽排序后整体回写）。
  Future<void> reorderCategories(List<String> orderedIds, int updatedAt) {
    return batch((Batch batch) {
      for (int i = 0; i < orderedIds.length; i++) {
        batch.update(
          tagCategories,
          TagCategoriesCompanion(
            sortOrder: Value<int>(i),
            dirty: const Value<bool>(true),
            updatedAt: Value<int>(updatedAt),
          ),
          where: (TagCategories tbl) => tbl.id.equals(orderedIds[i]),
        );
      }
    });
  }

  Future<int> maxCategorySortOrder(TagScope scope, String bookId) {
    final Expression<int> maxExpr = tagCategories.sortOrder.max();
    return (selectOnly(tagCategories)
          ..addColumns(<Expression<Object>>[maxExpr])
          ..where(tagCategories.scope.equals(scope.index) &
              tagCategories.bookId.equals(bookId) &
              tagCategories.deleted.equals(false)))
        .map((TypedResult row) => row.read(maxExpr))
        .getSingle()
        .then((int? v) => v ?? 0);
  }

  // ───────────────────────── 标签 ─────────────────────────

  Future<void> insertTag(TagsCompanion companion) {
    return into(tags).insert(companion);
  }

  Future<bool> updateTag(TagsCompanion companion) {
    return update(tags).replace(companion);
  }

  /// 软删除单个标签。
  Future<int> softDeleteTag(String id, int updatedAt) {
    return (update(tags)..where(($TagsTable tbl) => tbl.id.equals(id))).write(
      const TagsCompanion(
        deleted: Value<bool>(true),
        dirty: Value<bool>(true),
      ),
    );
  }

  /// 重命名标签（仅改 name / updatedAt / dirty）。
  Future<int> renameTag(String id, String name, int updatedAt) {
    return (update(tags)..where(($TagsTable tbl) => tbl.id.equals(id))).write(
      TagsCompanion(
        name: Value<String>(name),
        updatedAt: Value<int>(updatedAt),
        dirty: const Value<bool>(true),
      ),
    );
  }

  /// 批量写入某分组下标签排序（拖拽排序后整体回写）。
  Future<void> reorderTags(String categoryId, List<String> orderedIds, int updatedAt) {
    return batch((Batch batch) {
      for (int i = 0; i < orderedIds.length; i++) {
        batch.update(
          tags,
          TagsCompanion(
            sortOrder: Value<int>(i),
            dirty: const Value<bool>(true),
            updatedAt: Value<int>(updatedAt),
          ),
          where: (Tags tbl) => tbl.id.equals(orderedIds[i]),
        );
      }
    });
  }

  Future<int> maxTagSortOrder(String categoryId) {
    final Expression<int> maxExpr = tags.sortOrder.max();
    return (selectOnly(tags)
          ..addColumns(<Expression<Object>>[maxExpr])
          ..where(tags.categoryId.equals(categoryId) &
              tags.deleted.equals(false)))
        .map((TypedResult row) => row.read(maxExpr))
        .getSingle()
        .then((int? v) => v ?? 0);
  }

  /// 该分组下是否已存在同名标签（去重，忽略大小写差异由调用方在 UI 提示）。
  Future<Tag?> findTagByName(String categoryId, String name) {
    return (select(tags)
          ..where(($TagsTable tbl) =>
              tbl.categoryId.equals(categoryId) &
              tbl.name.equals(name) &
              tbl.deleted.equals(false)))
        .getSingleOrNull();
  }
}
