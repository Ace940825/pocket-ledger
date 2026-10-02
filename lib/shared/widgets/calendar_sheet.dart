import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

import '../../core/constants/app_dimens.dart';
import '../../core/theme/forest_design_tokens.dart';
import '../../core/utils/date_utils.dart';
import '../../features/record/providers/recording_settings_provider.dart'
    show appPrefs;
import 'app_toast.dart';

/// 口袋账本「全局共用日历组件」。
///
/// 综合旧日期时间选择器（日期+时间签章卡、表盘、快选胶囊、年份面板）
/// 与账单页周期选择器（周/月/年/自定义 Tab、12 宫格月/年、周列表、自定义区间）的优点，
/// 收敛为一个组件，按 [CalendarSheetMode] 切换粒度，并按引用位置用布尔开关隐藏不需要的部件：
///
/// - [showTime]：日模式下是否显示时间拨号 + 时/分分段（隐藏=纯日期）。
/// - [showQuickChips]：日模式下是否显示「今天/昨天/前天/此刻」快选胶囊。
/// - [showYearPanel]：兼容参数（小青账式改版后年份导航走「年」粒度 chip，此参数不再生效）。
/// - [showHandle]：顶部拖拽把手。
/// - [showHeader]：日模式的 DATE & TIME 标题栏（含关闭钮）。
/// - [weekStartsOn]：周日起点 / 一起点（账单/周期用周一，其余用周日）。
/// - [showDayView]：false=纯周期模式（流水页周期选择器）：无日视图/英雄区/
///   时间圆盘/齿轮，打开直接落在 [initialPeriod] 对应视图；粒度 chip 再点
///   不回日视图；确认后返回 [CalendarPeriod]（与账本 [LedgerPeriod] 一一对应）。
///
/// 用法：
/// ```dart
/// final CalendarSelection? r = await CalendarSheet.show(
///   context,
///   mode: CalendarSheetMode.day,
///   initialDate: DateTime.now(),
/// );
/// ```
class CalendarSheet {
  CalendarSheet._();

  static Future<CalendarSelection?> show(
    BuildContext context, {
    CalendarSheetMode mode = CalendarSheetMode.day,
    DateTime? initialDate,
    DateTime? initialMonth,
    int? initialYear,
    (DateTime, DateTime)? initialRange,
    CalendarPeriod? initialPeriod,
    DateTime? firstDate,
    DateTime? lastDate,
    bool showTime = true,
    bool showQuickChips = true,
    bool showYearPanel = true,
    bool showHandle = true,
    bool showHeader = true,
    bool showDayView = true,
    String? headerTitle,
    CalendarWeekStart weekStart = CalendarWeekStart.sunday,
  }) async {
    return showModalBottomSheet<CalendarSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ForestBg.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) => _CalendarSheetBody(
        mode: mode,
        initialDate: initialDate ?? DateTime.now(),
        initialMonth: initialMonth,
        initialYear: initialYear,
        initialRange: initialRange,
        initialPeriod: initialPeriod,
        firstDate: firstDate ?? DateTime(2000),
        lastDate: lastDate ?? DateTime(2107, 12, 31),
        showTime: showTime,
        showQuickChips: showQuickChips,
        showYearPanel: showYearPanel,
        showHandle: showHandle,
        showHeader: showHeader,
        showDayView: showDayView,
        headerTitle: headerTitle,
        weekStart: weekStart,
      ),
    );
  }
}

/// 每周起点。
enum CalendarWeekStart { sunday, monday }

/// 选择粒度。
enum CalendarSheetMode { day, month, year, range }

/// 周期模式（周/月/年/自定义）。[showDayView]=false 时驱动纯周期选择器。
enum CalendarPeriodMode { week, month, year, custom }

/// 统一选择结果（密封类，调用方按类型取用）。
sealed class CalendarSelection {
  const CalendarSelection();
}

/// 单日（含时间）。
final class CalendarDay extends CalendarSelection {
  const CalendarDay(this.date);
  final DateTime date;
}

/// 某自然月。
final class CalendarMonth extends CalendarSelection {
  const CalendarMonth(this.year, this.month);
  final int year;
  final int month;
}

/// 某自然年。
final class CalendarYear extends CalendarSelection {
  const CalendarYear(this.year);
  final int year;
}

/// 自定义区间（[end] 为包含的最后一天，时间归零）。
final class CalendarRange extends CalendarSelection {
  const CalendarRange(this.start, this.end);
  final DateTime start;
  final DateTime end;
}

/// 周期（周/月/年/自定义）。[end] 为开区间（不含），与账本 [LedgerPeriod] 约定一致。
final class CalendarPeriod extends CalendarSelection {
  const CalendarPeriod(this.mode, this.start, this.end);
  final CalendarPeriodMode mode;
  final DateTime start;
  final DateTime end;

  String get label => switch (mode) {
        CalendarPeriodMode.month => '${start.year}年${start.month}月',
        CalendarPeriodMode.year => '${start.year}年',
        CalendarPeriodMode.week => '周',
        CalendarPeriodMode.custom => _rangeLabel(start, end),
      };

  static String _md(DateTime d) => '${d.month}月${d.day}日';
  static String _rangeLabel(DateTime s, DateTime e) {
    final DateTime last = e.subtract(const Duration(days: 1));
    return s.year == last.year
        ? '${_md(s)}-${_md(last)}'
        : '${s.year}年${_md(s)}-${_md(last)}';
  }
}

class _CalendarSheetBody extends StatefulWidget {
  const _CalendarSheetBody({
    required this.mode,
    required this.initialDate,
    required this.initialMonth,
    required this.initialYear,
    required this.initialRange,
    required this.initialPeriod,
    required this.firstDate,
    required this.lastDate,
    required this.showTime,
    required this.showQuickChips,
    required this.showYearPanel,
    required this.showHandle,
    required this.showHeader,
    required this.showDayView,
    required this.headerTitle,
    required this.weekStart,
  });

  final CalendarSheetMode mode;
  final DateTime initialDate;
  final DateTime? initialMonth;
  final int? initialYear;
  final (DateTime, DateTime)? initialRange;
  final CalendarPeriod? initialPeriod;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool showTime;
  final bool showQuickChips;
  final bool showYearPanel;
  final bool showHandle;
  final bool showHeader;

  /// false=纯周期模式（流水页周期选择器）：无日视图/英雄区/时间圆盘，
  /// 打开直接落在 [initialPeriod] 对应的周期视图，粒度 chip 再点不回日视图。
  final bool showDayView;

  /// 标题栏文案覆盖（默认 DATE & TIME）；纯周期模式传「账单周期」等。
  final String? headerTitle;
  final CalendarWeekStart weekStart;

  @override
  State<_CalendarSheetBody> createState() => _CalendarSheetBodyState();
}

class _CalendarSheetBodyState extends State<_CalendarSheetBody> {
  late DateTime _selected;
  late DateTime _displayedMonth;
  bool _isHourMode = false;
  bool _nowPinned = false;
  bool _heroFloat = false;
  late final ScrollController _scrollController;

  // ── 周期 Tab 状态 ──
  late CalendarPeriodMode _periodMode;
  late DateTime _selWeek;
  late int _weekYear;
  late DateTime _selMonth;
  late int _monthYear;
  late int _selYear;
  late int _decadeStart;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  /// 自定义区间两步式选日（预览 s.rstep：'s'=选起始，'e'=选截止）
  /// + 当前浏览月（预览 s.disp）——‹ › 步进与选起始后自动跳下月共用。
  String _rangeRStep = 's';
  late DateTime _rangeViewMonth;
  /// 自定义区间的宫格导航子模式：null=日宫格（点选起止日）；
  /// 'month'=年宫格（点月份跳到该月日宫格）；'year'=年宫格（点年份进月宫格）。
  /// 用于快速定位很早/很晚的日期，不必逐月横滑。
  String? _rangeNavMode;

  // ---- 月/年宫格「单击选中、双击跳转」 ----
  // 单击仅选中年/月（有的场景只需要选年份或月份，不跳月/日期）；
  // 双击才跳转下一层。用「同一格 320ms 内再点」判定双击，相比
  // InkWell.onDoubleTap 无单击选中延迟（onDoubleTap 会让 onTap 等待超时）。
  DateTime? _gridTapAt;
  int? _gridTapCell;

  /// [cell] 为带命名空间的格子键（跨宫格不复用，防串扰）。
  void _gridCellTap(int cell, VoidCallback onSelect, VoidCallback onDouble) {
    final DateTime now = DateTime.now();
    if (_gridTapCell == cell &&
        _gridTapAt != null &&
        now.difference(_gridTapAt!) < const Duration(milliseconds: 320)) {
      _gridTapAt = null;
      _gridTapCell = null;
      onDouble();
      return;
    }
    _gridTapAt = now;
    _gridTapCell = cell;
    onSelect();
  }

  ScrollController? _weekCtrl;
  /// 周滚轮重建纪元：每次重锚（chip 进入 / 跨年箭头 / ◎ 回当前）自增，
  /// 作为 ListView 的 ValueKey——已挂载的 Scrollable 换控制器只会恢复旧
  /// 滚动位置（initialScrollOffset 不生效），必须整树重建才能落位。
  int _weekEpoch = 0;
  // 三个宫格控制器均为可重建：_gotoXPage 在未挂载分支 dispose 后按
  // initialPage=目标页 重建（挂载即落位，零竞态），故不可 late final。
  late PageController _monthPageCtrl;
  late PageController _yearPageCtrl;

  /// 统一日视图的粒度 chip（小青账式）：null=日视图；周/月/年/自定义。
  /// 再点当前激活 chip 返回日视图；月/年宫格为导航（点选后自动跳回）。
  CalendarPeriodMode? _dayViewTab;
  late PageController _dayPageCtrl;

  /// 自定义区间宫格 pager（与日/月/年同机制：换控制器 + ObjectKey 整树重建）。
  late PageController _rangePageCtrl;

  int _dayPageOf(DateTime m) =>
      (m.year - _kGridFirstYear) * 12 + m.month - 1;

  /// 设计稿 SETTINGS（齿轮键触发）：粒度 tab 显隐 + 时间圆盘开关。
  /// 关掉当前激活视图 → 退回第一个开启的视图（预览一致），全关则回日视图。
  final Map<CalendarPeriodMode, bool> _tabEnabled =
      <CalendarPeriodMode, bool>{
    CalendarPeriodMode.week: true,
    CalendarPeriodMode.month: true,
    CalendarPeriodMode.year: true,
    CalendarPeriodMode.custom: true,
  };
  bool _showDial = true;

  /// 齿轮设置持久化（SharedPreferences，重开弹窗/重启不丢）。
  static const String _kSettingsKey = 'calendar_sheet_settings_v1';

  /// initState 同步还原（appPrefs 已在 main() 预加载）；无记录/解析失败回落默认。
  static void _restoreSettings(Map<CalendarPeriodMode, bool> tabEnabled,
      void Function(bool) setShowDial) {
    try {
      final String? raw = appPrefs.getString(_kSettingsKey);
      if (raw == null) return;
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      for (final CalendarPeriodMode m in CalendarPeriodMode.values) {
        final Object? v = decoded[m.name];
        if (v is bool) tabEnabled[m] = v;
      }
      final Object? dial = decoded['showDial'];
      if (dial is bool) setShowDial(dial);
    } catch (_) {
      // 持久化读取失败不阻塞默认值
    }
  }

  void _persistSettings() {
    try {
      appPrefs.setString(_kSettingsKey, jsonEncode(<String, dynamic>{
        for (final MapEntry<CalendarPeriodMode, bool> e
            in _tabEnabled.entries)
          e.key.name: e.value,
        'showDial': _showDial,
      }));
    } catch (_) {
      // 持久化失败不阻塞内存态使用
    }
  }

  // 月/年宫格常量（原账本页私有，统一收纳）。
  // 末年取 2107：年宫格 12 年一页，末页 2096–2107 恰好铺满且不再越界置灰
  // （此前 2099 截止 → 末页 2101 年起灰掉不可点）。
  static const int _kGridFirstYear = 2000;
  static const int _kGridLastYear = 2107;
  static const int _kYearsPerPage = 12;
  static const double _kSheetBodyHeight = 198;
  static const double _kW = 46;
  static const double _kWeekCenterPad = (_kSheetBodyHeight - _kW) / 2;
  int get _windowPageCount =>
      ((_kGridLastYear - _kGridFirstYear + 1) / _kYearsPerPage).ceil();
  int _windowStart(int year) =>
      _kGridFirstYear +
      ((year - _kGridFirstYear) ~/ _kYearsPerPage) * _kYearsPerPage;

  @override
  void initState() {
    super.initState();
    final DateTime now = _localNow();
    _selected = widget.initialDate;
    // 齿轮设置记忆：上次开关状态（SharedPreferences）
    _restoreSettings(_tabEnabled, (bool v) => _showDial = v);
    _displayedMonth = DateTime(_selected.year, _selected.month);
    _nowPinned = _selected.year == now.year &&
        _selected.month == now.month &&
        _selected.day == now.day &&
        _selected.hour == now.hour &&
        _selected.minute == now.minute;
    _scrollController = ScrollController()
      ..addListener(() {
        final bool f = _scrollController.offset > 4;
        if (f != _heroFloat) setState(() => _heroFloat = f);
      });

    // 周期 Tab 初值
    final CalendarPeriod? ip = widget.initialPeriod;
    if (ip != null) {
      _periodMode = ip.mode;
      final DateTime base = ip.start;
      _selWeek = _mondayOf(base);
      _weekYear = _selWeek.year;
      _selMonth = DateTime(base.year, base.month);
      _monthYear = _selMonth.year;
      _selYear = ip.mode == CalendarPeriodMode.year ? base.year : now.year;
    } else {
      _periodMode = CalendarPeriodMode.month;
      final DateTime base =
          widget.initialMonth ?? DateTime(now.year, now.month);
      _selWeek = _mondayOf(base);
      _weekYear = _selWeek.year;
      _selMonth = DateTime(base.year, base.month);
      _monthYear = _selMonth.year;
      _selYear = now.year;
    }
    _decadeStart = _windowStart(_selYear);
    // 纯周期模式（流水页）：无日视图，打开直接落在当前周期视图。
    if (!widget.showDayView) {
      _dayViewTab = ip?.mode ?? CalendarPeriodMode.month;
    }
    // keepPage:false——挂载页一律由入口确定（_gotoXPage 重建控制器或直接跳），
    // 杜绝恢复旧浏览页造成「宫格页与页头脱钩」。
    _monthPageCtrl = PageController(
        initialPage: _selMonth.year - _kGridFirstYear, keepPage: false);
    _yearPageCtrl = PageController(
        initialPage:
            (_windowStart(_selYear) - _kGridFirstYear) ~/ _kYearsPerPage,
        keepPage: false);
    _dayPageCtrl = PageController(
        initialPage: _dayPageOf(_selected), keepPage: false);
    if (ip?.mode == CalendarPeriodMode.custom) {
      _rangeStart = ip!.start;
      _rangeEnd = ip.end.subtract(const Duration(days: 1));
      _rangeRStep = 's';
      _rangeViewMonth = DateTime(_rangeStart!.year, _rangeStart!.month);
    } else if (widget.initialRange != null) {
      _rangeStart = widget.initialRange!.$1;
      _rangeEnd = widget.initialRange!.$2;
      _rangeRStep = 's';
      _rangeViewMonth = DateTime(_rangeStart!.year, _rangeStart!.month);
    } else {
      _rangeRStep = 's';
      _rangeViewMonth = DateTime(_selected.year, _selected.month);
    }
    _rangePageCtrl = PageController(
        initialPage: _dayPageOf(_rangeViewMonth), keepPage: false);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _weekCtrl?.dispose();
    _monthPageCtrl.dispose();
    _yearPageCtrl.dispose();
    _dayPageCtrl.dispose();
    _rangePageCtrl.dispose();
    super.dispose();
  }

  // ---- 工具 ----

  DateTime _mondayOf(DateTime d) {
    final DateTime day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  int _leadingOf(DateTime month) {
    final int wd = DateTime(month.year, month.month, 1).weekday;
    return widget.weekStart == CalendarWeekStart.monday ? (wd - 1) % 7 : wd % 7;
  }

  bool _isMonthAllowed(DateTime month) {
    final DateTime first =
        DateTime(widget.firstDate.year, widget.firstDate.month);
    final DateTime last = DateTime(widget.lastDate.year, widget.lastDate.month);
    return !month.isBefore(first) && !month.isAfter(last);
  }

  bool _isDayAllowed(DateTime day) =>
      !day.isBefore(widget.firstDate) && !day.isAfter(widget.lastDate);

  DateTime _localNow() => localNow();

  /// 设计稿 hero 用单字周几（如「三」）。
  static const List<String> _weekdayShortCN = <String>[
    '日', '一', '二', '三', '四', '五', '六',
  ];
  String _weekdayShort(DateTime d) => _weekdayShortCN[d.weekday % 7];

  List<DateTime> _weeksOfYear(int year) {
    final DateTime jan1 = DateTime(year);
    final DateTime firstMonday =
        jan1.subtract(Duration(days: jan1.weekday - 1));
    final List<DateTime> weeks = <DateTime>[];
    DateTime w = firstMonday;
    final DateTime yearEnd = DateTime(year + 1);
    while (w.isBefore(yearEnd)) {
      weeks.add(w);
      w = w.add(const Duration(days: 7));
    }
    return weeks;
  }

  DateTime _nearestSelectableWeek(int year, DateTime sel, DateTime today) {
    final List<DateTime> weeks = _weeksOfYear(year);
    if (weeks.isEmpty) return sel;
    if (sel.isBefore(weeks.first)) return weeks.first;
    if (sel.isAfter(weeks.last)) {
      for (int i = weeks.length - 1; i >= 0; i--) {
        if (!weeks[i].isAfter(today)) return weeks[i];
      }
      return weeks.last;
    }
    DateTime? best;
    for (final DateTime w in weeks) {
      if (w.isAfter(today)) continue;
      if (best == null) {
        best = w;
      } else if (w.difference(sel).abs() < best.difference(sel).abs()) {
        best = w;
      }
    }
    return best ?? weeks.last;
  }

  // ---- 日模式操作 ----

  void _setHour(int v) => setState(() {
        _nowPinned = false;
        _selected = DateTime(_selected.year, _selected.month, _selected.day, v,
            _selected.minute);
      });

  void _setMinute(int v) => setState(() {
        _nowPinned = false;
        _selected = DateTime(
            _selected.year, _selected.month, _selected.day, _selected.hour, v);
      });

  // ── 宫格落页：换新控制器 + ObjectKey 整树重建（确定性，免疫一切污染）──
  //
  // SDK 源码事实（本机 flutter/lib/src/widgets/page_view.dart、scrollable.dart）：
  // 1. jumpToPage 在 position._cachedPage != null（视口曾以 0 尺寸布局过）或
  //    视口尺寸未就绪时【静默丢弃】——只把目标页记进 _cachedPage/
  //    _pageToUseOnStartup 后直接 return，不报错不跳转 → 页头已更新、
  //    宫格纹丝不动（页头 2024-2035 / 宫格 2072-2083 的脱钩真凶）；
  // 2. 给已挂载的 PageView 换控制器：ScrollableState.didUpdateWidget 只是
  //    detach+attach 原 position（页码原样保留），新控制器 initialPage 不生效；
  // 3. 全新 ScrollableState 首帧布局：oldPixels==null → page = initialPage，
  //    挂载即精确落位，无任何时序窗口。
  //
  // 因此跳页不再用 jumpToPage：一律换新控制器（initialPage=目标页），并给
  // PageView 挂 ObjectKey(控制器)——控制器换新 ⇒ 键变 ⇒ pager 子树整树重建，
  // 全新 position 挂载即落在目标页。已挂载/未挂载、hot reload 遗留旧 State、
  // PageStorage 等一切污染源都在重建时被洗掉。页头字段（_displayedMonth/
  // _monthYear/_decadeStart）是唯一事实来源；onPageChanged 只做纯采纳。

  void _gotoDayPage(int page, {bool animate = false}) {
    final PageController c = _dayPageCtrl;
    if (animate &&
        c.hasClients &&
        c.position.hasViewportDimension &&
        c.position.viewportDimension > 0) {
      // 同视图内 ‹ › 步进：pager 正在屏上且已布局，原位动画最顺滑。
      c.animateToPage(page,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic);
      return;
    }
    final PageController next =
        PageController(initialPage: page, keepPage: false);
    _dayPageCtrl = next;
    _retireCtrl(c);
  }

  void _gotoMonthPage(int page) {
    final PageController c = _monthPageCtrl;
    final PageController next =
        PageController(initialPage: page, keepPage: false);
    _monthPageCtrl = next;
    _retireCtrl(c);
  }

  void _gotoYearPage(int page) {
    final PageController c = _yearPageCtrl;
    final PageController next =
        PageController(initialPage: page, keepPage: false);
    _yearPageCtrl = next;
    _retireCtrl(c);
  }

  void _gotoRangePage(int page, {bool animate = false}) {
    final PageController c = _rangePageCtrl;
    if (animate &&
        c.hasClients &&
        c.position.hasViewportDimension &&
        c.position.viewportDimension > 0) {
      // 自定义 pager 在屏上（cell 点击/箭头步进）：原位动画滑页最可靠，
      // 不走换控制器重建（从宫格 cell 内触发重建落位在真机上不可靠）。
      c.animateToPage(page,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic);
      return;
    }
    final PageController next =
        PageController(initialPage: page, keepPage: false);
    _rangePageCtrl = next;
    _retireCtrl(c);
  }

  /// 旧控制器退役：仍挂着旧 pager（本帧随 ObjectKey 变化卸载并 detach）
  /// → 帧末确认无 client 后再销毁；本就无 client（目标视图未挂载）→ 立即销毁。
  void _retireCtrl(PageController c) {
    if (c.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!c.hasClients) c.dispose();
      });
    } else {
      c.dispose();
    }
  }

  /// 帧末对账（兜底）：宫格实际页必须等于页头页。滑动/惯性中跳过（用户滑动
  /// 由 onPageChanged 把页头采纳到实际页，终态收敛）；仅纠正污染（hot reload
  /// 遗留、被静默丢弃的跳页等）。正常稳态恒为 no-op，不会与用户手势打架。
  void _reconcileDayPage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final PageController c = _dayPageCtrl;
      if (!c.hasClients || c.position.isScrollingNotifier.value) return;
      final int? cur = c.page?.round();
      final int want = _dayPageOf(_displayedMonth);
      if (cur != null && cur != want) c.jumpToPage(want);
    });
  }

  void _reconcileMonthPage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final PageController c = _monthPageCtrl;
      if (!c.hasClients || c.position.isScrollingNotifier.value) return;
      final int? cur = c.page?.round();
      final int want = _monthYear - _kGridFirstYear;
      if (cur != null && cur != want) c.jumpToPage(want);
    });
  }

  void _reconcileYearPage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final PageController c = _yearPageCtrl;
      if (!c.hasClients || c.position.isScrollingNotifier.value) return;
      final int? cur = c.page?.round();
      final int want = (_decadeStart - _kGridFirstYear) ~/ _kYearsPerPage;
      if (cur != null && cur != want) c.jumpToPage(want);
    });
  }

  void _reconcileRangePage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final PageController c = _rangePageCtrl;
      if (!c.hasClients || c.position.isScrollingNotifier.value) return;
      final int? cur = c.page?.round();
      final int want = _dayPageOf(_rangeViewMonth);
      if (cur != null && cur != want) c.jumpToPage(want);
    });
  }

  /// onPageChanged 纯采纳：用户滑动或已挂载跳页后回写页头。
  void _onDayPageChanged(int page) {
    setState(() {
      _displayedMonth =
          DateTime(_kGridFirstYear + page ~/ 12, page % 12 + 1);
    });
  }

  void _onMonthPageChanged(int page) {
    setState(() => _monthYear = _kGridFirstYear + page);
  }

  void _onRangePageChanged(int page) {
    setState(() {
      _rangeViewMonth =
          DateTime(_kGridFirstYear + page ~/ 12, page % 12 + 1);
    });
  }

  void _onYearPageChanged(int page) {
    setState(() =>
        _decadeStart = _kGridFirstYear + page * _kYearsPerPage);
  }

  /// ◎ 回到当前：日视图=选中回「此刻」（含时分）、视图回本月；
  /// 周/月/年=**留在当前周期视图**，游标回到当前周期，选中（记录时间）
  /// 同步回「此刻」，不跳出周期视图；自定义=仅跳回本月继续选起止（保留已选区间）。
  void _jumpToCurrent() {
    final DateTime now = _localNow();
    if (_dayViewTab == CalendarPeriodMode.custom) {
      setState(() {
        _rangeNavMode = null; // 从年/月宫格退回日宫格
        _rangeViewMonth = DateTime(now.year, now.month);
      });
      _gotoRangePage(_dayPageOf(_rangeViewMonth), animate: true);
      return;
    }
    if (_dayViewTab != null) {
      // 周/月/年：留在当前周期视图回正当期（纯周期模式与日视图周期 chip
      // 同口径），选中时间同步回「此刻」——◎ 的语义是「回到当前」，
      // 不是「退出周期视图」（旧逻辑置 _dayViewTab=null 会错误跳回日视图）。
      setState(() {
        _selected = now;
        _nowPinned = true;
        _rangeStart = null;
        _rangeEnd = null;
        _rangeRStep = 's';
        _rangeNavMode = null;
        _rangeViewMonth = DateTime(now.year, now.month);
        _selWeek = _mondayOf(now);
        _weekYear = _selWeek.year;
        _weekEpoch++;
        _weekCtrl = null; // 周列表重建到当前周
        _selMonth = DateTime(now.year, now.month);
        _monthYear = now.year;
        _selYear = now.year;
        _decadeStart = _windowStart(now.year);
        if (widget.showDayView) {
          // 之后点粒度 chip 回日视图时落在今天，避免旧浏览月与新选中脱钩。
          _displayedMonth = DateTime(now.year, now.month);
        }
      });
      switch (_dayViewTab!) {
        case CalendarPeriodMode.week:
          break; // _weekCtrl=null 已在 setState 内触发周列表重建
        case CalendarPeriodMode.month:
          _gotoMonthPage(now.year - _kGridFirstYear);
        case CalendarPeriodMode.year:
          _gotoYearPage(
              (_windowStart(now.year) - _kGridFirstYear) ~/ _kYearsPerPage);
        case CalendarPeriodMode.custom:
          break;
      }
      if (widget.showDayView) {
        _gotoDayPage(_dayPageOf(_displayedMonth), animate: true);
      }
      return;
    }
    setState(() {
      _selected = now;
      _displayedMonth = DateTime(now.year, now.month);
      _nowPinned = true;
      _rangeStart = null;
      _rangeEnd = null;
      _rangeRStep = 's';
      _rangeViewMonth = DateTime(now.year, now.month);
      _rangeNavMode = null; // 回正后退出自定义宫格导航
      // 年/月宫格选区与浏览页同步锁定回当前年份（否则再次进入年视图时
      // 旧控制器恢复旧浏览页，与页头脱钩）。
      _selYear = now.year;
      _selMonth = DateTime(now.year, now.month);
      _monthYear = now.year;
      _decadeStart = _windowStart(now.year);
    });
    _gotoDayPage(_dayPageOf(_displayedMonth), animate: true);
    _gotoMonthPage(now.year - _kGridFirstYear);
    _gotoYearPage(
        (_windowStart(now.year) - _kGridFirstYear) ~/ _kYearsPerPage);
  }

  /// ◎「回到当前」显隐判据：日视图=选中与「此刻」完全一致（含时分）；
  /// 周期视图=各自的游标（周选中周 / 月选中年月 / 选中年 / 自定义浏览月）
  /// 是否在当前周期。不能用日视图的 _selected 判定周期视图——_tapRangeDay
  /// 等周期操作不改 _selected，显隐会随进入前的日视图选值漂移。
  bool _atNow() {
    final DateTime n = _localNow();
    if (_dayViewTab != null) {
      switch (_dayViewTab!) {
        case CalendarPeriodMode.week:
          return _sameDay(_mondayOf(n), _selWeek);
        case CalendarPeriodMode.month:
          return _selMonth.year == n.year && _selMonth.month == n.month;
        case CalendarPeriodMode.year:
          return _selYear == n.year;
        case CalendarPeriodMode.custom:
          if (_rangeNavMode != null) return false; // 年/月宫格导航中恒显示
          return _rangeViewMonth.year == n.year &&
              _rangeViewMonth.month == n.month;
      }
    }
    return _selected.year == n.year &&
        _selected.month == n.month &&
        _selected.day == n.day &&
        _selected.hour == n.hour &&
        _selected.minute == n.minute;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildNowButton() {
    // 固定 38px 圆形占位槽：偏离当前时显示 ◎，回正后透明占位，
    // 保证取消/确认两颗胶囊的位置与宽度不随显隐跳动。
    final bool visible = !_atNow();
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: visible ? _jumpToCurrent : null,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: visible ? AppPalette.paper2 : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: visible
            ? const Icon(Icons.gps_fixed,
                size: 17, color: AppPalette.textSecondary)
            : null,
      ),
    );
  }

  // ---- 区间（range / 自定义）操作 ----

  /// 两步式选区间（预览 data-r）：无起始→选起始（停留当前月）；选截止
  /// （早于起始则重选起始）；已完整→再点调整（<起始=重选起始，否则改截止）。
  /// 不再自动跳下月——选完起始后停留在当前月，截止日可在本月、也可经
  /// 页头宫格/‹›跳到任意月再点；想找很早的日期用页头年宫格直达。
  void _tapRangeDay(DateTime day) {
    setState(() {
      _nowPinned = false;
      if (_rangeStart == null) {
        // ① 选起始日：停留当前月，下一步选截止日。
        _rangeStart = day;
        _rangeEnd = null;
        _rangeRStep = 'e';
      } else if (_rangeRStep == 'e' && _rangeEnd == null) {
        // ② 选截止日
        if (!day.isBefore(_rangeStart!)) {
          _rangeEnd = day;
          _rangeRStep = 's';
        } else {
          // 早于起始 → 重选起始（停留当前月）
          _rangeStart = day;
          _rangeEnd = null;
          _rangeRStep = 'e';
        }
      } else {
        // 已完整 → 再点调整
        if (day.isBefore(_rangeStart!)) {
          _rangeStart = day;
          _rangeEnd = null;
          _rangeRStep = 'e';
        } else {
          _rangeEnd = day;
          _rangeRStep = 's';
        }
      }
    });
  }

  // ---- 确认 ----

  void _confirmDay() {
    if (widget.showTime) {
      Navigator.of(context).pop(CalendarDay(_selected));
    } else {
      Navigator.of(context).pop(
        CalendarDay(DateTime(_selected.year, _selected.month, _selected.day)),
      );
    }
  }

  void _confirmPeriod() {
    final CalendarPeriod p;
    switch (_periodMode) {
      case CalendarPeriodMode.week:
        p = CalendarPeriod(
          CalendarPeriodMode.week,
          _selWeek,
          _selWeek.add(const Duration(days: 7)),
        );
      case CalendarPeriodMode.month:
        p = CalendarPeriod(
          CalendarPeriodMode.month,
          DateTime(_selMonth.year, _selMonth.month),
          DateTime(_selMonth.year, _selMonth.month + 1),
        );
      case CalendarPeriodMode.year:
        p = CalendarPeriod(
          CalendarPeriodMode.year,
          DateTime(_selYear),
          DateTime(_selYear + 1),
        );
      case CalendarPeriodMode.custom:
        if (_rangeStart == null || _rangeEnd == null) {
          showAppToast(context, '请选择开始与结束日期');
          return;
        }
        if (_rangeStart!.isAfter(_rangeEnd!)) {
          showAppToast(context, '开始时间不能晚于结束时间');
          return;
        }
        p = CalendarPeriod(
          CalendarPeriodMode.custom,
          _rangeStart!,
          _rangeEnd!.add(const Duration(days: 1)),
        );
    }
    Navigator.of(context).pop(p);
  }

  // ---- 构建 ----

  @override
  Widget build(BuildContext context) {
    switch (widget.mode) {
      case CalendarSheetMode.day:
        return _buildDay();
      case CalendarSheetMode.month:
        return _buildMonthPicker();
      case CalendarSheetMode.year:
        return _buildYearPicker();
      case CalendarSheetMode.range:
        return _buildRangePicker();
    }
  }

  // ───────── 日模式 ─────────

  Widget _buildDay() {
    final double maxH = MediaQuery.of(context).size.height * 0.92;
    final DateTime now = _localNow();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Container(
          color: ForestBg.paper,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (widget.showHandle) _buildHandle(),
              if (widget.showHeader) _buildHeader(),
              // 纯周期模式（流水页）无英雄区：英雄卡展示的是「某日+时间」，与周期选择无关。
              if (widget.showDayView) _buildHeroSeal(context),
              Flexible(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    children: <Widget>[
                      if (widget.showQuickChips || !widget.showDayView)
                        _buildGranularityChips(),
                      if (_dayViewTab == null)
                        _fastspanDayBody()
                      else
                        _periodSection(now),
                      const SizedBox(height: 2),
                    ],
                  ),
                ),
              ),
              _buildDayFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() => Container(
        margin: const EdgeInsets.only(top: 10),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: ForestNeutral.hairline,
          borderRadius: BorderRadius.circular(ForestRadius.pill),
        ),
      );

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.spaceLg,
          AppDimens.spaceMd,
          AppDimens.spaceLg,
          4,
        ),
        child: Row(
          children: <Widget>[
            _CloseButton(onPressed: () => Navigator.of(context).pop()),
            const SizedBox(width: 10),
            Text(
              widget.headerTitle ?? 'DATE & TIME',
              style: TextStyle(
                fontSize: widget.headerTitle != null ? 17 : 19,
                fontWeight: FontWeight.w800,
                color: ForestGreen.deep,
                letterSpacing: widget.headerTitle != null ? 1 : 4,
              ),
            ),
            const Spacer(),
            // 齿轮设置（时间圆盘/粒度显隐）仅日模式有意义；纯周期模式
            // 关掉全部粒度 chip 会把用户困在单一视图，故不渲染。
            if (widget.showDayView) _GearButton(onPressed: _openSettings),
          ],
        ),
      );

  /// 设计稿 #cfg 齿轮键 → 设置底部弹窗（开关粒度 tab 显隐与时间圆盘）。
  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ForestBg.paper,
      barrierColor: AppPaletteX.forestScrim32, // rgba(20,30,24,.32)
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (BuildContext sheetCtx) => StatefulBuilder(
        builder: (BuildContext sheetCtx, void Function(void Function()) setSheet) {
          Widget row(CalendarPeriodMode? mode, String cn, String en) {
            final bool on =
                mode == null ? _showDial : (_tabEnabled[mode] ?? false);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 13),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: ForestNeutral.hairline),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Text(
                    '$cn $en',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: ForestNeutral.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  _SettingsSwitch(
                    on: on,
                    onTap: () {
                      _applySetting(mode, !on);
                      setSheet(() {});
                    },
                  ),
                ],
              ),
            );
          }

          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: ForestNeutral.hairline,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Container(
                    alignment: Alignment.centerLeft,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: const Text(
                      '设置 Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: ForestGreen.deep,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  row(CalendarPeriodMode.week, '周视图', 'Week'),
                  row(CalendarPeriodMode.month, '月视图', 'Month'),
                  row(CalendarPeriodMode.year, '年视图', 'Year'),
                  row(CalendarPeriodMode.custom, '自定义区间', 'Custom'),
                  row(null, '时间圆盘', 'Time Dial'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 设计稿 toggleSetting：切 tab 显隐；当前激活视图被关闭时
  /// 退回第一个开启的视图（无则回日视图）；showDial 直接翻转。
  void _applySetting(CalendarPeriodMode? mode, bool value) {
    setState(() {
      if (mode == null) {
        _showDial = value;
        _persistSettings();
        return;
      }
      _tabEnabled[mode] = value;
      if (!value && _dayViewTab == mode) {
        CalendarPeriodMode? first;
        for (final CalendarPeriodMode m in CalendarPeriodMode.values) {
          if (_tabEnabled[m] == true) {
            first = m;
            break;
          }
        }
        _dayViewTab = first;
        if (first != null) _periodMode = first;
      }
    });
    _persistSettings();
  }

  Widget _buildHeroSeal(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(18, 8, 18, 2),
        padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
        decoration: BoxDecoration(
          gradient: ForestGradients.sage,
          borderRadius: BorderRadius.circular(20),
          boxShadow: _heroFloat ? ForestElevation.float : ForestElevation.card,
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              right: -28,
              top: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.141),
                ),
              ),
            ),
            Positioned(
              right: 26,
              bottom: -46,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.102),
                ),
              ),
            ),
            // 设计稿：hero = Row[col(flex:1: lab+big+seg), 表盘] 垂直居中
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // 设计稿（fastspan 预览）：lab 仅 RECORD AT，11px/字距2
                      Text(
                        'RECORD AT',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 2,
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: 0.851),
                        ),
                      ),
                      const SizedBox(height: 2),
                      // 设计稿：big 21px「M月D日 X」+ 年份 12px；兜底 FittedBox 杜绝溢出
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: <Widget>[
                            Text(
                              '${_selected.month}月${_selected.day}日 '
                              '${_weekdayShort(_selected)}',
                              style: TextStyle(
                                fontSize: _narrow ? 19 : 21,
                                fontWeight: FontWeight.w800,
                                color:
                                    Theme.of(context).colorScheme.onPrimary,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${_selected.year}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context)
                                    .colorScheme
                                    .surface
                                    .withValues(alpha: 0.851),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.showTime) ...<Widget>[
                        const SizedBox(height: 10),
                        _buildHeroSeg(context),
                      ],
                    ],
                  ),
                ),
                if (widget.showTime && _showDial) ...<Widget>[
                  const SizedBox(width: 10),
                  _buildHeroDial(),
                ],
              ],
            ),
          ],
        ),
      );

  /// 设计稿断点：≤380px 时表盘缩小、字号降档（dtp-sheet-V3 @media）。
  bool get _narrow => MediaQuery.sizeOf(context).width <= 380;

  Widget _buildHeroSeg(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: <Widget>[
            Expanded(child: _heroSegBtn(context, '时 Hour', true)),
            Expanded(child: _heroSegBtn(context, '分 Min', false)),
          ],
        ),
      );

  Widget _heroSegBtn(BuildContext context, String label, bool isHour) {
    final bool on = _isHourMode == isHour;
    return InkWell(
      onTap: () => setState(() => _isHourMode = isHour),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:
              on ? Theme.of(context).colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: on
                ? ForestGreen.deep
                : Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: 0.851),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroDial() => _TimeDial(
        hourMode: _isHourMode,
        hour: _selected.hour,
        minute: _selected.minute,
        size: _narrow ? 100 : 112,
        onHourChanged: _setHour,
        onMinuteChanged: _setMinute,
        onToggleMode: () => setState(() => _isHourMode = !_isHourMode),
      );

  /// 粒度 chip 行（小青账式 ptabs）：周 Wk / 月 Mo / 年 Yr / 自定义 …
  /// 再点当前激活 chip 返回日视图（预览一致）。
  Widget _buildGranularityChips() {
    // 设置里关掉的粒度 tab 不渲染（预览 s.tabs 开关一致）。
    final List<(CalendarPeriodMode, String, String)> all =
        <(CalendarPeriodMode, String, String)>[
      (CalendarPeriodMode.week, '周', 'Wk'),
      (CalendarPeriodMode.month, '月', 'Mo'),
      (CalendarPeriodMode.year, '年', 'Yr'),
      (CalendarPeriodMode.custom, '自定义', '…'),
    ];
    final List<Widget> chips = <Widget>[];
    for (final (CalendarPeriodMode mode, String cn, String en) in all) {
      if (_tabEnabled[mode] != true) continue;
      if (chips.isNotEmpty) chips.add(const SizedBox(width: 8));
      chips.add(_granularityChip(mode, cn, en));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
      child: Row(children: chips),
    );
  }

  Widget _granularityChip(CalendarPeriodMode mode, String cn, String en) {
    final bool on = _dayViewTab == mode;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => setState(() {
          if (_dayViewTab == mode) {
            // 纯周期模式（流水页）无日视图可回，保持当前周期视图。
            if (widget.showDayView) _dayViewTab = null;
          } else {
            _dayViewTab = mode;
            _periodMode = mode;
            _rangeNavMode = null; // 进入任意周期视图时重置自定义宫格导航
            if (mode == CalendarPeriodMode.week) {
              // 进入周视图一律重锚到当前上下文所在周（与月/年 chip 锚定同
              // 口径）：_selWeek 只在 initState 锚定一次，之后会被滚轮滚动
              // （滚到底自动选中 12 月周）、跨年箭头、上次确认的周期污染，
              // 不重锚会落在旧位置。
              final DateTime ctx = widget.showDayView
                  ? _displayedMonth
                  : DateTime(_selMonth.year, _selMonth.month);
              _selWeek = _mondayOf(DateTime(ctx.year, ctx.month));
              _weekYear = _selWeek.year;
              _weekEpoch++;
              _weekCtrl = null; // 重建周列表，按 _selWeek 居中
            } else if (mode == CalendarPeriodMode.month) {
              // 锚定日视图当前上下文月（_displayedMonth），不是 _selMonth——
              // 后者只在点月格时更新，早与浏览年份脱钩（点 2026 落 2008 的根源）。
              _monthYear = _displayedMonth.year;
              _selMonth = DateTime(_monthYear, _displayedMonth.month);
              _gotoMonthPage(_monthYear - _kGridFirstYear);
            } else if (mode == CalendarPeriodMode.year) {
              // 与日页头「YYYY年M月 ▾」入口同口径：锚定日视图上下文年。
              _selYear = _displayedMonth.year;
              _decadeStart = _windowStart(_selYear);
              _gotoYearPage(
                  (_decadeStart - _kGridFirstYear) ~/ _kYearsPerPage);
            }
            if (mode == CalendarPeriodMode.custom) {
              // 预览：进自定义未起选则回到「选起始」步骤，浏览月锚定当前月
              if (_rangeStart == null) _rangeRStep = 's';
              _rangeViewMonth =
                  DateTime(_displayedMonth.year, _displayedMonth.month);
              _gotoRangePage(_dayPageOf(_rangeViewMonth));
            }
          }
        }),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: on ? ForestGradients.sage : null,
            color: on ? null : ForestSurface.card,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: on ? Colors.transparent : ForestNeutral.hairline,
            ),
            boxShadow: on ? ForestElevation.card : ForestElevation.flat,
          ),
          child: Text.rich(
            TextSpan(
              text: cn,
              children: <TextSpan>[
                TextSpan(
                  text: ' $en',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: on
                        ? Theme.of(context)
                            .colorScheme
                            .onPrimary
                            .withValues(alpha: 0.7)
                        : ForestNeutral.textSecondary,
                  ),
                ),
              ],
            ),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: on
                  ? Theme.of(context).colorScheme.onPrimary
                  : ForestNeutral.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  // ── 小青账式日视图：页头/星期表头固定在滑动区外，PageView 相邻月并排滑动 ──

  Widget _fastspanDayBody() {
    _reconcileDayPage();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 2),
      child: Column(
        children: <Widget>[
          _dayAxis(),
          _fixedWeekHeader(),
          SizedBox(
            height: _kSheetBodyHeight,
            child: PageView.builder(
              // 控制器换新 ⇒ 键变 ⇒ 子树重建，挂载即落在 initialPage（见 _gotoDayPage 注释）。
              key: ObjectKey(_dayPageCtrl),
              controller: _dayPageCtrl,
              itemCount: (_kGridLastYear - _kGridFirstYear + 1) * 12,
              onPageChanged: _onDayPageChanged,
              itemBuilder: (BuildContext ctx, int page) => _dayPageGrid(
                DateTime(_kGridFirstYear + page ~/ 12, page % 12 + 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 页头（固定在滑动区外）：「YYYY年M月 ▾」点按进年视图 + ‹ › 步进。
  Widget _dayAxis() {
    final bool canPrev = _isMonthAllowed(
      DateTime(_displayedMonth.year, _displayedMonth.month - 1),
    );
    final bool canNext = _isMonthAllowed(
      DateTime(_displayedMonth.year, _displayedMonth.month + 1),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
      child: Row(
        children: <Widget>[
          InkWell(
            onTap: () => setState(() {
              _dayViewTab = CalendarPeriodMode.year;
              _periodMode = CalendarPeriodMode.year;
              // 年宫格锁定到日视图上下文年所在 12 年窗（与粒度 chip 同口径）。
              _selYear = _displayedMonth.year;
              _decadeStart = _windowStart(_selYear);
              _gotoYearPage(
                  (_decadeStart - _kGridFirstYear) ~/ _kYearsPerPage);
            }),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Row(
                children: <Widget>[
                  Text(
                    '${_displayedMonth.year}年${_displayedMonth.month}月',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: ForestNeutral.deepInk,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    '▾',
                    style: TextStyle(
                      fontSize: 11,
                      color: ForestNeutral.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          _axisChevron('‹', canPrev, () => _shiftDayPage(-1)),
          const SizedBox(width: 18),
          _axisChevron('›', canNext, () => _shiftDayPage(1)),
        ],
      ),
    );
  }

  Widget _axisChevron(String glyph, bool enabled, VoidCallback onTap) =>
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            glyph,
            style: TextStyle(
              fontSize: 20,
              height: 1,
              color: enabled
                  ? ForestNeutral.deepInk
                  : ForestNeutral.textTertiary,
            ),
          ),
        ),
      );

  void _shiftDayPage(int n) {
    final DateTime c =
        DateTime(_displayedMonth.year, _displayedMonth.month + n);
    if (!_isMonthAllowed(c)) return;
    _gotoDayPage(_dayPageOf(c), animate: true);
  }

  /// 星期表头固定在滑动区外（11px 加粗浅字，设计稿 .fixedwk）。
  Widget _fixedWeekHeader() {
    final List<String> ordered = widget.weekStart == CalendarWeekStart.monday
        ? const <String>['一', '二', '三', '四', '五', '六', '日']
        : const <String>['日', '一', '二', '三', '四', '五', '六'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 2, 0, 6),
      child: Row(
        children: <Widget>[
          for (final String w in ordered)
            Expanded(
              child: Center(
                child: Text(
                  w,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ForestNeutral.textTertiary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 单月扁平网格：主体区固定 198px，按当月实际周行数均分行高
  /// （5 行月份行距自动加大、日期铺满到主体区底部，不再尾部空一行）；
  /// 选中=实心绿圆白字、今天=绿字（预览 .cell）。
  Widget _dayPageGrid(DateTime month) {
    final int leading = _leadingOf(month);
    final int dim = DateTime(month.year, month.month + 1, 0).day;
    final DateTime today = _localNow();
    final DateTime todayOnly = DateTime(today.year, today.month, today.day);
    final DateTime selOnly =
        DateTime(_selected.year, _selected.month, _selected.day);
    final int rows = ((leading + dim) / 7).ceil().clamp(1, 6);
    final List<Widget> cells = <Widget>[
      for (int i = 0; i < leading; i++) const SizedBox.shrink(),
      for (int d = 1; d <= dim; d++)
        _dayCellFastspan(month, d, todayOnly, selOnly),
      for (int i = leading + dim; i < rows * 7; i++) const SizedBox.shrink(),
    ];
    return LayoutBuilder(
      builder: (_, BoxConstraints c) {
        final double cellW = (c.maxWidth - 12) / 7; // 6 个列间距 × 2
        final double rowH = (_kSheetBodyHeight - (rows - 1) * 2) / rows;
        return GridView.count(
          crossAxisCount: 7,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: cellW / rowH,
          children: cells,
        );
      },
    );
  }

  Widget _dayCellFastspan(
      DateTime month, int day, DateTime todayOnly, DateTime selOnly) {
    final DateTime date = DateTime(month.year, month.month, day);
    final bool selected = date == selOnly;
    final bool isToday = date == todayOnly;
    final bool enabled = _isDayAllowed(date);
    final bool dim = !selected && !enabled;
    // 设计稿 .cell：.sel 写在 .today 之后 → 选中日=今天时白字盖过绿字
    final Color textColor = selected
        ? AppPalette.white
        : dim
            ? ForestNeutral.textTertiary
            : isToday
                ? AppPalette.ctaGreen
                : ForestNeutral.textPrimary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled
          ? () => setState(() {
                _nowPinned = false;
                _selected = DateTime(month.year, month.month, day,
                    _selected.hour, _selected.minute);
              })
          : null,
      child: Center(
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppPalette.ctaGreen : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 14,
              fontWeight:
                  selected || isToday ? FontWeight.w800 : FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  /// 粒度 chip 激活时的周期区：页头（固定在外）+ 周期 body（周滚轮/月宫格/年宫格/自定义）。
  Widget _periodSection(DateTime now) {
    final CalendarPeriodMode mode = _dayViewTab!;
    return Padding(
      // 与 _fastspanDayBody 同口径（体底 2），两视图尺寸完全一致。
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 2),
      child: Column(
        children: <Widget>[
          _periodAxis(now, mode),
          _periodBody(now),
        ],
      ),
    );
  }

  Widget _periodAxis(DateTime now, CalendarPeriodMode mode) {
    final bool canPrev;
    switch (mode) {
      case CalendarPeriodMode.week:
        canPrev = _weekYear > widget.firstDate.year;
      case CalendarPeriodMode.month:
        canPrev = _monthYear > widget.firstDate.year;
      case CalendarPeriodMode.year:
        canPrev = _decadeStart > _kGridFirstYear;
      case CalendarPeriodMode.custom:
        canPrev = _rangeNavMode == 'year'
            ? _decadeStart > _kGridFirstYear
            : _rangeNavMode == 'month'
                ? _monthYear > widget.firstDate.year
                : _isMonthAllowed(
                    DateTime(_rangeViewMonth.year, _rangeViewMonth.month - 1),
                  );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
      child: Row(
        children: <Widget>[
          // 与 _dayAxis 同口径：自定义分支的 _rangeAxisLabel 内部已含
          // InkWell+Padding(all:2)，外面不能再包一层 Padding（双层=+4px，
          // 弹窗会比日视图高一点）；其余分支是裸 Text，保留 Padding(all:2)。
          Expanded(
            child: mode == CalendarPeriodMode.custom
                ? _rangeAxisLabel()
                : Padding(
                    padding: const EdgeInsets.all(2),
                    child: Text(
                      _periodAxisLabel(),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: ForestNeutral.deepInk,
                      ),
                    ),
                  ),
          ),
          _axisChevron('‹', canPrev, _periodPrev),
          const SizedBox(width: 18),
          _axisChevron('›', _periodCanDown(now), _periodNext),
        ],
      ),
    );
  }

  /// 自定义区间页头（预览 .axis .pill）：起/止 pill + 浏览月「YYYY年M月」。
  /// 选起始阶段 pill 绿字浅红底，选截止阶段蓝字浅蓝底（设计稿 --red/--blue）。
  Widget _customAxisLabel() {
    final bool pickingEnd = _rangeRStep == 'e';
    return Row(
      children: <Widget>[
        Text(
          '${_rangeViewMonth.year}年${_rangeViewMonth.month}月',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: ForestNeutral.deepInk,
          ),
        ),
        const SizedBox(width: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: pickingEnd
                ? AppPaletteX.azureSurface // 设计稿 .pill.e 底
                : AppPaletteX.coralSurface, // 设计稿 .pill.s 底
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            pickingEnd ? '止' : '起',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: pickingEnd
                  ? AppPaletteX.azureAccent // --blue
                  : AppPaletteX.coralAccent, // --red
            ),
          ),
        ),
      ],
    );
  }

  /// 自定义区间页头标签（随宫格导航子模式切换，fontSize 适配两种入口字号）：
  /// - null（日宫格）：浏览月「YYYY年M月」+ 起/止 pill，点按→年宫格
  /// - 'month'（年宫格）：年份「YYYY年」，点按→年宫格
  /// - 'year'（年宫格）：年代区间，顶端不可再上钻
  Widget _rangeAxisLabel({double fontSize = 17}) {
    switch (_rangeNavMode) {
      case 'month':
        return InkWell(
          onTap: _openRangeYearGrid,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Row(
              children: <Widget>[
                Text(
                  '$_monthYear年',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800,
                    color: ForestNeutral.deepInk,
                  ),
                ),
                const SizedBox(width: 5),
                const Text('▾',
                    style:
                        TextStyle(fontSize: 11, color: ForestNeutral.textTertiary)),
              ],
            ),
          ),
        );
      case 'year':
        return Padding(
          // 与其余分支的 InkWell+Padding(all:2) 同高，页头行高不随导航态变。
          padding: const EdgeInsets.all(2),
          child: Text(
            '$_decadeStart年–${_decadeStart + _kYearsPerPage - 1}年',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: ForestNeutral.deepInk,
            ),
          ),
        );
      default:
        return InkWell(
          onTap: _openRangeYearGrid,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Row(
              children: <Widget>[
                _customAxisLabel(),
                const SizedBox(width: 5),
                const Text('▾',
                    style:
                        TextStyle(fontSize: 11, color: ForestNeutral.textTertiary)),
              ],
            ),
          ),
        );
    }
  }

  /// 自定义区间：点页头进入年宫格（与日视图页头 ▾ 同款直达，不必逐月横滑）。
  void _openRangeYearGrid() {
    setState(() {
      _rangeNavMode = 'year';
      _selYear = _rangeViewMonth.year;
      _decadeStart = _windowStart(_selYear);
      _gotoYearPage((_decadeStart - _kGridFirstYear) ~/ _kYearsPerPage);
    });
  }

  /// 小青账式 footer：◎ 靠左，取消 + 确认平均分剩余空间。
  Widget _buildDayFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
      child: Row(
        children: <Widget>[
          _buildNowButton(),
          const SizedBox(width: 12),
          Expanded(
            child: _footerPill(
              label: '取消',
              background: AppPalette.paper2,
              foreground: AppPalette.textSecondary,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _footerPill(
              label: '确认 Confirm',
              background: AppPalette.ctaGreen,
              foreground: AppPalette.white,
              onTap: _dayViewTab == null ? _confirmDay : _confirmPeriod,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerPill({
    required String label,
    required Color background,
    required Color foreground,
    required VoidCallback onTap,
  }) =>
      InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ),
      );

  Widget _buildFooter(
          {required VoidCallback onConfirm,
          required String label,
          Widget? leading}) =>
      Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
        decoration: BoxDecoration(
          color: ForestBg.paper,
          border: Border(top: BorderSide(color: ForestNeutral.hairline)),
        ),
        child: Column(
          children: <Widget>[
            if (leading != null)
              Row(
                children: <Widget>[
                  leading,
                  const SizedBox(width: 12),
                  Expanded(child: _ConfirmButton(onPressed: onConfirm, label: label)),
                ],
              )
            else
              _ConfirmButton(onPressed: onConfirm, label: label),
            const SizedBox(height: 14),
          ],
        ),
      );

  // ───────── 月 / 年 单选（点选即返回，无确认） ─────────

  Widget _buildMonthPicker() {
    int year = widget.initialMonth?.year ?? _selected.year;
    final int selM = widget.initialMonth?.month ?? _selected.month;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (widget.showHandle) _buildHandle(),
          _sageBar(
            title: '$year 年',
            canDown: year < _localNow().year,
            onPrev: () => setState(() => year--),
            onNext: () => setState(() => year++),
          ),
          Padding(
            padding: const EdgeInsets.all(AppDimens.spaceLg),
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.7,
              children: <Widget>[
                for (int m = 1; m <= 12; m++) _monthCell(year, m, selM),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthCell(int year, int m, int selM) {
    final bool disabled = !_isMonthAllowed(DateTime(year, m));
    final bool selected = year == widget.initialMonth?.year && m == selM;
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      onTap: disabled
          ? null
          : () => Navigator.of(context).pop(CalendarMonth(year, m)),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppPalette.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          border: Border.all(
            color: selected ? AppPalette.primary : AppPalette.sageLine,
          ),
        ),
        child: Text(
          '$m月',
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: disabled
                ? AppPalette.textTertiary
                : (selected ? AppPalette.white : AppPalette.textPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildYearPicker() {
    int year = widget.initialYear ?? _selected.year;
    final int selY = widget.initialYear ?? _selected.year;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (widget.showHandle) _buildHandle(),
          _sageBar(
            title: '$year 年',
            canUp: year > widget.firstDate.year,
            canDown: year < widget.lastDate.year,
            onPrev: () => setState(() => year--),
            onNext: () => setState(() => year++),
          ),
          Padding(
            padding: const EdgeInsets.all(AppDimens.spaceLg),
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.7,
              children: <Widget>[
                for (int y = year - 5; y <= year + 6; y++)
                  _yearPickCell(y, selY),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _yearPickCell(int y, int selY) {
    final bool outOfRange =
        y < widget.firstDate.year || y > widget.lastDate.year;
    final bool selected = y == selY;
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      onTap:
          outOfRange ? null : () => Navigator.of(context).pop(CalendarYear(y)),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppPalette.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          border: Border.all(
            color: selected ? AppPalette.primary : AppPalette.sageLine,
          ),
        ),
        child: Text(
          '$y',
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: outOfRange
                ? AppPalette.textTertiary
                : (selected ? AppPalette.white : AppPalette.textPrimary),
          ),
        ),
      ),
    );
  }

  // ───────── 区间（两步走） ─────────

  Widget _buildRangePicker() {
    final DateTime view = _rangeViewMonth;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (widget.showHandle) _buildHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _rangeStart == null
                        ? '选择开始日期'
                        : _rangeEnd == null
                            ? '选择结束日期'
                            : '${_md(_rangeStart!)} - ${_md(_rangeEnd!)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                ),
                _Arrow(
                  icon: Icons.chevron_left,
                  enabled: _isMonthAllowed(DateTime(view.year, view.month - 1)),
                  onPressed: () => setState(() =>
                      _rangeViewMonth = DateTime(view.year, view.month - 1)),
                ),
                _Arrow(
                  icon: Icons.chevron_right,
                  enabled: _isMonthAllowed(DateTime(view.year, view.month + 1)),
                  onPressed: () => setState(() =>
                      _rangeViewMonth = DateTime(view.year, view.month + 1)),
                ),
              ],
            ),
          ),
          _WeekdayRow(start: widget.weekStart),
          _buildRangeGrid(view),
          _buildFooter(
            onConfirm: () {
              if (_rangeStart == null || _rangeEnd == null) {
                showAppToast(context, '请选择开始与结束日期');
                return;
              }
              Navigator.of(context)
                  .pop(CalendarRange(_rangeStart!, _rangeEnd!));
            },
            label: '确定',
          ),
        ],
      ),
    );
  }

  Widget _buildRangeGrid(DateTime view) {
    final int leading = _leadingOf(view);
    final int dim = DateTime(view.year, view.month + 1, 0).day;
    final List<DateTime?> cells = <DateTime?>[
      for (int i = 0; i < leading; i++) null,
      for (int d = 1; d <= dim; d++) DateTime(view.year, view.month, d),
    ];
    while (cells.length < 42) cells.add(null);
    final DateTime today = _localNow();
    final DateTime todayOnly = DateTime(today.year, today.month, today.day);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 7,
        childAspectRatio: 1,
        children: cells.map((DateTime? d) {
          if (d == null) return const SizedBox.shrink();
          final bool inRange = _rangeStart != null &&
              _rangeEnd != null &&
              !d.isBefore(_rangeStart!) &&
              !d.isAfter(_rangeEnd!);
          final bool isStart = d == _rangeStart;
          final bool isEnd = d == _rangeEnd;
          final bool selected = inRange || isStart || isEnd;
          final bool isToday = d == todayOnly;
          final bool allowed = _isDayAllowed(d);
          return _DayCell(
            day: d.day,
            isSelected: selected,
            isToday: isToday,
            isMuted: !selected && !allowed,
            isEnabled: allowed,
            onTap: () => _tapRangeDay(d),
          );
        }).toList(growable: false),
      ),
    );
  }

  // ───────── 周期 Tab（周/月/年/自定义） ─────────

  String _periodAxisLabel() {
    switch (_periodMode) {
      case CalendarPeriodMode.week:
        return '$_weekYear年';
      case CalendarPeriodMode.month:
        return '$_monthYear年';
      case CalendarPeriodMode.year:
        // 标签用 _decadeStart（onPageChanged/‹›/年格点选三处均已同步）。
        // 勿读 _yearPageCtrl.page：滑动中取到分数页 round 后会与宫格错位。
        return '$_decadeStart年–${_decadeStart + _kYearsPerPage - 1}年';
      case CalendarPeriodMode.custom:
        return '';
    }
  }

  bool _periodCanDown(DateTime now) {
    switch (_periodMode) {
      case CalendarPeriodMode.week:
        return _weekYear < widget.lastDate.year;
      case CalendarPeriodMode.month:
        return _monthYear < widget.lastDate.year;
      case CalendarPeriodMode.year:
        return _decadeStart + _kYearsPerPage <= widget.lastDate.year;
      case CalendarPeriodMode.custom:
        if (_rangeNavMode == 'month') return _monthYear < widget.lastDate.year;
        if (_rangeNavMode == 'year') {
          return _decadeStart + _kYearsPerPage <= widget.lastDate.year;
        }
        return _isMonthAllowed(
          DateTime(_rangeViewMonth.year, _rangeViewMonth.month + 1),
        );
    }
  }

  void _periodPrev() {
    setState(() {
      switch (_periodMode) {
        case CalendarPeriodMode.week:
          _weekYear--;
          _selWeek = _nearestSelectableWeek(_weekYear, _selWeek, _localNow());
          _weekEpoch++;
          _weekCtrl = null;
        case CalendarPeriodMode.month:
          _monthYear--;
          _gotoMonthPage((_monthYear - _kGridFirstYear)
              .clamp(0, _kGridLastYear - _kGridFirstYear));
        case CalendarPeriodMode.year:
          _decadeStart = _windowStart(_decadeStart - _kYearsPerPage);
          _gotoYearPage(((_decadeStart - _kGridFirstYear) ~/ _kYearsPerPage)
              .clamp(0, _windowPageCount - 1));
        case CalendarPeriodMode.custom:
          if (_rangeNavMode == 'month') {
            _monthYear--;
            _gotoMonthPage((_monthYear - _kGridFirstYear)
                .clamp(0, _kGridLastYear - _kGridFirstYear));
          } else if (_rangeNavMode == 'year') {
            _decadeStart = _windowStart(_decadeStart - _kYearsPerPage);
            _gotoYearPage(((_decadeStart - _kGridFirstYear) ~/ _kYearsPerPage)
                .clamp(0, _windowPageCount - 1));
          } else {
            final DateTime c = DateTime(
                _rangeViewMonth.year, _rangeViewMonth.month - 1);
            if (_isMonthAllowed(c)) {
              _rangeViewMonth = c;
              _gotoRangePage(_dayPageOf(c), animate: true);
            }
          }
      }
    });
  }

  void _periodNext() {
    setState(() {
      switch (_periodMode) {
        case CalendarPeriodMode.week:
          _weekYear++;
          _selWeek = _nearestSelectableWeek(_weekYear, _selWeek, _localNow());
          _weekEpoch++;
          _weekCtrl = null;
        case CalendarPeriodMode.month:
          _monthYear++;
          _gotoMonthPage((_monthYear - _kGridFirstYear)
              .clamp(0, _kGridLastYear - _kGridFirstYear));
        case CalendarPeriodMode.year:
          _decadeStart = _windowStart(_decadeStart + _kYearsPerPage);
          _gotoYearPage(((_decadeStart - _kGridFirstYear) ~/ _kYearsPerPage)
              .clamp(0, _windowPageCount - 1));
        case CalendarPeriodMode.custom:
          if (_rangeNavMode == 'month') {
            _monthYear++;
            _gotoMonthPage((_monthYear - _kGridFirstYear)
                .clamp(0, _kGridLastYear - _kGridFirstYear));
          } else if (_rangeNavMode == 'year') {
            _decadeStart = _windowStart(_decadeStart + _kYearsPerPage);
            _gotoYearPage(((_decadeStart - _kGridFirstYear) ~/ _kYearsPerPage)
                .clamp(0, _windowPageCount - 1));
          } else {
            final DateTime c = DateTime(
                _rangeViewMonth.year, _rangeViewMonth.month + 1);
            if (_isMonthAllowed(c)) {
              _rangeViewMonth = c;
              _gotoRangePage(_dayPageOf(c), animate: true);
            }
          }
      }
    });
  }

  Widget _periodBody(DateTime now) {
    switch (_periodMode) {
      case CalendarPeriodMode.week:
        // 周/月/年不带星期表头，但总高需与日/自定义视图一致 → 等高隐形占位。
        return _withWeekHeaderGap(_periodWeekList(now));
      case CalendarPeriodMode.month:
        return _withWeekHeaderGap(_periodMonthGrid(now));
      case CalendarPeriodMode.year:
        return _withWeekHeaderGap(_periodYearGrid(now));
      case CalendarPeriodMode.custom:
        // 年/月宫格导航不带星期表头，但高度需与日宫格（自带星期表头）一致
        // → 等高隐形占位，弹窗在自定义各子模式间切换不跳动。
        if (_rangeNavMode == 'month') {
          return _withWeekHeaderGap(_rangeMonthGridNav());
        }
        if (_rangeNavMode == 'year') {
          return _withWeekHeaderGap(_rangeYearGridNav());
        }
        return _periodCustomRange(); // 自带星期表头
    }
  }

  /// 与 `_fixedWeekHeader` 等高的隐形占位：复用同一 widget 保证高度
  /// （含字体度量）严格一致，弹窗在各粒度视图间切换不再跳动。
  Widget _withWeekHeaderGap(Widget body) => Column(
        children: <Widget>[
          Visibility(
            visible: false,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: _fixedWeekHeader(),
          ),
          body,
        ],
      );

  Widget _periodWeekList(DateTime now) {
    final List<DateTime> weeks = _weeksOfYear(_weekYear);
    if (weeks.isEmpty) return const SizedBox(height: _kSheetBodyHeight);
    int selIdx = weeks.indexWhere((DateTime w) => w == _selWeek);
    if (selIdx < 0) {
      selIdx = weeks.indexWhere((DateTime w) => !w.isAfter(now));
      if (selIdx < 0) selIdx = 0;
    }
    final ScrollController ctrl =
        _weekCtrl ??= ScrollController(initialScrollOffset: selIdx * _kW);
    return SizedBox(
      height: _kSheetBodyHeight,
      child: Stack(
        children: <Widget>[
          Center(
            child: Container(
              height: _kW,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: AppPalette.neutralSoft,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification n) {
              if (n is ScrollUpdateNotification) {
                setState(() {}); // 实时刷新滚轮景深
              } else if (n is ScrollEndNotification) {
                final int idx =
                    (ctrl.offset / _kW).round().clamp(0, weeks.length - 1);
                // 吸附对齐：停在半行时把偏移拉回整行边界，避免边缘残留切片墨迹
                final double target =
                    (idx * _kW).clamp(0.0, ctrl.position.maxScrollExtent);
                if ((ctrl.offset - target).abs() > 0.5) {
                  ctrl.animateTo(
                    target,
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                  );
                }
                if (weeks[idx] != _selWeek) {
                  setState(() => _selWeek = weeks[idx]);
                }
              }
              return true;
            },
            child: ShaderMask(
              // 上下边缘 ~32px 渐隐：半行切片的墨迹淡出而非被视口硬切
              shaderCallback: (Rect bounds) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.transparent,
                  AppPalette.black,
                  AppPalette.black,
                  Colors.transparent,
                ],
                stops: <double>[0.0, 0.16, 0.84, 1.0],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: ListView.builder(
              // 纪元键：重锚时（chip 进入/跨年箭头/◎）epoch++ → 整树重建，
              // 新控制器 initialScrollOffset 才会生效（换控制器≠落位）。
              key: ValueKey<int>(_weekEpoch),
              controller: ctrl,
              itemExtent: _kW,
              padding: const EdgeInsets.symmetric(vertical: _kWeekCenterPad),
              itemCount: weeks.length,
              itemBuilder: (BuildContext ctx, int index) {
                final DateTime w = weeks[index];
                final DateTime wEnd = w.add(const Duration(days: 6));
                final bool selected = w == _selWeek;
                final bool disabled = w.isAfter(widget.lastDate);
                final bool isThis = w == _mondayOf(now);
                // 滚轮景深：按行距中框的距离做 3 档缩小 + 淡出（预览一致）
                final double center = ctrl.offset + _kSheetBodyHeight / 2;
                final double rowCenter = index * _kW + _kWeekCenterPad + _kW / 2;
                final double ad = (center - rowCenter).abs() / _kW;
                final int lv = ad.round().clamp(0, 2);
                final double scale = const <double>[1.0, 0.9, 0.76][lv];
                final double opacity = const <double>[1.0, 0.8, 0.58][lv];
                return Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: disabled ? 0.35 : opacity,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: disabled
                          ? null
                          : () {
                              ctrl.animateTo(
                                index * _kW,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutCubic,
                              );
                              setState(() => _selWeek = w);
                            },
                      child: Container(
                        alignment: Alignment.center,
                        // 全角「）」右半是字形空白，整行墨心比文本框中心左偏 ~4px，
                        // 视觉上「不居中」；左侧补等宽内距把墨心推回中线。
                        // 内距随景深 Transform.scale 等比缩放，与字号缩放天然自洽。
                        padding: const EdgeInsets.only(left: 8.5),
                        child: Text(
                          _weekLabel(w, wEnd, isThis, now),
                          style: TextStyle(
                            fontSize: selected ? 17 : 13.5,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: disabled
                                ? AppPalette.textTertiary
                                : selected
                                    ? AppPalette.textPrimary
                                    : AppPalette.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodMonthGrid(DateTime now) {
    _reconcileMonthPage();
    final int pageCount = _kGridLastYear - _kGridFirstYear + 1;
    return SizedBox(
      height: _kSheetBodyHeight,
      child: PageView.builder(
        // 控制器换新 ⇒ 键变 ⇒ 子树重建，挂载即落在 initialPage（见 _gotoMonthPage 注释）。
        key: ObjectKey(_monthPageCtrl),
        controller: _monthPageCtrl,
        itemCount: pageCount,
        onPageChanged: _onMonthPageChanged,
        itemBuilder: (BuildContext ctx, int page) {
          final int year = _kGridFirstYear + page;
          return Padding(
            padding: EdgeInsets.zero, // 4×45+3×6=198 恰好填满，多一层纵向内边距会被 PageView 裁掉末行
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisExtent: 45,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                for (int m = 1; m <= 12; m++)
                  Builder(
                    builder: (BuildContext c) {
                      final bool selected =
                          year == _selMonth.year && m == _selMonth.month;
                      final bool disabled =
                          !_isMonthAllowed(DateTime(year, m));
                      return InkWell(
                        borderRadius: BorderRadius.circular(13),
                        onTap: disabled
                            ? null
                            : () => _gridCellTap(
                                  1 * 1000000 + year * 100 + m,
                                  // 单击：仅选中该月（确认键按 _selMonth 出参）
                                  () => setState(() {
                                    _selMonth = DateTime(year, m);
                                  }),
                                  // 双击：选中并跳回该月日视图
                                  () => setState(() {
                                    _selMonth = DateTime(year, m);
                                    // 纯周期模式（流水/报表页）无日视图可回，
                                    // 置 null 会漏进日视图主体，跳过。
                                    if (_dayViewTab != null &&
                                        widget.showDayView) {
                                      // 设计稿 data-m：点月 → 自动跳回该月日视图
                                      final int last =
                                          DateTime(year, m + 1, 0).day;
                                      final int d = _selected.day > last
                                          ? last
                                          : _selected.day;
                                      _selected = DateTime(year, m, d,
                                          _selected.hour, _selected.minute);
                                      _displayedMonth = DateTime(year, m);
                                      _dayViewTab = null;
                                      _gotoDayPage(
                                          _dayPageOf(_displayedMonth),
                                          animate: true);
                                    }
                                  }),
                                ),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient:
                                selected ? ForestGradients.sage : null,
                            color: selected
                                ? null
                                : (disabled
                                    ? AppPalette.paper2
                                    : ForestSurface.card),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: disabled
                                  ? Colors.transparent
                                  : ForestNeutral.hairline,
                            ),
                          ),
                          child: Text(
                            '$m月',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: disabled
                                  ? AppPalette.textTertiary
                                  : (selected
                                      ? Theme.of(c).colorScheme.onPrimary
                                      : AppPalette.textPrimary),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _periodYearGrid(DateTime now) {
    _reconcileYearPage();
    return SizedBox(
      height: _kSheetBodyHeight,
      child: PageView.builder(
        // 控制器换新 ⇒ 键变 ⇒ 子树重建，挂载即落在 initialPage（见 _gotoYearPage 注释）。
        key: ObjectKey(_yearPageCtrl),
        controller: _yearPageCtrl,
        itemCount: _windowPageCount,
        onPageChanged: _onYearPageChanged,
        itemBuilder: (BuildContext ctx, int page) {
          final int start = _kGridFirstYear + page * _kYearsPerPage;
          return Padding(
            padding: EdgeInsets.zero, // 4×45+3×6=198 恰好填满，多一层纵向内边距会被 PageView 裁掉末行
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisExtent: 45,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                for (int y = start; y < start + _kYearsPerPage; y++)
                  Builder(
                    builder: (BuildContext c) {
                      final bool selected = y == _selYear;
                      final bool disabled =
                          y < widget.firstDate.year || y > widget.lastDate.year;
                      return InkWell(
                        borderRadius: BorderRadius.circular(13),
                        onTap: disabled
                            ? null
                            : () => _gridCellTap(
                                  2 * 1000000 + y,
                                  // 单击：仅选中年份（确认键按 _selYear 出参）
                                  () => setState(() {
                                    _selYear = y;
                                    _decadeStart = _windowStart(y);
                                  }),
                                  // 双击：选中并跳到该年月视图
                                  () => setState(() {
                                    _selYear = y;
                                    _decadeStart = _windowStart(y);
                                    if (_dayViewTab != null) {
                                      // 设计稿 data-y：点年 → 自动跳到该年月视图
                                      _dayViewTab = CalendarPeriodMode.month;
                                      _periodMode = CalendarPeriodMode.month;
                                      _monthYear = y;
                                      // 高亮月跟随日视图上下文月号（_selMonth 的
                                      // 旧月号属遗留选区，会落在错误月份上）。
                                      _selMonth =
                                          DateTime(y, _displayedMonth.month);
                                      _gotoMonthPage(y - _kGridFirstYear);
                                    }
                                  }),
                                ),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient:
                                selected ? ForestGradients.sage : null,
                            color: selected
                                ? null
                                : (disabled
                                    ? AppPalette.paper2
                                    : ForestSurface.card),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: disabled
                                  ? Colors.transparent
                                  : ForestNeutral.hairline,
                            ),
                          ),
                          child: Text(
                            '$y年',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: disabled
                                  ? AppPalette.textTertiary
                                  : (selected
                                      ? Theme.of(c).colorScheme.onPrimary
                                      : AppPalette.textPrimary),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 自定义区间（预览 rangeBody）：页头固定在外，body=星期表头 + 固定 198px
  /// 扁平宫格 PageView——与日视图完全同构（横滑翻月、换控制器 + ObjectKey
  /// 重建落位），仅 cell 样式按区间着色（.cell.sel/.st/.en）。
  Widget _periodCustomRange() {
    _reconcileRangePage();
    return Column(
      children: <Widget>[
        _fixedWeekHeader(),
        SizedBox(
          height: _kSheetBodyHeight,
          child: PageView.builder(
            key: ObjectKey(_rangePageCtrl),
            controller: _rangePageCtrl,
            itemCount: (_kGridLastYear - _kGridFirstYear + 1) * 12,
            onPageChanged: _onRangePageChanged,
            itemBuilder: (BuildContext ctx, int page) => _rangeMonthGrid(
              DateTime(_kGridFirstYear + page ~/ 12, page % 12 + 1),
            ),
          ),
        ),
      ],
    );
  }

  /// 自定义区间单月扁平网格：尺寸与 `_dayPageGrid` 一致
  /// （主体区固定 198px、按当月实际周行数均分行高），
  /// 起点红圆、终点蓝圆、区间中段绿圆。
  Widget _rangeMonthGrid(DateTime month) {
    final int leading = _leadingOf(month);
    final int dim = DateTime(month.year, month.month + 1, 0).day;
    final int rows = ((leading + dim) / 7).ceil().clamp(1, 6);
    final List<Widget> cells = <Widget>[
      for (int i = 0; i < leading; i++) const SizedBox.shrink(),
      for (int d = 1; d <= dim; d++) _rangeCell(month, d),
      for (int i = leading + dim; i < rows * 7; i++) const SizedBox.shrink(),
    ];
    return LayoutBuilder(
      builder: (_, BoxConstraints c) {
        final double cellW = (c.maxWidth - 12) / 7; // 6 个列间距 × 2
        final double rowH = (_kSheetBodyHeight - (rows - 1) * 2) / rows;
        return GridView.count(
          crossAxisCount: 7,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: cellW / rowH,
          children: cells,
        );
      },
    );
  }

  /// 区间 cell（预览 rangeMonth）：起点=.st 红圆、终点=.en 蓝圆、
  /// 区间中段=.sel 绿圆、两端外=普通字、禁选=置灰。
  Widget _rangeCell(DateTime month, int day) {
    final DateTime date = DateTime(month.year, month.month, day);
    final bool enabled = _isDayAllowed(date);
    final bool isStart = date == _rangeStart;
    final bool isEnd = date == _rangeEnd;
    final bool inRange = _rangeStart != null &&
        _rangeEnd != null &&
        !date.isBefore(_rangeStart!) &&
        !date.isAfter(_rangeEnd!);
    final bool selected = isStart || isEnd || inRange;
    final Color fill = isStart
        ? AppPaletteX.coralAccent // 设计稿 --red：起点
        : isEnd
            ? AppPaletteX.azureAccent // 设计稿 --blue：终点
            : selected
                ? AppPalette.ctaGreen
                : Colors.transparent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => _tapRangeDay(date) : null,
      child: Center(
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected
                  ? AppPalette.white
                  : enabled
                      ? ForestNeutral.textPrimary
                      : ForestNeutral.textTertiary,
            ),
          ),
        ),
      ),
    );
  }

  /// 自定义区间·年宫格导航：点年份→进该月的月宫格（与日视图年宫格同构，
  /// 仅 tap 落点改为自定义月导航而非跳出到日视图）。
  Widget _rangeYearGridNav() {
    _reconcileYearPage();
    return SizedBox(
      height: _kSheetBodyHeight,
      child: PageView.builder(
        key: ObjectKey(_yearPageCtrl),
        controller: _yearPageCtrl,
        itemCount: _windowPageCount,
        onPageChanged: _onYearPageChanged,
        itemBuilder: (BuildContext ctx, int page) {
          final int start = _kGridFirstYear + page * _kYearsPerPage;
          return Padding(
            padding: EdgeInsets.zero,
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisExtent: 45,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                for (int y = start; y < start + _kYearsPerPage; y++)
                  Builder(
                    builder: (BuildContext c) {
                      final bool selected = y == _selYear;
                      final bool disabled =
                          y < widget.firstDate.year || y > widget.lastDate.year;
                      return InkWell(
                        borderRadius: BorderRadius.circular(13),
                        onTap: disabled
                            ? null
                            : () => _gridCellTap(
                                  3 * 1000000 + y,
                                  // 单击：仅选中年份
                                  () => setState(() {
                                    _selYear = y;
                                    _decadeStart = _windowStart(y);
                                  }),
                                  // 双击：进该月的月宫格（自定义导航）
                                  () => setState(() {
                                    _selYear = y;
                                    _decadeStart = _windowStart(y);
                                    _rangeNavMode = 'month';
                                    _monthYear = y;
                                    _selMonth =
                                        DateTime(y, _rangeViewMonth.month);
                                    _gotoMonthPage(y - _kGridFirstYear);
                                  }),
                                ),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: selected ? ForestGradients.sage : null,
                            color: selected
                                ? null
                                : (disabled
                                    ? AppPalette.paper2
                                    : ForestSurface.card),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: disabled
                                  ? Colors.transparent
                                  : ForestNeutral.hairline,
                            ),
                          ),
                          child: Text(
                            '$y年',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: disabled
                                  ? AppPalette.textTertiary
                                  : (selected
                                      ? Theme.of(c).colorScheme.onPrimary
                                      : AppPalette.textPrimary),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 自定义区间·月宫格导航：点月份→自定义日宫格跳到该月（不退出自定义、
  /// 回到选起止日视图；回正起止高亮用的是当前浏览月）。
  Widget _rangeMonthGridNav() {
    _reconcileMonthPage();
    final int pageCount = _kGridLastYear - _kGridFirstYear + 1;
    return SizedBox(
      height: _kSheetBodyHeight,
      child: PageView.builder(
        key: ObjectKey(_monthPageCtrl),
        controller: _monthPageCtrl,
        itemCount: pageCount,
        onPageChanged: _onMonthPageChanged,
        itemBuilder: (BuildContext ctx, int page) {
          final int year = _kGridFirstYear + page;
          return Padding(
            padding: EdgeInsets.zero,
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisExtent: 45,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                for (int m = 1; m <= 12; m++)
                  Builder(
                    builder: (BuildContext c) {
                      final bool selected = year == _rangeViewMonth.year &&
                          m == _rangeViewMonth.month;
                      final bool disabled = !_isMonthAllowed(DateTime(year, m));
                      return InkWell(
                        borderRadius: BorderRadius.circular(13),
                        onTap: disabled
                            ? null
                            : () => _gridCellTap(
                                  4 * 1000000 + year * 100 + m,
                                  // 单击：仅选中年月（浏览月游标，轴标签/◎ 同步）
                                  () => setState(() {
                                    _rangeViewMonth = DateTime(year, m);
                                  }),
                                  // 双击：自定义日宫格跳到该月（不退出自定义）
                                  () => setState(() {
                                    _rangeViewMonth = DateTime(year, m);
                                    _gotoRangePage(
                                        _dayPageOf(_rangeViewMonth),
                                        animate: true);
                                    _rangeNavMode = null;
                                  }),
                                ),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: selected ? ForestGradients.sage : null,
                            color: selected
                                ? null
                                : (disabled
                                    ? AppPalette.paper2
                                    : ForestSurface.card),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: disabled
                                  ? Colors.transparent
                                  : ForestNeutral.hairline,
                            ),
                          ),
                          child: Text(
                            '$m月',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: disabled
                                  ? AppPalette.textTertiary
                                  : (selected
                                      ? Theme.of(c).colorScheme.onPrimary
                                      : AppPalette.textPrimary),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _md(DateTime d) => '${d.month}月${d.day}日';

  /// 周滚轮每行标签：起月日-止月日（跨月显示完整止月日）+ 本周/上周/下周/第N周。
  String _weekLabel(DateTime mon, DateTime sun, bool isThis, DateTime now) {
    final String monStr = '${mon.month}月${mon.day}日';
    final String sunStr =
        sun.month != mon.month ? '${sun.month}月${sun.day}日' : '${sun.day}日';
    final String tag;
    if (isThis) {
      tag = '本周';
    } else {
      // 行周一 − 本周周一：早 1 周 = -1 → 上周，晚 1 周 = +1 → 下周。
      // （旧写法反着减，上周/下周标签正好互换。）
      final int diff = (mon.difference(_mondayOf(now)).inDays / 7).round();
      tag = diff == -1
          ? '上周'
          : diff == 1
              ? '下周'
              : '第${_isoWeek(mon)}周';
    }
    return '$monStr-$sunStr（$tag）';
  }

  /// ISO 周序号（与预览一致）。
  int _isoWeek(DateTime d) {
    final DateTime dt = DateTime.utc(d.year, d.month, d.day);
    final int day = dt.weekday; // 周一=1 … 周日=7
    final DateTime shifted = dt.add(Duration(days: 4 - day));
    final DateTime yearStart = DateTime.utc(shifted.year, 1, 1);
    return ((shifted.difference(yearStart).inDays + 1) / 7).ceil();
  }

  Widget _sageBar({
    required String title,
    required bool canDown,
    required VoidCallback onPrev,
    required VoidCallback onNext,
    bool canUp = true,
  }) =>
      Container(
        decoration: const BoxDecoration(
          color: AppPalette.sage200,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceSm, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: canUp ? onPrev : null,
            ),
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: canDown ? onNext : null,
            ),
          ],
        ),
      );
}

/// 表盘拨号（签章卡内嵌，浅色化）。
class _TimeDial extends StatelessWidget {
  _TimeDial({
    required this.hourMode,
    required this.hour,
    required this.minute,
    required this.onHourChanged,
    required this.onMinuteChanged,
    required this.onToggleMode,
    this.size = 112,
  });

  final bool hourMode;
  final int hour;
  final int minute;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;
  final VoidCallback onToggleMode;

  /// 表盘边长（≤380px 屏幕传 100，时间字号随之降档）。
  final double size;

  final GlobalKey _key = GlobalKey();

  void _handle(Offset global, bool allowToggle) {
    final RenderBox? box =
        _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final Offset p = box.globalToLocal(global);
    final Offset c = box.size.center(Offset.zero);
    final double dx = p.dx - c.dx;
    final double dy = p.dy - c.dy;
    if (allowToggle && math.sqrt(dx * dx + dy * dy) < box.size.width * 0.18) {
      onToggleMode();
      return;
    }
    final double deg = math.atan2(dx, -dy) * 180 / math.pi;
    final double a = deg < 0 ? deg + 360 : deg;
    final int count = hourMode ? 24 : 60;
    final int val = (a / (360 / count)).round() % count;
    if (hourMode) {
      onHourChanged(val);
    } else {
      onMinuteChanged(val);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: GestureDetector(
        key: _key,
        behavior: HitTestBehavior.opaque,
        onPanStart: (DragStartDetails d) => _handle(d.globalPosition, false),
        onPanUpdate: (DragUpdateDetails d) => _handle(d.globalPosition, false),
        onTapDown: (TapDownDetails d) => _handle(d.globalPosition, true),
        child: Stack(
          children: <Widget>[
            CustomPaint(
              size: Size(size, size),
              painter: _DialPainter(
                hourMode: hourMode,
                hour: hour,
                minute: minute,
                surface: Theme.of(context).colorScheme.surface,
                onSurface: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    '${hour.toString().padLeft(2, '0')}:'
                    '${minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: size >= 106 ? 22 : 19,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures()
                      ],
                    ),
                  ),
                  Text(
                    hourMode ? '时 HOUR' : '分 MIN',
                    style: TextStyle(
                      fontSize: 8,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.851),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.hourMode,
    required this.hour,
    required this.minute,
    required this.surface,
    required this.onSurface,
  });

  final bool hourMode;
  final int hour;
  final int minute;
  final Color surface;
  final Color onSurface;

  static const Color _sage1 = AppPalette.sageMist;
  static const Color _sage2 = AppPalette.sageRibbon;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double r = size.width / 2 - 10;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = surface.withValues(alpha: 0.349)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    for (int i = 0; i < 60; i++) {
      final double a = i * 2 * math.pi / 60 - math.pi / 2;
      final bool major = i % 5 == 0;
      final double r2 = r - 3;
      final double r1 = major ? r - 14 : r - 9;
      canvas.drawLine(
        Offset(c.dx + r1 * math.cos(a), c.dy + r1 * math.sin(a)),
        Offset(c.dx + r2 * math.cos(a), c.dy + r2 * math.sin(a)),
        Paint()
          ..color = major
              ? surface.withValues(alpha: 0.902)
              : surface.withValues(alpha: 0.451)
          ..strokeWidth = major ? 2 : 1
          ..strokeCap = StrokeCap.round,
      );
    }
    final double frac = hourMode ? hour / 24 : minute / 60;
    final Rect arcRect = Rect.fromCircle(center: c, radius: r - 6);
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      frac * 2 * math.pi,
      false,
      Paint()
        ..color = onSurface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    final double ka = frac * 2 * math.pi - math.pi / 2;
    final double kr = r - 6;
    final Offset k = Offset(c.dx + kr * math.cos(ka), c.dy + kr * math.sin(ka));
    canvas.drawCircle(k, 9, Paint()..color = AppPalette.cream);
    canvas.drawCircle(
      k,
      9,
      Paint()
        ..color = ForestGreen.deep
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.hourMode != hourMode || old.hour != hour || old.minute != minute;
}

// ── 共享小组件 ──

/// 页头右侧齿轮设置键（设计稿 .xbtn.gear，与关闭键同款圆底）。
class _GearButton extends StatelessWidget {
  const _GearButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: ForestSurface.card,
          shape: BoxShape.circle,
          border: Border.all(color: ForestNeutral.hairline),
        ),
        child: IconButton(
          icon: const Icon(Icons.settings_outlined,
              size: 18, color: ForestNeutral.deepInk),
          padding: EdgeInsets.zero,
          onPressed: onPressed,
        ),
      );
}

/// 设置弹窗开关（设计稿 .switch 48×28，on=绿色）。
class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({required this.on, required this.onTap});
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 48,
          height: 28,
          padding: const EdgeInsets.all(3),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: on ? AppPalette.ctaGreen : ForestNeutral.hairline,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppPalette.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: ForestSurface.card,
          shape: BoxShape.circle,
          border: Border.all(color: ForestNeutral.hairline),
        ),
        child: IconButton(
          icon: const Icon(Icons.close, size: 18, color: ForestNeutral.deepInk),
          padding: EdgeInsets.zero,
          onPressed: onPressed,
        ),
      );
}

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({required this.onPressed, required this.label});
  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: ForestGradients.sage,
          borderRadius: BorderRadius.circular(16),
          boxShadow: ForestElevation.sm,
        ),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onPrimary,
              letterSpacing: 2,
            ),
          ),
        ),
      );
}

class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
        width: 30,
        height: 30,
        margin: const EdgeInsets.only(left: 6),
        decoration: BoxDecoration(
          color: ForestBg.sunken,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ForestNeutral.hairline),
        ),
        child: IconButton(
          icon: Icon(icon, size: 16, color: ForestNeutral.deepInk),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          onPressed: enabled ? onPressed : null,
        ),
      );
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({this.start = CalendarWeekStart.sunday});

  final CalendarWeekStart start;

  static const List<String> _labels = <String>[
    '日',
    '一',
    '二',
    '三',
    '四',
    '五',
    '六'
  ];
  static const Color _sageAccent = AppPalette.sageRibbon;

  List<String> get _ordered => start == CalendarWeekStart.monday
      ? const <String>['一', '二', '三', '四', '五', '六', '日']
      : _labels;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 4, 2, 0),
        child: Row(
          children: _ordered
              .map(
                (String label) => Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: (label == '日' || label == '六')
                            ? _sageAccent
                            : ForestNeutral.textTertiary,
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      );
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.isMuted,
    required this.isEnabled,
    required this.onTap,
  });

  final int day;
  final bool isSelected;
  final bool isToday;
  final bool isMuted;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 设计稿：选中=白字；置灰=浅字；今天=默认字+底部 4px 圆点（选中今天时圆点隐藏）
    final Color textColor = isSelected
        ? Theme.of(context).colorScheme.onPrimary
        : isMuted
            ? ForestNeutral.textTertiary
            : ForestNeutral.textPrimary;
    return Center(
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: isSelected ? ForestGradients.sage : null,
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Text(
                '$day',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: textColor,
                ),
              ),
              if (isToday && !isSelected)
                Positioned(
                  bottom: 3,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppPalette.sageRibbon,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
