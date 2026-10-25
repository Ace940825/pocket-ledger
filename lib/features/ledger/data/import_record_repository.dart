import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../database/app_database.dart';
import '../../accounts/data/account_repository.dart';
import '../../installment/data/installment_repository.dart';
import '../../investment/data/investment_repository.dart';
import '../../lend/data/lend_repository.dart';
import '../../reimbursement/data/reimbursement_repository.dart';
import '../../savings/data/savings_repository.dart';
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
    this.accountIds,
    this.lendRecordIds,
    this.investmentHoldingIds,
    this.reimbursementIds,
    this.savingsGoalIds,
    this.installmentPlanIds,
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

  /// 本次导入**新建**的账户 ID 清单（随导入建设的账户，删导入时一并软删）。
  final List<String>? accountIds;

  /// 本次导入新建的借还记录 ID 清单。
  final List<String>? lendRecordIds;

  /// 本次导入新建的投资持仓 ID 清单。
  final List<String>? investmentHoldingIds;

  /// 本次导入新建的报销记录 ID 清单。
  final List<String>? reimbursementIds;

  /// 本次导入新建的储蓄目标 ID 清单。
  final List<String>? savingsGoalIds;

  /// 本次导入新建的分期计划 ID 清单。
  final List<String>? installmentPlanIds;

  String? get failJson => failReasons == null ? null : jsonEncode(failReasons);

  String? get txnIdsJson => txnIds == null ? null : jsonEncode(txnIds);

  String? get accountIdsJson =>
      accountIds == null ? null : jsonEncode(accountIds);

  String? get lendRecordIdsJson =>
      lendRecordIds == null ? null : jsonEncode(lendRecordIds);

  String? get investmentHoldingIdsJson =>
      investmentHoldingIds == null ? null : jsonEncode(investmentHoldingIds);

  String? get reimbursementIdsJson =>
      reimbursementIds == null ? null : jsonEncode(reimbursementIds);

  String? get savingsGoalIdsJson =>
      savingsGoalIds == null ? null : jsonEncode(savingsGoalIds);

  String? get installmentPlanIdsJson =>
      installmentPlanIds == null ? null : jsonEncode(installmentPlanIds);

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
      'fail_json, txn_ids, account_ids, lend_record_ids, '
      'investment_holding_ids, reimbursement_ids, savings_goal_ids, '
      'installment_plan_ids, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        r.id,
        r.source,
        r.sourceLabel,
        r.importedCount,
        r.skippedCount,
        r.failJson,
        r.txnIdsJson,
        r.accountIdsJson,
        r.lendRecordIdsJson,
        r.investmentHoldingIdsJson,
        r.reimbursementIdsJson,
        r.savingsGoalIdsJson,
        r.installmentPlanIdsJson,
        r.createdAt,
      ],
    );
    _updates.add(null);
  }

  /// 全部导入记录（按完成时间倒序），供入口页列表展示。
  Future<List<ImportRecord>> getAll() async {
    final List<QueryRow> rows = await _db.customSelect(
      'SELECT id, source, source_label, imported_count, skipped_count, '
      'fail_json, txn_ids, account_ids, lend_record_ids, '
      'investment_holding_ids, reimbursement_ids, savings_goal_ids, '
      'installment_plan_ids, created_at FROM import_records '
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
      'fail_json, txn_ids, account_ids, lend_record_ids, '
      'investment_holding_ids, reimbursement_ids, savings_goal_ids, '
      'installment_plan_ids, created_at FROM import_records WHERE id = ?',
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

  /// 级联删除：把本批导入新建的**全部对象**一次性清除——流水（含借还 / 投资 /
  /// 分期订单等各路由产生的，靠事务前后差集网全）、借还 / 投资 / 报销 / 储蓄 /
  /// 分期台账、以及随导入新建的账户。整体包在单个 DB 事务里，任一步失败整批
  /// 回滚，杜绝「删一半留一半」。
  ///
  /// 顺序很关键：
  /// 1. **先 `removeBatch(txnIds)`**：删除本批全部流水，余额回滚 / 报销账单复原
  ///    （收入流水触发按台账反向恢复）/ 同步入队由 [TransactionRepository] 自理。
  ///    必须在删报销记录之前——收入流水删除时要能按 `reimbursements` 台账反向
  ///    恢复被抵扣的账单，若先把记录软删了就查不到、账单停留在「已报销」。
  /// 2. **再删各台账父记录**：借还 / 投资 remove 内部会级联自身关联流水并重算
  ///    派生余额（这些流水没进 `txnIds`，靠父记录 remove 兜底删除）；报销 / 储蓄 /
  ///    分期只删记录，其收入 / 存款 / 还款流水已在第 1 步删。
  /// 3. **最后删账户**：仅删本次导入新建、且此时（第 1、2 步后）已无其他未删
  ///    流水 / 借还 / 报销引用的账户——手动记账引用的账户会被保留，避免变孤儿。
  ///    删除走 [AccountRepository.remove]，自动入队同步 delete。
  ///
  /// 单笔失败（如已手动删除）不阻断其余，保证记录最终能被删掉。
  Future<void> deleteCascade(
    String recordId,
    TransactionRepository txnRepo,
    AccountRepository accRepo,
    LendRepository lendRepo,
    InvestmentRepository investRepo,
    ReimbursementRepository reimbRepo,
    SavingsRepository savingsRepo,
    InstallmentRepository instRepo,
  ) async {
    final ImportRecord? rec = await getById(recordId);
    await _db.transaction<void>(() async {
      // 1. 本批全部流水。
      if (rec?.txnIds != null && rec!.txnIds!.isNotEmpty) {
        await txnRepo.removeBatch(rec.txnIds!);
      }
      if (rec != null) {
        // 2. 各台账父记录（幂等：软删已删行是空操作，重复调用安全）。
        for (final String id in rec.lendRecordIds ?? const <String>[]) {
          await lendRepo.remove(id);
        }
        for (final String id in rec.investmentHoldingIds ?? const <String>[]) {
          await investRepo.remove(id);
        }
        for (final String id in rec.reimbursementIds ?? const <String>[]) {
          await reimbRepo.remove(id);
        }
        for (final String id in rec.savingsGoalIds ?? const <String>[]) {
          await savingsRepo.remove(id);
        }
        for (final String id in rec.installmentPlanIds ?? const <String>[]) {
          await instRepo.removePlan(id);
        }
        // 3. 随导入新建、且已无其他引用的账户。
        for (final String id in rec.accountIds ?? const <String>[]) {
          if (await _accountReferencedElsewhere(id)) continue;
          await accRepo.remove(id);
        }
      }
      // 4. 记录行。
      await _db.customStatement(
        'DELETE FROM import_records WHERE id = ?',
        <Object?>[recordId],
      );
    });
    _updates.add(null);
  }

  /// 账户是否仍被「本批以外」的未删数据引用：任意未删流水（accountId /
  /// toAccountId）、未删借还记录（指定账户）、未删报销记录。在级联第 3 步调用，
  /// 此时本批流水 / 台账已在同一事务内软删，故这里查到的都是外来引用。
  Future<bool> _accountReferencedElsewhere(String id) async {
    final Expression<int> total = countAll();

    final int txns = await (_db.selectOnly(_db.transactions)
          ..addColumns(<Expression<int>>[total])
          ..where(
            _db.transactions.deleted.equals(false) &
                (_db.transactions.accountId.equals(id) |
                    _db.transactions.toAccountId.equals(id)),
          ))
        .map((TypedResult row) => row.read(total) ?? 0)
        .getSingle();
    if (txns > 0) return true;

    final int lends = await (_db.selectOnly(_db.lendRecords)
          ..addColumns(<Expression<int>>[total])
          ..where(
            _db.lendRecords.deleted.equals(false) &
                _db.lendRecords.accountId.equals(id),
          ))
        .map((TypedResult row) => row.read(total) ?? 0)
        .getSingle();
    if (lends > 0) return true;

    final int reimbs = await (_db.selectOnly(_db.reimbursements)
          ..addColumns(<Expression<int>>[total])
          ..where(
            _db.reimbursements.deleted.equals(false) &
                _db.reimbursements.accountId.equals(id),
          ))
        .map((TypedResult row) => row.read(total) ?? 0)
        .getSingle();
    return reimbs > 0;
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
      accountIds: ImportRecord._parseJsonList(row.read<String?>('account_ids')),
      lendRecordIds:
          ImportRecord._parseJsonList(row.read<String?>('lend_record_ids')),
      investmentHoldingIds: ImportRecord._parseJsonList(
        row.read<String?>('investment_holding_ids'),
      ),
      reimbursementIds:
          ImportRecord._parseJsonList(row.read<String?>('reimbursement_ids')),
      savingsGoalIds:
          ImportRecord._parseJsonList(row.read<String?>('savings_goal_ids')),
      installmentPlanIds: ImportRecord._parseJsonList(
        row.read<String?>('installment_plan_ids'),
      ),
    );
  }
}
