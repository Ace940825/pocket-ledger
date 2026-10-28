import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:fast_gbk/fast_gbk.dart';

import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';
import 'bill_io.dart';
import 'bill_template.dart';

/// 第三方账单导入来源（2026-10-20 一期：支付宝 / 微信 / 云闪付导出 CSV）。
enum ImportSource {
  /// 本 App 导出的 CSV / JSON（原通道）。
  pocketLedger,

  /// 空白模板（与 pocketLedger 同构，仅模板文案不同）。
  blankTemplate,

  /// 支付宝 App / 网页「交易流水证明 / 账单导出」CSV（GBK 或 UTF-8）。
  alipay,

  /// 微信「服务-钱包-账单-下载账单」CSV（UTF-8，带前导说明行）。
  wechat,

  /// 云闪付 App「账单导出」CSV（GBK）。
  unionpay,

  /// 银行类（非云闪付）账单：各银行 App / 网银导出的 CSV（表头差异较大，
  /// 自动嗅探易误判，故由用户在来源弹层手动选择）。
  bank,
}

/// 来源的展示文案（导入来源弹层 / 副标题）。
extension ImportSourceX on ImportSource {
  String get label {
    switch (this) {
      case ImportSource.pocketLedger:
        return '本 App 导出';
      case ImportSource.blankTemplate:
        return '空白模板填写';
      case ImportSource.alipay:
        return '支付宝';
      case ImportSource.wechat:
        return '微信支付';
      case ImportSource.unionpay:
        return '云闪付';
      case ImportSource.bank:
        return '银行账单';
    }
  }

  String get subtitle {
    switch (this) {
      case ImportSource.pocketLedger:
        return '本 App 导出的账单数据文件';
      case ImportSource.blankTemplate:
        return '按模板字段说明手动整理的账单数据';
      case ImportSource.alipay:
        return '支付宝导出的账单 CSV，自动识别编码并匹配银行卡账户';
      case ImportSource.wechat:
        return '微信导出的账单 CSV，自动跳过说明行并匹配银行卡账户';
      case ImportSource.unionpay:
        return '云闪付导出的账单 CSV，按卡号末四位匹配现有账户';
      case ImportSource.bank:
        return '各银行 App / 网银导出的账单 CSV，需手动适配表头';
    }
  }
}

/// 文件字节 → 文本：UTF-8（含 BOM）优先，严格解码失败回退 GBK
/// （支付宝 / 云闪付导出为 GBK；GBK 字节序列几乎必然不是合法 UTF-8，
/// 故该探测可靠）。
String decodeBillFileBytes(List<int> bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return utf8.decode(bytes.sublist(3), allowMalformed: false);
  }
  try {
    return utf8.decode(bytes, allowMalformed: false);
  } on FormatException {
    return const GbkCodec(allowMalformed: true).decode(bytes);
  }
}

/// 按表头特征嗅探来源（无法识别返回 null，维持用户所选来源）。
ImportSource? detectSource(String content) {
  if (content.contains('交易时间') && content.contains('支付方式')) {
    return ImportSource.wechat;
  }
  if (content.contains('交易分类') &&
      (content.contains('收/付款方式') || content.contains('资金状态'))) {
    return ImportSource.alipay;
  }
  if (content.contains('卡号后四位')) {
    return ImportSource.unionpay;
  }
  return null;
}

/// 按来源解析；本 App / 空白模板委托 [parseInput]，第三方走专用解析器。
ParseResult parseSource(ImportSource source, String content) {
  switch (source) {
    case ImportSource.pocketLedger:
    case ImportSource.blankTemplate:
      return parseInput(content);
    case ImportSource.alipay:
      return _parseAlipay(content);
    case ImportSource.wechat:
      return _parseWechat(content);
    case ImportSource.unionpay:
      return _parseUnionpay(content);
    case ImportSource.bank:
      return _parseBank(content);
  }
}

/// 来源对应的空白导入模板（含 # 注释说明 + 示例行）；
/// 本 App / 空白模板沿用既有 [buildTemplateCsv]。
String buildSourceTemplate(ImportSource source) {
  switch (source) {
    case ImportSource.pocketLedger:
    case ImportSource.blankTemplate:
      return buildTemplateCsv();
    case ImportSource.alipay:
      return <String>[
        '# 支付宝账单导入模板（可直接导入支付宝导出的原始 CSV，本模板供手动整理用）',
        '# 获取路径：支付宝 App「我的-账单-…-开具交易流水证明」或网页版导出',
        '# 收/支：收入 / 支出 / 不计收支（不计收支将标记为不计收支统计）',
        '# 退款成功的行自动转为收入并加「退款」标记；关闭/失败/等待中的行自动跳过',
        '# 收/付款方式列含银行卡(末四位)，如「招商银行储蓄卡(1234)」，将自动匹配现有账户',
        '记账日期,交易分类,交易对方,商品说明,收/支,金额,收/付款方式,交易状态,备注',
        '2026-10-01 12:00:00,餐饮美食,老王饭店,午餐,支出,25.00,余额,交易成功,',
      ].join('\n');
    case ImportSource.wechat:
      return <String>[
        '# 微信支付账单导入模板（可直接导入微信导出的原始 CSV，本模板供手动整理用）',
        '# 获取路径：微信「服务-钱包-账单-常见问题-下载账单」（邮件获取，UTF-8）',
        '# 收/支：收入 / 支出 / 其他（「/」视为不计收支）；全额退款行自动转为收入',
        '# 支付方式列含银行卡(末四位)，如「招商银行储蓄卡(1234)」，将自动匹配现有账户',
        '交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态,备注',
        '2026-10-01 12:00:00,商户消费,小区便利店,早餐,支出,12.50,零钱,支付成功,',
      ].join('\n');
    case ImportSource.unionpay:
      return <String>[
        '# 云闪付账单导入模板（可直接导入云闪付导出的原始 CSV，本模板供手动整理用）',
        '# 获取路径：云闪付 App「首页-账单-导出」',
        '# 卡号后四位优先匹配现有账户（名称含卡号或账户卡号末四位一致），无匹配再自动创建「银行卡尾号XXXX」归户；无卡号列时按关联账户设置',
        '交易日期,交易类型,交易金额,收/支,卡号后四位,交易描述',
        '2026-10-01 12:00:00,消费,58.00,支出,1234,超市购物',
      ].join('\n');
    case ImportSource.bank:
      return <String>[
        '# 银行账单导入模板（各家银行 App / 网银导出的 CSV 表头差异较大，'
            '本模板为通用列，可据实调整列名）',
        '# 卡号列（卡号 / 卡号后四位）按卡号末四位自动匹配现有账户；无卡号列时按关联账户设置',
        '# 金额方向：优先取「借方发生额 / 贷方发生额」两列（借=支出、贷=收入）；'
            '仅有「收/支」或「借贷标志」列时据其值判断',
        '交易日期,交易摘要,收/支,交易金额,卡号后四位,交易对手,备注',
        '2026-10-01 12:00:00,超市购物,支出,58.00,1234,某超市,',
      ].join('\n');
  }
}

// ───────────────────── 通用解析工具 ─────────────────────

/// 在内容中定位表头行（同时包含 [mustHave] 全部关键字的行），从该行起交给
/// CSV 转换器解析。微信 / 支付宝导出前置有说明行，必须跳过。
List<List<dynamic>>? _tableFromHeader(
  String content,
  List<String> mustHave,
) {
  final List<String> lines = content.replaceAll('\r', '').split('\n');
  for (int i = 0; i < lines.length; i++) {
    // 模板注释行（# 开头）不参与表头匹配（注释里可能出现「收/支」字样）。
    if (lines[i].trimLeft().startsWith('#')) continue;
    int hits = 0;
    for (final String k in mustHave) {
      if (lines[i].contains(k)) hits++;
    }
    if (hits == mustHave.length) {
      final String rest = lines.sublist(i).join('\n');
      final List<List<dynamic>> table =
          const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
              .convert(rest);
      return table.isEmpty ? null : table;
    }
  }
  return null;
}

/// 金额文本 → 分：去掉 ¥ / ￥ / 逗号 / 空白后交给 [Money.tryParse]；
/// 出现负数取绝对值（银行导出偶见负号表示方向，方向已由收/支列表达）。
int _toMinor(String raw) {
  final String s = raw.replaceAll(RegExp(r'[¥￥,\s]'), '');
  if (s.isEmpty) return 0;
  return Money.tryParse(s).minor.abs();
}

/// 交易状态守门：关闭 / 失败 / 等待 / 处理中等不入库（退款行由调用方
/// 单独放行为收入）。
bool _statusSkip(String s) {
  if (s.isEmpty) return false;
  const List<String> deny = <String>[
    '关闭', '失败', '冻结', '等待', '处理中', '进行中', '已申请', '已撤销', '已取消',
  ];
  for (final String k in deny) {
    if (s.contains(k)) return true;
  }
  return false;
}

/// 收/支 列 → 类型。「不计收支」「/」「空」视为中性流水：按支出落库但同时
/// 不计收支统计 / 不计预算（充值提现等资金腾挪，用户可在确认页手动改）。
(TxnType, bool) _thirdPartyType(String raw) {
  final String t = raw.trim();
  if (t == '不计收支' || t == '/' || t.isEmpty) {
    return (TxnType.expense, true);
  }
  return (t.contains('收') ? TxnType.income : TxnType.expense, false);
}

/// 银行账单方向列（「收/支」「借贷标志」等混用）通用映射：
/// 收 / 贷 / 入 / 增 → 收入；支 / 借 / 出 / 减 → 支出；其余（空 / 异常）按支出处理。
TxnType _bankDirection(String raw) {
  final String s = raw.trim();
  if (s.contains('收') ||
      s.contains('贷') ||
      s.contains('入') ||
      s.contains('增')) {
    return TxnType.income;
  }
  if (s.contains('支') ||
      s.contains('借') ||
      s.contains('出') ||
      s.contains('减')) {
    return TxnType.expense;
  }
  return TxnType.expense;
}

/// 第三方 CSV 通用解析：表头定位 + 列名多别名匹配 + 行级守门。
/// [cols] 键 → 候选列名（按序取第一个命中）。
ParseResult _parseThirdParty(
  String content, {
  required List<String> headerMustHave,
  required Map<String, List<String>> cols,
  required String sourceLabel,
  String? debitKey,
  String? creditKey,
  bool ioIsDebitCredit = false,
}) {
  final List<List<dynamic>>? table = _tableFromHeader(content, headerMustHave);
  if (table == null) {
    return ParseResult(<BillRow>[], <String>[
      '未找到$sourceLabel账单表头（需要列：${headerMustHave.join('、')}），'
          '请确认导出的是完整账单 CSV',
    ]);
  }
  final List<BillRow> rows = <BillRow>[];
  final List<String> errors = <String>[];
  final List<dynamic> header = table.first;
  final Map<String, int> idx = <String, int>{};
  for (int i = 0; i < header.length; i++) {
    idx[header[i].toString().trim()] = i;
  }
  int col(String key) {
    for (final String name in cols[key] ?? const <String>[]) {
      final int? i = idx[name];
      if (i != null) return i;
    }
    return -1;
  }

  final int iDate = col('date');
  final int iType = col('io');
  final int iAmount = col('amount');
  final int iAccount = col('account');
  final int iCard = col('card');
  final int iCounterparty = col('counterparty');
  final int iCategory = col('category');
  final int iNote = col('note');
  final int iRemark = col('remark');
  final int iStatus = col('status');
  final int iFee = col('fee');
  final int iDebit = debitKey != null ? col(debitKey) : -1;
  final int iCredit = creditKey != null ? col(creditKey) : -1;

  for (int r = 1; r < table.length; r++) {
    final List<dynamic> raw = table[r];
    final String lineNo = '第$r行';
    String cell(int i) =>
        i < 0 || i >= raw.length ? '' : raw[i].toString().trim();

    // 前言 / 页脚 / 说明行：日期列不以数字开头的一律跳过（微信尾部说明等）。
    final String dateRaw = cell(iDate);
    if (dateRaw.isEmpty || !RegExp(r'^\d').hasMatch(dateRaw)) continue;
    final DateTime? dt = parseBillDateLoose(dateRaw);
    if (dt == null) {
      errors.add('$lineNo：日期无法识别（$dateRaw）');
      continue;
    }

    // 退款成功行：转为收入并打标记，避免「支出在、退款丢」导致统计虚高。
    final String status = cell(iStatus);
    final bool isRefund = status.contains('退款') &&
        (status.contains('成功') ||
            status.contains('全额') ||
            status.contains('已到账'));
    if (!isRefund && _statusSkip(status)) continue;

    // 收支方向：银行账单常见「借方发生额 / 贷方发生额」两列，或「借贷标志」
    // 列（借=支出、贷=收入）；其余按收/支列。
    TxnType type;
    bool neutral = false;
    int amountMinor;
    if (iDebit >= 0 || iCredit >= 0) {
      // 银行借贷发生额模式：借方=支出、贷方=收入，只一列非零。
      final int debit = _toMinor(cell(iDebit));
      final int credit = _toMinor(cell(iCredit));
      if (debit > 0 && credit == 0) {
        type = TxnType.expense;
        amountMinor = debit;
      } else if (credit > 0 && debit == 0) {
        type = TxnType.income;
        amountMinor = credit;
      } else if (debit == 0 && credit == 0) {
        continue; // 无发生额，跳过。
      } else {
        type = TxnType.expense; // 两列均非零异常：借方优先。
        amountMinor = debit;
      }
    } else if (ioIsDebitCredit) {
      type = _bankDirection(cell(iType));
      amountMinor = _toMinor(cell(iAmount));
    } else {
      final (TxnType t, bool n) = _thirdPartyType(cell(iType));
      type = t;
      neutral = n;
      amountMinor = _toMinor(cell(iAmount));
    }
    final String catTrim = cell(iCategory);
    final String cpTrim = cell(iCounterparty);
    final String noteCommodity = cell(iNote);
    final String remark = cell(iRemark);
    String account = cell(iAccount);
    if (account.isEmpty && iCard >= 0) {
      final String card = cell(iCard);
      if (card.isNotEmpty) {
        // 卡号列可能是「后四位」或完整卡号，统一规整为末四位，
        // 便于 extractCardLast4 识别并触发现有账户卡号匹配。
        final String digits = card.replaceAll(RegExp(r'\D'), '');
        final String last4 =
            digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
        account = '银行卡尾号$last4';
      }
    }
    final String note = [
      if (noteCommodity.isNotEmpty) noteCommodity,
      if (remark.isNotEmpty) remark,
    ].join(' / ');

    rows.add(
      BillRow(
        occurredAt: dt,
        module: SourceModule.ledger,
        // 退款行固定为收入（收/支 列对退款行常为「/」中性）。
        type: isRefund ? TxnType.income : type,
        amountMinor: amountMinor,
        accountName: account,
        categoryName: catTrim.isEmpty ? null : catTrim,
        tags: isRefund ? const <String>['退款'] : const <String>[],
        isReimbursable: false,
        // 中性流水（充值 / 提现 / 腾挪）：不计收支统计与预算。
        excludeFromStats: neutral,
        excludeFromBudget: neutral,
        note: note.isEmpty ? null : note,
        currency: 'CNY',
        counterparty: cpTrim.isEmpty ? null : cpTrim,
        feeMinor: iFee < 0 ? 0 : _toMinor(cell(iFee)),
      ),
    );
  }
  return ParseResult(rows, errors);
}

// ───────────────────── 卡号末四位账户匹配 ─────────────────────

/// 从第三方账单的账户名中提取卡号末四位，用于导入时优先匹配现有账户
/// 而非盲目建户：
/// - 云闪付自动账户名「银行卡尾号XXXX」；
/// - 支付宝 / 微信「收/付款方式」列常见形态「招商银行储蓄卡(1234)」
///   「招商银行信用卡（5678）」（半角 / 全角括号均可，取最后一组）。
///
/// 余额 / 零钱 / 余额宝 / 花呗 等非卡号账户返回 null，交由精确名称匹配。
String? extractCardLast4(String accountName) {
  final String s = accountName.trim();
  if (s.isEmpty) return null;
  // 云闪付自动账户名：银行卡尾号1234
  final RegExpMatch? m1 = RegExp(r'银行卡尾号(\d{4})$').firstMatch(s);
  if (m1 != null) return m1.group(1);
  // 支付宝 / 微信「收/付款方式」列：招商银行储蓄卡(1234)、…（5678）
  final Iterable<RegExpMatch> paren =
      RegExp(r'[\(（](\d{4})[\)）]').allMatches(s);
  if (paren.isNotEmpty) return paren.last.group(1);
  return null;
}

/// 按卡号末四位匹配现有账户（只读，不创建）：
/// - 账户名包含该卡号（如「招商银行储蓄卡1234」），或
/// - 账户存储的 [Account.cardNumber]（去非数字）末四位一致。
///
/// 多命中时优先银行类账户（bankCard / creditCard），其次首个命中；
/// 已归档（隐藏）账户不参与匹配，避免意外写回。无命中返回 null。
String? matchAccountByCardLast4(String last4, List<Account> accounts) {
  final String digits = last4.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 4) return null;
  Account? bankHit;
  Account? anyHit;
  for (final Account a in accounts) {
    if (a.isArchived) continue;
    final bool nameHit = a.name.contains(digits);
    final String? card = a.cardNumber;
    final bool cardHit =
        card != null && card.replaceAll(RegExp(r'\D'), '').endsWith(digits);
    if (nameHit || cardHit) {
      if (a.type == AccountType.bankCard || a.type == AccountType.creditCard) {
        bankHit ??= a;
      }
      anyHit ??= a;
    }
  }
  return (bankHit ?? anyHit)?.id;
}

// ───────────────────── 各来源解析器 ─────────────────────

/// 支付宝：App 导出（记账日期 / 交易分类 / 收/付款方式 …）与网页导出
/// （交易创建时间 / 商品名称 / 服务费 …）两代表头都兼容。
ParseResult _parseAlipay(String content) {
  return _parseThirdParty(
    content,
    headerMustHave: const <String>['收/支'],
    cols: const <String, List<String>>{
      'date': <String>['记账日期', '交易创建时间', '付款时间'],
      'io': <String>['收/支'],
      'amount': <String>['金额（元）', '金额'],
      'account': <String>['收/付款方式', '付款方式'],
      'counterparty': <String>['交易对方'],
      'category': <String>['交易分类'],
      'note': <String>['商品说明', '商品名称'],
      'remark': <String>['备注'],
      'status': <String>['交易状态'],
      'fee': <String>['服务费（元）', '服务费'],
    },
    sourceLabel: '支付宝',
  );
}

/// 微信支付：「下载账单」CSV（带前导说明行与尾部说明），表头以
/// 交易时间 / 收/支 定位。
ParseResult _parseWechat(String content) {
  return _parseThirdParty(
    content,
    headerMustHave: const <String>['交易时间', '收/支'],
    cols: const <String, List<String>>{
      'date': <String>['交易时间'],
      'io': <String>['收/支'],
      'amount': <String>['金额(元)', '金额（元）', '金额'],
      'account': <String>['支付方式'],
      'counterparty': <String>['交易对方'],
      'category': <String>['交易类型'],
      'note': <String>['商品'],
      'remark': <String>['备注'],
      'status': <String>['当前状态'],
    },
    sourceLabel: '微信支付',
  );
}

/// 云闪付：App「账单导出」CSV，银行卡按卡号后四位自动建户归户。
ParseResult _parseUnionpay(String content) {
  return _parseThirdParty(
    content,
    headerMustHave: const <String>['收/支', '卡号后四位'],
    cols: const <String, List<String>>{
      'date': <String>['记账日期', '交易日期'],
      'io': <String>['收/支'],
      'amount': <String>['交易金额', '金额（元）', '金额'],
      'card': <String>['卡号后四位'],
      'counterparty': <String>['商户名称', '交易对方'],
      'category': <String>['交易类型'],
      'note': <String>['交易描述', '商品说明'],
      'remark': <String>['备注'],
      'status': <String>['交易状态'],
    },
    sourceLabel: '云闪付',
  );
}

/// 银行类（非云闪付）账单：各银行 App / 网银导出的 CSV。各家表头差异较大，
/// 这里以通用列名做多别名匹配，并支持两种银行常见方向表达：
/// - 「借方发生额 / 贷方发生额」两列（借=支出、贷=收入，优先采用）；
/// - 「收/支」「借贷标志」等单列（[ioIsDebitCredit] 一并兼容）。
/// 卡号列（后四位或完整卡号）统一规整为末四位（见 _parseThirdParty），
/// 复用 extractCardLast4 触发现有账户卡号匹配；detactSource 不自动嗅探本来源，
/// 由用户在来源弹层手动选择，避免与其它来源误判。
ParseResult _parseBank(String content) {
  return _parseThirdParty(
    content,
    headerMustHave: const <String>['日期'],
    cols: const <String, List<String>>{
      'date': <String>[
        '交易日期', '记账日期', '日期', '交易时间', '发生日期', '账期',
      ],
      'io': <String>[
        '收/支', '借贷标志', '借贷方向', '发生额方向', '交易类型',
      ],
      'amount': <String>[
        '交易金额', '金额', '发生额', '交易额', '交易金额(元)',
      ],
      'debit': <String>['借方发生额', '借方金额', '支出金额', '借方'],
      'credit': <String>['贷方发生额', '贷方金额', '收入金额', '贷方'],
      'account': <String>['账户名称', '账户'],
      'card': <String>[
        '卡号', '卡号后四位', '账号后四位', '卡末四位', '卡号末四位',
      ],
      'counterparty': <String>[
        '交易对手', '对方户名', '商户名称', '交易地点', '对方账号',
      ],
      'category': <String>['交易摘要', '摘要', '交易类型', '用途', '业务类型'],
      'note': <String>['备注', '附言', '注释'],
      'remark': <String>['备注', '附言'],
      'status': <String>['交易状态', '状态', '记账状态'],
    },
    sourceLabel: '银行账单',
    debitKey: 'debit',
    creditKey: 'credit',
    ioIsDebitCredit: true,
  );
}
