import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/accounts/providers/accounts_providers.dart';
import 'package:pocket_ledger/features/accounts/presentation/widgets/account_transaction_tile.dart';

/// 渲染校验：账户详情页流水行（[AccountTransactionTile]）接入双轨线稿后，
/// 分类图标应与流水列表行一致 —— 普通支出走手绘线稿、储蓄存取走储蓄罐线稿、
/// 退款保持原 Material `replay`、无 iconKey 的转账走类型兜底。
void main() {
  testWidgets('account txn tile dual-track line icons',
      (WidgetTester tester) async {
    const int now = 1759100000000;

    const Category depositCategory = Category(
      updatedAt: now,
      deleted: false,
      dirty: false,
      id: 'cat-deposit',
      bookId: 'bk',
      name: '存款',
      type: CategoryType.expense,
      iconKey: 'deposit_in',
      sortOrder: 90,
      isArchived: false,
      isSystem: true,
    );
    const Category foodCategory = Category(
      updatedAt: now,
      deleted: false,
      dirty: false,
      id: 'cat-food',
      bookId: 'bk',
      name: '餐饮',
      type: CategoryType.expense,
      iconKey: 'restaurant',
      sortOrder: 0,
      isArchived: false,
      isSystem: false,
    );

    Transaction txn({
      required String id,
      required TxnType type,
      required String accountId,
      String? toAccountId,
      required String note,
      required String relatedId,
      SourceModule sourceModule = SourceModule.ledger,
      String? categoryId,
    }) =>
        Transaction(
          updatedAt: now,
          deleted: false,
          dirty: false,
          id: id,
          bookId: 'bk',
          type: type,
          amountMinor: 50000,
          currency: 'CNY',
          accountId: accountId,
          toAccountId: toAccountId,
          categoryId: categoryId,
          occurredAt: now,
          note: note,
          sourceModule: sourceModule,
          relatedId: relatedId,
          feeMinor: 0,
          discountMinor: 0,
          excludeFromStats: false,
          excludeFromBudget: false,
          isReimbursable: false,
        );

    // 1) 普通餐饮支出（手绘碗筷线稿）
    final Transaction foodTxn = txn(
      id: 't1',
      type: TxnType.expense,
      accountId: 'acc-bank',
      note: '午餐',
      relatedId: 'x',
      categoryId: 'cat-food',
    );
    // 2) 储蓄存入（罐腹向下箭头）
    final Transaction depositTxn = txn(
      id: 't2',
      type: TxnType.transfer,
      accountId: 'acc-bank',
      toAccountId: 'acc-savings',
      note: '储蓄存入「旅行基金」',
      relatedId: 'goal-1',
      sourceModule: SourceModule.savings,
      categoryId: 'cat-deposit',
    );
    // 3) 储蓄取出（罐腹向上箭头）
    final Transaction withdrawTxn = txn(
      id: 't3',
      type: TxnType.income,
      accountId: 'acc-bank',
      note: '储蓄取出「旅行基金」',
      relatedId: 'goal-1#withdraw',
      sourceModule: SourceModule.savings,
      categoryId: 'cat-deposit',
    );
    // 4) 退款（保持 Material `replay`，不接手绘）
    final Transaction refundTxn = txn(
      id: 't4',
      type: TxnType.income,
      accountId: 'acc-bank',
      note: '退款',
      relatedId: 't0',
      sourceModule: SourceModule.refund,
    );
    // 5) 转账（无 iconKey，走类型兜底 swap_horiz）
    final Transaction transferTxn = txn(
      id: 't5',
      type: TxnType.transfer,
      accountId: 'acc-bank',
      toAccountId: 'acc-cash',
      note: '转账',
      relatedId: 'x',
    );

    const Map<String, String> accountNames = <String, String>{
      'acc-bank': '招商银行',
      'acc-savings': '储蓄账户',
      'acc-cash': '现金',
    };

    tester.view.physicalSize = const Size(780, 760);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          categoryMapProvider.overrideWith(
            (ref) => Stream<Map<String, Category>>.value(<String, Category>{
              'cat-deposit': depositCategory,
              'cat-food': foodCategory,
            }),
          ),
          accountsProvider.overrideWith(
            (ref) => Stream<List<Account>>.value(<Account>[]),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            backgroundColor: Colors.white,
            body: RepaintBoundary(
              key: const Key('accountTxnTiles'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AccountTransactionTile(
                    transaction: foodTxn,
                    accountNames: accountNames,
                    accountId: 'acc-bank',
                  ),
                  AccountTransactionTile(
                    transaction: depositTxn,
                    accountNames: accountNames,
                    accountId: 'acc-bank',
                  ),
                  AccountTransactionTile(
                    transaction: withdrawTxn,
                    accountNames: accountNames,
                    accountId: 'acc-bank',
                  ),
                  AccountTransactionTile(
                    transaction: refundTxn,
                    accountNames: accountNames,
                    accountId: 'acc-bank',
                  ),
                  AccountTransactionTile(
                    transaction: transferTxn,
                    accountNames: accountNames,
                    accountId: 'acc-bank',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('accountTxnTiles')),
      matchesGoldenFile('account_txn_tile_icons.png'),
    );
  });
}
