import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/enums.dart';
import 'app_database.dart';

/// 共享的「同步入队」helper。
///
/// Phase 4 各模块的仓储直接基于 `AppDatabase` 的表访问器读写，
/// 不额外注册自定义 DAO，因此把"把变更写入 pending_ops 队列"抽成统一函数，
/// 保证所有模块的同步语义与账户/分类/流水一致：
/// 落库 + 标记 dirty + 入队（由 SyncEngine 异步推送）。
Future<void> enqueueSyncOp(
  AppDatabase db, {
  required String table,
  required String recordId,
  required SyncOpType opType,
  required int updatedAt,
  Map<String, Object?>? payload,
}) async {
  final int createdAt = DateTime.now().toUtc().millisecondsSinceEpoch;
  await db.pendingOpsDao.enqueue(
    PendingOpsCompanion(
      targetTable: Value<String>(table),
      recordId: Value<String>(recordId),
      opType: Value<SyncOpType>(opType),
      payload: Value<String?>(payload == null ? null : jsonEncode(payload)),
      updatedAt: Value<int>(updatedAt),
      createdAt: Value<int>(createdAt),
    ),
  );
}
