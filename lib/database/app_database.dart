import 'package:drift/drift.dart';

import '../domain/enums.dart';
import 'connection/connection.dart';
import 'daos/accounts_dao.dart';
import 'daos/books_dao.dart';
import 'daos/categories_dao.dart';
import 'daos/pending_ops_dao.dart';
import 'daos/tags_dao.dart';
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
    SavingsDeposits,
    InstallmentPlans,
    InstallmentPeriods,
    Budgets,
    InvestmentHoldings,
    InventoryItems,
    RecordTemplates,
    PendingOps,
    TagCategories,
    Tags,
  ],
  daos: <Type>[
    BooksDao,
    AccountsDao,
    CategoriesDao,
    TransactionsDao,
    PendingOpsDao,
    TagsDao,
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

  /// 当前数据库 schema 版本（用户态迁移目标版本）。
  ///
  /// 抽出为顶层常量，便于测试在不实例化 [AppDatabase] 的情况下引用当前版本，
  /// 避免迁移回归测试把版本号写死导致每次升级都要手动同步。
  static const int kSchemaVersion = 35;

  @override
  int get schemaVersion => kSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          // 原生 SQL 台账表必须先于索引创建：下方 [_createIndexes] 里的
          // idx_rolling_plans_goal 等直接引用这些表。
          // 踩坑（2026-10-16）：_createIndexes 曾排在 _ensureRollingPlansTable
          // 之前，全新安装首次开库即抛
          // `SqliteException(1): no such table: main.savings_rolling_plans`
          // → 迁移事务回滚 → bootstrapData 抛异常 → main() 中断 →
          // runApp 永不执行 → App 卡在 Flutter 启动图。升级路径本就安全
          // （onUpgrade 的 _createIndexes 在末尾、各版本建表步骤之后），
          // 此处把 onCreate 对齐为同一顺序：先建表、再建索引。
          await _ensureRawTables();
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

          if (from < 9) {
            // v9：分期计划新增「每期利息明细」数组列，承载首期/尾期全扣等
            // 非均摊利息扣除方式。历史数据的该列为 null，UI 按平均利息平摊。
            await _addColumnIfMissing(
              m,
              installmentPlans,
              installmentPlans.feeByPeriodMinor,
            );
          }

          if (from < 10) {
            // v10：分期计划新增「重复周期规则」列，用于支持每天/每周/每月/
            // 每年以及间隔、指定星期/日期/月份等复杂重复方式。历史数据为
            // null，Repository 会按原默认「每月」生成每期明细。
            await _addColumnIfMissing(
              m,
              installmentPlans,
              installmentPlans.repeatRule,
            );
          }

          if (from < 11) {
            // v11：新增本地「标签」两张表（分组 + 标签），不参与云端同步。
            await _createTableIfMissing(m, tagCategories);
            await _createTableIfMissing(m, tags);
          }

          if (from < 12) {
            // v12：模板新增「示例金额 / 转入账户 / 借还对方」三列，
            // 支撑模板页独立录入（不落流水）与模板卡金额/账户摘要展示。
            await _addColumnIfMissing(
              m,
              recordTemplates,
              recordTemplates.amountMinor,
            );
            await _addColumnIfMissing(
              m,
              recordTemplates,
              recordTemplates.toAccountId,
            );
            await _addColumnIfMissing(
              m,
              recordTemplates,
              recordTemplates.counterparty,
            );
          }

          if (from < 13) {
            // v13：模板新增「示例优惠」列，保存/回填记一笔的优惠金额。
            await _addColumnIfMissing(
              m,
              recordTemplates,
              recordTemplates.discountMinor,
            );
          }

          if (from < 14) {
            // v14：流水新增「报销账户」列（报销支出关联的报销类型账户，
            // 未选择为 null）。历史数据为 null，详情页报销账户行显示「无」。
            await _addColumnIfMissing(
              m,
              transactions,
              transactions.reimbursementAccountId,
            );
          }

          if (from < 15) {
            // v15：报销状态简化为两态（待报销 / 已报销），移除「已提交」「已收款」。
            // 旧索引：0=待报销 1=已提交 2=已报销 3=已收款
            // 新索引：0=待报销 1=已报销
            // 已提交视为尚未收回 → 归为待报销；已报销 / 已收款都算已结 → 归为已报销。
            await customStatement(
              'UPDATE reimbursements SET status = 0 WHERE status = 1',
            );
            await customStatement(
              'UPDATE reimbursements SET status = 1 WHERE status IN (2, 3)',
            );
          }

          if (from < 16) {
            // v16：报销新增「收款流水」列——被报销收入抵扣时落账的 income
            // 流水 ID，账单明细弹窗据此反向展示「关联账单」。历史数据 null。
            await _addColumnIfMissing(
              m,
              reimbursements,
              reimbursements.incomeTransactionId,
            );
          }

          if (from < 17) {
            // v17：报销新增「抵扣台账」列（JSON 数组），记录被每笔报销收入
            // 抵扣的金额明细。删除报销收入流水时按台账反向恢复账单状态与
            // 垫付余额。历史数据 null（删除旧收入时按无台账处理，不恢复）。
            await _addColumnIfMissing(
              m,
              reimbursements,
              reimbursements.incomeAllocs,
            );
          }

          if (from < 18) {
            // v18：借还流水冲销台账（原始 SQL 建表，见 _ensureLendFlowOffsetsTable）。
            // 记录每笔还债/收债/备忘分别冲销了哪些借还记录、各多少，供删除
            // 借还账户时跨账户反向恢复其余账户（与 drift 代码生成解耦）。
            await _ensureLendFlowOffsetsTable();
          }

          if (from < 19) {
            // v19：储蓄目标新增「已归档」列——储蓄页拆「计划/归档」双 Tab，
            // 停止的计划移入归档 Tab，可恢复。历史数据全部为 false（未归档）。
            await _addColumnIfMissing(
              m,
              savingsGoals,
              savingsGoals.isArchived,
            );
          }

          if (from < 20) {
            // v20：储蓄目标新增「存钱模式 / 重复周期 / 结束方式 / 已执行次数」
            // 四列——计划卡片按小青账样式展示模式名与三枚信息胶囊。
            // 历史数据 mode 等三列为 null（卡片兜底显示），已执行次数为 0。
            await _addColumnIfMissing(m, savingsGoals, savingsGoals.mode);
            await _addColumnIfMissing(
              m,
              savingsGoals,
              savingsGoals.repeatCycle,
            );
            await _addColumnIfMissing(m, savingsGoals, savingsGoals.endNote);
            await _addColumnIfMissing(
              m,
              savingsGoals,
              savingsGoals.depositCount,
            );
          }

          if (from < 21) {
            // v21：储蓄计划详情页——目标新增「开始日期」列（逐期排期起点，
            // 历史数据 null 时回退 updatedAt）+ 新增「逐期存入台账」本地表
            // （第 N 期实际存入金额/时间，点期卡标记存入 / 撤销）。
            await _addColumnIfMissing(m, savingsGoals, savingsGoals.startedAt);
            await _createTableIfMissing(m, savingsDeposits);
          }

          if (from < 22) {
            // v22：储蓄逐期存入台账新增「备注」列（存钱弹窗录入，可空）。
            await _addColumnIfMissing(m, savingsDeposits, savingsDeposits.note);
          }

          if (from < 23) {
            // v23：弹性存钱法支持真正递增——新增「递增模式 / 首期基础额 /
            // 金额模式系数 / 百分比模式百分比」四列。旧弹性计划三列均为
            // null，排期回退均摊（见 savings_schedule.dart），不崩。
            await _addColumnIfMissing(
              m,
              savingsGoals,
              savingsGoals.elasticMode,
            );
            await _addColumnIfMissing(
              m,
              savingsGoals,
              savingsGoals.elasticBaseMinor,
            );
            await _addColumnIfMissing(
              m,
              savingsGoals,
              savingsGoals.elasticStepMinor,
            );
            await _addColumnIfMissing(
              m,
              savingsGoals,
              savingsGoals.elasticPercentHundred,
            );
          }

          if (from < 24) {
            // v24：分类新增「系统分类」标记列——借入/借出/转账/报销/退款/
            // 分期/存款等落账时由 ensureNamed 自动重建挂分类，用户分类管理
            // 与图标选择器隐藏（仅流水挂分类与统计用）。历史数据全部为
            // false（旧版无系统分类概念）。
            await _addColumnIfMissing(m, categories, categories.isSystem);
          }

          if (from < 25) {
            // v25：储蓄计划新增「转出/扣款账户」列（存钱快捷属性落库）——
            // 原先该账户仅页面态不落库，编辑页重开必空。历史数据为 null，
            // 页面回退为默认资产账户 / 留空由用户选择。
            await _addColumnIfMissing(
              m,
              savingsGoals,
              savingsGoals.sourceAccountId,
            );
          }

          if (from < 26) {
            // v26：借还记录新增「免息期」列（天）。信用卡类债务在免息期内还款
            // 不计利息；历史数据为 0（无免息期）。UI 入口在借还录入表单补充。
            await _addColumnIfMissing(
              m,
              lendRecords,
              lendRecords.graceDays,
            );
          }

          if (from < 27) {
            // v27：流水新增「位置」三列（纬度 / 经度 / 逆地理编码地名）。
            // 记一笔时可附加当前 GPS 位置，仅本地存储、不参与云端同步。
            // 历史数据为 null，详情页与统计均按「无位置」处理。
            await _addColumnIfMissing(m, transactions, transactions.latitude);
            await _addColumnIfMissing(m, transactions, transactions.longitude);
            await _addColumnIfMissing(m, transactions, transactions.placeName);
          }

          if (from < 28) {
            // v28：分期「还款自动勾选」溯源表（原生 SQL，不参与 drift 代码生成）。
            // 记录被「还款自动对账」勾选已还的期次，供 reconcile 支持「可进可退」
            // 回退；用户手动勾选的期次不在此表，永不自动回退。范式参考
            // [_ensureLendFlowOffsetsTable]（本沙箱 build_runner 因管道耗尽不可用，
            // 故用原生 SQL 避免改 schema 必须重跑代码生成）。
            await _ensureInstallmentAutoPaidTable();
          }

          if (from < 29) {
            // v29：行情候选库（证券/币全量元数据缓存，支撑新建持仓自动补全）。
            // 原生 SQL 建表（同分期溯源表范式，避开 build_runner 代码生成）。
            await _ensureSecurityMetaTable();
          }

          if (from < 30) {
            // v30：36 期滚存计划配置表（原生 SQL 建表，避开 build_runner
            // 代码生成）。存储滚存计划的全部参数 + 利率调整记录 JSON。
            // 与 [SavingsGoals] 通过 goal_id 关联；本表为纯本地数据，
            // 不参与云端同步（与 security_meta 同级）。
            await _ensureRollingPlansTable();
          }

          if (from < 31) {
            // v31：滚存计划表补 amount_overrides 列（金额调整记录 JSON，
            // 支持后期追加 / 变更每月定投金额）。表本体 v30 已建，
            // [_ensureRollingPlansTable] 内部幂等补列。
            await _ensureRollingPlansTable();
          }

          if (from < 32) {
            // v32：持仓表加「已实现盈亏」缓存列（卖出落袋盈亏，避免亏损只藏在
            // 现金里、持仓卡看不见）。原生 SQL 思路与 security_meta 同（避开
            // build_runner 代码生成）；加列用幂等 [_addColumnIfMissing]。
            await _addColumnIfMissing(
              m,
              investmentHoldings,
              investmentHoldings.realizedProfitMinor,
            );
            // 存量回填：旧库已有卖出流水的持仓，按流水重放核算写入新列。
            await _backfillRealizedProfit();
          }

          if (from < 33) {
            // v33：补齐「行情接入」会话漏写的持仓表两列（当前价/币种）。
            // 当时只在 tables.dart 加列、未补迁移，导致创建早于该次改动的
            // 旧库 SELECT * 读不到这两列 → 映射非空 int 崩溃。幂等加列。
            await _addColumnIfMissing(
              m,
              investmentHoldings,
              investmentHoldings.currentPriceMinor,
            );
            await _addColumnIfMissing(
              m,
              investmentHoldings,
              investmentHoldings.currency,
            );
          }

          if (from < 34) {
            // v34：流水表加「真实记录时间」created_at（UTC 毫秒），与业务发生
            // 时间 occurred_at 解耦，使「坚持记账第 X 天」按真实记账起点算、
            // 不被改业务日期影响。列可空，老库加列后回填 occurred_at。
            await _addColumnIfMissing(
              m,
              transactions,
              transactions.createdAt,
            );
            // 老数据回填：created_at 缺失的行用业务时间 occurred_at 顶上。
            await customStatement(
              'UPDATE transactions SET created_at = occurred_at WHERE created_at IS NULL',
            );
          }

          if (from < 35) {
            // v35：流水表加「子分类」subcategory（自由文本，非结构化），支撑导入 /
            // 导出模板的「子分类」列。列可空，幂等加列（见 _addColumnIfMissing）。
            await _addColumnIfMissing(
              m,
              transactions,
              transactions.subcategory,
            );
          }

          // 索引在 onCreate 里创建；升级路径同样要补齐，且必须幂等
          // （旧库若已建过索引，重复 CREATE INDEX 也会报 already exists）。
          await _createIndexes();
        },
        beforeOpen: (OpeningDetails details) async {
          // 启用外键约束，保证账户与流水的引用完整性
          await customStatement('PRAGMA foreign_keys = ON');
          // 兜底对账：确保持仓表三列（当前价/币种/已实现盈亏）存在，覆盖任何
          // 漏迁移/半迁移的存量库。每次打开自愈，避免 SELECT * 读不到列 →
          // 映射非空 int 崩溃。幂等（PRAGMA 探测后仅在缺失时 ALTER）。
          await _ensureInvestmentHoldingColumns();
          // 兜底建表：四张原生 SQL 台账表每次打开自愈（幂等，表已存在时
          // 为零成本 no-op），覆盖任何漏写迁移步骤 / 建表顺序被改乱的库。
          await _ensureRawTables();
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

  /// v32 存量回填：给已有持仓按买卖流水重放核算已实现盈亏（分）写入新列。
  ///
  /// 仅用于升级旧库；此后每次买卖由 [InvestmentRepository] 精确维护该列，
  /// 无需再重放。与 [InvestmentRepository.realizedProfitMinorFor] 同公式
  /// （移动加权成本法），改公式需同步两处。
  Future<void> _backfillRealizedProfit() async {
    final List<InvestmentHolding> holdings = await (select(investmentHoldings)
          ..where((InvestmentHoldings t) => t.deleted.equals(false)))
        .get();
    if (holdings.isEmpty) return;
    final List<Transaction> flows = await (select(transactions)
          ..where(
            (Transactions t) =>
                t.sourceModule.equals(SourceModule.investment.index),
          ))
        .get();
    final Map<String, List<Transaction>> grouped =
        <String, List<Transaction>>{};
    for (final Transaction f in flows) {
      final String? hid = f.relatedId;
      if (hid == null) continue;
      (grouped[hid] ??= <Transaction>[]).add(f);
    }
    for (final InvestmentHolding h in holdings) {
      final int realized = _replayRealizedProfit(grouped[h.id]);
      if (realized == 0) continue;
      await (update(investmentHoldings)
            ..where((InvestmentHoldings t) => t.id.equals(h.id)))
          .write(
        InvestmentHoldingsCompanion(realizedProfitMinor: Value<int>(realized)),
      );
    }
  }

  /// 兜底：确保持仓表三列（当前价/币种/已实现盈亏）存在。
  ///
  /// 任何漏写迁移或中途失败的存量库，下次打开即自愈，避免 `SELECT *`
  /// 读不到列 → `map()` 把 null 赋给非空 int 字段崩溃。幂等：先用
  /// `PRAGMA table_info` 探测，仅在列缺失时 `ALTER TABLE ... ADD COLUMN`
  /// （与 [Migrator.addColumn] 同口径：NOT NULL + DEFAULT，存量行填默认值）。
  Future<void> _ensureInvestmentHoldingColumns() async {
    final List<QueryRow> info = await customSelect(
      'PRAGMA table_info(investment_holdings)',
    ).get();
    final Set<String> existing =
        info.map((QueryRow r) => r.read<String>('name')).toSet();
    const Map<String, String> defs = <String, String>{
      'current_price_minor': 'INTEGER NOT NULL DEFAULT 0',
      'currency': "TEXT NOT NULL DEFAULT 'CNY'",
      'realized_profit_minor': 'INTEGER NOT NULL DEFAULT 0',
    };
    for (final MapEntry<String, String> e in defs.entries) {
      if (!existing.contains(e.key)) {
        await customStatement(
          'ALTER TABLE investment_holdings ADD COLUMN ${e.key} ${e.value}',
        );
      }
    }
  }

  /// 与 [InvestmentRepository.realizedProfitMinorFor] 同公式的本地重放。
  ///
  /// DB 层不反向依赖仓储（避免 database↔features 循环 import），故在此复刻
  /// 解析与计算；[InvestmentRepository] 的版本为 canonical，二者口径须一致。
  static final RegExp _investMetaRe = RegExp(
    r'份额\s+([\d.]+)\s*·\s*单价\s*¥?\s*([\d,]+(?:\.\d+)?)\s*·\s*手续费\s*¥?\s*([\d,]+(?:\.\d+)?)',
  );

  static int _replayRealizedProfit(List<Transaction>? flows) {
    final List<Transaction> sorted = (flows ?? const <Transaction>[])
      ..sort(
        (Transaction a, Transaction b) => a.occurredAt.compareTo(b.occurredAt),
      );
    const int scale = 1000000;
    int qtyMicros = 0;
    int costMicros = 0; // 分·micros
    int realized = 0;
    for (final Transaction f in sorted) {
      int fee = 0;
      int delta = 0;
      if (f.note != null) {
        final RegExpMatch? m = _investMetaRe.firstMatch(f.note!);
        if (m != null) {
          fee = ((double.tryParse(m.group(3)!.replaceAll(',', '')) ?? 0) * 100)
              .round();
          delta = ((double.tryParse(m.group(1)!) ?? 0) * scale).round();
        }
      }
      if (f.type == TxnType.expense) {
        // 买入流水金额含手续费，投资净额 = 金额 − 费。
        final int net = f.amountMinor - fee;
        qtyMicros += delta;
        costMicros += net * scale;
      } else if (f.type == TxnType.income && delta > 0) {
        // 卖出：到账 = 流水金额（已扣费）；已实现 = 到账 − 已卖份额成本。
        final int avg = qtyMicros == 0 ? 0 : costMicros ~/ qtyMicros;
        final int costRemoved = (delta * avg) ~/ scale;
        realized += f.amountMinor - costRemoved;
        qtyMicros -= delta;
      }
    }
    return realized;
  }

  /// 幂等建表：四张原生 SQL 台账表一次建齐（表已存在时为零成本 no-op）。
  ///
  /// 集合口径：借还流水冲销台账、分期「还款自动勾选」溯源表、行情候选库、
  /// 36 期滚存计划配置表。被 [migration] 的 onCreate（先于 [_createIndexes]，
  /// 因索引直接引用这些表）与 beforeOpen（每次打开自愈）共用——将来新增
  /// 第五张原生表时只需在此追加一行，onCreate/beforeOpen 自动覆盖。
  Future<void> _ensureRawTables() async {
    await _ensureLendFlowOffsetsTable();
    await _ensureInstallmentAutoPaidTable();
    await _ensureSecurityMetaTable();
    await _ensureRollingPlansTable();
    await _ensureImportRecordsTable();
  }

  /// 幂等建表：账单导入归档记录表（原生 SQL，不参与 drift 代码生成）。
  ///
  /// 记录每笔「导入」的来源 / 笔数 / 跳过原因 / 写入的流水 ID 清单，供入口页
  /// 列表展示与「左滑删除 → 级联删本批流水」溯源。范式同 [_ensureSecurityMetaTable]
  /// （避开 build_runner 代码生成）；随 [_ensureRawTables] 在 onCreate / beforeOpen
  /// 自愈，存量库下次打开即自动建表。
  Future<void> _ensureImportRecordsTable() async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS import_records ('
      'id TEXT NOT NULL PRIMARY KEY, '
      'source TEXT NOT NULL, '
      'source_label TEXT NOT NULL, '
      'imported_count INTEGER NOT NULL, '
      'skipped_count INTEGER NOT NULL, '
      'fail_json TEXT, '
      'txn_ids TEXT, '
      'created_at INTEGER NOT NULL)',
    );
  }

  /// 幂等建表：借还流水冲销台账（[LendRepository] 用于跨账户冲销反向恢复）。
  ///
  /// 用原始 SQL 建表、不参与 drift 代码生成（本沙箱 `build_runner` 因系统
  /// 管道耗尽不可用，避免改 schema 后必须重跑代码生成）。表极小，仅三列
  /// 复合主键，承载「某笔借还流水 txn_id 冲销了某借还记录 lend_record_id
  /// 多少金额」，供删除借还账户时精确反向恢复其余账户。
  Future<void> _ensureLendFlowOffsetsTable() async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS lend_flow_offsets ('
      'txn_id TEXT NOT NULL, '
      'lend_record_id TEXT NOT NULL, '
      'amount_minor INTEGER NOT NULL, '
      'PRIMARY KEY (txn_id, lend_record_id))',
    );
  }

  /// 幂等建表：分期「还款自动勾选」溯源表（原生 SQL，不参与 drift 代码生成）。
  ///
  /// 记录哪些期次是被「还款自动对账」勾选已还的（[period_id]），用于支持
  /// 「可进可退」：当对应还款被删除/减少、周期不再满足阈值时，自动回退这些
  /// 期次的已还标记；而用户手动勾选的期次不在此表，reconcile 永不触碰，
  /// 避免误伤。范式参考 [_ensureLendFlowOffsetsTable]（本沙箱 build_runner
  /// 因管道耗尽不可用，故用原生 SQL 避免改 schema 必须重跑代码生成）。
  Future<void> _ensureInstallmentAutoPaidTable() async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS installment_auto_paid ('
      'period_id TEXT NOT NULL PRIMARY KEY, '
      'auto_at INTEGER NOT NULL)',
    );
  }

  /// 幂等建表：行情候选库（新建持仓自动补全用）。
  ///
  /// 缓存基金全量列表、币全量符号等元数据，首次/每周拉取后落本地，
  /// 补全直接在本地查（秒级、离线可用）。原生 SQL 范式同分期溯源表
  /// （避开 build_runner）。复合主键 (symbol, type) 使同代码不同品种不冲突。
  Future<void> _ensureSecurityMetaTable() async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS security_meta ('
      'symbol TEXT NOT NULL, '
      'name TEXT NOT NULL, '
      'type INTEGER NOT NULL, '
      'updated_at INTEGER NOT NULL, '
      'PRIMARY KEY (symbol, type))',
    );
  }

  /// 幂等建表：36 期滚存计划配置表（原生 SQL，不参与 drift 代码生成）。
  ///
  /// 存储滚存计划的全部参数（首期本金 / 年利率 / 期限 / 期数 / 取整策略 /
  /// 自动滚存 / 追投 / 滚存轮数 / 目标额 / 利率调整记录 JSON）。与
  /// [SavingsGoals] 通过 goal_id 关联，纯本地、不参与云端同步。范式同
  /// [ _ensureSecurityMetaTable]（避开 build_runner 代码生成）。
  Future<void> _ensureRollingPlansTable() async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS savings_rolling_plans ('
      'id TEXT NOT NULL PRIMARY KEY, '
      'goal_id TEXT NOT NULL, '
      'book_id TEXT NOT NULL, '
      'base_minor INTEGER NOT NULL, '
      'annual_rate_bp INTEGER NOT NULL, '
      'term_months INTEGER NOT NULL, '
      'periods INTEGER NOT NULL, '
      'round_strategy INTEGER NOT NULL, '
      'auto_roll INTEGER NOT NULL, '
      'roll_add_new INTEGER NOT NULL, '
      'roll_rounds INTEGER NOT NULL, '
      'roll_target_minor INTEGER, '
      'rate_overrides TEXT, '
      'amount_overrides TEXT, '
      'updated_at INTEGER NOT NULL)',
    );
    // v31 加列：v30 建的表没有 amount_overrides（金额调整记录 JSON）。
    // 幂等探测：列已存在则跳过（同 [_addColumnIfMissing] 的防重原则）。
    final List<QueryRow> cols = await customSelect(
      'PRAGMA table_info(savings_rolling_plans)',
    ).get();
    final bool hasAmountCol =
        cols.any((QueryRow r) => r.read<String>('name') == 'amount_overrides');
    if (!hasAmountCol) {
      await customStatement(
        'ALTER TABLE savings_rolling_plans ADD COLUMN amount_overrides TEXT',
      );
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
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_savings_deposits_goal '
      'ON savings_deposits(goal_id, day_index)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_rolling_plans_goal '
      'ON savings_rolling_plans(goal_id)',
    );
  }
}
