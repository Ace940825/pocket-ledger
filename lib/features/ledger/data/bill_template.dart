import 'package:csv/csv.dart';

import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';
import 'bill_io.dart';

/// 「数据导出 / 导入模板系统」——模板规范的唯一事实来源。
///
/// 设计目标（2026-10-18 用户需求，Phase 1 全量交易级字段）：
/// 1. 导出与导入共用同一套字段结构（[kBillTemplateFields] 派生 CSV 表头与
///    JSON 键），保证往返格式一致；
/// 2. 模板本身明确「字段名称 / 数据类型 / 是否必填 / 填写说明」，以 `#` 注释
///    行内置在模板文件里，用户拿到即可照着填；
/// 3. 导入侧按 分类 / 时间 / 账户 / 模块 四个维度做匹配校验与归集汇总
///    （[checkRows]），未知账户 / 分类在报告中显式列出「将自动创建」，
///    不再静默落库。
///
/// 模板版本号：字段结构变化时递增，模板文件里写明，便于排查用户旧文件。
const String kBillTemplateVersion = 'v2';

/// 模板单个字段的结构定义。
class BillTemplateField {
  const BillTemplateField({
    required this.header,
    required this.jsonKey,
    required this.typeLabel,
    required this.required,
    required this.desc,
  });

  /// CSV 表头 / 模板列名（与 JSON [jsonKey] 一一对应）。
  final String header;

  /// JSON 键。
  final String jsonKey;

  /// 数据类型说明（展示用）：日期时间 / 枚举 / 金额 / 文本 / 布尔。
  final String typeLabel;

  /// 是否必填。
  final bool required;

  /// 填写说明。
  final String desc;

  /// 展示用列名：必填字段带 `*` 后缀。
  String get displayHeader => required ? '$header*' : header;
}

/// 模板字段清单（顺序即列顺序，导出与解析共用）。
///
/// 与 [BillRow] 字段一一对应；`模块` 缺省时归「日常记账」，`分类` 缺省时不归分类，
/// `转入账户` 仅转账必填，`标签` 逗号分隔多标签，`账本` 按名称归户。
const List<BillTemplateField> kBillTemplateFields = <BillTemplateField>[
  BillTemplateField(
    header: '日期',
    jsonKey: 'date',
    typeLabel: '日期时间',
    required: true,
    desc: '格式 yyyy-MM-dd HH:mm，如 2026-10-18 12:30；只到日期也接受',
  ),
  BillTemplateField(
    header: '模块',
    jsonKey: 'module',
    typeLabel: '枚举',
    required: false,
    desc: '业务来源：日常记账 / 转账 / 借还 / 报销 / 储蓄 / 分期 / 投资 / 物品 / '
        '退款；留空默认「日常记账」。报销的「支出侧」不用本列——垫付请记一笔普通'
        '支出并填「可报销=Y + 报销账户」；本列「报销」仅用于报销到账的收入。'
        '借还（Phase 2 已支持）按分类名（借入/借出/还债/收债/债务消减/坏账计提）'
        '路由到借还台账，并需填「对方」列；储蓄/分期/投资仍仅作标记、不生成子台账',
  ),
  BillTemplateField(
    header: '类型',
    jsonKey: 'type',
    typeLabel: '枚举',
    required: true,
    desc: '只能填：收入 / 支出 / 转账',
  ),
  BillTemplateField(
    header: '金额',
    jsonKey: 'amount',
    typeLabel: '金额',
    required: true,
    desc: '正数金额（元），最多两位小数，如 25.50；不接受 0 或负数',
  ),
  BillTemplateField(
    header: '账户',
    jsonKey: 'account',
    typeLabel: '文本',
    required: true,
    desc: '账户名称；与现有账户按名称匹配（忽略大小写），不存在将自动创建',
  ),
  BillTemplateField(
    header: '转入账户',
    jsonKey: 'toAccount',
    typeLabel: '文本',
    required: false,
    desc: '仅「转账」必填：转入方账户名称',
  ),
  BillTemplateField(
    header: '对方',
    jsonKey: 'counterparty',
    typeLabel: '文本',
    required: false,
    desc: '仅「借还」模块且分类为借入/借出/还债/收债/债务消减/坏账计提之一时必填：'
        '借款人 / 出借人 / 债务方名。借还按固定分类名路由到借还台账，对方即其 counterparty；'
        '其余模块留空',
  ),
  BillTemplateField(
    header: '优惠',
    jsonKey: 'discount',
    typeLabel: '金额',
    required: false,
    desc: '优惠 / 折扣金额（元），如 45.00；实付 = 金额 − 优惠。留空为 0',
  ),
  BillTemplateField(
    header: '分类',
    jsonKey: 'category',
    typeLabel: '文本',
    required: false,
    desc: '分类名称；按收入/支出类型匹配同名分类，不存在将自动创建',
  ),
  BillTemplateField(
    header: '标签',
    jsonKey: 'tags',
    typeLabel: '文本',
    required: false,
    desc: '标签名，多个用半角逗号分隔，如 旅游,2026；留空无标签',
  ),
  BillTemplateField(
    header: '账本',
    jsonKey: 'book',
    typeLabel: '文本',
    required: false,
    desc: '账本名称；按名称归户到对应账本，不存在将归入当前账本。留空归当前账本',
  ),
  BillTemplateField(
    header: '可报销',
    jsonKey: 'isReimbursable',
    typeLabel: '布尔',
    required: false,
    desc: '是否可报销：Y / N（或 是 / 否 / true / false）。Y 时建议填「报销账户」',
  ),
  BillTemplateField(
    header: '报销账户',
    jsonKey: 'reimbursementAccount',
    typeLabel: '文本',
    required: false,
    desc: '可报销时挂账的报销账户名称（如「公司报销」）；不存在将自动创建为报销类账户',
  ),
  BillTemplateField(
    header: '不计预算',
    jsonKey: 'excludeFromBudget',
    typeLabel: '布尔',
    required: false,
    desc: '是否不计入预算：Y / N。Y 时不参与预算月度统计',
  ),
  BillTemplateField(
    header: '不计收支',
    jsonKey: 'excludeFromStats',
    typeLabel: '布尔',
    required: false,
    desc: '是否不计入收支统计：Y / N。Y 时不计入收支报表（如内部划转、对账调整）',
  ),
  BillTemplateField(
    header: '备注',
    jsonKey: 'note',
    typeLabel: '文本',
    required: false,
    desc: '选填，最长建议 200 字',
  ),
];

/// 示例数据（与表头严格 16 列对齐，经 [ListToCsvConverter] 生成，避免手写错位）。
///
/// 顺序：日期,模块,类型,金额,账户,转入账户,对方,优惠,分类,标签,账本,可报销,
/// 报销账户,不计预算,不计收支,备注。
const List<List<String>> _sampleRows = <List<String>>[
  <String>[
    '2026-10-18 12:30', '日常记账', '支出', '25.50', '微信',
    '', '', '', '餐饮', '午饭', '',
    'N', '', 'N', 'N', '午饭',
  ],
  <String>[
    '2026-10-18 09:00', '退款', '收入', '25.50', '微信',
    '', '', '', '', '旅游,2026', '',
    'N', '', 'N', 'N', '退货退款',
  ],
  <String>[
    '2026-10-18 15:00', '借还', '支出', '1000', '微信',
    '', '小米', '', '借出', '', '',
    'N', '', 'N', 'N', '借给小米',
  ],
  <String>[
    '2026-10-18 18:00', '储蓄', '转账', '500', '招商银行',
    '定期存款', '', '', '', '', '',
    'N', '', 'N', 'N', '每月定存',
  ],
  <String>[
    '2026-10-18 20:00', '日常记账', '支出', '200', '微信',
    '', '', '', '餐饮', '', '',
    'Y', '公司报销', 'N', 'N', '出差午饭（垫付，待报销）',
  ],
  <String>[
    '2026-10-25 10:00', '报销', '收入', '200', '公司报销',
    '', '', '', '', '', '',
    'N', '公司报销', 'N', 'N', '报销到账',
  ],
];

/// 校验示例与表头列数严格一致（防手写错位，曾在 Excel 里被发现）。
///
/// 示例与表头都由 [ListToCsvConverter] 生成，理论上不会错位；这里再显式守门，
/// 一旦有人改了 [_sampleRows] 漏一列，立即抛错暴露，而不是静默导出一份错位的模板。
void _verifySampleColumns() {
  final int expected = kBillTemplateFields.length;
  for (int i = 0; i < _sampleRows.length; i++) {
    if (_sampleRows[i].length != expected) {
      throw StateError(
        '示例第 ${i + 1} 行列数（${_sampleRows[i].length}）≠ 表头（$expected），'
        '模板示例错位',
      );
    }
  }
}

/// 把示例行渲染成 CSV 文本（含表头），仅用于生成注释与预览，不直接作数据区。
String _renderSampleCsv() {
  _verifySampleColumns();
  return const ListToCsvConverter(eol: '\n').convert(<List<dynamic>>[
    <String>[for (final BillTemplateField f in kBillTemplateFields) f.header],
    for (final List<String> r in _sampleRows) r,
  ]);
}

/// 模板文件头注释（CSV `#` 行 / JSON `_template` 元信息），含全部字段规范。
///
/// 示例行由 [_renderSampleCsv] 统一生成并前缀 `# 示例：`，与表头同列数，
/// 杜绝此前「手写注释示例列数错位」的问题。
List<String> templateCommentLines() {
  final List<String> sampleLines = _renderSampleCsv()
      .split('\n')
      .skip(1) // 跳过表头（表头另起一行，不进 # 注释）
      .map((String l) => '# 示例：$l')
      .toList();
  return <String>[
    '# 口袋账本 · 账单导入模板 $kBillTemplateVersion',
    '# 带 * 为必填列；以 # 开头的行是说明，导入时自动忽略，请勿删除表头行',
    for (final BillTemplateField f in kBillTemplateFields)
      '# ${f.displayHeader}（${f.typeLabel}）：${f.desc}',
    ...sampleLines,
  ];
}

/// 生成空白填写模板 CSV：说明注释行 + 表头行。用户填到表头行下方即可导入。
String buildTemplateCsv() => <String>[
      ...templateCommentLines(),
      <String>[for (final BillTemplateField f in kBillTemplateFields) f.header]
          .join(','),
      '',
    ].join('\n');

/// 生成空白填写模板 JSON：`_template` 元信息 + 空数组，字段规范在 `fields` 里。
String buildTemplateJson() {
  final Map<String, dynamic> spec = <String, dynamic>{
    '_template': <String, dynamic>{
      'app': '口袋账本',
      'version': kBillTemplateVersion,
      'fields': <Map<String, dynamic>>[
        for (final BillTemplateField f in kBillTemplateFields)
          <String, dynamic>{
            'key': f.jsonKey,
            'name': f.header,
            'type': f.typeLabel,
            'required': f.required,
            'desc': f.desc,
          },
      ],
    },
    'bills': <dynamic>[],
  };
  return _prettyJson(spec);
}

/// 极简两空格缩进 JSON（避免引入 dart:convert 之外的依赖；jsonEncode 原生
/// 输出单行不利于用户阅读）。
String _prettyJson(Object? o, {int indent = 0}) {
  final String pad = ' ' * indent;
  if (o is Map) {
    if (o.isEmpty) return '{}';
    final List<String> parts = <String>[];
    for (final MapEntry<Object?, Object?> e in o.entries) {
      parts.add(
        '$pad  "${e.key}": '
        '${_prettyJson(e.value, indent: indent + 2)}',
      );
    }
    return '{\n${parts.join(',\n')}\n$pad}';
  }
  if (o is List) {
    if (o.isEmpty) return '[]';
    final List<String> parts = <String>[];
    for (final Object? v in o) {
      parts.add('$pad  ${_prettyJson(v, indent: indent + 2)}');
    }
    return '[\n${parts.join(',\n')}\n$pad]';
  }
  if (o == null) return 'null';
  if (o is String) return '"$o"';
  return o.toString();
}

// ───────────────────── 导入匹配校验 + 核对归集 ─────────────────────

/// 单维度归集聚合（分类 / 账户 / 月 / 模块共用）。
class TemplateAgg {
  int count = 0;
  int incomeMinor = 0;
  int expenseMinor = 0;
  int transferMinor = 0;

  void add(BillRow r) {
    count++;
    switch (r.type) {
      case TxnType.income:
        incomeMinor += r.amountMinor;
      case TxnType.expense:
        expenseMinor += r.amountMinor;
      case TxnType.transfer:
        transferMinor += r.amountMinor;
    }
  }
}

/// 仅作标记、不生成子记录的模块（报销/储蓄/分期/投资）。
///
/// 借还（lend）已在 Phase 2 落地：按固定分类名路由到借还台账，不再仅作标记。
/// 其余业务有独立台账待后续阶段落地；当前导入会把它们落为普通交易并打上模块标记，
/// 但不会生成对应的报销应收 / 储蓄台账 / 分期计划 / 投资持仓，因此相关派生余额
/// 不会被驱动——导入校验阶段显式提示用户。
const Set<SourceModule> _kPhase2Modules = <SourceModule>{
  SourceModule.reimbursement,
  SourceModule.savings,
  SourceModule.installment,
  SourceModule.investment,
};

/// 模板校验结果：阻断错误（不导入）/ 提示（自动创建）/ 四维归集汇总。
class TemplateCheckResult {
  TemplateCheckResult({
    required this.errors,
    required this.warnings,
    required this.newAccounts,
    required this.newCategories,
    required this.byCategory,
    required this.byAccount,
    required this.byMonth,
    required this.byModule,
    required this.rowCount,
    required this.spanStart,
    required this.spanEnd,
  });

  /// 阻断性错误（金额非法、转账缺转入账户、类型不识别等），逐行带行号。
  final List<String> errors;

  /// 非阻断提示（如备注超长、Phase 1 仅标记等）。
  final List<String> warnings;

  /// 将自动创建的账户名（去重、保持出现顺序）。
  final List<String> newAccounts;

  /// 将自动创建的分类名（格式「支出:餐饮」）。
  final List<String> newCategories;

  /// 按分类归集（key 为「类型:分类名」，如「支出:餐饮」）。
  final Map<String, TemplateAgg> byCategory;

  /// 按账户归集（账户名，含转入账户）。
  final Map<String, TemplateAgg> byAccount;

  /// 按月归集（key 为 yyyy-MM）。
  final Map<String, TemplateAgg> byMonth;

  /// 按模块归集（key 为模块中文名，如「日常记账」「报销」）。
  final Map<String, TemplateAgg> byModule;

  final int rowCount;
  final DateTime? spanStart;
  final DateTime? spanEnd;

  bool get hasErrors => errors.isNotEmpty;
}

/// 对已解析的 [rows] 做模板匹配校验与四维归集。
///
/// - [accountNames]：当前账本全部账户名（比较时忽略大小写与首尾空格）；
/// - [categoryNamesByType]：按 TxnType.index 对齐的现有分类名集合
///   （index 0=income / 1=expense / 2=transfer，与 CategoryType 顺序一致）；
/// - [bookNames]：可选，全部账本名集合。提供后用于校验「账本」列是否存在，
///   不存在给出提示（归入当前账本）。
/// 时间维度校验在 bill_io 解析层已保证（无法识别即 error），此处补
/// 「金额必须 > 0」与归集。
TemplateCheckResult checkRows(
  List<BillRow> rows, {
  required Set<String> accountNames,
  required List<Set<String>> categoryNamesByType,
  Set<String> bookNames = const <String>{},
}) {
  final List<String> errors = <String>[];
  final List<String> warnings = <String>[];
  final List<String> newAccounts = <String>[];
  final List<String> newCategories = <String>[];
  final Map<String, TemplateAgg> byCategory = <String, TemplateAgg>{};
  final Map<String, TemplateAgg> byAccount = <String, TemplateAgg>{};
  final Map<String, TemplateAgg> byMonth = <String, TemplateAgg>{};
  final Map<String, TemplateAgg> byModule = <String, TemplateAgg>{};
  DateTime? spanStart;
  DateTime? spanEnd;

  String norm(String s) => s.trim().toLowerCase();

  // 未知账户 / 分类只在首次出现时登记提示，避免报告刷屏。
  final Set<String> seenNewAccounts = <String>{};
  final Set<String> seenNewCategories = <String>{};
  final Set<String> seenNewBooks = <String>{};
  final Set<SourceModule> seenPhase2Modules = <SourceModule>{}; // 每个 Phase2 模块只提示一次

  for (int i = 0; i < rows.length; i++) {
    final BillRow r = rows[i];
    final String lineNo = '第${i + 1}行';

    // 金额校验：解析层容忍 0（Money.tryParse 失败落 0），模板明确要求 > 0。
    if (r.amountMinor <= 0) {
      errors.add('$lineNo：金额必须大于 0');
      continue;
    }
    if (r.type == TxnType.transfer && r.toAccountName == null) {
      errors.add('$lineNo：转账缺少转入账户');
      continue;
    }
    if (r.note != null && r.note!.length > 200) {
      warnings.add('$lineNo：备注超过 200 字，已接受但建议精简');
    }

    // 借还（Phase 2 已落地）：按固定分类名路由到借还台账，校验对方与账户必填。
    if (r.module == SourceModule.lend) {
      if (r.categoryName == null || r.categoryName!.trim().isEmpty) {
        errors.add('$lineNo：借还模块必须指定分类'
            '（借入/借出/还债/收债/债务消减/坏账计提）');
        continue;
      }
      final LendOp? op = parseLendOp(r.categoryName);
      if (op == null) {
        errors.add('$lineNo：未识别的借还分类「${r.categoryName!.trim()}」，'
            '应为 借入/借出/还债/收债/债务消减/坏账计提 之一');
        continue;
      }
      final String cp = (r.counterparty ?? '').trim();
      if (cp.isEmpty) {
        errors.add('$lineNo：借还记录「对方」不能为空');
        continue;
      }
      if (lendOpNeedsAccount(op) && r.accountName.trim().isEmpty) {
        errors.add('$lineNo：借还（借入/借出/还债/收债）需指定账户');
        continue;
      }
    }

    // 模块：仅作标记落库提示（借还已在 Phase 2 落地，不再提示）。
    if (_kPhase2Modules.contains(r.module) &&
        !seenPhase2Modules.contains(r.module)) {
      seenPhase2Modules.add(r.module);
      warnings.add('模块「${r.module.label}」仅作标记落库，不会生成对应的'
          '报销/储蓄/分期/投资子记录，相关派生余额暂不驱动，请待后续阶段支持');
    }

    // 账本校验：指定了且账本集合已知但不存在 → 提示归入当前账本。
    if (r.book != null &&
        r.book!.trim().isNotEmpty &&
        bookNames.isNotEmpty &&
        !bookNames.contains(norm(r.book!)) &&
        !seenNewBooks.contains(norm(r.book!))) {
      seenNewBooks.add(norm(r.book!));
      warnings.add('账本「${r.book!.trim()}」不存在，将归入当前账本');
    }

    // 报销校验：标记可报销但未指定报销账户 → 仅记可报销、不挂账应收。
    if (r.isReimbursable &&
        (r.reimbursementAccount == null || r.reimbursementAccount!.trim().isEmpty)) {
      warnings.add('$lineNo：标记「可报销」但未指定报销账户，将仅记为可报销、不挂账报销应收');
    }

    // 账户匹配校验（支出/收入主账户 + 转账双方）。
    final List<String> involved = <String>[
      r.accountName,
      if (r.toAccountName != null) r.toAccountName!,
      if (r.isReimbursable && r.reimbursementAccount != null)
        r.reimbursementAccount!,
    ];
    for (final String name in involved) {
      if (!accountNames.contains(norm(name)) &&
          !seenNewAccounts.contains(norm(name))) {
        seenNewAccounts.add(norm(name));
        newAccounts.add(name.trim());
        warnings.add('账户「${name.trim()}」不存在，导入时将自动创建（现金类；报销账户建为报销类）');
      }
    }

    // 分类匹配校验（按交易类型对应分类类型）。借还路由行的分类是 6 类固定
    // 操作名（借入/借出/还债/收债/债务消减/坏账计提），由借还台账自建系统类目，
    // 不应当作用户分类校验 / 创建，故跳过。
    if (r.categoryName != null && r.module != SourceModule.lend) {
      final int typeIndex = r.type.index;
      final Set<String> known = typeIndex < categoryNamesByType.length
          ? categoryNamesByType[typeIndex]
          : <String>{};
      final String catKey = '${r.type.label}:${r.categoryName!.trim()}'; // 用中文类型名避免与模块名混
      if (!known.contains(norm(r.categoryName!)) &&
          !seenNewCategories.contains(norm(r.categoryName!))) {
        seenNewCategories.add(norm(r.categoryName!));
        newCategories.add(catKey);
        warnings.add(
          '${r.type.label}分类「${r.categoryName!.trim()}」不存在，'
          '导入时将自动创建',
        );
      }
      (byCategory[catKey] ??= TemplateAgg()).add(r);
    }

    (byAccount[r.accountName.trim()] ??= TemplateAgg()).add(r);
    if (r.toAccountName != null) {
      (byAccount[r.toAccountName!.trim()] ??= TemplateAgg()).add(r);
    }
    if (r.isReimbursable && r.reimbursementAccount != null) {
      (byAccount[r.reimbursementAccount!.trim()] ??= TemplateAgg()).add(r);
    }
    final String monthKey =
        '${r.occurredAt.year}-${r.occurredAt.month.toString().padLeft(2, '0')}';
    (byMonth[monthKey] ??= TemplateAgg()).add(r);
    (byModule[r.module.label] ??= TemplateAgg()).add(r);

    if (spanStart == null || r.occurredAt.isBefore(spanStart)) {
      spanStart = r.occurredAt;
    }
    if (spanEnd == null || r.occurredAt.isAfter(spanEnd)) {
      spanEnd = r.occurredAt;
    }
  }

  return TemplateCheckResult(
    errors: errors,
    warnings: warnings,
    newAccounts: newAccounts,
    newCategories: newCategories,
    byCategory: byCategory,
    byAccount: byAccount,
    byMonth: byMonth,
    byModule: byModule,
    rowCount: rows.length,
    spanStart: spanStart,
    spanEnd: spanEnd,
  );
}

/// 金额展示（元，两位小数，无符号）。
String aggAmount(int minor) => Money.fromMinor(minor).format(showSymbol: false);
