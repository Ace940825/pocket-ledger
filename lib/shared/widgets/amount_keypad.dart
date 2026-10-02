import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/theme/forest_design_tokens.dart';

/// 工程内数字键盘（记一笔底部键盘的**标准形态**，全工程统一复用）。
///
/// 布局标准：
/// - 4 列网格：数字 1-9 占前三列，右列为 删除 / − / + / 保存；
///   底行为 再记 / 0 / · / 保存（保存为鼠尾草渐变键）。
/// - 有 [onOperator]（记一笔金额/优惠运算键真正接通）或 [fourColumns]=true
///   （记一笔主键盘 / 弹层键盘保留右列占位）时渲染 4 列；[onOperator] 为 null
///   且 [fourColumns]=false（存钱弹窗等自带删除键的场景）时退化为 3 列干净
///   布局（不渲染 − / +），其余键帽样式不变，确保全工程键盘视觉统一。
///
/// 金额以字符串形式在 [value] 中维护，由调用方在 [onChanged] 里落状态，
/// 这样面板顶部的大字金额与键盘保持同步，且不依赖系统软键盘。
///
/// 可选能力：
/// - [onSaveAndMore] 传 null 时「再记」槽位退化为 [onBackspace] 删除键；
///   两者均为 null 且为 4 列带保存键布局时，「再记」以灰显占位渲染
///   （弹层键盘 / 计算器托盘，保持底行 矩形完整，不可点）；
/// - [onOperator] 传 null 时不渲染 − / +（见上，除非 [fourColumns]=true）；
/// - [showSave] = false 时不渲染内置「保存」键（调用方自带保存行）；
/// - [allowDecimal] = false 时为整数模式，禁用「.」键（如执行次数 / 天数）；
/// - [maxDecimalDigits] 放宽小数位（投资净值等场景传 4）。
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onSave,
    this.onSaveAndMore,
    this.onBackspace,
    this.onOperator,
    this.enabled = true,
    this.fourColumns = false,
    this.showSave = true,
    this.allowDecimal = true,
    this.maxDecimalDigits = 2,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onSave;
  final VoidCallback? onSaveAndMore;
  final ValueChanged<String>? onOperator;

  /// 运算键回调（收到 '+' / '-'）。为 null 时 − / + 不渲染（退化为 3 列），
  /// 除非 [fourColumns]=true（记一笔主键盘保留右列占位，− / + 灰显不可点）。
  final VoidCallback? onBackspace;

  /// 强制 4 列网格：记一笔主键盘与弹层键盘需要，即使 [onOperator] 为 null
  /// 也保留右列 删除/−/+ 占位（−/+ 在 [onOperator] 为 null 时灰显不可点）。
  /// 存钱弹窗等自带删除键且 [showSave]=false 的场景保持默认 false
  /// （退化 3 列干净布局，避免右列双删除键）。
  final bool fourColumns;

  final bool enabled;
  final bool showSave;

  /// 是否允许小数点（整数场景传 false 禁用「.」键）。
  final bool allowDecimal;

  /// 小数最大位数（投资净值等场景可放宽到 4）。
  final int maxDecimalDigits;

  static const int _maxIntegerDigits = 12;

  void _input(String s) {
    if (!enabled) return;
    if (s == '.') {
      if (!allowDecimal) return;
      if (value.contains('.')) return;
      onChanged(value.isEmpty ? '0.' : '$value.');
      return;
    }
    if (value.contains('.')) {
      final String decimals = value.split('.')[1];
      if (decimals.length >= maxDecimalDigits) return;
    }
    if (value.replaceAll('.', '').length >= _maxIntegerDigits) return;
    if (value == '0') {
      onChanged(s);
    } else {
      onChanged('$value$s');
    }
  }

  void _backspace() {
    if (!enabled) return;
    if (value.isNotEmpty) {
      onChanged(value.substring(0, value.length - 1));
    } else {
      onBackspace?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasOp = onOperator != null || fourColumns;
    // 4 列且带保存键但没有 再记/删除 回调（弹层键盘、计算器托盘）：
    // 底行左侧渲染灰显「再记」占位，保证 4×4 网格完整、与其他键盘同构。
    final bool showIdleAgain =
        onSaveAndMore == null && onBackspace == null && hasOp && showSave;
    final Widget? actionSlot = onSaveAndMore != null
        ? _AkKey(label: '再记', onTap: enabled ? onSaveAndMore : null)
        : (onBackspace != null
            ? _AkKey(
                label: '删除',
                icon: Icons.backspace_outlined,
                showLabel: false,
                onTap: enabled ? _backspace : null,
              )
            : (showIdleAgain
                ? _AkKey(label: '再记', onTap: null)
                : null));

    final List<Widget> cells = <Widget>[
      _AkDigit('1', () => _input('1')),
      _AkDigit('2', () => _input('2')),
      _AkDigit('3', () => _input('3')),
    ];
    if (hasOp) {
      cells.add(
        _AkKey(
          label: '删除',
          icon: Icons.backspace_outlined,
          showLabel: false,
          onTap: enabled ? _backspace : null,
        ),
      );
    }
    cells
      ..add(_AkDigit('4', () => _input('4')))
      ..add(_AkDigit('5', () => _input('5')))
      ..add(_AkDigit('6', () => _input('6')));
    if (hasOp) {
      cells.add(
        _AkKey(
          label: '-',
          icon: Icons.remove,
          showLabel: false,
          onTap: enabled ? () => onOperator!.call('-') : null,
        ),
      );
    }
    cells
      ..add(_AkDigit('7', () => _input('7')))
      ..add(_AkDigit('8', () => _input('8')))
      ..add(_AkDigit('9', () => _input('9')));
    if (hasOp) {
      cells.add(
        _AkKey(
          label: '+',
          icon: Icons.add,
          showLabel: false,
          onTap: enabled ? () => onOperator!.call('+') : null,
        ),
      );
    }
    if (actionSlot != null) cells.add(actionSlot);
    cells
      ..add(_AkDigit('0', () => _input('0')))
      ..add(
        _AkKey(
          label: '.',
          icon: Icons.circle,
          showLabel: false,
          onTap: enabled && allowDecimal ? () => _input('.') : null,
        ),
      );
    if (showSave) {
      cells.add(_AkKey(label: '保存', onTap: enabled ? onSave : null));
    }
    // 补齐空位使网格始终为整齐矩形（透明占位，不影响交互）。
    final int cols = hasOp ? 4 : 3;
    while (cells.length % cols != 0) {
      cells.add(const SizedBox.shrink());
    }
    final int rows = cells.length ~/ cols;

    // 高度按可用宽度精确计算：键帽 = 键宽/2（childAspectRatio 2.0），
    // 总高 = 行数×键高 + (行数−1)×间距。固定高度会在 3 列（键宽大、行高）
    // 场景下装不下 4 行，导致键盘被截断且 NeverScrollable 无法滚动补看。
    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints cons) {
        const double gap = AppDimens.spaceSm;
        final double tileW = (cons.maxWidth - (cols - 1) * gap) / cols;
        final double tileH = tileW / 2.0;
        final double height = rows * tileH + (rows - 1) * gap;
        return SizedBox(
          height: height,
          child: GridView.count(
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
            crossAxisCount: cols,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
            childAspectRatio: 2.0,
            children: cells,
          ),
        );
      },
    );
  }
}

class _AkDigit extends StatelessWidget {
  const _AkDigit(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: ForestSurface.card,
        border: Border.all(color: ForestNeutral.hairline),
        borderRadius: BorderRadius.circular(14),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppPalette.ink.withValues(alpha: 0.059),
            offset: const Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: ForestNeutral.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _AkKey extends StatelessWidget {
  const _AkKey({
    required this.label,
    this.icon,
    required this.onTap,
    this.showLabel = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool active = onTap != null;
    final bool isSave = label == '保存';
    final bool isAgain = label == '再记';
    final Color contentColor = isSave
        ? Theme.of(context).colorScheme.onPrimary
        : isAgain
            ? (active ? ForestNeutral.textSecondary : theme.disabledColor)
            : active
                ? ForestNeutral.textPrimary
                : theme.disabledColor;
    return Container(
      decoration: BoxDecoration(
        color: isSave
            ? null
            : isAgain
                ? ForestBg.sunken
                : ForestSurface.card,
        gradient: isSave ? ForestGradients.sage : null,
        border: isSave || isAgain
            ? null
            : Border.all(color: ForestNeutral.hairline),
        borderRadius: BorderRadius.circular(14),
        boxShadow: isSave
            ? <BoxShadow>[
                BoxShadow(
                  color: AppPalette.sage600.withValues(alpha: 0.38),
                  offset: const Offset(0, 6),
                  blurRadius: 14,
                ),
              ]
            : isAgain
                ? null
                : <BoxShadow>[
                    BoxShadow(
                      color: AppPalette.ink.withValues(alpha: 0.059),
                      offset: const Offset(0, 1),
                      blurRadius: 3,
                    ),
                  ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null && !isSave && !isAgain)
                Icon(
                  icon,
                  size: label == '.' ? 8 : 20,
                  color: contentColor,
                ),
              if (showLabel || isSave || isAgain)
                Text(
                  label,
                  style: (isSave || isAgain
                          ? theme.textTheme.labelMedium
                          : theme.textTheme.labelSmall)
                      ?.copyWith(
                    color: contentColor,
                    fontWeight: isSave ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: isSave ? 2 : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 兼容旧弹层式键盘的别名：**现已直接委托给标准 [AmountKeypad]**。
///
/// 旧语义（[onConfirm] / [onHide] / [allowDecimal] / [maxDecimalDigits]）全部透传给
/// [AmountKeypad]：确认键映射为「保存」，取消由弹层自身（点击遮罩 / 取消按钮）处理。
/// 原 `00` 快速键与单独的「收起」键不在标准键盘内，已移除（视觉已统一）。
/// 弹层同样使用 4 列标准布局（右列 删除 / − / + 占位 / 保存，− / + 灰显）。
class NumKeypad extends StatelessWidget {
  const NumKeypad({
    super.key,
    required this.value,
    required this.onChanged,
    this.onConfirm,
    this.onHide,
    this.allowDecimal = true,
    this.maxDecimalDigits = 2,
    this.confirmLabel = '完成',
  });

  final String value;
  final ValueChanged<String> onChanged;

  /// 确认键回调（✓）；映射为标准键盘的「保存」键。
  final VoidCallback? onConfirm;

  /// 收起键回调（同义取消）；委托后由弹层自身（遮罩/取消按钮）处理。
  final VoidCallback? onHide;

  /// 是否允许小数点（整数场景传 false 禁用「.」键）。
  final bool allowDecimal;

  /// 小数最大位数。
  final int maxDecimalDigits;

  /// 确认键文案（标准键盘固定为「保存」，此字段保留以兼容旧调用方）。
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return AmountKeypad(
      value: value,
      onChanged: onChanged,
      onSave: onConfirm ?? onHide ?? () {},
      allowDecimal: allowDecimal,
      maxDecimalDigits: maxDecimalDigits,
      showSave: true,
      fourColumns: true,
    );
  }
}

/// 以底部弹层形式弹出工程内数字键盘，返回录入的字符串（取消返回 null）。
///
/// [initial] 为初始值（如当前已填金额）；[allowDecimal] 控制是否允许小数点；
/// [maxDecimalDigits] 放宽小数位（投资净值等传 4）。调用方拿到结果后自行解析落库。
///
/// 键盘本体已统一为工程标准 [AmountKeypad] 4 列布局
/// （右列 删除 / − / + 占位 / 保存，− / + 灰显）。
Future<String?> showAmountKeypad({
  required BuildContext context,
  String initial = '',
  bool allowDecimal = true,
  int maxDecimalDigits = 2,
  String title = '',
  String confirmLabel = '完成',
}) async {
  String value = initial;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext ctx) => StatefulBuilder(
      builder: (BuildContext ctx, StateSetter set) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (title.isNotEmpty) ...<Widget>[
                Center(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppPalette.surfaceMist,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  value.isEmpty ? (title.isEmpty ? '请输入' : title) : value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: value.isEmpty
                        ? AppPalette.textTertiary
                        : Theme.of(ctx).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              NumKeypad(
                value: value,
                allowDecimal: allowDecimal,
                maxDecimalDigits: maxDecimalDigits,
                confirmLabel: confirmLabel,
                onChanged: (String v) => set(() => value = v),
                onHide: () => Navigator.of(ctx).pop(null),
                onConfirm: () => Navigator.of(ctx).pop(value),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 只读输入框：点击即唤起工程内数字键盘（[showAmountKeypad]），不唤起系统软键盘。
///
/// 视觉上等价于普通 [TextField]（[decoration] 透传，或走默认填充样式），
/// 适合一切金额 / 数量 / 份额 / 额度 / 天数等数值录入。文本类字段（名称 / 备注 /
/// 网址）请用系统键盘，不要复用本组件。
class KeypadField extends StatelessWidget {
  const KeypadField({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.prefixText,
    this.suffixIcon,
    this.helperText,
    this.style,
    this.textAlign = TextAlign.start,
    this.onChanged,
    this.allowDecimal = true,
    this.maxDecimalDigits = 2,
    this.title,
    this.decoration,
  });

  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final String? prefixText;
  final Widget? suffixIcon;
  final String? helperText;
  final TextStyle? style;
  final TextAlign textAlign;
  final ValueChanged<String>? onChanged;
  final bool allowDecimal;
  final int maxDecimalDigits;
  final String? title;
  final InputDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    final InputDecoration dec = decoration ??
        InputDecoration(
          labelText: labelText,
          hintText: hintText,
          prefixText: prefixText,
          suffixIcon: suffixIcon,
          helperText: helperText,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        );
    return TextField(
      controller: controller,
      readOnly: true,
      showCursor: false,
      enableInteractiveSelection: false,
      style: style,
      textAlign: textAlign,
      decoration: dec,
      onTap: () async {
        final String? r = await showAmountKeypad(
          context: context,
          initial: controller.text,
          allowDecimal: allowDecimal,
          maxDecimalDigits: maxDecimalDigits,
          title: title ?? labelText ?? hintText ?? '请输入',
        );
        if (r != null) {
          controller.text = r;
          onChanged?.call(r);
        }
      },
    );
  }
}
