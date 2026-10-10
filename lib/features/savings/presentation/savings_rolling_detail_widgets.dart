import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../database/app_database.dart';
import '../../../theme/app_colors.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/amount_keypad.dart';
import '../../../shared/widgets/calendar_sheet.dart';
import '../../record/providers/recording_settings_provider.dart' show appPrefs;
import '../domain/rolling_calculator.dart';
import '../domain/savings_rolling_plan.dart';
import '../providers/savings_providers.dart';
import 'savings_schedule.dart';

/// 36 期滚存法详情可视化组件。
///
/// 与「逐期排期」模式不同：滚存法没有固定期卡，而是 36 笔独立存单
/// 各自 3 年到期、到期后本息（带小数）按取整策略续存，形成滚存链。
/// 详情页用「滚存时间轴」呈现（参数 / 汇总见顶部计划卡与进度卡）：
/// - [RollingTimelineCard]：头行「年份筛选 + 网格/列表切换」（同其他计划），
///   存单按存入年份过滤，期卡布局对齐 _EntryListTile / _EntryCard，
///   期数胶囊颜色区分「新存」与「滚存」，新存期卡可点存入 / 撤销；
/// - [RollingAdjustSheet]：计划调整（周期 / 利率 / 金额），入口在顶部计划卡。
///
/// 全部结果来自 [RollingCalculator.simulate]，UI 不重复计算。

/// 金额格式化（元，千分位 + 两位小数）。
final NumberFormat _yuanFmt = NumberFormat('#,##0.00', 'zh_CN');

/// 滚存时间轴：头行对齐其他计划（「xxxx年 ∨」年份筛选 + 网格/列表切换键），
/// 存单按存入年份过滤后逐卡展示：
/// - 列表形态：左「第N期」胶囊（绿=新存 / 橙=滚存）+ 红字「存入日期 · 本金」
///   + 灰字「存 · 累计 · 利息」+ 右侧存入状态胶囊（滚存单显「滚存」不可点）；
/// - 网格形态：半宽卡（顶日期 + 期数，中「存:本金 / 利息」，右下状态胶囊）。
class RollingTimelineCard extends StatefulWidget {
  const RollingTimelineCard({
    super.key,
    required this.plan,
    required this.goal,
    required this.entries,
    required this.depositedByIndex,
    required this.onEntryTap,
  });

  final SavingsRollingPlan plan;
  final SavingsGoal goal;

  /// 滚存逐月排期（index = 月序，金额 = baseAtPeriod）。
  final List<SavingsScheduleEntry> entries;

  /// 台账：dayIndex（月序）→ 存入记录。
  final Map<int, SavingsDeposit> depositedByIndex;

  /// 点卡存入 / 撤销（详情页 _onEntryTap，弹「存钱」底部弹层）。
  final void Function(SavingsScheduleEntry entry, SavingsDeposit? deposit)
      onEntryTap;

  @override
  State<RollingTimelineCard> createState() => _RollingTimelineCardState();
}

class _RollingTimelineCardState extends State<RollingTimelineCard> {
  /// 年份筛选（null = 自动：当前年不在范围内时取第一年，同其他计划）。
  int? _year;

  /// 形态切换（false = 列表，true = 网格），全局偏好记忆。
  bool _grid = false;

  @override
  void initState() {
    super.initState();
    // 形态记忆：与其他计划共用 [kSavingsCardGridPref]，进页即读。
    _grid = appPrefs.getBool(kSavingsCardGridPref) ?? true;
  }

  /// 形态切换并持久化（同详情页期卡）。
  void _toggleGrid() {
    setState(() => _grid = !_grid);
    appPrefs.setBool(kSavingsCardGridPref, _grid);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final RollingResult result = RollingCalculator.simulate(widget.plan);
    final DateTime start = SavingsSchedule.startOf(widget.goal);

    // 每张存单的存入/到期真实日期（排期口径：日取计划起始日）。
    final List<(RollingDeposit, DateTime, DateTime)> dated =
        <(RollingDeposit, DateTime, DateTime)>[
      for (final RollingDeposit d in result.deposits)
        (
          d,
          _monthDate(start, d.depositMonth),
          _monthDate(start, d.maturityMonth),
        ),
    ];

    // 年份集合 + 当前选择归位（同其他计划逻辑）。
    // 注意：闭包参数不做 record 解构（(_, dep, __) 会被解析成三参函数签名），
    // 统一用显式单参数 + 位置字段访问。
    final Set<int> years = dated
        .map(((RollingDeposit, DateTime, DateTime) x) => x.$2.year)
        .toSet();
    final int nowYear = DateTime.now().year;
    final int activeYear = (_year != null && years.contains(_year))
        ? _year!
        : (years.contains(nowYear)
            ? nowYear
            : (years.isEmpty ? nowYear : years.first));
    final List<(RollingDeposit, DateTime, DateTime)> yearDeposits = dated
        .where(
            ((RollingDeposit, DateTime, DateTime) x) => x.$2.year == activeYear)
        .toList();

    // 月序 → 排期项（存单 seq = 月序，供存入状态 / 点卡存入）。
    final Map<int, SavingsScheduleEntry> entryByIndex =
        <int, SavingsScheduleEntry>{
      for (final SavingsScheduleEntry e in widget.entries) e.index: e,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // 头行：「xxxx年 ∨」+ 形态切换键（同其他计划，资产详情页同款）。
        Row(
          children: <Widget>[
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _pickYear(years, activeYear),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '$activeYear年',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const Icon(Icons.expand_more, size: 20),
                  ],
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: _grid ? '切换为列表' : '切换为网格',
              icon: Icon(
                _grid ? Icons.view_list_rounded : Icons.grid_view_outlined,
                size: 20,
                color: AppPalette.deepGreen,
              ),
              onPressed: _toggleGrid,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (yearDeposits.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                '$activeYear 年暂无存单',
                style: theme.textTheme.bodySmall,
              ),
            ),
          )
        else if (_grid)
          // 网格形态（_EntryCard 同构：半宽两列）。
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.28,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: <Widget>[
              for (final (RollingDeposit d, DateTime dep, DateTime _)
                  in yearDeposits)
                _RollingGridCard(
                  deposit: d,
                  depositDate: dep,
                  saved: widget.depositedByIndex[d.seq],
                  cumulativeMinor:
                      _depositInterestAndCum(d, widget.depositedByIndex[d.seq])
                          .$2,
                  onTap: (!d.isRoll && entryByIndex[d.seq] != null)
                      ? () => widget.onEntryTap(
                          entryByIndex[d.seq]!, widget.depositedByIndex[d.seq])
                      : null,
                ),
            ],
          )
        else ...<Widget>[
          // 列表形态（_EntryListTile 同构）。
          for (final (RollingDeposit d, DateTime dep, DateTime _)
              in yearDeposits)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _node(
                theme,
                d,
                dep,
                entryByIndex[d.seq],
                widget.depositedByIndex[d.seq],
              ),
            ),
        ],
      ],
    );
  }

  /// 年份选择：底部弹 [CalendarSheet]（year 模式，资产详情页同款），
  /// 可选范围取存单实际覆盖的年份区间（含当前选中）。
  Future<void> _pickYear(Set<int> years, int activeYear) async {
    final List<int> sorted = years.toList()..sort();
    final int min = sorted.isEmpty ? activeYear - 2 : sorted.first;
    final int max = sorted.isEmpty
        ? activeYear + 9
        : (sorted.last > activeYear ? sorted.last : activeYear);
    final CalendarSelection? sel = await CalendarSheet.show(
      context,
      mode: CalendarSheetMode.year,
      initialYear: activeYear,
      firstDate: DateTime(min, 1, 1),
      lastDate: DateTime(max, 12, 31),
    );
    if (sel is CalendarYear && sel.year != activeYear) {
      setState(() => _year = sel.year);
    }
  }

  /// 绝对月号 → 真实日期（日取计划起始日，月末溢出 clamp，同排期口径）。
  DateTime _monthDate(DateTime start, int absMonth) {
    final int startIdx = start.year * 12 + (start.month - 1);
    final int eff = startIdx + (absMonth - 1);
    final DateTime anchor = DateTime(eff ~/ 12, eff % 12 + 1, 1);
    final int lastDay = DateTime(anchor.year, anchor.month + 1, 0).day;
    final int day = start.day > lastDay ? lastDay : start.day;
    return DateTime(anchor.year, anchor.month, day);
  }

  /// 单张存单的（利息 U，累计分）：「累计」= 该存单**自己的**到期本息，
  /// 每期新存单是独立存单、不跨期累加；滚存单本金本身已含上期滚入本息。
  /// 已存入的新存单按台账实际存入额实时折算（利率/期限取存单锁定值）；
  /// 未存入/滚存单按计划模拟值。取整用计划 [SavingsRollingPlan.roundStrategy]。
  (int, int) _depositInterestAndCum(RollingDeposit d, SavingsDeposit? saved) {
    final bool deposited = !d.isRoll && saved != null;
    if (deposited) {
      final (:int interestU, :int maturityU) = RollingCalculator.depositOutcome(
        principalMinor: saved!.amountMinor,
        rateBp: d.rateBp,
        termMonths: d.maturityMonth - d.depositMonth,
      );
      return (
        interestU,
        RollingCalculator.roundToCents(maturityU, widget.plan.roundStrategy),
      );
    }
    return (
      d.interestU,
      RollingCalculator.roundToCents(d.maturityU, widget.plan.roundStrategy),
    );
  }

  /// 单张存单期卡（对齐其他计划列表形态 _EntryListTile 布局）：
  /// 左「第N期」胶囊（绿=新存 / 橙=滚存）+ 中列（红字「存入日期 · 本金」
  /// + 灰字「存 · 累计 · 利息」）+ 右侧存入状态胶囊；
  /// 新存单可点（弹存钱层），滚存单不可点（本息自动滚存，无手动存入）。
  Widget _node(
    ThemeData theme,
    RollingDeposit d,
    DateTime depositDate,
    SavingsScheduleEntry? entry,
    SavingsDeposit? saved,
  ) {
    final bool isRoll = d.isRoll;
    final Color accent = isRoll ? AppPalette.amber : AppPalette.deepGreen;
    final bool deposited = !isRoll && saved != null;
    // 已存入的新存单：本金/利息按台账**实际存入额**实时折算
    // （修改存入金额后利息同步；利率/期限仍取该存单锁定值）；
    // 未存入或滚存单：按计划模拟值。
    final int effPrincipalMinor =
        deposited ? saved!.amountMinor : d.principalMinor;
    // 「累计」= 该存单**自己的**到期本息：每期新存单是独立存单，不跨期
    // 累加；滚存单本金本身已含上期滚入本息。已存入按实际本金折算。
    final (int effInterestU, int cumMinor) = _depositInterestAndCum(d, saved);
    // 状态胶囊文案：滚存单「滚存」；新存单 未存入 / 实际存入日期。
    final String statusText;
    if (!isRoll && saved != null) {
      statusText = DateFormat('MM月dd日').format(
        DateTime.fromMillisecondsSinceEpoch(
          saved.depositedAt,
          isUtc: true,
        ).toLocal(),
      );
    } else {
      statusText = isRoll ? '滚存' : '未存入';
    }
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: (!isRoll && entry != null)
          ? () => widget.onEntryTap(entry, saved)
          : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: <Widget>[
            // 期数胶囊（兼作新存/滚存状态色）。
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isRoll
                    ? AppPalette.amber.withValues(alpha: 0.14)
                    : AppPalette.softGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '第${d.seq}期',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // 中列：存入日期 · 本金（红字）+ 存/累计/利息（灰字）。
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${DateFormat('yyyy年MM月dd日').format(depositDate)} · '
                    '${Money.fromMinor(effPrincipalMinor).format(showSymbol: false)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.pickerRed,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '存:${Money.fromMinor(effPrincipalMinor).format(showSymbol: false)}'
                    ' · 累计:${Money.fromMinor(cumMinor).format(showSymbol: false)}'
                    ' · 利息:${_yuanFmt.format(effInterestU / 100000.0)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 状态胶囊：滚存单显「滚存」；新存单显 未存入（琥珀）/ 存入日期（绿）。
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: deposited
                    ? AppPalette.softGreen
                    : AppPalette.amber.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: deposited ? AppPalette.deepGreen : AppPalette.amber,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 滚存存单网格卡（_EntryCard 同构）：顶行日期 + 期数，
/// 中「存:本金 / 利息:x」，右下角存入状态胶囊（滚存单显「滚存」不可点）。
class _RollingGridCard extends StatelessWidget {
  const _RollingGridCard({
    required this.deposit,
    required this.depositDate,
    required this.saved,
    required this.cumulativeMinor,
    required this.onTap,
  });

  final RollingDeposit deposit;
  final DateTime depositDate;

  /// 台账（滚存单为 null，不可存入）。
  final SavingsDeposit? saved;

  /// 「累计」= 该存单自己的到期本息（分），父级用
  /// [_depositInterestAndCum] 折算（已存入按实际本金）。
  final int? cumulativeMinor;

  /// null = 不可点（滚存单）。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isRoll = deposit.isRoll;
    final bool deposited = !isRoll && saved != null;
    // 已存入的新存单：本金/利息按台账**实际存入额**实时折算（与列表卡同口径）；
    // 未存入或滚存单：按计划模拟值。
    final int effPrincipalMinor =
        deposited ? saved!.amountMinor : deposit.principalMinor;
    final int effInterestU = deposited
        ? RollingCalculator.depositOutcome(
            principalMinor: effPrincipalMinor,
            rateBp: deposit.rateBp,
            termMonths: deposit.maturityMonth - deposit.depositMonth,
          ).interestU
        : deposit.interestU;
    final int cumMinor = cumulativeMinor ?? 0;
    // 状态胶囊文案：滚存单「滚存」；新存单 未存入 / 实际存入日期。
    final String statusText;
    if (!isRoll && saved != null) {
      statusText = DateFormat('MM月dd日').format(
        DateTime.fromMillisecondsSinceEpoch(
          saved!.depositedAt,
          isUtc: true,
        ).toLocal(),
      );
    } else {
      statusText = isRoll ? '滚存' : '未存入';
    }
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 3,
                  height: 13,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        AppPalette.sageMist,
                        AppPalette.sageRibbon,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    DateFormat('MM月dd日').format(depositDate),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '第${deposit.seq}期',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Center(
              child: Text(
                '存:${Money.fromMinor(effPrincipalMinor).format(showSymbol: false)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Center(
              child: Text(
                '累计:${Money.fromMinor(cumMinor).format(showSymbol: false)}'
                ' · 利息:${_yuanFmt.format(effInterestU / 100000.0)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: deposited
                      ? AppPalette.softGreen
                      : AppPalette.amber.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: deposited ? AppPalette.deepGreen : AppPalette.amber,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 调整记录编辑行（起始期 + 值；值语义由所在分组决定：新利率 % / 每月金额 ¥）。
class _AdjustRow {
  _AdjustRow({int? from, String? value})
      : fromPeriod = TextEditingController(text: from?.toString()),
        value = TextEditingController(text: value);
  final TextEditingController fromPeriod;
  final TextEditingController value;

  void dispose() {
    fromPeriod.dispose();
    value.dispose();
  }
}

/// 计划调整弹层：维护利率调整（银行浮动利率：某期起改用新利率）与
/// 金额调整（某期起每月存入改用新金额，用于后期追加定投）。
/// 保存返回新计划副本（[SavingsRollingPlan.copyWith]），由调用方落库。
class RollingAdjustSheet extends StatefulWidget {
  const RollingAdjustSheet({super.key, required this.initial});

  final SavingsRollingPlan initial;

  @override
  State<RollingAdjustSheet> createState() => _RollingAdjustSheetState();
}

class _RollingAdjustSheetState extends State<RollingAdjustSheet> {
  /// 周期修改：建仓期数 / 单笔期限（整数，月）。
  late final TextEditingController _periods;
  late final TextEditingController _term;

  /// 滚存停止方式（与创建页同款分段）+ 条件输入（轮数 / 目标额）。
  late RollingRollMode _rollMode;
  late final TextEditingController _rounds;
  late final TextEditingController _target;

  final List<_AdjustRow> _rateRows = <_AdjustRow>[];
  final List<_AdjustRow> _amountRows = <_AdjustRow>[];

  @override
  void initState() {
    super.initState();
    _periods = TextEditingController(text: '${widget.initial.periods}');
    _term = TextEditingController(text: '${widget.initial.termMonths}');
    _rollMode = widget.initial.rollMode;
    _rounds = TextEditingController(
      text: widget.initial.rollRounds > 0 ? '${widget.initial.rollRounds}' : '',
    );
    _target = TextEditingController(
      text: widget.initial.rollTargetMinor != null
          ? (widget.initial.rollTargetMinor! / 100).toStringAsFixed(2)
          : '',
    );
    // 单行语义：只显示「当前生效」的一条调整（列表按起始期升序，取最后
    // 一条），不罗列历史；新调整保存后整体替换（引擎 rateFor/baseAtPeriod
    // 均取「起始期 ≤ 当期的最后一条」，单条即可表达「某期起一直生效」）。
    final List<RollingRateOverride> rateOverrides =
        widget.initial.rateOverrides;
    if (rateOverrides.isNotEmpty) {
      final RollingRateOverride o = rateOverrides.last;
      _rateRows.add(
        _AdjustRow(
          from: o.fromPeriod,
          value: (o.rateBp / 100).toStringAsFixed(2),
        ),
      );
    }
    final List<RollingAmountOverride> amountOverrides =
        widget.initial.amountOverrides;
    if (amountOverrides.isNotEmpty) {
      final RollingAmountOverride o = amountOverrides.last;
      _amountRows.add(
        _AdjustRow(
          from: o.fromPeriod,
          value: (o.amountMinor / 100).toStringAsFixed(2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _periods.dispose();
    _term.dispose();
    _rounds.dispose();
    _target.dispose();
    for (final _AdjustRow r in _rateRows) {
      r.dispose();
    }
    for (final _AdjustRow r in _amountRows) {
      r.dispose();
    }
    super.dispose();
  }

  int _int(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;
  double _dbl(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  void _save() {
    // 单行语义：只取弹层里那一行，保存即整体替换旧调整（不罗列历史）；
    // 行为空/非法（起始期 <1 或值非正）= 清空调整，回退基础利率/金额。
    final List<RollingRateOverride> rates = <RollingRateOverride>[];
    if (_rateRows.isNotEmpty) {
      final int f = _int(_rateRows.first.fromPeriod);
      final double pct = _dbl(_rateRows.first.value);
      if (f >= 1 && pct > 0) {
        rates.add(
          RollingRateOverride(fromPeriod: f, rateBp: (pct * 100).round()),
        );
      }
    }

    final List<RollingAmountOverride> amounts = <RollingAmountOverride>[];
    if (_amountRows.isNotEmpty) {
      final int f = _int(_amountRows.first.fromPeriod);
      final double yuan = _dbl(_amountRows.first.value);
      if (f >= 1 && yuan > 0) {
        amounts.add(
          RollingAmountOverride(
            fromPeriod: f,
            amountMinor: Money.fromDecimal(yuan).minor,
          ),
        );
      }
    }

    // 周期修改：非正数回落原值（不合法输入不静默改坏计划）。
    final int periods =
        _int(_periods) > 0 ? _int(_periods) : widget.initial.periods;
    final int termMonths =
        _int(_term) > 0 ? _int(_term) : widget.initial.termMonths;

    // 滚存停止方式：按所选模式落 rollRounds / rollTargetMinor
    // （未填或非正数回落为永久滚存）。注意 rollMode 是派生 getter
    // （target 优先），切换回永久/N轮必须把 rollTargetMinor 置 null，
    // copyWith 做不到（?? 回落旧值），故整构造新 plan。
    final int rounds = _rollMode == RollingRollMode.rounds && _int(_rounds) > 0
        ? _int(_rounds)
        : 0;
    final int? targetMinor =
        _rollMode == RollingRollMode.target && _dbl(_target) > 0
            ? Money.fromDecimal(_dbl(_target)).minor
            : null;

    final SavingsRollingPlan p = widget.initial;
    Navigator.of(context).pop(
      SavingsRollingPlan(
        id: p.id,
        goalId: p.goalId,
        bookId: p.bookId,
        baseMinor: p.baseMinor,
        annualRateBp: p.annualRateBp,
        termMonths: termMonths,
        periods: periods,
        roundStrategy: p.roundStrategy,
        autoRoll: p.autoRoll,
        rollAddNew: p.rollAddNew,
        rollRounds: rounds,
        rollTargetMinor: targetMinor,
        rateOverrides: rates,
        amountOverrides: amounts,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 避让系统键盘（本弹层虽全用共享键盘，仍保留以防万一）。
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: AppPalette.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppPalette.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                '计划调整',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '已存入的存单不受影响（利率 / 本金在存入时锁定），调整从所设期起生效',
                style: TextStyle(
                  fontSize: 12,
                  color: AppPalette.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              // 周期修改：建仓期数 / 单笔期限（整数，月）。
              _periodSection(),
              const SizedBox(height: 16),
              // 滚存停止方式：永久 / N 轮 / 到目标（与创建页同款分段）。
              _rollModeSection(),
              const SizedBox(height: 16),
              _section(
                title: '利率调整',
                subtitle: '银行浮动利率：某期起改用新利率（保存后覆盖旧调整）',
                rows: _rateRows,
                valueLabel: '新利率（%）',
                valueHint: '2.00',
                valuePrefix: '%',
                onAdd: () {
                  if (_rateRows.isEmpty) {
                    setState(() => _rateRows.add(_AdjustRow()));
                  }
                },
                emptyText: '暂无利率调整，全部存入按基础年利率',
              ),
              const SizedBox(height: 16),
              _section(
                title: '金额调整',
                subtitle: '某期起每月存入改用新金额（保存后覆盖旧调整）',
                rows: _amountRows,
                valueLabel: '每月存入（元）',
                valueHint: '2000',
                valuePrefix: '¥',
                onAdd: () {
                  if (_amountRows.isEmpty) {
                    setState(() => _amountRows.add(_AdjustRow()));
                  }
                },
                emptyText: '暂无金额调整，全部按每月存入本金',
              ),
              const SizedBox(height: 20),
              // 保存键（全站口径：深绿实底胶囊）。
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.deepGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '保存',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 周期修改分组：建仓期数 + 单笔期限（整数输入，共享数字键盘）。
  Widget _periodSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.surfaceMist,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '周期修改',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            '建仓月数与单笔存期（月）；已存入的存单不受影响，调整后重建模拟',
            style: TextStyle(
              fontSize: 11.5,
              color: AppPalette.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _field(_periods, '建仓期数（月）', '36'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _field(_term, '单笔期限（月）', '36'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 滚存停止方式分组：永久 / N 轮 / 到目标分段（创建页同款），
  /// N 轮 → 轮数输入；到目标 → 目标额输入（¥ 前缀）。
  Widget _rollModeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.surfaceMist,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '滚存停止方式',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            '存单到期后自动续存何时停止；「轮」= 建仓期数个月',
            style: TextStyle(
              fontSize: 11.5,
              color: AppPalette.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          _segmentRow<RollingRollMode>(
            items: const <(RollingRollMode, String)>[
              (RollingRollMode.permanent, '永久'),
              (RollingRollMode.rounds, 'N 轮'),
              (RollingRollMode.target, '到目标'),
            ],
            selected: _rollMode,
            onSelected: (RollingRollMode s) => setState(() => _rollMode = s),
          ),
          const SizedBox(height: 10),
          if (_rollMode == RollingRollMode.rounds)
            _field(_rounds, '滚存轮数（每轮 = 建仓期数个月）', '5', allowDecimal: false)
          else if (_rollMode == RollingRollMode.target)
            _field(_target, '滚存到累计到期额达到（元）', '100000', prefix: '¥'),
        ],
      ),
    );
  }

  /// 全站口径胶囊分段行（创建页同款）：选中 = 软绿底 + 深绿字 + 勾；
  /// 未选 = 奶油底 + 发丝线。
  Widget _segmentRow<T>({
    required List<(T, String)> items,
    required T selected,
    required ValueChanged<T> onSelected,
  }) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < items.length; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelected(items[i].$1),
              child: Container(
                height: 38,
                margin: EdgeInsets.only(right: i == items.length - 1 ? 0 : 8),
                decoration: BoxDecoration(
                  color: items[i].$1 == selected
                      ? AppPalette.softGreen
                      : AppPalette.cream,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: items[i].$1 == selected
                        ? AppPalette.sage300
                        : AppPalette.hairline,
                  ),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (items[i].$1 == selected) ...<Widget>[
                      const Icon(Icons.check,
                          size: 15, color: AppPalette.deepGreen),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      items[i].$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: items[i].$1 == selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: items[i].$1 == selected
                            ? AppPalette.deepGreen
                            : AppPalette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required List<_AdjustRow> rows,
    required String valueLabel,
    required String valueHint,
    required String valuePrefix,
    required VoidCallback onAdd,
    required String emptyText,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.surfaceMist,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppPalette.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                emptyText,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppPalette.textTertiary,
                ),
              ),
            )
          else ...<Widget>[
            for (int i = 0; i < rows.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _field(
                        rows[i].fromPeriod,
                        '起始期（第几月）',
                        '13',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _field(
                        rows[i].value,
                        valueLabel,
                        valueHint,
                        prefix: valuePrefix,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: AppPalette.expense,
                      ),
                      onPressed: () {
                        setState(() {
                          rows[i].dispose();
                          rows.removeAt(i);
                        });
                      },
                    ),
                  ],
                ),
              ),
          ],
          TextButton.icon(
            onPressed: onAdd,
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.deepGreen,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: Text('添加$title'),
          ),
        ],
      ),
    );
  }

  /// 弹层内紧凑输入框（共享数字键盘，同创建页口径）。
  /// [allowDecimal] 传 false 时为整数输入（如滚存轮数）。
  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint, {
    String? prefix,
    bool allowDecimal = true,
  }) {
    return KeypadField(
      controller: ctrl,
      title: label,
      allowDecimal: allowDecimal,
      maxDecimalDigits: 2,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppPalette.textTertiary,
        ),
        isDense: true,
        prefixIcon: prefix == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 12, right: 6),
                child: Text(
                  prefix,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.deepGreen,
                  ),
                ),
              ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: AppPalette.cream,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
