import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/accounts/providers/accounts_providers.dart';
import 'package:pocket_ledger/features/ledger/presentation/widgets/transaction_tile.dart';

/// 渲染校验：流水明细里储蓄流水（`sourceModule = savings`，挂系统分类「存款」）
/// 左侧的分类图标必须走储蓄罐线稿 —— 存入 = 罐腹向下箭头、取出 = 罐腹向上箭头，
/// 而不是 transfer 的 `swap_horiz` 兜底（旧行为）或详情弹层的星形兜底。
///
/// 第 4 行是普通餐饮支出，作为「非储蓄流水不受影响」的对照。
void main() {
  testWidgets('savings deposit/withdraw tile icons render',
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
    const Account bank = Account(
      updatedAt: now,
      deleted: false,
      dirty: false,
      id: 'acc-bank',
      bookId: 'bk',
      name: '招商银行',
      type: AccountType.bankCard,
      balanceMinor: 100000,
      currency: 'CNY',
      status: AccountStatus.active,
      includeInTotal: true,
      isArchived: false,
      sortOrder: 0,
    );
    const Account savings = Account(
      updatedAt: now,
      deleted: false,
      dirty: false,
      id: 'acc-savings',
      bookId: 'bk',
      name: '储蓄账户',
      type: AccountType.bankCard,
      balanceMinor: 500000,
      currency: 'CNY',
      status: AccountStatus.active,
      includeInTotal: true,
      isArchived: false,
      sortOrder: 1,
    );

    Transaction txn({
      required String id,
      required TxnType type,
      required String accountId,
      String? toAccountId,
      required String note,
      required String relatedId,
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
          sourceModule:
              categoryId == 'cat-deposit' ? SourceModule.savings : SourceModule.ledger,
          relatedId: relatedId,
          feeMinor: 0,
          discountMinor: 0,
          excludeFromStats: false,
          excludeFromBudget: false,
          isReimbursable: false,
        );

    // 1) 存入（有入款账户 → 转账类型）
    final Transaction depositTxn = txn(
      id: 't1',
      type: TxnType.transfer,
      accountId: 'acc-bank',
      toAccountId: 'acc-savings',
      note: '储蓄存入「旅行基金」',
      relatedId: 'goal-1',
      categoryId: 'cat-deposit',
    );
    // 2) 取出（有转出账户 → 转账类型）
    final Transaction withdrawTransferTxn = txn(
      id: 't2',
      type: TxnType.transfer,
      accountId: 'acc-savings',
      toAccountId: 'acc-bank',
      note: '储蓄取出「旅行基金」',
      relatedId: 'goal-1#withdraw',
      categoryId: 'cat-deposit',
    );
    // 3) 取出（无转出账户 → 收入类型，旧行为会落到 swap_horiz 之外的收入兜底）
    final Transaction withdrawIncomeTxn = txn(
      id: 't3',
      type: TxnType.income,
      accountId: 'acc-bank',
      note: '储蓄取出「旅行基金」',
      relatedId: 'goal-1#withdraw',
      categoryId: 'cat-deposit',
    );
    // 4) 对照：普通餐饮支出（非储蓄流水，图标应为手绘餐饮线稿）
    final Transaction foodTxn = txn(
      id: 't4',
      type: TxnType.expense,
      accountId: 'acc-bank',
      note: '午餐',
      relatedId: 'x',
      categoryId: 'cat-food',
    );

    tester.view.physicalSize = const Size(780, 700);
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
            (ref) => Stream<List<Account>>.value(<Account>[bank, savings]),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            backgroundColor: Colors.white,
            body: RepaintBoundary(
              key: const Key('savingsTxnTiles'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TransactionTile(transaction: depositTxn),
                  TransactionTile(transaction: withdrawTransferTxn),
                  TransactionTile(transaction: withdrawIncomeTxn),
                  TransactionTile(transaction: foodTxn),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('savingsTxnTiles')),
      matchesGoldenFile('savings_txn_tile_icons.png'),
    );
  });
}
