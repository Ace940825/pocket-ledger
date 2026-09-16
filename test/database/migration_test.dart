import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pocket_ledger/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

/// 数据库迁移回归测试。
///
/// 复现并锁死的真实事故：开发机上存在一个「**列已经有了、但 `user_version`
/// 还是 1**」的库（因为曾用带该列的 `tables.dart` 建过 v1 库），此时 v2 迁移
/// 里的无条件 `ALTER TABLE ... ADD COLUMN` 会抛
/// `SqliteException(1): duplicate column name` → 迁移事务回滚 →
/// `bootstrapData` 抛异常 → `main()` 中断 → `runApp` 永不执行 →
/// **App 永远停在 Flutter 启动图，且每次冷启都重试再失败**。
void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pl_migration_test');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  String dbPath() => p.join(tmp.path, 'pocket_ledger.db');

  /// 用当前 schema 建一个完整库（此时 user_version = schemaVersion）。
  Future<void> createCurrentSchema() async {
    final AppDatabase db = AppDatabase(NativeDatabase(File(dbPath())));
    await db.booksDao.watchAll().first; // 触发懒打开 + onCreate
    await db.close();
  }

  /// 直接把 user_version 改成 1，模拟「版本号落后」的库。
  void forceUserVersion(int version) {
    final raw.Database db = raw.sqlite3.open(dbPath());
    db.execute('PRAGMA user_version = $version');
    db.dispose();
  }

  List<String> columnsOf(String table) {
    final raw.Database db = raw.sqlite3.open(dbPath());
    final List<String> names = db
        .select('PRAGMA table_info($table)')
        .map((raw.Row r) => r['name'] as String)
        .toList();
    db.dispose();
    return names;
  }

  List<String> reimbursementColumns() => columnsOf('reimbursements');

  List<String> transactionColumns() => columnsOf('transactions');

  int userVersion() {
    final raw.Database db = raw.sqlite3.open(dbPath());
    final int v = db.select('PRAGMA user_version').first.values.first! as int;
    db.dispose();
    return v;
  }

  bool tableExists(String name) {
    final raw.Database db = raw.sqlite3.open(dbPath());
    final int n = db
        .select(
          "SELECT count(*) AS c FROM sqlite_master "
          "WHERE type = 'table' AND name = '$name'",
        )
        .first['c'] as int;
    db.dispose();
    return n > 0;
  }

  int indexCount() {
    final raw.Database db = raw.sqlite3.open(dbPath());
    final int n = db
        .select(
          "SELECT count(*) AS c FROM sqlite_master WHERE type = 'index' "
          "AND name LIKE 'idx_%'",
        )
        .first['c'] as int;
    db.dispose();
    return n;
  }

  test('列已存在但 user_version=1 的破损库应能自愈（核心回归）', () async {
    await createCurrentSchema();
    forceUserVersion(1);

    expect(
      reimbursementColumns(),
      contains('exclude_from_stats'),
      reason: '前置条件：列已经在，只是版本号落后',
    );

    // 关键断言：打开不应抛异常（修复前这里抛 duplicate column name）。
    final AppDatabase db = AppDatabase(NativeDatabase(File(dbPath())));
    await expectLater(db.booksDao.watchAll().first, completes);
    await db.close();

    expect(userVersion(), 9, reason: '迁移成功后 user_version 必须推进到 9');
  });

  test('升级路径也必须补齐索引（且幂等）', () async {
    await createCurrentSchema();
    final int before = indexCount();
    expect(before, greaterThan(0), reason: 'onCreate 应已建好索引');

    forceUserVersion(1);

    final AppDatabase db = AppDatabase(NativeDatabase(File(dbPath())));
    await db.booksDao.watchAll().first; // 走 onUpgrade → 再次调用 _createIndexes
    await db.close();

    // 幂等：重复执行不抛错、数量不变（说明用的是 IF NOT EXISTS）。
    expect(indexCount(), before);
  });

  test('v6 库缺 transactions 三列时升级到 v7 会补上', () async {
    await createCurrentSchema();

    // 模拟已发布 v6 库：transactions 表已有 v7 三列，但 user_version 仍是 6。
    final raw.Database rawDb = raw.sqlite3.open(dbPath());
    rawDb.execute(
      'ALTER TABLE transactions DROP COLUMN exclude_from_stats',
    );
    rawDb.execute(
      'ALTER TABLE transactions DROP COLUMN exclude_from_budget',
    );
    rawDb.execute(
      'ALTER TABLE transactions DROP COLUMN is_reimbursable',
    );
    rawDb.execute('PRAGMA user_version = 6');
    rawDb.dispose();

    expect(transactionColumns(), isNot(contains('exclude_from_stats')));
    expect(transactionColumns(), isNot(contains('exclude_from_budget')));
    expect(transactionColumns(), isNot(contains('is_reimbursable')));

    final AppDatabase db = AppDatabase(NativeDatabase(File(dbPath())));
    await db.booksDao.watchAll().first;
    await db.close();

    expect(transactionColumns(), contains('exclude_from_stats'));
    expect(transactionColumns(), contains('exclude_from_budget'));
    expect(transactionColumns(), contains('is_reimbursable'));
    expect(userVersion(), 9, reason: 'v6→v9 升级后 user_version 必须推进到 9');
    // v8 迁移同时补齐本地模板表。
    expect(tableExists('record_templates'), isTrue);
  });

  test('新建库（user_version=0）走 onCreate，不应触发迁移', () async {
    final AppDatabase db = AppDatabase(NativeDatabase(File(dbPath())));
    await db.booksDao.watchAll().first;
    await db.close();

    expect(userVersion(), 9);
    expect(reimbursementColumns(), contains('exclude_from_stats'));
    expect(transactionColumns(), contains('exclude_from_stats'));
    expect(transactionColumns(), contains('exclude_from_budget'));
    expect(transactionColumns(), contains('is_reimbursable'));
    expect(tableExists('record_templates'), isTrue);
  });

  test('v9 升级为 installment_plans 补齐 fee_by_period_minor 列', () async {
    await createCurrentSchema();

    // 模拟已发布 v8 库：分期计划表还没有 v9 新增的利息明细数组列。
    final raw.Database rawDb = raw.sqlite3.open(dbPath());
    rawDb.execute(
      'ALTER TABLE installment_plans DROP COLUMN fee_by_period_minor',
    );
    rawDb.execute('PRAGMA user_version = 8');
    rawDb.dispose();

    expect(
      columnsOf('installment_plans'),
      isNot(contains('fee_by_period_minor')),
      reason: '前置：v8 库不应有该列',
    );

    final AppDatabase db = AppDatabase(NativeDatabase(File(dbPath())));
    await db.booksDao.watchAll().first; // 走 v8→v9 onUpgrade
    await db.close();

    expect(userVersion(), 9);
    expect(
      columnsOf('installment_plans'),
      contains('fee_by_period_minor'),
      reason: 'v9 迁移必须补齐每期利息明细列',
    );
  });
}
