import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/date_utils.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/asset_stats_settings.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/date_field.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/module_list_scaffold.dart';
import '../data/reimbursement_repository.dart';
import '../providers/reimbursement_providers.dart';

/// 报销页：垫付登记 → 提交 → 已报销 → 已收款 的状态跟踪。
class ReimbursementPage extends ConsumerWidget {
  const ReimbursementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Reimbursement>> records =
        ref.watch(reimbursementListProvider);
    // 「账单列表按年月分组 · 报销账户」开关（在资产详情页的齿轮设置里配置）。
    final bool groupByMonth =
        ref.watch(assetStatsSettingsProvider).groupByMonthReimburse;

    // 账户 ID -> 名称，用于列表项展示「报销账户 / 收款账户」。
    final Map<String, String> accountNames = <String, String>{
      for (final Account a in ref.watch(accountsProvider).valueOrNull ??
          <Account>[])
        a.id: a.name,
    };

    return ModuleListScaffold<Reimbursement>(
      title: '报销',
      items: records,
      emptyHint: '还没有报销记录，点右下角新增',
      groupHeaderBuilder: groupByMonth ? _monthHeader : null,
      header: records.maybeWhen(
        data: (List<Reimbursement> list) => _PendingSummary(records: list),
        orElse: () => null,
      ),
      onCreate: () => _showEditor(context, ref),
      itemBuilder: (BuildContext context, Reimbursement r) => ListTile(
        leading: _StatusDot(status: r.status),
        title: Text(r.title),
        subtitle: Text(
          '${r.payer} 垫付 · ${Money.fromMinor(r.amountMinor).format()}'
          '${r.target == null || r.target!.isEmpty ? '' : ' · 向 ${r.target}'}'
          '${_accountSuffix(r, accountNames)}',
        ),
        trailing: PopupMenuButton<_MenuAction>(
          onSelected: (_MenuAction action) => _onMenu(context, ref, r, action),
          itemBuilder: (BuildContext _) => <PopupMenuEntry<_MenuAction>>[
            for (final ReimbursementStatus s in ReimbursementStatus.values)
              if (s != r.status)
                PopupMenuItem<_MenuAction>(
                  value: _MenuAction.status(s),
                  child: Text('标记为「${s.label}」'),
                ),
            const PopupMenuDivider(),
            const PopupMenuItem<_MenuAction>(
              value: _MenuAction.delete(),
              child: Text('删除'),
            ),
          ],
        ),
        onTap: () => _showEditor(context, ref, r),
      ),
    );
  }

  /// 列表已按 `occurredAt` 倒序，所以只在「月份变化」时插一条小标题。
  static Widget? _monthHeader(
    BuildContext context,
    Reimbursement item,
    Reimbursement? previous,
  ) {
    if (previous != null &&
        sameLocalMonth(previous.occurredAt, item.occurredAt)) {
      return null;
    }
    return _MonthHeader(label: ledgerMonthLabel(item.occurredAt));
  }

  /// 列表副标题追加「报销账户 / 收款账户」名称（为空则该段不显示）。
  static String _accountSuffix(
    Reimbursement r,
    Map<String, String> accountNames,
  ) {
    final String? from = r.accountId == null ? null : accountNames[r.accountId];
    final String? to =
        r.toAccountId == null ? null : accountNames[r.toAccountId];
    final List<String> parts = <String>[];
    if (from != null && from.isNotEmpty) parts.add('报销账户 $from');
    if (to != null && to.isNotEmpty) parts.add('收款账户 $to');
    return parts.isEmpty ? '' : ' · ${parts.join(' · ')}';
  }

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    Reimbursement record,
    _MenuAction action,
  ) async {
    final ReimbursementRepository repo =
        ref.read(reimbursementRepositoryProvider);
    try {
      if (action.status != null) {
        await repo.advanceStatus(record.id, action.status!);
        return;
      }
      final bool ok = await confirmDelete(
        context,
        title: '删除「${record.title}」？',
      );
      if (!ok) return;
      await repo.remove(record.id);
    } on AppFailure catch (e) {
      if (context.mounted) showToast(context, e.message);
    }
  }

  Future<void> _showEditor(
    BuildContext context,
    WidgetRef ref, [
    Reimbursement? record,
  ]) async {
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
    int? receivedAt = record?.receivedAt;
    String? accountId = record?.accountId;
    String? toAccountId = record?.toAccountId;

    // 账户下拉选项（报销账户 / 收款账户）。
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
                  value: accountId,
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
                  value: toAccountId,
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
                DateField(
                  label: '收款日期（可选）',
                  value: receivedAt == null
                      ? null
                      : DateTime.fromMillisecondsSinceEpoch(
                          receivedAt!,
                          isUtc: true,
                        ).toLocal(),
                  allowClear: true,
                  onChanged: (DateTime? v) => setState(
                    () => receivedAt = v?.toUtc().millisecondsSinceEpoch,
                  ),
                ),
                const FormGap(),
                SwitchListTile(
                  title: const Text('不计入收支'),
                  subtitle: const Text('个人垫款、与报销统计无关时开启，'
                      '不计入「待收回」汇总'),
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

    if (saved != true || !context.mounted) return;

    final double? amt = double.tryParse(amountController.text.trim());
    if (amt == null || amt <= 0) {
      showToast(context, '金额必须大于 0');
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
          receivedAt: receivedAt,
          note: note.isEmpty ? null : note,
          excludeFromStats: excludeFromStats,
          accountId: accountId,
          toAccountId: toAccountId,
        );
      } else {
        await repo.update(
          id: record.id,
          title: titleController.text,
          status: status,
          amountMinor: Money.fromDecimal(amt).minor,
          payer: payerController.text,
          occurredAt: occurredAt.toUtc().millisecondsSinceEpoch,
          target: target.isEmpty ? null : target,
          receivedAt: receivedAt,
          note: note.isEmpty ? null : note,
          excludeFromStats: excludeFromStats,
          accountId: accountId,
          toAccountId: toAccountId,
        );
      }
    } on AppFailure catch (e) {
      if (context.mounted) showToast(context, e.message);
    }
  }
}

/// 「按年月分组」时插入的月份小标题，如 `2026年9月`。
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceMd,
        AppDimens.spaceLg,
        AppDimens.spaceXs,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// 未收回金额汇总。报销最关心的就是「还有多少钱没回来」。
class _PendingSummary extends StatelessWidget {
  const _PendingSummary({required this.records});

  final List<Reimbursement> records;

  @override
  Widget build(BuildContext context) {
    int pendingMinor = 0;
    for (final Reimbursement r in records) {
      if (r.status != ReimbursementStatus.received && !r.excludeFromStats) {
        pendingMinor += r.amountMinor;
      }
    }
    return Card(
      margin: const EdgeInsets.all(12),
      child: ListTile(
        leading: const Icon(Icons.hourglass_bottom),
        title: const Text('待收回'),
        trailing: Text(
          Money.fromMinor(pendingMinor).format(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final ReimbursementStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (status) {
      ReimbursementStatus.pending => const Color(0xFF9E9E9E),
      ReimbursementStatus.submitted => const Color(0xFF1E88E5),
      ReimbursementStatus.reimbursed => const Color(0xFFFB8C00),
      ReimbursementStatus.received => const Color(0xFF43A047),
    };
    return Tooltip(
      message: status.label,
      child: Icon(Icons.circle, size: 14, color: color),
    );
  }
}

/// 列表行菜单动作。状态非空表示流转，否则表示删除。
class _MenuAction {
  const _MenuAction.status(this.status);

  const _MenuAction.delete() : status = null;

  final ReimbursementStatus? status;
}
