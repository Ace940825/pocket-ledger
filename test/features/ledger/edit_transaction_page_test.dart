import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/accounts/providers/accounts_providers.dart';
import 'package:pocket_ledger/features/ledger/presentation/edit_transaction_page.dart';
import 'package:pocket_ledger/features/ledger/providers/ledger_providers.dart';
import 'package:pocket_ledger/providers/app_providers.dart';

/// 「编辑流水」页对**退款身份**的可见性测试。
///
/// 退款与普通收入的 `type` 都是 `income`，但统计口径不同（退款默认抵扣支出）。
/// 早期界面上完全看不出区别，于是 `支出:¥88.00 收入:¥0.00` 被误当成统计 bug。
/// 这个开关就是让那个隐形标记可见、可修。
void main() {
  const String txnId = 't1';
  const String accountId = 'acc1';

  Account fakeAccount() => const Account(
        id: accountId,
        bookId: 'default',
        name: '中国工商银行',
        type: AccountType.bankCard,
        balanceMinor: 11300,
        currency: 'CNY',
        isArchived: false,
        status: AccountStatus.active,
        includeInTotal: true,
        sortOrder: 0,
        updatedAt: 0,
        deleted: false,
        dirty: false,
      );

  Transaction fakeTx({
    required TxnType type,
    required SourceModule sourceModule,
    int amountMinor = 1200,
  }) {
    return Transaction(
      id: txnId,
      bookId: 'default',
      type: type,
      amountMinor: amountMinor,
      currency: 'CNY',
      accountId: accountId,
      occurredAt: DateTime(2026, 9, 11, 12).toUtc().millisecondsSinceEpoch,
      sourceModule: sourceModule,
      feeMinor: 0,
      discountMinor: 0,
      excludeFromStats: false,
      excludeFromBudget: false,
      isReimbursable: false,
      updatedAt: 0,
      deleted: false,
      dirty: false,
    );
  }

  Future<void> pumpEdit(WidgetTester tester, Transaction txn) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          transactionDetailProvider(txnId).overrideWith(
            (ref) => Stream<Transaction?>.value(txn),
          ),
          accountsProvider.overrideWith(
            (ref) => Stream<List<Account>>.value(<Account>[fakeAccount()]),
          ),
          incomeCategoriesProvider.overrideWith(
            (ref) => Stream<List<Category>>.value(<Category>[]),
          ),
          expenseCategoriesProvider.overrideWith(
            (ref) => Stream<List<Category>>.value(<Category>[]),
          ),
          currentBookIdProvider.overrideWith((ref) => 'default'),
        ],
        child: const MaterialApp(
          home: EditTransactionPage(transactionId: txnId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('编辑一笔退款：显示「这是退款」开关且为开启态', (WidgetTester tester) async {
    await pumpEdit(
      tester,
      fakeTx(type: TxnType.income, sourceModule: SourceModule.refund),
    );

    expect(find.text('这是退款'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(find.text('默认抵扣支出，不计入收入'), findsOneWidget);
  });

  testWidgets('编辑一笔普通收入：开关为关闭态，文案说明计入收入', (WidgetTester tester) async {
    await pumpEdit(
      tester,
      fakeTx(type: TxnType.income, sourceModule: SourceModule.ledger),
    );

    expect(find.text('这是退款'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(find.text('按普通收入计入收入统计'), findsOneWidget);
  });

  testWidgets('点开关会即时切换口径说明', (WidgetTester tester) async {
    await pumpEdit(
      tester,
      fakeTx(type: TxnType.income, sourceModule: SourceModule.refund),
    );

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(find.text('按普通收入计入收入统计'), findsOneWidget);
  });

  testWidgets('编辑一笔支出：不显示退款开关', (WidgetTester tester) async {
    await pumpEdit(
      tester,
      fakeTx(type: TxnType.expense, sourceModule: SourceModule.ledger),
    );

    expect(find.text('这是退款'), findsNothing);
  });

  testWidgets('编辑一笔转账：不显示退款开关', (WidgetTester tester) async {
    await pumpEdit(
      tester,
      fakeTx(type: TxnType.transfer, sourceModule: SourceModule.transfer),
    );

    expect(find.text('这是退款'), findsNothing);
  });
}
