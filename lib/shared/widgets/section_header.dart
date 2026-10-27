import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// 区块标题（全应用统一）：绿渐变竖条 4×16 + 16pt w700 标题，左对齐。
///
/// 与报销页/借还页/账单管理页的分区块头同款；凡页面内的分组标题
/// （如「最近流水」「交易流水」「入账进度」）一律用本组件，不再裸排 Text。
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 4),
    this.trailing,
  });

  final String title;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[AppPalette.sageMist, AppPalette.sageRibbon],
              ),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? context.forest.onSurface
                    : context.forest.onSurface,
              ),
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}
