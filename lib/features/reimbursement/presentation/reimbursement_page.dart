import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failures.dart';
import '../../../core/theme/forest_design_tokens.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../routing/app_router.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/date_field.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/line_icons.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../ledger/presentation/transaction_detail_sheet.dart';
import '../../ledger/providers/ledger_providers.dart';
import '../../../providers/asset_stats_settings.dart';
import '../data/reimbursement_repository.dart';
import '../providers/reimbursement_providers.dart';
import 'reimbursement_grouping.dart';

/// 状态筛选（顶部 chips）：全部 / 待报销 / 已报销 / 报销收入。
enum _StatusFilter { all, pending, reimbursed, incomes }

/// 报销页（ForestSage 方案 A · 暖纸奶油卡）。
///
/// 结构对齐设计稿：Hero 垫付汇总卡 + 吸顶筛选行（年份 / 设置 / 状态 chips）+
/// 按月分组或平铺账单列表（左滑四操作）+ 空态 + 底部双按钮（记一笔 / 报销收入）。
/// 右上「操作」打开资产操作弹窗（方案一：奶油分组列表）。
class ReimbursementPage extends ConsumerStatefulWidget {
  const ReimbursementPage({super.key});

  @override
  ConsumerState<ReimbursementPage> createState() => _ReimbursementPageState();
}

class _ReimbursementPageState extends ConsumerState<ReimbursementPage> {
  /// null = 全部年份；否则具体年份。
  int? _yearFilter;
  _StatusFilter _statusFilter = _StatusFilter.all;

  @override
  void initState() {
    super.initState();
    _yearFilter = DateTime.now().year;
  }

  // ── 工具 ────────────────────────────────────────────

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 96, left: 16, right: 16),
        backgroundColor: ForestNeutral.deepInk,
        duration: const Duration(seconds: 1, milliseconds: 600),
      ),
    );
  }

  Future<bool> _confirm(
    String title,
    String content,
  ) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // ── 列表行操作 ──────────────────────────────────────

  Future<void> _reimburse(Reimbursement r) async {
    try {
      await ref
          .read(reimbursementRepositoryProvider)
          .advanceStatus(r.id, ReimbursementStatus.reimbursed);
      _toast('已标记为「已报销」');
    } on AppFailure catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _unreimb(Reimbursement r) async {
    try {
      await ref
          .read(reimbursementRepositoryProvider)
          .advanceStatus(r.id, ReimbursementStatus.pending);
      _toast('已标记为「待报销」');
    } on AppFailure catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _migrate(Reimbursement r) async {
    final List<Account> accounts =
        ref.read(accountsProvider).valueOrNull ?? <Account>[];
    if (accounts.isEmpty) {
      _toast('还没有可用账户');
      return;
    }
    final String? targetId = await _pickAccount(accounts);
    if (targetId == null || !mounted) return;
    try {
      await ref.read(reimbursementRepositoryProvider).update(
            id: r.id,
            title: r.title,
            status: r.status,
            amountMinor: r.amountMinor,
            payer: r.payer,
            occurredAt: r.occurredAt,
            target: r.target,
            receivedAt: r.receivedAt,
            note: r.note,
            excludeFromStats: r.excludeFromStats,
            accountId: targetId,
            toAccountId: r.toAccountId,
          );
      _toast('已迁移到「${_accountName(targetId)}」');
    } on AppFailure catch (e) {
      _toast(e.message);
    }
  }

  Future<String?> _pickAccount(List<Account> accounts) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => _AccountPickerSheet(accounts: accounts),
    );
  }

  String _accountName(String id) {
    final List<Account> accounts =
        ref.read(accountsProvider).valueOrNull ?? <Account>[];
    for (final Account a in accounts) {
      if (a.id == id) return a.name;
    }
    return '';
  }

  Future<void> _delete(Reimbursement r) async {
    final bool ok = await _confirm('删除「${r.title}」？', '删除后可在「显示已删除账单」中恢复。');
    if (!ok || !mounted) return;
    try {
      await _removeRecord(r);
      _toast('已删除');
    } on AppFailure catch (e) {
      _toast(e.message);
    }
  }

  /// 删除一笔报销记录：报销与流水是同一笔钱的两个视图，
  /// 因此删报销记录时先删其关联的流水（自动回滚账户余额，并级联软删本记录）；
  /// 无关联流水的报销记录（如手动新增）直接软删本记录。
  Future<void> _removeRecord(Reimbursement r) async {
    if (r.transactionId != null) {
      try {
        await ref.read(transactionRepositoryProvider).remove(r.transactionId!);
        return; // transaction.remove 已级联软删本报销记录
      } on NotFoundFailure {
        // 关联流水已不存在，直接软删报销记录即可。
      }
    }
    await ref.read(reimbursementRepositoryProvider).remove(r.id);
  }

  Future<void> _restore(Reimbursement r) async {
    try {
      await ref.read(reimbursementRepositoryProvider).restore(r.id);
      _toast('已恢复');
    } on AppFailure catch (e) {
      _toast(e.message);
    }
  }

  // ── 弹窗 ────────────────────────────────────────────

  Future<void> _showYearSheet(
    Map<int, ReimbYearStat> byYear,
    ReimbYearStat all,
  ) async {
    final int? picked = await showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => _YearSheet(
        byYear: byYear,
        all: all,
        selectedYear: _yearFilter,
        currentYear: DateTime.now().year,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _yearFilter = picked);
    }
  }

  Future<void> _showSettingsSheet() async {
    final bool initialGroup =
        ref.read(assetStatsSettingsProvider).groupByMonthReimburse;
    final bool initialDeleted = ref.read(showDeletedReimbursementsProvider);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => _SettingsSheet(
        initialGroup: initialGroup,
        initialDeleted: initialDeleted,
        onGroup: (bool v) => ref
            .read(assetStatsSettingsProvider.notifier)
            .save(ref.read(assetStatsSettingsProvider).copyWith(
                  groupByMonthReimburse: v,
                )),
        onDeleted: (bool v) =>
            ref.read(showDeletedReimbursementsProvider.notifier).state = v,
      ),
    );
  }

  Future<void> _showAssetActionSheet(List<Reimbursement> all) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => _AssetActionSheet(
        onTimeMachine: () => _toast('时光机功能开发中'),
        onEditAsset: () => _toast('模块视图暂无可编辑的单一资产'),
        onSortAsset: () => _toast('模块视图暂不支持资产排序'),
        onMigrate: () => _toast('请在账单上左滑选择「迁移」'),
        onVerify: () => _toast('账面校验完成，无偏差'),
        onClear: () => _clearAll(all),
        onDeleteAsset: () => _toast('模块视图无单一资产可删除'),
      ),
    );
  }

  Future<void> _clearAll(List<Reimbursement> all) async {
    final List<Reimbursement> active =
        all.where((Reimbursement r) => !r.deleted).toList();
    if (active.isEmpty) {
      _toast('没有可清理的账单');
      return;
    }
    final bool ok = await _confirm(
      '清理全部账单？',
      '将软删除当前 ${active.length} 笔报销，可在「显示已删除账单」中恢复。',
    );
    if (!ok || !mounted) return;
    try {
      for (final Reimbursement r in active) {
        await _removeRecord(r);
      }
      _toast('已清理 ${active.length} 笔');
    } on AppFailure catch (e) {
      _toast(e.message);
    }
  }

  // ── 编辑 / 新增 ─────────────────────────────────────

  Future<void> _showEditor([Reimbursement? record]) async {
    final TextEditingController titleController =
        TextEditingController(text: record?.title ?? '');
    final TextEditingController amountController = TextEditingController(
      text: record != null
          ? Money.fromMinor(record.amountMinor).decimal.toStringAsFixed(2)
          : '',
    );
    final TextEditingController payerController =
        TextEditingController(text: record?.payer ?? '本人');
    final TextEditingController targetController =
        TextEditingController(text: record?.target ?? '');
    final TextEditingController noteController =
        TextEditingController(text: record?.note ?? '');

    ReimbursementStatus status = record?.status ?? ReimbursementStatus.pending;
    bool excludeFromStats = record?.excludeFromStats ?? false;
    DateTime occurredAt = record != null
        ? DateTime.fromMillisecondsSinceEpoch(record.occurredAt, isUtc: true)
            .toLocal()
        : DateTime.now();
    String? accountId = record?.accountId;
    String? toAccountId = record?.toAccountId;

    final List<Account> accounts =
        ref.read(accountsProvider).valueOrNull ?? <Account>[];

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setState) => AlertDialog(
          title: Text(record == null ? '新增报销' : '编辑报销'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: '事由'),
                  autofocus: true,
                ),
                const FormGap(),
                AmountField(controller: amountController),
                const FormGap(),
                TextField(
                  controller: payerController,
                  decoration: const InputDecoration(labelText: '垫付人'),
                ),
                const FormGap(),
                TextField(
                  controller: targetController,
                  decoration: const InputDecoration(
                    labelText: '报销方（公司 / 组织，可选）',
                  ),
                ),
                const FormGap(),
                DropdownButtonFormField<String>(
                  initialValue: accountId,
                  decoration: const InputDecoration(labelText: '报销账户'),
                  hint: const Text('选择原始支出账户（可选）'),
                  items: <DropdownMenuItem<String>>[
                    for (final Account a in accounts)
                      DropdownMenuItem<String>(
                        value: a.id,
                        child: Text(a.name),
                      ),
                  ],
                  onChanged: (String? v) => setState(() => accountId = v),
                ),
                const FormGap(),
                DropdownButtonFormField<String>(
                  initialValue: toAccountId,
                  decoration: const InputDecoration(labelText: '收款账户'),
                  hint: const Text('选择收到报销款的账户（可选）'),
                  items: <DropdownMenuItem<String>>[
                    for (final Account a in accounts)
                      DropdownMenuItem<String>(
                        value: a.id,
                        child: Text(a.name),
                      ),
                  ],
                  onChanged: (String? v) => setState(() => toAccountId = v),
                ),
                const FormGap(),
                EnumDropdown<ReimbursementStatus>(
                  label: '状态',
                  value: status,
                  values: ReimbursementStatus.values,
                  labelOf: (ReimbursementStatus s) => s.label,
                  onChanged: (ReimbursementStatus s) =>
                      setState(() => status = s),
                ),
                const FormGap(),
                DateField(
                  label: '垫付日期',
                  value: occurredAt,
                  onChanged: (DateTime? v) {
                    if (v != null) setState(() => occurredAt = v);
                  },
                ),
                const FormGap(),
                SwitchListTile(
                  title: const Text('不计入收支'),
                  subtitle: const Text(
                    '个人垫款、与报销统计无关时开启，不计入「垫付中」汇总',
                  ),
                  value: excludeFromStats,
                  onChanged: (bool v) => setState(() => excludeFromStats = v),
                  contentPadding: EdgeInsets.zero,
                ),
                const FormGap(),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: '备注'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialog).pop(true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;

    final double? amt = double.tryParse(amountController.text.trim());
    if (amt == null || amt <= 0) {
      _toast('金额必须大于 0');
      return;
    }

    final ReimbursementRepository repo =
        ref.read(reimbursementRepositoryProvider);
    final String target = targetController.text.trim();
    final String note = noteController.text.trim();
    try {
      if (record == null) {
        await repo.add(
          bookId: ref.read(currentBookIdProvider),
          title: titleController.text,
          status: status,
          amountMinor: Money.fromDecimal(amt).minor,
          payer: payerController.text,
          occurredAt: occurredAt.toUtc().millisecondsSinceEpoch,
          target: target.isEmpty ? null : target,
          receivedAt: null,
          note: note.isEmpty ? null : note,
          excludeFromStats: excludeFromStats,
          accountId: accountId,
          toAccountId: toAccountId,
        );
        _toast('已添加报销');
      } else {
        await repo.update(
          id: record.id,
          title: titleController.text,
          status: status,
          amountMinor: Money.fromDecimal(amt).minor,
          payer: payerController.text,
          occurredAt: occurredAt.toUtc().millisecondsSinceEpoch,
          target: target.isEmpty ? null : target,
          receivedAt: null,
          note: note.isEmpty ? null : note,
          excludeFromStats: excludeFromStats,
          accountId: accountId,
          toAccountId: toAccountId,
        );
        _toast('已保存');
      }
    } on AppFailure catch (e) {
      _toast(e.message);
    }
  }

  // ── 构建 ────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final AsyncValue<List<Reimbursement>> baseAsync =
        ref.watch(reimbursementListProvider);
    final bool showDeleted = ref.watch(showDeletedReimbursementsProvider);
    final AsyncValue<List<Reimbursement>> displayAsync = showDeleted
        ? ref.watch(reimbursementListIncludingDeletedProvider)
        : baseAsync;
    final AssetStatsSettings settings = ref.watch(assetStatsSettingsProvider);

    final List<Reimbursement> base = baseAsync.valueOrNull ?? <Reimbursement>[];
    final List<Account> accountList =
        ref.watch(accountsProvider).valueOrNull ?? const <Account>[];
    final Map<String, String> accountNames = <String, String>{
      for (final Account a in accountList) a.id: a.name,
    };

    // 报销页是「报销账户」的分支视图：只展示指向报销类型账户的账单；
    // 未指向账户的属于游离账单，不落入任何账户页（后期由「未选择资产」筛选收录）。
    // 指向已删除账户的账单同样视为游离账单。
    final Set<String> reimbAccountIds = <String>{
      for (final Account a in accountList)
        if (a.type == AccountType.reimbursement) a.id,
    };
    List<Reimbursement> scopeReimb(List<Reimbursement> list) => reimbAccountIds
            .isEmpty
        ? list // 尚无报销账户时退回全局列表，避免整页被清空
        : list
            .where((Reimbursement r) =>
                r.accountId != null && reimbAccountIds.contains(r.accountId))
            .toList(growable: false);
    final List<Reimbursement> scoped = scopeReimb(base);

    // Hero / 年份统计（始终基于未删除且归属本账户的列表）。
    int pendingMinor = 0;
    int pendingCount = 0;
    int reimbursedCount = 0;
    for (final Reimbursement r in scoped) {
      if (r.excludeFromStats) continue;
      if (r.status == ReimbursementStatus.pending) {
        pendingMinor += r.amountMinor;
        pendingCount += 1;
      } else if (r.status == ReimbursementStatus.reimbursed) {
        reimbursedCount += 1;
      }
    }
    // 「已收」口径 = 报销模块收入流水按年合计（实收多少算多少，
    // 部分报销立即同步），不再依赖「已报销」记录金额。
    final List<Transaction> incomesAll =
        ref.watch(reimbursementIncomesProvider).valueOrNull ??
            const <Transaction>[];
    final Map<int, int> receivedByYear = computeReceivedByYear(incomesAll);
    final Map<int, ReimbYearStat> byYearRaw = computeReimbYearStats(scoped);
    final Map<int, ReimbYearStat> byYear = <int, ReimbYearStat>{
      for (final MapEntry<int, ReimbYearStat> e in byYearRaw.entries)
        e.key: ReimbYearStat(
          count: e.value.count,
          pendingMinor: e.value.pendingMinor,
          reimbursedMinor: receivedByYear[e.key] ?? 0,
        ),
    };

    // 报销收入分组：报销模块产生的收入（记一笔报销收入）+ 报销类型账户内的
    // 全部收入流水，同样受年份筛选影响。
    final List<Transaction> incomes =
        incomesAll.where((Transaction t) {
      if (_yearFilter != null) {
        final int y = DateTime.fromMillisecondsSinceEpoch(
          t.occurredAt,
          isUtc: true,
        ).toLocal().year;
        return y == _yearFilter;
      }
      return true;
    }).toList(growable: false);

    // Hero 标题的账户名（设计稿「报销 · 高光」）：取记录关联账户的并集，
    // 恰好一个账户时展示其名称；无关联或多账户时退回「报销」。
    final Set<String> linkedNames = <String>{
      for (final Reimbursement r in scoped)
        if (r.accountId != null && accountNames.containsKey(r.accountId))
          accountNames[r.accountId]!,
    }..removeWhere((String n) => n.isEmpty);
    final String? heroAccountName = linkedNames.length == 1
        ? linkedNames.first
        : (linkedNames.isEmpty
            ? () {
                // 记录未关联账户时，退化用唯一的报销类型账户名。
                final List<Account> reimbAccounts = accountList
                    .where((Account a) => a.type == AccountType.reimbursement)
                    .toList();
                return reimbAccounts.length == 1
                    ? reimbAccounts.first.name
                    : null;
              }()
            : null);
    final ReimbYearStat all = allYearsStat(byYear);
    final int reimbursedYearMinor = _yearFilter == null
        ? all.reimbursedMinor
        : (byYear[_yearFilter]?.reimbursedMinor ?? 0);
    final String reimbursedLabel = _yearFilter == null
        ? '累计已收'
        : (_yearFilter == DateTime.now().year ? '本年已收' : '$_yearFilter年已收');

    // 展示列表：同样只保留归属报销账户的账单，再按年份 + 状态过滤。
    final List<Reimbursement> display = scopeReimb(
      displayAsync.valueOrNull ?? <Reimbursement>[],
    );
    final List<Reimbursement> filtered = display.where((Reimbursement r) {
      if (_statusFilter == _StatusFilter.pending &&
          r.status != ReimbursementStatus.pending) {
        return false;
      }
      if (_statusFilter == _StatusFilter.reimbursed &&
          r.status != ReimbursementStatus.reimbursed) {
        return false;
      }
      if (_yearFilter != null) {
        final int y = DateTime.fromMillisecondsSinceEpoch(
          r.occurredAt,
          isUtc: true,
        ).toLocal().year;
        if (y != _yearFilter) return false;
      }
      return true;
    }).toList();

    final List<ReimbMonthGroup> groups = settings.groupByMonthReimburse
        ? groupReimbursementsByMonth(filtered)
        : <ReimbMonthGroup>[];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF16191A) : ForestBg.paper,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF16191A) : ForestBg.paper,
        foregroundColor:
            isDark ? ForestNeutral.textPrimary : ForestNeutral.deepInk,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '资产详情',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => _showAssetActionSheet(scoped),
            child: Text(
              '操作',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? ForestGreen.brand : ForestGreen.deep,
              ),
            ),
          ),
        ],
      ),
      body: _body(
        context,
        isDark: isDark,
        pendingMinor: pendingMinor,
        pendingCount: pendingCount,
        reimbursedYearMinor: reimbursedYearMinor,
        reimbursedLabel: reimbursedLabel,
        heroAccountName: heroAccountName,
        reimbursedCount: reimbursedCount,
        byYear: byYear,
        all: all,
        accountNames: accountNames,
        settings: settings,
        displayAsync: displayAsync,
        filtered: filtered,
        groups: groups,
        scoped: scoped,
        incomes: incomes,
      ),
      bottomNavigationBar: _bottomBar(context, isDark),
    );
  }

  Widget _body(
    BuildContext context, {
    required bool isDark,
    required int pendingMinor,
    required int pendingCount,
    required int reimbursedYearMinor,
    required String reimbursedLabel,
    required String? heroAccountName,
    required int reimbursedCount,
    required Map<int, ReimbYearStat> byYear,
    required ReimbYearStat all,
    required Map<String, String> accountNames,
    required AssetStatsSettings settings,
    required AsyncValue<List<Reimbursement>> displayAsync,
    required List<Reimbursement> filtered,
    required List<ReimbMonthGroup> groups,
    required List<Reimbursement> scoped,
    required List<Transaction> incomes,
  }) {
    final bool grouped = settings.groupByMonthReimburse;
    final bool incomesMode = _statusFilter == _StatusFilter.incomes;
    final bool isEmpty = incomesMode ? incomes.isEmpty : filtered.isEmpty;

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: _HeroCard(
            pendingMinor: pendingMinor,
            pendingCount: pendingCount,
            reimbursedYearMinor: reimbursedYearMinor,
            reimbursedLabel: reimbursedLabel,
            accountName: heroAccountName,
            isDark: isDark,
            onEdit: () => _showAssetActionSheet(scoped),
          ),
        ),
        SliverToBoxAdapter(
          child: _FilterRow(
            yearLabel: _yearFilter == null ? '全部' : '$_yearFilter年',
            pendingCount: pendingCount,
            reimbursedCount: reimbursedCount,
            incomesCount: incomes.length,
            statusFilter: _statusFilter,
            isDark: isDark,
            onPickYear: () => _showYearSheet(byYear, all),
            onOpenSettings: _showSettingsSheet,
            onStatus: (f) => setState(() => _statusFilter = f),
          ),
        ),
        if (displayAsync.isLoading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (incomesMode)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) =>
                  _incomeTile(context, incomes[index], accountNames, isDark),
              childCount: incomes.length,
            ),
          )
        else if (isEmpty)
          SliverToBoxAdapter(
            child: _EmptyState(isDark: isDark),
          )
        else if (!grouped)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) => _tile(
                context,
                filtered[index],
                accountNames,
                isDark,
              ),
              childCount: filtered.length,
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                // 平铺：月份标题与账单交替。
                int cursor = 0;
                for (final ReimbMonthGroup group in groups) {
                  if (index == cursor) {
                    return _MonthHeader(month: group.month, isDark: isDark);
                  }
                  cursor += 1; // 月份标题之后，账单从 cursor 开始。
                  final int end = cursor + group.items.length;
                  if (index >= cursor && index < end) {
                    return _tile(
                      context,
                      group.items[index - cursor],
                      accountNames,
                      isDark,
                    );
                  }
                  cursor = end;
                }
                return const SizedBox.shrink();
              },
              childCount: groups.fold<int>(
                0,
                (int sum, ReimbMonthGroup g) => sum + 1 + g.items.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _tile(
    BuildContext context,
    Reimbursement r,
    Map<String, String> accountNames,
    bool isDark,
  ) {
    final bool deleted = r.deleted;
    final Widget card = _ReimbTile(
      r: r,
      subtitle: _subtitle(r, accountNames),
      isDark: isDark,
      dimmed: deleted,
      onTap: () => _openLinkedTransaction(context, r),
    );

    if (deleted) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
        // 设计稿 .swipe{border-radius:18px; overflow:hidden}：动作区与卡片同圆角。
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Slidable(
            key: ValueKey<String>('${r.id}-del'),
            endActionPane: ActionPane(
              // 设计稿 .sw-acts{position:absolute}：动作固定在底层，卡片滑开露出。
              motion: const BehindMotion(),
              // 设计稿 .sw-b 宽 56px：单动作 56 / 列表宽 354（390-2×18）≈ 0.16。
              extentRatio: 0.16,
              children: <Widget>[
                CustomSlidableAction(
                  onPressed: (_) => _restore(r),
                  backgroundColor: ForestGreen.cta,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  child: _swipeChild(
                    const LineIcon(LineIconKind.refundArrow,
                        size: 16, color: Colors.white),
                    '恢复',
                  ),
                ),
              ],
            ),
            child: card,
          ),
        ),
      );
    }

    final bool pending = r.status == ReimbursementStatus.pending;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Slidable(
          key: ValueKey<String>(r.id),
          endActionPane: ActionPane(
            motion: const BehindMotion(),
            // 设计稿 4 个 .sw-b 各 56px：224 / 354 ≈ 0.63。
            extentRatio: 0.63,
            children: <Widget>[
              CustomSlidableAction(
                onPressed: (_) => pending ? _reimburse(r) : _unreimb(r),
                backgroundColor:
                    pending ? ForestGreen.cta : ForestNeutral.textTertiary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                child: _swipeChild(
                  LineIcon(
                    pending
                        ? LineIconKind.reimbursement
                        : LineIconKind.refundArrow,
                    size: 16,
                    color: Colors.white,
                  ),
                  pending ? '报销' : '未报',
                ),
              ),
              CustomSlidableAction(
                onPressed: (_) => _migrate(r),
                backgroundColor: ForestSemantic.transfer,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                child: _swipeChild(
                  // 设计稿迁移图标：上箭头 + 下箭头（↥↧）。
                  const Icon(Icons.import_export,
                      size: 16, color: Colors.white),
                  '迁移',
                ),
              ),
              CustomSlidableAction(
                onPressed: (_) => _showEditor(r),
                backgroundColor: ForestAccent.gold,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                child: _swipeChild(
                  const LineIcon(LineIconKind.pencil,
                      size: 16, color: Colors.white),
                  '编辑',
                ),
              ),
              CustomSlidableAction(
                onPressed: (_) => _delete(r),
                backgroundColor: ForestSemantic.expense,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                child: _swipeChild(
                  const LineIcon(LineIconKind.trash,
                      size: 16, color: Colors.white),
                  '删除',
                ),
              ),
            ],
          ),
          child: card,
        ),
      ),
    );
  }

  // 设计稿 .sw-b：纵向 icon(16px)+4px+文字(10.5px)，字距 .02em、常规字重。
  /// 点击卡片 → 展示关联流水详情弹窗；无关联流水（手建记录/流水已删）时退回编辑器。
  Future<void> _openLinkedTransaction(
    BuildContext context,
    Reimbursement r,
  ) async {
    final String? tid = r.transactionId;
    if (tid != null) {
      final Transaction? txn =
          await ref.read(transactionDetailProvider(tid).future);
      if (!context.mounted) return;
      if (txn != null) {
        await TransactionDetailSheet.show(context, txn);
        return;
      }
    }
    await _showEditor(r);
  }

  /// 「报销收入」分组行：点击打开流水详情弹窗。
  Widget _incomeTile(
    BuildContext context,
    Transaction t,
    Map<String, String> accountNames,
    bool isDark,
  ) {
    final String to = accountNames[t.accountId] ?? '';
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(
      t.occurredAt,
      isUtc: true,
    ).toLocal();
    final String subtitle = to.isEmpty
        ? '${d.month}月${d.day}日 · 报销到账'
        : '${d.month}月${d.day}日 · 到账 $to';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: _IncomeTile(
        title: t.note?.trim().isNotEmpty == true ? t.note!.trim() : '报销收入',
        subtitle: subtitle,
        amountMinor: t.amountMinor,
        isDark: isDark,
        onTap: () => TransactionDetailSheet.show(context, t),
      ),
    );
  }

  Widget _swipeChild(Widget icon, String label) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          icon,
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: const TextStyle(
              fontSize: 10.5,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ],
      );

  String _subtitle(Reimbursement r, Map<String, String> names) {
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(
      r.occurredAt,
      isUtc: true,
    ).toLocal();
    final String day = '${d.month}月${d.day}日';
    if (r.status == ReimbursementStatus.pending) {
      final StringBuffer buf = StringBuffer('$day · ${r.payer}垫付');
      final String? from = r.accountId == null ? null : names[r.accountId];
      if (from != null && from.isNotEmpty) buf.write(' · 报销账户 $from');
      return buf.toString();
    }
    final String? to = r.toAccountId == null ? null : names[r.toAccountId];
    if (to != null && to.isNotEmpty) return '$day · 已到账 $to';
    if (r.target != null && r.target!.isNotEmpty) {
      return '$day · 向 ${r.target} 报销';
    }
    return '$day · 已报销';
  }

  Widget _bottomBar(BuildContext context, bool isDark) {
    final Color ghostBg = isDark ? const Color(0xFF1F2325) : ForestSurface.card;
    final Color ghostBorder =
        isDark ? const Color(0xFF2C3033) : ForestNeutral.hairlineStrong;
    return SafeArea(
      child: Container(
        color: isDark ? const Color(0xFF16191A) : ForestBg.paper,
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _PillButton(
                onPressed: () => context.push(Routes.ledgerAdd),
                backgroundColor: ghostBg,
                border: Border.all(color: ghostBorder),
                textColor:
                    isDark ? ForestNeutral.textPrimary : ForestNeutral.deepInk,
                label: '记一笔',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 135,
              child: _PillButton(
                onPressed: () => _showEditor(),
                gradient: ForestGradients.button,
                textColor: Colors.white,
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: '报销收入',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero 垫付汇总卡 ─────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.pendingMinor,
    required this.pendingCount,
    required this.reimbursedYearMinor,
    required this.reimbursedLabel,
    required this.accountName,
    required this.isDark,
    required this.onEdit,
  });

  final int pendingMinor;
  final int pendingCount;
  final int reimbursedYearMinor;
  final String reimbursedLabel;

  /// 报销账户名（设计稿「报销 · 高光」）；null 时仅显示「报销」。
  final String? accountName;
  final bool isDark;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final Color cardBg = isDark ? const Color(0xFF1B1F20) : ForestSurface.card;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 4),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF2C3033) : ForestNeutral.hairline,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: ForestGreen.deep.withValues(alpha: isDark ? 0.18 : 0.07),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark
                        ? ForestGreen.deep.withValues(alpha: 0.22)
                        : ForestGreen.soft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: LineIcon(
                    LineIconKind.reimbursement,
                    size: 21,
                    color: isDark ? ForestGreen.brand : ForestGreen.deep,
                  ),
                ),
                const SizedBox(width: 12),
                // 设计稿 .acct-name：单行「报销 · 账户名」（16px w600），无副行。
                Expanded(
                  child: Text(
                    accountName == null ? '报销' : '报销 · $accountName',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: ForestNeutral.deepInk,
                    ),
                  ),
                ),
                // 设计稿 .hero-actions button：34×34 圆形、sunken 底、15px 图标
                InkWell(
                  onTap: onEdit,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C3033) : ForestBg.sunken,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: LineIcon(
                      LineIconKind.pencil,
                      size: 15,
                      color: isDark
                          ? ForestNeutral.textPrimary
                          : ForestNeutral.deepInk,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '垫付中总金额（元）',
              style: TextStyle(
                fontSize: 12,
                color: ForestNeutral.textSecondary,
                letterSpacing: 0.48, // 设计稿 .04em @ 12px
              ),
            ),
            const SizedBox(height: 6),
            // 设计稿：¥ 为 0.52em（≈18.7px）w600、右距 3；数字 36px w700、.01em
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: '¥',
                    style: TextStyle(
                      fontSize: 36 * 0.52, // ≈18.7
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                  TextSpan(
                    text:
                        Money.fromMinor(pendingMinor).format(showSymbol: false),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.36, // 设计稿 .01em @ 36px
                    ),
                  ),
                ],
              ),
              style: const TextStyle(
                fontFamily: 'Noto Serif SC',
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: ForestNeutral.deepInk,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                _Chip(
                  label: '待报销 $pendingCount 笔',
                  background:
                      isDark ? const Color(0xFF2C3033) : ForestBg.sunken,
                  color: isDark
                      ? ForestNeutral.textSecondary
                      : ForestNeutral.textSecondary,
                ),
                _Chip(
                  label:
                      '$reimbursedLabel ${Money.fromMinor(reimbursedYearMinor).format()}',
                  background: ForestAccent.gold.withValues(alpha: 0.14),
                  color: ForestAccent.gold,
                  fontWeight: FontWeight.w500,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.background,
    required this.color,
    this.fontWeight = FontWeight.w400,
  });

  final String label;
  final Color background;
  final Color color;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: fontWeight),
      ),
    );
  }
}

// ── 吸顶筛选行 ─────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.yearLabel,
    required this.pendingCount,
    required this.reimbursedCount,
    required this.incomesCount,
    required this.statusFilter,
    required this.isDark,
    required this.onPickYear,
    required this.onOpenSettings,
    required this.onStatus,
  });

  final String yearLabel;
  final int pendingCount;
  final int reimbursedCount;
  final int incomesCount;
  final _StatusFilter statusFilter;
  final bool isDark;
  final VoidCallback onPickYear;
  final VoidCallback onOpenSettings;
  final ValueChanged<_StatusFilter> onStatus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 三枚胶囊需并排一行：左右留白 18→14，元素间距统一收到 6。
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Row(
        children: <Widget>[
          InkWell(
            onTap: onPickYear,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2325) : ForestSurface.card,
                border: Border.all(
                  color:
                      isDark ? const Color(0xFF2C3033) : ForestNeutral.hairline,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    yearLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ForestNeutral.deepInk,
                    ),
                  ),
                  const SizedBox(width: 5),
                  // 设计稿 .year-btn svg：12px、text3
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 12,
                    color: ForestNeutral.textTertiary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // 设计稿 .gear：34×34 圆形、card 底、hair 描边、15px 图标、text2
          InkWell(
            onTap: onOpenSettings,
            customBorder: const CircleBorder(),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2325) : ForestSurface.card,
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      isDark ? const Color(0xFF2C3033) : ForestNeutral.hairline,
                ),
              ),
              alignment: Alignment.center,
              child: LineIcon(
                LineIconKind.settings,
                size: 15,
                color: ForestNeutral.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // 右侧状态 chips：紧凑规格（padding 9 / 字号 12 / 间距 6）保证
          // 三枚在 390pt 屏并排一行；Wrap 仅作极窄屏兜底。
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  _StatusChip(
                    label: '待报销',
                    count: pendingCount,
                    selected: statusFilter == _StatusFilter.pending,
                    isDark: isDark,
                    onTap: () => onStatus(_StatusFilter.pending),
                  ),
                  _StatusChip(
                    label: '已报销',
                    count: reimbursedCount,
                    selected: statusFilter == _StatusFilter.reimbursed,
                    isDark: isDark,
                    onTap: () => onStatus(_StatusFilter.reimbursed),
                  ),
                  _StatusChip(
                    label: '报销收入',
                    count: incomesCount,
                    selected: statusFilter == _StatusFilter.incomes,
                    isDark: isDark,
                    onTap: () => onStatus(_StatusFilter.incomes),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = selected
        ? (isDark ? ForestGreen.deep.withValues(alpha: 0.22) : ForestGreen.soft)
        : (isDark ? const Color(0xFF1F2325) : ForestBg.sunken);
    final Color fg = selected
        ? (isDark ? ForestGreen.brand : ForestGreen.deep)
        : (isDark ? ForestNeutral.textSecondary : ForestNeutral.textSecondary);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        // 紧凑胶囊：水平 padding 13→9、字号 12.5→12，保证三枚并排一行。
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          border: selected
              ? Border.all(color: ForestGreen.softBorder)
              : Border.all(color: Colors.transparent),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(text: label),
              // 设计稿 .chip small：10px、75% 透明度、左距 2px
              TextSpan(
                text: ' $count',
                style: TextStyle(
                  fontSize: 10,
                  color: fg.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
          style: TextStyle(
            fontSize: 12,
            color: fg,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ── 账单卡片 ───────────────────────────────────────────

class _ReimbTile extends StatelessWidget {
  const _ReimbTile({
    required this.r,
    required this.subtitle,
    required this.isDark,
    this.dimmed = false,
    required this.onTap,
  });

  final Reimbursement r;
  final String subtitle;
  final bool isDark;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool pending = r.status == ReimbursementStatus.pending;
    final Color cardBg = isDark ? const Color(0xFF1B1F20) : ForestSurface.card;
    return Opacity(
      opacity: dimmed ? 0.5 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            border: Border.all(
              color: isDark ? const Color(0xFF2C3033) : ForestNeutral.hairline,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: ForestGreen.deep.withValues(alpha: isDark ? 0.10 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: pending
                      ? ForestAccent.gold.withValues(alpha: 0.14)
                      : ForestGreen.soft,
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Icon(
                  pending ? Icons.hourglass_bottom : Icons.check,
                  size: 18,
                  color: pending ? ForestAccent.gold : ForestGreen.deep,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      r.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ForestNeutral.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: ForestNeutral.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    _amount(r),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: pending
                          ? ForestNeutral.deepInk
                          : ForestSemantic.income,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures()
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                    decoration: BoxDecoration(
                      color: pending
                          ? ForestAccent.gold.withValues(alpha: 0.13)
                          : ForestGreen.soft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      pending ? '待报销' : '已报销',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: pending ? ForestAccent.gold : ForestGreen.deep,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _amount(Reimbursement r) {
    final String f = Money.fromMinor(r.amountMinor).format();
    return r.status == ReimbursementStatus.reimbursed ? '+$f' : f;
  }
}

// ── 报销收入卡片 ───────────────────────────────────────

/// 「报销收入」分组卡片：报销模块收到的真金白银（income 流水视图），
/// 待报销 / 已报销只负责账单记录，收入统一归入本分组。
class _IncomeTile extends StatelessWidget {
  const _IncomeTile({
    required this.title,
    required this.subtitle,
    required this.amountMinor,
    required this.isDark,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final int amountMinor;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color cardBg = isDark ? const Color(0xFF1B1F20) : ForestSurface.card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          border: Border.all(
            color: isDark ? const Color(0xFF2C3033) : ForestNeutral.hairline,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: ForestGreen.deep.withValues(alpha: isDark ? 0.10 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark
                    ? ForestGreen.deep.withValues(alpha: 0.22)
                    : ForestGreen.soft,
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: LineIcon(
                LineIconKind.moneyBag,
                size: 18,
                color: isDark ? ForestGreen.brand : ForestGreen.deep,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ForestNeutral.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: ForestNeutral.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '+${Money.fromMinor(amountMinor).format()}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ForestSemantic.income,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark
                        ? ForestGreen.deep.withValues(alpha: 0.22)
                        : ForestGreen.soft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '报销收入',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isDark ? ForestGreen.brand : ForestGreen.deep,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 月份小标题 ─────────────────────────────────────────

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.month, required this.isDark});

  final DateTime month;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
      child: Row(
        children: <Widget>[
          Text(
            '${month.month}月',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.14,
              color: isDark
                  ? ForestNeutral.textTertiary
                  : ForestNeutral.textTertiary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: isDark ? const Color(0xFF2C3033) : ForestNeutral.hairline,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 空态 ───────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        children: <Widget>[
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: isDark
                  ? ForestGreen.deep.withValues(alpha: 0.18)
                  : ForestGreen.soft,
              border: Border.all(
                color: isDark
                    ? ForestGreen.deep.withValues(alpha: 0.30)
                    : ForestGreen.softBorder,
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: LineIcon(
              LineIconKind.book,
              size: 34,
              color: isDark ? ForestGreen.brand : ForestGreen.label,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '没有内容了哦',
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? ForestNeutral.textTertiary
                  : ForestNeutral.textTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '该状态下暂无账单',
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? ForestNeutral.textTertiary
                  : ForestNeutral.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 底部药丸按钮 ───────────────────────────────────────

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.onPressed,
    this.backgroundColor,
    this.gradient,
    this.border,
    required this.textColor,
    this.icon,
    required this.label,
  });

  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Gradient? gradient;
  final BoxBorder? border;
  final Color textColor;
  final Widget? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        decoration: BoxDecoration(
          color: backgroundColor,
          gradient: gradient,
          border: border,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null)
                Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: icon,
                ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 年份选择弹窗 ───────────────────────────────────────

class _YearSheet extends StatelessWidget {
  const _YearSheet({
    required this.byYear,
    required this.all,
    required this.selectedYear,
    required this.currentYear,
  });

  final Map<int, ReimbYearStat> byYear;
  final ReimbYearStat all;
  final int? selectedYear;
  final int currentYear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final List<int> years = byYear.keys.toList()
      ..sort((int a, int b) => b.compareTo(a));

    final List<Widget> rows = <Widget>[
      _YearRow(
        title: '全部年份',
        subtitle:
            '共 ${all.count} 笔\n垫付中 ${Money.fromMinor(all.pendingMinor).format()} · 已收 ${Money.fromMinor(all.reimbursedMinor).format()}',
        amount: Money.fromMinor(all.totalMinor).format(),
        selected: selectedYear == null,
        isDark: isDark,
        onTap: () => Navigator.of(context).pop(null),
      ),
      for (final int y in years)
        _YearRow(
          title: '$y年',
          isCurrent: y == currentYear,
          subtitle:
              '共 ${byYear[y]!.count} 笔\n垫付中 ${Money.fromMinor(byYear[y]!.pendingMinor).format()} · 已收 ${Money.fromMinor(byYear[y]!.reimbursedMinor).format()}',
          amount: Money.fromMinor(byYear[y]!.totalMinor).format(),
          selected: selectedYear == y,
          isDark: isDark,
          onTap: () => Navigator.of(context).pop(y),
        ),
    ];

    return _SheetScaffold(
      isDark: isDark,
      maxHeight: 425,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const _Grab(),
          _SheetCloseButton(isDark: isDark),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }
}

class _YearRow extends StatelessWidget {
  const _YearRow({
    required this.title,
    this.isCurrent = false,
    required this.subtitle,
    required this.amount,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final String title;
  final bool isCurrent;
  final String subtitle;
  final String amount;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = selected
        ? (isDark ? ForestGreen.deep.withValues(alpha: 0.20) : ForestGreen.soft)
        : (isDark ? const Color(0xFF1F2325) : ForestSurface.raised);
    final Color border = selected
        ? (isDark ? ForestGreen.softBorder : ForestGreen.softBorder)
        : (isDark ? const Color(0xFF2C3033) : ForestNeutral.hairline);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? (isDark
                                    ? ForestGreen.brand
                                    : ForestGreen.deep)
                                : ForestNeutral.deepInk,
                          ),
                        ),
                        if (isCurrent)
                          Container(
                            margin: const EdgeInsets.only(left: 7),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: ForestAccent.gold.withValues(alpha: 0.13),
                              border: Border.all(
                                color:
                                    ForestAccent.gold.withValues(alpha: 0.28),
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              '今年',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.05,
                                color: ForestAccent.gold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: ForestNeutral.textTertiary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              Text(
                amount,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      selected ? ForestGreen.deep : ForestNeutral.textTertiary,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures()
                  ],
                ),
              ),
              const SizedBox(width: 9),
              if (selected)
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    gradient: ForestGradients.sage,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 显示设置弹窗 ───────────────────────────────────────

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({
    required this.initialGroup,
    required this.initialDeleted,
    required this.onGroup,
    required this.onDeleted,
  });

  final bool initialGroup;
  final bool initialDeleted;
  final ValueChanged<bool> onGroup;
  final ValueChanged<bool> onDeleted;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return _SheetScaffold(
      isDark: isDark,
      child: StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setState) {
          bool group = initialGroup;
          bool deleted = initialDeleted;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const _Grab(),
              _SheetCloseButton(isDark: isDark),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color:
                      isDark ? const Color(0xFF1F2325) : ForestSurface.raised,
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2C3033)
                        : ForestNeutral.hairline,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: <Widget>[
                    _SwitchRow(
                      title: '账单按年月分组',
                      subtitle: '关闭后按时间顺序平铺展示',
                      value: group,
                      isDark: isDark,
                      onChanged: (bool v) {
                        setState(() => group = v);
                        onGroup(v);
                      },
                    ),
                    _SwitchRow(
                      title: '显示已删除账单',
                      subtitle: '开启后可查看并恢复已删除记录',
                      value: deleted,
                      isDark: isDark,
                      onChanged: (bool v) {
                        setState(() => deleted = v);
                        onDeleted(v);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final bool isDark;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ForestNeutral.deepInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: ForestNeutral.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ── 资产操作弹窗（方案一：奶油分组列表）───────────────

class _AssetActionSheet extends StatelessWidget {
  const _AssetActionSheet({
    required this.onTimeMachine,
    required this.onEditAsset,
    required this.onSortAsset,
    required this.onMigrate,
    required this.onVerify,
    required this.onClear,
    required this.onDeleteAsset,
  });

  final VoidCallback onTimeMachine;
  final VoidCallback onEditAsset;
  final VoidCallback onSortAsset;
  final VoidCallback onMigrate;
  final VoidCallback onVerify;
  final VoidCallback onClear;
  final VoidCallback onDeleteAsset;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return _SheetScaffold(
      isDark: isDark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const _Grab(),
          _SheetCloseButton(isDark: isDark),
          _SectionLabel('常用'),
          _ActionGroup(
            isDark: isDark,
            children: <Widget>[
              _ActionRow(
                icon: const LineIcon(LineIconKind.calendar,
                    size: 17, color: ForestGreen.deep),
                title: '时光机',
                subtitle: '按时间线回看资产流水',
                onTap: onTimeMachine,
              ),
              _ActionRow(
                icon: const LineIcon(LineIconKind.pencil,
                    size: 17, color: ForestGreen.deep),
                title: '资产编辑',
                subtitle: '修改名称、图标与备注',
                onTap: onEditAsset,
              ),
              _ActionRow(
                icon: const Icon(Icons.swap_vert,
                    size: 17, color: ForestGreen.deep),
                title: '资产排序',
                subtitle: '调整资产列表展示顺序',
                onTap: onSortAsset,
              ),
            ],
          ),
          _SectionLabel('数据'),
          _ActionGroup(
            isDark: isDark,
            children: <Widget>[
              _ActionRow(
                icon: const Icon(Icons.swap_horiz,
                    size: 17, color: ForestGreen.deep),
                title: '账单迁移',
                subtitle: '把账单挪到其他资产账户',
                onTap: onMigrate,
              ),
              _ActionRow(
                icon: const LineIcon(LineIconKind.moneyBag,
                    size: 17, color: ForestGreen.deep),
                title: '金额校验',
                subtitle: '账面有偏差时一键核对',
                onTap: onVerify,
              ),
            ],
          ),
          _SectionLabel('危险操作', danger: true),
          _ActionGroup(
            isDark: isDark,
            children: <Widget>[
              _ActionRow(
                icon: const LineIcon(LineIconKind.trash,
                    size: 17, color: ForestSemantic.expense),
                title: '账单清理',
                subtitle: '删除此模块内全部账单',
                danger: true,
                onTap: onClear,
              ),
              _ActionRow(
                icon: const Icon(Icons.delete_forever,
                    size: 17, color: ForestSemantic.expense),
                title: '删除资产',
                subtitle: '删除当前报销模块',
                danger: true,
                onTap: onDeleteAsset,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.danger = false});

  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 13, 2, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.16,
          color: danger ? ForestSemantic.expense : ForestNeutral.textTertiary,
        ),
      ),
    );
  }
}

class _ActionGroup extends StatelessWidget {
  const _ActionGroup({required this.isDark, required this.children});

  final bool isDark;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2325) : ForestSurface.raised,
        border: Border.all(
          color: isDark ? const Color(0xFF2C3033) : ForestNeutral.hairline,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: children),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final Widget icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF2C3033) : ForestNeutral.hairline,
            ),
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: danger
                    ? ForestSemantic.expense.withValues(alpha: 0.10)
                    : (isDark
                        ? ForestGreen.deep.withValues(alpha: 0.16)
                        : ForestGreen.soft),
                border: Border.all(
                  color: danger
                      ? ForestSemantic.expense.withValues(alpha: 0.25)
                      : (isDark
                          ? ForestGreen.deep.withValues(alpha: 0.22)
                          : ForestGreen.softBorder),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: icon,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: danger
                          ? ForestSemantic.expense
                          : ForestNeutral.deepInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: ForestNeutral.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: ForestNeutral.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 账户选择器 ─────────────────────────────────────────

class _AccountPickerSheet extends StatelessWidget {
  const _AccountPickerSheet({required this.accounts});

  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return _SheetScaffold(
      isDark: isDark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _Grab(),
          _SheetCloseButton(isDark: isDark),
          const SizedBox(height: 8),
          Text(
            '迁移到账户',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: ForestNeutral.deepInk,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2325) : ForestSurface.raised,
              border: Border.all(
                color:
                    isDark ? const Color(0xFF2C3033) : ForestNeutral.hairline,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < accounts.length; i++)
                  InkWell(
                    onTap: () => Navigator.of(context).pop(accounts[i].id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 13, horizontal: 14),
                      decoration: BoxDecoration(
                        border: i == 0
                            ? Border.all(color: Colors.transparent)
                            : Border(
                                top: BorderSide(
                                  color: isDark
                                      ? const Color(0xFF2C3033)
                                      : ForestNeutral.hairline,
                                ),
                              ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              accounts[i].name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: ForestNeutral.deepInk,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: ForestNeutral.textTertiary,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ── 弹窗通用骨架 ───────────────────────────────────────

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({
    required this.isDark,
    required this.child,
    // 注意：单位是**逻辑像素**；不传时默认为「屏幕高度 × 0.82」。
    this.maxHeight,
  });

  final bool isDark;
  final Widget child;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final Color bg = isDark ? const Color(0xFF1B1F20) : ForestSurface.card;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x4D2C3329),
            blurRadius: 48,
            offset: Offset(0, -18),
          ),
        ],
      ),
      constraints: BoxConstraints(
          maxHeight: maxHeight ?? MediaQuery.of(context).size.height * 0.82),
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: child,
    );
  }
}

class _Grab extends StatelessWidget {
  const _Grab();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 4.5,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: ForestNeutral.hairlineStrong,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _SheetCloseButton extends StatelessWidget {
  const _SheetCloseButton({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(),
        customBorder: const CircleBorder(),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C3033) : ForestBg.sunken,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.close,
            size: 14,
            color: isDark
                ? ForestNeutral.textSecondary
                : ForestNeutral.textSecondary,
          ),
        ),
      ),
    );
  }
}
