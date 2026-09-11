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
  ///
  /// 注意这里**不用** `(value * 100).round()`：二进制浮点下 `1.005 * 100`
  /// 等于 `100.49999999999999`，四舍五入会得到 100 分（少 1 分）。
  /// 改为先取 `num.toString()`（Dart 会给出最短往返表示，即 `"1.005"`），
  /// 再按十进制字符串做整数运算。
  factory Money.fromDecimal(num value, {String currency = 'CNY'}) {
    if (value is int) return Money._(value * 100, currency);
    final int? minor = _minorFromDecimalString(value.toString());
    // 兜底：指数记法（如 1e-7）无法按十进制切分时退回浮点乘法。
    return Money._(minor ?? (value * 100).round(), currency);
  }

  /// 按字符串解析，解析失败返回零值。用于用户输入与 CSV 导入。
  ///
  /// 容忍首尾空白、千分位逗号（`,` / `，`）与货币符号前缀（`¥` / `$`）。
  /// 内部同样走「字符串 → 整数分」，避免 `double.tryParse('1.005')`
  /// 这类精度陷阱。
  factory Money.tryParse(String? text, {String currency = 'CNY'}) {
    if (text == null) return Money.zeroOf(currency);
    final String cleaned = text
        .trim()
        .replaceAll(',', '')
        .replaceAll('，', '')
        .replaceAll('¥', '')
        .replaceAll(r'$', '');
    final int? minor = _minorFromDecimalString(cleaned);
    if (minor != null) return Money._(minor, currency);
    // 兜底：指数记法（如 1e3）仍尝试按 double 解析。
    final double? parsed = double.tryParse(cleaned);
    if (parsed == null) return Money.zeroOf(currency);
    return Money.fromDecimal(parsed, currency: currency);
  }

  /// 十进制的「元」字符串 → 整数「分」。无法识别时返回 null。
  ///
  /// 接受 `[-+]?digits[.digits]`；小数部分只取前三位，第三位用于四舍五入
  /// （即「半个分」向上进位），多于三位直接截断丢弃。全程整数运算。
  static int? _minorFromDecimalString(String input) {
    String s = input.trim();
    if (s.isEmpty) return null;

    bool negative = false;
    if (s.startsWith('-')) {
      negative = true;
      s = s.substring(1);
    } else if (s.startsWith('+')) {
      s = s.substring(1);
    }

    final List<String> parts = s.split('.');
    if (parts.length > 2) return null; // 多个小数点视为非法
    final String intPart = parts[0].isEmpty ? '0' : parts[0];
    final String fracPart = parts.length == 2 ? parts[1] : '';
    if (!_digitsOnly.hasMatch(intPart)) return null;
    if (fracPart.isNotEmpty && !_digitsOnly.hasMatch(fracPart)) return null;

    // 不足三位补 0，多余截断；第 3 位是「厘」，>= 5 则进 1 分。
    final String frac = '${fracPart}000'.substring(0, 3);
    final int? whole = int.tryParse(intPart);
    if (whole == null) return null; // 超出 int 范围

    int minor = whole * 100 + int.parse(frac.substring(0, 2));
    if (int.parse(frac.substring(2)) >= 5) minor += 1;
    return negative ? -minor : minor;
  }

  static final RegExp _digitsOnly = RegExp(r'^\d+$');

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

  Money operator +(Money other) =>
      _assertSameCurrency(other, minor + other.minor);

  Money operator -(Money other) =>
      _assertSameCurrency(other, minor - other.minor);

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
