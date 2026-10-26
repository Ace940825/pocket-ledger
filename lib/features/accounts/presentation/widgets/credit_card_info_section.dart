import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/features/accounts/data/repay_date.dart';
import 'package:pocket_ledger/shared/models/money.dart';
import 'package:pocket_ledger/shared/widgets/line_icons.dart';
import 'package:pocket_ledger/theme/app_colors.dart';
import 'package:pocket_ledger/theme/app_dimens.dart';

/// 信用卡 / 负债账户的「账单信息区」——**资产详情页与信用卡还款页共用**。
///
/// 内容（对齐小青账参考稿）：
/// 1. 「当前欠款(元) / 可用额度」双列：负债账户正余额 = 欠款（参考稿取正数
///    红色展示）；可用额度 = 信用额度 − 欠款，为负（超额）时转红，额度下方
///    带用度进度条；
/// 2. 账单 / 还款两行三列日期宫格（账单日期 / 出账日期 / 出账天数 +
///    还款日 / 还款日期 / 免息天数），具体日期旁带「当期 / 下期」小签；
/// 3. 右下「分期记账」入口胶囊。
///
/// 日期宫格逻辑（含「当期 / 下期」口径、最长日期实测槽位）只在此处维护，
/// 两个消费页不要各自复制，避免再次分叉。
class CreditCardInfoSection extends StatelessWidget {
  const CreditCardInfoSection({
    super.key,
    required this.account,
    required this.onInstallment,
    this.now,
    this.showInstallment = true,
  });

  final Account account;

  /// 「分期记账」入口：跳添加分期页（由调用方决定路由）。
  final VoidCallback onInstallment;

  /// 可注入的「今天」（测试用）；为空时取 [DateTime.now]。
  final DateTime? now;

  /// 是否展示右下「分期记账」入口：还款列表卡片不需要（避免与「还款」按钮
  /// 抢视觉），资产详情页保留。
  final bool showInstallment;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final DateTime now = this.now ?? DateTime.now();

    // 负债方向账户正余额 = 当前欠款；展示按参考稿取正数红色表意。
    final int debt = account.balanceMinor;
    final int? limit = account.creditLimitMinor;
    final int? available = limit == null ? null : limit - debt;
    final bool overLimit = available != null && available < 0;
    final double usedRatio =
        (limit != null && limit > 0) ? (debt / limit).clamp(0.0, 1.0) : 0.0;

    final int? billingDay = account.billingDay;
    final DateTime? nextBilling =
        billingDay == null ? null : nextMonthlyDate(billingDay, now);
    final DateTime? nextDue = nextDueDate(account, now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // 当前欠款 / 可用额度 双列
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _fieldLabel(context, '当前欠款(元)'),
                  const SizedBox(height: 1),
                  Text(
                    Money.fromMinor(debt).format(showSymbol: false),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppPalette.expense,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            // 未设信用额度（如普通负债账户）时不展示可用额度列，
            // 欠款数字独占一行，避免出现无意义的「0.00」。
            if (limit != null)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _fieldLabel(context, '可用额度'),
                    const SizedBox(height: 1),
                    Text(
                      Money.fromMinor(available ?? 0).format(showSymbol: false),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color:
                            overLimit ? AppPalette.expense : scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (limit > 0) ...<Widget>[
                      const SizedBox(height: 4),
                      // 用度进度条：超额（可用<0）转红、满格。
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusSm),
                        child: LinearProgressIndicator(
                          value: usedRatio,
                          minHeight: 4,
                          color: overLimit
                              ? AppPalette.expense
                              : AppPalette.primary,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
        const Divider(height: AppDimens.md),
        // 日期宫格第一行：账单日期 / 出账日期 / 出账天数
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _DateCell(
                label: '账单日期',
                value: billingDay == null ? '—' : '每月$billingDay号',
              ),
            ),
            Expanded(
              child: _DateCell(
                label: '出账日期',
                value: nextBilling == null ? '—' : _fmtDate(nextBilling),
                tag: _periodTag(nextBilling, now),
              ),
            ),
            Expanded(
              child: _DateCell(
                label: '出账天数',
                value: nextBilling == null
                    ? '—'
                    : '剩${_daysUntil(nextBilling, now)}天',
              ),
            ),
          ],
        ),
        const Divider(height: AppDimens.md),
        // 日期宫格第二行：还款日 / 还款日期 / 免息天数
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _DateCell(
                label: '还款日',
                value: repaySummary(account),
              ),
            ),
            Expanded(
              child: _DateCell(
                label: '还款日期',
                value: nextDue == null ? '—' : _fmtDate(nextDue),
                tag: _periodTag(nextDue, now),
              ),
            ),
            Expanded(
              child: _DateCell(
                label: '免息天数',
                value:
                    nextDue == null ? '—' : '剩${_daysUntil(nextDue, now)}天',
              ),
            ),
          ],
        ),
        if (showInstallment) ...<Widget>[
          const SizedBox(height: AppDimens.xs),
          // 「分期记账」入口（右下，参考稿同款浅绿胶囊）
          Align(
            alignment: Alignment.centerRight,
            child: _InstallmentPill(onTap: onInstallment),
          ),
        ],
      ],
    );
  }
}

/// 「分期记账」入口胶囊：浅绿底 + 日历¥ 线稿图标。
class _InstallmentPill extends StatelessWidget {
  const _InstallmentPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppPalette.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const LineIcon(
              LineIconKind.installment,
              size: 16,
              color: AppPalette.primary,
            ),
            const SizedBox(width: 6),
            Text(
              '分期记账',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppPalette.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 字段小标签（如「当前欠款(元)」）。
Widget _fieldLabel(BuildContext context, String text) {
  return Text(
    text,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
  );
}

/// 日期宫格子项：label + 值（可带「当期 / 下期」小签）。
class _DateCell extends StatelessWidget {
  const _DateCell({
    required this.label,
    required this.value,
    this.tag,
  });

  final String label;
  final String value;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    // 日期值样式：槽位量宽与正文渲染共用同一样式，保证实测宽度即渲染宽度。
    final TextStyle? valueStyle = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w600,
    );
    // 小签样式（须与下方 Container 内 Text 完全一致，实测占位才准）。
    final TextStyle? tagStyle = theme.textTheme.labelSmall?.copyWith(
      color: AppPalette.primary,
      fontWeight: FontWeight.w600,
      fontSize: 10,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        // 日期 + 「当期 / 下期」小签：日期串宽度随月/日位数变化
        // （「11月1日」比「10月26日」窄约一个数字位），小签若紧跟日期尾随，
        // 两行小签会错位；若让小签贴单元格右缘，最短日期与小签之间又会拉出
        // 大空档、小签顶到第三列。
        // 正解：日期格式固定为「M月D日」，最宽即「12月31日」——按它实测出
        // 槽位宽度，日期占满槽位（不足则留空），小签固定在槽位右侧 →
        // 两行小签纵向严格对齐，与单元格右缘无关。
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // 槽位封顶：可用宽度 − 小签占位，保证「日期 + 小签」整体永不
            // 超出单元格（大字号无障碍缩放时日期走自身 ellipsis，小签始终
            // 可见）；空间富余时封顶不起作用，槽位即最长日期宽，两行小签
            // 落点不变。小签占位 = 左 margin 4 + 容器水平 padding 8 +
            // 文字实测宽（'当期' / '下期' 等宽）。
            final double tagRoom = tag == null
                ? 0
                : 4 + 8 + _textWidth(context, tagStyle, '当期');
            final double slot = math.min(
              _dateSlotWidth(context, valueStyle),
              math.max(0, constraints.maxWidth - tagRoom - 0.5),
            );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                // 严格槽位（SizedBox 而非 ConstrainedBox(minWidth)）：
                // 短日期被补齐到最长日期宽 → 小签落点恒定；长日期/窄单元格
                // 下由 Text 自身 ellipsis 收缩，不会撑破行。
                SizedBox(
                  width: slot,
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: valueStyle,
                  ),
                ),
                if (tag != null)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppPalette.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      tag!,
                      style: tagStyle,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// 按当前文字样式实测 [text] 的渲染宽度（含无障碍文字缩放）。
double _textWidth(BuildContext context, TextStyle? style, String text) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final double width = painter.width;
  painter.dispose();
  return width;
}

/// 日期值槽位宽度：日期格式固定为「M月D日」（见 [_fmtDate]），最宽串即
/// 「12月31日」——按当前文字样式实测其渲染宽度（含无障碍文字缩放），
/// 作为 [_DateCell] 值行的最小宽度：小签落点只取决于最长日期，
/// 不随单元格剩余宽度漂移，也不会被推到单元格右缘。
double _dateSlotWidth(BuildContext context, TextStyle? style) =>
    _textWidth(context, style, '12月31日');

/// 「当期 / 下期」小签口径（出账日期、还款日期共用）：
/// - 本月的该日期**已过**（含今天，见 [nextMonthlyDate]）→ 展示的是下月日期 →「下期」；
/// - 本月还没到 → 展示的就是本期日期 →「当期」。
String? _periodTag(DateTime? date, DateTime now) {
  if (date == null) return null;
  final bool sameMonth = date.year == now.year && date.month == now.month;
  return sameMonth ? '当期' : '下期';
}

/// 下一个「每月 [day] 号」的日期——实现见 [nextMonthlyDate]（共享 helper）。

/// 从「今天」到 [target] 的自然日天数（整数，稳定不随时刻抖动）。
int _daysUntil(DateTime target, DateTime now) {
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime t = DateTime(target.year, target.month, target.day);
  return t.difference(today).inDays;
}

String _fmtDate(DateTime d) => '${d.month}月${d.day}日';
