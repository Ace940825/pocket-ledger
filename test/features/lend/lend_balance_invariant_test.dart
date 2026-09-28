import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pocket_ledger/core/bootstrap.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/ledger/data/transaction_repository.dart';
import 'package:pocket_ledger/features/lend/data/lend_repository.dart';

/// 借入/借出账户「未还本金」余额不变量回归测试（真 SQLite，内存库）。
///
/// 不变量：借还账户 balanceMinor = 名下未结清借还记录合计
/// （本金 − 优惠 − 已还）。用户报告：借入账户记一笔 ¥100 后，
/// 资产详情页「未还本金」显示 ¥0.00。本文件复现各条可能路径。
void main() {
  late AppDatabase db;
  late LendRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LendRepository(db, TransactionRepository(db));
  });

  tearDown(() => db.close());

  Future<Account> insertAccount(
    String id,
    String name,
    AccountType type, {
    int balance = 0,
  }) async {
    await db.into(db.accounts).insert(
          AccountsCompanion.insert(
            id: id,
            bookId: 'b1',
            name: name,
            type: type,
            updatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
            balanceMinor: Value<int>(balance),
          ),
        );
    return (db.select(db.accounts)
          ..where(($AccountsTable t) => t.id.equals(id)))
        .getSingle();
  }

  Future<Account> account(String id) => (db.select(db.accounts)
            ..where(($AccountsTable t) => t.id.equals(id)))
          .getSingle();

  Future<List<LendRecord>> records() => db.select(db.lendRecords).get();

  test('A: 先建借入账户「2」，记一笔借入 ¥100（指定账户 + 现金）→ 余额应为 100',
      () async {
    await insertAccount('acc_cash', '现金', AccountType.cash);
    await insertAccount('acc_2', '2', AccountType.borrow);

    await repo.add(
      bookId: 'b1',
      direction: LendDirection.borrowIn,
      status: LendStatus.ongoing,
      counterparty: '2',
      amountMinor: 10000,
      occurredAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      accountId: 'acc_2',
      toAccountId: 'acc_cash',
    );

    expect((await account('acc_2')).balanceMinor, 10000,
        reason: '借入账户余额 = 名下未结清合计');
    expect((await account('acc_cash')).balanceMinor, 10000,
        reason: '现金账户收本金 +100');
  });

  test('B: 未指定借入账户、对方名「2」与账户同名 → 自动归户后余额应为 100',
      () async {
    await insertAccount('acc_cash', '现金', AccountType.cash);
    await insertAccount('acc_2', '2', AccountType.borrow);

    await repo.add(
      bookId: 'b1',
      direction: LendDirection.borrowIn,
      status: LendStatus.ongoing,
      counterparty: '2',
      amountMinor: 10000,
      occurredAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      accountId: null,
      toAccountId: 'acc_cash',
    );

    final LendRecord r = (await records()).single;
    expect(r.accountId, 'acc_2', reason: '按对方名自动归户');
    expect((await account('acc_2')).balanceMinor, 10000);
  });

  test('C: 先记借入后建同名账户，重启跑 bootstrap → 余额应为 100', () async {
    await insertAccount('acc_cash', '现金', AccountType.cash);

    await repo.add(
      bookId: 'b1',
      direction: LendDirection.borrowIn,
      status: LendStatus.ongoing,
      counterparty: '2',
      amountMinor: 10000,
      occurredAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      accountId: null,
      toAccountId: 'acc_cash',
    );

    // 建账户前余额无从谈起；建账户后未重启，记录仍未归户。
    await insertAccount('acc_2', '2', AccountType.borrow);
    expect((await account('acc_2')).balanceMinor, 0,
        reason: '建账户本身不归户存量记录');

    // 模拟重启：bootstrap 归户 + 补流水 + 余额对账。
    await bootstrapData(db);

    final LendRecord r = (await records()).single;
    expect(r.accountId, 'acc_2', reason: '启动归户回填 accountId');
    expect((await account('acc_2')).balanceMinor, 10000,
        reason: '启动对账重算借入账户余额');
  });

  test('D: 全额还债后余额 0（正确）；删除还债流水后记录是否恢复？', () async {
    await insertAccount('acc_cash', '现金', AccountType.cash);
    await insertAccount('acc_2', '2', AccountType.borrow);

    await repo.add(
      bookId: 'b1',
      direction: LendDirection.borrowIn,
      status: LendStatus.ongoing,
      counterparty: '2',
      amountMinor: 10000,
      occurredAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      accountId: 'acc_2',
      toAccountId: 'acc_cash',
    );
    expect((await account('acc_2')).balanceMinor, 10000);

    await repo.repay(
      bookId: 'b1',
      direction: LendDirection.borrowIn,
      counterparty: '2',
      amountMinor: 10000,
      occurredAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      accountId: 'acc_cash',
    );
    expect((await account('acc_2')).balanceMinor, 0, reason: '已还清 → 未还本金 0');
    expect((await records()).single.status, LendStatus.settled);

    // 用户在流水页删除「还债」流水（想撤销还款）——
    // 记录必须反向恢复：settled → ongoing、repaid 清零、余额回 100。
    final List<Transaction> flows = await (db.select(db.transactions)
          ..where(($TransactionsTable t) =>
              t.sourceModule.equals(SourceModule.lend.index) &
              t.deleted.equals(false)))
        .get();
    final Transaction repayFlow = flows.firstWhere(
      (Transaction t) =>
          t.type == TxnType.expense &&
          t.relatedId != null &&
          t.relatedId!.isNotEmpty,
    );
    await TransactionRepository(db).remove(repayFlow.id);

    final LendRecord r = (await records()).single;
    expect(r.status, LendStatus.ongoing, reason: '删除还债流水后债务重新生效');
    expect(r.repaidMinor, 0);
    expect((await account('acc_2')).balanceMinor, 10000,
        reason: '未还本金恢复为 100');
    expect((await account('acc_cash')).balanceMinor, 10000,
        reason: '现金侧回滚：还债 -100 被撤销');
  });

  test('D2: 删除债务消减备忘流水同样反向恢复（有台账）', () async {
    await insertAccount('acc_cash', '现金', AccountType.cash);
    await insertAccount('acc_2', '2', AccountType.borrow);

    await repo.add(
      bookId: 'b1',
      direction: LendDirection.borrowIn,
      status: LendStatus.ongoing,
      counterparty: '2',
      amountMinor: 10000,
      occurredAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      accountId: 'acc_2',
      toAccountId: 'acc_cash',
    );
    await repo.debtReduction(
      bookId: 'b1',
      direction: LendDirection.borrowIn,
      counterparty: '2',
      amountMinor: 4000,
      occurredAt: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    LendRecord r = (await records()).single;
    expect(r.repaidMinor, 4000, reason: '消减冲减已还口径（台账记录）');
    expect((await account('acc_2')).balanceMinor, 6000);

    final List<Transaction> memos = await (db.select(db.transactions)
          ..where(($TransactionsTable t) =>
              t.sourceModule.equals(SourceModule.lend.index) &
              t.deleted.equals(false) &
              t.type.equals(TxnType.expense.index)))
        .get();
    await TransactionRepository(db).remove(memos.first.id);

    r = (await records()).single;
    expect(r.repaidMinor, 0, reason: '删除备忘后冲减额回退');
    expect((await account('acc_2')).balanceMinor, 10000);
  });

  test('E: 优惠 100 时余额 0 属正确口径（本金−优惠−已还）', () async {
    await insertAccount('acc_cash', '现金', AccountType.cash);
    await insertAccount('acc_2', '2', AccountType.borrow);

    await repo.add(
      bookId: 'b1',
      direction: LendDirection.borrowIn,
      status: LendStatus.ongoing,
      counterparty: '2',
      amountMinor: 10000,
      occurredAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      accountId: 'acc_2',
      toAccountId: 'acc_cash',
      discountMinor: 10000,
    );

    expect((await account('acc_2')).balanceMinor, 0);
  });
}
