import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/account_icon.dart';
import '../providers/accounts_providers.dart';

/// 编辑账户页（参照小青账编辑逻辑），按账户类型分流两种布局：
///
/// - **借出 / 借入（应收 / 应付）**：基本信息「借款给谁 / 向谁借」+
///   **借出 / 借入金额**（派生余额，只读展示——由名下未结清借还记录
///   自动计算，保存时仓储层同事务重算，不可手改）；
/// - **借记卡（银行账户）**：「资产类型」卡（银行图标 + 银行名，点击改名）+
///   基本信息（备注信息 / 银行卡号）+ **资金**（账户余额可手动校正）；
/// - 共用「其他」：**资产状态** 三态胶囊（使用中 / 隐藏 / 封存）+
///   **计入总资产** 开关；底部整宽「保存」按钮。
class AccountEditPage extends ConsumerStatefulWidget {
  const AccountEditPage({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<AccountEditPage> createState() => _AccountEditPageState();
}

class _AccountEditPageState extends ConsumerState<AccountEditPage> {
  late final TextEditingController _nameController;
  // 借记卡模式专用：备注 / 卡号 / 余额（余额为真实值，允许手动校正）。
  late final TextEditingController _noteController;
  late final TextEditingController _cardNumberController;
  late final TextEditingController _balanceController;
  late AccountStatus _status;
  late bool _includeInTotal;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final Account? account =
        ref.watch(accountByIdProvider(widget.accountId)).valueOrNull;

    if (account == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _ensureInitialized(account);
    final bool isLend = account.type == AccountType.lend;
    final bool isDebit = account.type == AccountType.bankCard;

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑账户'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppDimens.spaceLg),
              children: isDebit
                  ? _debitSections(account)
                  : _lendSections(account, isLend),
            ),
          ),
          _saveButton(account),
        ],
      ),
    );
  }

  // ---- 借出 / 借入（应收 / 应付）布局 ----

  List<Widget> _lendSections(Account account, bool isLend) => <Widget>[
        _sectionLabel('基本信息'),
        _Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _fieldLabel(isLend ? '借款给谁' : '向谁借'),
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.done,
                  decoration: _filledDecoration(),
                ),
                const SizedBox(height: AppDimens.spaceMd),
                _fieldLabel(isLend ? '借出金额' : '借入金额'),
                _readOnlyAmount(account.balanceMinor),
                const SizedBox(height: AppDimens.spaceXs),
                Text(
                  '由名下未结清借还记录自动计算，不可手动修改',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimens.spaceLg),
        _otherSection(),
      ];

  // ---- 借记卡（银行账户）布局，参照小青账截图 ----

  List<Widget> _debitSections(Account account) => <Widget>[
        _sectionLabel('资产类型'),
        _assetTypeCard(account),
        const SizedBox(height: AppDimens.spaceLg),
        _sectionLabel('基本信息'),
        _Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _fieldLabel('备注信息'),
                TextField(
                  controller: _noteController,
                  textInputAction: TextInputAction.next,
                  decoration: _filledDecoration(),
                ),
                const SizedBox(height: AppDimens.spaceMd),
                _fieldLabel('银行卡号'),
                TextField(
                  controller: _cardNumberController,
                  keyboardType: const TextInputType.numberWithOptions(),
                  textInputAction: TextInputAction.done,
                  decoration: _filledDecoration(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimens.spaceLg),
        _sectionLabel('资金'),
        _Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _fieldLabel('账户余额'),
                TextField(
                  controller: _balanceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  decoration: _filledDecoration().copyWith(
                    suffixIcon: Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 20,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimens.spaceLg),
        _otherSection(),
      ];

  /// 「资产类型」卡：银行图标 + 银行名（账户名）+ chevron，点击改名。
  Widget _assetTypeCard(Account account) => _Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          onTap: () => _renameDialog(account),
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    accountIcon(account.type),
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppDimens.spaceMd),
                Expanded(
                  child: Text(
                    account.name,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      );

  /// 「其他」区块：资产状态三态 + 计入总资产开关（两种模式共用）。
  Widget _otherSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _sectionLabel('其他'),
          _Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              child: Column(
                children: <Widget>[
                  _statusRow(),
                  const SizedBox(height: AppDimens.spaceMd),
                  _includeRow(),
                ],
              ),
            ),
          ),
        ],
      );

  /// 改名对话框：借记卡的「银行名」即账户名。
  Future<void> _renameDialog(Account account) async {
    final TextEditingController controller =
        TextEditingController(text: _nameController.text);
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('账户名称'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: _filledDecoration(),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      setState(() => _nameController.text = controller.text.trim());
    }
  }

  // ---- 初始化（仅在首次拿到账户时回填，避免流刷新覆盖用户输入） ----

  void _ensureInitialized(Account account) {
    if (_initialized) return;
    _nameController = TextEditingController(text: account.name);
    _noteController = TextEditingController(text: account.note ?? '');
    _cardNumberController =
        TextEditingController(text: account.cardNumber ?? '');
    _balanceController = TextEditingController(
      text: Money.fromMinor(account.balanceMinor).decimal.toStringAsFixed(2),
    );
    _status = account.status;
    _includeInTotal = account.includeInTotal;
    _initialized = true;
  }

  // ---- 区块与字段 ----

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      );

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppDimens.spaceXs),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      );

  InputDecoration _filledDecoration() => InputDecoration(
        filled: true,
        fillColor: AppColors.textTertiary.withValues(alpha: 0.08),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceSm + 2,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: BorderSide.none,
        ),
      );

  /// 借出 / 借入金额：派生余额，只读展示（灰底、不可编辑）。
  Widget _readOnlyAmount(int balanceMinor) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceSm + 4,
        ),
        decoration: BoxDecoration(
          color: AppColors.textTertiary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        child: Text(
          Money.fromMinor(balanceMinor).format(),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      );

  /// 资产状态三态胶囊：使用中 / 隐藏 / 封存。
  Widget _statusRow() {
    final List<AccountStatus> statuses = <AccountStatus>[
      AccountStatus.active,
      AccountStatus.hidden,
      AccountStatus.sealed,
    ];
    return Row(
      children: <Widget>[
        const Text('资产状态'),
        const SizedBox(width: AppDimens.spaceMd),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: AppDimens.spaceSm,
              runSpacing: AppDimens.spaceXs,
              alignment: WrapAlignment.end,
              children: statuses
                  .map(
                    (AccountStatus s) => _StatusPill(
                      label: s.label,
                      selected: _status == s,
                      onTap: () => setState(() => _status = s),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
      ],
    );
  }

  /// 计入总资产开关。
  Widget _includeRow() => Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('计入总资产'),
                const SizedBox(height: 2),
                Text(
                  '是否加入总资产计算',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                ),
              ],
            ),
          ),
          Switch(
            value: _includeInTotal,
            activeColor: AppColors.primary,
            onChanged: (bool v) => setState(() => _includeInTotal = v),
          ),
        ],
      );

  // ---- 保存 ----

  Widget _saveButton(Account account) => Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            onPressed: () => _save(account),
            child: const Text('保存', style: TextStyle(fontSize: 16)),
          ),
        ),
      );

  Future<void> _save(Account account) async {
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      showAppToast(context, '账户名称不能为空');
      return;
    }
    try {
      if (account.type == AccountType.bankCard) {
        // 借记卡：余额为真实值（允许手动校正）；备注 / 卡号传空串即清空
        // （仓储层 `?? before` 仅在 null 时保留现值，空串会正常写入）。
        await ref.read(accountRepositoryProvider).update(
              id: account.id,
              name: name,
              type: account.type,
              balanceMinor: Money.tryParse(_balanceController.text).minor,
              note: _noteController.text.trim(),
              cardNumber: _cardNumberController.text.trim(),
              status: _status,
              includeInTotal: _includeInTotal,
            );
      } else {
        // 借还账户：余额不传手改值，由仓储层同事务按名下未结清记录重算
        // （防派生不变量被覆盖）；其余字段按表单保存。
        await ref.read(accountRepositoryProvider).update(
              id: account.id,
              name: name,
              type: account.type,
              balanceMinor: account.balanceMinor,
              status: _status,
              includeInTotal: _includeInTotal,
            );
      }
      if (!mounted) return;
      showAppToast(context, '已保存');
      context.pop();
    } on AppFailure catch (e) {
      if (mounted) {
        showAppToast(context, e.message);
      }
    }
  }
}

/// 圆角卡片容器（与新增账户页同风格）。
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }
}

/// 资产状态胶囊按钮：选中绿底白字，未选中灰底。
class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.textTertiary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
