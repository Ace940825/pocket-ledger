import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../domain/enums.dart';

/// 默认支出分类
const List<String> _defaultExpenseCategories = <String>[
  '餐饮',
  '交通',
  '购物',
  '居住',
  '娱乐',
  '医疗',
  '教育',
  '通讯',
  '人情',
  '其他',
];

/// 默认收入分类
const List<String> _defaultIncomeCategories = <String>[
  '工资',
  '奖金',
  '投资收益',
  '兼职',
  '红包',
  '退款',
  '其他',
];

/// 首次启动时写入默认数据，保证应用开箱可用。
///
/// 幂等：已存在账本时直接返回，不会重复写入。
Future<void> bootstrapData(AppDatabase db) async {
  final List<Book> books = await db.booksDao.watchAll().first;
  if (books.isNotEmpty) return;

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
    for (final String name in _defaultExpenseCategories) {
      await db.categoriesDao.insertCategory(
        CategoriesCompanion(
          id: Value<String>(uuid.v7()),
          bookId: const Value<String>(bookId),
          name: Value<String>(name),
          type: const Value<CategoryType>(CategoryType.expense),
          sortOrder: Value<int>(order++),
          updatedAt: Value<int>(now),
        ),
      );
    }

    order = 0;
    for (final String name in _defaultIncomeCategories) {
      await db.categoriesDao.insertCategory(
        CategoriesCompanion(
          id: Value<String>(uuid.v7()),
          bookId: const Value<String>(bookId),
          name: Value<String>(name),
          type: const Value<CategoryType>(CategoryType.income),
          sortOrder: Value<int>(order++),
          updatedAt: Value<int>(now),
        ),
      );
    }
  });
}
