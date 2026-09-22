import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_dimens.dart';
import '../../../../../database/app_database.dart';
import '../../../../../domain/enums.dart';
import '../../providers/ledger_providers.dart';
import '../../../../../shared/models/money.dart';
import '../../../../../shared/widgets/attachment_viewer.dart';
import '../../../../../shared/widgets/category_icons.dart';
import '../../../../../shared/widgets/money_text.dart';
import '../../../accounts/providers/accounts_providers.dart';

/// 流水列表项（小青账版本）。
///
/// 左侧为彩色圆角分类图标，中间是「分类名 + 账户 · 时间」两行，
/// 右侧为按类型着色的金额。用 [RepaintBoundary] 包裹，避免列表滚动时整屏重绘。
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
    // 退款必须显示「退款」而不是「收入」：两者的 `type` 都是 income，
    // 但统计口径不同（退款默认抵扣支出）。
    final String title = transaction.sourceModule == SourceModule.refund
        ? SourceModule.refund.label
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

    final Color tint = category?.colorValue != null
        ? Color(category!.colorValue!)
        : _tintFor(transaction.type);
    final IconData icon =
        category?.iconKey != null && category!.iconKey!.isNotEmpty
            ? categoryIconData(category.iconKey)
            : _iconFor(transaction.type);
    final String accountLabel = _accountLabel(accounts);

    return RepaintBoundary(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceLg,
            vertical: AppDimens.spaceSm,
          ),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.divider, width: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                child: Icon(icon, color: tint, size: 22),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$accountLabel  ${DateFormat('MM-dd HH:mm').format(occurred)}'
                      '${_noteSuffix()}$refundFromSuffix',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (attachments != null && attachments.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(right: AppDimens.spaceXs),
                  child: Icon(
                    Icons.attach_file,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                ),
              transaction.type == TxnType.transfer
                  ? Text(
                      Money.fromMinor(transaction.amountMinor).format(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.transfer,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : (transaction.type == TxnType.expense &&
                          transaction.discountMinor > 0)
                      ? _DiscountedAmount(
                          originalMinor: transaction.amountMinor,
                          discountMinor: transaction.discountMinor,
                        )
                      : MoneyText(Money.fromMinor(signedMinor), signed: true),
            ],
          ),
        ),
      ),
    );
  }

  String _accountLabel(Map<String, Account> accounts) {
    if (transaction.type == TxnType.transfer) {
      final String from = accounts[transaction.accountId]?.name ?? '转出';
      final String to = transaction.toAccountId != null
          ? (accounts[transaction.toAccountId]?.name ?? '转入')
          : '转入';
      return '$from → $to';
    }
    return accounts[transaction.accountId]?.name ?? '';
  }

  String _noteSuffix() {
    final String? note = transaction.note;
    if (note == null || note.isEmpty) return '';
    return '  $note';
  }

  Color _tintFor(TxnType type) => switch (type) {
        TxnType.income => AppColors.income,
        TxnType.expense => AppColors.expense,
        TxnType.transfer => AppColors.transfer,
      };

  IconData _iconFor(TxnType type) => switch (type) {
        TxnType.income => Icons.south_west,
        TxnType.expense => Icons.north_east,
        TxnType.transfer => Icons.swap_horiz,
      };
}

/// 优惠支出金额（对齐小青账）：第一行「划线原价 + 红色实付」，
/// 第二行「优惠45.00」红色小字。实付 = 原价 − 优惠。
class _DiscountedAmount extends StatelessWidget {
  const _DiscountedAmount({
    required this.originalMinor,
    required this.discountMinor,
  });

  final int originalMinor;
  final int discountMinor;

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
                color: AppColors.textTertiary,
                decoration: TextDecoration.lineThrough,
                decorationColor: AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              Money.fromMinor(actualMinor).format(),
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.expense,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Text(
          '优惠${Money.fromMinor(discountMinor).format()}',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.expense,
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
        AppDimens.spaceLg,
        AppDimens.spaceMd,
        AppDimens.spaceLg,
        AppDimens.spaceXs,
      ),
      child: Text(
        DateFormat('yyyy年M月d日').format(date),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
