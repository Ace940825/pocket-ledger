// 一次性脚本：把示例 / 模板渲染为 deliverables/ 下 v3 文件（含账户段）。
// 运行：dart run tool/gen_deliverables.dart
import 'dart:io';

import 'package:pocket_ledger/features/ledger/data/account_io.dart';
import 'package:pocket_ledger/features/ledger/data/bill_io.dart';
import 'package:pocket_ledger/features/ledger/data/bill_template.dart';

void main() {
  const String dir = 'deliverables';
  Directory(dir).createSync(recursive: true);

  File('$dir/bill_import_template.v3.csv').writeAsStringSync(buildTemplateCsv());
  File('$dir/bill_import_template.v3.json').writeAsStringSync(buildTemplateJson());

  final List<BillRow> rows = sampleBillRows();
  final List<AccountRow> accounts = sampleAccountRows();
  // sampleBillRows 已用标准 CSV 往返（parseInput）解析，列数由 [_verifySampleColumns]
  // 守门；此处仅再确认金额合法。
  for (int i = 0; i < rows.length; i++) {
    if (rows[i].amountMinor <= 0) {
      throw StateError('示例第 ${i + 1} 行金额非法');
    }
  }
  if (accounts.isEmpty) throw StateError('账户段示例为空');
  File('$dir/bill_import_sample.v3.csv')
      .writeAsStringSync(buildCsv(rows, accounts: accounts));
  File('$dir/bill_import_sample.v3.json')
      .writeAsStringSync(buildJson(rows, accounts: accounts));

  print('OK: 生成 ${rows.length} 行账单 + ${accounts.length} 个账户 示例/模板 (v3)');
}
