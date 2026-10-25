import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/core/bootstrap.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/features/record/presentation/record_sheet.dart';
import 'package:pocket_ledger/features/record/providers/recording_settings_provider.dart';
import 'package:pocket_ledger/features/record/record_tab.dart';
import 'package:pocket_ledger/providers/app_providers.dart';
import 'package:pocket_ledger/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 冒烟测试：借还 Tab 首帧构建不抛异常（复现真机整页空白的运行时错误）。
///
/// 工程约定（踩坑，2026-10-23 修）：
/// - bootstrapData 内含 drift 事务，在 testWidgets 假异步区里永不完成
///   （事务执行器的 Completer 依赖真实事件循环）→ DB 初始化放 setUp/tearDown；
/// - MaterialApp 必须带 AppThemeData.light：页面用 context.app / context.colors
///   主题扩展，裸主题会抛 null check operator；
/// - 记一笔整页较高，需拉高视口避免 RenderFlex 溢出；
/// - 整页有常驻帧调度，pumpAndSettle 不收敛，用 pump + 定时长 pump。
void main() {
  late AppDatabase db;

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SharedPreferences.setMockInitialValues(<String, String>{});
    appPrefs = await SharedPreferences.getInstance();
  });

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await bootstrapData(db);
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('借还 Tab 首帧构建不抛异常', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppThemeData.light,
          home: const RecordSheet(initialTab: RecordTab.lend),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('借入'), findsWidgets);

    // 收尾：卸载页面并推进微小时长，消化 drift 流 dispose 产生的 0 时长
    // 定时器（否则框架报 "A Timer is still pending even after dispose"）。
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 20));
  }, timeout: const Timeout(Duration(minutes: 2)),);
}
