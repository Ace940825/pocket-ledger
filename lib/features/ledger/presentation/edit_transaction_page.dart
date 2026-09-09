import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/errors/failures.dart';
import '../../../../domain/enums.dart';
import '../../../../providers/app_providers.dart';
import '../../../../shared/models/money.dart';
import '../../../database/app_database.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../data/transaction_repository.dart';
import '../providers/ledger_providers.dart';

/// 新增 / 编辑流水。
///
/// 编辑模式下 [transactionId] 不为空，会先加载原记录再回填表单。
class EditTransactionPage extends ConsumerStatefulWidget {
  const EditTransactionPage({super.key, this.transactionId});

  final String? transactionId;

  bool get isEdit => transactionId != null;

  @override
  ConsumerState<EditTransactionPage> createState() =>
      _EditTransactionPageState();
}

class _EditTransactionPageState extends ConsumerState<EditTransactionPage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  TxnType _type = TxnType.expense;
  String? _categoryId;
  String? _accountId;
  String? _toAccountId;
  DateTime _occurredAt = DateTime.now();
  bool _initialized = false;
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
    final AsyncValue<List<Category>> categories = ref.watch(
      _type == TxnType.income
          ? incomeCategoriesProvider
          : expenseCategoriesProvider,
    );

    // 编辑模式：加载原记录并回填（只回填一次，避免用户输入被覆盖）
    if (widget.isEdit) {
      final AsyncValue<Transaction?> detail =
          ref.watch(transactionDetailProvider(widget.transactionId!));
      detail.whenData((Transaction? txn) {
        if (txn != null && !_initialized) {
          _initialized = true;
          _type = txn.type;
          _categoryId = txn.categoryId;
          _accountId = txn.accountId;
          _toAccountId = txn.toAccountId;
          _occurredAt = DateTime.fromMillisecondsSinceEpoch(
            txn.occurredAt,
            isUtc: true,
          ).toLocal();
          _amountController.text =
              Money.fromMinor(txn.amountMinor).decimal.toStringAsFixed(2);
          _noteController.text = txn.note ?? '';
        }
      });

      if (!_initialized) {
        return Scaffold(
          appBar: AppBar(title: const Text('编辑流水')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? '编辑流水' : '记一笔'),
        actions: <Widget>[
          if (widget.isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          children: <Widget>[
            SegmentedButton<TxnType>(
              segments: TxnType.values
                  .map(
                    (TxnType t) => ButtonSegment<TxnType>(
                      value: t,
                      label: Text(t.label),
                    ),
                  )
                  .toList(growable: false),
              selected: <TxnType>{_type},
              onSelectionChanged: (Set<TxnType> next) {
                setState(() {
                  _type = next.first;
                  _categoryId = null;
                });
              },
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
            const SizedBox(height: AppDimens.spaceLg),
            if (_type != TxnType.transfer)
              _CategoryPicker(
                categories: categories,
                value: _categoryId,
                onChanged: (String? v) => setState(() => _categoryId = v),
              ),
            _AccountPicker(
              label: _type == TxnType.transfer ? '转出账户' : '账户',
              accounts: accounts,
              value: _accountId,
              onChanged: (String? v) => setState(() => _accountId = v),
            ),
            if (_type == TxnType.transfer)
              _AccountPicker(
                label: '转入账户',
                accounts: accounts,
                value: _toAccountId,
                onChanged: (String? v) => setState(() => _toAccountId = v),
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
                  : const Text('保存'),
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
    if (_accountId == null) {
      _showError('请选择账户');
      return;
    }

    final int amountMinor =
        Money.fromDecimal(double.parse(_amountController.text.trim())).minor;
    final String bookId = ref.read(currentBookIdProvider);
    final int occurredAt = _occurredAt.toUtc().millisecondsSinceEpoch;

    setState(() => _saving = true);
    try {
      final TransactionRepository repo =
          ref.read(transactionRepositoryProvider);

      if (widget.isEdit) {
        final Transaction? original = await ref
            .read(transactionsDaoProvider)
            .getById(widget.transactionId!);
        if (original == null) throw const NotFoundFailure('流水不存在');

        await repo.updateTransaction(
          original: original,
          type: _type,
          amountMinor: amountMinor,
          accountId: _accountId,
          toAccountId: _toAccountId,
          categoryId: _categoryId,
          note: _noteController.text.trim(),
          occurredAt: occurredAt,
        );
      } else {
        await repo.add(
          bookId: bookId,
          type: _type,
          amountMinor: amountMinor,
          accountId: _accountId!,
          toAccountId: _toAccountId,
          categoryId: _categoryId,
          occurredAt: occurredAt,
          note: _noteController.text.trim(),
        );
      }

      if (mounted) context.pop();
    } on AppFailure catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('删除这条流水？'),
        content: const Text('删除后账户余额会相应回滚，此操作不可撤销。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(transactionRepositoryProvider)
          .remove(widget.transactionId!);
      if (mounted) context.pop();
    } on AppFailure catch (e) {
      _showError(e.message);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.categories,
    required this.value,
    required this.onChanged,
  });

  final AsyncValue<List<Category>> categories;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return categories.when(
      data: (List<Category> list) => DropdownButtonFormField<String>(
        value: value,
        decoration: const InputDecoration(labelText: '分类'),
        items: list
            .map(
              (Category c) => DropdownMenuItem<String>(
                value: c.id,
                child: Text(c.name),
              ),
            )
            .toList(growable: false),
        onChanged: onChanged,
      ),
      loading: () => const LinearProgressIndicator(),
      error: (Object e, StackTrace? s) => Text('分类加载失败：$e'),
    );
  }
}

class _AccountPicker extends StatelessWidget {
  const _AccountPicker({
    required this.label,
    required this.accounts,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final AsyncValue<List<Account>> accounts;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return accounts.when(
      data: (List<Account> list) {
        if (list.isEmpty) {
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
          items: list
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
      error: (Object e, StackTrace? s) => Text('账户加载失败：$e'),
    );
  }
}
