import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/features/accounts/presentation/widgets/year_picker_sheet.dart';

void main() {
  testWidgets('默认展示当前年份和取消/确定按钮', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: YearPickerSheet(initialYear: 2026),
        ),
      ),
    );

    // 顶部标题与年份格都会出现「2026年」，共 2 处。
    expect(find.text('2026年'), findsNWidgets(2));
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('确定'), findsOneWidget);
  });

  testWidgets('点击其他年份会高亮，确定后返回选中年份', (WidgetTester tester) async {
    int? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<int>(
                  context: context,
                  builder: (_) => const YearPickerSheet(initialYear: 2026),
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

    // 默认范围内应包含 2027 年
    final Finder chip2027 = find.text('2027年');
    expect(chip2027, findsOneWidget);
    await tester.tap(chip2027);
    await tester.pumpAndSettle();

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(result, 2027);
  });

  testWidgets('取消后不返回年份', (WidgetTester tester) async {
    int? result = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<int>(
                  context: context,
                  builder: (_) => const YearPickerSheet(initialYear: 2026),
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

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
