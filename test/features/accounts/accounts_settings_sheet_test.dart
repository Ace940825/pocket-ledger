import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/features/accounts/presentation/widgets/accounts_settings_sheet.dart';

void main() {
  group('AccountsSettingsSheet', () {
    testWidgets('展示五个占位功能入口', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AccountsSettingsSheet()),
        ),
      );

      // 五个功能栏标题（占位，待后续填充真实逻辑）。
      expect(find.text('信用卡管理'), findsOneWidget);
      expect(find.text('资产排序'), findsOneWidget);
      expect(find.text('隐藏资产列表'), findsOneWidget);
      expect(find.text('封存资产列表'), findsOneWidget);
      expect(find.text('资产统计显示'), findsOneWidget);
    });
  });
}
