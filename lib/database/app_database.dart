import 'package:drift/drift.dart';

import '../domain/enums.dart';
import 'connection/connection.dart';
import 'daos/accounts_dao.dart';
import 'daos/books_dao.dart';
import 'daos/categories_dao.dart';
import 'daos/pending_ops_dao.dart';
import 'daos/transactions_dao.dart';
import 'tables.dart';

/// 注意：[AppDatabase] 是 `app_database.g.dart` 的宿主文件，
/// 而 part 文件**继承宿主的 import**（自身不带 import 段）。
/// 因此这里必须显式导入 `domain/enums.dart` —— 仅靠 `tables.dart`
/// 内部的 import 是不够的（import 不具传递性），否则生成代码里的
/// `AccountType` / `TxnType` 等枚举会全部报 "Type not found"。
///
/// 这里只 import 不 export：`SyncState` 在 `sync/sync_engine.dart` 中
/// 另有一个同名类，一旦对外导出就会让引用方出现 "imported from both" 冲突。
export 'tables.dart';

part 'app_database.g.dart';

/// 本地主数据库。
///
/// 所有 UI 读取**只走本地**，网络同步由独立的 SyncEngine 异步负责。
/// 因此应用在完全离线的情况下依然是一个功能完整的记账工具。
@DriftDatabase(
  tables: <Type>[
    Books,
    Accounts,
    Categories,
    Transactions,
    LendRecords,
    Reimbursements,
    SavingsGoals,
    InstallmentPlans,
    InstallmentPeriods,
    Budgets,
    InvestmentHoldings,
    InventoryItems,
    RecordTemplates,
    PendingOps,
  ],
  daos: <Type>[
    BooksDao,
    AccountsDao,
    CategoriesDao,
    TransactionsDao,
    PendingOpsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// 打开加密数据库。密码为空时表示不启用加密（仅开发调试用）。
  AppDatabase.open({required String password})
      : super(
          openEncryptedDatabase(
            name: 'pocket_ledger.db',
            password: password,
          ),
        );

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _createIndexes();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // 每个版本必须在此追加 step-by-step 迁移。
          //
          // ⚠️ 所有迁移步骤都必须是**幂等**的。踩过的坑：v2 用 `m.addColumn`
          // 无条件发 ALTER TABLE，而开发机上早就用「已含该列的 tables.dart」
          // 建过 v1 库（列已在、但 user_version 仍是 1），于是升级到 v2 时抛
          // `SqliteException(1): duplicate column name` → 迁移事务回滚 →
          // `bootstrapData` 抛异常 → `main()` 中断 → `runApp` 永不执行 →
          // App 永远停在 Flutter 启动图（且每次冷启都会重试、再次失败）。
          if (from < 2) {
            // v2：报销表新增「不计入收支」开关列。
            await _addColumnIfMissing(
              m,
              reimbursements,
              reimbursements.excludeFromStats,
            );
          }

          if (from < 3) {
            // v3：账户表扩展字段。
            await _addColumnIfMissing(m, accounts, accounts.note);
            await _addColumnIfMissing(m, accounts, accounts.cardNumber);
            await _addColumnIfMissing(m, accounts, accounts.status);
            await _addColumnIfMissing(m, accounts, accounts.includeInTotal);
          }

          if (from < 4) {
            // v4：转账新增手续费 / 优惠字段，用于精确回滚余额。
            await _addColumnIfMissing(
              m,
              transactions,
              transactions.feeMinor,
            );
            await _addColumnIfMissing(
              m,
              transactions,
              transactions.discountMinor,
            );
          }

          if (from < 5) {
            // v5：借还新增资产账户 / 利息 / 优惠字段。
            await _addColumnIfMissing(
              m,
              lendRecords,
              lendRecords.toAccountId,
            );
            await _addColumnIfMissing(
              m,
              lendRecords,
              lendRecords.feeMinor,
            );
            await _addColumnIfMissing(
              m,
              lendRecords,
              lendRecords.discountMinor,
            );
          }

          if (from < 6) {
            // v6：报销新增报销账户 / 收款账户字段。
            await _addColumnIfMissing(
              m,
              reimbursements,
              reimbursements.accountId,
            );
            await _addColumnIfMissing(
              m,
              reimbursements,
              reimbursements.toAccountId,
            );
          }

          if (from < 7) {
            // v7：流水新增「不计收支 / 不计预算 / 报销标记」三个开关列。
            await _addColumnIfMissing(
              m,
              transactions,
              transactions.excludeFromStats,
            );
            await _addColumnIfMissing(
              m,
              transactions,
              transactions.excludeFromBudget,
            );
            await _addColumnIfMissing(
              m,
              transactions,
              transactions.isReimbursable,
            );
          }

          if (from < 8) {
            // v8：新增本地「记一笔模板」表（不参与云端同步）。
            await _createTableIfMissing(m, recordTemplates);
          }

          // 索引在 onCreate 里创建；升级路径同样要补齐，且必须幂等
          // （旧库若已建过索引，重复 CREATE INDEX 也会报 already exists）。
          await _createIndexes();
        },
        beforeOpen: (OpeningDetails details) async {
          // 启用外键约束，保证账户与流水的引用完整性
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// 幂等加列：先探测列是否已存在，不存在才 `ADD COLUMN`。
  ///
  /// drift 的 [Migrator.addColumn] 是无条件 `ALTER TABLE ... ADD COLUMN`，
  /// 列已存在时 SQLite 会直接报 `duplicate column name`。开发期反复改
  /// schema 时极易踩到，见 [migration] 里的详细说明。
  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo<Table, dynamic> table,
    GeneratedColumn column,
  ) async {
    // PRAGMA table_info 在 SQLite 全版本可用，返回 name/type/notnull 等列信息。
    // 注意用 `this.customSelect`（AppDatabase 自身）而不是 `m.database`。
    final List<QueryRow> info = await customSelect(
      'PRAGMA table_info(${table.actualTableName})',
    ).get();
    final bool exists =
        info.any((QueryRow row) => row.read<String>('name') == column.name);
    if (!exists) {
      await m.addColumn(table, column);
    }
  }

  /// 幂等建表：先探测表是否已存在，不存在才 `CREATE TABLE`。
  ///
  /// 用于「新增整张表」的版本迁移（[ _addColumnIfMissing] 只处理加列）。
  /// 升级路径只会跑一次，但仍做存在性探测，避免重复 CREATE TABLE 报错，
  /// 也方便 `createCurrentSchema` 这类测试反复重建时不踩坑。
  Future<void> _createTableIfMissing(
    Migrator m,
    TableInfo<Table, dynamic> table,
  ) async {
    final List<QueryRow> info = await customSelect(
      'SELECT name FROM sqlite_master '
      'WHERE type = \'table\' AND name = \'${table.actualTableName}\'',
    ).get();
    if (info.isEmpty) {
      await m.createTable(table);
    }
  }

  /// 创建索引。
  ///
  /// 前 3 个索引决定列表与报表的查询速度；
  /// 最后一个部分索引让同步队列扫描只覆盖待同步行，避免全表扫描。
  ///
  /// 一律用 `IF NOT EXISTS`：本方法同时被 [migration] 的 onCreate 与
  /// onUpgrade 调用，重复执行必须是安全的。
  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_txn_book_date '
      'ON transactions(book_id, occurred_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_txn_account_date '
      'ON transactions(book_id, account_id, occurred_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_txn_category_date '
      'ON transactions(book_id, category_id, occurred_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_txn_dirty '
      'ON transactions(dirty) WHERE dirty = 1',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_accounts_book '
      'ON accounts(book_id, sort_order)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_categories_book '
      'ON categories(book_id, type, sort_order)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pending_ops_seq '
      'ON pending_ops(local_seq)',
    );
  }
}
