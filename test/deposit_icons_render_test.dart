import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/shared/widgets/line_icons.dart';

/// 存款（存入 / 取出）图标真渲染自检。
///
/// 目的：① 断言两个 key 都有手绘 LineIcon 映射（不回退 Material）；
/// ② 出多尺寸（64 / 40 / 24）真渲染图，目视核对「箭头在罐腹内」的构图与
/// 小尺寸可读性；③ 与同分组的既有图标（moneyBag / funds / withdrawal /
/// internalTransfer）并排比对疏密是否一致。
const List<String> depositKeys = <String>['deposit_in', 'deposit_out'];

void main() {
  testWidgets('deposit icons resolve to hand-drawn LineIcon and render',
      (WidgetTester tester) async {
    for (final String k in depositKeys) {
      expect(categoryLineKind(k), isNotNull,
          reason: 'iconKey "$k" 缺少 LineIcon 映射，会回退 Material');
    }

    const List<LineIconKind> siblings = <LineIconKind>[
      LineIconKind.moneyBag,
      LineIconKind.funds,
      LineIconKind.withdrawal,
      LineIconKind.internalTransfer,
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          backgroundColor: Colors.white,
          body: RepaintBoundary(
            key: const Key('depositIconGrid'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // 64px：看整体造型与箭头位置
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      for (final String k in depositKeys)
                        LineIcon(categoryLineKind(k)!,
                            size: 64, color: const Color(0xFF2E4A26)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 40px：看默认落位
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      for (final String k in depositKeys)
                        LineIcon(categoryLineKind(k)!,
                            size: 40, color: const Color(0xFF2E4A26)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 24px：看小尺寸可读性（记一笔网格实际尺寸）
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      for (final String k in depositKeys)
                        LineIcon(categoryLineKind(k)!,
                            size: 24, color: const Color(0xFF2E4A26)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  const Text('同组既有图标（疏密比对）',
                      style: TextStyle(fontSize: 11, color: Color(0xFF7A8B72))),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      for (final LineIconKind kind in siblings)
                        LineIcon(kind,
                            size: 40, color: const Color(0xFF2E4A26)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('depositIconGrid')),
      matchesGoldenFile('deposit_icons.png'),
    );
  });
}
