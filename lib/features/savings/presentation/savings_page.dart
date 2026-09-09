import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/date_field.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/module_list_scaffold.dart';
import '../data/savings_repository.dart';
import '../providers/savings_providers.dart';

/// 储蓄页：多目标进度跟踪 + 快捷存取。
class SavingsPage extends ConsumerWidget {
  const SavingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SavingsGoal>> goals =
        ref.watch(savingsListProvider);

    return ModuleListScaffold<SavingsGoal>(
      title: '储蓄',
      items: goals,
      emptyHint: '还没有储蓄目标，点右下角新增',
      onCreate: () => _showEditor(context, ref),
      itemBuilder: (BuildContext context, SavingsGoal g) =>
          _GoalTile(goal: g),
    );
  }

  Future<void> _showEditor(
    BuildContext context,
    WidgetRef ref, [
    SavingsGoal? goal,
  ]) async {
    final TextEditingController nameController =
        TextEditingController(text: goal?.name ?? '');
    final TextEditingController targetController = TextEditingController(
      text: goal != null
          ? Money.fromMinor(goal.targetMinor).decimal.toStringAsFixed(2)
          : '',
    );
    final TextEditingController currentController = TextEditingController(
      text: goal != null
          ? Money.fromMinor(goal.currentMinor).decimal.toStringAsFixed(2)
          : '0.00',
    );
    final TextEditingController noteController =
        TextEditingController(text: goal?.note ?? '');
    int? deadlineAt = goal?.deadlineAt;

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setState) => AlertDialog(
          title: Text(goal == null ? '新增储蓄目标' : '编辑储蓄目标'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '目标名称'),
                  autofocus: true,
                ),
                const FormGap(),
                AmountField(
                  controller: targetController,
                  label: '目标金额',
                ),
                const FormGap(),
                AmountField(
                  controller: currentController,
                  label: '已存金额',
                ),
                const FormGap(),
                DateField(
                  label: '截止日期（可选）',
                  value: deadlineAt == null
                      ? null
                      : DateTime.fromMillisecondsSinceEpoch(
                          deadlineAt!,
                          isUtc: true,
                        ).toLocal(),
                  allowClear: true,
                  onChanged: (DateTime? v) => setState(
                    () => deadlineAt = v?.toUtc().millisecondsSinceEpoch,
                  ),
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

    if (saved != true || !context.mounted) return;

    final double? target = double.tryParse(targetController.text.trim());
    final double current =
        double.tryParse(currentController.text.trim()) ?? 0;
    if (target == null || target <= 0) {
      showToast(context, '目标金额必须大于 0');
      return;
    }

    final SavingsRepository repo = ref.read(savingsRepositoryProvider);
    final String note = noteController.text.trim();
    try {
      if (goal == null) {
        await repo.add(
          bookId: ref.read(currentBookIdProvider),
          name: nameController.text,
          targetMinor: Money.fromDecimal(target).minor,
          currentMinor: Money.fromDecimal(current).minor,
          deadlineAt: deadlineAt,
          note: note.isEmpty ? null : note,
        );
      } else {
        await repo.update(
          id: goal.id,
          name: nameController.text,
          targetMinor: Money.fromDecimal(target).minor,
          currentMinor: Money.fromDecimal(current).minor,
          accountId: goal.accountId,
          deadlineAt: deadlineAt,
          note: note.isEmpty ? null : note,
        );
      }
    } on AppFailure catch (e) {
      if (context.mounted) showToast(context, e.message);
    }
  }
}

/// 单个目标：进度条 + 存入 / 取出 / 编辑 / 删除。
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
                    color: Color(0xFFFFA000),
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
                child: Text(
                  '${Money.fromMinor(goal.currentMinor).format()}'
                  ' / ${Money.fromMinor(goal.targetMinor).format()}'
                  '${goal.deadlineAt == null ? '' : '  ·  截止 '
                      '${DateFormat('yyyy-MM-dd').format(
                        DateTime.fromMillisecondsSinceEpoch(
                          goal.deadlineAt!,
                          isUtc: true,
                        ).toLocal(),
                      )}'}',
                  style: theme.textTheme.bodySmall,
                ),
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
