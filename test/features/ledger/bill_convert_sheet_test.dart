import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
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
import 'package:pocket_ledger/shared/widgets/clay_icon_tile.dart';
import 'package:pocket_ledger/shared/widgets/sheet_scaffold.dart';
import 'package:pocket_ledger/theme/app_theme.dart';

/// 面板独有文案（避开与页面标题「批量转换」同名）。
final Finder _sheetBodyText =
    find.text('已选中 3 笔，选择要改写的项（可多选）');

/// 批量转换面板回归测试（2026-10-22 真机四连反馈）：
///
/// ① 「点框外不能返回」——根因是「选择分类」二级弹窗的裸 ListView 在
///    AppModalSheet 自适应高度 Column 里拿到无界高度直接崩溃，崩掉的弹窗
///    留在栈顶只透出遮罩，点框外只关掉这个隐形弹窗。修好渲染后，点外面
///    按栈顶依次关闭（先二级后一级）即恢复预期。
/// ② 「选择分类不显示」——同上，ListView 无界高度崩溃。
/// ③ 「键盘弹起 BOTTOM OVERFLOWED BY 321 PIXELS」——AppModalSheet 的
///    Padding(bottom: viewInset) 与内容自适应高度叠加，把卡片撑超屏幕；
///    现外壳给 body 槽位加「屏高 − 键盘 − 铬件」上限，超高 body 内部滚动。
/// ④ 「改标签和备注像素不对」——③ 的连带（溢出导致输入框布局错位）。
///
/// 本文件驱动**真实页面** BillConvertPage + 真实 DB + 真实 providers，
/// 1:1 还原用户操作路径：全选 → 转换 → 弹层内开开关 / 选分类 / 键盘弹起。
void main() {
  /// setUp 里预取的「支出段 sortOrder 首位一级分类」名（种子里是「餐饮」）。
  /// 测试体跑在 fake_async 里，裸 await drift 流查询拿不到 isolate 回包会
  /// 永久挂起，必须在外层真实异步区预取；取排序首项保证它是列表第一行、
  /// 必然被构建。
  late String firstParentName;
  /// 上述一级分类下 sortOrder 首位的子分类名（无子分类时为 null）。
  late String? firstChildName;
  late Directory tmp;
  late AppDatabase db;
  late TransactionRepository txnRepo;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('pl_convert_sheet_test');
    db = AppDatabase(NativeDatabase(File(p.join(tmp.path, 'ledger.db'))));
    await bootstrapData(db);
    txnRepo = TransactionRepository(db);
    await db.accountsDao.insertAccount(
      AccountsCompanion(
        id: const Value<String>('现金'),
        bookId: const Value<String>('default'),
        name: const Value<String>('现金'),
        type: const Value<AccountType>(AccountType.cash),
        updatedAt: const Value<int>(0),
      ),
    );
    final List<Category> cats =
        await db.categoriesDao.watchAll('default').first;
    final List<Category> expenseCats = cats
        .where((Category c) =>
            c.type == CategoryType.expense && c.deleted == false)
        .toList();
    // 一级弹窗口径：parentId == null && 非系统，段内按 sortOrder。
    final List<Category> parents = cats
        .where(
          (Category c) =>
              c.type == CategoryType.expense &&
              c.parentId == null &&
              !c.isSystem &&
              c.deleted == false,
        )
        .toList()
      ..sort((Category a, Category b) => a.sortOrder.compareTo(b.sortOrder));
    final Category firstParent = parents.first;
    firstParentName = firstParent.name;
    final List<Category> kids = cats
        .where((Category c) => c.parentId == firstParent.id && c.deleted == false)
        .toList()
      ..sort((Category a, Category b) => a.sortOrder.compareTo(b.sortOrder));
    firstChildName = kids.isEmpty ? null : kids.first.name;
    // 三笔本月流水（页面默认周期 = 当月）。
    for (int i = 0; i < 3; i++) {
      await txnRepo.add(
        bookId: 'default',
        type: TxnType.expense,
        amountMinor: 1000 * (i + 1),
        accountId: '现金',
        categoryId: expenseCats.first.id,
        occurredAt: DateTime(2026, 10, 10 + i, 12, 0).millisecondsSinceEpoch,
        note: 'convert-test-$i',
      );
    }
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<void> pumpPage(WidgetTester tester,
      {Brightness brightness = Brightness.light}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: brightness == Brightness.light
              ? AppThemeData.light
              : AppThemeData.dark,
          home: const BillConvertPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 有界 pumping：渲染异常时避免 pumpAndSettle 永久挂起拖垮整个测试文件。
  Future<void> pumpFrames(WidgetTester tester, [int frames = 12]) async {
    for (int i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// 收尾：卸载页面让 ProviderScope 走 dispose，再推进时钟消化 drift 流
  /// 查询的 0 时长关闭定时器（否则测试框架报 pending timer）。
  Future<void> disposePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 20));
  }

  /// 全选并打开转换面板。
  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('全选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('转换(3个)'));
    await tester.pumpAndSettle();
  }

  testWidgets('点框外按栈顶依次关闭：先关分类选择、再关转换面板', (tester) async {
    await tester.binding.setSurfaceSize(const Size(414, 896));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester);
    await openSheet(tester);
    expect(_sheetBodyText, findsOneWidget, reason: '转换面板应打开');

    // 打开「改分类」开关 → 点「选择分类」弹出二级弹窗。
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择分类'));
    await pumpFrames(tester);
    expect(tester.takeException(), isNull, reason: '二级弹窗不应崩溃');
    expect(find.byType(AppModalSheet), findsNWidgets(2),
        reason: '转换面板 + 分类选择两个弹窗同时在栈');

    // 第一次点框外：只应关掉栈顶的「选择分类」。
    await tester.tapAt(const Offset(207, 30));
    await tester.pumpAndSettle();
    expect(find.byType(AppModalSheet), findsOneWidget,
        reason: '二级弹窗应关闭，转换面板仍在');
    expect(_sheetBodyText, findsOneWidget);

    // 第二次点框外：关掉转换面板。
    await tester.tapAt(const Offset(207, 30));
    await tester.pumpAndSettle();
    expect(_sheetBodyText, findsNothing, reason: '转换面板应关闭');
    await disposePage(tester);
  });

  testWidgets('选择分类：一级弹窗带分类图标 + 分段，钻取二级后回填', (tester) async {
    await tester.binding.setSurfaceSize(const Size(414, 896));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester);
    await openSheet(tester);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择分类'));
    await pumpFrames(tester);

    expect(
      tester.takeException(),
      isNull,
      reason: '分类弹窗不应崩溃（ListView 无界高度）',
    );

    final Finder level1 = find.byType(AppModalSheet).last;
    // 图标与全应用分类图标同源（ClayIconTile + CategoryGlyph），不再是
    // 「分类名首字」头像。
    expect(
      find.descendant(of: level1, matching: find.byType(ClayIconTile)),
      findsWidgets,
      reason: '一级列表每行应带分类图标',
    );
    expect(
      find.descendant(of: level1, matching: find.text('支出')),
      findsOneWidget,
      reason: '一级按 支出 / 收入 分段',
    );

    // 点第一行一级分类（种子里「餐饮」，带子分类）→ 在一级之上**叠开**二级
    // 弹层（一级不关闭，可随时退回）。栈里是「转换面板 + 一级 + 二级」三个。
    await tester.tap(
      find.descendant(of: level1, matching: find.text(firstParentName)),
    );
    await tester.pumpAndSettle();
    expect(
      find.byType(AppModalSheet),
      findsNWidgets(3),
      reason: '转换面板 + 一级 + 二级（一级常驻）',
    );
    expect(
      find.text('直接使用一级分类'),
      findsOneWidget,
      reason: '二级弹窗顶部保留「直接用一级」出口',
    );

    // 二级弹窗里选「直接使用一级分类」→ 两级弹层全部关闭、面板行回填。
    await tester.tap(find.text('直接使用一级分类'));
    await tester.pumpAndSettle();
    expect(find.text('选择分类'), findsNothing, reason: '占位文案应被替换');
    // 页面流水的分类列也会出现同名文本（流水挂的就是该分类），这里按
    // 选择器行的字号（14 / w400）精确定位回填行。
    // 回填行带方向标注（分类按支出/收入划分，方向随分类自动调整）。
    expect(
      find.byWidgetPredicate(
        (Widget w) =>
            w is Text &&
            w.data == '$firstParentName（支出）' &&
            w.style?.fontSize == 14,
      ),
      findsOneWidget,
      reason: '面板行回填一级分类名 + 方向',
    );
    await disposePage(tester);
  });

  testWidgets('选择分类：二级弹窗选子分类后回填子分类名', (tester) async {
    if (firstChildName == null) {
      // 种子分类若被改造成无子分类，本用例无意义（不影响其余用例）。
      return;
    }
    await tester.binding.setSurfaceSize(const Size(414, 896));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester);
    await openSheet(tester);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择分类'));
    await pumpFrames(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(AppModalSheet).last,
        matching: find.text(firstParentName),
      ),
    );
    await tester.pumpAndSettle();

    final Finder level2 = find.byType(AppModalSheet).last;
    expect(
      find.descendant(of: level2, matching: find.byType(ClayIconTile)),
      findsWidgets,
      reason: '二级列表也应带分类图标',
    );
    await tester.tap(
      find.descendant(of: level2, matching: find.text(firstChildName!)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppModalSheet), findsOneWidget, reason: '两级弹层都应关闭');
    // 回填行带方向标注（分类按支出/收入划分，方向随分类自动调整）。
    expect(
      find.byWidgetPredicate(
        (Widget w) =>
            w is Text &&
            w.data == '$firstChildName（支出）' &&
            w.style?.fontSize == 14,
      ),
      findsOneWidget,
      reason: '回填子分类名 + 方向',
    );
    await disposePage(tester);
  });

  /// 打开分类一级弹窗（转换面板 → 改分类 → 选择分类）。
  Future<void> openLevel1(WidgetTester tester, Brightness brightness) async {
    await pumpPage(tester, brightness: brightness);
    await openSheet(tester);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择分类'));
    await pumpFrames(tester);
  }

  testWidgets('golden：分类一级弹窗亮色', (tester) async {
    await tester.binding.setSurfaceSize(const Size(414, 896));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openLevel1(tester, Brightness.light);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('bill_convert_category_level1_light.png'),
    );
    await disposePage(tester);
  });

  testWidgets('golden：分类一级弹窗暗色', (tester) async {
    await tester.binding.setSurfaceSize(const Size(414, 896));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openLevel1(tester, Brightness.dark);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('bill_convert_category_level1_dark.png'),
    );
    await disposePage(tester);
  });

  testWidgets('golden：分类二级弹窗亮色', (tester) async {
    await tester.binding.setSurfaceSize(const Size(414, 896));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openLevel1(tester, Brightness.light);
    await tester.tap(
      find.descendant(
        of: find.byType(AppModalSheet).last,
        matching: find.text(firstParentName),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('bill_convert_category_level2_light.png'),
    );
    await disposePage(tester);
  });

  testWidgets('golden：分类二级弹窗暗色', (tester) async {
    await tester.binding.setSurfaceSize(const Size(414, 896));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openLevel1(tester, Brightness.dark);
    await tester.tap(
      find.descendant(
        of: find.byType(AppModalSheet).last,
        matching: find.text(firstParentName),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('bill_convert_category_level2_dark.png'),
    );
    await disposePage(tester);
  });

  testWidgets('键盘弹起 + 四个开关全开：不溢出、输入框可聚焦', (tester) async {
    await tester.binding.setSurfaceSize(const Size(414, 896));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // 模拟键盘 321px（真机反馈值）。
    tester.view.viewInsets = const FakeViewPadding(bottom: 321);
    addTearDown(() => tester.view.viewInsets = const FakeViewPadding());

    await pumpPage(tester);
    await openSheet(tester);

    // 四个开关全开（改分类 / 改账户 / 改标签 / 改备注——「改收支类型」
    // 已并入「改分类」），内容最高（键盘弹起时下方开关滚出折叠区，
    // 先 ensureVisible 滚入可视区再点）。
    for (int i = 0; i < 4; i++) {
      await tester.ensureVisible(find.byType(Switch).at(i));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).at(i));
      await tester.pumpAndSettle();
    }
    // 聚焦标签输入框（键盘交互路径）。
    await tester.ensureVisible(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: '键盘弹起时不应 RenderFlex overflow');
    expect(find.text('应用转换'), findsOneWidget);
    await disposePage(tester);
  });

  testWidgets('golden：转换面板亮色', (tester) async {
    await tester.binding.setSurfaceSize(const Size(414, 896));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester, brightness: Brightness.light);
    await openSheet(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('bill_convert_sheet_light.png'),
    );
    await disposePage(tester);
  });

  testWidgets('golden：转换面板暗色', (tester) async {
    await tester.binding.setSurfaceSize(const Size(414, 896));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester, brightness: Brightness.dark);
    await openSheet(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('bill_convert_sheet_dark.png'),
    );
    await disposePage(tester);
  });
}
