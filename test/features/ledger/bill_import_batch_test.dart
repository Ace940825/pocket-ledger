import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pocket_ledger/core/bootstrap.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/ledger/data/transaction_repository.dart';

/// 大批量导入优化回归测试（2026-10-21 原始版 → 2026-10-22 移植到主工程）。
///
/// 背景：用户导入 15,631 行时「卡死在导入界面」——原实现逐行
/// `txnRepo.add()`，每笔各自开事务提交（15,631 次 fsync），手机端要跑十几
/// 分钟且全程无进度反馈。优化分两拨落地：
/// · **主工程**（本仓库）：「整批原子事务」先行（根因 #4 修复，导入记录
///   也包进事务内）；
/// · **进度反馈**（2026-10-22 移植）：每 500 行让出事件循环 + 确定性进度条，
///   写入语义不变，仍在同一事务内（chunk 之间不提交）。
///
/// 本测试锁死该优化的三个前提假设：
/// 1. **结果等价**：外层事务包裹逐行 add ≡ 逐行独立事务（drift savepoint
///    语义在本机 native SQLite 上成立）——流水逐字段一致、余额一致、
///    同步队列条数一致；
/// 2. **原子回滚**：外层事务中途抛错 → 整体回滚，不留孤儿流水 / 孤儿
///    同步队列 / 错误余额（这是优化顺带修掉的旧缺陷：原实现中途失败会留
///    "导入一半又没有导入记录可删"的数据）；
/// 3. **跨 await 不丢事务**：事务内 `Future.delayed(Duration.zero)`（进度
///    让出机制）之后继续写入仍属同一事务，最终一并提交。
void main() {
  late Directory tmp;
  late AppDatabase db;
  late TransactionRepository txnRepo;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('pl_import_batch_test');
    db = AppDatabase(NativeDatabase(File(p.join(tmp.path, 'ledger.db'))));
    await bootstrapData(db);
    txnRepo = TransactionRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// 在默认账本补一个账户，返回其 id（id 显式传入，便于同名著两套账）。
  Future<String> addAccount(String id, AccountType type) async {
    await db.accountsDao.insertAccount(
      AccountsCompanion(
        id: Value<String>(id),
        bookId: const Value<String>('default'),
        name: Value<String>(id),
        type: Value<AccountType>(type),
        updatedAt: const Value<int>(0),
      ),
    );
    return id;
  }

  /// 一笔写入规格（三种类型轮换，覆盖 _applyBalanceDelta 全部分支）。
  /// 同名 note 会写两遍（逐行批 / 事务批各一笔），用于逐字段比对。
  List<_Spec> specs(String accA, String accB) => <_Spec>[
    _Spec(TxnType.expense, 100, accA, null, 'e1'),
    _Spec(TxnType.income, 250, accA, null, 'i1'),
    _Spec(TxnType.transfer, 300, accA, accB, 't1'),
    _Spec(TxnType.expense, 199, accB, null, 'e2'),
    _Spec(TxnType.income, 1, accB, null, 'i2'),
    _Spec(TxnType.transfer, 50, accB, accA, 't2'),
  ];

  /// 逐行写入（与 _import 的通用路径同口径）。
  Future<void> writeOne(_Spec s) async {
    await txnRepo.add(
      bookId: 'default',
      type: s.type,
      amountMinor: s.amount,
      accountId: s.accountId,
      toAccountId: s.toAccountId,
      occurredAt: 1700000000000,
      note: s.note,
    );
  }

  /// 生产代码同构：一个外层事务 + 分块循环 + 块间让出事件循环。
  Future<void> writeBatched(List<_Spec> list, {int chunk = 2}) async {
    await db.transaction<void>(() async {
      for (int start = 0; start < list.length; start += chunk) {
        final int end =
            start + chunk < list.length ? start + chunk : list.length;
        for (int i = start; i < end; i++) {
          await writeOne(list[i]);
        }
        // 与 _import 一致：每批让出事件循环刷新进度条。
        await Future.delayed(Duration.zero);
      }
    });
  }

  /// 取某账户的全部流水（按 note 升序）。
  Future<List<Transaction>> txnsOf(String accId) =>
      (db.select(db.transactions)
            ..where((t) => t.accountId.equals(accId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.note),
            ]))
          .get();

  test('外层事务包裹逐行 add ≡ 逐行独立事务（流水/余额/同步队列全等价）', () async {
    final String a1 = await addAccount('甲-逐行', AccountType.cash);
    final String b1 = await addAccount('乙-逐行', AccountType.cash);
    final String a2 = await addAccount('甲-事务', AccountType.cash);
    final String b2 = await addAccount('乙-事务', AccountType.cash);
    // bootstrap 种子本身会入队若干同步操作，期望值一律按基线相对计量。
    final int queueBefore = await db.pendingOpsDao.watchCount().first;

    // 批 1：逐行独立事务（原实现）。
    for (final _Spec s in specs(a1, b1)) {
      await writeOne(s);
    }
    // 批 2：外层事务包裹（优化后）——同一连接、同一批数据。
    await writeBatched(specs(a2, b2));

    // 每个账户 3 笔（支出/收入/转账的一方），两批各一套。
    expect((await txnsOf(a1)).length, 3);
    expect((await txnsOf(b1)).length, 3);
    expect((await txnsOf(a2)).length, 3);
    expect((await txnsOf(b2)).length, 3);

    // 逐字段比对：同 note 的两笔（逐行批 / 事务批各一笔）必须完全一致。
    final List<Transaction> all =
        await (db.select(db.transactions)
              ..orderBy([
                (t) => OrderingTerm.asc(t.note),
              ]))
            .get();
    final Map<String, List<Transaction>> byNote =
        <String, List<Transaction>>{};
    for (final Transaction t in all) {
      byNote.putIfAbsent(t.note ?? '', () => <Transaction>[]).add(t);
    }
    for (final MapEntry<String, List<Transaction>> e in byNote.entries) {
      expect(e.value.length, 2, reason: 'note=${e.key} 应有两批各一笔');
      final Transaction x = e.value[0];
      final Transaction y = e.value[1];
      expect(y.type, x.type);
      expect(y.amountMinor, x.amountMinor);
      expect(y.toAccountId == null, x.toAccountId == null);
      expect(y.occurredAt, x.occurredAt);
      expect(y.discountMinor, x.discountMinor);
      expect(y.feeMinor, x.feeMinor);
      expect(y.subcategory, x.subcategory);
      expect(y.isReimbursable, x.isReimbursable);
    }

    // 余额等价：两批同名账户的余额必须逐分相同。
    // 甲：e1 -100、i1 +250、t1 转出 -300、t2 转入 +50 = -100
    // 乙：t1 转入 +300、e2 -199、i2 +1、t2 转出 -50 = 52
    final List<Account> accs = await db.select(db.accounts).get();
    final Map<String, int> bal = <String, int>{};
    for (final Account a in accs) {
      bal[a.id] = a.balanceMinor;
    }
    expect(bal[a1], -100);
    expect(bal[a2], -100);
    expect(bal[b1], 52);
    expect(bal[b2], 52);

    // 同步队列等价：12 笔 → 基线上 +12 条待同步（事务批没有少写也没有多写）。
    expect(await db.pendingOpsDao.watchCount().first, queueBefore + 12);
  });

  test('外层事务中途抛错 → 整体回滚（不留孤儿流水/队列/错误余额）', () async {
    final String a = await addAccount('甲', AccountType.cash);
    final String b = await addAccount('乙', AccountType.cash);
    final List<_Spec> list = specs(a, b);
    final int queueBefore = await db.pendingOpsDao.watchCount().first;

    await expectLater(
      db.transaction<void>(() async {
        for (int i = 0; i < list.length; i++) {
          await writeOne(list[i]);
          if (i == 2) throw StateError('模拟导入中途崩溃');
        }
      }),
      throwsStateError,
    );

    expect(await db.select(db.transactions).get(), isEmpty);
    expect(await db.pendingOpsDao.watchCount().first, queueBefore);
    final List<Account> accs = await db.select(db.accounts).get();
    for (final Account acc in accs) {
      expect(acc.balanceMinor, 0, reason: '${acc.name} 余额应回滚为 0');
    }
  });

  test('事务内跨 await（进度让出）后继续写入仍属同一事务', () async {
    final String a = await addAccount('甲', AccountType.cash);
    final String b = await addAccount('乙', AccountType.cash);
    final List<_Spec> list = specs(a, b);
    final int queueBefore = await db.pendingOpsDao.watchCount().first;

    await db.transaction<void>(() async {
      for (int i = 0; i < list.length; i++) {
        await writeOne(list[i]);
        if (i == 2) {
          // 进度刷新点：让出事件循环（模拟 setState + Future.delayed）。
          await Future.delayed(Duration.zero);
          await Future.delayed(const Duration(milliseconds: 1));
        }
      }
    });

    expect((await db.select(db.transactions).get()).length, list.length);
    expect(await db.pendingOpsDao.watchCount().first, queueBefore + list.length);
  });
}

/// 一笔写入规格（测试内部用）。
class _Spec {
  _Spec(this.type, this.amount, this.accountId, this.toAccountId, this.note);

  final TxnType type;
  final int amount;
  final String accountId;
  final String? toAccountId;
  final String note;
}
