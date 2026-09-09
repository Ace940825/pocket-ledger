import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/module_list_scaffold.dart';
import '../providers/installment_providers.dart';
import 'installment_page.dart';

/// 分期详情：逐期勾选还款，逾期未还高亮提醒。
///
/// 只接收 [planId] 而不接收整个 plan 对象：详情页因此可以被深链直接打开，
/// 且数据来自数据库流，勾选后进度条自动刷新，不需要回传状态。
class InstallmentDetailPage extends ConsumerWidget {
  const InstallmentDetailPage({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<InstallmentPlan> planAsync =
        ref.watch(installmentPlanProvider(planId));
    final AsyncValue<List<InstallmentPeriod>> periods =
        ref.watch(installmentPeriodsProvider(planId));
    final int nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;

    final String title = planAsync.valueOrNull?.title ?? '分期详情';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: <Widget>[
          IconButton(
            tooltip: '删除计划',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final bool ok = await confirmDelete(
                context,
                title: '删除计划「$title」？',
                content: '该计划下的所有期数明细也会一并删除。',
              );
              if (!ok || !context.mounted) return;
              try {
                await ref
                    .read(installmentRepositoryProvider)
                    .removePlan(planId);
                if (context.mounted) Navigator.of(context).pop();
              } on AppFailure catch (e) {
                if (context.mounted) showToast(context, e.message);
              }
            },
          ),
        ],
      ),
      body: periods.when(
        data: (List<InstallmentPeriod> list) {
          if (list.isEmpty) {
            return const Center(child: Text('暂无期数明细'));
          }

          int remainingMinor = 0;
          for (final InstallmentPeriod p in list) {
            if (p.paidAt == null) remainingMinor += p.amountMinor;
          }
          final int paidCount =
              list.where((InstallmentPeriod p) => p.paidAt != null).length;
          final int fee = planAsync.valueOrNull?.feePerPeriodMinor ?? 0;

          return ListView.separated(
            itemCount: list.length + 1,
            separatorBuilder: (BuildContext _, int __) =>
                const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                return Card(
                  margin: const EdgeInsets.all(12),
                  child: ListTile(
                    title: const Text('剩余待还'),
                    subtitle: Text(
                      '$paidCount/${list.length} 期已还'
                      '${fee > 0 ? ' · 每期含手续费 '
                          '${Money.fromMinor(fee).format()}' : ''}',
                    ),
                    trailing: Text(
                      Money.fromMinor(remainingMinor).format(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                );
              }

              final InstallmentPeriod p = list[index - 1];
              final bool paid = p.paidAt != null;
              final bool overdue = !paid && p.dueAt < nowMs;

              return CheckboxListTile(
                value: paid,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (bool? v) async {
                  try {
                    await ref
                        .read(installmentRepositoryProvider)
                        .togglePeriodPaid(p.id, paid: v ?? false);
                  } on AppFailure catch (e) {
                    if (context.mounted) showToast(context, e.message);
                  }
                },
                title: Text('第 ${p.periodIndex} 期'),
                subtitle: Text(
                  '到期 ${formatDueDate(p.dueAt)}${overdue ? ' · 已逾期' : ''}',
                  style: overdue
                      ? const TextStyle(color: Color(0xFFE53935))
                      : null,
                ),
                secondary: Text(
                  Money.fromMinor(p.amountMinor).format(),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(child: Text('加载失败：$e')),
      ),
    );
  }
}
