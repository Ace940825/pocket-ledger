import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/core/bootstrap.dart';
import 'package:pocket_ledger/core/theme/forest_design_tokens.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/accounts/providers/accounts_providers.dart';
import 'package:pocket_ledger/features/investment/providers/investment_providers.dart';
import 'package:pocket_ledger/features/record/presentation/account_picker_sheet.dart';
import 'package:pocket_ledger/features/record/providers/recording_settings_provider.dart';
import 'package:pocket_ledger/providers/app_providers.dart';
import 'package:pocket_ledger/theme/app_colors.dart';
import 'package:pocket_ledger/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 账户选择弹层的余额语义色测试。
///
/// 背景（真机反馈）：弹层里信用卡的欠款与股票的持仓市值同色（都是收入绿），
/// 完全看不出负债。根因是金额色按存储层原始正负判定（正 = 绿），而负债方向
/// 账户**正余额 = 欠款**（见 [AccountType.isLiabilitySide]）。修复后按「对
/// 净资产的方向」判定：欠款 → 支出红，与资产页 / 账户详情页口径一致。
///
/// 工程约定（踩坑）：bootstrapData 内含 drift 事务，在 testWidgets 的假异步区
/// 里永不完成——DB 初始化一律放 setUp/tearDown（真实异步）；弹层有 AnimatedSize
/// 等常驻动画，pumpAndSettle 不收敛，用 pump + 定时长 pump；收尾必须
/// pumpWidget(SizedBox) + pump(20ms) 消化 drift 流 dispose 的 0 时长定时器。
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
      dueDay: dueDay,
    );
  }

  /// 弹层挂载环境：setUp 里已 bootstrap 的真内存库 +
  /// accountsProvider 以固定流覆盖（含信用卡/股票/借入/现金四类）。
  ///
  /// [balanceWithMarket] / [marketValues] 透传给弹层与市值 provider，
  /// 用于验证证券账户「现金 + 市值」与「仅现金」两种余额口径。
  Widget wrapPicker(
    List<Account> accounts, {
    String? selectedId,
    bool listView = false,
    bool balanceWithMarket = true,
    Map<String, int> marketValues = const <String, int>{},
  }) {
    return ProviderScope(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        accountsProvider
            .overrideWith((Ref ref) => Stream<List<Account>>.value(accounts)),
        investmentMarketValueByAccountProvider
            .overrideWithValue(marketValues),
        if (listView)
          recordingSettingsProvider.overrideWith(
            (Ref ref) =>
                RecordingSettingsNotifier()..setAccountPickerListView(true),
          ),
      ],
      child: MaterialApp(
        // 必须带主题：页面大量使用 context.app / context.colors 主题扩展，
        // 裸 MaterialApp 缺 ForestSage 令牌会抛 null check operator。
        theme: AppThemeData.light,
        home: Scaffold(
          body: AccountPickerSheet(
            filter: null,
            selectedId: selectedId,
            showNoneRow: false,
            balanceWithMarket: balanceWithMarket,
            onConfirm: (Account? _) {},
          ),
        ),
      ),
    );
  }

  /// 取某个金额文本的颜色（弹层里每类金额文本唯一）。
  Color colorOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color ?? Colors.transparent;

  /// 挂载 + 推进动画（不用 pumpAndSettle：弹层有常驻动画不收敛）。
  Future<void> pumpPicker(
    WidgetTester tester,
    Widget widget,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  }

  List<Account> sampleAccounts() => <Account>[
        fakeAccount(
          id: 'a1',
          name: '安阳银行',
          type: AccountType.creditCard,
          balanceMinor: 1000, // 欠款 ¥10.00（正余额 = 欠款）
          creditLimitMinor: 200000, // 可用 = 2000 - 10 = ¥1,990.00
          dueDay: 26,
          sortOrder: 1,
        ),
        fakeAccount(
          id: 'a2',
          name: '华泰',
          type: AccountType.stock,
          balanceMinor: 18184000, // ¥181,840.00（资产）
          sortOrder: 2,
        ),
        fakeAccount(
          id: 'a3',
          name: '老王借款',
          type: AccountType.borrow,
          balanceMinor: 50000, // 借入 ¥500.00（负债方向）
          sortOrder: 3,
        ),
        fakeAccount(id: 'c1', name: '现金', type: AccountType.cash),
      ];

  testWidgets('网格模式：负债欠款=支出红、资产结余=收入绿、零值=中性',
      (WidgetTester tester) async {
    await pumpPicker(tester, wrapPicker(sampleAccounts()));

    // 信用卡欠款与借入欠款：支出红（修复前是收入绿，与资产同色）。
    expect(colorOf(tester, '¥10.00'), ForestSemantic.expense);
    expect(colorOf(tester, '¥500.00'), ForestSemantic.expense);
    // 股票持仓市值：收入绿（资产，保持原色）。
    expect(colorOf(tester, '¥181,840.00'), ForestSemantic.income);
    // 零值余额：中性文字色（不参与语义色）。
    final Color onSurface =
        Theme.of(tester.element(find.text('¥0.00'))).colorScheme.onSurface;
    expect(colorOf(tester, '¥0.00'), onSurface);

    // 收尾：卸载页面 + 推进微小时长，消化 drift 流 dispose 的 0 时长定时器。
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 20));
  }, timeout: const Timeout(Duration(minutes: 2)),);

  testWidgets('选中态：选中负债卡用加深红，选中资产卡用加深绿',
      (WidgetTester tester) async {
    // 选中信用卡（欠款）：选中态加深变体 pickerRed。
    await pumpPicker(
      tester,
      wrapPicker(sampleAccounts(), selectedId: 'a1'),
    );
    expect(colorOf(tester, '¥10.00'), AppPalette.pickerRed);
    expect(colorOf(tester, '¥181,840.00'), ForestSemantic.income);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 20));

    // 选中股票（资产）：选中态加深变体 pickerGreen。
    await pumpPicker(
      tester,
      wrapPicker(sampleAccounts(), selectedId: 'a2'),
    );
    expect(colorOf(tester, '¥181,840.00'), AppPalette.pickerGreen);
    // 未选中的信用卡欠款仍为支出红。
    expect(colorOf(tester, '¥10.00'), ForestSemantic.expense);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 20));
  }, timeout: const Timeout(Duration(minutes: 2)),);

  /// 华泰股票账户：现金 ¥99,999.00 + 持仓市值 ¥81,840.00 = 总 ¥181,839.00
  /// （复现真机反馈：互转页卡显示 ¥99,999.00、弹层显示 ¥181,839.00 对不上）。
  Account stockAccount() => fakeAccount(
        id: 'a2',
        name: '华泰',
        type: AccountType.stock,
        balanceMinor: 9999900,
        sortOrder: 2,
      );

  const Map<String, int> stockMarket =
      <String, int>{'a2': 8184000}; // 持仓市值 ¥81,840.00

  testWidgets('现金口径（转账/报销）：股票账户只展示现金余额',
      (WidgetTester tester) async {
    await pumpPicker(
      tester,
      wrapPicker(
        <Account>[stockAccount()],
        balanceWithMarket: false,
        marketValues: stockMarket,
      ),
    );

    // 只显示现金 ¥99,999.00（与转账纽带卡 / 报销账户行的 balanceMinor 一致），
    // 不出现「现金 + 市值」的 ¥181,839.00。
    expect(find.text('¥99,999.00'), findsOneWidget);
    expect(find.text('¥181,839.00'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 20));
  }, timeout: const Timeout(Duration(minutes: 2)),);

  testWidgets('默认口径（其余调用方）：股票账户展示现金 + 市值',
      (WidgetTester tester) async {
    await pumpPicker(
      tester,
      wrapPicker(
        <Account>[stockAccount()],
        marketValues: stockMarket,
      ),
    );

    // 默认维持资产页口径：现金 + 市值 = ¥181,839.00。
    expect(find.text('¥181,839.00'), findsOneWidget);
    expect(find.text('¥99,999.00'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 20));
  }, timeout: const Timeout(Duration(minutes: 2)),);

  testWidgets('列表模式同样遵循现金口径', (WidgetTester tester) async {
    await pumpPicker(
      tester,
      wrapPicker(
        <Account>[stockAccount()],
        listView: true,
        balanceWithMarket: false,
        marketValues: stockMarket,
      ),
    );

    expect(find.text('¥99,999.00'), findsOneWidget);
    expect(find.text('¥181,839.00'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 20));
  }, timeout: const Timeout(Duration(minutes: 2)),);

  testWidgets('列表模式：与网格同一语义色口径', (WidgetTester tester) async {
    await pumpPicker(tester, wrapPicker(sampleAccounts(), listView: true));

    expect(colorOf(tester, '¥10.00'), ForestSemantic.expense);
    expect(colorOf(tester, '¥500.00'), ForestSemantic.expense);
    expect(colorOf(tester, '¥181,840.00'), ForestSemantic.income);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 20));
  }, timeout: const Timeout(Duration(minutes: 2)),);
}
