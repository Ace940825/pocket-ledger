import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:pocket_ledger/shared/widgets/confirm_dialog.dart';
import 'package:pocket_ledger/shared/widgets/hairline_card.dart';
import 'package:pocket_ledger/shared/widgets/loading_state.dart';
import 'package:pocket_ledger/shared/widgets/text_input_dialog.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/module_list_scaffold.dart'
    show confirmDelete, showToast;
import '../../../theme/app_colors.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../ledger/presentation/widgets/txn_slidable.dart';
import '../domain/fee_utils.dart';
import '../domain/repeat_rule.dart';
import '../providers/installment_providers.dart';
import 'installment_detail_page.dart';

/// 分期页：进行中 / 已结束双 Tab + 计划卡片（对照有钱记账分期文档布局）。
///
/// 卡片含状态徽章、应还总额 / 待入账、入账进度条与已入账期数；
/// 左滑支持修改名称、完结、删除。
class InstallmentPage extends ConsumerStatefulWidget {
  const InstallmentPage({super.key});

  @override
  ConsumerState<InstallmentPage> createState() => _InstallmentPageState();
}

class _InstallmentPageState extends ConsumerState<InstallmentPage> {
  bool _showFinished = false;

  @override
  void initState() {
    super.initState();
    // 惰性补账：进入分期页时把到期期次自动在负债付款账户入账（幂等）。
    // App 启动 bootstrap 已兜底一次，这里覆盖「App 长驻跨天」的场景。
    Future<void>.microtask(() async {
      try {
        await ref.read(installmentRepositoryProvider).postDuePeriods();
        // 入账后紧接自动对账：出账单日之后还款覆盖则自动勾已还（可进可退）。
        await ref
            .read(installmentRepositoryProvider)
            .reconcileInstallmentRepayments();
      } on AppFailure catch (e) {
        assert(() {
          debugPrint('installment reconcile: ${e.message}');
          return true;
        }());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<InstallmentPlan>> plans =
        ref.watch(installmentPlansProvider);
    final AsyncValue<List<InstallmentPeriod>> periodsAsync =
        ref.watch(installmentBookPeriodsProvider);
    final List<Account> accounts =
        ref.watch(accountsProvider).valueOrNull ?? const <Account>[];

    return Scaffold(
      appBar: AppBar(title: const Text('分期')),
      body: plans.when(
        data: (List<InstallmentPlan> list) {
          // 账本级期次一次订阅：汇总各计划的待入账金额与逾期态。
          // 双口径：待入账 = 未入账（transactionId 为空，到期由仓储自动
          // 补账）；逾期 = 到期未还（paidAt 为空，还款意义上的逾期）。
          final Map<String, int> remainingByPlan = <String, int>{};
          final Map<String, bool> overdueByPlan = <String, bool>{};
          final int nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
          periodsAsync.whenData((List<InstallmentPeriod> ps) {
            for (final InstallmentPeriod p in ps) {
              if (p.transactionId == null) {
                remainingByPlan[p.planId] =
                    (remainingByPlan[p.planId] ?? 0) + p.amountMinor;
              }
              if (p.dueAt < nowMs && p.paidAt == null) {
                overdueByPlan[p.planId] = true;
              }
            }
          });

          final List<InstallmentPlan> filtered = list
              .where((InstallmentPlan p) => p.isFinished == _showFinished)
              .toList(growable: false);
          return Column(
            children: <Widget>[
              _buildSegmented(),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child:
                            Text(_showFinished ? '暂无已结束的分期' : '还没有分期计划，点右下角新增'),
                      )
                    : TxnSlidableGroup(
                        child: ListView.separated(
                          padding: const EdgeInsets.only(top: 4, bottom: 88),
                          itemCount: filtered.length,
                          separatorBuilder: (BuildContext _, int __) =>
                              const Divider(height: 1),
                          itemBuilder: (BuildContext _, int index) {
                            final InstallmentPlan p = filtered[index];
                            return _PlanCard(
                              plan: p,
                              remainingMinor: remainingByPlan[p.id] ?? 0,
                              hasOverdue: overdueByPlan[p.id] ?? false,
                              repeatLabel: _repeatLabelOf(p),
                              accountName:
                                  _accountNameOf(accounts, p.accountId),
                              onOpen: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (BuildContext _) =>
                                      InstallmentDetailPage(planId: p.id),
                                ),
                              ),
                              onRename: () => _renamePlan(p),
                              onFinish:
                                  p.isFinished ? null : () => _finishPlan(p),
                              onDelete: () => _deletePlan(p),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => const LoadingState(),
        error: (Object e, StackTrace _) => Center(child: Text('加载失败：$e')),
      ),
    );
  }

  // ---------------------------------------------------------------- 视图

  Widget _buildSegmented() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppPalette.sage50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: _buildSegmentItem('进行中', !_showFinished)),
          Expanded(child: _buildSegmentItem('已结束', _showFinished)),
        ],
      ),
    );
  }

  Widget _buildSegmentItem(String label, bool selected) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () {
        if (!selected) setState(() => _showFinished = label == '已结束');
      },
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.surface
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.08),
                    blurRadius: 3,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected
                ? AppPalette.sage700
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- 数据

  String _repeatLabelOf(InstallmentPlan p) {
    final InstallmentRepeatRule? rule =
        InstallmentRepeatRule.fromJsonString(p.repeatRule);
    final int fallbackDay =
        DateTime.fromMillisecondsSinceEpoch(p.firstDueAt).day;
    return rule?.displayLabel(fallbackDay: fallbackDay) ?? '每月';
  }

  String? _accountNameOf(List<Account> accounts, String? accountId) {
    if (accountId == null) return null;
    for (final Account a in accounts) {
      if (a.id == accountId) return a.name;
    }
    return null;
  }

  // ---------------------------------------------------------------- 动作

  /// 左滑「改名」：仅标题；账户等元信息在详情页「编辑」里调整。
  Future<void> _renamePlan(InstallmentPlan p) async {
    final String? title = await showTextInput(
      context,
      title: '修改名称',
      labelText: '分期名称',
      initialValue: p.title,
    );
    if (title == null || !mounted) return;
    try {
      await ref.read(installmentRepositoryProvider).updatePlanMeta(
            planId: p.id,
            title: title,
            accountId: p.accountId,
          );
    } on AppFailure catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  /// 左滑「完结」：未还期次一次性标记为已还（提前结清口径）。
  Future<void> _finishPlan(InstallmentPlan p) async {
    final int unpaid = p.totalPeriods - p.paidPeriods;
    final bool? ok = await showConfirm(
      context,
      title: '完结「${p.title}」？',
      content: '将未还的 $unpaid 期一次性标记为已还，该计划随即完结。',
      confirmText: '完结',
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(installmentRepositoryProvider).finishPlan(p.id);
      if (mounted) showToast(context, '已完结');
    } on AppFailure catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  Future<void> _deletePlan(InstallmentPlan p) async {
    final bool ok = await confirmDelete(
      context,
      title: '删除计划「${p.title}」？',
      content: '该计划下的所有期数明细也会一并删除。',
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(installmentRepositoryProvider).removePlan(p.id);
    } on AppFailure catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }
}

/// 列表卡片（紧凑版）：状态徽章 + 名称 / 周期副行 / 应还总额与待入账 /
/// 进度条 + 已入账期数；左滑三个动作。
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.remainingMinor,
    required this.hasOverdue,
    required this.repeatLabel,
    required this.accountName,
    required this.onOpen,
    required this.onRename,
    required this.onFinish,
    required this.onDelete,
  });

  final InstallmentPlan plan;
  final int remainingMinor;
  final bool hasOverdue;
  final String repeatLabel;
  final String? accountName;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback? onFinish;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final List<int> fees = feeByPeriodOf(plan);
    final int totalFee = fees.fold<int>(0, (int s, int v) => s + v);
    final double progress =
        plan.totalPeriods == 0 ? 0 : plan.paidPeriods / plan.totalPeriods;
    final String statusLabel = plan.isFinished
        ? '已结束'
        : hasOverdue
            ? '有逾期'
            : '进行中';
    final Color statusColor = plan.isFinished
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : hasOverdue
            ? AppPalette.danger
            : AppPalette.primary;

    return Slidable(
      key: ValueKey<String>('installment-${plan.id}'),
      groupTag: TxnSlidable.groupTag,
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: onFinish == null ? 0.34 : 0.5,
        children: <Widget>[
          _SlideAction(
            icon: Icons.edit_outlined,
            label: '改名',
            color: AppPalette.info,
            onPressed: onRename,
          ),
          if (onFinish != null)
            _SlideAction(
              icon: Icons.check_circle_outline,
              label: '完结',
              color: AppPalette.primary,
              onPressed: onFinish!,
            ),
          _SlideAction(
            icon: Icons.delete_outline,
            label: '删除',
            color: AppPalette.danger,
            onPressed: onDelete,
          ),
        ],
      ),
      child: HairlineCard(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _badge(statusLabel, statusColor),
                    const Spacer(),
                    Expanded(
                      child: Text(
                        plan.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  <String>[
                    repeatLabel,
                    '${plan.totalPeriods} 期',
                    if (accountName != null) accountName!,
                  ].join(' · '),
                  style: t.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '应还总额',
                          style: t.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Money.fromMinor(plan.totalMinor + totalFee).format(),
                          style: t.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          '待入账',
                          style: t.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Money.fromMinor(remainingMinor).format(),
                          style: t.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '已入账 ${plan.paidPeriods}/${plan.totalPeriods} 期',
                  style: t.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// 左滑动作键——与流水列表同款圆形徽章样式，下方补动作名。
class _SlideAction extends StatelessWidget {
  const _SlideAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CustomSlidableAction(
      onPressed: (_) => onPressed(),
      backgroundColor: Colors.transparent,
      foregroundColor: color,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 与 TxnSlideAction 圆形徽章同款（全应用滑动列表统一视觉）
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.20)),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 24, color: color, semanticLabel: label),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 供详情页复用的日期格式化。
String formatDueDate(int msUtc) => DateFormat('yyyy-MM-dd')
    .format(DateTime.fromMillisecondsSinceEpoch(msUtc, isUtc: true).toLocal());
