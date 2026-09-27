import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/forest_design_tokens.dart';
import '../../../../database/app_database.dart';
import '../../../../domain/enums.dart';
import '../../../../shared/models/money.dart';
import '../../../../shared/widgets/line_icons.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../providers/ledger_providers.dart';
import 'transaction_detail_sheet.dart';
import 'widgets/transaction_tile.dart';

/// 分类账单页 · 对齐参考稿（小青账「分类下全部账单」）。
///
/// 头部：圆形 ✕ 关闭 + 居中标题「分类名(共N笔)」；
/// 账单明细节：右侧「按时间」胶囊；
/// 按天分组：天头「M月d日 今天/星期X」+ 右侧当日「支:x / 收:x / 收支:0」，
/// 行复用 [TransactionTile]（报徽章 / 已报 / 账户名 / 不计收支、预算），
/// 点击行进入流水明细弹窗。
class CategoryTransactionsPage extends ConsumerWidget {
  const CategoryTransactionsPage({required this.categoryId, super.key});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Map<String, Category> categories =
        ref.watch(categoryMapProvider).valueOrNull ?? <String, Category>{};
    final Category? category = categories[categoryId];
    final AsyncValue<List<Transaction>> listAsync =
        ref.watch(categoryTransactionsProvider(categoryId));

    return Scaffold(
      backgroundColor: ForestBg.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildHeader(context, category, listAsync),
            const SizedBox(height: 6),
            _buildSectionBar(context),
            Expanded(
              child: listAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (Object e, StackTrace _) => Center(
                  child: Text('加载失败 $e',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textTertiary)),
                ),
                data: (List<Transaction> list) {
                  if (list.isEmpty) {
                    return const Center(
                      child: Text('该分类下暂无账单',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textTertiary)),
                    );
                  }
                  return _buildDayGroups(context, list);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 头部：✕ + 居中标题 ──────────────────────────────
  Widget _buildHeader(
    BuildContext context,
    Category? category,
    AsyncValue<List<Transaction>> listAsync,
  ) {
    final int count = listAsync.valueOrNull?.length ?? 0;
    final String name = category?.name ?? '分类';
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned(
            left: 14,
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.close,
                    size: 20, color: ForestNeutral.textPrimary),
              ),
            ),
          ),
          Center(
            child: Text(
              '$name(共$count笔)',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ForestNeutral.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 节头：账单明细 + 按时间 ─────────────────────────
  Widget _buildSectionBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
      child: Row(
        children: <Widget>[
          const Text(
            '账单明细',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: ForestNeutral.textPrimary,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: ForestGreen.soft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              '按时间',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ForestGreen.deep,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 按天分组 ────────────────────────────────────────
  Widget _buildDayGroups(BuildContext context, List<Transaction> list) {
    final Map<String, List<Transaction>> groups =
        <String, List<Transaction>>{};
    for (final Transaction t in list) {
      final DateTime day = DateTime.fromMillisecondsSinceEpoch(
        t.occurredAt,
        isUtc: true,
      ).toLocal();
      final String key = DateFormat('yyyy-MM-dd').format(day);
      groups.putIfAbsent(key, () => <Transaction>[]).add(t);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 24),
      itemCount: groups.length,
      itemBuilder: (BuildContext context, int index) {
        final String key = groups.keys.elementAt(index);
        final List<Transaction> items = groups[key]!;
        return _DayGroup(
          day: DateFormat('yyyy-MM-dd').parse(key),
          items: items,
        );
      },
    );
  }
}

/// 单日分组：天头（日期 + 今天/星期X + 小圆环）+ 当日收支合计 + 账单行。
class _DayGroup extends StatelessWidget {
  const _DayGroup({required this.day, required this.items});

  final DateTime day;
  final List<Transaction> items;

  static const List<String> _weekLabels = <String>[
    '星期一',
    '星期二',
    '星期三',
    '星期四',
    '星期五',
    '星期六',
    '星期日',
  ];

  String get _dayLabel {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime target = DateTime(day.year, day.month, day.day);
    final int diff = today.difference(target).inDays;
    if (diff == 0) return 'M月d日 今天'.replaceFirst('M月d日', _md);
    if (diff == 1) return 'M月d日 昨天'.replaceFirst('M月d日', _md);
    return '$_md ${_weekLabels[day.weekday - 1]}';
  }

  String get _md => DateFormat('M月d日').format(day);

  String get _totalLabel {
    int expense = 0;
    int income = 0;
    for (final Transaction t in items) {
      if (t.type == TxnType.expense) {
        expense += t.amountMinor;
      } else if (t.type == TxnType.income) {
        income += t.amountMinor;
      }
    }
    if (expense > 0 && income > 0) {
      return '支:${Money.fromMinor(expense).format()} '
          '收:${Money.fromMinor(income).format()}';
    }
    if (expense > 0) return '支:${Money.fromMinor(expense).format()}';
    if (income > 0) return '收:${Money.fromMinor(income).format()}';
    return '收支:0';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
            child: Row(
              children: <Widget>[
                Text(
                  _dayLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ForestNeutral.textPrimary,
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.autorenew,
                    size: 14, color: ForestGreen.deep),
                const Spacer(),
                Text(
                  _totalLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < items.length; i++) ...<Widget>[
                  if (i > 0)
                    Container(
                      height: 0.6,
                      margin: const EdgeInsets.only(left: 52),
                      color: AppColors.divider,
                    ),
                  TransactionTile(
                    transaction: items[i],
                    onTap: () =>
                        TransactionDetailSheet.show(context, items[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
