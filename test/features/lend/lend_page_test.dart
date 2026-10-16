import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/accounts/providers/accounts_providers.dart';
import 'package:pocket_ledger/features/lend/presentation/lend_page.dart';
import 'package:pocket_ledger/features/lend/providers/lend_providers.dart';

/// 借还页渲染测试（第 35 批）。
///
/// 背景：第 34 批起不再预置账户，借还页原先只能看不能记（唯一动作是
/// 空态里的「去账户页新建」），直接沦为死空态。修复：底部常驻双按钮栏
/// （主「记一笔借还」+ 幽灵「去账户页新建」），空态去掉自有按钮、
/// 动作入口唯一。本测试锁死：
/// 1. 空态时动作入口仍然可见（页面不死）；
/// 2. 有记录时底部栏常驻。
///
/// 不接真实数据库，用 `Stream.value` 覆盖页面依赖的两个 provider。
void main() {
  LendRecord fakeRecord({
    required String id,
    String counterparty = '张三',
    int amountMinor = 10000,
    LendStatus status = LendStatus.ongoing,
  }) {
    return LendRecord(
      updatedAt: 0,
      deleted: false,
      dirty: false,
      id: id,
      bookId: 'default',
      direction: LendDirection.lendOut,
      status: status,
      counterparty: counterparty,
      amountMinor: amountMinor,
      currency: 'CNY',
      repaidMinor: 0,
      occurredAt: 0,
      dueAt: null,
      note: null,
      accountId: null,
      toAccountId: null,
      feeMinor: 0,
      discountMinor: 0,
      graceDays: 0,
    );
  }

  Widget wrap({List<LendRecord> records = const <LendRecord>[]}) {
    return ProviderScope(
      overrides: <Override>[
        accountsProvider.overrideWith(
          (Ref ref) => Stream<List<Account>>.value(const <Account>[]),
        ),
        lendListProvider.overrideWith(
          (Ref ref) => Stream<List<LendRecord>>.value(records),
        ),
      ],
      child: const MaterialApp(home: LendPage()),
    );
  }

  testWidgets('空态：说明文案 + 底部双按钮可见（不再是死页面）', (WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('还没有借还记录'), findsOneWidget);
    // 动作入口唯一且在空态可见：主按钮 + 幽灵按钮。
    expect(find.text('记一笔借还'), findsOneWidget);
    expect(find.text('去账户页新建'), findsOneWidget);
    // 空态自身不再放按钮（避免与底部栏双按钮重复）。
    expect(find.text('还没有借还账户'), findsNothing);
  });

  testWidgets('有未指定账户的记录：平铺区 + 底部栏常驻', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(
      records: <LendRecord>[fakeRecord(id: 'r1')],
    ));
    await tester.pumpAndSettle();

    expect(find.text('还没有借还记录'), findsNothing);
    expect(find.text('未指定账户的记录'), findsOneWidget);
    expect(find.text('张三'), findsOneWidget);
    // 底部栏常驻：有数据时也能记一笔。
    expect(find.text('记一笔借还'), findsOneWidget);
    expect(find.text('去账户页新建'), findsOneWidget);
  });

  // ── 第 41 批回归锁 ──────────────────────────────────────
  //
  // 真机事故：底栏按钮整只隐形但可点。根因是按钮装饰用了 Ink——Ink 装饰
  // 画在最近 Material 的 ink 层，而 _bottomBar 的 Container(color: surface)
  // 是不透明后代，绘制顺序在 ink 层之上，把渐变/描边/底色整体遮盖。
  // （Scaffold 自带的背景 Material 在底栏子树之下；GoRouter 路由树上方的
  // MaterialApp 不包裹路由内容，没有更近的 Material 可抬升 ink 层。）
  // 修法：装饰改由 Container 自绘（报销页空态按钮同款，渲染正常）。
  //
  // 本测试锁死两个不变量，防止回归：
  // 1. 按钮子树内不得再出现 Ink 装饰；
  // 2. 渐变确实挂在 Container 自绘装饰上（不是丢了）。
  testWidgets('底栏按钮装饰由 Container 自绘（ Ink 遮盖事故回归锁）',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    for (final String label in <String>['记一笔借还', '去账户页新建']) {
      final Finder button = find.ancestor(
        of: find.text(label),
        matching: find.byType(InkWell),
      );
      expect(button, findsOneWidget, reason: '$label 按钮应存在');
      expect(
        find.descendant(of: button, matching: find.byType(Ink)),
        findsNothing,
        reason: '$label 不得再用 Ink 画装饰（会被不透明 Container 遮盖）',
      );
    }
    // 主按钮的鼠尾草渐变必须挂在 Container 自绘装饰上。
    final Finder mainBtn = find.ancestor(
      of: find.text('记一笔借还'),
      matching: find.byType(InkWell),
    );
    expect(
      find.descendant(
        of: mainBtn,
        matching: find.byWidgetPredicate((Widget w) {
          if (w is! Container) return false;
          final Decoration? d = w.decoration;
          return d is BoxDecoration && d.gradient != null;
        }),
      ),
      findsOneWidget,
      reason: '主按钮渐变应由 Container 自绘',
    );
  });

  testWidgets('空态整体垂直居中（第 41 批：原为顶格）', (WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // 页面唯一的 Column 即空态列（底栏是 Row，AppBar 无 Column）。
    final Finder emptyCol = find.ancestor(
      of: find.text('还没有借还记录'),
      matching: find.byType(Column),
    );
    expect(emptyCol, findsOneWidget);

    final Rect colRect = tester.getRect(emptyCol);
    final Rect appBarRect = tester.getRect(find.byType(AppBar));
    // 底栏 SafeArea 用按钮文本锚定（框架层另有一个 SafeArea，byType 会歧义）。
    final Rect bottomBarRect = tester.getRect(
      find.ancestor(
        of: find.text('记一笔借还'),
        matching: find.byType(SafeArea),
      ),
    );
    final double bodyCenterY = (appBarRect.bottom + bottomBarRect.top) / 2;
    expect(
      (colRect.center.dy - bodyCenterY).abs(),
      lessThan(2),
      reason: '空态应垂直居中于 body 区（AppBar 与底栏之间）',
    );
  });
}
