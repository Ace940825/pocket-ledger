import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocket_ledger/shared/widgets/clay_icon_tile.dart';
import 'package:pocket_ledger/shared/widgets/confirm_dialog.dart';

import 'package:pocket_ledger/theme/app_dimens.dart';
import '../../../core/errors/failures.dart';
import '../../../core/theme/forest_design_tokens.dart';
import '../../../core/utils/date_utils.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/asset_stats_settings.dart';
import '../../../routing/app_router.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/action_group.dart';
import '../../../shared/widgets/action_row.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/calendar_sheet.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/line_icon_map.dart';
import '../../../shared/widgets/line_icons.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/sheet_scaffold.dart';
import '../../../theme/app_colors.dart';
import '../../investment/providers/investment_providers.dart';
import '../../ledger/data/transaction_repository.dart';
import '../../ledger/presentation/transaction_detail_sheet.dart';
import '../../ledger/presentation/widgets/txn_slidable.dart';
import '../../ledger/providers/ledger_providers.dart';
import '../../record/presentation/account_picker_sheet.dart';
import '../../record/presentation/record_sheet.dart';
import '../../record/record_tab.dart';
import '../data/account_icon.dart';
import '../providers/accounts_providers.dart';
import 'account_ledger_grouping.dart';
import 'widgets/account_transaction_tile.dart';
import 'widgets/asset_stats_settings_sheet.dart';
import 'widgets/credit_card_info_section.dart';

/// 单个账户的资产详情页（小青账「资产详情」复刻）。
///
/// 顶部展示账户卡片（图标 / 名称 / 类型 / 编辑 / 余额/欠款），
/// 下方按「年份 -> 月份 -> 日期」层级展示账单，支持：
/// - 点击年份弹出选择器切换年份；
/// - 点击月份标题折叠/展开该月明细；
/// - 每笔交易点击进入编辑页；
/// - 底部固定「记一笔」按钮。
///
/// **有账单日的负债账户（信用卡/花呗等，`billingDay != null`）走「账单
/// 周期模式」**（对齐小青账参考稿）：
/// - 账户卡扩展为「当前欠款/可用额度 + 账单/还款日期宫格 + 分期记账」；
/// - 卡片下方常驻一条「跨年账单」说明；
/// - 月份列表按**账单周期**分组（月标题带时钟图标与「周期：x月x日–x月x日」
///   副行，收支合计即该周期账单合计）；
/// - 底栏为「记一笔 + 还款」双按钮。
/// 其余账户（含无账单日的负债账户）保持原「自然月」布局与单按钮。
class AccountLedgerPage extends ConsumerStatefulWidget {
  const AccountLedgerPage({super.key, required this.accountId, this.now});

  final String accountId;

  /// 可注入的「今天」（测试用）；为空时取 [DateTime.now]。
  final DateTime? now;

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
    final Account? account = accountAsync.valueOrNull;

    // 账单周期模式：有账单日的负债账户（信用卡/花呗等）。
    // 日期宫格、周期分组、跨年说明、双按钮都只对这类账户生效。
    final bool statementMode =
        account != null && account.type.isDebt && account.billingDay != null;

    // 周期模式的取数范围要比自然年早一个月（覆盖 1 月账单周期的跨年尾巴），
    // 见 [accountTransactionsForStatementProvider] 注释。
    final AsyncValue<List<Transaction>> txnsAsync = statementMode
        ? ref.watch(
            accountTransactionsForStatementProvider(
              (accountId: widget.accountId, year: _selectedYear),
            ),
          )
        : ref.watch(
            accountTransactionsByYearProvider(
              (accountId: widget.accountId, year: _selectedYear),
            ),
          );
    final AsyncValue<List<Account>> accountsAsync = ref.watch(accountsProvider);
    final AsyncValue<Map<String, Category>> categoriesAsync =
        ref.watch(categoryMapProvider);
    final AssetStatsSettings settings = ref.watch(assetStatsSettingsProvider);

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
            IconButton(
              tooltip: '账户操作',
              icon: const LineGlyph(Icons.more_vert),
              onPressed: () => _showActionsSheet(account),
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
        statementMode: statementMode,
      ),
      bottomNavigationBar: _bottomButtons(context, account),
    );
  }

  Widget _body(
    BuildContext context,
    Account? account,
    List<Transaction> txns,
    Map<String, String> accountNames,
    Map<String, Category> categories,
    AssetStatsSettings settings, {
    required bool statementMode,
  }) {
    if (account == null) {
      return const EmptyState(message: '账户不存在或已删除');
    }

    // 周期模式按账单周期分组（组内交易仍是其真实日期），否则按自然月。
    final List<MonthGroup> groups = statementMode
        ? groupTransactionsByStatement(
            txns,
            account.billingDay!,
            _selectedYear,
          )
        : groupTransactionsByMonth(txns);
    // 平铺模式才需要展平结果；分组模式留空，避免白算一遍。
    // 周期模式下只展平「本年 12 个账单周期内」的交易（分组结果即该集合），
    // 避免把属于上年/次年账单的尾巴混进平铺列表。
    final List<Object> flatItems = settings.groupByMonthAsset
        ? const <Object>[]
        : _flattenByDay(
            statementMode
                ? groups
                    .expand((MonthGroup g) => g.transactions)
                    .toList(growable: false)
                : txns,
          );

    void tapTransaction(Transaction t) {
      TransactionDetailSheet.show(context, t);
    }

    return TxnSlidableGroup(
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: _AccountCardHeader(
              account: account,
              now: widget.now,
              onEdit: () => _showEditor(account),
              onInstallment: () => context.push(Routes.installmentAdd),
            ),
          ),
          // 跨年账单说明：仅账单周期模式展示（信用卡/花呗等会出现
          // 「当月消费、下月出账」的跨年账单）。
          if (statementMode)
            const SliverToBoxAdapter(child: _CrossYearNoticeCard()),
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    return TxnSlidable(
                      txn: item,
                      child: AccountTransactionTile(
                        transaction: item,
                        accountNames: accountNames,
                        accountId: widget.accountId,
                        onTap: () => tapTransaction(item),
                      ),
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
      ),
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
    final CalendarSelection? sel = await CalendarSheet.show(
      context,
      mode: CalendarSheetMode.year,
      initialYear: _selectedYear,
      firstDate: DateTime(_selectedYear - 2, 1, 1),
      lastDate: DateTime(_selectedYear + 9, 12, 31),
    );
    if (sel is CalendarYear && sel.year != _selectedYear) {
      setState(() => _selectedYear = sel.year);
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

  /// 三点键 → 账户操作弹层（与报销页「更多」同款 ActionGroup 风格）。
  ///
  /// 三组：编辑/隐藏、账单迁移/金额校验、账单清理/删除账户（不带分组小标题）。
  /// 其中账单迁移/校验/清理为账户详情页落地的真实能力（报销页同款菜单多为
  /// 占位），逻辑见各 handler。
  Future<void> _showActionsSheet(Account account) async {
    final String? action = await showAppModalSheet<String>(
      context,
      title: '账户操作',
      // 条目多（3 组 6 行），小屏/大字体下可能超出弹层高度上限。
      // 注意：Column(min) 给子级传无界高度，裸 SingleChildScrollView 不会滚动、
      // 仍会溢出——必须用 ConstrainedBox 给出确定上限（ Flutter 非滚动弹层
      // 上限为屏高 9/16，扣除把手/标题/内边距/底部安全区约 0.11 后取 0.45），
      // 内容矮时照旧收缩包裹、超限时在弹层内部滚动。
      body: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.45,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ActionGroup(
                children: <Widget>[
                  ActionRow(
                    icon: const LineIcon(
                      LineIconKind.pencil,
                      size: 17,
                      color: ForestGreen.deep,
                    ),
                    title: '编辑账户',
                    subtitle: '修改名称、余额与备注',
                    onTap: () => Navigator.of(context).pop('edit'),
                  ),
                  ActionRow(
                    icon: const LineIcon(
                      LineIconKind.excludeStats,
                      size: 17,
                      color: ForestGreen.deep,
                    ),
                    title: '隐藏账户',
                    subtitle: '不再显示在账户列表，数据保留',
                    onTap: () => Navigator.of(context).pop('archive'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ActionGroup(
                children: <Widget>[
                  ActionRow(
                    icon: const LineGlyph(
                      Icons.swap_horiz,
                      size: 17,
                      color: ForestGreen.deep,
                    ),
                    title: '账单迁移',
                    subtitle: '把本账户账单挪到其他账户',
                    onTap: () => Navigator.of(context).pop('migrate'),
                  ),
                  ActionRow(
                    icon: const LineIcon(
                      LineIconKind.moneyBag,
                      size: 17,
                      color: ForestGreen.deep,
                    ),
                    title: '金额校验',
                    subtitle: '账面有偏差时一键核对',
                    onTap: () => Navigator.of(context).pop('verify'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ActionGroup(
                children: <Widget>[
                  ActionRow(
                    icon: const LineIcon(
                      LineIconKind.trash,
                      size: 17,
                      color: ForestSemantic.expense,
                    ),
                    title: '账单清理',
                    subtitle: '软删除本账户全部账单',
                    danger: true,
                    onTap: () => Navigator.of(context).pop('clear'),
                  ),
                  ActionRow(
                    icon: const LineGlyph(
                      Icons.delete_forever,
                      size: 17,
                      color: ForestSemantic.expense,
                    ),
                    title: '删除账户',
                    subtitle: '流水记录保留，此操作不可撤销',
                    danger: true,
                    onTap: () => Navigator.of(context).pop('delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    await _onAction(action, account);
  }

  Future<void> _onAction(String action, Account account) async {
    switch (action) {
      case 'edit':
        await _showEditor(account);
      case 'archive':
        await _confirmArchive(account);
      case 'migrate':
        await _migrateAccount(account);
      case 'verify':
        await _verifyBalance(account);
      case 'clear':
        await _clearAccount(account);
      case 'delete':
        await _confirmDelete(account);
    }
  }

  /// 账单迁移：把本账户名下（不含借还关联镜像）全部账单逐笔改挂到目标账户，
  /// 余额由 [TransactionRepository.updateTransaction] 统一回滚旧账户、应用
  /// 新账户，无需手动搬运。目标账户排除自身与应收/应付（派生余额）账户。
  Future<void> _migrateAccount(Account account) async {
    final List<Transaction> all =
        await ref.read(accountAllTransactionsProvider(account.id).future);
    final List<Transaction> owned = all
        .where(
          (Transaction t) =>
              t.accountId == account.id && t.sourceModule != SourceModule.lend,
        )
        .toList();
    if (owned.isEmpty) {
      if (mounted) showAppToast(context, '该账户没有可迁移的账单');
      return;
    }
    if (!mounted) return;
    final String? targetId = await showAppModalSheet<String>(
      context,
      isScrollControlled: true,
      bodyPadding: EdgeInsets.zero,
      body: AccountPickerSheet(
        title: '迁移到账户',
        showNoneRow: false,
        showSettings: false,
        filter: (List<Account> list) => list
            .where(
              (Account a) =>
                  a.type.category != AccountCategory.receivable &&
                  a.type.category != AccountCategory.payable &&
                  a.id != account.id,
            )
            .toList(),
        onConfirm: (Account? acc) => Navigator.of(context).pop(acc?.id),
      ),
    );
    if (targetId == null || !mounted) return;
    final Map<String, String> names = <String, String>{
      for (final Account a
          in ref.read(accountsProvider).valueOrNull ?? <Account>[])
        a.id: a.name,
    };
    final String targetName = names[targetId] ?? '目标账户';
    final bool? ok = await showConfirm(
      context,
      title: '迁移账单？',
      content: '将把本账户 ${owned.length} 笔账单迁移至「$targetName」，'
          '余额自动跟随调整。',
      confirmText: '迁移',
    );
    if (ok != true || !mounted) return;
    try {
      final TransactionRepository repo =
          ref.read(transactionRepositoryProvider);
      for (final Transaction t in owned) {
        await repo.updateTransaction(original: t, accountId: targetId);
      }
      if (mounted) showAppToast(context, '已迁移 ${owned.length} 笔');
    } on AppFailure catch (e) {
      if (mounted) showAppToast(context, e.message);
    }
  }

  /// 金额校验：用与余额增量公式严格一致的口径重算本账户现金余额，与存储值
  /// 比较；不一致时二次确认后写回期望值并同步。借还账户按借还记录合计比对。
  Future<void> _verifyBalance(Account account) async {
    final String bookId = ref.read(currentBookIdProvider);
    try {
      final (int expected, int stored, bool fixed) =
          await ref.read(transactionRepositoryProvider).verifyAccountBalance(
                accountId: account.id,
                bookId: bookId,
                fix: false,
              );
      if (expected == stored) {
        if (mounted) showAppToast(context, '账面校验完成，无偏差');
        return;
      }
      final int diff = expected - stored;
      final bool? ok = await showConfirm(
        context,
        title: '发现偏差',
        content: '账面余额与流水重算相差 '
            '${Money.fromMinor(diff.abs()).format()}'
            '（重算应为 ${Money.fromMinor(expected).format()}）。是否校正？',
        confirmText: '校正',
      );
      if (ok != true || !mounted) return;
      final (int _, int _, bool done) =
          await ref.read(transactionRepositoryProvider).verifyAccountBalance(
                accountId: account.id,
                bookId: bookId,
                fix: true,
              );
      if (mounted) {
        showAppToast(
          context,
          done ? '已校正 ${Money.fromMinor(diff.abs()).format()}' : '校正失败',
        );
      }
    } on AppFailure catch (e) {
      if (mounted) showAppToast(context, e.message);
    }
  }

  /// 账单清理：软删除本账户名下（不含借还关联镜像）全部账单，余额由
  /// [TransactionRepository.remove] 自动回滚；借还关联与持仓由该仓储级联处理。
  Future<void> _clearAccount(Account account) async {
    final List<Transaction> all =
        await ref.read(accountAllTransactionsProvider(account.id).future);
    final List<Transaction> owned = all
        .where(
          (Transaction t) =>
              t.accountId == account.id && t.sourceModule != SourceModule.lend,
        )
        .toList();
    if (owned.isEmpty) {
      if (mounted) showAppToast(context, '该账户没有可清理的账单');
      return;
    }
    if (!mounted) return;
    final bool? ok = await showConfirm(
      context,
      title: '清理全部账单？',
      content: '将软删除本账户 ${owned.length} 笔账单，余额自动回滚'
          '（数据保留，可后续恢复）。',
      confirmText: '清理',
    );
    if (ok != true || !mounted) return;
    try {
      final TransactionRepository repo =
          ref.read(transactionRepositoryProvider);
      for (final Transaction t in owned) {
        await repo.remove(t.id);
      }
      if (mounted) showAppToast(context, '已清理 ${owned.length} 笔');
    } on AppFailure catch (e) {
      if (mounted) showAppToast(context, e.message);
    }
  }

  /// 编辑入口：统一跳转账户编辑页（借还账户余额派生只读、
  /// 状态/计入总资产在「其他」区块内维护）。
  Future<void> _showEditor(Account account) async {
    await context.push('/accounts/${account.id}/edit');
  }

  Future<void> _confirmArchive(Account account) async {
    final bool? ok = await showConfirm(
      context,
      title: '隐藏账户？',
      content: '「${account.name}」将不再显示在账户列表中，'
          '流水与数据保留，后续可在「已隐藏」中恢复。',
      confirmText: '隐藏',
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(accountRepositoryProvider).archive(account.id);
      if (mounted) {
        context.pop();
      }
    } on AppFailure catch (e) {
      if (mounted) {
        showAppToast(context, e.message);
      }
    }
  }

  Future<void> _confirmDelete(Account account) async {
    final bool? confirmed = await showConfirm(
      context,
      title: '删除账户？',
      content: '「${account.name}」将被删除。该账户的流水记录会保留，'
          '但不再计入资产负债。此操作不可撤销。',
      confirmText: '删除',
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(accountRepositoryProvider).remove(account.id);
      if (mounted) {
        context.pop();
      }
    } on AppFailure catch (e) {
      if (mounted) {
        showAppToast(context, e.message);
      }
    }
  }

  /// 底部操作条：
  /// - 负债方向账户（信用卡/花呗/借入等）：「记一笔 + 还款」双按钮
  ///   （对齐小青账参考稿；「还款」= 记一笔转账 Tab 且转入账户预填本账户）；
  /// - 其余账户：单「记一笔」按钮（借出/借入账户直接进借还 Tab）。
  Widget _bottomButtons(BuildContext context, Account? account) {
    final bool isLendAccount = account != null &&
        (account.type == AccountType.lend ||
            account.type == AccountType.borrow);
    // 记一笔按钮（两种布局共用）。
    final Widget recordButton = _bottomPillButton(
      context: context,
      label: '记一笔',
      filled: false,
      onPressed: () => openRecordSheet(
        context,
        initialTab: isLendAccount ? RecordTab.lend : RecordTab.expense,
      ),
    );

    if (account == null || !account.type.isLiabilitySide) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.lg,
            AppDimens.sm,
            AppDimens.lg,
            AppDimens.lg,
          ),
          child: recordButton,
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.lg,
          AppDimens.sm,
          AppDimens.lg,
          AppDimens.lg,
        ),
        child: Row(
          children: <Widget>[
            Expanded(child: recordButton),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: _bottomPillButton(
                context: context,
                label: '还款',
                filled: true,
                onPressed: () => openRecordSheet(
                  context,
                  initialTab: RecordTab.transfer,
                  initialTransferToAccountId: account.id,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 底栏胶囊按钮：filled = 品牌绿实底（主操作），否则描边空心。
  Widget _bottomPillButton({
    required BuildContext context,
    required String label,
    required bool filled,
    required VoidCallback onPressed,
  }) {
    final ThemeData theme = Theme.of(context);
    final Widget child = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.md),
      child: Text(label),
    );
    final BorderRadius radius =
        BorderRadius.circular(AppDimens.radiusChip);
    if (filled) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.primary,
          foregroundColor: Colors.white, // ignore: no_raw_colors
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
        child: child,
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurface,
        side: BorderSide(color: theme.colorScheme.outline),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      child: child,
    );
  }
}

/// 顶部的账户卡片。
///
/// 有账单日的负债账户（信用卡/花呗等）在头部之下再挂一节
/// [CreditCardInfoSection]（欠款/可用额度 + 日期宫格 + 分期记账），
/// 与信用卡还款页完全同款；其余账户维持「标签 + 大数」原布局。
class _AccountCardHeader extends ConsumerWidget {
  const _AccountCardHeader({
    required this.account,
    required this.onEdit,
    required this.onInstallment,
    this.now,
  });

  final Account account;
  final VoidCallback onEdit;

  /// 「分期记账」入口（仅账单周期模式展示）。
  final VoidCallback onInstallment;

  /// 可注入的「今天」（测试用）；为空时取 [DateTime.now]。
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final bool isDebt = account.type.isDebt;
    // 账单周期模式：有账单日的负债账户（与页面级 statementMode 同口径）。
    final bool statementMode = isDebt && account.billingDay != null;
    // 证券账户：展示余额 = 现金 + 持仓市值；其余账户即现金余额。
    final Map<String, int> mv =
        ref.watch(investmentMarketValueByAccountProvider);
    final int display = displayBalanceWithMarket(account, mv);
    final int market = isSecuritiesAccount(account) ? (mv[account.id] ?? 0) : 0;
    final Color cardColor = theme.colorScheme.surface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.lg,
        AppDimens.md,
        AppDimens.lg,
        AppDimens.md,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Theme.of(context)
                  .colorScheme
                  .shadow
                  .withValues(alpha: isDark ? 0.28 : 0.045),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  ClayIconTile(
                    size: 36,
                    color: AppPalette.primary,
                    child: LineIcon(
                      accountLineKind(account.type) ?? LineIconKind.star,
                      size: 18,
                      color: Color.lerp(
                        AppPalette.primary,
                        Theme.of(context).colorScheme.onSurface,
                        0.22,
                      )!,
                    ),
                  ),
                  const SizedBox(width: AppDimens.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          account.type.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 编辑胶囊：与报销/借还账户卡同款（浅底圆角 12）。
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
                      child: Text(
                        '编辑',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (statementMode) ...<Widget>[
                const SizedBox(height: AppDimens.md),
                // 欠款/可用额度 + 日期宫格 + 分期记账（与信用卡还款页共用）。
                CreditCardInfoSection(
                  account: account,
                  now: now,
                  onInstallment: onInstallment,
                ),
              ] else ...<Widget>[
                const SizedBox(height: AppDimens.md),
                Text(
                  switch (account.type) {
                    // 借出/借入账户按小青账口径展示本金净额（= 名下未结清合计）
                    AccountType.borrow => '未还本金',
                    AccountType.lend => '未收本金',
                    _ => isDebt ? '当前欠款' : '当前余额',
                  },
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppDimens.xs),
                MoneyText(
                  Money.fromMinor(display),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDebt ? AppPalette.expense : null,
                  ),
                ),
                if (market > 0) ...<Widget>[
                  const SizedBox(height: AppDimens.xs),
                  Text(
                    '现金 ${Money.fromMinor(account.balanceMinor).format()} · '
                    '市值 ${Money.fromMinor(market).format()}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 「跨年账单」说明卡（仅账单周期模式展示，对齐小青账参考稿）：
/// 信用卡、花呗等会出现跨年的账单，当月账单下月才会出账单。
class _CrossYearNoticeCard extends StatelessWidget {
  const _CrossYearNoticeCard();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(
        left: AppDimens.lg,
        right: AppDimens.lg,
        top: AppDimens.sm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.sm,
        vertical: AppDimens.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LineGlyph(
            Icons.info_outline,
            size: 14,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppDimens.xs),
          Expanded(
            child: Text(
              '信用卡、花呗等会出现跨年的账单，当月账单下月才会出账单，'
              '如2022年出现2021年12月份账单。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.only(
        left: AppDimens.lg,
        right: AppDimens.lg,
        top: AppDimens.sm,
        bottom: AppDimens.xs,
      ),
      child: Row(
        children: <Widget>[
          InkWell(
            onTap: onPickYear,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.sm,
                vertical: AppDimens.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '$year年',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(width: 4),
                  LineGlyph(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onOpenSettings,
            icon: const LineGlyph(Icons.settings_outlined),
            tooltip: '资产月消费统计',
          ),
        ],
      ),
    );
  }
}

/// 按月（或按账单周期）分组的账单区域。
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
    final DateTime? periodStart = group.periodStart;
    final DateTime? periodEnd = group.periodEnd;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.lg,
              vertical: AppDimens.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    LineGlyph(
                      collapsed ? Icons.chevron_right : Icons.expand_more,
                      size: 20,
                    ),
                    const SizedBox(width: AppDimens.xs),
                    Text(
                      '${group.month.month}月',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '支出 ${Money.fromMinor(stats.expenseMinor).format()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppPalette.expense,
                      ),
                    ),
                    const SizedBox(width: AppDimens.md),
                    Text(
                      '收入 ${Money.fromMinor(stats.incomeMinor).format()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppPalette.income,
                      ),
                    ),
                  ],
                ),
                if (periodStart != null && periodEnd != null) ...<Widget>[
                  const SizedBox(height: 1),
                  // 与月标题左缘对齐（折叠箭头 20 + 间距 4）。
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Text(
                      '周期：${_fmtPeriodDate(periodStart)}–${_fmtPeriodDate(periodEnd)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (!collapsed) ...<Widget>[
          _MonthSummary(stats: stats),
          ..._buildDays(context),
        ],
        const Divider(height: 1, indent: AppDimens.lg),
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
          TxnSlidable(
            txn: t,
            child: AccountTransactionTile(
              transaction: t,
              accountNames: accountNames,
              accountId: accountId,
              onTap: () => onTapTransaction(t),
            ),
          ),
        );
      }
    }
    return widgets;
  }
}

/// 账单周期副行的日期格式：同年省略年份（`9月2日`），跨年带年份
/// （`2025年12月2日`）——1 月账单周期必然跨年，必须可辨。
String _fmtPeriodDate(DateTime d) => d.month == 1 || d.month == 12
    ? '${d.year}年${d.month}月${d.day}日'
    : '${d.month}月${d.day}日';

/// 日期小标题（如「9月10日 昨天 星期四」）。分组模式与平铺模式共用。
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.dateAt});

  /// 该日 00:00 的 UTC 毫秒时间戳。
  final int dateAt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.lg,
        AppDimens.xs,
        AppDimens.lg,
        AppDimens.xs,
      ),
      child: Text(
        accountLedgerDateLabel(dateAt),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        horizontal: AppDimens.lg,
        vertical: AppDimens.xs,
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
