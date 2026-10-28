import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/shared/widgets/date_picker_sheet.dart';

/// 还款日弹窗布局回归（真机反馈「BOTTOM OVERFLOWED BY 179 PIXELS」）：
/// 弹窗内容（分段控件 + 1-31 宫格 / 步进器 + 按钮）必须在小屏面内收口——
/// 要么完整展示，要么模式区内部滚动，绝不允许 RenderFlex 溢出。
/// widget 测试中一旦发生 overflow，pump 阶段即报错失败。
void main() {
  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showRepayDatePickerSheet(
                  context,
                  initialBillingDay: 5,
                  initialDueDay: 10,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('小屏固定日期模式：不溢出，按钮与末日均在弹窗内', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(320 * 3, 400 * 3);
    tester.binding.window.devicePixelRatioTestValue = 3.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await openSheet(tester);

    // 两种模式分段 + 底部按钮均在（pump 无 overflow 异常即通过）。
    expect(find.text('固定日期'), findsOneWidget);
    expect(find.text('免息期'), findsOneWidget);
    expect(find.text('31'), findsOneWidget);
    expect(find.text('确定'), findsOneWidget);
  });

  testWidgets('小屏免息期模式：不溢出，步进器与预览可见', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(320 * 3, 400 * 3);
    tester.binding.window.devicePixelRatioTestValue = 3.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await openSheet(tester);
    await tester.tap(find.text('免息期'));
    await tester.pumpAndSettle();

    expect(find.text('账单日后 N 天还款（即免息期）'), findsOneWidget);
    // 步进器默认 20 天；预览是 RichText（账单日5号 + 20天 = Y月Z日）。
    expect(find.text('20'), findsOneWidget);
    // 预览 RichText：账单日5号 + 20天 = 11月25日（Text 内部也是 RichText，
    // 故按内容收口匹配，顺带校验预览算式）。
    expect(
      find.byWidgetPredicate(
        (Widget w) =>
            w is RichText && w.text.toPlainText().contains('账单日5号 + 20天'),
      ),
      findsOneWidget,
    );
    expect(find.text('确定'), findsOneWidget);
  });
}
