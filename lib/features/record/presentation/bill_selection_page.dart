import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../database/app_database.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/money_text.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../ledger/providers/ledger_providers.dart';

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

  /// 月份选择下拉：全部月份 / 最近 12 个月。
  Widget _buildMonthDropdown() {
    final List<DateTime> months = _generateRecentMonths(12);
    final DateTime? current = _filterMonth;
    final String label = current == null
        ? '全部月份'
        : DateFormat('yyyy年M月').format(current);

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
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(null),
                ),
                const Divider(height: 1),
                ...months.map((DateTime m) {
                  final bool isSelected = current != null &&
                      m.year == current.year &&
                      m.month == current.month;
                  return ListTile(
                    title: Text(DateFormat('yyyy年M月').format(m)),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () => Navigator.of(ctx).pop(m),
                  );
                }),
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

  List<DateTime> _generateRecentMonths(int count) {
    final List<DateTime> result = <DateTime>[];
    final DateTime now = DateTime.now();
    for (int i = 0; i < count; i++) {
      final DateTime m = DateTime(now.year, now.month - i);
      result.add(m);
    }
    return result;
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('筛选功能开发中')),
    );
  }

  /// 底部确认栏：展示已选笔数 / 合计金额，点击确认返回选中列表。
  Widget _buildConfirmFooter(List<Transaction> filtered) {
    final List<Transaction> selected = filtered
        .where((Transaction t) => _selectedIds.contains(t.id))
        .toList(growable: false);
    final int count = selected.length;
    final int totalMinor = selected.fold<int>(
      0,
      (int sum, Transaction t) => sum + t.amountMinor,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceMd,
        AppDimens.spaceLg,
        AppDimens.spaceLg,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '已选 $count 笔',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (count > 0)
                  MoneyText(
                    Money.fromMinor(-totalMinor),
                    signed: true,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.expense,
                        ),
                  ),
              ],
            ),
          ),
          FilledButton(
            onPressed: count == 0 ? null : () => _onConfirm(selected),
            child: Text('确认${count > 0 ? '（$count）' : ''}'),
          ),
        ],
      ),
    );
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

/// 账单列表项：左侧分类图标、标题/时间、右侧金额、最右选择圆圈。
class _BillTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime occurred = DateTime.fromMillisecondsSinceEpoch(
      transaction.occurredAt,
      isUtc: true,
    ).toLocal();

    final String title = category?.name ?? '支出';
    final IconData icon = _iconFor(category);
    final Color tint = _tintFor(category);

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
                    DateFormat('M月d日 HH:mm').format(occurred),
                    style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            MoneyText(
              Money.fromMinor(-transaction.amountMinor),
              signed: true,
              style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.expense,
                  ),
            ),
            const SizedBox(width: AppDimens.spaceMd),
            _SelectionCircle(selected: selected),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(Category? c) {
    final String? key = c?.iconKey;
    if (key != null && key.isNotEmpty) {
      return switch (key) {
        'food' => Icons.restaurant,
        'transport' => Icons.directions_car,
        'shopping' => Icons.shopping_bag,
        'entertainment' => Icons.movie,
        'housing' => Icons.home,
        'medical' => Icons.local_hospital,
        'education' => Icons.school,
        'salary' => Icons.work,
        'transfer' => Icons.swap_horiz,
        _ => Icons.label_outline,
      };
    }
    return Icons.north_east;
  }

  Color _tintFor(Category? c) {
    final int? colorValue = c?.colorValue;
    if (colorValue != null) return Color(colorValue);
    return AppColors.expense;
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
        color: tint.withOpacity(isDark ? 0.18 : 0.12),
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
        color: selected ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.textTertiary,
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
  }
}
