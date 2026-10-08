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
  const Bank(name: '渤海银行', initial: 'B', color: BankTint.blueDeep),
  const Bank(name: '保定银行', initial: 'B', color: BankTint.green),
  const Bank(name: '北海银行', initial: 'B', color: BankTint.amber),
  const Bank(name: '北京农商银行', initial: 'B', color: BankTint.greenDeep),
  // C
  const Bank(name: '建设银行', initial: 'C', color: BankTint.blueDeep),
  const Bank(name: '长沙银行', initial: 'C', color: BankTint.green),
  const Bank(name: '重庆银行', initial: 'C', color: BankTint.red),
  const Bank(name: '成都银行', initial: 'C', color: BankTint.blue),
  const Bank(name: '沧州银行', initial: 'C', color: BankTint.pink),
  const Bank(name: '重庆农商银行', initial: 'C', color: BankTint.greenDeep),
  const Bank(name: '常熟农商银行', initial: 'C', color: BankTint.coral),
  // D
  const Bank(name: '东莞银行', initial: 'D', color: BankTint.green),
  const Bank(name: '大连银行', initial: 'D', color: BankTint.blueDeep),
  const Bank(name: '德州银行', initial: 'D', color: BankTint.amber),
  const Bank(name: '东营银行', initial: 'D', color: BankTint.red),
  // F
  const Bank(name: '抚顺银行', initial: 'F', color: BankTint.green),
  const Bank(name: '阜新银行', initial: 'F', color: BankTint.blue),
  // G
  const Bank(name: '中国工商银行', initial: 'G', color: BankTint.redBright),
  const Bank(name: '广发银行', initial: 'G', color: BankTint.red),
  const Bank(name: '光大银行', initial: 'G', color: BankTint.greenDeep),
  const Bank(name: '广州银行', initial: 'G', color: BankTint.blue),
  const Bank(name: '贵阳银行', initial: 'G', color: BankTint.redDeep),
  const Bank(name: '赣州银行', initial: 'G', color: BankTint.pink),
  const Bank(name: '广州农商银行', initial: 'G', color: BankTint.greenDeep),
  // H
  const Bank(name: '华夏银行', initial: 'H', color: BankTint.red),
  const Bank(name: '杭州银行', initial: 'H', color: BankTint.green),
  const Bank(name: '哈尔滨银行', initial: 'H', color: BankTint.blueDeep),
  const Bank(name: '恒丰银行', initial: 'H', color: BankTint.coral),
  const Bank(name: '徽商银行', initial: 'H', color: BankTint.redBright),
  const Bank(name: '河北银行', initial: 'H', color: BankTint.blue),
  const Bank(name: '湖北银行', initial: 'H', color: BankTint.greenDeep),
  const Bank(name: '湖南银行', initial: 'H', color: BankTint.amber),
  // J
  const Bank(name: '交通银行', initial: 'J', color: BankTint.blueDeep),
  const Bank(name: '江苏银行', initial: 'J', color: BankTint.red),
  const Bank(name: '嘉兴银行', initial: 'J', color: BankTint.green),
  const Bank(name: '金华银行', initial: 'J', color: BankTint.pink),
  // K
  const Bank(name: '昆仑银行', initial: 'K', color: BankTint.redDeep),
  const Bank(name: '昆山农商银行', initial: 'K', color: BankTint.green),
  // L
  const Bank(name: '兰州银行', initial: 'L', color: BankTint.blue),
  const Bank(name: '廊坊银行', initial: 'L', color: BankTint.amber),
  const Bank(name: '乐山银行', initial: 'L', color: BankTint.greenDeep),
  // M
  const Bank(name: '民生银行', initial: 'M', color: BankTint.green),
  const Bank(name: '蒙古银行', initial: 'M', color: BankTint.red),
  // N
  const Bank(name: '中国农业银行', initial: 'N', color: BankTint.greenDeep),
  const Bank(name: '宁波银行', initial: 'N', color: BankTint.amber),
  const Bank(name: '南京银行', initial: 'N', color: BankTint.red),
  const Bank(name: '南昌银行', initial: 'N', color: BankTint.blueDeep),
  const Bank(name: '内蒙古银行', initial: 'N', color: BankTint.pink),
  // P
  const Bank(name: '浦发银行', initial: 'P', color: BankTint.blueDeep),
  const Bank(name: '平安银行', initial: 'P', color: BankTint.coral),
  // Q
  const Bank(name: '青岛银行', initial: 'Q', color: BankTint.green),
  const Bank(name: '泉州银行', initial: 'Q', color: BankTint.red),
  const Bank(name: '齐鲁银行', initial: 'Q', color: BankTint.blue),
  // R
  const Bank(name: '日照银行', initial: 'R', color: BankTint.amber),
  const Bank(name: '瑞金银行', initial: 'R', color: BankTint.greenDeep),
  // S
  const Bank(name: '上海银行', initial: 'S', color: BankTint.greenDeep),
  const Bank(name: '深圳发展银行', initial: 'S', color: BankTint.amber),
  const Bank(name: '苏州银行', initial: 'S', color: BankTint.red),
  const Bank(name: '绍兴银行', initial: 'S', color: BankTint.blue),
  const Bank(name: '盛京银行', initial: 'S', color: BankTint.pink),
  const Bank(name: '上饶银行', initial: 'S', color: BankTint.green),
  const Bank(name: '上海农商银行', initial: 'S', color: BankTint.greenDeep),
  const Bank(name: '顺德农商银行', initial: 'S', color: BankTint.coral),
  // T
  const Bank(name: '天津银行', initial: 'T', color: BankTint.redDeep),
  const Bank(name: '唐山银行', initial: 'T', color: BankTint.blue),
  const Bank(name: '泰安银行', initial: 'T', color: BankTint.green),
  // W
  const Bank(name: '无锡农商银行', initial: 'W', color: BankTint.greenDeep),
  const Bank(name: '威海银行', initial: 'W', color: BankTint.blue),
  // X
  const Bank(name: '兴业银行', initial: 'X', color: BankTint.green),
  const Bank(name: '厦门银行', initial: 'X', color: BankTint.red),
  const Bank(name: '邢台银行', initial: 'X', color: BankTint.amber),
  const Bank(name: '新乡银行', initial: 'X', color: BankTint.pink),
  // Y
  const Bank(name: '中国邮政储蓄银行', initial: 'Y', color: BankTint.greenDeep),
  const Bank(name: '烟台银行', initial: 'Y', color: BankTint.blueDeep),
  const Bank(name: '营口银行', initial: 'Y', color: BankTint.coral),
  // Z
  const Bank(name: '招商银行', initial: 'Z', color: BankTint.red),
  const Bank(name: '中信银行', initial: 'Z', color: BankTint.red),
  const Bank(name: '浙商银行', initial: 'Z', color: BankTint.green),
  const Bank(name: '郑州银行', initial: 'Z', color: BankTint.blue),
  const Bank(name: '张家口银行', initial: 'Z', color: BankTint.amber),
  const Bank(name: '珠海华润银行', initial: 'Z', color: BankTint.greenDeep),
  const Bank(name: '中原银行', initial: 'Z', color: BankTint.pink),
  const Bank(name: '自贡银行', initial: 'Z', color: BankTint.coral),
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
  return AppPalette.chartPalette[hash % AppPalette.chartPalette.length];
}
