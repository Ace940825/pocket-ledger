import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pocket_ledger/core/constants/app_colors.dart';
import 'package:pocket_ledger/shared/models/money.dart';
import 'package:pocket_ledger/shared/widgets/animated_money_text.dart';

void main() {
  testWidgets('显示正确的格式化金额（动画结束后）', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedMoneyText(Money.fromMinor(123456)),
        ),
      ),
    );
    // 让从 0 滚动到目标值的动画跑完
    await tester.pumpAndSettle();
    expect(find.text('¥1,234.56'), findsOneWidget);
  });

  testWidgets('正数按收入色（绿）着色', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedMoneyText(Money.fromMinor(100)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final Text text = tester.widget<Text>(find.byType(Text));
    expect(text.style?.color, AppColors.income);
  });

  testWidgets('负数按支出色（红）着色', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedMoneyText(Money.fromMinor(-100)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final Text text = tester.widget<Text>(find.byType(Text));
    expect(text.style?.color, AppColors.expense);
  });

  testWidgets('显式 color 覆盖自动着色', (WidgetTester tester) async {
    const Color forced = Colors.amber;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedMoneyText(Money.fromMinor(100), color: forced),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final Text text = tester.widget<Text>(find.byType(Text));
    expect(text.style?.color, forced);
  });
}
