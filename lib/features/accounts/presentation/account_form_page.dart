import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/models/money.dart';
import '../data/account_icon.dart';
import '../data/bank_data.dart';
import '../providers/accounts_providers.dart';
import 'bank_select_page.dart';
import '../../../shared/widgets/app_toast.dart';

/// 账户表单页。
///
/// 由 [AddAccountPage] 选择账户类型后跳转至此，填写账户详情并保存。
/// 未来可扩展为编辑模式：传入 [accountId] 时回显已有数据。
class AccountFormPage extends ConsumerStatefulWidget {
  const AccountFormPage({
    super.key,
    required this.accountType,
    this.initialBank,
  });

  /// 已选中的账户类型（从 AddAccountPage 传入）。
  final AccountType accountType;

  /// 信用卡场景下由 [BankSelectPage] 选中的发卡银行。
  final String? initialBank;

  @override
  ConsumerState<AccountFormPage> createState() => _AccountFormPageState();
}

class _AccountFormPageState extends ConsumerState<AccountFormPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController();
  final TextEditingController _creditLimitController = TextEditingController();
  final TextEditingController _billingDayController = TextEditingController();
  final TextEditingController _dueDayController = TextEditingController();

  bool _saving = false;
  bool _includeInTotal = true;
  bool _syncBill = false;
  AccountStatus _status = AccountStatus.active;
  String? _bankName;

  /// 完整模板：借记卡。
  /// 显示「账户名称 + 备注 + 卡号」，余额在独立资金卡片中填写。
  /// 完整模板：借记卡。
  /// 显示「开户银行 + 账户名称 + 备注 + 卡号」，余额在独立资金卡片中填写。
  bool get _isDebitCard => widget.accountType == AccountType.bankCard;

  /// 信用卡模板：与负债非信用卡类似，但额外显示「发卡银行」与「银行卡号」。
  bool get _isCreditCard => widget.accountType == AccountType.creditCard;

  /// 是否需要显示银行头部（开户银行 / 发卡银行）。
  bool get _hasBankHeader => _isDebitCard || _isCreditCard;

  /// 负债类（除信用卡）：采用花呗式模板。
  /// 无账户名称输入（默认用类型标签），含信用额度、当前欠款、剩余额度、
  /// 账单日、还款日。
  bool get _isDebtNonCredit =>
      widget.accountType.isDebt && widget.accountType != AccountType.creditCard;

  /// 是否需要显示信用额度 / 当前欠款 / 剩余额度 / 账单还款日。
  bool get _isDebtTemplate => _isDebtNonCredit || _isCreditCard;

  /// 应收-借出。
  bool get _isReceivableLend => widget.accountType == AccountType.lend;

  /// 应付-借入。
  bool get _isPayableBorrow => widget.accountType == AccountType.borrow;

  /// 应收-报销。
  bool get _isReimbursement => widget.accountType == AccountType.reimbursement;

  /// 是否需要显示「余额同步：同时记一笔账单」卡片（借出/借入默认开启）。
  bool get _isSyncBillVisible => _isReceivableLend || _isPayableBorrow;

  bool get _isDebt => widget.accountType.isDebt;

  @override
  void initState() {
    super.initState();
    _bankName = widget.initialBank;
    _syncBill = _isSyncBillVisible;
    _billingDayController.text = '1';
    _dueDayController.text = '10';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    _cardNumberController.dispose();
    _balanceController.dispose();
    _creditLimitController.dispose();
    _billingDayController.dispose();
    _dueDayController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final String accountName = _isDebtNonCredit
          ? widget.accountType.label
          : _isCreditCard
              ? (_bankName ?? widget.accountType.label)
              : _nameController.text;

      await ref.read(accountRepositoryProvider).add(
            bookId: ref.read(currentBookIdProvider),
            name: accountName,
            type: widget.accountType,
            balanceMinor: Money.tryParse(_balanceController.text).minor,
            creditLimitMinor: _creditLimitController.text.isEmpty
                ? null
                : Money.tryParse(_creditLimitController.text).minor,
            billingDay: int.tryParse(_billingDayController.text),
            dueDay: int.tryParse(_dueDayController.text),
            note: _noteController.text.isEmpty ? null : _noteController.text,
            cardNumber: _cardNumberController.text.isEmpty
                ? null
                : _cardNumberController.text,
            status: _status,
            includeInTotal: _includeInTotal,
          );
      if (mounted) Navigator.of(context).pop();
    } on AppFailure catch (e) {
      if (mounted) {
        showAppToast(context, e.message);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 剩余额度 = 信用额度 - 当前欠款。
  String? get _remainingLimitText {
    final int limit = Money.tryParse(_creditLimitController.text).minor;
    final int debt = Money.tryParse(_balanceController.text).minor;
    if (limit == 0 && debt == 0) return null;
    return Money.fromMinor(limit - debt).format();
  }

  Future<void> _pickDay(
    TextEditingController controller,
    String title,
  ) async {
    final int? current = int.tryParse(controller.text);
    final int initialDay = current ?? 1;
    final int? selected = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => _DayPickerDialog(
        title: title,
        initialDay: initialDay,
      ),
    );
    if (selected != null) {
      controller.text = selected.toString();
    }
  }

  /// 根据账户类型返回「基本信息」卡片里的字段列表。
  ///
  /// - 借记卡：「账户名称 + 备注 + 卡号」。
  /// - 信用卡：「备注信息 + 银行卡号」。
  /// - 负债非信用卡：仅「备注信息」。
  /// - 应收-借出：「借款给谁 + 借出金额」。
  /// - 应付-借入：「向谁借 + 借入金额」。
  /// - 应收-报销：「用户名」。
  /// - 简版模板：「账户名称 + 金额」，金额右侧用计算器图标。
  List<Widget> _basicInfoFields() {
    final List<Widget> fields = <Widget>[];

    if (_isDebtNonCredit) {
      fields.add(
        _TextField(
          controller: _noteController,
          label: '备注信息',
        ),
      );
    } else if (_isCreditCard || _isDebitCard) {
      if (_isDebitCard) {
        fields.add(
          _TextField(
            controller: _nameController,
            label: '账户名称',
            hint: '如「招商储蓄卡」',
          ),
        );
        fields.add(const Divider(height: 1, indent: AppDimens.spaceMd));
      }
      fields
        ..add(_TextField(controller: _noteController, label: '备注信息'))
        ..add(const Divider(height: 1, indent: AppDimens.spaceMd))
        ..add(
          _TextField(
            controller: _cardNumberController,
            label: '银行卡号',
            keyboardType: TextInputType.number,
          ),
        );
    } else if (_isReceivableLend || _isPayableBorrow) {
      final String nameLabel = _isReceivableLend ? '借款给谁' : '向谁借';
      final String amountLabel = _isReceivableLend ? '借出金额' : '借入金额';
      fields
        ..add(
          _TextField(
            controller: _nameController,
            label: nameLabel,
          ),
        )
        ..add(const Divider(height: 1, indent: AppDimens.spaceMd))
        ..add(
          _TextField(
            controller: _balanceController,
            label: amountLabel,
            prefixText: '¥ ',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffix: const Icon(
              Icons.calculate_outlined,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ),
        );
    } else if (_isReimbursement) {
      fields.add(
        _TextField(
          controller: _nameController,
          label: '用户名',
        ),
      );
    } else {
      // 简版模板
      fields
        ..add(
          _TextField(
            controller: _nameController,
            label: '账户名称',
          ),
        )
        ..add(const Divider(height: 1, indent: AppDimens.spaceMd))
        ..add(
          _TextField(
            controller: _balanceController,
            label: _isDebt ? '当前欠款' : '账户余额',
            prefixText: '¥ ',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffix: const Icon(
              Icons.calculate_outlined,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ),
        );
    }

    return fields;
  }

  /// 资金 / 负债卡片。
  ///
  /// - 借记卡：单个余额输入。
  /// - 负债模板（信用卡 / 负债非信用卡）：
  ///   信用额度 + 当前欠款 + 剩余额度（只读）+ 提示文案。
  /// - 借出 / 借入 / 报销 / 简版：金额已并入基本信息或不显示，此处返回空。
  List<Widget> _capitalFields() {
    if (_isDebtTemplate) {
      return <Widget>[
        _TextField(
          controller: _creditLimitController,
          label: '信用额度',
          prefixText: '¥ ',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
        ),
        const Divider(height: 1, indent: AppDimens.spaceMd),
        _TextField(
          controller: _balanceController,
          label: '当前欠款',
          prefixText: '¥ ',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
        ),
        const Divider(height: 1, indent: AppDimens.spaceMd),
        _ReadOnlyField(
          label: '剩余额度',
          value: _remainingLimitText ?? '',
          placeholder: '输入信用额度与当前欠款后自动计算',
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceSm,
            AppDimens.spaceMd,
            AppDimens.spaceMd,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.info_outline,
                size: 14,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: Text(
                  '当前欠款 和 信用额度 输入一个即可自动识别计算',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ];
    }

    if (_isDebitCard) {
      return <Widget>[
        _TextField(
          controller: _balanceController,
          label: '账户余额',
          prefixText: '¥ ',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          suffix: const Icon(
            Icons.account_balance_wallet_outlined,
            size: 18,
            color: AppColors.textTertiary,
          ),
        ),
      ];
    }

    return const <Widget>[];
  }

  /// 账单 / 还款日期卡片，信用卡与负债非信用卡均显示。
  List<Widget> _billDateFields() {
    final int billDay = int.tryParse(_billingDayController.text) ?? 1;
    final int dueDay = int.tryParse(_dueDayController.text) ?? 10;
    return <Widget>[
      _DayPickerField(
        label: '账单日期',
        suffix: '每月$billDay日',
        onTap: () => _pickDay(_billingDayController, '选择账单日期'),
      ),
      const Divider(height: 1, indent: AppDimens.spaceMd),
      _DayPickerField(
        label: '还款日期',
        suffix: '每月$dueDay日',
        onTap: () => _pickDay(_dueDayController, '选择还款日期'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    const Color primary = AppColors.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('新建账户'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        children: <Widget>[
          // 资产类型（只读）
          _SectionTitle('资产类型'),
          const SizedBox(height: AppDimens.spaceSm),
          _TypeHeader(type: widget.accountType),
          const SizedBox(height: AppDimens.spaceSm),

          // 银行头部（借记卡 / 信用卡）
          if (_hasBankHeader)
            _BankHeader(
              bankName: _bankName,
              label: _isCreditCard ? '发卡银行' : '开户银行',
              onTap: () async {
                final String pageTitle = _isCreditCard ? '信用卡' : '借记卡';
                final String? bank = await Navigator.of(context).push<String>(
                  MaterialPageRoute<String>(
                    builder: (_) => BankSelectPage(title: pageTitle),
                  ),
                );
                if (bank != null) setState(() => _bankName = bank);
              },
            ),
          if (_hasBankHeader) const SizedBox(height: AppDimens.spaceXl),

          // 基本信息
          _SectionTitle('基本信息'),
          const SizedBox(height: AppDimens.spaceSm),
          _Card(
            child: Column(
              children: _basicInfoFields(),
            ),
          ),
          const SizedBox(height: AppDimens.spaceXl),

          // 资金 / 负债（借记卡余额 / 负债额度，借出借入报销金额已在基本信息）
          if (_isDebitCard || _isDebtTemplate) ...<Widget>[
            _SectionTitle(_isDebt ? '负债' : '资金'),
            const SizedBox(height: AppDimens.spaceSm),
            _Card(
              child: Column(
                children: _capitalFields(),
              ),
            ),
            const SizedBox(height: AppDimens.spaceXl),
          ],

          // 账单 / 还款日期（信用卡与负债非信用卡）
          if (_isDebtTemplate) ...<Widget>[
            _SectionTitle('账单/还款日期'),
            const SizedBox(height: AppDimens.spaceSm),
            _Card(
              child: Column(
                children: _billDateFields(),
              ),
            ),
            const SizedBox(height: AppDimens.spaceXl),
          ],

          // 余额同步（仅借出 / 借入默认开启）
          if (_isSyncBillVisible) ...<Widget>[
            _SectionTitle('余额同步'),
            const SizedBox(height: AppDimens.spaceSm),
            _Card(
              child: _SwitchTile(
                title: '同时记一笔账单',
                subtitle: '将金额记一笔对应类型账单',
                value: _syncBill,
                onChanged: (bool v) => setState(() => _syncBill = v),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(
                left: AppDimens.spaceMd,
                top: AppDimens.spaceSm,
                right: AppDimens.spaceMd,
              ),
              child: Text(
                '如创建资产初始金额不为0并打开同时记一笔账单，'
                '将创建一笔调整资产的账单方便查看变动记录。',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: AppDimens.spaceXl),
          ],

          // 其他
          _SectionTitle('其他'),
          const SizedBox(height: AppDimens.spaceSm),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppDimens.spaceMd,
                    AppDimens.spaceMd,
                    AppDimens.spaceMd,
                    AppDimens.spaceSm,
                  ),
                  child: Text(
                    '资产状态',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceMd,
                    0,
                    AppDimens.spaceMd,
                    AppDimens.spaceMd,
                  ),
                  child: Wrap(
                    spacing: AppDimens.spaceSm,
                    children: AccountStatus.values
                        .map(
                          (AccountStatus s) => _StatusChip(
                            status: s,
                            selected: s == _status,
                            onTap: () => setState(() => _status = s),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
                const Divider(height: 1, indent: AppDimens.spaceMd),
                _SwitchTile(
                  title: '计入总资产',
                  subtitle: '是否加入总资产计算',
                  value: _includeInTotal,
                  onChanged: (bool v) => setState(() => _includeInTotal = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.spaceXl),

          // 保存按钮
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('保存'),
            ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
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
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }
}

class _TypeHeader extends StatelessWidget {
  const _TypeHeader({required this.type});

  final AccountType type;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Row(
          children: <Widget>[
            Icon(accountIcon(type), color: AppColors.primary, size: 24),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Text(
                type.label,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BankHeader extends StatelessWidget {
  const _BankHeader({
    required this.bankName,
    required this.onTap,
    required this.label,
  });

  final String? bankName;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String name = bankName ?? '选择$label';
    final Bank? bank = bankName == null
        ? null
        : kBuiltinBanks.cast<Bank?>().firstWhere(
              (Bank? b) => b?.name == bankName,
              orElse: () => null,
            );
    final Color color = bank?.color ?? colorForBank(name);

    return _Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name.substring(0, 1),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: bankName == null
                            ? AppColors.textTertiary
                            : AppColors.textPrimary,
                      ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    this.hint,
    this.prefixText,
    this.keyboardType,
    this.suffix,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? prefixText;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        suffixIcon: suffix,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.all(AppDimens.spaceMd),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.placeholder,
  });

  final String label;
  final String value;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            value.isEmpty ? placeholder : value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: value.isEmpty ? AppColors.textTertiary : null,
                ),
          ),
        ],
      ),
    );
  }
}

class _DayPickerField extends StatelessWidget {
  const _DayPickerField({
    required this.label,
    required this.suffix,
    required this.onTap,
  });

  final String label;
  final String suffix;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                  Text(
                    suffix,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _DayPickerDialog extends StatefulWidget {
  const _DayPickerDialog({
    required this.title,
    required this.initialDay,
  });

  final String title;
  final int initialDay;

  @override
  State<_DayPickerDialog> createState() => _DayPickerDialogState();
}

class _DayPickerDialogState extends State<_DayPickerDialog> {
  late int _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initialDay;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 240,
        height: 220,
        child: ListWheelScrollView.useDelegate(
          itemExtent: 44,
          magnification: 1.2,
          useMagnifier: true,
          diameterRatio: 1.2,
          controller: FixedExtentScrollController(
            initialItem: _selectedDay - 1,
          ),
          onSelectedItemChanged: (int index) {
            setState(() => _selectedDay = index + 1);
          },
          childDelegate: ListWheelChildBuilderDelegate(
            builder: (BuildContext context, int index) {
              if (index < 0 || index >= 31) return null;
              final int day = index + 1;
              final bool selected = day == _selectedDay;
              return Center(
                child: Text(
                  '每月$day日',
                  style: TextStyle(
                    fontSize: selected ? 18 : 16,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_selectedDay),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final AccountStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? AppColors.primary : AppColors.textTertiary;
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.12)
          : AppColors.textTertiary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceLg,
            vertical: AppDimens.spaceSm,
          ),
          child: Text(
            status.label,
            style: TextStyle(
              color: color,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
