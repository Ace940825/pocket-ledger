import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocket_ledger/database/sync_history_access.dart';
import 'package:pocket_ledger/features/settings/data/sync_settings.dart';
import 'package:pocket_ledger/features/settings/providers/sync_settings_providers.dart';
import 'package:pocket_ledger/providers/app_providers.dart';
import 'package:pocket_ledger/routing/app_router.dart';
import 'package:pocket_ledger/shared/widgets/app_toast.dart';
import 'package:pocket_ledger/shared/widgets/confirm_dialog.dart';
import 'package:pocket_ledger/shared/widgets/hairline_card.dart';
import 'package:pocket_ledger/shared/widgets/info_kv_row.dart';
import 'package:pocket_ledger/shared/widgets/line_icon_map.dart';
import 'package:pocket_ledger/shared/widgets/section_header.dart';
import 'package:pocket_ledger/shared/widgets/segmented_row.dart';
import 'package:pocket_ledger/sync/conflict_models.dart';
import 'package:pocket_ledger/sync/record_codec.dart';
import 'package:pocket_ledger/sync/sync_engine.dart';
import 'package:pocket_ledger/sync/sync_options.dart';
import 'package:pocket_ledger/theme/app_dimens.dart';
import 'package:pocket_ledger/theme/app_theme.dart';

/// 同步历史列表（自动失效；同步完成或撤回后手动 invalidate 刷新）。
final AutoDisposeFutureProvider<List<SyncHistoryRow>> syncHistoryProvider =
    FutureProvider.autoDispose<List<SyncHistoryRow>>(
  (Ref ref) => ref.watch(appDatabaseProvider).listSyncHistory(),
);

/// 按表统计的待同步分布（「云端同步数据（本地镜像）」面板用）。
final AutoDisposeFutureProvider<List<({String table, int count})>>
    pendingByTableProvider =
    FutureProvider.autoDispose<List<({String table, int count})>>(
  (Ref ref) =>
      ref.watch(appDatabaseProvider).pendingOpsDao.pendingCountByTable(),
);

/// 业务表中文名（与同步历史一致），用于把表名映射为友好标签。
const Map<String, String> _tableLabels = <String, String>{
  SyncTables.books: '账本',
  SyncTables.transactions: '交易',
  SyncTables.accounts: '账户',
  SyncTables.categories: '分类',
  SyncTables.lendRecords: '借还',
  SyncTables.reimbursements: '报销',
  SyncTables.savingsGoals: '储蓄',
  SyncTables.installmentPlans: '分期',
  SyncTables.installmentPeriods: '分期期次',
  SyncTables.budgets: '预算',
  SyncTables.investmentHoldings: '投资',
  SyncTables.inventoryItems: '物品',
};

/// 数据范围：友好标签 → 参与的表名（可多张，如「分期」含主计划与期次两张表）。
const List<({String label, List<String> tables})> _scopeGroups =
    <({String label, List<String> tables})>[
  (label: '账本', tables: <String>[SyncTables.books]),
  (label: '交易', tables: <String>[SyncTables.transactions]),
  (label: '账户', tables: <String>[SyncTables.accounts]),
  (label: '分类', tables: <String>[SyncTables.categories]),
  (label: '借还', tables: <String>[SyncTables.lendRecords]),
  (label: '报销', tables: <String>[SyncTables.reimbursements]),
  (label: '储蓄', tables: <String>[SyncTables.savingsGoals]),
  (
    label: '分期',
    tables: <String>[SyncTables.installmentPlans, SyncTables.installmentPeriods]
  ),
  (label: '预算', tables: <String>[SyncTables.budgets]),
  (label: '投资', tables: <String>[SyncTables.investmentHoldings]),
  (label: '物品', tables: <String>[SyncTables.inventoryItems]),
];

/// 时间区间快捷选项。
enum _TimeRangeKind { all, last7, thisMonth, custom }

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 同步控制面板（二级页）。
///
/// 设置页只保留一个入口，本页集中承载「模式 / 方向 / 范围 / 立即同步 / 历史撤回」，
/// 避免把控件平铺在设置页上。自动模式行为与旧版零回归：仅在下方点「立即同步」时
/// 才会触发带区间 / 范围约束的定向同步。
class SyncControlPage extends ConsumerStatefulWidget {
  const SyncControlPage({super.key});

  @override
  ConsumerState<SyncControlPage> createState() => _SyncControlPageState();
}

class _SyncControlPageState extends ConsumerState<SyncControlPage> {
  _TimeRangeKind _timeRange = _TimeRangeKind.all;
  DateTime? _from;
  DateTime? _to;
  final Set<String> _selectedTables = <String>{};
  bool _syncing = false;

  ({int? fromMs, int? toMs}) _rangeMs() {
    final DateTime now = DateTime.now();
    switch (_timeRange) {
      case _TimeRangeKind.all:
        return (fromMs: null, toMs: null);
      case _TimeRangeKind.last7:
        final DateTime from = now.subtract(const Duration(days: 7));
        return (
          fromMs: DateTime(from.year, from.month, from.day)
              .toUtc()
              .millisecondsSinceEpoch,
          toMs: null,
        );
      case _TimeRangeKind.thisMonth:
        return (
          fromMs:
              DateTime(now.year, now.month, 1).toUtc().millisecondsSinceEpoch,
          toMs: null,
        );
      case _TimeRangeKind.custom:
        if (_from == null || _to == null) return (fromMs: null, toMs: null);
        final int fromMs = DateTime(_from!.year, _from!.month, _from!.day)
            .toUtc()
            .millisecondsSinceEpoch;
        final DateTime toEnd = DateTime(
          _to!.year,
          _to!.month,
          _to!.day + 1,
        ).subtract(const Duration(milliseconds: 1));
        return (fromMs: fromMs, toMs: toEnd.toUtc().millisecondsSinceEpoch);
    }
  }

  SyncScope _buildScope() {
    final ({int? fromMs, int? toMs}) r = _rangeMs();
    final Set<String>? tables =
        _selectedTables.isEmpty ? null : _selectedTables.toSet();
    return SyncScope(fromMs: r.fromMs, toMs: r.toMs, tables: tables);
  }

  Future<void> _syncNow() async {
    final SyncSettings? settings = ref.read(syncSettingsProvider).value;
    if (settings == null || _syncing) return;

    final SyncScope scope = _buildScope();
    setState(() => _syncing = true);
    try {
      final SyncState result =
          await ref.read(syncControllerProvider.notifier).syncNow(
                options: SyncOptions(
                  direction: settings.defaultDirection,
                  scope: scope,
                ),
              );
      ref.invalidate(syncHistoryProvider);
      ref.invalidate(conflictsProvider);
      ref.invalidate(pendingByTableProvider);
      if (!mounted) return;
      if (result.status == SyncStatus.failure) {
        showAppToast(context, '同步失败：${result.error ?? '未知错误'}');
      } else if (result.pendingConflicts > 0) {
        showAppToast(
          context,
          '同步完成，但有 ${result.pendingConflicts} 条冲突待解决',
        );
      } else {
        showAppToast(context, '同步完成（待同步 ${result.pendingCount} 条）');
      }
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, '同步失败：$e');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _rollback(SyncHistoryRow row) async {
    final bool? confirmed = await showConfirm(
      context,
      title: '撤回本次同步',
      content: '将恢复被本次同步覆盖的本地数据，并将其标记为待上传。\n确定撤回「${_fmtRange(row)}」的同步吗？',
      confirmText: '撤回',
      danger: true,
    );
    if (confirmed != true) return;

    try {
      final int n =
          await ref.read(syncControllerProvider.notifier).rollbackSync(row.id);
      ref.invalidate(syncHistoryProvider);
      ref.invalidate(syncControllerProvider);
      if (!mounted) return;
      showAppToast(context, n > 0 ? '已撤回 $n 条本地数据' : '没有需要撤回的数据');
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, '撤回失败：$e');
    }
  }

  String _fmtRange(SyncHistoryRow row) {
    final String tables = row.tables == null || row.tables!.isEmpty
        ? '全部数据'
        : row.tables!.split(',').length >= SyncTables.all.length
            ? '全部数据'
            : row.tables!;
    return tables;
  }

  Future<void> _pickDate(bool isFrom) async {
    final DateTime initial = (isFrom ? _from : _to) ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2018),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SyncSettings> settingsAsync =
        ref.watch(syncSettingsProvider);
    final SyncSettings? settings = settingsAsync.value;

    return Scaffold(
      appBar: AppBar(title: const Text('同步控制')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.lg),
        children: <Widget>[
          _buildStatusSection(),
          const SizedBox(height: AppDimens.md),
          _buildCloudDataSection(),
          const SizedBox(height: AppDimens.md),
          _buildModeSection(settings),
          const SizedBox(height: AppDimens.md),
          _buildDirectionSection(settings),
          const SizedBox(height: AppDimens.md),
          _buildConflictSection(settings),
          const SizedBox(height: AppDimens.md),
          _buildScopeSection(),
          const SizedBox(height: AppDimens.md),
          _buildSyncButton(),
          const SizedBox(height: AppDimens.lg),
          _buildHistorySection(),
        ],
      ),
    );
  }

  /// 同步状态概览（自设置页「云备份与同步」状态卡迁入，2026-10-21 收口）：
  /// 模式 / 上次同步 / 待同步一眼可见；操作功能全在本页下方与历史区。
  Widget _buildStatusSection() {
    final ThemeData theme = Theme.of(context);
    return HairlineCard(
      padding: const EdgeInsets.all(AppDimens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeader(title: '同步状态'),
          const SizedBox(height: AppDimens.sm),
          ref.watch(syncControllerProvider).when(
                data: (SyncState s) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    InfoKVRow(label: '模式', value: Text(s.adapterName)),
                    InfoKVRow(
                      label: '上次同步',
                      value: Text(
                        s.lastSyncedAt == null || s.lastSyncedAt == 0
                            ? '从未同步'
                            : DateTime.fromMillisecondsSinceEpoch(s.lastSyncedAt!)
                                .toLocal()
                                .toString()
                                .substring(0, 19),
                      ),
                    ),
                    InfoKVRow(label: '待同步', value: Text('${s.pendingCount} 条')),
                    if (s.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppDimens.sm),
                        child: Text(
                          s.error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                  ],
                ),
                loading: () => const LinearProgressIndicator(),
                error: (Object e, _) => Text('状态加载失败：$e'),
              ),
        ],
      ),
    );
  }

  /// 云端同步数据（本地镜像）面板（修复「云同步界面缺少云端数据展示」）。
  ///
  /// 本地不保存云端全量副本，这里以「待推送队列按业务表分布」近似展示即将
  /// 同步到云端的数据范围与量级，让用户对「同步了什么 / 还有多少在排队」一目了然。
  Widget _buildCloudDataSection() {
    return HairlineCard(
      padding: const EdgeInsets.all(AppDimens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeader(title: '云端同步数据（本地镜像）'),
          const SizedBox(height: AppDimens.sm),
          Text(
            '本地不保存云端全量副本；下方为「待推送队列按表分布」，即本次同步将上传的数据范围与量级。',
            style: context.text.bodySmall
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppDimens.sm),
          ref.watch(pendingByTableProvider).when(
                loading: () => const LinearProgressIndicator(),
                error: (Object e, _) => Text('读取失败：$e'),
                data: (List<({String table, int count})> rows) {
                  if (rows.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppDimens.md),
                      child: Text(
                        '暂无待同步数据',
                        style: context.text.bodyMedium
                            ?.copyWith(color: context.colors.onSurfaceVariant),
                      ),
                    );
                  }
                  return Column(
                    children: <Widget>[
                      for (final (table: String table, count: int count) in rows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppDimens.xs),
                          child: Row(
                            children: <Widget>[
                              Text(
                                _tableLabels[table] ?? table,
                                style: context.text.bodyMedium,
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: context.colors.surfaceContainerHighest,
                                  borderRadius:
                                      BorderRadius.circular(AppDimens.radiusChip),
                                ),
                                child: Text(
                                  '$count 条',
                                  style: context.text.bodySmall?.copyWith(
                                    color: context.colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
        ],
      ),
    );
  }

  Widget _buildModeSection(SyncSettings? settings) {
    final SyncMode mode = settings?.mode ?? SyncMode.auto;
    return HairlineCard(
      padding: const EdgeInsets.all(AppDimens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeader(title: '同步模式'),
          const SizedBox(height: AppDimens.sm),
          SegmentedRow<SyncMode>(
            options: const <SegmentOption<SyncMode>>[
              SegmentOption<SyncMode>(value: SyncMode.auto, label: '自动'),
              SegmentOption<SyncMode>(value: SyncMode.manual, label: '手动'),
            ],
            value: mode,
            onChanged: (SyncMode v) =>
                ref.read(syncSettingsProvider.notifier).setMode(v),
          ),
          const SizedBox(height: AppDimens.sm),
          Text(
            mode == SyncMode.auto
                ? '自动：开启后在后台自动全量同步（与旧版一致，无需手动操作）。'
                : '手动：关闭后台自动触发，只在下方点「立即同步」时同步。',
            style: context.text.bodySmall
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionSection(SyncSettings? settings) {
    final SyncDirection dir = settings?.defaultDirection ?? SyncDirection.merge;
    return HairlineCard(
      padding: const EdgeInsets.all(AppDimens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeader(title: '默认方向'),
          const SizedBox(height: AppDimens.sm),
          SegmentedRow<SyncDirection>(
            options: const <SegmentOption<SyncDirection>>[
              SegmentOption<SyncDirection>(
                value: SyncDirection.merge,
                label: '合并',
                leading: LineGlyph(Icons.sync, size: 16),
              ),
              SegmentOption<SyncDirection>(
                value: SyncDirection.pushOnly,
                label: '仅上传',
                leading: LineGlyph(Icons.cloud_upload_outlined, size: 16),
              ),
              SegmentOption<SyncDirection>(
                value: SyncDirection.pullOnly,
                label: '仅下载',
                leading: LineGlyph(Icons.cloud_download_outlined, size: 16),
              ),
            ],
            value: dir,
            onChanged: (SyncDirection v) =>
                ref.read(syncSettingsProvider.notifier).setDirection(v),
          ),
          const SizedBox(height: AppDimens.sm),
          Text(
            switch (dir) {
              SyncDirection.merge => '合并：本地与云端互相同步，冲突以时间戳决胜（最后写入胜出）。',
              SyncDirection.pushOnly => '仅上传：本地覆盖云端，跳过下载（适合「以这台设备为准」）。',
              SyncDirection.pullOnly => '仅下载：云端覆盖本地，跳过上传（适合「拉取其他设备的最新数据」）。',
            },
            style: context.text.bodySmall
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildConflictSection(SyncSettings? settings) {
    final ConflictPolicy policy =
        settings?.conflictPolicy ?? ConflictPolicy.auto;
    final AsyncValue<List<SyncConflict>> conflicts =
        ref.watch(conflictsProvider);
    final int pending = conflicts.when(
      data: (List<SyncConflict> l) => l.length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    return HairlineCard(
      padding: const EdgeInsets.all(AppDimens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeader(title: '冲突处理'),
          const SizedBox(height: AppDimens.sm),
          SegmentedRow<ConflictPolicy>(
            options: const <SegmentOption<ConflictPolicy>>[
              SegmentOption<ConflictPolicy>(
                value: ConflictPolicy.auto,
                label: '自动(LWW)',
                leading: LineGlyph(Icons.sync, size: 16),
              ),
              SegmentOption<ConflictPolicy>(
                value: ConflictPolicy.prompt,
                label: '逐字段选择',
                leading: LineGlyph(Icons.gpp_maybe_outlined, size: 16),
              ),
            ],
            value: policy,
            onChanged: (ConflictPolicy v) =>
                ref.read(syncSettingsProvider.notifier).setConflictPolicy(v),
          ),
          const SizedBox(height: AppDimens.sm),
          Text(
            policy == ConflictPolicy.auto
                ? '自动：冲突以时间戳决胜（最后写入胜出），无需人工介入。'
                : '逐字段选择：本地与云端都改过的不一致记录会暂存，由你逐字段决定保留哪边。',
            style: context.text.bodySmall
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppDimens.sm),
          InkWell(
            onTap: () => context.push(Routes.conflictResolve),
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
              child: Row(
                children: <Widget>[
                  LineGlyph(
                    Icons.gpp_maybe_outlined,
                    size: 20,
                    color: context.colors.primary,
                  ),
                  const SizedBox(width: AppDimens.md),
                  Expanded(
                    child: Text('待解决冲突', style: context.text.bodyLarge),
                  ),
                  if (pending > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.errorContainer,
                        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
                      ),
                      child: Text(
                        '$pending',
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: AppDimens.sm),
                  LineGlyph(
                    Icons.chevron_right,
                    size: 18,
                    color: context.colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeSection() {
    return HairlineCard(
      padding: const EdgeInsets.all(AppDimens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeader(title: '本次同步范围（可选）'),
          const SizedBox(height: AppDimens.sm),
          Text(
            '不填则同步全部数据。范围仅在下方点「立即同步」时生效，且不会推进自动同步的增量游标。',
            style: context.text.bodySmall
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppDimens.sm),
          _buildTimeRangeChips(),
          if (_timeRange == _TimeRangeKind.custom) ...<Widget>[
            const SizedBox(height: AppDimens.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: _DateField(
                    label: '起始',
                    value: _from == null ? '选择日期' : _fmtDate(_from!),
                    onTap: () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: _DateField(
                    label: '结束',
                    value: _to == null ? '选择日期' : _fmtDate(_to!),
                    onTap: () => _pickDate(false),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppDimens.sm),
          Text(
            '数据范围',
            style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppDimens.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (int i = 0; i < _scopeGroups.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      right: i < _scopeGroups.length - 1 ? AppDimens.sm : 0,
                    ),
                    child: FilterChip(
                      label: Text(_scopeGroups[i].label),
                      selected: _scopeGroups[i].tables
                          .every(_selectedTables.contains),
                      onSelected: (bool selected) => setState(() {
                        if (selected) {
                          _selectedTables.addAll(_scopeGroups[i].tables);
                        } else {
                          _selectedTables
                              .removeAll(_scopeGroups[i].tables);
                        }
                      }),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeChips() {
    final List<({_TimeRangeKind kind, String label})> items =
        <({_TimeRangeKind kind, String label})>[
      (kind: _TimeRangeKind.all, label: '全部'),
      (kind: _TimeRangeKind.last7, label: '近 7 天'),
      (kind: _TimeRangeKind.thisMonth, label: '本月'),
      (kind: _TimeRangeKind.custom, label: '自定义'),
    ];
    return Wrap(
      spacing: AppDimens.sm,
      runSpacing: AppDimens.sm,
      children: <Widget>[
        for (final item in items)
          ChoiceChip(
            label: Text(item.label),
            selected: _timeRange == item.kind,
            onSelected: (bool selected) {
              if (selected) setState(() => _timeRange = item.kind);
            },
            // 底色/文字/勾选色全部走全局 chipTheme，不再页内覆盖。
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  Widget _buildSyncButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _syncing ? null : _syncNow,
        icon: _syncing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const LineGlyph(Icons.sync),
        label: Text(_syncing ? '同步中…' : '立即同步'),
      ),
    );
  }

  Widget _buildHistorySection() {
    final AsyncValue<List<SyncHistoryRow>> history =
        ref.watch(syncHistoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: '同步历史'),
        const SizedBox(height: AppDimens.sm),
        history.when(
          loading: () => const LinearProgressIndicator(),
          error: (Object e, _) => Text('历史读取失败：$e'),
          data: (List<SyncHistoryRow> rows) {
            if (rows.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimens.md),
                child: Text('还没有同步记录'),
              );
            }
            return Column(
              children: <Widget>[
                for (final SyncHistoryRow row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppDimens.md),
                    child: _HistoryTile(row: row, onRollback: _rollback),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// 日期选择框（只读输入，点击触发日期选择器）。
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: Container(
        height: AppDimens.minTouch,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(color: context.colors.outline),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              label,
              style: context.text.bodySmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
            Text(
              value,
              style: context.text.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// 单条同步历史。
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.row,
    required this.onRollback,
  });

  final SyncHistoryRow row;
  final void Function(SyncHistoryRow) onRollback;

  String get _tablesLabel {
    if (row.tables == null || row.tables!.isEmpty) return '全部数据';
    final List<String> list = row.tables!.split(',');
    if (list.length >= SyncTables.all.length) return '全部数据';
    const Map<String, String> names = <String, String>{
      SyncTables.books: '账本',
      SyncTables.transactions: '交易',
      SyncTables.accounts: '账户',
      SyncTables.categories: '分类',
      SyncTables.lendRecords: '借还',
      SyncTables.reimbursements: '报销',
      SyncTables.savingsGoals: '储蓄',
      SyncTables.installmentPlans: '分期',
      SyncTables.installmentPeriods: '分期期次',
      SyncTables.budgets: '预算',
      SyncTables.investmentHoldings: '投资',
      SyncTables.inventoryItems: '物品',
    };
    return list.map((String t) => names[t] ?? t).join('、');
  }

  String get _rangeLabel {
    if (row.fromMs == null && row.toMs == null) return '全部时间';
    final DateTime from = row.fromMs == null
        ? DateTime(2018)
        : DateTime.fromMillisecondsSinceEpoch(row.fromMs!, isUtc: true)
            .toLocal();
    final DateTime to = row.toMs == null
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(row.toMs!, isUtc: true).toLocal();
    return '${_fmtDate(from)} ~ ${_fmtDate(to)}';
  }

  @override
  Widget build(BuildContext context) {
    final DateTime at =
        DateTime.fromMillisecondsSinceEpoch(row.at, isUtc: true).toLocal();
    final bool canRollback = row.overwrote > 0;

    return HairlineCard(
      padding: const EdgeInsets.all(AppDimens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              LineGlyph(
                switch (row.direction) {
                  'merge' => Icons.sync,
                  'pushOnly' => Icons.cloud_upload_outlined,
                  'pullOnly' => Icons.cloud_download_outlined,
                  _ => Icons.history_outlined,
                },
                size: 18,
                color: context.colors.primary,
              ),
              const SizedBox(width: AppDimens.sm),
              Text(
                _directionLabelFor(row.direction),
                style: context.text.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '${at.year}-${at.month.toString().padLeft(2, '0')}-'
                '${at.day.toString().padLeft(2, '0')} '
                '${at.hour.toString().padLeft(2, '0')}:'
                '${at.minute.toString().padLeft(2, '0')}',
                style: context.text.bodySmall
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.sm),
          Text(
            _tablesLabel,
            style: context.text.bodyMedium,
          ),
          Text(
            _rangeLabel,
            style: context.text.bodySmall
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppDimens.sm),
          Row(
            children: <Widget>[
              _CountChip(label: '上传', value: row.pushed),
              const SizedBox(width: AppDimens.sm),
              _CountChip(label: '下载', value: row.pulled),
              const SizedBox(width: AppDimens.sm),
              _CountChip(label: '覆盖', value: row.overwrote),
              const Spacer(),
              if (canRollback)
                TextButton.icon(
                  onPressed: () => onRollback(row),
                  icon: const LineGlyph(Icons.history_outlined, size: 16),
                  label: const Text('撤回'),
                )
              else
                Text(
                  '无需撤回',
                  style: context.text.bodySmall
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _directionLabelFor(String d) => switch (d) {
        'merge' => '合并',
        'pushOnly' => '仅上传',
        'pullOnly' => '仅下载',
        _ => '同步',
      };
}

/// 历史计数胶囊。
class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      ),
      child: Text(
        '$label $value',
        style: context.text.bodySmall
            ?.copyWith(color: context.colors.onSurfaceVariant),
      ),
    );
  }
}
