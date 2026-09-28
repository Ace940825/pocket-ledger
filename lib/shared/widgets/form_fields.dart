import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../core/constants/app_dimens.dart';

/// 金额输入框。
///
/// 统一约定：输入以「元」为单位的小数，提交时由调用方用
/// `Money.fromDecimal()` 转成「分」整数落库，避免各页面各写一套解析。
///
/// 视觉标准：浅色圆角背景，左侧一条品牌色竖线装饰，内部占位符显示标签。
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    this.label = '金额',
    this.helperText,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? helperText;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const SizedBox(width: AppDimens.spaceMd),
              Container(
                width: 3,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlignVertical: TextAlignVertical.center,
                  validator: validator,
                  decoration: InputDecoration(
                    hintText: label,
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (helperText != null)
          Padding(
            padding: const EdgeInsets.only(
              top: AppDimens.spaceXs,
              left: AppDimens.spaceMd,
            ),
            child: Text(
              helperText!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
            ),
          ),
      ],
    );
  }
}

/// 整数输入框（期数、份额、阈值等非金额数值）。
class IntField extends StatelessWidget {
  const IntField({
    super.key,
    required this.controller,
    required this.label,
    this.suffixText,
    this.helperText,
  });

  final TextEditingController controller;
  final String label;
  final String? suffixText;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffixText,
        helperText: helperText,
      ),
    );
  }
}

/// 泛型枚举下拉框。
///
/// 所有业务枚举都实现了 `label` getter，但 Dart 无法对 `Enum` 做结构化约束，
/// 因此这里通过 [labelOf] 由调用方注入取名逻辑，保持类型安全。
class EnumDropdown<T extends Enum> extends StatelessWidget {
  const EnumDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: <DropdownMenuItem<T>>[
        for (final T v in values)
          DropdownMenuItem<T>(value: v, child: Text(labelOf(v))),
      ],
      onChanged: (T? v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

/// 表单内竖向间距，统一各模块对话框的呼吸感。
class FormGap extends StatelessWidget {
  const FormGap({super.key});

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: AppDimens.spaceMd);
}
