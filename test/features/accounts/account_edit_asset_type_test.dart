import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/accounts/data/account_repository.dart';
import 'package:pocket_ledger/features/accounts/presentation/account_edit_page.dart';
import 'package:pocket_ledger/features/accounts/providers/accounts_providers.dart';
import 'package:pocket_ledger/shared/widgets/sheet_scaffold.dart';
import 'package:pocket_ledger/theme/app_theme.dart';

/// 编辑账户页「资产类型」两栏布局测试。
///
/// 不接真实数据库：`accountByIdProvider` 用 `Stream.value` 覆盖，
/// `accountRepositoryProvider` 用 [_FakeAccountRepository] 捕获 update 调用
/// （与新增账户页测试同款思路，避免 Drift 在 fake-async 下残留 Timer）。
void main() {
  late _FakeAccountRepository repo;

  setUp(() {
    repo = _FakeAccountRepository();
  });

  Account fakeAccount({
    required String id,
    required String name,
    required AccountType type,
    int balanceMinor = 0,
    int? creditLimitMinor,
    int? billingDay,
    int? dueDay,
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
      creditLimitMinor: creditLimitMinor,
      billingDay: billingDay,
      dueDay: dueDay,
    );
  }

  /// 直接挂编辑页（渲染 / 交互用例用）。
  Future<void> pumpEditPage(WidgetTester tester, Account account) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          accountByIdProvider(account.id).overrideWith(
            (Ref ref) => Stream<Account?>.value(account),
          ),
          accountRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: AppThemeData.light,
          darkTheme: AppThemeData.dark,
          home: AccountEditPage(accountId: account.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 经 GoRouter 宿主推入编辑页（保存用例用：保存后 `context.pop()`
  /// 有路可回，与真实导航一致）。
  Future<void> pumpEditPageViaRouter(
    WidgetTester tester,
    Account account,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          accountByIdProvider(account.id).overrideWith(
            (Ref ref) => Stream<Account?>.value(account),
          ),
          accountRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp.router(
          theme: AppThemeData.light,
          darkTheme: AppThemeData.dark,
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: <RouteBase>[
              GoRoute(
                path: '/',
                builder: (BuildContext context, GoRouterState state) =>
                    Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () =>
                          context.push('/edit/${account.id}'),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
              GoRoute(
                path: '/edit/:id',
                builder: (BuildContext context, GoRouterState state) =>
                    AccountEditPage(
                  accountId: state.pathParameters['id'] ?? '',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// 弹层内的文本（页面同层可能有同名文本，按弹层容器限定范围）。
  Finder inSheet(String text) => find.descendant(
        of: find.byType(AppModalSheet),
        matching: find.text(text),
      );

  testWidgets('借记卡：资产类型两栏（第一栏类型 + 第二栏银行）', (
    WidgetTester tester,
  ) async {
    await pumpEditPage(
      tester,
      fakeAccount(
        id: 'a1',
        name: '安阳银行',
        type: AccountType.bankCard,
        balanceMinor: 21200,
      ),
    );

    expect(find.text('编辑账户'), findsOneWidget);
    expect(find.text('资产类型'), findsOneWidget);
    // 第一栏：账户类型；第二栏：银行名。
    expect(find.text('借记卡'), findsOneWidget);
    expect(find.text('安阳银行'), findsOneWidget);
    // 银行已选定，不显示占位文案。
    expect(find.text('选择银行'), findsNothing);
    // 借记卡布局其余区块照旧。
    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('银行卡号'), findsOneWidget);
    expect(find.text('账户余额'), findsOneWidget);
  });

  testWidgets('现金：仅第一栏，银行列隐藏', (WidgetTester tester) async {
    await pumpEditPage(
      tester,
      fakeAccount(
        id: 'a2',
        name: '现金账户',
        type: AccountType.cash,
        balanceMinor: 5000,
      ),
    );

    // 第一栏显示类型名；无银行列（无占位、无银行名）。
    expect(find.text('现金'), findsOneWidget);
    expect(find.text('选择银行'), findsNothing);
    expect(find.text('借记卡'), findsNothing);
    // 资金布局：用户名 + 账户余额。
    expect(find.text('用户名'), findsOneWidget);
    expect(find.text('现金账户'), findsOneWidget);
  });

  testWidgets('第一栏弹层：五大类 → 二级选「信用卡」后第二栏出现', (
    WidgetTester tester,
  ) async {
    await pumpEditPage(
      tester,
      fakeAccount(
        id: 'a1',
        name: '安阳银行',
        type: AccountType.bankCard,
        balanceMinor: 21200,
      ),
    );

    // 打开第一栏「资产类型」弹层。
    await tester.tap(find.text('借记卡'));
    await tester.pumpAndSettle();
    expect(find.text('资产类型'), findsNWidgets(2)); // 区块标题 + 弹层标题
    // 一级：五大类齐全。
    for (final String category in <String>['资金', '负债', '投资', '应收', '应付']) {
      expect(inSheet(category), findsOneWidget, reason: '缺少大类「$category」');
    }

    // 进入「负债」二级：类型列表 + 返回行。
    await tester.tap(inSheet('负债'));
    await tester.pumpAndSettle();
    expect(inSheet('信用卡'), findsOneWidget);
    expect(inSheet('花呗'), findsOneWidget);
    expect(inSheet('借记卡'), findsNothing); // 一级已收起

    // 选「信用卡」：弹层关闭，第一栏变信用卡；银行类→银行类保留银行名，
    // 第二栏仍显示「安阳银行」。
    await tester.tap(inSheet('信用卡'));
    await tester.pumpAndSettle();
    expect(find.text('信用卡'), findsWidgets);
    expect(find.text('安阳银行'), findsOneWidget);
    // 布局切到负债模板：信用额度 / 当前欠款 / 账单日期。
    expect(find.text('信用额度'), findsOneWidget);
    expect(find.text('当前欠款'), findsOneWidget);
    expect(find.text('账单日期'), findsOneWidget);
  });

  testWidgets('第一栏弹层：二级返回行可回到一级', (WidgetTester tester) async {
    await pumpEditPage(
      tester,
      fakeAccount(id: 'a1', name: '安阳银行', type: AccountType.bankCard),
    );

    await tester.tap(find.text('借记卡'));
    await tester.pumpAndSettle();
    await tester.tap(inSheet('资金'));
    await tester.pumpAndSettle();
    expect(inSheet('微信'), findsOneWidget);

    // 点返回行（二级标题即大类名）回到一级。
    await tester.tap(inSheet('资金'));
    await tester.pumpAndSettle();
    expect(inSheet('负债'), findsOneWidget);
    expect(inSheet('微信'), findsNothing);

    // 取消（点框外）不改类型。
    await tester.tapAt(const Offset(400, 80));
    await tester.pumpAndSettle();
    expect(find.text('借记卡'), findsOneWidget);
    expect(find.text('安阳银行'), findsOneWidget);
  });

  testWidgets('第二栏弹层：选银行后第二栏与名称更新', (WidgetTester tester) async {
    await pumpEditPage(
      tester,
      fakeAccount(id: 'a1', name: '安阳银行', type: AccountType.bankCard),
    );

    // 打开第二栏「银行」弹层。
    await tester.tap(find.text('安阳银行'));
    await tester.pumpAndSettle();
    expect(find.text('选择银行'), findsOneWidget); // 弹层标题
    expect(find.text('搜索银行'), findsOneWidget); // 搜索框
    expect(find.text('自定义'), findsOneWidget);
    // 当前银行在列表中（A 组）。
    expect(find.text('安阳银行'), findsNWidgets(2)); // 第二栏 + 列表行

    // 选 A 组另一家银行（列表顶部，无需滚动）。
    await tester.tap(find.text('澳门商业银行'));
    await tester.pumpAndSettle();
    expect(find.text('澳门商业银行'), findsOneWidget);
    expect(find.text('安阳银行'), findsNothing);
  });

  testWidgets('切到非银行类：银行列隐藏，名称保留可改', (
    WidgetTester tester,
  ) async {
    await pumpEditPage(
      tester,
      fakeAccount(id: 'a1', name: '安阳银行', type: AccountType.bankCard),
    );

    // 第一栏：资金 → 现金。
    await tester.tap(find.text('借记卡'));
    await tester.pumpAndSettle();
    await tester.tap(inSheet('资金'));
    await tester.pumpAndSettle();
    await tester.tap(inSheet('现金'));
    await tester.pumpAndSettle();

    // 银行列隐藏；名称保留（资金布局「用户名」输入框内可改）。
    expect(find.text('选择银行'), findsNothing);
    expect(find.text('借记卡'), findsNothing);
    expect(find.text('现金'), findsOneWidget);
    expect(find.text('安阳银行'), findsWidgets);
    expect(find.text('用户名'), findsOneWidget);
  });

  testWidgets('保存：切换类型 + 改银行后 update 携带新 type 与 name', (
    WidgetTester tester,
  ) async {
    await pumpEditPageViaRouter(
      tester,
      fakeAccount(
        id: 'a1',
        name: '安阳银行',
        type: AccountType.bankCard,
        balanceMinor: 21200,
        creditLimitMinor: 70000,
        billingDay: 1,
        dueDay: 10,
      ),
    );

    // 借记卡 → 信用卡（负债 → 信用卡）。
    await tester.tap(find.text('借记卡'));
    await tester.pumpAndSettle();
    await tester.tap(inSheet('负债'));
    await tester.pumpAndSettle();
    await tester.tap(inSheet('信用卡'));
    await tester.pumpAndSettle();

    // 改银行为「澳门商业银行」（名称即银行名，同步改名）。
    await tester.tap(find.text('安阳银行'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('澳门商业银行'));
    await tester.pumpAndSettle();
    expect(find.text('澳门商业银行'), findsOneWidget);

    // 保存。
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(repo.updates, hasLength(1));
    final _UpdateCall call = repo.updates.single;
    expect(call.id, 'a1');
    expect(call.type, AccountType.creditCard);
    expect(call.name, '澳门商业银行');
  });

  testWidgets('保存：切换到非负债类型时清掉额度与账单日字段', (
    WidgetTester tester,
  ) async {
    await pumpEditPageViaRouter(
      tester,
      fakeAccount(
        id: 'a2',
        name: '花呗',
        type: AccountType.huabei,
        balanceMinor: 4000,
        creditLimitMinor: 70000,
        billingDay: 1,
        dueDay: 10,
      ),
    );

    // 花呗（负债）→ 现金（资金）。
    await tester.tap(find.text('花呗'));
    await tester.pumpAndSettle();
    await tester.tap(inSheet('资金'));
    await tester.pumpAndSettle();
    await tester.tap(inSheet('现金'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(repo.updates, hasLength(1));
    final _UpdateCall call = repo.updates.single;
    expect(call.type, AccountType.cash);
    // 非负债分支：三个负债专属字段显式清空（Value(null)）。
    expect(call.creditLimitMinor.present, isTrue);
    expect(call.creditLimitMinor.value, isNull);
    expect(call.billingDay.present, isTrue);
    expect(call.billingDay.value, isNull);
    expect(call.dueDay.present, isTrue);
    expect(call.dueDay.value, isNull);
  });
  testWidgets('保存：负债账户备注非空时以备注为账户名', (
    WidgetTester tester,
  ) async {
    await pumpEditPageViaRouter(
      tester,
      fakeAccount(
        id: 'a1',
        name: '信用卡',
        type: AccountType.creditCard,
        balanceMinor: 4000,
        creditLimitMinor: 70000,
      ),
    );

    // 负债布局基本信息只有「备注信息 / 银行卡号」，无账户名称输入框。
    expect(find.text('备注信息'), findsOneWidget);
    // 备注是第一个 TextField（银行卡号在其后）。
    await tester.enterText(find.byType(TextField).first, '招行车主卡');
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(repo.updates, hasLength(1));
    final _UpdateCall call = repo.updates.single;
    // 备注非空 → 充当账户名；备注字段本身照常保存（数据不丢）。
    expect(call.name, '招行车主卡');
    expect(call.note, '招行车主卡');
  });

  testWidgets('保存：负债账户备注为空时保留原账户名', (
    WidgetTester tester,
  ) async {
    await pumpEditPageViaRouter(
      tester,
      fakeAccount(
        id: 'a2',
        name: '花呗',
        type: AccountType.huabei,
        balanceMinor: 4000,
      ),
    );

    // 备注留空直接保存：账户名保持原值。
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(repo.updates, hasLength(1));
    expect(repo.updates.single.name, '花呗');
  });
}

/// 捕获 update 调用的假仓储（不落库）。
class _FakeAccountRepository extends AccountRepository {
  _FakeAccountRepository() : super(AppDatabase(NativeDatabase.memory()));

  final List<_UpdateCall> updates = <_UpdateCall>[];

  @override
  Future<void> update({
    required String id,
    required String name,
    required AccountType type,
    required int balanceMinor,
    String? currency,
    Value<int?> creditLimitMinor = const Value.absent(),
    Value<int?> billingDay = const Value.absent(),
    Value<int?> dueDay = const Value.absent(),
    Value<int?> dueGraceDays = const Value.absent(),
    String? note,
    String? cardNumber,
    AccountStatus? status,
    bool? includeInTotal,
  }) async {
    updates.add(_UpdateCall(
      id: id,
      name: name,
      type: type,
      balanceMinor: balanceMinor,
      creditLimitMinor: creditLimitMinor,
      billingDay: billingDay,
      dueDay: dueDay,
      dueGraceDays: dueGraceDays,
      note: note,
      cardNumber: cardNumber,
      status: status,
      includeInTotal: includeInTotal,
    ),);
  }
}

class _UpdateCall {
  const _UpdateCall({
    required this.id,
    required this.name,
    required this.type,
    required this.balanceMinor,
    required this.creditLimitMinor,
    required this.billingDay,
    required this.dueDay,
    required this.dueGraceDays,
    this.note,
    this.cardNumber,
    this.status,
    this.includeInTotal,
  });

  final String id;
  final String name;
  final AccountType type;
  final int balanceMinor;
  final Value<int?> creditLimitMinor;
  final Value<int?> billingDay;
  final Value<int?> dueDay;
  final Value<int?> dueGraceDays;
  final String? note;
  final String? cardNumber;
  final AccountStatus? status;
  final bool? includeInTotal;
}
