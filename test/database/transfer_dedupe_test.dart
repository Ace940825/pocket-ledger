import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/database/daos/transfer_dedupe.dart';
import 'package:pocket_ledger/domain/enums.dart';

/// 构造一条流水。默认是普通支出，便于和转账腿对比。
Transaction _txn({
  required String id,
  required TxnType type,
  required int amountMinor,
  required String accountId,
  String? toAccountId,
  String? transferGroupId,
  int occurredAt = 0,
}) {
  return Transaction(
    id: id,
    bookId: 'book1',
    type: type,
    amountMinor: amountMinor,
    currency: 'CNY',
    accountId: accountId,
    toAccountId: toAccountId,
    occurredAt: occurredAt,
    sourceModule:
        type == TxnType.transfer ? SourceModule.transfer : SourceModule.ledger,
    transferGroupId: transferGroupId,
    updatedAt: 0,
    deleted: false,
    dirty: false,
  );
}

/// 模拟**历史遗留**的成对两条腿（早期 `transfer()` 的写法，
/// 现已改为只写一条，见 `transfer_repository_test.dart`）：
/// - 转出腿：accountId = 转出方, toAccountId = 转入方
/// - 转入腿：accountId = 转入方, toAccountId = 转出方
List<Transaction> _transferPair({
  required String groupId,
  required String from,
  required String to,
  required int amountMinor,
  int occurredAt = 0,
}) {
  return <Transaction>[
    _txn(
      id: '$groupId-out',
      type: TxnType.transfer,
      amountMinor: amountMinor,
      accountId: from,
      toAccountId: to,
      transferGroupId: groupId,
      occurredAt: occurredAt,
    ),
    _txn(
      id: '$groupId-in',
      type: TxnType.transfer,
      amountMinor: amountMinor,
      accountId: to,
      toAccountId: from,
      transferGroupId: groupId,
      occurredAt: occurredAt,
    ),
  ];
}

void main() {
  group('dedupeAccountTransfers', () {
    test('空列表返回空', () {
      expect(dedupeAccountTransfers(<Transaction>[], 'A'), isEmpty);
    });

    test('非转账流水原样保留且顺序不变', () {
      final List<Transaction> input = <Transaction>[
        _txn(
          id: 'e1',
          type: TxnType.expense,
          amountMinor: 100,
          accountId: 'A',
        ),
        _txn(
          id: 'i1',
          type: TxnType.income,
          amountMinor: 200,
          accountId: 'A',
        ),
      ];

      final List<Transaction> out = dedupeAccountTransfers(input, 'A');
      expect(out.map((Transaction t) => t.id), <String>['e1', 'i1']);
    });

    test('A 为转出方：一笔转账只保留「属于 A」的转出腿', () {
      // 查询侧会同时命中两条腿：转出腿靠 accountId、转入腿靠 toAccountId。
      final List<Transaction> input = _transferPair(
        groupId: 'g1',
        from: 'A',
        to: 'B',
        amountMinor: 900,
      );

      final List<Transaction> out = dedupeAccountTransfers(input, 'A');
      expect(out, hasLength(1));
      expect(out.single.id, 'g1-out');
      expect(out.single.accountId, 'A');
      expect(out.single.amountMinor, 900);
    });

    test('A 为转入方：只保留「属于 A」的转入腿', () {
      final List<Transaction> input = _transferPair(
        groupId: 'g1',
        from: 'B',
        to: 'A',
        amountMinor: 900,
      );

      final List<Transaction> out = dedupeAccountTransfers(input, 'A');
      expect(out, hasLength(1));
      expect(out.single.id, 'g1-in');
      expect(out.single.accountId, 'A');
    });

    test('顺序无关：转入腿先到、转出腿后到时仍选到正确的腿', () {
      final List<Transaction> pair = _transferPair(
        groupId: 'g1',
        from: 'A',
        to: 'B',
        amountMinor: 900,
      );
      final List<Transaction> reversed = pair.reversed.toList(growable: false);

      final List<Transaction> out = dedupeAccountTransfers(reversed, 'A');
      expect(out, hasLength(1));
      expect(out.single.id, 'g1-out');
    });

    test('多笔转账分别去重，互不影响', () {
      final List<Transaction> input = <Transaction>[
        ..._transferPair(groupId: 'g1', from: 'A', to: 'B', amountMinor: 900),
        ..._transferPair(groupId: 'g2', from: 'C', to: 'A', amountMinor: 300),
      ];

      final List<Transaction> out = dedupeAccountTransfers(input, 'A');
      expect(out, hasLength(2));
      // 「其他」合计不应翻倍。
      final int other = out.fold<int>(
        0,
        (int s, Transaction t) =>
            t.type == TxnType.transfer ? s + t.amountMinor : s,
      );
      expect(other, 1200);
    });

    test('历史数据只有一条腿时原样保留', () {
      final List<Transaction> input = <Transaction>[
        _txn(
          id: 'legacy',
          type: TxnType.transfer,
          amountMinor: 500,
          accountId: 'B',
          toAccountId: 'A',
          transferGroupId: 'g-only',
        ),
      ];

      final List<Transaction> out = dedupeAccountTransfers(input, 'A');
      expect(out, hasLength(1));
      expect(out.single.id, 'legacy');
    });

    test('transferGroupId 为空的转账不做合并（按普通流水处理）', () {
      final List<Transaction> input = <Transaction>[
        _txn(
          id: 't1',
          type: TxnType.transfer,
          amountMinor: 100,
          accountId: 'A',
          toAccountId: 'B',
        ),
        _txn(
          id: 't2',
          type: TxnType.transfer,
          amountMinor: 200,
          accountId: 'B',
          toAccountId: 'A',
        ),
      ];

      final List<Transaction> out = dedupeAccountTransfers(input, 'A');
      expect(out, hasLength(2));
    });
  });

  group('transferDirectionOf', () {
    test('本账户是 accountId → 转出', () {
      final Transaction leg = _txn(
        id: 'g1',
        type: TxnType.transfer,
        amountMinor: 900,
        accountId: 'A',
        toAccountId: 'B',
        transferGroupId: 'g1',
      );
      expect(transferDirectionOf(leg, 'A'), TransferDirection.outgoing);
    });

    test('本账户是 toAccountId → 转入', () {
      final Transaction leg = _txn(
        id: 'g1',
        type: TxnType.transfer,
        amountMinor: 900,
        accountId: 'A',
        toAccountId: 'B',
        transferGroupId: 'g1',
      );
      expect(transferDirectionOf(leg, 'B'), TransferDirection.incoming);
    });

    test('非转账流水没有方向', () {
      final Transaction expense = _txn(
        id: 'e1',
        type: TxnType.expense,
        amountMinor: 100,
        accountId: 'A',
      );
      expect(transferDirectionOf(expense, 'A'), isNull);
    });

    test('缺少对手方的转账没有方向', () {
      final Transaction legacy = _txn(
        id: 'legacy',
        type: TxnType.transfer,
        amountMinor: 100,
        accountId: 'A',
      );
      expect(transferDirectionOf(legacy, 'A'), isNull);
    });
  });
}
