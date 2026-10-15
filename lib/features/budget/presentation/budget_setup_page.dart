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

/// 设置月预算页（2026-10-14 依参考截图占位布局）：
///
/// - 顶部圆关闭钮（RoundCloseButton），无 AppBar；
/// - 头卡：黏土方糖 ¥ + 「设置 月预算」 + 「是否每月提示」开关（占位状态）；
/// - 复制范围卡：账本行（占位不可切换）+ 来源月份 → 目标月份
///   （点按唤起全局日历组件的「月」粒度，只取年月）；
/// - 「{目标月}预算」标题行 + 支出/收入分段；「{来源月}预算概览」卡：
///   预算/消费/结余三格 + 不复制/仅结余/超支结余分段（结余为 0 时锁定）；
/// - 「{目标月}总预算」卡：胶囊输入框，默认预填来源月总预算；
/// - 「{目标月}分类预算」卡：空状态 + 添加（唤起预算编辑弹窗），
///   已有预算列黏土方糖行，点按编辑；
/// - 底部粘性保存按钮（鼠尾草渐变）。
///
/// 口径说明：预算表无收支方向字段——总预算行（scope=overall）按
/// 支出口径保存；收入方向的总预算暂不支持单独保存（toast 提示），
/// 收入方向走分类预算。收入概览的「预算」= 来源月收入分类预算合计。
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
  /// 生效账本（构造参数优先，否则当前账本）。
  late final String _bookId = widget.bookId ?? ref.read(currentBookIdProvider);

  late DateTime _target;
  late DateTime _source;
  bool _reminder = false;
  CategoryType _direction = CategoryType.expense;
  _CopyMode _copyMode = _CopyMode.none;

  /// 用户是否手动改过总预算（未改时跟随来源月总预算自动预填）。
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
    _syncTotalPrefill(ref.read(bookBudgetsProvider(_bookId)).valueOrNull);
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

  /// 未手动编辑时，总预算输入框跟随来源月总预算。
  void _syncTotalPrefill(List<Budget>? budgets) {
    if (_totalTouched || budgets == null) return;
    final Budget? overall = _overallOf(budgets, _source);
    final String want = overall == null
        ? ''
        : Money.fromMinor(overall.amountMinor).decimal.toStringAsFixed(2);
    if (_totalController.text != want) _totalController.text = want;
  }

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
    _syncTotalPrefill(ref.read(bookBudgetsProvider(_bookId)).valueOrNull);
  }

  Future<void> _save() async {
    final double? amount = double.tryParse(_totalController.text.trim());
    if (amount == null || amount <= 0) {
      showToast(context, '请输入大于 0 的总预算');
      return;
    }
    // 预算表无方向字段：总预算行按支出口径保存；收入总预算待表结构支持。
    if (_direction != CategoryType.expense) {
      showToast(context, '收入总预算暂未支持单独保存，可先添加收入分类预算');
      return;
    }
    final List<Budget> budgets =
        ref.read(bookBudgetsProvider(_bookId)).valueOrNull ?? const <Budget>[];
    final Budget? existing = _overallOf(budgets, _target);
    final BudgetRepository repo = ref.read(budgetRepositoryProvider);
    try {
      if (existing == null) {
        await repo.add(
          bookId: _bookId,
          scope: BudgetScope.overall,
          period: BudgetPeriod.monthly,
          amountMinor: Money.fromDecimal(amount).minor,
          year: _target.year,
          periodIndex: _target.month,
          categoryId: null,
          alertEnabled: true,
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
          alertEnabled: existing.alertEnabled,
          alertThreshold: existing.alertThreshold,
        );
      }
      if (mounted) {
        showToast(context, '已保存 ${_target.year}-${_target.month} 支出预算');
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
      _syncTotalPrefill(next.valueOrNull);
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
                children: <Widget>[const RoundCloseButton(), const Spacer()],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              children: <Widget>[
                _HeaderCard(
                  reminder: _reminder,
                  onReminderChanged: (bool v) => setState(() => _reminder = v),
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
                      // 账本行（占位：多账本切换待账本管理完善后接入）。
                      InkWell(
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusCard),
                        onTap: () => showToast(context, '账本切换即将支持'),
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
                // 「{目标月}预算」标题行 + 支出/收入分段。
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${_target.year}-${_target.month}预算',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 148,
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
                        onChanged: (CategoryType v) =>
                            setState(() => _direction = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SectionHeader(title: '${_source.year}-${_source.month}预算概览'),
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
                            '预算',
                            Money.fromMinor(srcBudgetMinor).format(),
                          ),
                          const SizedBox(width: 8),
                          _statBox(
                            context,
                            '消费',
                            Money.fromMinor(srcSpentMinor).format(),
                          ),
                          const SizedBox(width: 8),
                          _statBox(
                            context,
                            '结余',
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
                  title: '${_target.year}-${_target.month}总预算',
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
                        text: '默认等于${_source.year}-${_source.month}预算，可自行调整',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionHeader(
                  title: '${_target.year}-${_target.month}分类预算',
                  padding: EdgeInsets.zero,
                  trailing: _AmberPill(label: '添加', onTap: _addCategoryBudget),
                ),
                const SizedBox(height: 8),
                HairlineCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(12),
                  child: targetCatBudgets.isEmpty
                      ? EmptyState(
                          message: '暂无$dirLabel分类预算',
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
                        '保存$dirLabel预算',
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

/// 头卡：黏土方糖 ¥ + 「设置 月预算」 + 「是否每月提示」开关（占位状态）。
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.reminder, required this.onReminderChanged});

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
              '设置 月预算',
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
