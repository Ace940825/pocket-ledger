import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_dimens.dart';
import '../../../core/theme/forest_design_tokens.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/line_icons.dart';
import '../../../theme/app_colors.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../providers/ledger_providers.dart';
import 'ledger_filter_page.dart';
import 'widgets/txn_icon.dart';

/// 「账单清理」页（我的 → 账单管理 → 账单清理，小青账布局）。
///
/// - 顶部：返回箭头 + 居中标题；下行「yyyy年M月 ˅」月份切换 + 右侧「筛选」；
/// - 提示卡：绿竖条「提示」+ ⓘ 说明（时间/筛选 → 多选清理，不可恢复）；
/// - 「共 N 笔账单」+ 右侧「全选」（全选当前筛选下的可见账单）；
/// - 行：图标 + 标题(+标签胶囊) + 日期/时间，右侧金额 + 圆形勾选框；
/// - 底部悬浮「清理(N个)」绿色胶囊，确认后逐笔
///   [TransactionRepository.remove]（余额回退 / 级联 / 同步入队由仓储保证）。
class BillCleanPage extends ConsumerStatefulWidget {
  const BillCleanPage({super.key});

  @override
  ConsumerState<BillCleanPage> createState() => _BillCleanPageState();
}

class _BillCleanPageState extends ConsumerState<BillCleanPage> {
  /// 当前查看的月份（默认当月）。
  late DateTime _month =
      DateTime(DateTime.now().year, DateTime.now().month);

  /// 高级筛选条件（与报表/账单页同款 [LedgerFilterPage]，查询后生效；
  /// null = 未筛选）。
  LedgerAdvancedFilter? _filter;

  /// 已勾选待删除的流水 ID。
  final Set<String> _selected = <String>{};

  bool _deleting = false;

  static const int _minYear = 2020;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Transaction>> txnsAsync =
        ref.watch(bookAllTransactionsProvider);
    final Map<String, Category> categories =
        ref.watch(categoryMapProvider).valueOrNull ?? <String, Category>{};
    final Map<String, Account> accounts = <String, Account>{
      for (final Account a
          in ref.watch(accountsProvider).valueOrNull ?? <Account>[])
        a.id: a,
    };

    return Scaffold(
      body: Stack(
        children: <Widget>[
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _header(),
                _monthFilterRow(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _TipCard(),
                ),
                Expanded(
                  child: txnsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (Object e, StackTrace? s) =>
                        Center(child: Text('加载失败：$e')),
                    data: (List<Transaction> all) {
                      final List<Transaction> list =
                          _filtered(all, categories);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _listHeader(list),
                          Expanded(
                            child: list.isEmpty
                                ? ListView(
                                    padding: EdgeInsets.zero,
                                    children: const <Widget>[
                                      Padding(
                                        padding: EdgeInsets.only(top: 72),
                                        child: EmptyState(message: '本月暂无账单'),
                                      ),
                                    ],
                                  )
                                : ListView.builder(
                                    padding:
                                        const EdgeInsets.only(bottom: 110),
                                    itemCount: list.length,
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                      final Transaction txn = list[index];
                                      return _CleanTile(
                                        txn: txn,
                                        category:
                                            categories[txn.categoryId],
                                        account: accounts[txn.accountId],
                                        toAccount:
                                            accounts[txn.toAccountId],
                                        checked:
                                            _selected.contains(txn.id),
                                        onToggle: () => _toggle(txn.id),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // 底部悬浮「清理(N个)」胶囊。
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(child: _cleanPill()),
          ),
        ],
      ),
    );
  }

  // ────────────────────────── 顶部 ──────────────────────────

  /// 返回箭头 + 居中标题（替代 X 圆钮版式）。
  /// 注意 Stack 必须 占满整行宽（width: double.infinity），否则
  /// 非定位子级把 Stack 收缩成标题自身宽度，「居中」失效变左对齐。
  Widget _header() {
    return SizedBox(
      height: 46,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          const Text(
            '账单清理',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppPalette.textPrimary,
            ),
          ),
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                size: 19,
                color: AppPalette.textPrimary,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }

  /// 「yyyy年M月 ˅」月份切换 + 右侧「筛选」。
  Widget _monthFilterRow() {
    final int n = _filter?.conditionCount ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _pickMonth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${_month.year}年${_month.month}月',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: AppPalette.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _pickFilter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Text(
                n > 0 ? '筛选(条件$n个)' : '筛选',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: n > 0 ? ForestGreen.deep : AppPalette.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────── 筛选 ──────────────────────────

  List<Transaction> _filtered(
    List<Transaction> all,
    Map<String, Category> categories,
  ) {
    final int start =
        _month.millisecondsSinceEpoch; // 本地月零点（下同），流水存 UTC 毫秒但同源可比
    final DateTime nextMonth = DateTime(_month.year, _month.month + 1);
    final int end = nextMonth.millisecondsSinceEpoch;
    final List<Transaction> monthList = all
        .where((Transaction t) => t.occurredAt >= start && t.occurredAt < end)
        .toList();
    // 高级筛选与报表/账单页共用同一套口径（applyLedgerAdvancedFilter）；
    // 筛选页若设置了周期/单日，会在所选月份范围内取交集。
    final List<Transaction> list =
        applyLedgerAdvancedFilter(monthList, _filter, categories);
    list.sort((Transaction a, Transaction b) => b.occurredAt - a.occurredAt);
    return list;
  }

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id)) {
        _selected.add(id);
      }
    });
  }

  Future<void> _pickMonth() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: AppPalette.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) => _MonthPickSheet(
        initial: _month,
        minYear: _minYear,
        maxYear: now.year,
      ),
    );
    if (picked != null) {
      setState(() {
        _month = picked;
        _selected.clear(); // 切月清空勾选（全选只对当前可见列表生效）
      });
    }
  }

  /// 打开筛选页（与报表 Tab 同款 [LedgerFilterPage]，查询后生效）。
  Future<void> _pickFilter() async {
    final LedgerAdvancedFilter? result =
        await Navigator.of(context, rootNavigator: true)
            .push<LedgerAdvancedFilter>(
      MaterialPageRoute<LedgerAdvancedFilter>(
        builder: (BuildContext _) => LedgerFilterPage(initial: _filter),
      ),
    );
    if (result != null) {
      setState(() {
        _filter = result.isEmpty ? null : result;
        _selected.clear(); // 条件生效后可见列表变化，清空勾选
      });
    }
  }

  // ────────────────────────── 列表头（共 N 笔 / 全选） ──────────────────────────

  Widget _listHeader(List<Transaction> visible) {
    final int count = visible.length;
    final bool allChecked =
        count > 0 && _selected.length >= count && _selected.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: <Widget>[
          Text(
            '共 $count 笔账单',
            style: const TextStyle(
              fontSize: 13,
              color: AppPalette.textTertiary,
            ),
          ),
          const Spacer(),
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: count == 0
                ? null
                : () => setState(() {
                      if (allChecked) {
                        _selected.clear();
                      } else {
                        _selected
                          ..clear()
                          ..addAll(visible.map((Transaction t) => t.id));
                      }
                    }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                allChecked ? '取消全选' : '全选',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: count == 0
                      ? AppPalette.textTertiary
                      : ForestGreen.deep,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────── 底部清理胶囊 ──────────────────────────

  Widget _cleanPill() {
    final int n = _selected.length;
    final bool enabled = n > 0 && !_deleting;
    return Opacity(
      opacity: enabled ? 1 : 0.75,
      child: Material(
        color: enabled ? ForestGreen.deep : ForestGreen.soft,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: enabled ? _confirmDelete : null,
          child: Container(
            constraints: const BoxConstraints(minWidth: 220),
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
            alignment: Alignment.center,
            child: _deleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ForestGreen.deep,
                    ),
                  )
                : Text(
                    '清理($n个)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: enabled ? AppPalette.white : ForestGreen.deep,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // ────────────────────────── 删除 ──────────────────────────

  Future<void> _confirmDelete() async {
    final int count = _selected.length;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
        title: const Text('确认清理', style: TextStyle(fontSize: 17)),
        content: Text(
          '将清理 $count 笔账单，账户余额会同步回退，'
          '关联的报销 / 借还记录一并处理，清理后不可恢复。',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消',
                style: TextStyle(color: AppPalette.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('清理',
                style: TextStyle(
                  color: AppPalette.expense,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _delete();
  }

  Future<void> _delete() async {
    setState(() => _deleting = true);
    final List<String> ids = List<String>.of(_selected);
    int done = 0;
    try {
      // 逐笔删除：remove() 内部保证「余额回退 + 级联 + 同步入队」原子性。
      for (final String id in ids) {
        try {
          await ref.read(transactionRepositoryProvider).remove(id);
          done++;
        } catch (_) {
          // 单笔失败不中断整批（如已被别处删除）。
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _deleting = false;
          _selected.clear();
        });
        showAppToast(context, done == ids.length
            ? '已清理 $done 笔账单'
            : '已清理 $done 笔，${ids.length - done} 笔失败');
      }
    }
  }
}

// ────────────────────────── 提示卡 ──────────────────────────

/// 提示卡：白底外卡（绿竖条 + 「提示」）+ 内嵌浅灰盒（ⓘ + 两行说明）。
class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 3.5,
                height: 14,
                decoration: BoxDecoration(
                  color: ForestGreen.deep,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 7),
              const Text(
                '提示',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppPalette.neutralSoft.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const <Widget>[
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: AppPalette.textTertiary,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '可以根据时间或筛选条件筛选账单，再多选清理；'
                    '清理后的账单不可恢复，请谨慎清理~',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: AppPalette.textTertiary,
                    ),
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

// ────────────────────────── 月份选择弹窗 ──────────────────────────

/// 「选择月份」底部弹窗：‹ 年份 › + 4×3 月份宫格（当前月深绿高亮，
/// 晚于当月的月份置灰不可选）。
class _MonthPickSheet extends StatefulWidget {
  const _MonthPickSheet({
    required this.initial,
    required this.minYear,
    required this.maxYear,
  });

  final DateTime initial;
  final int minYear;
  final int maxYear;

  @override
  State<_MonthPickSheet> createState() => _MonthPickSheetState();
}

class _MonthPickSheetState extends State<_MonthPickSheet> {
  late int _year = widget.initial.year.clamp(widget.minYear, widget.maxYear);

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final int nowYear = now.year;
    final int nowMonth = now.month;
    final bool isPickedYear = _year == widget.initial.year &&
        widget.initial.year >= widget.minYear &&
        widget.initial.year <= widget.maxYear;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // 标题行：‹ 选择月份 ›（左右切年）。
            Row(
              children: <Widget>[
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 24),
                  color: _year > widget.minYear
                      ? AppPalette.textPrimary
                      : AppPalette.divider,
                  onPressed: _year > widget.minYear
                      ? () => setState(() => _year--)
                      : null,
                ),
                Text(
                  '$_year年',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 24),
                  color: _year < widget.maxYear
                      ? AppPalette.textPrimary
                      : AppPalette.divider,
                  onPressed: _year < widget.maxYear
                      ? () => setState(() => _year++)
                      : null,
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 4),
            // 4×3 月份宫格。
            for (final List<int> row in const <List<int>>[
              <int>[1, 2, 3, 4],
              <int>[5, 6, 7, 8],
              <int>[9, 10, 11, 12],
            ])
              Row(
                children: <Widget>[
                  for (final int m in row)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: _monthCell(m, isPickedYear, nowYear, nowMonth),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _monthCell(int m, bool isPickedYear, int nowYear, int nowMonth) {
    final bool future = _year > nowYear || (_year == nowYear && m > nowMonth);
    final bool picked =
        isPickedYear && _year == widget.initial.year && m == widget.initial.month;
    final bool active = !future;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: active
          ? () => Navigator.of(context).pop(DateTime(_year, m))
          : null,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: picked
              ? ForestGreen.deep
              : active
                  ? ForestGreen.soft
                  : AppPalette.neutralSoft.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$m月',
          style: TextStyle(
            fontSize: 14,
            fontWeight: picked ? FontWeight.w700 : FontWeight.w400,
            color: picked
                ? AppPalette.white
                : active
                    ? ForestGreen.deep
                    : AppPalette.divider,
          ),
        ),
      ),
    );
  }
}

// ────────────────────────── 账单行 ──────────────────────────

/// 可勾选账单行：图标 + 标题(+标签胶囊)/日期/时间，右侧金额 + 圆形勾选框。
class _CleanTile extends StatelessWidget {
  const _CleanTile({
    required this.txn,
    required this.category,
    required this.account,
    required this.toAccount,
    required this.checked,
    required this.onToggle,
  });

  final Transaction txn;
  final Category? category;
  final Account? account;
  final Account? toAccount;
  final bool checked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final DateTime occurred = DateTime.fromMillisecondsSinceEpoch(
      txn.occurredAt,
      isUtc: true,
    ).toLocal();
    final String title = txn.sourceModule == SourceModule.refund
        ? SourceModule.refund.label
        : (category?.name ?? txn.type.label);

    // 标签胶囊：退款已关联原账单 → 「已关联」；储蓄存取 → 「存钱计划」。
    final List<String> tags = <String>[
      if (txn.sourceModule == SourceModule.refund &&
          (txn.relatedId?.isNotEmpty ?? false))
        '已关联',
      if (txn.sourceModule == SourceModule.savings) '存钱计划',
    ];

    final String dateLabel = occurred.year == DateTime.now().year
        ? DateFormat('M月d日').format(occurred)
        : DateFormat('yyyy年M月d日').format(occurred);

    return Material(
      color: AppPalette.white,
      child: InkWell(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppPalette.divider, width: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _icon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.textPrimary,
                            ),
                          ),
                        ),
                        for (final String tag in tags) ...<Widget>[
                          const SizedBox(width: 6),
                          _TagPill(tag),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppPalette.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('HH:mm').format(occurred),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppPalette.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _amountColumn(),
              const SizedBox(width: 12),
              // 圆形勾选框（最右）。
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: checked ? ForestGreen.deep : Colors.transparent,
                  border: Border.all(
                    width: 1.6,
                    color: checked ? ForestGreen.deep : AppPalette.divider,
                  ),
                ),
                child: checked
                    ? const Icon(Icons.check, size: 14, color: AppPalette.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _icon() {
    final Color tint = category?.colorValue != null
        ? Color(category!.colorValue!)
        : switch (txn.type) {
            TxnType.income => AppPalette.income,
            TxnType.expense => AppPalette.expense,
            TxnType.transfer => AppPalette.transfer,
          };
    final LineIconKind? lineKind = txnLineIconKind(txn, category);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Center(
        child: lineKind != null
            ? LineIcon(lineKind, size: 22, color: tint)
            : Icon(_fallbackIcon, size: 22, color: tint),
      ),
    );
  }

  IconData get _fallbackIcon => switch (txn.type) {
        TxnType.income => Icons.south_west,
        TxnType.expense => Icons.north_east,
        TxnType.transfer => Icons.swap_horiz,
      };

  Widget _amountColumn() {
    final bool isExpense = txn.type == TxnType.expense;
    final bool hasDiscount = isExpense && txn.discountMinor > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (hasDiscount)
          // 优惠支出：划线原价「−¥8.00」+ 红色实付「5.00」。
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                '−${Money.fromMinor(txn.amountMinor).format()}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppPalette.textTertiary,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: AppPalette.textTertiary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                Money.fromMinor(txn.amountMinor - txn.discountMinor)
                    .format(showSymbol: false),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.expense,
                ),
              ),
            ],
          )
        else
          Text(
            switch (txn.type) {
              TxnType.income => '+${Money.fromMinor(txn.amountMinor).format()}',
              TxnType.expense => '−${Money.fromMinor(txn.amountMinor).format()}',
              TxnType.transfer => Money.fromMinor(txn.amountMinor).format(),
            },
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: txn.type == TxnType.income
                  ? AppPalette.income
                  : txn.type == TxnType.expense
                      ? AppPalette.expense
                      : AppPalette.textPrimary,
            ),
          ),
        if (hasDiscount)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '优惠${Money.fromMinor(txn.discountMinor).format(showSymbol: false)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppPalette.expense,
              ),
            ),
          ),
      ],
    );
  }
}

/// 绿色描边标签胶囊（已关联 / 存钱计划）。
class _TagPill extends StatelessWidget {
  const _TagPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: ForestGreen.soft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: ForestGreen.deep,
        ),
      ),
    );
  }
}
