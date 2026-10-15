import 'package:flutter/material.dart';
import '../../../shared/widgets/line_icon_map.dart';
import '../../../theme/app_dimens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/bottom_action_bar.dart';
import '../../../shared/widgets/calendar_sheet.dart';
import '../../../shared/widgets/line_icons.dart';
import '../../../shared/widgets/clay_icon_tile.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/hairline_card.dart';
import '../../../shared/widgets/info_tip_row.dart';
import '../../../shared/widgets/module_list_scaffold.dart' show showToast;
import '../../../shared/widgets/round_close_button.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/segmented_row.dart';
import '../../../shared/widgets/sheet_scaffold.dart';
import '../../../theme/app_colors.dart';
import '../../categories/providers/categories_providers.dart';
import '../data/budget_repository.dart';
import '../providers/budget_providers.dart';
import 'budget_editor.dart';

/// 任意月份收支合计快照（预算概览用；bookId/year/month/type 定位）。
/// 复用 [TransactionsDao.watchTotalInRange] 的「实付口径」
/// （支出扣优惠、排除不计收支账单），与首页月合计一致。
final AutoDisposeFutureProviderFamily<int, (String, int, int, TxnType)>
    _monthTotalProvider =
    FutureProvider.autoDispose.family<int, (String, int, int, TxnType)>(
  (Ref ref, (String, int, int, TxnType) p) {
    final (String bookId, int year, int month, TxnType type) = p;
    final DateTime start = DateTime(year, month);
    final DateTime end = DateTime(year, month + 1);
    return ref
        .watch(transactionsDaoProvider)
        .watchTotalInRange(
          bookId: bookId,
          startAt: start.toUtc().millisecondsSinceEpoch,
          endAt: end.toUtc().millisecondsSinceEpoch,
          type: type,
        )
        .first;
  },
);

/// 来源月结余如何并入目标月草稿（对标参考稿；暂为占位状态，
/// 复制落库在分类预算草稿链路落地后接通）。
enum _CopyMode { none, balanceOnly, overspendBalance }

/// 全部账本（账本名按 bookId 查找用）。
final AutoDisposeStreamProvider<List<Book>> _booksProvider =
    StreamProvider.autoDispose<List<Book>>(
  (Ref ref) => ref.watch(booksDaoProvider).watchAll(),
);

/// 设置月预算页（2026-10-15 依小青账截图对标，第 25 批反馈修正；
/// 第 28 批「收入预算→收入目标」语义重构）：
///
/// - 顶部：✕ 关闭 + 居中「设置月预算」（收入方向显「设置月收入目标」；
///   支出/收入切换不在顶栏）；
/// - 头卡：黏土方糖 ¥ + 「设置月预算/设置月收入目标」+ 「是否每月提示」
///   开关（已接线：保存时写入总预算与带入分类的 alertEnabled，未手动改时
///   跟随目标月已有预算的开关值）；
/// - 复制范围卡：账本行（可点，弹账本列表切换）+ 来源月份 → 目标月份；
/// - 「{目标月}预算」标题行（行右 = 支出/收入切换，对标小青账）；
///   「{来源月}预算概览」卡（收入方向显「收入概览」，三格 =
///   目标/收入/差额）：
///   预算/消费/结余三格 + 不复制/仅结余/超支结余分段（结余为 0 时置灰）；
/// - 「{目标月}总预算」卡（收入方向显「总目标」）：输入框，草稿口径 =
///   目标月已有预算 > 复制模式起草（不复制=来源总预算 / 仅结余=结余>0
///   时的结余 / 超支结余=结余负值按 0）；
/// - 「{目标月}分类预算」卡（收入方向显「分类目标」）：空状态 + 添加
///   （接通预算编辑弹窗），已有预算列行，点按编辑；保存时复制模式非
///   「不复制」会把来源月有、目标月没有的同方向分类预算一并带入；
/// - 底部粘性保存按钮（鼠尾草渐变，支出=「保存支出预算」/ 收入=
///   「保存收入目标」）。
///
/// 口径说明：预算表无收支方向字段——总预算行（scope=overall）按
/// 支出口径保存；收入方向的总目标暂不支持单独保存（toast 提示），
/// 收入方向走分类目标。收入概览的「目标」= 来源月收入分类预算合计。
class BudgetSetupPage extends ConsumerStatefulWidget {
  const BudgetSetupPage({
    super.key,
    required this.initialTargetMonth,
    this.bookId,
  });

  /// 目标月份（默认取预算页当前查看的月份）。
  final DateTime initialTargetMonth;

  /// 指定账本（预算分类页按账本进入时传入）；空则用当前账本。
  final String? bookId;

  @override
  ConsumerState<BudgetSetupPage> createState() => _BudgetSetupPageState();
}

class _BudgetSetupPageState extends ConsumerState<BudgetSetupPage> {
  /// 生效账本（构造参数优先，否则当前账本；页内可切换）。
  late String _bookId = widget.bookId ?? ref.read(currentBookIdProvider);

  late DateTime _target;
  late DateTime _source;
  bool _reminder = false;

  /// 用户是否手动改过「是否每月提示」（未改时跟随目标月已有预算的开关）。
  bool _reminderTouched = false;
  CategoryType _direction = CategoryType.expense;
  _CopyMode _copyMode = _CopyMode.none;

  /// 用户是否手动改过总预算（未改时跟随草稿逻辑自动预填）。
  bool _totalTouched = false;
  late final TextEditingController _totalController;

  @override
  void initState() {
    super.initState();
    _target = DateTime(
      widget.initialTargetMonth.year,
      widget.initialTargetMonth.month,
    );
    _source = DateTime(_target.year, _target.month - 1);
    _totalController = TextEditingController();
    _syncDraft(ref.read(bookBudgetsProvider(_bookId)).valueOrNull);
  }

  @override
  void dispose() {
    _totalController.dispose();
    super.dispose();
  }

  /// 某月的总预算行（scope=overall 的 monthly 预算）。
  Budget? _overallOf(List<Budget> budgets, DateTime month) => budgets
      .where(
        (Budget b) =>
            b.scope == BudgetScope.overall &&
            b.period == BudgetPeriod.monthly &&
            b.year == month.year &&
            b.periodIndex == month.month,
      )
      .firstOrNull;

  /// 草稿同步（预算数据 / 周期 / 账本变化时调用）：
  /// 总预算输入框预填 + 「是否每月提示」跟随目标月已有预算。
  void _syncDraft(List<Budget>? budgets) {
    if (budgets == null) return;
    if (!_totalTouched) {
      // 目标月已有总预算 → 预填已有值（保存即更新）；
      // 否则按复制模式从来源月起草（结余口径的草稿在 _applyCopyModeDraft）。
      final Budget? targetOverall = _overallOf(budgets, _target);
      final Budget? srcOverall = _overallOf(budgets, _source);
      final String want = targetOverall != null
          ? _minorText(targetOverall.amountMinor)
          : _copyMode == _CopyMode.none
              ? _minorText(srcOverall?.amountMinor ?? 0)
              : _totalController.text;
      if (_totalController.text != want) _totalController.text = want;
    }
    if (!_reminderTouched) {
      final bool want = _overallOf(budgets, _target)?.alertEnabled ?? true;
      if (_reminder != want) _reminder = want;
    }
  }

  /// 复制模式起草（需要来源月消费口径，build 里算出结余后调用）：
  /// 未手动改、目标月无已有总预算时，按模式预填——
  /// 不复制 = 来源月总预算；仅结余 = 结余 > 0 时的结余，否则留空；
  /// 超支结余 = 结余（负值按 0 起草，预算不能为负）。
  void _applyCopyModeDraft(int srcBalanceMinor) {
    if (_totalTouched) return;
    final List<Budget>? budgets =
        ref.read(bookBudgetsProvider(_bookId)).valueOrNull;
    if (budgets == null || _overallOf(budgets, _target) != null) return;
    final String want = switch (_copyMode) {
      _CopyMode.none =>
        _minorText(_overallOf(budgets, _source)?.amountMinor ?? 0),
      _CopyMode.balanceOnly =>
        srcBalanceMinor > 0 ? _minorText(srcBalanceMinor) : '',
      _CopyMode.overspendBalance =>
        _minorText(srcBalanceMinor > 0 ? srcBalanceMinor : 0),
    };
    if (_totalController.text != want) _totalController.text = want;
  }

  String _minorText(int minor) =>
      minor > 0 ? Money.fromMinor(minor).decimal.toStringAsFixed(2) : '';

  /// 月份选择：全局日历组件「月」粒度，只提取年月（CalendarMonth）。
  Future<void> _pickMonth({required bool source}) async {
    final DateTime current = source ? _source : _target;
    final CalendarSelection? sel = await CalendarSheet.show(
      context,
      mode: CalendarSheetMode.month,
      initialMonth: current,
    );
    if (sel is! CalendarMonth) return;
    final DateTime picked = DateTime(sel.year, sel.month);
    setState(() {
      if (source) {
        _source = picked;
        // 目标月保持在来源月之后（至少次月）。
        if (!picked.isBefore(_target)) {
          _target = DateTime(picked.year, picked.month + 1);
        }
      } else {
        _target = picked;
        if (!picked.isAfter(_source)) {
          _source = DateTime(picked.year, picked.month - 1);
        }
      }
    });
    _syncDraft(ref.read(bookBudgetsProvider(_bookId)).valueOrNull);
  }

  /// 切换账本（对标小青账「复制范围」账本行）：弹账本列表，
  /// 选中后草稿整体重算（总预算预填 / 提示开关跟随）。
  Future<void> _pickBook() async {
    final List<Book> books =
        ref.read(_booksProvider).valueOrNull ?? const <Book>[];
    if (books.length <= 1) {
      showToast(context, '暂无其他账本可切换');
      return;
    }
    final String? picked = await showAppModalSheet<String>(
      context,
      title: '切换账本',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final Book b in books)
            InkWell(
              onTap: () => Navigator.of(context).pop(b.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        b.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: b.id == _bookId
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: b.id == _bookId
                              ? AppPalette.primary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (b.id == _bookId)
                      const LineGlyph(
                        Icons.check,
                        size: 18,
                        color: AppPalette.primary,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    if (picked == null || picked == _bookId || !mounted) {
      return;
    }
    setState(() {
      _bookId = picked;
      // 换账本后草稿重算：预填与提示开关都重新跟随目标月。
      _totalTouched = false;
      _reminderTouched = false;
    });
    _syncDraft(ref.read(bookBudgetsProvider(_bookId)).valueOrNull);
  }

  Future<void> _save() async {
    final double? amount = double.tryParse(_totalController.text.trim());
    if (amount == null || amount <= 0) {
      showToast(
        context,
        _direction == CategoryType.expense ? '请输入大于 0 的总预算' : '请输入大于 0 的总目标',
      );
      return;
    }
    // 预算表无方向字段：总预算行按支出口径保存；收入总目标待表结构支持。
    if (_direction != CategoryType.expense) {
      showToast(context, '收入总目标暂未支持单独保存，可先添加收入分类目标');
      return;
    }
    final List<Budget> budgets =
        ref.read(bookBudgetsProvider(_bookId)).valueOrNull ?? const <Budget>[];
    final Budget? existing = _overallOf(budgets, _target);
    final BudgetRepository repo = ref.read(budgetRepositoryProvider);
    try {
      // 分类带入（小青账口径「分类没有时会从来源月份带入」）：复制模式非
      // 「不复制」时，来源月有、目标月没有的同方向分类预算一并带入。
      int carried = 0;
      if (_copyMode != _CopyMode.none) {
        final List<Category> categories =
            ref.read(allCategoriesProvider).valueOrNull ?? const <Category>[];
        final Map<String, Category> catById = <String, Category>{
          for (final Category c in categories) c.id: c,
        };
        final Set<String> targetCatIds = <String>{
          for (final Budget b in budgets)
            if (b.scope == BudgetScope.category &&
                b.period == BudgetPeriod.monthly &&
                b.year == _target.year &&
                b.periodIndex == _target.month &&
                b.categoryId != null)
              b.categoryId!,
        };
        for (final Budget b in budgets) {
          if (b.scope != BudgetScope.category ||
              b.period != BudgetPeriod.monthly ||
              b.year != _source.year ||
              b.periodIndex != _source.month ||
              b.categoryId == null) {
            continue;
          }
          final Category? c = catById[b.categoryId];
          if (c == null || c.type != _direction) continue;
          if (targetCatIds.contains(b.categoryId)) continue;
          await repo.add(
            bookId: _bookId,
            scope: BudgetScope.category,
            period: BudgetPeriod.monthly,
            amountMinor: b.amountMinor,
            year: _target.year,
            periodIndex: _target.month,
            categoryId: b.categoryId,
            // 「是否每月提示」对本轮保存整体生效。
            alertEnabled: _reminder,
            alertThreshold: b.alertThreshold,
          );
          carried++;
        }
      }
      if (existing == null) {
        await repo.add(
          bookId: _bookId,
          scope: BudgetScope.overall,
          period: BudgetPeriod.monthly,
          amountMinor: Money.fromDecimal(amount).minor,
          year: _target.year,
          periodIndex: _target.month,
          categoryId: null,
          alertEnabled: _reminder,
          alertThreshold: 80,
        );
      } else {
        await repo.update(
          id: existing.id,
          scope: BudgetScope.overall,
          period: BudgetPeriod.monthly,
          amountMinor: Money.fromDecimal(amount).minor,
          year: _target.year,
          periodIndex: _target.month,
          categoryId: null,
          alertEnabled: _reminder,
          alertThreshold: existing.alertThreshold,
        );
      }
      if (mounted) {
        showToast(
          context,
          '已保存 ${_target.year}-${_target.month} 支出预算'
          '${carried > 0 ? '，带入 $carried 个分类预算' : ''}',
        );
        Navigator.of(context).pop();
      }
    } on AppFailure catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  void _addCategoryBudget() {
    showBudgetEditor(
      context,
      ref,
      null,
      BudgetSeed(
        scope: BudgetScope.category,
        categoryType: _direction,
        period: BudgetPeriod.monthly,
        year: _target.year,
        periodIndex: _target.month,
      ),
      _bookId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String dirLabel = _direction == CategoryType.expense ? '支出' : '收入';

    ref.listen<AsyncValue<List<Budget>>>(bookBudgetsProvider(_bookId),
        (_, AsyncValue<List<Budget>> next) {
      _syncDraft(next.valueOrNull);
    });

    final List<Budget> budgets =
        ref.watch(bookBudgetsProvider(_bookId)).valueOrNull ?? const <Budget>[];
    final List<Category> categories =
        ref.watch(allCategoriesProvider).valueOrNull ?? const <Category>[];
    final Book? book = ref
            .watch(_booksProvider)
            .valueOrNull
            ?.where((Book b) => b.id == _bookId)
            .firstOrNull ??
        ref.watch(currentBookProvider).valueOrNull;
    final String bookName = book?.name ?? '默认账本';
    final String bookId = _bookId;

    // ── 来源月概览 ──
    // 支出：预算=来源月总预算；收入：预算=来源月收入分类预算合计
    //（表无方向字段，总预算行只有一条且按支出口径）。
    final int srcBudgetMinor;
    if (_direction == CategoryType.expense) {
      srcBudgetMinor = _overallOf(budgets, _source)?.amountMinor ?? 0;
    } else {
      final Map<String, Category> catById = <String, Category>{
        for (final Category c in categories) c.id: c,
      };
      srcBudgetMinor = budgets
          .where(
            (Budget b) =>
                b.scope == BudgetScope.category &&
                b.period == BudgetPeriod.monthly &&
                b.year == _source.year &&
                b.periodIndex == _source.month &&
                catById[b.categoryId]?.type == CategoryType.income,
          )
          .fold<int>(0, (int s, Budget b) => s + b.amountMinor);
    }
    final int srcSpentMinor = ref
            .watch(
              _monthTotalProvider(
                (
                  bookId,
                  _source.year,
                  _source.month,
                  _direction == CategoryType.expense
                      ? TxnType.expense
                      : TxnType.income,
                ),
              ),
            )
            .valueOrNull ??
        0;
    final int srcBalanceMinor = srcBudgetMinor - srcSpentMinor;

    // 复制模式起草：结余口径的预填要在消费数据到位后执行。
    _applyCopyModeDraft(srcBalanceMinor);

    // ── 目标月分类预算（按当前方向过滤）──
    final Map<String, Category> catById = <String, Category>{
      for (final Category c in categories) c.id: c,
    };
    final List<(Budget, Category)> targetCatBudgets = <(Budget, Category)>[
      for (final Budget b in budgets)
        if (b.scope == BudgetScope.category &&
            b.period == BudgetPeriod.monthly &&
            b.year == _target.year &&
            b.periodIndex == _target.month &&
            catById[b.categoryId] != null &&
            catById[b.categoryId]!.type == _direction)
          (b, catById[b.categoryId]!),
    ];

    return Scaffold(
      body: Column(
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
                        // 收入方向走「收入目标」措辞（第 28 批）。
                        _direction == CategoryType.expense
                            ? '设置月预算'
                            : '设置月收入目标',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              children: <Widget>[
                _HeaderCard(
                  title:
                      _direction == CategoryType.expense ? '设置月预算' : '设置月收入目标',
                  reminder: _reminder,
                  onReminderChanged: (bool v) => setState(() {
                    _reminder = v;
                    _reminderTouched = true;
                  }),
                ),
                const SizedBox(height: 10),
                InfoTipRow(
                  text: '选择账本和来源月份，复制到目标月份后可再修改。'
                      '$bookName · ${_source.year}-${_source.month}'
                      ' → ${_target.year}-${_target.month}',
                ),
                const SizedBox(height: 16),
                SectionHeader(title: '复制范围'),
                const SizedBox(height: 8),
                HairlineCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // 账本行（对标小青账：可点，弹账本列表切换）。
                      InkWell(
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusCard),
                        onTap: _pickBook,
                        child: Row(
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
                                    '账本',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    bookName,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            LineGlyph(
                              Icons.chevron_right,
                              size: 20,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          _monthBox(
                            context,
                            '来源月份',
                            _source,
                            () => _pickMonth(source: true),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: LineGlyph(
                              Icons.arrow_right_alt,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          _monthBox(
                            context,
                            '目标月份',
                            _target,
                            () => _pickMonth(source: false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const InfoTipRow(
                        text: '将选中账本、来源月份的预算作为目标月份草稿，收支分开保存。',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 「{目标月}预算」标题行：支出/收入切换在行右
                // （第 25 批反馈「支出收入位置错误」——对标小青账
                // 「2026-10预算 [支出 收入]」，不在顶栏）。
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        // 收入方向：标题行显「收入目标」（第 28 批）。
                        _direction == CategoryType.expense
                            ? '${_target.year}-${_target.month}预算'
                            : '${_target.year}-${_target.month}收入目标',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 116,
                      child: SegmentedRow<CategoryType>(
                        options: const <SegmentOption<CategoryType>>[
                          SegmentOption<CategoryType>(
                            value: CategoryType.expense,
                            label: '支出',
                          ),
                          SegmentOption<CategoryType>(
                            value: CategoryType.income,
                            label: '收入',
                          ),
                        ],
                        value: _direction,
                        onChanged: (CategoryType v) {
                          setState(() => _direction = v);
                          _syncDraft(
                            ref.read(bookBudgetsProvider(_bookId)).valueOrNull,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SectionHeader(
                  title: _direction == CategoryType.expense
                      ? '${_source.year}-${_source.month}预算概览'
                      : '${_source.year}-${_source.month}收入概览',
                ),
                const SizedBox(height: 8),
                HairlineCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          _statBox(
                            context,
                            _direction == CategoryType.expense ? '预算' : '目标',
                            Money.fromMinor(srcBudgetMinor).format(),
                          ),
                          const SizedBox(width: 8),
                          _statBox(
                            context,
                            _direction == CategoryType.expense ? '消费' : '收入',
                            Money.fromMinor(srcSpentMinor).format(),
                          ),
                          const SizedBox(width: 8),
                          _statBox(
                            context,
                            _direction == CategoryType.expense ? '结余' : '差额',
                            Money.fromMinor(srcBalanceMinor).format(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SegmentedRow<_CopyMode>(
                        options: const <SegmentOption<_CopyMode>>[
                          SegmentOption<_CopyMode>(
                            value: _CopyMode.none,
                            label: '不复制',
                          ),
                          SegmentOption<_CopyMode>(
                            value: _CopyMode.balanceOnly,
                            label: '仅结余',
                          ),
                          SegmentOption<_CopyMode>(
                            value: _CopyMode.overspendBalance,
                            label: '超支结余',
                          ),
                        ],
                        value: _copyMode,
                        itemHeight: 34,
                        onChanged: (_CopyMode v) {
                          // 结余为 0 时仅「不复制」可选（对标参考稿置灰逻辑）。
                          if (srcBalanceMinor == 0 && v != _CopyMode.none) {
                            return;
                          }
                          setState(() => _copyMode = v);
                          _applyCopyModeDraft(srcBalanceMinor);
                        },
                      ),
                      const SizedBox(height: 10),
                      InfoTipRow(
                        text: srcBalanceMinor == 0
                            ? '${_source.year}-${_source.month}没有可计入的结余或超支'
                            : '可计入结余 '
                                '${Money.fromMinor(srcBalanceMinor).format()}，'
                                '保存后并入目标月份草稿',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionHeader(
                  title: _direction == CategoryType.expense
                      ? '${_target.year}-${_target.month}总预算'
                      : '${_target.year}-${_target.month}总目标',
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                HairlineCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TextField(
                        controller: _totalController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (String _) => _totalTouched = true,
                        decoration: InputDecoration(
                          hintText: '0.00',
                          filled: true,
                          // 全 app 输入框底色统一：surfaceContainerHighest。
                          fillColor: scheme.surfaceContainerHighest,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusChip),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusChip),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusChip),
                            borderSide: BorderSide(color: scheme.primary),
                          ),
                        ),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      InfoTipRow(
                        text: _direction == CategoryType.expense
                            ? (_overallOf(budgets, _target) != null
                                ? '${_target.year}-${_target.month}已有预算，'
                                    '保存将更新已有金额；分类没有时会从来源月份带入'
                                : '默认等于${_source.year}-${_source.month}预算，可自行调整')
                            : (_overallOf(budgets, _target) != null
                                ? '${_target.year}-${_target.month}已有目标，'
                                    '保存将更新已有金额；分类没有时会从来源月份带入'
                                : '默认等于${_source.year}-${_source.month}目标，可自行调整'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionHeader(
                  title: _direction == CategoryType.expense
                      ? '${_target.year}-${_target.month}分类预算'
                      : '${_target.year}-${_target.month}分类目标',
                  padding: EdgeInsets.zero,
                  trailing: _AmberPill(label: '添加', onTap: _addCategoryBudget),
                ),
                const SizedBox(height: 8),
                HairlineCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(12),
                  child: targetCatBudgets.isEmpty
                      ? EmptyState(
                          message: _direction == CategoryType.expense
                              ? '暂无$dirLabel分类预算'
                              : '暂无收入分类目标',
                          icon: Icons.account_balance_wallet_outlined,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          action:
                              _SagePill(label: '添加', onTap: _addCategoryBudget),
                        )
                      : Column(
                          children: <Widget>[
                            for (final (Budget b, Category c)
                                in targetCatBudgets)
                              _CategoryBudgetRow(
                                budget: b,
                                category: c,
                                onTap: () => showBudgetEditor(
                                  context,
                                  ref,
                                  b,
                                  BudgetSeed(
                                    scope: BudgetScope.category,
                                    categoryId: c.id,
                                    categoryType: c.type,
                                    period: BudgetPeriod.monthly,
                                    year: _target.year,
                                    periodIndex: _target.month,
                                  ),
                                  _bookId,
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          BottomActionBar(
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[AppPalette.sageMist, AppPalette.sageRibbon],
                  ),
                  borderRadius: BorderRadius.circular(AppDimens.radiusChip),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppDimens.radiusChip),
                    onTap: _save,
                    child: Center(
                      child: Text(
                        // 收入方向保存文案走「目标」（第 28 批）。
                        _direction == CategoryType.expense
                            ? '保存$dirLabel预算'
                            : '保存收入目标',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 月份盒（来源/目标）：灰底圆角 + 小标签 + 「y-m」粗体，点按选月。
  Widget _monthBox(
    BuildContext context,
    String label,
    DateTime month,
    VoidCallback onTap,
  ) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          ),
          child: Column(
            children: <Widget>[
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${month.year}-${month.month}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 概览三格（预算/消费/结余）：灰底圆角 + 标签 + 金额。
  Widget _statBox(BuildContext context, String label, String value) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Column(
          children: <Widget>[
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 头卡：黏土方糖 ¥ + 「设置月预算/设置月收入目标」+ 「是否每月提示」开关
/// （开关已接线：保存时写入总预算与带入分类的 alertEnabled）。
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.title,
    required this.reminder,
    required this.onReminderChanged,
  });

  /// 标题随方向：支出「设置月预算」/ 收入「设置月收入目标」（第 28 批）。
  final String title;
  final bool reminder;
  final ValueChanged<bool> onReminderChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return HairlineCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          const ClayIconTile(
            color: AppPalette.primary,
            child: LineGlyph(
              Icons.currency_yuan_outlined,
              size: 22,
              color: AppPalette.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            '是否每月提示',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          Switch(value: reminder, onChanged: onReminderChanged),
        ],
      ),
    );
  }
}

/// 「添加」琥珀 pill（分类预算卡头，对标参考稿）。
class _AmberPill extends StatelessWidget {
  const _AmberPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppPalette.amber.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(AppDimens.radiusChip),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
      ),
    );
  }
}

/// 「添加」鼠尾草渐变 pill（空状态主行动）。
class _SagePill extends StatelessWidget {
  const _SagePill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[AppPalette.sageMist, AppPalette.sageRibbon],
          ),
          borderRadius: BorderRadius.circular(AppDimens.radiusChip),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimens.radiusChip),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppPalette.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 目标月分类预算行：黏土方糖图标 + 分类名 + 金额，点按编辑。
class _CategoryBudgetRow extends StatelessWidget {
  const _CategoryBudgetRow({
    required this.budget,
    required this.category,
    required this.onTap,
  });

  final Budget budget;
  final Category category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color tint = category.colorValue != null
        ? Color(category.colorValue!)
        : AppPalette.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            ClayIconTile(
              size: 34,
              color: tint,
              // 与记一笔同款钢笔线稿（2026-10-14 反馈：图标风格全局统一）。
              child: LineIcon(
                categoryLineKind(category.iconKey) ?? LineIconKind.star,
                size: 18,
                color: Color.lerp(tint, scheme.onSurface, 0.22),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            Text(
              Money.fromMinor(budget.amountMinor).format(),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
