import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pocket_ledger/core/bootstrap.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/database/daos/transfer_dedupe.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/ledger/data/transaction_repository.dart';

/// `TransactionRepository.transfer()` 的写入回归测试（真 SQLite）。
///
/// 锁死两条不变量：
/// 1. **一笔转账只写一条流水** —— 早期写成对称的两条腿，导致同一笔转账在
///    账户明细里出现两次、月汇总重复累加，而且方向彻底丢失；
/// 2. **方向可判定** —— `accountId = 转出方`、`toAccountId = 转入方`，
///    这样「转账转入计入收入」这类统计口径才成立。
void main() {
  late Directory tmp;
  late AppDatabase db;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('pl_transfer_test');
    db = AppDatabase(NativeDatabase(File(p.join(tmp.path, 'ledger.db'))));
    await bootstrapData(db);
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// 在默认账本里补一个账户，返回其 id。
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

  Future<String> cashAccountId() async {
    final List<Account> accounts =
        await db.accountsDao.watchByBook('default').first;
    return accounts.firstWhere((Account a) => a.name == '现金').id;
  }

  test('一笔转账只写一条流水（不再写成对的两条腿）', () async {
    final String from = await cashAccountId();
    final String to = await addAccount('钱包', AccountType.eWallet);

    await TransactionRepository(db).transfer(
      bookId: 'default',
      fromAccountId: from,
      toAccountId: to,
      amountMinor: 90000,
      occurredAt: DateTime(2026, 9, 11, 10).toUtc().millisecondsSinceEpoch,
    );

    final List<Transaction> all = await db.transactionsDao
        .watchRecent(
          bookId: 'default',
          limit: 50,
        )
        .first;
    expect(all, hasLength(1), reason: '转账只应产生 1 条流水');
    expect(all.single.type, TxnType.transfer);
    expect(all.single.accountId, from, reason: 'accountId 是转出方');
    expect(all.single.toAccountId, to, reason: 'toAccountId 是转入方');
    expect(all.single.transferGroupId, isNotNull);
  });

  test('两个账户的明细里各出现一次，且方向相反', () async {
    final String from = await cashAccountId();
    final String to = await addAccount('钱包', AccountType.eWallet);

    await TransactionRepository(db).transfer(
      bookId: 'default',
      fromAccountId: from,
      toAccountId: to,
      amountMinor: 90000,
      occurredAt: DateTime(2026, 9, 11, 10).toUtc().millisecondsSinceEpoch,
    );

    final List<Transaction> fromSide = await db.transactionsDao
        .watchByAccount(bookId: 'default', accountId: from)
        .first;
    final List<Transaction> toSide = await db.transactionsDao
        .watchByAccount(bookId: 'default', accountId: to)
        .first;

    expect(fromSide, hasLength(1), reason: '转出方也只应看到 1 条');
    expect(toSide, hasLength(1), reason: '转入方也只应看到 1 条');
    expect(
      transferDirectionOf(fromSide.single, from),
      TransferDirection.outgoing,
    );
    expect(
      transferDirectionOf(toSide.single, to),
      TransferDirection.incoming,
    );
  });

  test('余额：转出方减少、转入方增加，净资产不变', () async {
    final String from = await cashAccountId();
    final String to = await addAccount('钱包', AccountType.eWallet);

    await TransactionRepository(db).transfer(
      bookId: 'default',
      fromAccountId: from,
      toAccountId: to,
      amountMinor: 90000,
      occurredAt: DateTime(2026, 9, 11, 10).toUtc().millisecondsSinceEpoch,
    );

    final List<Account> accounts =
        await db.accountsDao.watchByBook('default').first;
    final Account fromAcc = accounts.firstWhere((Account a) => a.id == from);
    final Account toAcc = accounts.firstWhere((Account a) => a.id == to);

    expect(fromAcc.balanceMinor, -90000);
    expect(toAcc.balanceMinor, 90000);
    expect(
      await db.accountsDao.watchNetAssets('default').first,
      0,
      reason: '转账是内部划转，净资产不变',
    );
  });

  test('转出与转入是同一账户时抛校验错误', () async {
    final String from = await cashAccountId();
    expect(
      () => TransactionRepository(db).transfer(
        bookId: 'default',
        fromAccountId: from,
        toAccountId: from,
        amountMinor: 100,
        occurredAt: 0,
      ),
      throwsA(
        predicate(
          (Object? e) => e.toString().contains('转出与转入账户不能相同'),
        ),
      ),
    );
  });
}
