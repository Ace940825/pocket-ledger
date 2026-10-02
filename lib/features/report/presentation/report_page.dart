import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_dimens.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/calendar_sheet.dart';
import '../../../shared/widgets/category_icons.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../theme/app_colors.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../ledger/presentation/ledger_filter_page.dart';
import '../../ledger/presentation/transaction_detail_sheet.dart';
import '../../ledger/presentation/widgets/transaction_tile.dart';
import '../../ledger/providers/ledger_providers.dart';
import '../../record/presentation/record_sheet.dart';
import '../../record/providers/recording_settings_provider.dart' show appPrefs;
import '../providers/report_providers.dart';
import 'report_category_detail_page.dart';

/// 报表页：报表 / 日历双 Tab。
///
/// 报表 Tab = 周期选择（全局共用日历组件，周/月/年/自定义）+ 高级筛选
/// + 三分支统计卡（周/月/年支出、收入、其他）
/// + 环形图（点击中心切换大类/小类）+ 分类明细排行。
/// 日历 Tab = 双形态：年视图（年支出/年收入 + 12 月宫格 + 年账单明细）
/// 与月视图（时间切到月份时：支出/收入/收支/结余四视角月历 +
/// 月结余/日均收入 + 当日账单列表），共用报表筛选。
/// 所有聚合都在本地完成，口径与账单页共享（applyLedgerAdvancedFilter）。
/// 「报表页面设置 · 优先展示」持久化键。
const String kReportSettingsPrefsKey = 'report_page_settings_v1';

/// 启动时按「优先展示」决定报表页初始 Tab（0 报表 / 1 日历）。
int _reportInitialTabIndex() {
  final String? raw = appPrefs.getString(kReportSettingsPrefsKey);
  if (raw == null) return 0;
  try {
    final Map<String, dynamic> m = jsonDecode(raw) as Map<String, dynamic>;
    return m['preferTab'] == 'calendar' ? 1 : 0;
  } catch (_) {
    return 0;
  }
}

/// 「日历报表阈值」持久化键。
const String kReportThresholdPrefsKey = 'report_cal_thresholds_v1';

/// 日历报表阈值默认值（支出/收入/结余 各 3 级，元）。
Map<String, List<double>> _thresholdDefaults() => <String, List<double>>{
      'e': <double>[0, 200, 300],
      'i': <double>[0, 200, 300],
      'b': <double>[0, 200, 300],
    };

/// 从偏好读取阈值（脏数据回退默认）。
Map<String, List<double>> _readThresholdPrefs() {
  final String? raw = appPrefs.getString(kReportThresholdPrefsKey);
  if (raw == null) return _thresholdDefaults();
  try {
    final Map<String, dynamic> m = jsonDecode(raw) as Map<String, dynamic>;
    List<double> read(String key) {
      final List<dynamic>? list = m[key] as List<dynamic>?;
      if (list == null || list.length != 3) return _thresholdDefaults()[key]!;
      return list.map((dynamic e) => (e as num).toDouble()).toList();
    }

    return <String, List<double>>{'e': read('e'), 'i': read('i'), 'b': read('b')};
  } catch (_) {
    return _thresholdDefaults();
  }
}

/// 日历报表阈值（报表 Tab / 日历 Tab 共享，任一处保存即时生效）。
final StateProvider<Map<String, List<double>>> reportThresholdProvider =
    StateProvider<Map<String, List<double>>>(
        (Ref ref) => _readThresholdPrefs());

/// 打开「日历报表阈值」弹窗（保存后写共享 provider + 持久化）。
void _showReportThresholdSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppPalette.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext ctx) => _ThresholdSheet(
      initial: ref.read(reportThresholdProvider),
      onSave: (Map<String, List<double>> v) async {
        ref.read(reportThresholdProvider.notifier).state = v;
        await appPrefs.setString(kReportThresholdPrefsKey, jsonEncode(v));
      },
    ),
  );
}

class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: _reportInitialTabIndex(),
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: SizedBox(
            width: 200,
            child: TabBar(
              tabs: const <Widget>[Tab(text: '报表'), Tab(text: '日历')],
              onTap: (_) {},
              // 去掉选中下划线指示条（仅以文字颜色区分选中态）。
              // indicatorColor 在主题带 BoxDecoration indicator 时不生效，须显式置空。
              indicator: const BoxDecoration(),
              indicatorColor: Colors.transparent,
              dividerColor: Colors.transparent,
            ),
          ),
        ),
        body: const TabBarView(
          children: <Widget>[_ReportTab(), _CalendarTab()],
        ),
      ),
    );
  }
}

// ────────────────────────────── 日历 ──────────────────────────────

/// 单月聚合结果（内部用）。口径：
/// - 计收支 = !excludeFromStats 的普通收入/支出（年支出/年收入/结余的主口径）；
/// - 不计收支 = excludeFromStats 的收入/支出（借还流水等）；
/// - 不计预算 = excludeFromBudget 的收入/支出（与上面两组可能重叠）。
class _MonthAgg {
  int count = 0;
  int income = 0; // 计收支收入
  int expense = 0; // 计收支支出
  int unstatsExpense = 0; // 不计收支 · 支出
  int unstatsIncome = 0; // 不计收支 · 收入
  int unbudgetExpense = 0; // 不计预算 · 支出
  int unbudgetIncome = 0; // 不计预算 · 收入

  bool get hasData => count > 0;
}

/// 单日聚合（月视图用，计收支口径：排除转账与 excludeFromStats）。
class _DayAgg {
  int expense = 0;
  int income = 0;
  int count = 0;

  bool get hasData => count > 0;
}

class _CalendarTab extends ConsumerStatefulWidget {
  const _CalendarTab();

  @override
  ConsumerState<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends ConsumerState<_CalendarTab> {
  // ────────────────────────── 状态 ──────────────────────────

  /// 月视图四视角：0 支出 / 1 收入 / 2 收支 / 3 结余。
  static const List<String> _calTabs = <String>['支出', '收入', '收支', '结余'];

  int _calView = 0;

  /// 年视图指标开关：选中的指标才在下方月份格里显示对应支/收行。
  bool _showYearExpense = true;
  bool _showYearIncome = true;

  /// null = 年视图；1~12 = 月视图（全局 provider，与报表 Tab 双向同步）。
  /// 本地字段见 reportCalendarMonthProvider，此处经 ref.watch 读取。

  /// 月视图当前选中日（null = 自动：今天优先，否则最后有账单的一天）。
  int? _selDay;

  /// 周视图当前选中日（绝对日期；null = 自动：今天在周内优先）。
  DateTime? _selWeekDay;

  /// 月历格三级色阶阈值（元）：金额 > t1 浅 / > t2 中 / > t3 深。
  /// 支出（红）/收入（绿）/结余（绿）三视角各自一组，齿轮弹窗配置；
  /// 值存共享 reportThresholdProvider（报表 Tab 设置弹窗保存后此处即时生效）。
  List<double> get _thE => ref.watch(reportThresholdProvider)['e']!;
  List<double> get _thI => ref.watch(reportThresholdProvider)['i']!;
  List<double> get _thB => ref.watch(reportThresholdProvider)['b']!;
  static const List<double> _tierAlphas = <double>[0.16, 0.38, 0.62];

  /// 金额（分）→ 三级色阶底色。调用方保证 yuan > 0。
  Color _tierBg(int minor, List<double> tiers, Color base) {
    final double yuan = minor / 100;
    int lvl = 0;
    for (int i = 0; i < 3; i++) {
      if (yuan > tiers[i]) lvl = i + 1;
    }
    return base.withValues(alpha: _tierAlphas[lvl - 1]);
  }

  // ────────────────────────── 数据 ──────────────────────────

  /// 按自然月聚合全年流水（转账不参与任何一列）。
  List<_MonthAgg> _aggregateMonths(List<Transaction> txns) {
    final List<_MonthAgg> months =
        List<_MonthAgg>.generate(12, (_) => _MonthAgg());
    for (final Transaction t in txns) {
      if (t.type == TxnType.transfer) continue;
      final DateTime local = DateTime.fromMillisecondsSinceEpoch(
        t.occurredAt,
        isUtc: true,
      ).toLocal();
      final _MonthAgg agg = months[local.month - 1];
      agg.count += 1;
      final int net = t.amountMinor - t.discountMinor;
      final bool counted = !t.excludeFromStats;
      final bool budgeted = !t.excludeFromBudget;
      if (t.type == TxnType.expense) {
        if (counted) {
          agg.expense += net;
        } else {
          agg.unstatsExpense += net;
        }
        if (!budgeted) agg.unbudgetExpense += net;
      } else if (t.type == TxnType.income) {
        if (counted) {
          agg.income += net;
        } else {
          agg.unstatsIncome += net;
        }
        if (!budgeted) agg.unbudgetIncome += net;
      }
    }
    return months;
  }

  // ────────────────────────── 交互 ──────────────────────────

  /// 时间选择：调用全局共用日历组件（纯周期模式）。确认「周」进周视图、
  /// 「月」进月视图、「年」回年视图；同时反向同步报表 Tab 的 reportPeriodProvider。
  Future<void> _pickPeriod(LedgerPeriod current) async {
    final CalendarPeriodMode m = switch (current.mode) {
      LedgerPeriodMode.week => CalendarPeriodMode.week,
      LedgerPeriodMode.month => CalendarPeriodMode.month,
      LedgerPeriodMode.year => CalendarPeriodMode.year,
      LedgerPeriodMode.custom => CalendarPeriodMode.custom,
    };
    final CalendarSelection? r = await CalendarSheet.show(
      context,
      mode: CalendarSheetMode.day,
      showDayView: false,
      headerTitle: '报表日历',
      initialPeriod: CalendarPeriod(m, current.start, current.end),
      weekStart: CalendarWeekStart.monday,
    );
    if (r is CalendarPeriod) {
      switch (r.mode) {
        case CalendarPeriodMode.month:
          setState(() {
            _selDay = null;
            _selWeekDay = null;
            _calView = 0;
          });
          ref.read(reportCalendarMonthProvider.notifier).state = r.start.month;
          ref.read(reportCalendarYearProvider.notifier).state = r.start.year;
          ref.read(reportPeriodProvider.notifier).state =
              LedgerPeriod.monthOf(DateTime(r.start.year, r.start.month));
        case CalendarPeriodMode.year:
          setState(() {
            _selDay = null;
            _selWeekDay = null;
          });
          ref.read(reportCalendarMonthProvider.notifier).state = null;
          ref.read(reportCalendarYearProvider.notifier).state = r.start.year;
          ref.read(reportPeriodProvider.notifier).state =
              LedgerPeriod.yearOf(r.start.year);
        case CalendarPeriodMode.week:
          setState(() {
            _selDay = null;
            _selWeekDay = null;
          });
          ref.read(reportCalendarMonthProvider.notifier).state = null;
          ref.read(reportCalendarYearProvider.notifier).state = r.start.year;
          ref.read(reportPeriodProvider.notifier).state = LedgerPeriod(
            mode: LedgerPeriodMode.week,
            start: r.start,
            end: r.end,
          );
        case CalendarPeriodMode.custom:
          // 自定义区间不改变日历形态（周/月/年视图均无对应形态）。
          break;
      }
    }
  }

  /// 点月宫格 / 明细行 → 报表 Tab 切到该月。
  void _openMonth(int year, int month) {
    ref.read(reportPeriodProvider.notifier).state =
        LedgerPeriod.monthOf(DateTime(year, month));
    DefaultTabController.of(context).animateTo(0);
  }

  /// 打开筛选页（与报表 Tab 共用 reportAdvancedFilterProvider）。
  Future<void> _openFilterPage(BuildContext context) async {
    final LedgerAdvancedFilter? result =
        await Navigator.of(context, rootNavigator: true)
            .push<LedgerAdvancedFilter>(
      MaterialPageRoute<LedgerAdvancedFilter>(
        builder: (BuildContext _) => LedgerFilterPage(
          initial: ref.read(reportAdvancedFilterProvider),
        ),
      ),
    );
    if (result != null) {
      ref.read(reportAdvancedFilterProvider.notifier).state = result;
    }
  }

  // ────────────────────────── 构建 ──────────────────────────

  @override
  Widget build(BuildContext context) {
    final int year = ref.watch(reportCalendarYearProvider);
    final int? calMonth = ref.watch(reportCalendarMonthProvider);
    final LedgerPeriod period = ref.watch(reportPeriodProvider);
    final List<Transaction> all = ref
            .watch(reportCalendarYearTransactionsProvider)
            .valueOrNull ??
        const <Transaction>[];
    // 周视图数据源：精确覆盖所选周（可跨年），跟随双向同步的 reportPeriodProvider。
    final List<Transaction> weekTxns = ref
            .watch(reportPeriodTransactionsProvider)
            .valueOrNull ??
        const <Transaction>[];
    final LedgerAdvancedFilter? filter = ref.watch(reportAdvancedFilterProvider);
    final Map<String, Category> cats =
        ref.watch(categoryMapProvider).valueOrNull ?? <String, Category>{};
    final List<Transaction> txns = applyLedgerAdvancedFilter(all, filter, cats);
    final List<Transaction> weekFiltered =
        applyLedgerAdvancedFilter(weekTxns, filter, cats);

    // 头部时间标签：周=起止日期区间；月=yyyy年M月；年视图=yyyy年。
    final String timeLabel;
    if (period.mode == LedgerPeriodMode.week) {
      final DateTime s = period.start;
      final DateTime e = period.end.subtract(const Duration(days: 1));
      // 同年区间尾部省略年份，跨年区间两端都带年份。
      timeLabel = s.year == e.year
          ? '${s.year}年${s.month}月${s.day}日–${e.month}月${e.day}日'
          : '${s.year}年${s.month}月${s.day}日–${e.year}年${e.month}月${e.day}日';
    } else {
      timeLabel = calMonth == null ? '$year年' : '$year年$calMonth月';
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceSm,
        AppDimens.spaceLg,
        AppDimens.spaceXl,
      ),
      children: <Widget>[
        _headerRow(timeLabel, period, filter),
        const SizedBox(height: AppDimens.spaceSm),
        if (period.mode == LedgerPeriodMode.week)
          ..._weekChildren(period.start, weekFiltered)
        else if (calMonth == null)
          ..._yearChildren(year, txns)
        else
          ..._monthChildren(year, calMonth, txns),
      ],
    );
  }

  // ── 年视图子树 ──

  List<Widget> _yearChildren(int year, List<Transaction> txns) {
    final List<_MonthAgg> months = _aggregateMonths(txns);
    int yearExpense = 0;
    int yearIncome = 0;
    int totalCount = 0;
    for (final _MonthAgg a in months) {
      yearExpense += a.expense;
      yearIncome += a.income;
      totalCount += a.count;
    }
    final int balance = yearIncome - yearExpense;

    return <Widget>[
      _yearCard(year, months, yearExpense, yearIncome),
      const SizedBox(height: AppDimens.spaceSm),
      _summaryRow(balance, yearIncome),
      const SizedBox(height: AppDimens.spaceLg),
      if (totalCount > 0) ...<Widget>[
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('年账单明细',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        _yearBillTable(year, months),
      ],
    ];
  }

  // ── 第一行：左时间（周区间/年/月）/ 右筛选 ──

  Widget _headerRow(
      String label, LedgerPeriod period, LedgerAdvancedFilter? filter) {
    final int n = filter?.conditionCount ?? 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        InkWell(
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          onTap: () => _pickPeriod(period),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceXs, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.expand_more,
                    size: 20, color: AppPalette.textSecondary),
              ],
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          onTap: () => _openFilterPage(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceXs, vertical: 4),
            child: Text(
              n > 0 ? '筛选(条件$n个)' : '筛选',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppPalette.sageInk,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 年支出/年收入 + 12 月宫格 ──

  Widget _yearCard(int year, List<_MonthAgg> months, int yearExpense,
      int yearIncome) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                    child: _yearIndicator('年支出', yearExpense, AppPalette.expense,
                        selected: _showYearExpense,
                        onToggle: () =>
                            setState(() => _showYearExpense = !_showYearExpense))),
                Expanded(
                    child: _yearIndicator('年收入', yearIncome, AppPalette.income,
                        selected: _showYearIncome,
                        onToggle: () =>
                            setState(() => _showYearIncome = !_showYearIncome))),
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
              padding: EdgeInsets.zero,
              children: <Widget>[
                for (int m = 1; m <= 12; m++)
                  _monthCell(year, m, months[m - 1],
                      showExpense: _showYearExpense,
                      showIncome: _showYearIncome),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 年支出/年收入指标键：可点选切换，未选中置灰（对勾空心圆），月份格不显示对应行。
  Widget _yearIndicator(String label, int minor, Color color,
      {required bool selected, required VoidCallback onToggle}) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      onTap: onToggle,
      child: Opacity(
        opacity: selected ? 1.0 : 0.35,
        child: Row(
          children: <Widget>[
            Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppPalette.sageLeaf : Colors.transparent,
                border: selected
                    ? null
                    : Border.all(color: AppPalette.sageLeaf, width: 1.2),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 10, color: AppPalette.white)
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppPalette.textPrimary)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                Money.fromMinor(minor).format(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 月宫格：有数据的月份按指标开关显示 支/收 金额（1 位小数，无符号），可点进报表月。
  Widget _monthCell(int year, int month, _MonthAgg agg,
      {required bool showExpense, required bool showIncome}) {
    final bool has = agg.hasData;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: has ? () => _openMonth(year, month) : null,
      child: Container(
        decoration: BoxDecoration(
          color: AppPalette.neutralMist,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
        // FittedBox：内容（月名+支/收两行）超出格高时整体等比缩小，杜绝溢出。
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '$month月',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.textPrimary),
              ),
              if (has) ...<Widget>[
                if (showExpense) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    '支:${_compact(agg.expense)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, height: 1.1, color: AppPalette.expense),
                  ),
                ],
                if (showIncome) ...<Widget>[
                  SizedBox(height: showExpense ? 1 : 3),
                  Text(
                    '收:${_compact(agg.income)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, height: 1.1, color: AppPalette.income),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 宫格金额：元 + 1 位小数、无符号无千分位（小青账同款，如 1388.5）。
  String _compact(int minor) => (minor / 100).toStringAsFixed(1);

  // ── 年结余 / 月均收入 ──

  Widget _summaryRow(int balance, int yearIncome) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceLg, vertical: AppDimens.spaceMd),
        child: Row(
          children: <Widget>[
            const Text('年结余: ',
                style: TextStyle(fontSize: 14, color: AppPalette.textPrimary)),
            Flexible(
              child: Text(
                Money.fromMinor(balance).format(),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: balance < 0 ? AppPalette.expense : AppPalette.income,
                ),
              ),
            ),
            const Spacer(),
            const Text('月均收入: ',
                style: TextStyle(fontSize: 14, color: AppPalette.textPrimary)),
            Flexible(
              child: Text(
                Money.fromMinor(yearIncome ~/ 12).format(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.income,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 年账单明细（横向滚动表格） ──

  static const double _leftW = 132; // 月份列固定宽
  static const double _colW = 92; // 数值列宽
  static const double _headH = 44; // 表头行高
  static const double _rowH = 58; // 数据行高

  Widget _yearBillTable(int year, List<_MonthAgg> months) {
    // 有数据的月份，倒序（最新在上）。
    final List<int> rows = <int>[
      for (int m = 12; m >= 1; m--)
        if (months[m - 1].hasData) m,
    ];
    // 表头列：主口径三列 + 不计收支/不计预算四列（横向滚动查看）。
    final List<(String, String?)> cols = <(String, String?)>[
      ('收入', null),
      ('支出', null),
      ('结余', null),
      ('不计收支', '支出'),
      ('不计收支', '收入'),
      ('不计预算', '支出'),
      ('不计预算', '收入'),
    ];

    Widget headerCell((String, String?) c) {
      return SizedBox(
        width: _colW,
        height: _headH,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(c.$1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.textSecondary)),
            if (c.$2 != null)
              Text(c.$2!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppPalette.textSecondary)),
          ],
        ),
      );
    }

    Widget valueCell(int minor, Color color) {
      return SizedBox(
        width: _colW,
        height: _rowH,
        child: Center(
          child: Text(
            Money.fromMinor(minor).format(),
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500, color: color),
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 左：月份列（固定，不随横向滚动）。
            SizedBox(
              width: _leftW,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    height: _headH,
                    padding: const EdgeInsets.only(left: 14),
                    alignment: Alignment.centerLeft,
                    child: Text('$year年',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppPalette.textPrimary)),
                  ),
                  for (final int m in rows) ...<Widget>[
                    Container(height: 0.6, color: AppPalette.sageLine),
                    InkWell(
                      onTap: () => _openMonth(year, m),
                      child: SizedBox(
                        height: _rowH,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 14, right: 8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Text('$m月',
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppPalette.textPrimary)),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '(${months[m - 1].count}笔)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppPalette.textTertiary),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${m}月1日-${m}月${DateTime(year, m + 1, 0).day}日',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppPalette.textTertiary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(children: <Widget>[for (final c in cols) headerCell(c)]),
                    for (final int m in rows) ...<Widget>[
                      Container(height: 0.6, width: _colW * cols.length, color: AppPalette.sageLine),
                      InkWell(
                        onTap: () => _openMonth(year, m),
                        child: Row(
                          children: <Widget>[
                            valueCell(
                                months[m - 1].income, AppPalette.income),
                            valueCell(
                                months[m - 1].expense, AppPalette.expense),
                            valueCell(
                                months[m - 1].income - months[m - 1].expense,
                                months[m - 1].income - months[m - 1].expense < 0
                                    ? AppPalette.expense
                                    : AppPalette.income),
                            valueCell(months[m - 1].unstatsExpense,
                                AppPalette.expense),
                            valueCell(
                                months[m - 1].unstatsIncome, AppPalette.income),
                            valueCell(months[m - 1].unbudgetExpense,
                                AppPalette.expense),
                            valueCell(
                                months[m - 1].unbudgetIncome, AppPalette.income),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────── 月视图 ──────────────────────────

  /// 格内金额：元 + 2 位小数、无符号（小青账同款，如 814.00）。
  String _amt(int minor) => (minor / 100).toStringAsFixed(2);

  List<Widget> _monthChildren(int year, int month, List<Transaction> txns) {
    final int dim = DateTime(year, month + 1, 0).day;
    final Map<int, _DayAgg> days = <int, _DayAgg>{};
    for (final Transaction t in txns) {
      if (t.type == TxnType.transfer || t.excludeFromStats) continue;
      final DateTime local = DateTime.fromMillisecondsSinceEpoch(
        t.occurredAt,
        isUtc: true,
      ).toLocal();
      if (local.year != year || local.month != month) continue;
      final _DayAgg d = days.putIfAbsent(local.day, _DayAgg.new);
      d.count += 1;
      final int net = t.amountMinor - t.discountMinor;
      if (t.type == TxnType.expense) {
        d.expense += net;
      } else if (t.type == TxnType.income) {
        d.income += net;
      }
    }

    int monthExpense = 0;
    int monthIncome = 0;
    for (final _DayAgg d in days.values) {
      monthExpense += d.expense;
      monthIncome += d.income;
    }
    final int balance = monthIncome - monthExpense;

    // 选中日：手动选择优先；否则今天（同年同月），否则最后有账单的一天。
    final DateTime now = DateTime.now();
    final int fallback = (now.year == year && now.month == month)
        ? now.day
        : days.isEmpty
            ? 1
            : days.keys.reduce((int a, int b) => a > b ? a : b);
    final int sel = (_selDay != null && _selDay! >= 1 && _selDay! <= dim)
        ? _selDay!
        : fallback;
    final _DayAgg selAgg = days[sel] ?? _DayAgg();

    return <Widget>[
      _monthCard(year, month, days, dim, sel),
      const SizedBox(height: AppDimens.spaceSm),
      _monthSummaryRow(monthExpense, monthIncome, dim, year, month),
      const SizedBox(height: AppDimens.spaceLg),
      _dayBillSection(DateTime(year, month, sel), selAgg, txns),
    ];
  }

  // ────────────────────────── 周视图 ──────────────────────────

  /// 周视图子树：周历卡（四视角 + 7 日条）+ 周汇总行 + 当日账单。
  List<Widget> _weekChildren(DateTime monday, List<Transaction> txns) {
    final DateTime m0 = DateTime(monday.year, monday.month, monday.day);
    final List<_DayAgg> days = List<_DayAgg>.generate(7, (_) => _DayAgg());
    for (final Transaction t in txns) {
      if (t.type == TxnType.transfer || t.excludeFromStats) continue;
      final DateTime local = DateTime.fromMillisecondsSinceEpoch(
        t.occurredAt,
        isUtc: true,
      ).toLocal();
      final int idx =
          DateTime(local.year, local.month, local.day).difference(m0).inDays;
      if (idx < 0 || idx > 6) continue;
      final _DayAgg d = days[idx];
      d.count += 1;
      final int net = t.amountMinor - t.discountMinor;
      if (t.type == TxnType.expense) {
        d.expense += net;
      } else if (t.type == TxnType.income) {
        d.income += net;
      }
    }

    int weekExpense = 0;
    int weekIncome = 0;
    for (final _DayAgg d in days) {
      weekExpense += d.expense;
      weekIncome += d.income;
    }

    // 选中日：手动选择优先（限本周）；否则今天（在周内）；否则最后有账单的一天；空则周一。
    final DateTime now = DateTime.now();
    final int todayIdx = DateTime(now.year, now.month, now.day)
        .difference(m0)
        .inDays;
    final bool todayInWeek = todayIdx >= 0 && todayIdx <= 6;
    int selIdx;
    final DateTime? picked = _selWeekDay;
    final int? pickedIdx = picked == null
        ? null
        : DateTime(picked.year, picked.month, picked.day).difference(m0).inDays;
    if (pickedIdx != null && pickedIdx >= 0 && pickedIdx <= 6) {
      selIdx = pickedIdx;
    } else if (todayInWeek) {
      selIdx = todayIdx;
    } else {
      selIdx = 0;
      for (int i = 6; i >= 0; i--) {
        if (days[i].hasData) {
          selIdx = i;
          break;
        }
      }
    }

    // 日均分母：本周已过天数（当前周=今天为止，历史/未来周=7 天）。
    final int denom = todayInWeek ? todayIdx + 1 : 7;

    return <Widget>[
      _weekCard(m0, days, selIdx),
      const SizedBox(height: AppDimens.spaceSm),
      _calSummaryRow(
          unit: '周',
          expense: weekExpense,
          income: weekIncome,
          denom: denom),
      const SizedBox(height: AppDimens.spaceLg),
      _dayBillSection(
          m0.add(Duration(days: selIdx)), days[selIdx], txns),
    ];
  }

  /// 周历卡：四视角 Tab + 齿轮 + 星期表头 + 7 日条（按视角阈值着色）。
  Widget _weekCard(DateTime m0, List<_DayAgg> days, int selIdx) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                for (int i = 0; i < _calTabs.length; i++)
                  Expanded(child: _calTabChip(i)),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    icon: const Icon(Icons.settings_outlined,
                        color: AppPalette.textSecondary),
                    onPressed: () => _showThresholdSheet(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceXs),
            Row(
              children: <Widget>[
                for (final String w in const <String>[
                  '周一',
                  '周二',
                  '周三',
                  '周四',
                  '周五',
                  '周六',
                  '周日',
                ])
                  Expanded(
                    child: Center(
                      child: Text(w,
                          style: const TextStyle(
                              fontSize: 13, color: AppPalette.textSecondary)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 74,
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < 7; i++)
                    Expanded(
                      child: _weekCell(
                          i, m0.add(Duration(days: i)), days[i], selIdx),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 周 7 日条单格：仅日期数字（小青账同款），底色按当前视角阈值色阶。
  Widget _weekCell(int idx, DateTime date, _DayAgg agg, int selIdx) {
    final bool has = agg.hasData;
    final bool selected = idx == selIdx;
    final DateTime now = DateTime.now();
    final bool isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    // 底色：与月历格同口径（支出红阶/收入绿阶/结余正绿负红）。
    Color bg = AppPalette.neutralMist;
    if (has) {
      switch (_calView) {
        case 0:
        case 2:
          bg = agg.expense > 0
              ? _tierBg(agg.expense, _thE, AppPalette.expense)
              : AppPalette.softGreen;
        case 1:
          bg = agg.income > 0
              ? _tierBg(agg.income, _thI, AppPalette.deepGreen)
              : AppPalette.softGreen;
        default:
          final int net = agg.income - agg.expense;
          if (net > 0) {
            bg = _tierBg(net, _thB, AppPalette.deepGreen);
          } else if (net < 0) {
            bg = AppPalette.expense.withValues(alpha: 0.18);
          } else {
            bg = AppPalette.softGreen;
          }
      }
    }

    // 金额行随视角：支出→支 / 收入→收 / 收支→支+收 / 结余→净额。
    final List<Widget> amounts;
    if (!has) {
      amounts = const <Widget>[];
    } else {
      switch (_calView) {
        case 0:
          amounts = <Widget>[_weekAmt('支:${_compact(agg.expense)}', AppPalette.expense)];
        case 1:
          amounts = <Widget>[_weekAmt('收:${_compact(agg.income)}', AppPalette.income)];
        case 2:
          amounts = <Widget>[
            _weekAmt('支:${_compact(agg.expense)}', AppPalette.expense),
            _weekAmt('收:${_compact(agg.income)}', AppPalette.income),
          ];
        default:
          final int net = agg.income - agg.expense;
          final Color c = net >= 0 ? AppPalette.income : AppPalette.expense;
          amounts = <Widget>[_weekAmt(_compact(net), c)];
      }
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _selWeekDay = date),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: AppPalette.deepGreen, width: 1.4)
                : isToday
                    ? Border.all(color: AppPalette.sageLeaf, width: 1.1)
                    : null,
          ),
          // FittedBox：日期+金额行超出格高时整体等比缩小，杜绝溢出。
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.1,
                    fontWeight:
                        isToday || has ? FontWeight.w700 : FontWeight.w400,
                    color: has ? AppPalette.textPrimary : AppPalette.textSecondary,
                  ),
                ),
                ...amounts,
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 周 7 日格金额行文本。
  Widget _weekAmt(String text, Color color) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 10, height: 1.15, color: color),
    );
  }

  // ── 月历卡：四视角 Tab + 星期表头 + 日宫格 ──

  Widget _monthCard(
      int year, int month, Map<int, _DayAgg> days, int dim, int sel) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                for (int i = 0; i < _calTabs.length; i++)
                  Expanded(child: _calTabChip(i)),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    icon: const Icon(Icons.settings_outlined,
                        color: AppPalette.textSecondary),
                    onPressed: () => _showThresholdSheet(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceXs),
            Row(
              children: <Widget>[
                for (final String w in const <String>[
                  '周一',
                  '周二',
                  '周三',
                  '周四',
                  '周五',
                  '周六',
                  '周日',
                ])
                  Expanded(
                    child: Center(
                      child: Text(w,
                          style: const TextStyle(
                              fontSize: 13, color: AppPalette.textSecondary)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _monthGrid(year, month, days, dim, sel),
          ],
        ),
      ),
    );
  }

  Widget _calTabChip(int i) {
    final bool selected = _calView == i;
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      onTap: () => setState(() => _calView = i),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: <Widget>[
            Text(
              _calTabs[i],
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? AppPalette.sageInk : AppPalette.textSecondary,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              height: 2.5,
              width: 22,
              decoration: BoxDecoration(
                color: selected ? AppPalette.sageLeaf : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 齿轮：报表页面设置弹窗（内含「日历报表阈值」入口）──

  void _showSettingsSheet() {
    final TabController? tabs = DefaultTabController.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppPalette.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) => _ReportSettingsSheet(
        onTabChange: (int index) => tabs?.animateTo(index),
        onOpenThreshold: _showThresholdSheet,
      ),
    );
  }

  void _showThresholdSheet() {
    _showReportThresholdSheet(context, ref);
  }

  Widget _monthGrid(
      int year, int month, Map<int, _DayAgg> days, int dim, int sel) {
    final int leading = DateTime(year, month, 1).weekday - 1; // 周一起始
    final int prevDim = DateTime(year, month, 0).day;
    final int cells = leading + dim;
    final int trailing = (7 - cells % 7) % 7;
    final int rows = (cells + trailing) ~/ 7;

    final List<(int, bool)> layout = <(int, bool)>[
      for (int i = 0; i < leading; i++) (prevDim - leading + 1 + i, false),
      for (int d = 1; d <= dim; d++) (d, true),
      for (int d = 1; d <= trailing; d++) (d, false),
    ];

    const double cellH = 62;
    return SizedBox(
      height: cellH * rows,
      child: Column(
        children: <Widget>[
          for (int r = 0; r < rows; r++)
            SizedBox(
              height: cellH,
              child: Row(
                children: <Widget>[
                  for (int col = 0; col < 7; col++)
                    Expanded(
                      child: _dayCell(
                        layout[r * 7 + col],
                        year: year,
                        month: month,
                        days: days,
                        sel: sel,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayCell(
    (int, bool)? cell, {
    required int year,
    required int month,
    required Map<int, _DayAgg> days,
    required int sel,
  }) {
    if (cell == null) return const SizedBox();
    final (int day, bool inMonth) = cell;
    final _DayAgg? agg = inMonth ? days[day] : null;
    final bool has = agg?.hasData ?? false;
    final bool selected = inMonth && day == sel;
    final DateTime now = DateTime.now();
    final bool isToday = inMonth &&
        year == now.year &&
        month == now.month &&
        day == now.day;

    // 底色：支出/收支视角按支出金额占比加深红底；有账单无支出浅绿底。
    Color bg = AppPalette.neutralMist;
    if (has) {
      switch (_calView) {
        case 0: // 支出：红阶
        case 2: // 收支：按支出强度
          bg = agg!.expense > 0
              ? _tierBg(agg.expense, _thE, AppPalette.expense)
              : AppPalette.softGreen;
        case 1: // 收入：绿阶
          bg = agg!.income > 0
              ? _tierBg(agg.income, _thI, AppPalette.deepGreen)
              : AppPalette.softGreen;
        default: // 结余：正=绿阶 / 负=浅红 / 零=浅绿
          final int net = agg!.income - agg.expense;
          if (net > 0) {
            bg = _tierBg(net, _thB, AppPalette.deepGreen);
          } else if (net < 0) {
            bg = AppPalette.expense.withValues(alpha: 0.18);
          } else {
            bg = AppPalette.softGreen;
          }
      }
    }

    final TextStyle numStyle = TextStyle(
      fontSize: 13.5,
      height: 1.05, // 收紧默认行高，防双行金额格纵向溢出
      fontWeight: isToday || has ? FontWeight.w700 : FontWeight.w400,
      color: !inMonth
          ? AppPalette.textTertiary.withValues(alpha: 0.55)
          : has
              ? AppPalette.textPrimary
              : AppPalette.textSecondary,
    );

    final List<Widget> lines;
    if (!has) {
      lines = const <Widget>[];
    } else {
      switch (_calView) {
        case 0:
        case 2: // 支出 / 收支：−支出（红） + 收入（绿）
          lines = <Widget>[
            Text('-${_amt(agg!.expense)}',
                style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.expense)),
            Text('+${_amt(agg.income)}',
                style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.income)),
          ];
        case 1: // 收入：单行
          lines = <Widget>[
            Text(_amt(agg!.income),
                style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.deepGreen)),
          ];
        default: // 结余：单行净值
          final int net = agg!.income - agg.expense;
          lines = <Widget>[
            Text(net > 0 ? '+${_amt(net)}' : _amt(net),
                style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.textPrimary)),
          ];
      }
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: inMonth ? () => setState(() => _selDay = day) : null,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: AppPalette.deepGreen, width: 1.4)
                : isToday
                    ? Border.all(color: AppPalette.sageLeaf, width: 1.1)
                    : null,
          ),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('$day', style: numStyle),
              if (lines.isNotEmpty) const SizedBox(height: 2),
              for (final Widget w in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FittedBox(fit: BoxFit.scaleDown, child: w),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 汇总行：随视角切换（支出→X支出/日均支出；收入→X收入/日均收入；
  // 收支/结余→X结余/日均结余）。月/周共用，unit = '月' | '周'。

  Widget _monthSummaryRow(
      int monthExpense, int monthIncome, int dim, int year, int month) {
    final DateTime now = DateTime.now();
    final bool current = now.year == year && now.month == month;
    final int denom = current ? now.day : dim;
    return _calSummaryRow(
      unit: '月',
      expense: monthExpense,
      income: monthIncome,
      denom: denom,
    );
  }

  Widget _calSummaryRow(
      {required String unit,
      required int expense,
      required int income,
      required int denom}) {
    final int dailyIncome = denom <= 0 ? 0 : income ~/ denom;
    final int dailyExpense = denom <= 0 ? 0 : expense ~/ denom;
    final int balance = income - expense;
    final int dailyBalance = denom <= 0 ? 0 : balance ~/ denom;

    // (标签, 金额, 颜色, 负值红)
    final (String, int, Color, bool) left;
    final (String, int, Color, bool) right;
    switch (_calView) {
      case 0: // 支出
        left = ('${unit}支出: ', expense, AppPalette.expense, false);
        right = ('日均支出: ', dailyExpense, AppPalette.expense, false);
      case 1: // 收入
        left = ('${unit}收入: ', income, AppPalette.income, false);
        right = ('日均收入: ', dailyIncome, AppPalette.income, false);
      default: // 收支 / 结余 → 结余
        left = ('${unit}结余: ', balance, AppPalette.income, true);
        right = ('日均结余: ', dailyBalance, AppPalette.income, true);
    }

    List<Widget> item((String, int, Color, bool) cfg) {
      final (String label, int minor, Color color, bool negRed) = cfg;
      final bool neg = negRed && minor < 0;
      return <Widget>[
        Text(label,
            style:
                const TextStyle(fontSize: 14, color: AppPalette.textPrimary)),
        Flexible(
          child: Text(
            Money.fromMinor(minor).format(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: neg ? AppPalette.expense : color,
            ),
          ),
        ),
      ];
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceLg, vertical: AppDimens.spaceMd),
        child: Row(
          children: <Widget>[
            ...item(left),
            const Spacer(),
            ...item(right),
          ],
        ),
      ),
    );
  }

  // ── 当日账单列表（月/周视图共用，day = 所选绝对日期） ──

  Widget _dayBillSection(
      DateTime day, _DayAgg selAgg, List<Transaction> txns) {
    final List<Transaction> dayTxns = <Transaction>[];
    for (final Transaction t in txns) {
      if (t.type == TxnType.transfer || t.excludeFromStats) continue;
      final DateTime local = DateTime.fromMillisecondsSinceEpoch(
        t.occurredAt,
        isUtc: true,
      ).toLocal();
      if (local.year != day.year ||
          local.month != day.month ||
          local.day != day.day) {
        continue;
      }
      dayTxns.add(t);
    }
    dayTxns.sort((Transaction a, Transaction b) =>
        b.occurredAt.compareTo(a.occurredAt));
    final List<Transaction> visible = switch (_calView) {
      0 => dayTxns.where((Transaction t) => t.type == TxnType.expense).toList(),
      1 => dayTxns.where((Transaction t) => t.type == TxnType.income).toList(),
      _ => dayTxns,
    };

    final String summary = switch (_calView) {
      0 => '支出 ${Money.fromMinor(selAgg.expense).format()}',
      1 => '收入 ${Money.fromMinor(selAgg.income).format()}',
      2 => '支:${_amt(selAgg.expense)} 收:${_amt(selAgg.income)}',
      _ => '结余 ${Money.fromMinor(selAgg.income - selAgg.expense).format()}',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '${day.month}月${day.day}日账单  $summary',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => openRecordSheet(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppPalette.softGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.history, size: 15, color: AppPalette.deepGreen),
                    SizedBox(width: 4),
                    Text('记一笔',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppPalette.deepGreen)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceSm),
        if (visible.isEmpty)
          EmptyState(
            icon: Icons.receipt_long_outlined,
            message: _calView == 1 ? '当天没有收入账单' : '当天没有账单',
          )
        else
          for (final Transaction t in visible)
            TransactionTile(
              transaction: t,
              onTap: () => TransactionDetailSheet.show(context, t),
            ),
      ],
    );
  }
}

// ────────────────────────────── 报表 ──────────────────────────────

/// 统计分支枚举 ReportBranch 见 report_providers.dart。

/// 环形图 / 明细行共用的一片聚合结果。
class _Slice {
  const _Slice({
    required this.key,
    required this.label,
    required this.iconKey,
    required this.minor,
    required this.count,
  });

  /// 分类聚合 key（分类 id；空串 = 未分类）。跳明细页用。
  final String key;
  final String label;
  final String? iconKey;
  final int minor; // 实付合计（amount − discount）
  final int count;
}

class _ReportTab extends ConsumerStatefulWidget {
  const _ReportTab();

  @override
  ConsumerState<_ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends ConsumerState<_ReportTab> {
  /// 当前统计分支（默认月支出）。
  ReportBranch _branch = ReportBranch.expense;

  /// 环形图聚合粒度：false=小类，true=大类（点击切换）。
  bool _byParent = false;

  // ────────────────────────── 数据 ──────────────────────────

  /// 筛选后按分支拆分。
  (List<Transaction>, List<Transaction>, List<Transaction>) _splitBranches(
    List<Transaction> txns,
  ) {
    final List<Transaction> expense = <Transaction>[];
    final List<Transaction> income = <Transaction>[];
    final List<Transaction> other = <Transaction>[];
    for (final Transaction t in txns) {
      if (t.excludeFromStats || t.type == TxnType.transfer) {
        other.add(t);
      } else if (t.type == TxnType.expense) {
        expense.add(t);
      } else if (t.type == TxnType.income) {
        income.add(t);
      }
    }
    return (expense, income, other);
  }

  int _netSum(List<Transaction> txns) {
    int sum = 0;
    for (final Transaction t in txns) {
      sum += t.amountMinor - t.discountMinor;
    }
    return sum;
  }

  /// 按分类（小类）或父分类（大类）聚合，降序。
  List<_Slice> _aggregate(
    List<Transaction> txns,
    Map<String, Category> cats, {
    required bool byParent,
  }) {
    final Map<String, _SliceBuilder> acc = <String, _SliceBuilder>{};
    for (final Transaction t in txns) {
      final Category? cat =
          (t.categoryId == null || t.categoryId!.isEmpty) ? null : cats[t.categoryId];
      final Category? top = (byParent && cat?.parentId != null)
          ? cats[cat!.parentId]
          : cat;
      final String key = top?.id ?? (cat?.id ?? '');
      final String label = top?.name ?? cat?.name ?? '未分类';
      final String? iconKey = top?.iconKey ?? cat?.iconKey;
      (acc[key] ??= _SliceBuilder(key, label, iconKey))
        ..minor += t.amountMinor - t.discountMinor
        ..count += 1;
    }
    final List<_Slice> slices = <_Slice>[
      for (final MapEntry<String, _SliceBuilder> e in acc.entries)
        _Slice(
          key: e.value.key,
          label: e.value.label,
          iconKey: e.value.iconKey,
          minor: e.value.minor,
          count: e.value.count,
        ),
    ];
    slices.sort((_Slice a, _Slice b) => b.minor - a.minor);
    return slices;
  }

  // ────────────────────────── 交互 ──────────────────────────

  /// 周期选择：调用全局共用日历组件（纯周期模式 showDayView:false，
  /// 周/月/年/自定义），确认后写回 [reportPeriodProvider]。
  Future<void> _pickPeriod(BuildContext context, LedgerPeriod current) async {
    final CalendarPeriodMode m = switch (current.mode) {
      LedgerPeriodMode.week => CalendarPeriodMode.week,
      LedgerPeriodMode.month => CalendarPeriodMode.month,
      LedgerPeriodMode.year => CalendarPeriodMode.year,
      LedgerPeriodMode.custom => CalendarPeriodMode.custom,
    };
    final CalendarSelection? r = await CalendarSheet.show(
      context,
      mode: CalendarSheetMode.day,
      showDayView: false,
      headerTitle: '报表周期',
      initialPeriod: CalendarPeriod(m, current.start, current.end),
      weekStart: CalendarWeekStart.monday,
    );
    if (r is CalendarPeriod) {
      final CalendarPeriod cp = r;
      final LedgerPeriodMode lm = switch (cp.mode) {
        CalendarPeriodMode.week => LedgerPeriodMode.week,
        CalendarPeriodMode.month => LedgerPeriodMode.month,
        CalendarPeriodMode.year => LedgerPeriodMode.year,
        CalendarPeriodMode.custom => LedgerPeriodMode.custom,
      };
      ref.read(reportPeriodProvider.notifier).state =
          LedgerPeriod(mode: lm, start: cp.start, end: cp.end);
      // 正向同步日历 Tab：年/月粒度直接落到对应视图；周/自定义只同步年份，
      // 日历形态（年视图/月视图）保持不变。
      ref.read(reportCalendarYearProvider.notifier).state = cp.start.year;
      if (cp.mode == CalendarPeriodMode.month) {
        ref.read(reportCalendarMonthProvider.notifier).state = cp.start.month;
      } else if (cp.mode == CalendarPeriodMode.year) {
        ref.read(reportCalendarMonthProvider.notifier).state = null;
      }
    }
  }

  /// 打开筛选页（与账单页同款，条件只作用于报表）。
  Future<void> _openFilterPage(BuildContext context) async {
    final LedgerAdvancedFilter? result =
        await Navigator.of(context, rootNavigator: true)
            .push<LedgerAdvancedFilter>(
      MaterialPageRoute<LedgerAdvancedFilter>(
        builder: (BuildContext _) => LedgerFilterPage(
          initial: ref.read(reportAdvancedFilterProvider),
        ),
      ),
    );
    if (result != null) {
      ref.read(reportAdvancedFilterProvider.notifier).state = result;
    }
  }

  // ────────────────────────── 构建 ──────────────────────────

  @override
  Widget build(BuildContext context) {
    final LedgerPeriod period = ref.watch(reportPeriodProvider);
    final List<Transaction> all = ref
            .watch(reportPeriodTransactionsProvider)
            .valueOrNull ??
        const <Transaction>[];
    final LedgerAdvancedFilter? filter = ref.watch(reportAdvancedFilterProvider);
    final Map<String, Category> cats =
        ref.watch(categoryMapProvider).valueOrNull ?? <String, Category>{};
    final List<Transaction> txns = applyLedgerAdvancedFilter(all, filter, cats);

    final (List<Transaction>, List<Transaction>, List<Transaction>) parts =
        _splitBranches(txns);
    final int expenseTotal = _netSum(parts.$1);
    final int incomeTotal = _netSum(parts.$2);
    final int otherTotal = _netSum(parts.$3);

    final List<Transaction> activeTxns = switch (_branch) {
      ReportBranch.expense => parts.$1,
      ReportBranch.income => parts.$2,
      ReportBranch.other => parts.$3,
    };
    final int activeTotal = switch (_branch) {
      ReportBranch.expense => expenseTotal,
      ReportBranch.income => incomeTotal,
      ReportBranch.other => otherTotal,
    };
    final List<_Slice> slices =
        _aggregate(activeTxns, cats, byParent: _byParent);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceSm,
        AppDimens.spaceLg,
        AppDimens.spaceXl,
      ),
      children: <Widget>[
        _headerRow(period, filter),
        const SizedBox(height: AppDimens.spaceSm),
        _statCard(
          periodPrefix: period.prefix,
          expenseTotal: expenseTotal,
          incomeTotal: incomeTotal,
          otherTotal: otherTotal,
          slices: slices,
          total: activeTotal,
        ),
        const SizedBox(height: AppDimens.spaceLg),
        if (slices.isNotEmpty) ...<Widget>[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('分类明细',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          for (int i = 0; i < slices.length; i++)
            _detailTile(slices[i], activeTotal, i),
        ],
      ],
    );
  }

  // ── 第一行：左周期 / 右筛选 ──

  Widget _headerRow(LedgerPeriod period, LedgerAdvancedFilter? filter) {
    final int n = filter?.conditionCount ?? 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        // 左：日历组件「2026年9月 / 自定义区间 ˅」
        InkWell(
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          onTap: () => _pickPeriod(context, period),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceXs, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  period.label,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const Icon(Icons.expand_more,
                    size: 20, color: AppPalette.textSecondary),
              ],
            ),
          ),
        ),
        // 右：筛选键（有条件时显示条数）
        InkWell(
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          onTap: () => _openFilterPage(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceXs, vertical: 4),
            child: Text(
              n > 0 ? '筛选(条件$n个)' : '筛选',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppPalette.sageInk,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 统计卡：三分支选择 + 环形图 ──

  Widget _statCard({
    required String periodPrefix,
    required int expenseTotal,
    required int incomeTotal,
    required int otherTotal,
    required List<_Slice> slices,
    required int total,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _branchSelector(
                      ReportBranch.expense, '${periodPrefix}支出', expenseTotal),
                ),
                Expanded(
                  child: _branchSelector(
                      ReportBranch.income, '${periodPrefix}收入', incomeTotal),
                ),
                Expanded(
                  child: _branchSelector(ReportBranch.other, '其他', otherTotal),
                ),
                _settingsButton(),
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),
            _donut(slices, total),
          ],
        ),
      ),
    );
  }

  Color _branchColor(ReportBranch b) => switch (b) {
        ReportBranch.expense => AppPalette.expense,
        ReportBranch.income => AppPalette.income,
        ReportBranch.other => AppPalette.textPrimary,
      };

  String _branchPrefix(ReportBranch b) => switch (b) {
        ReportBranch.expense => '支出',
        ReportBranch.income => '收入',
        ReportBranch.other => '其他',
      };

  Widget _branchSelector(ReportBranch b, String label, int minor) {
    final bool selected = _branch == b;
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      onTap: () => setState(() {
        _branch = b;
        _byParent = false;
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppPalette.sageLeaf : Colors.transparent,
                    border: Border.all(
                      color:
                          selected ? AppPalette.sageLeaf : AppPalette.sageLine,
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check,
                          size: 10, color: AppPalette.white)
                      : null,
                ),
                const SizedBox(width: 5),
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, color: AppPalette.textPrimary)),
              ],
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text(
                Money.fromMinor(minor).format(),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _branchColor(b),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsButton() {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 20,
        icon: const Icon(Icons.settings_outlined,
            color: AppPalette.textSecondary),
        onPressed: _showSettingsSheet,
      ),
    );
  }

  // ── 齿轮：报表页面设置弹窗（内含「日历报表阈值」入口）──

  void _showSettingsSheet() {
    final TabController? tabs = DefaultTabController.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppPalette.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) => _ReportSettingsSheet(
        onTabChange: (int index) => tabs?.animateTo(index),
        onOpenThreshold: () => _showReportThresholdSheet(context, ref),
      ),
    );
  }

  // ── 环形图：点击中心切换大类/小类 ──

  Widget _donut(List<_Slice> slices, int total) {
    if (slices.isEmpty || total <= 0) {
      return SizedBox(
        height: 240,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.pie_chart_outline,
                size: 56, color: AppPalette.sageLine),
            const SizedBox(height: AppDimens.spaceMd),
            const Text(
              '咦~没有发现账单哦',
              style:
                  TextStyle(fontSize: 14, color: AppPalette.textTertiary),
            ),
          ],
        ),
      );
    }
    final String centerTitle =
        '${_branchPrefix(_branch)}${_byParent ? '大类' : '小类'}';
    final String toggleHint = _byParent ? '切换小类' : '切换大类';
    // 外部标注最多画 5 条引线（slices 已按金额降序），避免小片挤成一团。
    final List<_Slice> calloutSlices = slices.length > 5
        ? slices.sublist(0, 5)
        : slices;
    return SizedBox(
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // 外部占比标注（引线 + 分类名 + 百分比），画在饼图下层，
          // 只占饼图外侧的空白区域，不遮挡扇区与点击。
          Positioned.fill(
            child: CustomPaint(
              painter: _DonutCalloutPainter(
                slices: calloutSlices,
                total: total,
              ),
            ),
          ),
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 62,
              startDegreeOffset: -90,
              sections: <PieChartSectionData>[
                for (int i = 0; i < slices.length; i++)
                  PieChartSectionData(
                    value: slices[i].minor.toDouble(),
                    color: AppPalette
                        .chartPalette[i % AppPalette.chartPalette.length],
                    radius: 46,
                    showTitle: false,
                  ),
              ],
            ),
          ),
          // 中心：分支 + 粒度，点击切换大类/小类
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _byParent = !_byParent),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  centerTitle,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  toggleHint,
                  style: const TextStyle(
                      fontSize: 11, color: AppPalette.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 分类明细行 ──

  Widget _detailTile(_Slice slice, int total, int index) {
    final double share = total <= 0 ? 0 : slice.minor / total;
    final Color color =
        AppPalette.chartPalette[index % AppPalette.chartPalette.length];
    final String pct =
        share >= 0.9995 ? '100.0%' : '${(share * 100).toStringAsFixed(1)}%';
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (BuildContext _) => ReportCategoryDetailPage(
            categoryKey: slice.key,
            byParent: _byParent,
            branch: _branch,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppPalette.sageHaze,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(categoryIconData(slice.iconKey),
                size: 20, color: AppPalette.sageInk),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        slice.label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(pct,
                        style: const TextStyle(
                            fontSize: 12, color: AppPalette.textTertiary)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2.5),
                  child: SizedBox(
                    height: 5,
                    child: Stack(
                      children: <Widget>[
                        Container(color: AppPalette.sageHaze),
                        FractionallySizedBox(
                          widthFactor: share.clamp(0.0, 1.0),
                          child: Container(color: color),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                Money.fromMinor(slice.minor).format(),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _branchColor(_branch),
                ),
              ),
              const SizedBox(height: 2),
              Text('${slice.count}笔',
                  style: const TextStyle(
                      fontSize: 11, color: AppPalette.textTertiary)),
            ],
          ),
        ],
        ),
      ),
    );
  }
}

/// 聚合累加器（内部用）。
class _SliceBuilder {
  _SliceBuilder(this.key, this.label, this.iconKey);

  final String key;
  final String label;
  final String? iconKey;
  int minor = 0;
  int count = 0;
}

/// 环形图外部标注：引线 + 分类名 + 占比（小青账同款样式）。
///
/// 角度口径与 fl_chart 一致：startDegreeOffset=-90（12 点方向起）、顺时针。
/// 引线从扇区外缘出发，先径向后斜向标签，标签左右分侧并做防重叠排版。
class _DonutCalloutPainter extends CustomPainter {
  _DonutCalloutPainter({required this.slices, required this.total});

  final List<_Slice> slices;
  final int total;

  // 与 _donut 中 PieChartData 的 centerSpaceRadius(62) + radius(46) 保持一致。
  static const double _outerR = 108;
  static const double _lineGap = 12; // 径向段长度
  static const double _minGap = 34; // 同侧标签最小垂直间距

  @override
  void paint(Canvas canvas, Size size) {
    if (slices.isEmpty || total <= 0) return;
    final Offset c = size.center(Offset.zero);

    final List<_Callout> right = <_Callout>[];
    final List<_Callout> left = <_Callout>[];
    double accDeg = -90; // startDegreeOffset
    for (final _Slice s in slices) {
      final double sweep = s.minor / total * 360;
      final double mid = accDeg + sweep / 2;
      accDeg += sweep;
      final double rad = mid * math.pi / 180;
      final double cosV = math.cos(rad);
      final Offset dir = Offset(cosV, math.sin(rad));
      final double share = s.minor / total;
      final String pct = share >= 0.9995
          ? '100%'
          : share < 0.001
              ? '<0.1%'
              : '${(share * 100).toStringAsFixed(1)}%';
      final _Callout callout = _Callout(
        tp: _buildTextPainter(s.label, pct),
        p0: c + dir * (_outerR + 2),
        p1: c + dir * (_outerR + _lineGap),
        sideRight: cosV >= 0,
        y: (c + dir * (_outerR + _lineGap)).dy,
      );
      (callout.sideRight ? right : left).add(callout);
    }
    _resolveOverlap(right, size);
    _resolveOverlap(left, size);

    final Paint linePaint = Paint()
      ..color = AppPalette.textTertiary
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (final List<_Callout> side in <List<_Callout>>[right, left]) {
      for (final _Callout cl in side) {
        // 引线：径向段 + 斜向段连到标签行高
        final double edgeX = cl.sideRight
            ? math.min(cl.p1.dx + 12, size.width - cl.tp.width - 4)
            : math.max(cl.p1.dx - 12, cl.tp.width + 4);
        final Path path = Path()
          ..moveTo(cl.p0.dx, cl.p0.dy)
          ..lineTo(cl.p1.dx, cl.p1.dy)
          ..lineTo(edgeX, cl.y);
        canvas.drawPath(path, linePaint);
        // 标签文本：右缘或左缘对齐引线端点
        final Offset topLeft = cl.sideRight
            ? Offset(edgeX + 3, cl.y - cl.tp.height / 2)
            : Offset(edgeX - cl.tp.width - 3, cl.y - cl.tp.height / 2);
        cl.tp.paint(canvas, topLeft);
      }
    }
  }

  TextPainter _buildTextPainter(String label, String pct) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppPalette.textPrimary,
              height: 1.25,
            ),
          ),
          TextSpan(
            text: '\n$pct',
            style: const TextStyle(
              fontSize: 11,
              color: AppPalette.textSecondary,
              height: 1.25,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    )..layout();
    return tp;
  }

  /// 同侧标签自上而下推开防重叠，超出底部时再自下而上收回。
  void _resolveOverlap(List<_Callout> list, Size size) {
    if (list.isEmpty) return;
    list.sort((_Callout a, _Callout b) => a.y.compareTo(b.y));
    for (int i = 1; i < list.length; i++) {
      if (list[i].y - list[i - 1].y < _minGap) {
        list[i].y = list[i - 1].y + _minGap;
      }
    }
    final double maxY = size.height - _minGap / 2;
    if (list.last.y > maxY) {
      list.last.y = maxY;
      for (int i = list.length - 2; i >= 0; i--) {
        if (list[i + 1].y - list[i].y < _minGap) {
          list[i].y = list[i + 1].y - _minGap;
        }
      }
    }
  }

  @override
  bool shouldRepaint(_DonutCalloutPainter oldDelegate) =>
      oldDelegate.slices != slices || oldDelegate.total != total;
}

/// 单条外部标注的排版与几何数据（内部用）。
class _Callout {
  _Callout({
    required this.tp,
    required this.p0,
    required this.p1,
    required this.sideRight,
    required this.y,
  });

  final TextPainter tp;
  final Offset p0; // 引线起点（扇区外缘）
  final Offset p1; // 径向段终点
  final bool sideRight; // 标签在右侧还是左侧
  double y; // 标签垂直中心（防重叠后可被调整）
}

/// 「日历报表阈值」底部弹窗（小青账同款布局）：
/// 顶部 X 关闭 + 居中标题 + 皇冠装饰；支出/收入/结余三枚胶囊切换视角；
/// 三行阈值配置（浅/中/深 三级色阶）：左侧色阶预览块 + 中间「金额>X / 默认X」
/// + 右侧「阈值金额」输入框；底部渐变「保存」胶囊按钮。
class _ThresholdSheet extends StatefulWidget {
  const _ThresholdSheet({
    required this.initial,
    required this.onSave,
  });

  /// 初始阈值：{'e': 支出, 'i': 收入, 'b': 结余}，各 3 级（元）。
  final Map<String, List<double>> initial;
  final void Function(Map<String, List<double>> value) onSave;

  @override
  State<_ThresholdSheet> createState() => _ThresholdSheetState();
}

class _ThresholdSheetState extends State<_ThresholdSheet> {
  /// 视角：0 支出 / 1 收入 / 2 结余（对应 initial 的 e/i/b）。
  static const List<String> _views = <String>['支出', '收入', '结余'];
  static const List<String> _keys = <String>['e', 'i', 'b'];
  static const List<double> _thDefaults = <double>[0, 200, 300];

  int _view = 0;

  /// 3 视角 × 3 级输入框（逐视角独立，切换互不覆盖）。
  late final List<List<TextEditingController>> _ctrls = <List<
      TextEditingController>>[
    for (final String k in _keys)
      <TextEditingController>[
        for (final double t in widget.initial[k]!)
          TextEditingController(text: t.toStringAsFixed(1)),
      ],
  ];

  @override
  void dispose() {
    for (final List<TextEditingController> list in _ctrls) {
      for (final TextEditingController c in list) {
        c.dispose();
      }
    }
    super.dispose();
  }

  /// 三级色阶预览块颜色（与月历格 _tierBg 同一梯度）。
  Color _previewColor(int tier) {
    const List<double> alphas = <double>[0.16, 0.38, 0.62];
    return switch (_view) {
      0 => AppPalette.expense.withValues(alpha: alphas[tier]),
      _ => AppPalette.deepGreen.withValues(alpha: alphas[tier]),
    };
  }

  Future<void> _save() async {
    final Map<String, List<double>> out = <String, List<double>>{};
    for (int v = 0; v < 3; v++) {
      out[_keys[v]] = <double>[
        for (int t = 0; t < 3; t++)
          double.tryParse(_ctrls[v][t].text.trim()) ??
              widget.initial[_keys[v]]![t],
      ];
    }
    Navigator.of(context).pop();
    widget.onSave(out);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // ── 头部：X + 标题 + 皇冠 ──
            Row(
              children: <Widget>[
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppPalette.neutralMist,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        size: 18, color: AppPalette.textSecondary),
                  ),
                ),
                const Expanded(
                  child: Text(
                    '日历报表阈值',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                const Icon(Icons.workspace_premium,
                    size: 24, color: AppPalette.goldStar),
              ],
            ),
            const SizedBox(height: 14),
            // ── 视角胶囊 ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (int i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setState(() => _view = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: _view == i
                              ? AppPalette.sageLeaf
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _views[i],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _view == i
                                ? AppPalette.white
                                : AppPalette.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // ── 三行阈值 ──
            for (int tier = 0; tier < 3; tier++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: <Widget>[
                    // 左：色阶预览块（数字 + 该级示例金额）。
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _previewColor(tier),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            '1',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.05,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.textPrimary,
                            ),
                          ),
                          Text(
                            _ctrls[_view][tier].text,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 9.5,
                              height: 1.1,
                              fontWeight: FontWeight.w600,
                              color: AppPalette.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 中：金额>X + 默认X。
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '金额>${_ctrls[_view][tier].text}',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '默认${_thDefaults[tier].toStringAsFixed(1)}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppPalette.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    // 右：阈值金额输入框。
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        const Text(
                          '阈值金额',
                          style: TextStyle(
                              fontSize: 12, color: AppPalette.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 110,
                          height: 40,
                          child: TextField(
                            controller: _ctrls[_view][tier],
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppPalette.neutralMist,
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            // ── 保存 ──
            SizedBox(
              width: double.infinity,
              height: 46,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(23),
                  gradient: const LinearGradient(
                    colors: <Color>[AppPalette.softGreen, AppPalette.sageLeaf],
                  ),
                ),
                child: TextButton(
                  onPressed: _save,
                  child: const Text(
                    '保存',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.white,
                    ),
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

// ────────────────────────── 报表页面设置弹窗 ──────────────────────────

/// 「报表页面设置」底部弹窗（小青账布局）：
/// 分组头「报表页面」+ 7 行设置。每行 = 圆角方图标 + 标题/副标题 + 右侧控件。
/// 全部选项即时持久化到 kReportSettingsPrefsKey（JSON）。
/// 目前真实生效：优先展示（切换报表/日历 Tab）、日历报表阈值（子弹窗）；
/// 其余选项（分类统计展示/统计图/统计图颜色/简洁设置/合并多账本分类）
/// 先落偏好值，视觉应用随后接入。
class _ReportSettingsSheet extends StatefulWidget {
  const _ReportSettingsSheet({
    required this.onTabChange,
    required this.onOpenThreshold,
  });

  /// 「优先展示」变更 → 切换报表/日历 Tab（0/1）。
  final ValueChanged<int> onTabChange;

  /// 「日历报表阈值」行点击 → 打开阈值子弹窗（设置层保持打开）。
  final VoidCallback onOpenThreshold;

  @override
  State<_ReportSettingsSheet> createState() => _ReportSettingsSheetState();
}

class _ReportSettingsSheetState extends State<_ReportSettingsSheet> {
  // 优先展示：report / calendar。
  String _preferTab = 'report';
  // 分类统计展示：list / card。
  String _catShow = 'list';
  // 统计图：donut / area。
  String _chart = 'donut';
  // 统计图颜色：调色板索引。
  int _chartColor = 0;
  bool _simple = true;
  bool _merge = true;

  /// 统计图颜色调色板（索引持久化）。
  static const List<Color> _palette = <Color>[
    AppPalette.pineGreen, // 松绿
    AppPalette.apricot, // 杏橙
    AppPalette.mistBlue, // 雾蓝
    AppPalette.orchid, // 藕紫
    AppPalette.peachPink, // 桃粉
    AppPalette.tealJade, // 青碧
  ];

  @override
  void initState() {
    super.initState();
    final String? raw = appPrefs.getString(kReportSettingsPrefsKey);
    if (raw == null) return;
    try {
      final Map<String, dynamic> m = jsonDecode(raw) as Map<String, dynamic>;
      _preferTab = (m['preferTab'] as String?) ?? _preferTab;
      _catShow = (m['catShow'] as String?) ?? _catShow;
      _chart = (m['chart'] as String?) ?? _chart;
      _chartColor = (m['chartColor'] as num?)?.toInt() ?? _chartColor;
      _simple = (m['simple'] as bool?) ?? _simple;
      _merge = (m['merge'] as bool?) ?? _merge;
    } catch (_) {
      // 脏数据忽略，沿用默认值。
    }
  }

  void _persist() {
    appPrefs.setString(
      kReportSettingsPrefsKey,
      jsonEncode(<String, dynamic>{
        'preferTab': _preferTab,
        'catShow': _catShow,
        'chart': _chart,
        'chartColor': _chartColor,
        'simple': _simple,
        'merge': _merge,
      }),
    );
  }

  // ── 通用行：圆角方图标 + 标题/副标题 + 右侧控件 ──

  Widget _row({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppPalette.softGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppPalette.deepGreen),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppPalette.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  /// 右侧胶囊组（选中=绿底白字，未选中=浅灰底）。
  Widget _pillGroup(
      List<(String, String)> options, String value, ValueChanged<String> onPick) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < options.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onPick(options[i].$1),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: value == options[i].$1
                    ? AppPalette.sageLeaf
                    : AppPalette.neutralMist,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                options[i].$2,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: value == options[i].$1
                      ? AppPalette.white
                      : AppPalette.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _divider() =>
      const Divider(height: 1, thickness: 0.6, color: AppPalette.sageLine);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // ── 头部：X + 居中标题 ──
            Row(
              children: <Widget>[
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppPalette.neutralMist,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        size: 18, color: AppPalette.textSecondary),
                  ),
                ),
                const Expanded(
                  child: Text(
                    '报表页面设置',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 32),
              ],
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // ── 分组头：报表页面 ──
                    Row(
                      children: <Widget>[
                        Container(
                          width: 4,
                          height: 15,
                          decoration: BoxDecoration(
                            color: AppPalette.sageLeaf,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '报表页面',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _row(
                      icon: Icons.sort_rounded,
                      title: '优先展示',
                      subtitle: '可将喜欢的模块作为主页显示',
                      trailing: _pillGroup(
                        <(String, String)>[
                          ('report', '报表'),
                          ('calendar', '日历'),
                        ],
                        _preferTab,
                        (String v) {
                          setState(() => _preferTab = v);
                          _persist();
                          widget.onTabChange(v == 'calendar' ? 1 : 0);
                        },
                      ),
                    ),
                    _divider(),
                    _row(
                      icon: Icons.grid_view_outlined,
                      title: '分类统计展示',
                      subtitle: '报表分类统计以列表或卡片展示',
                      trailing: _pillGroup(
                        <(String, String)>[
                          ('list', '列表'),
                          ('card', '卡片'),
                        ],
                        _catShow,
                        (String v) {
                          setState(() => _catShow = v);
                          _persist();
                        },
                      ),
                    ),
                    _divider(),
                    _row(
                      icon: Icons.donut_large_outlined,
                      title: '统计图',
                      subtitle: '报表统计图以环形或面积展示',
                      trailing: _pillGroup(
                        <(String, String)>[
                          ('donut', '环形'),
                          ('area', '面积'),
                        ],
                        _chart,
                        (String v) {
                          setState(() => _chart = v);
                          _persist();
                        },
                      ),
                    ),
                    _divider(),
                    _row(
                      icon: Icons.contrast_rounded,
                      title: '统计图颜色',
                      subtitle: '报表页面统计图颜色',
                      onTap: _pickChartColor,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _palette[_chartColor.clamp(
                                  0, _palette.length - 1)],
                              border: Border.all(
                                color: AppPalette.sageLine,
                                width: 1.5,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              size: 22, color: AppPalette.textTertiary),
                        ],
                      ),
                    ),
                    _divider(),
                    _row(
                      icon: Icons.tune_rounded,
                      title: '报表页面简洁设置',
                      subtitle: '开启后隐藏底部切换按钮',
                      trailing: Switch(
                        value: _simple,
                        activeColor: AppPalette.white,
                        activeTrackColor: AppPalette.sageLeaf,
                        inactiveThumbColor: AppPalette.white,
                        inactiveTrackColor: AppPalette.neutralMist,
                        onChanged: (bool v) {
                          setState(() => _simple = v);
                          _persist();
                        },
                      ),
                    ),
                    _divider(),
                    _row(
                      icon: Icons.donut_small_outlined,
                      title: '报表统计合并多账本分类',
                      subtitle: '将多账本同名分类合并统计',
                      trailing: Switch(
                        value: _merge,
                        activeColor: AppPalette.white,
                        activeTrackColor: AppPalette.sageLeaf,
                        inactiveThumbColor: AppPalette.white,
                        inactiveTrackColor: AppPalette.neutralMist,
                        onChanged: (bool v) {
                          setState(() => _merge = v);
                          _persist();
                        },
                      ),
                    ),
                    _divider(),
                    _row(
                      icon: Icons.calendar_month_outlined,
                      title: '日历报表阈值',
                      subtitle: '设置每日金额颜色深度样式',
                      onTap: widget.onOpenThreshold,
                      trailing: const Icon(Icons.chevron_right,
                          size: 22, color: AppPalette.textTertiary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 统计图颜色：小色板弹窗，点选即保存。
  Future<void> _pickChartColor() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppPalette.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('统计图颜色',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: <Widget>[
                  for (int i = 0; i < _palette.length; i++)
                    InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        setState(() => _chartColor = i);
                        _persist();
                        Navigator.of(ctx).pop();
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _palette[i],
                          border: _chartColor == i
                              ? Border.all(
                                  color: AppPalette.textPrimary, width: 2.5)
                              : null,
                        ),
                        child: _chartColor == i
                            ? const Icon(Icons.check,
                                size: 20, color: AppPalette.white)
                        : null,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
