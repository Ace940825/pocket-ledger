import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../database/app_database.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/category_icons.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../ledger/providers/ledger_providers.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/calendar_sheet.dart';

/// 账单选择页面返回的结果：用户确认后返回选中的流水列表。
///
/// 设计为返回原始 [Transaction] 列表，调用方自行决定如何「合并为一条」：
/// - 单选：直接使用该条流水作为关联对象。
/// - 多选：将金额求和、把 ID 列表写入备注或关联字段，生成一条合并记录。
class BillSelectionPage extends ConsumerStatefulWidget {
  const BillSelectionPage({
    super.key,
    this.bookId,
    this.initialSelectedIds = const <String>[],
    this.multiSelect = false,
    this.title = '选择账单',
  });

  /// 当前账本 ID；为空时页面展示空状态。
  final String? bookId;

  /// 进入页面时已经选中的账单 ID（用于编辑场景回显）。
  final List<String> initialSelectedIds;

  /// 是否允许多选。
  /// - false：单选，点击行即确认并返回一条。
  /// - true：多选，需要点击底部「确认」按钮返回列表。
  final bool multiSelect;

  /// 页面标题。
  final String title;

  @override
  ConsumerState<BillSelectionPage> createState() => _BillSelectionPageState();
}

class _BillSelectionPageState extends ConsumerState<BillSelectionPage> {
  /// 当前选中的账单 ID。
  final Set<String> _selectedIds = <String>{};

  /// 当前月份筛选：null 表示「全部月份」。
  DateTime? _filterMonth;

  @override
  void initState() {
    super.initState();
    _selectedIds.addAll(widget.initialSelectedIds);
    // 默认筛选当前月份，与小青账截图一致。
    final DateTime now = DateTime.now();
    _filterMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Transaction>> asyncTxns =
        ref.watch(bookExpenseTransactionsProvider);
    final Map<String, Category> categories =
        ref.watch(categoryMapProvider).valueOrNull ?? <String, Category>{};

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: _clearSelection,
            child: const Text('清空'),
          ),
        ],
      ),
      body: SafeArea(
        child: asyncTxns.when(
          data: (List<Transaction> list) {
            final List<Transaction> filtered = _applyMonthFilter(list);
            return Column(
              children: <Widget>[
                _buildFilterBar(filtered),
                const Divider(height: 1),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('暂无账单'))
                      : ListView.separated(
                          padding: const EdgeInsets.only(
                            bottom: AppDimens.spaceLg,
                          ),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            indent: AppDimens.spaceLg + 40 + AppDimens.spaceMd,
                          ),
                          itemBuilder: (BuildContext ctx, int index) {
                            final Transaction t = filtered[index];
                            return _BillTile(
                              transaction: t,
                              category: categories[t.categoryId],
                              selected: _selectedIds.contains(t.id),
                              onToggle: () => _onToggle(t),
                            );
                          },
                        ),
                ),
                _buildConfirmFooter(filtered),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, _) => Center(child: Text('账单加载失败：$e')),
        ),
      ),
    );
  }

  /// 顶部筛选栏：月份下拉 + 筛选按钮（预留）。
  Widget _buildFilterBar(List<Transaction> filtered) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceLg,
        vertical: AppDimens.spaceSm,
      ),
      child: Row(
        children: <Widget>[
          _buildMonthDropdown(),
          const Spacer(),
          TextButton.icon(
            onPressed: _showFilterHint,
            icon: const Icon(Icons.filter_list, size: 18),
            label: const Text('筛选'),
          ),
        ],
      ),
    );
  }

  /// 月份选择下拉：全部月份 / 具体月份（经 [CalendarSheet]）。
  Widget _buildMonthDropdown() {
    final DateTime? current = _filterMonth;
    final String label =
        current == null ? '全部月份' : DateFormat('yyyy年M月').format(current);

    return InkWell(
      onTap: () async {
        final DateTime? picked = await showModalBottomSheet<DateTime>(
          context: context,
          builder: (BuildContext ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  title: const Text('全部月份'),
                  trailing: current == null
                      ? const Icon(Icons.check, color: AppPalette.primary)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(null),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('选择具体月份'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final CalendarSelection? sel = await CalendarSheet.show(
                      ctx,
                      mode: CalendarSheetMode.month,
                      initialMonth:
                          _filterMonth ?? DateTime.now(),
                    );
                    if (sel is CalendarMonth) {
                      Navigator.of(ctx).pop(DateTime(sel.year, sel.month));
                    }
                  },
                ),
              ],
            ),
          ),
        );
        if (picked != _filterMonth) {
          setState(() => _filterMonth = picked);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }

  List<Transaction> _applyMonthFilter(List<Transaction> list) {
    if (_filterMonth == null) return list;
    final DateTime start = DateTime(_filterMonth!.year, _filterMonth!.month);
    final DateTime end = DateTime(_filterMonth!.year, _filterMonth!.month + 1);
    final int startMs = start.toUtc().millisecondsSinceEpoch;
    final int endMs = end.toUtc().millisecondsSinceEpoch;
    return list.where((Transaction t) {
      return t.occurredAt >= startMs && t.occurredAt < endMs;
    }).toList(growable: false);
  }

  void _onToggle(Transaction t) {
    setState(() {
      if (!_selectedIds.add(t.id)) {
        _selectedIds.remove(t.id);
      }
    });
  }

  void _clearSelection() {
    if (_selectedIds.isEmpty) return;
    setState(() => _selectedIds.clear());
  }

  void _showFilterHint() {
    showAppToast(context, '筛选功能开发中');
  }

  /// 底部确认栏（对齐小青账）：全宽浅绿渐变「确认」按钮，
  /// 未选中时置灰；按钮文案带已选笔数。
  Widget _buildConfirmFooter(List<Transaction> filtered) {
    final int count =
        filtered.where((Transaction t) => _selectedIds.contains(t.id)).length;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceMd,
        AppDimens.spaceLg,
        AppDimens.spaceLg + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      child: SizedBox(
        height: 48,
        child: FilledButton(
          onPressed: count == 0 ? null : () => _onConfirmFrom(filtered),
          style: FilledButton.styleFrom(
            backgroundColor: count == 0
                ? AppPalette.primary.withValues(alpha: 0.35)
                : AppPalette.primary,
            foregroundColor: AppPalette.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          child: Text(
            count == 0 ? '确认' : '确认（$count）',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  void _onConfirmFrom(List<Transaction> filtered) {
    final List<Transaction> selected = filtered
        .where((Transaction t) => _selectedIds.contains(t.id))
        .toList(growable: false);
    _onConfirm(selected);
  }

  void _onConfirm(List<Transaction> selected) {
    if (!widget.multiSelect) {
      // 单选模式：只返回第一条。
      Navigator.of(context).pop(<Transaction>[selected.first]);
      return;
    }
    Navigator.of(context).pop(selected);
  }
}

/// 账单列表项（对齐小青账）：左侧分类图标、标题(备注)、日期/时间两行，
/// 右侧金额（优惠账单=划线原价+红色实付+「优惠X」小字）+「退款 ¥X=¥Y」
/// 标注，最右选择圆圈。
class _BillTile extends ConsumerWidget {
  const _BillTile({
    required this.transaction,
    this.category,
    required this.selected,
    required this.onToggle,
  });

  final Transaction transaction;
  final Category? category;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final DateTime occurred = DateTime.fromMillisecondsSinceEpoch(
      transaction.occurredAt,
      isUtc: true,
    ).toLocal();

    // 标题：分类名（备注非空时「分类 - 备注」，对齐小青账「餐饮 - 三餐」）。
    final String note = transaction.note ?? '';
    final String title = note.isNotEmpty
        ? '${category?.name ?? '支出'} - $note'
        : (category?.name ?? '支出');
    final IconData icon = categoryIconData(category?.iconKey);
    final Color tint = category?.colorValue != null
        ? Color(category!.colorValue!)
        : AppPalette.expense;

    // 退款标注：被退款过的原账单显示「退款 ¥X=¥Y」
    // （X=累计已退合计，Y=剩余=实付−已退，与流水列表同口径）。
    final List<Transaction> refunds = ref
            .watch(refundsByRelatedIdProvider(transaction.id))
            .valueOrNull ??
        const <Transaction>[];
    final int refundedMinor =
        refunds.fold<int>(0, (int s, Transaction r) => s + r.amountMinor);
    final int paidMinor = transaction.amountMinor - transaction.discountMinor;

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceLg,
          vertical: AppDimens.spaceMd,
        ),
        child: Row(
          children: <Widget>[
            _CircleIcon(icon: icon, tint: tint),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('M月d日').format(occurred),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppPalette.textSecondary,
                    ),
                  ),
                  Text(
                    DateFormat('HH:mm').format(occurred),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppPalette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (transaction.discountMinor > 0) ...<Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Text(
                        '-${Money.fromMinor(transaction.amountMinor).format()}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppPalette.textTertiary,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: AppPalette.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        Money.fromMinor(paidMinor).format(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppPalette.expense,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '优惠${Money.fromMinor(transaction.discountMinor).format()}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppPalette.expense,
                    ),
                  ),
                ] else
                  Text(
                    '-${Money.fromMinor(transaction.amountMinor).format()}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppPalette.expense,
                    ),
                  ),
                if (refundedMinor > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '退款 ${Money.fromMinor(refundedMinor).format()}'
                      '=${Money.fromMinor(
                        (paidMinor - refundedMinor).clamp(0, paidMinor),
                      ).format()}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppPalette.expense,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppDimens.spaceMd),
            _SelectionCircle(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon, required this.tint});

  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: isDark ? 0.18 : 0.12),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 20, color: tint),
    );
  }
}

class _SelectionCircle extends StatelessWidget {
  const _SelectionCircle({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppPalette.primary : Colors.transparent,
        border: Border.all(
          color: selected ? AppPalette.primary : AppPalette.textTertiary,
          width: 1.5,
        ),
      ),
      child: selected
          ? Icon(Icons.check, size: 14, color: Theme.of(context).colorScheme.onPrimary)
          : null,
    );
  }
}
