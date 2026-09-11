import 'package:flutter_test/flutter_test.dart';

import 'package:pocket_ledger/shared/models/money.dart';

void main() {
  group('以「分」存储', () {
    test('fromDecimal 转分并四舍五入', () {
      expect(Money.fromDecimal(1).minor, 100);
      expect(Money.fromDecimal(0.01).minor, 1);
      // 0.1 元在二进制浮点里是 0.1000000000000000055，
      // 这里必须落到 10 分而不是 9 分。
      expect(Money.fromDecimal(0.1).minor, 10);
      expect(Money.fromDecimal(1.005).minor, 101);
    });

    test('fromMinor 原样保留', () {
      expect(Money.fromMinor(12345).minor, 12345);
    });

    // 这是整套金额设计的根本目的：0.1 + 0.2 === 0.3
    test('加法不产生浮点误差', () {
      final Money sum = Money.fromDecimal(0.1) + Money.fromDecimal(0.2);
      expect(sum.minor, 30);
      expect(sum, Money.fromDecimal(0.3));
    });

    test('tryParse 容错', () {
      expect(Money.tryParse('12.34').minor, 1234);
      expect(Money.tryParse(null).minor, 0);
      expect(Money.tryParse('abc').minor, 0);
      expect(Money.tryParse('  8.5  ').minor, 850);
    });
  });

  group('金额解析的浮点陷阱（回归）', () {
    // 这些值在二进制浮点里都「差一点点不到半数」，天真的
    // `(value * 100).round()` 会少 1 分。曾经因此挂掉过测试。
    // 用 record 列表而不是 Map：Dart 的 const Map 不允许 double 作 key。
    const List<(double, int)> traps = <(double, int)>[
      (1.005, 101),
      (2.675, 268),
      (8.115, 812),
      (0.145, 15),
      (18.475, 1848),
    ];

    for (final (double input, int expected) in traps) {
      test('fromDecimal($input) 应得 $expected 分', () {
        expect(Money.fromDecimal(input).minor, expected);
      });
    }

    test('负数同样按绝对值四舍五入', () {
      expect(Money.fromDecimal(-1.005).minor, -101);
      expect(Money.fromDecimal(-0.004).minor, 0);
    });

    test('整数走 int 分支，不做浮点乘法', () {
      expect(Money.fromDecimal(0).minor, 0);
      expect(Money.fromDecimal(3).minor, 300);
      expect(Money.fromDecimal(-3).minor, -300);
    });
  });

  group('tryParse 输入清洗与边界（回归）', () {
    test('千分位逗号被忽略', () {
      expect(Money.tryParse('1,234.56').minor, 123456);
      expect(Money.tryParse('1，234.56').minor, 123456);
    });

    test('货币符号前缀被忽略', () {
      expect(Money.tryParse('¥12.30').minor, 1230);
      expect(Money.tryParse(r'$12.30').minor, 1230);
      expect(Money.tryParse('¥ 12.30').minor, 1230);
    });

    test('带符号的输入', () {
      expect(Money.tryParse('-12.30').minor, -1230);
      expect(Money.tryParse('+12.30').minor, 1230);
    });

    test('末尾小数点与省略整数位都能解析', () {
      expect(Money.tryParse('12.').minor, 1200);
      expect(Money.tryParse('.5').minor, 50);
    });

    test('多于两位小数按「厘」四舍五入，之后截断', () {
      expect(Money.tryParse('1.0049').minor, 100);
      expect(Money.tryParse('1.0051').minor, 101);
      expect(Money.tryParse('1.99999').minor, 200);
    });

    test('非法输入返回零值而不是抛异常', () {
      expect(Money.tryParse('').minor, 0);
      expect(Money.tryParse('   ').minor, 0);
      expect(Money.tryParse('1.2.3').minor, 0);
      expect(Money.tryParse('1e').minor, 0);
      expect(Money.tryParse('--1').minor, 0);
      expect(Money.tryParse('12元').minor, 0);
    });

    test('指数记法仍可解析（兜底分支）', () {
      expect(Money.tryParse('1e2').minor, 10000);
      expect(Money.tryParse('1.5e2').minor, 15000);
    });
  });

  group('符号与比较', () {
    test('isZero / isNegative / isPositive', () {
      expect(Money.zero.isZero, isTrue);
      expect(Money.fromMinor(-1).isNegative, isTrue);
      expect(Money.fromMinor(1).isPositive, isTrue);
    });

    test('abs / negate', () {
      expect(Money.fromMinor(-500).abs().minor, 500);
      expect(Money.fromMinor(500).negate().minor, -500);
      expect(Money.fromMinor(500).negate().negate().minor, 500);
    });

    test('compareTo 与排序', () {
      final List<Money> list = <Money>[
        Money.fromMinor(300),
        Money.fromMinor(100),
        Money.fromMinor(200),
      ]..sort();
      expect(list.map((Money m) => m.minor).toList(), <int>[100, 200, 300]);
    });

    test('等值比较（Equatable）', () {
      expect(Money.fromMinor(100), Money.fromMinor(100));
      expect(Money.fromMinor(100) == Money.fromMinor(101), isFalse);
    });
  });

  group('运算', () {
    test('减法', () {
      expect(
        (Money.fromMinor(1000) - Money.fromMinor(250)).minor,
        750,
      );
    });

    test('按比例拆分（AA 分账）', () {
      // 100 元三人分：33.33 × 2 + 33.34 = 100.00，不丢分
      final Money total = Money.fromMinor(10000);
      final Money a = total.ratio(1 / 3);
      expect(a.minor * 2 + (total - a * 2).minor, 10000);
    });

    test('乘以系数', () {
      expect((Money.fromMinor(100) * 3).minor, 300);
    });
  });

  group('格式化', () {
    test('含货币符号与千分位', () {
      final String text = Money.fromMinor(123456).format();
      expect(text, contains('1,234.56'));
      expect(text, contains('¥'));
    });

    test('formatSigned 正数带 +', () {
      expect(Money.fromMinor(100).formatSigned(), startsWith('+'));
      expect(Money.fromMinor(-100).formatSigned(), isNot(startsWith('+')));
    });

    test('decimal 仅用于展示', () {
      expect(Money.fromMinor(12345).decimal, 123.45);
    });
  });
}
