import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/features/accounts/presentation/widgets/asset_stats_settings_sheet.dart';

/// 「资产月消费统计」面板的 widget 测试。
///
/// 重点锁死参考设计里的三件事：
/// 1. **结余行与提示文案已经移除**；
/// 2. 三个开关的副标题**随开关值变化**，把当前口径写清楚；
/// 3. 「账单列表样式」打开的是标题为「设置」的二级弹窗（按年月分组 · 资产/报销账户）。
void main() {
  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => AssetStatsSettingsSheet.show(ctx),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('渲染标题、三个开关与保存按钮', (WidgetTester tester) async {
    await openSheet(tester);

    expect(find.text('资产月消费统计'), findsOneWidget);
    expect(find.text('支出流水统计'), findsOneWidget);
    expect(find.text('收入流水统计'), findsOneWidget);
    expect(find.text('消费账单和退款账单不进行抵扣'), findsOneWidget);
    expect(find.text('账单列表样式'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(3));
  });

  testWidgets('结余行与提示文案已按参考设计移除', (WidgetTester tester) async {
    await openSheet(tester);

    expect(find.text('结余'), findsNothing);
    expect(find.text('结余=收入-支出'), findsNothing);
    expect(find.text('结余=支出-收入'), findsNothing);
    expect(find.textContaining('此功能设置仅为'), findsNothing);
  });

  testWidgets('默认（全关）副标题 = 只统计普通账单', (WidgetTester tester) async {
    await openSheet(tester);

    expect(find.text('支出=普通支出账单'), findsOneWidget);
    expect(find.text('收入=普通收入账单'), findsOneWidget);
    expect(
      find.text('关闭后，消费账单和退款账单进行抵扣'),
      findsOneWidget,
    );
  });

  testWidgets('拨动开关后副标题跟着变（各功能开关后的计算逻辑）', (WidgetTester tester) async {
    await openSheet(tester);

    await tester.tap(find.byType(Switch).at(0));
    await tester.pump();
    expect(find.text('支出=普通支出账单+转账转出账单'), findsOneWidget);
    expect(find.text('支出=普通支出账单'), findsNothing);

    await tester.tap(find.byType(Switch).at(1));
    await tester.pump();
    expect(find.text('收入=普通收入账单+转账转入账单'), findsOneWidget);

    await tester.tap(find.byType(Switch).at(2));
    await tester.pump();
    expect(
      find.text('开启后，消费账单和退款账单不进行抵扣'),
      findsOneWidget,
    );
    expect(find.text('关闭后，消费账单和退款账单进行抵扣'), findsNothing);
  });

  testWidgets('点「账单列表样式」打开标题为「设置」的二级弹窗', (WidgetTester tester) async {
    await openSheet(tester);

    await tester.tap(find.text('账单列表样式'));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('账单列表按年月分组'), findsNWidgets(2));
    expect(find.text('资产账户'), findsOneWidget);
    expect(find.text('报销账户'), findsOneWidget);
    // 二级弹窗再叠两个开关。
    expect(find.byType(Switch), findsNWidgets(5));
  });

  testWidgets('二级弹窗里拨「资产账户」后保存，落库为 groupByMonthAsset=false',
      (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    await openSheet(tester);

    await tester.tap(find.text('账单列表样式'));
    await tester.pumpAndSettle();

    // 二级弹窗的两个开关排在 3 个统计开关之后。
    await tester.tap(find.byType(Switch).at(3));
    await tester.pumpAndSettle();

    // 关闭二级弹窗（页面里此时有两个 ✕，取最上层那个）。
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    const FlutterSecureStorage storage = FlutterSecureStorage();
    final String? raw = await storage.read(key: 'asset_stats_settings');
    expect(raw, isNotNull);
    expect(raw, contains('"groupByMonthAsset":false'));
  });

  testWidgets('保存后写入 secure storage', (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    await openSheet(tester);

    await tester.tap(find.byType(Switch).at(2));
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    const FlutterSecureStorage storage = FlutterSecureStorage();
    final String? raw = await storage.read(key: 'asset_stats_settings');
    expect(raw, isNotNull);
    expect(raw, contains('"noOffset":true'));
  });
}
