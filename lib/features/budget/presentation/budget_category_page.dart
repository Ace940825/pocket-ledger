import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../database/app_database.dart';
import '../../../database/daos/transactions_dao.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/calendar_sheet.dart';
import '../../../shared/widgets/clay_icon_tile.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/hairline_card.dart';
import '../../../shared/widgets/line_icon_map.dart';
import '../../../shared/widgets/line_icons.dart';
import '../../../shared/widgets/module_list_scaffold.dart'
    show confirmDelete, showToast;
import '../../../shared/widgets/round_close_button.dart';
import '../../../shared/widgets/segmented_row.dart';
import '../../../shared/widgets/sheet_scaffold.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimens.dart';
import '../../../theme/app_theme.dart';
import '../../categories/providers/categories_providers.dart';
import '../../ledger/presentation/widgets/txn_slidable.dart';
import '../providers/budget_providers.dart';
import 'budget_editor.dart';
import 'budget_setup_page.dart';

/// 全部账本（账本名按 bookId 查找用）。
final AutoDisposeStreamProvider<List<Book>> _booksProvider =
    StreamProvider.autoDispose<List<Book>>(
  (Ref ref) => ref.watch(booksDaoProvider).watchAll(),
);

/// 区间收支合计（实付口径，与首页月合计一致）。
/// 键 = (bookId, startAtMs, endAtMs, TxnType)。
final AutoDisposeStreamProviderFamily<int, (String, int, int, TxnType)>
    _rangeTotalProvider =
    StreamProvider.autoDispose.family<int, (String, int, int, TxnType)>(
  (Ref ref, (String, int, int, TxnType) p) {
    final (String bookId, int startAt, int endAt, TxnType type) = p;
    return ref.watch(transactionsDaoProvider).watchTotalInRange(
          bookId: bookId,
          startAt: startAt,
          endAt: endAt,
          type: type,
        );
  },
);

/// 区间按分类聚合（实付口径 + 笔数）。键同上。
final AutoDisposeStreamProviderFamily<Map<String, CategoryTotal>,
        (String, int, int, TxnType)> _catTotalsProvider =
    StreamProvider.autoDispose
        .family<Map<String, CategoryTotal>, (String, int, int, TxnType)>(
  (Ref ref, (String, int, int, TxnType) p) {
    final (String bookId, int startAt, int endAt, TxnType type) = p;
    return ref
        .watch(transactionsDaoProvider)
        .watchCategoryTotals(
          bookId: bookId,
          startAt: startAt,
          endAt: endAt,
          type: type,
        )
        .map((List<CategoryTotal> list) => <String, CategoryTotal>{
              for (final CategoryTotal t in list) t.categoryId: t,
            },);
  },
);

/// 预算分类页（2026-10-15 依小青账截图对标，第 25 批反馈修正；
/// 第 28 批「收入预算→收入目标」语义重构）：
///
/// - 顶部：✕ 关闭 + 居中「N月预算 / YYYY年预算」（收入方向显
///   「N月收入目标」）+ ¥ 设置月预算 + 📅 选周期；
///   方向由入口参数固定（设置月预算入口从「⋯」弹层移出为顶栏直达）。
/// - 账本卡：账本名 + 周期日期范围 + 「⋯」菜单
///   （结转下期预算 / 删除当前预算），「剩余X预算（元）」大数字
///   （收入方向=「距X收入目标（元）」，已达成显「已达成」；未设置显 ----）
///   + 铅笔编辑 + 进度环 + 四格统计 + 日均三行；
///   收入方向口径：环与四格第三格显「目标完成%」而非「预算剩余%」，
///   预算列显「X目标」、日均显「日均目标」。
/// - 分类预算卡：「添加」pill + 一级分类聚合行（默认折叠，点击展开/
///   收起；展开显示二级预算行 + 「添加二级预算」入口）+ 各分类预算行
///   （黏土方糖图标 + 剩余% + 进度条 + 本期消费/收入 + 笔数）；
///   收入方向：卡标题「分类目标」、行内「已完成%」/「已达成」/「目标:」；
///   第 29 批总闸制：一级行金额 = 总闸优先否则 Σ二级（不叠加），
///   一级行已用 = 自身 + Σ名下全部二级流水（穿透，含无预算的二级）；
/// - 底部悬浮「月预算 / 年预算」胶囊。
///
/// 口径：总预算（scope=overall）按支出口径保存（表无方向字段），
/// 收入方向的「目标」= 收入分类预算合计；铅笔编辑仅支出方向可用。
/// 一级/二级预算关系（第 29 批）：流水记在二级，一级是汇总容器——
/// 已用必须穿透；金额总闸与二级不叠加，概览总额按分组成效额去重。
class BudgetCategoryPage extends ConsumerStatefulWidget {
  const BudgetCategoryPage({
    super.key,
    required this.initialYear,
    required this.initialMonth,
    this.initialYearly = false,
    this.initialDirection = CategoryType.expense,
    this.bookId,
  });

  final int initialYear;
  final int initialMonth;
  final bool initialYearly;
  final CategoryType initialDirection;

  /// 目标账本（null = 当前账本；预算主页跨账本网格点入时传入）。
  final String? bookId;

  @override
  ConsumerState<BudgetCategoryPage> createState() => _BudgetCategoryPageState();
}

class _BudgetCategoryPageState extends ConsumerState<BudgetCategoryPage> {
  late int _year = widget.initialYear;
  late int _month = widget.initialMonth;
  late bool _yearly = widget.initialYearly;
  late final CategoryType _direction = widget.initialDirection;

  /// 已展开「二级预算折叠栏」的一级分类 id 集合（默认空 = 进入页面全折叠）。
  final Set<String> _expandedCats = <String>{};

  bool get _isExpense => _direction == CategoryType.expense;

  /// 当前周期的查询区间（闭开）。
  (DateTime, DateTime) get _range => _yearly
      ? (DateTime(_year), DateTime(_year + 1))
      : (DateTime(_year, _month), DateTime(_year, _month + 1));

  /// 当前周期内的预算行。
  List<Budget> _periodBudgets(List<Budget> all) => all
      .where(
        (Budget b) => _yearly
            ? (b.period == BudgetPeriod.yearly && b.year == _year)
            : (b.period == BudgetPeriod.monthly &&
                b.year == _year &&
                b.periodIndex == _month),
      )
      .toList(growable: false);

  /// 周期选择：月模式选月（CalendarSheet month）、年模式选年（year）。
  Future<void> _pickPeriod() async {
    if (_yearly) {
      final CalendarSelection? sel = await CalendarSheet.show(
        context,
        mode: CalendarSheetMode.year,
        initialYear: _year,
      );
      if (sel is! CalendarYear || !mounted) return;
      setState(() => _year = sel.year);
    } else {
      final CalendarSelection? sel = await CalendarSheet.show(
        context,
        mode: CalendarSheetMode.month,
        initialMonth: DateTime(_year, _month),
      );
      if (sel is! CalendarMonth || !mounted) return;
      setState(() {
        _year = sel.year;
        _month = sel.month;
      });
    }
  }

  /// 周期内总预算（第 29 批总闸制·去重）：
  /// 支出 = 总预算行（scope=overall）+ Σ各一级分组成效额；
  /// 收入 = Σ各一级分组成效额。分组成效额 = 一级自身预算（总闸）
  /// 优先，否则 Σ二级预算——一级与二级不叠加，杜绝双计
  /// （旧口径裸加全部预算行，一级二级同设时同一笔额度算两遍）。
  int _totalBudgetMinor(
    List<Budget> periodBudgets,
    List<_BudgetGroupData> groups,
  ) {
    final int byGroup = groups.fold<int>(
      0,
      (int s, _BudgetGroupData g) => s + g.effectiveMinor,
    );
    if (_isExpense) {
      final int overall = periodBudgets
              .where((Budget b) => b.scope == BudgetScope.overall)
              .firstOrNull
              ?.amountMinor ??
          0;
      return overall + byGroup;
    }
    return byGroup;
  }

  /// 周期内已流逝的天数/月数（未来周期=0，过去周期=全量）。
  int get _elapsedUnits {
    final DateTime now = DateTime.now();
    if (_yearly) {
      if (_year < now.year) return 12;
      if (_year > now.year) return 0;
      return now.month;
    }
    if (_year < now.year) return _daysInMonth;
    if (_year > now.year) return 0;
    if (_month < now.month) return _daysInMonth;
    if (_month > now.month) return 0;
    return now.day;
  }

  /// 周期内剩余的天数/月数。
  int get _remainUnits {
    final DateTime now = DateTime.now();
    if (_yearly) {
      if (_year < now.year) return 0;
      if (_year > now.year) return 12;
      return 12 - now.month;
    }
    if (_year < now.year || (_year == now.year && _month < now.month)) {
      return 0;
    }
    if (_year > now.year || (_year == now.year && _month > now.month)) {
      return _daysInMonth;
    }
    return _daysInMonth - now.day;
  }

  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;

  String _fmtAvg(int minor, int units) => units <= 0
      ? Money.zero.format()
      : Money.fromMinor(minor ~/ units).format();

  /// 顶栏 ¥：打开「设置月预算」页（第 25 批反馈：设置预算入口从
  /// 「⋯」弹层移出，顶栏直达；结转/删除仍留在「⋯」弹层）。
  void _openSetup(String bookId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BudgetSetupPage(
          initialTargetMonth: DateTime(_year, _month),
          bookId: bookId,
        ),
      ),
    );
  }

  /// 结转：把当前周期预算（总 + 分类）复制到下一周期，已存在的跳过。
  Future<void> _carryToNextPeriod(
    String bookId,
    List<Budget> periodBudgets,
  ) async {
    if (periodBudgets.isEmpty) {
      showToast(context, _isExpense ? '当前周期暂无预算可结转' : '当前周期暂无目标可结转');
      return;
    }
    final int targetYear;
    final int targetIndex;
    final BudgetPeriod targetPeriod;
    if (_yearly) {
      targetYear = _year + 1;
      targetIndex = 1;
      targetPeriod = BudgetPeriod.yearly;
    } else if (_month == 12) {
      targetYear = _year + 1;
      targetIndex = 1;
      targetPeriod = BudgetPeriod.monthly;
    } else {
      targetYear = _year;
      targetIndex = _month + 1;
      targetPeriod = BudgetPeriod.monthly;
    }
    final String targetLabel =
        _yearly ? '$targetYear年' : '$targetYear年$targetIndex月';

    final bool confirmed = (await showConfirm(
          context,
          title: '结转至$targetLabel？',
          content: '将把当前${_yearly ? '年' : '月'}的 ${periodBudgets.length} 项'
              '${_isExpense ? '预算' : '目标'}'
              '（${_isExpense ? '总预算 + 分类预算' : '总目标 + 分类目标'}）'
              '复制到$targetLabel，已存在的项目跳过。',
          confirmText: '结转',
        )) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }

    final List<Budget> all =
        ref.read(bookBudgetsProvider(bookId)).valueOrNull ?? const <Budget>[];
    final repo = ref.read(budgetRepositoryProvider);
    int added = 0;
    int skipped = 0;
    for (final Budget b in periodBudgets) {
      final bool exists = all.any(
        (Budget x) =>
            x.scope == b.scope &&
            x.categoryId == b.categoryId &&
            x.period == targetPeriod &&
            x.year == targetYear &&
            x.periodIndex == targetIndex,
      );
      if (exists) {
        skipped++;
        continue;
      }
      await repo.add(
        bookId: bookId,
        scope: b.scope,
        period: targetPeriod,
        amountMinor: b.amountMinor,
        year: targetYear,
        periodIndex: targetIndex,
        categoryId: b.categoryId,
        alertEnabled: b.alertEnabled,
        alertThreshold: b.alertThreshold,
      );
      added++;
    }
    if (mounted) {
      showToast(
        context,
        '已结转 $added 项到$targetLabel'
        '${skipped > 0 ? '（跳过 $skipped 项已存在）' : ''}',
      );
    }
  }

  /// 账本行「⋯」菜单（第 25 批：「设置月预算」移出到顶栏 ¥ 直达）：
  /// 结转下期预算 / 删除当前预算。
  /// 删除 = 当期该账本全部预算（总 + 分类）软删。
  Future<void> _showBookMoreSheet(
    String bookId,
    List<Budget> periodBudgets,
  ) async {
    final String? action = await showAppModalSheet<String>(
      context,
      title: '更多',
      bodyPadding: const EdgeInsets.symmetric(vertical: 6),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _MenuRow(
            label: _isExpense ? '结转下期预算' : '结转下期目标',
            icon: Icons.swap_horiz,
            onTap: () => Navigator.of(context).pop('carry'),
          ),
          _MenuRow(
            label: _isExpense ? '删除当前预算' : '删除当前目标',
            icon: Icons.delete_outline,
            danger: true,
            onTap: () => Navigator.of(context).pop('delete'),
          ),
        ],
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == 'carry') {
      await _carryToNextPeriod(bookId, periodBudgets);
      return;
    }
    if (action == 'delete') {
      if (periodBudgets.isEmpty) {
        showToast(context, _isExpense ? '当前周期暂无预算' : '当前周期暂无目标');
        return;
      }
      final bool ok = await confirmDelete(
        context,
        title: '删除当前${_yearly ? '年' : '月'}${_isExpense ? '预算' : '目标'}？',
        content: '将删除本${_yearly ? '年' : '月'}的全部${_isExpense ? '' : '收入'}'
            '${_isExpense ? '预算' : '目标'}'
            '（共 ${periodBudgets.length} 项，'
            '含${_isExpense ? '总预算与分类预算' : '总目标与分类目标'}），'
            '删除后不可撤销。',
      );
      if (!ok) {
        return;
      }
      final repo = ref.read(budgetRepositoryProvider);
      for (final Budget b in periodBudgets) {
        await repo.remove(b.id);
      }
      if (mounted) {
        showToast(
          context,
          '已删除 ${periodBudgets.length} 项${_isExpense ? '预算' : '目标'}',
        );
      }
    }
  }

  /// 分类预算分组（第 20 批）：按一级分类聚合——二级预算行挂到父级下。
  /// 第 29 批总闸制：一级行显示金额 = 自身预算（总闸）优先，否则
  /// Σ二级（见 [_BudgetGroupData.effectiveMinor]）；已用穿透汇总见
  /// [_CategoryBudgetsCard._groupSpent]。
  /// 孤儿二级（父分类缺失/方向不符）兜底按一级展示。
  List<_BudgetGroupData> _buildBudgetGroups(
    List<Budget> periodBudgets,
    Map<String, Category> catById,
  ) {
    final Map<String, Category> topById = <String, Category>{};
    final Map<String, (Budget, Category)> ownMap =
        <String, (Budget, Category)>{};
    final Map<String, List<(Budget, Category)>> childMap =
        <String, List<(Budget, Category)>>{};
    final List<String> topOrder = <String>[];

    void ensureTop(Category top) {
      if (!topById.containsKey(top.id)) {
        topById[top.id] = top;
        topOrder.add(top.id);
      }
    }

    for (final Budget b in periodBudgets) {
      if (b.scope != BudgetScope.category) {
        continue;
      }
      final Category? c = catById[b.categoryId];
      if (c == null || c.type != _direction) {
        continue;
      }
      final Category? parent = c.parentId == null ? null : catById[c.parentId];
      if (parent != null && parent.type == _direction && !parent.isSystem) {
        ensureTop(parent);
        (childMap[parent.id] ??= <(Budget, Category)>[]).add((b, c));
      } else {
        ensureTop(c);
        ownMap[c.id] = (b, c);
      }
    }

    int orderOf(String id) => topById[id]?.sortOrder ?? 0;
    final List<String> sortedIds = List<String>.of(topOrder)
      ..sort((String a, String b) {
        final int byOrder = orderOf(a).compareTo(orderOf(b));
        return byOrder != 0 ? byOrder : a.compareTo(b);
      });

    final List<_BudgetGroupData> groups = <_BudgetGroupData>[];
    for (final String id in sortedIds) {
      final List<(Budget, Category)>? kids = childMap[id];
      if (kids != null) {
        kids.sort((var a, var b) {
          final int byOrder = (a.$2.sortOrder - b.$2.sortOrder).sign.toInt();
          return byOrder != 0 ? byOrder : a.$2.name.compareTo(b.$2.name);
        });
      }
      // 名下二级分类定义（不含系统保留项）：有点击展开的意义；
      // 叶子一级分类（无二级分类）点击仍走编辑/新增自身预算。
      final bool hasChildCats = catById.values.any(
        (Category c) => c.parentId == id && c.type == _direction && !c.isSystem,
      );
      groups.add(
        _BudgetGroupData(
          category: topById[id]!,
          own: ownMap[id],
          children: kids == null
              ? const <(Budget, Category)>[]
              : List<(Budget, Category)>.unmodifiable(kids),
          hasChildCats: hasChildCats,
        ),
      );
    }
    return groups;
  }

  /// 左滑「删除」（一二级通用）：删除单条预算行。
  Future<void> _deleteBudgetRow(Budget b, Category c) async {
    final bool income = c.type == CategoryType.income;
    final bool ok = await confirmDelete(
      context,
      title: income ? '删除分类目标？' : '删除分类预算？',
      content: '将删除「${c.name}」的本${_yearly ? '年' : '月'}'
          '${income ? '目标' : '预算'}'
          '（${Money.fromMinor(b.amountMinor).format()}），删除后不可撤销。',
    );
    if (!ok) {
      return;
    }
    await ref.read(budgetRepositoryProvider).remove(b.id);
    if (mounted) {
      showToast(context, '已删除「${c.name}」的${income ? '目标' : '预算'}');
    }
  }

  /// 一级行「删除」：有直接预算删直接预算；否则清空名下全部二级预算。
  Future<void> _deleteBudgetGroup(_BudgetGroupData g) async {
    final bool income = g.category.type == CategoryType.income;
    if (g.own != null) {
      await _deleteBudgetRow(g.own!.$1, g.own!.$2);
      return;
    }
    if (g.children.isEmpty) {
      showToast(context, '「${g.category.name}」暂无${income ? '目标' : '预算'}可删除');
      return;
    }
    final bool ok = await confirmDelete(
      context,
      title: income ? '删除二级目标？' : '删除二级预算？',
      content: '「${g.category.name}」没有直接${income ? '目标' : '预算'}，'
          '将删除名下 ${g.children.length} 项二级${income ? '目标' : '预算'}，'
          '删除后不可撤销。',
    );
    if (!ok) {
      return;
    }
    final repo = ref.read(budgetRepositoryProvider);
    for (final (Budget b, Category _) in g.children) {
      await repo.remove(b.id);
    }
    if (mounted) {
      showToast(context, '已删除 ${g.children.length} 项二级${income ? '目标' : '预算'}');
    }
  }

  /// 一级行「编辑」（无直接预算时）：以该一级分类为种子新增预算。
  void _addBudgetForCategory(Category c) {
    showBudgetEditor(
      context,
      ref,
      null,
      BudgetSeed(
        scope: BudgetScope.category,
        categoryId: c.id,
        categoryType: c.type,
        period: _yearly ? BudgetPeriod.yearly : BudgetPeriod.monthly,
        year: _year,
        periodIndex: _yearly ? 1 : _month,
      ),
      widget.bookId,
    );
  }

  /// 一级分组内「添加二级预算」（第 21 批反馈：二级预算在一级分类内添加）：
  /// 编辑弹窗候选分类锁定为该一级名下的二级分类。
  void _addSubBudget(Category parent) {
    final List<Category> categories =
        ref.read(allCategoriesProvider).valueOrNull ?? const <Category>[];
    final bool hasChildren = categories.any(
      (Category c) =>
          c.parentId == parent.id && c.type == parent.type && !c.isSystem,
    );
    if (!hasChildren) {
      showToast(context, '「${parent.name}」暂无二级分类，请先在分类管理中添加');
      return;
    }
    showBudgetEditor(
      context,
      ref,
      null,
      BudgetSeed(
        scope: BudgetScope.category,
        categoryType: parent.type,
        period: _yearly ? BudgetPeriod.yearly : BudgetPeriod.monthly,
        year: _year,
        periodIndex: _yearly ? 1 : _month,
      ),
      widget.bookId,
      parent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String dirLabel = _isExpense ? '支出' : '收入';

    final String bookId = widget.bookId ?? ref.watch(currentBookIdProvider);
    // 账本名：按 bookId 从账本列表查；查不到退回当前账本名/默认。
    final List<Book> books =
        ref.watch(_booksProvider).valueOrNull ?? const <Book>[];
    final String bookName =
        books.where((Book b) => b.id == bookId).firstOrNull?.name ??
            ref.watch(currentBookProvider).valueOrNull?.name ??
            '默认账本';
    final List<Budget> all =
        ref.watch(bookBudgetsProvider(bookId)).valueOrNull ?? const <Budget>[];
    final List<Budget> periodBudgets = _periodBudgets(all);
    final List<Category> categories =
        ref.watch(allCategoriesProvider).valueOrNull ?? const <Category>[];
    final Map<String, Category> catById = <String, Category>{
      for (final Category c in categories) c.id: c,
    };

    final (DateTime start, DateTime end) = _range;
    final int startAt = start.toUtc().millisecondsSinceEpoch;
    final int endAt = end.toUtc().millisecondsSinceEpoch;
    final TxnType txnType = _isExpense ? TxnType.expense : TxnType.income;
    final (String, int, int, TxnType) totalKey =
        (bookId, startAt, endAt, txnType);

    // 一级 → 名下二级分类定义（第 29 批：一级行已用穿透汇总用，
    // 含没有预算行的二级——流水记在二级，一级必须穿透才对得上账）。
    final Map<String, List<Category>> childCatsById =
        <String, List<Category>>{};
    for (final Category c in categories) {
      if (c.parentId == null || c.type != _direction || c.isSystem) continue;
      (childCatsById[c.parentId!] ??= <Category>[]).add(c);
    }

    // 分类预算分组（第 20 批）：一级分类聚合自身 + 名下二级预算行。
    final List<_BudgetGroupData> budgetGroups =
        _buildBudgetGroups(periodBudgets, catById);

    // 总预算（第 29 批总闸制·去重：依赖分组成效额，须先算分组）。
    final int totalBudget = _totalBudgetMinor(periodBudgets, budgetGroups);
    final int spent = ref.watch(_rangeTotalProvider(totalKey)).valueOrNull ?? 0;
    final Map<String, CategoryTotal> catTotals =
        ref.watch(_catTotalsProvider(totalKey)).valueOrNull ??
            const <String, CategoryTotal>{};

    final int remaining = totalBudget - spent;
    final int remainUnits = _remainUnits;
    final int elapsedUnits = _elapsedUnits;

    // 周期文案
    final String rangeLabel =
        _yearly ? '1月1日–12月31日' : '$_month月1日–$_month月$_daysInMonth日';
    // 大数字标签：支出=「剩余预算」（越花越少的上限口径）；
    // 收入=「距收入目标」（越挣越少的目标缺口口径，第 28 批收入预算→收入目标）。
    final String remainLabel = _yearly
        ? (_isExpense ? '剩余年预算（元）' : '距年收入目标（元）')
        : (_isExpense ? '剩余月预算（元）' : '距月收入目标（元）');
    final String spentLabel =
        _isExpense ? (_yearly ? '本年消费' : '本月消费') : (_yearly ? '本年收入' : '本月收入');
    final String budgetColLabel =
        _yearly ? (_isExpense ? '年预算' : '年目标') : (_isExpense ? '月预算' : '月目标');
    final String remainUnitLabel =
        _yearly ? '$remainUnits个月' : '剩$remainUnits天';

    // 日均三行
    final String avgSpentLabel;
    final String avgBudgetLabel;
    final String avgRemainLabel;
    if (_yearly) {
      avgSpentLabel = _isExpense ? '本年月均消费' : '本年月均收入';
      avgBudgetLabel = _isExpense ? '月均预算' : '月均目标';
      // 第 29 批：「剩余每月可收入金额」→「剩余每月需收入」；第 31 批
      // →「剩余月均需收入」，与同行「月均预算/月均目标」措辞对齐——
      // 口径 = (目标−已得)/剩余月数，即每月需再收入多少才达成。
      avgRemainLabel = _isExpense ? '剩余每月可消费金额' : '剩余月均需收入';
    } else {
      avgSpentLabel = _isExpense ? '本月日均消费' : '本月日均收入';
      avgBudgetLabel = _isExpense ? '日均预算' : '日均目标';
      avgRemainLabel = _isExpense ? '剩余日均' : '剩余日均需收入';
    }
    final int avgUnits = _yearly ? 12 : _daysInMonth;

    // 环填充 = 已发生/总额（支出=已用越多越满；收入=已得越多越满，
    // 第 28 批：收入侧即「目标完成度」）。
    final double ringValue =
        totalBudget > 0 ? (spent / totalBudget).clamp(0.0, 1.0) : 0.0;
    // 环中心百分比（第 24 批反馈：圆环没有显示百分比）——
    // 支出口径 = 剩余/总预算；收入口径 = 已得/总目标（完成度）；无预算时 100%。
    final String ringLabel = totalBudget > 0
        ? '${((_isExpense ? remaining : spent) / totalBudget * 100).clamp(0.0, 999.0).toStringAsFixed(0)}%'
        : '100%';

    return Scaffold(
      body: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: <Widget>[
                      const RoundCloseButton(),
                      Expanded(
                        child: Center(
                          child: Text(
                            // 收入方向顶栏走「收入目标」措辞（第 28 批）。
                            _yearly
                                ? (_isExpense ? '$_year年预算' : '$_year年收入目标')
                                : (_isExpense ? '$_month月预算' : '$_month月收入目标'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.forest.onSurface,
                            ),
                          ),
                        ),
                      ),
                      // 顶栏 ¥ = 设置月预算（第 25 批反馈：设置预算入口
                      // 从「⋯」弹层移出为顶栏直达）。
                      _ClayIconButton(
                        tooltip: '设置预算',
                        icon: Icons.currency_yuan_outlined,
                        onPressed: () => _openSetup(bookId),
                      ),
                      const SizedBox(width: 8),
                      _ClayIconButton(
                        tooltip: '选择周期',
                        icon: Icons.calendar_month_outlined,
                        onPressed: _pickPeriod,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 110),
                  children: <Widget>[
                    _OverviewCard(
                      bookName: bookName,
                      rangeLabel: rangeLabel,
                      remainLabel: remainLabel,
                      totalBudget: totalBudget,
                      spent: spent,
                      remaining: remaining,
                      ringValue: ringValue,
                      ringLabel: ringLabel,
                      spentLabel: spentLabel,
                      budgetColLabel: budgetColLabel,
                      remainUnitLabel: remainUnitLabel,
                      avgSpentLabel: avgSpentLabel,
                      avgBudgetLabel: avgBudgetLabel,
                      avgRemainLabel: avgRemainLabel,
                      avgSpent: _fmtAvg(spent, elapsedUnits),
                      avgBudget: _fmtAvg(totalBudget, avgUnits),
                      avgRemain: _fmtAvg(
                        remaining > 0 ? remaining : 0,
                        remainUnits > 0 ? remainUnits : 1,
                      ),
                      yearly: _yearly,
                      isIncome: !_isExpense,
                      onMore: () => _showBookMoreSheet(bookId, periodBudgets),
                      onEditTotal: () {
                        if (!_isExpense) {
                          showToast(context, '收入总目标暂未支持单独保存，可先添加收入分类目标');
                          return;
                        }
                        showBudgetEditor(
                          context,
                          ref,
                          periodBudgets
                              .where(
                                (Budget b) => b.scope == BudgetScope.overall,
                              )
                              .firstOrNull,
                          BudgetSeed(
                            scope: BudgetScope.overall,
                            categoryType: CategoryType.expense,
                            period: _yearly
                                ? BudgetPeriod.yearly
                                : BudgetPeriod.monthly,
                            year: _year,
                            periodIndex: _yearly ? 1 : _month,
                          ),
                          bookId,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _CategoryBudgetsCard(
                      dirLabel: dirLabel,
                      isIncome: !_isExpense,
                      groups: budgetGroups,
                      childCatsById: childCatsById,
                      catTotals: catTotals,
                      spentLabel: spentLabel,
                      yearly: _yearly,
                      expandedIds: _expandedCats,
                      onToggle: (String categoryId) => setState(() {
                        if (!_expandedCats.add(categoryId)) {
                          _expandedCats.remove(categoryId);
                        }
                      }),
                      onAdd: () => showBudgetEditor(
                        context,
                        ref,
                        null,
                        BudgetSeed(
                          scope: BudgetScope.category,
                          categoryType: _direction,
                          period: _yearly
                              ? BudgetPeriod.yearly
                              : BudgetPeriod.monthly,
                          year: _year,
                          periodIndex: _yearly ? 1 : _month,
                        ),
                        bookId,
                      ),
                      onEditBudget: (Budget b, Category c) => showBudgetEditor(
                        context,
                        ref,
                        b,
                        BudgetSeed(
                          scope: BudgetScope.category,
                          categoryId: c.id,
                          categoryType: c.type,
                          period: _yearly
                              ? BudgetPeriod.yearly
                              : BudgetPeriod.monthly,
                          year: _year,
                          periodIndex: _yearly ? 1 : _month,
                        ),
                        bookId,
                      ),
                      onAddForCategory: _addBudgetForCategory,
                      onAddSubBudget: _addSubBudget,
                      onDeleteBudget: _deleteBudgetRow,
                      onDeleteGroup: _deleteBudgetGroup,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 底部悬浮「月预算 / 年预算」胶囊（与预算主页同款）。
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: SizedBox(
                width: 232,
                child: SegmentedRow<bool>(
                  options: const <SegmentOption<bool>>[
                    SegmentOption<bool>(value: false, label: '月预算'),
                    SegmentOption<bool>(value: true, label: '年预算'),
                  ],
                  value: _yearly,
                  variant: SegmentVariant.sageGradient,
                  radius: 999,
                  itemRadius: 999,
                  trackHasShadow: true,
                  onChanged: (bool v) => setState(() => _yearly = v),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 黏土方糖操作按钮（✕ 右侧 ¥ / 📅，与预算主页 AppBar 按钮同款）。
class _ClayIconButton extends StatelessWidget {
  const _ClayIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: ClayIconTile(
          size: 40,
          color: AppPalette.primary,
          child: LineGlyph(icon, size: 20, color: AppPalette.primary),
        ),
      ),
    );
  }
}

/// 概览卡：账本行 + 剩余预算/距收入目标大数字（铅笔编辑）+ 进度环 +
/// 四格统计 + 日均三行。收入方向（isIncome）大数字已达成显「已达成」。
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.bookName,
    required this.rangeLabel,
    required this.remainLabel,
    required this.totalBudget,
    required this.spent,
    required this.remaining,
    required this.ringValue,
    required this.ringLabel,
    required this.spentLabel,
    required this.budgetColLabel,
    required this.remainUnitLabel,
    required this.avgSpentLabel,
    required this.avgBudgetLabel,
    required this.avgRemainLabel,
    required this.avgSpent,
    required this.avgBudget,
    required this.avgRemain,
    required this.yearly,
    required this.isIncome,
    required this.onMore,
    required this.onEditTotal,
  });

  final String bookName;
  final String rangeLabel;
  final String remainLabel;
  final int totalBudget;
  final int spent;
  final int remaining;
  final double ringValue;
  final String ringLabel;
  final String spentLabel;
  final String budgetColLabel;
  final String remainUnitLabel;
  final String avgSpentLabel;
  final String avgBudgetLabel;
  final String avgRemainLabel;
  final String avgSpent;
  final String avgBudget;
  final String avgRemain;

  /// 月视图（false）/ 年视图（true）——剩余天数/月份列的文案开关。
  final bool yearly;

  /// 收入方向（第 28 批「收入预算→收入目标」）：大数字与第三格统计
  /// 走目标口径（还差/已完成），支出口径走剩余口径。
  final bool isIncome;

  /// 账本行「⋯」菜单（结转/删除当期预算）。
  final VoidCallback onMore;
  final VoidCallback onEditTotal;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return HairlineCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 账本行（对标参考图）：黏土方糖 + 账本名 + 周期范围 + 「⋯」菜单。
          Row(
            children: <Widget>[
              const ClayIconTile(
                color: AppPalette.primary,
                child: LineGlyph(
                  Icons.account_balance_wallet_outlined,
                  size: 20,
                  color: AppPalette.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      bookName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.forest.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rangeLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.forest.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // 账本行右侧：「⋯」菜单（2026-10-14 第 13 批：chevron 改
              // 三点键，弹设置弹层；第 27 批反馈：⟳ 切换账本移除）。
              InkWell(
                borderRadius: BorderRadius.circular(AppDimens.radiusChip),
                onTap: onMore,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: LineGlyph(
                    Icons.more_horiz,
                    size: 22,
                    color: context.forest.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 剩余预算/距目标大数字（铅笔编辑）+ 进度环。
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      remainLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.forest.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              // 支出=剩余预算（负值=超支）；收入=距目标差额，已达成显「已达成」。
                              totalBudget <= 0
                                  ? '----'
                                  : (isIncome && remaining <= 0
                                      ? '已达成'
                                      : Money.fromMinor(remaining).format()),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: context.forest.onSurface,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          borderRadius: BorderRadius.circular(AppDimens.sm),
                          onTap: onEditTotal,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: LineGlyph(
                              Icons.edit_outlined,
                              size: 18,
                              color: context.forest.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 56,
                height: 56,
                // 环中心显示剩余%（支出）/完成%（收入）（第 24 批反馈）。
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    CircularProgressIndicator(
                      value: ringValue,
                      strokeWidth: 7,
                      strokeCap: StrokeCap.round,
                      color: AppPalette.sageMeadow,
                      backgroundColor: context.forest.surfaceContainerHighest,
                    ),
                    Text(
                      ringLabel,
                      maxLines: 1,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: context.forest.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 四格统计：本期消费/收入 / 预算(目标) / 预算剩余(目标完成) /
          // 剩余天数或月份。
          Row(
            children: <Widget>[
              _statCol(context, spentLabel, Money.fromMinor(spent).format()),
              _statCol(
                context,
                budgetColLabel,
                Money.fromMinor(totalBudget).format(),
              ),
              _statCol(
                context,
                isIncome ? '目标完成' : '预算剩余',
                totalBudget > 0
                    ? '${((isIncome ? spent : remaining) / totalBudget * 100).clamp(0.0, 999.0).toStringAsFixed(1)}%'
                    : (isIncome ? '0.0%' : '100.0%'),
              ),
              _statCol(context, yearly ? '剩余月份' : '剩余天数', remainUnitLabel),
            ],
          ),
          const SizedBox(height: 10),
          _dashedDivider(scheme),
          const SizedBox(height: 10),
          // 日均三行（彩色圆点，对标参考稿）。
          _avgRow(context, AppPalette.amber, avgSpentLabel, avgSpent),
          _avgRow(context, AppPalette.clayBrown, avgBudgetLabel, avgBudget),
          _avgRow(context, AppPalette.transfer, avgRemainLabel, avgRemain),
        ],
      ),
    );
  }

  Widget _statCol(BuildContext context, String label, String value) {
    final ThemeData theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.forest.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.forest.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avgRow(
    BuildContext context,
    Color dot,
    String label,
    String value,
  ) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.forest.onSurface,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.forest.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// 虚线分隔（对标参考稿）。
  Widget _dashedDivider(ColorScheme scheme) => LayoutBuilder(
        builder: (BuildContext ctx, BoxConstraints c) {
          const double w = 6;
          const double gap = 5;
          final int n = (c.maxWidth / (w + gap)).floor();
          return Row(
            children: <Widget>[
              for (int i = 0; i < n; i++)
                Container(
                  width: w,
                  height: 1,
                  margin: EdgeInsets.only(right: i == n - 1 ? 0 : gap),
                  color: ctx.forest.outline,
                ),
            ],
          );
        },
      );
}

/// 一级分类预算聚合（第 20 批）：自身预算行 + 名下二级预算行。
/// 一级行显示口径 = 自身 + Σ二级（「一级等于二级之和」）。
class _BudgetGroupData {
  const _BudgetGroupData({
    required this.category,
    this.own,
    this.children = const <(Budget, Category)>[],
    this.hasChildCats = false,
  });

  final Category category;

  /// 该一级分类自身的预算行（总闸；可能不存在——预算都设在二级上）。
  final (Budget, Category)? own;
  final List<(Budget, Category)> children;

  /// 名下是否有二级分类**定义**（第 25 批：决定点击一级行是展开
  /// 折叠栏还是直接编辑自身预算；与有没有二级预算无关）。
  final bool hasChildCats;

  bool get hasChildren => children.isNotEmpty;

  /// 一级行生效预算额（第 29 批总闸制）：设了自身预算（总闸）时取
  /// 自身；否则 = Σ二级预算。二者**不叠加**——旧口径 own+Σ二级，
  /// 一级二级同设时同一笔额度双计。
  ///
  /// 第 31 批补 0 回退：自身金额为 0 的行是「自动汇总」占位（添加一级
  /// 分类时允许不填金额），同样回退为 Σ二级——只有正数自身预算才算
  /// 总闸。这样「填了金额=总闸、不填=自动汇总」两种意图可并存。
  int get effectiveMinor {
    if (own != null && own!.$1.amountMinor > 0) return own!.$1.amountMinor;
    return children.fold<int>(
      0,
      (int s, (Budget, Category) r) => s + r.$1.amountMinor,
    );
  }
}

/// 分类预算卡：标题 + 「添加」pill + 一级分类聚合行（可展开二级折叠栏，
/// 进入页面默认折叠；第 25 批反馈：点一级行按「名下有无二级分类定义」
/// 判定——有则展开/收起（展开后可添加二级预算），叶子一级分类仍直接
/// 编辑/新增自身预算）。
/// 所有行（一二级）支持左滑：编辑 / 删除。
///
/// 第 29 批总闸制口径：
/// - 一级行金额 = 总闸（一级自身预算）优先，否则 Σ二级预算，不叠加；
/// - 一级行已用 = 自身流水 + Σ名下**全部**二级分类流水（穿透汇总，
///   含没有预算行的二级——流水记在二级，一级必须穿透才对得上账）；
/// - 二级行 = 自己的预算 + 自己的流水（明细）。
class _CategoryBudgetsCard extends StatelessWidget {
  const _CategoryBudgetsCard({
    required this.dirLabel,
    required this.isIncome,
    required this.groups,
    required this.childCatsById,
    required this.catTotals,
    required this.spentLabel,
    required this.yearly,
    required this.expandedIds,
    required this.onToggle,
    required this.onAdd,
    required this.onEditBudget,
    required this.onAddForCategory,
    required this.onAddSubBudget,
    required this.onDeleteBudget,
    required this.onDeleteGroup,
  });

  final String dirLabel;

  /// 收入方向（第 28 批「收入预算→收入目标」）：卡标题/空态/二级入口
  /// 走「目标」措辞。
  final bool isIncome;
  final List<_BudgetGroupData> groups;

  /// 一级分类 id → 名下二级分类定义（第 29 批：一级行已用穿透汇总用，
  /// 含没有预算行的二级）。
  final Map<String, List<Category>> childCatsById;
  final Map<String, CategoryTotal> catTotals;
  final String spentLabel;
  final bool yearly;
  final Set<String> expandedIds;
  final void Function(String categoryId) onToggle;
  final VoidCallback onAdd;
  final void Function(Budget budget, Category category) onEditBudget;
  final void Function(Category category) onAddForCategory;
  final void Function(Category parentCategory) onAddSubBudget;
  final void Function(Budget budget, Category category) onDeleteBudget;
  final void Function(_BudgetGroupData group) onDeleteGroup;

  /// 一级行聚合消费（第 29 批总闸制·穿透）：自身精确匹配 +
  /// Σ名下**全部**二级分类流水（含没有预算行的二级；watchCategoryTotals
  /// 按分类扁平统计，父级不会自动含子分类流水，需显式穿透求和）。
  int _groupSpent(_BudgetGroupData g) {
    int spent = g.own == null ? 0 : (catTotals[g.own!.$2.id]?.totalMinor ?? 0);
    for (final Category c
        in childCatsById[g.category.id] ?? const <Category>[]) {
      spent += catTotals[c.id]?.totalMinor ?? 0;
    }
    return spent;
  }

  int _groupCount(_BudgetGroupData g) {
    int count = g.own == null ? 0 : (catTotals[g.own!.$2.id]?.count ?? 0);
    for (final Category c
        in childCatsById[g.category.id] ?? const <Category>[]) {
      count += catTotals[c.id]?.count ?? 0;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return HairlineCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  gradient: context.app.sageGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isIncome ? '分类目标' : '分类预算',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.forest.onSurface,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(AppDimens.radiusChip),
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.amber.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(AppDimens.radiusChip),
                  ),
                  child: Text(
                    '添加',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.forest.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (groups.isEmpty)
            EmptyState(
              message: isIncome ? '暂无收入分类目标' : '暂无$dirLabel分类预算',
              icon: Icons.account_balance_wallet_outlined,
              padding: const EdgeInsets.symmetric(vertical: 20),
            )
          else
            // 滑动互斥组：同时只允许一行滑开。
            TxnSlidableGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final _BudgetGroupData g in groups) ...<Widget>[
                    _CategoryRow(
                      slidableKey: 'budget-group-${g.category.id}',
                      category: g.category,
                      // 第 29 批总闸制：一级行金额 = 总闸优先，否则 Σ二级。
                      amountMinor: g.effectiveMinor,
                      spent: _groupSpent(g),
                      count: _groupCount(g),
                      spentLabel: spentLabel,
                      yearly: yearly,
                      onTap: () {
                        // 点一级行（第 25 批反馈「一级分类可以折叠，
                        // 点击后添加二级分类」）：名下有二级分类定义时
                        // 展开/收起（展开区含二级预算行 + 添加二级预算
                        // 入口）；无二级分类的叶子一级分类直接编辑或新增。
                        if (g.hasChildCats) {
                          onToggle(g.category.id);
                        } else if (g.own != null) {
                          onEditBudget(g.own!.$1, g.own!.$2);
                        } else {
                          onAddForCategory(g.category);
                        }
                      },
                      onEdit: () => g.own != null
                          ? onEditBudget(g.own!.$1, g.own!.$2)
                          : onAddForCategory(g.category),
                      onDelete: () => onDeleteGroup(g),
                    ),
                    // 二级预算行 + 「添加二级预算」入口：仅在展开时显示（第 22 批）。
                    if (expandedIds.contains(g.category.id)) ...<Widget>[
                      for (final (Budget b, Category c) in g.children)
                        _CategoryRow(
                          slidableKey: 'budget-${b.id}',
                          category: c,
                          amountMinor: b.amountMinor,
                          spent: catTotals[c.id]?.totalMinor ?? 0,
                          count: catTotals[c.id]?.count ?? 0,
                          spentLabel: spentLabel,
                          yearly: yearly,
                          indent: true,
                          onTap: () => onEditBudget(b, c),
                          onEdit: () => onEditBudget(b, c),
                          onDelete: () => onDeleteBudget(b, c),
                        ),
                      InkWell(
                        borderRadius: BorderRadius.circular(AppDimens.sm),
                        onTap: () => onAddSubBudget(g.category),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 30, top: 4),
                          child: Row(
                            children: <Widget>[
                              LineGlyph(
                                Icons.add_circle_outline,
                                size: 16,
                                color: context.forest.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isIncome ? '添加二级目标' : '添加二级预算',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: context.forest.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 单个分类预算行（一二级通用）：
/// 黏土方糖图标 + 名称/总额 + 剩余%（收入=已完成%）+ 进度条 +
/// 本期消费/收入 + 笔数；
/// 无展开箭头（第 23 批：折叠交互保留、箭头图标删除）；
/// 左滑出 编辑/删除 两键。
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.slidableKey,
    required this.category,
    required this.amountMinor,
    required this.spent,
    required this.count,
    required this.spentLabel,
    required this.yearly,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.indent = false,
  });

  /// Slidable 的 ValueKey（一级行=分组键，二级行=预算行 id）。
  final String slidableKey;
  final Category category;

  /// 显示总额（一级行 = 自身 + Σ二级聚合值）。
  final int amountMinor;
  final int spent;
  final int count;
  final String spentLabel;
  final bool yearly;

  /// 二级行缩进。
  final bool indent;

  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color tint = category.colorValue != null
        ? Color(category.colorValue!)
        : AppPalette.primary;
    final double progress =
        amountMinor > 0 ? (spent / amountMinor).clamp(0.0, 1.0) : 0.0;
    final double remainPct = amountMinor > 0
        ? ((amountMinor - spent) / amountMinor * 100).clamp(0.0, 100.0)
        : 0.0;
    // 收入目标口径（第 28 批）：行内显示「已完成%」而非「剩余%」。
    final double donePct =
        amountMinor > 0 ? (spent / amountMinor * 100).clamp(0.0, 100.0) : 0.0;
    final String remainLabel = _isIncome
        ? '已完成${donePct.toStringAsFixed(2)}%'
        : '剩余${remainPct.toStringAsFixed(2)}%';

    return Slidable(
      key: ValueKey<String>(slidableKey),
      groupTag: TxnSlidable.groupTag,
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.32,
        children: <Widget>[
          TxnSlideAction(
            icon: Icons.edit_outlined,
            semanticLabel: '编辑',
            color: AppPalette.info,
            onPressed: onEdit,
          ),
          TxnSlideAction(
            icon: Icons.delete_outline,
            semanticLabel: '删除',
            color: AppPalette.danger,
            onPressed: onDelete,
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.only(
            left: indent ? 30 : 0,
            right: 0,
            top: indent ? 8 : 10,
            bottom: indent ? 8 : 10,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              ClayIconTile(
                size: indent ? 32 : 38,
                color: tint,
                // 与记一笔同款钢笔线稿（2026-10-14 反馈：分类预算行图标
                // 此前是 Material 图标，与记一笔主网格不一致）。
                child: LineIcon(
                  categoryLineKind(category.iconKey) ?? LineIconKind.star,
                  size: indent ? 18 : 20,
                  color: Color.lerp(tint, context.forest.onSurface, 0.22),
                ),
              ),
              const SizedBox(width: 10),
              // 名称 + 总额。
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.forest.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      // 支出=「总额:」；收入目标口径=「目标:」（第 28 批）。
                      '${_isIncome ? '目标' : '总额'}: ${Money.fromMinor(amountMinor).format()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.forest.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 剩余% + 金额 + 进度条。
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      remainLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.forest.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isIncome
                          ? (spent >= amountMinor
                              ? '已达成'
                              : Money.fromMinor(amountMinor - spent).format())
                          : Money.fromMinor(amountMinor - spent).format(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.forest.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        color: AppPalette.sageMeadow,
                        backgroundColor: context.forest.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 本期消费/收入 + 笔数。
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      spentLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.forest.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Money.fromMinor(spent).format(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.forest.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count笔',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.forest.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isIncome => category.type == CategoryType.income;
}

/// 「设置」弹层菜单行（对标小青账设置弹层）：黏土方糖图标 + 标签 + chevron。
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color tint = danger ? context.forest.error : AppPalette.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.sm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Row(
          children: <Widget>[
            ClayIconTile(
              size: 40,
              color: tint,
              child: LineGlyph(icon, size: 20, color: tint),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.forest.onSurface,
                ),
              ),
            ),
            LineGlyph(
              Icons.chevron_right,
              size: 18,
              color: context.forest.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
