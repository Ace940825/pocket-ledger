import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pocket_ledger/core/bootstrap.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/ledger/data/transaction_repository.dart';
import 'package:pocket_ledger/features/ledger/presentation/bill_convert_page.dart';
import 'package:pocket_ledger/providers/app_providers.dart';
import 'package:pocket_ledger/theme/app_theme.dart';

/// 「批量转换」分类选择器 + 收支方向合并的三条回归（2026-10-22 真机反馈）：
///
/// ① **二级分类没有返回一级的路径**（只能彻底返回后再进入）
///    → 二级弹层标题栏带返回键，点它回到一级；一级弹层在此期间不关闭。
/// ② **在分类弹窗点框外没反应**，只能点批量转换的框外
///    → 分类选择流程改走独立遮罩的整屏路由，卡片外任意处点击都能关闭。
/// ③ **改收支类型移除，功能合并到改分类**
///    → 面板不再有「改收支类型」开关；选中分类后自动按分类方向改收支类型。
void main() {
  /// 弹层标题（17 / w800）——与面板里的同名占位文案（14 / w400）区分。
  Finder sheetTitle(String text) => find.byWidgetPredicate(
        (Widget w) =>
            w is Text && w.data == text && w.style?.fontSize == 17,
      );

  /// 弹层列表行（15 / w600）——与页面流水行（16 / w700）区分。
  Finder sheetRow(String text) => find.byWidgetPredicate(
        (Widget w) =>
            w is Text && w.data == text && w.style?.fontSize == 15,
      );

  /// 转换面板里的行文案（14 / w400）。
  Finder panelRow(String text) => find.byWidgetPredicate(
        (Widget w) =>
            w is Text && w.data == text && w.style?.fontSize == 14,
      );

  late Directory tmp;
  late AppDatabase db;
  late TransactionRepository txnRepo;

  /// 支出段 sortOrder 首位的一级分类（含子分类，种子「餐饮」）。
  late String expenseParentName;
  /// 收入段 sortOrder 首位的一级分类。
  // ignore: unused_local_variable
  late String incomeParentName;
  /// 上述支出一级下的首个二级分类名。
  late String? expenseChildName;
  /// 支出 / 收入两个分类的 id（repository 层断言用）。
  late String expenseParentId;
  late String incomeParentId;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('pl_convert_picker_test');
    db = AppDatabase(NativeDatabase(File(p.join(tmp.path, 'ledger.db'))));
    await bootstrapData(db);
    txnRepo = TransactionRepository(db);
    await db.accountsDao.insertAccount(
      const AccountsCompanion(
        id: Value<String>('现金'),
        bookId: Value<String>('default'),
        name: Value<String>('现金'),
        type: Value<AccountType>(AccountType.cash),
        updatedAt: Value<int>(0),
      ),
    );
    final List<Category> cats =
        await db.categoriesDao.watchAll('default').first;
    List<Category> parentsOf(CategoryType t) => cats
        .where(
          (Category c) =>
              c.type == t &&
              c.parentId == null &&
              !c.isSystem &&
              c.deleted == false,
        )
        .toList()
      ..sort((Category a, Category b) => a.sortOrder.compareTo(b.sortOrder));

    final Category expenseParent = parentsOf(CategoryType.expense).first;
    final Category incomeParent = parentsOf(CategoryType.income).first;
    expenseParentName = expenseParent.name;
    incomeParentName = incomeParent.name;
    expenseParentId = expenseParent.id;
    incomeParentId = incomeParent.id;
    final List<Category> kids = cats
        .where(
          (Category c) =>
              c.parentId == expenseParent.id && c.deleted == false,
        )
        .toList()
      ..sort((Category a, Category b) => a.sortOrder.compareTo(b.sortOrder));
    expenseChildName = kids.isEmpty ? null : kids.first.name;

    // 一笔支出流水（挂支出分类）。
    await txnRepo.add(
      bookId: 'default',
      type: TxnType.expense,
      amountMinor: 1000,
      accountId: '现金',
      categoryId: expenseParentId,
      occurredAt: DateTime(2026, 10, 10, 12, 0).millisecondsSinceEpoch,
      note: 'picker-test',
    );
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppThemeData.light,
          home: const BillConvertPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 收尾：卸载页面让 ProviderScope 走 dispose，再推进时钟消化 drift 流
  /// 查询的 0 时长关闭定时器（否则测试框架报 pending timer）。
  Future<void> disposePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 20));
  }

  /// 全选 → 打开转换面板 → 打开「改分类」→ 打开一级分类弹层。
  Future<void> openCategoryPicker(WidgetTester tester) async {
    await tester.tap(find.text('全选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('转换(1个)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择分类'));
    await tester.pumpAndSettle();
  }

  testWidgets('① 二级弹层有返回键，点它回到一级（一级不关闭）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(414, 896));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester);
    await openCategoryPicker(tester);

    // 一级弹层在。
    expect(sheetTitle('选择分类'), findsOneWidget, reason: '一级分类弹层应打开');

    // 点进有子分类的一级 → 二级弹层叠开。
    await tester.tap(sheetRow(expenseParentName));
    await tester.pumpAndSettle();
    expect(find.text('直接使用一级分类'), findsOneWidget, reason: '二级弹层应打开');

    // 二级标题栏带返回键（专属 key 精确命中）。
    final Finder backBtn = find.byKey(const Key('category-sheet-back'));
    expect(backBtn, findsOneWidget, reason: '二级标题栏应有返回键');

    // 点返回键 → 回到一级（二级关闭，一级仍在）。
    await tester.tap(backBtn);
    await tester.pumpAndSettle();
    expect(find.text('直接使用一级分类'), findsNothing, reason: '二级应关闭');
    expect(sheetTitle('选择分类'), findsOneWidget, reason: '应回到一级弹层');
    expect(
      sheetRow(expenseParentName),
      findsOneWidget,
      reason: '一级列表仍在（可换别的分类）',
    );
    await disposePage(tester);
  });

  testWidgets('② 分类弹层点框外能关闭（不再只关掉批量转换面板）',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(414, 896));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester);
    await openCategoryPicker(tester);
    expect(sheetTitle('选择分类'), findsOneWidget);

    // 点卡片外的空白（屏幕顶部区域，分类卡片之外）。
    await tester.tapAt(const Offset(207, 30));
    await tester.pumpAndSettle();
    expect(
      sheetTitle('选择分类'),
      findsNothing,
      reason: '框外点击应关闭分类弹层',
    );
    // 批量转换面板仍在（只关掉分类弹层这一层）。
    expect(
      find.text('已选中 1 笔，选择要改写的项（可多选）'),
      findsOneWidget,
      reason: '批量转换面板不应被一起关掉',
    );
    await disposePage(tester);
  });

  testWidgets('③ 面板移除「改收支类型」开关，选中分类自动带方向', (tester) async {
    await tester.binding.setSurfaceSize(const Size(414, 896));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester);
    await openCategoryPicker(tester);

    // 选一个叶子分类（无子分类的一级）直接回填。
    // 用「餐饮」的一级分类名找不到叶子时，用二级里的首个分类。
    if (expenseChildName != null) {
      await tester.tap(sheetRow(expenseParentName));
      await tester.pumpAndSettle();
      await tester.tap(sheetRow(expenseChildName!));
      await tester.pumpAndSettle();
    }

    // 面板里不应再有「改收支类型」这一行。
    expect(panelRow('改收支类型'), findsNothing);
    // 开关数从 5 降到 4（改分类 / 改账户 / 改标签 / 改备注）。
    expect(find.byType(Switch), findsNWidgets(4));
    await disposePage(tester);
  });

  testWidgets('③ 选中分类后回填行带方向标注', (tester) async {
    await tester.binding.setSurfaceSize(const Size(414, 896));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester);
    await openCategoryPicker(tester);

    await tester.tap(sheetRow(expenseParentName));
    await tester.pumpAndSettle();
    // 选「直接使用一级分类」→ 选中一级分类（支出方向）。
    await tester.tap(find.text('直接使用一级分类'));
    await tester.pumpAndSettle();

    expect(
      panelRow('$expenseParentName（支出）'),
      findsOneWidget,
      reason: '选择器行应显示分类名 + 方向',
    );
    await disposePage(tester);
  });

  group('③ repository 层：改分类即按分类方向改收支类型', () {
    test('支出账单改成收入分类 → 类型变收入、分类变收入类', () async {
      final List<String> ids = <String>[
        (await db.transactionsDao.watchAll(bookId: 'default').first)
            .first
            .id,
      ];
      final (int converted, int skipped) = await txnRepo.convertBatch(
        ids,
        categoryId: incomeParentId,
        type: TxnType.income,
      );
      expect(converted, 1);
      expect(skipped, 0);

      final Transaction? t = await db.transactionsDao.getById(ids.first);
      expect(t, isNotNull);
      expect(t!.type, TxnType.income, reason: '类型应按分类方向改为收入');
      expect(t.categoryId, incomeParentId);
    });

    test('同方向换分类 → 类型不变、分类照改', () async {
      final List<String> ids = <String>[
        (await db.transactionsDao.watchAll(bookId: 'default').first)
            .first
            .id,
      ];
      final (int converted, int skipped) = await txnRepo.convertBatch(
        ids,
        categoryId: expenseParentId,
        type: TxnType.expense,
      );
      expect(converted, 1);
      expect(skipped, 0);

      final Transaction? t = await db.transactionsDao.getById(ids.first);
      expect(t!.type, TxnType.expense);
      expect(t.categoryId, expenseParentId);
    });
  });
}
