import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pocket_ledger/theme/app_dimens.dart';;
import '../../../../core/theme/forest_design_tokens.dart';
import '../../../../database/app_database.dart';
import '../../../../domain/enums.dart';
import '../../../../shared/models/money.dart';
import '../../../../shared/widgets/attachment_viewer.dart';
import '../../../../shared/widgets/badges.dart';
import '../../../../shared/widgets/clay_icon_tile.dart';
import '../../../../shared/widgets/line_icons.dart';
import '../../../../shared/widgets/money_text.dart';
import '../../../../theme/app_colors.dart';
import '../../../accounts/providers/accounts_providers.dart';
import '../../../lend/providers/lend_providers.dart';
import '../../../reimbursement/data/reimbursement_repository.dart';
import '../../../reimbursement/providers/reimbursement_providers.dart';
import '../../providers/ledger_providers.dart';
import 'txn_icon.dart';

/// 流水列表项（小青账版本，对齐参考稿卡片逻辑）。
///
/// 左侧为彩色圆角分类图标（报销收入行用「报」字图标），中间是
/// 「标题 + 报销徽章」与时间两行，右侧为金额 + 账户名 + 红色标注
/// （「已报 ¥xx」「不计收支、预算」）。用 [RepaintBoundary] 包裹，
/// 避免列表滚动时整屏重绘。
class TransactionTile extends ConsumerWidget {
  const TransactionTile({
    required this.transaction,
    super.key,
    this.onTap,
  });

  final Transaction transaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final Map<String, Category> categories =
        ref.watch(categoryMapProvider).valueOrNull ?? <String, Category>{};
    final Map<String, Account> accounts = <String, Account>{
      for (final Account a
          in ref.watch(accountsProvider).valueOrNull ?? <Account>[])
        a.id: a,
    };

    final Category? category = categories[transaction.categoryId];
    final bool isReimbIncome = transaction.type == TxnType.income &&
        transaction.sourceModule == SourceModule.reimbursement;
    // 退款必须显示「退款」而不是「收入」：两者的 `type` 都是 income，
    // 但统计口径不同（退款默认抵扣支出）。
    final String title = transaction.sourceModule == SourceModule.refund
        ? SourceModule.refund.label
        : isReimbIncome
            ? '报销收入'
            : (category?.name ?? transaction.type.label);
    final DateTime occurred = DateTime.fromMillisecondsSinceEpoch(
      transaction.occurredAt,
      isUtc: true,
    ).toLocal();

    // 收入记为正、支出记为负，便于列表直观展示
    final int signedMinor = switch (transaction.type) {
      TxnType.income => transaction.amountMinor,
      TxnType.expense => -transaction.amountMinor,
      TxnType.transfer => transaction.amountMinor,
    };

    // 有图片附件时在金额前显示一个回形针角标，点击进详情/编辑页即可查看原图。
    final List<String>? attachments =
        parseAttachmentUrls(transaction.attachmentUrls);

    // 退款：展示其关联的原账单，让用户一眼看出「退的是哪笔」。
    final String refundFromSuffix;
    if (transaction.sourceModule == SourceModule.refund &&
        transaction.relatedId != null) {
      final Transaction? original = ref
          .watch(transactionDetailProvider(transaction.relatedId!))
          .valueOrNull;
      if (original != null) {
        final String label = original.note != null && original.note!.isNotEmpty
            ? original.note!
            : (categories[original.categoryId]?.name ?? '原账单');
        refundFromSuffix = ' · 来自：$label';
      } else {
        refundFromSuffix = '';
      }
    } else {
      refundFromSuffix = '';
    }

    // 报销支出：反查报销记录，算累计已报（台账合计，旧数据按收入流水兜底），
    // 用于「已报 ¥xx」红字与超额报销标签。
    final bool isReimbExpense =
        transaction.type == TxnType.expense && transaction.isReimbursable;
    int receivedMinor = 0;
    if (isReimbExpense) {
      final List<Reimbursement> records =
          ref.watch(reimbursementListProvider).valueOrNull ??
              const <Reimbursement>[];
      for (final Reimbursement r in records) {
        if (r.transactionId != transaction.id) continue;
        final List<ReimbAllocEntry> allocs = parseReimbAllocs(r.incomeAllocs);
        if (allocs.isNotEmpty) {
          receivedMinor += allocs.fold<int>(
            0,
            (int s, ReimbAllocEntry e) => s + e.allocMinor,
          );
        } else if (r.incomeTransactionId != null) {
          receivedMinor += ref
                  .watch(transactionDetailProvider(r.incomeTransactionId!))
                  .valueOrNull
                  ?.amountMinor ??
              0;
        }
      }
    }
    final bool overReimbursed =
        isReimbExpense && receivedMinor > transaction.amountMinor;
    final bool fullyReimbursed = isReimbExpense &&
        receivedMinor > 0 &&
        receivedMinor >= transaction.amountMinor;

    // 退款标注：被退款的原支出账单，金额下显示「退款 ¥X=¥Y」
    // （X=累计已退合计，Y=剩余 = 实付 − 已退；对齐小青账）。
    final bool isExpenseRow = transaction.type == TxnType.expense;
    int refundedMinor = 0;
    if (isExpenseRow) {
      final List<Transaction> refunds =
          ref.watch(refundsByRelatedIdProvider(transaction.id)).valueOrNull ??
              const <Transaction>[];
      refundedMinor =
          refunds.fold<int>(0, (int s, Transaction r) => s + r.amountMinor);
    }
    final int paidMinor = transaction.amountMinor - transaction.discountMinor;

    final Color tint = isReimbIncome
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : category?.colorValue != null
            ? Color(category!.colorValue!)
            : _tintFor(transaction.type);
    // 图标恒为钢笔线稿：解析器全量兜底（分类缺行/缺 iconKey 时按
    // 模块/系统分类名/备注前缀/类型给线稿），不再退回 Material 图标。
    final LineIconKind lineKind = resolveTxnLineIcon(transaction, category);
    // 借还本金/还款流水：反查关联借还记录，右侧按转账样式显示
    // 「资金账户 ↔ 借还账户」双向账户对（无借还账户时回退单账户名）。
    final List<LendRecord> lendRecords =
        transaction.sourceModule == SourceModule.lend &&
                transaction.relatedId != null
            ? (ref.watch(lendListProvider).valueOrNull ?? const <LendRecord>[])
            : const <LendRecord>[];
    final String accountLabel = _accountLabel(accounts, lendRecords);

    // 红色标注：不计收支 / 不计预算（任一开启才显示）。
    final List<String> excludeLabels = <String>[
      if (transaction.excludeFromStats) '不计收支',
      if (transaction.excludeFromBudget) '不计预算',
    ];

    return RepaintBoundary(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.lg,
            vertical: AppDimens.sm,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outline,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // 左侧图标：黏土方糖 + 钢笔线稿（报销收入也统一走票据 ¥ 线稿），
              // 线稿配色走黏土约定（分类色向墨色收敛 22%）。
              ClayIconTile(
                size: 44,
                color: tint,
                child: LineIcon(
                  lineKind,
                  size: 22,
                  color: Color.lerp(
                    tint,
                    Theme.of(context).colorScheme.onSurface,
                    0.22,
                  )!,
                ),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // 标题 + 「报」徽章 + 「超额报销」标签。
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            title,
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isReimbExpense) ...<Widget>[
                          const SizedBox(width: 6),
                          const RebBadge(),
                          if (overReimbursed) ...<Widget>[
                            const SizedBox(width: 6),
                            const OverTag(),
                          ],
                          if (fullyReimbursed) ...<Widget>[
                            const SizedBox(width: 6),
                            const _RebDoneBadge(),
                          ],
                        ],
                      ],
                    ),
                    // 备注：夹在分类标题与时间之间独立一行（无备注不占位）。
                    if (_hasNote) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        transaction.note!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('HH:mm').format(occurred) + refundFromSuffix,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (attachments != null && attachments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: AppDimens.xs),
                  child: Icon(
                    Icons.attach_file,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              // 右侧：金额 + 已报 + 账户名 + 排除标注（自上而下）。
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  transaction.type == TxnType.transfer
                      ? Text(
                          Money.fromMinor(transaction.amountMinor).format(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppPalette.transfer,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : (transaction.type == TxnType.expense &&
                              transaction.discountMinor > 0)
                          ? _DiscountedAmount(
                              originalMinor: transaction.amountMinor,
                              discountMinor: transaction.discountMinor,
                              strikeActual: fullyReimbursed,
                            )
                          : MoneyText(
                              Money.fromMinor(signedMinor.abs()),
                              signed: false,
                              color: fullyReimbursed
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                  : null,
                              style: fullyReimbursed
                                  ? TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      decorationColor: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    )
                                  : null,
                            ),
                  if (isExpenseRow && refundedMinor > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '退款 ${Money.fromMinor(refundedMinor).format()}'
                        '=${Money.fromMinor(
                          (paidMinor - refundedMinor).clamp(0, paidMinor),
                        ).format()}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppPalette.expense,
                        ),
                      ),
                    ),
                  if (isReimbExpense && receivedMinor > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '已报 ${Money.fromMinor(receivedMinor).format()}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppPalette.expense,
                        ),
                      ),
                    ),
                  if (accountLabel.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        accountLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (excludeLabels.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        excludeLabels.join('、'),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppPalette.expense,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _accountLabel(
    Map<String, Account> accounts,
    List<LendRecord> lendRecords,
  ) {
    if (transaction.type == TxnType.transfer) {
      final String from = accounts[transaction.accountId]?.name ?? '转出';
      final String to = transaction.toAccountId != null
          ? (accounts[transaction.toAccountId]?.name ?? '转入')
          : '转入';
      return '$from → $to';
    }
    // 借还流水（借入/借出/还债/收债）：按转账样式显示账户对——
    // 借出/收债：资金流出我方 → 借出账户；借入/还债：借入账户 → 资金流入我方。
    if (transaction.sourceModule == SourceModule.lend) {
      LendRecord? record;
      for (final LendRecord r in lendRecords) {
        if (r.id == transaction.relatedId) {
          record = r;
          break;
        }
      }
      final String? lendAccountId = record?.accountId;
      final String myAccount = accounts[transaction.accountId]?.name ?? '';
      final Account? lendAccount =
          lendAccountId == null ? null : accounts[lendAccountId];
      if (lendAccount != null && myAccount.isNotEmpty) {
        // 资金方向跟流水类型走：支出（借出本金/还债）我方 → 借还账户；
        // 收入（借入本金/收债）借还账户 → 我方。
        final bool outflow = transaction.type == TxnType.expense;
        return outflow
            ? '$myAccount → ${lendAccount.name}'
            : '${lendAccount.name} → $myAccount';
      }
    }
    return accounts[transaction.accountId]?.name ?? '';
  }

  bool get _hasNote => transaction.note != null && transaction.note!.isNotEmpty;

  Color _tintFor(TxnType type) => switch (type) {
        TxnType.income => AppPalette.income,
        TxnType.expense => AppPalette.expense,
        TxnType.transfer => AppPalette.transfer,
      };
}

/// 「已报」实心徽章：账单已被全额报销时显示（与描边的「报」区分）。
class _RebDoneBadge extends StatelessWidget {
  const _RebDoneBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          color: ForestGreen.deep,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '已报',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      );
}

/// 优惠支出金额（对齐小青账）：第一行「划线原价 + 红色实付」，
/// 第二行「优惠45.00」红色小字。实付 = 原价 − 优惠。
class _DiscountedAmount extends StatelessWidget {
  const _DiscountedAmount({
    required this.originalMinor,
    required this.discountMinor,
    this.strikeActual = false,
  });

  final int originalMinor;
  final int discountMinor;
  final bool strikeActual;

  @override
  Widget build(BuildContext context) {
    final int actualMinor = originalMinor - discountMinor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Text(
              '-${Money.fromMinor(originalMinor).format()}',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                decoration: TextDecoration.lineThrough,
                decorationColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              Money.fromMinor(actualMinor).format(),
              style: TextStyle(
                fontSize: 15,
                color: strikeActual
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : AppPalette.expense,
                fontWeight: FontWeight.w600,
                decoration: strikeActual ? TextDecoration.lineThrough : null,
                decorationColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Text(
          '优惠${Money.fromMinor(discountMinor).format()}',
          style: const TextStyle(
            fontSize: 11,
            color: AppPalette.expense,
          ),
        ),
      ],
    );
  }
}

/// 日期分组标题
class DateSectionHeader extends StatelessWidget {
  const DateSectionHeader(this.timestamp, {super.key});

  final int timestamp;

  @override
  Widget build(BuildContext context) {
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(
      timestamp,
      isUtc: true,
    ).toLocal();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.lg,
        AppDimens.md,
        AppDimens.lg,
        AppDimens.xs,
      ),
      child: Text(
        DateFormat('yyyy年M月d日').format(date),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
