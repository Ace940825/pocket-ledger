import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/accounts/presentation/account_ledger_grouping.dart';
import 'package:pocket_ledger/providers/asset_stats_settings.dart';

/// 本账户 id。转账方向都相对它判定。
const String _me = 'acc1';
const String _other = 'acc2';

/// 为测试快速构造一条 Transaction。只填本分组/统计逻辑关心的字段。
Transaction _txn({
  required String id,
  required TxnType type,
  required int amountMinor,
  int feeMinor = 0,
  int discountMinor = 0,
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

/// 本账户转出到 [_other]。
Transaction _transferOut({
  required String id,
  required int amountMinor,
  int feeMinor = 0,
  int discountMinor = 0,
  int occurredAt = 0,
}) =>
    _txn(
      id: id,
      type: TxnType.transfer,
      amountMinor: amountMinor,
      feeMinor: feeMinor,
      discountMinor: discountMinor,
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
  int feeMinor = 0,
  int discountMinor = 0,
  int occurredAt = 0,
}) =>
    _txn(
      id: id,
      type: TxnType.transfer,
      amountMinor: amountMinor,
      feeMinor: feeMinor,
      discountMinor: discountMinor,
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

    test('转账转出含手续费时按实际扣款统计', () {
      final MonthStats stats = _stats(
        <Transaction>[
          _transferOut(id: 'o1', amountMinor: 3000, feeMinor: 200),
        ],
        const AssetStatsSettings(expenseWithTransfer: true),
      );
      expect(stats.expenseMinor, 3200, reason: '30 + 2 = 32 元');
      expect(stats.otherMinor, 0);
    });

    test('转账转出含优惠时按实际扣款统计', () {
      final MonthStats stats = _stats(
        <Transaction>[
          _transferOut(
            id: 'o1',
            amountMinor: 3000,
            feeMinor: 200,
            discountMinor: 50,
          ),
        ],
        const AssetStatsSettings(expenseWithTransfer: true),
      );
      expect(stats.expenseMinor, 3150, reason: '30 + 2 - 0.5 = 31.5 元');
      expect(stats.otherMinor, 0);
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

  group('statementPeriod · 账单周期起止', () {
    test('账单日 1 号：10 月周期 = 9月2日～10月1日', () {
      final ({DateTime start, DateTime end}) p = statementPeriod(2026, 10, 1);
      expect(p.start, DateTime(2026, 9, 2));
      expect(p.end, DateTime(2026, 10, 1));
    });

    test('1 月周期跨年：起点 = 上一年 12 月账单日次日', () {
      final ({DateTime start, DateTime end}) p = statementPeriod(2026, 1, 1);
      expect(p.start, DateTime(2025, 12, 2));
      expect(p.end, DateTime(2026, 1, 1));
    });

    test('账单日 31 号：2 月周期收敛到月末，不与 3 月周期重叠/留缝', () {
      final ({DateTime start, DateTime end}) feb = statementPeriod(2026, 2, 31);
      expect(feb.start, DateTime(2026, 2, 1));
      expect(feb.end, DateTime(2026, 2, 28), reason: '2026 年 2 月只有 28 天');
      final ({DateTime start, DateTime end}) mar = statementPeriod(2026, 3, 31);
      expect(mar.start, DateTime(2026, 3, 1), reason: '紧接 2 月周期终点次日');
      expect(mar.end, DateTime(2026, 3, 31));
    });

    test('周期在时间轴上严格首尾相接（本期起点 = 上期终点次日）', () {
      for (int m = 2; m <= 12; m++) {
        final ({DateTime start, DateTime end}) prev =
            statementPeriod(2026, m - 1, 9);
        final ({DateTime start, DateTime end}) cur =
            statementPeriod(2026, m, 9);
        expect(
          cur.start,
          DateTime(prev.end.year, prev.end.month, prev.end.day + 1),
          reason: '$m 月周期起点应紧接 ${m - 1} 月周期终点',
        );
      }
    });
  });

  group('groupTransactionsByStatement · 按账单周期分组', () {
    test('空列表返回空', () {
      expect(groupTransactionsByStatement(<Transaction>[], 1, 2026), isEmpty);
    });

    test('按账单周期归属而非自然月：9 月消费进 10 月账单', () {
      final List<Transaction> txns = <Transaction>[
        _txn(
          id: 't1',
          type: TxnType.expense,
          amountMinor: 100,
          occurredAt: _ms(DateTime(2026, 9, 15)),
        ),
        _txn(
          id: 't2',
          type: TxnType.expense,
          amountMinor: 200,
          occurredAt: _ms(DateTime(2026, 10, 1)),
        ),
        _txn(
          id: 't3',
          type: TxnType.expense,
          amountMinor: 300,
          occurredAt: _ms(DateTime(2026, 10, 2)),
        ),
        _txn(
          id: 't4',
          type: TxnType.expense,
          amountMinor: 400,
          occurredAt: _ms(DateTime(2026, 10, 5)),
        ),
      ];

      final List<MonthGroup> groups =
          groupTransactionsByStatement(txns, 1, 2026);
      expect(groups, hasLength(2));
      // 按截止月倒序。
      expect(groups.first.month, DateTime(2026, 11));
      expect(groups.last.month, DateTime(2026, 10));
      // 10 月账单周期 = 9月2日～10月1日（含两端）：9/15 与 10/1 两笔归它。
      expect(
        groups.last.transactions.map((Transaction t) => t.id),
        <String>['t1', 't2'],
      );
      // 11 月账单周期 = 10月2日～11月1日：10/2（起点，含）与 10/5。
      expect(
        groups.first.transactions.map((Transaction t) => t.id),
        <String>['t3', 't4'],
      );
    });

    test('组上带周期起止（供月份行「周期：x月x日–x月x日」使用）', () {
      final List<MonthGroup> groups = groupTransactionsByStatement(
        <Transaction>[
          _txn(
            id: 't1',
            type: TxnType.expense,
            amountMinor: 100,
            occurredAt: _ms(DateTime(2026, 10, 1)),
          ),
        ],
        1,
        2026,
      );
      expect(groups, hasLength(1));
      expect(groups.first.month, DateTime(2026, 10));
      expect(groups.first.periodStart, DateTime(2026, 9, 2));
      expect(groups.first.periodEnd, DateTime(2026, 10, 1));
    });

    test('12 月账单日之后的交易归次年 1 月账单，本年列表滤掉', () {
      final List<MonthGroup> groups = groupTransactionsByStatement(
        <Transaction>[
          _txn(
            id: 'in',
            type: TxnType.expense,
            amountMinor: 100,
            occurredAt: _ms(DateTime(2026, 12, 1)),
          ),
          _txn(
            id: 'out',
            type: TxnType.expense,
            amountMinor: 200,
            occurredAt: _ms(DateTime(2026, 12, 20)),
          ),
        ],
        1,
        2026,
      );
      expect(groups, hasLength(1));
      expect(groups.first.month, DateTime(2026, 12));
      expect(
        groups.first.transactions.map((Transaction t) => t.id),
        <String>['in'],
        reason: '12/1 是 12 月账单周期终点（含）；12/20 已属次年 1 月账单',
      );
    });

    test('1 月账单周期的跨年尾巴：上年 12 月消费归本年 1 月账单', () {
      final List<MonthGroup> groups = groupTransactionsByStatement(
        <Transaction>[
          _txn(
            id: 'dec',
            type: TxnType.expense,
            amountMinor: 100,
            occurredAt: _ms(DateTime(2025, 12, 20)),
          ),
          _txn(
            id: 'jan1',
            type: TxnType.expense,
            amountMinor: 200,
            occurredAt: _ms(DateTime(2026, 1, 1)),
          ),
          _txn(
            id: 'jan2',
            type: TxnType.expense,
            amountMinor: 300,
            occurredAt: _ms(DateTime(2026, 1, 2)),
          ),
        ],
        1,
        2026,
      );
      expect(groups, hasLength(2));
      expect(groups.first.month, DateTime(2026, 2));
      expect(
        groups.first.transactions.map((Transaction t) => t.id),
        <String>['jan2'],
      );
      expect(groups.last.month, DateTime(2026, 1));
      expect(
        groups.last.transactions.map((Transaction t) => t.id),
        <String>['dec', 'jan1'],
        reason: '上年 12/20 落在 1 月账单周期（上年12月2日～1月1日）内',
      );
    });
  });
}
