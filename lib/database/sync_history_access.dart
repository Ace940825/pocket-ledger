import 'package:drift/drift.dart';

import 'app_database.dart';

/// 同步历史与回滚点的数据库访问层（原生 SQL，不参与 drift 代码生成）。
///
/// 为什么不用 drift 表 + build_runner：本沙箱 build_runner 因系统管道耗尽不可用，
/// 改 schema 后必须重跑代码生成。沿用 [AppDatabase] 里 `_ensureRawTables` 的范式，
/// 用 `CREATE TABLE IF NOT EXISTS` 自愈式建表，零代码生成成本。
///
/// 两张表：
/// - `sync_history`：每次同步写一条版本记录（方向 / 区间 / 范围 / 影响条数），
///   对应设置页「同步历史」列表与「撤回」入口。
/// - `sync_backups`：每次「本地将被覆盖」前打一份行级快照，撤回时据此还原本地。
extension SyncHistoryAccess on AppDatabase {
  /// 幂等建表：同步历史 + 回滚点。表已存在时为零成本 no-op。
  Future<void> ensureSyncHistoryTables() async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS sync_history ('
      'id TEXT NOT NULL PRIMARY KEY, '
      'direction TEXT NOT NULL, '
      'from_ms INTEGER, '
      'to_ms INTEGER, '
      'tables TEXT, '
      'pushed INTEGER NOT NULL DEFAULT 0, '
      'pulled INTEGER NOT NULL DEFAULT 0, '
      'overwrote INTEGER NOT NULL DEFAULT 0, '
      'at INTEGER NOT NULL, '
      'device_id TEXT)',
    );
    await customStatement(
      'CREATE TABLE IF NOT EXISTS sync_backups ('
      'id TEXT NOT NULL PRIMARY KEY, '
      'sync_id TEXT NOT NULL, '
      'table_name TEXT NOT NULL, '
      'record_id TEXT NOT NULL, '
      'payload_before TEXT NOT NULL, '
      'at INTEGER NOT NULL)',
    );
  }

  /// 写入一条同步历史。
  Future<void> insertSyncHistory({
    required String id,
    required String direction,
    int? fromMs,
    int? toMs,
    String? tables,
    required int pushed,
    required int pulled,
    required int overwrote,
    required int at,
    required String deviceId,
  }) async {
    await customStatement(
      'INSERT INTO sync_history '
      '(id, direction, from_ms, to_ms, tables, pushed, pulled, overwrote, at, device_id) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        id,
        direction,
        fromMs,
        toMs,
        tables,
        pushed,
        pulled,
        overwrote,
        at,
        deviceId,
      ],
    );
  }

  /// 列出最近的同步历史（按时间倒序）。
  Future<List<SyncHistoryRow>> listSyncHistory({int limit = 50}) async {
    final List<QueryRow> rows = await customSelect(
      'SELECT id, direction, from_ms, to_ms, tables, pushed, pulled, '
      'overwrote, at, device_id '
      'FROM sync_history ORDER BY at DESC LIMIT ?',
      variables: <Variable<Object>>[Variable<int>(limit)],
    ).get();
    return rows.map(SyncHistoryRow.fromRow).toList(growable: false);
  }

  /// 仅保留最近 [retain] 条，删除更早的历史（含其回滚点）。
  Future<void> pruneSyncHistory({int retain = 50}) async {
    final List<QueryRow> excess = await customSelect(
      'SELECT id FROM sync_history ORDER BY at DESC LIMIT -1 OFFSET ?',
      variables: <Variable<Object>>[Variable<int>(retain)],
    ).get();
    for (final QueryRow row in excess) {
      final String id = row.read<String>('id');
      await customStatement(
        'DELETE FROM sync_backups WHERE sync_id = ?',
        <Object?>[id],
      );
      await customStatement(
        'DELETE FROM sync_history WHERE id = ?',
        <Object?>[id],
      );
    }
  }

  /// 批量写入回滚点。
  Future<void> insertSyncBackups(List<SyncBackupRow> rows) async {
    for (final SyncBackupRow r in rows) {
      await customStatement(
        'INSERT OR REPLACE INTO sync_backups '
        '(id, sync_id, table_name, record_id, payload_before, at) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>[
          r.id,
          r.syncId,
          r.table,
          r.recordId,
          r.payloadBefore,
          r.at,
        ],
      );
    }
  }

  /// 读取某次同步的全部回滚点。
  Future<List<SyncBackupRow>> getSyncBackups(String syncId) async {
    final List<QueryRow> rows = await customSelect(
      'SELECT id, sync_id, table_name, record_id, payload_before, at '
      'FROM sync_backups WHERE sync_id = ?',
      variables: <Variable<Object>>[Variable<String>(syncId)],
    ).get();
    return rows.map(SyncBackupRow.fromRow).toList(growable: false);
  }

  /// 删除某次同步的回滚点（撤回完成后清理）。
  Future<void> deleteSyncBackups(String syncId) async {
    await customStatement(
      'DELETE FROM sync_backups WHERE sync_id = ?',
      <Object?>[syncId],
    );
  }

  /// 清理早于 [olderThanMs] 的回滚点（历史已被 prune 后调用）。
  Future<void> pruneSyncBackups(int olderThanMs) async {
    await customStatement(
      'DELETE FROM sync_backups WHERE at < ?',
      <Object?>[olderThanMs],
    );
  }
}

/// 同步历史行。
class SyncHistoryRow {
  const SyncHistoryRow({
    required this.id,
    required this.direction,
    this.fromMs,
    this.toMs,
    this.tables,
    required this.pushed,
    required this.pulled,
    required this.overwrote,
    required this.at,
    this.deviceId,
  });

  final String id;
  final String direction;
  final int? fromMs;
  final int? toMs;
  final String? tables;
  final int pushed;
  final int pulled;
  final int overwrote;
  final int at;
  final String? deviceId;

  static SyncHistoryRow fromRow(QueryRow row) => SyncHistoryRow(
        id: row.read<String>('id'),
        direction: row.read<String>('direction'),
        fromMs: row.read<int?>('from_ms'),
        toMs: row.read<int?>('to_ms'),
        tables: row.read<String?>('tables'),
        pushed: row.read<int>('pushed'),
        pulled: row.read<int>('pulled'),
        overwrote: row.read<int>('overwrote'),
        at: row.read<int>('at'),
        deviceId: row.read<String?>('device_id'),
      );
}

/// 回滚点行。
class SyncBackupRow {
  const SyncBackupRow({
    required this.id,
    required this.syncId,
    required this.table,
    required this.recordId,
    required this.payloadBefore,
    required this.at,
  });

  final String id;
  final String syncId;
  final String table;
  final String recordId;
  final String payloadBefore;
  final int at;

  static SyncBackupRow fromRow(QueryRow row) => SyncBackupRow(
        id: row.read<String>('id'),
        syncId: row.read<String>('sync_id'),
        table: row.read<String>('table_name'),
        recordId: row.read<String>('record_id'),
        payloadBefore: row.read<String>('payload_before'),
        at: row.read<int>('at'),
      );
}
