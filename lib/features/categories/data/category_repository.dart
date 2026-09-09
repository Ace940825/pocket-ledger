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

  /// 新增分类。返回新记录 ID。
  Future<String> add({
    required String bookId,
    required String name,
    required CategoryType type,
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
