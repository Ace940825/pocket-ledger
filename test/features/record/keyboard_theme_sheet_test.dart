/// 键盘主题弹层测试。
///
/// 锁定第 39 批修复（用户反馈「滑到底部不要留太多空白」）：
/// 原实现 SizedBox 硬钉 84% 屏高，内容矮时 Expanded 把剩余空白全吃掉，
/// 滚到底后设置项与底部键盘预览之间一大片白。现改为 ConstrainedBox
/// 仅设上限 + Column(min) + Flexible(loose)：内容自适应收缩。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/features/record/presentation/recording_settings_sheet.dart';
import 'package:pocket_ledger/shared/widgets/sheet_scaffold.dart';

void main() {
  testWidgets('键盘主题弹层：内容自适应收缩，不钉 84% 屏高（第 39 批）', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => ElevatedButton(
                onPressed: () => RecordingSettingsSheet.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 第一个 Tab（一般）里点「键盘外观」入口（opt 版本文案；
    // 「键盘主题」是弹层标题，full 分支的入口才叫键盘主题）。
    await tester.tap(find.text('键盘外观'));
    await tester.pumpAndSettle();

    // 二级弹层已打开（基础/高级两组标题在列）。
    expect(find.text('基础设置'), findsOneWidget);
    expect(find.text('高级设置'), findsOneWidget);

    // 悬浮卡高度必须小于 84% 屏高——证明弹层按内容收缩，
    // 剩余空间没有被 Expanded 吃掉（旧实现卡高恒等于 0.84 屏高）。
    // 精确定位：AppModalSheet 外壳内的悬浮卡 Container（不是按钮等
    // 普通 Container，避免误抓导致假绿）。
    final Finder sheetCard = find.descendant(
      of: find.byType(AppModalSheet),
      matching: find.byType(Container),
    );
    expect(sheetCard, findsWidgets);
    final double cardHeight =
        tester.getSize(sheetCard.first).height;
    final Size logical = tester.view.physicalSize / tester.view.devicePixelRatio;
    final double screenHeight = logical.height;
    debugPrint('键盘主题弹层卡高=$cardHeight, 屏高=$screenHeight');
    expect(
      cardHeight,
      lessThan(screenHeight * 0.84),
      reason: '弹层仍被钉在 84% 屏高（卡高=$cardHeight, 屏高=$screenHeight）',
    );

    // 滚动区必须是 loose flex（Flexible）而非 Expanded：
    // loose 才能「矮时贴内容、高时触顶滚」。
    final Finder scrollView = find.byType(SingleChildScrollView);
    expect(scrollView, findsOneWidget);
    final Finder flexAncestor = find.ancestor(
      of: scrollView,
      matching: find.byType(Flexible),
    );
    expect(flexAncestor, findsOneWidget);
    final Finder expandedAncestor = find.ancestor(
      of: scrollView,
      matching: find.byType(Expanded),
    );
    expect(expandedAncestor, findsNothing);
  });
}
