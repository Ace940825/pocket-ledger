import 'package:flutter/material.dart';

import '../../../domain/enums.dart';

/// 通用 / 账本独立 分段控件（标签模块共用）。
///
/// 对齐 tag-forest-FINAL：容器 `#EDE4D2` 胶囊，选中项 = 深墨 `#2C3329`
/// 底 + 米白 `#F4EFDF` 字；未选项 = 灰绿 `#6A7263` 字。
class TagScopeToggle extends StatelessWidget {
  const TagScopeToggle({
    super.key,
    required this.scope,
    required this.onChanged,
  });

  final TagScope scope;
  final ValueChanged<TagScope> onChanged;

  static const Color _track = Color(0xFFEDE4D2);
  static const Color _onBg = Color(0xFF2C3329);
  static const Color _onFg = Color(0xFFF4EFDF);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _track,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: <Widget>[
          for (final TagScope s in TagScope.values)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (s != scope) onChanged(s);
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: s == scope ? _onBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    s.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: s == scope ? _onFg : const Color(0xFF6A7263),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
