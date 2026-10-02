import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/shared/widgets/line_icons.dart';

// 仅用于渲染校验：复刻详情页「管理」底部弹层里「存入 / 取出」两枚
// ListTile 的实际接法（LineIcon 作为 leading，size=24，onSurfaceVariant 着色），
// 确认存入/取出图标在列表里渲染正确、与文字对齐。
void main() {
  testWidgets('deposit action buttons render', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: RepaintBoundary(
            key: const Key('depositActions'),
            child: Container(
              color: Colors.white,
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('测试存钱计划',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                  ListTile(
                    leading: LineIcon(
                      categoryLineKind('deposit_in')!,
                      size: 24,
                      color: ThemeData.light().colorScheme.onSurfaceVariant,
                    ),
                    title: const Text('存入'),
                  ),
                  ListTile(
                    leading: LineIcon(
                      categoryLineKind('deposit_out')!,
                      size: 24,
                      color: ThemeData.light().colorScheme.onSurfaceVariant,
                    ),
                    title: const Text('取出'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(const Key('depositActions')),
      matchesGoldenFile('deposit_action_buttons.png'),
    );
  });
}
