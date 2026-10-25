import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pocket_ledger/core/bootstrap.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/ledger/data/import_record_repository.dart';
import 'package:pocket_ledger/features/ledger/data/transaction_repository.dart';

/// 覆盖模式数据安全测试（2026-10-22：导入冲突处理「覆盖原有数据」）。
///
/// 背景：用户导入时若库中已有数据，弹出「合并 / 覆盖 / 取消」三选一。
/// 覆盖路径在 _import 事务内的动作序列 = 本测试的断言对象：
/// ① 按 bookId 批量软删当前账本全部流水（[TransactionRepository.removeBatch]
///    内部自理余额回退 / 同步入队 / 报销级联）；
/// ② 删除与清空流水有交集的导入记录行（[ImportRecordRepository.deleteRow]，
///    只删行不再级联——getById 不过滤已软删行，重复 remove 会二次回退余额）；
/// ③ 之后正常写入新流水。
///
/// 关键不变量：删除后余额必须回到写入前、同步队列只增删除 op、之后的新
/// 流水计数与余额正确、其他账本流水与导入记录不受影响。
void main() {
  late Directory tmp;
  late AppDatabase db;
  late TransactionRepository txnRepo;
  late ImportRecordRepository importRepo;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('pl_import_overwrite_test');
    db = AppDatabase(NativeDatabase(File(p.join(tmp.path, 'ledger.db'))));
    await bootstrapData(db);
    txnRepo = TransactionRepository(db);
    importRepo = ImportRecordRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<String> addAccount(String id, AccountType type,
      {String bookId = 'default',}) async {
    await db.accountsDao.insertAccount(
      AccountsCompanion(
        id: Value<String>(id),
        bookId: Value<String>(bookId),
        name: Value<String>(id),
        type: Value<AccountType>(type),
        updatedAt: const Value<int>(0),
      ),
    );
    return id;
  }

  Future<int> liveTxnCount(String bookId) async {
    final Expression<int> cnt = db.transactions.id.count();
    final TypedResult? row = await (db.selectOnly(db.transactions)
          ..addColumns(<Expression<Object>>[cnt])
          ..where(db.transactions.bookId.equals(bookId) &
              db.transactions.deleted.equals(false),))
        .getSingleOrNull();
    return row?.read(cnt) ?? 0;
  }

  Future<int?> balanceOf(String accId) async {
    final List<Account> rows = await (db.select(db.accounts)
          ..where((t) => t.id.equals(accId)))
        .get();
    return rows.isEmpty ? null : rows.first.balanceMinor;
  }

  test('覆盖序列：软删当前账本流水 → 余额回退 → 删交集导入记录 → 新流水正常', () async {
    final String a = await addAccount('甲', AccountType.cash);
    final String b = await addAccount('乙', AccountType.cash);
    final int queueBefore = await db.pendingOpsDao.watchCount().first;

    // 旧流水（模拟上一次导入的成果）：3 笔，甲余额 -100+250+50=200，乙 +300。
    final List<String> oldIds = <String>[];
    oldIds.add(await txnRepo.add(
      bookId: 'default', type: TxnType.expense, amountMinor: 100,
      accountId: a, occurredAt: 1700000000000, note: 'old-e',
    ),);
    oldIds.add(await txnRepo.add(
      bookId: 'default', type: TxnType.income, amountMinor: 250,
      accountId: a, occurredAt: 1700000001000, note: 'old-i',
    ),);
    oldIds.add(await txnRepo.add(
      bookId: 'default', type: TxnType.transfer, amountMinor: 300,
      accountId: a, toAccountId: b, occurredAt: 1700000002000, note: 'old-t',
    ),);
    // 旧导入记录（txnIds 指向上面三笔）。
    await importRepo.insert(ImportRecord(
      id: 'rec-old',
      source: 'pocketLedger',
      sourceLabel: '口袋账本',
      importedCount: 3,
      skippedCount: 0,
      createdAt: 1700000003000,
      txnIds: List<String>.from(oldIds),
    ),);

    expect(await liveTxnCount('default'), 3);
    // 甲：-100 +250 -300 = -150；乙：+300。
    expect(await balanceOf(a), -150);
    expect(await balanceOf(b), 300);

    // ── 覆盖序列（与 _import 事务内的动作同构）──
    final List<Transaction> stale = await (db.select(db.transactions)
          ..where((t) =>
              t.bookId.equals('default') & t.deleted.equals(false),))
        .get();
    final List<String> staleIds = stale.map((Transaction t) => t.id).toList();
    final Set<String> staleIdSet = staleIds.toSet();
    await txnRepo.removeBatch(staleIds);
    for (final ImportRecord r in await importRepo.getAll()) {
      final bool touched = r.txnIds?.any(staleIdSet.contains) ?? false;
      if (touched) await importRepo.deleteRow(r.id);
    }

    // ① 当前账本无残留未删流水；导入记录行已删。
    expect(await liveTxnCount('default'), 0);
    expect(await importRepo.getAll(), isEmpty);

    // ② 余额回退到写入前（软删不穿透余额）。
    expect(await balanceOf(a), 0);
    expect(await balanceOf(b), 0);

    // ③ 同步队列：[PendingOpsDao.enqueue] 按 (targetTable, recordId) 去重
    //    （修复「待同步累计统计异常」根因）——3 笔 insert op 各自被随后的
    //    delete op 折叠替换，队列收敛为 3 条 delete op（= 有未同步变更的
    //    记录数），故基线上 +3 而非旧的 +6。
    expect(await db.pendingOpsDao.watchCount().first, queueBefore + 3);

    // ④ 之后正常导入新流水：计数 / 余额 / 记录均正确。
    await txnRepo.add(
      bookId: 'default', type: TxnType.expense, amountMinor: 88,
      accountId: a, occurredAt: 1700000004000, note: 'new-e',
    );
    await importRepo.insert(const ImportRecord(
      id: 'rec-new',
      source: 'pocketLedger',
      sourceLabel: '口袋账本',
      importedCount: 1,
      skippedCount: 0,
      createdAt: 1700000005000,
    ),);
    expect(await liveTxnCount('default'), 1);
    expect(await balanceOf(a), -88);
    expect((await importRepo.getAll()).length, 1);
  });

  test('覆盖不影响其他账本的流水与导入记录', () async {
    final String other = await addAccount('另账本账户', AccountType.cash,
        bookId: 'other',);
    final List<String> otherIds = <String>[
      await txnRepo.add(
        bookId: 'other', type: TxnType.expense, amountMinor: 42,
        accountId: other, occurredAt: 1700000000000, note: 'other-e',
      ),
    ];
    await importRepo.insert(ImportRecord(
      id: 'rec-other',
      source: 'pocketLedger',
      sourceLabel: '口袋账本',
      importedCount: 1,
      skippedCount: 0,
      createdAt: 1700000001000,
      txnIds: List<String>.from(otherIds),
    ),);

    // 对 default 账本执行覆盖（此时 default 无流水，staleIds 为空）。
    final List<Transaction> stale = await (db.select(db.transactions)
          ..where((t) =>
              t.bookId.equals('default') & t.deleted.equals(false),))
        .get();
    final List<String> staleIds =
        stale.map((Transaction t) => t.id).toList();
    final Set<String> staleIdSet = staleIds.toSet();
    if (staleIds.isNotEmpty) await txnRepo.removeBatch(staleIds);
    for (final ImportRecord r in await importRepo.getAll()) {
      final bool touched = r.txnIds?.any(staleIdSet.contains) ?? false;
      if (touched) await importRepo.deleteRow(r.id);
    }

    // 其他账本流水与导入记录原样保留。
    expect(await liveTxnCount('other'), 1);
    expect(await balanceOf(other), -42);
    expect((await importRepo.getAll()).length, 1);
  });
}
