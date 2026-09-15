import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/env.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/errors/failures.dart';
import '../../../../domain/enums.dart';
import '../../../../features/settings/providers/sync_settings_providers.dart';
import '../../../../providers/app_providers.dart';
import '../../../../shared/models/money.dart';
import '../../../../shared/widgets/attachment_viewer.dart';
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

  /// 这条流水的来源标记。
  ///
  /// 它**不是**用户可以随便填的备注，而是决定统计口径的关键：
  /// `SourceModule.refund` 会被资产页按「退款」处理（默认抵扣支出），
  /// 而普通 `income` 是纯收入。退款的 `type` 恰好也是 `income`，
  /// 光看类型区分不出来，所以编辑时必须把它显式带出来给用户看。
  SourceModule _sourceModule = SourceModule.ledger;
  String? _categoryId;
  String? _accountId;
  String? _toAccountId;
  DateTime _occurredAt = DateTime.now();
  int _feeMinor = 0;
  int _discountMinor = 0;
  bool _initialized = false;
  bool _saving = false;

  /// 已有图片附件（兼容本机路径与云端 `/api/file/<key>` URL）。
  /// 编辑页支持查看与删除，新增上传仍在「记一笔」完成。
  List<String> _attachmentUrls = <String>[];

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
          _sourceModule = txn.sourceModule;
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
          _feeMinor = txn.feeMinor;
          _discountMinor = txn.discountMinor;
          _attachmentUrls = parseAttachmentUrls(txn.attachmentUrls) ??
              <String>[];
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
            if (widget.isEdit && _type == TxnType.income)
              _RefundToggle(
                value: _sourceModule == SourceModule.refund,
                onChanged: (bool isRefund) => setState(() {
                  _sourceModule =
                      isRefund ? SourceModule.refund : SourceModule.ledger;
                }),
              ),
            if (widget.isEdit && _type == TxnType.income)
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
                // 转入账户不能与转出相同：列表里直接隐藏转出项。
                // 若账户总数 ≤1，转入侧会回落到空态提示，不强行隐藏。
                excludeId: _accountId,
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
            if (_attachmentUrls.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppDimens.spaceMd),
              _AttachmentSection(
                urls: _attachmentUrls,
                baseUrl: ref.watch(syncSettingsProvider).value?.baseUrl ??
                    Env.syncBaseUrl,
                onDeleted: (String url) =>
                    setState(() => _attachmentUrls.remove(url)),
              ),
            ],
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
    if (_type == TxnType.transfer) {
      if (_toAccountId == null) {
        _showError('请选择转入账户');
        return;
      }
      if (_accountId == _toAccountId) {
        _showError('转出与转入账户不能相同');
        return;
      }
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
          // 显式带出来源，让用户能在一笔「被当成退款」的收入上把标记摘掉。
          sourceModule: _sourceModule,
          // 转账时保留原手续费 / 优惠，避免编辑后余额回滚出错。
          feeMinor: _type == TxnType.transfer ? _feeMinor : null,
          discountMinor: _type == TxnType.transfer ? _discountMinor : null,
          // 附件（含删除后的最新列表）随编辑一并落库并触发同步。
          attachmentUrls: _attachmentUrls,
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

/// 「这是退款」开关。
///
/// 退款和普通收入的 `type` 都是 `income`，但在资产页的统计口径里完全不同：
/// 退款默认**抵扣支出**（钱是退回来的，不是新赚的），普通收入则计入收入。
/// 这个开关让用户能看见并修正这个隐形标记 —— 它当初就是「看不见」，
/// 才让 `支出:¥88.00 收入:¥0.00` 被误当成统计 bug。
class _RefundToggle extends StatelessWidget {
  const _RefundToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceSm,
        AppDimens.spaceSm,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.replay,
            size: 20,
            color: value ? AppColors.income : AppColors.textTertiary,
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '这是退款',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value ? '默认抵扣支出，不计入收入' : '按普通收入计入收入统计',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
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
      data: (List<Category> list) {
        // 防御：当前 value 若不在列表里（被删/被归档/类型切换后失效），
        // 强行传 null，避免 DropdownButtonFormField 断言炸红屏。
        final String? safeValue =
            list.any((Category c) => c.id == value) ? value : null;
        return DropdownButtonFormField<String>(
          value: safeValue,
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
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (Object e, StackTrace? s) => Text('分类加载失败：$e'),
    );
  }
}

/// 编辑页的图片附件展示区：缩略图网格，可删除（新增上传在「记一笔」完成）。
class _AttachmentSection extends StatelessWidget {
  const _AttachmentSection({
    required this.urls,
    required this.baseUrl,
    required this.onDeleted,
  });

  final List<String> urls;
  final String baseUrl;
  final ValueChanged<String> onDeleted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('图片附件', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: AppDimens.spaceSm),
        Wrap(
          spacing: AppDimens.spaceSm,
          runSpacing: AppDimens.spaceSm,
          children: <Widget>[
            for (final String url in urls)
              AttachmentThumb(
                url: url,
                baseUrl: baseUrl,
                showDelete: true,
                onDeleted: () => onDeleted(url),
              ),
          ],
        ),
      ],
    );
  }
}

class _AccountPicker extends StatelessWidget {
  const _AccountPicker({
    required this.label,
    required this.accounts,
    required this.value,
    required this.onChanged,
    this.excludeId,
  });

  final String label;
  final AsyncValue<List<Account>> accounts;
  final String? value;
  final ValueChanged<String?> onChanged;

  /// 若设置，items 里会隐藏该 id 的账户（用于「转入账户」屏蔽已选的「转出账户」）。
  /// 账户总数 ≤1 时跳过过滤，避免空列表。
  final String? excludeId;

  @override
  Widget build(BuildContext context) {
    return accounts.when(
      data: (List<Account> list) {
        final List<Account> shown = (excludeId != null && list.length > 1)
            ? list.where((Account a) => a.id != excludeId).toList()
            : list;
        // 防御：value 不在可见 items 里就降级为 null。
        final String? safeValue =
            shown.any((Account a) => a.id == value) ? value : null;
        if (shown.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceMd),
            child: Text(
              '还没有可用的账户，请先到「账户」页添加',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
        }
        return DropdownButtonFormField<String>(
          value: safeValue,
          decoration: InputDecoration(labelText: label),
          items: shown
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
