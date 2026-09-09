import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/config/env.dart';
import '../core/errors/failures.dart';
import '../database/app_database.dart';
import '../database/sync_records.dart';
import 'adapters/offline_adapter.dart';
import 'record_codec.dart';
import 'sync_adapter.dart';

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
    this.error,
  });

  final SyncStatus status;
  final int? lastSyncedAt;
  final int pendingCount;
  final String adapterName;
  final String? error;

  SyncState copyWith({
    SyncStatus? status,
    int? lastSyncedAt,
    int? pendingCount,
    String? adapterName,
    String? error,
  }) {
    return SyncState(
      status: status ?? this.status,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pendingCount: pendingCount ?? this.pendingCount,
      adapterName: adapterName ?? this.adapterName,
      error: error,
    );
  }
}

/// 同步引擎。
///
/// 流程：push（本地 → 云端）→ pull（云端 → 本地）→ 冲突判定 → 落库。
/// 全程异步，UI 不等待；失败时操作保留在 [PendingOps] 队列中，下次自动重试。
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

  /// 执行一轮完整同步。
  ///
  /// 返回 [SyncState]，调用方（Riverpod Notifier）据此更新 UI。
  Future<SyncState> run() async {
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
        return _snapshot(SyncStatus.disabled);
      }

      await _push();
      await _pull();

      final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await _storage.write(
        key: Env.lastSyncedAtStorageKey,
        value: now.toString(),
      );
      return _snapshot(SyncStatus.success, lastSyncedAt: now);
    } on AppFailure catch (e) {
      return _snapshot(SyncStatus.failure, error: e.message);
    } catch (e) {
      return _snapshot(SyncStatus.failure, error: '同步异常：$e');
    } finally {
      _running = false;
    }
  }

  /// 推送本地待同步操作
  Future<void> _push() async {
    final List<PendingOp> ops = await _db.pendingOpsDao.pending();
    if (ops.isEmpty) return;

    final List<SyncOp> payload = <SyncOp>[];
    for (final PendingOp op in ops) {
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
      await _db.pendingOpsDao.incrementRetry(
        ops.map((PendingOp o) => o.localSeq).toList(),
      );
      return;
    }

    final Set<String> applied = result.appliedIds.toSet();
    final Set<String> conflicted = result.conflictedIds.toSet();

    // 只有被服务端确认的操作才从队列移除，失败的保留等待重试
    final List<int> doneSeqs = ops
        .where((PendingOp o) => applied.contains(o.recordId))
        .map((PendingOp o) => o.localSeq)
        .toList(growable: false);

    if (doneSeqs.isNotEmpty) {
      await _db.pendingOpsDao.removeBySeq(doneSeqs);
      await _markSynced(ops, applied);
    }

    // 冲突 = 服务端持有更新的版本，本地这条注定推不上去。
    // 必须出队：紧随其后的 pull 会把权威版本拉回来覆盖本地；
    // 留在队列里只会让每次同步都重复推一条必然失败的操作。
    final List<int> conflictedSeqs = ops
        .where((PendingOp o) => conflicted.contains(o.recordId))
        .map((PendingOp o) => o.localSeq)
        .toList(growable: false);

    if (conflictedSeqs.isNotEmpty) {
      await _db.pendingOpsDao.removeBySeq(conflictedSeqs);
    }

    final List<int> failedSeqs = ops
        .where(
          (PendingOp o) =>
              !applied.contains(o.recordId) &&
              !conflicted.contains(o.recordId),
        )
        .map((PendingOp o) => o.localSeq)
        .toList(growable: false);

    if (failedSeqs.isNotEmpty) {
      await _db.pendingOpsDao.incrementRetry(failedSeqs);
    }
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

  /// 拉取并应用云端变更。
  ///
  /// **循环拉取直到取空**：一次请求的条数上限是 [Env.syncPullBatchSize]，
  /// 首次全量同步时变更很容易超过这个数。若只拉一批就收工，
  /// 剩下的数据会因为游标已经推进而永远拉不到 —— 静默丢数据。
  ///
  /// 游标以**服务端记录的 updatedAt** 推进，绝不用本地时钟：
  /// 本机时间偏快会让 since 超过真实数据，同样导致记录被永久跳过。
  Future<void> _pull() async {
    int since = await lastPulledAt();
    String afterId = await lastPulledId();

    while (true) {
      final PullResult result = await _adapter.pull(
        deviceId: _deviceId,
        since: since,
        afterId: afterId,
        limit: Env.syncPullBatchSize,
      );

      final List<RemoteRecord> records = result.records;
      if (records.isEmpty) break;

      for (final RemoteRecord record in records) {
        await _apply(record);
      }

      // 结果按 (updatedAt, id) 升序，最后一条即新游标
      final RemoteRecord last = records.last;
      since = last.updatedAt;
      afterId = last.recordId;
      await _saveCursor(since, afterId);

      // 不足一批说明已经拉到末尾
      if (records.length < Env.syncPullBatchSize) break;
    }
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

  /// 应用单条云端记录，采用 LWW（最后写入胜出）解决冲突。
  ///
  /// 覆盖 [SyncTables.all] 全部 12 张表：解码逻辑集中在 [RecordCodec]，
  /// 这里只负责「比时间戳 → 解码 → 落库」三步。
  /// 表名未知时 [RecordCodec.decode] 返回 null，只跳过这一条，
  /// 不让一条脏数据中断整轮同步。
  ///
  /// 单人使用场景下几乎不会冲突（同一时刻只在一台设备操作）。
  /// 若将来支持多人共享账本，可在此升级为字段级 LWW 或 CRDT。
  Future<void> _apply(RemoteRecord record) async {
    final int? localUpdatedAt = await _db.syncLocalUpdatedAt(
      record.tableName,
      record.recordId,
    );

    // 本地更新，保留本地版本
    if (localUpdatedAt != null && localUpdatedAt > record.updatedAt) return;

    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final dynamic companion = RecordCodec.decode(
      record.tableName,
      record.recordId,
      record.payload,
      updatedAt: record.updatedAt,
      deleted: record.deleted,
      syncedAt: now,
    );
    if (companion == null) return;

    await _db.syncUpsert(record.tableName, companion);
  }

  Future<SyncState> _snapshot(
    SyncStatus status, {
    int? lastSyncedAt,
    String? error,
  }) async {
    final int pending = await _db.pendingOpsDao.watchCount().first;
    return SyncState(
      status: status,
      lastSyncedAt: lastSyncedAt ?? await this.lastSyncedAt(),
      pendingCount: pending,
      adapterName: _adapter.name,
      error: error,
    );
  }
}
