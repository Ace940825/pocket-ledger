import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../domain/enums.dart';

/// 默认分类的图标与配色预设。
class _DefaultCategory {
  const _DefaultCategory(this.name, this.iconKey, this.colorValue);
  final String name;
  final String iconKey;
  final int colorValue;
}

/// 默认支出分类（一级）
const List<_DefaultCategory> _defaultExpenseCategories = <_DefaultCategory>[
  _DefaultCategory('餐饮', 'restaurant', 0xFFE57373),
  _DefaultCategory('交通', 'transport', 0xFFF06292),
  _DefaultCategory('购物', 'shopping', 0xFFBA68C8),
  _DefaultCategory('居住', 'home', 0xFF9575CD),
  _DefaultCategory('娱乐', 'entertainment', 0xFF7986CB),
  _DefaultCategory('医疗', 'medical', 0xFF64B5F6),
  _DefaultCategory('教育', 'education', 0xFF4FC3F7),
  _DefaultCategory('通讯', 'phone', 0xFF4DB6AC),
  _DefaultCategory('人情', 'heart', 0xFF81C784),
  _DefaultCategory('其他', 'settings', 0xFFFFB74D),
];

/// 默认收入分类（一级）
const List<_DefaultCategory> _defaultIncomeCategories = <_DefaultCategory>[
  _DefaultCategory('工资', 'salary', 0xFF12B886),
  _DefaultCategory('奖金', 'bonus', 0xFFEF9F27),
  _DefaultCategory('投资收益', 'investment', 0xFFE5484D),
  _DefaultCategory('兼职', 'work', 0xFF378ADD),
  _DefaultCategory('红包', 'red_envelope', 0xFFD4537E),
  _DefaultCategory('退款', 'refund', 0xFF888780),
  _DefaultCategory('其他', 'settings', 0xFFFFB74D),
];

/// 默认预设的分类查询表（name -> 预设图标/配色）。
final Map<String, _DefaultCategory> _defaultCategoryLookup =
    <String, _DefaultCategory>{
  for (final _DefaultCategory c in _defaultExpenseCategories) c.name: c,
  for (final _DefaultCategory c in _defaultIncomeCategories) c.name: c,
};

/// 首次启动时写入默认数据，保证应用开箱可用。
///
/// 幂等：已存在账本时直接返回，不会重复写入。
Future<void> bootstrapData(AppDatabase db) async {
  final List<Book> books = await db.booksDao.watchAll().first;
  if (books.isEmpty) {
    await _seedDefaults(db);
    return;
  }
  // 已存在账本：兜底修复老版本默认分类缺少图标/颜色的问题（只补空白值）。
  await _repairDefaultCategoryIcons(db);
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
      await (db.update(db.categories)
            ..where((tbl) => tbl.id.equals(cat.id)))
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
