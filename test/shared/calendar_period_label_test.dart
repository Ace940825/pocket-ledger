import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/core/utils/date_utils.dart';
import 'package:pocket_ledger/features/ledger/providers/ledger_providers.dart';
import 'package:pocket_ledger/shared/widgets/calendar_sheet.dart';

/// 自定义区间标签的跨年口径（2026-10-22 真机反馈「自定义跨年识别异常」）：
///
/// 用户选自定义区间 2020年1月1日–2021年10月1日，页面曾显示为
/// 「2020年1月1日-10月1日」——跨年分支漏写结束年份，整段被误读成
/// 「所选年份（2020）的当年月份」。现要求跨年必显两端年份。
/// [LedgerPeriod] 与 [CalendarPeriod] 两处标签同口径（页面头 + 日历组件
/// 各自的 label 出口），必须同时锁定，防止只修一处。
void main() {
  group('LedgerPeriod.label 自定义区间', () {
    test('同年区间不显年份（旧口径不变）', () {
      final LedgerPeriod p =
          LedgerPeriod.customOf(DateTime(2020, 1, 1), DateTime(2020, 10, 1));
      expect(p.label, '1月1日-10月1日');
    });

    test('跨年区间显结束年份（真机反馈场景）', () {
      final LedgerPeriod p =
          LedgerPeriod.customOf(DateTime(2020, 1, 1), DateTime(2021, 10, 1));
      expect(p.label, '2020年1月1日-2021年10月1日');
    });

    test('跨月但同年边界：12 月→次年 1 月也算跨年', () {
      final LedgerPeriod p =
          LedgerPeriod.customOf(DateTime(2020, 12, 31), DateTime(2021, 1, 1));
      expect(p.label, '2020年12月31日-2021年1月1日');
    });

    test('月/年模式标签不受影响', () {
      expect(LedgerPeriod.monthOf(DateTime(2020, 1)).label, '2020年1月');
      expect(LedgerPeriod.yearOf(2016).label, '2016年');
    });
  });

  group('CalendarPeriod.label 自定义区间', () {
    test('同年区间不显年份', () {
      final CalendarPeriod p = CalendarPeriod(
        CalendarPeriodMode.custom,
        DateTime(2020, 1, 1),
        DateTime(2020, 10, 2), // end 为开区间（不含）
      );
      expect(p.label, '1月1日-10月1日');
    });

    test('跨年区间显结束年份（与 LedgerPeriod 同口径）', () {
      final CalendarPeriod p = CalendarPeriod(
        CalendarPeriodMode.custom,
        DateTime(2020, 1, 1),
        DateTime(2021, 10, 2),
      );
      expect(p.label, '2020年1月1日-2021年10月1日');
    });
  });

  // 2026-10-22 第二次真机反馈（高级筛选页「基本信息 › 时间」仍显示
  // 「2022年2月1日-2月1日」）：同一现象散落在 5 处手拼实现里，漏改一处就复发。
  // 此后所有区间文案统一走 [formatDayRange]，本组锁死它的全部口径。
  group('formatDayRange 单一出口', () {
    test('同年 → 只显月日', () {
      expect(
        formatDayRange(DateTime(2022, 1, 1), DateTime(2022, 10, 1)),
        '1月1日-10月1日',
      );
    });

    // 2026-10-22 第三次：单日条件（筛选「时间」选某一天）现在会把页头周期
    // 收敛成一天，标签必须是一个日期——既不能出现「2月1日-2月1日」，
    // 也不能像跨年事故那样丢年份。
    test('单日区间 → 收敛成一个带年份的日期', () {
      expect(
        formatDayRange(DateTime(2022, 2, 1), DateTime(2022, 2, 1)),
        '2022年2月1日',
      );
    });

    test('跨年 → 两端都带年份（含结束年份）', () {
      expect(
        formatDayRange(DateTime(2021, 2, 1), DateTime(2022, 2, 1)),
        '2021年2月1日-2022年2月1日',
      );
      expect(
        formatDayRange(DateTime(2020, 1, 1), DateTime(2021, 10, 1)),
        '2020年1月1日-2021年10月1日',
      );
    });

    test('12 月 31 日 → 次年 1 月 1 日 也是跨年', () {
      expect(
        formatDayRange(DateTime(2020, 12, 31), DateTime(2021, 1, 1)),
        '2020年12月31日-2021年1月1日',
      );
    });

    test('keepYearOnSameYear：同年保留起始年（报表周视图口径）', () {
      expect(
        formatDayRange(
          DateTime(2022, 2, 1),
          DateTime(2022, 2, 20),
          separator: '–',
          keepYearOnSameYear: true,
        ),
        '2022年2月1日–2月20日',
      );
    });

    test('自定义分隔符在跨年分支同样生效', () {
      expect(
        formatDayRange(
          DateTime(2021, 12, 27),
          DateTime(2022, 1, 2),
          separator: '–',
          keepYearOnSameYear: true,
        ),
        '2021年12月27日–2022年1月2日',
      );
    });
  });
}
