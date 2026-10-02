import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/module_list_scaffold.dart'
    show confirmDelete, showToast;
import '../data/savings_repository.dart';
import '../providers/savings_providers.dart';
import 'savings_goal_detail_page.dart';
import 'savings_goal_edit_page.dart';
import 'savings_mode_create_page.dart';
import 'savings_mode_sheet.dart';
import 'savings_modes.dart';
import 'savings_schedule.dart';

/// 储蓄页：「计划 / 归档」双 Tab。
/// - 计划：内嵌「存钱模式选择」双列九宫格，点卡直接进该模式创建页；
///   进行中的储蓄目标列表移至记账页「存钱」Tab 展示；
/// - 归档：已停止的计划，可恢复或删除。
class SavingsPage extends ConsumerWidget {
  const SavingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SavingsGoal>> archived =
        ref.watch(savingsArchivedProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('储蓄'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: '计划'),
              Tab(text: '归档'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _PlanTab(
              onModeTap: (SavingsMode m) => _openCreate(context, m),
            ),
            _ArchivedList(items: archived),
          ],
        ),
      ),
    );
  }

  /// 模式卡点击 → 进对应模式的独立创建页。
  Future<void> _openCreate(BuildContext context, SavingsMode mode) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SavingsModeCreatePage(mode: mode),
      ),
    );
  }
}

/// 计划 Tab：内嵌「存钱模式选择」双列九宫格，点卡直接进创建页。
/// 进行中的计划列表已移至记账页「存钱」Tab（[SavingsGoalTile]）。
class _PlanTab extends StatelessWidget {
  const _PlanTab({required this.onModeTap});

  final ValueChanged<SavingsMode> onModeTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: <Widget>[
        // 顶部：存钱模式选择（对标小青账弹层标题样式）。
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Center(
            child: Text(
              '存钱模式选择',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        // 双列模式九宫格，点卡直接进创建页。
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          // 卡片高度 = 图标区 + 标题 + 两行说明。
          childAspectRatio: 0.98,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: <Widget>[
            for (final SavingsMode m in SavingsMode.values)
              SavingsModeCard(
                mode: m,
                onTap: () => onModeTap(m),
              ),
          ],
        ),
      ],
    );
  }
}

/// 归档 Tab 列表。
class _ArchivedList extends ConsumerWidget {
  const _ArchivedList({required this.items});

  final AsyncValue<List<SavingsGoal>> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return items.when(
      data: (List<SavingsGoal> list) {
        if (list.isEmpty) {
          return const Center(child: Text('暂无归档的储蓄计划'));
        }
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (BuildContext _, int __) =>
              const Divider(height: 1),
          itemBuilder: (BuildContext context, int index) =>
              _ArchivedTile(goal: list[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, StackTrace _) => Center(child: Text('加载失败：$e')),
    );
  }
}

/// 共用：进度摘要行（金额 + 百分比 + 截止日）。
Widget _progressSummary(BuildContext context, SavingsGoal goal) {
  final double progress = goal.targetMinor == 0
      ? 0
      : (goal.currentMinor / goal.targetMinor).clamp(0.0, 1.0);
  return Text(
    '${Money.fromMinor(goal.currentMinor).format()}'
    ' / ${Money.fromMinor(goal.targetMinor).format()}'
    '（${(progress * 100).toStringAsFixed(0)}%）'
    '${goal.deadlineAt == null ? '' : '  ·  截止 '
        '${DateFormat('yyyy-MM-dd').format(
        DateTime.fromMillisecondsSinceEpoch(
          goal.deadlineAt!,
          isUtc: true,
        ).toLocal(),
      )}'}',
    style: Theme.of(context).textTheme.bodySmall,
    overflow: TextOverflow.ellipsis,
  );
}

/// 归档 / 恢复（带轻提示）。
Future<void> _setArchived(
  BuildContext context,
  WidgetRef ref,
  SavingsGoal goal, {
  required bool archived,
}) async {
  try {
    await ref
        .read(savingsRepositoryProvider)
        .setArchived(goal.id, archived: archived);
  } on AppFailure catch (e) {
    if (context.mounted) showToast(context, e.message);
  }
}

/// 进行中的储蓄目标卡（参照小青账计划卡片布局）：
///
/// 行1：绿色竖条 + 模式名 + 右侧「编辑」胶囊；
/// 行2：头像 + 名称 + 模式胶囊 ｜ 右侧大字目标金额 + 已存入；
/// 行3：结束方式 / 重复周期 / 已执行次数三枚胶囊 + 日历键
/// （日历键点击弹底部弹窗：当月存入日历 + 执行进度摘要）。
/// 点卡片进计划详情页（逐期存入排期 / 日历 / 进度，管理动作在详情页）；
/// 横向留白交给宿主页面（记账页自身有页边距），纵向固定 8。
class SavingsGoalTile extends ConsumerWidget {
  const SavingsGoalTile({super.key, required this.goal, this.onTap});

  final SavingsGoal goal;

  /// 覆盖点击行为（详情页内复用本卡时传 no-op）；默认跳计划详情页。
  final VoidCallback? onTap;

  /// goal.mode 字符串反查枚举（历史数据 / 未知值 → null）。
  SavingsMode? get _mode {
    for (final SavingsMode m in SavingsMode.values) {
      if (m.name == goal.mode) return m;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final SavingsMode? mode = _mode;
    // 模式胶囊文案：按玩法归类（参照小青账「定额模式」绿胶囊）。
    final String? categoryLabel = switch (mode) {
      SavingsMode.monthly12 || SavingsMode.fixed => '定额模式',
      SavingsMode.flexible => '灵活模式',
      SavingsMode.countdown30 => '递减模式',
      SavingsMode.fixed365 ||
      SavingsMode.weekday ||
      SavingsMode.weeks52 ||
      SavingsMode.elastic =>
        '递增模式',
      null => null,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap ?? () => _openDetail(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _headerRow(context, mode),
              const SizedBox(height: 12),
              _bodyRow(context, categoryLabel),
              const SizedBox(height: 12),
              _metaRow(context, ref),
            ],
          ),
        ),
      ),
    );
  }

  /// 行1：绿色竖条 + 模式名 + 右侧「编辑」胶囊。
  Widget _headerRow(BuildContext context, SavingsMode? mode) {
    return Row(
      children: <Widget>[
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[AppPalette.sageMist, AppPalette.sageRibbon],
            ),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            mode?.label ?? '储蓄计划',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // 「编辑」胶囊：灰底圆角，点击跳转独立编辑页（名称 / 备注 / 快捷属性）。
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openEdit(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              '编辑',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  /// 行2：头像 + 名称 + 备注行 ｜ 大字目标金额 + 模式胶囊·已存入。
  Widget _bodyRow(BuildContext context, String? categoryLabel) {
    final ThemeData theme = Theme.of(context);
    final String? note =
        (goal.note == null || goal.note!.isEmpty) ? null : goal.note;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // 头像（🐱 圆角方块，与创建页一致）。
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppPalette.softGreen,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: const Text('🐱', style: TextStyle(fontSize: 26)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      goal.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (goal.isAchieved) ...<Widget>[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.emoji_events,
                      size: 16,
                      color: AppPalette.amberBright,
                    ),
                  ],
                ],
              ),
              // 备注行：名称左下方灰字（无备注不占位）。
              if (note != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              Money.fromMinor(goal.targetMinor).format(),
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            // 模式胶囊（递增/递减/定额）+ 已存入金额同行。
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (categoryLabel != null) ...<Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppPalette.softGreen,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      categoryLabel,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.deepGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  '已存入:${Money.fromMinor(goal.currentMinor).format(showSymbol: false)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// 行3：结束方式（绿底）/ 重复周期 / 已执行次数（描边）胶囊 + 日历键。
  /// 日历键点击 → 底部弹窗（当月存入日历 + 执行进度摘要）。
  Widget _metaRow(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final List<Widget> pills = <Widget>[
      if (goal.endNote != null) _softPill(goal.endNote!),
      if (goal.repeatCycle != null) _outlinePill(context, goal.repeatCycle!),
      _outlinePill(context, '已执行${goal.depositCount}次'),
    ];
    return Row(
      children: <Widget>[
        Expanded(
          child: Wrap(spacing: 8, runSpacing: 6, children: pills),
        ),
        // 日历键：点击弹底部弹窗，查看当月存入日历与排期进度。
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _showScheduleSheet(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  /// 日历键底部弹窗：模式名 + 执行进度摘要 + 当月存入日历。
  void _showScheduleSheet(BuildContext context, WidgetRef ref) {
    final SavingsMode? mode = _mode;
    // 排期总期数（灵活模式为 1 期任意金额）。
    final int totalPeriods = SavingsSchedule.build(goal).length;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // 标题行：绿竖条 + 模式名 ｜ 右侧已执行次数。
              Row(
                children: <Widget>[
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          AppPalette.sageMist,
                          AppPalette.sageRibbon,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mode?.label ?? '储蓄计划',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '已执行${goal.depositCount}/$totalPeriods次',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.deepGreen,
                    ),
                  ),
                ],
              ),
              if (goal.endNote != null || goal.repeatCycle != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  <String>[
                    if (goal.endNote != null) goal.endNote!,
                    if (goal.repeatCycle != null) goal.repeatCycle!,
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // 当月存入日历（台账实际存入日期绿圈标记）。
              Consumer(
                builder: (BuildContext ctx2, WidgetRef ref2, _) {
                  final List<SavingsDeposit> deposits =
                      ref2.watch(savingsDepositsProvider(goal.id)).value ??
                          const <SavingsDeposit>[];
                  return SavingsCalendarView(
                    deposits: deposits,
                    entries: SavingsSchedule.build(goal),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 绿底胶囊（结束方式，参照小青账「执行365次结束」）。
  Widget _softPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppPalette.softGreen,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppPalette.deepGreen,
        ),
      ),
    );
  }

  /// 描边胶囊（重复周期 / 已执行次数）。
  Widget _outlinePill(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  /// 卡片点击 → 计划详情页（逐期排期 / 日历 / 进度，管理动作在详情页）。
  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SavingsGoalDetailPage(goalId: goal.id),
      ),
    );
  }

  /// 「编辑」胶囊 → 独立编辑页（名称 / 备注 / 转入·入款账户，参照小青账）。
  void _openEdit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SavingsGoalEditPage(goal: goal),
      ),
    );
  }
}

/// 归档 Tab 单个目标：进度只读 + 恢复 / 删除。
class _ArchivedTile extends ConsumerWidget {
  const _ArchivedTile({required this.goal});

  final SavingsGoal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.archive_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: Text(
                  goal.name,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _progressSummary(context, goal),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton.icon(
                onPressed: () =>
                    _setArchived(context, ref, goal, archived: false),
                icon: const Icon(Icons.unarchive_outlined, size: 18),
                label: const Text('恢复'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error),
                onPressed: () async {
                  final bool ok = await confirmDelete(
                    context,
                    title: '删除目标「${goal.name}」？',
                  );
                  if (!ok) return;
                  try {
                    await ref.read(savingsRepositoryProvider).remove(goal.id);
                  } on AppFailure catch (e) {
                    if (context.mounted) showToast(context, e.message);
                  }
                },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('删除'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
