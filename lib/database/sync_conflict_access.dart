import 'dart:convert';

import 'package:drift/drift.dart';

import '../sync/conflict_models.dart';
import 'app_database.dart';

/// 字段级冲突的暂存表（原生 SQL，不参与 drift 代码生成）。
///
/// 沿用 [SyncHistoryAccess] 的自愈式范式（`CREATE TABLE IF NOT EXISTS`），
/// 与 `_ensureRawTables` 在 onCreate / beforeOpen 共用，零代码生成成本。
///
/// 何时写入：同步引擎在 `prompt` 策略下检测到「本地有未同步修改 + 云端更新 +
/// 字段差异」的真冲突时，把双方整行 payload 暂存，等用户在冲突解决页逐字段选择。
extension SyncConflictAccess on AppDatabase {
  /// 幂等建表。表已存在时为零成本 no-op。
  Future<void> ensureSyncConflictsTable() async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS sync_conflicts ('
      'id TEXT NOT NULL PRIMARY KEY, '
      'table_name TEXT NOT NULL, '
      'record_id TEXT NOT NULL, '
      'local_payload TEXT NOT NULL, '
      'remote_payload TEXT NOT NULL, '
      'local_updated_at INTEGER NOT NULL, '
      'remote_updated_at INTEGER NOT NULL, '
      'conflict_at INTEGER NOT NULL, '
      'resolved INTEGER NOT NULL DEFAULT 0, '
      'resolution TEXT, '
      'merged_payload TEXT)',
    );
  }

  /// 写入一条冲突。对同一 `(table_name, record_id)` 的未解决冲突做**去重刷新**：
  /// 重复拉取同一记录时只更新 payload，不堆积重复行。
  Future<void> upsertConflict(SyncConflict conflict) async {
    await customStatement(
      'DELETE FROM sync_conflicts '
      'WHERE table_name = ? AND record_id = ? AND resolved = 0',
      <Object?>[conflict.table, conflict.recordId],
    );
    final Map<String, Object?> cols = conflict.toColumns();
    await customStatement(
      'INSERT INTO sync_conflicts '
      '(id, table_name, record_id, local_payload, remote_payload, '
      'local_updated_at, remote_updated_at, conflict_at, resolved, '
      'resolution, merged_payload) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        cols['id'],
        cols['table_name'],
        cols['record_id'],
        cols['local_payload'],
        cols['remote_payload'],
        cols['local_updated_at'],
        cols['remote_updated_at'],
        cols['conflict_at'],
        cols['resolved'],
        cols['resolution'],
        cols['merged_payload'],
      ],
    );
  }

  /// 列出未解决的冲突（按冲突时间倒序）。
  Future<List<SyncConflict>> listUnresolvedConflicts() async {
    final List<QueryRow> rows = await customSelect(
      'SELECT id, table_name, record_id, local_payload, remote_payload, '
      'local_updated_at, remote_updated_at, conflict_at, resolved, '
      'resolution, merged_payload '
      'FROM sync_conflicts WHERE resolved = 0 ORDER BY conflict_at DESC',
    ).get();
    return rows.map((QueryRow r) => _rowToConflict(r)).toList(growable: false);
  }

  /// 按 ID 读取一条冲突（含已解决的，用于回显合并结果）。
  Future<SyncConflict?> getConflict(String id) async {
    final List<QueryRow> rows = await customSelect(
      'SELECT id, table_name, record_id, local_payload, remote_payload, '
      'local_updated_at, remote_updated_at, conflict_at, resolved, '
      'resolution, merged_payload FROM sync_conflicts WHERE id = ?',
      variables: <Variable<Object>>[Variable<String>(id)],
    ).get();
    if (rows.isEmpty) return null;
    return _rowToConflict(rows.first);
  }

  /// 未解决冲突计数（供设置页角标与同步结果提示）。
  Future<int> countUnresolvedConflicts() async {
    final List<QueryRow> rows = await customSelect(
      'SELECT COUNT(*) AS c FROM sync_conflicts WHERE resolved = 0',
    ).get();
    return rows.first.read<int>('c');
  }

  /// 标记已解决，写入用户的逐字段选择与合并结果。
  Future<void> markConflictResolved(
    String id,
    Map<String, Object?> merged,
    Map<String, bool> resolution,
  ) async {
    await customStatement(
      'UPDATE sync_conflicts SET resolved = 1, '
      'resolution = ?, merged_payload = ? WHERE id = ?',
      <Object?>[jsonEncode(resolution), jsonEncode(merged), id],
    );
  }

  /// 清理早于 [olderThanMs] 的**已解决**冲突（历史归档用）。
  Future<void> pruneResolvedConflicts(int olderThanMs) async {
    await customStatement(
      'DELETE FROM sync_conflicts WHERE resolved = 1 AND conflict_at < ?',
      <Object?>[olderThanMs],
    );
  }

  SyncConflict _rowToConflict(QueryRow r) =>
      SyncConflict.fromColumns(<String, Object?>{
        'id': r.read<String>('id'),
        'table_name': r.read<String>('table_name'),
        'record_id': r.read<String>('record_id'),
        'local_payload': jsonDecode(r.read<String>('local_payload')),
        'remote_payload': jsonDecode(r.read<String>('remote_payload')),
        'local_updated_at': r.read<int>('local_updated_at'),
        'remote_updated_at': r.read<int>('remote_updated_at'),
        'conflict_at': r.read<int>('conflict_at'),
        'resolved': r.read<int>('resolved'),
        'resolution': r.read<String?>('resolution') == null
            ? null
            : jsonDecode(r.read<String>('resolution')),
        'merged_payload': r.read<String?>('merged_payload') == null
            ? null
            : jsonDecode(r.read<String>('merged_payload')),
      });
}
