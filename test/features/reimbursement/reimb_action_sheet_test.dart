import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/features/reimbursement/presentation/reimbursement_page.dart';
import 'package:pocket_ledger/features/reimbursement/providers/reimbursement_providers.dart';
import 'package:pocket_ledger/features/accounts/providers/accounts_providers.dart';
import 'package:pocket_ledger/providers/asset_stats_settings.dart';

void main() {
  testWidgets('右上「操作」按钮弹出资产操作弹窗（opv1 三组）', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          reimbursementListProvider.overrideWith(
            (Ref ref) => Stream<List<Reimbursement>>.value(<Reimbursement>[]),
          ),
          reimbursementListIncludingDeletedProvider.overrideWith(
            (Ref ref) => Stream<List<Reimbursement>>.value(<Reimbursement>[]),
          ),
          accountsProvider.overrideWith(
            (Ref ref) => Stream<List<Account>>.value(<Account>[]),
          ),
          assetStatsSettingsProvider.overrideWith(
            (Ref ref) => AssetStatsSettingsNotifier(
              const FlutterSecureStorage(),
            ),
          ),
        ],
        child: const MaterialApp(home: ReimbursementPage()),
      ),
    );
    await tester.pumpAndSettle();

    // 页面本身渲染成功
    expect(find.text('报销'), findsWidgets);
    expect(find.text('操作'), findsOneWidget);

    // 点击右上「操作」
    await tester.tap(find.text('操作'));
    await tester.pumpAndSettle();

    // 弹窗三组内容出现
    expect(find.text('常用'), findsOneWidget);
    expect(find.text('时光机'), findsOneWidget);
    expect(find.text('资产排序'), findsOneWidget);
    expect(find.text('数据'), findsOneWidget);
    expect(find.text('金额校验'), findsOneWidget);
    expect(find.text('危险操作'), findsOneWidget);
    expect(find.text('账单清理'), findsOneWidget);
    expect(find.text('删除资产'), findsOneWidget);
  });
}
