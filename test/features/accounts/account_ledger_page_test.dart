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
    int? creditLimitMinor,
    int? billingDay,
    int? dueDay,
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
      creditLimitMinor: creditLimitMinor,
      billingDay: billingDay,
      dueDay: dueDay,
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
      feeMinor: 0,
      discountMinor: 0,
    excludeFromStats: false,
    excludeFromBudget: false,
    isReimbursable: false,
    updatedAt: 0,
    deleted: false,
    dirty: false,
    );
  }

  Widget wrap({
    required Account account,
    required List<Transaction> txns,
    AssetStatsSettings settings = const AssetStatsSettings(),
    DateTime? now,
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
        // 账单周期模式（有账单日的负债账户）改看 statement provider
        // （取数范围早一个月，覆盖 1 月账单周期的跨年尾巴）。测试数据由
        // 分组逻辑自行归属，这里原样给全量。
        accountTransactionsForStatementProvider(
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
      child: MaterialApp(
        home: AccountLedgerPage(accountId: accountId, now: now),
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
    expect(find.text('当前余额'), findsOneWidget);
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
    expect(find.text('当前欠款'), findsOneWidget);
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

  group('账单周期模式（有账单日的负债账户）', () {
    // 固定「今天」= 当年 10 月 23 日：与页面 _selectedYear（真实今年）同年，
    // 日期宫格与周期归属都不随真实日期漂移。
    final DateTime now = DateTime(DateTime.now().year, 10, 23);

    /// 招商信用卡：账单日 1 号、还款日 10 号（今天都已过 → 都归下月）。
    Account statementAccount() => fakeAccount(
          type: AccountType.creditCard,
          name: '招商银行',
          balanceMinor: 21200,
          creditLimitMinor: 70000,
          billingDay: 1,
          dueDay: 10,
        );

    testWidgets('账户卡扩展：欠款/可用额度 + 日期宫格 + 分期记账 + 跨年说明 + 双按钮',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      await tester.pumpWidget(
        wrap(account: statementAccount(), txns: <Transaction>[], now: now),
      );
      await tester.pumpAndSettle();

      // 顶部抬头不动：账户名 + 类型 + 编辑胶囊。
      expect(find.text('招商银行'), findsOneWidget);
      expect(find.text('信用卡'), findsOneWidget);
      expect(find.text('编辑'), findsOneWidget);
      // 资产详情标题仍在。
      expect(find.text('资产详情'), findsOneWidget);

      // 欠款 212.00（正数红色口径）；可用额度 = 700 − 212 = 488。
      expect(find.text('当前欠款(元)'), findsOneWidget);
      expect(find.text('可用额度'), findsOneWidget);
      expect(find.text('212.00'), findsOneWidget);
      expect(find.text('488.00'), findsOneWidget);
      // 非周期模式的「当前欠款」大数字标签被信息区取代，不再单独出现。
      expect(find.text('当前欠款'), findsNothing);

      // 日期宫格两行三列（与信用卡还款页同款）。
      for (final String label in <String>[
        '账单日期',
        '出账日期',
        '出账天数',
        '还款日',
        '还款日期',
        '免息天数',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      // 1/10 号今天都已过 → 展示下月日期 + 「下期」小签。
      expect(find.text('11月1日'), findsOneWidget);
      expect(find.text('11月10日'), findsOneWidget);
      expect(find.text('下期'), findsNWidgets(2));

      // 分期记账入口胶囊。
      expect(find.text('分期记账'), findsOneWidget);

      // 跨年账单说明卡。
      expect(find.textContaining('跨年的账单'), findsOneWidget);

      // 底栏双按钮：记一笔（描边）+ 还款（品牌绿实底）。
      expect(find.text('记一笔'), findsOneWidget);
      expect(find.text('还款'), findsOneWidget);
    });

    testWidgets('月份按账单周期分组：9 月消费归 10 月账单，12 月账单日后不归本年',
        (WidgetTester tester) async {
      final List<Transaction> txns = <Transaction>[
        fakeTx(
          id: 'sep',
          type: TxnType.expense,
          amountMinor: 2500,
          occurredLocal: DateTime(now.year, 9, 15, 10, 0),
        ),
        fakeTx(
          id: 'oct1',
          type: TxnType.expense,
          amountMinor: 1000,
          occurredLocal: DateTime(now.year, 10, 1, 9, 0),
        ),
        fakeTx(
          id: 'oct5',
          type: TxnType.expense,
          amountMinor: 3000,
          occurredLocal: DateTime(now.year, 10, 5, 20, 0),
        ),
        fakeTx(
          id: 'dec20',
          type: TxnType.expense,
          amountMinor: 9900,
          occurredLocal: DateTime(now.year, 12, 20, 12, 0),
        ),
      ];

      await tester.binding.setSurfaceSize(const Size(800, 2400));
      await tester.pumpWidget(
        wrap(account: statementAccount(), txns: txns, now: now),
      );
      await tester.pumpAndSettle();

      // 10 月账单（周期 9月2日–10月1日）：9/15 + 10/1 → 支出 25 + 10 = 35。
      expect(find.text('10月'), findsOneWidget);
      expect(find.text('周期：9月2日–10月1日'), findsOneWidget);
      expect(find.text('支出 ¥35.00'), findsOneWidget);
      // 11 月账单（周期 10月2日–11月1日）：10/5 → 支出 30。
      expect(find.text('11月'), findsOneWidget);
      expect(find.text('周期：10月2日–11月1日'), findsOneWidget);
      expect(find.text('支出 ¥30.00'), findsOneWidget);
      // 12/20 属次年 1 月账单 → 本年列表没有 12 月组。
      expect(find.text('12月'), findsNothing);

      // 明细按组内真实日期分日展示；12/20 那笔不出现。
      expect(find.text('-¥25.00'), findsOneWidget);
      expect(find.text('-¥10.00'), findsOneWidget);
      expect(find.text('-¥30.00'), findsOneWidget);
      expect(find.text('-¥99.00'), findsNothing);
    });
  });
}
