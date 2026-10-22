import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pocket_ledger/core/bootstrap.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/investment/data/investment_repository.dart';
import 'package:pocket_ledger/features/investment/presentation/investment_page.dart';
import 'package:pocket_ledger/features/ledger/data/transaction_repository.dart';
import 'package:pocket_ledger/providers/app_providers.dart';
import 'package:pocket_ledger/shared/widgets/sheet_scaffold.dart';
import 'package:pocket_ledger/theme/app_theme.dart';

/// 投资页布局回归（2026-10-22 真机反馈，第 47 批）：
///
/// 新增持仓入口从右上角「+」收敛到底部「+ 记一笔投资」深绿渐变胶囊
/// （与分期 / 退款 / 借还 / 报销底栏主按钮口径一致），空态标语同步
/// 改为指向下方按钮。本文件驱动真实页面 + 真实 DB：
/// ① 空态：底钮存在、AppBar 只剩刷新、空态标语指向下方、点钮开编辑器；
/// ② 有持仓：底钮不挡列表（golden 明暗两版）。
void main() {
  late Directory tmp;
  late AppDatabase db;
  late InvestmentRepository invRepo;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('pl_investment_page_test');
    db = AppDatabase(NativeDatabase(File(p.join(tmp.path, 'ledger.db'))));
    await bootstrapData(db);
    invRepo = InvestmentRepository(db, TransactionRepository(db));
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// 预置一笔持仓。数据取紧凑值（30 份）而非用户截图的大额值：
  /// flutter 测试环境用等宽方字（每字符宽=字号），持仓卡「持仓市值 |
  /// 总盈亏」一行两枚 titleLarge 大字，若用 ¥82,890.00 / +¥1,890.00
  /// （各 10 字符×22px=440px > 卡宽 364px）会触发 RenderFlex 横向溢出
  /// （真机比例字体下不溢，用户截图可证）；紧凑值保证测试与 golden 干净。
  Future<void> seedHolding() async {
    await invRepo.add(
      bookId: 'default',
      symbol: '000063',
      name: '中兴通讯',
      type: InvestmentType.stock,
      quantityMicros: 30 * 1000000,
      avgCostMinor: 2700,
      currentPriceMinor: 2763,
    );
  }

  Future<void> pumpPage(WidgetTester tester,
      {Brightness brightness = Brightness.light}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: brightness == Brightness.light
              ? AppThemeData.light
              : AppThemeData.dark,
          home: const InvestmentPage(),
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

  testWidgets('空态：新增入口移到底部「+ 记一笔投资」胶囊', (tester) async {
    await tester.binding.setSurfaceSize(const Size(414, 896));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester);

    // 底部主操作条：渐变胶囊「+ 记一笔投资」（图标 + 文案）。
    expect(find.text('记一笔投资'), findsOneWidget,
        reason: '底部应出现「+ 记一笔投资」胶囊');
    // 右上角「+」已移除：AppBar 动作区只剩刷新行情一个 IconButton。
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(IconButton),
      ),
      findsOneWidget,
      reason: 'AppBar 应只剩刷新按钮（新增入口已移走）',
    );
    // 空态标语同步改为指向下方按钮（旧「点右上角」文案下线）。
    expect(find.text('还没有持仓，点下方「+ 记一笔投资」新增'), findsOneWidget);
    expect(find.text('还没有持仓，点右上角「+」新增'), findsNothing);

    // 点底部胶囊 → 打开「新增持仓」编辑器弹层。
    await tester.tap(find.text('记一笔投资'));
    await tester.pumpAndSettle();
    expect(find.byType(AppModalSheet), findsOneWidget,
        reason: '点底部胶囊应弹出持仓编辑器');
    expect(find.text('新增持仓'), findsOneWidget);
    await disposePage(tester);
  });

  testWidgets('有持仓：底部胶囊常驻、列表与汇总正常', (tester) async {
    await tester.binding.setSurfaceSize(const Size(414, 896));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await seedHolding();
    await pumpPage(tester);

    // 汇总卡与持仓行正常渲染（底钮不挡内容）。
    expect(find.text('总资产'), findsOneWidget);
    expect(find.text('中兴通讯'), findsOneWidget);
    expect(find.text('000063'), findsOneWidget);
    expect(find.text('记一笔投资'), findsOneWidget,
        reason: '有持仓时底部胶囊仍常驻');
    await disposePage(tester);
  });

  testWidgets('golden：投资页亮色（含一笔持仓）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(414, 896));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await seedHolding();
    await pumpPage(tester, brightness: Brightness.light);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('investment_page_light.png'),
    );
    await disposePage(tester);
  });

  testWidgets('golden：投资页暗色（含一笔持仓）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(414, 896));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await seedHolding();
    await pumpPage(tester, brightness: Brightness.dark);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('investment_page_dark.png'),
    );
    await disposePage(tester);
  });
}
