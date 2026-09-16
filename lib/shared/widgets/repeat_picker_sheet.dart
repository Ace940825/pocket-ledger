import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
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
  int? _monthDay;
  int? _month;

  final List<String> _unitLabels = const <String>['每天', '每周', '每月', '每年'];

  @override
  void initState() {
    super.initState();
    final InstallmentRepeatRule rule =
        widget.initialRule ?? InstallmentRepeatRule.monthly;
    _unit = rule.unit;
    _interval = rule.interval.clamp(1, 120);
    _weekDay = rule.weekDay;
    _monthDay = rule.monthDay;
    _month = rule.month;
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
        monthDay: _unit == RepeatUnit.month ? _monthDay : null,
        month: _unit == RepeatUnit.year ? _month : null,
      );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceLg,
                    vertical: AppDimens.spaceMd,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _buildUnitTabs(theme),
                      const SizedBox(height: AppDimens.spaceLg),
                      _buildIntervalStepper(theme),
                      const SizedBox(height: AppDimens.spaceLg),
                      _buildExtraOptions(theme),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceLg,
                AppDimens.spaceMd,
                AppDimens.spaceLg,
                AppDimens.spaceLg,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_result),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
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
            '执行方式',
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
              onTap: () => setState(() => _unit = unit),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.surfaceLight,
                  borderRadius:
                      BorderRadius.circular(AppDimens.radiusMd),
                ),
                alignment: Alignment.center,
                child: Text(
                  _unitLabels[unit.index],
                  style: theme.textTheme.bodyMedium?.copyWith(
                        color: selected ? Colors.white : AppColors.textPrimary,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
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
          onTap: _interval <= 1
              ? null
              : () => setState(() => _interval--),
        ),
        GestureDetector(
          onTap: _editInterval,
          child: Container(
            width: 56,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: AppColors.divider),
              ),
            ),
            child: Text(
              '$_interval',
              style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
        _stepperButton(
          icon: Icons.add,
          onTap: _interval >= 120
              ? null
              : () => setState(() => _interval++),
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

  Future<void> _editInterval() async {
    final TextEditingController controller =
        TextEditingController(text: '$_interval');
    final int? value = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('设置间隔'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: '请输入 1-120 之间的数字',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final int? parsed = int.tryParse(controller.text.trim());
              if (parsed != null && parsed >= 1 && parsed <= 120) {
                Navigator.of(ctx).pop(parsed);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && mounted) {
      setState(() => _interval = value);
    }
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
          border: Border.all(color: AppColors.divider),
          borderRadius: const BorderRadius.horizontal(
            left: Radius.zero,
            right: Radius.zero,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? AppColors.divider : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildExtraOptions(ThemeData theme) {
    switch (_unit) {
      case RepeatUnit.day:
        return const SizedBox.shrink();
      case RepeatUnit.week:
        return _buildWeekDayGrid(theme);
      case RepeatUnit.month:
        return _buildMonthDayGrid(theme);
      case RepeatUnit.year:
        return _buildMonthGrid(theme);
    }
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

  Widget _buildMonthDayGrid(ThemeData theme) {
    final List<Widget> children = <Widget>[];
    for (int day = 1; day <= 31; day++) {
      children.add(_optionChip(
        label: '$day',
        selected: _monthDay == day,
        onTap: () => setState(() => _monthDay = day),
      ),);
    }
    children.add(_optionChip(
      label: '月末',
      selected: _monthDay == -1,
      onTap: () => setState(() => _monthDay = -1),
    ),);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: children,
    );
  }

  Widget _buildMonthGrid(ThemeData theme) {
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
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.8,
      children: List<Widget>.generate(12, (int index) {
        final int value = index + 1;
        return _optionChip(
          label: labels[index],
          selected: _month == value,
          onTap: () => setState(() => _month = value),
          width: double.infinity,
        );
      }),
    );
  }

  Widget _optionChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    double? width,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width ?? 64,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.textPrimary : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
