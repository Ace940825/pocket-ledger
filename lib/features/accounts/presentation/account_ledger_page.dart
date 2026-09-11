import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/date_utils.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../routing/app_router.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/money_text.dart';
import '../data/account_icon.dart';
import '../../../providers/asset_stats_settings.dart';
import '../providers/accounts_providers.dart';
import 'account_ledger_grouping.dart';
import 'widgets/account_transaction_tile.dart';
import 'widgets/asset_stats_settings_sheet.dart';
import 'widgets/year_picker_sheet.dart';

/// 单个账户的资产详情页（小青账「资产详情」复刻）。
///
/// 顶部展示账户卡片（图标 / 名称 / 类型 / 编辑 / 余额/欠款），
/// 下方按「年份 -> 月份 -> 日期」层级展示账单，支持：
/// - 点击年份弹出选择器切换年份；
/// - 点击月份标题折叠/展开该月明细；
/// - 每笔交易点击进入编辑页；
/// - 底部固定「记一笔」按钮。
class AccountLedgerPage extends ConsumerStatefulWidget {
  const AccountLedgerPage({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<AccountLedgerPage> createState() => _AccountLedgerPageState();
}

class _AccountLedgerPageState extends ConsumerState<AccountLedgerPage> {
  late int _selectedYear;
  final Set<String> _collapsedMonths = <String>{};

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Account?> accountAsync =
        ref.watch(accountByIdProvider(widget.accountId));
    final AsyncValue<List<Transaction>> txnsAsync = ref.watch(
      accountTransactionsByYearProvider(
        (accountId: widget.accountId, year: _selectedYear),
      ),
    );
    final AsyncValue<List<Account>> accountsAsync = ref.watch(accountsProvider);
    final AsyncValue<Map<String, Category>> categoriesAsync =
        ref.watch(categoryMapProvider);
    final AssetStatsSettings settings = ref.watch(assetStatsSettingsProvider);

    final Account? account = accountAsync.valueOrNull;
    final List<Transaction> txns = txnsAsync.valueOrNull ?? <Transaction>[];
    final Map<String, String> accountNames = <String, String>{
      for (final Account a in accountsAsync.valueOrNull ?? <Account>[])
        a.id: a.name,
    };
    final Map<String, Category> categories =
        categoriesAsync.valueOrNull ?? <String, Category>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text('资产详情'),
        actions: <Widget>[
          if (account != null)
            PopupMenuButton<String>(
              onSelected: (String value) => _onAction(value, account),
              itemBuilder: (BuildContext context) =>
                  const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Text('编辑账户'),
                ),
                PopupMenuItem<String>(
                  value: 'archive',
                  child: Text('隐藏账户'),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('删除账户'),
                ),
              ],
            ),
        ],
      ),
      body: _body(
        context,
        account,
        txns,
        accountNames,
        categories,
        settings,
      ),
      bottomNavigationBar: _bottomButton(context),
    );
  }

  Widget _body(
    BuildContext context,
    Account? account,
    List<Transaction> txns,
    Map<String, String> accountNames,
    Map<String, Category> categories,
    AssetStatsSettings settings,
  ) {
    if (account == null) {
      return const EmptyState(message: '账户不存在或已删除');
    }

    final List<MonthGroup> groups = groupTransactionsByMonth(txns);
    // 平铺模式才需要展平结果；分组模式留空，避免白算一遍。
    final List<Object> flatItems =
        settings.groupByMonthAsset ? const <Object>[] : _flattenByDay(txns);

    void tapTransaction(Transaction t) {
      context.push('/ledger/edit/${t.id}');
    }

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: _AccountCardHeader(
            account: account,
            onEdit: () => _showEditor(account),
          ),
        ),
        SliverToBoxAdapter(
          child: _YearSelectorRow(
            year: _selectedYear,
            onPickYear: _pickYear,
            onOpenSettings: () => AssetStatsSettingsSheet.show(context),
          ),
        ),
        if (groups.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                '$_selectedYear年暂无流水',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
          )
        else if (!settings.groupByMonthAsset)
          // 「账单列表按年月分组 · 资产账户」关闭：整年平铺，
          // 只保留日期小标题，不显示月标题与月汇总条。
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                final Object item = flatItems[index];
                if (item is DayGroup) {
                  return _DayHeader(dateAt: item.dateAt);
                }
                if (item is Transaction) {
                  return AccountTransactionTile(
                    transaction: item,
                    accountNames: accountNames,
                    onTap: () => tapTransaction(item),
                  );
                }
                // _flattenByDay 只会产出上面两种元素，这里只是兜底。
                return const SizedBox.shrink();
              },
              childCount: flatItems.length,
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                final MonthGroup group = groups[index];
                final String key = monthKey(group.month);
                return _MonthSection(
                  group: group,
                  accountId: widget.accountId,
                  accountNames: accountNames,
                  categories: categories,
                  settings: settings,
                  collapsed: _collapsedMonths.contains(key),
                  onToggle: () => _toggleMonth(key),
                  onTapTransaction: tapTransaction,
                );
              },
              childCount: groups.length,
            ),
          ),
      ],
    );
  }

  /// 把流水展平成「日期小标题 + 交易行」的序列，供平铺模式使用。
  ///
  /// 元素只有两种：`DayGroup`（代表一个日期小标题）与 `Transaction`（一笔交易）。
  List<Object> _flattenByDay(List<Transaction> txns) {
    final List<Object> flat = <Object>[];
    for (final DayGroup day in groupTransactionsByDay(txns)) {
      flat.add(day);
      flat.addAll(day.transactions);
    }
    return flat;
  }

  Future<void> _pickYear() async {
    final int? year = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => YearPickerSheet(
        initialYear: _selectedYear,
        minYear: _selectedYear - 2,
        maxYear: _selectedYear + 9,
      ),
    );
    if (year != null && year != _selectedYear) {
      setState(() => _selectedYear = year);
    }
  }

  void _toggleMonth(String monthKey) {
    setState(() {
      if (_collapsedMonths.contains(monthKey)) {
        _collapsedMonths.remove(monthKey);
      } else {
        _collapsedMonths.add(monthKey);
      }
    });
  }

  Future<void> _onAction(String action, Account account) async {
    switch (action) {
      case 'edit':
        await _showEditor(account);
      case 'archive':
        await _confirmArchive(account);
      case 'delete':
        await _confirmDelete(account);
    }
  }

  Future<void> _showEditor(Account account) async {
    final TextEditingController nameController =
        TextEditingController(text: account.name);
    final TextEditingController balanceController = TextEditingController(
      text: Money.fromMinor(account.balanceMinor).decimal.toStringAsFixed(2),
    );
    AccountType type = account.type;

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
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
                decoration: InputDecoration(
                  labelText: type.isDebt ? '当前欠款' : '余额',
                  prefixText: '¥ ',
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              DropdownButtonFormField<AccountType>(
                initialValue: type,
                decoration: const InputDecoration(labelText: '账户类型'),
                items: AccountType.values
                    .where((AccountType t) => t != AccountType.borrow)
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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _confirmArchive(Account account) async {
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
    if (ok != true || !mounted) return;
    try {
      await ref.read(accountRepositoryProvider).archive(account.id);
      if (mounted) {
        context.pop();
      }
    } on AppFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _confirmDelete(Account account) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('删除账户？'),
        content: Text(
          '「${account.name}」将被删除。该账户的流水记录会保留，'
          '但不再计入资产负债。此操作不可撤销。',
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

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(accountRepositoryProvider).remove(account.id);
      if (mounted) {
        context.pop();
      }
    } on AppFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Widget _bottomButton(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.spaceLg,
          AppDimens.spaceSm,
          AppDimens.spaceLg,
          AppDimens.spaceLg,
        ),
        child: FilledButton(
          onPressed: () => context.push(Routes.ledgerAdd),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: AppDimens.spaceMd),
            child: Text('记一笔'),
          ),
        ),
      ),
    );
  }
}

/// 顶部的账户卡片。
class _AccountCardHeader extends StatelessWidget {
  const _AccountCardHeader({required this.account, required this.onEdit});

  final Account account;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final bool isDebt = account.type.isDebt;
    final Color cardColor = isDark ? const Color(0xFF1B1F24) : Colors.white;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceMd,
        AppDimens.spaceLg,
        AppDimens.spaceMd,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.28 : 0.045),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(
                        isDark ? 0.18 : 0.12,
                      ),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      accountIcon(account.type),
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          account.type.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: onEdit,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      '编辑',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.spaceLg),
              Text(
                isDebt ? '当前欠款(元)' : '当前余额(元)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppDimens.spaceXs),
              MoneyText(
                Money.fromMinor(account.balanceMinor),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDebt ? AppColors.expense : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 年份选择行：左侧点年份切换年份，右侧齿轮打开「资产月消费统计」。
class _YearSelectorRow extends StatelessWidget {
  const _YearSelectorRow({
    required this.year,
    required this.onPickYear,
    required this.onOpenSettings,
  });

  final int year;
  final VoidCallback onPickYear;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceLg,
        vertical: AppDimens.spaceMd,
      ),
      child: Row(
        children: <Widget>[
          InkWell(
            onTap: onPickYear,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceSm,
                vertical: AppDimens.spaceXs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '$year年',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, size: 20),
                ],
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_outlined),
            tooltip: '资产月消费统计',
          ),
        ],
      ),
    );
  }
}

/// 按月分组的账单区域。
class _MonthSection extends StatelessWidget {
  const _MonthSection({
    required this.group,
    required this.accountId,
    required this.accountNames,
    required this.categories,
    required this.settings,
    required this.collapsed,
    required this.onToggle,
    required this.onTapTransaction,
  });

  final MonthGroup group;

  /// 当前正在查看的账户，`computeMonthStats` 需要它来判定转账方向。
  final String accountId;
  final Map<String, String> accountNames;
  final Map<String, Category> categories;
  final AssetStatsSettings settings;
  final bool collapsed;
  final VoidCallback onToggle;
  final void Function(Transaction) onTapTransaction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MonthStats stats = computeMonthStats(
      group.transactions,
      settings,
      accountId: accountId,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceLg,
              vertical: AppDimens.spaceMd,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  collapsed ? Icons.chevron_right : Icons.expand_more,
                  size: 20,
                ),
                const SizedBox(width: AppDimens.spaceXs),
                Text(
                  '${group.month.month}月',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '支出 ${Money.fromMinor(stats.expenseMinor).format()}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.expense,
                  ),
                ),
                const SizedBox(width: AppDimens.spaceMd),
                Text(
                  '收入 ${Money.fromMinor(stats.incomeMinor).format()}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.income,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!collapsed) ...<Widget>[
          _MonthSummary(stats: stats),
          ..._buildDays(context),
        ],
        const Divider(height: 1, indent: AppDimens.spaceLg),
      ],
    );
  }

  List<Widget> _buildDays(BuildContext context) {
    final List<DayGroup> days = groupTransactionsByDay(group.transactions);
    final List<Widget> widgets = <Widget>[];
    for (final DayGroup day in days) {
      widgets.add(_DayHeader(dateAt: day.dateAt));
      for (final Transaction t in day.transactions) {
        widgets.add(
          AccountTransactionTile(
            transaction: t,
            accountNames: accountNames,
            onTap: () => onTapTransaction(t),
          ),
        );
      }
    }
    return widgets;
  }
}

/// 日期小标题（如「9月10日 昨天 星期四」）。分组模式与平铺模式共用。
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.dateAt});

  /// 该日 00:00 的 UTC 毫秒时间戳。
  final int dateAt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceMd,
        AppDimens.spaceLg,
        AppDimens.spaceXs,
      ),
      child: Text(
        accountLedgerDateLabel(dateAt),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
      ),
    );
  }
}

/// 当月汇总条：`支出:… 收入:… 其他:… 结余:…`。
///
/// - **结余** = 支出 − 收入（口径见 [MonthStats.balanceMinor]，支出在前）。
/// - 两个收支开关都打开时，「其他」已无独立含义，**整项隐藏**
///   （只显示 `支出:… 收入:… 结余:…`），由 [MonthStats.showOther] 决定。
class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.stats});

  final MonthStats stats;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String expense = Money.fromMinor(stats.expenseMinor).format();
    final String income = Money.fromMinor(stats.incomeMinor).format();
    final String other = Money.fromMinor(stats.otherMinor).format();
    final String balance = Money.fromMinor(stats.balanceMinor).format();

    final String text = stats.showOther
        ? '支出:$expense 收入:$income 其他:$other 结余:$balance'
        : '支出:$expense 收入:$income 结余:$balance';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceLg,
        vertical: AppDimens.spaceSm,
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
