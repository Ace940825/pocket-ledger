import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/errors/failures.dart';
import '../../../../providers/app_providers.dart';
import '../../../database/app_database.dart';
import '../../../shared/models/money.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../ledger/providers/ledger_providers.dart';

/// 转账页：在两个账户间划转资金，不影响净资产。
class TransferPage extends ConsumerStatefulWidget {
  const TransferPage({super.key});

  @override
  ConsumerState<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends ConsumerState<TransferPage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String? _fromAccountId;
  String? _toAccountId;
  DateTime _occurredAt = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Account>> accounts = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('转账')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          children: <Widget>[
            _AccountPicker(
              label: '转出账户',
              accounts: accounts,
              exclude: _toAccountId,
              value: _fromAccountId,
              onChanged: (String? v) => setState(() => _fromAccountId = v),
            ),
            const SizedBox(height: AppDimens.spaceLg),
            _AccountPicker(
              label: '转入账户',
              accounts: accounts,
              exclude: _fromAccountId,
              value: _toAccountId,
              onChanged: (String? v) => setState(() => _toAccountId = v),
            ),
            const SizedBox(height: AppDimens.spaceLg),
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: Theme.of(context).textTheme.headlineSmall,
              decoration: const InputDecoration(
                labelText: '金额',
                prefixText: '¥ ',
              ),
              validator: (String? value) {
                final double? parsed = double.tryParse(value ?? '');
                if (parsed == null || parsed <= 0) return '请输入大于 0 的金额';
                return null;
              },
            ),
            const SizedBox(height: AppDimens.spaceMd),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('日期'),
              trailing: Text(DateFormat('yyyy-MM-dd').format(_occurredAt)),
              onTap: _pickDate,
            ),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: '备注'),
              maxLines: 2,
            ),
            const SizedBox(height: AppDimens.spaceXl),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('确认转账'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _occurredAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _occurredAt.hour,
          _occurredAt.minute,
        );
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromAccountId == null || _toAccountId == null) {
      _toast('请选择转出与转入账户');
      return;
    }
    if (_fromAccountId == _toAccountId) {
      _toast('转出与转入账户不能相同');
      return;
    }

    final int amountMinor =
        Money.fromDecimal(double.parse(_amountController.text.trim())).minor;
    final int occurredAt = _occurredAt.toUtc().millisecondsSinceEpoch;

    setState(() => _saving = true);
    try {
      await ref.read(transactionRepositoryProvider).transfer(
            bookId: ref.read(currentBookIdProvider),
            fromAccountId: _fromAccountId!,
            toAccountId: _toAccountId!,
            amountMinor: amountMinor,
            occurredAt: occurredAt,
            note: _noteController.text.trim(),
          );
      if (mounted) context.pop();
    } on AppFailure catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AccountPicker extends StatelessWidget {
  const _AccountPicker({
    required this.label,
    required this.accounts,
    required this.value,
    required this.onChanged,
    this.exclude,
  });

  final String label;
  final AsyncValue<List<Account>> accounts;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? exclude;

  @override
  Widget build(BuildContext context) {
    return accounts.when(
      data: (List<Account> list) {
        final List<Account> options =
            list.where((Account a) => a.id != exclude).toList(growable: false);
        if (options.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceMd),
            child: Text(
              '还没有账户，请先到「账户」页添加一个',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
        }
        return DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(labelText: label),
          items: options
              .map(
                (Account a) => DropdownMenuItem<String>(
                  value: a.id,
                  child: Text(a.name),
                ),
              )
              .toList(growable: false),
          onChanged: onChanged,
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (Object e, _) => Text('账户加载失败：$e'),
    );
  }
}
