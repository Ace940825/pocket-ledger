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
import '../../../shared/widgets/date_picker_sheet.dart';
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
          _attachmentUrls =
              parseAttachmentUrls(txn.attachmentUrls) ?? <String>[];
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.isEdit ? '编辑流水' : '记一笔',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
        ),
        actions: <Widget>[
          if (widget.isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.textPrimary),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          children: <Widget>[
            // 类型 Tab
            _TypeSelector(
              selected: _type,
              onChanged: (TxnType next) => setState(() {
                _type = next;
                _categoryId = null;
              }),
            ),
            const SizedBox(height: AppDimens.spaceXl),

            // 金额输入
            _AmountField(controller: _amountController),
            const SizedBox(height: AppDimens.spaceXl),

            // 退款开关（仅编辑模式且类型为收入时显示）
            if (widget.isEdit && _type == TxnType.income) ...<Widget>[
              _RefundToggle(
                value: _sourceModule == SourceModule.refund,
                onChanged: (bool isRefund) => setState(() {
                  _sourceModule =
                      isRefund ? SourceModule.refund : SourceModule.ledger;
                }),
              ),
              const SizedBox(height: AppDimens.spaceLg),
            ],

            // 分类选择
            if (_type != TxnType.transfer)
              _CategoryPicker(
                categories: categories,
                value: _categoryId,
                onChanged: (String? v) => setState(() => _categoryId = v),
              ),

            // 账户选择
            _AccountPicker(
              label: _type == TxnType.transfer ? '转出账户' : '账户',
              accounts: accounts,
              value: _accountId,
              onChanged: (String? v) => setState(() => _accountId = v),
            ),

            // 转入账户（仅转账）
            if (_type == TxnType.transfer)
              _AccountPicker(
                label: '转入账户',
                accounts: accounts,
                value: _toAccountId,
                excludeId: _accountId,
                onChanged: (String? v) => setState(() => _toAccountId = v),
              ),

            const SizedBox(height: AppDimens.spaceMd),

            // 日期行
            _DateRow(
              value: _occurredAt,
              onTap: _pickDate,
            ),

            const SizedBox(height: AppDimens.spaceMd),

            // 备注输入框
            _NoteField(controller: _noteController),

            // 附件
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

            // 保存按钮
            SizedBox(
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                  ),
                  textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await DateTimePickerSheet.show(
      context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      showTime: true,
    );
    if (picked != null) {
      setState(() => _occurredAt = picked);
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

/// 类型选择器：收入 / 支出 / 转账。
///
/// 选中项为绿色圆角药丸 + 白色对勾 + 白色文字；
/// 未选中项为透明背景 + 深色文字。
class _TypeSelector extends StatelessWidget {
  const _TypeSelector({
    required this.selected,
    required this.onChanged,
  });

  final TxnType selected;
  final ValueChanged<TxnType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: <Widget>[
          for (final TxnType type in TxnType.values)
            Expanded(
              child: _TypeTab(
                type: type,
                selected: selected == type,
                onTap: () => onChanged(type),
              ),
            ),
        ],
      ),
    );
  }
}

class _TypeTab extends StatelessWidget {
  const _TypeTab({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final TxnType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg - 2),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (selected)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.check,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            Text(
              type.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: selected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 金额输入区。
///
/// 上方小标签「金额」，下方大字号 ¥ + 输入框。
class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '金额',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
        ),
        const SizedBox(height: AppDimens.spaceXs),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
          decoration: const InputDecoration(
            hintText: '0.00',
            hintStyle: TextStyle(
              color: AppColors.textTertiary,
            ),
            prefixIcon: Padding(
              padding: EdgeInsets.only(right: 4),
              child: Text(
                '¥',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          validator: (String? value) {
            final double? parsed = double.tryParse(value ?? '');
            if (parsed == null || parsed <= 0) return '请输入大于 0 的金额';
            return null;
          },
        ),
      ],
    );
  }
}

/// 通用选择行。
///
/// 上方小标签，下方当前值 + 右侧下拉箭头，底部细线分隔。
class _SelectorRow extends StatelessWidget {
  const _SelectorRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.placeholder = '请选择',
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: AppDimens.spaceMd),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  value ?? placeholder,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: value != null
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                      ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceSm),
          const Divider(height: 1, color: AppColors.divider),
        ],
      ),
    );
  }
}

/// 分类选择行。
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
        final String? safeValue =
            list.any((Category c) => c.id == value) ? value : null;
        final Category? selected = safeValue == null
            ? null
            : list.firstWhere((Category c) => c.id == safeValue);

        return _SelectorRow(
          label: '分类',
          value: selected?.name,
          placeholder: '请选择分类',
          onTap: () async {
            final String? picked = await showModalBottomSheet<String>(
              context: context,
              isScrollControlled: true,
              builder: (BuildContext context) => _CategoryPickerSheet(
                categories: list,
                selectedId: safeValue,
              ),
            );
            if (picked != null) onChanged(picked);
          },
        );
      },
      loading: () => const _SelectorRowSkeleton(label: '分类'),
      error: (Object e, StackTrace? s) => Text('分类加载失败：$e'),
    );
  }
}

/// 账户选择行。
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
  final String? excludeId;

  @override
  Widget build(BuildContext context) {
    return accounts.when(
      data: (List<Account> list) {
        final List<Account> shown = (excludeId != null && list.length > 1)
            ? list.where((Account a) => a.id != excludeId).toList()
            : list;
        final String? safeValue =
            shown.any((Account a) => a.id == value) ? value : null;
        final Account? selected = safeValue == null
            ? null
            : shown.firstWhere((Account a) => a.id == safeValue);

        if (shown.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppDimens.spaceMd),
            child: Text(
              '还没有可用的账户，请先到「账户」页添加',
              style: TextStyle(color: AppColors.danger),
            ),
          );
        }

        return _SelectorRow(
          label: label,
          value: selected?.name,
          placeholder: '请选择账户',
          onTap: () async {
            final String? picked = await showModalBottomSheet<String>(
              context: context,
              isScrollControlled: true,
              builder: (BuildContext context) => _AccountPickerSheet(
                accounts: shown,
                selectedId: safeValue,
              ),
            );
            if (picked != null) onChanged(picked);
          },
        );
      },
      loading: () => _SelectorRowSkeleton(label: label),
      error: (Object e, StackTrace? s) => Text('账户加载失败：$e'),
    );
  }
}

/// 日期行。
class _DateRow extends StatelessWidget {
  const _DateRow({required this.value, required this.onTap});

  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: Text(
                  '日期',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                ),
              ),
              Text(
                DateFormat('yyyy-MM-dd HH:mm').format(value),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),
          const Divider(height: 1, color: AppColors.divider),
        ],
      ),
    );
  }
}

/// 备注输入框。
///
/// 圆角白色背景 + 灰色边框，占满整行。
class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      borderSide: const BorderSide(color: AppColors.divider),
    );
    return TextField(
      controller: controller,
      maxLines: 2,
      decoration: InputDecoration(
        hintText: '备注',
        hintStyle: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: AppColors.textTertiary),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(AppDimens.spaceMd),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
          ),
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
    );
  }
}

/// 选择行骨架。
class _SelectorRowSkeleton extends StatelessWidget {
  const _SelectorRowSkeleton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: AppDimens.spaceMd),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
          ),
        ),
        const SizedBox(height: AppDimens.spaceXs),
        const SizedBox(height: 24),
        const Divider(height: 1, color: AppColors.divider),
      ],
    );
  }
}

/// 分类选择底部弹窗。
class _CategoryPickerSheet extends StatelessWidget {
  const _CategoryPickerSheet({
    required this.categories,
    this.selectedId,
  });

  final List<Category> categories;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceLg,
                vertical: AppDimens.spaceSm,
              ),
              child: Text(
                '选择分类',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: categories.length,
                itemBuilder: (BuildContext context, int index) {
                  final Category category = categories[index];
                  final bool selected = category.id == selectedId;
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: category.colorValue != null
                          ? Color(category.colorValue!)
                          : AppColors.primary,
                      child: Icon(
                        _mapIcon(category.iconKey),
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(category.name),
                    trailing: selected
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () => Navigator.of(context).pop(category.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _mapIcon(String? key) {
    return switch (key) {
      'restaurant' => Icons.restaurant,
      'shopping' => Icons.shopping_bag,
      'transport' => Icons.directions_bus,
      'home' => Icons.home,
      'entertainment' => Icons.movie,
      'medical' => Icons.local_hospital,
      'education' => Icons.school,
      'salary' => Icons.work,
      'investment' => Icons.trending_up,
      'gift' => Icons.card_giftcard,
      _ => Icons.category,
    };
  }
}

/// 账户选择底部弹窗。
class _AccountPickerSheet extends StatelessWidget {
  const _AccountPickerSheet({
    required this.accounts,
    this.selectedId,
  });

  final List<Account> accounts;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    // 桌面端默认会给可滚动区域挂系统滚动条，这里关掉
    final ScrollBehavior behavior =
        ScrollConfiguration.of(context).copyWith(scrollbars: false);
    return ScrollConfiguration(
      behavior: behavior,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceMd),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceLg,
                  vertical: AppDimens.spaceSm,
                ),
                child: Text(
                  '选择账户',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: accounts.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Account account = accounts[index];
                    final bool selected = account.id == selectedId;
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: account.colorValue != null
                            ? Color(account.colorValue!)
                            : AppColors.primary,
                        child: Icon(
                          _mapIcon(account.iconKey),
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(account.name),
                      trailing: selected
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () => Navigator.of(context).pop(account.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _mapIcon(String? key) {
    return switch (key) {
      'cash' => Icons.payments,
      'bank' => Icons.account_balance,
      'credit_card' => Icons.credit_card,
      'wallet' => Icons.account_balance_wallet,
      'wechat' => Icons.chat_bubble,
      'alipay' => Icons.payment,
      'fund' => Icons.pie_chart,
      'stock' => Icons.show_chart,
      _ => Icons.account_balance_wallet,
    };
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
        color: Colors.white,
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
