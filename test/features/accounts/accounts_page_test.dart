import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/accounts/data/account_group_collapse.dart';
import 'package:pocket_ledger/features/accounts/data/account_group_order.dart';
import 'package:pocket_ledger/features/accounts/presentation/accounts_page.dart';
import 'package:pocket_ledger/features/accounts/providers/accounts_providers.dart';
import 'package:pocket_ledger/features/lend/providers/lend_providers.dart';
import 'package:pocket_ledger/features/reimbursement/providers/reimbursement_providers.dart';

/// 账户列表页（分组卡片布局）的整页渲染测试。
///
/// 不接真实数据库，用 `Stream.value` 覆盖页面依赖的 provider，
/// 避免 Drift 在 fake-async 下残留 Timer。
void main() {
  Account fakeAccount({
    required String id,
    required String name,
    required AccountType type,
    int balanceMinor = 10000,
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
      sortOrder: 0,
      updatedAt: 0,
      deleted: false,
      dirty: false,
    );
  }

  Widget wrap({
    required List<Account> accounts,
    int reimbursementMinor = 0,
    int lendOutMinor = 0,
    int borrowInMinor = 0,
  }) {
    return ProviderScope(
      overrides: <Override>[
        accountsProvider
            .overrideWith((Ref ref) => Stream<List<Account>>.value(accounts)),
        netAssetsProvider.overrideWith((Ref ref) => Stream<int>.value(0)),
        reimbursementPendingProvider
            .overrideWith((Ref ref) => Stream<int>.value(reimbursementMinor)),
        lendOutOngoingProvider
            .overrideWith((Ref ref) => Stream<int>.value(lendOutMinor)),
        borrowInOngoingProvider
            .overrideWith((Ref ref) => Stream<int>.value(borrowInMinor)),
        accountGroupOrderProvider
            .overrideWith((Ref ref) => AccountGroupOrderNotifier(FakeStorage())),
        accountGroupCollapsedProvider.overrideWith(
          (Ref ref) => AccountGroupCollapseNotifier(FakeStorage()),
        ),
      ],
      child: const MaterialApp(home: AccountsPage()),
    );
  }

  testWidgets('分组卡片渲染：净资产 + 资金/投资/负债分组', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(accounts: <Account>[
      fakeAccount(id: 'a1', name: '招商储蓄卡', type: AccountType.bankCard),
      fakeAccount(id: 'a2', name: '股票账户', type: AccountType.investment),
      fakeAccount(
        id: 'a3',
        name: '招行信用卡',
        type: AccountType.creditCard,
        balanceMinor: 50000,
      ),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('净资产'), findsOneWidget);
    expect(find.text('资金类'), findsOneWidget);
    expect(find.text('投资类'), findsOneWidget);
    expect(find.text('负债类'), findsOneWidget);
    // 应收/应付无数据，默认隐藏
    expect(find.text('应收类'), findsNothing);
    expect(find.text('应付类'), findsNothing);

    expect(find.text('招商储蓄卡'), findsOneWidget);
    expect(find.text('股票账户'), findsOneWidget);
    expect(find.text('招行信用卡'), findsOneWidget);
    // 资金/投资行各带「资产」标签、信用卡带「负债」标签
    expect(find.text('资产'), findsAtLeastNWidgets(1));
    expect(find.text('负债'), findsOneWidget); // 仅一张信用卡
  });

  testWidgets('点击分组头部折叠/展开', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(accounts: <Account>[
      // 账户名与类型标签不同，避免 find.text 误匹配到两项
      fakeAccount(id: 'a1', name: '我的现金', type: AccountType.cash),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('我的现金'), findsOneWidget);

    // 点击「资金类」头部折叠
    await tester.tap(find.text('资金类'));
    await tester.pumpAndSettle();

    // AnimatedCrossFade 折叠后把隐藏内容放在 Offstage，需用 skipOffstage 验证真正隐藏
    expect(find.text('我的现金', skipOffstage: true), findsNothing);

    // 再次点击展开
    await tester.tap(find.text('资金类'));
    await tester.pumpAndSettle();

    expect(find.text('我的现金', skipOffstage: true), findsOneWidget);
  });

  testWidgets('应收/应付分组：有金额时显示，无金额时隐藏', (WidgetTester tester) async {
    // 拉高视口，避免 Sliver 懒构建导致「应付类」卡片尚未实例化
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    await tester.pumpWidget(wrap(
      accounts: <Account>[
        fakeAccount(id: 'a1', name: '现金', type: AccountType.cash),
      ],
      reimbursementMinor: 8800,
      borrowInMinor: 20000,
    ));
    await tester.pumpAndSettle();

    expect(find.text('应收类'), findsOneWidget);
    expect(find.text('待收回报销'), findsOneWidget);
    // 金额同时出现在分组头部与汇总行
    expect(find.text('¥88.00'), findsAtLeastNWidgets(1));

    expect(find.text('应付类'), findsOneWidget);
    expect(find.text('借入'), findsOneWidget);
    expect(find.text('¥200.00'), findsAtLeastNWidgets(1));
  });

  testWidgets('空账户列表：资金类显示空 hint', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(accounts: const <Account>[]));
    await tester.pumpAndSettle();

    // 只有净资产头部，资金类卡片 still visible with empty state
    expect(find.text('净资产'), findsOneWidget);
    expect(find.text('还没有资金账户，点右上角新增'), findsOneWidget);
  });
}

class FakeStorage extends Fake implements FlutterSecureStorage {}
