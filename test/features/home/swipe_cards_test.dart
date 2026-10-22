import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/accounts/providers/accounts_providers.dart';
import 'package:pocket_ledger/features/budget/providers/budget_providers.dart';
import 'package:pocket_ledger/features/home/presentation/home_page.dart';
import 'package:pocket_ledger/features/ledger/providers/ledger_providers.dart';
import 'package:pocket_ledger/features/lend/providers/lend_providers.dart';

/// 首页四卡循环滑动测试（第 42 批：无限列表版）。
///
/// 演进：第 41 批「头尾复制 6 页 + 滑到副本 jumpToPage 跳回」被用户反馈
/// 「松手瞬移打断惯性、循环生硬」；第 42 批改为 **PageView.builder 无限列表**
/// （`itemCount: null` + `index % 4` 复用四张真实卡 + `initialPage: 100002`
/// ≡ 2 mod 4 落在「本月收支」卡）——左右永远有真实页可滑，零跳回、惯性连续。
/// 指示点同步改为按 `controller.page % count` 环形距离连续插值。
///
/// 不接真实数据库，用 Stream.value / overrideWithValue 覆盖页面依赖的
/// provider；只验证 PageView 的循环机械结构（无限性 / 落点）与指示点插值，
/// 不验证卡片内容。
void main() {
  Widget wrap() {
    return ProviderScope(
      overrides: <Override>[
        netAssetsProvider.overrideWithValue(const AsyncValue<int>.data(0)),
        totalAssetsProvider.overrideWithValue(const AsyncValue<int>.data(0)),
        totalLiabilitiesProvider.overrideWithValue(
          const AsyncValue<int>.data(0),
        ),
        borrowInOngoingProvider.overrideWith((Ref ref) => Stream<int>.value(0)),
        monthBudgetSummaryProvider(CategoryType.expense).overrideWithValue(
          (total: 0, spent: 0, remaining: 0),
        ),
        monthBudgetSummaryProvider(CategoryType.income).overrideWithValue(
          (total: 0, spent: 0, remaining: 0),
        ),
        monthIncomeProvider.overrideWith((Ref ref) => Stream<int>.value(0)),
        monthExpenseProvider.overrideWith((Ref ref) => Stream<int>.value(0)),
        recentTransactionsProvider.overrideWith(
          (Ref ref) => Stream<List<Transaction>>.value(const <Transaction>[]),
        ),
      ],
      child: const MaterialApp(home: HomePage()),
    );
  }

  /// 指示点定位：Container + 水平 3 外边距 + 圆角 3 的 BoxDecoration，
  /// 与 _PageDots 的实现一一对应（页面内无其他同特征组件）。
  final Finder dots = find.byWidgetPredicate((Widget w) {
    if (w is! Container) return false;
    if (w.margin != const EdgeInsets.symmetric(horizontal: 3)) return false;
    final BoxDecoration? d = w.decoration is BoxDecoration
        ? w.decoration as BoxDecoration
        : null;
    return d?.borderRadius == BorderRadius.circular(3);
  });

  /// 取四个指示点的渲染宽度并归一化：element.renderObject 会向下取到最外层
  /// 渲染对象（margin 的 Padding 在最外层，含左右各 3 的边距），故统一减去
  /// 最小基值，只断言「相对拉长量」——不耦合边距/公式常量等实现细节。
  List<double> dotWidths(WidgetTester tester) {
    final List<double> raw = dots
        .evaluate()
        .map((Element e) => (e.renderObject! as RenderBox).size.width)
        .toList(growable: false);
    final double base = raw.reduce((double a, double b) => a < b ? a : b);
    return raw.map((double w) => w - base).toList(growable: false);
  }

  testWidgets('无限列表：头尾无副本，estimatedChildCount 为 null', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final Finder pageView = find.byType(PageView);
    expect(pageView, findsOneWidget);
    final PageView view = tester.widget<PageView>(pageView);

    // itemCount: null = 真·无限列表（区别于旧版 6 页头尾复制）。
    expect(view.childrenDelegate.estimatedChildCount, isNull);
    expect(view.controller!.initialPage, 100002);
    // 100002 % 4 == 2 → 默认停在「本月收支」卡。
    expect(view.controller!.page, closeTo(100002.0, 0.01));
  });

  testWidgets('双向无限滑动：不过副本、不跳回、左右都连续', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final Finder pageView = find.byType(PageView);
    final PageController controller =
        tester.widget<PageView>(pageView).controller!;

    // 左滑一页：100002 → 100003（真实「资产总览」卡）。
    await tester.drag(pageView, const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(controller.page, closeTo(100003.0, 0.01));

    // 继续左滑：100003 → 100004（回到「支出预算」卡）——无副本、无跳回，
    // 与旧版「滑到副本瞬移跳回」形成对照。
    await tester.drag(pageView, const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(controller.page, closeTo(100004.0, 0.01));

    // 右滑两页回到初始位：100004 → 100002。
    await tester.drag(pageView, const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(controller.page, closeTo(100003.0, 0.01));
    await tester.drag(pageView, const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(controller.page, closeTo(100002.0, 0.01));

    // 继续右滑不触底：100002 → 100001（「收入目标」卡）——旧版在此处
    // 已无页可滑（用户反馈「往右滑滑不动」）。
    await tester.drag(pageView, const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(controller.page, closeTo(100001.0, 0.01));
  });

  testWidgets('指示点：整页滑动后高亮跟随当前卡', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // 静止在 100002（≡ 本月收支，下标 2）：第 3 点拉长（+12），
    // 其余为基值（+0）。
    expect(dots, findsNWidgets(4));
    expect(dotWidths(tester), <double>[0, 0, 12, 0]);

    // 左滑整页到 100003（≡ 资产总览，下标 3）：高亮移到第 4 点。
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(dotWidths(tester), <double>[0, 0, 0, 12]);

    // 右滑整页回 100002：高亮移回第 3 点。
    await tester.drag(find.byType(PageView), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(dotWidths(tester), <double>[0, 0, 12, 0]);
  });

  testWidgets('指示点：滑动半页时相邻两点连续均分', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // 左滑半页（不 settle）：page≈100002.5 → 环形位置≈2.5，
    // 第 3、4 点各占约一半（≈6/≈6），证明插值连续而非跳变。
    // 拖拽落点有浮点误差（实测 2.506），故用容差而非精确值。
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pump();
    final List<double> mid = dotWidths(tester);
    expect(mid[0], closeTo(0, 0.01));
    expect(mid[1], closeTo(0, 0.01));
    expect(mid[2], closeTo(6, 0.75));
    expect(mid[3], closeTo(6, 0.75));
    expect((mid[2] - mid[3]).abs(), lessThan(0.5));
  });
}
