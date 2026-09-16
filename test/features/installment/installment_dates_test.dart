import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/features/installment/domain/installment_dates.dart';
import 'package:pocket_ledger/features/installment/domain/repeat_rule.dart';

void main() {
  group('computeInstallmentDueDates', () {
    final DateTime firstDue = DateTime(2026, 9, 16, 14, 38);

    test('默认每月：保持开始日期', () {
      final List<DateTime> dates = computeInstallmentDueDates(
        firstDue: firstDue,
        rule: null,
        totalPeriods: 3,
      );
      expect(dates.length, 3);
      expect(dates[0], DateTime(2026, 9, 16, 14, 38));
      expect(dates[1], DateTime(2026, 10, 16, 14, 38));
      expect(dates[2], DateTime(2026, 11, 16, 14, 38));
    });

    test('每月间隔 2：每两个月', () {
      final List<DateTime> dates = computeInstallmentDueDates(
        firstDue: firstDue,
        rule: const InstallmentRepeatRule(
          unit: RepeatUnit.month,
          interval: 2,
        ),
        totalPeriods: 3,
      );
      expect(dates[0], DateTime(2026, 9, 16, 14, 38));
      expect(dates[1], DateTime(2026, 11, 16, 14, 38));
      expect(dates[2], DateTime(2027, 1, 16, 14, 38));
    });

    test('每月指定 31 日：月末夹取', () {
      final List<DateTime> dates = computeInstallmentDueDates(
        firstDue: firstDue,
        rule: const InstallmentRepeatRule(
          unit: RepeatUnit.month,
          interval: 1,
          monthDay: 31,
        ),
        totalPeriods: 3,
      );
      expect(dates[0], DateTime(2026, 9, 30, 14, 38));
      expect(dates[1], DateTime(2026, 10, 31, 14, 38));
      expect(dates[2], DateTime(2026, 11, 30, 14, 38));
    });

    test('每月月末：用 -1 表示', () {
      final List<DateTime> dates = computeInstallmentDueDates(
        firstDue: firstDue,
        rule: const InstallmentRepeatRule(
          unit: RepeatUnit.month,
          interval: 1,
          monthDay: -1,
        ),
        totalPeriods: 3,
      );
      expect(dates[0], DateTime(2026, 9, 30, 14, 38));
      expect(dates[1], DateTime(2026, 10, 31, 14, 38));
      expect(dates[2], DateTime(2026, 11, 30, 14, 38));
    });

    test('每天间隔 7：每 7 天', () {
      final List<DateTime> dates = computeInstallmentDueDates(
        firstDue: firstDue,
        rule: const InstallmentRepeatRule(
          unit: RepeatUnit.day,
          interval: 7,
        ),
        totalPeriods: 3,
      );
      expect(dates[0], DateTime(2026, 9, 16, 14, 38));
      expect(dates[1], DateTime(2026, 9, 23, 14, 38));
      expect(dates[2], DateTime(2026, 9, 30, 14, 38));
    });

    test('每周指定周一：从最近周一开始', () {
      // 2026-09-16 是周三。
      final List<DateTime> dates = computeInstallmentDueDates(
        firstDue: firstDue,
        rule: const InstallmentRepeatRule(
          unit: RepeatUnit.week,
          interval: 1,
          weekDay: 1,
        ),
        totalPeriods: 3,
      );
      expect(dates[0], DateTime(2026, 9, 21, 14, 38)); // 下周一
      expect(dates[1], DateTime(2026, 9, 28, 14, 38));
      expect(dates[2], DateTime(2026, 10, 5, 14, 38));
    });

    test('每周指定周三：保持开始日期', () {
      final List<DateTime> dates = computeInstallmentDueDates(
        firstDue: firstDue,
        rule: const InstallmentRepeatRule(
          unit: RepeatUnit.week,
          interval: 1,
          weekDay: 3,
        ),
        totalPeriods: 3,
      );
      expect(dates[0], DateTime(2026, 9, 16, 14, 38));
      expect(dates[1], DateTime(2026, 9, 23, 14, 38));
      expect(dates[2], DateTime(2026, 9, 30, 14, 38));
    });

    test('每年指定 5 月', () {
      final List<DateTime> dates = computeInstallmentDueDates(
        firstDue: firstDue,
        rule: const InstallmentRepeatRule(
          unit: RepeatUnit.year,
          interval: 1,
          month: 5,
        ),
        totalPeriods: 3,
      );
      expect(dates[0], DateTime(2026, 5, 16, 14, 38));
      expect(dates[1], DateTime(2027, 5, 16, 14, 38));
      expect(dates[2], DateTime(2028, 5, 16, 14, 38));
    });
  });
}
