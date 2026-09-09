import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failures.dart';
import '../../../core/utils/date_utils.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/module_list_scaffold.dart';
import '../../categories/providers/categories_providers.dart';
import '../data/budget_repository.dart';
import '../providers/budget_providers.dart';

/// 预算页：总预算与分类预算的额度设置、实时用量与超支提醒。
class BudgetPage extends ConsumerWidget {
  const BudgetPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Budget>> budgets = ref.watch(budgetListProvider);

    return ModuleListScaffold<Budget>(
      title: '预算',
      items: budgets,
      emptyHint: '还没有设置预算，点右下角新增',
      onCreate: () => showBudgetEditor(context, ref),
      itemBuilder: (BuildContext context, Budget b) => _BudgetTile(budget: b),
    );
  }
}

/// 预算新增 / 编辑对话框。
///
/// 抽成顶层函数而非页面私有方法：列表行需要独立触发编辑，
/// 让子 Widget 反过来去调用父页面的私有方法会形成不必要的耦合。
Future<void> showBudgetEditor(
  BuildContext context,
  WidgetRef ref, [
  Budget? budget,
]) async {
  final List<Category> categories =
      ref.read(allCategoriesProvider).valueOrNull ?? const <Category>[];
  final List<Category> expenseCategories = categories
      .where((Category c) => c.type == CategoryType.expense)
      .toList(growable: false);

  final TextEditingController amountController = TextEditingController(
    text: budget != null
        ? Money.fromMinor(budget.amountMinor).decimal.toStringAsFixed(2)
        : '',
  );
  final TextEditingController thresholdController = TextEditingController(
    text: '${budget?.alertThreshold ?? 80}',
  );

  BudgetScope scope = budget?.scope ?? BudgetScope.overall;
  BudgetPeriod period = budget?.period ?? BudgetPeriod.monthly;
  String? categoryId = budget?.categoryId ??
      (expenseCategories.isEmpty ? null : expenseCategories.first.id);
  bool alertEnabled = budget?.alertEnabled ?? true;
  int year = budget?.year ?? DateTime.now().year;

  final bool? saved = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialog) => StatefulBuilder(
      builder: (BuildContext ctx, StateSetter setState) => AlertDialog(
        title: Text(budget == null ? '新增预算' : '编辑预算'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              EnumDropdown<BudgetScope>(
                label: '范围',
                value: scope,
                values: BudgetScope.values,
                labelOf: (BudgetScope s) => s.label,
                onChanged: (BudgetScope s) => setState(() => scope = s),
              ),
              if (scope == BudgetScope.category) ...<Widget>[
                const FormGap(),
                DropdownButtonFormField<String>(
                  value: categoryId,
                  decoration: const InputDecoration(labelText: '分类'),
                  items: <DropdownMenuItem<String>>[
                    for (final Category c in expenseCategories)
                      DropdownMenuItem<String>(
                        value: c.id,
                        child: Text(c.name),
                      ),
                  ],
                  onChanged: (String? v) => setState(() => categoryId = v),
                ),
              ],
              const FormGap(),
              EnumDropdown<BudgetPeriod>(
                label: '周期',
                value: period,
                values: BudgetPeriod.values,
                labelOf: (BudgetPeriod p) => p.label,
                onChanged: (BudgetPeriod p) => setState(() => period = p),
              ),
              const FormGap(),
              AmountField(controller: amountController, label: '预算额度'),
              const FormGap(),
              IntField(
                controller: thresholdController,
                label: '提醒阈值',
                suffixText: '%',
                helperText: '用掉该比例时高亮提示',
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('启用超支提醒'),
                value: alertEnabled,
                onChanged: (bool v) => setState(() => alertEnabled = v),
              ),
              Row(
                children: <Widget>[
                  const Text('年份'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() => year -= 1),
                  ),
                  Text('$year'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(() => year += 1),
                  ),
                ],
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

  final double? amount = double.tryParse(amountController.text.trim());
  if (amount == null || amount <= 0) {
    showToast(context, '预算额度必须大于 0');
    return;
  }
  final int threshold = int.tryParse(thresholdController.text.trim()) ?? 80;

  // 新建时默认落在当前周期，省掉用户手填「第几个月 / 第几季度」。
  final int periodIndex = budget?.periodIndex ??
      currentPeriodIndex(
        monthly: period == BudgetPeriod.monthly,
        quarterly: period == BudgetPeriod.quarterly,
      );

  final BudgetRepository repo = ref.read(budgetRepositoryProvider);
  try {
    if (budget == null) {
      await repo.add(
        bookId: ref.read(currentBookIdProvider),
        scope: scope,
        period: period,
        amountMinor: Money.fromDecimal(amount).minor,
        year: year,
        periodIndex: periodIndex,
        categoryId: categoryId,
        alertEnabled: alertEnabled,
        alertThreshold: threshold,
      );
    } else {
      await repo.update(
        id: budget.id,
        scope: scope,
        period: period,
        amountMinor: Money.fromDecimal(amount).minor,
        year: year,
        periodIndex: periodIndex,
        categoryId: categoryId,
        alertEnabled: alertEnabled,
        alertThreshold: threshold,
      );
    }
  } on AppFailure catch (e) {
    if (context.mounted) showToast(context, e.message);
  }
}

/// 单条预算：额度 / 已用 / 剩余 + 超支高亮。
class _BudgetTile extends ConsumerWidget {
  const _BudgetTile({required this.budget});

  final Budget budget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BudgetRepository repo = ref.watch(budgetRepositoryProvider);
    final ({int end, int start}) range = repo.rangeOf(budget);
    final AsyncValue<int> spent = ref.watch(
      budgetSpentProvider(
        (
          start: range.start,
          end: range.end,
          categoryId: budget.categoryId,
        ),
      ),
    );

    final ThemeData theme = Theme.of(context);
    final int spentMinor = spent.valueOrNull ?? 0;
    final double ratio =
        budget.amountMinor == 0 ? 0 : spentMinor / budget.amountMinor;
    final bool overspent = spentMinor > budget.amountMinor;
    final bool nearLimit = budget.alertEnabled &&
        !overspent &&
        ratio * 100 >= budget.alertThreshold;

    final Color barColor = overspent
        ? const Color(0xFFE53935)
        : nearLimit
            ? const Color(0xFFFB8C00)
            : theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _title(ref),
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (overspent)
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: Color(0xFFE53935),
                )
              else if (nearLimit)
                const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Color(0xFFFB8C00),
                ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () => showBudgetEditor(context, ref, budget),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () async {
                  final bool ok = await confirmDelete(
                    context,
                    title: '删除这条预算？',
                  );
                  if (!ok) return;
                  try {
                    await ref.read(budgetRepositoryProvider).remove(budget.id);
                  } on AppFailure catch (e) {
                    if (context.mounted) showToast(context, e.message);
                  }
                },
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 8,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '已用 ${Money.fromMinor(spentMinor).format()}'
            ' / ${Money.fromMinor(budget.amountMinor).format()}'
            '  ·  ${_remainLabel(spentMinor, overspent)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: overspent ? const Color(0xFFE53935) : null,
            ),
          ),
        ],
      ),
    );
  }

  String _remainLabel(int spentMinor, bool overspent) {
    final int diff = (budget.amountMinor - spentMinor).abs();
    final String amount = Money.fromMinor(diff).format();
    return overspent ? '超支 $amount' : '剩余 $amount';
  }

  String _title(WidgetRef ref) {
    final String periodLabel = switch (budget.period) {
      BudgetPeriod.monthly => '${budget.year} 年 ${budget.periodIndex} 月',
      BudgetPeriod.quarterly => '${budget.year} 年 Q${budget.periodIndex}',
      BudgetPeriod.yearly => '${budget.year} 年',
    };
    if (budget.scope == BudgetScope.overall) return '总预算 · $periodLabel';

    final List<Category> categories =
        ref.watch(allCategoriesProvider).valueOrNull ?? const <Category>[];
    final Iterable<Category> matched =
        categories.where((Category c) => c.id == budget.categoryId);
    return '${matched.isEmpty ? '未知分类' : matched.first.name} · $periodLabel';
  }
}
