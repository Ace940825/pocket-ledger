import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';

/// 汇总条（全应用统一）：「共 N 笔 · 合计 ¥X」一行，顶部发丝线。
///
/// 合并 category_transactions_page / refund_page 等重复实现。
class SummaryBar extends StatelessWidget {
  const SummaryBar({
    super.key,
    required this.count,
    required this.totalText,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(
      vertical: 10,
      horizontal: AppDimens.lg,
    ),
  });

  final int count;
  final String totalText;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outline, width: 1)),
      ),
      child: Row(
        children: <Widget>[
          Text(
            '共 $count 笔',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const Spacer(),
          if (trailing != null) ...<Widget>[
            trailing!,
            const SizedBox(width: 8),
          ],
          Text(
            totalText,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
