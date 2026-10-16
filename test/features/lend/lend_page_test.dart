import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/accounts/providers/accounts_providers.dart';
import 'package:pocket_ledger/features/lend/presentation/lend_page.dart';
import 'package:pocket_ledger/features/lend/providers/lend_providers.dart';

/// 借还页渲染测试（第 35 批）。
///
/// 背景：第 34 批起不再预置账户，借还页原先只能看不能记（唯一动作是
/// 空态里的「去账户页新建」），直接沦为死空态。修复：底部常驻双按钮栏
/// （主「记一笔借还」+ 幽灵「去账户页新建」），空态去掉自有按钮、
/// 动作入口唯一。本测试锁死：
/// 1. 空态时动作入口仍然可见（页面不死）；
/// 2. 有记录时底部栏常驻。
///
/// 不接真实数据库，用 `Stream.value` 覆盖页面依赖的两个 provider。
void main() {
  LendRecord fakeRecord({
    required String id,
    String counterparty = '张三',
    int amountMinor = 10000,
    LendStatus status = LendStatus.ongoing,
  }) {
    return LendRecord(
      updatedAt: 0,
      deleted: false,
      dirty: false,
      id: id,
      bookId: 'default',
      direction: LendDirection.lendOut,
      status: status,
      counterparty: counterparty,
      amountMinor: amountMinor,
      currency: 'CNY',
      repaidMinor: 0,
      occurredAt: 0,
      dueAt: null,
      note: null,
      accountId: null,
      toAccountId: null,
      feeMinor: 0,
      discountMinor: 0,
      graceDays: 0,
    );
  }

  Widget wrap({List<LendRecord> records = const <LendRecord>[]}) {
    return ProviderScope(
      overrides: <Override>[
        accountsProvider.overrideWith(
          (Ref ref) => Stream<List<Account>>.value(const <Account>[]),
        ),
        lendListProvider.overrideWith(
          (Ref ref) => Stream<List<LendRecord>>.value(records),
        ),
      ],
      child: const MaterialApp(home: LendPage()),
    );
  }

  testWidgets('空态：说明文案 + 底部双按钮可见（不再是死页面）', (WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('还没有借还记录'), findsOneWidget);
    // 动作入口唯一且在空态可见：主按钮 + 幽灵按钮。
    expect(find.text('记一笔借还'), findsOneWidget);
    expect(find.text('去账户页新建'), findsOneWidget);
    // 空态自身不再放按钮（避免与底部栏双按钮重复）。
    expect(find.text('还没有借还账户'), findsNothing);
  });

  testWidgets('有未指定账户的记录：平铺区 + 底部栏常驻', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(
      records: <LendRecord>[fakeRecord(id: 'r1')],
    ));
    await tester.pumpAndSettle();

    expect(find.text('还没有借还记录'), findsNothing);
    expect(find.text('未指定账户的记录'), findsOneWidget);
    expect(find.text('张三'), findsOneWidget);
    // 底部栏常驻：有数据时也能记一笔。
    expect(find.text('记一笔借还'), findsOneWidget);
    expect(find.text('去账户页新建'), findsOneWidget);
  });
}
