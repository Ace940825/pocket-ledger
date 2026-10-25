import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/accounts/presentation/credit_card_repay_page.dart';
import 'package:pocket_ledger/features/accounts/providers/accounts_providers.dart';

/// 信用卡还款页整页渲染测试：不接真实库，用 `Stream.value` 覆盖 accountsProvider。
/// 日期相关断言一律注入固定「今天」（[CreditCardRepayPage.now]），避免随真实日期漂移。
void main() {
  Account fakeAccount({
    required String id,
    required String name,
    required AccountType type,
    int balanceMinor = 0,
    int? creditLimitMinor,
    int? billingDay,
    int? dueDay,
    int sortOrder = 0,
  }) {
    return Account(
      id: id,
      bookId: 'default',
      name: name,
      type: type,
      balanceMinor: balanceMinor,
      currency: 'CNY',
      isArchived: false,
      status: AccountStatus.active,
      includeInTotal: true,
      sortOrder: sortOrder,
      updatedAt: 0,
      deleted: false,
      dirty: false,
      creditLimitMinor: creditLimitMinor,
      billingDay: billingDay,
      dueDay: dueDay,
    );
  }

  Widget wrap(List<Account> accounts, {DateTime? now}) {
    return ProviderScope(
      overrides: <Override>[
        accountsProvider
            .overrideWith((Ref ref) => Stream<List<Account>>.value(accounts)),
      ],
      child: MaterialApp(home: CreditCardRepayPage(now: now)),
    );
  }

  testWidgets('合计卡 + 负债账户还款卡渲染', (WidgetTester tester) async {
    // 固定「今天」= 2026-10-23：账单日/还款日均为 1/10 号（已过）→ 两个日期都归下月。
    final DateTime now = DateTime(2026, 10, 23);
    // 拉高视口，避免 ListView 懒构建导致下方卡片尚未实例化。
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    await tester.pumpWidget(
      wrap(
        <Account>[
          fakeAccount(
            id: 'a1',
            name: '中国农业银行',
            type: AccountType.creditCard,
            balanceMinor: 21200,
            creditLimitMinor: 70000,
            billingDay: 1,
            dueDay: 10,
          ),
          fakeAccount(
            id: 'a2',
            name: '花呗',
            type: AccountType.huabei,
            balanceMinor: 4000,
            creditLimitMinor: 70000,
            billingDay: 1,
            dueDay: 10,
            sortOrder: 1,
          ),
        ],
        now: now,
      ),
    );
    await tester.pumpAndSettle();

    // 标题 + 合计卡要素。
    expect(find.text('信用卡还款'), findsOneWidget);
    expect(find.text('合计'), findsOneWidget);
    expect(find.text('总负债(元)'), findsOneWidget);
    expect(find.text('负债资产数量'), findsOneWidget);
    expect(find.text('今日到期数量'), findsOneWidget);
    // 总负债 = 212 + 40 = 252 → 负号展示。
    expect(find.text('-¥252.00'), findsOneWidget);

    // 还款列表标题 + 两张账户卡。
    expect(find.text('还款列表'), findsOneWidget);
    expect(find.text('中国农业银行'), findsOneWidget);
    expect(find.text('花呗'), findsOneWidget);

    // 欠款 / 额度（农行：欠 212、可用 700−212=488；花呗：欠 40）。
    // 口径同小青账参考稿：欠款取正数红色展示（不再带负号），额度可负。
    expect(find.text('当前欠款(元)'), findsNWidgets(2));
    expect(find.text('212.00'), findsOneWidget);
    expect(find.text('40.00'), findsOneWidget);
    expect(find.text('488.00'), findsOneWidget);

    // 日期宫格标签与「每月X号」稳定值。
    expect(find.text('账单日期'), findsNWidgets(2));
    expect(find.text('出账日期'), findsNWidgets(2));
    expect(find.text('出账天数'), findsNWidgets(2));
    expect(find.text('还款日'), findsNWidgets(2));
    expect(find.text('还款日期'), findsNWidgets(2));
    expect(find.text('免息天数'), findsNWidgets(2));
    expect(find.text('每月1号'), findsNWidgets(2));
    expect(find.text('每月10号'), findsNWidgets(2));

    // 出账日期旁的 info 符号已移除。
    expect(find.byTooltip('下一个出账日'), findsNothing);

    // 1/10 号均已过 → 展示下月日期，每卡 2 个「下期」小签。
    expect(find.text('11月1日'), findsNWidgets(2));
    expect(find.text('11月10日'), findsNWidgets(2));
    expect(find.text('下期'), findsNWidgets(4));

    // 还款按钮 + 编辑按钮。
    expect(find.widgetWithText(FilledButton, '还款'), findsNWidgets(2));
    expect(find.widgetWithText(TextButton, '编辑'), findsNWidgets(2));
  });

  testWidgets('当月未过的日期标「当期」、已过的标「下期」', (WidgetTester tester) async {
    // 固定「今天」= 2026-10-23。
    final DateTime now = DateTime(2026, 10, 23);
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    await tester.pumpWidget(
      wrap(
        <Account>[
          // 卡 1：账单日 1 号（已过 → 下月）、还款日 28 号（未过 → 本月）。
          fakeAccount(
            id: 'a1',
            name: '招商银行',
            type: AccountType.creditCard,
            balanceMinor: 10000,
            creditLimitMinor: 50000,
            billingDay: 1,
            dueDay: 28,
          ),
          // 卡 2：账单日 20 号（已过 → 下月）、还款日 23 号（= 今天，归下月）。
          fakeAccount(
            id: 'a2',
            name: '花呗',
            type: AccountType.huabei,
            balanceMinor: 4000,
            creditLimitMinor: 70000,
            billingDay: 20,
            dueDay: 23,
            sortOrder: 1,
          ),
        ],
        now: now,
      ),
    );
    await tester.pumpAndSettle();

    // 当期仅卡 1 的还款日期（10月28日，本月未到）。
    expect(find.text('当期'), findsOneWidget);
    // 下期 3 个：卡 1 出账、卡 2 出账、卡 2 还款（今天即到期 → 归下月）。
    expect(find.text('下期'), findsNWidgets(3));

    // 具体日期值。
    expect(find.text('10月28日'), findsOneWidget);
    expect(find.text('11月1日'), findsOneWidget);
    expect(find.text('11月20日'), findsOneWidget);
    expect(find.text('11月23日'), findsOneWidget);
  });

  testWidgets('「当期 / 下期」小签两行纵向对齐', (WidgetTester tester) async {
    // 固定「今天」= 2026-10-20：账单日 1 号（已过 → 11月1日「下期」）、
    // 还款日 26 号（未过 → 10月26日「当期」）——同一张卡两行各一个小签。
    final DateTime now = DateTime(2026, 10, 20);
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    await tester.pumpWidget(
      wrap(
        <Account>[
          fakeAccount(
            id: 'a1',
            name: '招商银行',
            type: AccountType.creditCard,
            balanceMinor: 10000,
            creditLimitMinor: 50000,
            billingDay: 1,
            dueDay: 26,
          ),
        ],
        now: now,
      ),
    );
    await tester.pumpAndSettle();

    final Finder tagNext = find.text('下期');
    final Finder tagCurrent = find.text('当期');
    expect(tagNext, findsOneWidget);
    expect(tagCurrent, findsOneWidget);

    // 日期串宽度不同（「11月1日」比「10月26日」窄约一个数字位），
    // 小签落在「最长日期（12月31日）」实测槽位右侧 → 两行小签左缘严格同 x。
    final double nextDx = tester.getTopLeft(tagNext).dx;
    final double currentDx = tester.getTopLeft(tagCurrent).dx;
    expect(nextDx, closeTo(currentDx, 0.01));

    // 且分处上下两行（纵向堆叠才有「上下对齐」一说）。
    final double nextDy = tester.getTopLeft(tagNext).dy;
    final double currentDy = tester.getTopLeft(tagCurrent).dy;
    expect(currentDy - nextDy, greaterThan(20));

    // 槽位定位 ≠ 贴单元格右缘：小签右缘（文字 + 右内边距 4）必须与
    // 第三列「免息天数」左缘保持距离，不能顶到邻列。
    final double tagBgRight = tester.getTopLeft(tagCurrent).dx +
        tester.getSize(tagCurrent).width +
        4;
    final double col3Left = tester.getTopLeft(find.text('免息天数')).dx;
    expect(tagBgRight, lessThan(col3Left));
  });

  testWidgets('无负债账户：合计为 0 + 空提示', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        <Account>[
          fakeAccount(id: 'c1', name: '现金', type: AccountType.cash),
        ],
        now: DateTime(2026, 10, 23),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('信用卡还款'), findsOneWidget);
    expect(find.text('还没有信用卡 / 负债账户'), findsOneWidget);
    // 资金账户不算负债：负债资产数量 0。
    expect(find.text('负债资产数量'), findsOneWidget);
  });
}
