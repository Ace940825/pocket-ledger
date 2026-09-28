import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../domain/enums.dart';
import '../features/categories/data/category_repository.dart';
import '../features/lend/data/lend_repository.dart';
import '../features/ledger/data/transaction_repository.dart';

/// 默认分类的图标与配色预设。
class _DefaultCategory {
  const _DefaultCategory(this.name, this.iconKey, this.colorValue);
  final String name;
  final String iconKey;
  final int colorValue;
}

/// 默认支出分类（一级）。
/// 色板为 ForestSage 调和色：中饱和、整体偏暖，与暖纸底 #FBF6EA /
/// 黄绿渐变 #AED494 同调（旧 Material 300 粉彩偏冷，已弃用，见
/// [_legacyCategoryPalette] 迁移）。
const List<_DefaultCategory> _defaultExpenseCategories = <_DefaultCategory>[
  _DefaultCategory('餐饮', 'restaurant', 0xFFD96F52), // 陶土红
  _DefaultCategory('交通', 'transport', 0xFF5C82B8), // 雾蓝
  _DefaultCategory('购物', 'shopping', 0xFFB86A9E), // 玫紫
  _DefaultCategory('居住', 'home', 0xFFA97742), // 木质棕
  _DefaultCategory('娱乐', 'entertainment', 0xFF8F6FBF), // 葡萄紫
  _DefaultCategory('医疗', 'medical', 0xFF4A96A6), // 青瓷蓝
  _DefaultCategory('教育', 'education', 0xFF6470C2), // 靛蓝紫
  _DefaultCategory('通讯', 'phone', 0xFF4C9E74), // 鼠尾草绿
  _DefaultCategory('人情', 'heart', 0xFFCE6478), // 玫红
  _DefaultCategory('其他', 'settings', 0xFFC7A24A), // 赭金
];

/// 默认收入分类（一级）
const List<_DefaultCategory> _defaultIncomeCategories = <_DefaultCategory>[
  _DefaultCategory('工资', 'salary', 0xFF45936A), // 深鼠尾草
  _DefaultCategory('奖金', 'bonus', 0xFFD69E3C), // 金黄
  _DefaultCategory('投资收益', 'investment', 0xFF4E93A6), // 石青
  _DefaultCategory('兼职', 'work', 0xFF6B87C9), // 长春花蓝
  _DefaultCategory('红包', 'red_envelope', 0xFFC7564E), // 枣红
  _DefaultCategory('退款', 'refund', 0xFF8E8A7E), // 暖灰
  _DefaultCategory('其他', 'settings', 0xFFC7A24A), // 赭金
];

/// 旧版 Material 300 粉彩色板（旧种子 + 分类编辑器预设的并集）。
/// 启动时命中该集合的默认分类颜色会被静默迁移为新调和色板，
/// 真正自定义的其它颜色不受影响。
const Set<int> _legacyCategoryPalette = <int>{
  0xFFE57373, 0xFFF06292, 0xFFBA68C8, 0xFF9575CD,
  0xFF7986CB, 0xFF64B5F6, 0xFF4FC3F7, 0xFF4DB6AC,
  0xFF81C784, 0xFFFFB74D, 0xFFA1887F, 0xFF90A4AE,
  0xFF12B886, 0xFFEF9F27, 0xFFE5484D, 0xFF378ADD,
  0xFFD4537E, 0xFF888780,
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
  final List<Book> books = await db.booksDao.watchAll().first;
  if (books.isEmpty) {
    await _seedDefaults(db);
    return;
  }
  // 已存在账本：兜底修复老版本默认分类缺少图标/颜色的问题（只补空白值）。
  await _repairDefaultCategoryIcons(db);
  // 色调迁移：旧 Material 粉彩 → ForestSage 调和色板（幂等，每次启动运行）。
  await _harmonizeDefaultCategoryColors(db);
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
    final LendDirection dir = a.type == AccountType.lend.index
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
  final List<LendRecord> undesignated =
      await (db.select(db.lendRecords)
            ..where((LendRecords t) =>
                t.accountId.isNull() & t.deleted.equals(false)))
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
    await (db.update(db.lendRecords)..where((LendRecords t) => t.id.equals(r.id)))
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
/// 识别的行保持未分类。幂等：仅 categoryId 为空的行会被处理。
Future<void> _backfillLendFlowCategories(AppDatabase db) async {
  final List<Transaction> txns = await (db.select(db.transactions)
        ..where((Transactions t) =>
            t.sourceModule.equals(SourceModule.lend.index) &
            t.categoryId.isNull() &
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
        name = '债务消减';
        type = CategoryType.income;
      case '坏账计提':
        name = '坏账计提';
    }
    if (name == null) continue;

    final String cacheKey = '${txn.bookId}:$name:${type.index}';
    final String? cached = cache[cacheKey];
    final String categoryId = cached ??
        await catRepo.ensureNamed(bookId: txn.bookId, name: name, type: type);
    cache[cacheKey] = categoryId;

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
    for (final _DefaultCategory c in _defaultExpenseCategories) {
      await db.categoriesDao.insertCategory(
        CategoriesCompanion(
          id: Value<String>(uuid.v7()),
          bookId: const Value<String>(bookId),
          name: Value<String>(c.name),
          type: const Value<CategoryType>(CategoryType.expense),
          iconKey: Value<String?>(c.iconKey),
          colorValue: Value<int?>(c.colorValue),
          sortOrder: Value<int>(order++),
          updatedAt: Value<int>(now),
        ),
      );
    }

    order = 0;
    for (final _DefaultCategory c in _defaultIncomeCategories) {
      await db.categoriesDao.insertCategory(
        CategoriesCompanion(
          id: Value<String>(uuid.v7()),
          bookId: const Value<String>(bookId),
          name: Value<String>(c.name),
          type: const Value<CategoryType>(CategoryType.income),
          iconKey: Value<String?>(c.iconKey),
          colorValue: Value<int?>(c.colorValue),
          sortOrder: Value<int>(order++),
          updatedAt: Value<int>(now),
        ),
      );
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
