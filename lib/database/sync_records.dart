import '../sync/record_codec.dart';
import 'app_database.dart';

/// 同步专用的数据库访问层。
///
/// 为什么写成 extension 而不是 Drift DAO：注册 DAO 需要改 `@DriftDatabase(daos:)`
/// 并重新运行 build_runner；而这里的操作都是「按表名动态分派」的通用读写，
/// 用 extension 即可复用生成代码中已有的表访问器，零代码生成成本。
///
/// 12 张表共用同一套语义：
/// - [syncRowAsJson]   读整行，作为推送 payload 的唯一数据源
/// - [syncUpsert]      冲突即覆盖地写入一条云端记录
/// - [syncMarkSynced]  推送成功后清零 dirty 并打上同步时间戳
extension SyncRecordsAccess on AppDatabase {
  /// 读取本地行并序列化为 JSON。
  ///
  /// Drift 生成的 `toJson()` 键名就是 **Dart 字段名（驼峰）**，
  /// 且 `intEnum` 列已被转成 int —— 与 [RecordCodec] 的解码约定完全一致，
  /// 因此这里不需要任何手工字段映射，也不会漏字段。
  ///
  /// 所有业务表都用软删除，删除后行仍在，因此这里一定能查到；
  /// 删除语义由 payload 之外的 `deleted` 标记承载。
  Future<Map<String, Object?>?> syncRowAsJson(String table, String id) async {
    switch (table) {
      case SyncTables.books:
        final Book? row =
            await (select(books)..where((t) => t.id.equals(id)))
                .getSingleOrNull();
        return row?.toJson();
      case SyncTables.transactions:
        final Transaction? row =
            await (select(transactions)..where((t) => t.id.equals(id)))
                .getSingleOrNull();
        return row?.toJson();
      case SyncTables.accounts:
        final Account? row =
            await (select(accounts)..where((t) => t.id.equals(id)))
                .getSingleOrNull();
        return row?.toJson();
      case SyncTables.categories:
        final Category? row =
            await (select(categories)..where((t) => t.id.equals(id)))
                .getSingleOrNull();
        return row?.toJson();
      case SyncTables.lendRecords:
        final LendRecord? row =
            await (select(lendRecords)..where((t) => t.id.equals(id)))
                .getSingleOrNull();
        return row?.toJson();
      case SyncTables.reimbursements:
        final Reimbursement? row =
            await (select(reimbursements)..where((t) => t.id.equals(id)))
                .getSingleOrNull();
        return row?.toJson();
      case SyncTables.savingsGoals:
        final SavingsGoal? row =
            await (select(savingsGoals)..where((t) => t.id.equals(id)))
                .getSingleOrNull();
        return row?.toJson();
      case SyncTables.installmentPlans:
        final InstallmentPlan? row =
            await (select(installmentPlans)..where((t) => t.id.equals(id)))
                .getSingleOrNull();
        return row?.toJson();
      case SyncTables.installmentPeriods:
        final InstallmentPeriod? row =
            await (select(installmentPeriods)..where((t) => t.id.equals(id)))
                .getSingleOrNull();
        return row?.toJson();
      case SyncTables.budgets:
        final Budget? row =
            await (select(budgets)..where((t) => t.id.equals(id)))
                .getSingleOrNull();
        return row?.toJson();
      case SyncTables.investmentHoldings:
        final InvestmentHolding? row =
            await (select(investmentHoldings)..where((t) => t.id.equals(id)))
                .getSingleOrNull();
        return row?.toJson();
      case SyncTables.inventoryItems:
        final InventoryItem? row =
            await (select(inventoryItems)..where((t) => t.id.equals(id)))
                .getSingleOrNull();
        return row?.toJson();
      default:
        return null;
    }
  }

  /// 本地行的 updatedAt（UTC 毫秒）。不存在返回 null，表示本地尚无此记录。
  Future<int?> syncLocalUpdatedAt(String table, String id) async {
    final Map<String, Object?>? row = await syncRowAsJson(table, id);
    return row?['updatedAt'] as int?;
  }

  /// 把一条云端记录写入本地。使用 insertOnConflictUpdate 做 upsert，
  /// 因此无论是「本地没有的新记录」还是「本地已有的旧版本」都能一次搞定。
  Future<void> syncUpsert(String table, dynamic companion) async {
    switch (table) {
      case SyncTables.books:
        await into(books).insertOnConflictUpdate(companion as BooksCompanion);
        break;
      case SyncTables.transactions:
        await into(transactions)
            .insertOnConflictUpdate(companion as TransactionsCompanion);
        break;
      case SyncTables.accounts:
        await into(accounts)
            .insertOnConflictUpdate(companion as AccountsCompanion);
        break;
      case SyncTables.categories:
        await into(categories)
            .insertOnConflictUpdate(companion as CategoriesCompanion);
        break;
      case SyncTables.lendRecords:
        await into(lendRecords)
            .insertOnConflictUpdate(companion as LendRecordsCompanion);
        break;
      case SyncTables.reimbursements:
        await into(reimbursements)
            .insertOnConflictUpdate(companion as ReimbursementsCompanion);
        break;
      case SyncTables.savingsGoals:
        await into(savingsGoals)
            .insertOnConflictUpdate(companion as SavingsGoalsCompanion);
        break;
      case SyncTables.installmentPlans:
        await into(installmentPlans)
            .insertOnConflictUpdate(companion as InstallmentPlansCompanion);
        break;
      case SyncTables.installmentPeriods:
        await into(installmentPeriods)
            .insertOnConflictUpdate(companion as InstallmentPeriodsCompanion);
        break;
      case SyncTables.budgets:
        await into(budgets)
            .insertOnConflictUpdate(companion as BudgetsCompanion);
        break;
      case SyncTables.investmentHoldings:
        await into(investmentHoldings)
            .insertOnConflictUpdate(companion as InvestmentHoldingsCompanion);
        break;
      case SyncTables.inventoryItems:
        await into(inventoryItems)
            .insertOnConflictUpdate(companion as InventoryItemsCompanion);
        break;
      default:
        break;
    }
  }

  /// 推送成功后清零 dirty 并写入同步时间戳。
  ///
  /// 用一条原生 SQL 批量更新而不是逐表构造 Companion：
  /// 12 张表的 Companion 构造代码会让这里膨胀数倍，而语义完全相同。
  /// 表名来自 [SyncTables] 白名单常量（编译期固定），不存在注入风险。
  Future<void> syncMarkSynced(
    String table,
    List<String> ids,
    int syncedAt,
  ) async {
    if (ids.isEmpty) return;
    if (!SyncTables.all.contains(table)) return;

    final String placeholders = List<String>.filled(ids.length, '?').join(',');
    await customStatement(
      'UPDATE $table SET dirty = 0, synced_at = ? WHERE id IN ($placeholders)',
      <Object?>[syncedAt, ...ids],
    );
  }
}
