import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';

/// 分类仓储。
///
/// 约定与账户/流水一致：写入即在同一个 DB 事务内「落库 + 标记 dirty + 同步入队」，
/// 不发起任何网络请求。同步由 SyncEngine 异步接管。
class CategoryRepository {
  const CategoryRepository(this._db);

  final AppDatabase _db;

  /// 查找或创建指定名称的分类，返回分类 ID（系统落账用，如「报销收入」）。
  ///
  /// 同账本同类型下按名称精确匹配（含未删除的），命中即复用；
  /// 未命中则用 [add] 创建，保证多次落账只会有一枚系统类目。
  ///
  /// 实现为一次性 `get()` 查询而非流查询：调用方可能在 DB 事务内
  /// （借还落账等），事务内创建流查询不可靠。
  Future<String> ensureNamed({
    required String bookId,
    required String name,
    required CategoryType type,
    String? iconKey,
    int? colorValue,
  }) async {
    final String trimmed = name.trim();
    final List<Category> all = await (_db.select(_db.categories)
          ..where(
            ($CategoriesTable tbl) =>
                tbl.bookId.equals(bookId) & tbl.deleted.equals(false),
          ))
        .get();
    for (final Category c in all) {
      if (c.type == type && c.name == trimmed) {
        return c.id;
      }
    }
    return add(
      bookId: bookId,
      name: trimmed,
      type: type,
      iconKey: iconKey,
      colorValue: colorValue,
    );
  }

  /// 新增分类。返回新记录 ID。
  Future<String> add({
    required String bookId,
    required String name,
    required CategoryType type,
    String? parentId,
    int? colorValue,
    String? iconKey,
  }) {
    if (name.trim().isEmpty) {
      throw const ValidationFailure('分类名称不能为空');
    }

    final String id = const Uuid().v7();
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;

    return _db.transaction<String>(() async {
      await _db.categoriesDao.insertCategory(
        CategoriesCompanion(
          id: Value<String>(id),
          bookId: Value<String>(bookId),
          name: Value<String>(name.trim()),
          type: Value<CategoryType>(type),
          parentId: Value<String?>(parentId),
          colorValue: Value<int?>(colorValue),
          iconKey: Value<String?>(iconKey),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );

      await _enqueue(
        id,
        SyncOpType.insert,
        now,
        <String, Object?>{
          'bookId': bookId,
          'name': name.trim(),
          'type': type.index,
          'parentId': parentId,
          'colorValue': colorValue,
          'iconKey': iconKey,
        },
      );

      return id;
    });
  }

  /// 更新分类（名称 / 颜色 / 图标）。类型不可改，避免已有流水错义。
  Future<void> update({
    required String id,
    required String bookId,
    required String name,
    required CategoryType type,
    String? parentId,
    int? colorValue,
    String? iconKey,
  }) {
    if (name.trim().isEmpty) {
      throw const ValidationFailure('分类名称不能为空');
    }

    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;

    return _db.transaction<void>(() async {
      await _db.categoriesDao.updateCategory(
        CategoriesCompanion(
          id: Value<String>(id),
          bookId: Value<String>(bookId),
          name: Value<String>(name.trim()),
          type: Value<CategoryType>(type),
          parentId: parentId == null
              ? const Value.absent()
              : Value<String?>(parentId),
          colorValue: Value<int?>(colorValue),
          iconKey: Value<String?>(iconKey),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );

      await _enqueue(
        id,
        SyncOpType.update,
        now,
        <String, Object?>{
          'bookId': bookId,
          'name': name.trim(),
          'type': type.index,
          if (parentId != null) 'parentId': parentId,
          'colorValue': colorValue,
          'iconKey': iconKey,
        },
      );
    });
  }

  /// 软删除（保留记录随同步推送，避免对端再次拉回）。
  Future<void> remove(String id) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.transaction<void>(() async {
      await _db.categoriesDao.softDelete(id, now);
      await _enqueue(id, SyncOpType.delete, now, null);
    });
  }

  /// 封存分类。
  Future<void> archive(String id) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.transaction<void>(() async {
      await _db.categoriesDao.archive(id, now);
      await _enqueue(id, SyncOpType.update, now, <String, Object?>{
        'isArchived': true,
      });
    });
  }

  /// 解封分类。
  Future<void> unarchive(String id) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.transaction<void>(() async {
      await _db.categoriesDao.unarchive(id, now);
      await _enqueue(id, SyncOpType.update, now, <String, Object?>{
        'isArchived': false,
      });
    });
  }

  /// 批量重排一级分类顺序。传入按目标顺序排列的 ID 列表。
  Future<void> reorderParents(List<String> orderedIds) async {
    if (orderedIds.isEmpty) return;
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.transaction<void>(() async {
      for (int i = 0; i < orderedIds.length; i++) {
        await _db.categoriesDao.setSortOrder(orderedIds[i], i, now);
        await _enqueue(
          orderedIds[i],
          SyncOpType.update,
          now,
          <String, Object?>{'sortOrder': i},
        );
      }
    });
  }

  /// 将子分类提升为一级分类。
  ///
  /// 子分类原来的直接子分类会一并提升（parentId 改为其原父分类的 parentId，
  /// 也就是 null）。sortOrder 追加到一级分类末尾。
  Future<void> promoteToParent(String id) async {
    final Category? cat = await _db.categoriesDao.getById(id);
    if (cat == null) {
      throw const NotFoundFailure('分类不存在');
    }
    if (cat.parentId == null) {
      // 已经是一级分类，无需操作。
      return;
    }

    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final int maxSo =
        await _db.categoriesDao.maxRootSortOrder(cat.bookId, cat.type.index);

    await _db.transaction<void>(() async {
      await _db.categoriesDao.updateCategory(
        CategoriesCompanion(
          id: Value<String>(cat.id),
          bookId: Value<String>(cat.bookId),
          name: Value<String>(cat.name),
          type: Value<CategoryType>(cat.type),
          parentId: const Value<String?>(null),
          colorValue: Value<int?>(cat.colorValue),
          iconKey: Value<String?>(cat.iconKey),
          sortOrder: Value<int>(maxSo + 1),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );
      await _enqueue(cat.id, SyncOpType.update, now, <String, Object?>{
        'parentId': null,
        'sortOrder': maxSo + 1,
      });
    });
  }

  /// 重排某父分类下的直接子分类顺序。传入按目标顺序排列的子分类 ID 列表。
  Future<void> reorderChildren(String parentId, List<String> orderedIds) async {
    if (orderedIds.isEmpty) return;
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.transaction<void>(() async {
      for (int i = 0; i < orderedIds.length; i++) {
        await _db.categoriesDao.setSortOrder(orderedIds[i], i, now);
        await _enqueue(
          orderedIds[i],
          SyncOpType.update,
          now,
          <String, Object?>{'sortOrder': i},
        );
      }
    });
  }

  /// 将一级分类改为另一父分类的子分类。
  ///
  /// 该分类原有的直接子分类会一并改挂到新父分类下，从而保持「两级」结构不被破坏。
  Future<void> changeToSubcategory(String id, String newParentId) async {
    final Category? cat = await _db.categoriesDao.getById(id);
    if (cat == null) {
      throw const NotFoundFailure('分类不存在');
    }
    if (cat.parentId != null) {
      // 仅一级分类可改挂，子分类无需此操作。
      return;
    }

    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final List<String> childIds = await _db.categoriesDao.childIds(cat.id);
    final int maxSo = await _db.categoriesDao.maxChildSortOrder(newParentId);

    await _db.transaction<void>(() async {
      if (childIds.isNotEmpty) {
        await _db.categoriesDao.reparentChildren(cat.id, newParentId, now);
      }
      await _db.categoriesDao.updateCategory(
        CategoriesCompanion(
          id: Value<String>(cat.id),
          bookId: Value<String>(cat.bookId),
          name: Value<String>(cat.name),
          type: Value<CategoryType>(cat.type),
          parentId: Value<String?>(newParentId),
          colorValue: Value<int?>(cat.colorValue),
          iconKey: Value<String?>(cat.iconKey),
          sortOrder: Value<int>(maxSo + 1),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );
      await _enqueue(cat.id, SyncOpType.update, now, <String, Object?>{
        'parentId': newParentId,
        'sortOrder': maxSo + 1,
      });
      for (final String childId in childIds) {
        await _enqueue(childId, SyncOpType.update, now, <String, Object?>{
          'parentId': newParentId,
        });
      }
    });
  }

  Future<void> _enqueue(
    String recordId,
    SyncOpType opType,
    int updatedAt,
    Map<String, Object?>? payload,
  ) async {
    final int createdAt = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.pendingOpsDao.enqueue(
      PendingOpsCompanion(
        targetTable: const Value<String>('categories'),
        recordId: Value<String>(recordId),
        opType: Value<SyncOpType>(opType),
        payload: Value<String?>(payload == null ? null : jsonEncode(payload)),
        updatedAt: Value<int>(updatedAt),
        createdAt: Value<int>(createdAt),
      ),
    );
  }
}
