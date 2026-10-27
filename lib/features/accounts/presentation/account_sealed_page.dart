import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:pocket_ledger/core/errors/failures.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/routing/app_router.dart';
import 'package:pocket_ledger/shared/models/money.dart';
import 'package:pocket_ledger/shared/widgets/app_toast.dart';
import 'package:pocket_ledger/shared/widgets/clay_icon_tile.dart';
import 'package:pocket_ledger/shared/widgets/confirm_dialog.dart';
import 'package:pocket_ledger/shared/widgets/empty_state.dart';
import 'package:pocket_ledger/shared/widgets/line_icon_map.dart';
import 'package:pocket_ledger/shared/widgets/line_icons.dart';
import 'package:pocket_ledger/shared/widgets/loading_state.dart';
import 'package:pocket_ledger/shared/widgets/menu_item.dart';
import 'package:pocket_ledger/shared/widgets/money_text.dart';
import 'package:pocket_ledger/shared/widgets/sheet_scaffold.dart';
import 'package:pocket_ledger/shared/widgets/slide_action_button.dart';
import 'package:pocket_ledger/theme/app_colors.dart';
import 'package:pocket_ledger/theme/app_dimens.dart';

import '../../investment/providers/investment_providers.dart';
import '../data/account_icon.dart';
import '../providers/accounts_providers.dart';

/// 封存资产列表页（账户设置 → 封存资产列表进入）。
///
/// 布局参照小青账「封存资产」（与 [AccountHiddenPage] 对称）：
/// - 顶部「合计」卡片（绿色竖条 + 净资产(元) 大数字 + 总资产/总负债拆分）；
/// - 「资产」分类标题（带说明图标）；
/// - 按分类（资金类/负债类/投资类/应收类/应付类）分组，每组一张卡片，
///   头部展示分类图标 + 名称 + 数量角标 + 金额 + 占比；
/// - 组内逐行列出封存账户，左滑露出「恢复 / 编辑 / 删除」操作（与主资产页
///   一致）：「恢复」即取消封存（[AccountRepository.restore]），账户自动从本
///   列表消失并回到资产总览；「编辑」进账户编辑页；「删除」走二次确认。
///
/// 封存账户的口径与资产总览一致：负债方向账户（信用卡/借入等）正余额即欠款，
/// 计入总负债、从净资产里扣；证券账户展示余额 = 现金 + 持仓市值。
class AccountSealedPage extends ConsumerStatefulWidget {
  const AccountSealedPage({super.key});

  @override
  ConsumerState<AccountSealedPage> createState() => _AccountSealedPageState();
}

class _AccountSealedPageState extends ConsumerState<AccountSealedPage> {
  Future<void> _restore(Account account) async {
    try {
      await ref.read(accountRepositoryProvider).restore(account.id);
      if (mounted) showAppToast(context, '已恢复「${account.name}」');
    } on AppFailure catch (e) {
      if (mounted) showAppToast(context, e.message);
    }
  }

  /// 左滑「编辑」：与主资产页同口径——借还/投资/负债/资金类进独立编辑页，
  /// 其余（如报销）进资产详情页。
  void _edit(Account a) {
    if (a.type == AccountType.lend ||
        a.type == AccountType.borrow ||
        a.type.category == AccountCategory.investment ||
        a.type.isDebt ||
        a.type.category == AccountCategory.capital) {
      context.push('/accounts/${a.id}/edit');
    } else {
      context.push('/accounts/${a.id}/transactions');
    }
  }

  Future<void> _delete(Account a) async {
    final bool? confirmed = await showConfirm(
      context,
      title: '删除账户？',
      content: '「${a.name}」将被删除。该账户的流水记录会保留，'
          '但不再计入资产负债。此操作不可撤销。',
      confirmText: '删除',
      danger: true,
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(accountRepositoryProvider).remove(a.id);
      if (mounted) showAppToast(context, '已删除「${a.name}」');
    } on AppFailure catch (e) {
      if (mounted) showAppToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Account>> sealed = ref.watch(sealedAccountsProvider);
    final Map<String, int> mv =
        ref.watch(investmentMarketValueByAccountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('封存资产'),
        actions: <Widget>[
          IconButton(
            icon: const LineGlyph(Icons.settings),
            tooltip: '设置',
            onPressed: () async {
              final String? route = await _showSealedSettings(context);
              if (route != null && context.mounted) {
                // 从封存资产页进入排序时，带 extra 告诉排序页只排封存账户。
                if (route == Routes.accountSort) {
                  await context.push(route, extra: AccountStatus.sealed);
                } else {
                  await context.push(route);
                }
              }
            },
          ),
        ],
      ),
      body: sealed.when(
        data: (List<Account> list) => _Body(
          list: list,
          mv: mv,
          onRestore: _restore,
          onEdit: _edit,
          onDelete: _delete,
        ),
        loading: () => const LoadingState(),
        error: (Object e, StackTrace _) => Center(child: Text('加载失败：$e')),
      ),
    );
  }

  /// 封存资产页右侧「设置」键：弹出与参考图一致的「设置」卡片弹层。
  ///
  /// 仅含两项：资产变动（暂无对应页，占位提示「敬请期待」）/
  /// 资产排序（跳转 [Routes.accountSort]）。标题栏带 × 关闭键；点遮罩或
  /// × 关闭返回 null。弹层走根导航器，故关闭一律 [Navigator.of](
  /// context, rootNavigator: true) 以确保关掉的是弹层而非本页。
  static Future<String?> _showSealedSettings(BuildContext context) {
    return showAppCardModal<String>(
      context,
      title: '设置',
      titleTrailing: IconButton(
        icon: const LineGlyph(Icons.close),
        tooltip: '关闭',
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
      ),
      body: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: <Widget>[
          MenuItem(
            title: '资产变动',
            icon: Icons.trending_up,
            iconColor: AppPalette.primary,
            onTap: () {
              showAppToast(context, '资产变动：敬请期待');
              Navigator.of(context, rootNavigator: true).pop();
            },
          ),
          MenuItem(
            title: '资产排序',
            icon: Icons.swap_vert,
            iconColor: AppPalette.blueTint,
            subtitle: '将资产整理顺序，常用可至前。',
            onTap: () => Navigator.of(context, rootNavigator: true)
                .pop(Routes.accountSort),
          ),
        ],
      ),
    );
  }
}

/// 分类展示顺序与标题（与资产总览默认顺序一致）。
const List<AccountCategory> _catOrder = <AccountCategory>[
  AccountCategory.capital,
  AccountCategory.debt,
  AccountCategory.investment,
  AccountCategory.receivable,
  AccountCategory.payable,
];

const Map<AccountCategory, String> _catTitle = <AccountCategory, String>{
  AccountCategory.capital: '资金类',
  AccountCategory.debt: '负债类',
  AccountCategory.investment: '投资类',
  AccountCategory.receivable: '应收类',
  AccountCategory.payable: '应付类',
};

class _Body extends StatelessWidget {
  const _Body({
    required this.list,
    required this.mv,
    required this.onRestore,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Account> list;
  final Map<String, int> mv;
  final void Function(Account) onRestore;
  final void Function(Account) onEdit;
  final void Function(Account) onDelete;

  @override
  Widget build(BuildContext context) {
    // 净资产 / 总资产 / 总负债（与资产总览同口径）。
    int net = 0;
    int totalAssets = 0;
    int totalDebt = 0;
    for (final Account a in list) {
      final int display = displayBalanceWithMarket(a, mv);
      if (a.type.isLiabilitySide) {
        net -= display;
        if (display > 0) totalDebt += display;
      } else {
        net += display;
        if (display > 0) totalAssets += display;
      }
    }

    // 按分类分组 + 各组金额。
    final Map<AccountCategory, List<Account>> grouped =
        <AccountCategory, List<Account>>{};
    final Map<AccountCategory, int> catAmount = <AccountCategory, int>{};
    int totalGross = 0;
    for (final AccountCategory c in _catOrder) {
      final List<Account> items =
          list.where((Account a) => a.type.category == c).toList();
      grouped[c] = items;
      int sum = 0;
      for (final Account a in items) {
        sum += displayBalanceWithMarket(a, mv);
      }
      catAmount[c] = sum;
      totalGross += sum.abs();
    }

    final List<Widget> slivers = <Widget>[
      SliverToBoxAdapter(
        child: _SummaryCard(
          net: net,
          totalAssets: totalAssets,
          totalDebt: totalDebt,
        ),
      ),
      const SliverToBoxAdapter(child: _SectionHeader()),
    ];

    if (list.isEmpty) {
      slivers.add(
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 48),
            child: EmptyState(message: '没有内容了哦'),
          ),
        ),
      );
    } else {
      for (final AccountCategory c in _catOrder) {
        final List<Account> items = grouped[c]!;
        if (items.isEmpty) continue;
        final int amount = catAmount[c]!;
        final double pct =
            totalGross == 0 ? 0 : amount.abs() / totalGross * 100;
        slivers.add(
          SliverToBoxAdapter(
            child: _GroupCard(
              category: c,
              accounts: items,
              amountMinor: amount,
              percentage: pct,
              mv: mv,
              onRestore: onRestore,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          ),
        );
      }
    }

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 88)));
    return SlidableAutoCloseBehavior(
      child: CustomScrollView(slivers: slivers),
    );
  }
}

/// 顶部「合计」卡片：净资产(元) 大数字 + 总资产/总负债拆分。
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.net,
    required this.totalAssets,
    required this.totalDebt,
  });

  final int net;
  final int totalAssets;
  final int totalDebt;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color netColor = net < 0 ? AppPalette.expense : AppPalette.primary;

    return Container(
      margin: const EdgeInsets.all(AppDimens.lg),
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // 「合计」绿色竖条标题
                    Row(
                      children: <Widget>[
                        Container(
                          width: 4,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppPalette.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: AppDimens.sm),
                        Text(
                          '合计',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.sm),
                    Text(
                      '净资产(元)',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppDimens.xs),
                    Text(
                      Money.fromMinor(net).format(),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: netColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              // 右侧装饰图标（呼应参考图的插画位）。
              const Opacity(
                opacity: 0.1,
                child: LineGlyph(
                  Icons.account_balance_wallet,
                  size: 56,
                  color: AppPalette.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.md,
              vertical: AppDimens.sm,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _SummaryItem(
                    label: '总资产',
                    amountMinor: totalAssets,
                    color: AppPalette.primary,
                  ),
                ),
                Expanded(
                  child: _SummaryItem(
                    label: '总负债',
                    amountMinor: totalDebt,
                    color: AppPalette.expense,
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

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.amountMinor,
    required this.color,
  });

  final String label;
  final int amountMinor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: context.forest.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        MoneyText(
          Money.fromMinor(amountMinor),
          color: color,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

/// 「资产」分类标题（带说明图标）。
class _SectionHeader extends StatelessWidget {
  const _SectionHeader();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.lg,
        AppDimens.md,
        AppDimens.lg,
        AppDimens.xs,
      ),
      child: Text(
        '资产',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 单个分类卡片：头部（图标 + 名称 + 数量角标 + 金额 + 占比）+ 账户行。
class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.category,
    required this.accounts,
    required this.amountMinor,
    required this.percentage,
    required this.mv,
    required this.onRestore,
    required this.onEdit,
    required this.onDelete,
  });

  final AccountCategory category;
  final List<Account> accounts;
  final int amountMinor;
  final double percentage;
  final Map<String, int> mv;
  final void Function(Account) onRestore;
  final void Function(Account) onEdit;
  final void Function(Account) onDelete;

  bool get _isDebt =>
      category == AccountCategory.debt || category == AccountCategory.payable;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color iconColor = _isDebt ? AppPalette.expense : AppPalette.primary;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimens.lg,
        vertical: AppDimens.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppDimens.md),
            child: Row(
              children: <Widget>[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: LineIcon(
                    accountCategoryLineKind(category),
                    size: 16,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: AppDimens.sm),
                Expanded(
                  child: Row(
                    children: <Widget>[
                      Text(
                        _catTitle[category] ?? category.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${accounts.length}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: iconColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    MoneyText(
                      Money.fromMinor(amountMinor),
                      color: _isDebt ? AppPalette.expense : null,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (int i = 0; i < accounts.length; i++) ...<Widget>[
            _SealedAccountRow(
              account: accounts[i],
              isDebt: _isDebt,
              mv: mv,
              onRestore: () => onRestore(accounts[i]),
              onEdit: () => onEdit(accounts[i]),
              onDelete: () => onDelete(accounts[i]),
            ),
          ],
        ],
      ),
    );
  }
}

/// 封存账户行：左滑露出「恢复 / 编辑 / 删除」三按钮（灰/绿/红），
/// 与主资产页左滑交互一致。账户主体点击进入资产详情页。
class _SealedAccountRow extends StatelessWidget {
  const _SealedAccountRow({
    required this.account,
    required this.isDebt,
    required this.mv,
    required this.onRestore,
    required this.onEdit,
    required this.onDelete,
  });

  final Account account;
  final bool isDebt;
  final Map<String, int> mv;
  final VoidCallback onRestore;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color iconColor = isDebt ? AppPalette.expense : AppPalette.primary;
    final int display = displayBalanceWithMarket(account, mv);

    return Slidable(
      key: ValueKey<String>(account.id),
      groupTag: 'sealed_account_rows',
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: <Widget>[
          SlideActionButton(
            icon: Icons.restore_outlined,
            label: '恢复',
            color: theme.colorScheme.onSurfaceVariant,
            onPressed: onRestore,
          ),
          SlideActionButton(
            icon: Icons.edit_outlined,
            label: '编辑',
            color: AppPalette.success,
            onPressed: onEdit,
          ),
          SlideActionButton(
            icon: Icons.delete_outline,
            label: '删除',
            color: AppPalette.danger,
            onPressed: onDelete,
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: AppDimens.md),
            leading: ClayIconTile(
              size: 40,
              color: iconColor,
              child: LineIcon(
                accountLineKind(account.type) ?? LineIconKind.star,
                size: 20,
                color:
                    Color.lerp(iconColor, theme.colorScheme.onSurface, 0.22)!,
              ),
            ),
            title: Text(
              account.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(account.type.label),
                Text(
                  Money.fromMinor(display).format(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDebt
                        ? AppPalette.expense
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 68),
        ],
      ),
    );
  }
}
