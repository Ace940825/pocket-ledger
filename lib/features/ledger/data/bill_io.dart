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
class BillRow {
  const BillRow({
    required this.occurredAt,
    required this.type,
    required this.amountMinor,
    required this.accountName,
    this.toAccountName,
    this.categoryName,
    this.note,
    this.currency = 'CNY',
    this.confidence,
  });

  /// 发生时间（本地时区）。
  final DateTime occurredAt;
  final TxnType type;

  /// 金额（分）。收入 / 支出为实际金额；转账为转入到账金额。
  final int amountMinor;
  final String accountName;
  final String? toAccountName;
  final String? categoryName;
  final String? note;
  final String currency;

  /// 识别置信度（0~1），仅截图 / OCR 识别来源填充；CSV / JSON 导入为 null。
  /// 低于 [_kLowConfidence] 的字段在确认页标「需复核」。
  final double? confidence;
}

/// 低于该置信度的字段在确认页高亮提示用户复核。
const double kLowConfidence = 0.6;

/// CSV 表头（导出与解析都据此定位列）。
const List<String> _kCsvHeader = <String>[
  '日期',
  '类型',
  '金额',
  '账户',
  '转入账户',
  '分类',
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

String _typeLabel(TxnType t) => switch (t) {
      TxnType.income => '收入',
      TxnType.expense => '支出',
      TxnType.transfer => '转账',
    };

String _amountLabel(int minor, String currency) =>
    Money.fromMinor(minor, currency: currency).format(showSymbol: false);

/// 导出为 CSV 文本（含表头）。备注里的逗号 / 换行由 [ListToCsvConverter] 自动转义。
String buildCsv(List<BillRow> rows) {
  final List<List<dynamic>> table = <List<dynamic>>[
    _kCsvHeader,
    for (final BillRow r in rows)
      <dynamic>[
        _formatDate(r.occurredAt),
        _typeLabel(r.type),
        _amountLabel(r.amountMinor, r.currency),
        r.accountName,
        r.toAccountName ?? '',
        r.categoryName ?? '',
        r.note ?? '',
      ],
  ];
  return const ListToCsvConverter(eol: '\n').convert(table);
}

/// 导出为 JSON 文本（账单数组，元素键与 CSV 表头一一对应）。
String buildJson(List<BillRow> rows) {
  final List<Map<String, dynamic>> list = <Map<String, dynamic>>[
    for (final BillRow r in rows)
      <String, dynamic>{
        'date': _formatDate(r.occurredAt),
        'type': _typeLabel(r.type),
        'amount': Money.fromMinor(r.amountMinor, currency: r.currency).decimal,
        'account': r.accountName,
        'toAccount': r.toAccountName ?? '',
        'category': r.categoryName ?? '',
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
  final List<BillRow> rows = <BillRow>[];
  final List<String> errors = <String>[];
  final List<List<dynamic>> table =
      const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
          .convert(content.replaceAll('\r', ''));
  if (table.isEmpty) return const ParseResult(<BillRow>[], <String>[]);

  // 表头 → 列索引（按中文表头定位，缺列时回退到 -1 表示无此列）。
  final Map<String, int> idx = <String, int>{};
  final List<dynamic> header = table.first;
  for (int i = 0; i < header.length; i++) {
    idx[header[i].toString().trim()] = i;
  }
  int col(String name) => idx[name] ?? -1;
  final int iDate = col('日期');
  final int iType = col('类型');
  final int iAmount = col('金额');
  final int iAccount = col('账户');
  final int iTo = col('转入账户');
  final int iCat = col('分类');
  final int iNote = col('备注');

  for (int r = 1; r < table.length; r++) {
    final List<dynamic> line = table[r];
    final String lineNo = '第$r行';
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
    final int amount = Money.tryParse(cell(iAmount)).minor;
    final String account = cell(iAccount);
    if (account.isEmpty) {
      errors.add('$lineNo：账户为空');
      continue;
    }
    final String toRaw = cell(iTo);
    final String? toAccount = toRaw.isEmpty ? null : toRaw;
    if (type == TxnType.transfer && toAccount == null) {
      errors.add('$lineNo：转账缺少转入账户');
      continue;
    }
    final String catRaw = cell(iCat);
    final String noteRaw = cell(iNote);
    rows.add(
      BillRow(
        occurredAt: dt,
        type: type,
        amountMinor: amount,
        accountName: account,
        toAccountName: toAccount,
        categoryName: catRaw.isEmpty ? null : catRaw,
        note: noteRaw.isEmpty ? null : noteRaw,
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
    final List<dynamic> list =
        decoded is List ? decoded : <dynamic>[decoded];
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
      final int amount = Money.tryParse((m['amount'] ?? '').toString()).minor;
      final String account = (m['account'] ?? '').toString().trim();
      if (account.isEmpty) {
        errors.add('$lineNo：账户为空');
        continue;
      }
      final String toRaw = (m['toAccount'] ?? '').toString().trim();
      final String? toAccount = toRaw.isEmpty ? null : toRaw;
      if (type == TxnType.transfer && toAccount == null) {
        errors.add('$lineNo：转账缺少转入账户');
        continue;
      }
      final String catRaw = (m['category'] ?? '').toString().trim();
      final String noteRaw = (m['note'] ?? '').toString().trim();
      rows.add(
        BillRow(
          occurredAt: dt,
          type: type,
          amountMinor: amount,
          accountName: account,
          toAccountName: toAccount,
          categoryName: catRaw.isEmpty ? null : catRaw,
          note: noteRaw.isEmpty ? null : noteRaw,
          currency: (m['currency'] ?? 'CNY').toString(),
        ),
      );
    }
  } on FormatException catch (e) {
    errors.add('JSON 解析失败：$e');
  }
  return ParseResult(rows, errors);
}
