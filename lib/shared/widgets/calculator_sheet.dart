import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import 'amount_keypad.dart';

/// 安全的中缀算术求值：仅支持非负数字与 `+ - * /` 运算符。
///
/// 返回 `null` 表示表达式非法（空、含非法字符、以运算符结尾、除零等）。
/// 不抛异常，供 UI 实时调用与单测断言。
double? evaluateExpression(String input) {
  final String expr = input.trim();
  if (expr.isEmpty) return null;

  // 分词：数字（含小数）与单字符运算符。
  final List<String> tokens = <String>[];
  final StringBuffer buf = StringBuffer();
  for (int i = 0; i < expr.length; i++) {
    final String ch = expr[i];
    if (ch == ' ' || ch == '\t') continue;
    if (ch == '+' ||
        ch == '-' ||
        ch == '*' ||
        ch == '/' ||
        ch == 'x' ||
        ch == 'X' ||
        ch == '×' ||
        ch == '÷') {
      if (buf.isNotEmpty) {
        tokens.add(buf.toString());
        buf.clear();
      }
      tokens.add(ch == '×'
          ? '*'
          : ch == '÷'
              ? '/'
              : ch);
    } else if (ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57 || ch == '.') {
      buf.write(ch);
    } else {
      return null; // 非法字符
    }
  }
  if (buf.isNotEmpty) tokens.add(buf.toString());
  if (tokens.isEmpty) return null;
  // 必须以数字结尾，且不能出现连续运算符。
  if (double.tryParse(tokens.last) == null) return null;

  final List<double> values = <double>[];
  final List<String> ops = <String>[];
  const Map<String, int> precedence = <String, int>{
    '+': 1,
    '-': 1,
    '*': 2,
    '/': 2,
  };

  double? toNum(String t) => double.tryParse(t);
  void apply(String op) {
    if (values.length < 2) throw const FormatException('need two operands');
    final double b = values.removeLast();
    final double a = values.removeLast();
    switch (op) {
      case '+':
        values.add(a + b);
      case '-':
        values.add(a - b);
      case '*':
        values.add(a * b);
      case '/':
        if (b == 0) throw const FormatException('div by zero');
        values.add(a / b);
    }
  }

  try {
    for (final String t in tokens) {
      final double? n = toNum(t);
      if (n != null) {
        values.add(n);
      } else {
        // 运算符：先压栈或先消更高的同/高优先级。
        while (ops.isNotEmpty && precedence[ops.last]! >= precedence[t]!) {
          apply(ops.removeLast());
        }
        ops.add(t);
      }
    }
    while (ops.isNotEmpty) {
      apply(ops.removeLast());
    }
  } on FormatException {
    return null;
  }
  if (values.length != 1) return null;
  return values.single;
}

/// AA 分摊：把 [total] 均分到 [people] 人，返回每人均摊金额。
///
/// [people] <= 0 时返回 0（避免除零）；金额保留两位小数的分摊语义由调用方决定。
double aaSplit(double total, int people) {
  if (people <= 0) return 0;
  return total / people;
}

String _formatCurrency(double v) {
  final String s = v.toStringAsFixed(2);
  return s.contains('.')
      ? s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')
      : s;
}

/// 快捷计算器：四则运算 + 多人 AA 分摊。
///
/// 点击底部按钮把结果（元）通过 [Navigator.pop] 返回给调用方，
/// 由调用方写回金额输入框。金额换算（汇率）不在本组件范围。
class CalculatorSheet extends StatefulWidget {
  const CalculatorSheet({super.key, this.initial});

  /// 初始表达式（如当前已输入的金额），可选。
  final String? initial;

  @override
  State<CalculatorSheet> createState() => _CalculatorSheetState();
}

class _CalculatorSheetState extends State<CalculatorSheet> {
  String _expr = '';
  bool _aaMode = false;
  final TextEditingController _aaTotal = TextEditingController();
  final TextEditingController _aaPeople = TextEditingController();

  @override
  void initState() {
    super.initState();
    _expr = widget.initial?.trim() ?? '';
  }

  @override
  void dispose() {
    _aaTotal.dispose();
    _aaPeople.dispose();
    super.dispose();
  }

  double? get _computed {
    if (_aaMode) {
      final double? total = double.tryParse(_aaTotal.text.trim());
      final int? people = int.tryParse(_aaPeople.text.trim());
      if (total == null || people == null) return null;
      return aaSplit(total, people);
    }
    return evaluateExpression(_expr);
  }

  void _tap(String v) {
    setState(() {
      if (v == 'AC') {
        _expr = '';
      } else if (v == '⌫') {
        if (_expr.isNotEmpty) _expr = _expr.substring(0, _expr.length - 1);
      } else if (v == '=') {
        final double? r = evaluateExpression(_expr);
        if (r != null) _expr = _formatCurrency(r);
      } else {
        _expr += v;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double? result = _computed;
    final String displayExpr = _expr.isEmpty ? '0' : _expr;
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + AppDimens.spaceMd,
        left: AppDimens.spaceLg,
        right: AppDimens.spaceLg,
        top: AppDimens.spaceMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('计算器', style: theme.textTheme.titleMedium),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _aaMode = !_aaMode),
                child: Text(
                  _aaMode ? '四则运算' : 'AA 分摊',
                  style: TextStyle(color: AppPalette.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),
          if (_aaMode)
            _buildAa(context, result)
          else
            _buildExpr(context, displayExpr, result),
          const SizedBox(height: AppDimens.spaceMd),
          if (!_aaMode) _buildPad(context),
          const SizedBox(height: AppDimens.spaceMd),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: result == null ? Theme.of(context).colorScheme.outline : AppPalette.primary,
                foregroundColor: result == null ? AppPalette.textTertiary : Theme.of(context).colorScheme.onPrimary,
                disabledBackgroundColor: Theme.of(context).colorScheme.outline,
                disabledForegroundColor: AppPalette.textTertiary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
              ),
              onPressed: result == null
                  ? null
                  : () => Navigator.of(context).pop(result),
              child: Text(
                result == null ? '无效计算' : '填入 ¥${_formatCurrency(result)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpr(BuildContext context, String displayExpr, double? result) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceMd,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            displayExpr,
            style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppPalette.textSecondary,
                ),
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            result == null ? '' : '= ${_formatCurrency(result)}',
            style: theme.textTheme.headlineSmall?.copyWith(
                  color: AppPalette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildAa(BuildContext context, double? result) {
    final ThemeData theme = Theme.of(context);
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      borderSide: BorderSide.none,
    );
    return Column(
      children: <Widget>[
        KeypadField(
          controller: _aaTotal,
          allowDecimal: true,
          decoration: InputDecoration(
            hintText: '总金额',
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: AppPalette.textTertiary,
                ),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest,
            border: border,
            enabledBorder: border,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              borderSide: const BorderSide(color: AppPalette.primary),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceMd,
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        KeypadField(
          controller: _aaPeople,
          allowDecimal: false,
          decoration: InputDecoration(
            hintText: '人数',
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: AppPalette.textTertiary,
                ),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest,
            border: border,
            enabledBorder: border,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              borderSide: const BorderSide(color: AppPalette.primary),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceMd,
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
          child: Text(
            result == null ? '人均 ¥0.00' : '人均 ¥${_formatCurrency(result)}',
            style: theme.textTheme.headlineSmall?.copyWith(
                  color: AppPalette.primary,
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildPad(BuildContext context) {
    const List<String> keys = <String>[
      '7', '8', '9', '÷',
      '4', '5', '6', '×',
      '1', '2', '3', '-',
      '0', '.', '=', '+',
      'AC', '⌫',
    ];
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppDimens.spaceXs,
      crossAxisSpacing: AppDimens.spaceXs,
      childAspectRatio: 1.6,
      children: <Widget>[
        for (final String k in keys)
          _buildKey(context, k),
        const SizedBox.shrink(),
        const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildKey(BuildContext context, String k) {
    final bool highlight = k == '=' || k == 'AC' || k == '⌫';
    return InkWell(
      onTap: () => _tap(k),
      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: highlight
              ? AppPalette.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
        child: Text(
          k,
          style: TextStyle(
            fontSize: 24,
            color: highlight ? AppPalette.primary : AppPalette.textPrimary,
            fontWeight: FontWeight.w500,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

/// 手续费计算器弹窗返回结果。
class FeeCalculatorResult {
  const FeeCalculatorResult({this.fee, this.discount});

  /// 手续费（元字符串）。
  final String? fee;

  /// 优惠（元字符串）。
  final String? discount;
}

/// 手续费计算弹窗（小清账风格）。
///
/// 输入「手续费」与「优惠」，实时计算「剩余手续费 = 手续费 - 优惠」。
/// 点击「保存」返回 [FeeCalculatorResult]，由调用方回填到对应字段。
class FeeCalculatorSheet extends StatefulWidget {
  const FeeCalculatorSheet({
    super.key,
    this.fee,
    this.discount,
  });

  final String? fee;
  final String? discount;

  @override
  State<FeeCalculatorSheet> createState() => _FeeCalculatorSheetState();
}

class _FeeCalculatorSheetState extends State<FeeCalculatorSheet> {
  late final TextEditingController _feeController;
  late final TextEditingController _discountController;

  @override
  void initState() {
    super.initState();
    _feeController = TextEditingController(text: widget.fee ?? '');
    _discountController = TextEditingController(text: widget.discount ?? '');
  }

  @override
  void dispose() {
    _feeController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  double? get _feeValue {
    final String t = _feeController.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  double? get _discountValue {
    final String t = _discountController.text.trim();
    if (t.isEmpty) return 0;
    return double.tryParse(t);
  }

  bool get _isValid {
    final double? fee = _feeValue;
    final double? discount = _discountValue;
    if (fee == null || discount == null) return false;
    return fee >= discount;
  }

  String get _remainingText {
    final double? fee = _feeValue;
    final double? discount = _discountValue;
    if (fee == null || discount == null) return '';
    final double remaining = fee - discount;
    return _formatCurrency(remaining < 0 ? 0 : remaining);
  }

  void _save() {
    if (!_isValid) return;
    final String fee = _feeController.text.trim();
    final String discount = _discountController.text.trim();
    Navigator.of(context).pop(FeeCalculatorResult(
      fee: fee.isEmpty ? null : fee,
      discount: discount.isEmpty ? null : discount,
    ));
  }

  InputDecoration _fieldDecoration(BuildContext context, String hint) {
    final ThemeData theme = Theme.of(context);
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: AppPalette.textTertiary,
          ),
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        borderSide: const BorderSide(color: AppPalette.primary),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceMd,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppDimens.spaceLg,
          right: AppDimens.spaceLg,
          top: AppDimens.spaceMd,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppDimens.spaceMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // 标题栏
                  Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: AppPalette.textSecondary),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      const Expanded(
                        child: Text(
                          '手续费计算',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppPalette.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 32),
                    ],
                  ),
                  const SizedBox(height: AppDimens.spaceMd),
                  // 说明
                  Container(
                    padding: const EdgeInsets.all(AppDimens.spaceMd),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(
                          Icons.info_outline,
                          size: 18,
                          color: AppPalette.textTertiary,
                        ),
                        const SizedBox(width: AppDimens.spaceSm),
                        Expanded(
                          child: Text(
                            '如手续费和优惠都存在的情况，手续费-优惠=真正的手续费',
                            style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppPalette.textSecondary,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceMd),
                  // 手续费
                  KeypadField(
                    controller: _feeController,
                    allowDecimal: true,
                    decoration: _fieldDecoration(context, '手续费'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppDimens.spaceMd),
                  // 优惠
                  KeypadField(
                    controller: _discountController,
                    allowDecimal: true,
                    decoration: _fieldDecoration(context, '优惠'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppDimens.spaceMd),
                  // 剩余手续费
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceMd,
                      vertical: AppDimens.spaceMd,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    ),
                    child: Row(
                      children: <Widget>[
                        Text(
                          '剩余手续费',
                          style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppPalette.textTertiary,
                              ),
                        ),
                        const Spacer(),
                        Text(
                          _remainingText.isEmpty ? '0.00' : _remainingText,
                          style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppPalette.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceLg),
                  // 保存按钮
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _isValid ? AppPalette.primary : Theme.of(context).colorScheme.outline,
                        foregroundColor: _isValid ? Theme.of(context).colorScheme.onPrimary : AppPalette.textTertiary,
                        disabledBackgroundColor: Theme.of(context).colorScheme.outline,
                        disabledForegroundColor: AppPalette.textTertiary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                        ),
                      ),
                      onPressed: _isValid ? _save : null,
                      child: const Text(
                        '保存',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
  }
}
