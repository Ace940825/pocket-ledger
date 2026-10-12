import 'package:flutter/material.dart';

import '../../core/theme/forest_design_tokens.dart';

/// 「报」小徽章：浅绿底 + 描边圆角方块（对齐报销账单详情）。
class RebBadge extends StatelessWidget {
  const RebBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: ForestGreen.soft,
          border: Border.all(color: ForestGreen.softBorder),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '报',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: ForestGreen.deep,
          ),
        ),
      );
}

/// 「超额报销」描边胶囊标签。
class OverTag extends StatelessWidget {
  const OverTag({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: ForestGreen.softBorder),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          '超额报销',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: ForestGreen.deep,
          ),
        ),
      );
}
