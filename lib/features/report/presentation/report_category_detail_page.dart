import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_dimens.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/category_icons.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../theme/app_colors.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../ledger/presentation/transaction_detail_sheet.dart';
import '../../ledger/providers/ledger_providers.dart';
import '../providers/report_providers.dart';

/// 报表 · 分类明细汇总页。
///
/// 从报表页「分类明细」行点入，展示当前报表周期 + 报表筛选条件下
/// 该分类（大类或小类，视报表环形图当前粒度）下的全部流水：
/// - AppBar：左关闭、中「分类名(共N笔)」、右刷新；
/// - 「账单明细」+ 按时间/按金额切换；
/// - 按日分组：日头「M月d日 今天/昨天」+ 当日合计（支:/收:）；
/// - 行：分类圆图标 + 备注/分类名 + 时间；右侧金额（有优惠时划线原价 +
///   实付 + 「优惠X」）+ 资产账户名；点行打开流水详情弹窗。
class ReportCategoryDetailPage extends ConsumerStatefulWidget {
  const ReportCategoryDetailPage({
    super.key,
    required this.categoryKey,
    required this.byParent,
    required this.branch,
  });

  /// 分类 id；空串 = 「未分类」（无分类流水）。
  final String categoryKey;

  /// 与报表环形图当前粒度一致：true=按大类（父分类）聚合命中。
  final bool byParent;

  /// 报表统计分支（月支出/月收入/其他）。
  final ReportBranch branch;

  @override
  ConsumerState<ReportCategoryDetailPage> createState() =>
      _ReportCategoryDetailPageState();
}

class _ReportCategoryDetailPageState
    extends ConsumerState<ReportCategoryDetailPage> {
  /// 排序方式：false=按时间（默认，日内新→旧），true=按金额（新→旧降序）。
  bool _byAmount = false;

  // ────────────────────────── 数据 ──────────────────────────

  /// 与报表页 _aggregate 完全一致的分类 key 口径。
  String _keyOf(Transaction t, Map<String, Category> cats) {
    final Category? cat = (t.categoryId == null || t.categoryId!.isEmpty)
        ? null
        : cats[t.categoryId];
    final Category? top = (widget.byParent && cat?.parentId != null)
        ? cats[cat!.parentId]
        : cat;
    return top?.id ?? (cat?.id ?? '');
  }

  int _netOf(Transaction t) => t.amountMinor - t.discountMinor;

  // ────────────────────────── 构建 ──────────────────────────

  @override
  Widget build(BuildContext context) {
    final List<Transaction> all = ref
        .watch(reportPeriodTransactionsProvider)
        .valueOrNull ?? const <Transaction>[];
    final LedgerAdvancedFilter? filter =
        ref.watch(reportAdvancedFilterProvider);
    final Map<String, Category> cats =
        ref.watch(categoryMapProvider).valueOrNull ?? <String, Category>{};
    final Map<String, Account> accounts = <String, Account>{
      for (final Account a in ref.watch(accountsProvider).valueOrNull ??
          const <Account>[])
        a.id: a,
    };

    // 与报表页同口径：先套高级筛选，再拆分支，再按分类 key 命中。
    final List<Transaction> txns = applyLedgerAdvancedFilter(all, filter, cats);
    final List<Transaction> mine = <Transaction>[
      for (final Transaction t in txns)
        if (_belongsTo(t, cats: cats)) t,
    ];
    final String title = _titleOf(cats);
    final int totalMinor =
        mine.fold<int>(0, (int s, Transaction t) => s + _netOf(t));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(title,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600)),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: '刷新',
            onPressed: () {
              ref.invalidate(reportPeriodTransactionsProvider);
              setState(() {});
            },
          ),
        ],
      ),
      body: mine.isEmpty
          ? const EmptyState(
              icon: Icons.receipt_long_outlined,
              message: '该分类下暂无账单\n（No transactions）',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceLg,
                AppDimens.spaceSm,
                AppDimens.spaceLg,
                AppDimens.spaceXl,
              ),
              children: <Widget>[
                _headerRow(),
                ..._daySections(mine, cats, accounts),
                const SizedBox(height: AppDimens.spaceMd),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '共 ${mine.length} 笔 · 合计 ${Money.fromMinor(totalMinor).format(showSymbol: false)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppPalette.textTertiary),
                  ),
                ),
              ],
            ),
    );
  }

  bool _belongsTo(Transaction t, {required Map<String, Category> cats}) {
    // 分支过滤。
    final bool isOther =
        t.excludeFromStats || t.type == TxnType.transfer;
    final bool inBranch = switch (widget.branch) {
      ReportBranch.expense => !isOther && t.type == TxnType.expense,
      ReportBranch.income => !isOther && t.type == TxnType.income,
      ReportBranch.other => isOther,
    };
    if (!inBranch) return false;
    return _keyOf(t, cats) == widget.categoryKey;
  }

  String _titleOf(Map<String, Category> cats) {
    // 未分类（key 为空）直接用固定名；否则按命中流水的分类名。
    if (widget.categoryKey.isEmpty) return '未分类';
    final Category? cat =
        (widget.byParent && cats[widget.categoryKey]?.parentId != null)
            ? cats[cats[widget.categoryKey]!.parentId]
            : cats[widget.categoryKey];
    return cat?.name ?? '未知分类';
  }

  // ── 头部：账单明细 + 排序切换 ──

  Widget _headerRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: Row(
        children: <Widget>[
          const Text('账单明细',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const Spacer(),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _byAmount = !_byAmount),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppPalette.sage200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _byAmount ? '按金额' : '按时间',
                style: const TextStyle(
                    fontSize: 12, color: AppPalette.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 按日分组区块 ──

  List<Widget> _daySections(
    List<Transaction> mine,
    Map<String, Category> cats,
    Map<String, Account> accounts,
  ) {
    // 以本地日聚合（保持原顺序，组内再按当前排序方式排）。
    final Map<int, List<Transaction>> byDay = <int, List<Transaction>>{};
    for (final Transaction t in mine) {
      final DateTime local = DateTime.fromMillisecondsSinceEpoch(
        t.occurredAt,
        isUtc: true,
      ).toLocal();
      final int day =
          local.year * 10000 + local.month * 100 + local.day;
      (byDay[day] ??= <Transaction>[]).add(t);
    }
    final List<int> days = byDay.keys.toList()..sort((int a, int b) => b - a);

    final List<Widget> out = <Widget>[];
    for (final int day in days) {
      final List<Transaction> list = byDay[day]!;
      list.sort((Transaction a, Transaction b) {
        if (_byAmount) return _netOf(b) - _netOf(a);
        return b.occurredAt - a.occurredAt;
      });
      final int daySum =
          list.fold<int>(0, (int s, Transaction t) => s + _netOf(t));
      out.add(_dayHeader(day, daySum));
      for (final Transaction t in list) {
        out.add(_txnTile(t, cats, accounts));
      }
      out.add(const SizedBox(height: AppDimens.spaceSm));
    }
    return out;
  }

  Widget _dayHeader(int day, int daySum) {
    final DateTime now = DateTime.now();
    final DateTime d = DateTime(day ~/ 10000, (day ~/ 100) % 100, day % 100);
    final int dayDiff =
        DateTime(now.year, now.month, now.day).difference(d).inDays;
    final String suffix =
        dayDiff == 0 ? ' 今天' : dayDiff == 1 ? ' 昨天' : '';
    final String prefix = switch (widget.branch) {
      ReportBranch.expense => '支',
      ReportBranch.income => '收',
      ReportBranch.other => '其他',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Text(
            '${d.month}月${d.day}日$suffix',
            style: const TextStyle(
                fontSize: 13, color: AppPalette.textSecondary),
          ),
          const Spacer(),
          Text(
            '$prefix:${Money.fromMinor(daySum).format(showSymbol: false)}',
            style: const TextStyle(
                fontSize: 13, color: AppPalette.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── 流水行 ──

  Widget _txnTile(
    Transaction t,
    Map<String, Category> cats,
    Map<String, Account> accounts,
  ) {
    final Category? cat = (t.categoryId == null || t.categoryId!.isEmpty)
        ? null
        : cats[t.categoryId];
    final String name = (t.note != null && t.note!.isNotEmpty)
        ? t.note!
        : (cat?.name ?? (t.type == TxnType.transfer ? '内部转账' : '未分类'));
    final DateTime occurred = DateTime.fromMillisecondsSinceEpoch(
      t.occurredAt,
      isUtc: true,
    ).toLocal();
    final String hhmm =
        '${occurred.hour.toString().padLeft(2, '0')}:${occurred.minute.toString().padLeft(2, '0')}';
    final Account? account = accounts[t.accountId];
    final String accountName = account?.name ?? '无';

    final int net = _netOf(t);
    final bool hasDiscount = t.discountMinor > 0;
    final Color amountColor = switch (widget.branch) {
      ReportBranch.expense => AppPalette.expense,
      ReportBranch.income => AppPalette.income,
      ReportBranch.other => AppPalette.textPrimary,
    };
    final String sign = switch (widget.branch) {
      ReportBranch.expense => '-',
      ReportBranch.income => '+',
      ReportBranch.other => '',
    };

    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      onTap: () => TransactionDetailSheet.show(context, t),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppPalette.sageHaze,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(categoryIconData(cat?.iconKey),
                  size: 20, color: AppPalette.sageInk),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 3),
                  Text(hhmm,
                      style: const TextStyle(
                          fontSize: 11, color: AppPalette.textTertiary)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                if (hasDiscount)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '${sign}${Money.fromMinor(t.amountMinor).format(showSymbol: false)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppPalette.textTertiary,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: AppPalette.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        Money.fromMinor(net).format(showSymbol: false),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: amountColor,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    '$sign${Money.fromMinor(net).format(showSymbol: false)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: amountColor,
                    ),
                  ),
                if (hasDiscount)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '优惠${Money.fromMinor(t.discountMinor).format(showSymbol: false)}',
                      style: TextStyle(
                          fontSize: 11, color: AppPalette.expense),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(accountName,
                      style: const TextStyle(
                          fontSize: 11, color: AppPalette.textTertiary)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
