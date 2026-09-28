import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../routing/app_router.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/money_text.dart';
import '../../lend/providers/lend_providers.dart';
import '../../reimbursement/providers/reimbursement_providers.dart';
import '../data/account_group_collapse.dart';
import '../data/account_group_order.dart';
import '../data/account_icon.dart';
import '../providers/accounts_providers.dart';
import '../../../shared/widgets/app_toast.dart';

/// 账户列表页（分组卡片布局）。
///
/// 顶部「净资产」卡片 + 五大分组卡片：
/// **资金类 / 负债类 / 投资类 / 应收类 / 应付类**。
///
/// - 资金、投资、负债类卡片列出该类的真实账户；
/// - 应收类卡片列出报销/借出等真实应收账户（未指向固定报销账户的待收回只在报销页体现，不进账户列表），并在借出下方展开每个对方账户（如小米）的应收余额；
/// - 应付类卡片展示「借入」入口，并在下方展开每个对方账户（如小明）的应付余额；
/// - 点击分组头部折叠/展开，长按头部拖动排序；
/// - 账户行支持左滑「隐藏 / 编辑 / 删除」，点击进资产详情页。
/// - 新增账户走独立页面 `/accounts/add`。
class AccountsPage extends ConsumerStatefulWidget {
  const AccountsPage({super.key});

  @override
  ConsumerState<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends ConsumerState<AccountsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账户'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新增账户',
            onPressed: () => context.push(Routes.accountAdd),
          ),
        ],
      ),
      body: SlidableAutoCloseBehavior(
        child: _Body(
          onOpenDetail: _openDetail,
          onEditAccount: _editAccount,
          onArchiveAccount: _archiveAccount,
          onDeleteAccount: _deleteAccount,
        ),
      ),
    );
  }

  /// 报销账户统一跳报销页、借出/借入账户统一跳借还页（即其「资产详情」），
  /// 其余类型进资产详情页。
  void _openDetail(Account a) {
    final String target = switch (a.type) {
      AccountType.reimbursement => Routes.reimbursement,
      AccountType.lend || AccountType.borrow => Routes.lend,
      _ => '/accounts/${a.id}/transactions',
    };
    context.push(target);
  }

  void _editAccount(Account a) => _showEditor(context, ref, a);

  void _archiveAccount(Account a) => _confirmArchive(context, ref, a);

  void _deleteAccount(Account a) => _confirmDelete(context, ref, a);

  Future<void> _showEditor(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final TextEditingController nameController =
        TextEditingController(text: account.name);
    final TextEditingController balanceController = TextEditingController(
      text: Money.fromMinor(account.balanceMinor).decimal.toStringAsFixed(2),
    );
    AccountType type = account.type;

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setState) => AlertDialog(
          title: const Text('编辑账户'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '账户名称'),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              TextField(
                controller: balanceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '余额',
                  prefixText: '¥ ',
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              DropdownButtonFormField<AccountType>(
                initialValue: type,
                decoration: const InputDecoration(labelText: '账户类型'),
                items: AccountType.values
                    .map(
                      (AccountType t) => DropdownMenuItem<AccountType>(
                        value: t,
                        child: Text(t.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (AccountType? v) {
                  if (v != null) setState(() => type = v);
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    try {
      await ref.read(accountRepositoryProvider).update(
            id: account.id,
            name: nameController.text,
            type: type,
            balanceMinor: Money.tryParse(balanceController.text).minor,
          );
    } on AppFailure catch (e) {
      if (context.mounted) {
        showAppToast(context, e.message);
      }
    }
  }

  Future<void> _confirmArchive(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('隐藏账户？'),
        content: Text(
          '「${account.name}」将不再显示在账户列表中，'
          '流水与数据保留，后续可在「已隐藏」中恢复。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('隐藏'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(accountRepositoryProvider).archive(account.id);
    } on AppFailure catch (e) {
      if (context.mounted) {
        showAppToast(context, e.message);
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('删除账户？'),
        content: Text(
          '「${account.name}」将被删除。该账户的流水记录会保留，但不再计入资产负债。此操作不可撤销。',
        ),
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
      await ref.read(accountRepositoryProvider).remove(account.id);
    } on AppFailure catch (e) {
      if (context.mounted) {
        showAppToast(context, e.message);
      }
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.onOpenDetail,
    required this.onEditAccount,
    required this.onArchiveAccount,
    required this.onDeleteAccount,
  });

  final void Function(Account) onOpenDetail;
  final void Function(Account) onEditAccount;
  final void Function(Account) onArchiveAccount;
  final void Function(Account) onDeleteAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Account>> accounts = ref.watch(accountsProvider);
    final AsyncValue<int> netAssets = ref.watch(netAssetsProvider);
    final List<String> order = ref.watch(accountGroupOrderProvider);
    final Map<String, bool> collapsed =
        ref.watch(accountGroupCollapsedProvider);
    final int lendOutMinor = ref.watch(lendOutOngoingProvider).valueOrNull ?? 0;
    final int borrowInMinor =
        ref.watch(borrowInOngoingProvider).valueOrNull ?? 0;
    final Map<String, int> lendOutBalances =
        ref.watch(lendCounterpartyBalancesProvider(LendDirection.lendOut)).valueOrNull ??
            const <String, int>{};
    final Map<String, int> borrowInBalances =
        ref.watch(lendCounterpartyBalancesProvider(LendDirection.borrowIn)).valueOrNull ??
            const <String, int>{};

    return accounts.when(
      data: (List<Account> list) {
        final List<Account> capitals = list
            .where(
              (Account a) => a.type.category == AccountCategory.capital,
            )
            .toList();
        final List<Account> investments = list
            .where(
              (Account a) => a.type.category == AccountCategory.investment,
            )
            .toList();
        final List<Account> debts = list
            .where(
              (Account a) => a.type.category == AccountCategory.debt,
            )
            .toList();
        final List<Account> receivables = list
            .where(
              (Account a) => a.type.category == AccountCategory.receivable,
            )
            .toList();
        final List<Account> payables = list
            .where(
              (Account a) => a.type.category == AccountCategory.payable,
            )
            .toList();

        final List<_GroupConfig> visible = _visibleGroups(
          order,
          capitals: capitals,
          investments: investments,
          debts: debts,
          receivables: receivables,
          payables: payables,
          lendOutMinor: lendOutMinor,
          borrowInMinor: borrowInMinor,
        );

        return CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: _NetAssetsHeader(value: netAssets),
            ),
            SliverReorderableList(
              itemCount: visible.length,
              itemBuilder: (BuildContext context, int index) {
                final _GroupConfig g = visible[index];
                return _GroupCard(
                  key: ValueKey<String>(g.title),
                  index: index,
                  title: g.title,
                  totalMinor: g.totalMinor,
                  collapsed: collapsed[g.title] ?? false,
                  onToggle: () => ref
                      .read(accountGroupCollapsedProvider.notifier)
                      .toggle(g.title),
                  isDebt: g.isDebt,
                  child: _buildGroupBody(
                    g.title,
                    capitals: capitals,
                    investments: investments,
                    debts: debts,
                    receivables: receivables,
                    payables: payables,
                              lendOutMinor: lendOutMinor,
                    borrowInMinor: borrowInMinor,
                    lendOutBalances: lendOutBalances,
                    borrowInBalances: borrowInBalances,
                  ),
                );
              },
              onReorderItem: (int oldIndex, int newIndex) {
                final List<String> visibleTitles =
                    visible.map((_GroupConfig g) => g.title).toList();
                ref
                    .read(accountGroupOrderProvider.notifier)
                    .reorderVisible(visibleTitles, oldIndex, newIndex);
              },
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 88),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, StackTrace _) => Center(child: Text('加载失败：$e')),
    );
  }

  Widget _buildGroupBody(
    String title, {
    required List<Account> capitals,
    required List<Account> investments,
    required List<Account> debts,
    required List<Account> receivables,
    required List<Account> payables,
    required int lendOutMinor,
    required int borrowInMinor,
    required Map<String, int> lendOutBalances,
    required Map<String, int> borrowInBalances,
  }) {
    return switch (title) {
      '资金类' => _AccountBody(
          accounts: capitals,
          isDebt: false,
          emptyHint: '还没有资金账户，点右上角新增',
          onOpenDetail: onOpenDetail,
          onEditAccount: onEditAccount,
          onArchiveAccount: onArchiveAccount,
          onDeleteAccount: onDeleteAccount,
        ),
      '投资类' => _AccountBody(
          accounts: investments,
          isDebt: false,
          emptyHint: '还没有投资账户，点右上角新增',
          onOpenDetail: onOpenDetail,
          onEditAccount: onEditAccount,
          onArchiveAccount: onArchiveAccount,
          onDeleteAccount: onDeleteAccount,
        ),
      '负债类' => _AccountBody(
          accounts: debts,
          isDebt: true,
          emptyHint: '还没有负债账户，点右上角新增',
          onOpenDetail: onOpenDetail,
          onEditAccount: onEditAccount,
          onArchiveAccount: onArchiveAccount,
          onDeleteAccount: onDeleteAccount,
        ),
      '应收类' => _ReceivableBody(
          accounts: receivables,
          lendOutMinor: lendOutMinor,
          lendOutBalances: lendOutBalances,
          onOpenDetail: onOpenDetail,
          onEditAccount: onEditAccount,
          onArchiveAccount: onArchiveAccount,
          onDeleteAccount: onDeleteAccount,
        ),
      '应付类' => _PayableBody(
          accounts: payables,
          borrowInMinor: borrowInMinor,
          borrowInBalances: borrowInBalances,
          onOpenDetail: onOpenDetail,
          onEditAccount: onEditAccount,
          onArchiveAccount: onArchiveAccount,
          onDeleteAccount: onDeleteAccount,
        ),
      _ => const SizedBox.shrink(),
    };
  }

  static List<_GroupConfig> _visibleGroups(
    List<String> order, {
    required List<Account> capitals,
    required List<Account> investments,
    required List<Account> debts,
    required List<Account> receivables,
    required List<Account> payables,
    required int lendOutMinor,
    required int borrowInMinor,
  }) {
    final List<_GroupConfig> result = <_GroupConfig>[];
    for (final String title in order) {
      final _GroupConfig? g = _GroupConfig.fromTitle(
        title,
        capitals: capitals,
        investments: investments,
        debts: debts,
        receivables: receivables,
        payables: payables,
        lendOutMinor: lendOutMinor,
        borrowInMinor: borrowInMinor,
      );
      if (g != null && g.isVisible) {
        result.add(g);
      }
    }
    return result;
  }
}

/// 单个分组的静态描述。
class _GroupConfig {
  const _GroupConfig({
    required this.title,
    required this.totalMinor,
    required this.isVisible,
    required this.isDebt,
  });

  final String title;
  final int totalMinor;
  final bool isVisible;
  final bool isDebt;

  static _GroupConfig? fromTitle(
    String title, {
    required List<Account> capitals,
    required List<Account> investments,
    required List<Account> debts,
    required List<Account> receivables,
    required List<Account> payables,
    required int lendOutMinor,
    required int borrowInMinor,
  }) =>
      switch (title) {
        '资金类' => _GroupConfig(
            title: '资金类',
            totalMinor:
                capitals.fold(0, (int s, Account a) => s + a.balanceMinor),
            // 真实账户分组始终展示，空时显示新增提示
            isVisible: true,
            isDebt: false,
          ),
        '投资类' => _GroupConfig(
            title: '投资类',
            totalMinor:
                investments.fold(0, (int s, Account a) => s + a.balanceMinor),
            isVisible: true,
            isDebt: false,
          ),
        '应收类' => _GroupConfig(
            title: '应收类',
            // 未指向固定报销账户的待收回不进账户列表（只在报销页体现）；
            // 指向了报销账户的应收已含在报销账户余额里，这里只汇总真实账户 + 借出。
            totalMinor: receivables.fold(
                  0,
                  (int s, Account a) => s + a.balanceMinor,
                ) +
                lendOutMinor,
            isVisible: receivables.isNotEmpty || lendOutMinor != 0,
            isDebt: false,
          ),
        '负债类' => _GroupConfig(
            title: '负债类',
            totalMinor: debts.fold(0, (int s, Account a) => s + a.balanceMinor),
            isVisible: true,
            isDebt: true,
          ),
        '应付类' => _GroupConfig(
            title: '应付类',
            totalMinor: payables.fold(
                  0,
                  (int s, Account a) => s + a.balanceMinor,
                ) +
                borrowInMinor,
            isVisible: payables.isNotEmpty || borrowInMinor != 0,
            isDebt: true,
          ),
        _ => null,
      };
}

/// 分组卡片：头部（可点击折叠、长按拖动）+ 可折叠主体。
class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required super.key,
    required this.index,
    required this.title,
    required this.totalMinor,
    required this.collapsed,
    required this.onToggle,
    required this.isDebt,
    required this.child,
  });

  final int index;
  final String title;
  final int totalMinor;
  final bool collapsed;
  final VoidCallback onToggle;
  final bool isDebt;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color amountColor =
        isDebt ? AppColors.expense : AppColors.textPrimary;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceLg,
        vertical: AppDimens.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 头部：点击折叠/展开；长按头部触发分组排序（不显示拖拽手柄/折叠箭头）
          ReorderableDelayedDragStartListener(
            index: index,
            child: InkWell(
              onTap: onToggle,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppDimens.radiusMd),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.spaceMd),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    MoneyText(
                      Money.fromMinor(totalMinor),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: amountColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // AnimatedSwitcher 会在过渡结束后真正移除被折叠的内容
          // （AnimatedCrossFade 会一直保留 inactive 子节点并绘制，无法真正隐藏）。
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: collapsed
                ? const SizedBox.shrink(key: ValueKey<String>('grp-collapsed'))
                : KeyedSubtree(
                    key: const ValueKey<String>('grp-expanded'),
                    child: child,
                  ),
          ),
        ],
      ),
    );
  }
}

/// 真实账户分组的展开内容。
class _AccountBody extends StatelessWidget {
  const _AccountBody({
    required this.accounts,
    required this.isDebt,
    required this.emptyHint,
    required this.onOpenDetail,
    required this.onEditAccount,
    required this.onArchiveAccount,
    required this.onDeleteAccount,
  });

  final List<Account> accounts;
  final bool isDebt;
  final String emptyHint;
  final void Function(Account) onOpenDetail;
  final void Function(Account) onEditAccount;
  final void Function(Account) onArchiveAccount;
  final void Function(Account) onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
        child: EmptyState(message: emptyHint),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: accounts.length,
      separatorBuilder: (BuildContext _, int __) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        final Account a = accounts[index];
        return Slidable(
          key: ValueKey<String>(a.id),
          groupTag: 'account_rows',
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.42,
            children: <Widget>[
              _SlideAction(
                icon: Icons.visibility_off_outlined,
                label: '隐藏',
                color: AppColors.textTertiary,
                onPressed: () => onArchiveAccount(a),
              ),
              _SlideAction(
                icon: Icons.edit_outlined,
                label: '编辑',
                color: AppColors.info,
                onPressed: () => onEditAccount(a),
              ),
              _SlideAction(
                icon: Icons.delete_outline,
                label: '删除',
                color: AppColors.danger,
                onPressed: () => onDeleteAccount(a),
              ),
            ],
          ),
          child: ListTile(
            onTap: () => onOpenDetail(a),
            leading: CircleAvatar(
              backgroundColor: (isDebt ? AppColors.expense : AppColors.primary)
                  .withValues(alpha: 0.12),
              child: Icon(
                accountIcon(a.type),
                size: 20,
                color: isDebt ? AppColors.expense : AppColors.primary,
              ),
            ),
            title: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                _SideTag(isDebt: isDebt),
              ],
            ),
            subtitle: Text(a.type.label),
            trailing: MoneyText(
              Money.fromMinor(a.balanceMinor),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: isDebt ? AppColors.expense : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        );
      },
    );
  }
}

/// 左滑操作按钮：圆角药丸、轻底色 + 同色图标/文字。
class _SlideAction extends StatelessWidget {
  const _SlideAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CustomSlidableAction(
      onPressed: (_) => onPressed(),
      backgroundColor: Colors.transparent,
      foregroundColor: color,
      padding: EdgeInsets.zero,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppDimens.spaceXs / 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 「资产 / 负债」小标签。
class _SideTag extends StatelessWidget {
  const _SideTag({required this.isDebt});

  final bool isDebt;

  @override
  Widget build(BuildContext context) {
    final Color color = isDebt ? AppColors.expense : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Text(
        isDebt ? '负债' : '资产',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

/// 应收类展开内容：先列出真实应收账户，再展示往来汇总。
class _ReceivableBody extends StatelessWidget {
  const _ReceivableBody({
    required this.accounts,
    required this.lendOutMinor,
    required this.lendOutBalances,
    required this.onOpenDetail,
    required this.onEditAccount,
    required this.onArchiveAccount,
    required this.onDeleteAccount,
  });

  final List<Account> accounts;
  final int lendOutMinor;
  final Map<String, int> lendOutBalances;
  final void Function(Account) onOpenDetail;
  final void Function(Account) onEditAccount;
  final void Function(Account) onArchiveAccount;
  final void Function(Account) onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty && lendOutMinor == 0) {
      return const Padding(
        padding: EdgeInsets.only(bottom: AppDimens.spaceMd),
        child: EmptyState(message: '没有待收回的款项'),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (accounts.isNotEmpty)
          _AccountBody(
            accounts: accounts,
            isDebt: false,
            emptyHint: '还没有应收账户，点右上角新增',
            onOpenDetail: onOpenDetail,
            onEditAccount: onEditAccount,
            onArchiveAccount: onArchiveAccount,
            onDeleteAccount: onDeleteAccount,
          ),
        if (accounts.isNotEmpty && lendOutMinor != 0)
          const Divider(height: 1),
        if (lendOutMinor != 0)
          _CounterpartyBalanceBody(
            title: '借出',
            icon: Icons.handshake_outlined,
            totalMinor: lendOutMinor,
            balances: lendOutBalances,
            amountColor: AppColors.income,
            onTotalTap: () => context.push(Routes.lend),
          ),
      ],
    );
  }
}

/// 应付类展开内容：先列出真实应付账户，再展示往来汇总。
class _PayableBody extends StatelessWidget {
  const _PayableBody({
    required this.accounts,
    required this.borrowInMinor,
    required this.borrowInBalances,
    required this.onOpenDetail,
    required this.onEditAccount,
    required this.onArchiveAccount,
    required this.onDeleteAccount,
  });

  final List<Account> accounts;
  final int borrowInMinor;
  final Map<String, int> borrowInBalances;
  final void Function(Account) onOpenDetail;
  final void Function(Account) onEditAccount;
  final void Function(Account) onArchiveAccount;
  final void Function(Account) onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty && borrowInMinor == 0) {
      return const Padding(
        padding: EdgeInsets.only(bottom: AppDimens.spaceMd),
        child: EmptyState(message: '没有待归还的款项'),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (accounts.isNotEmpty)
          _AccountBody(
            accounts: accounts,
            isDebt: true,
            emptyHint: '还没有应付账户，点右上角新增',
            onOpenDetail: onOpenDetail,
            onEditAccount: onEditAccount,
            onArchiveAccount: onArchiveAccount,
            onDeleteAccount: onDeleteAccount,
          ),
        if (accounts.isNotEmpty && borrowInMinor != 0)
          const Divider(height: 1),
        if (borrowInMinor != 0)
          _CounterpartyBalanceBody(
            title: '借入',
            icon: Icons.handshake_outlined,
            totalMinor: borrowInMinor,
            balances: borrowInBalances,
            amountColor: AppColors.expense,
            onTotalTap: () => context.push(Routes.lend),
          ),
      ],
    );
  }
}

/// 应收 / 应付对方账户明细：先显示汇总行，再列出每个 counterparty 的余额。
class _CounterpartyBalanceBody extends StatelessWidget {
  const _CounterpartyBalanceBody({
    required this.title,
    required this.icon,
    required this.totalMinor,
    required this.balances,
    required this.amountColor,
    required this.onTotalTap,
  });

  final String title;
  final IconData icon;
  final int totalMinor;
  final Map<String, int> balances;
  final Color amountColor;
  final VoidCallback onTotalTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _SummaryRow(
          icon: icon,
          title: title,
          amountMinor: totalMinor,
          amountColor: amountColor,
          onTap: onTotalTap,
        ),
        ...balances.entries.map(
          (MapEntry<String, int> e) => _CounterpartyRow(
            name: e.key,
            amountMinor: e.value,
            amountColor: amountColor,
          ),
        ),
      ],
    );
  }
}

/// 单个对方账户余额行。
class _CounterpartyRow extends StatelessWidget {
  const _CounterpartyRow({
    required this.name,
    required this.amountMinor,
    required this.amountColor,
  });

  final String name;
  final int amountMinor;
  final Color amountColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: ListTile(
        dense: true,
        title: Text(
          name,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        trailing: MoneyText(
          Money.fromMinor(amountMinor),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: amountColor,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

/// 往来汇总行（应收/应付类用）。
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.title,
    required this.amountMinor,
    required this.onTap,
    this.amountColor = AppColors.income,
  });

  final IconData icon;
  final String title;
  final int amountMinor;
  final VoidCallback onTap;
  final Color amountColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: amountColor.withValues(alpha: 0.12),
        child: Icon(icon, size: 20, color: amountColor),
      ),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          MoneyText(
            Money.fromMinor(amountMinor),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: amountColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(width: AppDimens.spaceXs),
          const Icon(Icons.chevron_right,
              size: 18, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

class _NetAssetsHeader extends StatelessWidget {
  const _NetAssetsHeader({required this.value});

  final AsyncValue<int> value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(AppDimens.spaceLg),
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '净资产',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            Money.fromMinor(value.valueOrNull ?? 0).format(),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
