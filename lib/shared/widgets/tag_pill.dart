import 'package:flutter/material.dart';

import '../../core/theme/forest_design_tokens.dart';

/// 浅绿标签胶囊（账单的「已报 / 标签」等小标记）。
///
/// 抽自账单列表页 / 账单清理页的逐字节相同私有实现。
class TagPill extends StatelessWidget {
  const TagPill(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: ForestGreen.soft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: ForestGreen.deep,
        ),
      ),
    );
  }
}
