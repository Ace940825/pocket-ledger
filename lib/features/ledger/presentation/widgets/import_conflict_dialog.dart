import 'package:flutter/material.dart';

import '../../../../theme/app_dimens.dart';
import '../../../../theme/app_theme.dart';

/// 导入冲突处理方式（2026-10-22：用户要求「数据库中已有数据」时给出选择）。
enum ImportConflictMode {
  /// 合并：保留现有流水，新账单追加导入（默认行为）。
  merge,

  /// 覆盖：先清空当前账本全部流水（软删 + 余额回退 + 同步入队），再导入。
  /// 调用方必须再经一次危险确认（不可恢复）。
  overwrite,
}

/// 导入冲突对话框：数据库中已有数据时的三选一。
///
/// 对标截图（iOS 风格三按钮竖排）：合并原有数据（主色）/ 覆盖原有数据
/// （危险红）/ 取消。返回 `null` = 取消或点遮罩关闭。
class ImportConflictDialog extends StatelessWidget {
  const ImportConflictDialog({
    super.key,
    required this.existingCount,
    required this.incomingCount,
  });

  /// 当前账本已有流水笔数（>0 才会弹本对话框）。
  final int existingCount;

  /// 本次准备导入的笔数。
  final int incomingCount;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colors;
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      title: Text(
        '数据库中已有数据，您想如何处理？',
        style: context.text.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '当前账本已有 $existingCount 笔流水，本次准备导入 $incomingCount 笔。',
            style: context.text.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimens.md),
          _ConflictButton(
            label: '合并原有数据',
            foreground: scheme.primary,
            onTap: () => Navigator.of(context).pop(ImportConflictMode.merge),
          ),
          const SizedBox(height: AppDimens.sm),
          _ConflictButton(
            label: '覆盖原有数据',
            foreground: scheme.error,
            onTap: () =>
                Navigator.of(context).pop(ImportConflictMode.overwrite),
          ),
          const SizedBox(height: AppDimens.sm),
          _ConflictButton(
            label: '取消',
            foreground: scheme.onSurfaceVariant,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// 便捷方法：弹出导入冲突对话框。
///
/// 返回 `ImportConflictMode.merge` / `overwrite`；`null` = 取消。
Future<ImportConflictMode?> showImportConflictDialog(
  BuildContext context, {
  required int existingCount,
  required int incomingCount,
}) {
  return showDialog<ImportConflictMode>(
    context: context,
    builder: (BuildContext ctx) => ImportConflictDialog(
      existingCount: existingCount,
      incomingCount: incomingCount,
    ),
  );
}

/// 全宽堆叠按钮（对标截图：三个等宽圆角按钮竖排）。
class _ConflictButton extends StatelessWidget {
  const _ConflictButton({
    required this.label,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: foreground.withValues(alpha: 0.12),
          foregroundColor: foreground,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          ),
        ),
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }
}
