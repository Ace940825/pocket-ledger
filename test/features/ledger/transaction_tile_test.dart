import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/accounts/providers/accounts_providers.dart';
import 'package:pocket_ledger/features/ledger/presentation/widgets/transaction_tile.dart';

/// 流水页（`ledger_page` / `home_page`）列表项的退款可见性。
///
/// 与 `AccountTransactionTile` 保持一致：退款不能显示成「收入」。
void main() {
  Transaction txn({
    required TxnType type,
    SourceModule sourceModule = SourceModule.ledger,
    int amountMinor = 1200,
  }) {
    return Transaction(
      id: 't1',
      bookId: 'default',
      type: type,
      amountMinor: amountMinor,
      currency: 'CNY',
      accountId: 'acc1',
      occurredAt: DateTime(2026, 9, 11, 12).toUtc().millisecondsSinceEpoch,
      sourceModule: sourceModule,
      feeMinor: 0,
      discountMinor: 0,
      updatedAt: 0,
      deleted: false,
      dirty: false,
    );
  }

  Future<void> pump(WidgetTester tester, Transaction t) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          categoryMapProvider.overrideWith(
            (ref) => Stream<Map<String, Category>>.value(<String, Category>{}),
          ),
        ],
        child:
            MaterialApp(home: Scaffold(body: TransactionTile(transaction: t))),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('退款显示「退款」', (WidgetTester tester) async {
    await pump(
      tester,
      txn(type: TxnType.income, sourceModule: SourceModule.refund),
    );
    expect(find.text('退款'), findsOneWidget);
    expect(find.text('收入'), findsNothing);
  });

  testWidgets('普通收入仍显示「收入」', (WidgetTester tester) async {
    await pump(tester, txn(type: TxnType.income));
    expect(find.text('收入'), findsOneWidget);
    expect(find.text('退款'), findsNothing);
  });
}
