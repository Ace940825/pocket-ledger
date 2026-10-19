import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';

/// 一笔可导入 / 导出的账单（与数据库无关的中间表示）。
///
/// 导入侧把 CSV / JSON 解析成 [BillRow]，导出侧把库内流水投影成 [BillRow]，
/// 二者共用同一套字段，保证「导出 → 导入」可无损往返（账户 / 分类按名称
/// 重新归户，见 bill_import_page）。
///
/// 字段与 [kBillTemplateFields] 一一对应（顺序除外）。交易级全量字段（Phase 1）：
/// 业务模块 [module]、标签 [tags]、账本名 [book]、优惠 [discountMinor]、
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
    this.discountMinor = 0,
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
  '分类',
  '标签',
  '账本',
  '可报销',
  '报销账户',
  '不计预算',
  '不计收支',
  '备注',
];

String _formatDate(DateTime dt) => DateFormat('yyyy-MM-dd HH:mm').format(dt);

DateTime? _parseDate(String raw) {
  final String s = raw.trim();
  if (s.isEmpty) return null;
  // CSV 里通常是 "yyyy-MM-dd HH:mm"，DateTime.tryParse 只认 'T' 分隔，先归一化。
  final DateTime? withT = DateTime.tryParse(s.replaceAll(' ', 'T'));
  if (withT != null) return withT;
  return DateTime.tryParse(s);
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

/// 导出为 CSV 文本（含表头）。备注里的逗号 / 换行由 [ListToCsvConverter] 自动转义。
String buildCsv(List<BillRow> rows) {
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
        r.categoryName ?? '',
        r.tags.join(','),
        r.book ?? '',
        _boolLabel(r.isReimbursable),
        r.reimbursementAccount ?? '',
        _boolLabel(r.excludeFromBudget),
        _boolLabel(r.excludeFromStats),
        r.note ?? '',
      ],
  ];
  return const ListToCsvConverter(eol: '\n').convert(table);
}

/// 导出为 JSON 文本（账单数组，元素键与 [_kJsonKeys] 一一对应）。
String buildJson(List<BillRow> rows) {
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
        'category': r.categoryName ?? '',
        'tags': r.tags,
        'book': r.book ?? '',
        'isReimbursable': r.isReimbursable,
        'reimbursementAccount': r.reimbursementAccount ?? '',
        'excludeFromBudget': r.excludeFromBudget,
        'excludeFromStats': r.excludeFromStats,
        'note': r.note ?? '',
        'currency': r.currency,
      },
  ];
  return jsonEncode(list);
}

/// 解析结果：成功解析的账单行 + 每一条无法解析的记录（带行号 / 原因）。
class ParseResult {
  const ParseResult(this.rows, this.errors);

  final List<BillRow> rows;
  final List<String> errors;

  bool get hasErrors => errors.isNotEmpty;
}

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
  // 用户无需手动删除模板里的注释行。
  final String filtered = content
      .replaceAll('\r', '')
      .split('\n')
      .where((String line) => !line.trimLeft().startsWith('#'))
      .join('\n');
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
  final int iCat = col('分类');
  final int iTags = col('标签');
  final int iBook = col('账本');
  final int iReimb = col('可报销');
  final int iReimbAcc = col('报销账户');
  final int iExclBudget = col('不计预算');
  final int iExclStats = col('不计收支');
  final int iNote = col('备注');

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
    final SourceModule module = _parseModule(cell(iModule)) ?? SourceModule.ledger;
    final int amount = Money.tryParse(cell(iAmount)).minor;
    final String catTrim = _nullIfEmpty(cell(iCat));
    final String? categoryName = catTrim.isEmpty ? null : catTrim;
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
    final List<String> tags = _parseTags(cell(iTags));
    final String bookTrim = _nullIfEmpty(cell(iBook));
    final String? book = bookTrim.isEmpty ? null : bookTrim;
    final bool isReimbursable = _parseBool(cell(iReimb));
    final String reimbAccTrim = _nullIfEmpty(cell(iReimbAcc));
    final String? reimbursementAccount = reimbAccTrim.isEmpty ? null : reimbAccTrim;
    final bool excludeFromBudget = _parseBool(cell(iExclBudget));
    final bool excludeFromStats = _parseBool(cell(iExclStats));
    final String noteTrim = _nullIfEmpty(cell(iNote));
    final String? note = noteTrim.isEmpty ? null : noteTrim;

    rows.add(
      BillRow(
        occurredAt: dt,
        module: module,
        type: type,
        amountMinor: amount,
        accountName: account,
        toAccountName: toAccount,
        categoryName: categoryName,
        discountMinor: discount,
        tags: tags,
        book: book,
        isReimbursable: isReimbursable,
        reimbursementAccount: reimbursementAccount,
        excludeFromBudget: excludeFromBudget,
        excludeFromStats: excludeFromStats,
        note: note,
        currency: 'CNY',
        counterparty: counterparty,
      ),
    );
  }
  return ParseResult(rows, errors);
}

ParseResult _parseJson(String content) {
  final List<BillRow> rows = <BillRow>[];
  final List<String> errors = <String>[];
  try {
    final dynamic decoded = jsonDecode(content);
    // 模板系统：本 App 生成的空白模板是 {_template:…, bills:[…]} 结构，
    // 账单数据在 bills 键下；兼容旧格式（裸数组或单对象）。
    final dynamic bills =
        decoded is Map && decoded['bills'] is List ? decoded['bills'] : decoded;
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
      final List<String> tags = _parseJsonTags(m['tags']);
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

      rows.add(
        BillRow(
          occurredAt: dt,
          module: module,
          type: type,
          amountMinor: amount,
          accountName: account,
          toAccountName: toAccount,
          categoryName: categoryName,
          discountMinor: discount,
          tags: tags,
          book: book,
          isReimbursable: isReimbursable,
          reimbursementAccount: reimbursementAccount,
          excludeFromBudget: excludeFromBudget,
          excludeFromStats: excludeFromStats,
          note: note,
          currency: (m['currency'] ?? 'CNY').toString(),
          counterparty: counterparty,
        ),
      );
    }
  } on FormatException catch (e) {
    errors.add('JSON 解析失败：$e');
  }
  return ParseResult(rows, errors);
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
