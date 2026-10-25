import 'dart:io';

void main(List<String> args) {
  final String path = args.isNotEmpty
      ? args[0]
      : 'deliverables/bill_import_accounts_filled_v3_2026-10-25.csv';
  final f = File(path);
  print('校验文件 = $path');
  final lines = f.readAsLinesSync();
  final accHeader = lines.indexWhere((l) => l.trim() == '# [账户]');
  final billHeader = lines.indexWhere((l) => l.trim() == '# [账单]');
  final header = lines[accHeader + 1];
  print('账户段表头列数 = ${header.split(',').length}');
  print('账户段表头 = $header');

  int n = 0, bad = 0;
  for (int i = accHeader + 2; i < billHeader; i++) {
    final l = lines[i];
    if (l.startsWith('#') || l.trim().isEmpty) continue;
    final cols = l.split(',');
    n++;
    // v3 + 免息期列（2026-10-25）：账户段 16 列
    // （账本,账户名,类型,币种,余额,图标,颜色,信用卡额度,账单日,还款日,免息期,
    //  备注,卡号,状态,计入总资产,排序）。
    if (cols.length != 16) {
      bad++;
      print('  第${n}行列数异常(${cols.length}): $l');
    }
  }
  print('账户数据行数 = $n, 错位行数 = $bad');

  final billHeaderLine = lines[billHeader + 1];
  print('账单段表头列数 = ${billHeaderLine.split(',').length}');

  // 类型分布统计
  final types = <String, int>{};
  for (int i = accHeader + 2; i < billHeader; i++) {
    final l = lines[i];
    if (l.startsWith('#') || l.trim().isEmpty) continue;
    final cols = l.split(',');
    final t = cols[2];
    types[t] = (types[t] ?? 0) + 1;
  }
  print('类型分布 = $types');
}
