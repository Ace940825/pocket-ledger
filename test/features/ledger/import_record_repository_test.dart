import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/features/accounts/data/account_repository.dart';
import 'package:pocket_ledger/features/installment/data/installment_repository.dart';
import 'package:pocket_ledger/features/investment/data/investment_repository.dart';
import 'package:pocket_ledger/features/ledger/data/import_record_repository.dart';
import 'package:pocket_ledger/features/ledger/data/transaction_repository.dart';
import 'package:pocket_ledger/features/lend/data/lend_repository.dart';
import 'package:pocket_ledger/features/reimbursement/data/reimbursement_repository.dart';
import 'package:pocket_ledger/features/savings/data/savings_repository.dart';

/// 导入记录仓储回归测试：覆盖原生 SQL 表 `import_records` 的写入 / 读取 /
/// 删除与 JSON 序列化往返（failReasons / txnIds），以及级联删除在「无流水清单」
/// 时仅删除记录行（不触碰流水）。
void main() {
  late Directory tmp;
  late AppDatabase db;
  late ImportRecordRepository repo;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pl_import_record_test');
    db = AppDatabase(NativeDatabase(File(p.join(tmp.path, 'import_record.db'))));
    repo = ImportRecordRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('insert → getAll 往返，含 failReasons / txnIds JSON 序列化', () async {
    const ImportRecord r = ImportRecord(
      id: 'rec-1',
      source: 'unionpay',
      sourceLabel: '云闪付',
      importedCount: 10,
      skippedCount: 2,
      createdAt: 1700000000000,
      failReasons: <String>['账户不存在', '分类缺失'],
      txnIds: <String>['t1', 't2'],
    );
    await repo.insert(r);

    final List<ImportRecord> all = await repo.getAll();
    expect(all.length, 1);
    final ImportRecord got = all.first;
    expect(got.id, 'rec-1');
    expect(got.source, 'unionpay');
    expect(got.sourceLabel, '云闪付');
    expect(got.importedCount, 10);
    expect(got.skippedCount, 2);
    expect(got.createdAt, 1700000000000);
    expect(got.failReasons, <String>['账户不存在', '分类缺失']);
    expect(got.txnIds, <String>['t1', 't2']);
  });

  test('getById 命中与未命中', () async {
    await repo.insert(const ImportRecord(
      id: 'rec-2',
      source: 'alipay',
      sourceLabel: '支付宝',
      importedCount: 3,
      skippedCount: 0,
      createdAt: 1700000000001,
    ),);

    final ImportRecord? hit = await repo.getById('rec-2');
    expect(hit, isNotNull);
    expect(hit!.sourceLabel, '支付宝');

    final ImportRecord? miss = await repo.getById('nope');
    expect(miss, isNull);
  });

  test('deleteRow 仅移除记录行', () async {
    await repo.insert(const ImportRecord(
      id: 'rec-3',
      source: 'wechat',
      sourceLabel: '微信',
      importedCount: 1,
      skippedCount: 0,
      createdAt: 1700000000002,
    ),);
    expect((await repo.getAll()).length, 1);

    await repo.deleteRow('rec-3');
    expect((await repo.getAll()).length, 0);
  });

  test('deleteCascade 对无 txnIds 记录只删记录行（不触碰流水）', () async {
    await repo.insert(const ImportRecord(
      id: 'rec-4',
      source: 'bank',
      sourceLabel: '银行',
      importedCount: 5,
      skippedCount: 1,
      createdAt: 1700000000003,
    ),);
    final TransactionRepository txnRepo = TransactionRepository(db);
    // deleteCascade 需全部台账仓储（级联第 2/3 步用）；本记录无任何
    // txnIds / 台账 / 账户 ID，故只有记录行被删，不触碰流水。
    await repo.deleteCascade(
      'rec-4',
      txnRepo,
      AccountRepository(db),
      LendRepository(db, txnRepo),
      InvestmentRepository(db, txnRepo),
      ReimbursementRepository(db),
      SavingsRepository(db),
      InstallmentRepository(db, txnRepo),
    );
    expect((await repo.getAll()).length, 0);
  });

  test('watchAll 实时反映写入与删除', () async {
    final List<ImportRecord> initial =
        await repo.watchAll().first;
    expect(initial.length, 0);

    await repo.insert(const ImportRecord(
      id: 'rec-5',
      source: 'pocketLedger',
      sourceLabel: '本应用',
      importedCount: 2,
      skippedCount: 0,
      createdAt: 1700000000004,
    ),);
    final List<ImportRecord> afterInsert =
        await repo.watchAll().first;
    expect(afterInsert.length, 1);

    await repo.deleteRow('rec-5');
    final List<ImportRecord> afterDelete =
        await repo.watchAll().first;
    expect(afterDelete.length, 0);
  });
}
