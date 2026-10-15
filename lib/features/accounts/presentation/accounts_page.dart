import 'package:flutter/material.dart';
import '../../../shared/widgets/line_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:pocket_ledger/shared/widgets/loading_state.dart';

import 'package:pocket_ledger/theme/app_dimens.dart';
import '../../../core/errors/failures.dart';
import '../../../core/theme/forest_asset_design_tokens.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../routing/app_router.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/clay_icon_tile.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../theme/app_colors.dart';
import '../../investment/providers/investment_providers.dart';
import '../../lend/providers/lend_providers.dart';
import '../data/account_group_collapse.dart';
import '../data/account_group_order.dart';
import '../data/account_icon.dart';
import '../providers/accounts_providers.dart';

/// 账户列表页（分组卡片布局）。
///
/// 顶部「净资产」卡片 + 五大分组卡片：
/// **资金类 / 负债类 / 投资类 / 应收类 / 应付类**。
///
/// - 资金、投资、负债类卡片列出该类的真实账户；
/// - 应收类卡片列出报销/借出等真实应收账户（未指向固定报销账户的待收回只在报销页体现，不进账户列表），并在借出下方展开**未指定借出账户**的每个对方账户（如小米）的应收余额（指定了账户的已含在账户余额里，不重复展示）；
/// - 应付类卡片展示「借入」入口，并在下方展开**未指定借入账户**的每个对方账户（如小明）的应付余额（同上，避免与账户余额双计）；
/// - 点击分组头部折叠/展开，长按头部拖动排序；
/// - 账户行支持左滑「隐藏 / 编辑 / 删除」，点击进资产详情页，长按整行拖动排序。
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

  /// 所有账户（含报销账户）统一进资产详情页（报销账户的资产详情含
  /// 垫付汇总 + 待报销/已报销筛选，即其主视图）。
  void _openDetail(Account a) {
    context.push('/accounts/${a.id}/transactions');
  }

  // 左滑「编辑」：应收（借出）/ 应付（借入）/ 投资类（基金、股票、期货、
  // 现货等）/ 资金类（现金、微信、支付宝、借记卡等）/ 负债（信用卡、花呗等）
  // 账户进独立编辑页（参照小青账：借还 = 借款给谁/向谁借 + 只读金额；投资 =
  // 账户名称 + 随持仓自动更新的投资余额（只读）；资金类 = 资产类型卡 +
  // 用户名/余额；借记卡 = 资产类型卡 + 备注/卡号 + 可校正余额；负债 =
  // 额度/欠款/剩余额度 + 账单还款日；共用资产状态三态 + 计入总资产）；
  // 报销维持进资产详情页（其「资产详情」即报销页）。
  void _editAccount(Account a) {
    if (a.type == AccountType.lend ||
        a.type == AccountType.borrow ||
        a.type.category == AccountCategory.investment ||
        a.type.isDebt ||
        a.type.category == AccountCategory.capital) {
      context.push('/accounts/${a.id}/edit');
    } else {
      _openDetail(a);
    }
  }

  void _archiveAccount(Account a) => _confirmArchive(context, ref, a);

  void _deleteAccount(Account a) => _confirmDelete(context, ref, a);

  Future<void> _confirmArchive(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final bool? ok = await showConfirm(
      context,
      title: '隐藏账户？',
      content: '「${account.name}」将不再显示在账户列表中，'
          '流水与数据保留，后续可在「已隐藏」中恢复。',
      confirmText: '隐藏',
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
    final bool? confirmed = await showConfirm(
      context,
      title: '删除账户？',
      content: '「${account.name}」将被删除。该账户的流水记录会保留，但不再计入资产负债。此操作不可撤销。',
      confirmText: '删除',
      danger: true,
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
    final Map<String, int> lendOutBalances = ref
            .watch(lendCounterpartyBalancesProvider(LendDirection.lendOut))
            .valueOrNull ??
        const <String, int>{};
    final Map<String, int> borrowInBalances = ref
            .watch(lendCounterpartyBalancesProvider(LendDirection.borrowIn))
            .valueOrNull ??
        const <String, int>{};
    // 证券/投资类账户的持仓市值聚合（按 accountId）；展示余额 = 现金 + 此值。
    final Map<String, int> mv =
        ref.watch(investmentMarketValueByAccountProvider);

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
          mv: mv,
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
                    ref: ref,
                    capitals: capitals,
                    investments: investments,
                    debts: debts,
                    receivables: receivables,
                    payables: payables,
                    lendOutMinor: lendOutMinor,
                    borrowInMinor: borrowInMinor,
                    lendOutBalances: lendOutBalances,
                    borrowInBalances: borrowInBalances,
                    mv: mv,
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
      loading: () => const LoadingState(),
      error: (Object e, StackTrace _) => Center(child: Text('加载失败：$e')),
    );
  }

  Widget _buildGroupBody(
    String title, {
    required WidgetRef ref,
    required List<Account> capitals,
    required List<Account> investments,
    required List<Account> debts,
    required List<Account> receivables,
    required List<Account> payables,
    required int lendOutMinor,
    required int borrowInMinor,
    required Map<String, int> lendOutBalances,
    required Map<String, int> borrowInBalances,
    required Map<String, int> mv,
  }) {
    return switch (title) {
      '资金类' => _AccountBody(
          accounts: capitals,
          isDebt: false,
          mv: mv,
          emptyHint: '还没有资金账户，点右上角新增',
          onOpenDetail: onOpenDetail,
          onEditAccount: onEditAccount,
          onArchiveAccount: onArchiveAccount,
          onDeleteAccount: onDeleteAccount,
          onReorder: _reorderGroup(ref, capitals),
        ),
      '投资类' => _AccountBody(
          accounts: investments,
          isDebt: false,
          mv: mv,
          emptyHint: '还没有投资账户，点右上角新增',
          onOpenDetail: onOpenDetail,
          onEditAccount: onEditAccount,
          onArchiveAccount: onArchiveAccount,
          onDeleteAccount: onDeleteAccount,
          onReorder: _reorderGroup(ref, investments),
        ),
      '负债类' => _AccountBody(
          accounts: debts,
          isDebt: true,
          mv: mv,
          emptyHint: '还没有负债账户，点右上角新增',
          onOpenDetail: onOpenDetail,
          onEditAccount: onEditAccount,
          onArchiveAccount: onArchiveAccount,
          onDeleteAccount: onDeleteAccount,
          onReorder: _reorderGroup(ref, debts),
        ),
      '应收类' => _ReceivableBody(
          accounts: receivables,
          lendOutMinor: lendOutMinor,
          lendOutBalances: lendOutBalances,
          onOpenDetail: onOpenDetail,
          onEditAccount: onEditAccount,
          onArchiveAccount: onArchiveAccount,
          onDeleteAccount: onDeleteAccount,
          onReorder: _reorderGroup(ref, receivables),
        ),
      '应付类' => _PayableBody(
          accounts: payables,
          borrowInMinor: borrowInMinor,
          borrowInBalances: borrowInBalances,
          onOpenDetail: onOpenDetail,
          onEditAccount: onEditAccount,
          onArchiveAccount: onArchiveAccount,
          onDeleteAccount: onDeleteAccount,
          onReorder: _reorderGroup(ref, payables),
        ),
      _ => const SizedBox.shrink(),
    };
  }

  /// 组内拖拽重排：把 [group] 按拖拽结果重排后，仅回写本组的 sortOrder。
  ///
  /// 账户列表页按分类分组展示、各组内部再按 sortOrder 升序，
  /// 组间 sortOrder 是否交错不影响视觉顺序，故只重排传入的本组账户。
  void Function(int oldIndex, int newIndex) _reorderGroup(
    WidgetRef ref,
    List<Account> group,
  ) {
    return (int oldIndex, int newIndex) async {
      // onReorderItem 的 newIndex 已内置「移除 oldIndex 后」的目标下标修正，
      // 调用方不要再做 -1（与 applyVisibleReorder 的注释同口径）。
      final List<String> ids = group.map((Account a) => a.id).toList();
      if (ids.length <= 1) return;
      if (oldIndex < 0 || oldIndex >= ids.length) return;
      if (newIndex < 0 || newIndex >= ids.length) return;
      final String moved = ids.removeAt(oldIndex);
      ids.insert(newIndex, moved);
      await ref.read(accountsDaoProvider).reorder(ids);
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
    required Map<String, int> mv,
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
        mv: mv,
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
    required Map<String, int> mv,
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
            // 分组合计 = 各证券账户「展示余额」之和（现金 + 持仓市值）。
            totalMinor: investments.fold(
              0,
              (int s, Account a) => s + displayBalanceWithMarket(a, mv),
            ),
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

  /// 分组头部小图标：一眼区分五类资产属性。
  static IconData _iconOf(String title) => switch (title) {
        '资金类' => Icons.wallet_outlined,
        '负债类' => Icons.credit_card_outlined,
        '投资类' => Icons.trending_up_outlined,
        '应收类' => Icons.south_west_outlined,
        '应付类' => Icons.north_east_outlined,
        _ => Icons.circle_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color amountColor =
        isDebt ? AppPalette.expense : Theme.of(context).colorScheme.onSurface;
    final Color iconColor = isDebt ? AppPalette.expense : AppPalette.primary;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimens.lg,
        vertical: AppDimens.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 头部：点击折叠/展开；长按头部触发分组排序
          // （显式 textPrimary——主题重构后 titleSmall 默认色太浅，浅卡上几乎不可读）
          ReorderableDelayedDragStartListener(
            index: index,
            child: InkWell(
              onTap: onToggle,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppDimens.radiusMd),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.md),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusSm,
                        ),
                      ),
                      child: Icon(_iconOf(title), size: 16, color: iconColor),
                    ),
                    const SizedBox(width: AppDimens.sm),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    MoneyText(
                      Money.fromMinor(totalMinor),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: amountColor,
                        fontWeight: FontWeight.w700,
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
    required this.onReorder,
    this.mv = const <String, int>{},
  });

  final List<Account> accounts;
  final bool isDebt;
  final String emptyHint;

  /// 证券账户的持仓市值聚合（按 accountId）；非空时用于展示「现金 + 市值」。
  final Map<String, int> mv;
  final void Function(Account) onOpenDetail;
  final void Function(Account) onEditAccount;
  final void Function(Account) onArchiveAccount;
  final void Function(Account) onDeleteAccount;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppDimens.md),
        child: EmptyState(message: emptyHint),
      );
    }

    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      padding: EdgeInsets.zero,
      onReorderItem: onReorder,
      children: <Widget>[
        for (int i = 0; i < accounts.length; i++)
          Slidable(
            key: ValueKey<String>(accounts[i].id),
            groupTag: 'account_rows',
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.42,
              children: <Widget>[
                _SlideAction(
                  icon: Icons.visibility_off_outlined,
                  label: '隐藏',
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  onPressed: () => onArchiveAccount(accounts[i]),
                ),
                _SlideAction(
                  icon: Icons.edit_outlined,
                  label: '编辑',
                  color: AppPalette.info,
                  onPressed: () => onEditAccount(accounts[i]),
                ),
                _SlideAction(
                  icon: Icons.delete_outline,
                  label: '删除',
                  color: AppPalette.danger,
                  onPressed: () => onDeleteAccount(accounts[i]),
                ),
              ],
            ),
            child: Column(
              children: <Widget>[
                // 长按整行拖动排序（替代常驻拖拽手柄，行内视觉更干净）
                ReorderableDelayedDragStartListener(
                  index: i,
                  child: ListTile(
                    // 与分组头部 Padding(spaceMd) 对齐：金额右缘同线
                    // （ListTile 默认水平 16，比头部 12 多 4px，会向左错位）
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.md,
                    ),
                    onTap: () => onOpenDetail(accounts[i]),
                    leading: ClayIconTile(
                      size: 40,
                      color: isDebt ? AppPalette.expense : AppPalette.primary,
                      child: LineIcon(
                        accountLineKind(accounts[i].type) ?? LineIconKind.star,
                        size: 20,
                        color: Color.lerp(
                          isDebt ? AppPalette.expense : AppPalette.primary,
                          Theme.of(context).colorScheme.onSurface,
                          0.22,
                        )!,
                      ),
                    ),
                    title: Text(
                      accounts[i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: _accountSubtitle(context, accounts[i]),
                    trailing: MoneyText(
                      Money.fromMinor(_accountDisplay(accounts[i])),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            // 零展示余额弱化为弱文字，突出有结余的账户
                            color: _accountDisplay(accounts[i]) == 0
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : isDebt
                                    ? AppPalette.expense
                                    : Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
                // 分隔线缩进到文字起点（12 + 头像 40 + 间距 16 = 68）
                const Divider(height: 1, indent: 68),
              ],
            ),
          ),
      ],
    );
  }

  /// 该行账户的「展示余额」：证券账户 = 现金 + 持仓市值，其余 = 现金。
  int _accountDisplay(Account a) => displayBalanceWithMarket(a, mv);

  /// 副标题：证券账户在有持仓时显示「现金 ¥X · 市值 ¥Y」拆分，
  /// 否则退化为账户类型标签。
  Widget _accountSubtitle(BuildContext context, Account a) {
    if (isSecuritiesAccount(a)) {
      final int market = mv[a.id] ?? 0;
      if (market > 0) {
        return Text(
          '现金 ${Money.fromMinor(a.balanceMinor).format()} · '
          '市值 ${Money.fromMinor(market).format()}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        );
      }
    }
    return Text(a.type.label);
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
        margin: const EdgeInsets.symmetric(horizontal: AppDimens.xs / 2),
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
    required this.onReorder,
  });

  final List<Account> accounts;
  final int lendOutMinor;
  final Map<String, int> lendOutBalances;
  final void Function(Account) onOpenDetail;
  final void Function(Account) onEditAccount;
  final void Function(Account) onArchiveAccount;
  final void Function(Account) onDeleteAccount;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty && lendOutMinor == 0) {
      return const Padding(
        padding: EdgeInsets.only(bottom: AppDimens.md),
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
            onReorder: onReorder,
          ),
        if (accounts.isNotEmpty && lendOutMinor != 0) const Divider(height: 1),
        if (lendOutMinor != 0)
          _CounterpartyBalanceBody(
            title: '借出',
            icon: Icons.handshake_outlined,
            totalMinor: lendOutMinor,
            balances: lendOutBalances,
            amountColor: AppPalette.income,
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
    required this.onReorder,
  });

  final List<Account> accounts;
  final int borrowInMinor;
  final Map<String, int> borrowInBalances;
  final void Function(Account) onOpenDetail;
  final void Function(Account) onEditAccount;
  final void Function(Account) onArchiveAccount;
  final void Function(Account) onDeleteAccount;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty && borrowInMinor == 0) {
      return const Padding(
        padding: EdgeInsets.only(bottom: AppDimens.md),
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
            onReorder: onReorder,
          ),
        if (accounts.isNotEmpty && borrowInMinor != 0) const Divider(height: 1),
        if (borrowInMinor != 0)
          _CounterpartyBalanceBody(
            title: '借入',
            icon: Icons.handshake_outlined,
            totalMinor: borrowInMinor,
            balances: borrowInBalances,
            amountColor: AppPalette.expense,
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
        // 右缘对齐分组头部（12）；左侧补 16 保持文字位置不变
        contentPadding: const EdgeInsets.only(
          left: AppDimens.lg,
          right: AppDimens.md,
        ),
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
    this.amountColor = AppPalette.income,
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
      // 右缘对齐分组头部（12），头像 x=12 与账户行一致
      contentPadding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
      leading: ClayIconTile(
        size: 40,
        color: amountColor,
        child: Icon(
          icon,
          size: 20,
          color: Color.lerp(
            amountColor,
            Theme.of(context).colorScheme.onSurface,
            0.22,
          )!,
        ),
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
          const SizedBox(width: AppDimens.xs),
          Icon(
            Icons.chevron_right,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _NetAssetsHeader extends ConsumerWidget {
  const _NetAssetsHeader({required this.value});

  final AsyncValue<int> value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final int totalAssets = ref.watch(totalAssetsProvider).valueOrNull ?? 0;
    final int totalDebt = ref.watch(totalLiabilitiesProvider).valueOrNull ?? 0;
    final int net = value.valueOrNull ?? 0;
    final TextStyle? base = value.isLoading
        ? theme.textTheme.headlineSmall?.copyWith(
            color: ForestAssetText.emphasis.withValues(alpha: 0.4),
            fontWeight: FontWeight.w600,
          )
        : theme.textTheme.headlineSmall?.copyWith(
            // 负净值（资不抵债）用暖红警示，正/零用森林绿
            color: net < 0
                ? ForestAssetSemantic.expense
                : ForestAssetText.emphasis,
            fontWeight: FontWeight.w600,
          );

    return Container(
      margin: const EdgeInsets.all(AppDimens.lg),
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        gradient: ForestAssetBg.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        boxShadow: ForestAssetElevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '净资产',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: ForestAssetText.primary.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: AppDimens.xs),
          Text(
            value.isLoading ? '--' : Money.fromMinor(net).format(),
            style: base,
          ),
          const SizedBox(height: AppDimens.md),
          // 总资产 / 总负债摘要：一眼看出净值的两个构成
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.md,
              vertical: AppDimens.sm,
            ),
            decoration: BoxDecoration(
              color:
                  Colors.white.withValues(alpha: 0.35), // ignore: no_raw_colors
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _NetHeaderItem(
                    label: '总资产',
                    amountMinor: totalAssets,
                    color: ForestAssetText.primary,
                    labelColor: ForestAssetText.secondary,
                  ),
                ),
                Expanded(
                  child: _NetHeaderItem(
                    label: '总负债',
                    amountMinor: totalDebt,
                    color: ForestAssetAccent.amberText,
                    labelColor: ForestAssetText.secondary,
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

/// 净资产卡内的「总资产 / 总负债」单项。
class _NetHeaderItem extends StatelessWidget {
  const _NetHeaderItem({
    required this.label,
    required this.amountMinor,
    required this.color,
    required this.labelColor,
  });

  final String label;
  final int amountMinor;
  final Color color;
  final Color labelColor;

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
              ?.copyWith(color: labelColor),
        ),
        const SizedBox(height: 2),
        MoneyText(
          Money.fromMinor(amountMinor),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}
