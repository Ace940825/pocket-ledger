import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_dimens.dart';
import '../../../core/theme/forest_design_tokens.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/line_icons.dart';
import '../../../theme/app_colors.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../providers/ledger_providers.dart';
import 'transaction_detail_sheet.dart';
import 'widgets/txn_icon.dart';

/// 「账单列表」页（我的 → 账单管理 → 账单列表，小青账布局）。
///
/// 跨全部周期的账单明细平铺列表（不按日分组，每行自带日期/时间），
/// 右上角胶囊显示当前排序规则，点击弹「选取排序规则」底部弹窗：
/// 按时间 / 按创建时间 / 按更新时间 / 按金额。
/// 选「按创建时间」时顶部出现提示条（辅助查询记错日期的账单）。
class BillListPage extends ConsumerStatefulWidget {
  const BillListPage({super.key});

  @override
  ConsumerState<BillListPage> createState() => _BillListPageState();
}

/// 排序规则。
enum _SortMode {
  time('按时间'),
  createdAt('按创建时间'),
  updatedAt('按更新时间'),
  amount('按金额');

  const _SortMode(this.label);
  final String label;
}

class _BillListPageState extends ConsumerState<BillListPage> {
  _SortMode _sort = _SortMode.time;

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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 顶部：X 圆钮（浅灰底）关闭页面。
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppPalette.neutralSoft,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 20,
                    color: AppPalette.textSecondary,
                  ),
                ),
              ),
            ),
            // 「按创建时间」提示条（仅该排序下显示）。
            if (_sort == _SortMode.createdAt)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _TipBanner(),
              ),
            Expanded(
              child: txnsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (Object e, StackTrace? s) =>
                    Center(child: Text('加载失败：$e')),
                data: (List<Transaction> all) {
                  final List<Transaction> list = _sorted(all);
                  if (list.isEmpty) {
                    return ListView(
                      padding: EdgeInsets.zero,
                      children: <Widget>[
                        _detailHeader(0),
                        const Padding(
                          padding: EdgeInsets.only(top: 72),
                          child: EmptyState(message: '暂无账单'),
                        ),
                      ],
                    );
                  }
                  return ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: list.length + 1,
                    itemBuilder: (BuildContext context, int index) {
                      if (index == 0) {
                        return _detailHeader(list.length);
                      }
                      return _BillTile(
                        txn: list[index - 1],
                        category: categories[list[index - 1].categoryId],
                        account: accounts[list[index - 1].accountId],
                        toAccount: accounts[list[index - 1].toAccountId],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────── 排序 ──────────────────────────

  List<Transaction> _sorted(List<Transaction> all) {
    final List<Transaction> list = List<Transaction>.of(all);
    switch (_sort) {
      case _SortMode.time:
        // 发生时间倒序（watchAll 已按此排序，稳妥起见再排一次）。
        list.sort((Transaction a, Transaction b) =>
            b.occurredAt - a.occurredAt);
      case _SortMode.createdAt:
        // 创建时间倒序：流水 ID 为 UUIDv7（时间有序），字典序即创建顺序，
        // 无需加 createdAt 列即可精确还原录入先后。
        list.sort((Transaction a, Transaction b) => b.id.compareTo(a.id));
      case _SortMode.updatedAt:
        list.sort((Transaction a, Transaction b) {
          final int byTime = b.updatedAt - a.updatedAt;
          if (byTime != 0) return byTime;
          return b.occurredAt - a.occurredAt;
        });
      case _SortMode.amount:
        // 按金额（实付口径 amount − discount）降序；并列按发生时间倒序。
        list.sort((Transaction a, Transaction b) {
          final int am = a.amountMinor - a.discountMinor;
          final int bm = b.amountMinor - b.discountMinor;
          if (am != bm) return bm - am;
          return b.occurredAt - a.occurredAt;
        });
    }
    return list;
  }

  Future<void> _pickSort() async {
    final _SortMode? picked = await showModalBottomSheet<_SortMode>(
      context: context,
      backgroundColor: AppPalette.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) => _SortSheet(current: _sort),
    );
    if (picked != null) {
      setState(() => _sort = picked);
    }
  }

  // ────────────────────────── 头部 ──────────────────────────

  Widget _detailHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Row(
        children: <Widget>[
          Text(
            '账单明细(共$count笔)',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppPalette.textPrimary,
            ),
          ),
          const Spacer(),
          // 排序规则胶囊（浅绿底 + 深绿字），点击弹排序弹窗。
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: _pickSort,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: ForestGreen.soft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _sort.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ForestGreen.deep,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────── 提示条 ──────────────────────────

/// 「提示」卡：绿色竖条 + 标题 + ⓘ 说明文案（按创建时间排序时显示）。
class _TipBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppPalette.neutralSoft.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
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
          const SizedBox(height: 6),
          const Text(
            '按创建时间查询，可辅助查询到近期记账但记错日期的账单，'
            '如今天记账不小心选择了上年日期。',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: AppPalette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────── 排序弹窗 ──────────────────────────

/// 「选取排序规则」底部弹窗：X 圆钮 + 居中标题 + 四行规则（当前项绿色高亮）。
class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.current});

  final _SortMode current;

  static const List<_SortMode> _options = <_SortMode>[
    _SortMode.time,
    _SortMode.createdAt,
    _SortMode.updatedAt,
    _SortMode.amount,
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // 头部：X 圆钮 + 居中标题。
            SizedBox(
              height: 32,
              child: Stack(
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppPalette.neutralSoft,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: AppPalette.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const Align(
                    alignment: Alignment.center,
                    child: Text(
                      '选取排序规则',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < _options.length; i++) ...<Widget>[
              if (i > 0)
                const Divider(height: 1, color: AppPalette.divider),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.of(context).pop(_options[i]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 17,
                  ),
                  child: Row(
                    children: <Widget>[
                      Text(
                        _options[i].label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: _options[i] == current
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: _options[i] == current
                              ? ForestGreen.deep
                              : AppPalette.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.chevron_right,
                        size: 22,
                        color: AppPalette.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ────────────────────────── 账单行 ──────────────────────────

/// 账单行（小青账布局）：左图标，中「标题+标签 / 日期 / 时间」三行，
/// 右「金额（优惠划线）/ 优惠 / 账户」。平铺不按日分组，日期时间自带。
class _BillTile extends StatelessWidget {
  const _BillTile({
    required this.txn,
    required this.category,
    required this.account,
    required this.toAccount,
  });

  final Transaction txn;
  final Category? category;
  final Account? account;
  final Account? toAccount;

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
        onTap: () => TransactionDetailSheet.show(context, txn),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
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
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
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
              _amountColumn(context),
            ],
          ),
        ),
      ),
    );
  }

  // ── 左侧图标：线稿优先，退回分类色 Material 图标 / 类型兜底 ──

  Widget _icon(BuildContext context) {
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

  // ── 右侧金额区 ──

  Widget _amountColumn(BuildContext context) {
    final bool isExpense = txn.type == TxnType.expense;
    final bool hasDiscount = isExpense && txn.discountMinor > 0;
    final String accountLabel = _accountLabel();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (hasDiscount)
          // 优惠支出：划线原价 + 红色实付（对齐小青账「—¥8.00 5.00」）。
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
                Money.fromMinor(txn.amountMinor - txn.discountMinor).format(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.expense,
                ),
              ),
            ],
          )
        else if (txn.type == TxnType.transfer)
          Text(
            Money.fromMinor(txn.amountMinor).format(),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppPalette.textPrimary,
            ),
          )
        else
          Text(
            switch (txn.type) {
              TxnType.income => '+${Money.fromMinor(txn.amountMinor).format()}',
              TxnType.expense => '−${Money.fromMinor(txn.amountMinor).format()}',
              TxnType.transfer => Money.fromMinor(txn.amountMinor).format(),
            },
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: txn.type == TxnType.income
                  ? AppPalette.income
                  : AppPalette.expense,
            ),
          ),
        if (hasDiscount)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '优惠${Money.fromMinor(txn.discountMinor).format()}',
              style: const TextStyle(
                fontSize: 11,
                color: AppPalette.expense,
              ),
            ),
          ),
        if (accountLabel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              accountLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppPalette.textTertiary,
              ),
            ),
          ),
      ],
    );
  }

  String _accountLabel() {
    if (txn.type == TxnType.transfer) {
      final String from = account?.name ?? '转出';
      final String to = toAccount?.name ?? '转入';
      return '$from → $to';
    }
    return account?.name ?? '';
  }
}

/// 「优惠X.XX」红色小字（划线原价下方）。

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
