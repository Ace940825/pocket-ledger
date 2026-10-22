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
import 'package:pocket_ledger/features/ledger/presentation/ledger_filter_page.dart';
import 'package:pocket_ledger/features/ledger/providers/ledger_providers.dart';
import 'package:pocket_ledger/providers/app_providers.dart';
import 'package:pocket_ledger/theme/app_theme.dart';

/// 高级筛选页「基本信息 › 时间」行的区间文案（2026-10-22 第二次真机反馈）：
///
/// 用户选了跨年区间，时间行显示成「2022年2月1日-2月1日」——结束年份丢失，
/// 被读成同年内的两个月。根因是各页各自手拼 label，本轮已统一到
/// `formatDayRange`；本测试用**真实页面 + 真 DB** 锁住页面出口，
/// 避免再次出现「改了公共函数但页面没用」的漏网。
void main() {
  late Directory tmp;
  late AppDatabase db;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('pl_filter_label_test');
    db = AppDatabase(NativeDatabase(File(p.join(tmp.path, 'ledger.db'))));
    await bootstrapData(db);
    await db.accountsDao.insertAccount(
      const AccountsCompanion(
        id: Value<String>('现金'),
        bookId: Value<String>('default'),
        name: Value<String>('现金'),
        type: Value<AccountType>(AccountType.cash),
        updatedAt: Value<int>(0),
      ),
    );
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<void> pumpFilter(
    WidgetTester tester,
    LedgerAdvancedFilter initial,
  ) async {
    await tester.binding.setSurfaceSize(const Size(414, 896));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppThemeData.light,
          home: LedgerFilterPage(initial: initial),
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

  testWidgets('跨年区间：时间行两端都显年份（真机反馈场景）', (tester) async {
    // rangeEnd 为排他边界：2021-02-01 ~ 2022-02-02 实际含到 2022-02-01。
    await pumpFilter(
      tester,
      LedgerAdvancedFilter(
        rangeStart: DateTime(2021, 2, 1),
        rangeEnd: DateTime(2022, 2, 2),
      ),
    );

    expect(find.text('基本信息'), findsOneWidget);
    expect(
      find.text('2021年2月1日-2022年2月1日'),
      findsWidgets,
      reason: '跨年区间必须两端都带年份，否则被误读成同年内两个月',
    );
    expect(
      find.text('2021年2月1日-2月1日'),
      findsNothing,
      reason: '修复前的错误文案不得再出现',
    );
    await disposePage(tester);
  });

  testWidgets('同年区间：仍只显月日（旧口径不变）', (tester) async {
    await pumpFilter(
      tester,
      LedgerAdvancedFilter(
        rangeStart: DateTime(2022, 2, 1),
        // end 为排他边界：+2 天 → 实际含到 2 月 2 日（真 2 天区间）。
        rangeEnd: DateTime(2022, 2, 3),
      ),
    );

    expect(find.text('2月1日-2月2日'), findsWidgets);
    await disposePage(tester);
  });
}
