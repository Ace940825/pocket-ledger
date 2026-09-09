import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_dimens.dart';
import '../../../../../database/app_database.dart';
import '../../../../../domain/enums.dart';
import '../../../../../shared/models/money.dart';
import '../../../../../shared/widgets/money_text.dart';
import '../../../accounts/providers/accounts_providers.dart';

/// 流水列表项。
///
/// 用 [RepaintBoundary] 包裹，避免列表滚动时整屏重绘。
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

    final Category? category = categories[transaction.categoryId];
    final String title = category?.name ?? transaction.type.label;
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

    return RepaintBoundary(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.12),
          child: Icon(
            _iconFor(transaction.type),
            color: AppColors.primary,
            size: 20,
          ),
        ),
        title: Text(title, style: theme.textTheme.bodyLarge),
        subtitle: Text(
          '${DateFormat('MM-dd HH:mm').format(occurred)}'
          '${_noteSuffix()}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: transaction.type == TxnType.transfer
            ? Text(
                Money.fromMinor(transaction.amountMinor).format(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.transfer,
                  fontWeight: FontWeight.w600,
                ),
              )
            : MoneyText(Money.fromMinor(signedMinor), signed: true),
      ),
    );
  }

  String _noteSuffix() {
    final String? note = transaction.note;
    if (note == null || note.isEmpty) return '';
    return '  $note';
  }

  IconData _iconFor(TxnType type) => switch (type) {
        TxnType.income => Icons.south_west,
        TxnType.expense => Icons.north_east,
        TxnType.transfer => Icons.swap_horiz,
      };
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
            ),
      ),
    );
  }
}
