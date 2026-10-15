import 'package:flutter/material.dart';
import 'package:pocket_ledger/shared/widgets/app_button.dart';

import '../../theme/app_dimens.dart';
import '../../shared/widgets/line_icon_map.dart';

/// 主题化加载指示（spinner）。
///
/// 统一使用 [ColorScheme.primary] 着色，自动适配暗色模式，
/// 取代散落在各页的 `Center(child: CircularProgressIndicator())`。
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({
    super.key,
    this.size = 28,
    this.strokeWidth = 3,
  });

  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// 整区加载占位，用于 [AsyncValue.when] 的 loading 分支或页面级加载。
///
/// 默认填满父容器并垂直居中；当父容器无界（嵌套在 [Column]/[ListView]）
/// 时传 [expand] = false，仅按内容居中。
class LoadingState extends StatelessWidget {
  const LoadingState({
    super.key,
    this.message,
    this.expand = true,
    this.indicatorSize = 28,
  });

  final String? message;
  final bool expand;
  final double indicatorSize;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget child = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LoadingIndicator(size: indicatorSize),
        if (message != null && message!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppDimens.md),
            child: Text(
              message!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
    return expand
        ? SizedBox.expand(child: Center(child: child))
        : Center(child: child);
  }
}

/// 错误占位，与 [LoadingState] 配对用于 [AsyncValue.when] 的 error 分支。
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
    this.expand = true,
  });

  final String message;
  final VoidCallback? onRetry;
  final IconData icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget child = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LineGlyph(icon, size: 56, color: theme.colorScheme.outlineVariant),
        const SizedBox(height: AppDimens.lg),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        if (onRetry != null)
          Padding(
            padding: const EdgeInsets.only(top: AppDimens.lg),
            child: TonalButton(
              label: '重试',
              onPressed: onRetry,
              fullWidth: false,
            ),
          ),
      ],
    );
    return expand
        ? SizedBox.expand(child: Center(child: child))
        : Center(child: child);
  }
}
