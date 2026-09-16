import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/features/installment/domain/repeat_rule.dart';

void main() {
  group('InstallmentRepeatRule', () {
    test('displayLabel：每月单选日期', () {
      const InstallmentRepeatRule rule = InstallmentRepeatRule(
        unit: RepeatUnit.month,
        interval: 1,
        monthDays: <int>[16],
      );
      expect(rule.displayLabel(), '每月 16 日');
    });

    test('displayLabel：每月多选日期', () {
      const InstallmentRepeatRule rule = InstallmentRepeatRule(
        unit: RepeatUnit.month,
        interval: 1,
        monthDays: <int>[5, 15, -1],
      );
      expect(rule.displayLabel(), '每月 5日、15日、月末');
    });

    test('displayLabel：每月月末', () {
      const InstallmentRepeatRule rule = InstallmentRepeatRule(
        unit: RepeatUnit.month,
        interval: 1,
        monthDays: <int>[-1],
      );
      expect(rule.displayLabel(), '每月 月末');
    });

    test('JSON 序列化：monthDays 数组', () {
      const InstallmentRepeatRule rule = InstallmentRepeatRule(
        unit: RepeatUnit.month,
        interval: 1,
        monthDays: <int>[5, 15, -1],
      );
      final String json = rule.toJsonString();
      expect(json.contains('"monthDays":[5,15,-1]'), isTrue);
      expect(json.contains('"monthDay"'), isFalse);
    });

    test('JSON 兼容：旧版 monthDay 单值', () {
      const String raw = '{"unit":"month","interval":1,"monthDay":31}';
      final InstallmentRepeatRule? rule = InstallmentRepeatRule.fromJsonString(raw);
      expect(rule, isNotNull);
      expect(rule!.unit, RepeatUnit.month);
      expect(rule.monthDay, 31);
      expect(rule.displayLabel(), '每月 31 日');
    });

    test('JSON 反序列化：monthDays 数组', () {
      const String raw = '{"unit":"month","interval":2,"monthDays":[5,15]}';
      final InstallmentRepeatRule? rule = InstallmentRepeatRule.fromJsonString(raw);
      expect(rule, isNotNull);
      expect(rule!.unit, RepeatUnit.month);
      expect(rule.interval, 2);
      expect(rule.monthDays, <int>[5, 15]);
      expect(rule.displayLabel(), '每 2 月 5日、15日');
    });
  });
}
