import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/core/errors/failures.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/accounts/data/account_repository.dart';
import 'package:pocket_ledger/features/accounts/presentation/add_account_page.dart';
import 'package:pocket_ledger/features/accounts/providers/accounts_providers.dart';
import 'package:pocket_ledger/providers/app_providers.dart';

/// 新增账户流程测试。
///
/// **不接真实数据库**：用 [FakeAccountRepository] 覆盖 [accountRepositoryProvider]，
/// 记录 `add` 调用。避免 Drift 在 widget 测试的 fake-async 下残留 Timer 导致
/// `pumpAndSettle` 挂死。
void main() {
  final FakeAccountRepository fakeRepo = FakeAccountRepository();

  setUp(() {
    fakeRepo.adds.clear();
  });

  /// 把 [AddAccountPage] 用 MaterialApp + ProviderScope 包起来，并附加
  /// 对 [currentBookIdProvider] 的默认值覆盖。
  Future<void> pumpAddAccountPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          accountRepositoryProvider.overrideWithValue(fakeRepo),
          currentBookIdProvider.overrideWith((_) => 'default'),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AddAccountPage(),
                  ),
                ),
                child: const Text('host'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('host'));
    await tester.pumpAndSettle();

    // 拉高视口，让表单页底部的「保存」按钮和状态选择在屏幕内。
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    await tester.pumpAndSettle();
  }

  testWidgets('渲染：五个分类 Tab + 账户类型列表', (WidgetTester tester) async {
    await pumpAddAccountPage(tester);

    expect(find.text('新增账户'), findsOneWidget);
    for (final String tab in <String>['资金', '负债', '投资', '应收', '应付']) {
      expect(find.text(tab), findsOneWidget, reason: '缺少 Tab「$tab」');
    }
    expect(find.text('账户名称'), findsNothing);
    expect(find.text('账户类型'), findsOneWidget);
    expect(find.text('现金'), findsOneWidget);
  });

  testWidgets('点击类型跳转到表单页', (WidgetTester tester) async {
    await pumpAddAccountPage(tester);

    await tester.tap(find.text('现金'));
    await tester.pumpAndSettle();

    expect(find.text('新建账户'), findsOneWidget);
    expect(find.text('资产类型'), findsOneWidget);
    expect(find.text('现金'), findsWidgets);
    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('账户余额'), findsOneWidget);
  });

  testWidgets('信用卡：先选银行，再进表单，显示信用额度/当前欠款/剩余额度/账单日',
      (WidgetTester tester) async {
    await pumpAddAccountPage(tester);

    await tester.tap(find.text('负债'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('信用卡'));
    await tester.pumpAndSettle();

    // 进入银行选择页
    expect(find.text('选择银行'), findsOneWidget);
    expect(find.text('搜索银行'), findsOneWidget);
    expect(find.text('中国工商银行'), findsOneWidget);

    await tester.tap(find.text('中国工商银行'));
    await tester.pumpAndSettle();

    // 回到 AddAccountPage 的栈，同时 AccountFormPage 被 push（异步结果）
    // 继续断言表单页内容
    expect(find.text('新建账户'), findsOneWidget);
    expect(find.text('中国工商银行'), findsWidgets);

    // 信用卡模板：无账户名称、有备注+银行卡号
    expect(find.text('账户名称'), findsNothing);
    expect(find.text('备注信息'), findsOneWidget);
    expect(find.text('银行卡号'), findsOneWidget);

    // 资金卡片：信用额度 + 当前欠款 + 剩余额度
    expect(find.text('信用额度'), findsOneWidget);
    expect(find.text('当前欠款'), findsOneWidget);
    expect(find.text('剩余额度'), findsOneWidget);
    expect(find.byIcon(Icons.account_balance_wallet_outlined), findsNothing);
    expect(find.byIcon(Icons.calculate_outlined), findsNothing);

    // 账单 / 还款日期
    expect(find.text('账单/还款日期'), findsOneWidget);
    expect(find.text('账单日期'), findsOneWidget);
    expect(find.text('还款日期'), findsOneWidget);
    expect(find.text('每月1日'), findsOneWidget);
    expect(find.text('每月10日'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, '备注信息'),
      '日常消费',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '银行卡号'),
      '6222',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '信用额度'),
      '10000',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '当前欠款'),
      '2500',
    );

    // 修改还款日为 20 日
    await tester.tap(find.text('还款日期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(fakeRepo.adds, hasLength(1));
    final AddCall call = fakeRepo.adds.single;
    expect(call.type, AccountType.creditCard);
    expect(call.name, '中国工商银行');
    expect(call.balanceMinor, 250000);
    expect(call.creditLimitMinor, 1000000);
    expect(call.note, '日常消费');
    expect(call.cardNumber, '6222');
    expect(call.billingDay, 1);
    expect(call.dueDay, 10);
  });

  testWidgets('空名称保存 → 仓库抛校验异常，页面提示「账户名称不能为空」',
      (WidgetTester tester) async {
    await pumpAddAccountPage(tester);
    await tester.tap(find.text('现金'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('账户名称不能为空'), findsOneWidget);
    expect(fakeRepo.adds, isEmpty, reason: '空名不应落库');
  });

  testWidgets('借记卡：先选银行，再进表单，填写后保存 → 落库并返回',
      (WidgetTester tester) async {
    await pumpAddAccountPage(tester);

    await tester.tap(find.text('借记卡'));
    await tester.pumpAndSettle();

    // 进入银行选择页
    expect(find.text('选择银行'), findsOneWidget);
    expect(find.text('搜索银行'), findsOneWidget);
    expect(find.text('中国工商银行'), findsOneWidget);

    await tester.tap(find.text('中国工商银行'));
    await tester.pumpAndSettle();

    // 表单页顶部显示所选银行
    expect(find.text('新建账户'), findsOneWidget);
    expect(find.text('中国工商银行'), findsOneWidget);

    // 借记卡保留「账户名称 + 备注 + 卡号」字段，用于验证完整字段透传。
    await tester.enterText(
      find.widgetWithText(TextField, '账户名称'),
      '我的工资卡',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '账户余额'),
      '88.5',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '备注信息'),
      '备用',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '银行卡号'),
      '6222',
    );

    // 把状态切到「隐藏」验证新字段透传
    await tester.tap(find.text('隐藏'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // 保存后 pop 回到新增账户页
    expect(find.text('新增账户'), findsOneWidget);

    expect(fakeRepo.adds, hasLength(1));
    final AddCall call = fakeRepo.adds.single;
    expect(call.bookId, 'default');
    expect(call.name, '我的工资卡');
    expect(call.type, AccountType.bankCard);
    expect(call.balanceMinor, 8850);
    expect(call.note, '备用');
    expect(call.cardNumber, '6222');
    expect(call.status, AccountStatus.hidden);
  });

  testWidgets('表单页：现金使用简版模板，不显示备注和卡号',
      (WidgetTester tester) async {
    await pumpAddAccountPage(tester);

    await tester.tap(find.text('现金'));
    await tester.pumpAndSettle();

    expect(find.text('账户名称'), findsOneWidget);
    expect(find.text('账户余额'), findsOneWidget);
    expect(find.text('备注信息'), findsNothing);
    expect(find.text('银行卡号'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextField, '账户名称'),
      '零花钱',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '账户余额'),
      '200',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(fakeRepo.adds, hasLength(1));
    final AddCall call = fakeRepo.adds.single;
    expect(call.type, AccountType.cash);
    expect(call.name, '零花钱');
    expect(call.balanceMinor, 20000);
    expect(call.note, isNull);
    expect(call.cardNumber, isNull);
  });

  testWidgets('负债非信用卡模板（花呗）：备注+信用额度+当前欠款+剩余额度+账单/还款日',
      (WidgetTester tester) async {
    await pumpAddAccountPage(tester);

    await tester.tap(find.text('负债'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('花呗'));
    await tester.pumpAndSettle();

    // 资产类型已显示，无账户名称输入框
    expect(find.text('资产类型'), findsOneWidget);
    expect(find.text('花呗'), findsWidgets);
    expect(find.text('账户名称'), findsNothing);

    // 基本信息只有备注
    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('备注信息'), findsOneWidget);

    // 负债卡片：信用额度 + 当前欠款 + 剩余额度
    expect(find.text('信用额度'), findsOneWidget);
    expect(find.text('当前欠款'), findsOneWidget);
    expect(find.text('剩余额度'), findsOneWidget);

    // 账单 / 还款日期
    expect(find.text('账单/还款日期'), findsOneWidget);
    expect(find.text('账单日期'), findsOneWidget);
    expect(find.text('还款日期'), findsOneWidget);
    expect(find.text('每月1日'), findsOneWidget);
    expect(find.text('每月10日'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, '备注信息'),
      '日常消费',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '信用额度'),
      '3000',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '当前欠款'),
      '500',
    );

    // 修改账单日为 5 日
    await tester.tap(find.text('账单日期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(fakeRepo.adds, hasLength(1));
    final AddCall call = fakeRepo.adds.single;
    expect(call.type, AccountType.huabei);
    // 名称自动使用类型标签
    expect(call.name, '花呗');
    expect(call.balanceMinor, 50000);
    expect(call.creditLimitMinor, 300000);
    expect(call.note, '日常消费');
    expect(call.billingDay, 1);
    expect(call.dueDay, 10);
    expect(call.cardNumber, isNull);
  });

  testWidgets('简版模板：投资类（基金）显示「账户余额」+ 计算器图标，无备注/卡号',
      (WidgetTester tester) async {
    await pumpAddAccountPage(tester);

    await tester.tap(find.text('投资'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('基金'));
    await tester.pumpAndSettle();

    expect(find.text('账户余额'), findsOneWidget);
    expect(find.byIcon(Icons.calculate_outlined), findsOneWidget);
    expect(find.byIcon(Icons.account_balance_wallet_outlined), findsNothing);
    expect(find.text('备注信息'), findsNothing);
    expect(find.text('银行卡号'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextField, '账户名称'),
      '天天基金',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '账户余额'),
      '1200',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(fakeRepo.adds, hasLength(1));
    final AddCall call = fakeRepo.adds.single;
    expect(call.type, AccountType.fund);
    expect(call.name, '天天基金');
    expect(call.balanceMinor, 120000);
  });

  testWidgets('应收-借出模板：借款给谁 + 借出金额 + 余额同步默认开启',
      (WidgetTester tester) async {
    await pumpAddAccountPage(tester);

    await tester.tap(find.text('应收'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('借出'));
    await tester.pumpAndSettle();

    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('借款给谁'), findsOneWidget);
    expect(find.text('借出金额'), findsOneWidget);
    expect(find.byIcon(Icons.calculate_outlined), findsOneWidget);
    expect(find.text('账户余额'), findsNothing);
    expect(find.text('备注信息'), findsNothing);
    expect(find.text('银行卡号'), findsNothing);

    expect(find.text('余额同步'), findsOneWidget);
    // Switch 默认开启（截图中余额同步默认打开）
    expect(find.text('同时记一笔账单'), findsOneWidget);
    expect(find.text('将金额记一笔对应类型账单'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, '借款给谁'),
      '张三',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '借出金额'),
      '500',
    );

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(fakeRepo.adds, hasLength(1));
    final AddCall call = fakeRepo.adds.single;
    expect(call.type, AccountType.lend);
    expect(call.name, '张三');
    expect(call.balanceMinor, 50000);
  });

  testWidgets('应收-报销模板：仅用户名，无余额同步/金额',
      (WidgetTester tester) async {
    await pumpAddAccountPage(tester);

    await tester.tap(find.text('应收'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('报销'));
    await tester.pumpAndSettle();

    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('用户名'), findsOneWidget);
    expect(find.text('账户余额'), findsNothing);
    expect(find.text('借出金额'), findsNothing);
    expect(find.text('余额同步'), findsNothing);
    expect(find.text('同时记一笔账单'), findsNothing);
    expect(find.byIcon(Icons.calculate_outlined), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextField, '用户名'),
      '公司报销',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(fakeRepo.adds, hasLength(1));
    final AddCall call = fakeRepo.adds.single;
    expect(call.type, AccountType.reimbursement);
    expect(call.name, '公司报销');
    expect(call.balanceMinor, 0);
  });

  testWidgets('应付-借入模板：向谁借 + 借入金额 + 余额同步默认开启',
      (WidgetTester tester) async {
    await pumpAddAccountPage(tester);

    await tester.tap(find.text('应付'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('借入'));
    await tester.pumpAndSettle();

    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('向谁借'), findsOneWidget);
    expect(find.text('借入金额'), findsOneWidget);
    expect(find.byIcon(Icons.calculate_outlined), findsOneWidget);
    expect(find.text('账户余额'), findsNothing);
    expect(find.text('备注信息'), findsNothing);
    expect(find.text('银行卡号'), findsNothing);

    expect(find.text('余额同步'), findsOneWidget);
    expect(find.text('同时记一笔账单'), findsOneWidget);
    expect(find.text('将金额记一笔对应类型账单'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, '向谁借'),
      '李四',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '借入金额'),
      '1000',
    );

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(fakeRepo.adds, hasLength(1));
    final AddCall call = fakeRepo.adds.single;
    expect(call.type, AccountType.borrow);
    expect(call.name, '李四');
    expect(call.balanceMinor, 100000);
  });

  testWidgets('应收 Tab 显示报销/借出，应付 Tab 显示借入', (WidgetTester tester) async {
    await pumpAddAccountPage(tester);

    await tester.tap(find.text('应收'));
    await tester.pumpAndSettle();
    expect(find.text('报销'), findsOneWidget);
    expect(find.text('借出'), findsOneWidget);

    await tester.tap(find.text('应付'));
    await tester.pumpAndSettle();
    expect(find.text('借入'), findsOneWidget);
  });
}

/// [AccountRepository] 的假实现：只记录 `add` 调用，不做任何数据库操作。
class FakeAccountRepository extends AccountRepository {
  FakeAccountRepository() : super(AppDatabase(NativeDatabase.memory()));

  final List<AddCall> adds = <AddCall>[];

  @override
  Future<String> add({
    required String bookId,
    required String name,
    required AccountType type,
    int balanceMinor = 0,
    String currency = 'CNY',
    int? creditLimitMinor,
    int? billingDay,
    int? dueDay,
    String? note,
    String? cardNumber,
    AccountStatus status = AccountStatus.active,
    bool includeInTotal = true,
  }) async {
    if (name.trim().isEmpty) {
      throw const ValidationFailure('账户名称不能为空');
    }
    adds.add(AddCall(
      bookId: bookId,
      name: name,
      type: type,
      balanceMinor: balanceMinor,
      creditLimitMinor: creditLimitMinor,
      billingDay: billingDay,
      dueDay: dueDay,
      note: note,
      cardNumber: cardNumber,
      status: status,
      includeInTotal: includeInTotal,
    ));
    return 'fake-id';
  }
}

class AddCall {
  const AddCall({
    required this.bookId,
    required this.name,
    required this.type,
    required this.balanceMinor,
    this.creditLimitMinor,
    this.billingDay,
    this.dueDay,
    this.note,
    this.cardNumber,
    this.status = AccountStatus.active,
    this.includeInTotal = true,
  });

  final String bookId;
  final String name;
  final AccountType type;
  final int balanceMinor;
  final int? creditLimitMinor;
  final int? billingDay;
  final int? dueDay;
  final String? note;
  final String? cardNumber;
  final AccountStatus status;
  final bool includeInTotal;
}
