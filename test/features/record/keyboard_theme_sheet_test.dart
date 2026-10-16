// 键盘主题弹层测试。
//
// 锁定第 39 批修复（用户反馈「滑到底部不要留太多空白」）：
// 原实现 SizedBox 硬钉 84% 屏高，内容矮时 Expanded 把剩余空白全吃掉，
// 滚到底后设置项与底部键盘预览之间一大片白。现改为 ConstrainedBox
// 仅设上限 + Column(min) + Flexible(loose)：内容自适应收缩。
// 第 40 批追加：顶部区域「一行/两行 × 金额左/右」四种形态断言。
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
    final double cardHeight = tester.getSize(sheetCard.first).height;
    final Size logical =
        tester.view.physicalSize / tester.view.devicePixelRatio;
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

  testWidgets('键盘主题弹层：一行/两行 × 金额左/右 四种形态（第 40 批）', (
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
    await tester.tap(find.text('键盘外观'));
    await tester.pumpAndSettle();

    final Finder note = find.text('请输入备注信息（最多150字）');
    final Finder amount = find.text('¥0.00');

    // 默认 topAreaRows='1行' + amountPosition='右'：
    // 备注与金额必须在同一 Row（用户参考图的一行表现形式）。
    Finder rowOfNote = find.ancestor(of: note, matching: find.byType(Row));
    expect(rowOfNote, findsWidgets);
    expect(
      find.descendant(of: rowOfNote.first, matching: amount),
      findsOneWidget,
      reason: '1行形式：备注与金额应同行',
    );

    // 切「2行」：备注与金额必须分家（金额独占一行，参考图1）。
    // 「顶部区域行数」在高级设置区，弹层矮时需先滚到可见再点。
    await tester.ensureVisible(find.text('2行'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2行'));
    await tester.pumpAndSettle();
    rowOfNote = find.ancestor(of: note, matching: find.byType(Row));
    expect(rowOfNote, findsWidgets);
    expect(
      find.descendant(of: rowOfNote.first, matching: amount),
      findsNothing,
      reason: '2行形式：金额应独占一行',
    );

    // 回到「1行」+ 切金额位置「左」：一行形式里金额应是第一个子级
    // （¥金额 · 备注 · 日期 · 箭头，参考图3）。
    await tester.ensureVisible(find.text('1行'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1行'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('左'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('左'));
    await tester.pumpAndSettle();
    rowOfNote = find.ancestor(of: note, matching: find.byType(Row));
    final Row oneRowLeft = tester.widget<Row>(rowOfNote.first);
    final List<Widget> leftChildren = oneRowLeft.children;
    // 跳过可能的 SizedBox 前导，找金额 Text 的位置应在备注 Text 之前。
    int amountIdx = -1;
    int noteIdx = -1;
    for (int i = 0; i < leftChildren.length; i++) {
      final Widget w = leftChildren[i];
      if (w is Text && w.data == '¥0.00') amountIdx = i;
      if (w is Expanded) {
        final Widget child = w.child;
        if (child is Text && child.data == '请输入备注信息（最多150字）') {
          noteIdx = i;
        }
      }
    }
    expect(amountIdx, greaterThanOrEqualTo(0));
    expect(noteIdx, greaterThanOrEqualTo(0));
    expect(
      amountIdx,
      lessThan(noteIdx),
      reason: '金额在左：¥金额应在备注之前',
    );
  });
}
