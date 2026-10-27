import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/accounts/data/account_icon.dart';
import 'package:pocket_ledger/features/accounts/providers/accounts_providers.dart';
import 'package:pocket_ledger/features/investment/providers/investment_providers.dart';
import 'package:pocket_ledger/providers/app_providers.dart';
import 'package:pocket_ledger/shared/models/money.dart';
import 'package:pocket_ledger/shared/widgets/app_toast.dart';
import 'package:pocket_ledger/shared/widgets/clay_icon_tile.dart';
import 'package:pocket_ledger/shared/widgets/line_icons.dart';
import 'package:pocket_ledger/shared/widgets/money_text.dart';
import 'package:pocket_ledger/theme/app_colors.dart';
import 'package:pocket_ledger/theme/app_dimens.dart';

/// 资产排序页：扁平列出当前账本**指定范围的账户**（不分资金类/负债类等分组），
/// 长按拖动调整顺序，点底部「保存」按分类回写各自的 [Account.sortOrder]。
///
/// 排序范围按进入页区分：
/// - [filterStatus] == null：从账户页进入，排 active（使用中）账户；
/// - [filterStatus] == [AccountStatus.hidden]：从隐藏资产页进入，排隐藏账户；
/// - [filterStatus] == [AccountStatus.sealed]：从封存资产页进入，排封存账户。
///
/// 回写策略：各组内部按 sortOrder 升序展示，组间顺序不影响视觉；故保存时把扁平
/// 顺序「拆解」回各分类的子序列，分别调用 [AccountsDao.reorder] 重排本组。
/// 不同状态（active/hidden/sealed）的 sortOrder 序列互不干扰——查询时按 status
/// 过滤，reorder 只更新当前列表内账户的 sortOrder 值。
class AccountSortPage extends ConsumerStatefulWidget {
  const AccountSortPage({super.key, this.filterStatus});

  /// 排序范围：null = 正常账户页（active），hidden = 隐藏资产页，sealed = 封存资产页。
  final AccountStatus? filterStatus;

  @override
  ConsumerState<AccountSortPage> createState() => _AccountSortPageState();
}

class _AccountSortPageState extends ConsumerState<AccountSortPage> {
  /// 编辑中的扁平顺序；首次拿到数据后由账户列表初始化一次，之后以用户拖动为准，
  /// 不被底层流重复 emit 覆盖（避免拖动到一半被刷新打断）。
  List<Account>? _items;
  bool _saving = false;

  /// 扁平列表初始的「分类先后顺序」，与账户页默认分组顺序一致：
  /// 资金类 → 负债类 → 投资类 → 应收类 → 应付类。
  static const Map<AccountCategory, int> _categoryRank = <AccountCategory, int>{
    AccountCategory.capital: 0,
    AccountCategory.debt: 1,
    AccountCategory.investment: 2,
    AccountCategory.receivable: 3,
    AccountCategory.payable: 4,
  };

  List<Account> _initList(List<Account> list) {
    final List<Account> sorted = List<Account>.from(list);
    sorted.sort((Account a, Account b) {
      final int ra = _categoryRank[a.type.category] ?? 99;
      final int rb = _categoryRank[b.type.category] ?? 99;
      if (ra != rb) return ra.compareTo(rb);
      return a.sortOrder.compareTo(b.sortOrder);
    });
    return sorted;
  }

  Future<void> _save() async {
    if (_items == null || _items!.isEmpty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    try {
      // 按分类拆解扁平顺序，分别回写各组的 sortOrder。
      final Map<AccountCategory, List<String>> byCat =
          <AccountCategory, List<String>>{};
      for (final Account a in _items!) {
        byCat.putIfAbsent(a.type.category, () => <String>[]).add(a.id);
      }
      final dao = ref.read(accountsDaoProvider);
      for (final List<String> ids in byCat.values) {
        await dao.reorder(ids);
      }
      if (mounted) {
        showAppToast(context, '排序已保存');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, '保存失败：$e');
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 根据来源页选择对应的账户列表 provider：
    // - 默认（账户页）→ accountsProvider（active）
    // - 隐藏页进入 → hiddenAccountsProvider
    // - 封存页进入 → sealedAccountsProvider
    final AsyncValue<List<Account>> accountsAv = switch (widget.filterStatus) {
      AccountStatus.hidden => ref.watch(hiddenAccountsProvider),
      AccountStatus.sealed => ref.watch(sealedAccountsProvider),
      _ => ref.watch(accountsProvider),
    };
    final Map<String, int> mv =
        ref.watch(investmentMarketValueByAccountProvider);

    final String title = switch (widget.filterStatus) {
      AccountStatus.hidden => '隐藏资产排序',
      AccountStatus.sealed => '封存资产排序',
      _ => '资产排序',
    };

    final String emptyHint = switch (widget.filterStatus) {
      AccountStatus.hidden => '还没有隐藏的账户',
      AccountStatus.sealed => '还没有封存的账户',
      _ => '还没有账户，去添加吧',
    };

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: accountsAv.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(child: Text('加载失败：$e')),
        data: (List<Account> list) {
          // 首次进入用当前账户顺序初始化；之后保留用户拖动结果。
          _items ??= _initList(list);
          if (_items!.isEmpty) {
            return Center(child: Text(emptyHint));
          }
          return _buildBody(context, mv);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, Map<String, int> mv) {
    final ThemeData theme = Theme.of(context);
    return Stack(
      children: <Widget>[
        Column(
          children: <Widget>[
            const _HintBar(),
            Expanded(
              child: ReorderableListView(
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.only(
                  left: AppDimens.lg,
                  right: AppDimens.lg,
                  bottom: 96,
                ),
                onReorderItem: (int oldIndex, int newIndex) {
                  setState(() {
                    final Account moved = _items!.removeAt(oldIndex);
                    _items!.insert(newIndex, moved);
                  });
                },
                children: <Widget>[
                  for (int i = 0; i < _items!.length; i++)
                    _AccountRow(
                      key: ValueKey<String>(_items![i].id),
                      account: _items![i],
                      index: i,
                      marketValue: mv,
                    ),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: AppDimens.lg,
          child: SafeArea(
            top: false,
            child: Center(child: _saveButton(theme)),
          ),
        ),
      ],
    );
  }

  Widget _saveButton(ThemeData theme) {
    return SizedBox(
      width: 200,
      height: 48,
      child: ElevatedButton(
        onPressed: _saving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          disabledBackgroundColor: AppPalette.primary.withValues(alpha: 0.5),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
        ),
        child: _saving
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.onPrimary,
                ),
              )
            : Text(
                '保存',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

/// 顶部提示条：复刻参考图的「长按 拖动排序哦」灰底信息条。
class _HintBar extends StatelessWidget {
  const _HintBar();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDimens.lg,
        AppDimens.md,
        AppDimens.lg,
        AppDimens.sm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.md,
        vertical: AppDimens.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.info_outline,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppDimens.sm),
          Text(
            '长按 拖动排序哦',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 单个账户行：图标 + 名称 + 类型副标题 + 右侧金额（负债强制红色，0 弱化为灰）。
///
/// 长按整行进入拖动（与账户页一致，省去常驻拖拽手柄，列表更干净）。
class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required super.key,
    required this.account,
    required this.index,
    required this.marketValue,
  });

  final Account account;
  final int index;
  final Map<String, int> marketValue;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDebt = account.type.isDebt;
    final int display = displayBalanceWithMarket(account, marketValue);
    final Color accent = isDebt ? AppPalette.expense : AppPalette.primary;

    return Column(
      children: <Widget>[
        ReorderableDelayedDragStartListener(
          index: index,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppDimens.md,
            ),
            leading: ClayIconTile(
              size: 40,
              color: accent,
              child: LineIcon(
                accountLineKind(account.type) ?? LineIconKind.star,
                size: 20,
                color: Color.lerp(
                  accent,
                  context.forest.onSurface,
                  0.22,
                )!,
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
            subtitle: Text(account.type.label),
            trailing: MoneyText(
              Money.fromMinor(display),
              // 零展示余额弱化为弱文字；负债（信用卡/借入）强制支出红，
              // 避免被 MoneyText 自动正负着色渲染成收入绿；其余按正负自动。
              color: display == 0
                  ? context.forest.onSurfaceVariant
                  : isDebt
                      ? AppPalette.expense
                      : null,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const Divider(height: 1, indent: 68),
      ],
    );
  }
}
