import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/category_icons.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../providers/installment_providers.dart';

/// 添加分期页（小青账模板）。
///
/// 通过 [GoRouterState.extra] 可传入默认账本 ID（当前未使用，取 [currentBookIdProvider]）。
class AddInstallmentPage extends ConsumerStatefulWidget {
  const AddInstallmentPage({super.key});

  @override
  ConsumerState<AddInstallmentPage> createState() =>
      _AddInstallmentPageState();
}

class _AddInstallmentPageState extends ConsumerState<AddInstallmentPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _principalController = TextEditingController();
  final TextEditingController _interestController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  int _periods = 12;
  DateTime _firstDueAt = DateTime(
    DateTime.now().year,
    DateTime.now().month + 1,
    DateTime.now().day,
  );

  String _repeatLabel = '每月';
  String _roundingLabel = '四舍五入';
  String _remainderLabel = '首期';
  String _precisionLabel = '小数点后2位';
  String _principalTimingLabel = '分期时记入';
  /// 利息扣除方式：按期均摊、首期全部扣除、尾期全部扣除。
  String _interestDeductLabel = '按期均摊';
  String _interestTimingLabel = '分期时记入';

  String? _accountId;
  String? _categoryId;

  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _principalController.dispose();
    _interestController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int get _principalMinor =>
      Money.tryParse(_principalController.text.trim()).minor;

  int get _interestMinor =>
      Money.tryParse(_interestController.text.trim()).minor;

  /// 根据「利息扣除方式」把总利息拆成每期的手续费（分）。
  ///
  /// - 按期均摊：利息平均分，余数归末期（与本金余数规则一致）。
  /// - 首期全部扣除：全部利息算入第 1 期。
  /// - 尾期全部扣除：全部利息算入最后一期。
  List<int> _buildFeeByPeriod(int totalInterest, int periods) {
    if (periods <= 0 || totalInterest <= 0) {
      return List<int>.filled(periods.clamp(1, 120), 0, growable: false);
    }
    final List<int> result = List<int>.filled(periods, 0, growable: false);
    switch (_interestDeductLabel) {
      case '首期全部扣除':
        result[0] = totalInterest;
      case '尾期全部扣除':
        result[periods - 1] = totalInterest;
      case '按期均摊':
      default:
        final int base = totalInterest ~/ periods;
        final int remainder = totalInterest - base * periods;
        for (int i = 0; i < periods; i++) {
          result[i] = base + (i == periods - 1 ? remainder : 0);
        }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const Text('添加分期'),
            Text(
              '购买商品时进行分期',
              style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                  ),
            ),
          ],
        ),
        centerTitle: true,
        actions: <Widget>[
          TextButton(
            onPressed: _saving ? null : _preview,
            child: const Text('预览'),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimens.spaceLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _buildSection(
                        '分期信息',
                        <Widget>[
                          _buildTextField(_nameController, '名称'),
                          _buildStepperRow(
                            label: '分期期数',
                            value: _periods,
                            onDecrease: _periods <= 1
                                ? null
                                : () => setState(() => _periods--),
                            onIncrease: _periods >= 120
                                ? null
                                : () => setState(() => _periods++),
                          ),
                          _buildDateRow(
                            label: '开始时间',
                            value: _firstDueAt,
                            onTap: _pickFirstDue,
                          ),
                          _buildSelectorRow(
                            label: '重复周期',
                            value: _repeatLabel,
                            subtitle: '默认按月重复，入账日与开始时间一致',
                            icon: Icons.repeat_outlined,
                            onTap: () => _showOptionSheet(
                              title: '重复周期',
                              options: const <String>['每月', '每周', '每年'],
                              selected: _repeatLabel,
                              onSelected: (String v) =>
                                  setState(() => _repeatLabel = v),
                            ),
                          ),
                          _buildSelectorRow(
                            label: '余数计算方式',
                            value: _roundingLabel,
                            icon: Icons.calculate_outlined,
                            onTap: () => _showOptionSheet(
                              title: '余数计算方式',
                              options: const <String>['四舍五入', '向上取整', '向下取整'],
                              selected: _roundingLabel,
                              onSelected: (String v) =>
                                  setState(() => _roundingLabel = v),
                            ),
                          ),
                          _buildSelectorRow(
                            label: '差额归期',
                            value: _remainderLabel,
                            icon: Icons.swap_horiz_outlined,
                            onTap: () => _showOptionSheet(
                              title: '差额归期',
                              options: const <String>['首期', '末期'],
                              selected: _remainderLabel,
                              onSelected: (String v) =>
                                  setState(() => _remainderLabel = v),
                            ),
                          ),
                          _buildSelectorRow(
                            label: '计算精度',
                            value: _precisionLabel,
                            icon: Icons.pin_outlined,
                            onTap: () => _showOptionSheet(
                              title: '计算精度',
                              options: const <String>['小数点后2位', '小数点后1位', '整数'],
                              selected: _precisionLabel,
                              onSelected: (String v) =>
                                  setState(() => _precisionLabel = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimens.spaceLg),
                      _buildSection(
                        '本金',
                        <Widget>[
                          _buildMoneyField(
                            _principalController,
                            '分期本金',
                            onChanged: (_) => setState(() {}),
                          ),
                          _buildSelectorRow(
                            label: '本金计入方式',
                            value: _principalTimingLabel,
                            subtitle: '控制本金何时从扣款账户扣除，默认每期入账时扣',
                            icon: Icons.account_balance_wallet_outlined,
                            onTap: () => _showOptionSheet(
                              title: '本金计入方式',
                              options: const <String>['分期时记入', '每期入账时扣'],
                              selected: _principalTimingLabel,
                              onSelected: (String v) => setState(
                                  () => _principalTimingLabel = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimens.spaceLg),
                      _buildSection(
                        '利息',
                        <Widget>[
                          _buildMoneyField(
                            _interestController,
                            '利息总额',
                            onChanged: (_) => setState(() {}),
                          ),
                          _buildSelectorRow(
                            label: '利息扣除方式',
                            value: _interestDeductLabel,
                            icon: Icons.percent_outlined,
                            onTap: () => _showOptionSheet(
                              title: '利息扣除方式',
                              options: const <String>[
                                '按期均摊',
                                '首期全部扣除',
                                '尾期全部扣除',
                              ],
                              selected: _interestDeductLabel,
                              onSelected: (String v) => setState(
                                  () => _interestDeductLabel = v),
                            ),
                          ),
                          _buildSelectorRow(
                            label: '利息计入方式',
                            value: _interestTimingLabel,
                            subtitle: '控制利息何时从扣款账户扣除，默认每期入账时扣',
                            icon: Icons.savings_outlined,
                            onTap: () => _showOptionSheet(
                              title: '利息计入方式',
                              options: const <String>['分期时记入', '每期入账时扣'],
                              selected: _interestTimingLabel,
                              onSelected: (String v) => setState(
                                  () => _interestTimingLabel = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimens.spaceLg),
                      _buildSection(
                        '账单信息',
                        <Widget>[
                          _buildAccountRow(),
                          _buildBookRow(),
                          _buildCategoryRow(),
                        ],
                      ),
                      const SizedBox(height: AppDimens.spaceLg),
                    ],
                  ),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceMd),
        Container(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _insertDividers(children),
          ),
        ),
      ],
    );
  }

  List<Widget> _insertDividers(List<Widget> children) {
    final List<Widget> result = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        result.add(const Divider(height: 24, indent: 0));
      }
    }
    return result;
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: AppColors.textTertiary),
        border: InputBorder.none,
        filled: false,
        contentPadding: EdgeInsets.zero,
      ),
      textInputAction: TextInputAction.next,
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
    );
  }

  Widget _buildMoneyField(
    TextEditingController controller,
    String hint, {
    ValueChanged<String>? onChanged,
  }) {
    return Row(
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          ),
          child: Text(
            '¥',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(width: AppDimens.spaceSm),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textTertiary),
              border: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: onChanged,
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
          ),
        ),
      ],
    );
  }

  Widget _buildStepperRow({
    required String label,
    required int value,
    required VoidCallback? onDecrease,
    required VoidCallback? onIncrease,
  }) {
    return Row(
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: onDecrease,
          color: AppColors.textSecondary,
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: onIncrease,
          color: AppColors.textSecondary,
        ),
      ],
    );
  }

  Widget _buildDateRow({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Icon(
            Icons.access_time_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Text(
            DateFormat('yyyy年M月d日 HH:mm').format(value),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          Icon(
            Icons.chevron_right,
            size: 18,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorRow({
    required String label,
    required String value,
    String? subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          Icon(
            Icons.chevron_right,
            size: 18,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }

  Future<void> _pickFirstDue() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _firstDueAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _firstDueAt = picked);
    }
  }

  Future<void> _showOptionSheet({
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) async {
    final String? result = await showModalBottomSheet<String>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusLg),
        ),
      ),
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              child: Text(
                title,
                style: Theme.of(ctx).textTheme.titleSmall,
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext ctx, int index) {
                  final String option = options[index];
                  return ListTile(
                    title: Text(option),
                    trailing: option == selected
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () => Navigator.of(ctx).pop(option),
                  );
                },
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      onSelected(result);
    }
  }

  Widget _buildAccountRow() {
    final AsyncValue<List<Account>> accounts = ref.watch(accountsProvider);
    return accounts.when(
      data: (List<Account> list) {
        final Account? selected =
            list.where((Account a) => a.id == _accountId).firstOrNull;
        return InkWell(
          onTap: list.isEmpty
              ? null
              : () => _showAccountPicker(list),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.credit_card_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: Text(
                  selected?.name ?? '请选择负债账户',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: selected != null
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                      ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (Object e, _) => Text('账户加载失败：$e'),
    );
  }

  Future<void> _showAccountPicker(List<Account> accounts) async {
    final String? result = await showModalBottomSheet<String>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusLg),
        ),
      ),
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              child: Text(
                '选择负债账户',
                style: Theme.of(ctx).textTheme.titleSmall,
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: accounts.length,
                itemBuilder: (BuildContext ctx, int index) {
                  final Account account = accounts[index];
                  return ListTile(
                    title: Text(account.name),
                    trailing: account.id == _accountId
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () => Navigator.of(ctx).pop(account.id),
                  );
                },
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _accountId = result);
    }
  }

  Widget _buildBookRow() {
    final AsyncValue<Book?> book = ref.watch(currentBookProvider);
    return book.when(
      data: (Book? value) => InkWell(
        onTap: () {},
        child: Row(
          children: <Widget>[
            const CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary,
              child: Text(
                '账',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    value?.name ?? '默认账本',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    '默认账本',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
      loading: () => const LinearProgressIndicator(),
      error: (Object e, _) => Text('账本加载失败：$e'),
    );
  }

  Widget _buildCategoryRow() {
    final AsyncValue<List<Category>> categories =
        ref.watch(expenseCategoriesProvider);
    return categories.when(
      data: (List<Category> list) {
        final Category? selected =
            list.where((Category c) => c.id == _categoryId).firstOrNull;
        return InkWell(
          onTap: list.isEmpty ? null : () => _showCategoryPicker(list),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.category_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: Text(
                  selected?.name ?? '分类',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: selected != null
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                      ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (Object e, _) => Text('分类加载失败：$e'),
    );
  }

  Future<void> _showCategoryPicker(List<Category> categories) async {
    final List<Category> parents = categories
        .where((Category c) => c.parentId == null)
        .toList(growable: false);
    final String? result = await showModalBottomSheet<String>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusLg),
        ),
      ),
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              child: Text(
                '选择分类',
                style: Theme.of(ctx).textTheme.titleSmall,
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: parents.length,
                itemBuilder: (BuildContext ctx, int index) {
                  final Category category = parents[index];
                  return ListTile(
                    leading: category.iconKey != null
                        ? Icon(categoryIconData(category.iconKey))
                        : null,
                    title: Text(category.name),
                    trailing: category.id == _categoryId
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () => Navigator.of(ctx).pop(category.id),
                  );
                },
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _categoryId = result);
    }
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceMd,
        AppDimens.spaceLg,
        AppDimens.spaceLg,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton(
              onPressed: _saving ? null : _preview,
              child: const Text('预览'),
            ),
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: FilledButton(
              onPressed: _saving ? null : _save,
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
        ],
      ),
    );
  }

  Future<void> _save() async {
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      _toast('请填写分期名称');
      return;
    }
    final int principal = _principalMinor;
    if (principal <= 0) {
      _toast('请输入大于 0 的分期本金');
      return;
    }
    if (_periods <= 0 || _periods > 120) {
      _toast('期数需在 1 - 120 之间');
      return;
    }

    setState(() => _saving = true);
    try {
      final String bookId = ref.read(currentBookIdProvider);
      final List<int> feeByPeriod = _buildFeeByPeriod(_interestMinor, _periods);
      await ref.read(installmentRepositoryProvider).addPlan(
            bookId: bookId,
            title: name,
            totalMinor: principal,
            totalPeriods: _periods,
            feeByPeriodMinor: feeByPeriod,
            firstDueAt: _firstDueAt.toUtc().millisecondsSinceEpoch,
            accountId: _accountId,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );
      if (mounted) {
        context.pop();
      }
    } on AppFailure catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _preview() {
    final String name = _nameController.text.trim();
    final int principal = _principalMinor;
    final int interest = _interestMinor;
    if (principal <= 0 || _periods <= 0) {
      _toast('请输入本金和期数后再预览');
      return;
    }

    final int base = principal ~/ _periods;
    final int remainder = principal - base * _periods;
    final List<int> feeByPeriod = _buildFeeByPeriod(interest, _periods);

    showModalBottomSheet<void>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusLg),
        ),
      ),
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              child: Text(
                name.isEmpty ? '分期预览' : '「$name」预览',
                style: Theme.of(ctx).textTheme.titleSmall,
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _periods,
                itemBuilder: (BuildContext ctx, int index) {
                  final int amount = base +
                      (_remainderLabel == '首期' && index == 0 ? remainder : 0) +
                      (_remainderLabel == '末期' && index == _periods - 1
                          ? remainder
                          : 0);
                  final int periodFee = feeByPeriod.length > index
                      ? feeByPeriod[index]
                      : 0;
                  final int total = amount + periodFee;
                  return ListTile(
                    dense: true,
                    title: Text('第 ${index + 1} 期'),
                    subtitle: Text(
                      DateFormat('yyyy-MM-dd').format(
                        DateTime(
                          _firstDueAt.year,
                          _firstDueAt.month + index,
                          _firstDueAt.day,
                        ),
                      ),
                    ),
                    trailing: Text(Money.fromMinor(total).format()),
                  );
                },
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
          ],
        ),
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
