import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pocket_ledger/core/theme/forest_design_tokens.dart';

import '../../theme/app_dimens.dart';

/// 日分组头：左侧「M月d日（今天/昨天）」，右侧「N笔」。
/// 跨年账单（非当年份）自动补全年份「yyyy年M月d日」，避免年份歧义
/// （与账单列表/转换/清理页同口径）。
///
/// 视觉规范源自账单明细页（ledger_page 的日分组），现抽为共享组件，
/// 首页「最近流水」与账单明细共用，保证两处分组样式零漂移。
///
/// [date] 传该组任一流水的本地日期即可（组件内只取年月日）；
/// [count] 为该日流水笔数，传 null 则不显示右侧计数。
/// [padding] 可覆盖默认外边距（默认值按账单明细页的全宽滚动容器设计；
/// 若外层列表自带水平 padding，请传入不含水平方向的 padding）。
class DayGroupHeader extends StatelessWidget {
  const DayGroupHeader({
    super.key,
    required this.date,
    this.count,
    this.padding = const EdgeInsets.fromLTRB(
      AppDimens.lg,
      AppDimens.md,
      AppDimens.lg,
      AppDimens.xs,
    ),
  });

  final DateTime date;
  final int? count;
  final EdgeInsetsGeometry padding;

  /// UTC 毫秒 → 本地日期（只保留年月日）。供调用方做同日判断/取组日期，
  /// 口径与账单明细页一致（存储为 UTC 毫秒，展示转本地）。
  static DateTime localDay(int millisSinceEpoch) =>
      DateTime.fromMillisecondsSinceEpoch(millisSinceEpoch, isUtc: true)
          .toLocal();

  /// 两条流水（UTC 毫秒）是否落在同一自然日本地日。
  static bool sameDay(int a, int b) {
    final DateTime da = localDay(a);
    final DateTime db = localDay(b);
    return da.year == db.year && da.month == db.month && da.day == db.day;
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime day = DateTime(date.year, date.month, date.day);
    final DateTime today0 = DateTime(now.year, now.month, now.day);
    final String relative = day == today0
        ? '  今天'
        : day == today0.subtract(const Duration(days: 1))
            ? '  昨天'
            : '';
    // 跨年账单（非当年份）补全年份：只显「M月d日」时，用户无法区分
    // 今年与去年的同月同日（与账单列表/转换/清理页同口径）。
    final String base = date.year == now.year
        ? DateFormat('M月d日').format(date)
        : DateFormat('yyyy年M月d日').format(date);

    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          Text(
            '$base$relative',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.forest.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          if (count != null)
            Text(
              '$count笔',
              style: TextStyle(
                fontSize: 12,
                color: context.forest.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
