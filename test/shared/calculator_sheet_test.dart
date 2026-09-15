import 'package:flutter_test/flutter_test.dart';

import 'package:pocket_ledger/shared/widgets/calculator_sheet.dart';

/// [evaluateExpression] / [aaSplit] 纯函数回归测试。
void main() {
  group('evaluateExpression', () {
    test('基础四则运算', () {
      expect(evaluateExpression('1+2'), 3);
      expect(evaluateExpression('10-4'), 6);
      expect(evaluateExpression('3*4'), 12);
      expect(evaluateExpression('8/2'), 4);
    });

    test('运算符优先级（先乘除后加减）', () {
      expect(evaluateExpression('1+2*3'), 7);
      expect(evaluateExpression('2*3+4'), 10);
      expect(evaluateExpression('10-2*3'), 4);
    });

    test('支持 unicode 乘除号 × ÷', () {
      expect(evaluateExpression('6×7'), 42);
      expect(evaluateExpression('9÷3'), 3);
    });

    test('非法输入返回 null', () {
      expect(evaluateExpression(''), isNull);
      expect(evaluateExpression('   '), isNull);
      expect(evaluateExpression('1+'), isNull, reason: '以运算符结尾');
      expect(evaluateExpression('1+a'), isNull, reason: '含非法字符');
      expect(evaluateExpression('1/0'), isNull, reason: '除零');
      expect(evaluateExpression('2++3'), isNull, reason: '连续运算符');
    });

    test('小数与空格容忍', () {
      expect(evaluateExpression('1.5 + 2.5'), 4);
      expect(evaluateExpression(' 3 * 4 '), 12);
    });
  });

  group('aaSplit', () {
    test('均摊到多人', () {
      expect(aaSplit(100, 3), closeTo(100 / 3, 1e-6));
      expect(aaSplit(200, 4), 50);
    });

    test('人数非正时返回 0（避免除零）', () {
      expect(aaSplit(100, 0), 0);
      expect(aaSplit(100, -2), 0);
    });
  });
}
