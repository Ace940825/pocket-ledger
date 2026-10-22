import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pocket_ledger/core/bootstrap.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/ledger/data/transaction_repository.dart';
import 'package:pocket_ledger/features/ledger/presentation/bill_clean_page.dart';
import 'package:pocket_ledger/providers/app_providers.dart';
import 'package:pocket_ledger/shared/widgets/sheet_scaffold.dart';
import 'package:pocket_ledger/theme/app_theme.dart';

/// 账单清理页年份范围回归（2026-10-22 真机反馈「批量删除年份范围不完整」）：
///
/// 周期选择器的 firstDate 曾硬编码 DateTime(2020)，2016-2019 的历史账单
/// 在年宫格里置灰、无法被选中清理。现改为按「账本内最早一笔流水的年份」
/// 动态取值（兜底 2000）——本测试驱动真实页面 + 真实 DB，1:1 还原用户路径：
/// 点周期标签 → 年 Yr → ‹ 翻窗 → 点 2016 → 确认，断言历史账单可见可清理。
void main() {
  late Directory tmp;
  late AppDatabase db;
  late TransactionRepository txnRepo;
  late String catOld; // 2016 年流水挂的分类（切到 2016 后应可见）
  late String catNow; // 本月流水挂的分类（切到 2016 后应消失）

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('pl_clean_year_test');
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
        .toList()
      ..sort((Category a, Category b) => a.name.compareTo(b.name));
    catOld = expenseCats[0].id;
    catNow = expenseCats[1].id;
    // 一笔 2016 年历史流水（用户场景：2016-2019 已有账单）。
    await txnRepo.add(
      bookId: 'default',
      type: TxnType.expense,
      amountMinor: 2000,
      accountId: '现金',
      categoryId: catOld,
      occurredAt: DateTime(2016, 5, 20, 10, 30).millisecondsSinceEpoch,
      note: 'old-2016',
    );
    // 一笔本月流水（页面默认周期 = 当月）。
    final DateTime now = DateTime.now();
    await txnRepo.add(
      bookId: 'default',
      type: TxnType.expense,
      amountMinor: 100,
      accountId: '现金',
      categoryId: catNow,
      occurredAt:
          DateTime(now.year, now.month, 15, 9, 0).millisecondsSinceEpoch,
      note: 'now',
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
          home: const BillCleanPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 收尾：卸载页面消化 drift 流查询的 0 时长关闭定时器。
  Future<void> disposePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 20));
  }

  testWidgets('年份范围放开：2016 历史账单可被选中清理', (tester) async {
    await tester.binding.setSurfaceSize(const Size(414, 896));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester);

    // 默认当月：只见本月流水。
    final DateTime now = DateTime.now();
    expect(find.text('${now.year}年${now.month}月'), findsOneWidget,
        reason: '页头应显示当前月');
    expect(find.text('共 1 笔账单'), findsOneWidget);

    // 打开「清理周期」弹层（AppModalSheet）。
    await tester.tap(find.text('${now.year}年${now.month}月'));
    await tester.pumpAndSettle();
    expect(find.byType(AppModalSheet), findsOneWidget);
    expect(find.text('清理周期'), findsOneWidget);

    // 切到「年 Yr」粒度 → 年宫格（12 年一窗，初始落在含当前年的窗）。
    // 粒度 chip 是富文本（「年 Yr」单根 Text），按整串匹配。
    await tester.tap(find.text('年 Yr'));
    await tester.pumpAndSettle();

    // ‹ 翻窗：当前窗（含 2026）→ 2012-2023 窗。
    await tester.tap(find.text('‹'));
    await tester.pumpAndSettle();
    expect(find.text('2012年–2023年'), findsOneWidget,
        reason: '页头应显示翻窗后的 12 年区间');

    // 2016 必须可点（修复前 firstDate=2020 会置灰）。
    // 注意：周期年宫格 cell 文案带「年」后缀（「2016年」），与年份单选器
    // （CalendarSheetMode.year，裸「2016」）不同。
    await tester.tap(find.text('2016年'));
    await tester.pumpAndSettle();

    // 确认 → 周期切到 2016 年。
    await tester.tap(find.text('确认 Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('2016年'), findsOneWidget, reason: '页头应显示 2016年');

    // 2016 流水可见、本月流水不可见 → 历史账单确实可被选中清理。
    expect(find.text('共 1 笔账单'), findsOneWidget);
    expect(find.text('2016年5月20日'), findsOneWidget,
        reason: '跨年流水行显完整年月日');
    await disposePage(tester);
  });

  testWidgets('默认下限仍早于最早流水年：2015 置灰、2016 可选', (tester) async {
    await tester.binding.setSurfaceSize(const Size(414, 896));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester);

    final DateTime now = DateTime.now();
    await tester.tap(find.text('${now.year}年${now.month}月'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('年 Yr'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('‹'));
    await tester.pumpAndSettle();

    // 2015 早于账本最早流水年（2016）→ 仍置灰（ InkWell onTap 为 null）。
    final Finder cell2015 = find.ancestor(
      of: find.text('2015年'),
      matching: find.byType(InkWell),
    );
    expect(cell2015, findsOneWidget);
    expect(tester.widget<InkWell>(cell2015).onTap, isNull,
        reason: '2015 无流水、应保持置灰');
    // 2016 有流水 → 可点。
    final Finder cell2016 = find.ancestor(
      of: find.text('2016年'),
      matching: find.byType(InkWell),
    );
    expect(tester.widget<InkWell>(cell2016).onTap, isNotNull,
        reason: '2016 有流水、必须可选中');
    await disposePage(tester);
  });
}
