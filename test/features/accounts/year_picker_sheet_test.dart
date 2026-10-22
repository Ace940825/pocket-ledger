import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/shared/widgets/calendar_sheet.dart';

// YearPickerSheet 已于 T1 收编进全局 CalendarSheet(year)（2026-10-01），
// 本文件随之改测新组件的 year 单选模式。
//
// 注意：年宫格是「单击选中、再点同一格确认返回」（320ms 双击判定），
// 因此选年份必须用连续两次 tap 触发双击确认，单次 tap 只高亮不 pop。
void main() {
  Future<void> openSheet(
    WidgetTester tester, {
    int initialYear = 2026,
    DateTime? firstDate,
    DateTime? lastDate,
    required void Function(CalendarSelection?) onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async {
                final CalendarSelection? r = await CalendarSheet.show(
                  context,
                  mode: CalendarSheetMode.year,
                  initialYear: initialYear,
                  firstDate: firstDate,
                  lastDate: lastDate,
                );
                onResult(r);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  // 年宫格需双击确认（单击仅选中），两次 tap 紧接执行以压在 320ms 真实时间内。
  Future<void> doubleTapYear(WidgetTester tester, String year) async {
    await tester.tap(find.text(year));
    await tester.tap(find.text(year));
    await tester.pumpAndSettle();
  }

  testWidgets('year 模式：标题展示当前年份，宫格含相邻年份', (WidgetTester tester) async {
    await openSheet(tester, initialYear: 2026, onResult: (_) {});

    // 页头标题「2026 年」+ 选中格「2026」。
    expect(find.text('2026 年'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
    // 12 宫格（year-5 .. year+6）应包含 2021 与 2032。
    expect(find.text('2021'), findsOneWidget);
    expect(find.text('2032'), findsOneWidget);
  });

  testWidgets('双击其他年份立即返回 CalendarYear', (WidgetTester tester) async {
    CalendarSelection? result;
    await openSheet(tester, onResult: (r) => result = r);

    await doubleTapYear(tester, '2027');

    expect(result, isA<CalendarYear>());
    expect((result! as CalendarYear).year, 2027);
  });

  testWidgets('范围外年份置灰不可点', (WidgetTester tester) async {
    CalendarSelection? result;
    await openSheet(
      tester,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      onResult: (r) => result = r,
    );

    // 2021 超出 [2024, 2030]：仍渲染但 onTap 为 null，点选不返回。
    await tester.tap(find.text('2021'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(result, isNull);

    // 范围内年份双击可点选。
    await doubleTapYear(tester, '2027');
    expect((result! as CalendarYear).year, 2027);
  });
}
