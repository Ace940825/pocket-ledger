import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_dimens.dart';

/// 分段/开关行（全应用统一）：等宽胶囊分组，选中态填充、未选透明。
///
/// 用于「借入 / 借出」「买入 / 卖出」「收入 / 支出」等二元或多元切换。
///
/// 三种视觉变体：
/// - [SegmentVariant.solid]（默认）：未选淡底轨道 + 选中主色实心，白字；通用中性风格。
/// - [SegmentVariant.sageGradient]：奶油/浅绿轨道 + 选中鼠尾草绿渐变（对标品牌 _Sage.sage）；
///   文字色可用 [selectedTextColor] 覆盖（借还白字、投资深绿字两种口径）。
///
/// 既有页面多为此二风格，迁移时按原底选择 [variant] 即可零偏差落地；
/// 如需纯色定制可传 [selectedColor]。
enum SegmentVariant { solid, sageGradient }

/// 鼠尾草绿渐变（同 ForestGradients.sage / _Sage.sage），内联避免反向依赖 core/theme。
const LinearGradient _sageGradient = LinearGradient(
  colors: <Color>[AppPalette.sageMist, AppPalette.sageRibbon],
);

/// sage 选中态投影（同 _Sage 原 selected 投影）。
final List<BoxShadow> _sageSelectedShadow = <BoxShadow>[
  BoxShadow(
    color: AppPalette.sage600.withValues(alpha: 0.35),
    blurRadius: 10,
    offset: const Offset(0, 3),
  ),
];

class SegmentOption<T> {
  const SegmentOption({
    required this.value,
    required this.label,
    this.leading,
  });

  final T value;
  final String label;
  final Widget? leading;
}

class SegmentedRow<T> extends StatelessWidget {
  const SegmentedRow({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.variant = SegmentVariant.solid,
    this.selectedColor,
    this.selectedTextColor,
    this.unselectedTextColor,
    this.trackColor,
    this.trackBorderColor,
    this.trackHasShadow = false,
    // 旧版 core/constants AppDimens 的 radiusMd/radiusSm（12/8），
    // 新 lib/theme 令牌无此二者，先以字面量保持原视觉。
    this.radius = 12,
    this.itemRadius,
    this.itemHeight = 38,
    this.gap = 4,
    this.padding = const EdgeInsets.all(4),
    this.textStyle,
  });

  final List<SegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final SegmentVariant variant;
  final Color? selectedColor;
  final Color? selectedTextColor;
  final Color? unselectedTextColor;
  final Color? trackColor;
  final Color? trackBorderColor;
  final bool trackHasShadow;
  final double radius;
  final double? itemRadius;
  final double itemHeight;
  final double gap;
  final EdgeInsetsGeometry padding;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool sage = variant == SegmentVariant.sageGradient;
    final Color trackBg =
        trackColor ?? (sage ? scheme.surface : scheme.surfaceContainerHighest);
    final Color? trackBorder =
        trackBorderColor ?? (sage ? scheme.outline : null);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: trackBg,
        border: trackBorder == null ? null : Border.all(color: trackBorder),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: trackHasShadow ? context.app.shadowSm : null,
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < options.length; i++) ...<Widget>[
            if (i > 0) SizedBox(width: gap),
            Expanded(
              child: _SegmentButton<T>(
                option: options[i],
                selected: options[i].value == value,
                sage: sage,
                selectedColor: selectedColor,
                selectedTextColor: selectedTextColor,
                unselectedTextColor: unselectedTextColor,
                itemRadius: itemRadius ?? 8,
                itemHeight: itemHeight,
                textStyle: textStyle,
                onChanged: onChanged,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SegmentButton<T> extends StatelessWidget {
  const _SegmentButton({
    required this.option,
    required this.selected,
    required this.sage,
    required this.selectedColor,
    required this.selectedTextColor,
    required this.unselectedTextColor,
    required this.itemRadius,
    required this.itemHeight,
    required this.textStyle,
    required this.onChanged,
  });

  final SegmentOption<T> option;
  final bool selected;
  final bool sage;
  final Color? selectedColor;
  final Color? selectedTextColor;
  final Color? unselectedTextColor;
  final double itemRadius;
  final double itemHeight;
  final TextStyle? textStyle;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color fg = selected
        ? (selectedTextColor ?? (sage ? scheme.onPrimary : AppPalette.white))
        : (unselectedTextColor ?? scheme.onSurfaceVariant);

    final Decoration decoration;
    if (selected && sage) {
      decoration = BoxDecoration(
        gradient: _sageGradient,
        borderRadius: BorderRadius.circular(itemRadius),
        boxShadow: _sageSelectedShadow,
      );
    } else if (selected) {
      decoration = BoxDecoration(
        color: selectedColor ?? scheme.primary,
        borderRadius: BorderRadius.circular(itemRadius),
      );
    } else {
      decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(itemRadius),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(itemRadius),
      onTap: () => onChanged(option.value),
      child: Container(
        height: itemHeight,
        alignment: Alignment.center,
        decoration: decoration,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (option.leading != null) ...<Widget>[
              option.leading!,
              const SizedBox(width: 6),
            ],
            Text(
              option.label,
              style: (textStyle ?? const TextStyle(fontSize: 14)).copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
