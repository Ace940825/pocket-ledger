import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

/// 标签模块专用的轻量 toast：基于 Overlay。
///
/// 传入 [anchor]（通常是「通用/账本独立」分段键的 BuildContext）时，
/// toast 会紧贴锚点上方展示，保证弹窗与全屏管理页两处入口位置一致；
/// 不传则回退为状态栏下方展示。
OverlayEntry? _activeTagToast;

void showTagToast(
  BuildContext context,
  String message, {
  BuildContext? anchor,
}) {
  _activeTagToast?.remove();
  final OverlayEntry entry = OverlayEntry(
    builder: (BuildContext ctx) {
      // 计算锚点在屏幕上的位置，把 toast 底边贴在锚点上方 10px。
      double? bottom;
      if (anchor != null) {
        final RenderObject? ro = anchor.findRenderObject();
        if (ro is RenderBox && ro.attached && ro.hasSize) {
          final double anchorTop = ro.localToGlobal(Offset.zero).dy;
          bottom = MediaQuery.of(ctx).size.height - anchorTop + 10;
        }
      }
      return Positioned(
        top: bottom == null ? MediaQuery.of(ctx).padding.top + 14 : null,
        bottom: bottom,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: Center(
            // heightFactor:1 让 Center 只占 toast 自身高度，
            // 配合 bottom 定位才能贴在锚点上方而不是被撑满整屏。
            heightFactor: 1,
            child: Container(
              // 对齐设计稿 .toast：rgba(38,43,36,.92) 半透明深底、
              // 全胶囊 999 圆角、12.5px/w600、单行不换行、无阴影。
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.sage900.withValues(alpha: 0.922),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: const TextStyle(
                  color: AppColors.creamSoft,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  _activeTagToast = entry;
  Overlay.of(context).insert(entry);
  Future<void>.delayed(const Duration(milliseconds: 1800), () {
    if (_activeTagToast == entry) {
      entry.remove();
      _activeTagToast = null;
    }
  });
}
