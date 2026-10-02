import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../domain/enums.dart';
import '../data/account_icon.dart';
import 'account_form_page.dart';
import 'bank_select_page.dart';

/// 新增账户页（独立页面）。
///
/// 顶部是五大分类 Tab：**资金 / 负债 / 投资 / 应收 / 应付**。
/// 选中分类后，下方列出该分类可创建的账户类型。
/// 点击具体类型后，跳转到 [AccountFormPage] 填写账户详情。
class AddAccountPage extends StatefulWidget {
  const AddAccountPage({super.key});

  @override
  State<AddAccountPage> createState() => _AddAccountPageState();
}

class _AddAccountPageState extends State<AddAccountPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const List<String> _tabs = <String>['资金', '负债', '投资', '应收', '应付'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onSelectType(AccountType type) async {
    if (type == AccountType.creditCard || type == AccountType.bankCard) {
      final String? bankName = await Navigator.of(context).push<String>(
        MaterialPageRoute<String>(
          builder: (_) => const BankSelectPage(title: '选择银行'),
        ),
      );
      if (bankName == null || !mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => AccountFormPage(
            accountType: type,
            initialBank: bankName,
          ),
        ),
      );
      return;
    }

    // 上面的分支里 push 过页面，这里再确认一次挂载状态。
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AccountFormPage(accountType: type),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新增账户'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs.map((String t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List<Widget>.generate(
          _tabs.length,
          (int index) => _TabContent(
            index: index,
            onSelect: _onSelectType,
          ),
        ),
      ),
    );
  }
}

/// 每个分类 Tab 的内容：可选类型列表。
class _TabContent extends StatelessWidget {
  const _TabContent({
    required this.index,
    required this.onSelect,
  });

  final int index;
  final ValueChanged<AccountType> onSelect;

  @override
  Widget build(BuildContext context) {
    final List<AccountType> types = _typesForTab(index);

    return ListView(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      children: <Widget>[
        Text(
          '账户类型',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppPalette.textSecondary,
              ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        if (types.isEmpty)
          const _NoTypeHint()
        else
          _Card(
            child: Column(
              children: types
                  .map(
                    (AccountType t) => _TypeOption(
                      type: t,
                      onTap: () => onSelect(t),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
      ],
    );
  }
}

/// 应收 / 应付分类没有可新建的账户类型，给出提示。
class _NoTypeHint extends StatelessWidget {
  const _NoTypeHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppPalette.textTertiary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: const Text(
        '该分类没有可新建的账户类型。'
        '应收/应付款项请在「记一笔」里通过报销、借出、借入创建。',
        style: TextStyle(color: AppPalette.textSecondary),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: child,
    );
  }
}

/// 单个账户类型选项：图标 + 名称。
class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.type,
    required this.onTap,
  });

  final AccountType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceMd,
        ),
        child: Row(
          children: <Widget>[
            Icon(accountIcon(type), size: 22, color: AppPalette.textSecondary),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Text(
                type.label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 根据 Tab 下标返回该分类下可创建的账户类型。
///
/// 顺序与 [_tabs] 严格对应：**资金 / 负债 / 投资 / 应收 / 应付**。
/// 注意：「投资账户」已从列表移除（与基金/股票/期货/现货重复）。
List<AccountType> _typesForTab(int index) => switch (index) {
      // 资金
      0 => <AccountType>[
          AccountType.cash,
          AccountType.wechat,
          AccountType.alipay,
          AccountType.bankCard,
          AccountType.providentFund,
          AccountType.medicalInsurance,
          AccountType.transitCard,
          AccountType.giftCard,
          AccountType.other,
        ],
      // 负债
      1 => <AccountType>[
          AccountType.huabei,
          AccountType.jiebei,
          AccountType.baitiao,
          AccountType.creditCard,
          AccountType.meituanMonthly,
          AccountType.douyinMonthly,
          AccountType.otherDebt,
        ],
      // 投资
      2 => <AccountType>[
          AccountType.fund,
          AccountType.stock,
          AccountType.futures,
          AccountType.spot,
        ],
      // 应收
      3 => <AccountType>[
          AccountType.reimbursement,
          AccountType.lend,
        ],
      // 应付
      4 => <AccountType>[AccountType.borrow],
      _ => <AccountType>[],
    };
