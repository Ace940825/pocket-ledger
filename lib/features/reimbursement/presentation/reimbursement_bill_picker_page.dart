import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/forest_design_tokens.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/category_icons.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../ledger/providers/ledger_providers.dart';
import '../data/reimbursement_repository.dart';
import '../providers/reimbursement_providers.dart';

/// 「选择账单」独立页参数：报销账户 ID + 已勾选集合。
class ReimbBillPickerArgs {
  const ReimbBillPickerArgs({
    required this.accountId,
    this.initialSelected = const <String>{},
  });

  final String accountId;
  final Set<String> initialSelected;
}

/// 报销 · 从历史账单选择（独立整页，替代原底部弹层）。
///
/// 头部：返回 + 居中标题「选择账单」+「全选 / 取消全选」（AppBar actions，
/// 与标题同层不重叠）；列表分「分支账单 / 未选取报销账户」两组；底部渐变
/// 「确认」胶囊，pop 返回 Set<String>（选中流水 ID）。
class ReimbursementBillPickerPage extends ConsumerStatefulWidget {
  const ReimbursementBillPickerPage({super.key, required this.args});

  final ReimbBillPickerArgs args;

  @override
  ConsumerState<ReimbursementBillPickerPage> createState() =>
      _ReimbursementBillPickerPageState();
}

class _ReimbursementBillPickerPageState
    extends ConsumerState<ReimbursementBillPickerPage> {
  late final Set<String> _selected =
      Set<String>.from(widget.args.initialSelected);

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _toggleAll(List<Transaction> all) {
    setState(() {
      final bool allSelected = all.isNotEmpty &&
          all.every((Transaction t) => _selected.contains(t.id));
      if (allSelected) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(all.map((Transaction t) => t.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Transaction>> av =
        ref.watch(recentTransactionsProvider);
    final Map<String, Category> categories =
        ref.watch(categoryMapProvider).valueOrNull ?? <String, Category>{};
    final List<Account> accounts =
        ref.watch(accountsProvider).valueOrNull ?? const <Account>[];
    String branchName = '报销账户';
    for (final Account a in accounts) {
      if (a.id == widget.args.accountId) {
        branchName = a.name;
        break;
      }
    }

    return Scaffold(
      backgroundColor: ForestBg.paper,
      appBar: AppBar(
        backgroundColor: ForestBg.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: ForestNeutral.textPrimary),
        title: const Text(
          '选择账单',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: ForestNeutral.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: <Widget>[
          av.maybeWhen(
            data: (List<Transaction> list) {
              final (List<Transaction> branch, List<Transaction> loose) =
                  _split(list);
              final List<Transaction> all = <Transaction>[...branch, ...loose];
              final bool allSelected = all.isNotEmpty &&
                  all.every((Transaction t) => _selected.contains(t.id));
              return Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Center(
                  child: GestureDetector(
                    onTap: () => _toggleAll(all),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: ForestGreen.soft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        allSelected ? '取消全选' : '全选',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: ForestGreen.deep,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: av.when(
        data: (List<Transaction> list) {
          final (List<Transaction> branch, List<Transaction> loose) =
              _split(list);
          if (branch.isEmpty && loose.isEmpty) {
            return const Center(
              child: Text(
                '暂无可提取的报销账单',
                style: TextStyle(color: ForestNeutral.textTertiary),
              ),
            );
          }
          // 每笔账单的累计已报（台账合计，旧数据按收入流水兜底）。
          final Map<String, int> receivedMap =
              _receivedMap();
          return Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  children: <Widget>[
                    if (branch.isNotEmpty) ...<Widget>[
                      _sectionHeader('$branchName · 分支账单', branch.length),
                      for (final Transaction t in branch)
                        _row(t, categories, receivedMap[t.id] ?? 0),
                    ],
                    if (loose.isNotEmpty) ...<Widget>[
                      _sectionHeader('未选取报销账户', loose.length),
                      for (final Transaction t in loose)
                        _row(t, categories, receivedMap[t.id] ?? 0),
                    ],
                  ],
                ),
              ),
              _confirmFooter(),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: _SageGreen.b),
        ),
        error: (Object e, _) => Center(child: Text('加载失败：$e')),
      ),
    );
  }

  /// 可提取账单两组：分支账单（指向当前报销账户）/ 未选取报销账户。
  /// 已全额报销的账单屏蔽，与保存路径「已报销跳过抵扣」同口径。
  (List<Transaction>, List<Transaction>) _split(List<Transaction> list) {
    final List<Reimbursement> records =
        ref.watch(reimbursementListProvider).valueOrNull ??
            const <Reimbursement>[];
    final Set<String> reimbursedBillIds = <String>{
      for (final Reimbursement r in records)
        if (r.status == ReimbursementStatus.reimbursed &&
            r.transactionId != null)
          r.transactionId!,
    };
    final List<Transaction> branch = <Transaction>[];
    final List<Transaction> loose = <Transaction>[];
    for (final Transaction t in list) {
      if (t.type != TxnType.expense || !t.isReimbursable) continue;
      if (reimbursedBillIds.contains(t.id)) continue;
      if (t.reimbursementAccountId == widget.args.accountId) {
        branch.add(t);
      } else if (t.reimbursementAccountId == null) {
        loose.add(t);
      }
    }
    return (branch, loose);
  }

  Map<String, int> _receivedMap() {
    final List<Reimbursement> records =
        ref.watch(reimbursementListProvider).valueOrNull ??
            const <Reimbursement>[];
    final Map<String, int> map = <String, int>{};
    for (final Reimbursement r in records) {
      if (r.transactionId == null) continue;
      final List<ReimbAllocEntry> allocs = parseReimbAllocs(r.incomeAllocs);
      int amt = allocs.fold<int>(
          0, (int s, ReimbAllocEntry e) => s + e.allocMinor);
      if (amt == 0 && r.incomeTransactionId != null) {
        amt = ref
                .watch(transactionDetailProvider(r.incomeTransactionId!))
                .valueOrNull
                ?.amountMinor ??
            0;
      }
      map[r.transactionId!] = (map[r.transactionId!] ?? 0) + amt;
    }
    return map;
  }

  Widget _sectionHeader(String title, int count) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Row(
          children: <Widget>[
            Container(
              width: 3,
              height: 12,
              decoration: BoxDecoration(
                color: ForestGreen.deep,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ForestNeutral.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count 笔',
              style: const TextStyle(
                fontSize: 12,
                color: ForestNeutral.textTertiary,
              ),
            ),
          ],
        ),
      );

  Widget _row(Transaction t, Map<String, Category> categories, int received) {
    final bool sel = _selected.contains(t.id);
    final Category? cat = categories[t.categoryId];
    final Color tint = cat?.colorValue != null
        ? Color(cat!.colorValue!)
        : ForestGreen.deep;
    final IconData icon = cat?.iconKey != null && cat!.iconKey!.isNotEmpty
        ? categoryIconData(cat.iconKey)
        : Icons.north_east;
    final String title =
        cat?.name ?? (t.note?.isNotEmpty == true ? t.note! : '支出');
    final DateTime occurred = DateTime.fromMillisecondsSinceEpoch(
      t.occurredAt,
      isUtc: true,
    ).toLocal();
    final List<String> excludeLabels = <String>[
      if (t.excludeFromStats) '不计收支',
      if (t.excludeFromBudget) '不计预算',
    ];

    return InkWell(
      onTap: () => _toggle(t.id),
      child: Container(
        color: ForestSurface.card,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: ForestNeutral.hairline)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: tint, size: 22),
            ),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: ForestNeutral.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: ForestGreen.soft,
                          border: Border.all(color: ForestGreen.softBorder),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '报',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: ForestGreen.deep,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('y年M月d日').format(occurred),
                    style: const TextStyle(
                        fontSize: 12, color: ForestNeutral.textTertiary),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    DateFormat('HH:mm').format(occurred),
                    style: const TextStyle(
                        fontSize: 12, color: ForestNeutral.textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  Money.fromMinor(t.amountMinor).format(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ForestNeutral.textPrimary,
                  ),
                ),
                if (received > 0) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    '已报 ${Money.fromMinor(received).format()}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.expense,
                    ),
                  ),
                ],
                if (excludeLabels.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    excludeLabels.join('、'),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.expense,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 10),
            _pickCircle(sel),
          ],
        ),
      ),
    );
  }

  Widget _pickCircle(bool sel) => Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: sel ? Colors.transparent : const Color(0xFFD8CDB4),
            width: 1.5,
          ),
          gradient: sel
              ? const LinearGradient(
                  colors: <Color>[_SageGreen.a, _SageGreen.b],
                )
              : null,
        ),
        child: sel
            ? const Icon(Icons.check, size: 13, color: Colors.white)
            : null,
      );

  Widget _confirmFooter() {
    final int count = _selected.length;
    return Container(
      decoration: const BoxDecoration(
        color: ForestSurface.card,
        border: Border(top: BorderSide(color: ForestNeutral.hairline)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[_SageGreen.a, _SageGreen.b],
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(Set<String>.from(_selected)),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: Text(
              count == 0 ? '确认' : '确认 · 已选 $count 笔',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 鼠尾草渐变停靠色（与 ForestGradients.sage 同值，页面内取用方便）。
abstract final class _SageGreen {
  static const Color a = Color(0xFF93BF9A);
  static const Color b = Color(0xFF5F9A6E);
}
