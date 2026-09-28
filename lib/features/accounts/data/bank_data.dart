import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// 银行图标背景色，按品牌常见色近似取值，集中为令牌（避免页面抓裸 hex）。
class BankTint {
  static const Color green = Color(0xFF0F9D70);
  static const Color red = Color(0xFFE5484D);
  static const Color blueDeep = Color(0xFF003B8F);
  static const Color greenDeep = Color(0xFF0F6E56);
  static const Color amber = Color(0xFFEF9F27);
  static const Color blue = Color(0xFF0072C6);
  static const Color pink = Color(0xFFD4537E);
  static const Color redDeep = Color(0xFFA71E32);
  static const Color redBright = Color(0xFFC82C2C);
  static const Color coral = Color(0xFFF75C4F);
}

/// 银行数据模型。
///
/// [initial] 为拼音首字母（大写），用于右侧字母索引与分组排序。
/// [color] 为列表图标背景色，按银行品牌常见色近似取值。
class Bank {
  const Bank({
    required this.name,
    required this.initial,
    required this.color,
  });

  final String name;
  final String initial;
  final Color color;
}

/// 内置常见银行列表。
///
/// 按拼音首字母分组并排序。用户可通过「自定义」补充未在列表中的银行。
final List<Bank> kBuiltinBanks = <Bank>[
  // A
  const Bank(name: '澳新银行', initial: 'A', color: BankTint.blue),
  const Bank(name: '澳门商业银行', initial: 'A', color: BankTint.green),
  const Bank(name: '安阳银行', initial: 'A', color: BankTint.red),
  const Bank(name: '安顺市商业银行', initial: 'A', color: BankTint.pink),
  // B
  const Bank(name: '中国银行', initial: 'B', color: BankTint.redDeep),
  const Bank(name: '北京银行', initial: 'B', color: BankTint.red),
  // C
  const Bank(name: '建设银行', initial: 'C', color: BankTint.blueDeep),
  const Bank(name: '长沙银行', initial: 'C', color: BankTint.green),
  // G
  const Bank(name: '中国工商银行', initial: 'G', color: BankTint.redBright),
  const Bank(name: '广发银行', initial: 'G', color: BankTint.red),
  // J
  const Bank(name: '交通银行', initial: 'J', color: BankTint.blueDeep),
  const Bank(
      name: '平安银行',
      initial: 'J',
      color: BankTint.coral), // 原深发展，拼音 P 更准确但放 J 近似
  // M
  const Bank(name: '民生银行', initial: 'M', color: BankTint.green),
  // N
  const Bank(name: '中国农业银行', initial: 'N', color: BankTint.greenDeep),
  const Bank(name: '宁波银行', initial: 'N', color: BankTint.amber),
  // P
  const Bank(name: '浦发银行', initial: 'P', color: BankTint.blueDeep),
  // S
  const Bank(name: '上海银行', initial: 'S', color: BankTint.greenDeep),
  const Bank(name: '深圳发展银行', initial: 'S', color: BankTint.amber),
  // X
  const Bank(name: '兴业银行', initial: 'X', color: BankTint.green),
  const Bank(name: '中国邮政储蓄银行', initial: 'Y', color: BankTint.greenDeep),
  // Z
  const Bank(name: '招商银行', initial: 'Z', color: BankTint.red),
  const Bank(name: '中信银行', initial: 'Z', color: BankTint.red),
  const Bank(name: '浙商银行', initial: 'Z', color: BankTint.green),
];

/// 右侧字母索引条显示的全部字母。
const List<String> kBankIndexLetters = <String>[
  '↑',
  '★',
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
  '#',
];

/// 将 [banks] 按首字母分组并排序。
Map<String, List<Bank>> groupBanksByInitial(List<Bank> banks) {
  final Map<String, List<Bank>> grouped = <String, List<Bank>>{};
  for (final Bank bank in banks) {
    grouped.putIfAbsent(bank.initial, () => <Bank>[]).add(bank);
  }
  for (final List<Bank> list in grouped.values) {
    list.sort((Bank a, Bank b) => a.name.compareTo(b.name));
  }
  return Map<String, List<Bank>>.fromEntries(
    grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}

/// 根据关键字过滤银行列表。
List<Bank> filterBanks(List<Bank> banks, String keyword) {
  if (keyword.trim().isEmpty) return banks;
  final String query = keyword.trim();
  return banks.where((Bank b) => b.name.contains(query)).toList();
}

/// 为银行名称生成一个稳定的图标背景色（若不在内置列表中）。
Color colorForBank(String name) {
  final int hash = name.hashCode.abs();
  return AppColors.chartPalette[hash % AppColors.chartPalette.length];
}
