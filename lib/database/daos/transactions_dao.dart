import 'package:drift/drift.dart';

import '../../domain/enums.dart';


import '../app_database.dart';

part 'transactions_dao.g.dart';

/// 分类金额聚合结果（用于报表饼图与分类排行）
class CategoryTotal {
  const CategoryTotal({required this.categoryId, required this.totalMinor});

  final String categoryId;

  /// 该分类的合计金额（分），恒为正数
  final int totalMinor;
}

/// 单月收支聚合结果（用于趋势图）
class MonthTotal {
  const MonthTotal({
    required this.monthKey,
    required this.incomeMinor,
    required this.expenseMinor,
  });

  /// `yyyy-MM` 形式的月份键，便于与 UI 的月份轴对齐
  final String monthKey;

  final int incomeMinor;

  final int expenseMinor;

  /// 结余 = 收入 - 支出，可为负
  int get balanceMinor => incomeMinor - expenseMinor;
}

/// 按来源模块的聚合结果（用于模块下钻）
class ModuleTotal {
  const ModuleTotal({required this.module, required this.totalMinor});

  final SourceModule module;

  final int totalMinor;
}

/// 流水数据访问。
///
/// 所有查询都作用在本地库，**不涉及任何网络请求**。
@DriftAccessor(tables: <Type>[Transactions])
class TransactionsDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionsDaoMixin {
  TransactionsDao(super.attachedDatabase);

  /// 分页查询流水，按发生时间倒序。
  Future<List<Transaction>> page({
    required String bookId,
    int offset = 0,
    int limit = 30,
    int? startAt,
    int? endAt,
    String? accountId,
    String? categoryId,
    TxnType? type,
  }) {
    return (select(transactions)
          ..where(($TransactionsTable tbl) => _buildCondition(
                tbl,
                bookId: bookId,
                startAt: startAt,
                endAt: endAt,
                accountId: accountId,
                categoryId: categoryId,
                type: type,
              ),)
          ..orderBy([
            ($TransactionsTable tbl) => OrderingTerm.desc(tbl.occurredAt),
          ])
          ..limit(limit, offset: offset))
        .get();
  }

  /// 实时监听流水列表，本地数据变化后 UI 自动刷新。
  Stream<List<Transaction>> watchRecent({
    required String bookId,
    int limit = 30,
  }) {
    return (select(transactions)
          ..where(($TransactionsTable tbl) =>
              tbl.bookId.equals(bookId) & tbl.deleted.equals(false),)
          ..orderBy([
            ($TransactionsTable tbl) => OrderingTerm.desc(tbl.occurredAt),
          ])
          ..limit(limit))
        .watch();
  }

  Stream<Transaction?> watchById(String id) {
    return (select(transactions)
          ..where(($TransactionsTable tbl) => tbl.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<Transaction?> getById(String id) {
    return (select(transactions)
          ..where(($TransactionsTable tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  /// 区间内的收支合计（分）。[type] 决定统计收入还是支出。
  Stream<int> watchTotalInRange({
    required String bookId,
    required int startAt,
    required int endAt,
    required TxnType type,
  }) {
    final Expression<int> total = transactions.amountMinor.sum();
    return (selectOnly(transactions)
          ..addColumns(<Expression<Object>>[total])
          ..where(
            transactions.bookId.equals(bookId) &
                transactions.deleted.equals(false) &
                transactions.type.equals(type.index) &
                transactions.occurredAt.isBiggerOrEqualValue(startAt) &
                transactions.occurredAt.isSmallerThanValue(endAt),
          ))
        .map((TypedResult row) => row.read(total) ?? 0)
        .watchSingle();
  }

  /// 区间内按分类聚合，用于饼图与分类排行。
  Stream<List<CategoryTotal>> watchCategoryTotals({
    required String bookId,
    required int startAt,
    required int endAt,
    required TxnType type,
  }) {
    final Expression<int> total = transactions.amountMinor.sum();
    return (selectOnly(transactions)
          ..addColumns(<Expression<Object>>[transactions.categoryId, total])
          ..where(
            transactions.bookId.equals(bookId) &
                transactions.deleted.equals(false) &
                transactions.type.equals(type.index) &
                transactions.occurredAt.isBiggerOrEqualValue(startAt) &
                transactions.occurredAt.isSmallerThanValue(endAt),
          )
          ..groupBy(<Expression<Object>>[transactions.categoryId])
          ..orderBy(<OrderingTerm>[OrderingTerm.desc(total)]))
        .map((TypedResult row) => CategoryTotal(
              categoryId: row.read(transactions.categoryId) ?? '',
              totalMinor: row.read(total) ?? 0,
            ),)
        .watch();
  }

  /// 按自然月汇总收支，用于趋势图。
  ///
  /// 用 SQLite 的 `strftime` 在**数据库内**完成分组，只返回 N 行，
  /// 而不是把区间内所有流水取到 Dart 里再遍历 —— 数据量增长后差别很大。
  ///
  /// 关于 `%Y-%m`：occurred_at 存的是 UTC 毫秒，先除 1000 转秒，
  /// 再交给 unixepoch 解析；`localtime` 让「月份归属」符合用户所在时区
  /// （UTC 的 1 号 00:30 在东八区仍是上个月的最后一天）。
  Stream<List<MonthTotal>> watchMonthlyTotals({
    required String bookId,
    required int startAt,
    required int endAt,
  }) {
    final $TransactionsTable t = transactions;
    const Expression<String> monthKey = CustomExpression<String>(
      'strftime(\'%Y-%m\', occurred_at / 1000, \'unixepoch\', \'localtime\')',
    );
    final Expression<int> incomeSum = CustomExpression<int>(
      'SUM(CASE WHEN type = ${TxnType.income.index} '
      'THEN amount_minor ELSE 0 END)',
    );
    final Expression<int> expenseSum = CustomExpression<int>(
      'SUM(CASE WHEN type = ${TxnType.expense.index} '
      'THEN amount_minor ELSE 0 END)',
    );

    return (selectOnly(t)
          ..addColumns(<Expression<Object>>[monthKey, incomeSum, expenseSum])
          ..where(
            t.bookId.equals(bookId) &
                t.deleted.equals(false) &
                t.occurredAt.isBiggerOrEqualValue(startAt) &
                t.occurredAt.isSmallerThanValue(endAt),
          )
          ..groupBy(<Expression<Object>>[monthKey])
          ..orderBy(<OrderingTerm>[OrderingTerm.asc(monthKey)]))
        .map((TypedResult row) => MonthTotal(
              monthKey: row.read(monthKey) ?? '',
              incomeMinor: row.read(incomeSum) ?? 0,
              expenseMinor: row.read(expenseSum) ?? 0,
            ),)
        .watch();
  }

  /// 按来源模块汇总支出，用于「钱都花在哪些模块」的下钻视图。
  Stream<List<ModuleTotal>> watchModuleTotals({
    required String bookId,
    required int startAt,
    required int endAt,
    required TxnType type,
  }) {
    final $TransactionsTable t = transactions;
    final Expression<int> total = t.amountMinor.sum();

    return (selectOnly(t)
          ..addColumns(<Expression<Object>>[t.sourceModule, total])
          ..where(
            t.bookId.equals(bookId) &
                t.deleted.equals(false) &
                t.type.equals(type.index) &
                t.occurredAt.isBiggerOrEqualValue(startAt) &
                t.occurredAt.isSmallerThanValue(endAt),
          )
          ..groupBy(<Expression<Object>>[t.sourceModule])
          ..orderBy(<OrderingTerm>[OrderingTerm.desc(total)]))
        .map((TypedResult row) => ModuleTotal(
              module: SourceModule.values[row.read(t.sourceModule) ?? 0],
              totalMinor: row.read(total) ?? 0,
            ),)
        .watch();
  }

  /// 取出所有待同步的流水
  Future<List<Transaction>> dirtyTransactions({int limit = 200}) {
    return (select(transactions)
          ..where(($TransactionsTable tbl) => tbl.dirty.equals(true))
          ..limit(limit))
        .get();
  }

  Future<void> markSynced(List<String> ids, int syncedAt) {
    return (update(transactions)
          ..where(($TransactionsTable tbl) => tbl.id.isIn(ids)))
        .write(
      TransactionsCompanion(
        dirty: const Value<bool>(false),
        syncedAt: Value<int>(syncedAt),
      ),
    );
  }

  /// 写入一条流水。同步字段由调用方通过 companion 传入。
  Future<void> insertTx(TransactionsCompanion companion) {
    return into(transactions).insert(companion);
  }

  Future<bool> updateTx(TransactionsCompanion companion) {
    return update(transactions).replace(companion);
  }

  /// 软删除：物理删除无法同步到云端，必须标记后随同步推送。
  Future<int> softDelete(String id, int updatedAt) {
    return (update(transactions)
          ..where(($TransactionsTable tbl) => tbl.id.equals(id)))
        .write(
      TransactionsCompanion(
        deleted: const Value<bool>(true),
        dirty: const Value<bool>(true),
        updatedAt: Value<int>(updatedAt),
      ),
    );
  }

  Expression<bool> _buildCondition(
    $TransactionsTable tbl, {
    required String bookId,
    int? startAt,
    int? endAt,
    String? accountId,
    String? categoryId,
    TxnType? type,
  }) {
    Expression<bool> condition =
        tbl.bookId.equals(bookId) & tbl.deleted.equals(false);

    if (startAt != null) {
      condition = condition & tbl.occurredAt.isBiggerOrEqualValue(startAt);
    }
    if (endAt != null) {
      condition = condition & tbl.occurredAt.isSmallerThanValue(endAt);
    }
    if (accountId != null) {
      condition = condition & tbl.accountId.equals(accountId);
    }
    if (categoryId != null) {
      condition = condition & tbl.categoryId.equals(categoryId);
    }
    if (type != null) {
      condition = condition & tbl.type.equals(type.index);
    }
    return condition;
  }
}
