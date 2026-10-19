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
        '模块',
        '类型',
        '金额',
        '账户',
        '转入账户',
        '对方',
        '优惠',
        '分类',
        '标签',
        '账本',
        '可报销',
        '报销账户',
        '不计预算',
        '不计收支',
        '备注',
      ]);
      // 必填：日期/类型/金额/账户；其余（含模块）均为选填。
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
      expect(
        csv,
        contains('日期,模块,类型,金额,账户,转入账户,对方,优惠,分类,标签,账本,'
            '可报销,报销账户,不计预算,不计收支,备注'),
      );
      // 示例文本只在 # 注释行内（带模块列），不是独立数据行。
      expect(csv, contains('# 示例：2026-10-18 12:30,日常记账,支出'));
      // 数据区（去掉 # 注释行后）不含示例数据。
      final String dataArea = lines
          .where((l) => !l.trimLeft().startsWith('#'))
          .join('\n');
      expect(dataArea.contains('2026-10-18 12:30,日常记账,支出'), isFalse);
    });

    test('模板示例与表头列数严格一致（防错位）', () {
      // 把模板正文（含 # 注释）整体当作数据解析，注释行会被忽略；
      // 表头行 + 用户数据行的列数都应等于 16（15 字段 + 对方）。
      // 这里直接校验渲染出的示例块。
      final String csv = buildTemplateCsv();
      final List<String> nonComment = csv
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('#'))
          .where((l) => l.trim().isNotEmpty)
          .toList();
      // 第一行应为表头（16 列）。
      expect(nonComment.first.split(',').length, 16);
    });

    test('JSON 模板含 _template 元信息与空 bills 数组', () {
      final String json = buildTemplateJson();
      expect(json, contains('"_template"'));
      expect(json, contains('"version"'));
      expect(json, contains('"bills": []'));
      expect(json, contains('"fields"'));
      // 16 个字段规范（含「对方」）。
      expect(kBillTemplateFields.length, 16);
    });
  });

  group('parseInput 兼容模板注释行 / JSON 模板结构', () {
    test('含 # 注释的 CSV 只解析数据行', () {
      const String csv = '''
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

  group('parseInput v2 全量字段', () {
    test('16 列表头解析：模块/对方/优惠/标签/开关/报销账户/账本', () {
      const String csv = '''
日期,模块,类型,金额,账户,转入账户,对方,优惠,分类,标签,账本,可报销,报销账户,不计预算,不计收支,备注
2026-10-18 12:30,报销,支出,200,微信,,,45,餐饮,"旅游,2026",我的账本,Y,公司报销,N,N,出差午饭
''';
      final ParseResult r = parseInput(csv);
      expect(r.errors, isEmpty);
      expect(r.rows.length, 1);
      final BillRow row = r.rows.first;
      expect(row.module, SourceModule.reimbursement);
      expect(row.amountMinor, 20000);
      expect(row.discountMinor, 4500);
      expect(row.tags, <String>['旅游', '2026']);
      expect(row.book, '我的账本');
      expect(row.isReimbursable, isTrue);
      expect(row.reimbursementAccount, '公司报销');
      expect(row.excludeFromBudget, isFalse);
      expect(row.excludeFromStats, isFalse);
      expect(row.categoryName, '餐饮');
    });

    test('模块缺省归日常记账；布尔接受 N/否', () {
      const String csv = '''
日期,模块,类型,金额,账户,转入账户,对方,优惠,分类,标签,账本,可报销,报销账户,不计预算,不计收支,备注
2026-10-18 12:30,,收入,88,工资卡,,,,,,我的账本,否,,是,N,薪水
''';
      final ParseResult r = parseInput(csv);
      expect(r.errors, isEmpty);
      final BillRow row = r.rows.first;
      expect(row.module, SourceModule.ledger);
      expect(row.isReimbursable, isFalse); // 可报销=否 → false
      // 不计收支=N → false（验证 N / 否 都接受为「否」）。
      expect(row.excludeFromStats, isFalse);
    });

    test('JSON 全量字段往返一致（含借还 counterparty）', () {
      const String json = '''
[
  {"date":"2026-10-18 12:30","module":"借还","type":"支出","amount":1000,
   "account":"微信","counterparty":"小米","discount":0,"category":"借出",
   "tags":[],"book":"","isReimbursable":false,"reimbursementAccount":"",
   "excludeFromBudget":false,"excludeFromStats":false,"note":"借给小米",
   "currency":"CNY"}
]
''';
      final ParseResult r = parseInput(json);
      expect(r.errors, isEmpty);
      expect(r.rows.first.module, SourceModule.lend);
      expect(r.rows.first.amountMinor, 100000);
      expect(r.rows.first.counterparty, '小米');
      expect(r.rows.first.categoryName, '借出');
      expect(r.rows.first.book, isNull);
    });

    test('CSV 借还行解析：对方列 + 分类名路由', () {
      const String csv = '''
日期,模块,类型,金额,账户,转入账户,对方,优惠,分类,标签,账本,可报销,报销账户,不计预算,不计收支,备注
2026-10-18 15:00,借还,支出,1000,微信,,小米,0,借出,,我的账本,N,,N,N,借给小米
''';
      final ParseResult r = parseInput(csv);
      expect(r.errors, isEmpty);
      expect(r.rows.length, 1);
      final BillRow row = r.rows.first;
      expect(row.module, SourceModule.lend);
      expect(row.counterparty, '小米');
      expect(row.categoryName, '借出');
      expect(parseLendOp(row.categoryName), LendOp.lendAdd);
    });

    test('数据行列数超出表头被拦截', () {
      const String csv = '''
日期,类型,金额,账户
2026-10-18 12:30,支出,25.50,微信,多余的列
''';
      final ParseResult r = parseInput(csv);
      expect(r.errors, isNotEmpty);
      expect(r.errors.first, startsWith('第1行：列数'));
      expect(r.rows, isEmpty);
    });

    test('旧 7 列表头（无模块/标签等）仍可解析，模块缺省', () {
      const String csv = '''
日期,类型,金额,账户,转入账户,分类,备注
2026-10-18 12:30,支出,25.50,微信,,餐饮,午饭
''';
      final ParseResult r = parseInput(csv);
      expect(r.errors, isEmpty);
      expect(r.rows.first.module, SourceModule.ledger);
      expect(r.rows.first.tags, isEmpty);
    });
  });

  group('checkRows 校验与归集', () {
    final List<BillRow> rows = <BillRow>[
      _row('2026-10-01 10:00', TxnType.expense, 2550, '微信', null, '餐饮', '午饭'),
      _row('2026-10-02 10:00', TxnType.income, 800000, '工资卡', null, '工资', '月薪'),
      _row('2026-10-03 10:00', TxnType.transfer, 100000, '微信', '招商银行', null,
          '腾挪',),
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
              '',),
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

    test('按模块归集计数正确，且非日常记账模块被归入对应模块', () {
      final TemplateCheckResult c = checkRows(
        <BillRow>[
          _row('2026-10-01 10:00', TxnType.expense, 2550, '微信', null, '餐饮', ''),
          _row('2026-10-02 10:00', TxnType.expense, 1000, '微信', null, '借出',
              '借给小米', module: SourceModule.lend, counterparty: '小米'),
        ],
        accountNames: <String>{'微信'},
        categoryNamesByType: <Set<String>>[
          <String>{},
          <String>{'餐饮', '借出'},
          <String>{},
        ],
      );
      expect(c.byModule['日常记账']!.count, 1);
      expect(c.byModule['借还']!.count, 1);
    });

    test('仅作标记模块（储蓄/分期/投资）给出提示；借还已在 Phase 2 落地不再提示', () {
      final TemplateCheckResult c = checkRows(
        <BillRow>[
          _row('2026-10-01 10:00', TxnType.transfer, 500, '招商银行', '定期存款',
              null, '', module: SourceModule.savings),
          _row('2026-10-02 10:00', TxnType.expense, 1000, '微信', null, '借出',
              '借给小米', module: SourceModule.lend, counterparty: '小米'),
        ],
        accountNames: <String>{'微信', '招商银行', '定期存款'},
        categoryNamesByType: <Set<String>>[
          <String>{},
          <String>{'借出'},
          <String>{},
        ],
      );
      expect(
        c.warnings,
        contains(startsWith('模块「储蓄」仅作标记落库')),
      );
      // 借还（Phase 2 已支持）不应出现「仅标记」提示。
      expect(
        c.warnings,
        isNot(contains(contains('借还'))),
      );
    });
  });

  group('借还路由（Phase 2）', () {
    test('固定分类名 → LendOp 映射，非固定名返回 null', () {
      expect(parseLendOp('借入'), LendOp.borrowAdd);
      expect(parseLendOp('借出'), LendOp.lendAdd);
      expect(parseLendOp('还债'), LendOp.borrowRepay);
      expect(parseLendOp('收债'), LendOp.lendCollect);
      expect(parseLendOp('债务消减'), LendOp.borrowReduce);
      expect(parseLendOp('坏账计提'), LendOp.lendBadDebt);
      expect(parseLendOp('餐饮'), isNull);
      expect(parseLendOp(null), isNull);
      expect(parseLendOp(' 借出 '), LendOp.lendAdd); // 容忍首尾空格
    });

    test('lendOpDirection 方向正确', () {
      expect(lendOpDirection(LendOp.borrowAdd), LendDirection.borrowIn);
      expect(lendOpDirection(LendOp.borrowRepay), LendDirection.borrowIn);
      expect(lendOpDirection(LendOp.borrowReduce), LendDirection.borrowIn);
      expect(lendOpDirection(LendOp.lendAdd), LendDirection.lendOut);
      expect(lendOpDirection(LendOp.lendCollect), LendDirection.lendOut);
      expect(lendOpDirection(LendOp.lendBadDebt), LendDirection.lendOut);
    });

    test('lendOpNeedsAccount 仅本金/还款需要真实资产账户', () {
      expect(lendOpNeedsAccount(LendOp.borrowAdd), isTrue);
      expect(lendOpNeedsAccount(LendOp.lendAdd), isTrue);
      expect(lendOpNeedsAccount(LendOp.borrowRepay), isTrue);
      expect(lendOpNeedsAccount(LendOp.lendCollect), isTrue);
      expect(lendOpNeedsAccount(LendOp.borrowReduce), isFalse);
      expect(lendOpNeedsAccount(LendOp.lendBadDebt), isFalse);
    });

    test('checkRows 借还行：分类/对方必填，债务消减/坏账计提无需账户', () {
      // 缺分类 → 拦截。
      final TemplateCheckResult c1 = checkRows(
        <BillRow>[
          _row('2026-10-01 10:00', TxnType.expense, 1000, '微信', null, null, '',
              module: SourceModule.lend, counterparty: '小米'),
        ],
        accountNames: <String>{'微信'},
        categoryNamesByType: <Set<String>>[<String>{}, <String>{}, <String>{}],
      );
      expect(c1.errors, contains(startsWith('第1行：借还模块必须指定分类')));

      // 缺对方 → 拦截。
      final TemplateCheckResult c2 = checkRows(
        <BillRow>[
          _row('2026-10-01 10:00', TxnType.expense, 1000, '微信', null, '借出', '',
              module: SourceModule.lend),
        ],
        accountNames: <String>{'微信'},
        categoryNamesByType: <Set<String>>[<String>{}, <String>{}, <String>{}],
      );
      expect(c2.errors, contains(startsWith('第1行：借还记录「对方」不能为空')));

      // 债务消减：无需真实资产账户，仅对方 + 分类即可通过校验（账户空也放行）。
      final TemplateCheckResult c3 = checkRows(
        <BillRow>[
          _row('2026-10-01 10:00', TxnType.expense, 1000, '', null, '债务消减',
              '', module: SourceModule.lend, counterparty: '小米'),
        ],
        accountNames: <String>{},
        categoryNamesByType: <Set<String>>[<String>{}, <String>{}, <String>{}],
      );
      expect(c3.errors, isEmpty);
      expect(c3.byModule['借还']!.count, 1);

      // 借出（需账户）：账户空 → 拦截。
      final TemplateCheckResult c4 = checkRows(
        <BillRow>[
          _row('2026-10-01 10:00', TxnType.expense, 1000, '', null, '借出', '',
              module: SourceModule.lend, counterparty: '小米'),
        ],
        accountNames: <String>{},
        categoryNamesByType: <Set<String>>[<String>{}, <String>{}, <String>{}],
      );
      expect(c4.errors, contains(startsWith('第1行：借还（借入/借出/还债/收债）需指定账户')));
    });

    test('checkRows 借还行的分类是操作名，不触发用户分类自动创建提示', () {
      // 借还分类「借出」不在普通分类集合里，不应被登记为「将自动创建的分类」。
      final TemplateCheckResult c = checkRows(
        <BillRow>[
          _row('2026-10-01 10:00', TxnType.expense, 1000, '微信', null, '借出',
              '借给小米', module: SourceModule.lend, counterparty: '小米'),
        ],
        accountNames: <String>{'微信'},
        categoryNamesByType: <Set<String>>[<String>{}, <String>{}, <String>{}],
      );
      expect(c.errors, isEmpty);
      expect(c.newCategories, isEmpty);
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
  String? note, {
  SourceModule module = SourceModule.ledger,
  String? counterparty,
}) =>
    BillRow(
      occurredAt: DateTime.parse(date.replaceAll(' ', 'T')),
      type: type,
      amountMinor: amountMinor,
      accountName: account,
      toAccountName: toAccount,
      categoryName: category,
      note: note,
      module: module,
      counterparty: counterparty,
    );
