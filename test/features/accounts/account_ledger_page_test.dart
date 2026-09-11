import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/accounts/presentation/account_ledger_page.dart';
import 'package:pocket_ledger/features/accounts/providers/accounts_providers.dart';
import 'package:pocket_ledger/providers/asset_stats_settings.dart';

/// 资产详情页的整页渲染测试。
///
/// 不接真实数据库，而是用 `Stream.value` 覆盖页面依赖的 provider，
/// 这样可以控制数据、避免 Drift 在 fake-async 下残留 Timer，
/// 同时照样把整页渲染出来 —— 用来捕获「布局溢出 / 空约束」这类运行时错误。
void main() {
  const String accountId = 'acc1';

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  Account fakeAccount({
    required AccountType type,
    int balanceMinor = 11300,
    String name = '中国工商银行',
  }) {
    return Account(
      id: accountId,
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

  Transaction fakeTx({
    required String id,
    required TxnType type,
    required int amountMinor,
    required DateTime occurredLocal,
    String? toAccountId,
  }) {
    return Transaction(
      id: id,
      bookId: 'default',
      type: type,
      amountMinor: amountMinor,
      currency: 'CNY',
      accountId: accountId,
      toAccountId: toAccountId,
      occurredAt: occurredLocal.toUtc().millisecondsSinceEpoch,
      sourceModule: SourceModule.ledger,
      updatedAt: 0,
      deleted: false,
      dirty: false,
    );
  }

  Widget wrap({
    required Account account,
    required List<Transaction> txns,
    AssetStatsSettings settings = const AssetStatsSettings(),
  }) {
    return ProviderScope(
      overrides: <Override>[
        accountByIdProvider(accountId)
            .overrideWith((ref) => Stream<Account?>.value(account)),
        accountTransactionsByYearProvider(
          (accountId: accountId, year: DateTime.now().year),
        ).overrideWith(
          (ref) => Stream<List<Transaction>>.value(txns),
        ),
        accountsProvider.overrideWith(
          (ref) => Stream<List<Account>>.value(<Account>[account]),
        ),
        categoryMapProvider.overrideWith(
          (ref) => Stream<Map<String, Category>>.value(<String, Category>{}),
        ),
        assetStatsSettingsProvider.overrideWith((ref) {
          final AssetStatsSettingsNotifier notifier =
              AssetStatsSettingsNotifier(const FlutterSecureStorage());
          // save() 在第一个 await 之前同步赋值 state，首帧即为目标设置。
          notifier.save(settings);
          return notifier;
        }),
      ],
      child: const MaterialApp(
        home: AccountLedgerPage(accountId: accountId),
      ),
    );
  }

  testWidgets('渲染账户卡片 + 年份行 + 按月分组 + 记一笔按钮', (WidgetTester tester) async {
    final DateTime now = DateTime.now();
    final Account account = fakeAccount(type: AccountType.bankCard);
    final List<Transaction> txns = <Transaction>[
      fakeTx(
        id: 't1',
        type: TxnType.expense,
        amountMinor: 2500,
        occurredLocal: DateTime(now.year, now.month, 10, 14, 17),
      ),
    ];

    await tester.pumpWidget(wrap(account: account, txns: txns));
    await tester.pumpAndSettle();

    // 顶部 AppBar 与账户卡片
    expect(find.text('资产详情'), findsOneWidget);
    // 账户名出现 2 处：卡片标题 + 交易行的账户说明
    expect(find.text('中国工商银行'), findsNWidgets(2));
    expect(find.text('借记卡'), findsOneWidget);
    expect(find.text('当前余额(元)'), findsOneWidget);
    expect(find.text('¥113.00'), findsOneWidget); // 余额带 ¥ 符号

    // 年份选择行
    expect(find.text('${now.year}年'), findsOneWidget);

    // 月份分组标题 + 当月支出汇总
    expect(find.text('${now.month}月'), findsOneWidget);
    expect(find.text('支出 ¥25.00'), findsOneWidget);

    // 交易金额：支出显示为负号 + ¥
    expect(find.text('-¥25.00'), findsOneWidget);

    // 底部「记一笔」
    expect(find.text('记一笔'), findsOneWidget);
  });

  testWidgets('信用卡账户显示「当前欠款」', (WidgetTester tester) async {
    final Account account = fakeAccount(
      type: AccountType.creditCard,
      name: '招行信用卡',
    );

    await tester.pumpWidget(
      wrap(account: account, txns: <Transaction>[]),
    );
    await tester.pumpAndSettle();

    expect(find.text('招行信用卡'), findsOneWidget);
    expect(find.text('当前欠款(元)'), findsOneWidget);
    expect(find.text('信用卡'), findsOneWidget);
  });

  testWidgets('无流水的年份显示空态提示', (WidgetTester tester) async {
    final Account account = fakeAccount(type: AccountType.bankCard);

    await tester.pumpWidget(
      wrap(account: account, txns: <Transaction>[]),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('暂无流水'), findsOneWidget);
    expect(find.text('中国工商银行'), findsOneWidget); // 账户卡片仍在
  });

  testWidgets('点击月份标题可折叠/展开该月明细', (WidgetTester tester) async {
    final DateTime now = DateTime.now();
    final Account account = fakeAccount(type: AccountType.bankCard);
    final List<Transaction> txns = <Transaction>[
      fakeTx(
        id: 't1',
        type: TxnType.expense,
        amountMinor: 2500,
        occurredLocal: DateTime(now.year, now.month, 10, 14, 17),
      ),
    ];

    await tester.pumpWidget(wrap(account: account, txns: txns));
    await tester.pumpAndSettle();
    expect(find.text('-¥25.00'), findsOneWidget);

    // 折叠
    await tester.tap(find.text('${now.month}月'));
    await tester.pumpAndSettle();
    expect(find.text('-¥25.00'), findsNothing);
    expect(find.text('${now.month}月'), findsOneWidget); // 标题仍在

    // 展开
    await tester.tap(find.text('${now.month}月'));
    await tester.pumpAndSettle();
    expect(find.text('-¥25.00'), findsOneWidget);
  });

  group('当月汇总条：其他 / 结余', () {
    final DateTime now = DateTime.now();

    /// 支出 ¥10.00 + 转出 ¥5.00（本账户是转出方）。
    List<Transaction> txnsWithTransfer() => <Transaction>[
          fakeTx(
            id: 't1',
            type: TxnType.expense,
            amountMinor: 1000,
            occurredLocal: DateTime(now.year, now.month, 10, 14, 17),
          ),
          fakeTx(
            id: 't2',
            type: TxnType.transfer,
            amountMinor: 500,
            occurredLocal: DateTime(now.year, now.month, 11, 9, 0),
            toAccountId: 'acc2',
          ),
        ];

    testWidgets('默认（两个开关都关）：显示 其他 + 结余，结余 = 支出 − 收入',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          account: fakeAccount(type: AccountType.bankCard),
          txns: txnsWithTransfer(),
        ),
      );
      await tester.pumpAndSettle();

      // 支出 10.00 +（转账没折进来）→ 其他 5.00；结余 = 10.00 − 0.00
      expect(
        find.text('支出:¥10.00 收入:¥0.00 其他:¥5.00 结余:¥10.00'),
        findsOneWidget,
      );
    });

    testWidgets('收入多于支出时结余为负（口径：支出 − 收入）', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          account: fakeAccount(type: AccountType.bankCard),
          txns: <Transaction>[
            fakeTx(
              id: 't1',
              type: TxnType.expense,
              amountMinor: 100,
              occurredLocal: DateTime(now.year, now.month, 10, 14, 17),
            ),
            fakeTx(
              id: 't2',
              type: TxnType.income,
              amountMinor: 900,
              occurredLocal: DateTime(now.year, now.month, 11, 9, 0),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('支出:¥1.00 收入:¥9.00 其他:¥0.00 结余:-¥8.00'),
        findsOneWidget,
      );
    });

    testWidgets('两个收支开关都打开：其他整项隐藏，只留 支出 / 收入 / 结余',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          account: fakeAccount(type: AccountType.bankCard),
          txns: txnsWithTransfer(),
          settings: const AssetStatsSettings(
            expenseWithTransfer: true,
            incomeWithTransfer: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 转出 ¥5.00 折进支出 → 支出 15.00；结余 = 15.00 − 0.00
      expect(
        find.text('支出:¥15.00 收入:¥0.00 结余:¥15.00'),
        findsOneWidget,
      );
      expect(find.textContaining('其他:'), findsNothing, reason: '「其他」整项不应出现');
    });
  });
}
