// 一次性脚本：把示例 / 模板渲染为 deliverables/ 下 v2 文件。运行后即删。
import 'dart:io';

import 'package:pocket_ledger/features/ledger/data/bill_io.dart';
import 'package:pocket_ledger/features/ledger/data/bill_template.dart';

void main() {
  const String dir = 'deliverables';
  Directory(dir).createSync(recursive: true);

  File('$dir/bill_import_template.v2.csv').writeAsStringSync(buildTemplateCsv());
  File('$dir/bill_import_template.v2.json').writeAsStringSync(buildTemplateJson());

  final List<BillRow> rows = sampleBillRows();
  // sampleBillRows 已用标准 CSV 往返（parseInput）解析，列数由 [_verifySampleColumns]
  // 守门；此处仅再确认金额合法。
  for (int i = 0; i < rows.length; i++) {
    if (rows[i].amountMinor <= 0) {
      throw StateError('示例第 ${i + 1} 行金额非法');
    }
  }
  File('$dir/bill_import_sample.v2.csv').writeAsStringSync(buildCsv(rows));
  File('$dir/bill_import_sample.v2.json').writeAsStringSync(buildJson(rows));

  print('OK: 生成 ${rows.length} 行示例 + 模板 (v2)');
}
