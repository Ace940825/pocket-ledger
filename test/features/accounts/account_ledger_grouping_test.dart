import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/providers/asset_stats_settings.dart';
import 'package:pocket_ledger/features/accounts/presentation/account_ledger_grouping.dart';

/// 本账户 id。转账方向都相对它判定。
const String _me = 'acc1';
const String _other = 'acc2';

/// 为测试快速构造一条 Transaction。只填本分组/统计逻辑关心的字段。
Transaction _txn({
  required String id,
  required TxnType type,
  required int amountMinor,
  int occurredAt = 0,
  String accountId = _me,
  String? toAccountId,
  SourceModule sourceModule = SourceModule.ledger,
  String? transferGroupId,
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
    sourceModule: sourceModule,
    transferGroupId: transferGroupId,
    feeMinor: 0,
    discountMinor: 0,
    updatedAt: 0,
    deleted: false,
    dirty: false,
  );
}

/// 本账户转出到 [_other]。
Transaction _transferOut({
  required String id,
  required int amountMinor,
  int occurredAt = 0,
}) =>
    _txn(
      id: id,
      type: TxnType.transfer,
      amountMinor: amountMinor,
      occurredAt: occurredAt,
      accountId: _me,
      toAccountId: _other,
      sourceModule: SourceModule.transfer,
      transferGroupId: 'g-$id',
    );

/// [_other] 转入本账户。
Transaction _transferIn({
  required String id,
  required int amountMinor,
  int occurredAt = 0,
}) =>
    _txn(
      id: id,
      type: TxnType.transfer,
      amountMinor: amountMinor,
      occurredAt: occurredAt,
      accountId: _other,
      toAccountId: _me,
      sourceModule: SourceModule.transfer,
      transferGroupId: 'g-$id',
    );

int _ms(DateTime local) => local.toUtc().millisecondsSinceEpoch;

/// 便捷调用：默认以 [_me] 的视角统计。
MonthStats _stats(List<Transaction> txns, [AssetStatsSettings? settings]) =>
    computeMonthStats(
      txns,
      settings ?? const AssetStatsSettings(),
      accountId: _me,
    );

void main() {
  group('groupTransactionsByMonth', () {
    test('空列表返回空', () {
      expect(groupTransactionsByMonth(<Transaction>[]), isEmpty);
    });

    test('同一月份聚合在一组', () {
      final List<Transaction> txns = <Transaction>[
        _txn(
          id: 't1',
          type: TxnType.expense,
          amountMinor: 100,
          occurredAt: _ms(DateTime(2026, 9, 10)),
        ),
        _txn(
          id: 't2',
          type: TxnType.expense,
          amountMinor: 200,
          occurredAt: _ms(DateTime(2026, 9, 11)),
        ),
      ];

      final List<MonthGroup> groups = groupTransactionsByMonth(txns);
      expect(groups, hasLength(1));
      expect(groups.first.month.month, 9);
      expect(groups.first.transactions, hasLength(2));
    });

    test('跨月份按倒序排列（最近月份在前）', () {
      final List<Transaction> txns = <Transaction>[
        _txn(
          id: 't1',
          type: TxnType.expense,
          amountMinor: 100,
          occurredAt: _ms(DateTime(2026, 8, 1)),
        ),
        _txn(
          id: 't2',
          type: TxnType.expense,
          amountMinor: 200,
          occurredAt: _ms(DateTime(2026, 9, 1)),
        ),
      ];

      final List<MonthGroup> groups = groupTransactionsByMonth(txns);
      expect(groups, hasLength(2));
      expect(groups.first.month.month, 9);
      expect(groups.last.month.month, 8);
    });

    test('UTC 跨天时区仍归到正确本地月份', () {
      final List<Transaction> txns = <Transaction>[
        _txn(
          id: 't1',
          type: TxnType.expense,
          amountMinor: 100,
          occurredAt: DateTime.utc(2026, 8, 31, 16, 30).millisecondsSinceEpoch,
        ),
      ];

      final List<MonthGroup> groups = groupTransactionsByMonth(txns);
      expect(groups, hasLength(1));
      expect(groups.first.month.month, 9);
    });
  });

  group('groupTransactionsByDay', () {
    test('同一天的交易聚合在一组', () {
      final List<Transaction> txns = <Transaction>[
        _txn(
          id: 't1',
          type: TxnType.expense,
          amountMinor: 100,
          occurredAt: _ms(DateTime(2026, 9, 10, 10)),
        ),
        _txn(
          id: 't2',
          type: TxnType.expense,
          amountMinor: 200,
          occurredAt: _ms(DateTime(2026, 9, 10, 18)),
        ),
        _txn(
          id: 't3',
          type: TxnType.expense,
          amountMinor: 300,
          occurredAt: _ms(DateTime(2026, 9, 9)),
        ),
      ];

      final List<DayGroup> days = groupTransactionsByDay(txns);
      expect(days, hasLength(2));
      expect(days.first.transactions, hasLength(2));
      expect(days.last.transactions, hasLength(1));
    });
  });

  group('computeMonthStats · 默认（两个转账开关都关）', () {
    final List<Transaction> txns = <Transaction>[
      _txn(id: 'e1', type: TxnType.expense, amountMinor: 300),
      _txn(id: 'i1', type: TxnType.income, amountMinor: 50),
      _transferOut(id: 'o1', amountMinor: 500),
      _transferIn(id: 'n1', amountMinor: 200),
    ];

    test('支出只算普通支出，收入只算普通收入，其他=全部转账', () {
      final MonthStats stats = _stats(txns);
      expect(stats.expenseMinor, 300);
      expect(stats.incomeMinor, 50);
      expect(stats.otherMinor, 700);
      expect(stats.showOther, isTrue, reason: '两个开关没都开 → 展示「其他」');
    });

    test('空列表全为 0', () {
      final MonthStats stats = _stats(<Transaction>[]);
      expect(stats.expenseMinor, 0);
      expect(stats.incomeMinor, 0);
      expect(stats.otherMinor, 0);
      expect(stats.balanceMinor, 0);
    });
  });

  group('computeMonthStats · 支出流水统计（+转账转出）', () {
    final List<Transaction> txns = <Transaction>[
      _txn(id: 'e1', type: TxnType.expense, amountMinor: 300),
      _transferOut(id: 'o1', amountMinor: 500),
      _transferIn(id: 'n1', amountMinor: 200),
    ];

    test('开启后转账转出计入支出，且不再重复进「其他」', () {
      final MonthStats stats =
          _stats(txns, const AssetStatsSettings(expenseWithTransfer: true));
      expect(stats.expenseMinor, 800, reason: '300 + 500');
      expect(stats.otherMinor, 200, reason: '只剩转入腿');
    });

    test('只看转入腿：本账户是转入方时不算支出', () {
      final MonthStats stats = _stats(
        <Transaction>[_transferIn(id: 'n1', amountMinor: 200)],
        const AssetStatsSettings(expenseWithTransfer: true),
      );
      expect(stats.expenseMinor, 0, reason: '转入不是支出');
      expect(stats.otherMinor, 200);
    });
  });

  group('computeMonthStats · 收入流水统计（+转账转入）', () {
    final List<Transaction> txns = <Transaction>[
      _txn(id: 'i1', type: TxnType.income, amountMinor: 50),
      _transferOut(id: 'o1', amountMinor: 500),
      _transferIn(id: 'n1', amountMinor: 200),
    ];

    test('开启后转账转入计入收入，且不再重复进「其他」', () {
      final MonthStats stats =
          _stats(txns, const AssetStatsSettings(incomeWithTransfer: true));
      expect(stats.incomeMinor, 250, reason: '50 + 200');
      expect(stats.otherMinor, 500, reason: '只剩转出腿');
    });

    test('两个开关都开：转账全部折进收支，其他为 0 且整项隐藏', () {
      final MonthStats stats = _stats(
        txns,
        const AssetStatsSettings(
          expenseWithTransfer: true,
          incomeWithTransfer: true,
        ),
      );
      expect(stats.expenseMinor, 500);
      expect(stats.incomeMinor, 250);
      expect(stats.otherMinor, 0);
      expect(stats.showOther, isFalse, reason: '两个开关都开 → 隐藏「其他」');
    });
  });

  group('computeMonthStats · 「其他」的展示开关', () {
    final List<Transaction> txns = <Transaction>[
      _txn(id: 'e1', type: TxnType.expense, amountMinor: 1000),
      _transferOut(id: 'o1', amountMinor: 500),
      _transferIn(id: 'n1', amountMinor: 200),
    ];

    test('两个都关 → 展示', () {
      expect(_stats(txns).showOther, isTrue);
    });

    test('只开支出 → 仍展示（其他里还留着转入腿）', () {
      final MonthStats stats =
          _stats(txns, const AssetStatsSettings(expenseWithTransfer: true));
      expect(stats.showOther, isTrue);
      expect(stats.otherMinor, 200);
    });

    test('只开收入 → 仍展示（其他里还留着转出腿）', () {
      final MonthStats stats =
          _stats(txns, const AssetStatsSettings(incomeWithTransfer: true));
      expect(stats.showOther, isTrue);
      expect(stats.otherMinor, 500);
    });

    test('两个都开 → 隐藏', () {
      final MonthStats stats = _stats(
        txns,
        const AssetStatsSettings(
          expenseWithTransfer: true,
          incomeWithTransfer: true,
        ),
      );
      expect(stats.showOther, isFalse);
    });
  });

  group('computeMonthStats · 结余 = 支出 − 收入', () {
    test('支出多于收入 → 结余为正（口径：支出在前）', () {
      final MonthStats stats = _stats(<Transaction>[
        _txn(id: 'e1', type: TxnType.expense, amountMinor: 1000),
        _txn(id: 'i1', type: TxnType.income, amountMinor: 412),
      ]);
      expect(stats.expenseMinor, 1000);
      expect(stats.incomeMinor, 412);
      expect(stats.balanceMinor, 588, reason: '1000 − 412');
    });

    test('收入多于支出 → 结余为负', () {
      final MonthStats stats = _stats(<Transaction>[
        _txn(id: 'e1', type: TxnType.expense, amountMinor: 100),
        _txn(id: 'i1', type: TxnType.income, amountMinor: 900),
      ]);
      expect(stats.balanceMinor, -800, reason: '100 − 900');
    });

    test('只有支出 → 结余等于支出', () {
      final MonthStats stats = _stats(<Transaction>[
        _txn(id: 'e1', type: TxnType.expense, amountMinor: 250),
      ]);
      expect(stats.balanceMinor, 250);
    });

    test('结余基于开关过滤后的收支（把开关的影响一起算进来）', () {
      // 支出 1000 + 转出 500 = 1500；收入 412 + 转入 200 = 612 → 结余 888。
      final MonthStats stats = _stats(
        <Transaction>[
          _txn(id: 'e1', type: TxnType.expense, amountMinor: 1000),
          _txn(id: 'i1', type: TxnType.income, amountMinor: 412),
          _transferOut(id: 'o1', amountMinor: 500),
          _transferIn(id: 'n1', amountMinor: 200),
        ],
        const AssetStatsSettings(
          expenseWithTransfer: true,
          incomeWithTransfer: true,
        ),
      );
      expect(stats.expenseMinor, 1500);
      expect(stats.incomeMinor, 612);
      expect(stats.balanceMinor, 888, reason: '1500 − 612');
    });

    test('结余不受「其他」影响（其他只是展示项）', () {
      final MonthStats stats = _stats(<Transaction>[
        _txn(id: 'e1', type: TxnType.expense, amountMinor: 1000),
        _transferOut(id: 'o1', amountMinor: 500),
      ]);
      expect(stats.otherMinor, 500, reason: '转出没折进支出，进了其他');
      expect(stats.balanceMinor, 1000, reason: '仍只按支出 1000 − 收入 0');
    });
  });

  group('computeMonthStats · 退款抵扣', () {
    final List<Transaction> txns = <Transaction>[
      _txn(id: 'e1', type: TxnType.expense, amountMinor: 1000),
      _txn(
        id: 'r1',
        type: TxnType.income,
        amountMinor: 300,
        sourceModule: SourceModule.refund,
      ),
    ];

    test('默认（进行抵扣）：退款从支出里扣掉，不计入收入', () {
      final MonthStats stats = _stats(txns);
      expect(stats.expenseMinor, 700);
      expect(stats.incomeMinor, 0);
    });

    test('开启不抵扣：退款按普通收入计入收入，支出保持原值', () {
      final MonthStats stats =
          _stats(txns, const AssetStatsSettings(noOffset: true));
      expect(stats.expenseMinor, 1000);
      expect(stats.incomeMinor, 300);
    });
  });

  group('computeMonthStats · 边界', () {
    test('缺对手方的转账（旧数据）只进「其他」', () {
      final MonthStats stats = _stats(<Transaction>[
        _txn(
          id: 'legacy',
          type: TxnType.transfer,
          amountMinor: 500,
          accountId: _me,
          sourceModule: SourceModule.transfer,
        ),
      ]);
      expect(stats.otherMinor, 500);
      expect(stats.expenseMinor, 0);
      expect(stats.incomeMinor, 0);
    });

    test('方向取决于视角账户：同一笔流水换个账户看方向相反', () {
      final List<Transaction> leg = <Transaction>[
        _transferOut(id: 'o1', amountMinor: 500),
      ];

      final MonthStats mine = computeMonthStats(
        leg,
        const AssetStatsSettings(
          expenseWithTransfer: true,
          incomeWithTransfer: true,
        ),
        accountId: _me,
      );
      final MonthStats theirs = computeMonthStats(
        leg,
        const AssetStatsSettings(
          expenseWithTransfer: true,
          incomeWithTransfer: true,
        ),
        accountId: _other,
      );

      expect(mine.expenseMinor, 500, reason: '我是转出方 → 支出');
      expect(mine.incomeMinor, 0);
      expect(theirs.incomeMinor, 500, reason: '对方是转入方 → 收入');
      expect(theirs.expenseMinor, 0);
    });
  });
}
