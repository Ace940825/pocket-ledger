import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../domain/enums.dart';
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
  // 借还落流水对账（幂等，每次启动运行）：有可挂账户（资产账户优先，
  // 其次指定借入/借出账户）但缺本金流水的借还记录补建流水；借还模块
  // 流水统一排除收支统计与预算。补建必须在余额对账**之前**——补建的
  // 流水挂在指定账户上会带错向余额增量，随后由对账覆盖修复。
  await _backfillLendFlowTransactions(db);
  await _excludeLendFromStatsAndBudget(db);
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

/// 借还落流水对账：历史版本借入/借出只记 LendRecords、不落流水，
/// 资产账户余额与流水列表都看不到这笔钱。启动时对「选了资产账户但
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
