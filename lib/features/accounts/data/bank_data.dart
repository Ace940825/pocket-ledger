import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

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
  const Bank(name: '澳新银行', initial: 'A', color: Color(0xFF0072C6)),
  const Bank(name: '澳门商业银行', initial: 'A', color: Color(0xFF0F9D70)),
  const Bank(name: '安阳银行', initial: 'A', color: Color(0xFFE5484D)),
  const Bank(name: '安顺市商业银行', initial: 'A', color: Color(0xFFD4537E)),
  // B
  const Bank(name: '中国银行', initial: 'B', color: Color(0xFFA71E32)),
  const Bank(name: '北京银行', initial: 'B', color: Color(0xFFE5484D)),
  // C
  const Bank(name: '建设银行', initial: 'C', color: Color(0xFF003B8F)),
  const Bank(name: '长沙银行', initial: 'C', color: Color(0xFF0F9D70)),
  // G
  const Bank(name: '中国工商银行', initial: 'G', color: Color(0xFFC82C2C)),
  const Bank(name: '广发银行', initial: 'G', color: Color(0xFFE5484D)),
  // J
  const Bank(name: '交通银行', initial: 'J', color: Color(0xFF003B8F)),
  const Bank(name: '平安银行', initial: 'J', color: Color(0xFFF75C4F)), // 原深发展，拼音 P 更准确但放 J 近似
  // M
  const Bank(name: '民生银行', initial: 'M', color: Color(0xFF0F9D70)),
  // N
  const Bank(name: '中国农业银行', initial: 'N', color: Color(0xFF0F6E56)),
  const Bank(name: '宁波银行', initial: 'N', color: Color(0xFFEF9F27)),
  // P
  const Bank(name: '浦发银行', initial: 'P', color: Color(0xFF003B8F)),
  // S
  const Bank(name: '上海银行', initial: 'S', color: Color(0xFF0F6E56)),
  const Bank(name: '深圳发展银行', initial: 'S', color: Color(0xFFEF9F27)),
  // X
  const Bank(name: '兴业银行', initial: 'X', color: Color(0xFF0F9D70)),
  const Bank(name: '中国邮政储蓄银行', initial: 'Y', color: Color(0xFF0F6E56)),
  // Z
  const Bank(name: '招商银行', initial: 'Z', color: Color(0xFFE5484D)),
  const Bank(name: '中信银行', initial: 'Z', color: Color(0xFFE5484D)),
  const Bank(name: '浙商银行', initial: 'Z', color: Color(0xFF0F9D70)),
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
