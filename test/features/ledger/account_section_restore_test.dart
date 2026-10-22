import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pocket_ledger/core/bootstrap.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/accounts/data/account_repository.dart';
import 'package:pocket_ledger/features/ledger/data/account_io.dart';
import 'package:pocket_ledger/features/ledger/data/bill_io.dart';
import 'package:pocket_ledger/features/ledger/data/bill_template.dart';

/// 账户段（导入模板 v3）测试：**导出 → 新系统导入后账户信息全部复原**。
///
/// 三层：
/// ① 往返：buildCsv / buildJson 带账户段 → parseInput 解析，逐字段相等
///    （名称 / 类型 / 币种 / 余额 / 图标 / 颜色 / 额度 / 账单日 / 还款日 /
///    备注 / 卡号 / 状态 / 计入总资产 / 排序）；
/// ② 复原：AccountRepository.restoreAccount / setRestoredBalance 在真库上的
///    建户、合并不动、覆盖、余额收尾校正；
/// ③ 兼容：旧单段（v2）文件照常按账单解析、无账户段。
void main() {
  final AccountRow rich = AccountRow(
    name: '招商信用卡',
    type: AccountType.creditCard,
    book: '日常账本',
    currency: 'CNY',
    balanceMinor: -230000,
    iconKey: 'card',
    colorValue: 0xFF88CC66,
    creditLimitMinor: 2000000,
    billingDay: 5,
    dueDay: 23,
    note: '主力卡',
    cardNumber: '5678',
    status: AccountStatus.hidden,
    includeInTotal: false,
    sortOrder: 7,
  );

  void expectSame(AccountRow a, AccountRow b) {
    expect(a.name, b.name);
    expect(a.type, b.type);
    expect(a.book, b.book);
    expect(a.currency, b.currency);
    expect(a.balanceMinor, b.balanceMinor);
    expect(a.iconKey, b.iconKey);
    expect(a.colorValue, b.colorValue);
    expect(a.creditLimitMinor, b.creditLimitMinor);
    expect(a.billingDay, b.billingDay);
    expect(a.dueDay, b.dueDay);
    expect(a.note, b.note);
    expect(a.cardNumber, b.cardNumber);
    expect(a.status, b.status);
    expect(a.includeInTotal, b.includeInTotal);
    expect(a.sortOrder, b.sortOrder);
  }

  group('导出 → 解析 往返', () {
    test('CSV 双段往返：账户字段逐项相等', () {
      final String csv = buildCsv(
        <BillRow>[
          BillRow(
            occurredAt: DateTime(2026, 10, 18, 12, 30),
            type: TxnType.expense,
            amountMinor: 2550,
            accountName: '微信',
          ),
        ],
        accounts: <AccountRow>[rich],
      );
      expect(csv, contains(kAccountSectionMarker));
      expect(csv, contains(kBillSectionMarker));

      final ParseResult r = parseInput(csv);
      expect(r.errors, isEmpty);
      expect(r.rows, hasLength(1));
      expect(r.accounts, hasLength(1));
      expectSame(r.accounts.single, rich);
    });

    test('JSON accounts 键往返：账户字段逐项相等', () {
      final String json = buildJson(
        <BillRow>[
          BillRow(
            occurredAt: DateTime(2026, 10, 18, 12, 30),
            type: TxnType.expense,
            amountMinor: 2550,
            accountName: '微信',
          ),
        ],
        accounts: <AccountRow>[rich],
      );
      final ParseResult r = parseInput(json);
      expect(r.errors, isEmpty);
      expect(r.accounts, hasLength(1));
      expectSame(r.accounts.single, rich);
    });

    test('无账户段时保持旧单段格式，解析无账户', () {
      final String csv = buildCsv(<BillRow>[
        BillRow(
          occurredAt: DateTime(2026, 10, 18),
          type: TxnType.income,
          amountMinor: 100,
          accountName: '微信',
        ),
      ]);
      expect(csv, isNot(contains(kAccountSectionMarker)));
      final ParseResult r = parseInput(csv);
      expect(r.accounts, isEmpty);
      expect(r.rows, hasLength(1));
    });

    test('模板 CSV 双段表头可解析（0 行、0 错误）', () {
      final ParseResult r = parseInput(buildTemplateCsv());
      expect(r.errors, isEmpty);
      expect(r.rows, isEmpty);
      expect(r.accounts, isEmpty);
    });

    test('示例账户段 sampleAccountRows 可解析且字段正确', () {
      final List<AccountRow> accounts = sampleAccountRows();
      expect(accounts, hasLength(4));
      expect(accounts[0].type, AccountType.wechat);
      expect(accounts[0].balanceMinor, 12550);
      expect(accounts[2].type, AccountType.creditCard);
      expect(accounts[2].creditLimitMinor, 2000000);
      expect(accounts[2].billingDay, 5);
      expect(accounts[2].dueDay, 23);
      expect(accounts[3].status, AccountStatus.hidden);
      expect(accounts[3].includeInTotal, false);
      expect(accounts[3].colorValue, 0xFF88CC66);
    });

    test('类型中文名可解析（微信 → wechat）；状态 0/1/2 可解析', () {
      expect(parseAccountType('微信'), AccountType.wechat);
      expect(parseAccountType('wechat'), AccountType.wechat);
      expect(parseAccountType('胡说'), isNull);
      expect(parseAccountStatus('2'), AccountStatus.sealed);
      expect(parseAccountStatus('封存'), AccountStatus.sealed);
      expect(parseAccountStatus(''), AccountStatus.active);
      expect(parseAccountColor('#88CC66'), 0xFF88CC66);
      expect(parseAccountColor('0xFF88CC66'), 0xFF88CC66);
    });
  });

  group('新系统复原（真库）', () {
    late Directory tmp;
    late AppDatabase db;
    late AccountRepository repo;

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('pl_account_restore_test');
      db = AppDatabase(NativeDatabase(File(p.join(tmp.path, 'ledger.db'))));
      await bootstrapData(db);
      repo = AccountRepository(db);
    });

    tearDown(() async {
      await db.close();
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('建户：全量字段落库', () async {
      final String id = await repo.restoreAccount(
        bookId: 'default',
        name: rich.name,
        type: rich.type,
        balanceMinor: rich.balanceMinor,
        currency: rich.currency,
        iconKey: rich.iconKey,
        colorValue: rich.colorValue,
        creditLimitMinor: rich.creditLimitMinor,
        billingDay: rich.billingDay,
        dueDay: rich.dueDay,
        note: rich.note,
        cardNumber: rich.cardNumber,
        status: rich.status,
        includeInTotal: rich.includeInTotal,
        sortOrder: rich.sortOrder,
      );
      final Account? a = await db.accountsDao.getById(id);
      expect(a, isNotNull);
      expect(a!.name, '招商信用卡');
      expect(a.type, AccountType.creditCard);
      expect(a.currency, 'CNY');
      expect(a.balanceMinor, -230000);
      expect(a.iconKey, 'card');
      expect(a.colorValue, 0xFF88CC66);
      expect(a.creditLimitMinor, 2000000);
      expect(a.billingDay, 5);
      expect(a.dueDay, 23);
      expect(a.note, '主力卡');
      expect(a.cardNumber, '5678');
      expect(a.status, AccountStatus.hidden);
      expect(a.includeInTotal, false);
      expect(a.sortOrder, 7);
      // 隐藏账户与 isArchived 同步
      expect(a.isArchived, true);
    });

    test('合并语义：已存在且不覆盖 → 字段与余额都不动', () async {
      final String id = await repo.add(
        bookId: 'default',
        name: '微信',
        type: AccountType.wechat,
        balanceMinor: 999,
        note: '原备注',
      );
      final String again = await repo.restoreAccount(
        bookId: 'default',
        name: '微信',
        type: AccountType.wechat,
        balanceMinor: 12550,
        note: '文件里的备注',
        existingId: id,
        overwrite: false,
      );
      expect(again, id);
      final Account? a = await db.accountsDao.getById(id);
      expect(a!.note, '原备注');
      expect(a.balanceMinor, 999);
    });

    test('覆盖语义：已存在且覆盖 → 字段被全量覆盖', () async {
      final String id = await repo.add(
        bookId: 'default',
        name: '微信',
        type: AccountType.wechat,
        balanceMinor: 999,
        note: '原备注',
      );
      await repo.restoreAccount(
        bookId: 'default',
        name: '微信',
        type: AccountType.wechat,
        balanceMinor: 12550,
        note: '文件里的备注',
        iconKey: 'wallet',
        colorValue: 0xFF112233,
        status: AccountStatus.sealed,
        includeInTotal: false,
        sortOrder: 3,
        existingId: id,
        overwrite: true,
      );
      final Account? a = await db.accountsDao.getById(id);
      expect(a!.note, '文件里的备注');
      expect(a.balanceMinor, 12550);
      expect(a.iconKey, 'wallet');
      expect(a.colorValue, 0xFF112233);
      expect(a.status, AccountStatus.sealed);
      expect(a.includeInTotal, false);
      expect(a.sortOrder, 3);
    });

    test('收尾校正：流水落库后余额拍回文件值', () async {
      // 模拟导入序列：restore 写文件值 → 流水逐笔 adjustBalance → 收尾校正。
      const int fileBalance = 50000;
      final String id = await repo.restoreAccount(
        bookId: 'default',
        name: '招商银行',
        type: AccountType.bankCard,
        balanceMinor: fileBalance,
      );
      // 假流水影响：+100 / -50（结果应被校正无视）
      await db.accountsDao.adjustBalance(id, 100, 0);
      await db.accountsDao.adjustBalance(id, -50, 0);
      await repo.setRestoredBalance(
        id: id,
        type: AccountType.bankCard,
        balanceMinor: fileBalance,
      );
      final Account? a = await db.accountsDao.getById(id);
      expect(a!.balanceMinor, fileBalance);
    });

    test('派生余额账户不校正：报销 / 借还跳过', () async {
      final String reimb = await repo.restoreAccount(
        bookId: 'default',
        name: '公司报销',
        type: AccountType.reimbursement,
        balanceMinor: 12345,
      );
      final String lend = await repo.restoreAccount(
        bookId: 'default',
        name: '张三',
        type: AccountType.lend,
        balanceMinor: 7777,
      );
      // 借还账户余额是派生不变量：restoreAccount 写库后即按名下未结清记录
      // 重算（无记录 → 0）。这里拿重算后的现值做基线。
      final int lendBaseline = (await db.accountsDao.getById(lend))!.balanceMinor;
      await repo.setRestoredBalance(
        id: reimb,
        type: AccountType.reimbursement,
        balanceMinor: 999,
      );
      await repo.setRestoredBalance(
        id: lend,
        type: AccountType.lend,
        balanceMinor: 999,
      );
      // 报销：新建时写文件值、收尾不校正（保持文件值）。
      expect((await db.accountsDao.getById(reimb))!.balanceMinor, 12345);
      // 借还：收尾不校正（保持派生值，不被 999 覆盖）。
      expect((await db.accountsDao.getById(lend))!.balanceMinor, lendBaseline);
    });
  });

  group('checkRows 账户段归集', () {
    test('段内账户区分「新建 / 覆盖」，重名阻断', () {
      final TemplateCheckResult r = checkRows(
        const <BillRow>[],
        accountNames: <String>{'微信'},
        categoryNamesByType: const <Set<String>>[
          <String>{},
          <String>{},
          <String>{},
        ],
        accounts: <AccountRow>[
          const AccountRow(name: '微信', type: AccountType.wechat),
          const AccountRow(name: '招商银行', type: AccountType.bankCard),
          const AccountRow(name: '招商银行', type: AccountType.bankCard),
        ],
      );
      expect(r.updatedAccounts, <String>['微信']);
      expect(r.restoredAccounts, <String>['招商银行']);
      expect(r.errors, hasLength(1));
      expect(r.errors.single, contains('重复'));
    });
  });
}
