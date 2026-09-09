import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../models/money.dart';

/// 金额文本。
///
/// 自动按正负着色，符合国内记账认知：**收入绿、支出红**。
/// 注意：投资涨跌场景不要用本组件，应使用 AppColors.stockUp / stockDown。
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.money, {
    super.key,
    this.style,
    this.signed = false,
    this.color,
  });

  final Money money;
  final TextStyle? style;
  final bool signed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final TextStyle base =
        style ?? Theme.of(context).textTheme.bodyMedium ?? const TextStyle();

    return Text(
      signed ? money.formatSigned() : money.format(),
      style: base.copyWith(
        color: color ?? _resolveColor(),
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Color? _resolveColor() {
    if (money.isZero) return AppColors.textSecondary;
    return money.isPositive ? AppColors.income : AppColors.expense;
  }
}
