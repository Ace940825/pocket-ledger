import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

/// 金额值对象。
///
/// **核心约定：金额一律以「分」为整数存储**（[minor]），绝不使用 double。
/// 这从根本上避免 `0.1 + 0.2 != 0.3` 之类的浮点误差导致账目对不上。
/// 仅在展示层才转换为小数。
class Money extends Equatable implements Comparable<Money> {
  const Money._(this.minor, this.currency);

  /// 以「分」构造。100 表示 1.00 元。
  factory Money.fromMinor(int minor, {String currency = 'CNY'}) =>
      Money._(minor, currency);

  /// 以「元」构造。内部四舍五入到分。
  factory Money.fromDecimal(num value, {String currency = 'CNY'}) =>
      Money._((value * 100).round(), currency);

  /// 按字符串解析，解析失败返回零值。用于用户输入与 CSV 导入。
  factory Money.tryParse(String? text, {String currency = 'CNY'}) {
    if (text == null) return Money.zeroOf(currency);
    final double? parsed = double.tryParse(text.trim());
    if (parsed == null) return Money.zeroOf(currency);
    return Money.fromDecimal(parsed, currency: currency);
  }

  /// 零值
  static const Money zero = Money._(0, 'CNY');

  static Money zeroOf(String currency) => Money._(0, currency);

  /// 以「分」为单位的整数值
  final int minor;

  /// ISO 4217 币种代码，默认 CNY
  final String currency;

  /// 以「元」为单位的数值，仅用于展示与图表
  double get decimal => minor / 100;

  bool get isZero => minor == 0;
  bool get isNegative => minor < 0;
  bool get isPositive => minor > 0;

  Money abs() => Money._(minor.abs(), currency);

  /// 取反。用于把支出统一表示为负数参与求和。
  Money negate() => Money._(-minor, currency);

  Money operator +(Money other) => _assertSameCurrency(other, minor + other.minor);

  Money operator -(Money other) => _assertSameCurrency(other, minor - other.minor);

  Money operator *(num factor) => Money._((minor * factor).round(), currency);

  /// 按 [ratio] 比例取一部分（如 AA 分账）
  Money ratio(num ratio) => Money._((minor * ratio).round(), currency);

  Money _assertSameCurrency(Money other, int result) {
    assert(
      currency == other.currency,
      '币种不匹配：$currency 与 ${other.currency} 不能直接运算',
    );
    return Money._(result, currency);
  }

  @override
  int compareTo(Money other) => minor.compareTo(other.minor);

  /// 格式化显示，如 `¥1,234.56`
  String format({bool showSymbol = true, int decimalDigits = 2}) {
    final NumberFormat formatter = NumberFormat.currency(
      locale: 'zh_CN',
      symbol: showSymbol ? '¥' : '',
      decimalDigits: decimalDigits,
    );
    return formatter.format(minor / 100);
  }

  /// 带正负号的格式化，用于收支明细与报表
  String formatSigned({int decimalDigits = 2}) {
    final String body = format(decimalDigits: decimalDigits);
    if (minor > 0) return '+$body';
    return body;
  }

  @override
  String toString() => format();

  @override
  List<Object?> get props => <Object?>[minor, currency];
}
