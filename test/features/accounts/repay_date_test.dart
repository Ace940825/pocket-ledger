import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/accounts/data/repay_date.dart';

/// 还款日推算 helper 单元测试：固定日期 / 免息期 两种模式 + 边界口径。
/// 「今天」一律注入固定值，避免随真实日期漂移。
void main() {
  Account fakeAccount({
    int? billingDay,
    int? dueDay,
    int? dueGraceDays,
  }) {
    return Account(
      id: 'a1',
      bookId: 'default',
      name: '测试信用卡',
      type: AccountType.creditCard,
      balanceMinor: 0,
      currency: 'CNY',
      isArchived: false,
      status: AccountStatus.active,
      includeInTotal: true,
      sortOrder: 0,
      updatedAt: 0,
      deleted: false,
      dirty: false,
      billingDay: billingDay,
      dueDay: dueDay,
      dueGraceDays: dueGraceDays,
    );
  }

  group('repayModeOf', () {
    test('免息期优先：dueGraceDays 非空 → graceDays', () {
      expect(
        repayModeOf(fakeAccount(billingDay: 5, dueDay: 23, dueGraceDays: 18)),
        RepayMode.graceDays,
      );
    });

    test('无免息期 → fixedDay（dueDay 有无都算）', () {
      expect(repayModeOf(fakeAccount(billingDay: 5, dueDay: 23)), RepayMode.fixedDay);
      expect(repayModeOf(fakeAccount(billingDay: 5)), RepayMode.fixedDay);
    });
  });

  group('nextMonthlyDate', () {
    test('今天即当天 → 归到下个月', () {
      expect(nextMonthlyDate(23, DateTime(2026, 10, 23)), DateTime(2026, 11, 23));
    });

    test('今天还没到 → 仍是本月', () {
      expect(nextMonthlyDate(23, DateTime(2026, 10, 10)), DateTime(2026, 10, 23));
    });

    test('跨年：12 月的下一期归到明年 1 月', () {
      expect(nextMonthlyDate(23, DateTime(2026, 12, 25)), DateTime(2027, 1, 23));
    });

    test('31 号在小月收敛到当月最后一天', () {
      // 2026 年 2 月只有 28 天。
      expect(nextMonthlyDate(31, DateTime(2026, 2, 10)), DateTime(2026, 2, 28));
      // 4 月 30 天。
      expect(nextMonthlyDate(31, DateTime(2026, 4, 10)), DateTime(2026, 4, 30));
    });
  });

  group('nextDueDate', () {
    test('固定日期模式：每月 dueDay 号', () {
      final DateTime? due = nextDueDate(
        fakeAccount(billingDay: 1, dueDay: 20),
        DateTime(2026, 10, 23),
      );
      expect(due, DateTime(2026, 11, 20));
    });

    test('免息期模式：下一账单日 + N 天', () {
      // 账单日 5 号，免息期 18 天；今天 10-23（账单日已过）→ 下一账单 11-05，
      // +18 天 → 11-23。
      final DateTime? due = nextDueDate(
        fakeAccount(billingDay: 5, dueGraceDays: 18),
        DateTime(2026, 10, 23),
      );
      expect(due, DateTime(2026, 11, 23));
    });

    test('免息期模式：账单日未到 → 本期账单日 + N 天', () {
      // 今天 10-03，账单日 5 号还没到 → 下一账单 10-05，+20 天 → 10-25。
      final DateTime? due = nextDueDate(
        fakeAccount(billingDay: 5, dueGraceDays: 20),
        DateTime(2026, 10, 3),
      );
      expect(due, DateTime(2026, 10, 25));
    });

    test('免息期跨月：账单日 + N 天可跨到下一月', () {
      // 今天 10-26，账单日 25 号已过 → 下一账单 11-25；+20 天 → 12-15
      // （跨越 11 月落到 12 月）。
      final DateTime? due = nextDueDate(
        fakeAccount(billingDay: 25, dueGraceDays: 20),
        DateTime(2026, 10, 26),
      );
      expect(due, DateTime(2026, 12, 15));
    });

    test('无账单日（无计费周期）→ null', () {
      expect(nextDueDate(fakeAccount(dueDay: 20), DateTime(2026, 10, 23)), isNull);
    });

    test('两种模式都无值 → null', () {
      expect(nextDueDate(fakeAccount(billingDay: 1), DateTime(2026, 10, 23)), isNull);
    });
  });

  group('repaySummary', () {
    test('免息期 → 账单后N天', () {
      expect(repaySummary(fakeAccount(billingDay: 5, dueGraceDays: 18)), '账单后18天');
    });

    test('固定日期 → 每月X号', () {
      expect(repaySummary(fakeAccount(billingDay: 1, dueDay: 20)), '每月20号');
    });

    test('都无值 → 破折号', () {
      expect(repaySummary(fakeAccount(billingDay: 1)), '—');
    });
  });
}
