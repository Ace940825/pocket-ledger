import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../models/money.dart';

/// 金额文本（带数字滚动动画）。
///
/// 行为与原生 [MoneyText] 一致（自动正负着色、收入绿/支出红），
/// 但数字从旧值平滑滚动到新值。适合记账 App 的总览数字，
/// 让净资产、收支在加载完成 / 数值变化时有一点点「呼吸感」。
///
/// 动画策略：首次挂载从 0 滚到目标值；之后每当 [Money.minor] 变化，
/// 从旧值滚到新值（不回到 0），避免来回跳变。
class AnimatedMoneyText extends StatefulWidget {
  const AnimatedMoneyText(
    this.money, {
    super.key,
    this.style,
    this.signed = false,
    this.color,
    this.duration = const Duration(milliseconds: 650),
  });

  final Money money;
  final TextStyle? style;
  final bool signed;
  final Color? color;
  final Duration duration;

  @override
  State<AnimatedMoneyText> createState() => _AnimatedMoneyTextState();
}

class _AnimatedMoneyTextState extends State<AnimatedMoneyText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<int> _animation;
  late int _from;
  late int _to;

  @override
  void initState() {
    super.initState();
    _from = 0;
    _to = widget.money.minor;
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = _tween.animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  IntTween get _tween => IntTween(begin: _from, end: _to);

  @override
  void didUpdateWidget(covariant AnimatedMoneyText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.money.minor != widget.money.minor) {
      _from = oldWidget.money.minor;
      _to = widget.money.minor;
      _animation = _tween.animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _resolveColor() {
    final Money money = widget.money;
    if (money.isZero) return AppColors.textSecondary;
    return money.isPositive ? AppColors.income : AppColors.expense;
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle base =
        widget.style ?? Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    final Color resolved = widget.color ?? _resolveColor();

    return AnimatedBuilder(
      animation: _animation,
      builder: (BuildContext context, Widget? child) {
        final Money animated = Money.fromMinor(_animation.value, currency: widget.money.currency);
        return Text(
          widget.signed ? animated.formatSigned() : animated.format(),
          style: base.copyWith(
            color: resolved,
            fontWeight: FontWeight.w600,
          ),
        );
      },
    );
  }
}
