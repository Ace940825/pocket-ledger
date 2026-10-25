import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../core/config/env.dart';
import '../core/errors/failures.dart';
import '../database/app_database.dart';
import '../database/sync_conflict_access.dart';
import '../database/sync_history_access.dart';
import '../database/sync_records.dart';
import '../domain/enums.dart';
import 'adapters/offline_adapter.dart';
import 'conflict_models.dart';
import 'record_codec.dart';
import 'sync_adapter.dart';
import 'sync_field_meta.dart';
import 'sync_options.dart';

/// 同步结果
enum SyncStatus {
  idle,
  disabled,
  running,
  success,
  failure;

  bool get isRunning => this == SyncStatus.running;
}

/// 同步状态快照，供设置页与首页角标展示
class SyncState {
  const SyncState({
    this.status = SyncStatus.idle,
    this.lastSyncedAt,
    this.pendingCount = 0,
    this.adapterName = '纯本地',
    this.pendingConflicts = 0,
    this.error,
  });

  final SyncStatus status;
  final int? lastSyncedAt;
  final int pendingCount;
  final String adapterName;

  /// 待解决的字段级冲突数（[ConflictPolicy.prompt] 下产生）。
  final int pendingConflicts;
  final String? error;

  SyncState copyWith({
    SyncStatus? status,
    int? lastSyncedAt,
    int? pendingCount,
    String? adapterName,
    int? pendingConflicts,
    String? error,
  }) {
    return SyncState(
      status: status ?? this.status,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pendingCount: pendingCount ?? this.pendingCount,
      adapterName: adapterName ?? this.adapterName,
      pendingConflicts: pendingConflicts ?? this.pendingConflicts,
      error: error,
    );
  }
}

/// 一次 pull 的统计。
class _PullStats {
  const _PullStats({this.applied = 0, this.overwrote = 0, this.suspended = 0});

  final int applied;
  final int overwrote;

  /// 因 [ConflictPolicy.prompt] 被挂起、需用户逐字段解决的冲突数。
  final int suspended;
}

/// 同步引擎。
///
/// 流程：push（本地 → 云端）→ pull（云端 → 本地）→ 冲突判定 → 落库。
/// 全程异步，UI 不等待；失败时操作保留在 [PendingOps] 队列中，下次自动重试。
///
/// 控制层（v36）：在保持「自动全量同步」不变的前提下，新增
/// [runWithOptions] 支持**手动定向同步**（方向 / 时间区间 / 数据范围）、
/// **本地回滚点**（覆盖前打快照）与**同步历史记录**。
class SyncEngine {
  SyncEngine({
    required AppDatabase database,
    required SyncAdapter adapter,
    required String deviceId,
    FlutterSecureStorage? storage,
  })  : _db = database,
        _adapter = adapter,
        _deviceId = deviceId,
        _storage = storage ?? const FlutterSecureStorage();

  final AppDatabase _db;
  final SyncAdapter _adapter;
  final String _deviceId;
  final FlutterSecureStorage _storage;

  bool _running = false;

  /// 兼容原 [run]：全量自动同步。
  Future<SyncState> run() => runWithOptions(SyncOptions.fullAuto);

  /// 执行一轮同步（可带方向 / 区间 / 范围）。
  ///
  /// - 自动模式（[SyncOptions.fullAuto]）：与旧 [run] 行为完全一致，并推进
  ///   全局增量游标；
  /// - 手动定向同步：只在 [scope] 限定的区间 / 表内操作，**不推进全局游标**
  ///   （否则下一次自动全量同步会因游标越界而永久漏拉区间外记录）。
  Future<SyncState> runWithOptions(SyncOptions options) async {
    if (_running) {
      return _snapshot(SyncStatus.running);
    }

    // 纯本地模式：不发起任何网络请求
    if (_adapter is OfflineAdapter || !Env.cloudSyncEnabled) {
      return _snapshot(SyncStatus.disabled);
    }

    _running = true;
    try {
      final bool available = await _adapter.isAvailable();
      if (!available) {
        return await _snapshot(SyncStatus.disabled);
      }

      int pushed = 0;
      int pulled = 0;
      int overwrote = 0;
      final String syncId = const Uuid().v4();

      if (options.direction != SyncDirection.pullOnly) {
        pushed = await _push(options.scope);
      }

      if (options.direction != SyncDirection.pushOnly) {
        final _PullStats stats = await _pull(
          options.scope,
          advanceCursor: options.scope.isFull,
          syncId: syncId,
          conflictPolicy: options.conflictPolicy,
        );
        pulled = stats.applied;
        overwrote = stats.overwrote;
      }

      final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await _storage.write(
        key: Env.lastSyncedAtStorageKey,
        value: now.toString(),
      );

      // 写入同步历史版本记录。
      await _db.insertSyncHistory(
        id: syncId,
        direction: options.direction.name,
        fromMs: options.scope.fromMs,
        toMs: options.scope.toMs,
        tables: options.scope.tablesParam,
        pushed: pushed,
        pulled: pulled,
        overwrote: overwrote,
        at: now,
        deviceId: _deviceId,
      );
      await _db.pruneSyncHistory(retain: 50);

      return await _snapshot(SyncStatus.success, lastSyncedAt: now);
    } on AppFailure catch (e) {
      return _snapshot(SyncStatus.failure, error: e.message);
    } catch (e) {
      return _snapshot(SyncStatus.failure, error: '同步异常：$e');
    } finally {
      _running = false;
    }
  }

  /// 撤回某次同步：把该次「本地被覆盖」的行恢复到同步前状态，并重新入队，
  /// 使本地改动可在下次推送时再次生效（覆盖云端）。
  ///
  /// 仅对「含本地覆盖」的同步有意义（pullOnly / merge 且云端确实覆盖过本地）；
  /// uploadOnly 同步不会覆盖本地，撤回无副作用，UI 应禁用其撤回按钮。
  Future<int> rollback(String syncId) async {
    final List<SyncBackupRow> backups = await _db.getSyncBackups(syncId);
    if (backups.isEmpty) return 0;

    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (final SyncBackupRow b in backups) {
      final Map<String, Object?>? before =
          (jsonDecode(b.payloadBefore) as Map?)?.cast<String, Object?>();
      if (before == null) continue;
      final dynamic companion = RecordCodec.decode(
        b.table,
        b.recordId,
        before,
        updatedAt: now,
        deleted: (before['deleted'] as int? ?? 0) == 1,
        syncedAt: now,
      );
      if (companion == null) continue;
      await _db.syncUpsert(b.table, companion);
      // 重新入队：让本地这版改动下次推送时覆盖云端，等于「本地重新胜出」。
      await _db.pendingOpsDao.enqueue(
        PendingOpsCompanion(
          targetTable: Value<String>(b.table),
          recordId: Value<String>(b.recordId),
          opType: const Value<SyncOpType>(SyncOpType.update),
          payload: Value<String>(b.payloadBefore),
          updatedAt: Value<int>(now),
          createdAt: Value<int>(now),
        ),
      );
    }
    await _db.deleteSyncBackups(syncId);
    return backups.length;
  }

  /// 推送本地待同步操作（可按 [scope] 限定区间 / 表）。
  ///
  /// 返回本次实际从队列移除的待同步条数（用于历史记录与面板展示）。
  ///
  /// **整轮排空（修复「清空账单后云端残留」根因）**：旧实现每轮只取前 200 条
  /// FIFO 推送，队列被历史重复 op 撑到 3 万+ 后，清空账单产生的 delete 被埋在队尾
  /// 永远轮不到推送，云端数据因此残留。现改为循环分批（每批最多 500）：
  /// - 每批推送后从队列移除「已确认 / 冲突」的 op；
  /// - 推送失败（重试）的 op 加入 [skip]，下一轮不再卡在队首空转；
  /// - 队列清空、达到安全上限（max）或连续整批零推进时退出，杜绝死循环。
  Future<int> _push([SyncScope? scope]) async {
    final Set<int> skip = <int>{};
    int totalRemoved = 0;
    int iterations = 0;
    const int batch = 500;
    const int max = 20000;

    while (totalRemoved < max && iterations < 200) {
      final List<PendingOp> ops =
          await _db.pendingOpsDao.pending(limit: batch, exclude: skip);
      if (ops.isEmpty) break;

      final List<PendingOp> scoped = (scope == null || scope.isFull)
          ? ops
          : ops
              .where((PendingOp o) => scope.matches(o.targetTable, o.updatedAt))
              .toList(growable: false);

      if (scoped.isEmpty) {
        // 本批没有命中 scope 的 op。若是满批，说明队首一整批都不在范围内，跳过
        // 这批避免卡死（更深的命中 op 会在下一轮浮现）；若已是末批则直接结束。
        if (ops.length < batch) break;
        skip.addAll(ops.map((PendingOp o) => o.localSeq));
        iterations++;
        continue;
      }

      final int removed = await _pushBatch(scoped, skip);
      totalRemoved += removed;
      iterations++;
      // 满批却零推进（全部失败/冲突），再循环只会空转，退出。
      if (ops.length >= batch && removed == 0) break;
    }
    return totalRemoved;
  }

  /// 推送一批 op 到云端，返回本次从队列成功移除的条数（已确认 + 冲突）。
  ///
  /// 失败的 op 递增重试计数并加入 [skip]，由 [_push] 在下一轮排空时跳过，避免
  /// 始终卡在队首反复推送必然失败的操作（例如本地已物理删除、无法重建 payload 的行）。
  Future<int> _pushBatch(List<PendingOp> scoped, Set<int> skip) async {
    final List<SyncOp> payload = <SyncOp>[];
    for (final PendingOp op in scoped) {
      payload.add(
        SyncOp(
          tableName: op.targetTable,
          recordId: op.recordId,
          opType: op.opType,
          updatedAt: op.updatedAt,
          payload: await _buildPayload(op),
        ),
      );
    }

    final PushResult result = await _adapter.push(
      deviceId: _deviceId,
      ops: payload,
    );

    if (result.appliedIds.isEmpty && result.conflictedIds.isEmpty) {
      // 整批都没被服务端接纳：全部标记重试，下一轮跳过，避免空转。
      final List<int> all = scoped.map((PendingOp o) => o.localSeq).toList();
      await _db.pendingOpsDao.incrementRetry(all);
      skip.addAll(all);
      return 0;
    }

    final Set<String> applied = result.appliedIds.toSet();
    final Set<String> conflicted = result.conflictedIds.toSet();

    // 只有被服务端确认的操作才从队列移除，失败的保留等待重试
    final List<int> doneSeqs = scoped
        .where((PendingOp o) => applied.contains(o.recordId))
        .map((PendingOp o) => o.localSeq)
        .toList(growable: false);

    if (doneSeqs.isNotEmpty) {
      await _db.pendingOpsDao.removeBySeq(doneSeqs);
      await _markSynced(scoped, applied);
    }

    // 冲突 = 服务端持有更新的版本，本地这条注定推不上去。
    // 必须出队：紧随其后的 pull 会把权威版本拉回来覆盖本地；
    // 留在队列里只会让每次同步都重复推一条必然失败的操作。
    final List<int> conflictedSeqs = scoped
        .where((PendingOp o) => conflicted.contains(o.recordId))
        .map((PendingOp o) => o.localSeq)
        .toList(growable: false);

    if (conflictedSeqs.isNotEmpty) {
      await _db.pendingOpsDao.removeBySeq(conflictedSeqs);
    }

    final List<int> failedSeqs = scoped
        .where(
          (PendingOp o) =>
              !applied.contains(o.recordId) && !conflicted.contains(o.recordId),
        )
        .map((PendingOp o) => o.localSeq)
        .toList(growable: false);

    if (failedSeqs.isNotEmpty) {
      await _db.pendingOpsDao.incrementRetry(failedSeqs);
      skip.addAll(failedSeqs);
    }

    return doneSeqs.length + conflictedSeqs.length;
  }

  /// 构造要推送的 payload。
  ///
  /// **以本地数据库行为唯一数据源**，而不是直接采用入队时手工拼的 JSON。
  /// 原因：手工 payload 极易漏字段（例如漏掉 `bookId`），
  /// 一旦漏了，另一台设备拉回来时无法重建这条记录 —— 而且是静默丢数据。
  /// 入队时的 payload 只作为兜底（行已被物理清除等极端情况）。
  Future<Map<String, Object?>?> _buildPayload(PendingOp op) async {
    final Map<String, Object?>? fromRow = await _db.syncRowAsJson(
      op.targetTable,
      op.recordId,
    );
    if (fromRow != null) return fromRow;

    if (op.payload == null) return null;
    try {
      return (jsonDecode(op.payload!) as Map).cast<String, Object?>();
    } on FormatException {
      return null;
    }
  }

  /// 推送成功后清零 dirty 并写入同步时间戳。
  ///
  /// 服务端只回传记录 ID，不回传表名，因此这里先按表分组再批量更新 ——
  /// 12 张表各自一条 SQL，而不是每人一条。
  Future<void> _markSynced(List<PendingOp> ops, Set<String> applied) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final Map<String, List<String>> grouped = <String, List<String>>{};

    for (final PendingOp op in ops) {
      if (!applied.contains(op.recordId)) continue;
      grouped.putIfAbsent(op.targetTable, () => <String>[]).add(op.recordId);
    }

    for (final MapEntry<String, List<String>> entry in grouped.entries) {
      await _db.syncMarkSynced(entry.key, entry.value, now);
    }
  }

  /// 拉取并应用云端变更（可按 [scope] 限定区间 / 表）。
  ///
  /// **循环拉取直到取空**：一次请求的条数上限是 [Env.syncPullBatchSize]。
  /// 游标以**服务端记录的 updatedAt** 推进，绝不用本地时钟。
  ///
  /// [advanceCursor] 为 true 时按全局增量游标推进（自动全量同步）；
  /// 为 false 时（手动定向同步）**不推进游标**，仅做一次性定向拉取。
  ///
  /// [syncId] 非 null 时，对「将覆盖本地已有行」的记录打回滚点快照。
  Future<_PullStats> _pull(
    SyncScope? scope, {
    bool advanceCursor = true,
    String? syncId,
    ConflictPolicy conflictPolicy = ConflictPolicy.auto,
  }) async {
    int since = advanceCursor ? await lastPulledAt() : (scope?.fromMs ?? 0);
    String afterId = advanceCursor ? await lastPulledId() : '';

    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final List<SyncBackupRow> backups = <SyncBackupRow>[];
    int applied = 0;
    int overwrote = 0;
    int suspended = 0;

    while (true) {
      final PullResult result = await _adapter.pull(
        deviceId: _deviceId,
        since: since,
        afterId: afterId,
        limit: Env.syncPullBatchSize,
        until: scope?.toMs,
        tables: scope?.tables?.toList(),
      );

      final List<RemoteRecord> records = result.records;
      if (records.isEmpty) break;

      for (final RemoteRecord record in records) {
        await _apply(
          record,
          syncId: syncId,
          backups: backups,
          now: now,
          conflictPolicy: conflictPolicy,
          onApplied: () => applied++,
          onOverwrite: () => overwrote++,
          onConflict: () => suspended++,
        );
      }

      // 结果按 (updatedAt, id) 升序，最后一条即新游标
      final RemoteRecord last = records.last;
      since = last.updatedAt;
      afterId = last.recordId;
      if (advanceCursor) await _saveCursor(since, afterId);

      // 不足一批说明已经拉到末尾
      if (records.length < Env.syncPullBatchSize) break;
    }

    if (backups.isNotEmpty) await _db.insertSyncBackups(backups);

    return _PullStats(
      applied: applied,
      overwrote: overwrote,
      suspended: suspended,
    );
  }

  /// 应用单条云端记录，采用 LWW（最后写入胜出）解决冲突。
  ///
  /// 覆盖 [SyncTables.all] 全部 12 张表：解码逻辑集中在 [RecordCodec]，
  /// 这里只负责「比时间戳 → 解码 → 落库」三步。
  /// 表名未知时 [RecordCodec.decode] 返回 null，只跳过这一条，
  /// 不让一条脏数据中断整轮同步。
  ///
  /// [conflictPolicy] 为 [ConflictPolicy.prompt] 时，若本地存在未同步修改
  /// （`dirty == true`）且云端版本更新且字段确有差异，则**不覆盖本地**，改为
  /// 把双方整行 payload 暂存为一条 [SyncConflict]，等用户在冲突解决页逐字段选择。
  Future<void> _apply(
    RemoteRecord record, {
    required String? syncId,
    required List<SyncBackupRow> backups,
    required int now,
    required ConflictPolicy conflictPolicy,
    required VoidCallback onApplied,
    required VoidCallback onOverwrite,
    VoidCallback? onConflict,
  }) async {
    final int? localUpdatedAt = await _db.syncLocalUpdatedAt(
      record.tableName,
      record.recordId,
    );

    // 本地更新且本地更新时间更新 → 保留本地版本，不覆盖（LWW）。
    if (localUpdatedAt != null && localUpdatedAt > record.updatedAt) return;

    // 本地已存在：读取整行（含 dirty 标记），用于判定「真冲突」与回滚点。
    final Map<String, Object?>? before = localUpdatedAt != null
        ? await _db.syncRowAsJson(record.tableName, record.recordId)
        : null;

    // 字段级冲突策略：本地有未同步修改 + 云端更新 + 字段差异 → 挂起，不覆盖。
    if (conflictPolicy == ConflictPolicy.prompt &&
        before != null &&
        _isDirty(before) &&
        record.updatedAt >= localUpdatedAt! &&
        SyncFieldMeta.differingFields(
          record.tableName,
          before,
          record.payload,
        ).isNotEmpty) {
      await _db.upsertConflict(
        SyncConflict.create(
          table: record.tableName,
          recordId: record.recordId,
          localPayload: before,
          remotePayload: record.payload,
          localUpdatedAt: localUpdatedAt,
          remoteUpdatedAt: record.updatedAt,
        ),
      );
      onConflict?.call();
      return;
    }

    // 本地已存在且云端版本更新/相等 → 将覆盖本地，打回滚点快照。
    if (syncId != null && before != null) {
      backups.add(
        SyncBackupRow(
          id: const Uuid().v4(),
          syncId: syncId,
          table: record.tableName,
          recordId: record.recordId,
          payloadBefore: jsonEncode(before),
          at: now,
        ),
      );
      onOverwrite();
    }

    final int applyNow = DateTime.now().toUtc().millisecondsSinceEpoch;
    final dynamic companion = RecordCodec.decode(
      record.tableName,
      record.recordId,
      record.payload,
      updatedAt: record.updatedAt,
      deleted: record.deleted,
      syncedAt: applyNow,
    );
    if (companion == null) return;

    // 云端新增的流水标记来源为「自动同步」：本地原本没有该 id（before == null），
    // 说明它来自其他设备同步拉取，而非本机推送的回声（回声会命中本地已有行、保留原来源）。
    final dynamic finalCompanion =
        (before == null && record.tableName == SyncTables.transactions)
            ? (companion as TransactionsCompanion)
                .copyWith(source: const Value<String?>('自动同步'))
            : companion;
    await _db.syncUpsert(record.tableName, finalCompanion);
    onApplied();
  }

  /// 本地行是否带有未同步修改（[SyncTables] 的 `dirty` 列，bool 或 0/1 皆可）。
  bool _isDirty(Map<String, Object?> row) {
    final Object? d = row['dirty'];
    if (d is bool) return d;
    if (d is int) return d != 0;
    return false;
  }

  /// 解决一条字段级冲突：按用户逐字段选择合并，落库并按需重新入队回推云端。
  ///
  /// [choices]：字段名 → true(采用本地) / false(采用云端)，仅含确有差异的字段。
  /// 若没有任何字段选「本地」，说明用户全盘接受云端 → 直接标记已同步、无需回推；
  /// 否则合并结果以「本地为胜」写回并重新入队，使其在下一次推送时以更新的时间戳
  /// 覆盖云端，让多设备收敛到同一份数据。
  ///
  /// 返回解决的冲突条数（0 表示 ID 不存在）。
  Future<int> resolveConflict(String id, Map<String, bool> choices) async {
    final SyncConflict? conflict = await _db.getConflict(id);
    if (conflict == null) return 0;

    final Map<String, Object?> merged = conflict.merged(choices);
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final bool anyLocal = choices.values.any((bool b) => b);

    final int updatedAt = anyLocal ? now : conflict.remoteUpdatedAt;
    final dynamic companion = RecordCodec.decode(
      conflict.table,
      conflict.recordId,
      merged,
      updatedAt: updatedAt,
      deleted: (merged['deleted'] as bool?) ?? false,
      syncedAt: now,
    );
    if (companion == null) return 0;

    await _db.syncUpsert(conflict.table, companion);

    if (anyLocal) {
      // 标记本地脏并刷新 updatedAt，使合并结果在下一次推送时以更新的时间戳
      // 胜出（否则服务端 LWW 会因时间戳不新而再次判为冲突）。
      await _db.customStatement(
        'UPDATE ${conflict.table} SET dirty = 1, updated_at = ? WHERE id = ?',
        <Object?>[now, conflict.recordId],
      );
      await _db.pendingOpsDao.enqueue(
        PendingOpsCompanion(
          targetTable: Value<String>(conflict.table),
          recordId: Value<String>(conflict.recordId),
          opType: const Value<SyncOpType>(SyncOpType.update),
          payload: Value<String>(jsonEncode(merged)),
          updatedAt: Value<int>(now),
          createdAt: Value<int>(now),
        ),
      );
    } else {
      await _db.syncMarkSynced(
        conflict.table,
        <String>[conflict.recordId],
        now,
      );
    }

    await _db.markConflictResolved(id, merged, choices);
    return 1;
  }

  /// 上次成功同步时间（本地时钟），仅用于 UI 展示。
  Future<int> lastSyncedAt() async {
    final String? raw = await _storage.read(key: Env.lastSyncedAtStorageKey);
    return int.tryParse(raw ?? '') ?? 0;
  }

  /// 同步游标的时间部分（服务端权威 updatedAt，UTC 毫秒）。首次为 0，表示全量拉取。
  Future<int> lastPulledAt() async {
    final String? raw = await _storage.read(key: Env.lastPulledAtStorageKey);
    return int.tryParse(raw ?? '') ?? 0;
  }

  /// 同步游标的 id 部分。
  Future<String> lastPulledId() async {
    return (await _storage.read(key: Env.lastPulledIdStorageKey)) ?? '';
  }

  Future<void> _saveCursor(int since, String afterId) async {
    await _storage.write(key: Env.lastPulledAtStorageKey, value: '$since');
    await _storage.write(key: Env.lastPulledIdStorageKey, value: afterId);
  }

  Future<SyncState> _snapshot(
    SyncStatus status, {
    int? lastSyncedAt,
    String? error,
  }) async {
    final int pending = await _db.pendingOpsDao.watchCount().first;
    final int pendingConflicts = await _db.countUnresolvedConflicts();
    return SyncState(
      status: status,
      lastSyncedAt: lastSyncedAt ?? await this.lastSyncedAt(),
      pendingCount: pending,
      adapterName: _adapter.name,
      pendingConflicts: pendingConflicts,
      error: error,
    );
  }
}
