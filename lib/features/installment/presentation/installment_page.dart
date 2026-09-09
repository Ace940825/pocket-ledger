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
import '../providers/installment_providers.dart';
import 'installment_detail_page.dart';

/// 分期页：计划列表与还款进度。
class InstallmentPage extends ConsumerWidget {
  const InstallmentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<InstallmentPlan>> plans =
        ref.watch(installmentPlansProvider);

    return ModuleListScaffold<InstallmentPlan>(
      title: '分期',
      items: plans,
      emptyHint: '还没有分期计划，点右下角新增',
      onCreate: () => _showCreate(context, ref),
      itemBuilder: (BuildContext context, InstallmentPlan p) {
        final double progress =
            p.totalPeriods == 0 ? 0 : p.paidPeriods / p.totalPeriods;
        final int perPeriod =
            p.totalPeriods == 0 ? 0 : p.totalMinor ~/ p.totalPeriods;
        return ListTile(
          title: Text(p.title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 4),
              Text(
                '${Money.fromMinor(p.totalMinor).format()} · '
                '${p.totalPeriods} 期 · 每期约 '
                '${Money.fromMinor(perPeriod + p.feePerPeriodMinor).format()}',
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                ),
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('${p.paidPeriods}/${p.totalPeriods}'),
              if (p.isFinished)
                const Icon(
                  Icons.check_circle,
                  size: 16,
                  color: Color(0xFF43A047),
                ),
            ],
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext _) => InstallmentDetailPage(planId: p.id),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreate(BuildContext context, WidgetRef ref) async {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController totalController = TextEditingController();
    final TextEditingController periodsController =
        TextEditingController(text: '12');
    final TextEditingController feeController =
        TextEditingController(text: '0');
    final TextEditingController noteController = TextEditingController();
    DateTime firstDue = DateTime.now();

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setState) => AlertDialog(
          title: const Text('新增分期计划'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: '名称（如 iPhone 分期）'),
                  autofocus: true,
                ),
                const FormGap(),
                AmountField(controller: totalController, label: '总金额'),
                const FormGap(),
                IntField(
                  controller: periodsController,
                  label: '期数',
                  suffixText: '期',
                ),
                const FormGap(),
                AmountField(
                  controller: feeController,
                  label: '每期手续费',
                  helperText: '无手续费填 0',
                ),
                const FormGap(),
                DateField(
                  label: '首期还款日',
                  value: firstDue,
                  onChanged: (DateTime? v) {
                    if (v != null) setState(() => firstDue = v);
                  },
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
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !context.mounted) return;

    final double? total = double.tryParse(totalController.text.trim());
    final int? periods = int.tryParse(periodsController.text.trim());
    final double fee = double.tryParse(feeController.text.trim()) ?? 0;
    if (total == null || total <= 0) {
      showToast(context, '总金额必须大于 0');
      return;
    }
    if (periods == null || periods <= 0) {
      showToast(context, '期数必须为正整数');
      return;
    }

    final String note = noteController.text.trim();
    try {
      await ref.read(installmentRepositoryProvider).addPlan(
            bookId: ref.read(currentBookIdProvider),
            title: titleController.text,
            totalMinor: Money.fromDecimal(total).minor,
            totalPeriods: periods,
            feePerPeriodMinor: Money.fromDecimal(fee).minor,
            firstDueAt: firstDue.toUtc().millisecondsSinceEpoch,
            note: note.isEmpty ? null : note,
          );
    } on AppFailure catch (e) {
      if (context.mounted) showToast(context, e.message);
    }
  }
}

/// 供详情页复用的日期格式化。
String formatDueDate(int msUtc) => DateFormat('yyyy-MM-dd')
    .format(DateTime.fromMillisecondsSinceEpoch(msUtc, isUtc: true).toLocal());
