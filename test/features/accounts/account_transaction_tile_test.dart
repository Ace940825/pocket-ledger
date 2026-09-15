import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/accounts/presentation/widgets/account_transaction_tile.dart';
import 'package:pocket_ledger/features/accounts/providers/accounts_providers.dart';

Transaction _txn({
  required String id,
  required TxnType type,
  required int amountMinor,
  int feeMinor = 0,
  int discountMinor = 0,
  String accountId = 'acc1',
  String? toAccountId,
  SourceModule sourceModule = SourceModule.ledger,
}) {
  return Transaction(
    id: id,
    bookId: 'book1',
    type: type,
    amountMinor: amountMinor,
    currency: 'CNY',
    accountId: accountId,
    toAccountId: toAccountId,
    occurredAt: DateTime(2026, 9, 10, 12).toUtc().millisecondsSinceEpoch,
    sourceModule: sourceModule,
    feeMinor: feeMinor,
    discountMinor: discountMinor,
    excludeFromStats: false,
    excludeFromBudget: false,
    isReimbursable: false,
    updatedAt: 0,
    deleted: false,
    dirty: false,
  );
}

Future<void> _pumpWithAccount(
  WidgetTester tester,
  Transaction txn, {
  required String accountId,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        categoryMapProvider.overrideWith(
          (Ref ref) => Stream<Map<String, Category>>.value(
            <String, Category>{},
          ),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: AccountTransactionTile(
            transaction: txn,
            accountNames: const <String, String>{
              'acc1': '中国工商银行',
              'acc2': '支付宝',
            },
            accountId: accountId,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pump(WidgetTester tester, Transaction txn) async {
  await _pumpWithAccount(tester, txn, accountId: txn.accountId);
}

void main() {
  testWidgets('支出行：显示账户副标题，金额带负号', (WidgetTester tester) async {
    await _pump(
      tester,
      _txn(id: 't1', type: TxnType.expense, amountMinor: 1234),
    );

    expect(find.text('中国工商银行'), findsOneWidget);
    // 注意：符号在币种符号**之前**（`-¥12.34`），不是 `¥-12.34`。
    expect(find.text('-¥12.34'), findsOneWidget);
  });

  testWidgets('收入行：金额带正号', (WidgetTester tester) async {
    await _pump(
      tester,
      _txn(id: 't1', type: TxnType.income, amountMinor: 1234),
    );

    expect(find.text('+¥12.34'), findsOneWidget);
    expect(find.textContaining('-'), findsNothing);
  });

  testWidgets('转账显示「从 -> 到」说明', (WidgetTester tester) async {
    await _pump(
      tester,
      _txn(
        id: 't1',
        type: TxnType.transfer,
        amountMinor: 90000,
        accountId: 'acc1',
        toAccountId: 'acc2',
      ),
    );

    expect(find.text('中国工商银行 -> 支付宝'), findsOneWidget);
  });

  testWidgets('转账金额显示为正数（不显示负号）', (WidgetTester tester) async {
    await _pump(
      tester,
      _txn(
        id: 't1',
        type: TxnType.transfer,
        amountMinor: 90000,
        accountId: 'acc1',
        toAccountId: 'acc2',
      ),
    );

    expect(find.text('¥900.00'), findsOneWidget);
    expect(find.text('-¥900.00'), findsNothing);
  });

  testWidgets('转账转出方金额含手续费/优惠', (WidgetTester tester) async {
    await _pumpWithAccount(
      tester,
      _txn(
        id: 't1',
        type: TxnType.transfer,
        amountMinor: 3000,
        accountId: 'acc1',
        toAccountId: 'acc2',
        feeMinor: 200,
      ),
      accountId: 'acc1',
    );

    // 转出方（acc1）实际扣款 = 30 + 2 = 32。
    expect(find.text('¥32.00'), findsOneWidget);
    expect(find.text('¥30.00'), findsNothing);
  });

  testWidgets('转账转入方金额仍显示到账金额', (WidgetTester tester) async {
    await _pumpWithAccount(
      tester,
      _txn(
        id: 't1',
        type: TxnType.transfer,
        amountMinor: 3000,
        accountId: 'acc1',
        toAccountId: 'acc2',
        feeMinor: 200,
      ),
      accountId: 'acc2',
    );

    // 转入方（acc2）到账金额仍是 30。
    expect(find.text('¥30.00'), findsOneWidget);
    expect(find.text('¥32.00'), findsNothing);
  });

  group('退款必须与普通收入区分', () {
    testWidgets('退款行标题显示「退款」而不是「收入」', (WidgetTester tester) async {
      await _pump(
        tester,
        _txn(
          id: 't1',
          type: TxnType.income,
          amountMinor: 1200,
          sourceModule: SourceModule.refund,
        ),
      );

      expect(find.text('退款'), findsOneWidget);
      expect(
        find.text('收入'),
        findsNothing,
        reason: '标题只看 type 的话，退款和普通收入在界面上完全一样 —— '
            '而两者统计口径不同，这正是「¥88.00」被误判成统计 bug 的根源',
      );
    });

    testWidgets('普通收入行标题仍是「收入」', (WidgetTester tester) async {
      await _pump(
        tester,
        _txn(id: 't1', type: TxnType.income, amountMinor: 1200),
      );

      expect(find.text('收入'), findsOneWidget);
      expect(find.text('退款'), findsNothing);
    });

    testWidgets('退款金额仍按收入方向显示为正号', (WidgetTester tester) async {
      await _pump(
        tester,
        _txn(
          id: 't1',
          type: TxnType.income,
          amountMinor: 1200,
          sourceModule: SourceModule.refund,
        ),
      );

      expect(find.text('+¥12.00'), findsOneWidget);
    });
  });
}
