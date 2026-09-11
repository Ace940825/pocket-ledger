import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/reimbursement/presentation/reimbursement_page.dart';
import 'package:pocket_ledger/features/reimbursement/providers/reimbursement_providers.dart';
import 'package:pocket_ledger/providers/asset_stats_settings.dart';

Reimbursement _reimb({
  required String id,
  required String title,
  required int occurredAt,
}) {
  return Reimbursement(
    id: id,
    bookId: 'book1',
    title: title,
    status: ReimbursementStatus.pending,
    amountMinor: 10000,
    currency: 'CNY',
    payer: '本人',
    occurredAt: occurredAt,
    updatedAt: 0,
    deleted: false,
    dirty: false,
    excludeFromStats: false,
  );
}

/// 列表按 `occurredAt` 倒序（与 repository 的 orderBy 一致）。
int _ms(int y, int m, int d) => DateTime.utc(y, m, d, 4).millisecondsSinceEpoch;

Future<void> _pump(
  WidgetTester tester, {
  required List<Reimbursement> records,
  required bool groupByMonth,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        reimbursementListProvider.overrideWith(
          (Ref ref) => Stream<List<Reimbursement>>.value(records),
        ),
        assetStatsSettingsProvider.overrideWith((Ref ref) {
          final AssetStatsSettingsNotifier notifier =
              AssetStatsSettingsNotifier(const FlutterSecureStorage());
          // save() 在第一个 await 之前就同步赋值 state，因此首帧即为目标设置。
          notifier.save(
            AssetStatsSettings(groupByMonthReimburse: groupByMonth),
          );
          return notifier;
        }),
      ],
      child: const MaterialApp(home: ReimbursementPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  testWidgets('关闭「按年月分组」时不出现月份小标题', (WidgetTester tester) async {
    await _pump(
      tester,
      records: <Reimbursement>[
        _reimb(id: 'r1', title: '九月差旅', occurredAt: _ms(2026, 9, 20)),
        _reimb(id: 'r2', title: '八月打车', occurredAt: _ms(2026, 8, 8)),
      ],
      groupByMonth: false,
    );

    expect(find.text('九月差旅'), findsOneWidget);
    expect(find.text('八月打车'), findsOneWidget);
    expect(find.text('2026年9月'), findsNothing);
    expect(find.text('2026年8月'), findsNothing);
  });

  testWidgets('开启「按年月分组」后按月插入小标题，且同月只插一次', (WidgetTester tester) async {
    await _pump(
      tester,
      records: <Reimbursement>[
        _reimb(id: 'r3', title: '九月下旬', occurredAt: _ms(2026, 9, 25)),
        _reimb(id: 'r2', title: '九月中旬', occurredAt: _ms(2026, 9, 15)),
        _reimb(id: 'r1', title: '八月打车', occurredAt: _ms(2026, 8, 8)),
      ],
      groupByMonth: true,
    );

    expect(find.text('2026年9月'), findsOneWidget, reason: '同月两条只插一次');
    expect(find.text('2026年8月'), findsOneWidget);
    expect(find.text('九月下旬'), findsOneWidget);
    expect(find.text('九月中旬'), findsOneWidget);
    expect(find.text('八月打车'), findsOneWidget);
  });

  testWidgets('跨年时两个月份各自成组', (WidgetTester tester) async {
    await _pump(
      tester,
      records: <Reimbursement>[
        _reimb(id: 'r2', title: '元旦', occurredAt: _ms(2026, 1, 3)),
        _reimb(id: 'r1', title: '跨年夜', occurredAt: _ms(2025, 12, 31)),
      ],
      groupByMonth: true,
    );

    expect(find.text('2026年1月'), findsOneWidget);
    expect(find.text('2025年12月'), findsOneWidget);
  });

  testWidgets('列表为空时仍显示空态，不崩溃', (WidgetTester tester) async {
    await _pump(
      tester,
      records: const <Reimbursement>[],
      groupByMonth: true,
    );

    expect(find.text('还没有报销记录，点右下角新增'), findsOneWidget);
  });
}
