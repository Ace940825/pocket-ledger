import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/module_list_scaffold.dart'
    show confirmDelete, showToast;
import '../data/savings_repository.dart';
import '../providers/savings_providers.dart';
import 'savings_mode_create_page.dart';
import 'savings_mode_sheet.dart';
import 'savings_modes.dart';

/// 储蓄页：「计划 / 归档」双 Tab。
/// - 计划：顶部内嵌「存钱模式选择」双列九宫格（点卡直接进该模式创建页），
///   下方为进行中的储蓄目标列表（含达标）；
/// - 归档：已停止的计划，可恢复或删除。
class SavingsPage extends ConsumerWidget {
  const SavingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SavingsGoal>> goals = ref.watch(savingsListProvider);
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
              items: goals,
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

/// 计划 Tab：内嵌「存钱模式选择」九宫格 + 计划列表。
class _PlanTab extends ConsumerWidget {
  const _PlanTab({required this.items, required this.onModeTap});

  final AsyncValue<List<SavingsGoal>> items;
  final ValueChanged<SavingsMode> onModeTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return items.when(
      data: (List<SavingsGoal> list) {
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
            // 下方：我的计划列表。
            if (list.isNotEmpty) ...<Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '我的计划',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const Divider(height: 1),
              for (final SavingsGoal g in list) _GoalTile(goal: g),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('还没有储蓄计划，从上方选择模式开始')),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, StackTrace _) => Center(child: Text('加载失败：$e')),
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

/// 计划 Tab 单个目标：进度条 + 存入 / 取出 / 归档 / 删除。
class _GoalTile extends ConsumerWidget {
  const _GoalTile({required this.goal});

  final SavingsGoal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double progress = goal.targetMinor == 0
        ? 0
        : (goal.currentMinor / goal.targetMinor).clamp(0.0, 1.0);
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  goal.name,
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (goal.isAchieved)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.emoji_events,
                    size: 18,
                    color: AppColors.amberBright,
                  ),
                ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: _progressSummary(context, goal),
              ),
              IconButton(
                tooltip: '存入',
                icon: const Icon(Icons.add_circle_outline, size: 20),
                onPressed: () => _showDeposit(context, ref, sign: 1),
              ),
              IconButton(
                tooltip: '取出',
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                onPressed: () => _showDeposit(context, ref, sign: -1),
              ),
              IconButton(
                tooltip: '归档',
                icon: const Icon(Icons.archive_outlined, size: 20),
                onPressed: () =>
                    _setArchived(context, ref, goal, archived: true),
              ),
              IconButton(
                tooltip: '删除',
                icon: const Icon(Icons.delete_outline, size: 20),
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showDeposit(
    BuildContext context,
    WidgetRef ref, {
    required int sign,
  }) async {
    final TextEditingController controller = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: Text(sign > 0 ? '存入「${goal.name}」' : '从「${goal.name}」取出'),
        content: AmountField(controller: controller),
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
    if (ok != true || !context.mounted) return;

    final double? amt = double.tryParse(controller.text.trim());
    if (amt == null || amt <= 0) {
      showToast(context, '金额必须大于 0');
      return;
    }
    try {
      await ref
          .read(savingsRepositoryProvider)
          .deposit(goal.id, sign * Money.fromDecimal(amt).minor);
    } on AppFailure catch (e) {
      if (context.mounted) showToast(context, e.message);
    }
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
