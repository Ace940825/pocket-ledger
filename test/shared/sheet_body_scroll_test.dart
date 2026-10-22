// 回归测试：「问题明细」类长列表弹层滚动失效（2026-10-22 真机反馈）。
//
// 背景：AppModalSheet 的 body 槽位曾是 ConstrainedBox(maxHeight: 屏高−铬件)。
// Column(mainAxisSize.min) 给非 flex 子级的高度约束是 Infinity，
// ConstrainedBox.additionalConstraints.enforce(Infinity) 只认自己的上限、
// 把模态路由的 9/16 高度帽彻底抹掉 → body 拿到近全屏高 → shrinkWrap 的
// ListView 按全内容高度布局（maxScrollExtent == 0 完全滑不动、超出部分被
// 卡片 Clip.antiAlias 裁死不可达），或撑爆 Column（RenderFlex overflow）。
//
// 修复：body 槽位改 Flexible(fit: loose) —— 由 RenderFlex 按父级真实约束
// 分配，天然尊重路由帽与键盘避让；短内容取自然高（视觉零变化）。
//
// 本测试锁定不变量：
//   ① 无 RenderFlex overflow / 布局异常；
//   ② body 拿到的是有限高度（≤ 路由帽），ListVior 不按全内容高度布局；
//   ③ 内容超槽位时 maxScrollExtent > 0 且拖拽真的滚动；
//   ④ 短内容时卡片按自然高度（不撑满），不产生 overflow。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/shared/widgets/sheet_scaffold.dart';

const Size kPhone = Size(418, 931);

/// 与 bill_import_page._showProblemSheet 同构：shrinkWrap ListView + 长文本行。
Future<void> _openProblemSheet(
  WidgetTester tester,
  int count, {
  String title = '导入问题明细',
}) async {
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  await tester.binding.setSurfaceSize(kPhone);
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: kPhone),
      child: MaterialApp(
        theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
        home: Scaffold(
          appBar: AppBar(title: const Text('账单导入')),
          body: Builder(
            builder: (BuildContext context) => ElevatedButton(
              onPressed: () => showAppModalSheet<void>(
                context,
                title: title,
                body: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (int i = 0; i < count; i++)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Text(
                          '· 理财 收入 ¥$i.00: ValidationFailure: '
                          '未找到可收债的「朱德金」未结清债务',
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                  ],
                ),
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

void main() {
  // 9/16 帽：931 × 9/16 ≈ 523.7；卡片还要扣掉四边留边与标题栏，
  // 因此 body 实际可用高度应明显小于全屏、且是有限值。
  const double kRouteCap = 931 * 9.0 / 16.0;

  testWidgets('9 条：无溢出异常、body 拿有限高度、不按全内容高布局',
      (WidgetTester tester) async {
    await _openProblemSheet(tester, 9);

    // ① 无 RenderFlex overflow / 布局异常
    expect(tester.takeException(), isNull);

    final ScrollableState st =
        tester.state<ScrollableState>(find.byType(Scrollable).first);
    final RenderBox listBox =
        tester.renderObject<RenderBox>(find.byType(ListView));

    // ② body 高度有限且 ≤ 路由帽（修复前这里接近全屏 ~800，
    // ListView 按全内容高度 684 布局、maxScrollExtent == 0 滑不动）
    expect(listBox.size.height, greaterThan(0));
    expect(listBox.size.height, lessThanOrEqualTo(kRouteCap));
    expect(listBox.constraints.maxHeight, lessThanOrEqualTo(kRouteCap));

    // ③ 内容超槽位 → 可滚（修复前 maxScrollExtent == 0 完全滑不动）
    expect(st.position.maxScrollExtent, greaterThan(0));
    expect(st.position.viewportDimension, lessThanOrEqualTo(kRouteCap));

    // ③-b 拖拽真的滚动
    await tester.drag(find.byType(ListView), const Offset(0, -150));
    await tester.pump();
    expect(st.position.pixels, greaterThan(0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('30 条：仍可滚、内容不溢出路由帽', (WidgetTester tester) async {
    await _openProblemSheet(tester, 30);
    expect(tester.takeException(), isNull);

    final ScrollableState st =
        tester.state<ScrollableState>(find.byType(Scrollable).first);

    // 长内容：槽位把可视区钳在路由帽内，剩余走滚动
    expect(st.position.maxScrollExtent, greaterThan(0));
    expect(st.position.viewportDimension, lessThanOrEqualTo(kRouteCap));

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump();
    expect(st.position.pixels, greaterThan(0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('短内容（2 条）：卡片按自然高度、不撑满不溢出',
      (WidgetTester tester) async {
    await _openProblemSheet(tester, 2);
    expect(tester.takeException(), isNull);

    final RenderBox listBox =
        tester.renderObject<RenderBox>(find.byType(ListView));
    // 短内容远小于槽位：自然高度即 2 行文本高（每行 ~19.5 + 16 padding）
    expect(listBox.size.height, lessThan(200));
    // 短内容无需滚动（自然高 ≤ 槽位）
    final ScrollableState st =
        tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(st.position.maxScrollExtent, 0);
  });
}
