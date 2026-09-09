import '../../domain/enums.dart';

/// 一次待推送的变更操作。
class SyncOp {
  const SyncOp({
    required this.tableName,
    required this.recordId,
    required this.opType,
    required this.updatedAt,
    this.payload,
  });

  /// 目标表名（与本地 Drift 表名一致）
  final String tableName;

  /// 记录主键（UUID v7，客户端生成）
  final String recordId;

  final SyncOpType opType;

  /// 变更内容。删除操作可为 null，此时仅凭 recordId + opType 即可表达。
  final Map<String, Object?>? payload;

  /// UTC 毫秒，冲突判定依据
  final int updatedAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'table': tableName,
        'id': recordId,
        'op': opType.name,
        'updatedAt': updatedAt,
        'payload': payload,
      };

  factory SyncOp.fromJson(Map<String, Object?> json) => SyncOp(
        tableName: json['table']! as String,
        recordId: json['id']! as String,
        opType: SyncOpType.values.firstWhere(
          (SyncOpType e) => e.name == json['op'],
          orElse: () => SyncOpType.update,
        ),
        updatedAt: json['updatedAt']! as int,
        payload: json['payload'] as Map<String, Object?>?,
      );
}

/// 服务端的单条变更记录
class RemoteRecord {
  const RemoteRecord({
    required this.tableName,
    required this.recordId,
    required this.updatedAt,
    required this.deleted,
    required this.payload,
  });

  final String tableName;
  final String recordId;
  final int updatedAt;
  final bool deleted;
  final Map<String, Object?> payload;

  factory RemoteRecord.fromJson(Map<String, Object?> json) => RemoteRecord(
        tableName: json['table']! as String,
        recordId: json['id']! as String,
        updatedAt: json['updatedAt']! as int,
        deleted: (json['deleted'] as bool?) ?? false,
        payload: (json['payload'] as Map?)?.cast<String, Object?>() ??
            const <String, Object?>{},
      );
}

/// 拉取结果
class PullResult {
  const PullResult({required this.records, required this.serverTime});

  final List<RemoteRecord> records;

  /// 服务器当前时间（UTC 毫秒），用于校准本地时钟偏差
  final int serverTime;
}

/// 推送结果
class PushResult {
  const PushResult({required this.appliedIds, required this.conflictedIds});

  /// 服务端已成功应用的记录 ID
  final List<String> appliedIds;

  /// 因版本过旧被服务端拒绝的记录 ID（本地需保留以便重新拉取）
  final List<String> conflictedIds;
}

/// 云端同步适配器。
///
/// **业务代码只依赖本接口，不依赖任何具体后端。**
/// 换云（Cloudflare → PocketBase → 自建）只需新增一个实现类，
/// 再在 Provider 中切换即可，其余代码零改动。
abstract class SyncAdapter {
  /// 适配器名称，用于设置页展示
  String get name;

  /// 云端是否可用。返回 false 时同步引擎会跳过整个同步流程。
  Future<bool> isAvailable();

  /// 拉取服务端自游标之后的变更。
  ///
  /// [since] 与 [afterId] 共同构成复合游标 `(updatedAt, id)`：
  /// 返回所有满足 `updatedAt > since || (updatedAt == since && id > afterId)`
  /// 的记录，并按 `(updatedAt, id)` 升序排列。
  ///
  /// 只用一个时间戳是不够的 —— 同一毫秒内的多条记录会被漏掉。
  /// 返回条数小于 [limit] 即表示已拉到末尾。
  Future<PullResult> pull({
    required String deviceId,
    required int since,
    String afterId = '',
    int limit = 500,
  });

  /// 批量推送本地变更。
  Future<PushResult> push({
    required String deviceId,
    required List<SyncOp> ops,
  });

  /// 上传附件（票据 / 物品照片），返回可访问 URL。
  Future<String> uploadFile(String localPath, {String? remoteKey});
}
