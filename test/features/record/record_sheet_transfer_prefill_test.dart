import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pocket_ledger/core/bootstrap.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/accounts/presentation/credit_card_repay_page.dart';
import 'package:pocket_ledger/features/accounts/providers/accounts_providers.dart';
import 'package:pocket_ledger/features/record/presentation/record_sheet.dart';
import 'package:pocket_ledger/features/record/providers/recording_settings_provider.dart';
import 'package:pocket_ledger/features/record/record_tab.dart';
import 'package:pocket_ledger/providers/app_providers.dart';
import 'package:pocket_ledger/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 转账预填测试（旧独立「转账页」移除后改写）：
/// 信用卡还款页「还款」键与「更多 → 转账」统一走「记一笔」转账 Tab，
/// 入口可经 [RecordSheet.initialTransferToAccountId] 预填「转入账户」。
///
/// 转账中间区是错位双卡：转出卡空置时占位文案「转出账户」，
/// 转入卡空置时占位「转入账户」；预填后占位被账户名替换。
///
/// 工程约定（踩坑）：bootstrapData 内含 drift 事务，在 testWidgets 的
/// 假异步区里永不完成（Completer 依赖真实事件循环）——DB 初始化一律放
/// setUp/tearDown（真实异步），testWidgets 体内只做 pump + 断言。
/// 另：记一笔整页有常驻帧调度，pumpAndSettle 不收敛，用 pump + 定时长 pump。
void main() {
  late AppDatabase db;

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SharedPreferences.setMockInitialValues(<String, String>{});
    appPrefs = await SharedPreferences.getInstance();
  });

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await bootstrapData(db);
  });

  tearDown(() async {
    await db.close();
  });

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

  /// 记一笔转账 Tab 的挂载环境：setUp 里已 bootstrap 的真内存库 +
  /// accountsProvider 以固定流覆盖（资金账户含信用卡）。
  Widget wrapRecordSheet(List<Account> accounts, {String? prefillToAccountId}) {
    return ProviderScope(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        accountsProvider
            .overrideWith((Ref ref) => Stream<List<Account>>.value(accounts)),
      ],
      child: MaterialApp(
        // 必须带主题：页面大量使用 context.app / context.colors 主题扩展，
        // 裸 MaterialApp 缺 ForestSage 令牌会抛 null check operator。
        theme: AppThemeData.light,
        home: RecordSheet(
          initialTab: RecordTab.transfer,
          initialTransferToAccountId: prefillToAccountId,
        ),
      ),
    );
  }

  testWidgets('传入 initialTransferToAccountId：转入账户预填、转出账户空置',
      (WidgetTester tester) async {
    // 拉高视口：记一笔整页较高，默认 800×600 会 RenderFlex 溢出。
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      wrapRecordSheet(
        <Account>[
          fakeAccount(
            id: 'a1',
            name: '中国农业银行',
            type: AccountType.creditCard,
            balanceMinor: 21200,
            creditLimitMinor: 70000,
            billingDay: 1,
            dueDay: 10,
            sortOrder: 1,
          ),
          fakeAccount(id: 'c1', name: '现金', type: AccountType.cash),
        ],
        prefillToAccountId: 'a1',
      ),
    );
    // 记一笔有常驻帧调度：pump + 定时长 pump（不用 pumpAndSettle）。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    // 转入卡占位「转入账户」被负债账户名替换。
    expect(find.text('中国农业银行'), findsOneWidget);
    expect(find.text('转入账户'), findsNothing);
    // 转出卡仍空置（占位在，现金未作为已选值出现）。
    expect(find.text('转出账户'), findsOneWidget);
    expect(find.text('现金'), findsNothing);

    // 收尾：卸载页面 + 推进微小时长，消化 drift 流 dispose 的 0 时长定时器。
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 20));
  }, timeout: const Timeout(Duration(minutes: 2)),);

  testWidgets('不传 initialTransferToAccountId：转出/转入均空置',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      wrapRecordSheet(<Account>[
        fakeAccount(
          id: 'a1',
          name: '中国农业银行',
          type: AccountType.creditCard,
        ),
        fakeAccount(id: 'c1', name: '现金', type: AccountType.cash),
      ]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    // 无预填：两卡均显示占位文案，不出现任何账户名。
    expect(find.text('转出账户'), findsOneWidget);
    expect(find.text('转入账户'), findsOneWidget);
    expect(find.text('中国农业银行'), findsNothing);
    expect(find.text('现金'), findsNothing);

    // 收尾：卸载页面 + 推进微小时长，消化 drift 流 dispose 的 0 时长定时器。
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 20));
  }, timeout: const Timeout(Duration(minutes: 2)),);

  testWidgets('还款页点「还款」→ 打开记一笔转账 Tab 且转入账户预填为当前负债账户',
      (WidgetTester tester) async {
    final List<Account> accounts = <Account>[
      fakeAccount(
        id: 'a1',
        name: '中国农业银行',
        type: AccountType.creditCard,
        balanceMinor: 21200,
        creditLimitMinor: 70000,
        billingDay: 1,
        dueDay: 10,
        sortOrder: 1,
      ),
      fakeAccount(id: 'c1', name: '现金', type: AccountType.cash),
    ];

    // 迷你路由：复刻 app_router 对 Routes.record 的 extra 解析口径
    // （RecordSheetLaunchArgs → RecordSheet 各入参）。
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          // 固定「今天」避免日期逻辑随真实时间漂移（本用例不断言日期）。
          builder: (BuildContext context, GoRouterState state) =>
              CreditCardRepayPage(now: DateTime(2026, 10, 23)),
        ),
        GoRoute(
          path: '/record',
          builder: (BuildContext context, GoRouterState state) {
            final Object? extra = state.extra;
            if (extra is RecordSheetLaunchArgs) {
              return RecordSheet(
                initialTab: extra.initialTab,
                initialTransferToAccountId: extra.initialTransferToAccountId,
              );
            }
            return const RecordSheet();
          },
        ),
      ],
    );

    // 拉高视口，避免 ListView 懒构建导致还款按钮尚未实例化。
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          accountsProvider.overrideWith(
            (Ref ref) => Stream<List<Account>>.value(accounts),
          ),
        ],
        child: MaterialApp.router(
          theme: AppThemeData.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('信用卡还款'), findsOneWidget);

    // 点第一张负债卡的「还款」。
    await tester.tap(find.widgetWithText(FilledButton, '还款').first);
    // 路由推入动画 + 记一笔首帧 + 账户流回包：定时长 pump（不用 pumpAndSettle）。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    // 进入统一「记一笔」转账 Tab：转入账户已预填为该负债账户。
    expect(find.text('账户互转'), findsOneWidget);
    expect(find.text('中国农业银行'), findsOneWidget);
    expect(find.text('转入账户'), findsNothing);
    // 转出账户仍空置。
    expect(find.text('转出账户'), findsOneWidget);
    expect(find.text('现金'), findsNothing);

    // 收尾：卸载页面 + 推进微小时长，消化 drift 流 dispose 的 0 时长定时器。
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 20));
  }, timeout: const Timeout(Duration(minutes: 2)),);
}
