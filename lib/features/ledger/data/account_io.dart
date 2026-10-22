import 'package:csv/csv.dart';

import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';

/// 一个可导入 / 导出的账户（与数据库无关的中间表示，对标 [BillRow]）。
///
/// 账户段的设计目标（2026-10-22 用户需求）：**导出后在另一个新系统里能全部
/// 复原账户信息**——名称 / 类型 / 币种 / 余额 / 图标 / 颜色 / 信用卡额度 /
/// 账单日 / 还款日 / 备注 / 卡号 / 状态 / 计入总资产 / 排序 一个不落。
///
/// 余额语义：导出时刻的**当前余额**（分，原值搬运，信用卡等负债类正余额=欠款）。
/// 导入完成后余额会被校正为该值（见 bill_import_page 的收尾校正），因此
/// 「导出 → 新系统导入」终态余额与源系统一致；手工填写模板时也按当前余额填。
class AccountRow {
  const AccountRow({
    required this.name,
    required this.type,
    this.book,
    this.currency = 'CNY',
    this.balanceMinor = 0,
    this.iconKey,
    this.colorValue,
    this.creditLimitMinor,
    this.billingDay,
    this.dueDay,
    this.note,
    this.cardNumber,
    this.status = AccountStatus.active,
    this.includeInTotal = true,
    this.sortOrder = 0,
  });

  /// 账户名称（匹配键，忽略大小写）。
  final String name;

  final AccountType type;

  /// 所属账本名（按名称归户；为空归当前账本）。
  final String? book;

  final String currency;

  /// 当前余额（分）。与库内口径一致：信用卡等负债类**正余额 = 欠款**
  /// （见 accounts_dao 净资产注释）；导出/导入按原值搬运，不做符号转换。
  final int balanceMinor;

  /// 图标 key（可空；账户 UI 多由 [type] 派生，这里是保留的自定义位）。
  final String? iconKey;

  /// 颜色（ARGB int，同库里 colorValue）。可空。
  final int? colorValue;

  /// 信用卡额度（分），仅信用卡 / 负债类有意义。
  final int? creditLimitMinor;

  /// 账单日 / 还款日（1-31）。
  final int? billingDay;
  final int? dueDay;

  final String? note;

  /// 卡号（银行卡 / 信用卡等；导出保留原值，导入按末四位归户逻辑不受影响）。
  final String? cardNumber;

  final AccountStatus status;

  /// 是否计入总资产（净值计算）。
  final bool includeInTotal;

  /// 账户列表排序（小的在前）。
  final int sortOrder;
}

/// 账户段 CSV 表头（顺序即列顺序）。与 [kAccountTemplateFields] 一一对应。
const List<String> kAccountCsvHeader = <String>[
  '账本',
  '账户名',
  '类型',
  '币种',
  '余额',
  '图标',
  '颜色',
  '信用卡额度',
  '账单日',
  '还款日',
  '备注',
  '卡号',
  '状态',
  '计入总资产',
  '排序',
];

/// 账户段 JSON 键（顺序与 [kAccountCsvHeader] 一致）。
const List<String> kAccountJsonKeys = <String>[
  'book',
  'name',
  'type',
  'currency',
  'balance',
  'icon',
  'color',
  'creditLimit',
  'billingDay',
  'dueDay',
  'note',
  'cardNumber',
  'status',
  'includeInTotal',
  'sortOrder',
];

/// 类型导出值：枚举名（如 `wechat`）。
///
/// 不用中文名导出——「其他账户」一名对三（other / otherDebt / investmentOther），
/// 中文名无法无损往返。导入侧中文名 / 枚举名都认（见 [parseAccountType]）。
String accountTypeExportValue(AccountType t) => t.name;

/// 状态导出值：中文名（使用中 / 隐藏 / 封存，唯一无歧义）。
String accountStatusExportValue(AccountStatus s) => s.label;

/// 颜色导出值：`0xAARRGGBB` 大写十六进制（与库内 int 字面量同形），可空 → 空串。
String accountColorExportValue(int? colorValue) =>
    colorValue == null ? '' : '0x${colorValue.toRadixString(16).toUpperCase().padLeft(8, '0')}';

String _moneyLabel(int minor, String currency) =>
    Money.fromMinor(minor, currency: currency).format(showSymbol: false);

String _boolLabel(bool v) => v ? 'Y' : 'N';

/// 账户行 → CSV 数据行（与 [kAccountCsvHeader] 同列数）。
List<dynamic> accountRowToCsvCells(AccountRow a) => <dynamic>[
      a.book ?? '',
      a.name,
      accountTypeExportValue(a.type),
      a.currency,
      _moneyLabel(a.balanceMinor, a.currency),
      a.iconKey ?? '',
      accountColorExportValue(a.colorValue),
      a.creditLimitMinor == null
          ? ''
          : _moneyLabel(a.creditLimitMinor!, a.currency),
      a.billingDay?.toString() ?? '',
      a.dueDay?.toString() ?? '',
      a.note ?? '',
      a.cardNumber ?? '',
      accountStatusExportValue(a.status),
      _boolLabel(a.includeInTotal),
      a.sortOrder.toString(),
    ];

/// 账户行 → JSON 对象（键与 [kAccountJsonKeys] 一致）。
Map<String, dynamic> accountRowToJson(AccountRow a) => <String, dynamic>{
      'book': a.book ?? '',
      'name': a.name,
      'type': accountTypeExportValue(a.type),
      'currency': a.currency,
      'balance': Money.fromMinor(a.balanceMinor, currency: a.currency).decimal,
      'icon': a.iconKey ?? '',
      'color': accountColorExportValue(a.colorValue),
      'creditLimit': a.creditLimitMinor == null
          ? ''
          : Money.fromMinor(a.creditLimitMinor!, currency: a.currency).decimal,
      'billingDay': a.billingDay,
      'dueDay': a.dueDay,
      'note': a.note ?? '',
      'cardNumber': a.cardNumber ?? '',
      'status': accountStatusExportValue(a.status),
      'includeInTotal': a.includeInTotal,
      'sortOrder': a.sortOrder,
    };

/// 解析账户类型：枚举名优先，其次中文名（唯一者直接命中；「其他账户」等
/// 多义名取定义序第一个，如需精确请用枚举名）。
AccountType? parseAccountType(String raw) {
  final String s = raw.trim();
  if (s.isEmpty) return null;
  final String lower = s.toLowerCase();
  for (final AccountType t in AccountType.values) {
    if (t.name.toLowerCase() == lower) return t;
  }
  for (final AccountType t in AccountType.values) {
    if (t.label == s) return t;
  }
  return null;
}

/// 解析账户状态：中文名 / 枚举名 / 序号（0 使用中 / 1 隐藏 / 2 封存）。
/// 空 → [AccountStatus.active]。
AccountStatus? parseAccountStatus(String raw) {
  final String s = raw.trim();
  if (s.isEmpty) return AccountStatus.active;
  final String lower = s.toLowerCase();
  for (final AccountStatus st in AccountStatus.values) {
    if (st.name.toLowerCase() == lower || st.label == s) return st;
  }
  final int? idx = int.tryParse(s);
  if (idx != null && idx >= 0 && idx < AccountStatus.values.length) {
    return AccountStatus.values[idx];
  }
  return null;
}

/// 解析颜色：`0xAARRGGBB` / `#AARRGGBB` / `#RRGGBB`（补 FF alpha）/ 十进制整数。
/// 空 / 非法 → null。
int? parseAccountColor(String raw) {
  final String s = raw.trim();
  if (s.isEmpty) return null;
  String hex = s;
  if (hex.startsWith('0x') || hex.startsWith('0X')) {
    hex = hex.substring(2);
  } else if (hex.startsWith('#')) {
    hex = hex.substring(1);
  } else if (RegExp(r'^\d+$').hasMatch(hex)) {
    return int.tryParse(hex);
  }
  if (!RegExp(r'^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(hex)) return null;
  if (hex.length == 6) hex = 'FF$hex';
  return int.tryParse(hex, radix: 16);
}

/// 解析 1-31 的账单日 / 还款日。空 → null；越界 / 非法 → -1（调用方报错用）。
int? parseDayOfMonth(String raw) {
  final String s = raw.trim();
  if (s.isEmpty) return null;
  final int? v = int.tryParse(s);
  if (v == null || v < 1 || v > 31) return -1;
  return v;
}

/// CSV 数据行（已按下标取好单元格）→ [AccountRow]；[errors] 收集逐格错误。
///
/// [nameIndex] 为「账户名」列下标，其余列按下标传入（-1 表示无此列）。
AccountRow? parseAccountCsvRow({
  required List<dynamic> line,
  required String lineNo,
  required int iBook,
  required int iName,
  required int iType,
  required int iCurrency,
  required int iBalance,
  required int iIcon,
  required int iColor,
  required int iCreditLimit,
  required int iBilling,
  required int iDue,
  required int iNote,
  required int iCard,
  required int iStatus,
  required int iInclude,
  required int iSort,
  required List<String> errors,
}) {
  String cell(int i) => i < 0 || i >= line.length ? '' : line[i].toString().trim();

  final String name = cell(iName);
  if (name.isEmpty) {
    errors.add('$lineNo：账户名为空');
    return null;
  }
  final AccountType? type = parseAccountType(cell(iType));
  if (type == null) {
    errors.add('$lineNo：账户类型无法识别（如 微信 / cash）');
    return null;
  }
  final AccountStatus? status = parseAccountStatus(cell(iStatus));
  if (status == null) {
    errors.add('$lineNo：账户状态无法识别（应为 使用中 / 隐藏 / 封存）');
    return null;
  }
  final int? billing = parseDayOfMonth(cell(iBilling));
  if (billing == -1) {
    errors.add('$lineNo：账单日应为 1-31 的整数');
    return null;
  }
  final int? due = parseDayOfMonth(cell(iDue));
  if (due == -1) {
    errors.add('$lineNo：还款日应为 1-31 的整数');
    return null;
  }
  final String colorRaw = cell(iColor);
  final int? color = parseAccountColor(colorRaw);
  if (colorRaw.isNotEmpty && color == null) {
    errors.add('$lineNo：颜色应为 0xFF88CC66 / #FF88CC66 / #88CC66 形式');
    return null;
  }
  final String sortRaw = cell(iSort);
  final int sort = sortRaw.isEmpty ? 0 : (int.tryParse(sortRaw) ?? 0);

  String? orNull(String s) => s.isEmpty ? null : s;

  return AccountRow(
    name: name,
    type: type,
    book: orNull(cell(iBook)),
    currency: orNull(cell(iCurrency)) ?? 'CNY',
    balanceMinor: Money.tryParse(cell(iBalance)).minor,
    iconKey: orNull(cell(iIcon)),
    colorValue: color,
    creditLimitMinor: cell(iCreditLimit).isEmpty
        ? null
        : Money.tryParse(cell(iCreditLimit)).minor,
    billingDay: billing,
    dueDay: due,
    note: orNull(cell(iNote)),
    cardNumber: orNull(cell(iCard)),
    status: status,
    includeInTotal: _parseBool(cell(iInclude)),
    sortOrder: sort,
  );
}

/// JSON 对象 → [AccountRow]；键缺失按默认值兜底。返回 null 时写 [errors]。
AccountRow? parseAccountJsonRow(
  Map<String, dynamic> m, {
  required String lineNo,
  required List<String> errors,
}) {
  final String name = (m['name'] ?? '').toString().trim();
  if (name.isEmpty) {
    errors.add('$lineNo：账户名为空');
    return null;
  }
  final AccountType? type = parseAccountType((m['type'] ?? '').toString());
  if (type == null) {
    errors.add('$lineNo：账户类型无法识别（如 微信 / cash）');
    return null;
  }
  final AccountStatus? status = parseAccountStatus((m['status'] ?? '').toString());
  if (status == null) {
    errors.add('$lineNo：账户状态无法识别（应为 使用中 / 隐藏 / 封存）');
    return null;
  }
  final int? billing = _parseDayJson(m['billingDay']);
  if (billing == -1) {
    errors.add('$lineNo：账单日应为 1-31 的整数');
    return null;
  }
  final int? due = _parseDayJson(m['dueDay']);
  if (due == -1) {
    errors.add('$lineNo：还款日应为 1-31 的整数');
    return null;
  }
  final dynamic colorRaw = m['color'];
  final int? color = colorRaw == null
      ? null
      : parseAccountColor(colorRaw.toString());
  if (colorRaw != null &&
      colorRaw.toString().trim().isNotEmpty &&
      color == null) {
    errors.add('$lineNo：颜色应为 0xFF88CC66 / #FF88CC66 / #88CC66 形式');
    return null;
  }
  String orEmpty(Object? v) => (v ?? '').toString().trim();
  String? orNull(Object? v) {
    final String s = orEmpty(v);
    return s.isEmpty ? null : s;
  }

  return AccountRow(
    name: name,
    type: type,
    book: orNull(m['book']),
    currency: orNull(m['currency']) ?? 'CNY',
    balanceMinor: Money.tryParse(orEmpty(m['balance'])).minor,
    iconKey: orNull(m['icon']),
    colorValue: color,
    creditLimitMinor: orEmpty(m['creditLimit']).isEmpty
        ? null
        : Money.tryParse(orEmpty(m['creditLimit'])).minor,
    billingDay: billing,
    dueDay: due,
    note: orNull(m['note']),
    cardNumber: orNull(m['cardNumber']),
    status: status,
    includeInTotal: _parseBool(orEmpty(m['includeInTotal'])),
    sortOrder: int.tryParse(orEmpty(m['sortOrder'])) ?? 0,
  );
}

int? _parseDayJson(Object? v) {
  if (v == null) return null;
  return parseDayOfMonth(v.toString());
}

bool _parseBool(String raw) {
  final String s = raw.trim().toLowerCase();
  if (s.isEmpty) return true; // 缺省计入总资产
  return s == 'y' || s == 'true' || s == '是' || s == '1';
}

/// 账户段渲染为 CSV 文本（含表头，供拼进导出文件 / 模板示例）。
String buildAccountCsv(List<AccountRow> accounts) =>
    const ListToCsvConverter(eol: '\n').convert(<List<dynamic>>[
      kAccountCsvHeader,
      for (final AccountRow a in accounts) accountRowToCsvCells(a),
    ]);
