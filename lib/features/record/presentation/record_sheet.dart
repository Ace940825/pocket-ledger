import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/env.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../features/accounts/data/account_icon.dart';
import '../../../features/accounts/data/bank_data.dart';
import '../../../features/accounts/providers/accounts_providers.dart';
import '../../../features/installment/presentation/add_installment_page.dart';
import '../../../features/ledger/providers/ledger_providers.dart';
import '../../../features/lend/providers/lend_providers.dart';
import '../../../features/reimbursement/providers/reimbursement_providers.dart';
import '../../../features/savings/providers/savings_providers.dart';
import '../../../features/settings/providers/sync_settings_providers.dart';
import '../../../providers/app_providers.dart';
import '../../../routing/app_router.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/attachment_viewer.dart';
import '../../../shared/widgets/calculator_sheet.dart';
import '../../../shared/widgets/category_icons.dart';
import '../../../shared/widgets/date_field.dart';
import '../../../shared/widgets/date_picker_sheet.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../sync/sync_adapter.dart';
import '../providers/recording_settings_provider.dart';
import '../record_tab.dart';
import '../widgets/amount_keypad.dart';
import 'account_picker_sheet.dart';
import 'bill_selection_page.dart';
import '../../../core/theme/forest_design_tokens.dart';
import '../../tags/presentation/tag_sheet.dart';
import 'recording_settings_sheet.dart';
import 'record_template_sheet.dart';

/// 退款模式：全额退回 / AA 付款分摊。
enum RefundMode { full, aa }

/// 转账页 / 借还页 手续费 / 利息 / 优惠输入模式。
enum _FeeInputType { fee, discount }

/// 借还页动作类型。
enum _LendActionType {
  borrow,
  repay,
  debtReduction;

  String label(LendDirection dir) => switch (this) {
        _LendActionType.borrow => dir == LendDirection.borrowIn ? '借入' : '借出',
        _LendActionType.repay => dir == LendDirection.borrowIn ? '还债' : '收债',
        _LendActionType.debtReduction =>
          dir == LendDirection.borrowIn ? '债务削减' : '坏账损失',
      };

  IconData icon(LendDirection dir) => switch (this) {
        _LendActionType.borrow =>
          dir == LendDirection.borrowIn ? Icons.south_west : Icons.north_east,
        _LendActionType.repay => Icons.check_circle_outline,
        _LendActionType.debtReduction => Icons.content_cut_outlined,
      };
}

/// 统一「记一笔」独立页面：顶部 8 个 Tab（支出/收入/转账/借还/报销/退款/存钱/分期），
/// 中间是对应表单，底部是自定义数字键盘。
///
/// 通过 [Routes.record] 以全屏独立路由打开（而非底部面板），Tab 状态由
/// [RecordSheet] 内部维护；分期 Tab 内嵌 [AddInstallmentPage]（showAppBar:false），
/// 分期本身也可经 [Routes.installmentAdd] 独立打开。
///
/// 设计要点：
/// - 8 种类型映射到既有 [SourceModule] 或独立表（借还=LendRecords /
///   报销=Reimbursements / 存钱=SavingsGoals），不新增任何 intEnum 下标，
///   避免触发 tables.dart 注释警告的迁移灾难。
/// - 仅「退款」用到新追加的 [SourceModule.refund]（append-only 安全）。
/// - 金额统一走自定义键盘，落库时用 [Money.fromDecimal] 转「分」整数。
Future<void> openRecordSheet(
  BuildContext context, {
  RecordTab initialTab = RecordTab.expense,
}) async {
  await context.push<void>(
    Routes.record,
    extra: initialTab,
  );
}

class RecordSheet extends ConsumerStatefulWidget {
  const RecordSheet({super.key, this.initialTab = RecordTab.expense});

  final RecordTab initialTab;

  @override
  ConsumerState<RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends ConsumerState<RecordSheet>
    with TickerProviderStateMixin {
  RecordTab _tab = RecordTab.expense;
  late TabController _tabController;

  /// 与 [TabBar] 联动的页面控制器；使用 [PageView.builder] 替代 [TabBarView]，
  /// 只构建当前页和相邻页，避免首帧同时创建 8 套完整表单导致的超长帧。
  late PageController _pageController;

  /// 点击 Tab 触发 [PageController] 程序化滚动时为 true，
  /// 此时页面滚动监听器不回写 [TabController]，避免双向驱动冲突。
  bool _pageAnimating = false;

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
  LendDirection _lendDir = LendDirection.borrowIn;
  LendStatus _lendStatus = LendStatus.ongoing;

  /// 还债 / 收债时选择的资金账户：现金收支落到这个账户，余额随之变化。
  String? _repayAccountId;
  _LendActionType _lendAction = _LendActionType.borrow;

  // 借还利息 / 优惠输入。
  _FeeInputType _lendFeeInputType = _FeeInputType.fee;
  final TextEditingController _lendFeeController = TextEditingController();
  final FocusNode _lendFeeFocusNode = FocusNode();
  String? _lendFeeAmount;
  String? _lendDiscountAmount;

  // 报销
  ReimbursementStatus _rbStatus = ReimbursementStatus.pending;
  bool _rbExclude = false;
  String? _rbAccountId; // 报销账户
  String? _rbToAccountId; // 收款账户
  final TextEditingController _rbAmountController = TextEditingController();

  // 退款
  RefundMode _refundMode = RefundMode.full;
  bool _refundAmountAuto = true;

  /// 选中的原账单（支持多选合并为一条退款）。
  final List<Transaction> _refundOriginals = <Transaction>[];
  final TextEditingController _refundAmountController = TextEditingController();

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

  // 图片附件：本地持久化后的绝对路径列表（存于 appDocs/attachments）。
  final List<String> _attachmentPaths = <String>[];

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

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _tabController = TabController(
      initialIndex: widget.initialTab.index,
      length: RecordTab.values.length,
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);
    _pageController = PageController(initialPage: widget.initialTab.index);
    _pageController.addListener(_onPageScrolled);
    _noteFocusNode.addListener(_onNoteFocusChanged);
    _feeInputFocusNode.addListener(_onFeeInputFocusChanged);
    _lendFeeFocusNode.addListener(_onLendFeeFocusChanged);
  }

  /// [TabController] 的 index 变化（点击 Tab 或页面拖拽越过中点）时更新表单逻辑状态。
  /// 这里只做轻量状态更新并 [setState]：重活（8 套表单）已被 [PageView.builder]
  /// + [AutomaticKeepAlive] 缓存，单次重建开销很小，无需延迟到动画结束。
  void _onTabChanged() {
    final int index = _tabController.index;
    if (index == _tab.index) return;
    _tab = RecordTab.values[index];
    _categoryId = null;
    _attachmentPaths.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    if (mounted) setState(() {});
  }

  /// 页面滚动时让原生 [TabBar] 指示器跟随手指。
  /// 仅在用户拖拽（非点击触发的程序化滚动）时回写 [TabController]，
  /// 避免与点击逻辑互相打架。
  /// 注意：[TabController.animateTo] 本版本接收 int（目标 tab 下标），
  /// 故以最近整数 tab 驱动，指示器在越过中点时平滑滑向目标 tab。
  void _onPageScrolled() {
    if (_pageAnimating) return;
    final double page = _pageController.page ?? _tabController.index.toDouble();
    final int nearest = page.round();
    if (nearest != _tabController.index) {
      _tabController.animateTo(nearest);
    }
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

  void _onLendFeeFocusChanged() {
    if (_lendFeeFocusNode.hasFocus) {
      // 借还利息/优惠输入使用系统键盘，临时收起自定义数字键盘避免冲突。
      if (mounted && _keyboardExpanded) {
        setState(() => _keyboardExpanded = false);
      }
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScrolled);
    _pageController.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _noteFocusNode.removeListener(_onNoteFocusChanged);
    _noteFocusNode.dispose();
    _feeInputFocusNode.removeListener(_onFeeInputFocusChanged);
    _feeInputFocusNode.dispose();
    _feeInputController.dispose();
    _lendFeeFocusNode.removeListener(_onLendFeeFocusChanged);
    _lendFeeFocusNode.dispose();
    _lendFeeController.dispose();
    _noteController.dispose();
    _counterpartyController.dispose();
    _rbTitleController.dispose();
    _rbPayerController.dispose();
    _rbAmountController.dispose();
    _refundAmountController.dispose();
    super.dispose();
  }

  int get _amountMinor {
    if (_tab == RecordTab.refund) return _refundAmountMinor;
    return Money.tryParse(_effectiveAmount).minor;
  }

  /// 退款页实际退款金额（分）。
  ///
  /// - 全额退款 + 自动：以选中账单金额之和作为退款金额（多选时合并为一条）。
  /// - AA 付款 + 自动：按人均退款，默认 2 人 AA，即原账单总额的一半。
  /// - 自定义：读取输入框。
  int get _refundAmountMinor {
    if (_refundOriginals.isNotEmpty && _refundAmountAuto) {
      final int total = _refundOriginals.fold<int>(
        0,
        (int sum, Transaction t) => sum + t.amountMinor,
      );
      if (_refundMode == RefundMode.aa) {
        return Money.fromMinor(total).ratio(0.5).minor;
      }
      return total;
    }
    return Money.tryParse(_refundAmountController.text).minor;
  }

  /// 选中账单的原始金额合计（分），用于备注与显示。
  int get _refundOriginalTotalMinor => _refundOriginals.fold<int>(
        0,
        (int sum, Transaction t) => sum + t.amountMinor,
      );

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

  /// 借还利息金额（分）。未输入时返回 0。
  int get _lendFeeMinor {
    if (_lendFeeAmount == null || _lendFeeAmount!.isEmpty) return 0;
    return Money.tryParse(_lendFeeAmount!).minor;
  }

  /// 借还优惠 / 减免金额（分）。未输入时返回 0。
  int get _lendDiscountMinor {
    if (_lendDiscountAmount == null || _lendDiscountAmount!.isEmpty) return 0;
    return Money.tryParse(_lendDiscountAmount!).minor;
  }

  /// 报销收入金额（分）。未输入时返回 0。
  int get _rbAmountMinor {
    final String text = _rbAmountController.text.trim();
    if (text.isEmpty) return 0;
    return Money.tryParse(text).minor;
  }

  // ---- 保存 ----

  Future<void> _save({bool andMore = false}) async {
    final int minor =
        _tab == RecordTab.reimbursement ? _rbAmountMinor : _amountMinor;
    if (minor <= 0) {
      _toast('请输入大于 0 的金额');
      return;
    }
    final String bookId = ref.read(currentBookIdProvider);
    final int occurredAt = _occurredAt.toUtc().millisecondsSinceEpoch;

    setState(() => _saving = true);
    try {
      String? savedId;
      switch (_tab) {
        case RecordTab.expense:
        case RecordTab.income:
          if (_accountId == null) {
            _toast('请选择账户');
            return;
          }
          savedId = await ref.read(transactionRepositoryProvider).add(
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
                discountMinor: _discountMinor,
                tags: _tags,
                excludeFromStats: _excludeFromStats,
                excludeFromBudget: _excludeFromBudget,
                isReimbursable: _isReimbursable,
                attachmentUrls: _attachmentPaths,
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
          savedId = await ref.read(transactionRepositoryProvider).transfer(
                bookId: bookId,
                fromAccountId: _accountId!,
                toAccountId: _toAccountId!,
                amountMinor: minor,
                feeMinor: _feeMinor,
                discountMinor: _discountMinor,
                occurredAt: occurredAt,
                note: _noteController.text.trim(),
                attachmentUrls: _attachmentPaths,
              );
        case RecordTab.refund:
          if (_refundOriginals.isEmpty) {
            _toast('请选择需要退款的账单');
            return;
          }
          if (_accountId == null) {
            _toast('请选择入款账户');
            return;
          }
          if (minor <= 0) {
            _toast('请输入退款金额');
            return;
          }
          // 退款 = 钱退回账户，按「收入」方向增加账户余额，来源标记为 refund。
          final String modeText =
              _refundMode == RefundMode.full ? '全额退款' : 'AA 付款';
          String refundNote = _noteController.text.trim();

          final int originalTotalMinor = _refundOriginalTotalMinor;
          final String originalAmounts = _refundOriginals
              .map((Transaction t) => Money.fromMinor(t.amountMinor).format())
              .join(' + ');
          final String refundAmountText =
              Money.fromMinor(minor).format(showSymbol: false);
          final String detail = '[$modeText] 原账单合计：'
              '${Money.fromMinor(originalTotalMinor).format()}'
              '（$originalAmounts）'
              '${_refundMode == RefundMode.aa ? '，人均退款：$refundAmountText' : ''}';
          refundNote = refundNote.isEmpty ? detail : '$refundNote\n$detail';

          // 单选时保留 relatedId 语义；多选时通过 note 记录关联关系。
          final String? relatedId =
              _refundOriginals.length == 1 ? _refundOriginals.first.id : null;

          savedId = await ref.read(transactionRepositoryProvider).add(
                bookId: bookId,
                type: TxnType.income,
                amountMinor: minor,
                accountId: _accountId!,
                note: refundNote,
                occurredAt: occurredAt,
                sourceModule: SourceModule.refund,
                relatedId: relatedId,
                attachmentUrls: _attachmentPaths,
              );
        case RecordTab.lend:
          final String counterparty = _counterpartyController.text.trim();
          if (_lendAction == _LendActionType.debtReduction) {
            if (counterparty.isEmpty) {
              _toast(
                '请填写$_lendCounterpartyHint',
              );
              return;
            }
            await ref.read(lendRepositoryProvider).debtReduction(
                  bookId: bookId,
                  direction: _lendDir,
                  counterparty: counterparty,
                  amountMinor: minor,
                  occurredAt: occurredAt,
                  note: _noteController.text.trim(),
                );
          } else if (_lendAction == _LendActionType.repay) {
            // 还债 / 收债：冲销该对方名下未结清债务，并把现金收支落到指定资金账户。
            if (_repayAccountId == null) {
              _toast(
                _lendDir == LendDirection.borrowIn ? '请选择还款账户' : '请选择收款账户',
              );
              return;
            }
            if (counterparty.isEmpty) {
              // 「不选择具体账户」：不冲销任何债务，只记一条资金流水，
              // 账户空置（借入方向=支出、借出方向=收入）。
              final bool borrowIn = _lendDir == LendDirection.borrowIn;
              final String verb = borrowIn ? '还债' : '收债';
              final String userNote = _noteController.text.trim();
              await ref.read(transactionRepositoryProvider).add(
                    bookId: bookId,
                    type: borrowIn ? TxnType.expense : TxnType.income,
                    amountMinor: minor,
                    accountId: _repayAccountId!,
                    occurredAt: occurredAt,
                    note: userNote.isEmpty ? verb : '$verb\n$userNote',
                    sourceModule: SourceModule.lend,
                  );
            } else {
              await ref.read(lendRepositoryProvider).repay(
                    bookId: bookId,
                    direction: _lendDir,
                    counterparty: counterparty,
                    amountMinor: minor,
                    occurredAt: occurredAt,
                    note: _noteController.text.trim(),
                    accountId: _repayAccountId,
                  );
            }
          } else {
            // 借入 / 借出：新建一笔未结清债务。
            if (counterparty.isEmpty && _accountId == null) {
              _toast('请选择或填写对方账户');
              return;
            }
            await ref.read(lendRepositoryProvider).add(
                  bookId: bookId,
                  direction: _lendDir,
                  status: LendStatus.ongoing,
                  counterparty: counterparty.isEmpty
                      ? (_accountNameOf(_accountId) ?? '')
                      : counterparty,
                  amountMinor: minor,
                  occurredAt: occurredAt,
                  dueAt: null,
                  note: _noteController.text.trim(),
                  accountId: _accountId,
                  toAccountId: _toAccountId,
                  feeMinor: _lendFeeMinor,
                  discountMinor: _lendDiscountMinor,
                );
          }
        case RecordTab.reimbursement:
          if (_rbTitleController.text.trim().isEmpty) {
            _toast('请填写报销账单');
            return;
          }
          if (_rbAccountId == null) {
            _toast('请选择报销账户');
            return;
          }
          if (_rbToAccountId == null) {
            _toast('请选择收款账户');
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
                target: null,
                receivedAt: null,
                note: _noteController.text.trim(),
                excludeFromStats: _rbExclude,
                accountId: _rbAccountId,
                toAccountId: _rbToAccountId,
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
        case RecordTab.installment:
          // 分期 Tab 选择后立即跳转独立页面，不会执行到这里。
          return;
      }

      // 附件：写库成功后异步上传到云端，让其他设备也能查看原图。
      // 不阻塞保存返回——上传失败会保留本机路径，本地仍可见，下次联网重试。
      if (savedId != null && _attachmentPaths.isNotEmpty && mounted) {
        unawaited(_uploadAttachments(savedId));
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
          _rbAmountController.clear();
          _rbAccountId = null;
          _rbToAccountId = null;
          _rbExclude = false;
          _refundOriginals.clear();
          _refundAmountController.clear();
          _refundAmountAuto = true;
          _refundMode = RefundMode.full;
          _feeAmount = null;
          _discountAmount = null;
          _feeInputType = _FeeInputType.fee;
          _feeInputController.clear();
          _tags.clear();
          _isReimbursable = false;
          _excludeFromStats = false;
          _excludeFromBudget = false;
          _attachmentPaths.clear();
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
          onPressed: () => setState(() {
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
          initialValue: safe,
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
          initialValue: safe,
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

  Widget _dateField({String label = '日期'}) => DateField(
        label: label,
        value: _occurredAt,
        showTime: true,
        onChanged: (DateTime? v) =>
            setState(() => _occurredAt = v ?? DateTime.now()),
      );

  Future<void> _pickDate() async {
    final DateTime? picked = await DateTimePickerSheet.show(
      context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      showTime: true,
    );
    if (picked != null && mounted) {
      setState(() => _occurredAt = picked);
    }
  }

  Widget _noteField() => TextField(
        controller: _noteController,
        decoration: const InputDecoration(labelText: '备注'),
        maxLines: 2,
      );

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
          initialValue: safe,
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
        // 退款改用独立的 _buildRefundBody，不再走 legacy 表单。
        return const <Widget>[SizedBox.shrink()];
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
        // 报销改用独立的 _buildReimbursementBody，不再走 legacy 表单。
        return const <Widget>[SizedBox.shrink()];
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
      case RecordTab.installment:
        // 分期使用独立页面，不在 sheet 内渲染表单。
        return const <Widget>[SizedBox.shrink()];
    }
  }

  // ---- 小青账风格：支出 / 收入主体 ----

  /// 小青账统一布局：顶部滚动表单 + 底部固定功能栏/金额栏/日期备注栏/键盘。
  /// 适用于 支出 / 收入 / 转账 / 借还。
  Widget _buildNewLayoutBody() {
    final double viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    final bool systemKeyboardOpen = viewInsetsBottom > 0 &&
        (_noteFocusNode.hasFocus || _feeInputFocusNode.hasFocus);
    return Column(
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
    );
  }

  /// 根据账户 ID 从当前账户列表中查找名称；未找到返回 null。
  String? _accountNameOf(String? accountId) {
    if (accountId == null) return null;
    final AsyncValue<List<Account>> value = ref.read(accountsProvider);
    final List<Account>? list = value.valueOrNull;
    if (list == null) return null;
    final Account? account = list.cast<Account?>().firstWhere(
          (Account? a) => a?.id == accountId,
          orElse: () => null,
        );
    return account?.name;
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
    /// 限定可选项大类；非空时仅展示这些大类（如借还借入/借出账户限定为
    /// 应付 / 应收），为空则展示资金类账户（排除应收 / 应付对方虚拟账户）。
    List<AccountCategory>? allowedCategories,
    /// 限定可选项具体类型；非空时只展示这些类型（优先级高于 [allowedCategories]），
    /// 用于「报销账户」这类只需应收类中的某一个分支（如仅报销、不含借出）。
    List<AccountType>? allowedTypes,
  }) {
    final AsyncValue<List<Account>> accounts = ref.watch(accountsProvider);
    return accounts.when(
      data: (List<Account> list) {
        // 资金类（默认）排除应收 / 应付；allowedTypes 按具体类型过滤，
        // allowedCategories 按大类过滤，二选一（allowedTypes 优先）。
        List<Account> shown;
        if (allowedTypes != null) {
          shown = list
              .where((Account a) => allowedTypes.contains(a.type))
              .toList(growable: false);
        } else if (allowedCategories == null) {
          shown = fundAccountsOnly(list);
        } else {
          shown = list
              .where(
                (Account a) => allowedCategories.contains(a.type.category),
              )
              .toList(growable: false);
        }
        if (excludeId != null && shown.length > 1) {
          shown = shown.where((Account a) => a.id != excludeId).toList();
        }
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
                          // 可选项已由 shown 处理：资金类（默认）或限定大类（报销账户=应收 / 应付）
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
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
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
            // 右侧：标签卡片。固定宽度与费用行右侧计算器列一致，使主卡片右边缘对齐。
            Container(
              width: 96,
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

  /// 弹出 A 模板账户选择弹窗（转账 / 借还 / 报销 / 退款各 tab 通用）。
  ///
  /// 与支出/收入功能键的账户选择同源：网格卡片 + 列表切换 + 添加 / 资产管理
  /// （添加、资产管理页压在弹窗上，返回后弹窗原位）。这些场景账户必选，
  /// 不显示「不选择具体账户」行。
  Future<void> _showTransferAccountPicker({
    required String label,
    required List<Account> accounts,
    required String? selectedId,
    required ValueChanged<String?> onChanged,
  }) async {
    final String? result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => AccountPickerSheet(
        accounts: accounts,
        selectedId: selectedId,
        title: '选择$label',
        showNoneRow: false, // 转账 / 借还 / 报销 / 退款：账户必选
        onReload: () => ref.invalidate(accountsProvider),
        // 点添加/资产管理：不关闭当前弹窗，把目标页压在上面；
        // 页面返回后弹窗仍原位（回到「选择账户」这个入口界面）。
        onAdd: () {
          if (mounted) context.push(Routes.accountAdd);
        },
        onManage: () {
          if (mounted) context.push(Routes.accountManage);
        },
        onConfirm: (Account? acc) => Navigator.of(ctx).pop(acc?.id ?? ''),
      ),
    );
    if (result == null || result.isEmpty || !mounted) return;
    onChanged(result);
  }

  /// 转账页手续费 / 优惠 / 计算器行。
  ///
  /// 整体为与账户栏一致的圆角卡片：左侧绿色 ¥ 图标 + 输入框；中间是「手续费 / 优惠」
  /// 切换开关（选中项为绿色药丸，未选项为灰色文字）；右侧为「计算器」卡片按钮。
  /// 布局：白色输入框（含绿色边框）宽 274px、左侧贴卡片左缘；右侧「计算器」卡片宽 96px、
  /// 右边缘贴卡片右缘，与上方「入款账户」标签卡片左右对齐；中间由 Row 的 spaceBetween 均分剩余空间。
  Widget _buildTransferFeeRow() {
    final bool isFee = _feeInputType == _FeeInputType.fee;
    final String? currentValue = isFee ? _feeAmount : _discountAmount;
    return Container(
      height: 48,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          SizedBox(
            width: 274,
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
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 24,
                ),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: AppDimens.spaceSm),
                  child: _buildFeeTypeToggle(),
                ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 68,
                  minHeight: 28,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                  vertical: AppDimens.spaceXs / 2,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
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
          SizedBox(
            width: 96,
            child: _buildTransferCalculatorButton(enabled: isFee),
          ),
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
  Widget _buildTransferCalculatorButton({required bool enabled}) {
    return InkWell(
      onTap: enabled ? _openTransferFeeCalculator : null,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: Container(
        width: 96,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(
          '计算器',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: enabled ? AppColors.textPrimary : AppColors.textTertiary,
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
      _feeInputController.text = type == _FeeInputType.fee
          ? (_feeAmount ?? '')
          : (_discountAmount ?? '');
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

  // ---- 借还页（小青账风格） ----

  /// 借还页顶部「借入 / 借出」分段开关。
  Widget _buildLendDirectionToggle() {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _buildLendDirectionSegment(
              label: '借入',
              selected: _lendDir == LendDirection.borrowIn,
              onTap: () => setState(() => _lendDir = LendDirection.borrowIn),
            ),
          ),
          Expanded(
            child: _buildLendDirectionSegment(
              label: '借出',
              selected: _lendDir == LendDirection.lendOut,
              onTap: () => setState(() => _lendDir = LendDirection.lendOut),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLendDirectionSegment({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
              ),
        ),
      ),
    );
  }

  /// 借还页动作图标网格：借入/借出、还债/收债、债务削减/坏账损失。
  Widget _buildLendActionGrid() {
    const List<_LendActionType> actions = _LendActionType.values;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        for (final _LendActionType action in actions)
          _buildLendActionItem(action),
      ],
    );
  }

  Widget _buildLendActionItem(_LendActionType action) {
    final bool selected = _lendAction == action;
    const Color activeColor = AppColors.primary;
    return InkWell(
      onTap: () => setState(() {
        _lendAction = action;
        _repayAccountId = null;
      }),
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: selected
                    ? activeColor.withValues(alpha: 0.12)
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
              child: Icon(
                action.icon(_lendDir),
                size: 28,
                color: selected ? activeColor : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              action.label(_lendDir),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: selected ? activeColor : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// 借还页账户选择卡片（借入/借出账户、资产账户）。
  /// [allowedCategories] 非空时只展示对应大类的账户；借入/借出账户通常限定为
  /// 应付 / 应收，资产账户则保持全部账户或另行传入资金类。
  Widget _buildLendAccountCard({
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
    required String placeholder,
    bool autoFillCounterparty = true,
    List<AccountCategory>? allowedCategories,
  }) {
    final AsyncValue<List<Account>> accounts = ref.watch(accountsProvider);
    return accounts.when(
      data: (List<Account> list) {
        // allowedCategories 非空（借入/借出账户）：只展示 payable / receivable；
        // 其余（资产账户、还款/收款账户）是资金类，排除应收应付对方虚拟账户。
        final List<Account> shown = allowedCategories == null
            ? fundAccountsOnly(list)
            : list
                .where(
                  (Account a) => allowedCategories.contains(a.type.category),
                )
                .toList(growable: false);
        final String? safe =
            shown.any((Account a) => a.id == value) ? value : null;
        final Account? selected =
            safe == null ? null : shown.firstWhere((Account a) => a.id == safe);
        return InkWell(
          onTap: shown.isEmpty
              ? null
              : () => _showTransferAccountPicker(
                    label: label,
                    accounts: shown,
                    selectedId: safe,
                    onChanged: (String? v) {
                      onChanged(v);
                      // 选择借入/借出账户时，若对方未填写则自动填入账户名。
                      if (autoFillCounterparty &&
                          label != '资产账户' &&
                          _counterpartyController.text.trim().isEmpty &&
                          v != null) {
                        final Account? acc = shown.cast<Account?>().firstWhere(
                              (Account? a) => a?.id == v,
                              orElse: () => null,
                            );
                        if (acc != null) {
                          _counterpartyController.text = acc.name;
                        }
                      }
                    },
                  ),
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          child: Container(
            height: 48,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  label == '资产账户'
                      ? Icons.account_balance_wallet_outlined
                      : Icons.account_box_outlined,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(
                  child: Text(
                    selected?.name ?? placeholder,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: selected != null
                              ? AppColors.textPrimary
                              : AppColors.textTertiary,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (Object e, _) => Text('账户加载失败：$e'),
    );
  }

  /// 借还页小字提示行。
  Widget _buildLendHintLine(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(
          Icons.info_outline,
          size: 14,
          color: AppColors.textTertiary,
        ),
        const SizedBox(width: AppDimens.spaceXs),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
          ),
        ),
      ],
    );
  }

  /// 借还页「对方账户」输入框的提示词：
  /// - 还债 / 债务削减 / 借入（借入方向）→ 借入账户
  /// - 收债 / 坏账损失 / 借出（借出方向）→ 借出账户
  String get _lendCounterpartyHint =>
      _lendDir == LendDirection.borrowIn ? '借入账户' : '借出账户';

  /// 债务削减 / 坏账损失 / 借还页对方的账户选择器。
  /// 点击后从当前方向对应的应收/应付真实账户中选择，不再显示资金、投资等账户；
  /// 也支持手动输入新账户。
  Widget _buildLendCounterpartyField() {
    final ThemeData theme = Theme.of(context);
    final String current = _counterpartyController.text.trim();
    final bool hasValue = current.isNotEmpty;

    return InkWell(
      onTap: _showLendCounterpartyPicker,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: Container(
        height: 48,
        width: double.infinity,
        padding: const EdgeInsets.only(left: AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.receipt_long_outlined,
              size: 20,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppDimens.spaceSm),
            Expanded(
              child: Text(
                hasValue ? current : _lendCounterpartyHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color:
                      hasValue ? AppColors.textPrimary : AppColors.textTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: AppDimens.spaceMd),
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 弹出底部选择器，列出当前方向下的应收/应付真实账户，不再显示资金、投资等账户。
  /// 使用 A 模板账户选择弹窗（网格卡片 + 列表切换 + 确认）。
  Future<void> _showLendCounterpartyPicker() async {
    final String? result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => Consumer(
        builder: (_, WidgetRef sheetRef, __) {
          final AsyncValue<List<Account>> accountsValue = sheetRef.watch(
            lendAccountsProvider(_lendDir),
          );
          return accountsValue.when(
            data: (List<Account> items) => AccountPickerSheet(
              accounts: items,
              selectedName: _counterpartyController.text.trim(),
              title: '选择${_lendDir == LendDirection.lendOut ? '应收' : '应付'}账户',
              noneTitle: '不选择具体账户',
              noneSubtitle: '仅计入收支账单，不计入资产',
              onReload: () => sheetRef.invalidate(
                lendAccountsProvider(_lendDir),
              ),
              // 点添加/资产管理：不关闭当前弹窗，把目标页压在上面；
              // 页面返回后弹窗仍原位（回到「选择账户」这个入口界面）。
              onAdd: () {
                if (mounted) context.push(Routes.accountAdd);
              },
              onManage: () {
                if (mounted) context.push(Routes.accountManage);
              },
              // 点「不选择具体账户」时 onConfirm 收到 null，用空字符串区分
              // 「明确选择不选择」（''）与「下滑关闭」（null）。
              onConfirm: (Account? acc) => Navigator.of(ctx).pop(acc?.name ?? ''),
            ),
            loading: () => Container(
              decoration: const BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: const SafeArea(
                top: false,
                child: SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
            error: (Object e, _) => Container(
              decoration: const BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 220,
                  child: Center(child: Text('加载失败：$e')),
                ),
              ),
            ),
          );
        },
      ),
    );

    if (result == null || !mounted) return;

    if (result.isEmpty) {
      // 用户选择「不选择具体账户」：保留手动输入能力。
      setState(() => _counterpartyController.clear());
      return;
    }

    setState(() => _counterpartyController.text = result);
  }

  /// 借还页利息 / 优惠 / 计算器行。

  /// 借还页利息 / 优惠 / 计算器行。
  /// 布局与转账页手续费行保持一致：白色输入框宽 274px、左侧贴卡片左缘；右侧「计算器」
  /// 卡片宽 96px、右边缘贴卡片右缘；中间由 Row 的 spaceBetween 均分剩余空间。
  Widget _buildLendFeeRow() {
    final bool isFee = _lendFeeInputType == _FeeInputType.fee;
    final String? currentValue = isFee ? _lendFeeAmount : _lendDiscountAmount;
    return Container(
      height: 48,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          SizedBox(
            width: 274,
            child: TextField(
              controller: _lendFeeController,
              focusNode: _lendFeeFocusNode,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: isFee ? '利息' : '优惠',
                hintStyle: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textTertiary),
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
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 24,
                ),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: AppDimens.spaceSm),
                  child: _buildLendFeeTypeToggle(),
                ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 68,
                  minHeight: 28,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                  vertical: AppDimens.spaceXs / 2,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
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
                    _lendFeeAmount = trimmed.isEmpty ? null : trimmed;
                  } else {
                    _lendDiscountAmount = trimmed.isEmpty ? null : trimmed;
                  }
                });
              },
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
            ),
          ),
          SizedBox(
            width: 96,
            child: _buildLendCalculatorButton(enabled: isFee),
          ),
        ],
      ),
    );
  }

  /// 「利息 / 优惠」切换开关。
  Widget _buildLendFeeTypeToggle() {
    final bool isFee = _lendFeeInputType == _FeeInputType.fee;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildLendFeeTypeSegment(
          label: '利息',
          selected: isFee,
          type: _FeeInputType.fee,
        ),
        _buildLendFeeTypeSegment(
          label: '优惠',
          selected: !isFee,
          type: _FeeInputType.discount,
        ),
      ],
    );
  }

  Widget _buildLendFeeTypeSegment({
    required String label,
    required bool selected,
    required _FeeInputType type,
  }) {
    return InkWell(
      onTap: () => _onLendFeeInputTypeChanged(type),
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

  /// 借还计算器按钮（文字按钮）。
  Widget _buildLendCalculatorButton({required bool enabled}) {
    return InkWell(
      onTap: enabled ? _openLendFeeCalculator : null,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: Container(
        width: 96,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(
          '计算器',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: enabled ? AppColors.textPrimary : AppColors.textTertiary,
              ),
        ),
      ),
    );
  }

  /// 打开手续费计算弹窗（转账页），回填手续费 / 优惠。
  Future<void> _openTransferFeeCalculator() async {
    final FeeCalculatorResult? result =
        await showModalBottomSheet<FeeCalculatorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppDimens.radiusLg),
          topRight: Radius.circular(AppDimens.radiusLg),
        ),
      ),
      builder: (_) => FeeCalculatorSheet(
        fee: _feeAmount,
        discount: _discountAmount,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _feeAmount = result.fee;
      _discountAmount = result.discount;
      _feeInputController.text = _feeInputType == _FeeInputType.fee
          ? (_feeAmount ?? '')
          : (_discountAmount ?? '');
    });
  }

  /// 打开手续费计算弹窗（借还页），回填利息 / 优惠。
  Future<void> _openLendFeeCalculator() async {
    final FeeCalculatorResult? result =
        await showModalBottomSheet<FeeCalculatorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppDimens.radiusLg),
          topRight: Radius.circular(AppDimens.radiusLg),
        ),
      ),
      builder: (_) => FeeCalculatorSheet(
        fee: _lendFeeAmount,
        discount: _lendDiscountAmount,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _lendFeeAmount = result.fee;
      _lendDiscountAmount = result.discount;
      _lendFeeController.text = _lendFeeInputType == _FeeInputType.fee
          ? (_lendFeeAmount ?? '')
          : (_lendDiscountAmount ?? '');
    });
  }

  /// 切换借还利息 / 优惠输入模式，并在模式间迁移当前输入值。
  void _onLendFeeInputTypeChanged(_FeeInputType type) {
    if (type == _lendFeeInputType) return;
    _lendFeeFocusNode.requestFocus();
    setState(() {
      final String current = _lendFeeController.text.trim();
      if (_lendFeeInputType == _FeeInputType.fee) {
        _lendFeeAmount = current.isEmpty ? null : current;
      } else {
        _lendDiscountAmount = current.isEmpty ? null : current;
      }
      _lendFeeInputType = type;
      _lendFeeController.text = type == _FeeInputType.fee
          ? (_lendFeeAmount ?? '')
          : (_lendDiscountAmount ?? '');
    });
  }

  /// 借还页利息说明文案。
  Widget _buildLendFeeHint() {
    final String dirLabel = _lendDir == LendDirection.borrowIn ? '借入' : '借出';
    final String oppositeLabel =
        _lendDir == LendDirection.borrowIn ? '还债' : '收债';
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
              '利息根据个人需求可在$dirLabel或者$oppositeLabel时候添加；一般在一方添加即可\n'
              '$dirLabel：\n'
              '${_lendDir == LendDirection.borrowIn ? '借入' : '借出'}账户 = 借入金额 + 利息\n'
              '资产账户 = 借入金额\n'
              '$oppositeLabel：\n'
              '${_lendDir == LendDirection.borrowIn ? '借入' : '借出'}账户 = 借入金额\n'
              '资产账户 = 借入金额 + 利息',
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
          data: (List<Category> list) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildCategoryGrid(list),
              _buildAttachmentSection(),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, StackTrace? s) => Center(child: Text('分类加载失败：$e')),
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
            const SizedBox(height: AppDimens.spaceLg),
            _buildAttachmentSection(),
          ],
        );
      case RecordTab.lend:
        final bool isDebtReduction =
            _lendAction == _LendActionType.debtReduction;
        final bool isRepay = _lendAction == _LendActionType.repay;
        // 减免 / 还款都按「对方账户」冲销未结清债务，不需要资产账户卡片。
        final bool usesCounterparty = isDebtReduction || isRepay;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildLendDirectionToggle(),
            const SizedBox(height: AppDimens.spaceLg),
            _buildLendActionGrid(),
            const SizedBox(height: AppDimens.spaceLg),
            if (usesCounterparty) ...<Widget>[
              _buildLendCounterpartyField(),
              const SizedBox(height: AppDimens.spaceSm),
              _buildLendHintLine(
                isRepay
                    ? (_lendDir == LendDirection.borrowIn
                        ? '输入欠款对象，将冲销其名下未结清借入债务（按发生时间从早到晚抵扣）；不选择具体账户时仅记资金流水'
                        : '输入借款对象，将冲销其名下未结清借出债务（按发生时间从早到晚抵扣）；不选择具体账户时仅记资金流水')
                    : (_lendDir == LendDirection.borrowIn
                        ? '虚拟账户：如找小明借钱，小明就是此账户'
                        : '虚拟账户：如借给小明，小明就是此账户'),
              ),
              if (isRepay) ...<Widget>[
                const SizedBox(height: AppDimens.spaceMd),
                _buildLendAccountCard(
                  label: _lendDir == LendDirection.borrowIn ? '还款账户' : '收款账户',
                  value: _repayAccountId,
                  placeholder: _lendDir == LendDirection.borrowIn
                      ? '选择还款账户（现金从此扣出）'
                      : '选择收款账户（现金存入此账户）',
                  onChanged: (String? v) => setState(() => _repayAccountId = v),
                  autoFillCounterparty: false,
                ),
                const SizedBox(height: AppDimens.spaceSm),
                _buildLendHintLine(
                  _lendDir == LendDirection.borrowIn
                      ? '还债：现金从该账户扣出，余额相应减少'
                      : '收债：现金存入该账户，余额相应增加',
                ),
              ],
            ] else ...<Widget>[
              _buildLendAccountCard(
                label: _lendDir == LendDirection.borrowIn ? '借入账户' : '借出账户',
                value: _accountId,
                placeholder:
                    _lendDir == LendDirection.borrowIn ? '借入账户' : '借出账户',
                onChanged: (String? v) => setState(() => _accountId = v),
                allowedCategories: <AccountCategory>[
                  _lendDir == LendDirection.borrowIn
                      ? AccountCategory.payable
                      : AccountCategory.receivable,
                ],
              ),
              const SizedBox(height: AppDimens.spaceSm),
              _buildLendHintLine(
                _lendDir == LendDirection.borrowIn
                    ? '虚拟账户：如找小明借钱，小明就是此账户'
                    : '虚拟账户：如借给小明，小明就是此账户',
              ),
              const SizedBox(height: AppDimens.spaceMd),
              _buildLendAccountCard(
                label: '资产账户',
                value: _toAccountId,
                placeholder: '资产账户',
                onChanged: (String? v) => setState(() => _toAccountId = v),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              _buildLendHintLine('资产账户：将金额累计到这个账户里'),
              const SizedBox(height: AppDimens.spaceLg),
              _buildLendFeeRow(),
              const SizedBox(height: AppDimens.spaceMd),
              _buildLendFeeHint(),
            ],
          ],
        );
      case RecordTab.reimbursement:
      case RecordTab.refund:
      case RecordTab.savings:
      case RecordTab.installment:
        // 存钱 / 分期已分别走独立布局或内嵌页面，不在 legacy body 渲染。
        return const SizedBox.shrink();
    }
  }

  /// 原 ListView + 底部键盘布局，供存钱复用。
  Widget _buildLegacyBody() {
    return Column(
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
            onChanged: (String v) => setState(() => _amount = v),
            onSave: () => _save(),
            onSaveAndMore: () => _save(andMore: true),
          ),
        ),
      ],
    );
  }

  /// 报销页独立布局（小青账模板）：顶部滚动表单 + 底部固定「保存」按钮。
  ///
  /// 报销使用自带「报销收入」输入框（系统数字键盘），不使用自定义数字键盘，
  /// 因此底部不渲染键盘栏，只放一个「保存」按钮。
  Widget _buildReimbursementBody() {
    return Column(
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimens.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildReimbursementForm(),
            ),
          ),
        ),
        _buildSaveFooter(),
      ],
    );
  }

  List<Widget> _buildReimbursementForm() {
    return <Widget>[
      _buildTransferAccountCard(
        label: '报销账户',
        value: _rbAccountId,
        placeholder: '请选择报销账户',
        // 报销账户仅展示「报销」类型（应收类中的这一个分支，不含借出）
        allowedTypes: const <AccountType>[AccountType.reimbursement],
        onChanged: (String? v) => setState(() => _rbAccountId = v),
      ),
      const SizedBox(height: AppDimens.spaceMd),
      _buildRbBillField(),
      const SizedBox(height: AppDimens.spaceMd),
      _buildRbAmountRow(),
      const SizedBox(height: AppDimens.spaceMd),
      _dateField(),
      const SizedBox(height: AppDimens.spaceMd),
      SwitchListTile(
        title: const Text('不计入收支'),
        subtitle: const Text('个人垫款、与报销统计无关时开启'),
        value: _rbExclude,
        onChanged: (bool v) => setState(() => _rbExclude = v),
        contentPadding: EdgeInsets.zero,
      ),
      const SizedBox(height: AppDimens.spaceMd),
      _noteField(),
      const SizedBox(height: AppDimens.spaceMd),
      _buildTransferAccountCard(
        label: '收款账户',
        value: _rbToAccountId,
        placeholder: '请选择收款账户',
        onChanged: (String? v) => setState(() => _rbToAccountId = v),
      ),
      const SizedBox(height: AppDimens.spaceMd),
      _buildRbBookRow(),
    ];
  }

  /// 报销账单（事由）。
  Widget _buildRbBillField() => TextField(
        controller: _rbTitleController,
        decoration: const InputDecoration(labelText: '报销账单'),
        maxLines: 1,
      );

  /// 报销收入金额输入框：¥ 图标 + 数字输入框，使用系统数字键盘。
  Widget _buildRbAmountRow() {
    final String text = _rbAmountController.text.trim();
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _rbAmountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: '报销收入',
                hintStyle: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textTertiary),
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
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 24,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                  vertical: AppDimens.spaceXs / 2,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: text.isNotEmpty
                        ? AppColors.textPrimary
                        : AppColors.textTertiary,
                  ),
              maxLines: 1,
              onChanged: (_) => setState(() {}),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
            ),
          ),
        ],
      ),
    );
  }

  /// 账本（只读展示当前账本名）。
  Widget _buildRbBookRow() {
    final AsyncValue<Book?> book = ref.watch(currentBookProvider);
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.book_outlined,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppDimens.spaceSm),
          const Text('账本'),
          const Spacer(),
          Text(
            book.valueOrNull?.name ?? '账本',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(width: AppDimens.spaceXs),
          Icon(
            Icons.chevron_right,
            size: 16,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }

  /// 独立布局页（报销 / 退款）底部「保存」按钮。
  Widget _buildSaveFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceSm,
        AppDimens.spaceLg,
        AppDimens.spaceLg,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          onPressed: _saving ? null : () => _save(),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ),
    );
  }

  /// 退款页独立布局（小青账模板）。
  Widget _buildRefundBody() {
    return Column(
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimens.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildRefundForm(),
            ),
          ),
        ),
        _buildSaveFooter(),
      ],
    );
  }

  List<Widget> _buildRefundForm() {
    return <Widget>[
      _buildSectionTitle('原账单'),
      const SizedBox(height: AppDimens.spaceSm),
      _buildRefundOriginalField(),
      const SizedBox(height: AppDimens.spaceMd),
      _buildSectionTitle('退款信息'),
      const SizedBox(height: AppDimens.spaceSm),
      _buildRefundModeChips(),
      const SizedBox(height: AppDimens.spaceMd),
      _buildRefundAmountRow(),
      const SizedBox(height: AppDimens.spaceMd),
      _dateField(label: '时间'),
      const SizedBox(height: AppDimens.spaceMd),
      _buildRefundNoteField(),
      const SizedBox(height: AppDimens.spaceMd),
      _buildSectionTitle('账户'),
      const SizedBox(height: AppDimens.spaceSm),
      _buildTransferAccountCard(
        label: '入款账户',
        value: _accountId,
        placeholder: '入款账户',
        onChanged: (String? v) => setState(() => _accountId = v),
      ),
      const SizedBox(height: AppDimens.spaceMd),
      _buildAttachmentSection(),
      const SizedBox(height: AppDimens.spaceMd),
      _buildRbBookRow(),
    ];
  }

  /// 带绿色竖线的分组标题。
  Widget _buildSectionTitle(String label) {
    return Row(
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
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
        ),
      ],
    );
  }

  /// 原账单选择栏。
  ///
  /// - 未选：显示占位提示。
  /// - 单选：显示日期 + 金额 + 备注。
  /// - 多选：显示「共 N 笔，合计 ¥XXX.XX」+ 首条备注等摘要。
  Widget _buildRefundOriginalField() {
    final List<Transaction> txns = _refundOriginals;
    final String display;
    if (txns.isEmpty) {
      display = '请选择需要退款的账单';
    } else if (txns.length == 1) {
      final Transaction txn = txns.first;
      final String date = DateFormat('M月d日').format(
        DateTime.fromMillisecondsSinceEpoch(txn.occurredAt),
      );
      final String note = (txn.note ?? '').trim();
      display = '$date · ${Money.fromMinor(txn.amountMinor).format()}'
          '${note.isEmpty ? '' : ' · $note'}';
    } else {
      final int totalMinor = txns.fold<int>(
        0,
        (int sum, Transaction t) => sum + t.amountMinor,
      );
      final String sample = (txns.first.note ?? '').trim();
      display = '共 ${txns.length} 笔，合计 ${Money.fromMinor(totalMinor).format()}'
          '${sample.isEmpty ? '' : ' · $sample 等'}';
    }
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              display,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: txns.isEmpty
                        ? AppColors.textTertiary
                        : AppColors.textPrimary,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ActionChip(
            label: const Text('搜索'),
            onPressed: _onSearchRefundOriginal,
          ),
          const SizedBox(width: AppDimens.spaceSm),
          ActionChip(
            label: const Text('选取'),
            onPressed: _pickRefundOriginal,
          ),
        ],
      ),
    );
  }

  Future<void> _onSearchRefundOriginal() async {
    _toast('账单搜索功能开发中');
  }

  /// 点击「选取」打开账单选择页面（全屏 Navigator.push）。
  ///
  /// 跳转与传参逻辑：
  /// - 触发方式：退款页「原账单」栏右侧的「选取」ActionChip。
  /// - 页面跳转：通过 [Navigator.push] 推入 [BillSelectionPage]，等待返回
  ///   `List<Transaction>`，避免 go_router 不便传递对象的问题。
  /// - 传参：传入当前账本 ID 与已选账单 ID 列表，实现编辑回显。
  /// - 合并机制：页面内允许多选，确认后返回列表；退款页把金额求和视为
  ///   一条合并退款，多选时把原始金额明细写入备注。
  Future<void> _pickRefundOriginal() async {
    final String? bookId = ref.read(currentBookIdProvider);
    final List<Transaction>? selected =
        await Navigator.of(context).push<List<Transaction>>(
      MaterialPageRoute<List<Transaction>>(
        builder: (_) => BillSelectionPage(
          bookId: bookId,
          initialSelectedIds:
              _refundOriginals.map((Transaction t) => t.id).toList(),
          multiSelect: true,
          title: '选择原账单',
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _refundOriginals
        ..clear()
        ..addAll(selected);
    });
  }

  /// 退款模式：全额退款 / AA 付款。
  Widget _buildRefundModeChips() {
    return SegmentedButton<RefundMode>(
      segments: const <ButtonSegment<RefundMode>>[
        ButtonSegment<RefundMode>(
          value: RefundMode.aa,
          label: Text('AA 付款'),
        ),
        ButtonSegment<RefundMode>(
          value: RefundMode.full,
          label: Text('全额退款'),
        ),
      ],
      selected: <RefundMode>{_refundMode},
      onSelectionChanged: (Set<RefundMode> next) =>
          setState(() => _refundMode = next.first),
    );
  }

  /// 退款金额行：标签 + 自动/自定义开关，下方显示/输入金额。
  Widget _buildRefundAmountRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              '退款金额',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
            ),
            const Spacer(),
            SegmentedButton<bool>(
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(value: true, label: Text('自动')),
                ButtonSegment<bool>(value: false, label: Text('自定义')),
              ],
              selected: <bool>{_refundAmountAuto},
              onSelectionChanged: (Set<bool> next) => setState(() {
                _refundAmountAuto = next.first;
                if (_refundAmountAuto) {
                  _refundAmountController.clear();
                }
              }),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceSm),
        if (_refundAmountAuto)
          _buildRefundAmountDisplay()
        else
          _buildRefundAmountInput(),
      ],
    );
  }

  Widget _buildRefundAmountDisplay() {
    final int m = _refundAmountMinor;
    final int originalTotal = _refundOriginalTotalMinor;
    final bool isAa = _refundMode == RefundMode.aa && originalTotal > 0;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          const SizedBox(width: AppDimens.spaceMd),
          Container(
            width: 3,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Text(
            m <= 0 ? '0.00' : Money.fromMinor(m).format(showSymbol: false),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
          ),
          if (isAa) ...<Widget>[
            const Spacer(),
            Text(
              '人均（2人AA）',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(width: AppDimens.spaceMd),
          ],
        ],
      ),
    );
  }

  Widget _buildRefundAmountInput() {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      borderSide: const BorderSide(color: AppColors.divider),
    );
    return TextField(
      controller: _refundAmountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      textAlignVertical: TextAlignVertical.center,
      decoration: InputDecoration(
        hintText: '请输入退款金额',
        hintStyle: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: AppColors.textTertiary),
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
                    height: 1.0,
                  ),
            ),
          ),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 44, minHeight: 24),
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
      ),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
          ),
      maxLines: 1,
      onChanged: (_) => setState(() {}),
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
    );
  }

  /// 退款备注输入框（带左侧信息图标）。
  ///
  /// 绿色圆角边框 + 白色填充，占满整行宽度。
  Widget _buildRefundNoteField() {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      borderSide: const BorderSide(color: AppColors.divider),
    );
    return TextField(
      controller: _noteController,
      decoration: InputDecoration(
        hintText: '备注',
        hintStyle: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: AppColors.textTertiary),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 12, right: 8),
          child: Icon(
            Icons.info_outline,
            size: 18,
            color: AppColors.textTertiary,
          ),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 38, minHeight: 18),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceSm,
        ),
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
      maxLines: 2,
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
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
          icon: categoryIconData(cat.iconKey),
          color: cat.colorValue != null
              ? Color(cat.colorValue!)
              : AppColors.chartPalette[colorIndex],
          onTap: () => _onCategoryTap(cat, categories),
        );
      },
    );
  }

  void _onCategoryTap(Category parent, List<Category> all) {
    final List<Category> children = all
        .where((Category c) => c.parentId == parent.id)
        .toList(growable: false);
    // 小青账交互：点任意父分类都弹出二级菜单（即使暂无子分类，
    // 也给出「添加」入口，并能直接选中父分类记账）。
    _showSubcategorySheet(parent, children);
  }

  Future<void> _showSubcategorySheet(
    Category parent,
    List<Category> children,
  ) async {
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: false,
      builder: (BuildContext ctx) => _SubcategorySheet(
        parent: parent,
        children: children,
        selectedId: _categoryId,
      ),
    );
    if (selected == null || !mounted) return;
    if (selected == '__add__') {
      await context.push(
        '/categories/add-subcategory',
        extra: parent,
      );
      return;
    }
    setState(() => _categoryId = selected);
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
          // 已设优惠时对齐小青账：chip 显示「优惠50.00」并高亮
          label: _discountAmount == null || _discountAmount!.isEmpty
              ? '优惠'
              : '优惠${Money.tryParse(_discountAmount!).decimal.toStringAsFixed(2)}',
          icon: Icons.local_offer_outlined,
          onTap: _onDiscount,
          active: _discountAmount != null && _discountAmount!.isNotEmpty,
        ),
      _FunctionItem(
        label:
            _attachmentPaths.isEmpty ? '图片' : '图片 ${_attachmentPaths.length}',
        icon: Icons.image_outlined,
        onTap: _onAddImage,
        active: _attachmentPaths.isNotEmpty,
      ),
      _FunctionItem(
        label: _tags.isEmpty ? '标签' : '标签 ${_tags.length}',
        icon: Icons.label_outlined,
        onTap: _onAddTag,
      ),
      _FunctionItem(
        // 账本占位：展示当前账本名；多账本切换功能待接入（点击暂不响应）。
        label: ref.watch(currentBookProvider).value?.name ?? '账本',
        icon: Icons.menu_book_outlined,
        onTap: () {},
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
    final Color color =
        active ? theme.colorScheme.primary : AppColors.textSecondary;
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? theme.colorScheme.primaryContainer
              : AppColors.surfaceLight,
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
    if (mounted && _keyboardExpanded) {
      setState(() => _keyboardExpanded = false);
    }
    final String? value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: ForestBg.paper,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusLg)),
      ),
      // 优惠前金额 = 上一页（记一笔）当前金额，弹窗内只录入优惠 / 实付。
      builder: (BuildContext ctx) => DiscountSheet(
        initial: _discountAmount,
        base: _displayAmount,
      ),
    );
    if (value == null || !mounted) return;
    setState(
        () => _discountAmount = value.trim().isEmpty ? null : value.trim());
  }

  /// 支出 / 收入功能键「账户」：A 模板账户选择弹窗。
  /// 可不选（「不选择具体账户」清空账户）；标题随当前 tab 变化。
  Future<void> _onSelectAccount() async {
    final bool isExpense = _tab == RecordTab.expense;
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => Consumer(
        builder: (_, WidgetRef sheetRef, __) {
          final AsyncValue<List<Account>> accountsValue =
              sheetRef.watch(accountsProvider);
          return accountsValue.when(
            data: (List<Account> items) => AccountPickerSheet(
              accounts: fundAccountsOnly(items),
              selectedId: _accountId,
              title: isExpense ? '选择支出账户' : '选择收入账户',
              noneTitle: '不选择具体账户',
              noneSubtitle: '仅计入收支账单，不计入资产',
              onReload: () => sheetRef.invalidate(accountsProvider),
              // 点添加/资产管理：不关闭当前弹窗，把目标页压在上面；
              // 页面返回后弹窗仍原位（回到「选择账户」这个入口界面）。
              onAdd: () {
                if (mounted) context.push(Routes.accountAdd);
              },
              onManage: () {
                if (mounted) context.push(Routes.accountManage);
              },
              onConfirm: (Account? acc) => Navigator.of(ctx).pop(acc?.id ?? ''),
            ),
            loading: () => Container(
              decoration: const BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: const SafeArea(
                top: false,
                child: SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
            error: (Object e, _) => Container(
              decoration: const BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 220,
                  child: Center(child: Text('加载失败：$e')),
                ),
              ),
            ),
          );
        },
      ),
    );
    if (selected == null || !mounted) return;
    if (selected.isEmpty) {
      // 「不选择具体账户」：清空已选账户。
      setState(() => _accountId = null);
      return;
    }
    setState(() => _accountId = selected);
  }

  /// 图片功能键弹窗：复刻「森林手账·鼠尾草绿」账单图片模板（对齐小青账）。
  /// 暖纸皮肤（与设计交付模板 bill-photo-sheet-forest.html FINAL 同源）：
  ///   · 纸底 ForestBg.paper ｜ 奶油卡 ForestSurface.card ｜ 沙底关闭钮 ForestBg.sunken
  ///   · 选中按钮 = 鼠尾草绿渐变 ForestGradients.sageMid + 深绿墨字 ForestSage.ink
  /// 半屏贴底（高度 = 屏幕 50%），照片/拍照可切换选中；照片支持多选（最多 9 张）。
  ///
  /// 选完图片后**循环回到本弹窗**（已选图片显示在虚线卡内，可继续追加或删除），
  /// 仅点 ✕（或下滑关闭）才回到记账页。
  Future<void> _onAddImage() async {
    while (mounted) {
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (BuildContext ctx) => ImageSourceSheet(
          attachments: List<String>.of(_attachmentPaths),
          onRemove: (String path) =>
              setState(() => _attachmentPaths.remove(path)),
          onReorder: (int from, int to) => setState(() {
            final String item = _attachmentPaths.removeAt(from);
            _attachmentPaths.insert(to, item);
          }),
        ),
      );
      if (source == null || !mounted) return; // ✕ 关闭：回到记账页

      if (source == ImageSource.gallery) {
        // 相册多选：总上限 9 张，剩余配额 = 9 - 已选数。
        final int remain = 9 - _attachmentPaths.length;
        if (remain <= 0) {
          _toast('最多选择9张图片');
          continue; // 回到弹窗，让用户先删除
        }
        final List<XFile> picked = await ImagePicker()
            .pickMultiImage(imageQuality: 80, limit: remain);
        // 取消选择也回到弹窗（保持入口一致）。
        if (picked.isEmpty || !mounted) continue;
        // image_picker 的 limit 在 iOS 上不强制（仅 Android Photo Picker 支持），
        // 返回后本地再裁一次，超出配额的丢弃并提示。
        final List<XFile> accepted =
            picked.length > remain ? picked.sublist(0, remain) : picked;
        if (accepted.length < picked.length) {
          _toast('最多选择9张图片，已保留前 ${accepted.length} 张');
        }
        for (final XFile f in accepted) {
          final String? stored = await _copyPickedImageToStorage(f);
          if (stored != null && mounted) _attachmentPaths.add(stored);
        }
        if (mounted) setState(() {});
      } else {
        if (_attachmentPaths.length >= 9) {
          _toast('最多选择9张图片');
          continue; // 回到弹窗，让用户先删除
        }
        final XFile? picked = await ImagePicker().pickImage(
          source: source,
          imageQuality: 80,
        );
        if (picked == null || !mounted) continue;
        final String? stored = await _copyPickedImageToStorage(picked);
        if (stored != null && mounted) {
          setState(() => _attachmentPaths.add(stored));
        }
      }
      // 不 return：循环回到弹窗，展示已选图片，用户点 ✕ 才退出。
    }
  }

  /// 把系统返回的临时图片复制到应用私有附件目录，返回持久化后的绝对路径。
  ///
  /// image_picker 返回的路径多在系统缓存/临时区，重启或清理后可能失效；
  /// 复制到 `<appDocs>/attachments/` 才能保证长期可读（与流水一起持久化）。
  Future<String?> _copyPickedImageToStorage(XFile file) async {
    try {
      final Directory docs = await getApplicationDocumentsDirectory();
      final Directory dir = Directory(p.join(docs.path, 'attachments'));
      if (!await dir.exists()) await dir.create(recursive: true);
      final String ext = p.extension(file.path).isNotEmpty
          ? p.extension(file.path).toLowerCase()
          : '.jpg';
      final String fileName = '${const Uuid().v7()}$ext';
      final File dst = File(p.join(dir.path, fileName));
      final File src = File(file.path);
      if (await src.exists()) {
        await src.copy(dst.path);
      } else {
        final Uint8List? bytes = await file.readAsBytes();
        if (bytes == null) return null;
        await dst.writeAsBytes(bytes);
      }
      return dst.path;
    } catch (e) {
      _toast('图片保存失败：$e');
      return null;
    }
  }

  /// 图片附件预览：横排滑动（单行，左对齐依次排开，超出屏宽左右滑动），
  /// 缩略图 + 删除 + 点击查看大图；长按缩略图可拖拽调整顺序。
  ///
  /// 拖拽用 LongPressDraggable + DragTarget 自绘（与账单图片弹窗 3×3 网格同款），
  /// 不用横向 ReorderableListView——后者对横向列表项的约束/代理布局易溢出报红。
  Widget _buildAttachmentSection() {
    if (_attachmentPaths.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: AppDimens.spaceMd),
        _buildSectionTitle('图片附件'),
        const SizedBox(height: AppDimens.spaceSm),
        SizedBox(
          // 72px 缩略图 + 上下 4px 余量，容纳 ✕ 徽标越出缩略图 2px
          height: 80,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                for (int i = 0; i < _attachmentPaths.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: AppDimens.spaceSm),
                  _stripCell(i),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 横条单格：长按拖拽排序（与账单图片弹窗同款自绘）。
  /// 优化点：拖起触感反馈、浮图放大跟手；原位留空槽；
  /// 悬停落点放大+绿边+淡绿底，落定轻微触感反馈。单击看大图/✕ 删除不受影响。
  Widget _stripCell(int index) {
    final String path = _attachmentPaths[index];
    return LongPressDraggable<String>(
      data: path,
      maxSimultaneousDrags: 1,
      dragAnchorStrategy: childDragAnchorStrategy,
      onDragStarted: () => HapticFeedback.mediumImpact(),
      feedback: Transform.scale(
        scale: 1.06,
        child: Container(
          width: 72,
          height: 72,
          transform: Matrix4.translationValues(0, -6, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x552E5B39),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            child: Image(
              image: resolveImageProvider(path, _attachmentBaseUrl),
              width: 72,
              height: 72,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
      // 原位变空槽，直观表达「已被拿起」
      childWhenDragging: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          color: ForestBg.sunken,
          border: Border.all(color: ForestNeutral.hairline, width: 1.5),
        ),
      ),
      child: DragTarget<String>(
        onWillAccept: (String? data) => data != null && data != path,
        onAccept: (String dragged) {
          final int from = _attachmentPaths.indexOf(dragged);
          if (from < 0 || from == index) return;
          setState(() {
            final String item = _attachmentPaths.removeAt(from);
            _attachmentPaths.insert(index, item);
          });
          HapticFeedback.selectionClick();
        },
        builder: (
          BuildContext ctx,
          List<String?> candidate,
          List<dynamic> rejected,
        ) {
          final bool hovered = candidate.isNotEmpty;
          return AnimatedScale(
            scale: hovered ? 1.06 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                border: hovered
                    ? Border.all(color: const Color(0xFF3C8A60), width: 2.5)
                    : null,
                color: hovered ? const Color(0x1A3C8A60) : null,
              ),
              child: _buildAttachmentThumb(path),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAttachmentThumb(String path) {
    return AttachmentThumb(
      url: path,
      baseUrl: _attachmentBaseUrl,
      showDelete: true,
      onDeleted: () => setState(() => _attachmentPaths.remove(path)),
    );
  }

  /// 当前同步端点（拼接相对附件地址用）。未配置时使用编译期默认值。
  String get _attachmentBaseUrl =>
      ref.watch(syncSettingsProvider).value?.baseUrl ?? Env.syncBaseUrl;

  /// 把本笔流水的本地附件异步上传到云端 R2，并把返回的 `/api/file/<key>` URL
  /// 写回流水（替换本机路径），使其他设备 pull 后即可查看原图。
  ///
  /// 使用稳定的 [remoteKey]（`$txnId_$index$ext`）保证幂等：重传同一笔会覆盖
  /// 同一对象、URL 不变。离线或单张失败时保留本机路径，不阻断其余图片。
  Future<void> _uploadAttachments(String txnId) async {
    final SyncAdapter adapter = ref.read(syncAdapterProvider);
    if (!await adapter.isAvailable()) return; // 离线：保留本机路径

    final List<String> finalUrls = <String>[];
    for (int i = 0; i < _attachmentPaths.length; i++) {
      final String local = _attachmentPaths[i];
      final String ext = p.extension(local).isNotEmpty
          ? p.extension(local).toLowerCase()
          : '.jpg';
      final String key = '${txnId}_$i$ext';
      try {
        finalUrls.add(await adapter.uploadFile(local, remoteKey: key));
      } catch (_) {
        finalUrls.add(local); // 上传失败保留本机路径
      }
    }

    if (!mounted) return;
    final Transaction? txn =
        await ref.read(transactionsDaoProvider).getById(txnId);
    if (txn != null && mounted) {
      await ref.read(transactionRepositoryProvider).updateTransaction(
            original: txn,
            attachmentUrls: finalUrls,
          );
    }
  }

  Future<void> _onAddTag() async {
    if (mounted && _keyboardExpanded) {
      setState(() => _keyboardExpanded = false);
    }
    // 打开标签选择弹窗（50% 半屏），返回选中的标签名列表。
    // 弹窗内可进入「标签管理页」增删改分组与标签，选择态与新增即时同步。
    final List<String>? selected = await TagSheet.show(
      context,
      initialSelected: _tags,
    );
    if (selected == null || !mounted) return;
    setState(() => _tags
      ..clear()
      ..addAll(selected));
  }

  /// 打开「记一笔模板」面板：可把当前填写存为模板，也可一键套用已有模板。
  Future<void> _onSaveTemplate() async {
    final RecordTemplateDraft draft = RecordTemplateDraft(
      tabIndex: _tab.index,
      accountId: _accountId,
      categoryId: _categoryId,
      note: _noteController.text.trim(),
      tags: _tags.isEmpty ? null : jsonEncode(_tags),
      excludeFromStats: _excludeFromStats,
      excludeFromBudget: _excludeFromBudget,
      isReimbursable: _isReimbursable,
    );
    await RecordTemplateSheet.show(
      context,
      draft: draft,
      onApply: _applyTemplate,
    );
  }

  /// 套用模板：填充 Tab / 账户 / 分类 / 备注 / 标签 / 开关（金额不填）。
  void _applyTemplate(RecordTemplate t) {
    setState(() {
      _tab = RecordTab.values[t.tabIndex];
      _accountId = t.accountId;
      _categoryId = t.categoryId;
      _noteController.text = t.note ?? '';
      _tags.clear();
      if (t.tags != null && t.tags!.isNotEmpty) {
        final List<dynamic>? decoded = jsonDecode(t.tags!) as List<dynamic>?;
        if (decoded != null) _tags.addAll(decoded.cast<String>());
      }
      _excludeFromStats = t.excludeFromStats;
      _excludeFromBudget = t.excludeFromBudget;
      _isReimbursable = t.isReimbursable;
    });
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
                  DateFormat('M月d日 HH:mm').format(_occurredAt),
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
                fillColor: Colors.transparent,
                filled: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
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
    final ColorScheme scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        // 顶栏布局：左返回箭头 + 中间原生 TabBar（横向滑动、指示器随手指连续滑动）
        // + 右设置键。尺寸规格：左右留白 19 / 图标 24×24 / 箭头→首 Tab 间距 40 /
        // 末 Tab→设置键间距 40 / 相邻 Tab 间距 12。
        // 使用原生 TabBar 替代自制滚动行：其内置 IndicatorPainter 直接跟随
        // TabController.animation 每帧重绘，拖拽时高亮随手指平滑滑动，无跳变延迟。
        automaticallyImplyLeading: false,
        leadingWidth: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 19),
          child: Row(
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                iconSize: 24,
                onPressed: () => context.pop(),
                tooltip: '返回',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 24,
                  height: 24,
                ),
              ),
              // 返回键→首 Tab 间距 40：TabBar 首 Tab 左侧 labelPadding 为 12，
              // 故此处留白 28 抵消，使箭头到首个 pill 仍为 40。
              const SizedBox(width: 28),
              Expanded(
                child: Theme(
                  // 覆盖默认 TabBar 点击水波纹，避免与 pill 选中态视觉冲突。
                  data: theme.copyWith(
                    splashFactory: NoSplash.splashFactory,
                    highlightColor: Colors.transparent,
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    // 点击 Tab：让 PageView 平滑滚动到目标页，bar 指示器由
                    // TabController 原生动画驱动；_pageAnimating 防止回写冲突。
                    onTap: (int index) {
                      _pageAnimating = true;
                      _pageController
                          .animateToPage(
                        index,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      )
                          .then((_) {
                        _pageAnimating = false;
                      });
                    },
                    tabAlignment: TabAlignment.start,
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                    dividerHeight: 0,
                    indicator: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                    ),
                    indicatorSize: TabBarIndicatorSize.label,
                    labelColor: scheme.onPrimaryContainer,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    unselectedLabelStyle: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: RecordTab.values
                        .map(
                          (RecordTab t) => Tab(
                            height: 40,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(t.label),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(width: 40),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                iconSize: 24,
                onPressed: () => RecordingSettingsSheet.show(context),
                tooltip: '记账页面设置',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 24,
                  height: 24,
                ),
              ),
            ],
          ),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        // 拖拽结束后兜底同步表单状态（边界已在 _onTabChanged 处理）。
        onPageChanged: (int index) {
          if (index != _tab.index) {
            _tab = RecordTab.values[index];
            _categoryId = null;
            _attachmentPaths.clear();
            FocusManager.instance.primaryFocus?.unfocus();
            if (mounted) setState(() {});
          }
        },
        itemCount: RecordTab.values.length,
        // 懒构建：只创建当前页与相邻页，避免首帧一次性构建 8 套完整表单。
        itemBuilder: (BuildContext context, int index) {
          final RecordTab tab = RecordTab.values[index];
          if (tab == RecordTab.installment) {
            return const AddInstallmentPage(showAppBar: false);
          } else if (tab == RecordTab.reimbursement) {
            return _KeepAlivePage(
              key: ValueKey<RecordTab>(tab),
              builder: (_) => _buildReimbursementBody(),
            );
          } else if (tab == RecordTab.refund) {
            return _KeepAlivePage(
              key: ValueKey<RecordTab>(tab),
              builder: (_) => _buildRefundBody(),
            );
          } else if (tab.usesNewLayout) {
            return _KeepAlivePage(
              key: ValueKey<RecordTab>(tab),
              builder: (_) => _buildNewLayoutBody(),
            );
          } else {
            return _KeepAlivePage(
              key: ValueKey<RecordTab>(tab),
              builder: (_) => _buildLegacyBody(),
            );
          }
        },
      ),
    );
  }
}

/// 让 [PageView] 的子页面在切走后保持存活，避免每次切换都重建整个表单。
class _KeepAlivePage extends StatefulWidget {
  final WidgetBuilder builder;

  const _KeepAlivePage({super.key, required this.builder});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.builder(context);
  }
}

/// 分类网格项：图标 + 名称。
class _CategoryItem extends StatelessWidget {
  const _CategoryItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: selected
              ? Border.all(color: color, width: 2)
              : Border.all(color: Colors.transparent),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.2),
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
          ],
        ),
      ),
    );
  }
}

/// 宫格 / 列表横向切换按钮。
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({
    required this.listView,
    required this.onChanged,
  });

  final bool listView;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    Widget buildOption({
      required bool value,
      required IconData icon,
      required String label,
    }) {
      final bool selected = listView == value;
      return Material(
        color:
            selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onChanged(value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  icon,
                  size: 16,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        buildOption(
          value: false,
          icon: Icons.grid_view_outlined,
          label: '宫格',
        ),
        const SizedBox(width: AppDimens.spaceSm),
        buildOption(
          value: true,
          icon: Icons.list_alt_outlined,
          label: '列表',
        ),
      ],
    );
  }
}

/// 二级分类底部面板：仿小青账网格 + 列表切换 + 添加子分类入口。
class _SubcategorySheet extends StatefulWidget {
  const _SubcategorySheet({
    required this.parent,
    required this.children,
    this.selectedId,
  });

  final Category parent;
  final List<Category> children;
  final String? selectedId;

  @override
  State<_SubcategorySheet> createState() => _SubcategorySheetState();
}

class _SubcategorySheetState extends State<_SubcategorySheet> {
  bool _listView = false;

  Color get _parentColor => widget.parent.colorValue != null
      ? Color(widget.parent.colorValue!)
      : AppColors.primary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = _parentColor;

    return SizedBox(
      width: MediaQuery.sizeOf(context).width,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceLg,
            AppDimens.spaceSm,
            AppDimens.spaceLg,
            AppDimens.spaceLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  InkWell(
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    onTap: () => Navigator.of(context).pop(widget.parent.id),
                    child: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Icon(
                        categoryIconData(widget.parent.iconKey),
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      onTap: () => Navigator.of(context).pop(widget.parent.id),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.parent.name,
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '点击此处直接选择「${widget.parent.name}」',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => Navigator.of(context).pop('__add__'),
                    child: const Text('添加'),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.spaceMd),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  _ViewToggle(
                    listView: _listView,
                    onChanged: (bool value) =>
                        setState(() => _listView = value),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.spaceMd),
              if (widget.children.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                  child: Text(
                    '暂无子分类，可选择上方「${widget.parent.name}」，或点右上角「添加」新建',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.35,
                ),
                child: _listView
                    ? _buildList(theme, color)
                    : _buildGrid(theme, color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(ThemeData theme, Color color) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 5,
      mainAxisSpacing: AppDimens.spaceSm,
      crossAxisSpacing: AppDimens.spaceSm,
      childAspectRatio: 0.88,
      children: <Widget>[
        for (final Category child in widget.children)
          _CategoryItem(
            label: child.name,
            icon: categoryIconData(child.iconKey),
            color: color,
            selected: child.id == widget.selectedId,
            onTap: () => Navigator.of(context).pop(child.id),
          ),
      ],
    );
  }

  Widget _buildList(ThemeData theme, Color color) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: widget.children.length,
      itemBuilder: (BuildContext context, int index) {
        final Category child = widget.children[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(categoryIconData(child.iconKey), color: color),
          ),
          title: Text(child.name),
          trailing: child.id == widget.selectedId
              ? Icon(Icons.check, color: theme.colorScheme.primary)
              : null,
          onTap: () => Navigator.of(context).pop(child.id),
        );
      },
    );
  }
}

/// 优惠功能键弹窗：复刻「森林手账·鼠尾草绿」优惠金额模板（对齐小青账逻辑）。
///
/// 优惠前金额 = 上一页（记一笔）当前输入的金额（摘要卡只读展示，固定两位小数）。
/// 三种金额始终联动：优惠后金额 = 原价 − 实付，优惠金额 = 原价 − 实付。
/// - 分段「输入优惠金额」：优惠前锁定为上一页金额，直接录入优惠
///   （点「优惠前算法」可切到录入优惠后/实付）。
/// - 分段「输入原价和实付」：原价预填上一页金额、可键盘修改；实付为纯手动
///   输入（进入模式时清空、不联动原价），填实付后反推优惠（实付超原价自动钳回）。
/// 键盘复用项目内 [_RecordKeypad]（4×4：数字 + 删除/−/+ + 再记/0/•/保存）。
/// 确认后回传的仍是「优惠金额」字符串（与旧 [_PromptSheet] 行为一致，最小化数据改动）。
class DiscountSheet extends StatefulWidget {
  const DiscountSheet({this.initial, this.base});

  /// 已填写的优惠金额（元字符串），用于回显。
  final String? initial;

  /// 优惠前金额（元字符串）= 上一页（记一笔）当前输入的金额，
  /// 弹窗内只读展示，不可用键盘修改。
  final String? base;

  @override
  State<DiscountSheet> createState() => _DiscountSheetState();
}

class _DiscountSheetState extends State<DiscountSheet> {
  /// 优惠前金额(原价)
  String _base = '';

  /// 优惠金额
  String _amt = '';

  /// 优惠后金额(实付)
  String _paid = '';

  /// 分段模式：discount（仅优惠）/ original（原价+实付）
  String _mode = 'discount';

  /// 优惠模式下键盘写入目标：discount=优惠，paid=优惠后(实付)
  String _algo = 'discount';

  /// 原价+实付模式下键盘焦点：base(原价) / paid(实付)，进模式默认选原价
  String _focus = 'base';

  /// 最近一次录入的字段，用于重算时反推另一项
  String _lastEdited = 'amt';

  /// 记忆设置：上次使用的分段模式 / 算法（SharedPreferences 持久化）
  static const String _prefModeKey = 'discount_sheet_mode';
  static const String _prefAlgoKey = 'discount_sheet_algo';

  @override
  void initState() {
    super.initState();
    // 记忆设置：还原上次使用的分段模式与算法（无记录/非法值回落默认）
    final String savedMode = appPrefs.getString(_prefModeKey) ?? '';
    if (savedMode == 'discount' || savedMode == 'original') {
      _mode = savedMode;
    }
    if (_mode == 'discount') {
      final String savedAlgo = appPrefs.getString(_prefAlgoKey) ?? '';
      if (savedAlgo == 'discount' || savedAlgo == 'paid') {
        _algo = savedAlgo;
      }
    }
    // 优惠前金额预填上一页输入的金额（如 ¥100 → "100.00"，对齐小青账）。
    _base = _fmt2(_toDouble(widget.base?.trim() ?? ''));
    _amt = widget.initial?.trim() ?? '';
    if ((_mode == 'discount' && _algo == 'paid') || _mode == 'original') {
      // 优惠后算法 / 原价+实付模式：打开弹窗不自动填充、不反算
      //（避免把「实付 0」反推成 ¥100 填进输入栏），等键盘录入才联动
      _paid = '';
      _lastEdited = 'paid';
    } else {
      _recalc();
    }
  }

  double _toDouble(String v) {
    if (v.isEmpty) return 0;
    return double.tryParse(v) ?? 0;
  }

  String _fmt(double v) {
    final double d = (v * 100).round() / 100;
    return d.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  /// 摘要卡展示用：固定两位小数（如 100 → "100.00"，对齐小青账 ¥100.00）。
  String _fmt2(double v) {
    final double d = (v * 100).round() / 100;
    return d.toStringAsFixed(2);
  }

  String _display(String v) => v.isEmpty ? '0.00' : v;

  /// 当前键盘写入的字段 key：
  /// 模式一优惠前来自上一页不可编辑（写 优惠/优惠后）；模式二原价、实付均可编辑。
  String _focusKey() {
    if (_mode == 'original') return _focus;
    return _algo == 'paid' ? 'paid' : 'amt';
  }

  void _recalc() {
    final double base = _toDouble(_base);
    final double amt = _toDouble(_amt);
    final double paid = _toDouble(_paid);
    if (_lastEdited == 'paid') {
      // 录实付：钳制 ≤ 原价（优惠前为 0 时任何实付都钳为 0），反推优惠
      double p = paid;
      if (p > base) p = base;
      _paid = _fmt(p);
      _amt = _fmt(base - p);
    } else if (_lastEdited == 'base') {
      // 录原价（模式二）：实付为手动输入、不联动；
      // 仅当实付已填时反推优惠（实付超原价时钳回）
      if (_paid.isNotEmpty) {
        double p = _toDouble(_paid);
        if (p > base) {
          p = base;
          _paid = _fmt(p);
        }
        _amt = _fmt(base - p);
      }
    } else {
      // 录优惠：钳制 ≤ 原价（优惠前为 0 时任何优惠都钳为 0），反推优惠后
      double a = amt;
      if (a > base) a = base;
      _amt = _fmt(a);
      _paid = _fmt(base - a);
    }
  }

  void _onKey(String v) {
    final String key = _focusKey();
    if (key == 'base') {
      _base = v;
      _lastEdited = 'base';
    } else if (key == 'paid') {
      _paid = v;
      _lastEdited = 'paid';
    } else {
      _amt = v;
      _lastEdited = 'amt';
    }
    _recalc();
    setState(() {});
  }

  void _confirm() => Navigator.of(context).pop(_amt);

  Future<void> _openAlgo() async {
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: ForestBg.paper,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusLg)),
      ),
      builder: (BuildContext ctx) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: ForestBg.paper,
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppDimens.radiusLg)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 8),
              ListTile(
                title: const Text('优惠前算法'),
                subtitle: const Text('键盘输入为优惠金额，优惠后 = 优惠前 − 优惠'),
                trailing: _algo == 'discount'
                    ? Icon(Icons.check, color: ForestGreen.deep)
                    : null,
                onTap: () => Navigator.of(ctx).pop('discount'),
              ),
              ListTile(
                title: const Text('优惠后算法'),
                subtitle: const Text('键盘输入为优惠后金额，优惠 = 优惠前 − 优惠后'),
                trailing: _algo == 'paid'
                    ? Icon(Icons.check, color: ForestGreen.deep)
                    : null,
                onTap: () => Navigator.of(ctx).pop('paid'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    setState(() {
      if (choice != _algo) {
        _algo = choice;
        // 记忆设置：持久化本次算法选择
        appPrefs.setString(_prefAlgoKey, choice);
        // 切换算法：输入栏自动清空、不做反算（避免把 0 实付反推成 ¥100 填进输入栏）
        _amt = '';
        _paid = '';
        _lastEdited = choice == 'paid' ? 'paid' : 'amt';
      }
    });
  }

  Widget _infoHint(ThemeData theme) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: ForestBg.sunken,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ForestNeutral.hairline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.info_outline,
                size: 16, color: ForestNeutral.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '支出可以使用这个功能哦。如使用招商信用卡，消费20元笔笔返现0.5元，实际扣款19.5 = 消费金额(20) − 优惠金额(0.5)',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: ForestNeutral.textSecondary),
              ),
            ),
          ],
        ),
      );

  /// 分段控件（模板 .seg）：未选 = 沙色底灰绿字；选中 = 浅绿平涂 + 浅绿描边 + 深绿墨字
  Widget _segPill(ThemeData theme, String mode, String label) {
    final bool on = _mode == mode;
    return InkWell(
      onTap: () => setState(() {
        _mode = mode;
        // 记忆设置：持久化本次分段选择
        appPrefs.setString(_prefModeKey, mode);
        if (mode == 'original') {
          // 默认聚焦原价；实付为纯手动输入，进入时不联动原价、保持为空
          _focus = 'base';
          _paid = '';
        }
      }),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: on ? ForestGreen.soft : ForestBg.sunken,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: on ? ForestGreen.softBorder : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: on ? ForestSage.ink : ForestNeutral.textSecondary,
          ),
        ),
      ),
    );
  }

  /// 输入胶囊（模板 .pill）：单行全圆角，未选 = 奶油卡 + 暖发丝线；
  /// 选中 = 鼠尾草绿渐变选中卡 + 深绿圆白✓ + 深绿墨字；可选右侧算法入口。
  Widget _focusPill(
    ThemeData theme, {
    required String label,
    required String value,
    required bool selected,
    required VoidCallback onTap,
    String? algoLabel,
    VoidCallback? onAlgoTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        margin: const EdgeInsets.only(top: 5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? ForestGradients.sageMid : null,
          color: selected ? null : ForestSurface.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? const Color(0x402E5B39) // rgba(46,91,57,.25)
                : ForestNeutral.hairline,
            width: 1.5,
          ),
          boxShadow: selected
              ? <BoxShadow>[
                  const BoxShadow(
                    color: Color(0x333C8A60), // rgba(60,138,96,.20)
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: selected ? ForestGreen.deep : ForestSurface.cardAlt,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: selected
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : const Text(
                        '¥',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: ForestNeutral.textSecondary,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$label ¥${_display(value)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? ForestSage.ink : ForestNeutral.textTertiary,
              ),
            ),
            if (algoLabel != null) ...<Widget>[
              const Spacer(),
              InkWell(
                onTap: onAlgoTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  child: Text(
                    algoLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ForestSage.label,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String focused = _focusKey();
    final String keypadValue =
        focused == 'base' ? _base : focused == 'paid' ? _paid : _amt;
    // 模式一 · 优惠后算法：键盘录「优惠后」，胶囊/小卡随之切换（小卡显示计算出的优惠）
    final bool typingPaid = _mode == 'discount' && _algo == 'paid';
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 拖动条（模板 .grab）
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0x332E5B39), // rgba(46,91,57,.20)
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          // 头部：✕（左 · 圆形沙底）+ 分段控件，无标题行（模板 .hd）
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Row(
              children: <Widget>[
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: ForestSurface.cardAlt,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        '✕',
                        style: TextStyle(
                          fontSize: 14,
                          color: ForestNeutral.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Flexible(child: _segPill(theme, 'discount', '输入优惠金额')),
                      const SizedBox(width: 6),
                      Flexible(child: _segPill(theme, 'original', '输入原价和实付')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 信息提示卡（沙色 · 模板 .hint）
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _infoHint(theme),
          ),
          // 摘要：奶油卡 + 深绿墨字（模板 .sum）；优惠后小卡浅绿底，聚焦时描边环
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: ForestSurface.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ForestNeutral.hairline),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x142C3329), // rgba(44,51,41,.08)
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          '优惠前金额',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .3,
                            color: ForestNeutral.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          // 优惠前金额 = 上一页金额，固定两位小数（¥100.00）
                          '¥${_fmt2(_toDouble(_base))}',
                          style: const TextStyle(
                            fontSize: 28,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            color: ForestSage.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: ForestGreen.soft,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: focused == 'paid'
                          ? const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x593C8A60), // rgba(46,138,96,.35)
                                blurRadius: 0,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          // 优惠后算法（键盘录优惠后）时，小卡切换为显示计算出的「优惠」
                          typingPaid ? '优惠' : '优惠后金额',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: ForestSage.label,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          // 常规：优惠后 = 优惠前 − 优惠；优惠后算法：优惠 = 优惠前 − 优惠后
                          '¥${_fmt2(_toDouble(typingPaid ? _amt : _paid))}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: ForestGreen.deep,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 输入胶囊（模板 .pill）：模式一单条（含算法入口）；
          // 模式二原价(预填上一页金额，可改)/实付 两行堆叠（标签在上方，小青账样式）
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _mode == 'discount'
                ? _focusPill(
                    theme,
                    // 优惠后算法时胶囊切换为正在录入的「优惠后」，右侧入口显示当前算法
                    label: typingPaid ? '优惠后' : '优惠',
                    value: typingPaid ? _paid : _amt,
                    selected: true,
                    onTap: () {},
                    // 右侧入口跟随当前算法显示「优惠前 / 优惠后」（不带「算法」字样）
                    algoLabel:
                        typingPaid ? 'Ⓢ 优惠后' : 'Ⓢ 优惠前',
                    onAlgoTap: _openAlgo,
                  )
                : Column(
                    children: <Widget>[
                      _focusPill(
                        theme,
                        label: '原价',
                        value: _base,
                        selected: _focus == 'base',
                        onTap: () => setState(() => _focus = 'base'),
                      ),
                      _focusPill(
                        theme,
                        label: '实付价格',
                        value: _paid,
                        selected: _focus == 'paid',
                        onTap: () => setState(() => _focus = 'paid'),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          // 键盘托盘（模板 .kb：沙色底 + 4×4 键盘；保存键即确认，无独立确定按钮）
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ForestBg.sunken,
              borderRadius: BorderRadius.circular(16),
            ),
            child: _RecordKeypad(
              value: keypadValue,
              onChanged: _onKey,
              onSave: _confirm,
              onSaveAndMore: null,
              onOperator: null,
              onBackspace: null,
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

/// 通用底部弹出输入框：用于「优惠金额」「添加标签」等需要单行文本录入的功能键。
class _PromptSheet extends StatefulWidget {
  const _PromptSheet({
    required this.title,
    this.hint,
    this.initial,
    this.keyboardType,
  });

  final String title;
  final String? hint;
  final String? initial;
  final TextInputType? keyboardType;

  @override
  State<_PromptSheet> createState() => _PromptSheetState();
}

class _PromptSheetState extends State<_PromptSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceLg,
              AppDimens.spaceLg,
              AppDimens.spaceMd,
              AppDimens.spaceSm,
            ),
            child: Row(
              children: <Widget>[
                Text(widget.title, style: theme.textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppDimens.spaceLg),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(hintText: widget.hint),
              keyboardType: widget.keyboardType,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (String v) => Navigator.of(context).pop(v.trim()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceLg,
              0,
              AppDimens.spaceLg,
              AppDimens.spaceLg,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(_controller.text.trim()),
                child: const Text('确定'),
              ),
            ),
          ),
        ],
      ),
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
                  color:
                      active ? theme.colorScheme.primary : theme.disabledColor,
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

/// 图片功能键底部弹窗（暖纸皮肤，对齐 bill-photo-sheet-forest.html FINAL）。
/// 半屏贴底（屏幕 50% 高）；✕ 关闭 + 居中标题「账单图片」+ 满高虚线描述卡 +
/// 「最多选择9张图片」提示 + 照片/拍照互斥切换选中。默认选中「照片」。
///
/// [attachments] 非空时，虚线卡内改为展示已选图片缩略图（右上角 ✕ 删除，
/// 删除同步回调 [onRemove] 通知宿主页）；为空时显示原描述文案。
class ImageSourceSheet extends StatefulWidget {
  const ImageSourceSheet({
    super.key,
    this.attachments = const <String>[],
    this.onRemove,
    this.onReorder,
  });

  /// 当前已选图片（本地持久化路径），宿主页传入用于回显。
  final List<String> attachments;

  /// 在弹窗内删除某张图片时回调宿主页同步删除。
  final ValueChanged<String>? onRemove;

  /// 在弹窗内拖拽排序后回调宿主页同步顺序（from/to 为重排前下标）。
  final void Function(int from, int to)? onReorder;

  @override
  State<ImageSourceSheet> createState() => _ImageSourceSheetState();
}

class _ImageSourceSheetState extends State<ImageSourceSheet> {
  bool _isPhoto = true;

  /// 弹窗内的本地副本：删除即时生效（宿主页通过 [ImageSourceSheet.onRemove]
  /// 同步），重新打开时由宿主页重新传入最新列表。
  late final List<String> _paths = List<String>.of(widget.attachments);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: ForestBg.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        children: <Widget>[
          // 头部：左 ✕（沙底圆）+ 居中标题
          SizedBox(
            height: 34,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: ForestBg.sunken,
                        shape: BoxShape.circle,
                        border: Border.all(color: ForestNeutral.hairline),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Color(0xFF6A7263),
                      ),
                    ),
                  ),
                ),
                const Text(
                  '账单图片',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2C3329),
                    letterSpacing: 0.02,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // 满高虚线卡（奶油卡底 + 沙色虚线描边）：固定尺寸（高度由弹窗布局锁定，
          // 不随图片数量变化）；已选图片时内部为固定 3 列网格。
          Expanded(
            child: _DashedRoundedCard(
              child: _paths.isEmpty
                  ? const Center(
                      child: Text(
                        '可将小票、消费账单拍照上传，或者配一些精美的照片丰富记账~',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.8,
                          color: Color(0xFF6A7263),
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (BuildContext ctx, BoxConstraints c) {
                        const double gap = 10;
                        // 固定 3 列：格子边长 = (可用宽 - 2 个间距) / 3，
                        // 高度受限时按可用高度收格子，保证 3 行完整放下。
                        // 网格留出 top/right 6px 内边距，容纳 ✕ 徽标越出格子。
                        final double w = (c.maxWidth - 6 - 2 * gap) / 3;
                        final double h = (c.maxHeight - 6 - 2 * gap) / 3;
                        final double cell = w < h ? w : h;
                        return GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          padding: const EdgeInsets.only(top: 6, right: 6),
                          mainAxisSpacing: gap,
                          crossAxisSpacing: gap,
                          childAspectRatio: 1,
                          children: <Widget>[
                            for (int i = 0; i < _paths.length; i++)
                              _gridCell(i, cell),
                          ],
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _paths.isEmpty ? '最多选择9张图片' : '已选 ${_paths.length}/9 张图片',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF9AA091)),
          ),
          const SizedBox(height: 8),
          // 照片（默认选中）
          _imageModeButton(
            label: '照片',
            selected: _isPhoto,
            onTap: () {
              setState(() => _isPhoto = true);
              Navigator.of(context).pop(ImageSource.gallery);
            },
          ),
          const SizedBox(height: 4),
          // 拍照
          _imageModeButton(
            label: '拍照',
            selected: !_isPhoto,
            onTap: () {
              setState(() => _isPhoto = false);
              Navigator.of(context).pop(ImageSource.camera);
            },
          ),
        ],
      ),
    );
  }

  /// 网格格子：长按拖拽排序（自绘，不依赖第三方包）。
  /// 优化点：拖起有触感反馈、浮图轻微放大并跟随手指；原位显示空槽；
  /// 悬停落点格放大+深绿描边+淡绿底，落定有轻微触感反馈。删除 ✕ 不受影响。
  Widget _gridCell(int index, double cell) {
    final String path = _paths[index];
    return LongPressDraggable<String>(
      data: path,
      maxSimultaneousDrags: 1,
      dragAnchorStrategy: childDragAnchorStrategy, // 浮图贴住原图位置，跟手更自然
      onDragStarted: () => HapticFeedback.mediumImpact(),
      feedback: Transform.scale(
        scale: 1.06,
        child: Container(
          width: cell,
          height: cell,
          transform: Matrix4.translationValues(0, -8, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x552E5B39),
                blurRadius: 16,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(File(path), fit: BoxFit.cover),
          ),
        ),
      ),
      // 原位变空槽（沙底描边），直观表达「已被拿起」
      childWhenDragging: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: ForestBg.sunken,
          border: Border.all(color: ForestNeutral.hairline, width: 1.5),
        ),
      ),
      child: DragTarget<String>(
        onWillAccept: (String? data) => data != null && data != path,
        onAccept: (String dragged) {
          final int from = _paths.indexOf(dragged);
          final int to = _paths.indexOf(path);
          if (from < 0 || to < 0 || from == to) return;
          setState(() => _paths.insert(to, _paths.removeAt(from)));
          HapticFeedback.selectionClick();
          widget.onReorder?.call(from, to);
        },
        builder: (
          BuildContext ctx,
          List<String?> candidate,
          List<dynamic> rejected,
        ) {
          // 悬停落点：放大 + 深绿描边 + 淡绿底，提示将插入此处
          final bool hovered = candidate.isNotEmpty;
          return AnimatedScale(
            scale: hovered ? 1.04 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: hovered
                    ? Border.all(color: ForestGreen.deep, width: 2.5)
                    : null,
                color: hovered ? const Color(0x1A3C8A60) : null,
              ),
              child: _thumb(path),
            ),
          );
        },
      ),
    );
  }

  /// 弹窗内缩略图：填满整个网格格子（GridView 传入的格子约束为紧约束），
  /// 圆角方图 + 右上角深绿 ✕ 删除徽标（与关闭钮同源，可越出格子 6px）。
  Widget _thumb(String path) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, Object e, StackTrace? st) => Container(
                color: ForestBg.sunken,
                child: const Icon(
                  Icons.broken_image_outlined,
                  size: 22,
                  color: Color(0xFF9AA091),
                ),
              ),
            ),
          ),
        ),
          Positioned(
            right: -6,
            top: -6,
            child: GestureDetector(
              onTap: () {
                setState(() => _paths.remove(path));
                widget.onRemove?.call(path);
              },
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: ForestGreen.deep,
                  shape: BoxShape.circle,
                  border: Border.all(color: ForestBg.paper, width: 1.5),
                ),
                child: const Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  /// 照片/拍照切换按钮：选中 = 鼠尾草绿渐变胶囊（深绿墨字加粗 + 投影），
  /// 未选 = 中深绿文字钮（与模板 .on 态同源）。
  Widget _imageModeButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: selected ? 13 : 11),
          decoration: BoxDecoration(
            gradient: selected ? ForestGradients.sageMid : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x333C8A60),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: selected ? 15.5 : 14.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? ForestSage.ink : ForestSage.label,
                letterSpacing: selected ? 0.06 : 0.04,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 虚线圆角卡片（Flutter 原生 BorderStyle 无 dashed，用 CustomPaint 实现）。
class _DashedRoundedCard extends StatelessWidget {
  const _DashedRoundedCard({
    required this.child,
    this.radius = 14,
    this.color = const Color(0xFFD8CBB2),
    this.strokeWidth = 1.6,
  });

  final Widget child;
  final double radius;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRoundedRectPainter(
        radius: radius,
        color: color,
        strokeWidth: strokeWidth,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  const _DashedRoundedRectPainter({
    required this.radius,
    required this.color,
    required this.strokeWidth,
  });

  final double radius;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final Path path = Path()..addRRect(rrect);
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    const double dash = 6;
    const double gap = 4;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double len =
            dash < (metric.length - distance) ? dash : metric.length - distance;
        canvas.drawPath(metric.extractPath(distance, distance + len), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
