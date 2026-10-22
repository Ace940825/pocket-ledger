import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pocket_ledger/core/bootstrap.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/categories/data/category_repository.dart';
import 'package:pocket_ledger/features/ledger/data/bill_io.dart';
import 'package:pocket_ledger/features/ledger/data/bill_template.dart';

/// 「子分类」列结构化（2026-10-20）：
///  - 导入落库侧：子分类非空 → 在一级分类下按名建/找二级，categoryId 改指二级，
///    报表按 parentId 归集一级（`CategoryRepository.ensureChild`）。
///  - 校验侧：checkRows 对子分类列给出「将挂为二级」提示（不阻断）。
///  - 导出侧：二级交易分类列出一级名（`_exportCategoryName`，见导出页）。
void main() {
  group('ensureChild', () {
    late AppDatabase db;
    late CategoryRepository repo;
    late String bookId;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await bootstrapData(db);
      repo = CategoryRepository(db);
      bookId = (await db.select(db.books).get()).first.id;
    });

    tearDown(() async => db.close());

    test('父下按名建二级：parentId/type 正确，colorValue=0 继承父配色', () async {
      final List<Category> all = await db.select(db.categories).get();
      final Category dining = all.firstWhere(
        (Category c) =>
            c.type == CategoryType.expense && c.name == '餐饮' && !c.deleted,
      );

      final String id = await repo.ensureChild(
        bookId: bookId,
        parentId: dining.id,
        name: '公共交通',
        type: CategoryType.expense,
      );

      final Category? created =
          await (db.select(db.categories)
                ..where(($CategoriesTable t) => t.id.equals(id)))
              .getSingleOrNull();
      expect(created, isNotNull);
      expect(created!.name, '公共交通');
      expect(created.parentId, dining.id);
      expect(created.type, CategoryType.expense);
      // 0 = 继承父分类配色（与 bootstrap 种子中子类语义一致）。
      expect(created.colorValue, 0);
    });

    test('同名二级复用同一 ID，不重复建', () async {
      final List<Category> all = await db.select(db.categories).get();
      final Category travel = all.firstWhere(
        (Category c) =>
            c.type == CategoryType.expense && c.name == '出行' && !c.deleted,
      );
      final String a = await repo.ensureChild(
        bookId: bookId,
        parentId: travel.id,
        name: '公共交通',
        type: CategoryType.expense,
      );
      final String b = await repo.ensureChild(
        bookId: bookId,
        parentId: travel.id,
        name: '公共交通',
        type: CategoryType.expense,
      );
      expect(a, b);
      final int count = (await db.select(db.categories).get())
          .where((Category c) =>
              c.name == '公共交通' && c.parentId == travel.id && !c.deleted,)
          .length;
      expect(count, 1);
    });

    test('不同父下的同名子分类互相隔离，各建各的', () async {
      final List<Category> all = await db.select(db.categories).get();
      final Category travel = all.firstWhere(
        (Category c) =>
            c.type == CategoryType.expense && c.name == '出行' && !c.deleted,
      );
      final Category home = all.firstWhere(
        (Category c) =>
            c.type == CategoryType.expense && c.name == '居住' && !c.deleted,
      );
      final String a = await repo.ensureChild(
        bookId: bookId,
        parentId: travel.id,
        name: '话费网费',
        type: CategoryType.expense,
      );
      final String b = await repo.ensureChild(
        bookId: bookId,
        parentId: home.id,
        name: '话费网费',
        type: CategoryType.expense,
      );
      expect(a, isNot(b));
    });

    test('bootstrap 预置二级可命中（导入不重复建）', () async {
      final List<Category> all = await db.select(db.categories).get();
      final Category travel = all.firstWhere(
        (Category c) =>
            c.type == CategoryType.expense && c.name == '出行' && !c.deleted,
      );
      final String id = await repo.ensureChild(
        bookId: bookId,
        parentId: travel.id,
        name: '公共交通',
        type: CategoryType.expense,
      );
      final Category existing = all.firstWhere(
        (Category c) =>
            c.name == '公共交通' && c.parentId == travel.id && !c.deleted,
      );
      expect(id, existing.id);
    });
  });

  group('checkRows 子分类提示', () {
    BillRow rowWithSub(String category, String subcategory) => BillRow(
          occurredAt: DateTime.parse('2026-10-01T10:00'),
          type: TxnType.expense,
          amountMinor: 2550,
          accountName: '微信',
          categoryName: category,
          subcategoryName: subcategory.isEmpty ? null : subcategory,
        );

    test('子分类非空时提示将挂为二级（同一名只提示一次）', () {
      final TemplateCheckResult c = checkRows(
        <BillRow>[
          rowWithSub('出行', '公共交通'),
          rowWithSub('出行', '公共交通'),
          rowWithSub('购物', '果蔬蛋奶'),
        ],
        accountNames: <String>{'微信'},
        categoryNamesByType: <Set<String>>[
          <String>{},
          <String>{'出行', '购物'},
          <String>{},
        ],
      );
      final List<String> subWarns = c.warnings
          .where((String w) => w.startsWith('子分类「'))
          .toList();
      expect(subWarns, hasLength(2));
      expect(subWarns.first, contains('公共交通'));
      expect(subWarns.first, contains('二级分类'));
      expect(subWarns.first, contains('「出行」下'));
      // 提示不阻断：errors 为空。
      expect(c.errors, isEmpty);
    });

    test('子分类为空时不提示', () {
      final TemplateCheckResult c = checkRows(
        <BillRow>[rowWithSub('出行', '')],
        accountNames: <String>{'微信'},
        categoryNamesByType: <Set<String>>[
          <String>{},
          <String>{'出行'},
          <String>{},
        ],
      );
      expect(c.warnings.where((String w) => w.startsWith('子分类「')), isEmpty);
    });

    test('借还/储蓄/投资模块行不参与子分类提示', () {
      final TemplateCheckResult c = checkRows(
        <BillRow>[
          BillRow(
            occurredAt: DateTime.parse('2026-10-01T10:00'),
            type: TxnType.income,
            amountMinor: 1000,
            accountName: '微信',
            categoryName: '收债',
            subcategoryName: '借出账款',
            module: SourceModule.lend,
          ),
        ],
        accountNames: <String>{'微信'},
        categoryNamesByType: <Set<String>>[
          <String>{},
          <String>{'收债'},
          <String>{},
        ],
      );
      expect(c.warnings.where((String w) => w.startsWith('子分类「')), isEmpty);
    });
  });
}
