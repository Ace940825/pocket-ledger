import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pocket_ledger/core/bootstrap.dart';
import 'package:pocket_ledger/core/utils/date_utils.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/budget/data/budget_repository.dart';
import 'package:pocket_ledger/features/budget/providers/budget_providers.dart';
import 'package:pocket_ledger/features/categories/providers/categories_providers.dart';
import 'package:pocket_ledger/providers/app_providers.dart';

/// 首页预算模块卡汇总口径（第 32 批：修「月年累计 + 收支混计」）。
///
/// 用户实证：10 月支出总预算 10,000 + 2026 年收入目标 1,000，旧 provider
/// Σ 全部预算行（不分月/年、不分支出/收入）→ 首页卡显示 11,000。
/// 新口径：只取**当月月度**预算行，按方向分（支出=overall+支出分类，
/// 收入=收入分类），与预算主页「N月预算」月视图同口径。
void main() {
  late AppDatabase db;
  late BudgetRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await bootstrapData(db);
    repo = BudgetRepository(db);
  });

  tearDown(() => db.close());

  /// 自建一个现金账户并返回其 id。
  /// 第 34 批起 bootstrap 不再预置账户（用户要求「不预置账户」），
  /// 需要账户的测试自建。
  Future<String> newAccount() async {
    const String id = 'acc-cash';
    await db.accountsDao.insertAccount(
      const AccountsCompanion(
        id: Value<String>(id),
        bookId: Value<String>('default'),
        name: Value<String>('现金'),
        type: Value<AccountType>(AccountType.cash),
        updatedAt: Value<int>(0),
      ),
    );
    return id;
  }

  /// 建容器并等依赖流（预算行/分类/已用）首发完成，再读同步汇总值。
  ///
  /// monthBudgetSummaryProvider 是同步 Provider，watch 的三个流都是异步
  /// 发射——必须先 listen 保住 autoDispose 家族不被回收，再逐个 await
  /// `.future`，最后读同步值才是新鲜数据。
  Future<({BudgetSummary expense, BudgetSummary income})> readSummaries({
    required List<BudgetSpentKey> spentKeys,
  }) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    container.listen(
      monthBudgetSummaryProvider(CategoryType.expense),
      (_, __) {},
      fireImmediately: true,
    );
    container.listen(
      monthBudgetSummaryProvider(CategoryType.income),
      (_, __) {},
      fireImmediately: true,
    );
    await container.read(budgetListProvider.future);
    await container.read(allCategoriesProvider.future);
    for (final BudgetSpentKey key in spentKeys) {
      await container.read(budgetSpentProvider(key).future);
    }
    return (
      expense: container.read(
        monthBudgetSummaryProvider(CategoryType.expense),
      ),
      income: container.read(
        monthBudgetSummaryProvider(CategoryType.income),
      ),
    );
  }

  test('当月月度 + 方向分流：年/季/上月不累计，收入目标不进支出卡', () async {
    final List<Category> cats = await db.select(db.categories).get();
    final Category expenseCat = cats.firstWhere(
      (Category c) => c.type == CategoryType.expense && !c.deleted,
    );
    final Category incomeCat = cats.firstWhere(
      (Category c) => c.type == CategoryType.income && !c.deleted,
    );
    final String accountId = await newAccount();

    final DateTime now = DateTime.now();
    final int year = now.year;
    final int month = now.month;
    // 上月（跨年安全）：1 月 → 去年 12 月。
    final int lastMonth = month == 1 ? 12 : month - 1;
    final int lastYear = month == 1 ? year - 1 : year;

    // 预算行（分）：
    // ① 当月 支出分类 100000——支出卡计入
    // ② 当月 收入分类目标 30000——收入卡计入
    // ③ 年度 收入目标 100000——**不在月度卡累计**（第 32 批核心）
    // ④ 上月 支出分类 99999——非当月，排除
    await repo.add(
      bookId: 'default',
      scope: BudgetScope.category,
      period: BudgetPeriod.monthly,
      amountMinor: 100000,
      year: year,
      periodIndex: month,
      categoryId: expenseCat.id,
    );
    await repo.add(
      bookId: 'default',
      scope: BudgetScope.category,
      period: BudgetPeriod.monthly,
      amountMinor: 30000,
      year: year,
      periodIndex: month,
      categoryId: incomeCat.id,
    );
    await repo.add(
      bookId: 'default',
      scope: BudgetScope.category,
      period: BudgetPeriod.yearly,
      amountMinor: 100000,
      year: year,
      periodIndex: 0,
      categoryId: incomeCat.id,
    );
    await repo.add(
      bookId: 'default',
      scope: BudgetScope.category,
      period: BudgetPeriod.monthly,
      amountMinor: 99999,
      year: lastYear,
      periodIndex: lastMonth,
      categoryId: expenseCat.id,
    );

    // 当月流水：支出 40000（支出分类）、收入 15000（收入分类）。
    final int occurredAt =
        DateTime(year, month, 15).toUtc().millisecondsSinceEpoch;
    await db.transactionsDao.insertTx(
      TransactionsCompanion(
        id: const Value<String>('txn-exp-1'),
        bookId: const Value<String>('default'),
        type: const Value<TxnType>(TxnType.expense),
        amountMinor: const Value<int>(40000),
        accountId: Value<String>(accountId),
        occurredAt: Value<int>(occurredAt),
        categoryId: Value<String?>(expenseCat.id),
        sourceModule: const Value<SourceModule>(SourceModule.ledger),
        updatedAt: const Value<int>(0),
      ),
    );
    await db.transactionsDao.insertTx(
      TransactionsCompanion(
        id: const Value<String>('txn-inc-1'),
        bookId: const Value<String>('default'),
        type: const Value<TxnType>(TxnType.income),
        amountMinor: const Value<int>(15000),
        accountId: Value<String>(accountId),
        occurredAt: Value<int>(occurredAt),
        categoryId: Value<String?>(incomeCat.id),
        sourceModule: const Value<SourceModule>(SourceModule.ledger),
        updatedAt: const Value<int>(0),
      ),
    );

    final ({int start, int end}) range = budgetRange(
      year: year,
      periodIndex: month,
      monthly: true,
      quarterly: false,
    );
    final ({BudgetSummary expense, BudgetSummary income}) s =
        await readSummaries(
      spentKeys: <BudgetSpentKey>[
        (
          start: range.start,
          end: range.end,
          categoryId: expenseCat.id,
          type: TxnType.expense,
        ),
        (
          start: range.start,
          end: range.end,
          categoryId: incomeCat.id,
          type: TxnType.income,
        ),
      ],
    );

    // 支出卡：只含当月支出分类行（100000），已用 = 当月该分类支出。
    expect(s.expense.total, 100000, reason: '年/季/上月预算行不累计');
    expect(s.expense.spent, 40000);
    expect(s.expense.remaining, 60000);
    // 收入卡：只含当月收入目标行（30000），年度 100000 不累计。
    expect(s.income.total, 30000, reason: '年度收入目标不进月度卡');
    expect(s.income.spent, 15000, reason: '已得 = 当月该分类收入流水');
    expect(s.income.remaining, 15000);
  });

  test('overall 行走支出口径：已用=当月全部支出，收入流水不计入', () async {
    final String accountId = await newAccount();
    final DateTime now = DateTime.now();
    final int year = now.year;
    final int month = now.month;

    await repo.add(
      bookId: 'default',
      scope: BudgetScope.overall,
      period: BudgetPeriod.monthly,
      amountMinor: 100000,
      year: year,
      periodIndex: month,
    );

    final int occurredAt =
        DateTime(year, month, 15).toUtc().millisecondsSinceEpoch;
    // 支出 40000（无分类）；收入 99999——不得计入支出卡「已用」。
    await db.transactionsDao.insertTx(
      TransactionsCompanion(
        id: const Value<String>('txn-exp-1'),
        bookId: const Value<String>('default'),
        type: const Value<TxnType>(TxnType.expense),
        amountMinor: const Value<int>(40000),
        accountId: Value<String>(accountId),
        occurredAt: Value<int>(occurredAt),
        sourceModule: const Value<SourceModule>(SourceModule.ledger),
        updatedAt: const Value<int>(0),
      ),
    );
    await db.transactionsDao.insertTx(
      TransactionsCompanion(
        id: const Value<String>('txn-inc-1'),
        bookId: const Value<String>('default'),
        type: const Value<TxnType>(TxnType.income),
        amountMinor: const Value<int>(99999),
        accountId: Value<String>(accountId),
        occurredAt: Value<int>(occurredAt),
        sourceModule: const Value<SourceModule>(SourceModule.ledger),
        updatedAt: const Value<int>(0),
      ),
    );

    final ({int start, int end}) range = budgetRange(
      year: year,
      periodIndex: month,
      monthly: true,
      quarterly: false,
    );
    final ({BudgetSummary expense, BudgetSummary income}) s =
        await readSummaries(
      spentKeys: <BudgetSpentKey>[
        (
          start: range.start,
          end: range.end,
          categoryId: null,
          type: TxnType.expense,
        ),
      ],
    );

    expect(s.expense.total, 100000, reason: 'overall 行按支出口径计入');
    expect(s.expense.spent, 40000, reason: '已用=当月全部支出（收入流水不计）');
    // 无收入目标行 → 收入卡空态（首页显示「本月未设置收入目标」）。
    expect(s.income.total, 0);
    expect(s.income.spent, 0);
  });
}
