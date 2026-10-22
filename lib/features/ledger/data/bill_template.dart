import 'package:csv/csv.dart';

import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';
import 'account_io.dart';
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
///
/// v3（2026-10-22）：新增账户段（[kAccountTemplateFields]）——CSV 单文件双段
/// （`# [账户]` / `# [账单]` 标记分行），JSON 增 `accounts` 键；用于在新系统
/// 复原账户信息。旧 v2 单段文件仍可导入。
const String kBillTemplateVersion = 'v3';

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
    desc: '格式 yyyy-MM-dd HH:mm，如 2026-10-18 12:30；只到日期也接受。'
        '兼容微信等导出的宽松写法：斜杠分隔、月/日/时/分不补零'
        '（如 2026-9-29 17:31 / 2026/10/9 17:3）',
  ),
  BillTemplateField(
    header: '模块',
    jsonKey: 'module',
    typeLabel: '枚举',
    required: false,
    desc:         '业务来源：日常记账 / 转账 / 借还 / 报销 / 储蓄 / 分期 / 投资 / 物品 / '
        '退款；留空默认「日常记账」。报销的「支出侧」不用本列——垫付请记一笔普通'
        '支出并填「可报销=Y + 报销账户」（走通用路径自动挂报销账户应收）；本列'
        '「报销」（Phase 2 已支持）仅用于报销到账的收入：类型须「收入」、报销账户'
        '必填、「账户」列填实际收款账户（如微信/银行卡），导入即建报销收入流水 + '
        '待报销记录并全额抵扣翻「已报销」+ 核销报销账户挂账，维持「报销账户余额 = '
        '待收垫付」不变量，导出→再导入无损往返。'
        '借还（Phase 2 已支持）按分类名（借入/借出/还债/收债/债务消减/坏账计提）'
        '路由到借还台账，并需填「对方」列。储蓄（Phase 2 已支持）按「转入账户」列'
        '= 储蓄计划名路由到储蓄台账：建/匹配目标 + 逐期存入；账户列=扣款账户'
        '（可空 = 灵活存入，无联动流水）。分期（Phase 2 已支持）按「备注」= 计划名'
        '（如 iPhone 分期）+ 「转入账户」= 负债付款账户（花呗/信用卡）路由分期'
        '计划：类型须「转账」，导入即建/匹配计划并逐期生成「分期订单」、还款自动'
        '对账标记已还。投资（Phase 2 已支持）按「对方」= 证券代码 + 「分类」= 品种类型'
        '（股票/基金/债券/期货/期权/外汇/贵金属/加密货币/其他）+ 「备注」= 名称@单价 路由'
        '投资持仓台账：类型须「支出」（买入）或「收入」（卖出），导入即生成持仓与资金流水。'
        '报销（Phase 2 已支持）按「账户」= 实际收款账户 + 「报销账户」= 报销类账户路由：'
        '建报销收入流水（进收款账户）+ 建待报销记录并全额抵扣翻「已报销」+ 核销报销账户'
        '挂账，维持「报销账户余额 = 待收垫付」不变量；导出→再导入无损往返。',
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
        '借入/借出导入时若账户列表中无同名应收/应付账户，将按对方名自动创建对应类型账户；'
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
    header: '手续费',
    jsonKey: 'fee',
    typeLabel: '金额',
    required: false,
    desc: '手续费（元），如 2.00；常见于银行 / 第三方转账。仅作记录项签，'
        '不参与余额扣减（转账实付请在记一笔侧用「扣款金额」表达）。留空为 0',
  ),
  BillTemplateField(
    header: '分类',
    jsonKey: 'category',
    typeLabel: '文本',
    required: false,
    desc: '分类名称；按收入/支出类型匹配同名分类，不存在将自动创建',
  ),
  BillTemplateField(
    header: '子分类',
    jsonKey: 'subcategory',
    typeLabel: '文本',
    required: false,
    desc: '子分类名称（自由文本，可不填）；与「分类」解耦：分类参与统计归集，'
        '子分类只是可选项签，不影响任何聚合。如「餐饮」下记「聚餐 / 外卖」',
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
  BillTemplateField(
    header: '位置',
    jsonKey: 'placeName',
    typeLabel: '文本',
    required: false,
    desc: '选填，语义化地名（小区/店名级）；与纬度/经度一起填写可恢复定位显示',
  ),
  BillTemplateField(
    header: '纬度',
    jsonKey: 'latitude',
    typeLabel: '数字',
    required: false,
    desc: '选填，WGS-84 纬度（小数度，如 39.913860）',
  ),
  BillTemplateField(
    header: '经度',
    jsonKey: 'longitude',
    typeLabel: '数字',
    required: false,
    desc: '选填，WGS-84 经度（小数度，如 116.627910）',
  ),
];

// ───────────────────── 账户段字段（v3，账户信息复原） ─────────────────────

/// 账户段字段清单（顺序即列顺序，导出与解析共用）。
///
/// 与 [AccountRow]（account_io.dart）一一对应。设计目标：**导出 → 新系统
/// 导入后账户信息全部复原**——类型 / 币种 / 余额 / 图标 / 颜色 / 信用卡额度 /
/// 账单日 / 还款日 / 备注 / 卡号 / 状态 / 计入总资产 / 排序 一个不落。
///
/// 余额语义 = **当前余额**（分，信用卡负数=欠款）；导入收尾会把余额校正为
/// 该值，因此新系统终态与导出时一致。
const List<BillTemplateField> kAccountTemplateFields = <BillTemplateField>[
  BillTemplateField(
    header: '账本',
    jsonKey: 'book',
    typeLabel: '文本',
    required: false,
    desc: '账本名称；为空归当前账本。与账单段「账本」列同一口径，按名称归户',
  ),
  BillTemplateField(
    header: '账户名',
    jsonKey: 'name',
    typeLabel: '文本',
    required: true,
    desc: '账户名称；与现有账户按名称匹配（忽略大小写），不存在则按本段全量字段'
        '建户。名称是复原的匹配键，改名会被当成另一个账户',
  ),
  BillTemplateField(
    header: '类型',
    jsonKey: 'type',
    typeLabel: '枚举',
    required: true,
    desc: '导出为英文代码（如 wechat / creditCard），保证无歧义往返；手工填写'
        '也可写中文名（如 微信 / 信用卡）。代码清单：cash 现金、bankCard 借记卡、'
        'creditCard 信用卡、eWallet 电子钱包、other 其他账户、wechat 微信、'
        'alipay 支付宝、providentFund 公积金、medicalInsurance 医保卡、'
        'transitCard 公交卡、giftCard 储值卡、fund 基金、stock 股票、futures 期货、'
        'spot 现货、reimbursement 报销、lend 借出、huabei 花呗、jiebei 借呗、'
        'baitiao 白条、meituanMonthly 美团月付、douyinMonthly 抖音月付、'
        'otherDebt 其他负债账户、borrow 借入、timeDeposit 定期、'
        'investmentOther 其他投资账户',
  ),
  BillTemplateField(
    header: '币种',
    jsonKey: 'currency',
    typeLabel: '文本',
    required: false,
    desc: '如 CNY / USD / HKD；留空默认 CNY',
  ),
  BillTemplateField(
    header: '余额',
    jsonKey: 'balance',
    typeLabel: '金额',
    required: false,
    desc: '当前余额（元），可为负数（如投资账户亏损）；信用卡等负债类按库内'
        '口径正余额=欠款，照账户页显示值填即可。导入完成后余额会校正为该值，'
        '保证新系统与导出时一致（报销 / 借还类账户余额为派生值，由各自台账'
        '重算、不校正）；留空为 0',
  ),
  BillTemplateField(
    header: '图标',
    jsonKey: 'icon',
    typeLabel: '文本',
    required: false,
    desc: '图标 key，留空则按账户类型自动派生',
  ),
  BillTemplateField(
    header: '颜色',
    jsonKey: 'color',
    typeLabel: '文本',
    required: false,
    desc: '颜色值：0xFF88CC66 / #FF88CC66 / #88CC66 任一形式；留空为不自定义',
  ),
  BillTemplateField(
    header: '信用卡额度',
    jsonKey: 'creditLimit',
    typeLabel: '金额',
    required: false,
    desc: '仅信用卡 / 负债类账户有意义，如 20000.00；留空为不设额度',
  ),
  BillTemplateField(
    header: '账单日',
    jsonKey: 'billingDay',
    typeLabel: '数字',
    required: false,
    desc: '信用卡账单日，1-31；留空为不设',
  ),
  BillTemplateField(
    header: '还款日',
    jsonKey: 'dueDay',
    typeLabel: '数字',
    required: false,
    desc: '信用卡还款日，1-31；留空为不设',
  ),
  BillTemplateField(
    header: '备注',
    jsonKey: 'note',
    typeLabel: '文本',
    required: false,
    desc: '账户备注，选填',
  ),
  BillTemplateField(
    header: '卡号',
    jsonKey: 'cardNumber',
    typeLabel: '文本',
    required: false,
    desc: '卡号（可只记后四位）；第三方账单导入按末四位归户时也用它匹配',
  ),
  BillTemplateField(
    header: '状态',
    jsonKey: 'status',
    typeLabel: '枚举',
    required: false,
    desc: '使用中 / 隐藏 / 封存（也可写 active / hidden / sealed）；留空默认「使用中」',
  ),
  BillTemplateField(
    header: '计入总资产',
    jsonKey: 'includeInTotal',
    typeLabel: '布尔',
    required: false,
    desc: '是否计入总资产（净值计算）：Y / N。留空默认 Y',
  ),
  BillTemplateField(
    header: '排序',
    jsonKey: 'sortOrder',
    typeLabel: '数字',
    required: false,
    desc: '账户列表排序号，小的在前；留空为 0',
  ),
];

/// 示例数据（与表头严格 21 列对齐，经 [ListToCsvConverter] 生成，避免手写错位）。
///
/// 顺序：日期,模块,类型,金额,账户,转入账户,对方,优惠,手续费,分类,子分类,标签,
/// 账本,可报销,报销账户,不计预算,不计收支,备注,位置,纬度,经度。
const List<List<String>> _sampleRows = <List<String>>[
  <String>[
    '2026-10-18 12:30', '日常记账', '支出', '25.50', '微信',
    '', '', '', '', '餐饮', '', '午饭', '',
    'N', '', 'N', 'N', '午饭', '通州区XX小区', '39.913860', '116.627910',
  ],
  <String>[
    '2026-10-18 09:00', '退款', '收入', '25.50', '微信',
    '', '', '', '', '', '', '旅游,2026', '',
    'N', '', 'N', 'N', '退货退款', '', '', '',
  ],
  <String>[
    '2026-10-18 15:00', '借还', '支出', '1000', '微信',
    '', '小米', '', '', '借出', '', '', '',
    'N', '', 'N', 'N', '借给小米', '', '', '',
  ],
  <String>[
    '2026-10-18 18:00', '储蓄', '支出', '500', '招商银行',
    '定期存款', '', '', '', '', '', '', '',
    'N', '', 'N', 'N', '每月定存（第1期）', '', '', '',
  ],
  <String>[
    '2026-10-19 18:00', '储蓄', '支出', '500', '招商银行',
    '定期存款', '', '', '', '', '', '', '',
    'N', '', 'N', 'N', '每月定存（第2期）', '', '', '',
  ],
  <String>[
    '2026-11-01 09:00', '分期', '转账', '2000', '招商银行',
    '花呗', '', '', '', '', '', '', '',
    'N', '', 'N', 'N', 'iPhone 分期', '', '', '',
  ],
  <String>[
    '2026-12-01 09:00', '分期', '转账', '2000', '招商银行',
    '花呗', '', '', '', '', '', '', '',
    'N', '', 'N', 'N', 'iPhone 分期', '', '', '',
  ],
  <String>[
    '2026-10-20 09:30', '投资', '支出', '1000', '招商银行',
    '', '000300', '0', '', '基金', '', '', '',
    'N', '', 'N', 'N', '沪深300ETF@1.2300', '', '', '',
  ],
  <String>[
    '2026-11-20 09:30', '投资', '收入', '800', '招商银行',
    '', '000300', '0', '', '基金', '', '', '',
    'N', '', 'N', 'N', '沪深300ETF@1.3500 部分止盈', '', '', '',
  ],
  <String>[
    '2026-10-18 20:00', '日常记账', '支出', '200', '微信',
    '', '', '', '', '餐饮', '', '', '',
    'Y', '公司报销', 'N', 'N', '出差午饭（垫付，待报销）', '', '', '',
  ],
  <String>[
    '2026-10-25 10:00', '报销', '收入', '200', '微信',
    '', '', '', '', '', '', '', '',
    'N', '公司报销', 'N', 'N', '报销到账（退回垫付，收款账户=微信）', '', '', '',
  ],
];

/// 账户段示例（与 [kAccountTemplateFields] 严格 15 列对齐）。
///
/// 顺序：账本,账户名,类型,币种,余额,图标,颜色,信用卡额度,账单日,还款日,
/// 备注,卡号,状态,计入总资产,排序。
const List<List<String>> _accountSampleRows = <List<String>>[
  <String>[
    '', '微信', 'wechat', 'CNY', '125.50', '', '', '', '', '',
    '日常零钱', '', '使用中', 'Y', '1',
  ],
  <String>[
    '', '招商银行', 'bankCard', 'CNY', '18620.33', '', '', '', '', '',
    '工资卡', '1234', '使用中', 'Y', '2',
  ],
  <String>[
    '', '招商信用卡', 'creditCard', 'CNY', '-2300.00', '', '', '20000', '5', '23',
    '', '5678', '使用中', 'Y', '3',
  ],
  <String>[
    '', '余额宝', 'investmentOther', 'CNY', '3000.00', '', '0xFF88CC66', '', '', '',
    '货币基金', '', '隐藏', 'N', '4',
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
  final int accExpected = kAccountTemplateFields.length;
  for (int i = 0; i < _accountSampleRows.length; i++) {
    if (_accountSampleRows[i].length != accExpected) {
      throw StateError(
        '账户示例第 ${i + 1} 行列数（${_accountSampleRows[i].length}）≠ 表头'
        '（$accExpected），模板示例错位',
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

/// 账户段示例渲染成 CSV 文本（含表头），用途同 [_renderSampleCsv]。
String _renderAccountSampleCsv() {
  _verifySampleColumns();
  return const ListToCsvConverter(eol: '\n').convert(<List<dynamic>>[
    <String>[for (final BillTemplateField f in kAccountTemplateFields) f.header],
    for (final List<String> r in _accountSampleRows) r,
  ]);
}

/// 模板文件头注释（CSV `#` 行 / JSON `_template` 元信息），含全部字段规范。
///
/// 示例行由 [_renderSampleCsv] 统一生成并前缀 `# 示例：`，与表头同列数，
/// 杜绝此前「手写注释示例列数错位」的问题。账户段注释同理（v3）。
List<String> templateCommentLines() {
  final List<String> billSamples = _renderSampleCsv()
      .split('\n')
      .skip(1) // 跳过表头（表头另起一行，不进 # 注释）
      .map((String l) => '# 示例：$l')
      .toList();
  final List<String> accountSamples = _renderAccountSampleCsv()
      .split('\n')
      .skip(1)
      .map((String l) => '# 示例：$l')
      .toList();
  return <String>[
    '# 口袋账本 · 账单导入模板 $kBillTemplateVersion',
    '# 带 * 为必填列；以 # 开头的行是说明，导入时自动忽略，请勿删除表头行',
    '# 文件分两段：`# [账户]` 段（可选，账户信息，用于在新系统复原账户）+ '
        '`# [账单]` 段（账单数据）；只有账单数据时可整体省略账户段',
    '# ── 账户段字段 ──',
    for (final BillTemplateField f in kAccountTemplateFields)
      '# ${f.displayHeader}（${f.typeLabel}）：${f.desc}',
    ...accountSamples,
    '# ── 账单段字段 ──',
    for (final BillTemplateField f in kBillTemplateFields)
      '# ${f.displayHeader}（${f.typeLabel}）：${f.desc}',
    ...billSamples,
  ];
}

/// 生成空白填写模板 CSV：说明注释行 + 双段表头（`# [账户]` 段 + `# [账单]`
/// 段）。用户填到各段表头行下方即可导入；账户段可整段留空。
String buildTemplateCsv() => <String>[
      ...templateCommentLines(),
      kAccountSectionMarker,
      <String>[for (final BillTemplateField f in kAccountTemplateFields) f.header]
          .join(','),
      '',
      kBillSectionMarker,
      <String>[for (final BillTemplateField f in kBillTemplateFields) f.header]
          .join(','),
      '',
    ].join('\n');

/// 生成空白填写模板 JSON：`_template` 元信息 + 空数组，字段规范在 `fields` /
/// `accountFields` 里。
String buildTemplateJson() {
  final Map<String, dynamic> spec = <String, dynamic>{
    '_template': <String, dynamic>{
      'app': '口袋账本',
      'version': kBillTemplateVersion,
      'accountFields': <Map<String, dynamic>>[
        for (final BillTemplateField f in kAccountTemplateFields)
          <String, dynamic>{
            'key': f.jsonKey,
            'name': f.header,
            'type': f.typeLabel,
            'required': f.required,
            'desc': f.desc,
          },
      ],
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
    'accounts': <dynamic>[],
    'bills': <dynamic>[],
  };
  return _prettyJson(spec);
}

/// 示例账单行（[BillRow] 列表）：由 [_sampleRows] 经标准 CSV 往返解析得到，作为
/// 导出示例文件 / 应用内预览的单一数据源。含投资等 Phase 2 模块的合法样例，列数由
/// [_verifySampleColumns] 守门，杜绝手写示例错位。
List<BillRow> sampleBillRows() {
  final String csv = const ListToCsvConverter(eol: '\n').convert(<List<dynamic>>[
    <String>[for (final BillTemplateField f in kBillTemplateFields) f.header],
    for (final List<String> r in _sampleRows) r,
  ]);
  return parseInput(csv).rows;
}

/// 示例账户行（[AccountRow] 列表）：与 [sampleBillRows] 同定位，供导出示例 /
/// 模板预览用。
List<AccountRow> sampleAccountRows() {
  return parseInput('$kAccountSectionMarker\n'
          '${_renderAccountSampleCsv()}\n'
          '$kBillSectionMarker\n'
          '${_renderSampleCsv()}')
      .accounts;
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

/// 仅作标记、不生成子记录的模块（当前为空：借还 / 储蓄 / 分期 / 投资 / 报销 均已
/// 在 Phase 2 落地并生成对应的台账子记录——借还→借还台账、储蓄→储蓄台账、
/// 分期→分期计划、投资→投资持仓、报销→报销记录 + 应收核销）。
///
/// 保留空集合 + 下方提示逻辑作为未来扩展占位，避免误删（新增仅标记模块时只需把
/// 对应 [SourceModule] 加入此集合即可触发「仅作标记落库」提示）。
const Set<SourceModule> _kPhase2Modules = <SourceModule>{};

/// 投资行备注约定：`证券名称@单价[ 用户备注]`，如 `沪深300ETF@1.23`、
/// `沪深300ETF@1.23 每月定投`。单价以「元」计、至多两位小数（与持仓单价同精度，分）。
/// 返回 (name, priceMinor, userNote)；priceMinor 为 null 表示缺单价（非法）。
(String, int?, String?) parseInvestmentNote(String? note) {
  final String raw = (note ?? '').trim();
  if (raw.isEmpty) return ('', null, null);
  final int at = raw.indexOf('@');
  if (at < 0) return (raw, null, null);
  final String name = raw.substring(0, at).trim();
  final String rest = raw.substring(at + 1).trim();
  final List<String> parts = rest.split(RegExp(r'\s+'));
  final double? price = double.tryParse(parts.first.replaceAll(',', ''));
  final int? priceMinor = price == null ? null : (price * 100).round();
  final String? userNote =
      parts.length > 1 ? parts.skip(1).join(' ').trim() : null;
  return (name, priceMinor, userNote);
}

/// 投资品种类型（[InvestmentType]）从「分类」列文本解析；无法识别返回 null，
/// 调用方按证券代码兜底（股票代码 → 股票，其余 → 基金）。
InvestmentType? investmentTypeFromLabel(String? label) {
  final String s = (label ?? '').trim();
  if (s.isEmpty) return null;
  for (final InvestmentType t in InvestmentType.values) {
    if (t.label == s) return t;
  }
  return null;
}

/// 解析投资品种类型，未知/缺省时按证券代码兜底（股票代码 → 股票，其余 → 基金）。
InvestmentType resolveInvestmentType(String? label, String symbol) {
  final InvestmentType? direct = investmentTypeFromLabel(label);
  if (direct != null) return direct;
  final String s = symbol.trim().toUpperCase();
  // 纯数字 6 位 / .SH/.SZ/.BJ/.HK → 股票；纯字母 → 美股，均归股票。
  if (RegExp(r'^\d{6}$').hasMatch(s) ||
      s.endsWith('.SH') ||
      s.endsWith('.SZ') ||
      s.endsWith('.BJ') ||
      s.endsWith('.HK') ||
      RegExp(r'^[A-Z]+$').hasMatch(s)) {
    return InvestmentType.stock;
  }
  return InvestmentType.fund;
}

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
    this.restoredAccounts = const <String>[],
    this.updatedAccounts = const <String>[],
  });

  /// 阻断性错误（金额非法、转账缺转入账户、类型不识别等），逐行带行号。
  final List<String> errors;

  /// 非阻断提示（如备注超长、Phase 1 仅标记等）。
  final List<String> warnings;

  /// 将自动创建的账户名（去重、保持出现顺序）。
  final List<String> newAccounts;

  /// 账户段（v3）中将**新建**的账户名（当前库不存在，按段内全量字段建户）。
  final List<String> restoredAccounts;

  /// 账户段（v3）中将**覆盖更新**的账户名（当前库已存在同名账户）。
  final List<String> updatedAccounts;

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
  List<AccountRow> accounts = const <AccountRow>[],
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
  final Set<String> seenNewSubCategories = <String>{}; // 同一子分类名只提示一次
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
    // 投资模块的「转账」类型由下方投资块单独拦截（给出更精确的提示），此处跳过，
    // 避免先触发通用的「转账缺少转入账户」而掩盖投资专属错误。
    if (r.type == TxnType.transfer &&
        r.toAccountName == null &&
        r.module != SourceModule.investment) {
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

    // 储蓄（Phase 2 已支持）：「转入账户」列 = 储蓄计划名，必填；账户列 = 扣款账户
    // （可空 = 灵活存入，无联动流水）。未指定计划名无法路由到储蓄台账，拦截。
    if (r.module == SourceModule.savings) {
      if (r.toAccountName == null || r.toAccountName!.trim().isEmpty) {
        errors.add('$lineNo：储蓄模块必须指定「转入账户」= 储蓄计划名');
        continue;
      }
    }

    // 分期（Phase 2 已支持）：类型须「转账」（账户=扣款账户、转入账户=负债付款
    // 账户），「备注」= 计划名（如 iPhone 分期）。按计划名忽略大小写建/匹配分期计划，
    // 逐期生成「分期订单」并还款自动对账标记已还；缺任一要素无法路由，拦截。
    if (r.module == SourceModule.installment) {
      if (r.type != TxnType.transfer) {
        errors.add('$lineNo：分期模块类型必须为「转账」（账户=扣款账户，'
            '转入账户=负债付款账户）');
        continue;
      }
      if (r.accountName.trim().isEmpty) {
        errors.add('$lineNo：分期模块必须指定「账户」（扣款账户）');
        continue;
      }
      if (r.toAccountName == null || r.toAccountName!.trim().isEmpty) {
        errors.add('$lineNo：分期模块必须指定「转入账户」= 负债付款账户（如花呗/信用卡）');
        continue;
      }
      if ((r.note ?? '').trim().isEmpty) {
        errors.add('$lineNo：分期模块「备注」必须填计划名（如 iPhone 分期），'
            '用于匹配/创建分期计划');
        continue;
      }
    }

    // 投资（Phase 2 已支持）：类型须「支出」（买入）或「收入」（卖出），账户列 =
    // 资金账户（必填），「对方」列 = 证券代码（必填），「备注」= 名称@单价（单价必填，
    // 用于推算份额）；「分类」列 = 品种类型（股票/基金/…，缺省按代码兜底）。缺任一要素
    // 无法路由到持仓台账，拦截。
    if (r.module == SourceModule.investment) {
      if (r.type == TxnType.transfer) {
        errors.add('$lineNo：投资模块类型须为「支出」（买入）或「收入」（卖出），不能是转账');
        continue;
      }
      if (r.accountName.trim().isEmpty) {
        errors.add('$lineNo：投资模块必须指定「账户」（资金账户，买款来源/卖款去向）');
        continue;
      }
      final String invSymbol = (r.counterparty ?? '').trim();
      if (invSymbol.isEmpty) {
        errors.add('$lineNo：投资模块必须指定「对方」= 证券代码（如 000300 / AAPL / BTC）');
        continue;
      }
      final (String invName, int? invPrice, String? invNote) =
          parseInvestmentNote(r.note);
      if (invName.isEmpty) {
        errors.add('$lineNo：投资模块「备注」须含证券名称，格式：名称@单价'
            '（如 沪深300ETF@1.2300）');
        continue;
      }
      if (invPrice == null || invPrice <= 0) {
        errors.add('$lineNo：投资模块「备注」须含有效单价，格式：名称@单价'
            '（如 沪深300ETF@1.2300），用于推算份额');
        continue;
      }
    }

    // 报销（Phase 2 已支持）：模块=报销 + 收入 + 报销账户，路由到报销台账
    // （建收入流水 + 待报销记录 + 全额抵扣翻「已报销」+ 核销垫付）。支出侧的垫付
    // 走通用路径（可报销=Y + 报销账户），此处只校验「报销到账」行。
    if (r.module == SourceModule.reimbursement) {
      if (r.type != TxnType.income) {
        errors.add('$lineNo：报销模块（报销到账）类型必须为「收入」');
        continue;
      }
      final String reimbAcct = (r.reimbursementAccount ?? '').trim();
      if (reimbAcct.isEmpty) {
        errors.add('$lineNo：报销模块必须指定「报销账户」');
        continue;
      }
      // 收款账户应与报销账户不同：否则收入进报销账户后再核销会重复扣减，
      // 报销账户余额失真；此处仅提示，不让整行失败。
      final String recvAcct = r.accountName.trim();
      if (recvAcct.isNotEmpty &&
          recvAcct.toLowerCase() == reimbAcct.toLowerCase()) {
        warnings.add('$lineNo：报销到账的「账户」与「报销账户」相同，'
            '收入将进报销账户、不再单独核销，报销账户余额可能失真；'
            '建议「账户」填实际收款账户（如微信/银行卡）');
      }
    }

    // 模块：仅作标记落库提示（借还/储蓄/分期/投资已在 Phase 2 落地，不再提示）。
    if (_kPhase2Modules.contains(r.module) &&
        !seenPhase2Modules.contains(r.module)) {
      seenPhase2Modules.add(r.module);
      warnings.add('模块「${r.module.label}」仅作标记落库，不会生成对应的'
          '报销子记录，相关派生余额暂不驱动，请待后续阶段支持');
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

    // 账户匹配校验（支出/收入主账户 + 转账双方）。储蓄行的「转入账户」列是
    // 储蓄计划名（非账户），不得当作账户登记自动创建，故排除。
    final List<String> involved = <String>[
      r.accountName,
      if (r.toAccountName != null && r.module != SourceModule.savings)
        r.toAccountName!,
      if (r.isReimbursable && r.reimbursementAccount != null)
        r.reimbursementAccount!,
    ];
    for (final String name in involved) {
      if (name.trim().isEmpty) continue; // 空账户名（储蓄灵活存入等）跳过
      if (!accountNames.contains(norm(name)) &&
          !seenNewAccounts.contains(norm(name))) {
        seenNewAccounts.add(norm(name));
        newAccounts.add(name.trim());
        // 分期的「转入账户」是负债付款账户，缺失时应建为负债类而非现金类。
        final bool isInstallmentTo = r.module == SourceModule.installment &&
            r.toAccountName != null &&
            r.toAccountName!.trim().toLowerCase() == name.trim().toLowerCase();
        warnings.add(isInstallmentTo
            ? '账户「${name.trim()}」不存在，导入时将自动创建为负债类账户（分期付款账户）'
            : '账户「${name.trim()}」不存在，导入时将自动创建（现金类；报销账户建为报销类）',);
      }
    }

    // 分类匹配校验（按交易类型对应分类类型）。借还路由行的分类是 6 类固定
    // 操作名（借入/借出/还债/收债/债务消减/坏账计提），由借还台账自建系统类目，
    // 不应当作用户分类校验 / 创建，故跳过。储蓄行的分类（若有）归系统「存款」
    // 类目，同样跳过用户分类校验。
    if (r.categoryName != null &&
        r.module != SourceModule.lend &&
        r.module != SourceModule.savings &&
        r.module != SourceModule.investment) {
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
      // 子分类列语义 = 二级分类名：挂到上方一级分类下，不存在则自动创建
      // （导入侧 categoryId 改指二级，报表按 parentId 归集一级）。
      // 仅提示不阻断；同一子分类名只提示一次。
      final String subTrim = r.subcategoryName?.trim() ?? '';
      if (subTrim.isNotEmpty &&
          !seenNewSubCategories.contains(norm(r.subcategoryName!))) {
        seenNewSubCategories.add(norm(r.subcategoryName!));
        warnings.add(
          '子分类「$subTrim」将作为二级分类挂到'
          '「${r.categoryName!.trim()}」下（不存在则自动创建）',
        );
      }
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

  // ── 账户段（v3）校验：同段重名阻断、未知账本提示、建户/覆盖归集 ──
  final List<String> restoredAccounts = <String>[];
  final List<String> updatedAccounts = <String>[];
  final Map<String, String> accSeenAt = <String, String>{}; // 小写名 → 行号
  for (int i = 0; i < accounts.length; i++) {
    final AccountRow a = accounts[i];
    final String lineNo = '账户段第${i + 1}行';
    final String key = norm(a.name);
    final String? prev = accSeenAt[key];
    if (prev != null) {
      errors.add('$lineNo：账户名「${a.name}」与$prev重复（匹配忽略大小写），'
          '同名账户会归成同一个');
      continue;
    }
    accSeenAt[key] = lineNo;
    final String? book = a.book?.trim();
    if (book != null && book.isNotEmpty && !bookNames.contains(norm(book))) {
      if (seenNewBooks.add(norm(book))) {
        warnings.add('$lineNo：账本「$book」不存在，将归入当前账本');
      }
    }
    if (accountNames.contains(key)) {
      updatedAccounts.add(a.name);
    } else {
      restoredAccounts.add(a.name);
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
    restoredAccounts: restoredAccounts,
    updatedAccounts: updatedAccounts,
  );
}

/// 金额展示（元，两位小数，无符号）。
String aggAmount(int minor) => Money.fromMinor(minor).format(showSymbol: false);
