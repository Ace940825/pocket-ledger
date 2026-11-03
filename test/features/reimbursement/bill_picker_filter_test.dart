import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/reimbursement/presentation/reimbursement_bill_picker_page.dart';

/// 构造一笔流水的便捷函数：仅关心筛选相关的关键字段，其余给安全默认值，
/// 以便专注验证「报销账单选择器」的过滤逻辑。
Transaction _txn({
  required String id,
  required TxnType type,
  bool isReimbursable = false,
  String? reimbursementAccountId,
}) {
  return Transaction(
    updatedAt: 0,
    deleted: false,
    dirty: false,
    id: id,
    bookId: 'b1',
    type: type,
    amountMinor: 1000,
    currency: 'CNY',
    accountId: 'acc',
    occurredAt: 1,
    sourceModule: SourceModule.ledger,
    feeMinor: 0,
    discountMinor: 0,
    excludeFromStats: false,
    excludeFromBudget: false,
    isReimbursable: isReimbursable,
    reimbursementAccountId: reimbursementAccountId,
  );
}

void main() {
  group('报销账单选择器 · 可提取账单过滤', () {
    test('普通支出（未开「可报销」开关）也能被找到', () {
      final List<Transaction> list = <Transaction>[
        _txn(id: 'e1', type: TxnType.expense, isReimbursable: false),
        _txn(id: 'e2', type: TxnType.expense, isReimbursable: true),
        _txn(id: 'i1', type: TxnType.income),
        _txn(id: 't1', type: TxnType.transfer),
      ];
      final (List<Transaction> branch, List<Transaction> loose) =
          splitReimbursableBills(
        list,
        reimbursedBillIds: <String>{},
        branchAccountId: null,
      );
      // 进入「选择账单」时：未指定报销账户，两笔支出都归入「未指定报销账户」。
      expect(branch, isEmpty);
      expect(loose.map((Transaction t) => t.id),
          containsAll(<String>['e1', 'e2']),);
      // 收入 / 转账不应出现。
      expect(loose.map((Transaction t) => t.id), isNot(contains('i1')));
      expect(loose.map((Transaction t) => t.id), isNot(contains('t1')));
    });

    test('已全额报销的账单被屏蔽', () {
      final List<Transaction> list = <Transaction>[
        _txn(id: 'e1', type: TxnType.expense),
      ];
      final (List<Transaction> branch, List<Transaction> loose) =
          splitReimbursableBills(
        list,
        reimbursedBillIds: <String>{'e1'},
        branchAccountId: null,
      );
      expect(branch, isEmpty);
      expect(loose, isEmpty);
    });

    test('指定报销账户时，归属该账户的账单进「分支账单」分组', () {
      final List<Transaction> list = <Transaction>[
        _txn(id: 'e1', type: TxnType.expense, reimbursementAccountId: 'ra'),
        _txn(id: 'e2', type: TxnType.expense), // 无报销账户 → 游离
      ];
      final (List<Transaction> branch, List<Transaction> loose) =
          splitReimbursableBills(
        list,
        reimbursedBillIds: <String>{},
        branchAccountId: 'ra',
      );
      expect(branch.map((Transaction t) => t.id), contains('e1'));
      expect(loose.map((Transaction t) => t.id), contains('e2'));
    });
  });
}
