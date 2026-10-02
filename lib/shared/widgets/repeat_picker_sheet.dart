import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import 'amount_keypad.dart';
import '../../features/installment/domain/repeat_rule.dart';

/// 小青账风格的分期「执行方式 / 重复周期」底部选择面板。
///
/// 支持每天/每周/每月/每年 Tab、间隔步进器、以及对应的星期/日期/月份选择。
class RepeatPickerSheet extends StatefulWidget {
  const RepeatPickerSheet({
    super.key,
    this.initialRule,
  });

  final InstallmentRepeatRule? initialRule;

  static Future<InstallmentRepeatRule?> show(
    BuildContext context, {
    InstallmentRepeatRule? initialRule,
  }) async {
    return showModalBottomSheet<InstallmentRepeatRule?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => RepeatPickerSheet(
        initialRule: initialRule,
      ),
    );
  }

  @override
  State<RepeatPickerSheet> createState() => _RepeatPickerSheetState();
}

class _RepeatPickerSheetState extends State<RepeatPickerSheet> {
  late RepeatUnit _unit;
  late int _interval;
  int? _weekDay;
  final Set<int> _monthDays = <int>{};
  int? _month;

  late final TextEditingController _intervalController;
  late final FocusNode _intervalFocusNode;

  final List<String> _unitLabels = const <String>['每天', '每周', '每月', '每年'];

  @override
  void initState() {
    super.initState();
    final InstallmentRepeatRule rule =
        widget.initialRule ?? InstallmentRepeatRule.monthly;
    _unit = rule.unit;
    _interval = rule.interval.clamp(1, 120);
    _weekDay = rule.weekDay;
    _monthDays.clear();
    if (rule.monthDays != null && rule.monthDays!.isNotEmpty) {
      _monthDays.addAll(rule.monthDays!);
    } else if (rule.monthDay != null) {
      _monthDays.add(rule.monthDay!);
    }
    _month = rule.month;
    _intervalController = TextEditingController(text: '$_interval');
    _intervalFocusNode = FocusNode();
    _intervalFocusNode.addListener(_onIntervalFocusChange);
  }

  @override
  void dispose() {
    _intervalFocusNode.removeListener(_onIntervalFocusChange);
    _intervalFocusNode.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  String get _unitText {
    switch (_unit) {
      case RepeatUnit.day:
        return '天';
      case RepeatUnit.week:
        return '周';
      case RepeatUnit.month:
        return '月';
      case RepeatUnit.year:
        return '年';
    }
  }

  InstallmentRepeatRule get _result => InstallmentRepeatRule(
        unit: _unit,
        interval: _interval,
        weekDay: _unit == RepeatUnit.week ? _weekDay : null,
        monthDays: _unit == RepeatUnit.month && _monthDays.isNotEmpty
            ? _monthDays.toList()
            : null,
        month: _unit == RepeatUnit.year ? _month : null,
      );

  void _onIntervalFocusChange() {
    if (!_intervalFocusNode.hasFocus) {
      _commitIntervalText();
    }
  }

  void _commitIntervalText() {
    final int? parsed = int.tryParse(_intervalController.text.trim());
    if (parsed != null) {
      final int clamped = parsed.clamp(1, 120);
      if (clamped != _interval) {
        setState(() => _interval = clamped);
      }
      if (_intervalController.text != '$clamped') {
        _intervalController.text = '$clamped';
      }
    } else {
      _intervalController.text = '$_interval';
    }
  }

  void _changeInterval(int delta) {
    FocusScope.of(context).unfocus();
    _commitIntervalText();
    setState(() {
      _interval = (_interval + delta).clamp(1, 120);
      _intervalController.text = '$_interval';
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // 键盘弹出时 MediaQuery.viewInsets 变化会触发本 widget 重建，
    // 因此可直接据此判断是否显示底部保存按钮。
    final double keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final bool keyboardVisible = keyboardHeight > 0;

    return AnimatedPadding(
      padding: EdgeInsets.only(
        bottom: keyboardHeight,
      ),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: SafeArea(
        bottom: false,
        child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppDimens.radiusLg),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _buildHeader(theme),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: AppDimens.spaceLg,
                      right: AppDimens.spaceLg,
                      top: AppDimens.spaceMd,
                      bottom: AppDimens.spaceMd,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _buildUnitTabs(theme),
                        const SizedBox(height: AppDimens.spaceLg),
                        _buildCenteredContent(theme),
                      ],
                    ),
                  ),
                ),
              ),
              // 键盘弹出时隐藏保存按钮，让面板更紧凑；点击外部收起键盘后自动重现。
              if (!keyboardVisible)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceLg,
                    AppDimens.spaceMd,
                    AppDimens.spaceLg,
                    0,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_result),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusMd),
                        ),
                      ),
                      child: const Text('保存'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceMd,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Text(
            '重复周期',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Positioned(
            left: 0,
            child: IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.of(context).pop(),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitTabs(ThemeData theme) {
    return Row(
      children: RepeatUnit.values.map((RepeatUnit unit) {
        final bool selected = _unit == unit;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () {
                // 切换 每天/每周/每月/每年 时收起键盘，避免数字键盘遮挡新内容。
                FocusScope.of(context).unfocus();
                setState(() => _unit = unit);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color:
                      selected ? AppPalette.textPrimary : AppPalette.surfaceLight,
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                alignment: Alignment.center,
                child: Text(
                  _unitLabels[unit.index],
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: selected ? Theme.of(context).colorScheme.onPrimary : AppPalette.textPrimary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIntervalStepper(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          '每',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: AppDimens.spaceMd),
        _stepperButton(
          icon: Icons.remove,
          onTap: _interval <= 1 ? null : () => _changeInterval(-1),
        ),
        Container(
          width: 56,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          child:             KeypadField(
              controller: _intervalController,
              allowDecimal: false,
              textAlign: TextAlign.center,
              onChanged: (_) => _commitIntervalText(),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                counterText: '',
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
        ),
        _stepperButton(
          icon: Icons.add,
          onTap: _interval >= 120 ? null : () => _changeInterval(1),
        ),
        const SizedBox(width: AppDimens.spaceMd),
        Text(
          _unitText,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _stepperButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: const BorderRadius.horizontal(
            left: Radius.zero,
            right: Radius.zero,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? Theme.of(context).colorScheme.outline : AppPalette.textSecondary,
        ),
      ),
    );
  }

  /// 把「间隔步进器 + 额外选项」作为整体在固定高度区域内垂直居中，
  /// 保证每天/每周/每年 Tab 切换时视觉中心一致，且面板总高度以「每月」为准不变。
  Widget _buildCenteredContent(ThemeData theme) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double optionsWidth = constraints.maxWidth;
        final double optionsHeight = _calcMonthGridHeight(optionsWidth);
        const double stepperHeight = 40;
        final double contentHeight =
            optionsHeight + stepperHeight + AppDimens.spaceLg;

        return SizedBox(
          height: contentHeight,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _buildIntervalStepper(theme),
                const SizedBox(height: AppDimens.spaceLg),
                _buildExtraOptionsContent(theme, optionsWidth),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExtraOptionsContent(ThemeData theme, double width) {
    switch (_unit) {
      case RepeatUnit.day:
        return const SizedBox.shrink();
      case RepeatUnit.week:
        return _buildWeekDayGrid(theme);
      case RepeatUnit.month:
        return _buildMonthDayGrid(theme, width);
      case RepeatUnit.year:
        return _buildMonthGrid(theme, width);
    }
  }

  /// 计算「每月」选项网格的高度，让所有 tab 的选项区域高度一致。
  double _calcMonthGridHeight(double maxWidth) {
    const int columns = 6;
    const double spacing = 10;
    const double aspectRatio = 3.0;
    final double cellWidth = (maxWidth - (columns - 1) * spacing) / columns;
    final double cellHeight = cellWidth / aspectRatio;
    const int itemCount = 32; // 1-31 日 + 月末
    final int rows = (itemCount + columns - 1) ~/ columns;
    return rows * cellHeight + (rows - 1) * spacing;
  }

  Widget _buildWeekDayGrid(ThemeData theme) {
    const List<String> labels = <String>[
      '周一',
      '周二',
      '周三',
      '周四',
      '周五',
      '周六',
      '周日',
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: List<Widget>.generate(7, (int index) {
        final int value = index + 1;
        final bool selected = _weekDay == value;
        return _optionChip(
          label: labels[index],
          selected: selected,
          onTap: () => setState(() => _weekDay = value),
        );
      }),
    );
  }

  Widget _buildMonthDayGrid(ThemeData theme, double maxWidth) {
    const int columns = 6;
    const double spacing = 10;
    const double aspectRatio = 3.0;
    final double cellWidth = (maxWidth - (columns - 1) * spacing) / columns;
    final double cellHeight = cellWidth / aspectRatio;
    final double fontSize = cellHeight * 0.8;

    final List<Widget> children = <Widget>[];
    for (int day = 1; day <= 31; day++) {
      children.add(_optionChip(
        label: '$day',
        selected: _monthDays.contains(day),
        onTap: () => setState(() {
          if (_monthDays.contains(day)) {
            _monthDays.remove(day);
          } else {
            _monthDays.add(day);
          }
        }),
        width: cellWidth,
        height: cellHeight,
        fontSize: fontSize,
      ));
    }
    children.add(_optionChip(
      label: '月末',
      selected: _monthDays.contains(-1),
      onTap: () => setState(() {
        if (_monthDays.contains(-1)) {
          _monthDays.remove(-1);
        } else {
          _monthDays.add(-1);
        }
      }),
      width: cellWidth,
      height: cellHeight,
      fontSize: fontSize,
    ));
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      alignment: WrapAlignment.center,
      children: children,
    );
  }

  Widget _buildMonthGrid(ThemeData theme, double maxWidth) {
    final List<String> labels = <String>[
      '1月',
      '2月',
      '3月',
      '4月',
      '5月',
      '6月',
      '7月',
      '8月',
      '9月',
      '10月',
      '11月',
      '12月',
    ];
    const int columns = 4;
    const double spacing = 10;
    const double aspectRatio = 2.8;
    final double cellWidth = (maxWidth - (columns - 1) * spacing) / columns;
    final double cellHeight = cellWidth / aspectRatio;
    final double fontSize = cellHeight * 0.7;

    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      childAspectRatio: aspectRatio,
      children: List<Widget>.generate(12, (int index) {
        final int value = index + 1;
        return _optionChip(
          label: labels[index],
          selected: _month == value,
          onTap: () => setState(() => _month = value),
          width: double.infinity,
          height: cellHeight,
          fontSize: fontSize,
        );
      }),
    );
  }

  Widget _optionChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    double? width,
    double? height,
    double? fontSize,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width ?? 64,
        height: height ?? 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppPalette.textPrimary : AppPalette.surfaceLight,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Theme.of(context).colorScheme.onPrimary : AppPalette.textPrimary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: fontSize,
            height: 1.0,
          ),
          overflow: TextOverflow.visible,
        ),
      ),
    );
  }
}
