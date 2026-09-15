import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pocket_ledger/core/errors/failures.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/ledger/data/transaction_repository.dart';
import 'package:pocket_ledger/features/lend/data/lend_repository.dart';

/// [LendRepository.repay]（还债 / 收债）冲销行为的回归测试（真 SQLite，内存库）。
///
/// 锁死核心不变量：
/// 1. **repay 不新增借还记录**，只冲减该对方名下未结清债务的
///    [LendRecords.repaidMinor]，足量时转「已结清(settled)」；超额 / 无匹配均抛错；
/// 2. 给定 [accountId] 时，repay 同时写一条真实现金流水，让账户余额随之变化，
///    且与冲销处于同一事务（报错则两者都不落库）。
void main() {
  late AppDatabase db;
  late LendRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LendRepository(db, TransactionRepository(db));
  });

  tearDown(() => db.close());

  Future<String> addDebt(
    LendDirection dir,
    String cp,
    int amount,
    int occurredAt,
  ) =>
      repo.add(
        bookId: 'b1',
        direction: dir,
        status: LendStatus.ongoing,
        counterparty: cp,
        amountMinor: amount,
        occurredAt: occurredAt,
      );

  Future<List<LendRecord>> all() => db.select(db.lendRecords).get();

  test('还债 / 收债 冲销单笔未结清债务，足额转已结清', () async {
    await addDebt(LendDirection.lendOut, '小明', 1000, 1000);

    await repo.repay(
      bookId: 'b1',
      direction: LendDirection.lendOut,
      counterparty: '小明',
      amountMinor: 600,
      occurredAt: 2000,
    );
    LendRecord r = (await all()).first;
    expect(r.repaidMinor, 600);
    expect(r.status, LendStatus.ongoing);

    await repo.repay(
      bookId: 'b1',
      direction: LendDirection.lendOut,
      counterparty: '小明',
      amountMinor: 400,
      occurredAt: 3000,
    );
    r = (await all()).first;
    expect(r.repaidMinor, 1000);
    expect(r.status, LendStatus.settled);

    // 不新增记录：始终只有最初那一条。
    expect((await all()).length, 1);
  });

  test('还款金额超过剩余未结清债务时抛错，且不改动任何记录', () async {
    await addDebt(LendDirection.borrowIn, '小红', 500, 1000);

    expect(
      () => repo.repay(
        bookId: 'b1',
        direction: LendDirection.borrowIn,
        counterparty: '小红',
        amountMinor: 600,
        occurredAt: 2000,
      ),
      throwsA(isA<ValidationFailure>()),
    );

    final LendRecord r = (await all()).first;
    expect(r.repaidMinor, 0, reason: '超额还款不应改动任何记录');
  });

  test('没有可冲销的未结清债务时抛错', () async {
    expect(
      () => repo.repay(
        bookId: 'b1',
        direction: LendDirection.lendOut,
        counterparty: '不存在',
        amountMinor: 100,
        occurredAt: 1,
      ),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('多笔债务按发生时间从早到晚 FIFO 冲销', () async {
    await addDebt(LendDirection.lendOut, '小刚', 300, 1000); // 先发生
    await addDebt(LendDirection.lendOut, '小刚', 500, 2000); // 后发生

    await repo.repay(
      bookId: 'b1',
      direction: LendDirection.lendOut,
      counterparty: '小刚',
      amountMinor: 800,
      occurredAt: 3000,
    );

    final List<LendRecord> rs = await all();
    final LendRecord first = rs.firstWhere((LendRecord r) => r.occurredAt == 1000);
    final LendRecord second =
        rs.firstWhere((LendRecord r) => r.occurredAt == 2000);

    expect(first.repaidMinor, 300);
    expect(first.status, LendStatus.settled);
    expect(second.repaidMinor, 500);
    expect(second.status, LendStatus.settled);
    expect(rs.length, 2, reason: '两笔原始债务都还在，只是被冲销');
  });

  test('已结清债务不再参与后续冲销', () async {
    await addDebt(LendDirection.borrowIn, '阿强', 1000, 1000);
    await repo.repay(
      bookId: 'b1',
      direction: LendDirection.borrowIn,
      counterparty: '阿强',
      amountMinor: 1000,
      occurredAt: 2000,
    );

    // 再借一笔新的未结清债务。
    await addDebt(LendDirection.borrowIn, '阿强', 200, 3000);

    await repo.repay(
      bookId: 'b1',
      direction: LendDirection.borrowIn,
      counterparty: '阿强',
      amountMinor: 150,
      occurredAt: 4000,
    );

    final LendRecord oldDebt =
        (await all()).firstWhere((LendRecord r) => r.occurredAt == 1000);
    final LendRecord newDebt =
        (await all()).firstWhere((LendRecord r) => r.occurredAt == 3000);
    expect(oldDebt.repaidMinor, 1000, reason: '已结清债务保持不动');
    expect(newDebt.repaidMinor, 150, reason: '新还款只冲销新的未结清债务');
  });

  test('不同对方互不影响：只冲销指定 counterparty', () async {
    await addDebt(LendDirection.lendOut, 'A', 1000, 1000);
    await addDebt(LendDirection.lendOut, 'B', 1000, 1000);

    await repo.repay(
      bookId: 'b1',
      direction: LendDirection.lendOut,
      counterparty: 'A',
      amountMinor: 400,
      occurredAt: 2000,
    );

    final List<LendRecord> rs = await all();
    final LendRecord a = rs.firstWhere((LendRecord r) => r.counterparty == 'A');
    final LendRecord b = rs.firstWhere((LendRecord r) => r.counterparty == 'B');
    expect(a.repaidMinor, 400);
    expect(b.repaidMinor, 0, reason: 'B 的债务不应被 A 的还款冲销');
  });

  group('收债 / 还债 同时记现金流水并改动账户余额', () {
    Future<String> addAccount(String id) async {
      await db.accountsDao.insertAccount(
        AccountsCompanion(
          id: Value<String>(id),
          bookId: const Value<String>('b1'),
          name: Value<String>(id),
          type: Value<AccountType>(AccountType.cash),
          updatedAt: const Value<int>(0),
        ),
      );
      return id;
    }

    Future<int> balanceOf(String id) async {
      final Account? a = await db.accountsDao.getById(id);
      return a?.balanceMinor ?? 0;
    }

    Future<List<Transaction>> txns() =>
        db.transactionsDao.watchRecent(bookId: 'b1', limit: 100).first;

    test('还债(借入) 写支出流水，账户余额减少', () async {
      final String acc = await addAccount('acc-repay');
      await addDebt(LendDirection.borrowIn, '小红', 500, 1000);

      await repo.repay(
        bookId: 'b1',
        direction: LendDirection.borrowIn,
        counterparty: '小红',
        amountMinor: 500,
        occurredAt: 2000,
        accountId: acc,
      );

      expect(await balanceOf(acc), -500, reason: '还债=现金流出，余额 -500');
      final List<Transaction> ts = await txns();
      expect(ts, hasLength(1), reason: '应产生 1 条现金流水');
      expect(ts.single.type, TxnType.expense, reason: '还债记支出');
      expect(ts.single.accountId, acc);
      expect(ts.single.amountMinor, 500);
      expect(ts.single.sourceModule, SourceModule.lend);

      // 借还记录仍被冲销，且不新增。
      final List<LendRecord> rs = await all();
      expect(rs.length, 1);
      expect(rs.first.repaidMinor, 500);
      expect(rs.first.status, LendStatus.settled);
    });

    test('收债(借出) 写收入流水，账户余额增加', () async {
      final String acc = await addAccount('acc-collect');
      await addDebt(LendDirection.lendOut, '小明', 800, 1000);

      await repo.repay(
        bookId: 'b1',
        direction: LendDirection.lendOut,
        counterparty: '小明',
        amountMinor: 800,
        occurredAt: 2000,
        accountId: acc,
      );

      expect(await balanceOf(acc), 800, reason: '收债=现金流入，余额 +800');
      final List<Transaction> ts = await txns();
      expect(ts, hasLength(1));
      expect(ts.single.type, TxnType.income, reason: '收债记收入');
      expect(ts.single.accountId, acc);
      expect(ts.single.amountMinor, 800);
    });

    test('找不到可冲销债务时抛错，且不产生任何现金流水 / 不动余额', () async {
      final String acc = await addAccount('acc-no');
      expect(
        () => repo.repay(
          bookId: 'b1',
          direction: LendDirection.lendOut,
          counterparty: '不存在',
          amountMinor: 100,
          occurredAt: 1,
          accountId: acc,
        ),
        throwsA(isA<ValidationFailure>()),
      );
      expect(await txns(), isEmpty, reason: '报错不应写入流水');
      expect(await balanceOf(acc), 0, reason: '报错不应改动余额');
    });
  });
}
