import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pocket_ledger/core/bootstrap.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/ledger/data/transaction_repository.dart';
import 'package:pocket_ledger/features/ledger/presentation/ledger_page.dart';
import 'package:pocket_ledger/features/ledger/providers/ledger_providers.dart';
import 'package:pocket_ledger/providers/app_providers.dart';
import 'package:pocket_ledger/theme/app_theme.dart';

/// 账单页「筛选 → 页头周期同步」（2026-10-22 真机反馈：筛选页日期改对了，
/// 查询后账单页头仍是 2026年10月）。
///
/// 用真实页面 + 真 DB 走一遍用户路径：点「筛选」→ 筛选页点「时间」→ 日历选
/// 15 日 → 确认 → 查询。修复前页头周期停在当月，明细却被筛到指定日；
/// 修复后页头周期跟着切到该日（时间轴只认一处）。
void main() {
  late Directory tmp;
  late AppDatabase db;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('pl_ledger_filter_sync_test');
    db = AppDatabase(NativeDatabase(File(p.join(tmp.path, 'ledger.db'))));
    await bootstrapData(db);
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
    final Category cat = cats.firstWhere(
      (Category c) => c.type == CategoryType.expense && c.deleted == false,
    );
    final DateTime now = DateTime.now();
    // 本月 15 日一笔（筛到 15 日后仍应可见）。
    await TransactionRepository(db).add(
      bookId: 'default',
      type: TxnType.expense,
      amountMinor: 1200,
      accountId: '现金',
      categoryId: cat.id,
      occurredAt: DateTime(now.year, now.month, 15, 9, 30).millisecondsSinceEpoch,
      note: '十五号午饭',
    );
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(414, 896));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppThemeData.light,
          home: const LedgerPage(),
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

  testWidgets('筛选页选定时间后，账单页页头周期跟着切', (tester) async {
    final DateTime now = DateTime.now();
    final String monthLabel = '${now.year}年${now.month}月';
    final String dayLabel = '${now.year}年${now.month}月15日';

    await pumpPage(tester);
    expect(find.text(monthLabel), findsOneWidget, reason: '页头默认当月');
    expect(find.text('筛选'), findsOneWidget);

    // 打开独立筛选页。
    await tester.tap(find.text('筛选'));
    await tester.pumpAndSettle();
    expect(find.text('基本信息'), findsOneWidget);

    // 「时间」行默认文案是当年 → 点开日历（日视图 + 快捷 chip）。
    await tester.tap(find.text('${now.year}年'));
    await tester.pumpAndSettle();

    // 选 15 日并确认。
    await tester.tap(find.text('15').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认 Confirm'));
    await tester.pumpAndSettle();
    expect(find.text(dayLabel), findsWidgets, reason: '筛选页「时间」行应回显该日');

    // 查询 → 返回账单页。
    await tester.tap(find.text('查询(条件1个)'));
    await tester.pumpAndSettle();

    expect(
      find.text(dayLabel),
      findsOneWidget,
      reason: '页头周期必须跟着筛选的时间走（修复前停在当月）',
    );
    expect(find.text(monthLabel), findsNothing);
    expect(find.text('筛选(1)'), findsOneWidget, reason: '条件数与筛选页「查询(条件1个)」同口径');
    expect(find.text('十五号午饭'), findsOneWidget);
    await disposePage(tester);
  });

  testWidgets('长跨年区间写进页头：小屏不溢出、结束年份可见', (tester) async {
    // 直接摆出「查询已生效」的状态：周期 = 跨年区间，筛选条件 = 同一区间。
    final LedgerAdvancedFilter filter = LedgerAdvancedFilter(
      rangeStart: DateTime(2025, 2, 5),
      rangeEnd: DateTime(2026, 3, 7),
    );
    final LedgerPeriod period =
        LedgerPeriod.customOf(DateTime(2025, 2, 5), DateTime(2026, 3, 6));

    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          ledgerPeriodProvider.overrideWith((Ref ref) => period),
          ledgerAdvancedFilterProvider.overrideWith((Ref ref) => filter),
        ],
        child: MaterialApp(
          theme: AppThemeData.light,
          home: const LedgerPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('2025年2月5日-2026年3月6日'),
      findsOneWidget,
      reason: '页头只显示一个区间标签（Flexible 换行，不是被截断）',
    );
    // 行宽装不下时必须是换行而不是横向溢出（修复前 414 宽就会超 100px+）。
    expect(tester.takeException(), isNull);
    await disposePage(tester);
  });
}
