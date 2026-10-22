import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/features/ledger/presentation/bill_export_page.dart';
import 'package:pocket_ledger/theme/app_theme.dart';

/// 账单导出页「时间范围」两条日期行（2026-10-22 真机反馈）：
///
/// 该页的区间语义已由「开始时间 / 结束时间」两行分别承担，弹窗里再给一个
/// 「自定义」chip 属重复入口（还得在宫格里连点两日）——已传
/// `showCustomRange: false` 隐去。
///
/// 同时锁住一个连带修复：日历在「周/月/年」chip 下返回的是 [CalendarPeriod]
/// （不是 CalendarDay/CalendarRange），而 `_pickDate` 原先只认后两者，
/// 导致这三个 chip 点了确认等于没点。现在按「整段覆盖为所选周期」处理，
/// 且注意 CalendarPeriod.end 是开区间（本页 _end 是闭区间）需减一天。
void main() {
  /// 页面时间行用 `yyyy年M月d日` 展示。
  String fmt(DateTime d) => '${d.year}年${d.month}月${d.day}日';

  final DateTime now = DateTime.now();
  final DateTime monthStart = DateTime(now.year, now.month);
  final DateTime monthEnd = DateTime(now.year, now.month + 1, 0);
  final String thisMonthStart = fmt(monthStart);
  final String thisMonthEnd = fmt(monthEnd);
  final String today = fmt(now);

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(414, 896));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppThemeData.light,
          home: const BillExportPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 打开某一行的日期弹窗。
  Future<void> openPicker(WidgetTester tester, String rowLabel) async {
    final Finder row = find.text(rowLabel);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  testWidgets('弹窗不再出现「自定义」chip，仍保留 周/月/年', (tester) async {
    await pumpPage(tester);

    await openPicker(tester, '开始时间');
    expect(find.text('选择开始时间'), findsOneWidget);
    expect(find.text('周 Wk'), findsOneWidget);
    expect(find.text('月 Mo'), findsOneWidget);
    expect(find.text('年 Yr'), findsOneWidget);
    expect(
      find.textContaining('自定义'),
      findsNothing,
      reason: '区间已由开始/结束两行承担，弹窗内不应再有自定义入口',
    );

    // 取消关掉弹层，再验「结束时间」入口同口径。
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await openPicker(tester, '结束时间');
    expect(find.text('选择结束时间'), findsOneWidget);
    expect(find.textContaining('自定义'), findsNothing);
  });

  testWidgets('选「月」chip：整段覆盖为本月首日 ~ 本月末日', (tester) async {
    await pumpPage(tester);
    // 默认本月 1 日 ~ 今天，先确认起点在场。
    expect(find.text(thisMonthStart), findsOneWidget);

    await openPicker(tester, '开始时间');
    await tester.tap(find.text('月 Mo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认 Confirm'));
    await tester.pumpAndSettle();

    expect(find.text(thisMonthStart), findsOneWidget);
    expect(
      find.text(thisMonthEnd),
      findsOneWidget,
      reason: 'CalendarPeriod.end 是开区间，减一天后应落在本月末日',
    );
    expect(
      find.text(today),
      now.day == monthEnd.day ? findsOneWidget : findsNothing,
      reason: '今天不再是结束日（除非今天正好是月末）',
    );
  });

  testWidgets('选「年」chip：整段覆盖为年初 ~ 年末', (tester) async {
    await pumpPage(tester);

    await openPicker(tester, '结束时间');
    await tester.tap(find.text('年 Yr'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认 Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('${now.year}年1月1日'), findsOneWidget);
    expect(find.text('${now.year}年12月31日'), findsOneWidget);
  });

  testWidgets('单日点选仍生效，且结束不早于开始', (tester) async {
    await pumpPage(tester);

    await openPicker(tester, '开始时间');
    // 日宫格里点 15 号（本月必然存在）。
    final DateTime picked = DateTime(now.year, now.month, 15);
    await tester.tap(find.text('15').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认 Confirm'));
    await tester.pumpAndSettle();

    expect(find.text(fmt(picked)), findsOneWidget);
    // 15 号晚于今天（今天 < 15）时，结束日应被抬到与开始同日。
    expect(
      find.text(fmt(now)),
      now.day >= 15 ? findsOneWidget : findsNothing,
      reason: '开始日不能晚于结束日：若从 15 号起选，结束日需同步抬到 15 号',
    );
  });
}
