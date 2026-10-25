import 'package:flutter/material.dart';

import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/features/accounts/data/repay_date.dart';
import 'package:pocket_ledger/shared/widgets/line_icon_map.dart';
import 'package:pocket_ledger/shared/widgets/sheet_scaffold.dart';
import 'package:pocket_ledger/theme/app_colors.dart';
import 'package:pocket_ledger/theme/app_dimens.dart';

/// 还款日设定弹窗结果：两种模式互斥，调用方按 [mode] 决定取哪一侧。
class RepayDateResult {
  const RepayDateResult({
    required this.mode,
    this.dueDay,
    this.dueGraceDays,
  });

  final RepayMode mode;

  /// 固定日期模式下的值（每月 X 日，1-31）。
  final int? dueDay;

  /// 免息期模式下的值（账单日后 N 天）。
  final int? dueGraceDays;
}

/// 打开「还款日」设定弹窗：固定日期 / 免息期 两种模式并行，底部确定返回。
///
/// [initialBillingDay] 用于免息期模式的「账单日 + N 天 = 还款日」实时预览；
/// 账单日缺失时免息期模式不可用（预览提示先填账单日）。
Future<RepayDateResult?> showRepayDatePickerSheet(
  BuildContext context, {
  required int? initialBillingDay,
  int? initialDueDay,
  int? initialDueGraceDays,
}) {
  final RepayMode initialMode =
      initialDueGraceDays != null ? RepayMode.graceDays : RepayMode.fixedDay;
  return showAppModalSheet<RepayDateResult>(
    context,
    title: '还款日',
    // 与 showDayPickSheet 同口径：允许突破 9/16 路由帽。本弹窗比纯宫格多
    // 一段分段控件 + 说明文案，不放开高度帽时小屏机型内容超出 body 槽位
    // 直接 RenderFlex 溢出（真机「BOTTOM OVERFLOWED BY 179 PIXELS」）。
    isScrollControlled: true,
    bodyPadding: EdgeInsets.zero,
    surfaceColor: AppPalette.white,
    body: _RepayDatePickerSheet(
      initialBillingDay: initialBillingDay,
      initialMode: initialMode,
      initialDueDay: initialDueDay,
      initialDueGraceDays: initialDueGraceDays,
    ),
  );
}

class _RepayDatePickerSheet extends StatefulWidget {
  const _RepayDatePickerSheet({
    required this.initialBillingDay,
    required this.initialMode,
    this.initialDueDay,
    this.initialDueGraceDays,
  });

  final int? initialBillingDay;
  final RepayMode initialMode;
  final int? initialDueDay;
  final int? initialDueGraceDays;

  @override
  State<_RepayDatePickerSheet> createState() => _RepayDatePickerSheetState();
}

class _RepayDatePickerSheetState extends State<_RepayDatePickerSheet> {
  late RepayMode _mode;
  late int _dueDay;
  late int _graceDays;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _dueDay = widget.initialDueDay ?? 10;
    _graceDays = widget.initialDueGraceDays ?? 20;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 模式分段控件：固定日期 / 免息期 并行二选一。
          _SegmentedControl(
            mode: _mode,
            onChanged: (RepayMode m) => setState(() => _mode = m),
          ),
          const SizedBox(height: 16),
          // 模式内容区：Flexible(loose) 槽位——上限 = 弹窗实际可用高减去
          // 分段控件 / 按钮等非弹性同级。内容够高时取自然高（ListView
          // shrinkWrap），超高时在槽位内滚动而非撑爆 Column（小屏兜底）；
          // 底部「取消 / 确定」始终可见，不随内容滚动。
          Flexible(
            fit: FlexFit.loose,
            child: _mode == RepayMode.fixedDay
                ? _buildFixedDaySection(scheme)
                : _buildGraceSection(scheme),
          ),
          const SizedBox(height: 10),
          // 底部右侧：取消 + 确定。
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                  textStyle: const TextStyle(fontSize: 15),
                ),
                child: const Text('取消'),
              ),
              const SizedBox(width: 12),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.of(context).pop(
                    RepayDateResult(
                      mode: _mode,
                      dueDay: _mode == RepayMode.fixedDay ? _dueDay : null,
                      dueGraceDays:
                          _mode == RepayMode.graceDays ? _graceDays : null,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.sageLeaf,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      '确定',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFixedDaySection(ColorScheme scheme) {
    // shrinkWrap：内容未超槽位时按自然高布局（无空白、无滚动条），
    // 超出时由外层 Flexible 槽位收口、内部滚动。
    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            '每月固定还款日',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          padding: EdgeInsets.zero,
          childAspectRatio: 1,
          children: <Widget>[
            for (int day = 1; day <= 31; day++) _dayCell(day, scheme),
          ],
        ),
      ],
    );
  }

  Widget _buildGraceSection(ColorScheme scheme) {
    final DateTime now = DateTime.now();
    final bool hasBilling = widget.initialBillingDay != null;
    final DateTime? preview = hasBilling
        ? nextMonthlyDate(widget.initialBillingDay!, now)
            .add(Duration(days: _graceDays))
        : null;
    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '账单日后 N 天还款（即免息期）',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        // 步进器：− / 数值 / +，范围 0-60 天。
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _StepButton(
              icon: Icons.remove,
              onTap: _graceDays > 0
                  ? () => setState(() => _graceDays--)
                  : null,
            ),
            SizedBox(
              width: 96,
              child: Column(
                children: <Widget>[
                  Text(
                    '$_graceDays',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text('天', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            _StepButton(
              icon: Icons.add,
              onTap: _graceDays < 60
                  ? () => setState(() => _graceDays++)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 14),
        // 实时预览：账单日 X 号 + N 天 = 还款日 Y月Z日。
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimens.md),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
          child: preview == null
              ? Text(
                  '请先在上方填写账单日后再设定免息期',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                )
              : RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onSurface,
                    ),
                    children: <TextSpan>[
                      TextSpan(
                        text:
                            '账单日${widget.initialBillingDay}号 + $_graceDays天 = ',
                      ),
                      TextSpan(
                        text: '${preview.month}月${preview.day}日',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppPalette.primary,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _dayCell(int day, ColorScheme scheme) {
    final bool selected = day == _dueDay;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _dueDay = day),
      child: Center(
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? AppPalette.sageLeaf : Colors.transparent,
          ),
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 16,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? AppPalette.white : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({required this.mode, required this.onChanged});

  final RepayMode mode;
  final ValueChanged<RepayMode> onChanged;

  static const List<_SegItem> _items = <_SegItem>[
    _SegItem(mode: RepayMode.fixedDay, label: '固定日期'),
    _SegItem(mode: RepayMode.graceDays, label: '免息期'),
  ];

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Row(
        children: <Widget>[
          for (final _SegItem item in _items) ...<Widget>[
            if (item != _items.first) const SizedBox(width: 4),
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(item.mode),
                child: Container(
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: mode == item.mode
                        ? scheme.surface
                        : Colors.transparent,
                    borderRadius:
                        BorderRadius.circular(AppDimens.radiusSm + 2),
                    boxShadow: mode == item.mode
                        ? <BoxShadow>[
                            BoxShadow(
                              color: scheme.shadow.withValues(alpha: 0.12),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: mode == item.mode
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: mode == item.mode
                          ? AppPalette.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SegItem {
  const _SegItem({required this.mode, required this.label});
  final RepayMode mode;
  final String label;
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled
                ? AppPalette.primary.withValues(alpha: 0.12)
                : scheme.surfaceContainerHighest,
          ),
          child: LineGlyph(
            icon,
            size: 20,
            color: enabled
                ? AppPalette.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
