import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/forest_design_tokens.dart';
import '../../../../database/app_database.dart';
import '../../../../domain/enums.dart';
import '../../../../shared/models/money.dart';
import '../../../../theme/app_dimens.dart';
import '../../data/budget_repository.dart';
import '../../providers/budget_providers.dart';

/// 副统计项（标签 + 金额 + 是否暖色）。
typedef _SubStat = ({String label, int minor, bool warm});

/// 预算主页顶部三态指标卡（2026-10-15 第 26 批，对标小青账「剩余预算」卡）：
///
/// - 三态左右滑动循环切换（可回绕）：剩余预算 → 总预算 → 已用；
///   底部圆点指示器可点按直达；**进入页面默认显「剩余预算」（结余）**；
/// - 卡面用 sage 中档渐变（[ForestGradients.sageMid]，令牌注释即「本月结余卡」），
///   大数位 + 双副统计；已用金额走陶土橙（[ForestAccent.clay]），与参考卡一致；
/// - 无支出方向预算时，「剩余预算 / 总预算」大数位退化为「未设置」。
///
/// 口径：当前账本、当前查看周期（月/年）的**支出方向**预算
/// （scope=overall + 支出分类预算），与「支出预算」分组卡同源；
/// 已用逐条预算按各自生效区间实时聚合（budgetSpentProvider）。
///
/// 历史：第 12 批做过「预算剩余/总预算/剩余日均 + 进度环 + ⇄ 按钮」版本，
/// 第 25 批整卡移除；本批按小青账新参考图重做——去掉 ⇄ 按钮与进度环，
/// 改滑动循环，默认结余。
class BudgetHeroCard extends ConsumerStatefulWidget {
  const BudgetHeroCard({
    super.key,
    required this.budgets,
    required this.catById,
  });

  /// 当前账本在查看周期内的预算行（页面侧已按周期过滤）。
  final List<Budget> budgets;

  /// 分类表（按 id），用于判定分类预算的收支方向。
  final Map<String, Category> catById;

  @override
  ConsumerState<BudgetHeroCard> createState() => _BudgetHeroCardState();
}

class _BudgetHeroCardState extends ConsumerState<BudgetHeroCard> {
  /// 当前态：0=剩余预算（默认）/ 1=总预算 / 2=已用。
  int _idx = 0;

  /// 上一次切换是否向前（供入场滑移动方向使用）。
  bool _forward = true;

  static const int _count = 3;

  /// 循环切换（dir=1 向前 / -1 向后，越界回绕）。
  void _cycle(int dir) {
    setState(() {
      _forward = dir > 0;
      _idx = (_idx + dir + _count) % _count;
    });
  }

  /// 圆点直达。
  void _goTo(int target) {
    if (target == _idx) return;
    setState(() {
      _forward = target > _idx;
      _idx = target;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 120) return;
    _cycle(velocity < 0 ? 1 : -1);
  }

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
                    categoryId: b.categoryId,
                  ),
                ),
              )
              .valueOrNull ??
          0;
    }
    final int remainingMinor = totalMinor - spentMinor;
    final bool noBudget = totalMinor <= 0;

    final Widget pane = switch (_idx) {
      0 => _metricPane(
          theme,
          label: '剩余预算',
          big: remainingMinor,
          bigWarm: remainingMinor < 0,
          bigAsText: noBudget,
          subs: <_SubStat>[
            (label: '总预算', minor: totalMinor, warm: false),
            (label: '已用', minor: spentMinor, warm: true),
          ],
        ),
      1 => _metricPane(
          theme,
          label: '总预算',
          big: totalMinor,
          bigWarm: false,
          bigAsText: noBudget,
          subs: <_SubStat>[
            (label: '已用', minor: spentMinor, warm: true),
            (label: '剩余预算', minor: remainingMinor, warm: remainingMinor < 0),
          ],
        ),
      _ => _metricPane(
          theme,
          label: '已用',
          big: spentMinor,
          bigWarm: false,
          bigAsText: false,
          subs: <_SubStat>[
            (label: '总预算', minor: totalMinor, warm: false),
            (label: '剩余预算', minor: remainingMinor, warm: remainingMinor < 0),
          ],
        ),
    };

    return Container(
      decoration: BoxDecoration(
        gradient: ForestGradients.sageMid,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        boxShadow: ForestElevation.card,
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      // 整卡可左右拖动循环；纵向拖动留给外层 ListView。
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: _transition,
              child: KeyedSubtree(
                key: ValueKey<int>(_idx),
                child: pane,
              ),
            ),
            const SizedBox(height: 14),
            _buildDots(),
          ],
        ),
      ),
    );
  }

  /// 切换入场动画：按方向轻微横滑 + 淡入。
  Widget _transition(Widget child, Animation<double> animation) {
    final Offset begin =
        _forward ? const Offset(0.06, 0) : const Offset(-0.06, 0);
    return SlideTransition(
      position: Tween<Offset>(
        begin: begin,
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: FadeTransition(opacity: animation, child: child),
    );
  }

  /// 单态面板：标签 + 大数位 + 双副统计。
  Widget _metricPane(
    ThemeData theme, {
    required String label,
    required int big,
    required bool bigWarm,
    required bool bigAsText,
    required List<_SubStat> subs,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: ForestSage.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          bigAsText ? '未设置' : Money.fromMinor(big).format(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: bigWarm ? ForestAccent.clay : ForestSage.ink,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (int i = 0; i < subs.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      subs[i].label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: ForestSage.label,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      Money.fromMinor(subs[i].minor).format(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color:
                            subs[i].warm ? ForestAccent.clay : ForestSage.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// 圆点指示器：当前态深绿加宽，其余浅色小点；可点按直达。
  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < _count; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _goTo(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: i == _idx ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _idx
                      ? ForestSage.ink
                      : ForestNeutral.onGreen.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
