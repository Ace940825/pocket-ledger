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
      : super(openEncryptedDatabase(
          name: 'pocket_ledger.db',
          password: password,
        ),);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _createIndexes();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // 首个版本，暂无历史迁移。后续每个版本必须在此追加 step-by-step 迁移，
          // 并在迁移前自动备份数据库文件。
        },
        beforeOpen: (OpeningDetails details) async {
          // 启用外键约束，保证账户与流水的引用完整性
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// 创建索引。
  ///
  /// 前 3 个索引决定列表与报表的查询速度；
  /// 最后一个部分索引让同步队列扫描只覆盖待同步行，避免全表扫描。
  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX idx_txn_book_date '
      'ON transactions(book_id, occurred_at DESC)',
    );
    await customStatement(
      'CREATE INDEX idx_txn_account_date '
      'ON transactions(book_id, account_id, occurred_at DESC)',
    );
    await customStatement(
      'CREATE INDEX idx_txn_category_date '
      'ON transactions(book_id, category_id, occurred_at DESC)',
    );
    await customStatement(
      'CREATE INDEX idx_txn_dirty '
      'ON transactions(dirty) WHERE dirty = 1',
    );
    await customStatement(
      'CREATE INDEX idx_accounts_book ON accounts(book_id, sort_order)',
    );
    await customStatement(
      'CREATE INDEX idx_categories_book '
      'ON categories(book_id, type, sort_order)',
    );
    await customStatement(
      'CREATE INDEX idx_pending_ops_seq ON pending_ops(local_seq)',
    );
  }
}
