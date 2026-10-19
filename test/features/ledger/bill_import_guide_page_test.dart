import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pocket_ledger/features/ledger/presentation/bill_import_guide_page.dart';

void main() {
  // 页面是长列表，测试时给一个足够高的视口，让 ListView 一次性渲染全部内容，
  // 否则滚动视口外的子节点不会 build，find.text 会漏判。
  testWidgets('导入说明页能正常构建并展示 16 列核心内容', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 6000));
    await tester.pumpWidget(
      const MaterialApp(home: BillImportGuidePage()),
    );
    await tester.pumpAndSettle();

    // 标题与区块。
    expect(find.text('导入说明'), findsOneWidget);
    expect(find.text('字段规范（16 列）'), findsOneWidget);
    expect(find.text('模块路由规则'), findsOneWidget);
    expect(find.text('填写示例'), findsOneWidget);
    expect(find.text('导入校验要点'), findsOneWidget);

    // v2 新增的「对方」列与借还支持说明。
    expect(find.text('对方'), findsWidgets);
    expect(find.text('借还 → 借还台账'), findsOneWidget);

    // 借还 6 操作名全部出现。
    for (final String op in <String>[
      '借入',
      '借出',
      '还债',
      '收债',
      '债务消减',
      '坏账计提',
    ]) {
      expect(find.text(op), findsWidgets);
    }

    // 复制模板按钮存在。
    expect(find.widgetWithText(OutlinedButton, '复制'), findsOneWidget);
  });

  testWidgets('点击复制按钮触发剪贴板且不抛错', (WidgetTester tester) async {
    // 测试中 clipboard 平台通道不会真正返回，mock 使其立即完成。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async => null,
    );
    await tester.binding.setSurfaceSize(const Size(420, 6000));
    await tester.pumpWidget(
      const MaterialApp(home: BillImportGuidePage()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '复制'));
    await tester.pump(const Duration(milliseconds: 200));
    // 复制后按钮文案切换为「已复制」（1 秒后才自动还原）。
    expect(find.widgetWithText(OutlinedButton, '已复制'), findsOneWidget);
    // 让 1 秒自动还原定时器触发，避免测试结束时仍有挂起的 Timer。
    await tester.pump(const Duration(seconds: 2));
  });
}
