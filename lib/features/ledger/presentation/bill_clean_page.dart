import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pocket_ledger/shared/widgets/loading_state.dart';

import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/calendar_sheet.dart';
import '../../../shared/widgets/clay_icon_tile.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/line_icon_map.dart';
import '../../../shared/widgets/line_icons.dart';
import '../../../shared/widgets/tag_pill.dart';
import '../../../theme/app_colors.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../providers/ledger_providers.dart';
import 'ledger_filter_page.dart';
import 'widgets/txn_icon.dart';

/// 「账单清理」页（我的 → 账单管理 → 账单清理，小青账布局）。
///
/// - 顶部：返回箭头 + 居中标题；下行「周期标签 ˅」（共享日历组件，月/年/自定义）
///   + 右侧「筛选」；
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
  /// 当前查看的周期（默认当月；经共享日历组件可切周/月/年/自定义）。
  late LedgerPeriod _period =
      LedgerPeriod.monthOf(DateTime(DateTime.now().year, DateTime.now().month));

  /// 高级筛选条件（与报表/账单页同款 [LedgerFilterPage]，查询后生效；
  /// null = 未筛选）。
  LedgerAdvancedFilter? _filter;

  /// 已勾选待删除的流水 ID。
  final Set<String> _selected = <String>{};

  bool _deleting = false;

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
                    loading: () => const LoadingState(),
                    error: (Object e, StackTrace? s) =>
                        Center(child: Text('加载失败：$e')),
                    data: (List<Transaction> all) {
                      final List<Transaction> list = _filtered(all, categories);
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
                                        child: EmptyState(message: '当前周期暂无账单'),
                                      ),
                                    ],
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.only(bottom: 110),
                                    itemCount: list.length,
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                      final Transaction txn = list[index];
                                      return _CleanTile(
                                        txn: txn,
                                        category: categories[txn.categoryId],
                                        account: accounts[txn.accountId],
                                        toAccount: accounts[txn.toAccountId],
                                        checked: _selected.contains(txn.id),
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
          Text(
            '账单清理',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.forest.onSurface,
            ),
          ),
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: IconButton(
              icon: LineGlyph(
                Icons.arrow_back_ios_new,
                size: 19,
                color: context.forest.onSurface,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }

  /// 「周期标签 ˅」（月/年/自定义）+ 右侧「筛选」。
  Widget _monthFilterRow() {
    final int n = _filter?.conditionCount ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _pickPeriod,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _period.label,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: context.forest.onSurface,
                    ),
                  ),
                  LineGlyph(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: context.forest.onSurfaceVariant,
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
                  color: n > 0
                      ? ForestGreen.deep
                      : context.forest.onSurface,
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
        _period.start.millisecondsSinceEpoch; // 本地零点（下同），流水存 UTC 毫秒但同源可比
    final int end = _period.end.millisecondsSinceEpoch; // 开区间（不含）
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

  /// 周期切换：共享日历组件（CalendarSheet 纯周期模式，与流水页/报表页同款），
  /// 支持周/月/年/自定义四种粒度，确认后整段区间生效。
  Future<void> _pickPeriod() async {
    // 年份下限取「账本内最早一笔流水的年份」（兜底 2000 = 日历宫格首年）：
    // 此前硬编码 DateTime(2020)，2016-2019 的历史账单在年宫格里置灰、
    // 无法被选中清理（2026-10-22 真机反馈「批量删除年份范围不完整」）。
    // 动态取值同时保证：账本里存在的任意年份都可选，又不会开出一堆
    // 永远空白的早年（2000-最早年之间仍置灰）。
    // 注意： earliest 先用 null 累积、循环后再兜底——切勿把兜底值当初值
    // 参与 min（那样任何账本的下限都会被压成兜底值，动态下限失效）。
    final List<Transaction> allTxns =
        ref.read(bookAllTransactionsProvider).valueOrNull ??
            const <Transaction>[];
    int? earliestYear;
    for (final Transaction t in allTxns) {
      final int y = DateTime.fromMillisecondsSinceEpoch(
        t.occurredAt,
        isUtc: true,
      ).toLocal().year;
      if (earliestYear == null || y < earliestYear) earliestYear = y;
    }
    final int firstYear = earliestYear ?? 2000;
    final CalendarPeriodMode cm = switch (_period.mode) {
      LedgerPeriodMode.week => CalendarPeriodMode.week,
      LedgerPeriodMode.month => CalendarPeriodMode.month,
      LedgerPeriodMode.year => CalendarPeriodMode.year,
      LedgerPeriodMode.custom => CalendarPeriodMode.custom,
    };
    final CalendarSelection? r = await CalendarSheet.show(
      context,
      mode: CalendarSheetMode.day,
      showDayView: false,
      headerTitle: '清理周期',
      initialPeriod: CalendarPeriod(cm, _period.start, _period.end),
      firstDate: DateTime(firstYear),
      lastDate: DateTime(DateTime.now().year, 12, 31),
      weekStart: CalendarWeekStart.monday,
    );
    if (r is! CalendarPeriod) return;
    final LedgerPeriodMode lm = switch (r.mode) {
      CalendarPeriodMode.week => LedgerPeriodMode.week,
      CalendarPeriodMode.month => LedgerPeriodMode.month,
      CalendarPeriodMode.year => LedgerPeriodMode.year,
      CalendarPeriodMode.custom => LedgerPeriodMode.custom,
    };
    setState(() {
      _period = LedgerPeriod(mode: lm, start: r.start, end: r.end);
      // 反向同步：筛选带着时间条件时一并换成新周期，否则页头是新周期、
      // 明细却被旧区间夹成空列表（时间轴只认一处）。
      _filter = ledgerFilterWithPeriod(_filter, _period);
      _selected.clear(); // 切周期清空勾选（全选只对当前可见列表生效）
    });
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
        // 筛选的「时间」即页面周期：查询后页头周期跟着切，避免页头停在旧
        // 周期、列表却被筛到别的区间（2026-10-22 真机反馈同款问题）。
        _period = ledgerPeriodOfFilter(result) ?? _period;
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
            style: TextStyle(
              fontSize: 13,
              color: context.forest.onSurfaceVariant,
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
                      ? context.forest.onSurfaceVariant
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
    final bool? ok = await showConfirm(
      context,
      title: '确认清理',
      content: '将清理 $count 笔账单，账户余额会同步回退，'
          '关联的报销 / 借还记录一并处理，清理后不可恢复。',
      confirmText: '清理',
      danger: true,
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
        showAppToast(
          context,
          done == ids.length
              ? '已清理 $done 笔账单'
              : '已清理 $done 笔，${ids.length - done} 笔失败',
        );
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
              Text(
                '提示',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.forest.onSurface,
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
              children: <Widget>[
                LineGlyph(
                  Icons.info_outline,
                  size: 14,
                  color: context.forest.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '可以根据时间或筛选条件筛选账单，再多选清理；'
                    '清理后的账单不可恢复，请谨慎清理~',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: context.forest.onSurfaceVariant,
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
              _icon(context),
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
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: context.forest.onSurface,
                            ),
                          ),
                        ),
                        for (final String tag in tags) ...<Widget>[
                          const SizedBox(width: 6),
                          TagPill(tag),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      dateLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.forest.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('HH:mm').format(occurred),
                      style: TextStyle(
                        fontSize: 13,
                        color: context.forest.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _amountColumn(context),
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
                    ? const LineGlyph(Icons.check,
                        size: 14, color: AppPalette.white,)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _icon(BuildContext context) {
    final Color tint = category?.colorValue != null
        ? Color(category!.colorValue!)
        : switch (txn.type) {
            TxnType.income => AppPalette.income,
            TxnType.expense => AppPalette.expense,
            TxnType.transfer => AppPalette.transfer,
          };
    final LineIconKind lineKind = resolveTxnLineIcon(txn, category);

    return ClayIconTile(
      size: 44,
      color: tint,
      child: Center(
        child: LineIcon(
          lineKind,
          size: 22,
          color: Color.lerp(
            tint,
            context.forest.onSurface,
            0.22,
          )!,
        ),
      ),
    );
  }

  Widget _amountColumn(BuildContext context) {
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
                style: TextStyle(
                  fontSize: 13,
                  color: context.forest.onSurfaceVariant,
                  decoration: TextDecoration.lineThrough,
                  decorationColor:
                      context.forest.onSurfaceVariant,
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
              TxnType.expense =>
                '−${Money.fromMinor(txn.amountMinor).format()}',
              TxnType.transfer => Money.fromMinor(txn.amountMinor).format(),
            },
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: txn.type == TxnType.income
                  ? AppPalette.income
                  : txn.type == TxnType.expense
                      ? AppPalette.expense
                      : context.forest.onSurface,
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
