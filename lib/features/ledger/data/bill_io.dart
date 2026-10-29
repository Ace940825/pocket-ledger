import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';
import 'account_io.dart';

// ── 截图 OCR 跨语言结果解析（Swift 与 Dart 共用 schema）──
//
// 字段名与 ScreenshotOcrService 的模型 prompt 输出完全一致：
//   amount / direction / date / account / toAccount / merchant /
//   note / category / currency / confidence
// Swift 侧（ScreenshotIntent.swift）把 LLM 原始 items 透传写入
// pl_pending_ocr_result.json，Dart 侧用本组函数重建 [BillRow]，
// 保证「识别在 Swift、落库在 Dart」两端语义一致、单一真源。

/// 交接文件名（Swift 写出、Dart 读取的 OCR 结果）。
const String kPendingOcrResult = 'pl_pending_ocr_result.json';

/// 把模型返回的单条 item 映射成 [BillRow]；字段缺失 / 非法返回 null。
///
/// 与 [ScreenshotOcrService] 原先的私有 [_parseItem] 同构，提到顶层后
/// 供「Swift 已识别、Dart 仅重建」路径复用，避免两端各写一份解析。
BillRow? parseOcrItem(Map<String, dynamic> m) {
  final DateTime? dt = parseOcrDate((m['date'] ?? '').toString());
  if (dt == null) return null;
  final TxnType? type = _parseType((m['direction'] ?? '').toString());
  if (type == null) return null;
  final int amount = Money.tryParse((m['amount'] ?? '').toString()).minor;
  final String account = (m['account'] ?? '').toString().trim();
  if (account.isEmpty) return null;
  final String toRaw = (m['toAccount'] ?? '').toString().trim();
  final String? toAccount = toRaw.isEmpty ? null : toRaw;
  if (type == TxnType.transfer && toAccount == null) return null;
  final String merchant = (m['merchant'] ?? '').toString().trim();
  final String noteRaw = (m['note'] ?? '').toString().trim();
  final String mergedNote = <String>[
    if (merchant.isNotEmpty) merchant,
    if (noteRaw.isNotEmpty) noteRaw,
  ].join(' · ');
  final double? conf = double.tryParse((m['confidence'] ?? '').toString());
  final String? category = ((m['category'] ?? '').toString().trim()).isEmpty
      ? null
      : (m['category'] as String).trim();
  return BillRow(
    occurredAt: dt,
    type: type,
    amountMinor: amount,
    accountName: account,
    toAccountName: toAccount,
    categoryName: category,
    note: mergedNote.isEmpty ? null : mergedNote,
    currency: (m['currency'] ?? 'CNY').toString(),
    confidence: conf,
  );
}

/// 把模型返回 items 数组批量映射成 [BillRow]，跳过无法映射的项。
List<BillRow> parseOcrItems(List<dynamic> items) {
  final List<BillRow> rows = <BillRow>[];
  for (final dynamic it in items) {
    if (it is! Map) continue;
    final BillRow? row = parseOcrItem(it.cast<String, dynamic>());
    if (row != null) rows.add(row);
  }
  return rows;
}

/// 解析 OCR 日期（"YYYY-MM-DD HH:mm" / "YYYY-MM-DD"），非法返回 null。
DateTime? parseOcrDate(String raw) {
  final String s = raw.trim();
  if (s.isEmpty) return null;
  final DateTime? withT = DateTime.tryParse(s.replaceAll(' ', 'T'));
  if (withT != null) return withT;
  return DateTime.tryParse(s);
}

/// 一笔可导入 / 导出的账单（与数据库无关的中间表示）。
///
/// 导入侧把 CSV / JSON 解析成 [BillRow]，导出侧把库内流水投影成 [BillRow]，
/// 二者共用同一套字段，保证「导出 → 导入」可无损往返（账户 / 分类按名称
/// 重新归户，见 bill_import_page）。
///
/// 字段与 [kBillTemplateFields] 一一对应（顺序除外）。交易级全量字段（Phase 1）：
/// 业务模块 [module]、标签 [tags]、账本名 [book]、优惠 [discountMinor]、
/// 手续费 [feeMinor]、子分类 [subcategoryName]、
/// 报销开关 / 报销账户 [isReimbursable] / [reimbursementAccount]、
/// 不计预算 / 不计收支 [excludeFromBudget] / [excludeFromStats]。
/// 借还 / 储蓄 / 分期 / 投资 / 报销等独立台账由对应阶段落地；其中借还（Phase 2）
/// 已支持按固定分类名路由到借还台账（见 [parseLendOp]），储蓄（Phase 2）已支持按
/// 「转入账户」= 计划名路由到储蓄台账（建/匹配目标 + 逐期存入），其余模块仍仅打标落交易。
class BillRow {
  const BillRow({
    required this.occurredAt,
    required this.type,
    required this.amountMinor,
    required this.accountName,
    this.toAccountName,
    this.module = SourceModule.ledger,
    this.categoryName,
    this.subcategoryName,
    this.discountMinor = 0,
    this.feeMinor = 0,
    this.tags = const <String>[],
    this.book,
    this.isReimbursable = false,
    this.reimbursementAccount,
    this.excludeFromBudget = false,
    this.excludeFromStats = false,
    this.note,
    this.currency = 'CNY',
    this.confidence,
    this.counterparty,
    this.placeName,
    this.latitude,
    this.longitude,
  });

  /// 发生时间（本地时区）。
  final DateTime occurredAt;
  final TxnType type;

  /// 金额（分）。收入 / 支出为实际金额；转账为转入到账金额。
  final int amountMinor;
  final String accountName;
  final String? toAccountName;

  /// 业务来源模块（见 [SourceModule]）。默认 [SourceModule.ledger]，即日常记账。
  final SourceModule module;
  final String? categoryName;

  /// 优惠金额（分）。实付 = 金额 − 优惠。
  final int discountMinor;

  /// 手续费（分）。如银行 / 第三方转账手续费；一般场景为 0。仅作记录项签，
  /// 不参与余额扣减（转账实付已在记一笔侧用 fromAmount 表达）。
  final int feeMinor;

  /// 子分类名称（自由文本，非结构化）。与 [categoryName] 解耦：分类是结构化类目、
  /// 参与统计归集，子分类只是可选项签，不影响任何聚合。
  final String? subcategoryName;

  /// 标签列表（导出逗号拼接，导入按逗号拆分）。
  final List<String> tags;

  /// 账本名称（按名称归户到对应账本；为空归当前账本）。
  final String? book;

  /// 是否可报销（挂账到报销账户）。
  final bool isReimbursable;

  /// 报销账户名称（[isReimbursable]=true 时有效）。
  final String? reimbursementAccount;

  /// 是否不计入预算。
  final bool excludeFromBudget;

  /// 是否不计入收支统计。
  final bool excludeFromStats;

  /// 借还「对方」（借款人 / 出借人 / 债务方名）。仅 [module]=借还 且分类为
  /// 6 类固定名（借入/借出/还债/收债/债务消减/坏账计提）时用于路由到借还台账，
  /// 对应 [LendRepository] 强制要求的 counterparty；其余模块恒为 null。
  final String? counterparty;

  final String? note;
  final String currency;

  /// 识别置信度（0~1），仅截图 / OCR 识别来源填充；CSV / JSON 导入为 null。
  /// 低于 [kLowConfidence] 的字段在确认页标「需复核」。
  final double? confidence;

  /// 位置信息（可选）：语义化地名（小区/店名级）+ WGS-84 坐标。
  /// 导出附加三列（CSV）/三个键（JSON），导入解析后随流水落库恢复定位显示。
  final String? placeName;
  final double? latitude;
  final double? longitude;

  /// 复制并修改部分字段。
  BillRow copyWith({
    DateTime? occurredAt,
    TxnType? type,
    int? amountMinor,
    String? accountName,
    String? toAccountName,
    SourceModule? module,
    String? categoryName,
    String? subcategoryName,
    int? discountMinor,
    int? feeMinor,
    List<String>? tags,
    String? book,
    bool? isReimbursable,
    String? reimbursementAccount,
    bool? excludeFromBudget,
    bool? excludeFromStats,
    String? counterparty,
    String? note,
    String? currency,
    double? confidence,
    String? placeName,
    double? latitude,
    double? longitude,
  }) {
    return BillRow(
      occurredAt: occurredAt ?? this.occurredAt,
      type: type ?? this.type,
      amountMinor: amountMinor ?? this.amountMinor,
      accountName: accountName ?? this.accountName,
      toAccountName: toAccountName ?? this.toAccountName,
      module: module ?? this.module,
      categoryName: categoryName ?? this.categoryName,
      subcategoryName: subcategoryName ?? this.subcategoryName,
      discountMinor: discountMinor ?? this.discountMinor,
      feeMinor: feeMinor ?? this.feeMinor,
      tags: tags ?? this.tags,
      book: book ?? this.book,
      isReimbursable: isReimbursable ?? this.isReimbursable,
      reimbursementAccount: reimbursementAccount ?? this.reimbursementAccount,
      excludeFromBudget: excludeFromBudget ?? this.excludeFromBudget,
      excludeFromStats: excludeFromStats ?? this.excludeFromStats,
      counterparty: counterparty ?? this.counterparty,
      note: note ?? this.note,
      currency: currency ?? this.currency,
      confidence: confidence ?? this.confidence,
      placeName: placeName ?? this.placeName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

/// 低于该置信度的字段在确认页高亮提示用户复核。
const double kLowConfidence = 0.6;

/// CSV 表头（导出与解析都据此定位列）。顺序与 [kBillTemplateFields] 一致。
const List<String> _kCsvHeader = <String>[
  '日期',
  '模块',
  '类型',
  '金额',
  '账户',
  '转入账户',
  '对方',
  '优惠',
  '手续费',
  '分类',
  '子分类',
  '标签',
  '账本',
  '可报销',
  '报销账户',
  '不计预算',
  '不计收支',
  '备注',
  '位置',
  '纬度',
  '经度',
];

String _formatDate(DateTime dt) => DateFormat('yyyy-MM-dd HH:mm').format(dt);

/// 公开版宽松日期解析（供第三方账单解析复用）：兼容 `-` / `/` 分隔、
/// 月/日/时/分不补零、秒可省略；拒绝非法日期（如 2 月 30 日回滚）。
DateTime? parseBillDateLoose(String raw) => _parseDate(raw);

DateTime? _parseDate(String raw) {
  final String s = raw.trim();
  if (s.isEmpty) return null;
  // 统一走自写的宽松解析：同时兼容严格格式（yyyy-MM-dd HH:mm，正则本就匹配）
  // 与微信等导出的宽松写法（斜杠分隔、月/日/时/分不补零，如 2026-9-29 17:31）。
  // 不走 DateTime.tryParse 兜底——它会对非法日期（如 2/30）静默回滚到 3 月，
  // 导致脏数据被静默接受（详见 _parseLooseDate 的二次校验）。
  return _parseLooseDate(s);
}

/// 解析「年-月-日 时:分[:秒]」的宽松变体：允许 `-` 与 `/` 混用、月/日/时/分/秒
/// 不补零，且秒可省略。归一化为严格格式再校验，拒绝非法日期（含回滚，如 2 月 30 日）。
DateTime? _parseLooseDate(String raw) {
  final RegExp re = RegExp(
    r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})'
    r'(?:[ Tt](\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?$',
  );
  final Match? m = re.firstMatch(raw);
  if (m == null) return null;
  final int y = int.parse(m.group(1)!);
  final int mo = int.parse(m.group(2)!);
  final int d = int.parse(m.group(3)!);
  final int hh = m.group(4) == null ? 0 : int.parse(m.group(4)!);
  final int mm = m.group(5) == null ? 0 : int.parse(m.group(5)!);
  final int ss = m.group(6) == null ? 0 : int.parse(m.group(6)!);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  if (hh > 23 || mm > 59 || ss > 59) return null;
  final DateTime dt = DateTime(y, mo, d, hh, mm, ss);
  // 二次校验，拒绝回滚（如 2026-02-30 被 Dart 解析成 3 月）。
  if (dt.year != y || dt.month != mo || dt.day != d) return null;
  return dt;
}

TxnType? _parseType(String raw) {
  final String s = raw.trim();
  if (s.isEmpty) return null;
  final String lower = s.toLowerCase();
  if (lower == 'income' || s == '收入' || s == '收') return TxnType.income;
  if (lower == 'expense' || s == '支出' || s == '支') return TxnType.expense;
  if (lower == 'transfer' || s == '转账' || s == '转') return TxnType.transfer;
  return null;
}

SourceModule? _parseModule(String raw) {
  final String s = raw.trim();
  if (s.isEmpty) return null;
  final String lower = s.toLowerCase();
  for (final SourceModule m in SourceModule.values) {
    if (m.name.toLowerCase() == lower || m.label == s) return m;
  }
  return null;
}

String _amountLabel(int minor, String currency) =>
    Money.fromMinor(minor, currency: currency).format(showSymbol: false);

String _boolLabel(bool v) => v ? 'Y' : 'N';

int _parseDiscount(String raw) {
  final String s = raw.trim();
  if (s.isEmpty) return 0;
  return Money.tryParse(s).minor;
}

int _parseFee(String raw) {
  final String s = raw.trim();
  if (s.isEmpty) return 0;
  return Money.tryParse(s).minor;
}

bool _parseBool(String raw) {
  final String s = raw.trim().toLowerCase();
  return s == 'y' || s == 'true' || s == '是' || s == '1';
}

List<String> _parseTags(String raw) {
  final String s = raw.trim();
  if (s.isEmpty) return const <String>[];
  return s
      .split(',')
      .map((String e) => e.trim())
      .where((String e) => e.isNotEmpty)
      .toList();
}

List<String> _parseJsonTags(dynamic v) {
  if (v == null) return const <String>[];
  if (v is List) {
    return v
        .map((dynamic e) => e.toString().trim())
        .where((String e) => e.isNotEmpty)
        .toList();
  }
  if (v is String) return _parseTags(v);
  return const <String>[];
}

String _nullIfEmpty(String s) {
  final String t = s.trim();
  return t.isEmpty ? '' : t;
}

/// 账户段 / 账单段的分段标记行（CSV 单文件双段，v3）。
///
/// 旧文件没有标记 → 整个文件按账单段解析（向后兼容）。标记行形如
/// `# [账户]`，以 `#` 开头所以不会被当成数据行，用户阅读时也一眼可见。
const String kAccountSectionMarker = '# [账户]';
const String kBillSectionMarker = '# [账单]';

/// 导出为 CSV 文本（含表头）。备注里的逗号 / 换行由 [ListToCsvConverter] 自动转义。
///
/// [accounts] 非空时输出「账户段 + 账单段」双段文件（v3，用于在新系统复原
/// 账户信息）；为空时保持旧单段账单格式，向后兼容。
String buildCsv(List<BillRow> rows, {List<AccountRow> accounts = const []}) {
  final List<List<dynamic>> table = <List<dynamic>>[
    _kCsvHeader,
    for (final BillRow r in rows)
      <dynamic>[
        _formatDate(r.occurredAt),
        r.module.label,
        r.type.label,
        _amountLabel(r.amountMinor, r.currency),
        r.accountName,
        r.toAccountName ?? '',
        r.counterparty ?? '',
        _amountLabel(r.discountMinor, r.currency),
        _amountLabel(r.feeMinor, r.currency),
        r.categoryName ?? '',
        r.subcategoryName ?? '',
        r.tags.join(','),
        r.book ?? '',
        _boolLabel(r.isReimbursable),
        r.reimbursementAccount ?? '',
        _boolLabel(r.excludeFromBudget),
        _boolLabel(r.excludeFromStats),
        r.note ?? '',
        r.placeName ?? '',
        r.latitude?.toStringAsFixed(6) ?? '',
        r.longitude?.toStringAsFixed(6) ?? '',
      ],
  ];
  final String bills = const ListToCsvConverter(eol: '\n').convert(table);
  if (accounts.isEmpty) return bills;
  return <String>[
    '$kAccountSectionMarker\n'
        '${const ListToCsvConverter(eol: '\n').convert(<List<dynamic>>[
          kAccountCsvHeader,
          for (final AccountRow a in accounts) accountRowToCsvCells(a),
        ])}',
    '$kBillSectionMarker\n$bills',
  ].join('\n');
}

/// 导出为 JSON 文本。
///
/// [accounts] 非空时输出 `{accounts:[…], bills:[…]}` 包裹结构（v3）；为空时
/// 保持旧账单数组结构，向后兼容（导入侧两种都能读）。
String buildJson(List<BillRow> rows, {List<AccountRow> accounts = const []}) {
  final List<Map<String, dynamic>> list = <Map<String, dynamic>>[
    for (final BillRow r in rows)
      <String, dynamic>{
        'date': _formatDate(r.occurredAt),
        'module': r.module.label,
        'type': r.type.label,
        'amount': Money.fromMinor(r.amountMinor, currency: r.currency).decimal,
        'account': r.accountName,
        'toAccount': r.toAccountName ?? '',
        'counterparty': r.counterparty ?? '',
        'discount':
            Money.fromMinor(r.discountMinor, currency: r.currency).decimal,
        'fee': Money.fromMinor(r.feeMinor, currency: r.currency).decimal,
        'category': r.categoryName ?? '',
        'subcategory': r.subcategoryName ?? '',
        'tags': r.tags,
        'book': r.book ?? '',
        'isReimbursable': r.isReimbursable,
        'reimbursementAccount': r.reimbursementAccount ?? '',
        'excludeFromBudget': r.excludeFromBudget,
        'excludeFromStats': r.excludeFromStats,
        'note': r.note ?? '',
        'currency': r.currency,
        if (r.placeName != null) 'placeName': r.placeName,
        if (r.latitude != null) 'latitude': r.latitude,
        if (r.longitude != null) 'longitude': r.longitude,
      },
  ];
  if (accounts.isEmpty) return jsonEncode(list);
  return jsonEncode(<String, dynamic>{
    'accounts': <Map<String, dynamic>>[
      for (final AccountRow a in accounts) accountRowToJson(a),
    ],
    'bills': list,
  });
}

/// 解析结果：成功解析的账单行 / 账户行 + 每一条无法解析的记录（带行号 / 原因）。
class ParseResult {
  const ParseResult(
    this.rows,
    this.errors, {
    this.accounts = const <AccountRow>[],
  });

  final List<BillRow> rows;

  /// 账户段（v3 导出文件 / 模板自带；旧文件为空）。
  final List<AccountRow> accounts;
  final List<String> errors;

  bool get hasErrors => errors.isNotEmpty;
}

/// 文件是否含可导入内容：账单行或账户段任一非空即算「已识别」。
///
/// v3 起导出文件是双段结构，**纯账户文件**（只有 `# [账户]` 段、账单段为空，
/// 如「33 张卡片截图整理」的账户数据文件）同样应当可导入。旧门禁只看
/// `rows.isEmpty`，纯账户文件会被「请先选择账单文件」挡死——即实机反馈的
/// 「识别不到」。导入链路（预览 / 冲突 / 进度 / 结果文案）均以本函数为准。
bool hasImportableContent(ParseResult r) =>
    r.rows.isNotEmpty || r.accounts.isNotEmpty;

/// 自动识别 CSV / JSON 并把内容解析成 [BillRow] 列表。
///
/// 以 `[` 或 `{` 开头视为 JSON，否则按 CSV 处理。空内容返回空结果。
ParseResult parseInput(String content) {
  final String trimmed = content.trim();
  if (trimmed.isEmpty) return const ParseResult(<BillRow>[], <String>[]);
  if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
    return _parseJson(trimmed);
  }
  return _parseCsv(trimmed);
}

ParseResult _parseCsv(String content) {
  // 模板系统（bill_template.dart）：以 # 开头的行是填写说明，导入时忽略，
  // 用户无需手动删除模板里的注释行。v3 起 `# [账户]` / `# [账单]` 是分段
  // 标记：账户段在前、账单段在后；旧文件无标记 → 全部按账单段解析。
  final List<String> lines = content.replaceAll('\r', '').split('\n');
  bool sawMarker = false;
  bool inAccounts = false;
  final List<String> billLines = <String>[];
  final List<String> accountLines = <String>[];
  for (final String line in lines) {
    final String t = line.trim();
    if (t == kAccountSectionMarker || t == '# [accounts]') {
      sawMarker = true;
      inAccounts = true;
      continue;
    }
    if (t == kBillSectionMarker || t == '# [bills]') {
      sawMarker = true;
      inAccounts = false;
      continue;
    }
    if (t.trimLeft().startsWith('#')) continue;
    (inAccounts && sawMarker ? accountLines : billLines).add(line);
  }
  final ParseResult accountsResult = _parseAccountCsvSection(accountLines);
  final ParseResult billsResult = _parseBillCsvSection(billLines);
  return ParseResult(
    billsResult.rows,
    <String>[...accountsResult.errors, ...billsResult.errors],
    accounts: accountsResult.accounts,
  );
}

/// 账户段（一组 CSV 行，首行表头）→ [AccountRow]；表头缺列按空处理。
ParseResult _parseAccountCsvSection(List<String> lines) {
  // 去掉尾部空行（模板 / 导出文件常以换行收尾），避免空行报「账户名为空」。
  while (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines = lines.sublist(0, lines.length - 1);
  }
  if (lines.isEmpty) return const ParseResult(<BillRow>[], <String>[]);
  final List<List<dynamic>> table =
      const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
          .convert(lines.join('\n'));
  if (table.isEmpty) return const ParseResult(<BillRow>[], <String>[]);
  final List<String> errors = <String>[];
  final List<AccountRow> accounts = <AccountRow>[];

  final Map<String, int> idx = <String, int>{};
  final List<dynamic> header = table.first;
  for (int i = 0; i < header.length; i++) {
    idx[header[i].toString().trim()] = i;
  }
  int col(String name) => idx[name] ?? -1;

  final int headerLen = header.length;
  for (int r = 1; r < table.length; r++) {
    List<dynamic> raw = List<dynamic>.from(table[r]);
    final String lineNo = '账户段第$r行';
    // 兼容：手写 / 旧导出常在「还款日 / 信用卡额度」等空字段处多打一个空逗号
    // （如「19,,,20」），导致整行右移一列被当成 14 列而整行丢弃。这里先还原
    // 对齐（只丢空列、绝不丢有内容的列），还原后再判列数。
    raw = _recoverAccountRow(raw, headerLen);
    if (raw.length > headerLen) {
      errors.add('$lineNo：列数（${raw.length}）超出表头（$headerLen），'
          '请检查是否有多余的逗号或漏写引号');
      continue;
    }
    final List<dynamic> line = List<dynamic>.filled(headerLen, '');
    for (int i = 0; i < raw.length; i++) {
      line[i] = raw[i];
    }
    // 全空行（多余换行）静默跳过，不计错误。
    if (line.every((dynamic c) => c.toString().trim().isEmpty)) continue;
    final AccountRow? row = parseAccountCsvRow(
      line: line,
      lineNo: lineNo,
      iBook: col('账本'),
      iName: col('账户名'),
      iType: col('类型'),
      iCurrency: col('币种'),
      iBalance: col('余额'),
      iCreditLimit: col('信用卡额度'),
      iBilling: col('账单日'),
      iDue: col('还款日'),
      iGrace: col('免息期'),
      iCard: col('卡号'),
      iStatus: col('状态'),
      iInclude: col('计入总资产'),
      iSort: col('排序'),
      errors: errors,
    );
    if (row != null) accounts.add(row);
  }
  return ParseResult(const <BillRow>[], errors, accounts: accounts);
}

/// 还原账户段数据行对齐：当列数多于表头时，丢弃多余的空列。
///
/// 典型成因：手写 CSV 在「还款日 / 信用卡额度」为空时多打了一个逗号
/// （如「19,,,20」），整行右移一列。策略：
/// ① 先去掉行尾空列；
/// ② 右对齐真实数据恒定非空的尾部列（卡号 / 状态 / 计入总资产 / 排序），
///    把「中部」多出的空列丢弃，使前列（账本..免息期）重新对齐。
/// 只丢空列、绝不丢有内容的列；若仍无法对齐（多出的列含内容），
/// 原样返回交由调用方报结构性错误。
List<dynamic> _recoverAccountRow(List<dynamic> cells, int headerLen) {
  List<dynamic> out = List<dynamic>.from(cells);
  // ① 去尾部空列
  while (out.isNotEmpty && out.last.toString().trim().isEmpty) {
    out.removeLast();
  }
  if (out.length <= headerLen) return out;
  // ② 右对齐尾部 4 列（卡号 / 状态 / 计入总资产 / 排序），还原前列
  const int anchorTail = 4;
  if (out.length - anchorTail < 0) return out;
  final List<dynamic> tail = out.sublist(out.length - anchorTail);
  final List<dynamic> lead = out.sublist(0, out.length - anchorTail);
  final int leadTarget = headerLen - anchorTail;
  while (lead.length > leadTarget) {
    int? lastEmpty;
    for (int i = lead.length - 1; i >= 0; i--) {
      if (lead[i].toString().trim().isEmpty) {
        lastEmpty = i;
        break;
      }
    }
    if (lastEmpty == null) break; // 多出的列含内容，无法安全还原
    lead.removeAt(lastEmpty);
  }
  if (lead.length == leadTarget) return <dynamic>[...lead, ...tail];
  return out; // 还原失败，交调用方报错
}

/// 账单段（一组 CSV 行，首行表头）→ [BillRow]；逻辑与旧单段解析完全一致。
ParseResult _parseBillCsvSection(List<String> lines) {
  final String filtered = lines.join('\n');
  final List<BillRow> rows = <BillRow>[];
  final List<String> errors = <String>[];
  final List<List<dynamic>> table =
      const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
          .convert(filtered);
  if (table.isEmpty) return const ParseResult(<BillRow>[], <String>[]);

  // 表头 → 列索引（按中文表头定位，缺列时回退到 -1 表示无此列）。
  final Map<String, int> idx = <String, int>{};
  final List<dynamic> header = table.first;
  for (int i = 0; i < header.length; i++) {
    idx[header[i].toString().trim()] = i;
  }
  int col(String name) => idx[name] ?? -1;
  final int iDate = col('日期');
  final int iModule = col('模块');
  final int iType = col('类型');
  final int iAmount = col('金额');
  final int iAccount = col('账户');
  final int iTo = col('转入账户');
  final int iCounterparty = col('对方');
  final int iDiscount = col('优惠');
  final int iFee = col('手续费');
  final int iCat = col('分类');
  final int iSubcat = col('子分类');
  final int iTags = col('标签');
  final int iBook = col('账本');
  final int iReimb = col('可报销');
  final int iReimbAcc = col('报销账户');
  final int iExclBudget = col('不计预算');
  final int iExclStats = col('不计收支');
  final int iNote = col('备注');
  // 位置三列（可选，旧导出文件无这些列 → -1，按空处理）。
  final int iPlace = col('位置');
  final int iLat = col('纬度');
  final int iLng = col('经度');

  // 列数守门：表头长度即合法列数。数据行若多出列（多半是某字段漏写引号 /
  // 多出逗号），会导致后续字段整体串位 → 直接报错，避免静默错读。
  // 少于表头长度（行尾缺列）则补空，不影响已填字段。
  final int headerLen = header.length;

  for (int r = 1; r < table.length; r++) {
    final List<dynamic> raw = table[r];
    final String lineNo = '第$r行';
    if (raw.length > headerLen) {
      errors.add('$lineNo：列数（${raw.length}）超出表头（$headerLen），'
          '请检查是否有多余的逗号或漏写引号');
      continue;
    }
    // 补齐到表头长度，避免行尾缺列时越界或串读。
    final List<dynamic> line = List<dynamic>.filled(headerLen, '');
    for (int i = 0; i < raw.length; i++) {
      line[i] = raw[i];
    }
    String cell(int i) =>
        i < 0 || i >= line.length ? '' : line[i].toString().trim();

    final DateTime? dt = _parseDate(cell(iDate));
    if (dt == null) {
      errors.add('$lineNo：日期无法识别');
      continue;
    }
    final TxnType? type = _parseType(cell(iType));
    if (type == null) {
      errors.add('$lineNo：类型无法识别（应为 收入 / 支出 / 转账）');
      continue;
    }
    final SourceModule module =
        _parseModule(cell(iModule)) ?? SourceModule.ledger;
    final int amount = Money.tryParse(cell(iAmount)).minor;
    final String catTrim = _nullIfEmpty(cell(iCat));
    final String? categoryName = catTrim.isEmpty ? null : catTrim;
    final String subcatTrim = _nullIfEmpty(cell(iSubcat));
    final String? subcategoryName = subcatTrim.isEmpty ? null : subcatTrim;
    // 借还路由行：债务消减/坏账计提无需真实资产账户，账户可空；其余行账户必填。
    final LendOp? lendOp =
        module == SourceModule.lend ? parseLendOp(categoryName) : null;
    final String account = cell(iAccount);
    final bool accountRequired = lendOp == null || lendOpNeedsAccount(lendOp);
    // 储蓄模块账户可空（= 灵活存入，无联动流水）；其余行账户必填。
    if (account.isEmpty && accountRequired && module != SourceModule.savings) {
      errors.add('$lineNo：账户为空');
      continue;
    }
    final String cpRaw = cell(iCounterparty);
    final String? counterparty = cpRaw.isEmpty ? null : cpRaw;
    final String toRaw = cell(iTo);
    final String? toAccount = toRaw.isEmpty ? null : toRaw;
    if (type == TxnType.transfer && toAccount == null) {
      errors.add('$lineNo：转账缺少转入账户');
      continue;
    }
    final int discount = _parseDiscount(cell(iDiscount));
    final int fee = _parseFee(cell(iFee));
    final List<String> tags = _parseTags(cell(iTags));
    final String bookTrim = _nullIfEmpty(cell(iBook));
    final String? book = bookTrim.isEmpty ? null : bookTrim;
    final bool isReimbursable = _parseBool(cell(iReimb));
    final String reimbAccTrim = _nullIfEmpty(cell(iReimbAcc));
    final String? reimbursementAccount =
        reimbAccTrim.isEmpty ? null : reimbAccTrim;
    final bool excludeFromBudget = _parseBool(cell(iExclBudget));
    final bool excludeFromStats = _parseBool(cell(iExclStats));
    final String noteTrim = _nullIfEmpty(cell(iNote));
    final String? note = noteTrim.isEmpty ? null : noteTrim;
    final String placeTrim = _nullIfEmpty(cell(iPlace));
    final String? placeName = placeTrim.isEmpty ? null : placeTrim;
    final double? latitude = double.tryParse(cell(iLat).trim());
    final double? longitude = double.tryParse(cell(iLng).trim());

    rows.add(
      BillRow(
        occurredAt: dt,
        module: module,
        type: type,
        amountMinor: amount,
        accountName: account,
        toAccountName: toAccount,
        categoryName: categoryName,
        subcategoryName: subcategoryName,
        discountMinor: discount,
        feeMinor: fee,
        tags: tags,
        book: book,
        isReimbursable: isReimbursable,
        reimbursementAccount: reimbursementAccount,
        excludeFromBudget: excludeFromBudget,
        excludeFromStats: excludeFromStats,
        note: note,
        currency: 'CNY',
        counterparty: counterparty,
        placeName: placeName,
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }
  return ParseResult(rows, errors);
}

ParseResult _parseJson(String content) {
  final List<BillRow> rows = <BillRow>[];
  final List<AccountRow> accounts = <AccountRow>[];
  final List<String> errors = <String>[];
  try {
    final dynamic decoded = jsonDecode(content);
    // 模板系统：本 App 生成的空白模板是 {_template:…, bills:[…]} 结构，
    // 账单数据在 bills 键下；v3 起另有 accounts 键装账户段。
    // 兼容旧格式（裸数组或单对象）。
    final dynamic bills = decoded is Map
        ? (decoded['bills'] is List ? decoded['bills'] : decoded)
        : decoded;
    if (decoded is Map && decoded['accounts'] is List) {
      final List<dynamic> accList = decoded['accounts'] as List<dynamic>;
      for (int i = 0; i < accList.length; i++) {
        final dynamic item = accList[i];
        if (item is! Map) {
          errors.add('账户段第${i + 1}项：不是对象');
          continue;
        }
        final AccountRow? row = parseAccountJsonRow(
          item.cast<String, dynamic>(),
          lineNo: '账户段第${i + 1}项',
          errors: errors,
        );
        if (row != null) accounts.add(row);
      }
    }
    final List<dynamic> list = bills is List ? bills : <dynamic>[bills];
    for (int i = 0; i < list.length; i++) {
      final dynamic item = list[i];
      if (item is! Map) {
        errors.add('第${i + 1}项：不是对象');
        continue;
      }
      final Map<String, dynamic> m = item.cast<String, dynamic>();
      final String lineNo = '第${i + 1}项';
      final DateTime? dt = _parseDate((m['date'] ?? '').toString());
      if (dt == null) {
        errors.add('$lineNo：日期无法识别');
        continue;
      }
      final TxnType? type = _parseType((m['type'] ?? '').toString());
      if (type == null) {
        errors.add('$lineNo：类型无法识别（应为 收入 / 支出 / 转账）');
        continue;
      }
      final SourceModule module =
          _parseModule((m['module'] ?? '').toString()) ?? SourceModule.ledger;
      final int amount = Money.tryParse((m['amount'] ?? '').toString()).minor;
      final String catRaw = _nullIfEmpty((m['category'] ?? '').toString());
      final String? categoryName = catRaw.isEmpty ? null : catRaw;
      // 借还路由行：债务消减/坏账计提无需真实资产账户，账户可空；其余行账户必填。
      final LendOp? lendOp =
          module == SourceModule.lend ? parseLendOp(categoryName) : null;
      final String account = (m['account'] ?? '').toString().trim();
      final bool accountRequired = lendOp == null || lendOpNeedsAccount(lendOp);
      // 储蓄模块账户可空（= 灵活存入，无联动流水）；其余行账户必填。
      if (account.isEmpty &&
          accountRequired &&
          module != SourceModule.savings) {
        errors.add('$lineNo：账户为空');
        continue;
      }
      final String cpRaw = (m['counterparty'] ?? '').toString().trim();
      final String? counterparty = cpRaw.isEmpty ? null : cpRaw;
      final String toRaw = (m['toAccount'] ?? '').toString().trim();
      final String? toAccount = toRaw.isEmpty ? null : toRaw;
      if (type == TxnType.transfer && toAccount == null) {
        errors.add('$lineNo：转账缺少转入账户');
        continue;
      }
      final int discount = _parseDiscount((m['discount'] ?? '').toString());
      final int fee = _parseFee((m['fee'] ?? '').toString());
      final List<String> tags = _parseJsonTags(m['tags']);
      final String subcatRaw =
          _nullIfEmpty((m['subcategory'] ?? '').toString());
      final String? subcategoryName = subcatRaw.isEmpty ? null : subcatRaw;
      final String bookRaw = _nullIfEmpty((m['book'] ?? '').toString());
      final String? book = bookRaw.isEmpty ? null : bookRaw;
      final bool isReimbursable =
          _parseBool((m['isReimbursable'] ?? '').toString());
      final String reimbAccRaw =
          _nullIfEmpty((m['reimbursementAccount'] ?? '').toString());
      final String? reimbursementAccount =
          reimbAccRaw.isEmpty ? null : reimbAccRaw;
      final bool excludeFromBudget =
          _parseBool((m['excludeFromBudget'] ?? '').toString());
      final bool excludeFromStats =
          _parseBool((m['excludeFromStats'] ?? '').toString());
      final String noteRaw = _nullIfEmpty((m['note'] ?? '').toString());
      final String? note = noteRaw.isEmpty ? null : noteRaw;
      final String placeRaw = _nullIfEmpty((m['placeName'] ?? '').toString());
      final String? placeName = placeRaw.isEmpty ? null : placeRaw;
      final double? latitude = (m['latitude'] as num?)?.toDouble();
      final double? longitude = (m['longitude'] as num?)?.toDouble();

      rows.add(
        BillRow(
          occurredAt: dt,
          module: module,
          type: type,
          amountMinor: amount,
          accountName: account,
          toAccountName: toAccount,
          categoryName: categoryName,
          subcategoryName: subcategoryName,
          discountMinor: discount,
          feeMinor: fee,
          tags: tags,
          book: book,
          isReimbursable: isReimbursable,
          reimbursementAccount: reimbursementAccount,
          excludeFromBudget: excludeFromBudget,
          excludeFromStats: excludeFromStats,
          note: note,
          currency: (m['currency'] ?? 'CNY').toString(),
          counterparty: counterparty,
          placeName: placeName,
          latitude: latitude,
          longitude: longitude,
        ),
      );
    }
  } on FormatException catch (e) {
    errors.add('JSON 解析失败：$e');
  }
  return ParseResult(rows, errors, accounts: accounts);
}

// ───────────────────── 借还路由（Phase 2） ─────────────────────

/// 借还 6 子类操作：由 [categoryName]（固定分类名）解析得到，再路由到
/// [LendRepository] 的对应方法，而非只打标记落普通交易。
///
/// 组合 = 方向(借入 borrowIn / 借出 lendOut) × 操作(本金 add / 还款 repay /
/// 冲减备忘 debtReduction)：
/// - 借入 / 借出 → [LendRepository.add]（建本金记录 + 资金流水）；
/// - 还债 / 收债 → [LendRepository.repay]（冲销未结清债务 + 可选资金流水）；
/// - 债务消减 / 坏账计提 → [LendRepository.debtReduction]（记账备忘冲减）。
enum LendOp {
  borrowAdd, // 借入
  lendAdd, // 借出
  borrowRepay, // 还债
  lendCollect, // 收债
  borrowReduce, // 债务消减
  lendBadDebt, // 坏账计提
}

/// 固定分类名 → 借还操作（与 [LendRepository] 内部 `_flowCategoryId` 的系统
/// 类目名一一对应）。非 6 类固定名返回 null。
const Map<String, LendOp> _kLendOpByName = <String, LendOp>{
  '借入': LendOp.borrowAdd,
  '借出': LendOp.lendAdd,
  '还债': LendOp.borrowRepay,
  '收债': LendOp.lendCollect,
  '债务消减': LendOp.borrowReduce,
  '坏账计提': LendOp.lendBadDebt,
};

/// 把分类名解析为借还操作；非 6 类固定名 / 空返回 null。
LendOp? parseLendOp(String? name) {
  if (name == null) return null;
  return _kLendOpByName[name.trim()];
}

/// 借还操作对应的借贷方向。
LendDirection lendOpDirection(LendOp op) {
  switch (op) {
    case LendOp.borrowAdd:
    case LendOp.borrowRepay:
    case LendOp.borrowReduce:
      return LendDirection.borrowIn;
    case LendOp.lendAdd:
    case LendOp.lendCollect:
    case LendOp.lendBadDebt:
      return LendDirection.lendOut;
  }
}

/// 该借还操作是否需要真实资产账户（落资金流水）：
/// 借入/借出/还债/收债需要；债务消减/坏账计提无需（仅记账备忘）。
bool lendOpNeedsAccount(LendOp op) =>
    op == LendOp.borrowAdd ||
    op == LendOp.lendAdd ||
    op == LendOp.borrowRepay ||
    op == LendOp.lendCollect;

/// 导入行序修正：借入/借出（add）行稳定前置，其余行保持原相对顺序。
///
/// 根因：导出按 `occurredAt DESC`（见 `transactions_dao.watchAll`），CSV 里
/// 「收债/还债」（发生更晚）排在「借出/借入」（更早）之前；导入按文件顺序
/// 逐行处理时，冲销行的债务尚未落库，`_offsetDebts` 抛
/// 「未找到可收债的「XXX」未结清债务」——整行计入 skipped（2026-10-22
/// 真机反馈：导出再导入，9 条收债全报此错）。
///
/// 稳定分区（非排序）：add 行内部、非 add 行内部都维持原相对顺序，
/// 只保证「同批导入中所有债务先建立、再冲销」。储蓄/分期/投资等模块
/// 的行相对顺序不受影响（它们本就依赖稳定分区外的原序）。
List<BillRow> reorderLendRowsForImport(List<BillRow> rows) {
  final List<BillRow> addRows = <BillRow>[];
  final List<BillRow> rest = <BillRow>[];
  for (final BillRow row in rows) {
    final LendOp? op =
        row.module == SourceModule.lend ? parseLendOp(row.categoryName) : null;
    if (op == LendOp.borrowAdd || op == LendOp.lendAdd) {
      addRows.add(row);
    } else {
      rest.add(row);
    }
  }
  return <BillRow>[...addRows, ...rest];
}
