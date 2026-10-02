import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../domain/enums.dart';
import '../features/categories/data/category_repository.dart';
import '../features/lend/data/lend_repository.dart';
import '../features/ledger/data/transaction_repository.dart';
import '../features/savings/presentation/savings_modes.dart';

/// 默认分类的图标与配色预设。
///
/// 支持两级：一级分类（顶层项）可携带若干二级子类（[children]）。
/// 子类的 [colorValue] 传 0 表示继承所属一级分类的配色。
class _DefaultCategory {
  const _DefaultCategory(this.name, this.iconKey, this.colorValue,
      [this.children = const <_DefaultCategory>[]]);
  final String name;
  final String iconKey;
  final int colorValue;
  final List<_DefaultCategory> children;
}

/// 默认支出分类树（一级 + 二级）。
///
/// 每个分区取自设计稿各「分组」：列表首个自身为一级分类，
/// 其 [children] 为二级子类（一级用各组首个图标，二级用其余图标）。
/// 色板为 ForestSage 调和色，与暖纸底 #FBF6EA 同调。
const List<_DefaultCategory> _defaultExpenseCategories = <_DefaultCategory>[
  _DefaultCategory('餐饮', 'restaurant', 0xFFD96F52, <_DefaultCategory>[
    _DefaultCategory('早餐', 'breakfast', 0),
    _DefaultCategory('午餐', 'lunch', 0),
    _DefaultCategory('晚餐', 'dinner', 0),
    _DefaultCategory('饮品', 'beverage', 0),
    _DefaultCategory('团购券', 'groupbuy', 0),
    _DefaultCategory('风味小吃', 'street_food', 0),
  ]),
  _DefaultCategory('购物', 'shopping', 0xFFB86A9E, <_DefaultCategory>[
    _DefaultCategory('果蔬蛋奶', 'produce', 0),
    _DefaultCategory('零食', 'snack', 0),
    _DefaultCategory('运费', 'shipping', 0),
    _DefaultCategory('服饰鞋包', 'apparel', 0),
    _DefaultCategory('美妆护肤', 'beauty', 0),
    _DefaultCategory('数码电器', 'digital', 0),
    _DefaultCategory('生活耗材', 'consumable', 0),
    _DefaultCategory('烟酒茶糖', 'tobacco', 0),
    _DefaultCategory('家居家具', 'furniture', 0),
    _DefaultCategory('个护服务', 'personal_care', 0),
  ]),
  _DefaultCategory('出行', 'travel', 0xFF5C82B8, <_DefaultCategory>[
    _DefaultCategory('养车', 'car_care', 0),
    _DefaultCategory('公共交通', 'transit', 0),
    _DefaultCategory('加油充电', 'fuel', 0),
    _DefaultCategory('打车租车', 'taxi_rental', 0),
    _DefaultCategory('城际出行', 'intercity', 0),
  ]),
  _DefaultCategory('居住', 'home', 0xFFA97742, <_DefaultCategory>[
    _DefaultCategory('住宿', 'lodging', 0),
    _DefaultCategory('装修维护', 'renovation', 0),
    _DefaultCategory('房租房贷', 'rent', 0),
    _DefaultCategory('水电燃物', 'utilities', 0),
    _DefaultCategory('话费网费', 'telecom', 0),
  ]),
  _DefaultCategory('娱乐', 'entertainment', 0xFF8F6FBF, <_DefaultCategory>[
    _DefaultCategory('运动健身', 'fitness', 0),
    _DefaultCategory('线下娱乐', 'offline_fun', 0),
    _DefaultCategory('数字娱乐', 'digital_fun', 0),
    _DefaultCategory('旅游度假', 'travel_vacation', 0),
    _DefaultCategory('收藏爱好', 'hobby', 0),
  ]),
  _DefaultCategory('医疗健康', 'medical', 0xFF4A96A6, <_DefaultCategory>[
    _DefaultCategory('就医购药', 'clinic', 0),
    _DefaultCategory('养生保健', 'wellness', 0),
    _DefaultCategory('体检疫苗', 'checkup', 0),
    _DefaultCategory('商业保险', 'insurance', 0),
  ]),
  _DefaultCategory('学习办公', 'education', 0xFF6470C2, <_DefaultCategory>[
    _DefaultCategory('知识付费', 'knowledge', 0),
    _DefaultCategory('图文工具', 'stationery', 0),
  ]),
  _DefaultCategory('人情往来', 'social', 0xFFCE6478, <_DefaultCategory>[
    _DefaultCategory('红包', 'red_packet', 0),
    _DefaultCategory('送礼', 'gift', 0),
  ]),
  _DefaultCategory('宠物', 'pet', 0xFF7E9B6B, <_DefaultCategory>[
    _DefaultCategory('宠物食品', 'pet_food', 0),
    _DefaultCategory('宠物用品', 'pet_supply', 0),
    _DefaultCategory('宠物医疗', 'pet_medical', 0),
    _DefaultCategory('宠物服务', 'pet_service', 0),
  ]),
  _DefaultCategory('资金往来', 'funds', 0xFF3E8E8E, <_DefaultCategory>[
    _DefaultCategory('还款', 'repay', 0),
    _DefaultCategory('借款', 'lend', 0),
    _DefaultCategory('计提', 'accrue', 0),
  ]),
  _DefaultCategory('投资支出', 'investment', 0xFF4E93A6, <_DefaultCategory>[
    _DefaultCategory('缴税', 'tax', 0),
    _DefaultCategory('博彩理财', 'finance', 0),
    _DefaultCategory('分红入股', 'dividend', 0),
    _DefaultCategory('日常运营', 'operations', 0),
    _DefaultCategory('大额投入', 'capex', 0),
  ]),
  // 设计稿未单列、但旧版保留的常用一级（不动，避免丢掉用户历史数据）。
  _DefaultCategory('其他', 'other', 0xFFC7A24A),
];

/// 默认收入分类（一级，无内置二级）。
const List<_DefaultCategory> _defaultIncomeCategories = <_DefaultCategory>[
  _DefaultCategory('职业收入', 'income_job', 0xFF45936A, <_DefaultCategory>[
    _DefaultCategory('基本工资', 'salary', 0),
    _DefaultCategory('绩效奖金', 'performance_bonus', 0),
    _DefaultCategory('津贴补助', 'allowance', 0),
  ]),
  _DefaultCategory('经营收入', 'income_business', 0xFFD69E3C, <_DefaultCategory>[
    _DefaultCategory('个体经营', 'sole_proprietor', 0),
    _DefaultCategory('副业兼职', 'income_side', 0),
  ]),
  _DefaultCategory('投资收入', 'income_invest', 0xFF4E93A6, <_DefaultCategory>[
    _DefaultCategory('证券收入', 'securities', 0),
    _DefaultCategory('利息收入', 'interest', 0),
  ]),
  _DefaultCategory('资金往来', 'income_funds', 0xFF8E8A7E, <_DefaultCategory>[
    _DefaultCategory('退款返现', 'refund_cashback', 0),
    _DefaultCategory('他人还款', 'repayment', 0),
    _DefaultCategory('人情往来', 'social_income', 0),
    _DefaultCategory('退税报销', 'tax_reimburse', 0),
  ]),
  _DefaultCategory('其他', 'other', 0xFFC7A24A), // 赭金（独立一级，保留不动）
];

/// 旧版 Material 300 粉彩色板（旧种子 + 分类编辑器预设的并集）。
/// 启动时命中该集合的默认分类颜色会被静默迁移为新调和色板，
/// 真正自定义的其它颜色不受影响。
const Set<int> _legacyCategoryPalette = <int>{
  0xFFE57373,
  0xFFF06292,
  0xFFBA68C8,
  0xFF9575CD,
  0xFF7986CB,
  0xFF64B5F6,
  0xFF4FC3F7,
  0xFF4DB6AC,
  0xFF81C784,
  0xFFFFB74D,
  0xFFA1887F,
  0xFF90A4AE,
  0xFF12B886,
  0xFFEF9F27,
  0xFFE5484D,
  0xFF378ADD,
  0xFFD4537E,
  0xFF888780,
};

/// 默认预设的分类查询表（name -> 预设图标/配色）。
final Map<String, _DefaultCategory> _defaultCategoryLookup =
    <String, _DefaultCategory>{
  for (final _DefaultCategory c in _defaultExpenseCategories) c.name: c,
  for (final _DefaultCategory c in _defaultIncomeCategories) c.name: c,
};

/// 按类型区分的查询表（支出/收入各一份，「其他」等同名分类配色不同）。
final Map<String, _DefaultCategory> _expenseCategoryLookup =
    <String, _DefaultCategory>{
  for (final _DefaultCategory c in _defaultExpenseCategories) c.name: c,
};
final Map<String, _DefaultCategory> _incomeCategoryLookup =
    <String, _DefaultCategory>{
  for (final _DefaultCategory c in _defaultIncomeCategories) c.name: c,
};

/// 首次启动时写入默认数据，保证应用开箱可用。
///
/// 幂等：已存在账本时直接返回，不会重复写入。
Future<void> bootstrapData(AppDatabase db) async {
  // 报销账户余额对账（幂等，每次启动运行）：余额 = 名下「待报销」合计，
  // 修复历史版本挂账/核销链路缺失导致的 100 vs 30 类不一致。
  await _reconcileReimbursementBalances(db);
  await _reconcileReimbursedAmounts(db);
  // 借还账户销户清账兜底（幂等，每次启动运行）：历史版本删除借出/借入
  // 账户时未级联清理，名下借还记录成为孤儿（accountId 指向已删/不存在
  // 账户，汇总不显示但流水残留在流水页）。启动时把指向已删账户的记录
  // 及其关联流水一并清除。必须在归户**之前**，避免孤儿记录被后续链路
  // 误处理。
  await _purgeLendRecordsOfDeletedAccounts(db);
  // 借还指定账户存量归户（幂等）：旧记录未指定借入/借出账户、但对方
  // 名称与同方向账户名一致的，回填 accountId——必须在流水补建**之前**，
  // 归户后的记录才能按「资产账户优先 → 指定账户兜底」口径补建本金流水。
  await _backfillLendDesignatedAccounts(db);
  // 历史还债/收债流水补关联借还记录（幂等）：旧版本还债/收债流水未写
  // relatedId，详情无法显示「借还账户」行；按备注「动词-对方」反查同方向
  // 借还记录回填 relatedId。必须在归户**之后**（对方名已与账户对齐）。
  await _backfillRepayRelatedIds(db);
  // 借还落流水对账（幂等，每次启动运行）：有可挂账户（资产账户优先，
  // 其次指定借入/借出账户）但缺本金流水的借还记录补建流水；借还模块
  // 流水统一排除收支统计与预算。补建必须在余额对账**之前**——补建的
  // 流水挂在指定账户上会带错向余额增量，随后由对账覆盖修复。
  await _backfillLendFlowTransactions(db);
  await _excludeLendFromStatsAndBudget(db);
  // 历史借还流水补分类（幂等）：借还模块流水按操作类型落固定类目
  // （借入/借出、还债/收债、债务消减/坏账计提），旧流水分类为空时
  // 按备注「动词-对方」的动词回填——须在流水补建**之后**（补建的
  // 新流水已自带分类，这里只兜底更早的历史行）。
  await _backfillLendFlowCategories(db);
  // 借还指定账户余额对账（幂等）：借出/借入类型账户余额 =
  // 名下未结清借还记录合计（报销账户同款不变量）。
  await _reconcileLendAccountBalances(db);
  // 储蓄旧计划模式回填（幂等）：v20 之前创建的计划没有 mode/repeatCycle/
  // endNote，卡片标题兜底「储蓄计划」、三枚胶囊只剩已执行次数。目标金额
  // 恰好等于某模式预设总额的（365天 66795 / 30天倒数 5580 / 星期 14560 /
  // 52周 13780），按金额反推模式补齐三列。
  await _backfillSavingsLegacyModes(db);
  // 储蓄备注预置清理（幂等）：创建页旧口径会把模式说明兜底写进备注，
  // 现口径「备注不预置」——备注恰好等于任一模式说明的置 null。
  await _clearPresetSavingsNotes(db);
  await _repairSavingsNoPresetCurrent(db);
  final List<Book> books = await db.booksDao.watchAll().first;
  if (books.isEmpty) {
    await _seedDefaults(db);
    await _seedSystemCategories(db);
    return;
  }
  // 已存在账本：兜底修复老版本默认分类缺少图标/颜色的问题（只补空白值）。
  await _repairDefaultCategoryIcons(db);
  // 重建默认支出分类树：一级重命名对齐设计稿 + 补齐二级子类 + 新增
  // 宠物/资金往来/投资支出 等一级分区（幂等，每次启动安全运行）。
  await _rebuildExpenseCategoryTree(db);
  // 重建默认收入分类树（同支出树口径：一级重命名 + 旧一级下沉为二级 + 补齐子类，幂等）。
  await _rebuildIncomeCategoryTree(db);
  // 色调迁移：旧 Material 粉彩 → ForestSage 调和色板（幂等，每次启动运行）。
  await _harmonizeDefaultCategoryColors(db);
  // 下线旧默认分类（幂等，软删 + 同步入队，与页内手动删除同口径）：
  // 通讯/咖啡/奶茶/果汁/点心（旧种子残留）+ 还债/债务消减（借还固定
  // 分类，用户确认照删——下次借还落账会由 ensureNamed 自动重建挂分类）。
  // 另把「其他」的旧图标键 settings（太阳线稿）迁移为 other（四点格）。
  await _retireLegacyDefaultCategories(db);
  // 标记系统分类（幂等）：借入/借出/转账/报销/退款/分期/存款等落账时由
  // ensureNamed 自动重建挂分类的分类，标记为 isSystem=1 后用户分类管理/
  // 图标选择器隐藏（仅流水挂分类与统计用）。对历史已落账、早于本开关
  // 创建的同名分类同样生效，避免它们残留在用户分类列表里。
  await _markSystemCategories(db);
  // 预建 11 个落账系统分类（转账三变体/借还六类/报销收入/退款），确保入库
  // 并隐藏于用户分类列表，落账时按同名同类型引用。
  await _seedSystemCategories(db);
}

/// 下线旧版默认分类（幂等）：按名称精确匹配的支出分类软删，走
/// [CategoryRepository.remove]（软删 + 同步删除入队，与手动删除完全
/// 同口径）；名下已有流水改显「未分类」。另把「其他」的图标键从
/// settings 迁移为 other（只改 iconKey，不动名称/颜色，幂等写库）。
/// 「兼职」为旧版收入种子残留（收入/支出都清，含名下子分类）。
Future<void> _retireLegacyDefaultCategories(AppDatabase db) async {
  const List<String> retired = <String>[
    '通讯',
    '咖啡',
    '奶茶',
    '果汁',
    '点心',
    '还债',
    '债务消减',
  ];
  final List<Category> rows = await (db.select(db.categories)
        ..where((Categories t) =>
            t.name.isIn(retired) &
            t.type.equals(CategoryType.expense.index) &
            t.deleted.equals(false)))
      .get();
  if (rows.isNotEmpty) {
    final CategoryRepository repo = CategoryRepository(db);
    for (final Category c in rows) {
      await repo.remove(c.id);
    }
  }

  // 「兼职」下线（幂等，收入/支出两种类型都清）：旧版种子残留，现按
  // 「不内置」口径移除——按名称精确匹配软删（走 CategoryRepository.remove，
  // 软删 + 同步入队，与手动删除完全同口径），名下子分类一并删除，
  // 已有流水改显「未分类」。注意不碰「副业兼职」（经营收入的内置二级）。
  final List<Category> parttimeRows = await (db.select(db.categories)
        ..where((Categories t) =>
            t.name.equals('兼职') & t.deleted.equals(false)))
      .get();
  if (parttimeRows.isNotEmpty) {
    final CategoryRepository repo = CategoryRepository(db);
    for (final Category c in parttimeRows) {
      final List<Category> children = await (db.select(db.categories)
            ..where((Categories t) =>
                t.parentId.equals(c.id) & t.deleted.equals(false)))
          .get();
      for (final Category sub in children) {
        await repo.remove(sub.id);
      }
      await repo.remove(c.id);
    }
  }

  // 「其他」图标迁移（幂等，仅命中时写库，dirty 置真走同步）。
  final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await (db.update(db.categories)
        ..where((Categories t) =>
            t.name.equals('其他') &
            t.iconKey.equals('settings') &
            t.deleted.equals(false)))
      .write(
    CategoriesCompanion(
      iconKey: const Value<String?>('other'),
      updatedAt: Value<int>(now),
      dirty: const Value<bool>(true),
    ),
  );
}

/// 标记系统分类（幂等）：借入/借出/转账/报销/退款/分期/存款等落账时由
/// [CategoryRepository.ensureNamed] 自动重建挂分类的分类，统一置 isSystem=1，
/// 用户分类管理 / 图标选择器隐藏（仅流水挂分类与统计聚合用）。对历史已落账、
/// 早于本开关创建的同名分类同样生效，避免它们残留在用户分类列表里。
///
/// 直接写库（与分类颜色迁移同口径，不单独入队同步）：本开关为本地不变量，
/// 云端表尚未含 isSystem，待同步侧schema补齐后由全量对账收敛。
Future<void> _markSystemCategories(AppDatabase db) async {
  const List<(String, CategoryType)> systemNames = <(String, CategoryType)>[
    ('借入', CategoryType.income),
    ('借出', CategoryType.expense),
    ('还债', CategoryType.expense),
    ('收债', CategoryType.income),
    ('债务消减', CategoryType.expense),
    ('坏账计提', CategoryType.expense),
    ('报销收入', CategoryType.income),
    ('转账', CategoryType.transfer),
    ('退款', CategoryType.income),
    ('分期', CategoryType.expense),
    ('存款', CategoryType.expense),
    ('取现', CategoryType.transfer),
    ('还款', CategoryType.transfer),
    ('内部转账', CategoryType.transfer),
  ];
  // 历史系统分类补打 iconKey（落账 ensureNamed 也会写入，这里兜底旧数据；
  // 含转账三变体取现/还款/内部转账）。
  const Map<String, String> systemIconKeys = <String, String>{
    '借入': 'borrow_in',
    '借出': 'lend_out',
    '还债': 'repay_debt',
    '收债': 'collect_debt',
    '债务消减': 'debt_reduce',
    '坏账计提': 'bad_debt',
    '报销收入': 'reimburse_income',
    '退款': 'refund',
    '取现': 'withdrawal',
    '还款': 'repay',
    '内部转账': 'internal_transfer',
    // 旧「转账」大类遗留行：语义即内部转账，补线稿图标（名称不变）。
    '转账': 'internal_transfer',
    // 储蓄「存款」：分类级只存默认向（存入）；流水行/详情弹层会按存取方向
    // 覆盖成 deposit_out（见 `ledger/presentation/widgets/txn_icon.dart`）。
    '存款': 'deposit_in',
  };
  final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
  // 逐行条件修复：老行可能「已标 isSystem 但缺 iconKey」（早期版本先跑过
  // 标记、后补的图标字典盖不住 isSystem.equals(false) 守卫），故不再按
  // isSystem 过滤，而是命中缺标记或缺图标才写库（幂等、避免脏同步抖动）。
  for (final (String name, CategoryType type) in systemNames) {
    final String? iconKey = systemIconKeys[name];
    final List<Category> rows = await (db.select(db.categories)
          ..where((Categories t) =>
              t.name.equals(name) &
              t.type.equals(type.index) &
              t.deleted.equals(false)))
        .get();
    for (final Category row in rows) {
      final bool needMark = !row.isSystem;
      final bool needIcon = iconKey != null && row.iconKey != iconKey;
      if (!needMark && !needIcon) continue;
      await (db.update(db.categories)..where((Categories t) => t.id.equals(row.id)))
          .write(
        CategoriesCompanion(
          isSystem: const Value<bool>(true),
          iconKey: needIcon
              ? Value<String?>(iconKey)
              : const Value<String?>.absent(),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );
    }
  }
}

/// 预建系统分类（幂等，每次启动运行）：转账三变体（取现/还款/内部转账）、
/// 借还六类（借入/借出/还债/收债/债务消减/坏账计提）、报销收入、退款，
/// 共 11 个落账自动挂分类。启动时按 (bookId, name, type) 确保存在，并标记
/// [Category.isSystem]=true、挂对应线稿图标 key；用户分类管理/图标选择器
/// /预算/迁移/分期选父类等列表按 isSystem 隐藏，仅流水挂分类与统计聚合用。
///
/// 落账时由 [CategoryRepository.ensureNamed] 按同名同类型引用既有行（不再
/// 新建），故这里先行入库即等价于「当需要时引用」的单一数据源。
Future<void> _seedSystemCategories(AppDatabase db) async {
  final List<Book> books = await db.booksDao.watchAll().first;
  if (books.isEmpty) return;
  const List<(String, CategoryType, String)> seed =
      <(String, CategoryType, String)>[
    ('取现', CategoryType.transfer, 'withdrawal'),
    ('还款', CategoryType.transfer, 'repay'),
    ('内部转账', CategoryType.transfer, 'internal_transfer'),
    ('借入', CategoryType.income, 'borrow_in'),
    ('借出', CategoryType.expense, 'lend_out'),
    ('还债', CategoryType.expense, 'repay_debt'),
    ('收债', CategoryType.income, 'collect_debt'),
    ('债务消减', CategoryType.expense, 'debt_reduce'),
    ('坏账计提', CategoryType.expense, 'bad_debt'),
    ('报销收入', CategoryType.income, 'reimburse_income'),
    ('退款', CategoryType.income, 'refund'),
  ];
  final CategoryRepository repo = CategoryRepository(db);
  for (final Book book in books) {
    for (final (String name, CategoryType type, String iconKey) in seed) {
      await repo.ensureNamed(
        bookId: book.id,
        name: name,
        type: type,
        iconKey: iconKey,
        isSystem: true,
      );
    }
  }
}

/// 报销账户余额对账：每个报销类型账户的余额重算为
/// 名下未删除「待报销」记录的金额合计（保持「余额 = 待收垫付」不变量）。
///
/// 历史版本中「明细是否报销开关 / 报销页手动推进状态 / 历史账单补建」
/// 均未联动余额，长期漂移后出现「报销页垫付 100 vs 账户余额 30」类
/// 不一致——启动时按记录重算一次性修复，仅在有偏差时写库（避免脏同步）。
Future<void> _reconcileReimbursementBalances(AppDatabase db) async {
  final List<Account> reimbAccounts = await (db.select(db.accounts)
        ..where((Accounts t) =>
            t.type.equals(AccountType.reimbursement.index) &
            t.deleted.equals(false)))
      .get();
  if (reimbAccounts.isEmpty) return;

  final List<Reimbursement> pendings = await (db.select(db.reimbursements)
        ..where((Reimbursements t) =>
            t.status.equals(ReimbursementStatus.pending.index) &
            t.deleted.equals(false) &
            t.accountId.isNotNull()))
      .get();
  final Map<String, int> expected = <String, int>{};
  for (final Reimbursement r in pendings) {
    expected[r.accountId!] = (expected[r.accountId!] ?? 0) + r.amountMinor;
  }

  final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
  for (final Account a in reimbAccounts) {
    final int want = expected[a.id] ?? 0;
    if (a.balanceMinor == want) continue;
    await (db.update(db.accounts)..where((Accounts t) => t.id.equals(a.id)))
        .write(
      AccountsCompanion(
        balanceMinor: Value<int>(want),
        updatedAt: Value<int>(now),
        dirty: const Value<bool>(true),
      ),
    );
  }
}

/// 借还指定账户余额对账：借出(lend)/借入(borrow)类型账户的余额重算为
/// 名下未结清借还记录合计（本金 − 优惠 − 已还；报销账户同款不变量）。
///
/// 借还模块流水挂在这些账户上的余额增量是错向的（借出记支出做减法），
/// 余额一律以记录合计为准；历史漂移启动时一次性修复，仅在有偏差时写库。
Future<void> _reconcileLendAccountBalances(AppDatabase db) async {
  final List<Account> lendAccounts = await (db.select(db.accounts)
        ..where((Accounts t) =>
            (t.type.equals(AccountType.lend.index) |
                t.type.equals(AccountType.borrow.index)) &
            t.deleted.equals(false)))
      .get();
  if (lendAccounts.isEmpty) return;

  final List<LendRecord> records = await (db.select(db.lendRecords)
        ..where((LendRecords t) =>
            t.status.equals(LendStatus.ongoing.index) &
            t.deleted.equals(false) &
            t.accountId.isNotNull()))
      .get();

  final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
  for (final Account a in lendAccounts) {
    // ⚠️ a.type 是 Dart 枚举，与 `.index`（int）比较恒 false——曾导致
    // 借出账户方向恒判为 borrowIn、名下记录合计为 0，启动对账把借出
    // 账户余额清零。
    final LendDirection dir = a.type == AccountType.lend
        ? LendDirection.lendOut
        : LendDirection.borrowIn;
    final int want = records
        .where((LendRecord r) => r.accountId == a.id && r.direction == dir)
        .fold<int>(
          0,
          (int sum, LendRecord r) =>
              sum + r.amountMinor - r.discountMinor - r.repaidMinor,
        );
    if (a.balanceMinor == want) continue;
    await (db.update(db.accounts)..where((Accounts t) => t.id.equals(a.id)))
        .write(
      AccountsCompanion(
        balanceMinor: Value<int>(want),
        updatedAt: Value<int>(now),
        dirty: const Value<bool>(true),
      ),
    );
  }
}

/// 借还指定账户存量归户：未指定借入/借出账户（accountId 为空）的借还
/// 记录，若对方名称与同方向类型（借入→borrow / 借出→lend）的未删账户名
/// 一致，自动回填 accountId——借还账户本就是「对方」的虚拟化，名称一致
/// 视为同一对象。历史版本没有指定账户概念，此类记录只出现在借入/借出
/// 汇总里、不进任何账户余额，出现「借入汇总 ¥100 vs 账户 ¥0」类不一致。
/// 幂等：每次启动运行，仅在有匹配时写库（dirty 置真走同步）。
Future<void> _backfillLendDesignatedAccounts(AppDatabase db) async {
  final List<LendRecord> undesignated = await (db.select(db.lendRecords)
        ..where(
            (LendRecords t) => t.accountId.isNull() & t.deleted.equals(false)))
      .get();
  if (undesignated.isEmpty) return;

  final List<Account> lendAccounts = await (db.select(db.accounts)
        ..where((Accounts t) =>
            (t.type.equals(AccountType.lend.index) |
                t.type.equals(AccountType.borrow.index)) &
            t.deleted.equals(false)))
      .get();
  if (lendAccounts.isEmpty) return;

  final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
  for (final LendRecord r in undesignated) {
    final String name = r.counterparty.trim();
    if (name.isEmpty) continue;
    final AccountType type = r.direction == LendDirection.borrowIn
        ? AccountType.borrow
        : AccountType.lend;
    Account? match;
    for (final Account a in lendAccounts) {
      if (a.type == type && a.name.trim() == name) {
        match = a;
        break;
      }
    }
    if (match == null) continue;
    await (db.update(db.lendRecords)
          ..where((LendRecords t) => t.id.equals(r.id)))
        .write(
      LendRecordsCompanion(
        accountId: Value<String?>(match.id),
        updatedAt: Value<int>(now),
        dirty: const Value<bool>(true),
      ),
    );
  }
}

/// 已报销记录金额对账：「已报销」记录的金额应等于关联账单（transactionId）
/// 的原始金额。历史版本 deduct 全额抵扣时未还原金额（部分抵扣把 amountMinor
/// 扣成余额后直接翻状态），出现「已报销 ¥50 vs 实收 ¥100」类不一致——
/// 启动时按账单重算一次性修复；无关联账单的手建记录不动。
Future<void> _reconcileReimbursedAmounts(AppDatabase db) async {
  final List<Reimbursement> reimbursed = await (db.select(db.reimbursements)
        ..where((Reimbursements t) =>
            t.status.equals(ReimbursementStatus.reimbursed.index) &
            t.deleted.equals(false) &
            t.transactionId.isNotNull()))
      .get();
  if (reimbursed.isEmpty) return;

  final Set<String> txnIds =
      reimbursed.map((Reimbursement r) => r.transactionId!).toSet();
  final List<Transaction> bills = await (db.select(db.transactions)
        ..where((Transactions t) => t.id.isIn(txnIds)))
      .get();
  final Map<String, int> billAmount = <String, int>{
    for (final Transaction t in bills) t.id: t.amountMinor,
  };

  final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
  for (final Reimbursement r in reimbursed) {
    final int? want = billAmount[r.transactionId!];
    if (want == null || want == r.amountMinor) continue;
    await (db.update(db.reimbursements)
          ..where((Reimbursements t) => t.id.equals(r.id)))
        .write(
      ReimbursementsCompanion(
        amountMinor: Value<int>(want),
        updatedAt: Value<int>(now),
        dirty: const Value<bool>(true),
      ),
    );
  }
}

/// 历史还债/收债流水补关联借还记录：旧版本还债/收债流水（sourceModule=lend、
/// 排除收支统计）未写 relatedId，详情无法显示「借还账户」行。按备注里的
/// 「动词-对方」反查同方向（还债=borrowIn / 收债=lendOut）的未删借还记录，
/// 优先未结清，回填 relatedId——仅当该记录已指定借还账户（否则行本就不显示）。
/// 幂等：每次启动运行，仅在有匹配且尚未关联时写库（dirty 置真走同步）。
Future<void> _backfillRepayRelatedIds(AppDatabase db) async {
  final List<Transaction> txns = await (db.select(db.transactions)
        ..where((Transactions t) =>
            t.sourceModule.equals(SourceModule.lend.index) &
            t.relatedId.isNull() &
            t.excludeFromStats.equals(true) &
            t.deleted.equals(false)))
      .get();
  if (txns.isEmpty) return;

  final List<LendRecord> records = await (db.select(db.lendRecords)
        ..where((LendRecords t) => t.deleted.equals(false)))
      .get();
  final Map<String, List<LendRecord>> byKey = <String, List<LendRecord>>{};
  for (final LendRecord r in records) {
    final String key = '${r.direction.index}:${r.counterparty.trim()}';
    (byKey[key] ??= <LendRecord>[]).add(r);
  }

  final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
  for (final Transaction txn in txns) {
    final String? note = txn.note;
    if (note == null || !note.contains('-')) continue;
    final String counterparty = note.split('-')[1].split('\n')[0].trim();
    if (counterparty.isEmpty) continue;
    final LendDirection dir = txn.type == TxnType.expense
        ? LendDirection.borrowIn
        : LendDirection.lendOut;
    final List<LendRecord>? matches = byKey['${dir.index}:$counterparty'];
    if (matches == null || matches.isEmpty) continue;
    // 优先未结清记录
    LendRecord? pick;
    for (final LendRecord r in matches) {
      if (r.status == LendStatus.ongoing) {
        pick = r;
        break;
      }
    }
    pick ??= matches.first;
    if (pick.accountId == null || pick.accountId!.isEmpty) continue;
    await (db.update(db.transactions)
          ..where((Transactions t) => t.id.equals(txn.id)))
        .write(
      TransactionsCompanion(
        relatedId: Value<String?>(pick.id),
        updatedAt: Value<int>(now),
        dirty: const Value<bool>(true),
      ),
    );
  }
}

/// 历史借还流水补分类：借还模块流水（sourceModule=lend）按操作类型落
/// 固定类目——「借入记借入、还债记还债、借出记借出」。新流水落账时已
/// 自带分类，这里只兜底**分类为空的历史行**：按备注首行「动词-对方」的
/// 动词（借入/借出/还债/收债/债务消减/坏账计提）确定类目名与类型，
/// 用 [CategoryRepository.ensureNamed] 查找或创建。备注缺失或动词无法
/// 识别的行保持未分类。
///
/// 幂等：仅当某行当前 categoryId 与「动词推导出的正确类目」不一致时才
/// 改写（避免每次启动都刷 updatedAt）。据此也能把历史上错归为 income 的
/// 「债务消减」流水重新翻成 expense 版类目。
Future<void> _backfillLendFlowCategories(AppDatabase db) async {
  final List<Transaction> txns = await (db.select(db.transactions)
        ..where((Transactions t) =>
            t.sourceModule.equals(SourceModule.lend.index) &
            t.deleted.equals(false)))
      .get();
  if (txns.isEmpty) return;

  final CategoryRepository catRepo = CategoryRepository(db);
  // 类目缓存：(bookId, 类目名+类型) → 分类 ID，避免逐行查库。
  final Map<String, String> cache = <String, String>{};

  for (final Transaction txn in txns) {
    final String? note = txn.note;
    if (note == null || note.isEmpty) continue;
    final String verb = note.split('-').first.trim();
    String? name;
    CategoryType type = CategoryType.expense;
    switch (verb) {
      case '借入':
        name = '借入';
        type = CategoryType.income;
      case '借出':
        name = '借出';
      case '还债':
        name = '还债';
      case '收债':
        name = '收债';
        type = CategoryType.income;
      case '债务消减':
        // 统一为支出类型（修正历史上错归 income 的版本）。
        name = '债务消减';
      case '坏账计提':
        name = '坏账计提';
    }
    if (name == null) continue;

    final String cacheKey = '${txn.bookId}:$name:${type.index}';
    final String? cached = cache[cacheKey];
    final String categoryId = cached ??
        await catRepo.ensureNamed(
          bookId: txn.bookId,
          name: name,
          type: type,
          isSystem: true,
        );
    cache[cacheKey] = categoryId;

    // 已是正确类目则跳过（幂等）。
    if (txn.categoryId == categoryId) continue;

    await (db.update(db.transactions)
          ..where((Transactions t) => t.id.equals(txn.id)))
        .write(
      TransactionsCompanion(
        categoryId: Value<String?>(categoryId),
        updatedAt: Value<int>(DateTime.now().toUtc().millisecondsSinceEpoch),
        dirty: const Value<bool>(true),
      ),
    );
  }

  // 清理历史「债务消减」income 类目：已无流水引用（上面的改写已全部改指
  // expense 版），软删之避免分类列表出现重复 / 孤儿类目。
  final List<Book> books = await db.booksDao.watchAll().first;
  for (final Book book in books) {
    final List<Category> cats = await db.categoriesDao.watchAll(book.id).first;
    for (final Category c in cats) {
      if (c.name != '债务消减' || c.type != CategoryType.income || c.deleted) {
        continue;
      }
      final int refCount = (await (db.select(db.transactions)
                ..where((Transactions t) =>
                    t.categoryId.equals(c.id) & t.deleted.equals(false)))
              .get())
          .length;
      if (refCount == 0) await catRepo.remove(c.id);
    }
  }
}

/// 借还账户销户清账兜底：把 accountId 指向已软删 / 不存在账户的借还
/// 记录及其关联流水清除（复用 [LendRepository.purgeByDesignatedAccount]，
/// 流水撤销会回滚真实资金账户余额）。幂等：无孤儿记录时空操作。
Future<void> _purgeLendRecordsOfDeletedAccounts(AppDatabase db) async {
  final List<LendRecord> records = await (db.select(db.lendRecords)
        ..where((LendRecords t) =>
            t.deleted.equals(false) & t.accountId.isNotNull()))
      .get();
  if (records.isEmpty) return;
  final Set<String> aliveAccounts = (await (db.select(db.accounts)
            ..where((Accounts t) => t.deleted.equals(false)))
          .get())
      .map((Account a) => a.id)
      .toSet();
  final LendRepository lendRepo = LendRepository(db, TransactionRepository(db));
  for (final LendRecord r in records) {
    final String? accId = r.accountId;
    if (accId == null || accId.isEmpty || aliveAccounts.contains(accId)) {
      continue;
    }
    await lendRepo.purgeByDesignatedAccount(accId);
  }
}

/// 借还落流水对账：历史版本借入/借出只记 LendRecords、不落流水，/// 资产账户余额与流水列表都看不到这笔钱。启动时对「选了资产账户但
/// 没有任何本金流水（含已删）」的借还记录补建，幂等可重复运行。
Future<void> _backfillLendFlowTransactions(AppDatabase db) async {
  final LendRepository lendRepo = LendRepository(db, TransactionRepository(db));
  await lendRepo.backfillFlowTransactions();
}

/// 借还模块流水排除收支统计 / 预算：借款不是收支（借入不是收入、
/// 借出不是支出），否则借款周期会在统计里虚增。历史版本还债/收债
/// 流水计入统计，这里统一翻标记；只动统计开关，不影响余额，幂等。
Future<void> _excludeLendFromStatsAndBudget(AppDatabase db) async {
  await (db.update(db.transactions)
        ..where((Transactions t) =>
            t.sourceModule.equals(SourceModule.lend.index) &
            t.deleted.equals(false) &
            (t.excludeFromStats.equals(false) |
                t.excludeFromBudget.equals(false))))
      .write(
    const TransactionsCompanion(
      excludeFromStats: Value<bool>(true),
      excludeFromBudget: Value<bool>(true),
      dirty: Value<bool>(true),
    ),
  );
}

/// 色调迁移：一级默认分类若仍持有旧版 Material 粉彩色（见
/// [_legacyCategoryPalette]），改写为当前调和色板对应色。
///
/// 仅命中旧色板的颜色会被替换，用户选的其它自定义颜色不动；
/// 函数幂等，可安全在每次启动时运行。
Future<void> _harmonizeDefaultCategoryColors(AppDatabase db) async {
  final List<Book> books = await db.booksDao.watchAll().first;
  final int now = DateTime.now().toUtc().millisecondsSinceEpoch;

  for (final Book book in books) {
    final List<Category> categories =
        await db.categoriesDao.watchAll(book.id).first;
    for (final Category cat in categories) {
      if (cat.parentId != null) continue;
      final int? color = cat.colorValue;
      if (color == null || !_legacyCategoryPalette.contains(color)) continue;
      final Map<String, _DefaultCategory> lookup =
          cat.type == CategoryType.expense
              ? _expenseCategoryLookup
              : _incomeCategoryLookup;
      final _DefaultCategory? def = lookup[cat.name];
      if (def == null || def.colorValue == color) continue;
      await (db.update(db.categories)..where((tbl) => tbl.id.equals(cat.id)))
          .write(
        CategoriesCompanion(
          colorValue: Value<int?>(def.colorValue),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );
    }
  }
}

/// 储蓄旧计划模式回填：v20 之前创建的储蓄目标没有 mode/repeatCycle/endNote
/// 三列，计划卡片标题只能兜底「储蓄计划」、行3三枚胶囊只剩「已执行N次」。
/// 目标金额恰好等于某模式预设总额的按金额反推模式（文案口径与创建页
/// [SavingsModeCreatePage] 落库完全一致），补齐三列——详情页逐期排期
/// 也随之恢复正确节奏。金额对不上任何预设的（定额 / 弹性 / 灵活 /
/// 用户自定义金额）保持原样，不强猜。
///
/// 幂等：只处理 mode 为空的行，且仅在有匹配时写库（dirty 置真走同步）。
Future<void> _backfillSavingsLegacyModes(AppDatabase db) async {
  // 预设总额 → (模式名, 重复周期, 结束方式)，与创建页落库口径一致。
  const Map<int, (String, String, String)> byTarget =
      <int, (String, String, String)>{
    6679500: ('fixed365', '每1天', '执行365次结束'),
    558000: ('countdown30', '每月1日', '执行12次结束'),
    1456000: ('weekday', '每7天', '执行52次结束'),
    1378000: ('weeks52', '每7天', '执行52次结束'),
  };

  final List<SavingsGoal> legacy = await (db.select(db.savingsGoals)
        ..where((SavingsGoals t) => t.mode.isNull() & t.deleted.equals(false)))
      .get();
  if (legacy.isEmpty) return;

  final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
  for (final SavingsGoal g in legacy) {
    final (String, String, String)? hit = byTarget[g.targetMinor];
    if (hit == null) continue;
    final (String, String, String) mode = hit;
    await (db.update(db.savingsGoals)
          ..where((SavingsGoals t) => t.id.equals(g.id)))
        .write(
      SavingsGoalsCompanion(
        mode: Value<String?>(mode.$1),
        repeatCycle: Value<String?>(mode.$2),
        endNote: Value<String?>(mode.$3),
        updatedAt: Value<int>(now),
        dirty: const Value<bool>(true),
      ),
    );
  }
}

/// 储蓄备注预置清理（幂等）：创建页旧逻辑在备注留空时兜底落
/// [SavingsMode.presetNote]（= 模式说明 description），编辑页头像行 /
/// 备注框因此出现「第1天存1元…」预置文案。现口径备注不预置——
/// 备注恰好等于任一模式说明的置 null；用户手写的备注不受影响。
/// 仅在命中时写库（dirty 置真走同步）。
Future<void> _clearPresetSavingsNotes(AppDatabase db) async {
  final Set<String> presets = <String>{
    for (final SavingsMode m in SavingsMode.values) m.description,
  };

  final List<SavingsGoal> rows = await (db.select(db.savingsGoals)
        ..where(
            (SavingsGoals t) => t.note.isNotNull() & t.deleted.equals(false)))
      .get();

  final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
  for (final SavingsGoal g in rows) {
    final String note = g.note ?? '';
    if (!presets.contains(note)) continue;
    await (db.update(db.savingsGoals)
          ..where((SavingsGoals t) => t.id.equals(g.id)))
        .write(
      SavingsGoalsCompanion(
        note: const Value<String?>(null),
        updatedAt: Value<int>(now),
        dirty: const Value<bool>(true),
      ),
    );
  }
}

/// 无预设目标模式的「已存初值」修复（幂等）：旧创建页把输入金额同时落
/// targetMinor 与 currentMinor（定额 / 12 月定额 / 弹性 presetTargetMinor
/// == null 的兜底分支），导致计划一创建就「已存 = 目标」进度 100%。
/// 现口径这三类模式已存初值固定 0——depositCount == 0 且 currentMinor > 0
/// 的行（旧 bug 签名：从未存入却已存）清零已存并撤销完成标记。
/// 有真实存入（depositCount > 0）或预设目标模式不动。
Future<void> _repairSavingsNoPresetCurrent(AppDatabase db) async {
  const Set<String> noPresetModes = <String>{'fixed', 'monthly12', 'elastic'};
  final List<SavingsGoal> rows = await (db.select(db.savingsGoals)
        ..where((SavingsGoals t) =>
            t.mode.isIn(noPresetModes) &
            t.depositCount.equals(0) &
            t.currentMinor.isBiggerThanValue(0) &
            t.deleted.equals(false)))
      .get();
  if (rows.isEmpty) return;

  final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
  for (final SavingsGoal g in rows) {
    await (db.update(db.savingsGoals)
          ..where((SavingsGoals t) => t.id.equals(g.id)))
        .write(
      SavingsGoalsCompanion(
        currentMinor: const Value<int>(0),
        isAchieved: const Value<bool>(false),
        updatedAt: Value<int>(now),
        dirty: const Value<bool>(true),
      ),
    );
  }
}

/// 写入默认账本、账户与一级分类。
Future<void> _seedDefaults(AppDatabase db) async {
  const String bookId = 'default';
  final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
  const Uuid uuid = Uuid();

  await db.transaction<void>(() async {
    await db.booksDao.insertBook(
      BooksCompanion(
        id: const Value<String>(bookId),
        name: const Value<String>('日常账本'),
        createdAt: Value<int>(now),
        updatedAt: Value<int>(now),
      ),
    );

    await db.accountsDao.insertAccount(
      AccountsCompanion(
        id: Value<String>(uuid.v7()),
        bookId: const Value<String>(bookId),
        name: const Value<String>('现金'),
        type: const Value<AccountType>(AccountType.cash),
        updatedAt: Value<int>(now),
      ),
    );

    int order = 0;
    for (final _DefaultCategory parent in _defaultExpenseCategories) {
      final String parentId = uuid.v7();
      await db.categoriesDao.insertCategory(
        CategoriesCompanion(
          id: Value<String>(parentId),
          bookId: const Value<String>(bookId),
          name: Value<String>(parent.name),
          type: const Value<CategoryType>(CategoryType.expense),
          iconKey: Value<String?>(parent.iconKey),
          colorValue: Value<int?>(parent.colorValue),
          sortOrder: Value<int>(order++),
          updatedAt: Value<int>(now),
        ),
      );
      int childOrder = 0;
      for (final _DefaultCategory child in parent.children) {
        await db.categoriesDao.insertCategory(
          CategoriesCompanion(
            id: Value<String>(uuid.v7()),
            bookId: const Value<String>(bookId),
            name: Value<String>(child.name),
            type: const Value<CategoryType>(CategoryType.expense),
            parentId: Value<String?>(parentId),
            iconKey: Value<String?>(child.iconKey),
            // 子类色值 0 表示继承一级分类配色。
            colorValue: Value<int?>(
                child.colorValue == 0 ? parent.colorValue : child.colorValue),
            sortOrder: Value<int>(childOrder++),
            updatedAt: Value<int>(now),
          ),
        );
      }
    }

    order = 0;
    for (final _DefaultCategory parent in _defaultIncomeCategories) {
      final String parentId = uuid.v7();
      await db.categoriesDao.insertCategory(
        CategoriesCompanion(
          id: Value<String>(parentId),
          bookId: const Value<String>(bookId),
          name: Value<String>(parent.name),
          type: const Value<CategoryType>(CategoryType.income),
          iconKey: Value<String?>(parent.iconKey),
          colorValue: Value<int?>(parent.colorValue),
          sortOrder: Value<int>(order++),
          updatedAt: Value<int>(now),
        ),
      );
      int childOrder = 0;
      for (final _DefaultCategory child in parent.children) {
        await db.categoriesDao.insertCategory(
          CategoriesCompanion(
            id: Value<String>(uuid.v7()),
            bookId: const Value<String>(bookId),
            name: Value<String>(child.name),
            type: const Value<CategoryType>(CategoryType.income),
            parentId: Value<String?>(parentId),
            iconKey: Value<String?>(child.iconKey),
            colorValue: Value<int?>(
                child.colorValue == 0 ? parent.colorValue : child.colorValue),
            sortOrder: Value<int>(childOrder++),
            updatedAt: Value<int>(now),
          ),
        );
      }
    }
  });
}

/// 兜底修复：仅对「一级分类 + iconKey 为空 + 名称命中预设」的分类写入图标与配色。
///
/// 不覆盖用户已自定义图标、也不影响子分类，因此可安全在每次启动时运行。
Future<void> _repairDefaultCategoryIcons(AppDatabase db) async {
  final List<Book> books = await db.booksDao.watchAll().first;
  final int now = DateTime.now().toUtc().millisecondsSinceEpoch;

  for (final Book book in books) {
    final List<Category> categories =
        await db.categoriesDao.watchAll(book.id).first;
    for (final Category cat in categories) {
      if (cat.parentId != null) continue;
      if (cat.iconKey != null && cat.iconKey!.isNotEmpty) continue;
      final _DefaultCategory? def = _defaultCategoryLookup[cat.name];
      if (def == null) continue;
      await (db.update(db.categories)..where((tbl) => tbl.id.equals(cat.id)))
          .write(
        CategoriesCompanion(
          iconKey: Value<String?>(def.iconKey),
          colorValue: Value<int?>(def.colorValue),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );
    }
  }
}

/// 重建默认支出分类树（幂等，每次启动安全运行）。
///
/// 对齐设计稿的 11 个一级分区：旧一级同名对齐后**重命名**
/// （交通→出行 / 教育→学习办公 / 医疗→医疗健康 / 人情→人情往来，
/// 仅改名称、保留 ID，绝不破坏历史交易引用），补齐二级子类，
/// 并新增 宠物 / 资金往来 / 投资支出 三个一级分区。绝不删除任何分类。
Future<void> _rebuildExpenseCategoryTree(AppDatabase db) async {
  // 旧一级名 → 新一级名（语义 1:1，保留 ID 不破坏交易引用）。
  const Map<String, String> rename = <String, String>{
    '交通': '出行',
    '教育': '学习办公',
    '医疗': '医疗健康',
    '人情': '人情往来',
  };
  final Uuid uuid = const Uuid();
  final int now = DateTime.now().toUtc().millisecondsSinceEpoch;

  final List<Book> books = await db.booksDao.watchAll().first;
  for (final Book book in books) {
    final List<Category> all = await db.categoriesDao.watchAll(book.id).first;
    final List<Category> parents = all
        .where((Category c) =>
            c.type == CategoryType.expense && c.parentId == null && !c.deleted)
        .toList();

    // 快照内最大一级 sortOrder，用于给新增一级分配顺序（避免碰撞）。
    int maxSo = -1;
    for (final Category c in parents) {
      if (c.sortOrder > maxSo) maxSo = c.sortOrder;
    }
    int createdParents = 0;

    Category? findParent(String targetName) {
      for (final Category c in parents) {
        if (c.name == targetName) return c;
      }
      // 再按「需重命名的旧名」查找。
      String? oldName;
      for (final MapEntry<String, String> e in rename.entries) {
        if (e.value == targetName) {
          oldName = e.key;
          break;
        }
      }
      if (oldName != null) {
        for (final Category c in parents) {
          if (c.name == oldName) return c;
        }
      }
      return null;
    }

    for (final _DefaultCategory def in _defaultExpenseCategories) {
      final Category? existing = findParent(def.name);
      String parentId;
      if (existing == null) {
        parentId = uuid.v7();
        await db.categoriesDao.insertCategory(
          CategoriesCompanion(
            id: Value<String>(parentId),
            bookId: Value<String>(book.id),
            name: Value<String>(def.name),
            type: const Value<CategoryType>(CategoryType.expense),
            iconKey: Value<String?>(def.iconKey),
            colorValue: Value<int?>(def.colorValue),
            sortOrder: Value<int>(maxSo + 1 + createdParents++),
            updatedAt: Value<int>(now),
          ),
        );
      } else {
        parentId = existing.id;
        final String targetName = rename[existing.name] ?? existing.name;
        final bool needRename = targetName != existing.name;
        final bool needIcon = existing.iconKey != def.iconKey;
        final bool needColor = (existing.colorValue ?? 0) != def.colorValue;
        if (needRename || needIcon || needColor) {
          await (db.update(db.categories)
                ..where((tbl) => tbl.id.equals(existing.id)))
              .write(
            CategoriesCompanion(
              name:
                  needRename ? Value<String>(targetName) : const Value.absent(),
              iconKey: Value<String?>(def.iconKey),
              colorValue: Value<int?>(def.colorValue),
              updatedAt: Value<int>(now),
              dirty: const Value<bool>(true),
            ),
          );
        }
      }

      // 二级子类：同名同父已存在则跳过，避免重复。
      int childOrder = 0;
      for (final _DefaultCategory child in def.children) {
        bool exists = false;
        for (final Category c in all) {
          if (c.parentId == parentId && c.name == child.name && !c.deleted) {
            exists = true;
            break;
          }
        }
        if (exists) continue;
        await db.categoriesDao.insertCategory(
          CategoriesCompanion(
            id: Value<String>(uuid.v7()),
            bookId: Value<String>(book.id),
            name: Value<String>(child.name),
            type: const Value<CategoryType>(CategoryType.expense),
            parentId: Value<String?>(parentId),
            iconKey: Value<String?>(child.iconKey),
            colorValue: Value<int?>(
                child.colorValue == 0 ? def.colorValue : child.colorValue),
            sortOrder: Value<int>(childOrder++),
            updatedAt: Value<int>(now),
          ),
        );
      }
    }
  }
}

/// 重建默认收入分类树（幂等，每次启动安全运行）。
///
/// 对齐设计稿的 5 个一级分区（职业收入 / 经营收入 / 副业兼职 / 投资收入 /
/// 资金往来）+ 独立保留「其他」。旧数据按以下口径迁移、**保留 ID**
/// （绝不破坏历史交易引用）：
///  · 投资收益 → 投资收入（同级重命名，成为一级）；
///  · 工资 → 基本工资、奖金 → 绩效奖金、红包 → 人情往来、退款 → 退款返现
///    （下沉为对应一级的二级子分类）；
///  · 副业兼职：旧版为独立一级，现下沉为「经营收入」的二级（保留原 ID），
///    其原二级（骑手 / 视频收入 / 兼职）软删除，避免重复与历史脏数据；
///  · 其余二级子类（津贴补助 / 个体经营 / 证券收入 / 利息收入 / 他人还款 /
///    退税报销）为全新插入；资金往来(一级) 复用既有分类。
Future<void> _rebuildIncomeCategoryTree(AppDatabase db) async {
  // 旧一级名 → 新名（同级重命名）。
  const Map<String, String> rename = <String, String>{
    '投资收益': '投资收入',
  };
  // 旧一级名 → 下沉为二级（新名 + 归属一级）。
  const Map<String, Map<String, String>> demote = <String, Map<String, String>>{
    '工资': <String, String>{'name': '基本工资', 'parent': '职业收入'},
    '奖金': <String, String>{'name': '绩效奖金', 'parent': '职业收入'},
    '红包': <String, String>{'name': '人情往来', 'parent': '资金往来'},
    '退款': <String, String>{'name': '退款返现', 'parent': '资金往来'},
  };
  // 这些二级由旧一级下沉而来，def 循环不再重复创建。
  const Set<String> demotedNames = <String>{
    '基本工资',
    '绩效奖金',
    '人情往来',
    '退款返现',
  };
  final Uuid uuid = const Uuid();
  final int now = DateTime.now().toUtc().millisecondsSinceEpoch;

  final List<Book> books = await db.booksDao.watchAll().first;
  for (final Book book in books) {
    final List<Category> all = await db.categoriesDao.watchAll(book.id).first;
    final List<Category> parents = all
        .where((Category c) =>
            c.type == CategoryType.income && c.parentId == null && !c.deleted)
        .toList();

    int maxSo = -1;
    for (final Category c in parents) {
      if (c.sortOrder > maxSo) maxSo = c.sortOrder;
    }
    int createdParents = 0;

    Category? findParent(String targetName) {
      for (final Category c in parents) {
        if (c.name == targetName) return c;
      }
      String? oldName;
      for (final MapEntry<String, String> e in rename.entries) {
        if (e.value == targetName) {
          oldName = e.key;
          break;
        }
      }
      if (oldName != null) {
        for (final Category c in parents) {
          if (c.name == oldName) return c;
        }
      }
      return null;
    }

    for (final _DefaultCategory def in _defaultIncomeCategories) {
      final Category? existing = findParent(def.name);
      String parentId;
      if (existing == null) {
        parentId = uuid.v7();
        await db.categoriesDao.insertCategory(
          CategoriesCompanion(
            id: Value<String>(parentId),
            bookId: Value<String>(book.id),
            name: Value<String>(def.name),
            type: const Value<CategoryType>(CategoryType.income),
            iconKey: Value<String?>(def.iconKey),
            colorValue: Value<int?>(def.colorValue),
            sortOrder: Value<int>(maxSo + 1 + createdParents++),
            updatedAt: Value<int>(now),
          ),
        );
      } else {
        parentId = existing.id;
        final String targetName = rename[existing.name] ?? existing.name;
        final bool needRename = targetName != existing.name;
        final bool needIcon = existing.iconKey != def.iconKey;
        final bool needColor = (existing.colorValue ?? 0) != def.colorValue;
        if (needRename || needIcon || needColor) {
          await (db.update(db.categories)
                ..where((tbl) => tbl.id.equals(existing.id)))
              .write(
            CategoriesCompanion(
              name: needRename ? Value<String>(targetName) : const Value.absent(),
              iconKey: Value<String?>(def.iconKey),
              colorValue: Value<int?>(def.colorValue),
              updatedAt: Value<int>(now),
              dirty: const Value<bool>(true),
            ),
          );
        }
      }

      int childOrder = 0;
      for (final _DefaultCategory child in def.children) {
        if (demotedNames.contains(child.name)) continue; // 由旧一级下沉创建
        bool exists = false;
        for (final Category c in all) {
          if (c.parentId == parentId && c.name == child.name && !c.deleted) {
            exists = true;
            break;
          }
        }
        if (exists) continue;

        // 旧版「副业兼职」为独立一级，现下沉为经营收入的二级（保留原 ID），
        // 其原二级（骑手 / 视频收入 / 兼职）软删除以避免重复与历史脏数据。
        if (child.name == '副业兼职') {
          Category? oldTop;
          for (final Category c in all) {
            if (c.name == '副业兼职' &&
                c.type == CategoryType.income &&
                c.parentId == null &&
                !c.deleted) {
              oldTop = c;
              break;
            }
          }
          if (oldTop != null) {
            await (db.update(db.categories)
                  ..where((tbl) => tbl.id.equals(oldTop!.id)))
                .write(
              CategoriesCompanion(
                parentId: Value<String?>(parentId),
                colorValue: const Value<int?>(0), // 继承经营收入配色
                sortOrder: Value<int>(childOrder++),
                updatedAt: Value<int>(now),
                dirty: const Value<bool>(true),
              ),
            );
            for (final Category sub in all) {
              if (sub.parentId == oldTop.id && !sub.deleted) {
                await db.categoriesDao.softDelete(sub.id, now);
              }
            }
            continue;
          }
        }

        await db.categoriesDao.insertCategory(
          CategoriesCompanion(
            id: Value<String>(uuid.v7()),
            bookId: Value<String>(book.id),
            name: Value<String>(child.name),
            type: const Value<CategoryType>(CategoryType.income),
            parentId: Value<String?>(parentId),
            iconKey: Value<String?>(child.iconKey),
            colorValue: Value<int?>(
                child.colorValue == 0 ? def.colorValue : child.colorValue),
            sortOrder: Value<int>(childOrder++),
            updatedAt: Value<int>(now),
          ),
        );
      }
    }

    // 旧一级下沉为二级（保留 ID）；若用户无该旧一级，则全新插入目标二级，
    // 保证资金往来下的「退款返现」等即使没有历史「退款」也能补齐。
    for (final MapEntry<String, Map<String, String>> e in demote.entries) {
      final String oldName = e.key;
      final String newName = e.value['name']!;
      final String parentName = e.value['parent']!;
      final Category? parent = findParent(parentName);
      if (parent == null) continue;
      final bool childExists = all.any((Category x) =>
          x.parentId == parent.id && x.name == newName && !x.deleted);
      if (childExists) continue;
      Category? oldTop;
      for (final Category c in all) {
        if (c.name == oldName &&
            c.type == CategoryType.income &&
            c.parentId == null &&
            !c.deleted) {
          oldTop = c;
          break;
        }
      }
      final int childSo = all
              .where((Category x) => x.parentId == parent.id && !x.deleted)
              .length;
      final _DefaultCategory? childDef = _defaultCategoryLookup[newName];
      if (oldTop != null) {
        await (db.update(db.categories)
              ..where((tbl) => tbl.id.equals(oldTop!.id)))
            .write(
          CategoriesCompanion(
            name: Value<String>(newName),
            parentId: Value<String?>(parent.id),
            sortOrder: Value<int>(childSo),
            iconKey: childDef != null
                ? Value<String?>(childDef.iconKey)
                : const Value.absent(),
            colorValue: childDef != null
                ? Value<int?>(childDef.colorValue == 0
                    ? parent.colorValue
                    : childDef.colorValue)
                : const Value.absent(),
            updatedAt: Value<int>(now),
            dirty: const Value<bool>(true),
          ),
        );
      } else {
        await db.categoriesDao.insertCategory(
          CategoriesCompanion(
            id: Value<String>(uuid.v7()),
            bookId: Value<String>(book.id),
            name: Value<String>(newName),
            type: const Value<CategoryType>(CategoryType.income),
            parentId: Value<String?>(parent.id),
            iconKey: childDef != null
                ? Value<String?>(childDef.iconKey)
                : const Value.absent(),
            colorValue: childDef != null
                ? Value<int?>(childDef.colorValue == 0
                    ? parent.colorValue
                    : childDef.colorValue)
                : const Value.absent(),
            sortOrder: Value<int>(childSo),
            updatedAt: Value<int>(now),
          ),
        );
      }
    }
  }
}
