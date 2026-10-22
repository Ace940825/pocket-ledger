import 'dart:convert';

import 'package:uuid/uuid.dart';

/// 一条字段级同步冲突。
///
/// 触发条件（见 [SyncEngine]）：pull 阶段，本地行存在且 `dirty == true`（有未同步的
/// 本地修改），而云端版本更新（`remoteUpdatedAt >= localUpdatedAt`）且字段值与本地
/// 确有差异。此时**不静默覆盖本地**，而是把双方的整行 payload 暂存下来，等用户在
/// 冲突解决页逐字段选择保留本地还是采用云端。
///
/// 模型本身是**纯数据**（可序列化、可断言测试），不依赖数据库与格式化层；
/// 字段级 diff 展示由 [SyncFieldMeta] 在 UI 层计算。
class SyncConflict {
  const SyncConflict({
    required this.id,
    required this.table,
    required this.recordId,
    required this.localPayload,
    required this.remotePayload,
    required this.localUpdatedAt,
    required this.remoteUpdatedAt,
    required this.conflictAt,
    this.resolved = false,
    this.mergedPayload,
    this.resolution,
  });

  /// 冲突唯一 ID（UUID）。
  final String id;

  /// 实体表名（[SyncTables]，下划线形式，如 `transactions`）。
  final String table;

  /// 记录 ID。
  final String recordId;

  /// 本地整行 payload（冲突发生时的本地版本，作为「保留本地」的数据源）。
  final Map<String, Object?> localPayload;

  /// 云端整行 payload（即将拉回的版本，作为「采用云端」的数据源）。
  final Map<String, Object?> remotePayload;

  /// 本地行的 updatedAt（UTC 毫秒）。
  final int localUpdatedAt;

  /// 云端记录的 updatedAt（UTC 毫秒）。
  final int remoteUpdatedAt;

  /// 冲突被检测到的时刻（UTC 毫秒）。
  final int conflictAt;

  /// 是否已解决。解决后 [mergedPayload] / [resolution] 非空。
  final bool resolved;

  /// 解决后的合并结果（仅在 [resolved] 时非空）。
  final Map<String, Object?>? mergedPayload;

  /// 逐字段选择：字段名 → true(采用本地) / false(采用云端)。
  final Map<String, bool>? resolution;

  /// 便捷构造：自动生成 ID 与冲突时刻。
  factory SyncConflict.create({
    required String table,
    required String recordId,
    required Map<String, Object?> localPayload,
    required Map<String, Object?> remotePayload,
    required int localUpdatedAt,
    required int remoteUpdatedAt,
  }) =>
      SyncConflict(
        id: const Uuid().v4(),
        table: table,
        recordId: recordId,
        localPayload: localPayload,
        remotePayload: remotePayload,
        localUpdatedAt: localUpdatedAt,
        remoteUpdatedAt: remoteUpdatedAt,
        conflictAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      );

  /// 从数据库行映射还原（payload 列已是解码后的 Map）。
  static SyncConflict fromColumns(Map<String, Object?> row) => SyncConflict(
        id: row['id'] as String,
        table: row['table_name'] as String,
        recordId: row['record_id'] as String,
        localPayload:
            (row['local_payload'] as Map?)?.cast<String, Object?>() ??
                <String, Object?>{},
        remotePayload:
            (row['remote_payload'] as Map?)?.cast<String, Object?>() ??
                <String, Object?>{},
        localUpdatedAt: row['local_updated_at'] as int,
        remoteUpdatedAt: row['remote_updated_at'] as int,
        conflictAt: row['conflict_at'] as int,
        resolved: (row['resolved'] as int? ?? 0) == 1,
        mergedPayload:
            (row['merged_payload'] as Map?)?.cast<String, Object?>(),
        resolution: (row['resolution'] as Map?)?.map(
          (Object? k, Object? v) => MapEntry<String, bool>(k as String, v as bool),
        ),
      );

  /// 序列化为便于存库的列映射（payload 已转成 JSON 字符串）。
  Map<String, Object?> toColumns() => <String, Object?>{
        'id': id,
        'table_name': table,
        'record_id': recordId,
        'local_payload': jsonEncode(localPayload),
        'remote_payload': jsonEncode(remotePayload),
        'local_updated_at': localUpdatedAt,
        'remote_updated_at': remoteUpdatedAt,
        'conflict_at': conflictAt,
        'resolved': resolved ? 1 : 0,
        'resolution': resolution == null ? null : jsonEncode(resolution),
        'merged_payload':
            mergedPayload == null ? null : jsonEncode(mergedPayload),
      };

  SyncConflict copyWith({
    String? id,
    String? table,
    String? recordId,
    Map<String, Object?>? localPayload,
    Map<String, Object?>? remotePayload,
    int? localUpdatedAt,
    int? remoteUpdatedAt,
    int? conflictAt,
    bool? resolved,
    Map<String, Object?>? mergedPayload,
    Map<String, bool>? resolution,
  }) =>
      SyncConflict(
        id: id ?? this.id,
        table: table ?? this.table,
        recordId: recordId ?? this.recordId,
        localPayload: localPayload ?? this.localPayload,
        remotePayload: remotePayload ?? this.remotePayload,
        localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
        remoteUpdatedAt: remoteUpdatedAt ?? this.remoteUpdatedAt,
        conflictAt: conflictAt ?? this.conflictAt,
        resolved: resolved ?? this.resolved,
        mergedPayload: mergedPayload ?? this.mergedPayload,
        resolution: resolution ?? this.resolution,
      );

  /// 按用户逐字段选择计算合并结果。
  ///
  /// [choices] 仅包含**确有差异**的字段；值为 `true` 表示采用本地，`false` 表示
  /// 采用云端。合并以 [remotePayload] 为骨架（保证字段完整、可直接喂给
  /// [RecordCodec.decode]），再把用户选「本地」的差异字段覆盖上去。
  Map<String, Object?> merged(Map<String, bool> choices) {
    final Map<String, Object?> result = <String, Object?>{}
      ..addAll(remotePayload);
    for (final MapEntry<String, bool> e in choices.entries) {
      if (e.value && localPayload.containsKey(e.key)) {
        result[e.key] = localPayload[e.key];
      }
    }
    return result;
  }

  /// 是否已做出全部选择（所有差异字段都有明确倾向）。
  bool isFullyChosen(Map<String, bool> choices, List<String> differingFields) =>
      differingFields.every(choices.containsKey);
}

/// 冲突中单个字段的差异（仅用于 UI 展示，不参与持久化）。
class SyncConflictField {
  const SyncConflictField({
    required this.field,
    required this.label,
    required this.localValue,
    required this.remoteValue,
    required this.localDisplay,
    required this.remoteDisplay,
    this.useLocal = true,
  });

  /// 字段名（Dart 驼峰，与 payload 键一致）。
  final String field;

  /// 字段中文标签（来自 [SyncFieldMeta]）。
  final String label;

  /// 本地原始值。
  final Object? localValue;

  /// 云端原始值。
  final Object? remoteValue;

  /// 本地值的可读展示。
  final String localDisplay;

  /// 云端值的可读展示。
  final String remoteDisplay;

  /// 用户选择：`true`=采用本地，`false`=采用云端。默认本地胜出
  /// （更保守，避免丢本地编辑）。
  final bool useLocal;

  /// 本地与云端是否真有差异。
  bool get differs => !equal(localValue, remoteValue);

  SyncConflictField copyWith({bool? useLocal}) => SyncConflictField(
        field: field,
        label: label,
        localValue: localValue,
        remoteValue: remoteValue,
        localDisplay: localDisplay,
        remoteDisplay: remoteDisplay,
        useLocal: useLocal ?? this.useLocal,
      );

  /// 值相等比较：把 `true/1` 与 `false/0` 归并比较，避免「同值却被判为差异」。
  static bool equal(Object? a, Object? b) {
    if (a == b) return true;
    // Drift 把 bool 列以 0/1 存库、读回为 bool；payload 可能因来源不同混用，
    // 这里把「true/1」与「false/0」归并比较，避免「值相同却被判为差异」。
    if (a is bool || b is bool) {
      final bool? ca = _toBool(a);
      final bool? cb = _toBool(b);
      return ca != null && cb != null && ca == cb;
    }
    return false;
  }

  static bool? _toBool(Object? v) {
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is String) {
      if (v == 'true') return true;
      if (v == 'false') return false;
    }
    return null;
  }
}
