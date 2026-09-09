import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/errors/failures.dart';
import '../../../../domain/enums.dart';
import '../../../../providers/app_providers.dart';
import '../../../../shared/models/money.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/money_text.dart';
import '../../../database/app_database.dart';
import '../data/account_repository.dart';
import '../providers/accounts_providers.dart';

final Provider<AccountRepository> accountRepositoryProvider =
    Provider<AccountRepository>(
  (Ref ref) => AccountRepository(ref.watch(appDatabaseProvider)),
);

/// 账户列表页
class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Account>> accounts = ref.watch(accountsProvider);
    final AsyncValue<int> netAssets = ref.watch(netAssetsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('账户')),
      body: accounts.when(
        data: (List<Account> list) {
          if (list.isEmpty) {
            return const EmptyState(message: '还没有账户，点右下角新增一个');
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: <Widget>[
              _NetAssetsHeader(value: netAssets),
              const SizedBox(height: AppDimens.spaceSm),
              ...list.map(
                (Account a) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        AppColors.primary.withOpacity(0.12),
                    child: Icon(
                      _iconFor(a.type),
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(a.name),
                  subtitle: Text(a.type.label),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      MoneyText(Money.fromMinor(a.balanceMinor)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => _confirmDelete(context, ref, a),
                      ),
                    ],
                  ),
                  onTap: () => _showEditor(context, ref, a),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace? s) => Center(child: Text('加载失败：$e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  IconData _iconFor(AccountType type) => switch (type) {
        AccountType.cash => Icons.payments_outlined,
        AccountType.bankCard => Icons.credit_card,
        AccountType.creditCard => Icons.credit_score_outlined,
        AccountType.eWallet => Icons.account_balance_wallet_outlined,
        AccountType.investment => Icons.trending_up,
        AccountType.other => Icons.savings_outlined,
      };

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController balanceController = TextEditingController();
    AccountType type = AccountType.cash;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => AlertDialog(
          title: const Text('新增账户'),
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
                  labelText: '初始余额',
                  prefixText: '¥ ',
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              DropdownButtonFormField<AccountType>(
                value: type,
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
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(accountRepositoryProvider).add(
            bookId: ref.read(currentBookIdProvider),
            name: nameController.text,
            type: type,
            balanceMinor: Money.tryParse(balanceController.text).minor,
          );
    } on AppFailure catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

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
                value: type,
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
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
              color: Colors.white.withOpacity(0.85),
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
