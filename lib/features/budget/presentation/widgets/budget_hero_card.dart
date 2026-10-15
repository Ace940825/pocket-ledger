import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/forest_design_tokens.dart';
import '../../../../database/app_database.dart';
import '../../../../domain/enums.dart';
import '../../../../shared/models/money.dart';
import '../../../../shared/widgets/clay_icon_tile.dart';
import '../../../../shared/widgets/hairline_card.dart';
import '../../../../shared/widgets/line_icon_map.dart';
import '../../../../theme/app_colors.dart';
import '../../data/budget_repository.dart';
import '../../providers/budget_providers.dart';

/// 预算主页顶部指标卡（对标小青账截图 1-3 的会员位，按现有数据推演）：
///
/// - 三指标循环切换：预算剩余(元) → 总预算(元) → 剩余日均(元)
///   （点右上角 ⇄ 按钮循环，圆点指示器标明当前位置）；
/// - 左侧 sage 渐变进度环：已用 / 总预算，超支整环转珊瑚红；
/// - 副行恒显「已用 ¥x · 共 ¥y」，未设置预算时大数位显「未设置」。
///
/// 口径：当前账本、当前查看周期（月/年）的**支出方向**预算
/// （scope=overall + 支出分类预算），与「支出预算」分组卡同源；
/// 已用逐条预算按各自生效区间实时聚合（budgetSpentProvider）。
class BudgetHeroCard extends ConsumerStatefulWidget {
  const BudgetHeroCard({
    super.key,
    required this.budgets,
    required this.catById,
    required this.daysLeft,
  });

  /// 当前账本在查看周期内的预算行（页面侧已按周期过滤）。
  final List<Budget> budgets;

  /// 分类表（按 id），用于判定分类预算的收支方向。
  final Map<String, Category> catById;

  /// 周期剩余天数（含今天）；周期已结束为 0（剩余日均退化为 ¥0.00）。
  final int daysLeft;

  @override
  ConsumerState<BudgetHeroCard> createState() => _BudgetHeroCardState();
}

class _BudgetHeroCardState extends ConsumerState<BudgetHeroCard> {
  /// 当前指标：0=预算剩余 / 1=总预算 / 2=剩余日均。
  int _metric = 0;

  static const List<String> _metricLabels = <String>[
    '预算剩余(元)',
    '总预算(元)',
    '剩余日均(元)',
  ];

  void _cycleMetric() =>
      setState(() => _metric = (_metric + 1) % _metricLabels.length);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final BudgetRepository repo = ref.watch(budgetRepositoryProvider);

    // 支出方向预算：总预算行 + 支出分类行（收入分类不进支出口径）。
    final List<Budget> expenseBudgets = widget.budgets
        .where(
          (Budget b) =>
              b.scope == BudgetScope.overall ||
              (b.scope == BudgetScope.category &&
                  widget.catById[b.categoryId]?.type == CategoryType.expense),
        )
        .toList(growable: false);

    int totalMinor = 0;
    int spentMinor = 0;
    for (final Budget b in expenseBudgets) {
      totalMinor += b.amountMinor;
      final ({int start, int end}) range = repo.rangeOf(b);
      spentMinor += ref
              .watch(
                budgetSpentProvider(
                  (
                    start: range.start,
                    end: range.end,
                    categoryId: b.categoryId
                  ),
                ),
              )
              .valueOrNull ??
          0;
    }
    final int remainingMinor = totalMinor - spentMinor;
    final double ratio = totalMinor > 0 ? spentMinor / totalMinor : 0;
    final int dailyMinor =
        widget.daysLeft > 0 ? (remainingMinor / widget.daysLeft).round() : 0;
    final int shownMinor = switch (_metric) {
      0 => remainingMinor,
      1 => totalMinor,
      _ => dailyMinor,
    };
    final bool noBudget = totalMinor <= 0;

    return HairlineCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _BudgetProgressRing(ratio: ratio, over: ratio > 1),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // 指标标签 + 循环切换按钮。
                Row(
                  children: <Widget>[
                    Text(
                      _metricLabels[_metric],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _cycleMetric,
                      child: const Tooltip(
                        message: '切换指标',
                        child: ClayIconTile(
                          size: 32,
                          color: AppPalette.primary,
                          child: LineGlyph(
                            Icons.swap_horiz,
                            size: 16,
                            color: AppPalette.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // 大数位：未设置预算时退化为文字提示。
                Text(
                  noBudget ? '未设置' : Money.fromMinor(shownMinor).format(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: noBudget
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                // 圆点指示器：当前指标实心加宽，其余空心小点。
                Row(
                  children: <Widget>[
                    for (int i = 0; i < _metricLabels.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(right: 5),
                        width: i == _metric ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _metric
                              ? AppPalette.primary
                              : theme.colorScheme.outline,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  noBudget
                      ? '点右上角 ¥ 设置本周期预算'
                      : '已用 ${Money.fromMinor(spentMinor).format()}'
                          ' · 共 ${Money.fromMinor(totalMinor).format()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// sage 渐变进度环：轨道用描边色，进度用 [ForestGradients.sage] 扫掠渐变，
/// 超支（ratio > 1）整环转珊瑚红；环心显示百分比（超支可显 100%+）。
class _BudgetProgressRing extends StatelessWidget {
  const _BudgetProgressRing({required this.ratio, required this.over});

  /// 已用 / 总预算，可超过 1（超支）。
  final double ratio;

  /// 是否超支（决定环色）。
  final bool over;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int percent = (ratio * 100).round();
    return SizedBox(
      width: 92,
      height: 92,
      child: CustomPaint(
        painter: _RingPainter(
          ratio: ratio.clamp(0.0, 1.0),
          track: theme.colorScheme.outline,
          over: over,
        ),
        child: Center(
          child: Text(
            '$percent%',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: over ? AppPalette.expense : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.ratio,
    required this.track,
    required this.over,
  });

  final double ratio;
  final Color track;
  final bool over;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    const double strokeW = 10;
    final double radius = (size.width - strokeW) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    // 轨道环。
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..color = track,
    );
    if (ratio <= 0) return;

    final Paint progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;
    if (over) {
      progress.color = AppPalette.expense;
    } else {
      // 扫掠渐变从 12 点方向起步（与弧起点对齐），色值取设计令牌
      // ForestGradients.sage（浅 sage → 深 sage）。
      progress.shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: ForestGradients.sage.colors,
      ).createShader(rect);
    }
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * ratio, false, progress);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.ratio != ratio || old.track != track || old.over != over;
}
