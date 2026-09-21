import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/errors/failures.dart';
import '../../../../database/app_database.dart';
import '../../../../domain/enums.dart';
import '../../../../providers/app_providers.dart';
import '../../../../shared/models/money.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../providers/ledger_providers.dart';

/// 流水详情底部弹窗。
///
/// 从流水列表点击条目弹出：占屏幕高度 50%，顶部圆角，白底。
/// 布局参考小青账：左侧关闭键，右侧「删除 / 退款 / 修改」操作药丸；
/// 下方按「分类 / 账单 / 资产 / 退款账单」分组展示。
class TransactionDetailSheet extends ConsumerWidget {
  const TransactionDetailSheet({super.key, required this.transaction});

  final Transaction transaction;

  static Future<void> show(BuildContext context, Transaction transaction) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionDetailSheet(transaction: transaction),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Map<String, Category> categories =
        ref.watch(categoryMapProvider).valueOrNull ?? <String, Category>{};
    final AsyncValue<List<Account>> accountsAsync = ref.watch(accountsProvider);
    final Book? book = ref.watch(currentBookProvider).valueOrNull;

    final Category? category = categories[transaction.categoryId];
    final Map<String, Account> accounts = <String, Account>{
      for (final Account a in accountsAsync.valueOrNull ?? <Account>[]) a.id: a,
    };
    final Account? account = accounts[transaction.accountId];
    final Account? toAccount = transaction.toAccountId != null
        ? accounts[transaction.toAccountId]
        : null;

    final DateTime occurred = DateTime.fromMillisecondsSinceEpoch(
      transaction.occurredAt,
      isUtc: true,
    ).toLocal();
    final Money money = Money.fromMinor(transaction.amountMinor);

    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusXl),
        ),
      ),
      child: Column(
        children: <Widget>[
          _buildHeader(context, ref),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppDimens.spaceLg),
              children: <Widget>[
                // 分类
                _buildGroup(
                  title: '分类',
                  child: _buildCell(
                    leading: _buildCategoryIcon(category),
                    title: category?.name ?? '未分类',
                  ),
                ),
                const SizedBox(height: AppDimens.spaceLg),

                // 账单：金额、时间、账本
                _buildGroup(
                  title: '账单',
                  child: Column(
                    children: <Widget>[
                      _buildInfoRow(
                        '金额',
                        money.format(),
                        valueColor: _amountColor,
                      ),
                      const Divider(
                        height: 1,
                        indent: AppDimens.spaceMd,
                        color: AppColors.divider,
                      ),
                      _buildInfoRow(
                        '时间',
                        DateFormat('yyyy-MM-dd HH:mm').format(occurred),
                      ),
                      const Divider(
                        height: 1,
                        indent: AppDimens.spaceMd,
                        color: AppColors.divider,
                      ),
                      _buildInfoRow('账本', book?.name ?? '默认账本'),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimens.spaceLg),

                // 资产：账户（转账时含转入账户）
                _buildGroup(
                  title: '资产',
                  child: Column(
                    children: <Widget>[
                      _buildInfoRow(
                        '资产账户',
                        account?.name ?? '未知账户',
                      ),
                      if (toAccount != null) ...<Widget>[
                        const Divider(
                          height: 1,
                          indent: AppDimens.spaceMd,
                          color: AppColors.divider,
                        ),
                        _buildInfoRow(
                          '转入账户',
                          toAccount.name,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppDimens.spaceLg),

                // 退款账单
                if (transaction.type == TxnType.expense)
                  _buildRefundGroup(context, ref, categories),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color get _amountColor {
    return switch (transaction.type) {
      TxnType.income => AppColors.income,
      TxnType.expense => AppColors.expense,
      TxnType.transfer => AppColors.transfer,
    };
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          _ActionPill(
            text: '删除',
            foregroundColor: AppColors.danger,
            borderColor: AppColors.danger,
            onTap: () => _confirmDelete(context, ref),
          ),
          if (transaction.type == TxnType.expense)
            _ActionPill(
              text: '退款',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onTap: () => _onRefund(context, ref),
            ),
          _ActionPill(
            text: '修改',
            backgroundColor: AppColors.textPrimary,
            foregroundColor: Colors.white,
            onTap: () {
              Navigator.of(context).pop();
              context.push('/ledger/edit/${transaction.id}');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(
      {required String title, required Widget child, Widget? titleSuffix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(
            left: AppDimens.spaceMd,
            bottom: AppDimens.spaceSm,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (titleSuffix != null) titleSuffix,
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildCell({
    Widget? leading,
    required String title,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceMd,
      ),
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[
            leading,
            const SizedBox(width: AppDimens.spaceSm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceMd,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 7,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 15,
                color: valueColor ?? AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefundGroup(
    BuildContext context,
    WidgetRef ref,
    Map<String, Category> categories,
  ) {
    final AsyncValue<List<Transaction>> refundsAsync =
        ref.watch(refundsByRelatedIdProvider(transaction.id));

    final Widget titleSuffix = _ActionPill(
      text: '退款',
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      onTap: () => _onRefundByTitle(context, ref),
    );

    return refundsAsync.when(
      data: (List<Transaction> refunds) {
        if (refunds.isEmpty) {
          return _buildGroup(
            title: '退款账单',
            titleSuffix: titleSuffix,
            child: const _EmptyRefundCell(),
          );
        }
        return _buildGroup(
          title: '退款账单',
          titleSuffix: titleSuffix,
          child: Column(
            children:
                refunds.asMap().entries.map((MapEntry<int, Transaction> entry) {
              final Transaction refund = entry.value;
              final Category? refundCategory = categories[refund.categoryId];
              final String label =
                  refund.note != null && refund.note!.isNotEmpty
                      ? refund.note!
                      : (refundCategory?.name ?? '退款');
              return Column(
                children: <Widget>[
                  if (entry.key > 0)
                    const Divider(
                      height: 1,
                      indent: AppDimens.spaceMd,
                      color: AppColors.divider,
                    ),
                  _buildCell(
                    leading: _buildCategoryIcon(refundCategory),
                    title: label,
                    subtitle:
                        '${DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(refund.occurredAt, isUtc: true).toLocal())} · ${Money.fromMinor(refund.amountMinor).format()}',
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
      loading: () => _buildGroup(
        title: '退款账单',
        titleSuffix: titleSuffix,
        child: const Padding(
          padding: EdgeInsets.all(AppDimens.spaceMd),
          child: Center(
            child: SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (Object e, StackTrace? s) => _buildGroup(
        title: '退款账单',
        titleSuffix: titleSuffix,
        child: _buildCell(title: '加载失败：$e'),
      ),
    );
  }

  Widget _buildCategoryIcon(Category? category) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Icon(
        _iconDataFor(category?.iconKey),
        size: 18,
        color: AppColors.primary,
      ),
    );
  }

  IconData _iconDataFor(String? iconKey) {
    return switch (iconKey) {
      'restaurant' => Icons.restaurant,
      'shopping' => Icons.shopping_bag,
      'transport' => Icons.directions_car,
      'entertainment' => Icons.movie,
      'housing' => Icons.home,
      'medical' => Icons.local_hospital,
      'education' => Icons.school,
      'salary' => Icons.work,
      'bonus' => Icons.card_giftcard,
      'investment' => Icons.trending_up,
      'transfer' => Icons.swap_horiz,
      _ => Icons.category,
    };
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('删除流水'),
        content: const Text('删除后账户余额会相应回滚，此操作不可撤销。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(transactionRepositoryProvider).remove(transaction.id);
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已删除')));
      }
    } on AppFailure catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _onRefund(BuildContext context, WidgetRef ref) async {
    // TODO: 打开退款创建页或标记退款。
    // 当前先提示，后续可接入「选择原账单创建退款收入」流程。
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('退款功能将在后续版本接入')),
      );
    }
  }

  Future<void> _onRefundByTitle(BuildContext context, WidgetRef ref) async {
    await _onRefund(context, ref);
  }
}

/// 顶部操作药丸：可配实心背景或描边样式。
class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.text,
    this.backgroundColor,
    required this.foregroundColor,
    this.borderColor,
    this.onTap,
  });

  final String text;
  final Color? backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: borderColor != null ? Border.all(color: borderColor!) : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: foregroundColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _EmptyRefundCell extends StatelessWidget {
  const _EmptyRefundCell();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceMd,
      ),
      child: Center(
        child: Text(
          '无退款账单',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
