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
import '../providers/accounts_providers.dart';

/// 编辑账户页（应收 / 应付账户专用，参照小青账编辑逻辑）。
///
/// - 基本信息：**借款给谁 / 向谁借**（账户名）+ **借出 / 借入金额**
///   （派生余额，只读展示——由名下未结清借还记录自动计算，保存时
///   仓储层同事务重算，不可手改）；
/// - 其他：**资产状态** 三态胶囊（使用中 / 隐藏 / 封存）+ **计入总资产** 开关；
/// - 底部整宽「保存」按钮。
class AccountEditPage extends ConsumerStatefulWidget {
  const AccountEditPage({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<AccountEditPage> createState() => _AccountEditPageState();
}

class _AccountEditPageState extends ConsumerState<AccountEditPage> {
  late final TextEditingController _nameController;
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
              children: <Widget>[
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
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textTertiary,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.spaceLg),
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
            ),
          ),
          _saveButton(account),
        ],
      ),
    );
  }

  // ---- 初始化（仅在首次拿到账户时回填，避免流刷新覆盖用户输入） ----

  void _ensureInitialized(Account account) {
    if (_initialized) return;
    _nameController = TextEditingController(text: account.name);
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
      // 余额不传手改值：借还账户由仓储层同事务按名下未结清记录重算
      // （防派生不变量被覆盖）；其余字段按表单保存。
      await ref.read(accountRepositoryProvider).update(
            id: account.id,
            name: name,
            type: account.type,
            balanceMinor: account.balanceMinor,
            status: _status,
            includeInTotal: _includeInTotal,
          );
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
