import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../database/app_database.dart';
import 'transaction_repository.dart';

/// 一笔「账单导入」的归档记录（入口页展示 + 级联删除溯源）。
///
/// 不进 drift 代码生成：用原生 SQL 表（与 [AppDatabase._ensureRawTables] 同口径，
/// 避开本沙箱 `build_runner` 因管道耗尽不可用的问题）。本库仅本地、不参与云端同步。
class ImportRecord {
  const ImportRecord({
    required this.id,
    required this.source,
    required this.sourceLabel,
    required this.importedCount,
    required this.skippedCount,
    required this.createdAt,
    this.failReasons,
    this.txnIds,
  });

  final String id;

  /// 导入来源枚举名（如 'unionpay' / 'alipay' / 'wechat' / 'bank'）。
  final String source;

  /// 来源可读名（如 '云闪付'）。
  final String sourceLabel;

  /// 成功写入的流水笔数。
  final int importedCount;

  /// 被跳过 / 失败的笔数。
  final int skippedCount;

  /// 导入完成时刻（epoch ms，UTC）。
  final int createdAt;

  /// 被跳过 / 失败的行原因清单（展示给用户「查看问题」用）。
  final List<String>? failReasons;

  /// 本次导入写入的流水 ID 清单（级联删除溯源）。
  final List<String>? txnIds;

  String? get failJson => failReasons == null ? null : jsonEncode(failReasons);

  String? get txnIdsJson => txnIds == null ? null : jsonEncode(txnIds);

  static List<String>? _parseJsonList(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? v = jsonDecode(raw);
      if (v is List) return v.cast<String>();
    } catch (_) {
      // 容忍脏数据：解码失败按无数据处理。
    }
    return null;
  }
}

/// 导入记录仓储（原生 SQL 表 `import_records` 的读写 + 级联删除）。
class ImportRecordRepository {
  ImportRecordRepository(this._db) {
    // 原生 SQL 表不进 drift 反应式体系：写入经 customStatement，不会触发 drift
    // 的表变更通知，[watchAll] 用的 customSelect().watch() 也读不到实时数据。
    // 故内部用广播流主动通知，每次订阅先发当前快照，保证入口页即开即见、滑删后即时刷新。
    _updates = StreamController<void>.broadcast();
  }

  final AppDatabase _db;
  late final StreamController<void> _updates;

  /// 写入一条导入记录。
  Future<void> insert(ImportRecord r) async {
    await _db.customStatement(
      'INSERT INTO import_records '
      '(id, source, source_label, imported_count, skipped_count, '
      'fail_json, txn_ids, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        r.id,
        r.source,
        r.sourceLabel,
        r.importedCount,
        r.skippedCount,
        r.failJson,
        r.txnIdsJson,
        r.createdAt,
      ],
    );
    _updates.add(null);
  }

  /// 全部导入记录（按完成时间倒序），供入口页列表展示。
  Future<List<ImportRecord>> getAll() async {
    final List<QueryRow> rows = await _db.customSelect(
      'SELECT id, source, source_label, imported_count, skipped_count, '
      'fail_json, txn_ids, created_at FROM import_records '
      'ORDER BY created_at DESC',
    ).get();
    return rows.map(_rowToRecord).toList();
  }

  /// 实时流：导入 / 删除导入记录后主动重发。每次订阅先发当前快照，再监听内部
  /// 广播流在写入 / 删除后重发最新列表（原生 SQL 表不依赖 drift 反应式）。
  Stream<List<ImportRecord>> watchAll() async* {
    yield await getAll();
    await for (final _ in _updates.stream) {
      yield await getAll();
    }
  }

  Future<ImportRecord?> getById(String id) async {
    final List<QueryRow> rows = await _db.customSelect(
      'SELECT id, source, source_label, imported_count, skipped_count, '
      'fail_json, txn_ids, created_at FROM import_records WHERE id = ?',
      variables: <Variable<Object>>[Variable<Object>(id)],
    ).get();
    if (rows.isEmpty) return null;
    return _rowToRecord(rows.first);
  }

  /// 仅删记录行（不碰流水）；级联删除见 [deleteCascade]。
  Future<void> deleteRow(String id) async {
    await _db.customStatement(
      'DELETE FROM import_records WHERE id = ?',
      <Object?>[id],
    );
    _updates.add(null);
  }

  /// 级联删除：先把本批导入的流水**合并进单个事务**批量软删（余额回滚 + 同步
  /// 入队 + 报销联动 + 借还联动由 [TransactionRepository.removeBatch] 内部逐笔
  /// 自理，语义与单笔删除完全一致），再删记录行。一次提交、一次 fsync、watch
  /// 只重建一次 —— 大批量删除不再随笔数线性变慢、避免请求超时。单笔失败
  /// （如已手动删除）不阻断其余，保证记录最终能被删掉。
  ///
  /// 注：普通 / 储蓄 / 分期 / 报销路由的流水均在 [txnIds] 内，级联完整；
  /// 借还 / 投资路由的流水在各自台账内部创建，未纳入 [txnIds]，删除导入记录时
  /// 不会回溯（属幂次模板导入的窄路径，沿用「删台账由模块负责」的既有约定）。
  Future<void> deleteCascade(
    String recordId,
    TransactionRepository txnRepo,
  ) async {
    final ImportRecord? rec = await getById(recordId);
    if (rec?.txnIds != null && rec!.txnIds!.isNotEmpty) {
      await txnRepo.removeBatch(rec.txnIds!);
    }
    await deleteRow(recordId);
    _updates.add(null);
  }

  ImportRecord _rowToRecord(QueryRow row) {
    return ImportRecord(
      id: row.read<String>('id'),
      source: row.read<String>('source'),
      sourceLabel: row.read<String>('source_label'),
      importedCount: row.read<int>('imported_count'),
      skippedCount: row.read<int>('skipped_count'),
      createdAt: row.read<int>('created_at'),
      failReasons: ImportRecord._parseJsonList(row.read<String?>('fail_json')),
      txnIds: ImportRecord._parseJsonList(row.read<String?>('txn_ids')),
    );
  }
}
