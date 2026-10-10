import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/failures.dart';
import '../../../core/theme/forest_design_tokens.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../routing/app_router.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/line_icons.dart';
import '../../../theme/theme.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../record/presentation/record_sheet.dart';
import '../../record/record_tab.dart';
import '../providers/lend_providers.dart';

/// 借还页：对照报销页总览——每个借出 / 借入账户一张存钱计划样式卡片。
///
/// 行1：头像 ｜ 绿竖条 + 账户名 + 「编辑」胶囊；行2：大字未结清金额
/// （账户余额不变量 = 名下未结清合计）+「待收回 / 待归还」小标；
/// 行3：进行中 / 已结清状态胶囊 + 进入箭头。
/// 未指定账户的记录落在页尾「未指定账户的记录」平铺区，不丢数据。
class LendPage extends ConsumerStatefulWidget {
  const LendPage({super.key});

  @override
  ConsumerState<LendPage> createState() => _LendPageState();
}

class _LendPageState extends ConsumerState<LendPage> {
  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Account> accountList =
        ref.watch(accountsProvider).valueOrNull ?? const <Account>[];
    final List<LendRecord> records =
        ref.watch(lendListProvider).valueOrNull ?? const <LendRecord>[];

    final List<Account> lendOutAccounts = accountList
        .where((Account a) => !a.deleted && a.type == AccountType.lend)
        .toList(growable: false);
    final List<Account> borrowInAccounts = accountList
        .where((Account a) => !a.deleted && a.type == AccountType.borrow)
        .toList(growable: false);

    // 按账户聚合状态笔数（大字金额直接用账户余额不变量，口径与账户页一致）。
    final Map<String, int> ongoingCnt = <String, int>{};
    final Map<String, int> settledCnt = <String, int>{};
    for (final LendRecord r in records) {
      final String? aid = r.accountId;
      if (aid == null || aid.isEmpty) continue;
      if (r.status == LendStatus.ongoing) {
        ongoingCnt[aid] = (ongoingCnt[aid] ?? 0) + 1;
      } else {
        // 已结清与已核销都算「已结清」口径。
        settledCnt[aid] = (settledCnt[aid] ?? 0) + 1;
      }
    }

    // 未指定借还账户的记录：平铺列出，避免无处可见。
    final List<LendRecord> unassigned = records
        .where((LendRecord r) => r.accountId == null || r.accountId!.isEmpty)
        .toList(growable: false);

    final bool pageEmpty = lendOutAccounts.isEmpty &&
        borrowInAccounts.isEmpty &&
        unassigned.isEmpty;

    return Scaffold(
      backgroundColor:
          isDark ? Theme.of(context).colorScheme.surface : ForestBg.paper,
      appBar: AppBar(
        backgroundColor:
            isDark ? Theme.of(context).colorScheme.surface : ForestBg.paper,
        foregroundColor:
            isDark ? ForestNeutral.textPrimary : ForestNeutral.deepInk,
        elevation: 0,
        centerTitle: true,
        title: const Text('借还'),
      ),
      body: pageEmpty
          ? const _NoLendEmpty()
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: <Widget>[
                if (lendOutAccounts.isNotEmpty) ...<Widget>[
                  const SectionHeader(title: '借出账户'),
                  for (final Account a in lendOutAccounts)
                    _LendAccountCard(
                      account: a,
                      isLendOut: true,
                      ongoingCount: ongoingCnt[a.id] ?? 0,
                      settledCount: settledCnt[a.id] ?? 0,
                      isDark: isDark,
                      onTap: () => context.push('/accounts/${a.id}/transactions'),
                      onEdit: () => context.push('/accounts/${a.id}/edit'),
                    ),
                ],
                if (borrowInAccounts.isNotEmpty) ...<Widget>[
                  const SectionHeader(title: '借入账户'),
                  for (final Account a in borrowInAccounts)
                    _LendAccountCard(
                      account: a,
                      isLendOut: false,
                      ongoingCount: ongoingCnt[a.id] ?? 0,
                      settledCount: settledCnt[a.id] ?? 0,
                      isDark: isDark,
                      onTap: () => context.push('/accounts/${a.id}/transactions'),
                      onEdit: () => context.push('/accounts/${a.id}/edit'),
                    ),
                ],
                if (unassigned.isNotEmpty) ...<Widget>[
                  const SectionHeader(title: '未指定账户的记录'),
                  for (final LendRecord r in unassigned)
                    _UnassignedTile(
                      record: r,
                      onDelete: () => _confirmDelete(context, ref, r),
                      onTap: () => openRecordSheet(context, editLendId: r.id),
                    ),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openRecordSheet(context, initialTab: RecordTab.lend),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    LendRecord record,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('删除这条借还记录？'),
        content: const Text('删除后不可撤销。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(lendRepositoryProvider).remove(record.id);
    } on AppFailure catch (e) {
      if (context.mounted) showAppToast(context, e.message);
    }
  }
}

// ── 分区头（报销页同款绿竖条） ─────────────────────────────

// ── 借还账户卡（报销页 _ReimbAccountCard 同款布局） ─────────

/// 行1：头像 ｜ 绿竖条 + 账户名 + 「编辑」胶囊；行2：大字未结清金额
/// （账户余额不变量）+「待收回 / 待归还」小标；行3：状态胶囊 + 进入箭头。
class _LendAccountCard extends StatelessWidget {
  const _LendAccountCard({
    required this.account,
    required this.isLendOut,
    required this.ongoingCount,
    required this.settledCount,
    required this.isDark,
    required this.onTap,
    required this.onEdit,
  });

  final Account account;
  final bool isLendOut;
  final int ongoingCount;
  final int settledCount;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // 行1：头像 ｜ 绿竖条 + 账户名 + 编辑胶囊（图标与名称并排）。
              Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark
                          ? ForestGreen.deep.withValues(alpha: 0.22)
                          : ForestGreen.soft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: LineIcon(
                      LineIconKind.lend,
                      size: 20,
                      color: isDark ? ForestGreen.brand : ForestGreen.deep,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 4,
                          height: 14,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                AppPalette.sageMist,
                                AppPalette.sageRibbon,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            account.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onEdit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '编辑',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 行2：大字未结清金额 +「待收回 / 待归还」小标（右对齐、同行）。
              Row(
                children: <Widget>[
                  const Spacer(),
                  Text(
                    Money.fromMinor(account.balanceMinor).format(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? ForestNeutral.textPrimary
                          : ForestNeutral.deepInk,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isLendOut ? '待收回' : '待归还',
                    style: const TextStyle(
                      fontSize: 11,
                      color: ForestNeutral.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 行3：状态胶囊 + 进入箭头。
              Row(
                children: <Widget>[
                  _capsule(
                    '进行中 $ongoingCount 笔',
                    isDark
                        ? ForestGreen.deep.withValues(alpha: 0.22)
                        : ForestGreen.soft,
                    isDark ? ForestGreen.brand : ForestGreen.deep,
                  ),
                  const SizedBox(width: 8),
                  _capsule(
                    '已结清 $settledCount 笔',
                    ForestAccent.gold.withValues(alpha: 0.14),
                    ForestAccent.gold,
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: ForestNeutral.textTertiary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _capsule(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: fg),
        ),
      );
}

// ── 未指定账户的记录：平铺行（保留删除 / 编辑入口） ─────────

class _UnassignedTile extends StatelessWidget {
  const _UnassignedTile({
    required this.record,
    required this.onDelete,
    required this.onTap,
  });

  final LendRecord record;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isOut = record.direction == LendDirection.lendOut;
    return ListTile(
      leading: Icon(
        isOut ? Icons.north_east : Icons.south_west,
        color: isOut ? AppPalette.expense : AppPalette.income,
      ),
      title: Text(
        record.counterparty.isEmpty ? '未填写对方' : record.counterparty,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${record.direction.label} · ${record.status.label} · '
        '${Money.fromMinor(record.amountMinor).format()}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (record.dueAt != null)
            Text(
              '到期 ${DateFormat('MM-dd').format(
                DateTime.fromMillisecondsSinceEpoch(record.dueAt!,
                    isUtc: true),
              )}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _NoLendEmpty extends StatelessWidget {
  const _NoLendEmpty();

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: <Widget>[
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: isDark
                  ? ForestGreen.deep.withValues(alpha: 0.18)
                  : ForestGreen.soft,
              border: Border.all(
                color: isDark
                    ? ForestGreen.deep.withValues(alpha: 0.30)
                    : ForestGreen.softBorder,
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: LineIcon(
              LineIconKind.lend,
              size: 34,
              color: isDark ? ForestGreen.brand : ForestGreen.label,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '还没有借还账户',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? ForestNeutral.textPrimary : ForestNeutral.deepInk,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '到账户页新建借出 / 借入类型账户后，这里会显示对应卡片',
            style: TextStyle(
              fontSize: 12,
              color: ForestNeutral.textTertiary,
            ),
          ),
          const SizedBox(height: 18),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => context.push(Routes.accounts),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              decoration: BoxDecoration(
                gradient: ForestGradients.button,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '去账户页新建',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
