import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/ledger/data/bill_io.dart';
import 'package:pocket_ledger/features/ledger/data/bill_template.dart';

/// 模板系统（2026-10-18）单测：模板结构 / 模板文件兼容 / 校验与归集。
void main() {
  group('kBillTemplateFields', () {
    test('覆盖 BillRow 全部字段且必填项正确', () {
      final List<String> headers =
          kBillTemplateFields.map((f) => f.header).toList();
      expect(headers, <String>[
        '日期',
        '类型',
        '金额',
        '账户',
        '转入账户',
        '分类',
        '备注',
      ]);
      // 必填：日期/类型/金额/账户；选填：转入账户/分类/备注。
      final Set<String> required = <String>{
        for (final f in kBillTemplateFields)
          if (f.required) f.header,
      };
      expect(required, <String>{'日期', '类型', '金额', '账户'});
    });

    test('必填列带 * 展示后缀', () {
      final BillTemplateField date = kBillTemplateFields.firstWhere(
        (f) => f.header == '日期',
      );
      final BillTemplateField note = kBillTemplateFields.firstWhere(
        (f) => f.header == '备注',
      );
      expect(date.displayHeader, '日期*');
      expect(note.displayHeader, '备注');
    });
  });

  group('buildTemplate*', () {
    test('CSV 模板含注释说明行 + 表头行，示例仅出现在 # 注释内', () {
      final String csv = buildTemplateCsv();
      final List<String> lines = csv.split('\n');
      // 第一行是 # 注释，最后非空行是表头。
      expect(lines.first.startsWith('#'), isTrue);
      expect(csv, contains('口袋账本 · 账单导入模板'));
      expect(csv, contains('日期,类型,金额,账户,转入账户,分类,备注'));
      // 示例文本只在 # 注释行内（不是独立数据行）。
      expect(csv, contains('# 示例：2026-10-18 12:30,支出'));
      // 数据区（去掉 # 注释行后）不含示例数据。
      final String dataArea = lines
          .where((l) => !l.trimLeft().startsWith('#'))
          .join('\n');
      expect(dataArea.contains('2026-10-18 12:30,支出'), isFalse);
    });

    test('JSON 模板含 _template 元信息与空 bills 数组', () {
      final String json = buildTemplateJson();
      expect(json, contains('"_template"'));
      expect(json, contains('"version"'));
      expect(json, contains('"bills": []'));
      expect(json, contains('"fields"'));
    });
  });

  group('parseInput 兼容模板注释行 / JSON 模板结构', () {
    test('含 # 注释的 CSV 只解析数据行', () {
      final String csv = '''
# 说明行
日期,类型,金额,账户,转入账户,分类,备注
2026-10-18 12:30,支出,25.50,微信,,餐饮,午饭
''';
      final ParseResult r = parseInput(csv);
      expect(r.errors, isEmpty);
      expect(r.rows.length, 1);
      expect(r.rows.first.accountName, '微信');
      expect(r.rows.first.categoryName, '餐饮');
    });

    test('JSON 模板（{_template,bills}）只解析 bills', () {
      const String json = '''
{
  "_template": {"version": "v1"},
  "bills": [
    {"date":"2026-10-18 12:30","type":"支出","amount":25.5,"account":"微信","category":"餐饮"}
  ]
}
''';
      final ParseResult r = parseInput(json);
      expect(r.errors, isEmpty);
      expect(r.rows.length, 1);
      expect(r.rows.first.amountMinor, 2550);
    });
  });

  group('checkRows 校验与归集', () {
    final List<BillRow> rows = <BillRow>[
      _row('2026-10-01 10:00', TxnType.expense, 2550, '微信', null, '餐饮', '午饭'),
      _row('2026-10-02 10:00', TxnType.income, 800000, '工资卡', null, '工资', '月薪'),
      _row('2026-10-03 10:00', TxnType.transfer, 100000, '微信', '招商银行', null,
          '腾挪'),
      _row('2026-10-03 11:00', TxnType.expense, 0, '微信', null, '餐饮', '无效金额'),
    ];

    test('错误行（金额<=0）被标记且不计入归集', () {
      final TemplateCheckResult c = checkRows(
        rows,
        accountNames: <String>{'微信', '工资卡', '招商银行'},
        categoryNamesByType: <Set<String>>[
          {'工资'}, // income
          {'餐饮'}, // expense
          <String>{}, // transfer
        ],
      );
      expect(c.errors, contains(startsWith('第4行：金额必须大于 0')));
      expect(c.rowCount, 4);
      // 无效金额行不计入任何归集。
      expect(c.byAccount['微信']!.count, 2); // 两笔有效微信
      expect(c.byCategory['支出:餐饮']!.count, 1);
      expect(c.byCategory['收入:工资']!.count, 1);
    });

    test('未知账户/分类登记为自动创建提示', () {
      final TemplateCheckResult c = checkRows(
        <BillRow>[
          _row('2026-10-01 10:00', TxnType.expense, 2550, '新账户', null, '新分类',
              ''),
        ],
        accountNames: <String>{'微信'},
        categoryNamesByType: <Set<String>>[
          <String>{},
          <String>{'餐饮'},
          <String>{},
        ],
      );
      expect(c.newAccounts, <String>['新账户']);
      expect(c.newCategories, <String>['支出:新分类']);
      expect(c.warnings, isNotEmpty);
    });

    test('全部匹配现有数据时不提示新建', () {
      final TemplateCheckResult c = checkRows(
        <BillRow>[
          _row('2026-10-01 10:00', TxnType.expense, 2550, '微信', null, '餐饮', ''),
        ],
        accountNames: <String>{'微信'},
        categoryNamesByType: <Set<String>>[
          <String>{},
          <String>{'餐饮'},
          <String>{},
        ],
      );
      expect(c.newAccounts, isEmpty);
      expect(c.newCategories, isEmpty);
    });

    test('转账缺转入账户被拦截', () {
      final TemplateCheckResult c = checkRows(
        <BillRow>[
          _row('2026-10-01 10:00', TxnType.transfer, 100, '微信', null, null, ''),
        ],
        accountNames: <String>{'微信'},
        categoryNamesByType: <Set<String>>[
          <String>{},
          <String>{},
          <String>{},
        ],
      );
      expect(c.errors, contains(startsWith('第1行：转账缺少转入账户')));
    });

    test('按月与按账户归集计数正确', () {
      final TemplateCheckResult c = checkRows(
        rows,
        accountNames: <String>{'微信', '工资卡', '招商银行'},
        categoryNamesByType: <Set<String>>[
          {'工资'},
          {'餐饮'},
          <String>{},
        ],
      );
      expect(c.byMonth['2026-10']!.count, 3); // 有效 3 笔同月
      expect(c.byAccount['招商银行']!.count, 1);
      expect(c.byAccount['工资卡']!.count, 1);
      expect(c.byAccount['微信']!.count, 2);
    });
  });
}

BillRow _row(
  String date,
  TxnType type,
  int amountMinor,
  String account,
  String? toAccount,
  String? category,
  String? note,
) =>
    BillRow(
      occurredAt: DateTime.parse(date.replaceAll(' ', 'T')),
      type: type,
      amountMinor: amountMinor,
      accountName: account,
      toAccountName: toAccount,
      categoryName: category,
      note: note,
    );
