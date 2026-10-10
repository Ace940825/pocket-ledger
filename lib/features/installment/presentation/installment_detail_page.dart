import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/module_list_scaffold.dart';
import '../../../theme/app_colors.dart';
import '../../../shared/widgets/section_header.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../record/presentation/record_sheet.dart';
import '../../record/record_tab.dart';
import '../domain/fee_utils.dart';
import '../domain/repeat_rule.dart';
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
      appBar: AppBar(title: Text(title)),
      body: periods.when(
        data: (List<InstallmentPeriod> list) {
          if (list.isEmpty) {
            return const Center(child: Text('暂无期数明细'));
          }

          // 双口径（2026-10-09）：「已入账」按期次是否已自动入账
          // （transactionId 非空）；「已逾期」按还款意义上的到期未还
          // （paidAt 为空）。勾选已还与自动入账互相独立。
          int remainingMinor = 0;
          for (final InstallmentPeriod p in list) {
            if (p.transactionId == null) remainingMinor += p.amountMinor;
          }
          final int paidCount = list
              .where((InstallmentPeriod p) => p.transactionId != null)
              .length;
          final InstallmentPlan? plan = planAsync.valueOrNull;
          final List<int> fees =
              plan == null ? const <int>[] : feeByPeriodOf(plan);

          // 顶部卡片派生数据：总利息、已入账本金/利息、下次入账日。
          final int totalFee = fees.fold<int>(0, (int s, int v) => s + v);
          int paidPrincipal = 0;
          int paidFee = 0;
          int? nextDueAt;
          bool hasOverdue = false;
          for (int i = 0; i < list.length; i++) {
            final InstallmentPeriod p = list[i];
            final int fee = i < fees.length ? fees[i] : 0;
            if (p.transactionId != null) {
              paidFee += fee;
              paidPrincipal += p.amountMinor - fee;
            } else {
              if (nextDueAt == null || p.dueAt < nextDueAt) {
                nextDueAt = p.dueAt;
              }
            }
            if (p.paidAt == null && p.dueAt < nowMs) hasOverdue = true;
          }
          final List<Account> accounts =
              ref.watch(accountsProvider).valueOrNull ?? const <Account>[];
          Account? planAccount;
          for (final Account a in accounts) {
            if (a.id == plan?.accountId) {
              planAccount = a;
              break;
            }
          }
          final InstallmentRepeatRule? rule = plan == null
              ? null
              : InstallmentRepeatRule.fromJsonString(plan.repeatRule);
          final int fallbackDay = plan == null
              ? 1
              : DateTime.fromMillisecondsSinceEpoch(plan.firstDueAt).day;
          final String repeatLabel =
              rule?.displayLabel(fallbackDay: fallbackDay) ?? '每月';

          // ──「结清 / 退款」入口派生数据（2026-10-10）──
          // 已入账订单（transactionId 非空）→ 退款入口预关联多笔原账单，
  // 退款金额自动 = 各笔合计（本金 + 利息）；
          // 剩余未还本金（未还期次金额 − 对应期次利息）→ 结清订单金额。
          final bool settled = plan?.isFinished ?? false;
          final List<String> postedTxnIds = <String>[
            for (final InstallmentPeriod p in list)
              if (p.transactionId != null) p.transactionId!,
          ];
          int remainingPrincipal = 0;
          for (final InstallmentPeriod p in list) {
            if (p.paidAt != null) continue;
            final int idx = p.periodIndex - 1;
            final int fee = idx >= 0 && idx < fees.length ? fees[idx] : 0;
            remainingPrincipal += p.amountMinor - fee;
          }
          final bool canSettle = plan != null &&
              !settled &&
              remainingPrincipal > 0 &&
              plan.accountId != null &&
              plan.accountId!.isNotEmpty;

          return ListView.separated(
            itemCount: list.length + 1,
            separatorBuilder: (BuildContext _, int __) =>
                const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                return Column(
                  children: <Widget>[
                    _PlanHeaderCard(
                      plan: plan,
                      repeatLabel: repeatLabel,
                      accountName: planAccount?.name,
                      paidCount: paidCount,
                      totalCount: list.length,
                      totalFee: totalFee,
                      remainingMinor: remainingMinor,
                      nextDueAt: nextDueAt,
                      hasOverdue: hasOverdue,
                      onEdit: plan == null
                          ? null
                          : () => _editPlan(context, ref, plan),
                      onSettle: canSettle
                          ? () => _settlePlanEarly(
                              context, ref, plan, remainingPrincipal)
                          : null,
                      onRefund: plan == null || postedTxnIds.isEmpty
                          ? null
                          : () => _refundPostedOrders(
                              context, ref, plan, postedTxnIds),
                    ),
                    _PlanProgressCard(
                      paidCount: paidCount,
                      totalCount: list.length,
                      paidPrincipal: paidPrincipal,
                      paidFee: paidFee,
                      remainingMinor: remainingMinor,
                    ),
                  ],
                );
              }

              final InstallmentPeriod p = list[index - 1];
              final bool paid = p.paidAt != null;
              final bool posted = p.transactionId != null;
              final bool overdue = !paid && p.dueAt < nowMs;
              // 已结束（提前结清 / 完结）的计划：「已还」勾选置灰不可点击。
              final bool locked = settled;

              return CheckboxListTile(
                value: paid,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: locked
                    ? null
                    : (bool? v) async {
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
                  '到期 ${formatDueDate(p.dueAt)}'
                  '${posted ? ' · 已入账' : ''}'
                  '${overdue ? ' · 已逾期' : ''}'
                  '${locked ? ' · 已结束' : ''}',
                  style: overdue
                      ? TextStyle(color: Theme.of(context).colorScheme.error)
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

  /// 编辑计划元信息（标题 / 关联账户）。
  ///
  /// 金额、期数、利息牵连已生成的期次明细与已还进度，不在此开放；
  /// 需要调整时删除计划后重建。
  Future<void> _editPlan(
    BuildContext context,
    WidgetRef ref,
    InstallmentPlan plan,
  ) async {
    final TextEditingController titleController =
        TextEditingController(text: plan.title);
    String? accountId = plan.accountId;
    // 分期付款账户只能是负债账户（2026-10-09 口径）：编辑只列负债方向账户。
    // 兼容旧数据：当前关联账户不在负债口径内时保留该项，避免 Dropdown 断言。
    final List<Account> allAccounts =
        ref.read(accountsProvider).valueOrNull ?? const <Account>[];
    final List<Account> liabilityAccounts = allAccounts
        .where((Account a) => a.type.isLiabilitySide)
        .toList(growable: false);
    Account? legacySelected;
    if (accountId != null) {
      for (final Account a in allAccounts) {
        if (a.id == accountId) legacySelected = a;
      }
    }
    // 可增长副本：旧数据当前关联账户不在负债口径内时补进可选项。
    // 用 final 局部别名让闭包内稳定收窄（可变变量无法提升类型）。
    final List<Account> accountItems = List<Account>.of(liabilityAccounts);
    final Account? legacy = legacySelected;
    if (legacy != null &&
        !liabilityAccounts.any((Account a) => a.id == legacy.id)) {
      accountItems.add(legacy);
    }

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setDialogState) => AlertDialog(
          title: const Text('编辑分期'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: '分期名称'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: accountId,
                decoration: const InputDecoration(labelText: '负债账户'),
                hint: const Text('请选择负债账户'),
                items: <DropdownMenuItem<String?>>[
                  // 分期付款账户只能是负债账户：不提供「不关联」选项
                  for (final Account a in accountItems)
                    DropdownMenuItem<String?>(value: a.id, child: Text(a.name)),
                ],
                onChanged: (String? v) => setDialogState(() => accountId = v),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    try {
      await ref
          .read(installmentRepositoryProvider)
          .updatePlanMeta(
            planId: plan.id,
            title: titleController.text,
            accountId: accountId,
          );
    } on AppFailure catch (e) {
      if (context.mounted) showToast(context, e.message);
    }
  }

  /// 提前结清：确认后为剩余未还本金生成一笔结清订单（计入下个账单
  /// 一次性还清），计划随即转为已结束、「已还」勾选置灰。
  Future<void> _settlePlanEarly(
    BuildContext context,
    WidgetRef ref,
    InstallmentPlan plan,
    int remainingPrincipal,
  ) async {
    final bool ok = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialog) => AlertDialog(
            title: Text('提前结清「${plan.title}」？'),
            content: Text(
              '将为剩余未还本金 ${Money.fromMinor(remainingPrincipal).format()} '
              '生成一笔结清订单，计入下个账单后一次性还清；'
              '未到期期次的利息不再收取，计划随即转为已结束。',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialog).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialog).pop(true),
                child: const Text('结清'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok || !context.mounted) return;
    try {
      await ref
          .read(installmentRepositoryProvider)
          .settlePlanEarly(plan.id);
      if (context.mounted) showToast(context, '已提前结清');
    } on AppFailure catch (e) {
      if (context.mounted) showToast(context, e.message);
    } catch (_) {
      // 数据库等未知异常：给用户可见反馈，绝不静默吞掉。
      if (context.mounted) showToast(context, '结清失败，请重试');
    }
  }

  /// 退款：跳转记一笔退款 Tab，预关联全部已入账订单（多笔原账单），
  /// 退款金额自动 = 各笔合计（已入账订单本金 + 利息）。
  ///
  /// 退款真正落库后（[openRecordSheet] 的 onSaved 回调）把计划转为
  /// 已结束：未还期次保持未还、不再入账，列表移入「已结束」Tab。
  void _refundPostedOrders(
    BuildContext context,
    WidgetRef ref,
    InstallmentPlan plan,
    List<String> postedTxnIds,
  ) {
    openRecordSheet(
      context,
      initialTab: RecordTab.refund,
      refundSourceIds: postedTxnIds,
      onSaved: () =>
          ref.read(installmentRepositoryProvider).markPlanRefunded(plan.id),
    );
  }
}

/// 顶部「计划概要」卡：对照小青账详情头布局——
/// 状态徽章 + 标题 / 周期副行 / 应还总额（含息）/ 待入账 / 下次入账时间 / 底部胶囊。
class _PlanHeaderCard extends StatelessWidget {
  const _PlanHeaderCard({
    required this.plan,
    required this.repeatLabel,
    required this.accountName,
    required this.paidCount,
    required this.totalCount,
    required this.totalFee,
    required this.remainingMinor,
    required this.nextDueAt,
    required this.hasOverdue,
    this.onEdit,
    this.onSettle,
    this.onRefund,
  });

  final InstallmentPlan? plan;
  final String repeatLabel;
  final String? accountName;
  final int paidCount;
  final int totalCount;
  final int totalFee;
  final int remainingMinor;
  final int? nextDueAt;
  final bool hasOverdue;
  final VoidCallback? onEdit;

  /// 「结清」键：为剩余未还本金生成结清订单并结束计划（无待结清时隐藏）。
  final VoidCallback? onSettle;

  /// 「退款」键：跳退款页并预填已入账订单本息合计（无已入账订单时隐藏）。
  final VoidCallback? onRefund;

  @override
  Widget build(BuildContext context) {
    final InstallmentPlan? p = plan;
    if (p == null) return const SizedBox.shrink();
    final TextTheme t = Theme.of(context).textTheme;
    // 已结束 = 计划完结标记（提前结清 / 左滑完结 / 全部勾还），与列表页同口径；
    // 不能只看已入账期数——提前结清后未到期期次永不入账。
    final bool finished =
        p.isFinished || (totalCount > 0 && paidCount >= totalCount);
    final String statusLabel = finished
        ? '已结束'
        : hasOverdue
            ? '有逾期'
            : '进行中';
    final Color statusColor = finished
        ? AppPalette.textTertiary
        : hasOverdue
            ? AppPalette.danger
            : AppPalette.primary;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppPalette.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: t.bodySmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                ),
                if (onEdit != null)
                  _HeaderPill(
                    label: '编辑',
                    color: AppPalette.textPrimary,
                    surface: true,
                    onTap: onEdit!,
                  ),
                if (onRefund != null)
                  _HeaderPill(
                    label: '退款',
                    color: AppPalette.info,
                    onTap: onRefund!,
                  ),
                if (onSettle != null)
                  _HeaderPill(
                    label: '结清',
                    color: AppPalette.primary,
                    onTap: onSettle!,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              <String>[
                repeatLabel,
                '${p.totalPeriods} 期',
                if (accountName != null) accountName!,
              ].join(' · '),
              style: t.bodySmall?.copyWith(color: AppPalette.textSecondary),
            ),
            const SizedBox(height: 8),
            _amountRow(
              context,
              '应还总额',
              Money.fromMinor(p.totalMinor + totalFee).format(),
              valueColor: totalFee > 0 ? AppPalette.danger : null,
              suffix: totalFee > 0
                  ? ' 含息 ${Money.fromMinor(totalFee).format()}'
                  : null,
            ),
            const SizedBox(height: 6),
            _amountRow(
              context,
              '待入账',
              Money.fromMinor(remainingMinor).format(),
            ),
            if (nextDueAt != null) ...<Widget>[
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Text(
                    '预计下次入账',
                    style: t.bodySmall
                        ?.copyWith(color: AppPalette.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatDueDate(nextDueAt!),
                    style: t.bodySmall?.copyWith(
                      color: hasOverdue
                          ? AppPalette.danger
                          : AppPalette.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (hasOverdue) ...<Widget>[
                    const SizedBox(width: 6),
                    Text(
                      '已逾期',
                      style: t.bodySmall?.copyWith(
                        color: AppPalette.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                _chip(context, repeatLabel),
                _chip(context, '${p.totalPeriods}期', highlight: true),
                _chip(context, '已入账 $paidCount 期'),
                if (accountName != null) _chip(context, accountName!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
    String? suffix,
  }) {
    final TextTheme t = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(
          label,
          style: t.bodySmall?.copyWith(color: AppPalette.textSecondary),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: t.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppPalette.textPrimary,
          ),
        ),
        if (suffix != null)
          Text(
            suffix,
            style: t.bodySmall?.copyWith(color: AppPalette.textTertiary),
          ),
      ],
    );
  }

  Widget _chip(BuildContext context, String label, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: highlight ? AppPalette.sage50 : AppPalette.paper2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight ? AppPalette.sage200 : AppPalette.chipLine,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: highlight ? AppPalette.sage700 : AppPalette.textSecondary,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
            ),
      ),
    );
  }
}

/// 详情头右上操作胶囊（结清 / 退款 / 编辑）：浅色底 + 主题色文字，
/// 与原「编辑」胶囊同尺寸，只是颜色随动作区分。
class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.label,
    required this.color,
    required this.onTap,
    this.surface = false,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  /// true 时用中性浅灰底（原「编辑」样式），false 用动作色淡底。
  final bool surface;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: surface
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
        ),
      ),
    );
  }
}

/// 顶部「入账进度」卡（紧凑版）：已入账期数 + 已入账本金/利息 +
/// 待入账金额 + 进度条。
class _PlanProgressCard extends StatelessWidget {
  const _PlanProgressCard({
    required this.paidCount,
    required this.totalCount,
    required this.paidPrincipal,
    required this.paidFee,
    required this.remainingMinor,
  });

  final int paidCount;
  final int totalCount;
  final int paidPrincipal;
  final int paidFee;
  final int remainingMinor;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppPalette.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SectionHeader(
              title: '入账进度',
              padding: EdgeInsets.fromLTRB(0, 0, 0, 8),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Text(
                  '已入账：$paidCount / $totalCount 期',
                  style: t.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppPalette.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '本金 ${Money.fromMinor(paidPrincipal).format()}'
                  ' + 利息 ${Money.fromMinor(paidFee).format()}',
                  style:
                      t.bodySmall?.copyWith(color: AppPalette.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Text(
                  '待入账金额',
                  style:
                      t.bodySmall?.copyWith(color: AppPalette.textSecondary),
                ),
                const Spacer(),
                Text(
                  Money.fromMinor(remainingMinor).format(),
                  style: t.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppPalette.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: totalCount == 0 ? 0 : paidCount / totalCount,
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
