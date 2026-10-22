import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/features/ledger/providers/ledger_providers.dart';

/// 「筛选的时间条件」与「页头周期」是同一件事的两种呈现（2026-10-22 真机
/// 第三次反馈：筛选页日期改对了，查询后账单页头仍停在 2026年10月）。
///
/// 本测试锁住两个方向的纯函数口径，页面层（账单页 / 清理页 / 转换页）
/// 只是把它们接到 provider / setState 上：
/// - `ledgerPeriodOfFilter`：查询后页头周期该切成什么；
/// - `ledgerFilterWithPeriod`：页头切了周期后，筛选里的时间条件该怎么跟着换。
void main() {
  group('ledgerPeriodOfFilter：查询 → 页头周期', () {
    test('跨年区间：切成该区间，标签与筛选页一致（用户截图场景）', () {
      // 用户真机：2025-02-05 ~ 2026-03-06（rangeEnd 为排他边界 → 03-07）。
      final LedgerAdvancedFilter f = LedgerAdvancedFilter(
        rangeStart: DateTime(2025, 2, 5),
        rangeEnd: DateTime(2026, 3, 7),
      );

      final LedgerPeriod? p = ledgerPeriodOfFilter(f);

      expect(p, isNotNull);
      expect(p!.start, DateTime(2025, 2, 5));
      expect(p.end, DateTime(2026, 3, 7));
      expect(p.mode, LedgerPeriodMode.custom);
      expect(
        p.label,
        '2025年2月5日-2026年3月6日',
        reason: '页头必须与筛选页「时间」行同一文案（跨年两端都带年份）',
      );
    });

    test('月粒度：页头显「2025年2月」，不退回日区间文案', () {
      final LedgerPeriod? p = ledgerPeriodOfFilter(
        LedgerAdvancedFilter(
          rangeStart: DateTime(2025, 2),
          rangeEnd: DateTime(2025, 3),
          rangeMode: LedgerPeriodMode.month,
        ),
      );

      expect(p!.mode, LedgerPeriodMode.month);
      expect(p.label, '2025年2月');
      expect(p.dayCount, 28);
    });

    test('年粒度：页头显「2025年」', () {
      final LedgerPeriod? p = ledgerPeriodOfFilter(
        LedgerAdvancedFilter(
          rangeStart: DateTime(2025),
          rangeEnd: DateTime(2026),
          rangeMode: LedgerPeriodMode.year,
        ),
      );

      expect(p!.mode, LedgerPeriodMode.year);
      expect(p.label, '2025年');
    });

    test('单日条件：周期收敛成一天，标签是带年份的单个日期', () {
      final LedgerPeriod? p = ledgerPeriodOfFilter(
        LedgerAdvancedFilter(day: DateTime(2025, 2, 5, 18, 30)),
      );

      expect(p!.mode, LedgerPeriodMode.custom);
      expect(p.start, DateTime(2025, 2, 5), reason: '时刻必须归零到当天 0 点');
      expect(p.end, DateTime(2025, 2, 6));
      expect(p.dayCount, 1);
      expect(
        p.label,
        '2025年2月5日',
        reason: '单日不能显示成「2月5日-2月5日」，也不能丢年份',
      );
    });

    test('没有时间条件 → null（周期保持不动）', () {
      expect(ledgerPeriodOfFilter(null), isNull);
      expect(
        ledgerPeriodOfFilter(const LedgerAdvancedFilter(note: '午饭')),
        isNull,
      );
    });
  });

  group('ledgerFilterWithPeriod：页头切周期 → 筛选时间跟随', () {
    test('时间条件换成新周期，其余条件原样保留', () {
      final LedgerAdvancedFilter f = LedgerAdvancedFilter(
        note: '午饭',
        minMinor: 100,
        tagNames: const <String>{'出差'},
        rangeStart: DateTime(2025, 2, 5),
        rangeEnd: DateTime(2025, 3, 1),
      );

      final LedgerAdvancedFilter? g = ledgerFilterWithPeriod(
        f,
        LedgerPeriod.monthOf(DateTime(2026, 10)),
      );

      expect(g!.rangeStart, DateTime(2026, 10));
      expect(g.rangeEnd, DateTime(2026, 11));
      expect(g.rangeMode, LedgerPeriodMode.month);
      expect(g.note, '午饭');
      expect(g.minMinor, 100);
      expect(g.tagNames, <String>{'出差'});
    });

    test('单日条件换成区间（不再残留 day）', () {
      final LedgerAdvancedFilter g = ledgerFilterWithPeriod(
        LedgerAdvancedFilter(day: DateTime(2025, 2, 5)),
        LedgerPeriod.yearOf(2026),
      )!;

      expect(g.day, isNull);
      expect(g.rangeStart, DateTime(2026));
      expect(g.rangeEnd, DateTime(2027));
      expect(g.rangeMode, LedgerPeriodMode.year);
    });

    test('没有时间条件 → 原样返回同一实例（调用方免写 provider）', () {
      const LedgerAdvancedFilter f = LedgerAdvancedFilter(note: 'x');
      final LedgerAdvancedFilter? g = ledgerFilterWithPeriod(
        f,
        LedgerPeriod.monthOf(DateTime(2026, 10)),
      );

      expect(identical(g, f), isTrue);
      expect(identical(ledgerFilterWithPeriod(null, LedgerPeriod.yearOf(2026)), null),
          isTrue);
    });
  });
}
