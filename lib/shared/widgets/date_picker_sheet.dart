import 'package:flutter/material.dart';

import 'package:pocket_ledger/features/accounts/data/repay_date.dart';
import 'package:pocket_ledger/shared/widgets/sheet_scaffold.dart';
import 'package:pocket_ledger/theme/app_colors.dart';
import 'package:pocket_ledger/theme/app_dimens.dart';

/// 共享层：账单日 / 还款日 日期选择器。
///
/// 由账户页（`account_edit_page` / `account_form_page`）与卡片管理页
/// （`card_edit_page`）共用，避免各页面重复实现同一套「绿底圆选 + 7 列宫格」
/// 的弹窗。账户页使用 [RepayMode] 枚举；卡片页使用 [CardRepayMode]，调用方
/// 在取值后自行按 [RepayDateResult] 映射回各自的枚举（持久化模型不变）。

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

/// 圆形数字单元格（固定日期 / 免息期 / 账单日 三处共用，保证布局一致）。
Widget roundNumberCell(
  BuildContext context,
  int value,
  bool selected,
  VoidCallback onTap,
) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
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
          '$value',
          style: TextStyle(
            fontSize: 16,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? AppPalette.white : context.forest.onSurface,
          ),
        ),
      ),
    ),
  );
}

/// 账单日（每月几号）选择器：7 列数字网格（1-31），与还款日选择器同款绿底选中。
///
/// 返回选中的「每月第几号」（1-31）；取消/点遮罩返回 null。
Future<int?> showDayPickerSheet(
  BuildContext context, {
  required int? initialDay,
  String title = '账单日',
}) {
  return showAppModalSheet<int>(
    context,
    title: title,
    isScrollControlled: true,
    bodyPadding: EdgeInsets.zero,
    surfaceColor: AppPalette.white,
    body: _DayPickerSheet(initialDay: initialDay),
  );
}

class _DayPickerSheet extends StatefulWidget {
  const _DayPickerSheet({this.initialDay});

  final int? initialDay;

  @override
  State<_DayPickerSheet> createState() => _DayPickerSheetState();
}

class _DayPickerSheetState extends State<_DayPickerSheet> {
  late int _day;

  @override
  void initState() {
    super.initState();
    _day = widget.initialDay ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              '每月固定账单日',
              style: TextStyle(
                fontSize: 13,
                color: context.forest.onSurfaceVariant,
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
              for (int d = 1; d <= 31; d++)
                roundNumberCell(
                  context,
                  d,
                  d == _day,
                  () => setState(() => _day = d),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: context.forest.onSurfaceVariant,
                  textStyle: const TextStyle(fontSize: 15),
                ),
                child: const Text('取消'),
              ),
              const SizedBox(width: 12),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.of(context).pop(_day),
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
    // 标题不再写死：下放至 [_RepayDatePickerSheet] 内部，随分段控件
    // （固定日期 / 免息期）实时同步变更（见 build 顶部动态标题行）。
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // 动态标题：随分段控件（固定日期 / 免息期）实时同步。
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.md,
            vertical: AppDimens.sm,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: context.forest.outline,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _mode == RepayMode.graceDays ? '免息期' : '还款日',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: context.forest.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
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
                    ? _buildFixedDaySection()
                    : _buildGraceSection(),
              ),
              const SizedBox(height: 10),
              // 底部右侧：取消 + 确定。
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: context.forest.onSurfaceVariant,
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
        ),
      ],
    );
  }

  Widget _buildFixedDaySection() {
    // shrinkWrap：内容未超槽位时按自然高布局（无空白、无滚动条），
    // 超出时由外层 Flexible 槽位收口、内部滚动。
    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '每月固定还款日',
            style: TextStyle(
              fontSize: 13,
              color: context.forest.onSurfaceVariant,
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
            for (int day = 1; day <= 31; day++)
              _roundNumberCell(
                day,
                day == _dueDay,
                () => setState(() => _dueDay = day),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildGraceSection() {
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
              color: context.forest.onSurfaceVariant,
            ),
          ),
        ),
        // 与「固定日期」同款 7 列数字网格（1-31 天），点选即生效。
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          padding: EdgeInsets.zero,
          childAspectRatio: 1,
          children: <Widget>[
            for (int d = 1; d <= 31; d++)
              _roundNumberCell(
                d,
                d == _graceDays,
                () => setState(() => _graceDays = d),
              ),
          ],
        ),
      ],
    );
  }

  /// 圆形数字单元格（委托给模块级 [roundNumberCell]，三处共用）。
  Widget _roundNumberCell(int value, bool selected, VoidCallback onTap) =>
      roundNumberCell(context, value, selected, onTap);
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
        color: context.forest.surfaceContainerHighest,
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
                        ? context.forest.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm + 2),
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
                      fontWeight:
                          mode == item.mode ? FontWeight.w700 : FontWeight.w400,
                      color: mode == item.mode
                          ? AppPalette.primary
                          : context.forest.onSurfaceVariant,
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
