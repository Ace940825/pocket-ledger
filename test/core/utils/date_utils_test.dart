import 'package:flutter_test/flutter_test.dart';

import 'package:pocket_ledger/core/utils/date_utils.dart';

void main() {
  group('addMonths', () {
    test('普通月份直接加，日不变', () {
      expect(addMonths(DateTime(2026, 3, 15), 1), DateTime(2026, 4, 15));
      expect(addMonths(DateTime(2026, 3, 15), 6), DateTime(2026, 9, 15));
    });

    test('跨年进位', () {
      expect(addMonths(DateTime(2026, 11, 10), 3), DateTime(2027, 2, 10));
      expect(addMonths(DateTime(2026, 1, 10), -2), DateTime(2025, 11, 10));
    });

    // 这是本工具存在的核心理由：Dart 原生 DateTime(y, m+1, d) 会把
    // 1 月 31 日 +1 月溢出成 3 月 3 日，而分期账单要求落在 2 月末。
    test('月末夹取：1/31 + 1 月 = 2/28（平年）', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    });

    test('月末夹取：1/31 + 1 月 = 2/29（闰年）', () {
      expect(addMonths(DateTime(2024, 1, 31), 1), DateTime(2024, 2, 29));
    });

    test('月末夹取：8/31 + 1 月 = 9/30', () {
      expect(addMonths(DateTime(2026, 8, 31), 1), DateTime(2026, 9, 30));
    });

    test('加 0 个月保持不变', () {
      expect(addMonths(DateTime(2026, 5, 20), 0), DateTime(2026, 5, 20));
    });

    test('保留时分', () {
      expect(
        addMonths(DateTime(2026, 5, 20, 13, 45), 1),
        DateTime(2026, 6, 20, 13, 45),
      );
    });
  });

  group('daysInMonth / isLeapYear', () {
    test('各月天数', () {
      expect(daysInMonth(2026, 1), 31);
      expect(daysInMonth(2026, 4), 30);
      expect(daysInMonth(2026, 2), 28);
      expect(daysInMonth(2024, 2), 29);
    });

    test('闰年判定', () {
      expect(isLeapYear(2024), isTrue);
      expect(isLeapYear(2000), isTrue); // 能被 400 整除
      expect(isLeapYear(1900), isFalse); // 能被 100 但不能被 400 整除
      expect(isLeapYear(2026), isFalse);
    });
  });

  group('budgetRange', () {
    test('月度区间为 [当月 1 日, 次月 1 日)', () {
      final (int start, int end) startAndEnd = (
        budgetRange(
          year: 2026,
          periodIndex: 3,
          monthly: true,
          quarterly: false,
        ).start,
        budgetRange(
          year: 2026,
          periodIndex: 3,
          monthly: true,
          quarterly: false,
        ).end,
      );
      // 端点由「本地月初」转 UTC 毫秒得到，回看时必须用 toLocal()，
      // 否则东八区下会整体退回上一个月。
      final DateTime startDt = DateTime.fromMillisecondsSinceEpoch(
        startAndEnd.$1,
        isUtc: true,
      ).toLocal();
      final DateTime endDt = DateTime.fromMillisecondsSinceEpoch(
        startAndEnd.$2,
        isUtc: true,
      ).toLocal();
      expect(startDt.month, 3);
      expect(endDt.month, 4);
      expect(startDt.isBefore(endDt), isTrue);
    });

    test('年度区间覆盖整年', () {
      final ({int end, int start}) r = budgetRange(
        year: 2026,
        periodIndex: 0,
        monthly: false,
        quarterly: false,
      );
      final DateTime start =
          DateTime.fromMillisecondsSinceEpoch(r.start, isUtc: true).toLocal();
      final DateTime end =
          DateTime.fromMillisecondsSinceEpoch(r.end, isUtc: true).toLocal();
      expect(start.month, 1);
      // 右开区间，次年月首
      expect(end.year, 2027);
      expect(end.month, 1);
    });

    test('季度区间为 3 个月', () {
      final ({int end, int start}) r = budgetRange(
        year: 2026,
        periodIndex: 2,
        monthly: false,
        quarterly: true,
      );
      final DateTime start =
          DateTime.fromMillisecondsSinceEpoch(r.start, isUtc: true).toLocal();
      final DateTime end =
          DateTime.fromMillisecondsSinceEpoch(r.end, isUtc: true).toLocal();
      expect(start.month, 4); // Q2 从 4 月开始
      expect(end.month, 7); // 到 6 月末，右开 → 7 月 1 日
    });
  });

  group('currentPeriodIndex', () {
    test('月度返回月份，季度返回 1-4，年度恒为 0', () {
      expect(
        currentPeriodIndex(monthly: true, quarterly: false),
        inInclusiveRange(1, 12),
      );
      expect(
        currentPeriodIndex(monthly: false, quarterly: true),
        inInclusiveRange(1, 4),
      );
      expect(currentPeriodIndex(monthly: false, quarterly: false), 0);
    });
  });

  group('startOfDayMs', () {
    test('同一天的不同时刻映射到同一个零点', () {
      final int a = startOfDayMs(DateTime(2026, 5, 20, 0, 0, 1));
      final int b = startOfDayMs(DateTime(2026, 5, 20, 23, 59, 59));
      expect(a, b);
    });
  });
}
