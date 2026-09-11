import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../database/app_database.dart';
import '../../../../domain/enums.dart';
import '../../../../shared/models/money.dart';
import '../../../../shared/widgets/money_text.dart';
import '../../../accounts/providers/accounts_providers.dart';

/// 资产详情页用的交易行。
///
/// 与小青账账单列表对齐：左侧圆形图标 + 标题/时间，
/// 右侧金额 + 账户/去向说明。支出红字、收入绿字、转账灰字。
class AccountTransactionTile extends ConsumerWidget {
  const AccountTransactionTile({
    super.key,
    required this.transaction,
    required this.accountNames,
    this.onTap,
  });

  final Transaction transaction;

  /// 账户 ID -> 名称映射，用于渲染转账的「从 -> 到」说明。
  final Map<String, String> accountNames;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final DateTime occurred = DateTime.fromMillisecondsSinceEpoch(
      transaction.occurredAt,
      isUtc: true,
    ).toLocal();

    final Category? category = _category(ref);
    final String title = _title(category);
    final IconData icon = _iconFor(category, transaction.type);
    final Color tint = _tintFor(category);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceLg,
          vertical: AppDimens.spaceMd,
        ),
        child: Row(
          children: <Widget>[
            _CircleIcon(icon: icon, tint: tint),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('HH:mm').format(occurred),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                _AmountText(transaction: transaction),
                const SizedBox(height: 2),
                Text(
                  _subtitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Category? _category(WidgetRef ref) {
    final Map<String, Category> categories =
        ref.watch(categoryMapProvider).valueOrNull ?? <String, Category>{};
    return categories[transaction.categoryId];
  }

  /// 行标题。
  ///
  /// **退款必须显示「退款」而不是「收入」**：退款的 `type` 同样是 `income`，
  /// 如果标题只看 `type`，它和普通收入在界面上完全一样 —— 而统计口径却不同
  /// （退款默认抵扣支出）。早期正是因为这个「看不出来」，
  /// 才把 `支出:¥88.00 收入:¥0.00` 当成了统计 bug。
  String _title(Category? category) {
    if (transaction.sourceModule == SourceModule.refund) {
      return SourceModule.refund.label;
    }
    return category?.name ?? transaction.type.label;
  }

  IconData _iconFor(Category? category, TxnType type) {
    if (transaction.sourceModule == SourceModule.refund) {
      return Icons.replay;
    }
    final String? key = category?.iconKey;
    if (key != null && key.isNotEmpty) {
      return _parseIcon(key);
    }
    return switch (type) {
      TxnType.income => Icons.south_west,
      TxnType.expense => Icons.north_east,
      TxnType.transfer => Icons.swap_horiz,
    };
  }

  Color _tintFor(Category? category) {
    final int? colorValue = category?.colorValue;
    if (colorValue != null) return Color(colorValue);
    return switch (transaction.type) {
      TxnType.income => AppColors.income,
      TxnType.expense => AppColors.expense,
      TxnType.transfer => AppColors.transfer,
    };
  }

  IconData _parseIcon(String key) {
    // 分类的 iconKey 是字符串，这里只兜底几个常用图标；
    // 未来可接入完整的图标映射表。
    return switch (key) {
      'food' => Icons.restaurant,
      'transport' => Icons.directions_car,
      'shopping' => Icons.shopping_bag,
      'entertainment' => Icons.movie,
      'housing' => Icons.home,
      'medical' => Icons.local_hospital,
      'education' => Icons.school,
      'salary' => Icons.work,
      'transfer' => Icons.swap_horiz,
      _ => Icons.label_outline,
    };
  }

  String _subtitle() {
    if (transaction.type == TxnType.transfer &&
        transaction.toAccountId != null) {
      final String from = accountNames[transaction.accountId] ?? '';
      final String to = accountNames[transaction.toAccountId] ?? '';
      if (from.isNotEmpty && to.isNotEmpty) return '$from -> $to';
    }
    return accountNames[transaction.accountId] ?? '';
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon, required this.tint});

  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: tint.withOpacity(isDark ? 0.18 : 0.12),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 20, color: tint),
    );
  }
}

class _AmountText extends StatelessWidget {
  const _AmountText({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    switch (transaction.type) {
      case TxnType.transfer:
        return Text(
          Money.fromMinor(transaction.amountMinor).format(),
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.transfer,
          ),
        );
      case TxnType.income:
        return MoneyText(
          Money.fromMinor(transaction.amountMinor),
          signed: true,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        );
      case TxnType.expense:
        return MoneyText(
          Money.fromMinor(-transaction.amountMinor),
          signed: true,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        );
    }
  }
}
