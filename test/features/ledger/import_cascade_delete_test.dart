import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pocket_ledger/core/bootstrap.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/accounts/data/account_repository.dart';
import 'package:pocket_ledger/features/installment/data/installment_repository.dart';
import 'package:pocket_ledger/features/investment/data/investment_repository.dart';
import 'package:pocket_ledger/features/ledger/data/import_record_repository.dart';
import 'package:pocket_ledger/features/ledger/data/transaction_repository.dart';
import 'package:pocket_ledger/features/lend/data/lend_repository.dart';
import 'package:pocket_ledger/features/reimbursement/data/reimbursement_repository.dart';
import 'package:pocket_ledger/features/savings/data/savings_repository.dart';

/// 导入记录级联删除 + 清空全部数据。
///
/// 覆盖「删除导入记录时随导入新建的账户 / 流水清不干净、且不同步删除」的修复：
/// - deleteCascade 把本批流水、随导入新建账户一并软删并入队同步 delete；
/// - 账户守卫：被本批以外流水引用的账户保留，避免手动账单变孤儿；
/// - wipeAllUserData 清空全部账目表但保留账本。
void main() {
  group('ImportRecordRepository.deleteCascade', () {
    late Directory tmp;
    late AppDatabase db;
    late TransactionRepository txnRepo;
    late AccountRepository accRepo;
    late LendRepository lendRepo;
    late InvestmentRepository investRepo;
    late ReimbursementRepository reimbRepo;
    late SavingsRepository savingsRepo;
    late InstallmentRepository instRepo;
    late ImportRecordRepository importRepo;

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('pl_import_cascade_test');
      db = AppDatabase(NativeDatabase(File(p.join(tmp.path, 'ledger.db'))));
      await bootstrapData(db);
      txnRepo = TransactionRepository(db);
      accRepo = AccountRepository(db);
      lendRepo = LendRepository(db, txnRepo);
      investRepo = InvestmentRepository(db, txnRepo);
      reimbRepo = ReimbursementRepository(db);
      savingsRepo = SavingsRepository(db);
      instRepo = InstallmentRepository(db, txnRepo);
      importRepo = ImportRecordRepository(db);
    });

    tearDown(() async {
      await db.close();
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    Future<Transaction?> txn(String id) =>
        (db.select(db.transactions)..where((Transactions t) => t.id.equals(id)))
            .getSingleOrNull();

    Future<Account?> acc(String id) =>
        (db.select(db.accounts)..where((Accounts t) => t.id.equals(id)))
            .getSingleOrNull();

    test('级联删除：流水 + 随导入新建账户一并软删并入队同步 delete', () async {
      final String accId = await accRepo.add(
        bookId: 'default',
        name: '导入账户',
        type: AccountType.cash,
        balanceMinor: 100000,
      );
      final String tid = await txnRepo.add(
        bookId: 'default',
        type: TxnType.expense,
        amountMinor: 2550,
        accountId: accId,
        occurredAt: DateTime.utc(2026, 10, 20).millisecondsSinceEpoch,
      );
      const String recId = 'rec-1';
      await importRepo.insert(
        ImportRecord(
          id: recId,
          source: 'test',
          sourceLabel: '测试',
          importedCount: 1,
          skippedCount: 0,
          createdAt: DateTime.utc(2026, 10, 21).millisecondsSinceEpoch,
          txnIds: <String>[tid],
          accountIds: <String>[accId],
        ),
      );

      await importRepo.deleteCascade(
        recId,
        txnRepo,
        accRepo,
        lendRepo,
        investRepo,
        reimbRepo,
        savingsRepo,
        instRepo,
      );

      expect((await txn(tid))!.deleted, isTrue);
      expect((await acc(accId))!.deleted, isTrue);

      final List<PendingOp> ops = await db.select(db.pendingOps).get();
      expect(
        ops.any(
          (PendingOp o) =>
              o.targetTable == 'accounts' &&
              o.recordId == accId &&
              o.opType == SyncOpType.delete,
        ),
        isTrue,
        reason: '随导入新建的账户应入队同步 delete',
      );
      expect(
        ops.any(
          (PendingOp o) =>
              o.targetTable == 'transactions' &&
              o.recordId == tid &&
              o.opType == SyncOpType.delete,
        ),
        isTrue,
      );
      expect(await importRepo.getById(recId), isNull);
    });

    test('账户守卫：被本批以外流水引用时保留账户', () async {
      final String accId = await accRepo.add(
        bookId: 'default',
        name: '共用账户',
        type: AccountType.cash,
        balanceMinor: 100000,
      );
      final String batchTxn = await txnRepo.add(
        bookId: 'default',
        type: TxnType.expense,
        amountMinor: 1000,
        accountId: accId,
        occurredAt: DateTime.utc(2026, 10, 20).millisecondsSinceEpoch,
      );
      final String externalTxn = await txnRepo.add(
        bookId: 'default',
        type: TxnType.expense,
        amountMinor: 2000,
        accountId: accId,
        occurredAt: DateTime.utc(2026, 10, 19).millisecondsSinceEpoch,
      );
      const String recId = 'rec-guard';
      await importRepo.insert(
        ImportRecord(
          id: recId,
          source: 'test',
          sourceLabel: '测试',
          importedCount: 1,
          skippedCount: 0,
          createdAt: DateTime.utc(2026, 10, 21).millisecondsSinceEpoch,
          txnIds: <String>[batchTxn],
          accountIds: <String>[accId],
        ),
      );

      await importRepo.deleteCascade(
        recId,
        txnRepo,
        accRepo,
        lendRepo,
        investRepo,
        reimbRepo,
        savingsRepo,
        instRepo,
      );

      expect((await txn(batchTxn))!.deleted, isTrue);
      expect((await txn(externalTxn))!.deleted, isFalse);
      expect(
        (await acc(accId))!.deleted,
        isFalse,
        reason: '仍被外部流水引用，账户应保留',
      );
    });
  });

  group('AppDatabase.wipeAllUserData', () {
    test('清空全部账目数据但保留账本', () async {
      final Directory tmp = Directory.systemTemp.createTempSync('pl_wipe_test');
      final AppDatabase db =
          AppDatabase(NativeDatabase(File(p.join(tmp.path, 'ledger.db'))));
      try {
        await bootstrapData(db);
        final AccountRepository accRepo = AccountRepository(db);
        await accRepo.add(
          bookId: 'default',
          name: '待清空账户',
          type: AccountType.cash,
          balanceMinor: 500,
        );
        expect(await db.select(db.accounts).get(), isNotEmpty);

        await db.wipeAllUserData();

        expect(await db.select(db.accounts).get(), isEmpty);
        expect(await db.select(db.transactions).get(), isEmpty);
        expect(await db.select(db.pendingOps).get(), isEmpty);
        expect(await db.select(db.books).get(), isNotEmpty);
      } finally {
        await db.close();
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      }
    });
  });
}
