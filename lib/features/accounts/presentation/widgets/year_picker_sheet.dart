import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/forest_design_tokens.dart';

/// 底部弹出的年份选择器。
///
/// 参考小青账「资产详情」页：年份选择器以网格展示若干年份，
/// 当前选中年份高亮，底部有取消/确定。
class YearPickerSheet extends StatefulWidget {
  const YearPickerSheet({
    super.key,
    required this.initialYear,
    this.minYear,
    this.maxYear,
  });

  /// 初始选中年份。
  final int initialYear;

  /// 可选最小年份。默认 [initialYear] 往前 2 年。
  final int? minYear;

  /// 可选最大年份。默认 [initialYear] 往后 9 年。
  final int? maxYear;

  @override
  State<YearPickerSheet> createState() => _YearPickerSheetState();
}

class _YearPickerSheetState extends State<YearPickerSheet> {
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int min = widget.minYear ?? widget.initialYear - 2;
    final int max = widget.maxYear ?? widget.initialYear + 9;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '$_selectedYear年',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: ForestNeutral.deepInk,
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              '$min年-$max年',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: ForestNeutral.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceLg),
            Wrap(
              spacing: AppDimens.spaceMd,
              runSpacing: AppDimens.spaceMd,
              alignment: WrapAlignment.center,
              children: List<Widget>.generate(
                max - min + 1,
                (int i) {
                  final int year = min + i;
                  final bool selected = year == _selectedYear;
                  return _YearChip(
                    year: year,
                    selected: selected,
                    onTap: () => setState(() => _selectedYear = year),
                  );
                },
              ),
            ),
            const SizedBox(height: AppDimens.spaceLg),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceMd),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selectedYear),
                    child: const Text('确定'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _YearChip extends StatelessWidget {
  const _YearChip({
    required this.year,
    required this.selected,
    required this.onTap,
  });

  final int year;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color unselectedBg = theme.brightness == Brightness.dark
        ? const Color(0xFF2A2E33)
        : ForestBg.sunken;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceSm,
        ),
        decoration: BoxDecoration(
          gradient: selected ? ForestGradients.sage : null,
          color: selected ? null : unselectedBg,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        alignment: Alignment.center,
        child: Text(
          '$year年',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: selected ? Colors.white : ForestNeutral.textPrimary,
            fontWeight: selected ? FontWeight.w800 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
