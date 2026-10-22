// 弹层外壳顶部留边测试（2026-10-20 用户截图反馈「顶部已经顶到头了」）。
//
// AppModalSheet 设计规格是「四周留边」悬浮卡，但上边距曾恒为 0：
// 贴底短弹层看不出问题，而 isScrollControlled + constrainHeight 的全高
// 弹层（分类排序 / 子分类排序 / 记账设置 / 存钱目标计划调整共 4 处）会
// 一路撑到屏幕顶端，标题直接顶到状态栏。现上边距 = 状态栏高度 + md。
//
// ⚠️ 状态栏高度为什么读 View.of(context).padding 而不是 MediaQuery：
// 弹层路由默认 useSafeArea=false，底层用
// MediaQuery.removePadding(removeTop: true) 包住整个弹层内容（连
// viewPadding 一起减掉）；Scaffold 有 AppBar 时也会剥掉页面 body 的 top
// padding。两重剥离后 MediaQuery 在弹层内恒为 0（本测试外层 MediaQuery
// 特意给 0 padding 模拟该场景），唯有原始视图 padding 不受影响。
//
// 本测试锁定：
//   1) 全高弹层卡片顶部恰好停在「状态栏 + md」，不进入状态栏区；
//   2) 贴底短弹层仍贴底（底部 md 留边不变、按内容收缩）——证明加顶部
//      留边对既有短弹层零回归（底层 _ModalBottomSheetLayout 贴底锚定，
//      顶部 margin 只是卡片上方不可见空白）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/shared/widgets/sheet_scaffold.dart';

const Size kPhone = Size(418, 931); // 与用户反馈截图同尺寸
const double kStatusBar = 47; // 伪造的视图状态栏高度
const double kEdge = 12; // AppDimens.md
const double kExpectedTopGap = kStatusBar + kEdge;

/// 打开一个弹层并等动画结束。[fullHeight] 为 true 时复刻「分类排序」的
/// 结构（isScrollControlled + constrainHeight + Column + Expanded 长列表），
/// 为 false 时为普通贴底短弹层。页面带 AppBar（真机页面同款）。
Future<void> _openSheet(
  WidgetTester tester, {
  required bool fullHeight,
  Brightness brightness = Brightness.light,
}) async {
  // 伪造状态栏 / home indicator：TestFlutterView 原生支持。
  tester.view.padding = const FakeViewPadding(top: kStatusBar, bottom: 34);
  await tester.binding.setSurfaceSize(kPhone);
  await tester.pumpWidget(
    // 外层 MediaQuery 的 padding 给 0：模拟「Scaffold AppBar 已剥掉 top
    // padding」的真机场景——此时 MediaQuery 在弹层内恒为 0，只有
    // View.of(context).padding 能拿到真实状态栏高度。
    MediaQuery(
      data: const MediaQueryData(size: kPhone),
      child: MaterialApp(
        theme: ThemeData(brightness: brightness, useMaterial3: true),
        home: Scaffold(
          appBar: AppBar(title: const Text('分类管理')),
          // 用与卡片区隔明显的底色，让 golden 里悬浮卡的四边留边可辨。
          backgroundColor: brightness == Brightness.light
              ? const Color(0xFFCBD3B6)
              : const Color(0xFF171A15),
          body: Builder(
            builder: (BuildContext context) => ElevatedButton(
              onPressed: () => showAppModalSheet<void>(
                context,
                title: '分类排序',
                titleTrailing: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
                isScrollControlled: true,
                constrainHeight: fullHeight,
                body: fullHeight
                    ? Column(
                        children: <Widget>[
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.builder(
                              itemCount: 12,
                              itemBuilder: (_, int i) => ListTile(
                                leading: const CircleAvatar(
                                  radius: 14,
                                  child: Icon(Icons.circle, size: 12),
                                ),
                                title: Text('分类 $i'),
                                trailing: const Icon(Icons.drag_handle),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      )
                    : const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ListTile(title: Text('选项一')),
                          ListTile(title: Text('选项二')),
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

/// 悬浮卡视觉盒子：AppModalSheet 里那个带圆角的 [DecoratedBox]。
/// 注意不能直接用 `find.byType(Container)`——Container 的 margin 是最外层
/// Padding，量到的是「含边距的整块」（通屏通高），不是卡片本身。
Finder get _cardFinder => find.descendant(
      of: find.byType(AppModalSheet),
      matching: find.byWidgetPredicate(
        (Widget w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).borderRadius != null,
      ),
    );

void main() {
  testWidgets('全高弹层：卡片顶部停在「状态栏 + md」，不顶到头', (
    WidgetTester tester,
  ) async {
    await _openSheet(tester, fullHeight: true);
    final Rect card = tester.getRect(_cardFinder);
    debugPrint('全高弹层卡片 rect=$card（期望 top=$kExpectedTopGap）');
    // 顶部留边 = 状态栏 47 + md 12 = 59，不顶到头。
    expect(card.top, greaterThanOrEqualTo(kExpectedTopGap - 0.5));
    expect(card.top, lessThanOrEqualTo(kExpectedTopGap + 0.5));
    // 左右 / 底部 md 留边保持，卡片不越界。
    expect(card.left, greaterThanOrEqualTo(kEdge - 0.5));
    expect(card.right, lessThanOrEqualTo(kPhone.width - kEdge + 0.5));
    expect(card.bottom, lessThanOrEqualTo(kPhone.height - kEdge + 0.5));
    // 标题随卡片下移，不进入状态栏区。
    expect(
      tester.getTopLeft(find.text('分类排序')).dy,
      greaterThanOrEqualTo(kExpectedTopGap),
    );
  });

  testWidgets('贴底短弹层：仍贴底 + 按内容收缩（顶部留边零回归）', (
    WidgetTester tester,
  ) async {
    await _openSheet(tester, fullHeight: false);
    final Rect card = tester.getRect(_cardFinder);
    debugPrint('短弹层卡片 rect=$card');
    // 底部 md 留边不变 → 贴底锚定未被破坏。
    expect(card.bottom, lessThanOrEqualTo(kPhone.height - kEdge + 0.5));
    expect(card.bottom, greaterThanOrEqualTo(kPhone.height - kEdge - 0.5));
    // 卡片按内容高度收缩（内容矮 → 卡片矮），没被拉高去「够到」顶部留边。
    expect(card.height, lessThan(kPhone.height * 0.5));
  });

  testWidgets('golden：全高弹层亮色（四边留边可见）', (
    WidgetTester tester,
  ) async {
    await _openSheet(tester, fullHeight: true, brightness: Brightness.light);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('sheet_top_gap_light.png'),
    );
  });

  testWidgets('golden：全高弹层暗色（四边留边可见）', (
    WidgetTester tester,
  ) async {
    await _openSheet(tester, fullHeight: true, brightness: Brightness.dark);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('sheet_top_gap_dark.png'),
    );
  });
}
