import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pocket_ledger/core/bootstrap.dart';
import 'package:pocket_ledger/core/errors/failures.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/budget/data/budget_repository.dart';

/// 预算仓储校验语义（第 31 批：「添加一级分类时可以不填金额」）。
///
/// 一级分类金额 = Σ名下二级分类（总闸制）：不填金额的一级分类落 0 金额
/// **占位行**——分组可见、可进内添加二级目标，展示按二级合计自动汇总
/// （UI 层 _BudgetGroupData.effectiveMinor 的 0 回退）。故 0 金额在仓储
/// 层必须合法；负值仍拒绝。二级分类行由编辑器强制填正数
/// （budget_editor 的 amountOptional 只对一级新增放行）。
void main() {
  late AppDatabase db;
  late BudgetRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await bootstrapData(db);
    repo = BudgetRepository(db);
  });

  tearDown(() => db.close());

  test('add：0 金额占位行合法，负值抛 ValidationFailure', () async {
    final List<Category> cats = await db.select(db.categories).get();
    final Category cat = cats.firstWhere(
      (Category c) => c.type == CategoryType.expense && !c.deleted,
    );
    final String bookId = (await db.select(db.books).get()).first.id;

    final String id = await repo.add(
      bookId: bookId,
      scope: BudgetScope.category,
      period: BudgetPeriod.monthly,
      amountMinor: 0,
      year: 2026,
      periodIndex: 10,
      categoryId: cat.id,
    );
    final Budget? row = await (db.select(db.budgets)
          ..where((Budgets t) => t.id.equals(id)))
        .getSingleOrNull();
    expect(row?.amountMinor, 0, reason: '0 金额占位行正常落库');

    expect(
      () => repo.add(
        bookId: bookId,
        scope: BudgetScope.category,
        period: BudgetPeriod.monthly,
        amountMinor: -1,
        year: 2026,
        periodIndex: 10,
        categoryId: cat.id,
      ),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('update：改 0 合法（总闸→自动汇总可逆），负值抛 ValidationFailure', () async {
    final List<Category> cats = await db.select(db.categories).get();
    final Category cat = cats.firstWhere(
      (Category c) => c.type == CategoryType.expense && !c.deleted,
    );
    final String bookId = (await db.select(db.books).get()).first.id;

    final String id = await repo.add(
      bookId: bookId,
      scope: BudgetScope.category,
      period: BudgetPeriod.monthly,
      amountMinor: 50000,
      year: 2026,
      periodIndex: 10,
      categoryId: cat.id,
    );

    await repo.update(
      id: id,
      scope: BudgetScope.category,
      period: BudgetPeriod.monthly,
      amountMinor: 0,
      year: 2026,
      periodIndex: 10,
      categoryId: cat.id,
    );
    final Budget? row = await (db.select(db.budgets)
          ..where((Budgets t) => t.id.equals(id)))
        .getSingleOrNull();
    expect(row?.amountMinor, 0, reason: '总闸行可改回 0 占位（自动汇总）');

    expect(
      () => repo.update(
        id: id,
        scope: BudgetScope.category,
        period: BudgetPeriod.monthly,
        amountMinor: -5,
        year: 2026,
        periodIndex: 10,
        categoryId: cat.id,
      ),
      throwsA(isA<ValidationFailure>()),
    );
  });
}
