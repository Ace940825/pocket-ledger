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

    expect(find.text('没有内容了哦'), findsOneWidget);
    expect(find.text('该状态下暂无账单'), findsOneWidget);
  });

  // ── 第 41 批回归锁 ──────────────────────────────────────
  //
  // 真机事故：报销页底栏双按钮整只隐形但可点。根因是 _PillButton 用 Ink
  // 画装饰——Ink 装饰绘制在最近 Material 的 ink 层，被 _bottomBar 的
  // 不透明 Container(color: surface) 整体遮盖（Scaffold 背景 Material 在
  // 底栏子树之下；GoRouter 路由树上方的 MaterialApp 不包裹路由内容）。
  // 修法：装饰改由 Container 自绘（本页 _NoAccountEmpty 空态按钮同款）。
  testWidgets('底栏按钮装饰由 Container 自绘（ Ink 遮盖事故回归锁）',
      (WidgetTester tester) async {
    await _pump(
      tester,
      records: <Reimbursement>[
        _reimb(id: 'r1', title: '九月差旅', occurredAt: _ms(2026, 9, 20)),
      ],
      groupByMonth: true,
    );

    for (final String label in <String>['新建账户', '记一笔报销']) {
      // 第 45 批：空态胶囊与底栏幽灵键都显示「新建账户」，用底栏 SafeArea
      // 作用域排除空态胶囊，只锁底栏按钮的装饰自绘。
      final Finder button = find.ancestor(
        of: find.text(label),
        matching: find.byType(SafeArea),
      );
      expect(button, findsOneWidget, reason: '$label 底栏按钮应存在');
      final Finder inkWell = find.ancestor(
        of: find.text(label),
        matching: find.byType(InkWell),
      );
      expect(
        find.descendant(of: inkWell, matching: find.byType(Ink)),
        findsNothing,
        reason: '$label 不得再用 Ink 画装饰（会被不透明 Container 遮盖）',
      );
    }
    // 主按钮的鼠尾草渐变必须挂在 Container 自绘装饰上。
    final Finder mainBtn = find.ancestor(
      of: find.text('记一笔报销'),
      matching: find.byType(SafeArea),
    );
    expect(
      find.descendant(
        of: mainBtn,
        matching: find.byWidgetPredicate((Widget w) {
          if (w is! Container) return false;
          final Decoration? d = w.decoration;
          return d is BoxDecoration && d.gradient != null;
        }),
      ),
      findsOneWidget,
      reason: '主按钮渐变应由 Container 自绘',
    );
  });
}
