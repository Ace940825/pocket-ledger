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

/// 首页四卡循环滑动测试（第 41 批）。
///
/// 用户反馈：「往右滑滑不动，只能从往左滑跳转，而且跳转的很突兀」。
/// 旧实现只做尾部复制（8 页），从初始页往右滑到第 0 页即触底；
/// 且过副本时 jumpToPage 无动画回跳被感知为「突兀」。
/// 新实现：头尾双向复制（6 页），两个方向滑过副本都无感跳回真实页。
///
/// 不接真实数据库，用 Stream.value / overrideWithValue 覆盖页面依赖的
/// provider；只验证 PageView 的循环机械结构（页数 / 落点），不验证卡片内容。
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

  testWidgets('四卡双向循环：头尾复制 + 过副本无感跳回真实页', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final Finder pageView = find.byType(PageView);
    expect(pageView, findsOneWidget);
    final PageController controller =
        tester.widget<PageView>(pageView).controller!;

    // 结构：6 页 = 头部副本(第4张) + 4 张真实卡 + 尾部副本(第1张)。
    // 注意：PageView 无公开 children 字段，真实页数走 childrenDelegate。
    expect(
      tester.widget<PageView>(pageView).childrenDelegate.estimatedChildCount,
      6,
    );
    // 默认停在「本月收支」（真实下标 2 → 头部副本偏移 +1 = 3）。
    expect(controller.initialPage, 3);
    expect(controller.page, closeTo(3.0, 0.01));

    // 左滑一页：3 → 4（真实「资产总览」卡，不过副本）。
    await tester.drag(pageView, const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(controller.page, closeTo(4.0, 0.01));

    // 再左滑：4 → 5（尾部副本=第 1 张）→ 无感跳回真实第 1 页(1)。
    await tester.drag(pageView, const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(controller.page, closeTo(1.0, 0.01));

    // 右滑：1 → 0（头部副本=第 4 张）→ 无感跳回真实最后页(4)。
    // 旧实现无头复制，这一步滑不动——正是用户反馈「往右滑滑不动」。
    await tester.drag(pageView, const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(controller.page, closeTo(4.0, 0.01));

    // 继续右滑回真实卡：4 → 3，双向都能连续滑。
    await tester.drag(pageView, const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(controller.page, closeTo(3.0, 0.01));
  });
}
