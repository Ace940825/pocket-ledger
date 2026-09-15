import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pocket_ledger/core/bootstrap.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/ledger/data/transaction_repository.dart';

/// `TransactionRepository` 图片附件（attachmentUrls）的回归测试（真 SQLite）。
///
/// 锁死：add / updateTransaction / transfer 都能正确写入与回读附件 JSON，
/// 且默认（不传）时该列为 null，不会污染其它流水。
void main() {
  late Directory tmp;
  late AppDatabase db;
  late TransactionRepository repo;

  final int at = DateTime(2026, 9, 15, 10).toUtc().millisecondsSinceEpoch;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('pl_attach_test');
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

  Future<String> addWallet() async {
    const String id = 'acc-wallet';
    await db.accountsDao.insertAccount(
      AccountsCompanion(
        id: const Value<String>(id),
        bookId: const Value<String>('default'),
        name: const Value<String>('钱包'),
        type: const Value<AccountType>(AccountType.eWallet),
        updatedAt: const Value<int>(0),
      ),
    );
    return id;
  }

  Future<Transaction> reload(String id) async {
    final Transaction? t = await db.transactionsDao.getById(id);
    expect(t, isNotNull, reason: '流水应存在');
    return t!;
  }

  test('add 写入 attachmentUrls 并可读回', () async {
    final String acc = await cashAccountId();
    final String id = await repo.add(
      bookId: 'default',
      type: TxnType.expense,
      amountMinor: 5000,
      accountId: acc,
      occurredAt: at,
      attachmentUrls: <String>['/a/1.jpg', '/a/2.png'],
    );
    expect((await reload(id)).attachmentUrls, '["/a/1.jpg","/a/2.png"]');
  });

  test('add 不传 attachmentUrls 时该列为 null', () async {
    final String acc = await cashAccountId();
    final String id = await repo.add(
      bookId: 'default',
      type: TxnType.expense,
      amountMinor: 5000,
      accountId: acc,
      occurredAt: at,
    );
    expect((await reload(id)).attachmentUrls, isNull);
  });

  test('updateTransaction 可覆盖 attachmentUrls', () async {
    final String acc = await cashAccountId();
    final String id = await repo.add(
      bookId: 'default',
      type: TxnType.expense,
      amountMinor: 5000,
      accountId: acc,
      occurredAt: at,
      attachmentUrls: <String>['/old/1.jpg'],
    );

    await repo.updateTransaction(
      original: await reload(id),
      amountMinor: 5000,
      attachmentUrls: <String>['/new/9.jpg'],
    );

    expect((await reload(id)).attachmentUrls, '["/new/9.jpg"]');
  });

  test('updateTransaction 不传时保留原附件', () async {
    final String acc = await cashAccountId();
    final String id = await repo.add(
      bookId: 'default',
      type: TxnType.expense,
      amountMinor: 5000,
      accountId: acc,
      occurredAt: at,
      attachmentUrls: <String>['/keep/1.jpg'],
    );

    await repo.updateTransaction(
      original: await reload(id),
      amountMinor: 6000,
    );

    expect((await reload(id)).attachmentUrls, '["/keep/1.jpg"]');
  });

  test('transfer 透传 attachmentUrls', () async {
    final String from = await cashAccountId();
    final String to = await addWallet();
    final String id = await repo.transfer(
      bookId: 'default',
      fromAccountId: from,
      toAccountId: to,
      amountMinor: 9000,
      occurredAt: at,
      attachmentUrls: <String>['/t/1.jpg'],
    );
    expect((await reload(id)).attachmentUrls, '["/t/1.jpg"]');
  });
}
