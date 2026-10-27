import 'package:flutter/material.dart';
import 'package:pocket_ledger/core/theme/forest_design_tokens.dart';

import '../../theme/app_dimens.dart';

/// 底部弹窗拖拽条（全应用统一）：36×4 圆角胶囊。
///
/// 默认色取主题 [ColorScheme.outline]（亮色即 [AppPalette.hairline]）；
/// 个别页面若用更深的灰，请在迁移时显式传入 [color]。
class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({
    super.key,
    this.color,
    this.margin = const EdgeInsets.only(top: 8, bottom: 4),
    this.width = AppDimens.sheetHandleW,
    this.height = AppDimens.sheetHandleH,
  });

  final Color? color;
  final EdgeInsetsGeometry margin;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {

    return Container(
      margin: margin,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? context.forest.outline,
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      ),
    );
  }
}
