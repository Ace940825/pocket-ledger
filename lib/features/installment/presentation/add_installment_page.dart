import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../routing/app_router.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/category_icons.dart';
import '../../../shared/widgets/date_picker_sheet.dart';
import '../../../shared/widgets/repeat_picker_sheet.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../record/presentation/account_picker_sheet.dart';
import '../domain/installment_dates.dart';
import '../domain/repeat_rule.dart';
import '../providers/installment_providers.dart';
import '../../../shared/widgets/app_toast.dart';

/// 添加分期页（小青账模板）。
///
/// 通过 [GoRouterState.extra] 可传入默认账本 ID（当前未使用，取 [currentBookIdProvider]）。
class AddInstallmentPage extends ConsumerStatefulWidget {
  const AddInstallmentPage({super.key, this.showAppBar = true});

  /// 是否显示独立 AppBar 和 SafeArea。
  ///
  /// - `true`：作为独立页面使用，包含 `Scaffold(AppBar+SafeArea)`。
  /// - `false`：作为内嵌组件使用，直接返回 body，避免与外层页面的 AppBar / 安全区叠加。
  final bool showAppBar;

  @override
  ConsumerState<AddInstallmentPage> createState() => _AddInstallmentPageState();
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

  late InstallmentRepeatRule _repeatRule;
  String _roundingLabel = '四舍五入';
  String _remainderLabel = '首期';
  String _precisionLabel = '小数点后2位';
  String _principalTimingLabel = '分期时计入';

  /// 利息扣除方式：按期均摊、首期全部扣除、尾期全部扣除。
  String _interestDeductLabel = '按期均摊';
  String _interestTimingLabel = '分期时计入';

  String? _accountId;
  String? _categoryId;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repeatRule = InstallmentRepeatRule.defaultFor(
      RepeatUnit.month,
      firstDue: _firstDueAt,
    );
  }

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

    final Widget body = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
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
                        min: 1,
                        max: 120,
                        onChanged: (int value) =>
                            setState(() => _periods = value),
                      ),
                      _buildDateRow(
                        label: '开始时间',
                        value: _firstDueAt,
                        onTap: _pickFirstDue,
                      ),
                      _buildSelectorRow(
                        label: '重复周期',
                        value: _repeatRule.displayLabel(
                          fallbackDay: _firstDueAt.day,
                        ),
                        icon: Icons.repeat_outlined,
                        onTap: _pickRepeatRule,
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
                        icon: Icons.account_balance_wallet_outlined,
                        onTap: () => _showOptionSheet(
                          title: '本金计入方式',
                          options: const <String>['分期时计入', '分期时全部计入'],
                          selected: _principalTimingLabel,
                          onSelected: (String v) =>
                              setState(() => _principalTimingLabel = v),
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
                          onSelected: (String v) =>
                              setState(() => _interestDeductLabel = v),
                        ),
                      ),
                      _buildSelectorRow(
                        label: '利息计入方式',
                        value: _interestTimingLabel,
                        icon: Icons.savings_outlined,
                        onTap: () => _showOptionSheet(
                          title: '利息计入方式',
                          options: const <String>['分期时计入', '分期时全部计入'],
                          selected: _interestTimingLabel,
                          onSelected: (String v) =>
                              setState(() => _interestTimingLabel = v),
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
    );

    if (widget.showAppBar) {
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
        body: SafeArea(child: body),
      );
    }
    return body;
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

  /// 统一输入框装饰：所有状态边框、圆角、填充色及内外边距保持一致，
  /// 并通过占位 [prefixIcon] 强制内容区高度与带 ¥ 符号的金额输入框对齐。
  ///
  /// [alignWithMoneyField] 为 true 时，若未提供真实 prefixIcon，会自动塞入一个
  /// 与 ¥ 符号同宽（44px）的透明占位，使普通输入框的文本起始位置与金额输入框对齐。
  InputDecoration _buildFieldDecoration({
    required String hintText,
    Widget? prefixIcon,
    bool alignWithMoneyField = false,
  }) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      borderSide: const BorderSide(color: AppColors.divider),
    );
    // 当没有真实 prefixIcon 时，塞入一个透明占位，
    // 让普通输入框的内容区高度与带 ¥ 的输入框（prefixIcon 24×24）完全一致。
    // 若 [alignWithMoneyField] 为 true，占位宽度与真实 ¥ prefixIcon（44px）相同，
    // 使名称等普通输入框的文本与金额输入框水平对齐，同时自然留出左留白。
    final bool hasRealPrefix = prefixIcon != null;
    final bool useWidePlaceholder = !hasRealPrefix && alignWithMoneyField;
    final Widget effectivePrefixIcon = hasRealPrefix
        ? prefixIcon
        : SizedBox(width: useWidePlaceholder ? 24 : 0, height: 24);
    return InputDecoration(
      hintText: hintText,
      hintStyle: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(color: AppColors.textTertiary),
      prefixIcon: effectivePrefixIcon,
      prefixIconConstraints: BoxConstraints(
        minWidth: hasRealPrefix || useWidePlaceholder ? 44 : 0,
        minHeight: 24,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs / 2,
      ),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      disabledBorder: border,
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      decoration: _buildFieldDecoration(
        hintText: hint,
        alignWithMoneyField: true,
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
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: _buildFieldDecoration(
        hintText: hint,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Container(
            width: 24,
            height: 24,
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
        ),
      ),
      onChanged: onChanged,
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
    );
  }

  Widget _buildStepperRow({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        _InlineNumberStepper(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
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
            DateFormat('yyyy年M月d日').format(value),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
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
        ],
      ),
    );
  }

  /// 带边框圆角的选择框，与输入框共用 [_buildFieldDecoration]，
  /// 通过 [InputDecorator] 保证边框、圆角、填充及高度完全一致。
  Widget _buildOutlinedSelector({
    required Widget child,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        child: InputDecorator(
          decoration: _buildFieldDecoration(hintText: ''),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 24),
            child: child,
          ),
        ),
      ),
    );
  }

  Future<void> _pickFirstDue() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final DateTime? picked = await DatePickerSheet.show(
      context,
      initialDate: _firstDueAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      currentTimeLabel: '当前时间',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    if (picked != null && mounted) {
      setState(() {
        _firstDueAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _firstDueAt.hour,
          _firstDueAt.minute,
          _firstDueAt.second,
          _firstDueAt.millisecond,
          _firstDueAt.microsecond,
        );
        // 当开始时间改变时，把重复规则也同步到新的日期/月份，避免「每月 31 日」
        // 但开始时间只有 30 号这类错位。
        _repeatRule = InstallmentRepeatRule.defaultFor(
          _repeatRule.unit,
          firstDue: _firstDueAt,
        ).copyWith(interval: _repeatRule.interval);
      });
    }
  }

  Future<void> _pickRepeatRule() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final InstallmentRepeatRule? picked = await RepeatPickerSheet.show(
      context,
      initialRule: _repeatRule,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    if (picked != null && mounted) {
      setState(() => _repeatRule = picked);
    }
  }

  Future<void> _showOptionSheet({
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
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
    FocusManager.instance.primaryFocus?.unfocus();
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
        return _buildOutlinedSelector(
          onTap: list.isEmpty ? null : () => _showAccountPicker(list),
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
            ],
          ),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (Object e, _) => Text('账户加载失败：$e'),
    );
  }

  Future<void> _showAccountPicker(List<Account> accounts) async {
    FocusManager.instance.primaryFocus?.unfocus();
    // 统一 A 模板网格账户选择弹窗（与记一笔页各账户键同源）。
    final String? result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => AccountPickerSheet(
        accounts: accounts,
        selectedId: _accountId,
        title: '选择负债账户',
        // 负债账户可不选（addPlan.accountId 可空）：仅建分期计划，不关联账户。
        showNoneRow: true,
        noneSubtitle: '暂不关联负债账户',
        onReload: () => ref.invalidate(accountsProvider),
        // 点添加/资产管理：不关闭当前弹窗，把目标页压在上面。
        onAdd: () {
          if (mounted) context.push(Routes.accountAdd);
        },
        onManage: () {
          if (mounted) context.push(Routes.accountManage);
        },
        // 点「不选择具体账户」时 onConfirm 收到 null，以空串区分
        // 「明确清空」（''）与「下滑关闭」（null）。
        onConfirm: (Account? acc) => Navigator.of(ctx).pop(acc?.id ?? ''),
      ),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    if (result != null && mounted) {
      // 「不选择具体账户」（空串）：清除已选负债账户。
      setState(() => _accountId = result.isEmpty ? null : result);
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
        return _buildOutlinedSelector(
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
            ],
          ),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (Object e, _) => Text('分类加载失败：$e'),
    );
  }

  Future<void> _showCategoryPicker(List<Category> categories) async {
    FocusManager.instance.primaryFocus?.unfocus();
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
    FocusManager.instance.primaryFocus?.unfocus();
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
            repeatRule: _repeatRule,
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
    final List<DateTime> dueDates = computeInstallmentDueDates(
      firstDue: _firstDueAt,
      rule: _repeatRule,
      totalPeriods: _periods,
    );

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
                  final int periodFee =
                      feeByPeriod.length > index ? feeByPeriod[index] : 0;
                  final int total = amount + periodFee;
                  return ListTile(
                    dense: true,
                    title: Text('第 ${index + 1} 期'),
                    subtitle: Text(
                      DateFormat('yyyy-MM-dd').format(dueDates[index]),
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
    showAppToast(context, message);
  }
}

/// 内联可编辑数字步进器。
///
/// 中间数字为可编辑文本框，支持数字键盘直接输入；失去焦点或提交时自动
/// 校验并限制在 [min]、[max] 范围。两侧 +/- 按钮仍可按步调整。
class _InlineNumberStepper extends StatefulWidget {
  const _InlineNumberStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  State<_InlineNumberStepper> createState() => _InlineNumberStepperState();
}

class _InlineNumberStepperState extends State<_InlineNumberStepper> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _InlineNumberStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focusNode.hasFocus) {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _commit();
    }
  }

  void _commit() {
    final int? parsed = int.tryParse(_controller.text);
    if (parsed == null) {
      _controller.text = '${widget.value}';
      return;
    }
    final int clamped = parsed.clamp(widget.min, widget.max);
    _controller.text = '$clamped';
    if (clamped != widget.value) {
      widget.onChanged(clamped);
    }
  }

  int _parseCurrent() {
    return int.tryParse(_controller.text)?.clamp(widget.min, widget.max) ??
        widget.value;
  }

  void _decrease() {
    final int current = _parseCurrent();
    final int next = (current - 1).clamp(widget.min, widget.max);
    _controller.text = '$next';
    if (next != widget.value) {
      widget.onChanged(next);
    }
  }

  void _increase() {
    final int current = _parseCurrent();
    final int next = (current + 1).clamp(widget.min, widget.max);
    _controller.text = '$next';
    if (next != widget.value) {
      widget.onChanged(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: widget.value <= widget.min ? null : _decrease,
          color: AppColors.textSecondary,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
        ),
        SizedBox(
          width: 48,
          height: 30,
          child: Center(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              keyboardType: TextInputType.number,
              maxLines: 1,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                    color: AppColors.textPrimary,
                  ),
              strutStyle: const StrutStyle(
                height: 1.0,
                leading: 0,
                forceStrutHeight: true,
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
              onSubmitted: (_) => _commit(),
              onTap: () => _controller.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _controller.text.length,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: widget.value >= widget.max ? null : _increase,
          color: AppColors.textSecondary,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
        ),
      ],
    );
  }
}
