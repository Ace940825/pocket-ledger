import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../../database/app_database.dart';
import '../../../../domain/enums.dart';
import '../../../../providers/app_providers.dart';
import '../../../../shared/models/money.dart';
import '../../../../shared/widgets/clay_icon_tile.dart';
import '../../../../shared/widgets/hairline_card.dart';
import '../../../../shared/widgets/line_icon_map.dart';
import '../../../../shared/widgets/line_icons.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_dimens.dart';
import '../../../accounts/providers/accounts_providers.dart';
import '../../../ledger/presentation/transaction_detail_sheet.dart';
import '../../../ledger/presentation/widgets/txn_icon.dart';

/// 近 3 日（含今天）全部流水（当前账本），按发生时间倒序。
final AutoDisposeStreamProviderFamily<List<Transaction>, String>
    _last3DayTxnsProvider =
    StreamProvider.autoDispose.family<List<Transaction>, String>(
  (Ref ref, String bookId) {
    final DateTime now = localNow();
    final DateTime today = DateTime(now.year, now.month, now.day);
    return ref.watch(transactionsDaoProvider).watchRange(
          bookId: bookId,
          startAt: today
              .subtract(const Duration(days: 2))
              .toUtc()
              .millisecondsSinceEpoch,
          endAt:
              today.add(const Duration(days: 1)).toUtc().millisecondsSinceEpoch,
        );
  },
);

/// 预算页「近3日账单」区（对标小青账截图 1-3）：
///
/// - 头部「按时间 / 按金额」切换钮（时间=发生时间倒序，金额=实付倒序）；
/// - 紧凑流水小列（分类线稿 + 名称/时间 + 实付金额），最多 6 条；
/// - 点行进流水详情弹层；空态提示「近3日暂无账单」。
class RecentBillsCard extends ConsumerStatefulWidget {
  const RecentBillsCard({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<RecentBillsCard> createState() => _RecentBillsCardState();
}

class _RecentBillsCardState extends ConsumerState<RecentBillsCard> {
  /// false=按时间（默认），true=按金额。
  bool _byAmount = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Transaction> txns =
        ref.watch(_last3DayTxnsProvider(widget.bookId)).valueOrNull ??
            const <Transaction>[];
    final List<Transaction> sorted = List<Transaction>.of(txns);
    if (_byAmount) {
      // 金额排序按「实付」口径（与列表展示一致），稳定排序保留时间次序。
      sorted.sort(
        (Transaction a, Transaction b) => (b.amountMinor - b.discountMinor)
            .compareTo(a.amountMinor - a.discountMinor),
      );
    }
    final List<Transaction> visible = sorted.take(6).toList(growable: false);

    return HairlineCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: '近3日账单',
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 0),
            trailing: GestureDetector(
              onTap: () => setState(() => _byAmount = !_byAmount),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppDimens.radiusChip),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    LineGlyph(
                      Icons.swap_vert,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _byAmount ? '按金额' : '按时间',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 4, 12, 14),
              child: Text('近3日暂无账单'),
            )
          else
            for (final Transaction t in visible) _RecentBillRow(txn: t),
        ],
      ),
    );
  }
}

/// 紧凑流水行：分类线稿 + 名称/时间 + 实付金额，点行进详情弹层。
class _RecentBillRow extends ConsumerWidget {
  const _RecentBillRow({required this.txn});

  final Transaction txn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final Category? category =
        ref.watch(categoryMapProvider).valueOrNull?[txn.categoryId];

    final String title = txn.sourceModule == SourceModule.refund
        ? SourceModule.refund.label
        : (txn.type == TxnType.income &&
                txn.sourceModule == SourceModule.reimbursement
            ? '报销收入'
            : (category?.name ?? txn.type.label));
    final DateTime occurred = DateTime.fromMillisecondsSinceEpoch(
      txn.occurredAt,
      isUtc: true,
    ).toLocal();

    // 实付口径：支出扣优惠（与预算已用一致），收入/转账用原额。
    final int netMinor = txn.type == TxnType.expense
        ? txn.amountMinor - txn.discountMinor
        : txn.amountMinor;
    final Color amountColor = switch (txn.type) {
      TxnType.expense => AppPalette.expense,
      TxnType.income => AppPalette.income,
      TxnType.transfer => AppPalette.transfer,
    };
    final String sign = switch (txn.type) {
      TxnType.expense => '-',
      TxnType.income => '+',
      TxnType.transfer => '',
    };

    final Color tint = category?.colorValue != null
        ? Color(category!.colorValue!)
        : _tintFor(txn.type);
    final LineIconKind lineKind = resolveTxnLineIcon(txn, category);

    return InkWell(
      onTap: () => TransactionDetailSheet.show(context, txn),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: <Widget>[
            ClayIconTile(
              size: 36,
              color: tint,
              child: LineIcon(
                lineKind,
                size: 18,
                color: Color.lerp(tint, theme.colorScheme.onSurface, 0.22)!,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    DateFormat('M月d日 HH:mm').format(occurred),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$sign${Money.fromMinor(netMinor.abs()).format()}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _tintFor(TxnType type) => switch (type) {
        TxnType.income => AppPalette.income,
        TxnType.expense => AppPalette.expense,
        TxnType.transfer => AppPalette.transfer,
      };
}
