import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/shared/widgets/calendar_sheet.dart';

// YearPickerSheet 已于 T1 收编进全局 CalendarSheet(year)（2026-10-01），
// 本文件随之改测新组件的 year 单选模式。
void main() {
  Future<CalendarSelection?> openSheet(
    WidgetTester tester, {
    int initialYear = 2026,
  }) async {
    CalendarSelection? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async {
                result = await CalendarSheet.show(
                  context,
                  mode: CalendarSheetMode.year,
                  initialYear: initialYear,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('year 模式：标题展示当前年份，宫格含相邻年份', (WidgetTester tester) async {
    await openSheet(tester, initialYear: 2026);

    // 页头标题「2026 年」+ 选中格「2026」。
    expect(find.text('2026 年'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
    // 12 宫格（year-5 .. year+6）应包含 2021 与 2032。
    expect(find.text('2021'), findsOneWidget);
    expect(find.text('2032'), findsOneWidget);
  });

  testWidgets('点击其他年份立即返回 CalendarYear', (WidgetTester tester) async {
    final CalendarSelection? result = await openSheet(tester);

    await tester.tap(find.text('2027'));
    await tester.pumpAndSettle();

    expect(result, isA<CalendarYear>());
    expect((result! as CalendarYear).year, 2027);
  });

  testWidgets('范围外年份置灰不可点', (WidgetTester tester) async {
    CalendarSelection? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async {
                result = await CalendarSheet.show(
                  context,
                  mode: CalendarSheetMode.year,
                  initialYear: 2026,
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2030),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 2021 超出 [2024, 2030]：仍渲染但 onTap 为 null，点选不返回。
    await tester.tap(find.text('2021'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(result, isNull);

    // 范围内年份仍可点选。
    await tester.tap(find.text('2027'));
    await tester.pumpAndSettle();
    expect((result! as CalendarYear).year, 2027);
  });
}
