import 'package:flutter/material.dart';

/// 自定义数字键盘（参考小青账记一笔底部键盘）。
///
/// 布局：3 列数字网格（1-9 + 再记 / 0 / .），下方一个通栏「保存」按钮。
/// 金额以字符串形式在 [value] 中维护，由调用方在 [onChanged] 里落状态，
/// 这样面板顶部的大字金额与键盘保持同步，且不依赖系统软键盘。
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onSave,
    this.onSaveAndMore,
    this.enabled = true,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onSave;
  final VoidCallback? onSaveAndMore;
  final bool enabled;

  static const int _maxIntegerDigits = 12;
  static const int _maxDecimalDigits = 2;

  void _input(String s) {
    if (!enabled) return;
    if (s == '.') {
      if (value.contains('.')) return;
      onChanged(value.isEmpty ? '0.' : '$value.');
      return;
    }
    // 数字
    if (value.contains('.')) {
      final String decimals = value.split('.')[1];
      if (decimals.length >= _maxDecimalDigits) return;
    }
    if (value.replaceAll('.', '').length >= _maxIntegerDigits) return;
    // 去掉前导 0（除非是 "0." 的小数输入场景）
    if (value == '0') {
      onChanged(s);
    } else {
      onChanged('$value$s');
    }
  }

  Widget _digit(String s) => _Key(
        label: s,
        onTap: () => _input(s),
        enabled: enabled,
      );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.4,
          children: <Widget>[
            _digit('1'),
            _digit('2'),
            _digit('3'),
            _digit('4'),
            _digit('5'),
            _digit('6'),
            _digit('7'),
            _digit('8'),
            _digit('9'),
            _Action(
              label: '再记',
              icon: Icons.add_task_outlined,
              onTap: enabled ? onSaveAndMore : null,
            ),
            _digit('0'),
            _Key(
              label: '.',
              onTap: () => _input('.'),
              enabled: enabled,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: enabled ? onSave : null,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('保存'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: theme.textTheme.titleMedium,
            ),
          ),
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap, this.enabled = true});

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Center(
        child: Text(
          label,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: enabled ? theme.colorScheme.onSurface : theme.disabledColor,
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool active = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              color: active ? theme.colorScheme.primary : theme.disabledColor,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: active ? theme.colorScheme.primary : theme.disabledColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
