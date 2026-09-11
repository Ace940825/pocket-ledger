import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pocket_ledger/core/bootstrap.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/accounts/presentation/account_ledger_grouping.dart';
import 'package:pocket_ledger/features/ledger/data/transaction_repository.dart';
import 'package:pocket_ledger/providers/asset_stats_settings.dart';

/// `TransactionRepository.updateTransaction()` 的回归测试（真 SQLite）。
///
/// 复现并锁死 2026-09-11 的真实事故：
/// 明细「餐饮 −¥100 + 收入 +¥12」，汇总却是 `支出:¥88.00 收入:¥0.00`。
/// 根因是 `type` 的三个从属字段（`sourceModule` / `toAccountId` /
/// `transferGroupId`）在编辑时**从不重新推导**，于是留下撒谎的旧标记。
void main() {
  late Directory tmp;
  late AppDatabase db;
  late TransactionRepository repo;

  final int at = DateTime(2026, 9, 11, 10).toUtc().millisecondsSinceEpoch;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('pl_update_txn_test');
    db = AppDatabase(NativeDatabase(File(p.join(tmp.path, 'ledger.db'))));
    await bootstrapData(db);
    repo = TransactionRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<String> cashAccountId() async {
    final List<Account> accounts =
        await db.accountsDao.watchByBook('default').first;
    return accounts.firstWhere((Account a) => a.name == '现金').id;
  }

  Future<String> addAccount(String name, AccountType type) async {
    final String id = 'acc-$name';
    await db.accountsDao.insertAccount(
      AccountsCompanion(
        id: Value<String>(id),
        bookId: const Value<String>('default'),
        name: Value<String>(name),
        type: Value<AccountType>(type),
        updatedAt: const Value<int>(0),
      ),
    );
    return id;
  }

  Future<Transaction> reload(String id) async {
    final Transaction? t = await db.transactionsDao.getById(id);
    expect(t, isNotNull, reason: '流水应仍然存在');
    return t!;
  }

  /// 取某账户的明细（已过转账去重），按默认设置算月统计。
  Future<MonthStats> statsOf(String accountId) async {
    final List<Transaction> list = await db.transactionsDao
        .watchByAccount(bookId: 'default', accountId: accountId)
        .first;
    return computeMonthStats(
      list,
      const AssetStatsSettings(),
      accountId: accountId,
    );
  }

  group('退款标记（复现截图场景）', () {
    test('还原现象：退款标记会让支出被抵扣、收入为 0', () async {
      final String acc = await cashAccountId();
      await repo.add(
        bookId: 'default',
        type: TxnType.expense,
        amountMinor: 10000,
        accountId: acc,
        occurredAt: at,
      );
      await repo.add(
        bookId: 'default',
        type: TxnType.income,
        amountMinor: 1200,
        accountId: acc,
        occurredAt: at,
        sourceModule: SourceModule.refund,
      );

      final MonthStats stats = await statsOf(acc);
      expect(stats.expenseMinor, 8800, reason: '100 − 12：这正是截图里的 ¥88.00');
      expect(stats.incomeMinor, 0);
    });

    test('退款保持收入时，标记不丢（它确实是退款）', () async {
      final String acc = await cashAccountId();
      final String id = await repo.add(
        bookId: 'default',
        type: TxnType.income,
        amountMinor: 1200,
        accountId: acc,
        occurredAt: at,
        sourceModule: SourceModule.refund,
      );

      await repo.updateTransaction(
        original: await reload(id),
        type: TxnType.income,
        amountMinor: 1200,
      );

      expect((await reload(id)).sourceModule, SourceModule.refund);
    });

    test('把误标的退款改回普通收入 → 支出 ¥100.00、收入 ¥12.00（修复路径）', () async {
      final String acc = await cashAccountId();
      await repo.add(
        bookId: 'default',
        type: TxnType.expense,
        amountMinor: 10000,
        accountId: acc,
        occurredAt: at,
      );
      final String id = await repo.add(
        bookId: 'default',
        type: TxnType.income,
        amountMinor: 1200,
        accountId: acc,
        occurredAt: at,
        sourceModule: SourceModule.refund,
      );

      await repo.updateTransaction(
        original: await reload(id),
        type: TxnType.income,
        // 用户在编辑页关掉「这是退款」。
        sourceModule: SourceModule.ledger,
      );

      expect((await reload(id)).sourceModule, SourceModule.ledger);

      final MonthStats stats = await statsOf(acc);
      expect(stats.expenseMinor, 10000, reason: '不再抵扣');
      expect(stats.incomeMinor, 1200, reason: '按普通收入计入');
      expect(stats.balanceMinor, 8800);
    });

    test('退款改成支出 → 退款标记失效', () async {
      final String acc = await cashAccountId();
      final String id = await repo.add(
        bookId: 'default',
        type: TxnType.income,
        amountMinor: 1200,
        accountId: acc,
        occurredAt: at,
        sourceModule: SourceModule.refund,
      );

      await repo.updateTransaction(
        original: await reload(id),
        type: TxnType.expense,
        amountMinor: 1200,
      );

      expect((await reload(id)).sourceModule, SourceModule.ledger);
    });
  });

  group('转账改类型（清理 toAccountId / transferGroupId）', () {
    test('转账改成支出：两个附属字段清空，且不再出现在转入方明细里', () async {
      final String from = await cashAccountId();
      final String to = await addAccount('钱包', AccountType.eWallet);
      final String id = await repo.transfer(
        bookId: 'default',
        fromAccountId: from,
        toAccountId: to,
        amountMinor: 90000,
        occurredAt: at,
      );

      await repo.updateTransaction(
        original: await reload(id),
        type: TxnType.expense,
        amountMinor: 90000,
      );

      final Transaction t = await reload(id);
      expect(t.type, TxnType.expense);
      expect(t.sourceModule, SourceModule.ledger);
      expect(t.toAccountId, isNull, reason: '否则这笔支出会凭 toAccountId 出现在钱包明细里');
      expect(t.transferGroupId, isNull);

      final List<Transaction> toSide = await db.transactionsDao
          .watchByAccount(bookId: 'default', accountId: to)
          .first;
      expect(toSide, isEmpty, reason: '钱包不该再看到这笔已经变成支出的流水');
    });

    test('转账改成支出后，两个账户余额都正确回滚', () async {
      final String from = await cashAccountId();
      final String to = await addAccount('钱包', AccountType.eWallet);
      final String id = await repo.transfer(
        bookId: 'default',
        fromAccountId: from,
        toAccountId: to,
        amountMinor: 90000,
        occurredAt: at,
      );

      await repo.updateTransaction(
        original: await reload(id),
        type: TxnType.expense,
        amountMinor: 90000,
      );

      final List<Account> accounts =
          await db.accountsDao.watchByBook('default').first;
      expect(
        accounts.firstWhere((Account a) => a.id == from).balanceMinor,
        -90000,
      );
      expect(
        accounts.firstWhere((Account a) => a.id == to).balanceMinor,
        0,
        reason: '转入方的 +900 必须被回滚',
      );
    });

    test('转账改成收入：同样清理干净', () async {
      final String from = await cashAccountId();
      final String to = await addAccount('钱包', AccountType.eWallet);
      final String id = await repo.transfer(
        bookId: 'default',
        fromAccountId: from,
        toAccountId: to,
        amountMinor: 90000,
        occurredAt: at,
      );

      await repo.updateTransaction(
        original: await reload(id),
        type: TxnType.income,
        amountMinor: 90000,
      );

      final Transaction t = await reload(id);
      expect(t.sourceModule, SourceModule.ledger);
      expect(t.toAccountId, isNull);
      expect(t.transferGroupId, isNull);
    });

    test('改成转账但没给转入账户 → 抛校验错误', () async {
      final String acc = await cashAccountId();
      final String id = await repo.add(
        bookId: 'default',
        type: TxnType.expense,
        amountMinor: 500,
        accountId: acc,
        occurredAt: at,
      );

      final Transaction original = await reload(id);
      expect(
        () =>
            repo.updateTransaction(original: original, type: TxnType.transfer),
        throwsA(
          predicate((Object? e) => e.toString().contains('转账必须指定转入账户')),
        ),
      );
    });

    test('支出改成转账（给了转入账户）→ 归位为 transfer', () async {
      final String from = await cashAccountId();
      final String to = await addAccount('钱包', AccountType.eWallet);
      final String id = await repo.add(
        bookId: 'default',
        type: TxnType.expense,
        amountMinor: 5000,
        accountId: from,
        occurredAt: at,
      );

      await repo.updateTransaction(
        original: await reload(id),
        type: TxnType.transfer,
        toAccountId: to,
        amountMinor: 5000,
      );

      final Transaction t = await reload(id);
      expect(t.type, TxnType.transfer);
      expect(t.sourceModule, SourceModule.transfer);
      expect(t.toAccountId, to);
    });
  });

  group('编辑不得丢字段（updateTx 走 INSERT OR REPLACE 的隐患）', () {
    test('currency / tags / attachmentUrls / bookId 必须原样保留', () async {
      final String acc = await cashAccountId();
      const String id = 'txn-keep-fields';
      await db.transactionsDao.insertTx(
        TransactionsCompanion(
          id: const Value<String>(id),
          bookId: const Value<String>('default'),
          type: const Value<TxnType>(TxnType.expense),
          amountMinor: const Value<int>(100),
          currency: const Value<String>('USD'),
          accountId: Value<String>(acc),
          occurredAt: Value<int>(at),
          tags: const Value<String>('["旅行","AA"]'),
          attachmentUrls: const Value<String>('["a.jpg"]'),
          relatedId: const Value<String>('rel-1'),
          sourceModule: const Value<SourceModule>(SourceModule.ledger),
          updatedAt: const Value<int>(0),
        ),
      );

      await repo.updateTransaction(
        original: await reload(id),
        amountMinor: 200,
      );

      final Transaction t = await reload(id);
      expect(t.amountMinor, 200, reason: '金额确实被改掉');
      expect(t.currency, 'USD', reason: '不能被 replace 打回 CNY');
      expect(t.bookId, 'default', reason: '非空外键不能被清空');
      expect(t.tags, '["旅行","AA"]');
      expect(t.attachmentUrls, '["a.jpg"]');
      expect(t.relatedId, 'rel-1');
      expect(t.dirty, isTrue, reason: '编辑后必须标记为待同步');
    });
  });
}
