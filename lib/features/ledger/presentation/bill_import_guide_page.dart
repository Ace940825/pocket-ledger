import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/forest_design_tokens.dart';
import '../../../shared/widgets/hairline_card.dart';
import '../../../shared/widgets/line_icon_map.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimens.dart';

/// 「账单导入说明」页（v2）。
///
/// 把导入模板的 16 列规范、模块路由规则、借还 6 操作名与填写示例固化进 App 内，
/// 用户无需离开应用即可核对填法。视觉沿用 Forest 设计系统（sage 渐变、奶油卡面、
/// 发丝线、语义色），暗色下自动适配。
class BillImportGuidePage extends StatefulWidget {
  const BillImportGuidePage({super.key});

  @override
  State<BillImportGuidePage> createState() => _BillImportGuidePageState();
}

class _BillImportGuidePageState extends State<BillImportGuidePage> {
  bool _copied = false;

  static const List<_Col> _columns = <_Col>[
    _Col(1, '日期', true, '日期时间',
        '格式 yyyy-MM-dd HH:mm（如 2026-10-18 12:30）；只到日期也接受。'),
    _Col(2, '模块', false, '枚举',
        '日常记账 / 转账 / 借还 / 报销 / 储蓄 / 分期 / 投资 / 物品 / 退款；留空默认「日常记账」。'),
    _Col(3, '类型', true, '枚举', '只能填：收入 / 支出 / 转账。'),
    _Col(4, '金额', true, '金额', '正数金额（元），最多两位小数，如 25.50；不接受 0 或负数。'),
    _Col(5, '账户', true, '文本',
        '账户名称；与现有账户按名称匹配（忽略大小写），不存在将自动创建。'),
    _Col(6, '转入账户', false, '文本', '仅「转账」必填：转入方账户名称。'),
    _Col(7, '对方', false, '文本',
        '借还模块 + 6 个借还操作名时必填：借款人 / 出借人 / 债务方名。投资模块必填：'
        '证券代码（如 000300 / AAPL / BTC）。其余模块留空。'),
    _Col(8, '优惠', false, '金额', '优惠 / 折扣金额（元），如 45.00；实付 = 金额 − 优惠。留空为 0。'
        '投资模块中本列作「手续费」用。'),
    _Col(9, '分类', false, '文本', '分类名称；按收入 / 支出类型匹配同名分类，不存在将自动创建。'
        '投资模块中本列作「品种类型」（股票/基金/债券/期货/期权/外汇/贵金属/加密货币/其他），'
        '缺省按代码兜底。'),
    _Col(10, '标签', false, '文本', '标签名，多个用半角逗号分隔，如 旅游,2026；留空无标签。'),
    _Col(11, '账本', false, '文本', '账本名称；按名称归户到对应账本，不存在将归入当前账本。留空归当前账本。'),
    _Col(12, '可报销', false, '布尔', 'Y / N（或 是 / 否 / true / false）。Y 时建议填「报销账户」。'),
    _Col(13, '报销账户', false, '文本',
        '可报销时挂账的报销账户名称（如「公司报销」）；不存在将自动创建为报销类账户。'),
    _Col(14, '不计预算', false, '布尔', 'Y / N。Y 时不参与预算月度统计。'),
    _Col(15, '不计收支', false, '布尔', 'Y / N。Y 时不计入收支报表（如内部划转、对账调整）。'),
    _Col(16, '备注', false, '文本', '选填，最长建议 200 字。投资模块中本列必填且约定为「名称@单价」'
        '（如 沪深300ETF@1.2300；单价元计，至多两位小数），可追加空格 + 用户备注。'),
  ];

  static const List<_Module> _modules = <_Module>[
    _Module('日常记账', _ModKey.neutral, '普通收支交易', '直接落库'),
    _Module('转账', _ModKey.transfer, '需填「转入账户」', '直接落库'),
    _Module('报销', _ModKey.income, '报销到账：建收入流水 + 待报销记录并全额抵扣翻已报销 + 核销报销账户挂账', 'Phase 2 已支持'),
    _Module('借还', _ModKey.lend, '按分类名路由借还台账', 'Phase 2 已支持'),
    _Module('储蓄', _ModKey.lend, '按「转入账户」=计划名路由储蓄台账', 'Phase 2 已支持'),
    _Module('分期', _ModKey.lend, '按备注=计划名路由分期计划', 'Phase 2 已支持'),
    _Module('投资', _ModKey.lend, '按对方=代码+分类=品种+备注=名称@单价路由持仓', 'Phase 2 已支持'),
    _Module('物品 / 退款', _ModKey.neutral, '普通交易 / 退款收入', '直接落库'),
  ];

  static const List<_Op> _ops = <_Op>[
    _Op('借入', 'borrowIn · add · 本金'),
    _Op('借出', 'lendOut · add · 本金'),
    _Op('还债', 'borrowIn · repay'),
    _Op('收债', 'lendOut · repay'),
    _Op('债务消减', 'borrowIn · debtReduction'),
    _Op('坏账计提', 'lendOut · debtReduction'),
  ];

  static const List<_Example> _examples = <_Example>[
    _Example(_ModKey.neutral, '日常',
        '2026-10-18 12:30,日常记账,支出,25.50,微信,,,0.00,餐饮,午饭,,N,,N,N,午饭',
        '普通支出：微信账户，分类「餐饮」，标签「午饭」。'),
    _Example(_ModKey.income, '退款',
        '2026-10-18 09:00,退款,收入,25.50,微信,,,0.00,,"旅游,2026",,N,,N,N,退货退款',
        '退款收入，多标签用半角逗号分隔。'),
    _Example(_ModKey.lend, '借还',
        '2026-10-18 15:00,借还,支出,"1,000.00",微信,,小米,0.00,借出,,,N,,N,N,借给小米',
        '借出 1000 元给「小米」——模块=借还、分类=借出、对方=小米，路由到借出本金。'),
    _Example(_ModKey.lend, '储蓄',
        '2026-10-18 18:00,储蓄,支出,500.00,招商银行,定期存款,,0.00,,,,N,,N,N,每月定存（第1期）',
        '储蓄存入：模块=储蓄、转入账户=计划名「定期存款」、账户=扣款账户（可空）。'
            '导入即建/匹配目标并逐期存入台账，并联动一笔「存款」支出流水。'),
    _Example(_ModKey.expense, '垫付',
        '2026-10-18 20:00,日常记账,支出,200.00,微信,,,0.00,餐饮,,,Y,公司报销,N,N,出差午饭（垫付，待报销）',
        '垫付支出：可报销=Y + 报销账户「公司报销」。'),
    _Example(_ModKey.income, '报销',
        '2026-10-25 10:00,报销,收入,200.00,微信,,,0.00,,,,N,公司报销,N,N,报销到账（退回垫付，收款账户=微信）',
        '报销到账：模块=报销、类型=收入、账户列=实际收款账户（微信）、报销账户=公司报销。'
            '导入即建报销收入流水（进收款账户）+ 待报销记录并全额抵扣翻「已报销」+ 核销报销账户挂账，'
            '维持「报销账户余额 = 待收垫付」不变量。'),
    _Example(_ModKey.lend, '分期',
        '2026-11-01 09:00,分期,转账,2000.00,招商银行,花呗,,,0.00,,,,N,,N,N,iPhone 分期',
        '分期还款：模块=分期、类型=转账、账户=扣款账户、转入账户=负债付款账户'
            '（花呗）、备注=计划名「iPhone 分期」。导入即建/匹配分期计划并逐期入账，'
            '还款自动对账标记已还。'),
    _Example(_ModKey.expense, '投资买入',
        '2026-10-20 09:30,投资,支出,1000.00,招商银行,,000300,0.00,基金,,,,N,,N,N,沪深300ETF@1.2300',
        '投资买入：模块=投资、类型=支出、对方=证券代码（000300）、分类=品种（基金）、'
            '备注=名称@单价。导入即建/增资持仓并记支出流水（账户扣款 = 金额 + 手续费）。'),
    _Example(_ModKey.income, '投资卖出',
        '2026-11-20 09:30,投资,收入,800.00,招商银行,,000300,0.00,基金,,,,N,,N,N,沪深300ETF@1.3500 部分止盈',
        '投资卖出：模块=投资、类型=收入，其余同买入。导入即减仓并记收入流水'
            '（到账 = 金额 − 手续费）；要求该证券此前已有买入。'),
  ];

  static const String _template = '日期,模块,类型,金额,账户,转入账户,对方,优惠,分类,标签,账本,可报销,报销账户,不计预算,不计收支,备注\n'
      '2026-10-18 12:30,日常记账,支出,25.50,微信,,,0.00,餐饮,午饭,,N,,N,N,午饭\n'
      '2026-10-18 15:00,借还,支出,1000,微信,,小米,0.00,借出,,,N,,N,N,借给小米\n'
      '2026-10-18 20:00,日常记账,支出,200.00,微信,,,0.00,餐饮,,,Y,公司报销,N,N,出差午饭（垫付，待报销）\n'
      '2026-10-25 10:00,报销,收入,200.00,微信,,,0.00,,,,N,公司报销,N,N,报销到账（退回垫付，收款账户=微信）\n'
      '2026-11-01 09:00,分期,转账,2000.00,招商银行,花呗,,,0.00,,,,N,,N,N,iPhone 分期\n'
      '2026-10-20 09:30,投资,支出,1000.00,招商银行,,000300,0.00,基金,,,,N,,N,N,沪深300ETF@1.2300\n'
      '2026-11-20 09:30,投资,收入,800.00,招商银行,,000300,0.00,基金,,,,N,,N,N,沪深300ETF@1.3500 部分止盈';

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = scheme.brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入说明'),
        centerTitle: true,
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.lg,
          AppDimens.md,
          AppDimens.lg,
          AppDimens.xl,
        ),
        children: <Widget>[
          // Hero
          Container(
            decoration: BoxDecoration(
              gradient: ForestGradients.sage,
              borderRadius: BorderRadius.circular(AppDimens.radiusCard),
            ),
            padding: const EdgeInsets.all(AppDimens.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '账单批量导入指南 · v2',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.white,
                    letterSpacing: 0.01,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '16 列模板，把日常记账、转账、借还、报销等交易一次性导入。'
                  '带 * 为必填；以 # 开头的说明行导入时自动忽略。',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppPalette.white.withValues(alpha: 0.95),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppDimens.md),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const <Widget>[
                    _Pill('16 列模板'),
                    _Pill('借还/储蓄/分期/投资/报销 已支持'),
                    _Pill('CSV / JSON 双格式'),
                    _Pill('导出→再导入 无损往返'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.lg),

          // What's new
          const SectionHeader(title: 'v2 相比 v1'),
          const SizedBox(height: AppDimens.sm),
          const _Feature(
            tag: '新增列',
            title: '对方（第 7 列）',
            body: '仅「借还」模块、且分类为 6 个固定借还操作名之一时必填。填写借款人 / '
                '出借人 / 债务方姓名，导入后作为借还记录的 counterparty，驱动借还往来余额。',
          ),
          const SizedBox(height: AppDimens.sm),
          const _Feature(
            tag: '模块升级',
            title: '借还 → 借还台账',
            body: '借还行不再只打标记落普通交易，而是按分类名路由到借还台账的本金 / 还款 / '
                '冲减方法，真正生成可追踪的借还往来记录。',
          ),
          const SizedBox(height: AppDimens.lg),

          // Column spec
          const SectionHeader(title: '字段规范（16 列）'),
          const SizedBox(height: AppDimens.sm),
          HairlineCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                for (int i = 0; i < _columns.length; i++) ...<Widget>[
                  if (i > 0)
                    Divider(height: 1, color: scheme.outline.withValues(alpha: 0.6)),
                  _ColRow(col: _columns[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppDimens.lg),

          // Module routing
          const SectionHeader(title: '模块路由规则'),
          const SizedBox(height: AppDimens.sm),
          Text(
            '不同模块在导入时落到不同的业务通道。借还、储蓄、分期已打通：借按 6 个固定分类名'
            '路由借还台账；储蓄按「转入账户」= 计划名路由储蓄台账（建/匹配目标 + 逐期存入）；'
            '分期按「备注」= 计划名 + 「转入账户」= 负债付款账户路由分期计划（建/匹配计划 + '
            '逐期「分期订单」+ 还款自动对账标记已还）。投资已打通：按「对方」= 证券代码 + '
            '「分类」= 品种类型（股票/基金/债券/期货/期权/外汇/贵金属/加密货币/其他）+ '
            '「备注」= 名称@单价 路由投资持仓台账（买入建/增资持仓 + 支出流水、卖出减仓 + 收入流水）。'
            '报销已打通：报销到账（模块=报销 + 收入 + 报销账户）建报销收入流水（账户列=实际收款账户）'
            '+ 建待报销记录并全额抵扣翻「已报销」+ 核销报销账户挂账，维持「报销账户余额 = 待收垫付」不变量；'
            '垫付侧（支出 + 可报销=Y + 报销账户）走通用路径自动挂报销账户应收。',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppDimens.sm),
          Wrap(
            spacing: AppDimens.sm,
            runSpacing: AppDimens.sm,
            children: <Widget>[
              for (final _Module m in _modules) _ModChip(m: m),
            ],
          ),
          const SizedBox(height: AppDimens.md),
          Container(
            decoration: BoxDecoration(
              color: AppPalette.softGreen.withValues(alpha: isDark ? 0.18 : 1),
              borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              border: Border.all(color: scheme.outline),
            ),
            padding: const EdgeInsets.all(AppDimens.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '借还（Phase 2 已支持）：借还模块不靠普通分类，而是靠 6 个固定分类名决定走向。'
                  '必须填「对方」列。债务消减 / 坏账计提无需真实资产账户（账户可空），其余 4 类需指定账户。',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppPalette.ctaGreen,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppDimens.sm),
                Wrap(
                  spacing: AppDimens.sm,
                  runSpacing: AppDimens.sm,
                  children: <Widget>[
                    for (final _Op op in _ops)
                      SizedBox(
                        width: (MediaQuery.of(context).size.width - 64) / 2,
                        child: _OpTile(op: op),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.lg),

          // Examples
          const SectionHeader(title: '填写示例'),
          const SizedBox(height: AppDimens.sm),
          Text(
            '下面是模板附带的可直接复制的真实样例（含一行借还）。每行严格 16 列；'
            '含逗号的数字（如 1,000.00）在 CSV 中会被自动加引号。',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppDimens.sm),
          for (final _Example ex in _examples) ...<Widget>[
            _ExampleRow(ex: ex),
            const SizedBox(height: AppDimens.sm),
          ],
          const SizedBox(height: AppDimens.lg),

          // Copy template
          const SectionHeader(title: '复制空白模板'),
          const SizedBox(height: AppDimens.sm),
          Text(
            '把下面整段（含表头）粘贴为 .csv 文件即可。第一行是表头，其后每行一条交易。',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppDimens.sm),
          HairlineCard(
            padding: EdgeInsets.zero,
            child: Stack(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: SelectableText(
                    _template,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.55,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: OutlinedButton.icon(
                    onPressed: _copyTemplate,
                    icon: LineGlyph(
                      _copied ? Icons.check : Icons.copy,
                      size: 16,
                      color: AppPalette.ctaGreen,
                    ),
                    label: Text(_copied ? '已复制' : '复制'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppPalette.ctaGreen,
                      side: const BorderSide(color: AppPalette.ctaGreen),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusMd),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.lg),

          // Validation
          const SectionHeader(title: '导入校验要点'),
          const SizedBox(height: AppDimens.sm),
          HairlineCard(
            child: Column(
              children: const <Widget>[
                _Rule('必填列（日期 / 类型 / 金额 / 账户）缺失会被逐行拦截并提示行号。'),
                _Rule('金额为正数，不接受 0 或负数；格式最多两位小数。'),
                _Rule('借还行必须指定「分类」（6 个固定名之一）与「对方」；借入 / 借出 / '
                    '还债 / 收债还需指定「账户」，债务消减 / 坏账计提账户可空。'),
                _Rule('转账行必须填「转入账户」，否则拦截。'),
                _Rule('储蓄行必须指定「转入账户」= 储蓄计划名；账户列 = 扣款账户（可空 = 灵活存入，'
                    '无联动流水），导入即建/匹配目标并按期存入台账。'),
                _Rule('分期行类型必须为「转账」，账户列 = 扣款账户、转入账户 = 负债付款账户'
                    '（花呗/信用卡，导入缺失时建为负债类），备注 = 计划名（如 iPhone 分期）；'
                    '导入即建/匹配分期计划、逐期生成「分期订单」并还款自动对账标记已还。'),
                _Rule('投资行类型须为「支出」(买入) 或「收入」(卖出)；禁止填「转账」。'
                    '对方 = 证券代码（如 000300 / AAPL / BTC），分类 = 品种类型'
                    '（股票/基金/债券/期货/期权/外汇/贵金属/加密货币/其他，缺省按代码兜底：'
                    '6 位数字 / .SH/.SZ/.BJ/.HK / 纯字母 → 股票，其余 → 基金）；'
                    '备注 = 名称@单价（单价元计，至多两位小数），可追加空格 + 用户备注；'
                    '优惠列作手续费。卖出前该证券须已有买入。'),
                _Rule('报销的「支出侧」不要填模块=报销——垫付请用普通支出 + 可报销=Y + '
                    '报销账户（走通用路径自动挂报销账户应收）；模块=报销仅用于报销到账的收入：'
                    '类型须为「收入」、报销账户必填、「账户」列填实际收款账户（如微信/银行卡），'
                    '导入即建报销收入流水 + 待报销记录并全额抵扣翻「已报销」+ 核销报销账户挂账。'),
                _Rule('账户 / 分类 / 报销账户 / 账本按名称匹配，不存在自动创建；借还对方不会创建账户；'
                    '储蓄的「转入账户」是计划名、不会创建账户。'),
                _Rule('导出的 CSV 再次导入可无损往返（借还的「对方」、储蓄的「计划名 + 逐期」、'
                    '投资的「证券代码 + 品种 + 名称@单价」、报销的「模块=报销 + 报销账户」均会被回填）。'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyTemplate() async {
    await Clipboard.setData(const ClipboardData(text: _template));
    setState(() => _copied = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制模板到剪贴板')),
      );
    }
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _copied = false);
    });
  }
}

/// 列信息。
class _Col {
  const _Col(this.no, this.name, this.required, this.type, this.desc);
  final int no;
  final String name;
  final bool required;
  final String type;
  final String desc;
}

/// 模块信息。
class _Module {
  const _Module(this.name, this.key, this.desc, this.state);
  final String name;
  final _ModKey key;
  final String desc;
  final String state;
}

/// 借还操作名。
class _Op {
  const _Op(this.name, this.route);
  final String name;
  final String route;
}

/// 填写示例。
class _Example {
  const _Example(this.key, this.badge, this.row, this.caption);
  final _ModKey key;
  final String badge;
  final String row;
  final String caption;
}

/// 模块配色键。
enum _ModKey { neutral, transfer, income, expense, lend, flag }

Color _modColor(_ModKey key) {
  switch (key) {
    case _ModKey.neutral:
      return AppPalette.transferBlueGray;
    case _ModKey.transfer:
      return AppPalette.transferBlueGray;
    case _ModKey.income:
      return AppPalette.income;
    case _ModKey.expense:
      return AppPalette.expense;
    case _ModKey.lend:
      return AppPalette.ctaGreen;
    case _ModKey.flag:
      return AppPalette.sageMist;
  }
}

/// 单行列规范。
class _ColRow extends StatelessWidget {
  const _ColRow({required this.col});
  final _Col col;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppDimens.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${col.no}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      col.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (col.required)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppPalette.redSoftBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '* 必填',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppPalette.expense,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '选填',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.softGreen,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        col.type,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppPalette.ctaGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  col.desc,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 模块芯片。
class _ModChip extends StatelessWidget {
  const _ModChip({required this.m});
  final _Module m;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color color = _modColor(m.key);
    final bool on = m.state != '仅标记';
    return Container(
      width: (MediaQuery.of(context).size.width - AppDimens.lg * 2 - AppDimens.sm) / 2,
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  m.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            m.desc,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            on ? '● $stateText' : '◐ $stateText',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: on ? AppPalette.income : AppPalette.sageRibbon,
            ),
          ),
        ],
      ),
    );
  }

  String get stateText => m.state;
}

/// 借还操作瓦片。
class _OpTile extends StatelessWidget {
  const _OpTile({required this.op});
  final _Op op;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            op.name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            op.route,
            style: TextStyle(
              fontSize: 10.5,
              fontFamily: 'monospace',
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 示例行。
class _ExampleRow extends StatelessWidget {
  const _ExampleRow({required this.ex});
  final _Example ex;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color color = _modColor(ex.key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppDimens.radiusChip),
              ),
              child: Text(
                ex.badge,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          ),
          child: SelectableText(
            ex.row,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11.5,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          ex.caption,
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// 校验要点行。
class _Rule extends StatelessWidget {
  const _Rule(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '✓',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppPalette.income,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                color: scheme.onSurface,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 特点卡（What's new）。
class _Feature extends StatelessWidget {
  const _Feature({
    required this.tag,
    required this.title,
    required this.body,
  });
  final String tag;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return HairlineCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: AppPalette.softGreen,
              borderRadius: BorderRadius.circular(AppDimens.radiusChip),
            ),
            child: Text(
              tag,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppPalette.ctaGreen,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero 药丸标签。
class _Pill extends StatelessWidget {
  const _Pill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppPalette.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(AppDimens.radiusChip),
          border: Border.all(
            color: AppPalette.white.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppPalette.white,
          ),
        ),
      );
}
