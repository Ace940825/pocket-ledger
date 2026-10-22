import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pocket_ledger/shared/widgets/day_group_header.dart';

/// 首页「最近流水」/账单明细页共用的日分组头。
///
/// 回归锁（用户反馈：非当年份账单不显示年份）：
/// - 当年份只显「M月d日」；
/// - 非当年份必须补全「yyyy年M月d日」；
/// - 「今天/昨天」相对标签不受影响（元旦跨年的「昨天」同样带年份）。
void main() {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime yesterday = today.subtract(const Duration(days: 1));
  // 去年同日（跨年样本；2/29 会被 DateTime 归一化为 3/1，
  // 期望值取自同一对象的字段，故仍自洽）。
  final DateTime lastYearSameDay =
      DateTime(now.year - 1, now.month, now.day);

  Widget wrap(DateTime date, {int? count}) => MaterialApp(
        home: Scaffold(
          body: DayGroupHeader(date: date, count: count),
        ),
      );

  testWidgets('当年份：只显 M月d日，不带年份', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(today));
    await tester.pumpAndSettle();
    expect(find.text('${today.month}月${today.day}日  今天'), findsOneWidget);
    // 不带年份（YYYY 前缀不存在）。
    expect(find.textContaining('${today.year}年'), findsNothing);
  });

  testWidgets('非当年份：补全 yyyy年M月d日', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(lastYearSameDay));
    await tester.pumpAndSettle();
    expect(
      find.text('${lastYearSameDay.year}年${lastYearSameDay.month}月'
          '${lastYearSameDay.day}日'),
      findsOneWidget,
    );
  });

  testWidgets('昨天：当年份显「M月d日  昨天」', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(yesterday));
    await tester.pumpAndSettle();
    if (yesterday.year == now.year) {
      expect(
        find.text('${yesterday.month}月${yesterday.day}日  昨天'),
        findsOneWidget,
      );
    } else {
      // 元旦当天的「昨天」落在去年，应同时带年份与相对标签。
      expect(
        find.text('${yesterday.year}年${yesterday.month}月${yesterday.day}日  昨天'),
        findsOneWidget,
      );
    }
  });

  testWidgets('count 透传右侧 N笔', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(today, count: 3));
    await tester.pumpAndSettle();
    expect(find.text('3笔'), findsOneWidget);
  });
}
