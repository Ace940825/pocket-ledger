import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/date_field.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../ledger/providers/ledger_providers.dart';
import '../../lend/providers/lend_providers.dart';
import '../../reimbursement/providers/reimbursement_providers.dart';
import '../../savings/providers/savings_providers.dart';
import '../record_tab.dart';
import '../widgets/amount_keypad.dart';

/// 退款模式：全额退回 / AA 付款分摊。
enum RefundMode { full, aa }

/// 转账页手续费 / 优惠输入模式。
enum _FeeInputType { fee, discount }

/// 统一「记一笔」底部面板：顶部 7 个 Tab（支出/收入/转账/借还/报销/退款/存钱），
/// 中间是对应表单，底部是自定义数字键盘。
///
/// 设计要点：
/// - 7 种类型映射到既有 [SourceModule] 或独立表（借还=LendRecords /
///   报销=Reimbursements / 存钱=SavingsGoals），不新增任何 intEnum 下标，
///   避免触发 tables.dart 注释警告的迁移灾难。
/// - 仅「退款」用到新追加的 [SourceModule.refund]（append-only 安全）。
/// - 金额统一走自定义键盘，落库时用 [Money.fromDecimal] 转「分」整数。
Future<void> openRecordSheet(
  BuildContext context, {
  RecordTab initialTab = RecordTab.expense,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (BuildContext ctx) => RecordSheet(initialTab: initialTab),
  );
}

class RecordSheet extends ConsumerStatefulWidget {
  const RecordSheet({super.key, this.initialTab = RecordTab.expense});

  final RecordTab initialTab;

  @override
  ConsumerState<RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends ConsumerState<RecordSheet> {
  RecordTab _tab = RecordTab.expense;

  // 金额（自定义键盘维护的原始字符串，单位：元）
  String _amount = '';

  // 小青账键盘算术运算暂存：previous operand / operator。
  String _pendingAmount = '';
  String? _pendingOperator;

  // 账户
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;

  // 日期 / 备注 / 通用备注
  DateTime _occurredAt = DateTime.now();

  // 借还
  LendDirection _lendDir = LendDirection.lendOut;
  LendStatus _lendStatus = LendStatus.ongoing;

  // 报销
  ReimbursementStatus _rbStatus = ReimbursementStatus.pending;
  bool _rbExclude = false;

  // 退款 AA
  RefundMode _refundMode = RefundMode.full;
  bool _refundAuto = true;
  int _refundPeople = 2;
  final TextEditingController _refundTotalController = TextEditingController();

  // 存钱
  bool _saveDeposit = true;
  String? _goalId;

  // 支出 / 收入新布局状态
  bool _keyboardExpanded = true;
  bool _isReimbursable = false;
  bool _excludeFromStats = false;
  bool _excludeFromBudget = false;
  final List<String> _tags = <String>[];
  String? _discountAmount;

  // 转账
  String? _feeAmount;
  _FeeInputType _feeInputType = _FeeInputType.fee;
  final TextEditingController _feeInputController = TextEditingController();
  final FocusNode _feeInputFocusNode = FocusNode();

  bool _saving = false;

  final TextEditingController _noteController = TextEditingController();
  final FocusNode _noteFocusNode = FocusNode();
  final TextEditingController _counterpartyController = TextEditingController();
  final TextEditingController _rbTitleController = TextEditingController();
  final TextEditingController _rbPayerController =
      TextEditingController(text: '本人');
  final TextEditingController _rbTargetController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _noteFocusNode.addListener(_onNoteFocusChanged);
    _feeInputFocusNode.addListener(_onFeeInputFocusChanged);
  }

  void _onNoteFocusChanged() {
    if (_noteFocusNode.hasFocus) {
      // 备注输入使用系统键盘，临时收起自定义数字键盘避免冲突。
      if (mounted && _keyboardExpanded) {
        setState(() => _keyboardExpanded = false);
      }
    }
  }

  void _onFeeInputFocusChanged() {
    if (_feeInputFocusNode.hasFocus) {
      // 手续费/优惠输入使用系统键盘，临时收起自定义数字键盘避免冲突。
      if (mounted && _keyboardExpanded) {
        setState(() => _keyboardExpanded = false);
      }
    }
  }

  @override
  void dispose() {
    _noteFocusNode.removeListener(_onNoteFocusChanged);
    _noteFocusNode.dispose();
    _feeInputFocusNode.removeListener(_onFeeInputFocusChanged);
    _feeInputFocusNode.dispose();
    _feeInputController.dispose();
    _noteController.dispose();
    _counterpartyController.dispose();
    _rbTitleController.dispose();
    _rbPayerController.dispose();
    _rbTargetController.dispose();
    _refundTotalController.dispose();
    super.dispose();
  }

  /// AA 自动退款金额：他人应还份额 = 垫付总额 × (人数-1) / 人数。
  int get _refundComputedMinor {
    final int total = Money.tryParse(_refundTotalController.text).minor;
    if (total <= 0 || _refundPeople < 2) return 0;
    return (total * (_refundPeople - 1) / _refundPeople).round();
  }

  /// 是否处于「退款 + AA + 自动」模式：金额由垫付总额/人数算出，键盘只读。
  bool get _refundAutoMode =>
      _tab == RecordTab.refund && _refundMode == RefundMode.aa && _refundAuto;

  int get _amountMinor {
    if (_refundAutoMode) return _refundComputedMinor;
    return Money.tryParse(_effectiveAmount).minor;
  }

  /// 当前应保存的字符串金额：若存在 pending 运算符，先计算再返回。
  ///
  /// 关键边界：连续按运算符或保存前已输入完上一轮（[ _amount] 为空但挂起结果存在）
  /// 时，直接以挂起的 [ _pendingAmount] 作为最终结果，避免返回空串被解析成 0。
  String get _effectiveAmount {
    if (_pendingOperator == null || _pendingAmount.isEmpty) {
      return _amount;
    }
    if (_amount.isEmpty) {
      // 上一轮运算已完成（如 12-3 后又按了一次运算符，或即将保存），
      // 没有新的第二操作数可算，直接取挂起结果。
      return _pendingAmount;
    }
    final int a = Money.tryParse(_pendingAmount).minor;
    final int b = Money.tryParse(_amount).minor;
    final int result = _pendingOperator == '+' ? a + b : a - b;
    return Money.fromMinor(result).decimal.toStringAsFixed(2);
  }

  String get _displayAmount {
    if (_refundAutoMode) {
      final int m = _refundComputedMinor;
      return m <= 0 ? '0.00' : Money.fromMinor(m).decimal.toStringAsFixed(2);
    }
    // 展示当前输入；无输入时展示挂起的运算结果，让计算过程可见。
    if (_amount.isNotEmpty) return _amount;
    if (_pendingAmount.isNotEmpty) return _pendingAmount;
    return '0.00';
  }

  /// 转账手续费金额（分）。未输入时返回 0。
  int get _feeMinor {
    if (_feeAmount == null || _feeAmount!.isEmpty) return 0;
    return Money.tryParse(_feeAmount!).minor;
  }

  /// 转账优惠金额（分）。未输入时返回 0。
  int get _discountMinor {
    if (_discountAmount == null || _discountAmount!.isEmpty) return 0;
    return Money.tryParse(_discountAmount!).minor;
  }

  // ---- 保存 ----

  Future<void> _save({bool andMore = false}) async {
    final int minor = _amountMinor;
    if (minor <= 0) {
      _toast('请输入大于 0 的金额');
      return;
    }
    final String bookId = ref.read(currentBookIdProvider);
    final int occurredAt = _occurredAt.toUtc().millisecondsSinceEpoch;

    setState(() => _saving = true);
    try {
      switch (_tab) {
        case RecordTab.expense:
        case RecordTab.income:
          if (_accountId == null) {
            _toast('请选择账户');
            return;
          }
          await ref.read(transactionRepositoryProvider).add(
                bookId: bookId,
                type: _tab == RecordTab.expense
                    ? TxnType.expense
                    : TxnType.income,
                amountMinor: minor,
                accountId: _accountId!,
                categoryId: _categoryId,
                note: _noteController.text.trim(),
                occurredAt: occurredAt,
                sourceModule: SourceModule.ledger,
              );
        case RecordTab.transfer:
          if (_accountId == null || _toAccountId == null) {
            _toast('请选择转出与转入账户');
            return;
          }
          if (_accountId == _toAccountId) {
            _toast('转出与转入账户不能相同');
            return;
          }
          await ref.read(transactionRepositoryProvider).transfer(
                bookId: bookId,
                fromAccountId: _accountId!,
                toAccountId: _toAccountId!,
                amountMinor: minor,
                feeMinor: _feeMinor,
                discountMinor: _discountMinor,
                occurredAt: occurredAt,
                note: _noteController.text.trim(),
              );
        case RecordTab.refund:
          if (_accountId == null) {
            _toast('请选择退回账户');
            return;
          }
          // 退款 = 钱退回账户，按「收入」方向增加账户余额，来源标记为 refund。
          String refundNote = _noteController.text.trim();
          if (_refundMode == RefundMode.aa) {
            final int total = Money.tryParse(_refundTotalController.text).minor;
            final String modeText = _refundAuto ? '自动' : '自定义';
            final String detail = '[AA 退款] 垫付总额：'
                '${Money.fromMinor(total).format()}，均摊 $_refundPeople 人，'
                '$modeText，退回 ${Money.fromMinor(minor).format()}';
            refundNote = refundNote.isEmpty ? detail : '$refundNote\n$detail';
          }
          await ref.read(transactionRepositoryProvider).add(
                bookId: bookId,
                type: TxnType.income,
                amountMinor: minor,
                accountId: _accountId!,
                note: refundNote,
                occurredAt: occurredAt,
                sourceModule: SourceModule.refund,
              );
        case RecordTab.lend:
          if (_counterpartyController.text.trim().isEmpty) {
            _toast('请填写对方');
            return;
          }
          await ref.read(lendRepositoryProvider).add(
                bookId: bookId,
                direction: _lendDir,
                status: _lendStatus,
                counterparty: _counterpartyController.text.trim(),
                amountMinor: minor,
                occurredAt: occurredAt,
                dueAt: null,
                note: _noteController.text.trim(),
              );
        case RecordTab.reimbursement:
          if (_rbTitleController.text.trim().isEmpty) {
            _toast('请填写事由');
            return;
          }
          await ref.read(reimbursementRepositoryProvider).add(
                bookId: bookId,
                title: _rbTitleController.text.trim(),
                status: _rbStatus,
                amountMinor: minor,
                payer: _rbPayerController.text.trim().isEmpty
                    ? '本人'
                    : _rbPayerController.text.trim(),
                occurredAt: occurredAt,
                target: _rbTargetController.text.trim().isEmpty
                    ? null
                    : _rbTargetController.text.trim(),
                receivedAt: null,
                note: _noteController.text.trim(),
                excludeFromStats: _rbExclude,
              );
        case RecordTab.savings:
          if (_goalId == null) {
            _toast('请选择储蓄目标');
            return;
          }
          await ref.read(savingsRepositoryProvider).deposit(
                _goalId!,
                _saveDeposit ? minor : -minor,
              );
      }

      if (!mounted) return;
      // 清空 pending 运算状态，避免影响下一笔。
      _pendingAmount = '';
      _pendingOperator = null;
      if (andMore) {
        // 连续记账：保留 Tab 与账户，清空金额与文本，方便快速下一笔。
        setState(() {
          _amount = '';
          _categoryId = null;
          _noteController.clear();
          _counterpartyController.clear();
          _rbTitleController.clear();
          _rbPayerController.text = '本人';
          _rbTargetController.clear();
          _refundTotalController.clear();
          _feeAmount = null;
          _discountAmount = null;
          _feeInputType = _FeeInputType.fee;
          _feeInputController.clear();
        });
        return;
      }
      context.pop();
    } on AppFailure catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// 处理小青账键盘的「+」「-」运算符。
  void _onOperator(String operator) {
    if (_amount.isEmpty && _pendingAmount.isEmpty) return;
    setState(() {
      if (_amount.isNotEmpty &&
          _pendingAmount.isNotEmpty &&
          _pendingOperator != null) {
        // 连续运算：先结算上一轮，再挂起当前运算符。
        final int a = Money.tryParse(_pendingAmount).minor;
        final int b = Money.tryParse(_amount).minor;
        final int result = _pendingOperator == '+' ? a + b : a - b;
        _pendingAmount = Money.fromMinor(result).decimal.toStringAsFixed(2);
        _pendingOperator = operator;
        _amount = '';
      } else if (_amount.isNotEmpty) {
        _pendingAmount = _amount;
        _pendingOperator = operator;
        _amount = '';
      } else {
        // 当前无新输入，仅切换运算符。
        _pendingOperator = operator;
      }
    });
  }

  /// 删除键逻辑：先删当前输入，当前输入为空时删除运算符并恢复第一操作数。
  void _onBackspace() {
    if (_amount.isNotEmpty) {
      setState(() => _amount = _amount.substring(0, _amount.length - 1));
      return;
    }
    if (_pendingOperator != null) {
      setState(() {
        // 恢复第一操作数到当前输入，撤销运算符。
        _amount = _pendingAmount;
        _pendingOperator = null;
        _pendingAmount = '';
      });
    }
  }

  // ---- 表单字段 ----

  Widget _amountDisplay() {
    final ThemeData theme = Theme.of(context);
    final String shown = _displayAmount.isEmpty ? '0.00' : _displayAmount;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Text(
            '¥ $shown',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.backspace_outlined),
          // AA 自动模式下金额由垫付总额/人数算出，键盘只读，删除按钮禁用。
          onPressed: _refundAutoMode
              ? null
              : () => setState(() {
                    _amount = _amount.isNotEmpty
                        ? _amount.substring(0, _amount.length - 1)
                        : '';
                  }),
        ),
      ],
    );
  }

  Widget _accountField({
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
    String? excludeId,
  }) {
    final AsyncValue<List<Account>> accounts = ref.watch(accountsProvider);
    return accounts.when(
      data: (List<Account> list) {
        final List<Account> shown = (excludeId != null && list.length > 1)
            ? list.where((Account a) => a.id != excludeId).toList()
            : list;
        final String? safe =
            shown.any((Account a) => a.id == value) ? value : null;
        if (shown.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceMd),
            child: Text(
              '还没有账户，请先到「账户」页添加',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
        }
        return DropdownButtonFormField<String>(
          value: safe,
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
      error: (Object e, _) => Text('账户加载失败：$e'),
    );
  }

  Widget _categoryField() {
    final AsyncValue<List<Category>> cats = ref.watch(
      _tab == RecordTab.income
          ? incomeCategoriesProvider
          : expenseCategoriesProvider,
    );
    return cats.when(
      data: (List<Category> list) {
        final String? safe =
            list.any((Category c) => c.id == _categoryId) ? _categoryId : null;
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceMd),
            child: Text(
              '还没有分类，请先到「分类」页添加',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
        }
        return DropdownButtonFormField<String>(
          value: safe,
          decoration: const InputDecoration(labelText: '分类'),
          items: list
              .map(
                (Category c) => DropdownMenuItem<String>(
                  value: c.id,
                  child: Text(c.name),
                ),
              )
              .toList(growable: false),
          onChanged: (String? v) => setState(() => _categoryId = v),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (Object e, _) => Text('分类加载失败：$e'),
    );
  }

  Widget _dateField() => DateField(
        label: '日期',
        value: _occurredAt,
        onChanged: (DateTime? v) =>
            setState(() => _occurredAt = v ?? DateTime.now()),
      );

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
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

  Widget _noteField() => TextField(
        controller: _noteController,
        decoration: const InputDecoration(labelText: '备注'),
        maxLines: 2,
      );

  /// AA 均摊人数步进器：最少 2 人（AA 才有意义），上限 20 人。
  Widget _refundPeopleField() {
    return Row(
      children: <Widget>[
        const Expanded(child: Text('均摊人数')),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed:
              _refundPeople > 2 ? () => setState(() => _refundPeople--) : null,
        ),
        Text('$_refundPeople', style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed:
              _refundPeople < 20 ? () => setState(() => _refundPeople++) : null,
        ),
        const Text(' 人'),
      ],
    );
  }

  /// AA 自动模式金额提示：他人应还 = 垫付总额 × (人数-1) / 人数。
  Widget _refundAaHint() {
    final int total = Money.tryParse(_refundTotalController.text).minor;
    final int m = _refundComputedMinor;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          '自动退回 ${Money.fromMinor(m).format()}'
          '（垫付 ${Money.fromMinor(total).format()}'
          ' ÷ $_refundPeople 人 × ${_refundPeople - 1} 人）',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }

  Widget _goalField() {
    final AsyncValue<List<SavingsGoal>> goals = ref.watch(savingsListProvider);
    return goals.when(
      data: (List<SavingsGoal> list) {
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceMd),
            child: Text(
              '还没有储蓄目标，请先到「储蓄」页创建',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
        }
        final String? safe =
            list.any((SavingsGoal g) => g.id == _goalId) ? _goalId : null;
        return DropdownButtonFormField<String>(
          value: safe,
          decoration: const InputDecoration(labelText: '储蓄目标'),
          items: list
              .map(
                (SavingsGoal g) => DropdownMenuItem<String>(
                  value: g.id,
                  child: Text(
                    '${g.name}（${Money.fromMinor(g.currentMinor).format()}'
                    '/${Money.fromMinor(g.targetMinor).format()}）',
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: (String? v) => setState(() => _goalId = v),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (Object e, _) => Text('目标加载失败：$e'),
    );
  }

  List<Widget> _formFields() {
    switch (_tab) {
      case RecordTab.expense:
      case RecordTab.income:
        return <Widget>[
          _categoryField(),
          const FormGap(),
          _accountField(
            label: '账户',
            value: _accountId,
            onChanged: (String? v) => setState(() => _accountId = v),
          ),
          const FormGap(),
          _dateField(),
          const FormGap(),
          _noteField(),
        ];
      case RecordTab.transfer:
        return <Widget>[
          _accountField(
            label: '转出账户',
            value: _accountId,
            excludeId: _toAccountId,
            onChanged: (String? v) => setState(() => _accountId = v),
          ),
          const FormGap(),
          _accountField(
            label: '转入账户',
            value: _toAccountId,
            excludeId: _accountId,
            onChanged: (String? v) => setState(() => _toAccountId = v),
          ),
          const FormGap(),
          _dateField(),
          const FormGap(),
          _noteField(),
        ];
      case RecordTab.refund:
        return <Widget>[
          _accountField(
            label: '退回账户',
            value: _accountId,
            onChanged: (String? v) => setState(() => _accountId = v),
          ),
          const FormGap(),
          SegmentedButton<RefundMode>(
            segments: const <ButtonSegment<RefundMode>>[
              ButtonSegment<RefundMode>(
                value: RefundMode.full,
                label: Text('全额退款'),
                icon: Icon(Icons.replay),
              ),
              ButtonSegment<RefundMode>(
                value: RefundMode.aa,
                label: Text('AA 付款'),
                icon: Icon(Icons.group),
              ),
            ],
            selected: <RefundMode>{_refundMode},
            onSelectionChanged: (Set<RefundMode> next) =>
                setState(() => _refundMode = next.first),
          ),
          if (_refundMode == RefundMode.aa) ...<Widget>[
            const FormGap(),
            AmountField(
              controller: _refundTotalController,
              label: '垫付总额',
              helperText: '你先垫付的总额（已含你自己的份额）',
            ),
            const FormGap(),
            _refundPeopleField(),
            const FormGap(),
            SegmentedButton<bool>(
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(value: true, label: Text('自动')),
                ButtonSegment<bool>(value: false, label: Text('自定义')),
              ],
              selected: <bool>{_refundAuto},
              onSelectionChanged: (Set<bool> next) =>
                  setState(() => _refundAuto = next.first),
            ),
            const FormGap(),
            if (_refundAuto)
              _refundAaHint()
            else
              const Text('请在底部键盘输入实际退回账户的金额'),
            const FormGap(),
          ],
          _dateField(),
          const FormGap(),
          _noteField(),
        ];
      case RecordTab.lend:
        return <Widget>[
          TextField(
            controller: _counterpartyController,
            decoration: const InputDecoration(labelText: '对方（人/单位）'),
          ),
          const FormGap(),
          EnumDropdown<LendDirection>(
            label: '方向',
            value: _lendDir,
            values: LendDirection.values,
            labelOf: (LendDirection d) => d.label,
            onChanged: (LendDirection d) => setState(() => _lendDir = d),
          ),
          const FormGap(),
          EnumDropdown<LendStatus>(
            label: '状态',
            value: _lendStatus,
            values: LendStatus.values,
            labelOf: (LendStatus s) => s.label,
            onChanged: (LendStatus s) => setState(() => _lendStatus = s),
          ),
          const FormGap(),
          _dateField(),
          const FormGap(),
          _noteField(),
        ];
      case RecordTab.reimbursement:
        return <Widget>[
          TextField(
            controller: _rbTitleController,
            decoration: const InputDecoration(labelText: '事由'),
          ),
          const FormGap(),
          TextField(
            controller: _rbPayerController,
            decoration: const InputDecoration(labelText: '垫付人'),
          ),
          const FormGap(),
          TextField(
            controller: _rbTargetController,
            decoration: const InputDecoration(
              labelText: '报销方（公司/组织，可选）',
            ),
          ),
          const FormGap(),
          EnumDropdown<ReimbursementStatus>(
            label: '状态',
            value: _rbStatus,
            values: ReimbursementStatus.values,
            labelOf: (ReimbursementStatus s) => s.label,
            onChanged: (ReimbursementStatus s) => setState(() => _rbStatus = s),
          ),
          const FormGap(),
          _dateField(),
          const FormGap(),
          SwitchListTile(
            title: const Text('不计入收支'),
            subtitle: const Text('个人垫款、与报销统计无关时开启，'
                '不计入「待收回」汇总'),
            value: _rbExclude,
            onChanged: (bool v) => setState(() => _rbExclude = v),
            contentPadding: EdgeInsets.zero,
          ),
          const FormGap(),
          _noteField(),
        ];
      case RecordTab.savings:
        return <Widget>[
          SegmentedButton<bool>(
            segments: const <ButtonSegment<bool>>[
              ButtonSegment<bool>(value: true, label: Text('存入')),
              ButtonSegment<bool>(value: false, label: Text('取出')),
            ],
            selected: <bool>{_saveDeposit},
            onSelectionChanged: (Set<bool> next) =>
                setState(() => _saveDeposit = next.first),
          ),
          const FormGap(),
          _goalField(),
          const FormGap(),
          _noteField(),
        ];
    }
  }

  // ---- 小青账风格：支出 / 收入主体 ----

  /// 小青账统一布局：顶部滚动表单 + 底部固定功能栏/金额栏/日期备注栏/键盘。
  /// 适用于 支出 / 收入 / 转账 / 借还。
  Widget _buildNewLayoutBody() {
    final double viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    final bool systemKeyboardOpen =
        viewInsetsBottom > 0 &&
        (_noteFocusNode.hasFocus || _feeInputFocusNode.hasFocus);
    return Expanded(
      child: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimens.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildNewLayoutScrollArea(),
                ],
              ),
            ),
          ),
          // 功能键行、金额栏、备注栏三段垂直间距统一为 spaceSm。
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceLg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildFunctionBar(),
                const SizedBox(height: AppDimens.spaceSm),
                _buildInlineAmount(),
                const SizedBox(height: AppDimens.spaceSm),
                _buildDateNoteRow(),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          // 系统键盘（备注输入）弹出或键盘折叠时，不渲染键盘栏。
          if (!systemKeyboardOpen) _buildCollapsibleKeypad(),
        ],
      ),
    );
  }

  /// 互换转账的转出/转入账户。
  void _swapTransferAccounts() {
    setState(() {
      final String? tmp = _accountId;
      _accountId = _toAccountId;
      _toAccountId = tmp;
    });
  }

  /// 转账页卡片式账户选择器（匹配小青账模板）。
  ///
  /// 左侧是圆角长条账户栏卡片（已选账户名或占位符），右侧是圆角长条标签卡片。
  Widget _buildTransferAccountCard({
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
    String? excludeId,
    String placeholder = '请选择',
  }) {
    final AsyncValue<List<Account>> accounts = ref.watch(accountsProvider);
    return accounts.when(
      data: (List<Account> list) {
        final List<Account> shown = (excludeId != null && list.length > 1)
            ? list.where((Account a) => a.id != excludeId).toList()
            : list;
        final String? safe =
            shown.any((Account a) => a.id == value) ? value : null;
        final Account? selected =
            safe == null ? null : shown.firstWhere((Account a) => a.id == safe);
        return Row(
          children: <Widget>[
            // 左侧：账户栏卡片。
            Expanded(
              child: InkWell(
                onTap: shown.isEmpty
                    ? null
                    : () => _showTransferAccountPicker(
                          label: label,
                          accounts: shown,
                          selectedId: safe,
                          onChanged: onChanged,
                        ),
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceMd,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          selected?.name ?? placeholder,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: selected != null
                                    ? AppColors.textPrimary
                                    : AppColors.textTertiary,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            // 右侧：标签卡片。
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                border: Border.all(color: AppColors.divider),
              ),
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (Object e, _) => Text('账户加载失败：$e'),
    );
  }

  Future<void> _showTransferAccountPicker({
    required String label,
    required List<Account> accounts,
    required String? selectedId,
    required ValueChanged<String?> onChanged,
  }) async {
    final String? result = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              child: Text(
                '选择$label',
                style: Theme.of(ctx).textTheme.titleSmall,
              ),
            ),
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              itemCount: accounts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (BuildContext ctx, int index) {
                final Account account = accounts[index];
                final bool selected = account.id == selectedId;
                return ListTile(
                  title: Text(account.name),
                  trailing: selected
                      ? Icon(
                          Icons.check,
                          color: Theme.of(ctx).colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.of(ctx).pop(account.id),
                );
              },
            ),
          ],
        ),
      ),
    );
    if (result != null) onChanged(result);
  }

  /// 转账页手续费 / 优惠 / 计算器行。
  ///
  /// 整体为与账户栏一致的圆角卡片：左侧绿色 ¥ 图标 + 输入框；中间是「手续费 / 优惠」
  /// 切换开关（选中项为绿色药丸，未选项为灰色文字）；右侧为「计算器」文字按钮。
  Widget _buildTransferFeeRow() {
    final bool isFee = _feeInputType == _FeeInputType.fee;
    final String? currentValue = isFee ? _feeAmount : _discountAmount;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
                    height: 1.0,
                  ),
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: TextField(
              controller: _feeInputController,
              focusNode: _feeInputFocusNode,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: isFee ? '手续费' : '优惠',
                hintStyle: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textTertiary),
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: currentValue != null && currentValue.isNotEmpty
                        ? AppColors.textPrimary
                        : AppColors.textTertiary,
                  ),
              maxLines: 1,
              onChanged: (String v) {
                final String trimmed = v.trim();
                setState(() {
                  if (isFee) {
                    _feeAmount = trimmed.isEmpty ? null : trimmed;
                  } else {
                    _discountAmount = trimmed.isEmpty ? null : trimmed;
                  }
                });
              },
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          _buildFeeTypeToggle(),
          const SizedBox(width: AppDimens.spaceSm),
          _buildTransferCalculatorButton(),
        ],
      ),
    );
  }

  /// 「手续费 / 优惠」切换开关：选中项为绿色药丸，未选项为灰色文字。
  Widget _buildFeeTypeToggle() {
    final bool isFee = _feeInputType == _FeeInputType.fee;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildFeeTypeSegment(
          label: '手续费',
          selected: isFee,
          type: _FeeInputType.fee,
        ),
        _buildFeeTypeSegment(
          label: '优惠',
          selected: !isFee,
          type: _FeeInputType.discount,
        ),
      ],
    );
  }

  Widget _buildFeeTypeSegment({
    required String label,
    required bool selected,
    required _FeeInputType type,
  }) {
    return InkWell(
      onTap: () => _onFeeInputTypeChanged(type),
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
              ),
        ),
      ),
    );
  }

  /// 转账计算器按钮（文字按钮）。
  Widget _buildTransferCalculatorButton() {
    return InkWell(
      onTap: () => _toast('转账计算器功能开发中'),
      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      child: Container(
        height: 28,
        alignment: Alignment.center,
        child: Text(
          '计算器',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
              ),
        ),
      ),
    );
  }

  /// 切换手续费 / 优惠输入模式，并在模式间迁移当前输入值。
  void _onFeeInputTypeChanged(_FeeInputType type) {
    if (type == _feeInputType) return;
    _feeInputFocusNode.requestFocus();
    setState(() {
      final String current = _feeInputController.text.trim();
      if (_feeInputType == _FeeInputType.fee) {
        _feeAmount = current.isEmpty ? null : current;
      } else {
        _discountAmount = current.isEmpty ? null : current;
      }
      _feeInputType = type;
      _feeInputController.text =
          type == _FeeInputType.fee ? (_feeAmount ?? '') : (_discountAmount ?? '');
    });
  }

  /// 转账页说明文案。
  Widget _buildTransferHint() {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.info_outline,
            size: 16,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Text(
              '转账、信用卡还款、取现可以用这个功能哦。\n'
              '转出账户 = 转出金额 + 手续费\n'
              '转出账户 = 转出金额 - 优惠',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// 小青账布局顶部滚动区：根据 Tab 显示分类网格、转账字段或借还字段。
  Widget _buildNewLayoutScrollArea() {
    switch (_tab) {
      case RecordTab.expense:
      case RecordTab.income:
        final AsyncValue<List<Category>> categories = ref.watch(
          _tab == RecordTab.income
              ? incomeCategoriesProvider
              : expenseCategoriesProvider,
        );
        return categories.when(
          data: _buildCategoryGrid,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, StackTrace? s) =>
              Center(child: Text('分类加载失败：$e')),
        );
      case RecordTab.transfer:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildTransferAccountCard(
              label: '扣款账户',
              value: _accountId,
              excludeId: _toAccountId,
              placeholder: '转出账户',
              onChanged: (String? v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Center(
              child: InkWell(
                onTap: _swapTransferAccounts,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceMd,
                    vertical: AppDimens.spaceSm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.sync_alt,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppDimens.spaceXs),
                      Text(
                        '转至',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            _buildTransferAccountCard(
              label: '入款账户',
              value: _toAccountId,
              excludeId: _accountId,
              placeholder: '转入账户',
              onChanged: (String? v) => setState(() => _toAccountId = v),
            ),
            const SizedBox(height: AppDimens.spaceLg),
            _buildTransferFeeRow(),
            const SizedBox(height: AppDimens.spaceMd),
            _buildTransferHint(),
          ],
        );
      case RecordTab.lend:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _counterpartyController,
              decoration: const InputDecoration(
                labelText: '对方（人/单位）',
              ),
            ),
            const FormGap(),
            _accountField(
              label: '账户',
              value: _accountId,
              onChanged: (String? v) => setState(() => _accountId = v),
            ),
          ],
        );
      case RecordTab.reimbursement:
      case RecordTab.refund:
      case RecordTab.savings:
        return const SizedBox.shrink();
    }
  }

  /// 原 ListView + 底部键盘布局，供转账 / 借还 / 报销 / 退款 / 存钱复用。
  Widget _buildLegacyBody() {
    return Expanded(
      child: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppDimens.spaceLg),
              children: <Widget>[
                _amountDisplay(),
                const SizedBox(height: AppDimens.spaceLg),
                ..._formFields(),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceLg,
              AppDimens.spaceSm,
              AppDimens.spaceLg,
              AppDimens.spaceLg,
            ),
            child: AmountKeypad(
              value: _amount,
              enabled: !_saving,
              onChanged: (String v) => setState(() {
                if (!_refundAutoMode) _amount = v;
              }),
              onSave: () => _save(),
              onSaveAndMore: () => _save(andMore: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(List<Category> categories) {
    final List<Category> parents = categories
        .where((Category c) => c.parentId == null)
        .toList(growable: false);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: AppDimens.spaceSm,
        crossAxisSpacing: AppDimens.spaceSm,
        childAspectRatio: 0.88,
      ),
      itemCount: parents.length + 1,
      itemBuilder: (BuildContext context, int index) {
        if (index == parents.length) {
          return _CategoryItem(
            label: '设置',
            icon: Icons.settings_outlined,
            color: AppColors.textTertiary,
            onTap: () => context.push('/categories'),
          );
        }
        final Category cat = parents[index];
        final int colorIndex = index % AppColors.chartPalette.length;
        return _CategoryItem(
          label: cat.name,
          icon: _categoryIcon(cat.iconKey),
          color: cat.colorValue != null
              ? Color(cat.colorValue!)
              : AppColors.chartPalette[colorIndex],
          onTap: () => _onCategoryTap(cat, categories),
          onMore: () => _onCategoryMore(cat),
        );
      },
    );
  }

  IconData _categoryIcon(String? iconKey) {
    if (iconKey == null || iconKey.isEmpty) {
      return Icons.category_outlined;
    }
    // 简单映射：小青账默认图标用 Material 图标兜底。
    return switch (iconKey) {
      'restaurant' => Icons.restaurant_outlined,
      'shopping' => Icons.shopping_bag_outlined,
      'transport' => Icons.directions_bus_outlined,
      'home' => Icons.home_outlined,
      'daily' => Icons.local_convenience_store_outlined,
      'heart' => Icons.favorite_outline,
      'entertainment' => Icons.movie_outlined,
      'travel' => Icons.flight_outlined,
      'medical' => Icons.local_hospital_outlined,
      'member' => Icons.card_membership_outlined,
      'salary' => Icons.payments_outlined,
      'bonus' => Icons.card_giftcard_outlined,
      'investment' => Icons.trending_up_outlined,
      _ => Icons.category_outlined,
    };
  }

  void _onCategoryTap(Category parent, List<Category> all) {
    final List<Category> children = all
        .where((Category c) => c.parentId == parent.id)
        .toList(growable: false);
    if (children.isEmpty) {
      setState(() => _categoryId = parent.id);
      return;
    }
    _showSubcategorySheet(parent, children);
  }

  Future<void> _showSubcategorySheet(
    Category parent,
    List<Category> children,
  ) async {
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => _SubcategorySheet(
        parent: parent,
        children: children,
        selectedId: _categoryId,
      ),
    );
    if (selected == null || !mounted) return;
    if (selected == '__add__') {
      _toast('分类管理功能开发中');
      return;
    }
    setState(() => _categoryId = selected);
  }

  void _onCategoryMore(Category category) {
    // 暂不提供分类管理菜单；后续可扩展为「编辑 / 删除 / 添加子分类」。
  }

  Widget _buildFunctionBar() {
    final bool isExpense = _tab == RecordTab.expense;
    final bool isIncome = _tab == RecordTab.income;
    // 账户 / 不计收支 / 不计预算：仅支出、收入显示。
    final bool showAccountStats = isExpense || isIncome;
    final List<_FunctionItem> items = <_FunctionItem>[
      if (showAccountStats)
        _FunctionItem(
          label: '账户',
          icon: Icons.account_balance_wallet_outlined,
          onTap: _onSelectAccount,
        ),
      if (isExpense)
        _FunctionItem(
          label: '报销',
          icon: Icons.receipt_long_outlined,
          onTap: () => setState(() => _isReimbursable = !_isReimbursable),
          active: _isReimbursable,
        ),
      if (isExpense)
        _FunctionItem(
          label: '优惠',
          icon: Icons.local_offer_outlined,
          onTap: _onDiscount,
        ),
      _FunctionItem(
        label: '图片',
        icon: Icons.image_outlined,
        onTap: _onAddImage,
      ),
      _FunctionItem(
        label: _tags.isEmpty ? '标签' : '标签 ${_tags.length}',
        icon: Icons.label_outlined,
        onTap: _onAddTag,
      ),
      if (showAccountStats)
        _FunctionItem(
          label: '不计收支',
          icon: Icons.visibility_off_outlined,
          onTap: () => setState(() => _excludeFromStats = !_excludeFromStats),
          active: _excludeFromStats,
        ),
      if (showAccountStats)
        _FunctionItem(
          label: '不计预算',
          icon: Icons.pie_chart_outline,
          onTap: () => setState(() => _excludeFromBudget = !_excludeFromBudget),
          active: _excludeFromBudget,
        ),
      _FunctionItem(
        label: '模板',
        icon: Icons.bookmark_border_outlined,
        onTap: _onSaveTemplate,
      ),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppDimens.spaceSm),
        itemBuilder: (BuildContext context, int index) {
          final _FunctionItem item = items[index];
          return _buildFunctionChip(item);
        },
      ),
    );
  }

  Widget _buildFunctionChip(_FunctionItem item) {
    final ThemeData theme = Theme.of(context);
    final bool active = item.active ?? false;
    final Color color = active ? theme.colorScheme.primary : AppColors.textSecondary;
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? theme.colorScheme.primaryContainer : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(item.icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              item.label,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onDiscount() async {
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => _PromptDialog(
        title: '优惠金额',
        hint: '请输入优惠金额（元）',
        initial: _discountAmount ?? '',
      ),
    );
    if (value == null || !mounted) return;
    setState(() => _discountAmount = value.trim().isEmpty ? null : value.trim());
  }

  Future<void> _onSelectAccount() async {
    final AsyncValue<List<Account>> accountsValue = ref.watch(accountsProvider);
    final List<Account>? list = accountsValue.valueOrNull;
    if (list == null || list.isEmpty) {
      _toast('还没有账户，请先到「账户」页添加');
      return;
    }
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => _AccountSelectorSheet(
        accounts: list,
        selectedId: _accountId,
      ),
    );
    if (selected != null && mounted) {
      setState(() => _accountId = selected);
    }
  }

  void _onAddImage() {
    _toast('图片附件功能开发中');
  }

  Future<void> _onAddTag() async {
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => const _PromptDialog(
        title: '添加标签',
        hint: '输入标签名称，多个用空格分隔',
      ),
    );
    if (value == null || value.trim().isEmpty || !mounted) return;
    setState(() {
      _tags.addAll(
        value.trim().split(RegExp(r'\s+')).where((String s) => s.isNotEmpty),
      );
    });
  }

  void _onSaveTemplate() {
    _toast('模板功能开发中');
  }

  bool get _hasExpression =>
      _pendingOperator != null && _pendingAmount.isNotEmpty;

  Widget _buildInlineAmount() {
    final ThemeData theme = Theme.of(context);
    final String shown = _displayAmount;
    final Color amountColor =
        _tab == RecordTab.expense ? AppColors.expense : AppColors.income;
    final Widget amountRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              // 收起系统键盘，切回自定义数字键盘。
              FocusManager.instance.primaryFocus?.unfocus();
              setState(() => _keyboardExpanded = true);
            },
            child: Text(
              '¥ $shown',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: amountColor,
              ),
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            _keyboardExpanded
                ? Icons.keyboard_arrow_down
                : Icons.keyboard_arrow_up,
            size: 20,
          ),
          iconSize: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: _keyboardExpanded ? '收起键盘' : '展开键盘',
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            setState(() => _keyboardExpanded = !_keyboardExpanded);
          },
        ),
      ],
    );

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.divider),
      ),
      child: _hasExpression
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(flex: 2, child: Center(child: amountRow)),
                Expanded(
                  flex: 1,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildExpression(),
                  ),
                ),
              ],
            )
          : Center(child: amountRow),
    );
  }

  /// 小青账键盘的运算表达式（如 12 - 3），显示在金额栏内下方 1/3 区域。
  Widget _buildExpression() {
    if (!_hasExpression) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    final String expression = _amount.isEmpty
        ? '$_pendingAmount $_pendingOperator'
        : '$_pendingAmount $_pendingOperator $_amount';
    return Text(
      expression,
      textAlign: TextAlign.left,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: AppColors.textSecondary,
        height: 1,
      ),
    );
  }

  Widget _buildDateNoteRow() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          InkWell(
            onTap: _pickDate,
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('M月d日').format(_occurredAt),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: TextField(
              controller: _noteController,
              focusNode: _noteFocusNode,
              decoration: const InputDecoration(
                hintText: '请输入备注信息（最多150字）',
                border: InputBorder.none,
                counterText: '',
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              maxLines: 1,
              maxLength: 150,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              buildCounter: (
                BuildContext context, {
                required int currentLength,
                required bool isFocused,
                required int? maxLength,
              }) =>
                  null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleKeypad() {
    final ThemeData theme = Theme.of(context);
    final double bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    if (!_keyboardExpanded) {
      // 折叠态不再保留键盘栏：由金额右侧的按键负责重新展开。
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        0,
        AppDimens.spaceMd,
        AppDimens.spaceMd + bottomSafe,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: _RecordKeypad(
        value: _amount,
        enabled: !_saving,
        onChanged: (String v) => setState(() => _amount = v),
        onOperator: _onOperator,
        onBackspace: _onBackspace,
        onSave: () => _save(),
        onSaveAndMore: () => _save(andMore: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double statusBarPadding = MediaQuery.paddingOf(context).top;
    final double viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.92,
      padding: EdgeInsets.only(bottom: viewInsetsBottom),
      child: Column(
        children: <Widget>[
          // 顶部：标题 + 关闭，预留状态栏高度避免贴顶。
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppDimens.spaceLg,
              AppDimens.spaceMd + statusBarPadding,
              AppDimens.spaceSm,
              AppDimens.spaceSm,
            ),
            child: Row(
              children: <Widget>[
                Text('记一笔', style: theme.textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
          // 7 个 Tab（横向滚动，避免窄屏溢出）
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
            child: SegmentedButton<RecordTab>(
              segments: <ButtonSegment<RecordTab>>[
                for (final RecordTab t in RecordTab.values)
                  ButtonSegment<RecordTab>(
                    value: t,
                    label: Text(t.label),
                    icon: Icon(t.icon),
                  ),
              ],
              selected: <RecordTab>{_tab},
              onSelectionChanged: (Set<RecordTab> next) {
                setState(() {
                  _tab = next.first;
                  _categoryId = null;
                });
              },
            ),
          ),
          const Divider(height: 1),
          // 主体：支出 / 收入 / 转账 / 借还 使用小青账统一布局，其余保持原表单。
          if (_tab.usesNewLayout)
            _buildNewLayoutBody()
          else
            _buildLegacyBody(),
        ],
      ),
    );
  }
}

/// 分类网格项：图标 + 名称 + 右上角「更多」入口。
class _CategoryItem extends StatelessWidget {
  const _CategoryItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.onMore,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.2),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            if (onMore != null)
              Positioned(
                top: 2,
                right: 2,
                child: InkWell(
                  onTap: onMore,
                  customBorder: const CircleBorder(),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.more_horiz,
                      size: 12,
                      color: color,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 二级分类底部面板。
class _SubcategorySheet extends StatelessWidget {
  const _SubcategorySheet({
    required this.parent,
    required this.children,
    this.selectedId,
  });

  final Category parent;
  final List<Category> children;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(parent.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppDimens.spaceMd),
            Wrap(
              spacing: AppDimens.spaceSm,
              runSpacing: AppDimens.spaceSm,
              children: <Widget>[
                for (final Category child in children)
                  ChoiceChip(
                    label: Text(child.name),
                    selected: child.id == selectedId,
                    onSelected: (_) => Navigator.of(context).pop(child.id),
                  ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Row(
              children: <Widget>[
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop('__add__'),
                  icon: const Icon(Icons.add),
                  label: const Text('添加'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 账户选择底部面板。
class _AccountSelectorSheet extends StatelessWidget {
  const _AccountSelectorSheet({
    required this.accounts,
    this.selectedId,
  });

  final List<Account> accounts;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppDimens.spaceLg),
            child: Text('选择账户', style: theme.textTheme.titleMedium),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: accounts.length,
              itemBuilder: (BuildContext context, int index) {
                final Account a = accounts[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(a.name.isNotEmpty ? a.name[0] : '?'),
                  ),
                  title: Text(a.name),
                  trailing: a.id == selectedId
                      ? Icon(Icons.check, color: theme.colorScheme.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(a.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 通用单行输入对话框。
class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    this.hint,
    this.initial,
  });

  final String title;
  final String? hint;
  final String? initial;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(hintText: widget.hint),
        autofocus: true,
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

/// 功能键数据。
class _FunctionItem {
  const _FunctionItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.active,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool? active;
}

/// 小青账风格底部键盘：左侧数字 + 右侧「删除 / 折叠」。
class _RecordKeypad extends StatelessWidget {
  const _RecordKeypad({
    required this.value,
    required this.onChanged,
    required this.onSave,
    this.onSaveAndMore,
    this.onOperator,
    this.onBackspace,
    this.enabled = true,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onSave;
  final VoidCallback? onSaveAndMore;
  final ValueChanged<String>? onOperator;
  final VoidCallback? onBackspace;
  final bool enabled;

  static const int _maxIntegerDigits = 12;
  static const int _maxDecimalDigits = 2;

  void _input(String s) {
    if (!enabled) return;
    if (s == '.') {
      if (value.contains('.')) return;
      onChanged(value.isEmpty ? '0.' : '$value.');
      return;
    }
    if (value.contains('.')) {
      final String decimals = value.split('.')[1];
      if (decimals.length >= _maxDecimalDigits) return;
    }
    if (value.replaceAll('.', '').length >= _maxIntegerDigits) return;
    if (value == '0') {
      onChanged(s);
    } else {
      onChanged('$value$s');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 小青账风格 4×4 键盘：右侧列 = 删除 / - / + / 保存。
    // 按键压缩高度、拉长宽度，行列间距统一为 spaceSm，视觉更协调。
    return SizedBox(
      height: 196,
      child: GridView.count(
        crossAxisCount: 4,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: AppDimens.spaceSm,
        mainAxisSpacing: AppDimens.spaceSm,
        childAspectRatio: 2.0,
        children: <Widget>[
          _Digit('1', () => _input('1')),
          _Digit('2', () => _input('2')),
          _Digit('3', () => _input('3')),
          _KeyAction(
            label: '删除',
            icon: Icons.backspace_outlined,
            showLabel: false,
            onTap: enabled
                ? () {
                    if (value.isNotEmpty) {
                      onChanged(value.substring(0, value.length - 1));
                    } else {
                      onBackspace?.call();
                    }
                  }
                : null,
          ),
          _Digit('4', () => _input('4')),
          _Digit('5', () => _input('5')),
          _Digit('6', () => _input('6')),
          _KeyAction(
            label: '-',
            icon: Icons.remove,
            showLabel: false,
            onTap: enabled ? () => onOperator?.call('-') : null,
          ),
          _Digit('7', () => _input('7')),
          _Digit('8', () => _input('8')),
          _Digit('9', () => _input('9')),
          _KeyAction(
            label: '+',
            icon: Icons.add,
            showLabel: false,
            onTap: enabled ? () => onOperator?.call('+') : null,
          ),
          _KeyAction(
            label: '再记',
            onTap: enabled ? onSaveAndMore : null,
          ),
          _Digit('0', () => _input('0')),
          _KeyAction(
            label: '.',
            icon: Icons.circle,
            showLabel: false,
            onTap: enabled ? () => _input('.') : null,
          ),
          _KeyAction(
            label: '保存',
            onTap: enabled ? onSave : null,
          ),
        ],
      ),
    );
  }
}

class _Digit extends StatelessWidget {
  const _Digit(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.headlineSmall,
          ),
        ),
      ),
    );
  }
}

class _KeyAction extends StatelessWidget {
  const _KeyAction({
    required this.label,
    this.icon,
    required this.onTap,
    this.showLabel = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool active = onTap != null;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null)
                Icon(
                  icon,
                  size: label == '.' ? 8 : 20,
                  color: active ? theme.colorScheme.primary : theme.disabledColor,
                ),
              if (showLabel && label != '.')
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: active
                        ? theme.colorScheme.primary
                        : theme.disabledColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
