import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';
import 'bill_io.dart';

/// 「数据导出 / 导入模板系统」——模板规范的唯一事实来源。
///
/// 设计目标（2026-10-18 用户需求）：
/// 1. 导出与导入共用同一套字段结构（[kBillTemplateFields] 派生 CSV 表头与
///    JSON 键），保证往返格式一致；
/// 2. 模板本身明确「字段名称 / 数据类型 / 是否必填 / 填写说明」，以 `#` 注释
///    行内置在模板文件里，用户拿到即可照着填；
/// 3. 导入侧按 分类 / 时间 / 账户 三个维度做匹配校验与归集汇总
///    （[checkRows]），未知账户 / 分类在报告中显式列出「将自动创建」，
///    不再静默落库。
///
/// 模板版本号：字段结构变化时递增，模板文件里写明，便于排查用户旧文件。
const String kBillTemplateVersion = 'v1';

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

  /// 数据类型说明（展示用）：日期时间 / 枚举 / 金额 / 文本。
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
/// 与 [BillRow] 字段一一对应；`分类` 缺省时不归分类，`转入账户` 仅转账必填。
const List<BillTemplateField> kBillTemplateFields = <BillTemplateField>[
  BillTemplateField(
    header: '日期',
    jsonKey: 'date',
    typeLabel: '日期时间',
    required: true,
    desc: '格式 yyyy-MM-dd HH:mm，如 2026-10-18 12:30；只到日期也接受',
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
    header: '分类',
    jsonKey: 'category',
    typeLabel: '文本',
    required: false,
    desc: '分类名称；按收入/支出类型匹配同名分类，不存在将自动创建',
  ),
  BillTemplateField(
    header: '备注',
    jsonKey: 'note',
    typeLabel: '文本',
    required: false,
    desc: '选填，最长建议 50 字',
  ),
];

/// 模板文件头注释（CSV `#` 行 / JSON `_template` 元信息），含全部字段规范。
List<String> templateCommentLines() => <String>[
      '# 口袋账本 · 账单导入模板 $kBillTemplateVersion',
      '# 带 * 为必填列；以 # 开头的行是说明，导入时自动忽略，请勿删除表头行',
      for (final BillTemplateField f in kBillTemplateFields)
        '# ${f.displayHeader}（${f.typeLabel}）：${f.desc}',
      '# 示例：2026-10-18 12:30,支出,25.50,微信,,餐饮,午饭',
      '# 示例：2026-10-18 09:00,转账,1000,招商银行,微信,零存,零钱腾挪',
    ];

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

/// 单维度归集聚合（分类 / 账户 / 月份共用）。
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

/// 模板校验结果：阻断错误（不导入）/ 提示（自动创建）/ 三维归集汇总。
class TemplateCheckResult {
  TemplateCheckResult({
    required this.errors,
    required this.warnings,
    required this.newAccounts,
    required this.newCategories,
    required this.byCategory,
    required this.byAccount,
    required this.byMonth,
    required this.rowCount,
    required this.spanStart,
    required this.spanEnd,
  });

  /// 阻断性错误（金额非法、转账缺转入账户、类型不识别等），逐行带行号。
  final List<String> errors;

  /// 非阻断提示（如备注超长等）。
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

  final int rowCount;
  final DateTime? spanStart;
  final DateTime? spanEnd;

  bool get hasErrors => errors.isNotEmpty;
}

/// 对已解析的 [rows] 做模板匹配校验与三维归集。
///
/// - [accountNames]：当前账本全部账户名（比较时忽略大小写与首尾空格）；
/// - [categoryNamesByType]：按 TxnType.index 对齐的现有分类名集合
///   （index 0=income / 1=expense / 2=transfer，与 CategoryType 顺序一致）。
/// 时间维度校验在 bill_io 解析层已保证（无法识别即 error），此处补
/// 「金额必须 > 0」与归集。
TemplateCheckResult checkRows(
  List<BillRow> rows, {
  required Set<String> accountNames,
  required List<Set<String>> categoryNamesByType,
}) {
  final List<String> errors = <String>[];
  final List<String> warnings = <String>[];
  final List<String> newAccounts = <String>[];
  final List<String> newCategories = <String>[];
  final Map<String, TemplateAgg> byCategory = <String, TemplateAgg>{};
  final Map<String, TemplateAgg> byAccount = <String, TemplateAgg>{};
  final Map<String, TemplateAgg> byMonth = <String, TemplateAgg>{};
  DateTime? spanStart;
  DateTime? spanEnd;

  String norm(String s) => s.trim().toLowerCase();

  // 未知账户 / 分类只在首次出现时登记提示，避免报告刷屏。
  final Set<String> seenNewAccounts = <String>{};
  final Set<String> seenNewCategories = <String>{};

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

    // 账户匹配校验（支出/收入主账户 + 转账双方）。
    final List<String> involved = <String>[
      r.accountName,
      if (r.toAccountName != null) r.toAccountName!,
    ];
    for (final String name in involved) {
      if (!accountNames.contains(norm(name)) &&
          !seenNewAccounts.contains(norm(name))) {
        seenNewAccounts.add(norm(name));
        newAccounts.add(name.trim());
        warnings.add('账户「${name.trim()}」不存在，导入时将自动创建（现金类）');
      }
    }

    // 分类匹配校验（按交易类型对应分类类型）。
    if (r.categoryName != null) {
      final int typeIndex = r.type.index;
      final Set<String> known = typeIndex < categoryNamesByType.length
          ? categoryNamesByType[typeIndex]
          : <String>{};
      final String catKey = '${_typeLabel(r.type)}:${r.categoryName!.trim()}';
      if (!known.contains(norm(r.categoryName!)) &&
          !seenNewCategories.contains(norm(r.categoryName!))) {
        seenNewCategories.add(norm(r.categoryName!));
        newCategories.add(catKey);
        warnings.add(
          '${_typeLabel(r.type)}分类「${r.categoryName!.trim()}」不存在，'
          '导入时将自动创建',
        );
      }
      (byCategory[catKey] ??= TemplateAgg()).add(r);
    }

    (byAccount[r.accountName.trim()] ??= TemplateAgg()).add(r);
    if (r.toAccountName != null) {
      (byAccount[r.toAccountName!.trim()] ??= TemplateAgg()).add(r);
    }
    final String monthKey =
        '${r.occurredAt.year}-${r.occurredAt.month.toString().padLeft(2, '0')}';
    (byMonth[monthKey] ??= TemplateAgg()).add(r);

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
    rowCount: rows.length,
    spanStart: spanStart,
    spanEnd: spanEnd,
  );
}

String _typeLabel(TxnType t) => switch (t) {
      TxnType.income => '收入',
      TxnType.expense => '支出',
      TxnType.transfer => '转账',
    };

/// 金额展示（元，两位小数，无符号）。
String aggAmount(int minor) => Money.fromMinor(minor).format(showSymbol: false);
