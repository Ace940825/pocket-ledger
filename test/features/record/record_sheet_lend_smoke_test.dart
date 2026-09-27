import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/core/bootstrap.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/features/record/presentation/record_sheet.dart';
import 'package:pocket_ledger/features/record/record_tab.dart';
import 'package:pocket_ledger/features/record/providers/recording_settings_provider.dart';
import 'package:pocket_ledger/providers/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 冒烟测试：借还 Tab 首帧构建不抛异常（复现真机整页空白的运行时错误）。
void main() {
  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SharedPreferences.setMockInitialValues(<String, String>{});
    appPrefs = await SharedPreferences.getInstance();
  });

  testWidgets('借还 Tab 首帧构建不抛异常', (WidgetTester tester) async {
    final AppDatabase db = AppDatabase(NativeDatabase.memory());
    await bootstrapData(db);
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          home: RecordSheet(initialTab: RecordTab.lend),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('借入'), findsWidgets);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
