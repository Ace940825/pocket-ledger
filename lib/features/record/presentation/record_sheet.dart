import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PathMetric;

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
import '../../../theme/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../features/accounts/data/account_icon.dart';
import '../../../features/accounts/data/bank_data.dart';
import '../../../features/accounts/providers/accounts_providers.dart';
import '../../../features/categories/providers/categories_providers.dart';
import '../../../features/installment/presentation/add_installment_page.dart';
import '../../../features/ledger/data/transaction_repository.dart';
import '../../../features/ledger/providers/ledger_providers.dart';
import '../../../features/lend/providers/lend_providers.dart';
import '../../../features/reimbursement/data/reimbursement_repository.dart';
import '../../../features/reimbursement/presentation/reimbursement_bill_picker_page.dart';
import '../../../features/reimbursement/providers/reimbursement_providers.dart';
import '../../../features/savings/presentation/savings_page.dart'
    show SavingsGoalTile;
import '../../../features/savings/providers/savings_providers.dart';
import '../../../features/settings/providers/sync_settings_providers.dart';
import '../../../providers/app_providers.dart';
import '../../../core/utils/date_utils.dart';
import '../../../routing/app_router.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/attachment_viewer.dart';
import '../../../shared/widgets/calculator_sheet.dart';
import '../../../shared/widgets/category_icons.dart';
import '../../../shared/widgets/line_icons.dart';
import '../../../shared/widgets/date_field.dart';
import '../../../shared/widgets/calendar_sheet.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../sync/sync_adapter.dart';
import '../providers/recording_settings_provider.dart';
import '../record_tab.dart';
import '../../../shared/widgets/amount_keypad.dart';
import 'account_picker_sheet.dart';
import 'bill_selection_page.dart';
import '../../../core/theme/forest_design_tokens.dart';
import '../../tags/presentation/tag_sheet.dart';
import 'recording_settings_sheet.dart';
import 'record_template_sheet.dart';
import '../../../shared/widgets/app_toast.dart';

/// 退款模式：全额退回 / AA 付款分摊。
enum RefundMode { full, aa }

/// 退款 AA 付款的人均取整方式（向下取整 / 四舍五入 / 向上取整）。
enum _AaRounding { down, half, up }

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
          dir == LendDirection.borrowIn ? '债务削减' : '坏账计提',
      };

  IconData icon(LendDirection dir) => switch (this) {
        _LendActionType.borrow =>
          dir == LendDirection.borrowIn ? Icons.south_west : Icons.north_east,
        _LendActionType.repay => Icons.check_circle_outline,
        _LendActionType.debtReduction => Icons.content_cut_outlined,
      };
}

/// ForestSage · 借还中心区域「纸感·细线」方案配色（严格对齐设计稿
/// [loan_center_forestsage_V1.html] 的 CSS 变量，便于零偏差落地）。
///
/// 仅作用于借还页中间区这一处视觉；其余页面仍走 [AppPalette] / 森林 token。
class _Sage {
  // 统一委托 forest_design_tokens.dart 官方令牌——此前这里是一套取值
  // 略有偏差的私有色（如 greenDeep #3E7A4C vs 官方 #2E6B49），导致报销区
  // 与借还区等已落地 ForestSage 区域色调不一致。改为别名后全页同源。
  static const Color paper = ForestBg.paper; // #FBF6EA 主纸底
  static const Color card = ForestSurface.card; // #FFFCF5 奶油卡面
  static const Color cardAlt = ForestSurface.cardAlt; // #F6EFE0 次级卡面

  // 鼠尾草绿渐变停靠色（--sage-a/--sage-b，与 ForestGradients.sage 同值）
  static const Color sageA = AppPalette.sageMist;
  static const Color sageB = AppPalette.sageRibbon;

  static const Color greenDeep = ForestGreen.deep; // #2E6B49 深绿强调
  static const Color greenSoft = ForestGreen.soft; // #E6F2E9 浅绿选中底
  static const Color greenSoftBd = ForestGreen.softBorder; // #BFE0C9 浅绿描边

  // 文字三档
  static const Color ink = ForestNeutral.textPrimary; // #2C3329
  static const Color ink2 = ForestNeutral.textSecondary; // #6A7263
  static const Color ink3 = ForestNeutral.textTertiary; // #9AA091

  // 发丝线
  static const Color hairline = ForestNeutral.hairline; // #ECE2D0
  static const Color hairline2 = ForestNeutral.hairline; // 兼容旧引用

  // 选中态渐变（同 ForestGradients.sage）
  static const LinearGradient sage = ForestGradients.sage;

  // 卡片投影：官方 ForestElevation.card（暖墨极浅，替代偏棕的强投影）
  static const List<BoxShadow> shadow = ForestElevation.card;

  // --shadow-pick: 0 4px 16px rgba(95,154,110,.18),0 0 0 1px rgba(95,154,110,.25)
  static List<BoxShadow> pickShadow = <BoxShadow>[
    BoxShadow(color: AppPalette.sage600.withValues(alpha: 0.18), blurRadius: 16, offset: Offset(0, 4)),
    BoxShadow(
      color: AppPalette.sage600.withValues(alpha: 0.251),
      blurRadius: 0,
      spreadRadius: 1,
      offset: Offset.zero,
    ),
  ];
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
/// 记一笔页启动参数容器：同时携带初始 Tab 与可选的借还编辑 ID，
/// 经 [Routes.record] 的 extra 透传给 [RecordSheet]。
class RecordSheetLaunchArgs {
  const RecordSheetLaunchArgs(
    this.initialTab,
    this.editLendId, {
    this.refundSourceId,
  });
  final RecordTab initialTab;
  final String? editLendId;

  /// 退款 Tab 预关联的原账单 ID（账单详情卡「退款」键入口）：
  /// 非空时进入退款 Tab 并自动关联该账单，退款金额与账户留空待填。
  final String? refundSourceId;
}

Future<void> openRecordSheet(
  BuildContext context, {
  RecordTab initialTab = RecordTab.expense,
  String? editLendId,
  String? refundSourceId,
}) async {
  await context.push<void>(
    Routes.record,
    extra: RecordSheetLaunchArgs(
      initialTab,
      editLendId,
      refundSourceId: refundSourceId,
    ),
  );
}

class RecordSheet extends ConsumerStatefulWidget {
  const RecordSheet({
    super.key,
    this.initialTab = RecordTab.expense,
    this.templateMode = false,
    this.initialTemplate,
    this.editTxnId,
    this.editLendId,
    this.refundSourceId,
  });

  final RecordTab initialTab;

  /// 模板页「编辑」入口：带入模板内容预填表单（含初始 Tab / 金额 / 账户等）。
  final RecordTemplate? initialTemplate;

  /// 编辑模式：待编辑流水的 ID（`/ledger/edit/:id` 入口）。
  ///
  /// 非空时 Tab 收窄为 支出 / 收入 / 转账 / 借还 / 退款 / 报销 六个可编辑类型，
  /// 加载原流水回填表单，保存走对应仓储的更新方法。
  final String? editTxnId;

  /// 编辑模式：待编辑借还记录的 ID（借还页入口）。
  ///
  /// 非空时进入借还 Tab，加载 [LendRecord] 回填借还表单，
  /// 保存走 [LendRepository.update]。
  final String? editLendId;

  /// 退款 Tab 预关联的原账单 ID（账单详情卡「退款」键入口）：
  /// 非空且非编辑模式时进入退款 Tab 并自动关联该账单，
  /// 退款金额与账户留空待用户填写。
  final String? refundSourceId;

  /// 模板模式（账单模板页「添加」入口）：
  /// - Tab 收窄为 支出 / 收入 / 转账 / 借还 四个；
  /// - 功能区不显示「模板」键，键盘「再记」置灰；
  /// - 「保存」不写入流水，而是校验后携带 [RecordTemplateDraft] 返回上一页，
  ///   由模板页弹窗命名后入库。
  final bool templateMode;

  @override
  ConsumerState<RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends ConsumerState<RecordSheet>
    with TickerProviderStateMixin {
  RecordTab _tab = RecordTab.expense;
  late TabController _tabController;

  /// 当前模式可用的 Tab 列表：普通记账为全部 8 个，模板模式仅 4 个；
  /// 编辑模式仅 支出 / 收入 / 转账 三个（Transactions 表只存这三类）。
  List<RecordTab> get _tabs => widget.templateMode
      ? const <RecordTab>[
          RecordTab.expense,
          RecordTab.income,
          RecordTab.transfer,
          RecordTab.lend,
        ]
      : widget.editTxnId != null || widget.editLendId != null
          ? const <RecordTab>[
              RecordTab.expense,
              RecordTab.income,
              RecordTab.transfer,
              RecordTab.lend,
              RecordTab.refund,
              RecordTab.reimbursement,
            ]
          : RecordTab.values;

  /// 是否编辑模式（流水 / 借还二选一入口）。
  bool get _isEdit => widget.editTxnId != null || widget.editLendId != null;

  /// 编辑模式：被编辑的原始流水（保存时作为 updateTransaction 的 original）。
  Transaction? _editingTxn;

  /// 编辑模式：被编辑的原始借还记录（保存时作为 lendRepository.update 的入参）。
  LendRecord? _editingLend;
  // 编辑借还记录时保留原到期日（借还 Tab 表单无到期日字段，不能因编辑而清空）。
  int? _dueAt;

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
  DateTime _occurredAt = localNow();

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
  // 报销收入默认「不计入收支」（收回垫付不是真实收入，可手动关）。
  bool _rbExclude = true;
  String? _rbAccountId; // 报销账户
  String? _rbToAccountId; // 收款账户
  final TextEditingController _rbAmountController = TextEditingController();
  // 报销金额只读显示框的焦点节点：录入走工程内数字键盘
  // （_feeKeyboardTarget = 'rbAmount'），焦点由 _activateFeeKeyboard 程序化赋予。
  final FocusNode _rbAmountFocusNode = FocusNode();

  // 报销：从历史账单选择关联的交易（多选）。
  final Set<String> _rbHistIds = <String>{};
  // 报销：勾选「完成报销(结束此报销)」的账单——保存时整笔核销翻「已报销」，
  // 不占用本次报销收入金额（用于公司一次性结清、无需资金抵扣的账单）。
  final Set<String> _rbFinishIds = <String>{};

  // 退款
  RefundMode _refundMode = RefundMode.full;
  bool _refundAmountAuto = true;

  /// 选中的原账单（支持多选合并为一条退款）。
  final List<Transaction> _refundOriginals = <Transaction>[];
  final TextEditingController _refundAmountController = TextEditingController();

  // 退款 AA 付款参数（底部弹窗「AA付款」确认后生效）。
  int _aaHeadcount = 2; // 总AA人数
  bool _aaIncludeSelf = true; // 计算方式：包含自己 / 不包含自己
  int _aaCollectCount = 1; // 本次收款人数
  _AaRounding _aaRounding = _AaRounding.half; // 人均取整方式
  /// 手动改过的「本次收款(约)」金额（分）；null = 按人均 × 收款人数自动计算。
  int? _aaCollectOverrideMinor;

  // 存钱
  bool _saveDeposit = true;
  String? _goalId;

  // 支出 / 收入新布局状态
  bool _keyboardExpanded = true;
  bool _isReimbursable = false;
  // 报销账户：支出页开启「报销」后显示的功能键；仅可选「报销」类型账户。
  // 数据模型暂无对应列（报销全链路待建），当前为页面内本地状态。
  String? _reimbAccountId;
  bool _excludeFromStats = false;
  bool _excludeFromBudget = false;
  final List<String> _tags = <String>[];
  String? _discountAmount;

  // 图片附件：本地持久化后的绝对路径列表（存于 appDocs/attachments）。
  final List<String> _attachmentPaths = <String>[];

  // 转账
  String? _feeAmount;
  final TextEditingController _feeInputController = TextEditingController();
  final TextEditingController _discountInputController =
      TextEditingController();
  // 只读费用输入框的焦点：选中时程序化 requestFocus（readOnly 不弹系统键盘），
  // 让 showCursor 生效显示闪烁光标。IgnorePointer 挡掉的是点击，不影响程序取焦。
  final FocusNode _discountFocusNode = FocusNode();
  final FocusNode _feeFocusNode = FocusNode();

  /// 优惠 / 手续费使用工程内（自定义）数字键盘录入时的当前目标：
  /// null = 键盘录入主金额；'discount' = 转账优惠；'fee' = 转账手续费；
  /// 'lendFee' = 借还利息 / 优惠（具体写入哪个由 [_lendFeeInputType] 决定）。
  String? _feeKeyboardTarget;

  /// 转账纽带「光点续流」动画：光点沿 S 形曲线流动 + 接口节点脉动，循环播放。
  late final AnimationController _flowAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  /// 互换按钮点击后的旋转动画（点击时 forward(from: 0)）。
  late final AnimationController _swapAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  bool _saving = false;

  final TextEditingController _noteController = TextEditingController();
  final FocusNode _noteFocusNode = FocusNode();
  final TextEditingController _counterpartyController = TextEditingController();
  final TextEditingController _rbPayerController =
      TextEditingController(text: '本人');

  @override
  void initState() {
    super.initState();
    // 模板模式可用 Tab 是 RecordTab.values 的子集，初始下标需在子集内换算。
    // 「编辑模板」入口：以模板自带类型为准。
    final RecordTab effectiveInitial = widget.initialTemplate != null
        ? RecordTab.values[widget.initialTemplate!.tabIndex]
        : widget.initialTab;
    final int initialIndex =
        _tabs.indexOf(effectiveInitial).clamp(0, _tabs.length - 1);
    _tab = _tabs[initialIndex];
    _tabController = TabController(
      initialIndex: initialIndex,
      length: _tabs.length,
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);
    _pageController = PageController(initialPage: initialIndex);
    _pageController.addListener(_onPageScrolled);
    _noteFocusNode.addListener(_onNoteFocusChanged);
    // 编辑预填：控制器就绪后写表单字段（纯赋值，无需 setState）。
    if (widget.initialTemplate != null) {
      _applyTemplateFields(widget.initialTemplate!);
    }
    // 编辑模式：异步加载原记录并回填（流水 / 借还二选一）。
    if (widget.editTxnId != null) {
      _loadEditingTxn();
    } else if (widget.editLendId != null) {
      _loadEditingLend();
    } else if (widget.initialTab == RecordTab.refund &&
        widget.refundSourceId != null) {
      // 账单详情卡「退款」键入口：预关联原账单，金额/账户空置待填。
      _loadRefundSource(widget.refundSourceId!);
    }
  }

  /// 退款预关联：加载原账单加入 [_refundOriginals]（源账单卡显示「关联」），
  /// 退款金额与账户留空——由用户填写后保存生成关联退款收入。
  Future<void> _loadRefundSource(String sourceId) async {
    final Transaction? txn =
        await ref.read(transactionsDaoProvider).getById(sourceId);
    if (!mounted) return;
    if (txn == null) {
      _toast('原账单不存在或已被删除');
      return;
    }
    setState(() {
      _refundOriginals
        ..clear()
        ..add(txn);
      _refundAmountAuto = false;
      _refundAmountController.clear();
      _accountId = null;
    });
  }

  /// 编辑模式：加载原流水并回填表单（金额 / 账户 / 分类 / 日期 / 备注 / 附件），
  /// Tab 定位到原类型对应页。加载失败（已删除）直接退出。
  /// 编辑模式：加载原流水并回填表单（金额 / 账户 / 分类 / 日期 / 备注 / 附件），
  /// 按 [TxnType] + [SourceModule] 定位 Tab（退款 / 报销收入也进入对应 Tab），
  /// 加载失败（已删除）直接退出。
  Future<void> _loadEditingTxn() async {
    final Transaction? txn =
        await ref.read(transactionsDaoProvider).getById(widget.editTxnId!);
    if (!mounted) return;
    if (txn == null) {
      _toast('流水不存在或已被删除');
      context.pop();
      return;
    }
    // 借还本金流水（sourceModule=lend 且关联借还记录）：编辑应落到借还
    // 记录编辑（金额 / 账户改动经 lendRepository.update 联动本金流水与
    // 余额），而不是按普通收支编辑造成两边数据脱钩。
    if (txn.sourceModule == SourceModule.lend && txn.relatedId != null) {
      final LendRecord? rec = await ref
          .read(lendRepositoryProvider)
          .getById(txn.relatedId!);
      if (!mounted) return;
      if (rec != null) {
        await _applyLendEdit(rec);
        return;
      }
      // 借还记录已被删：退化为普通收支流水编辑（下方逻辑兜底）。
    }
    final RecordTab tab = switch (txn.type) {
      TxnType.expense => RecordTab.expense,
      TxnType.transfer => RecordTab.transfer,
      TxnType.income => switch (txn.sourceModule) {
        SourceModule.refund => RecordTab.refund,
        SourceModule.reimbursement => RecordTab.reimbursement,
        _ => RecordTab.income,
      },
    };
    // 退款：尽量回填关联原账单（单选 relatedId），金额走自定义输入。
    Transaction? refundOrig;
    if (tab == RecordTab.refund && txn.relatedId != null) {
      refundOrig = await ref
          .read(transactionsDaoProvider)
          .getById(txn.relatedId!);
    }
    final int index = _tabs.indexOf(tab).clamp(0, _tabs.length - 1);
    setState(() {
      _editingTxn = txn;
      _tab = _tabs[index];
      _tabController.index = index;
      _amount = Money.fromMinor(txn.amountMinor).decimal.toStringAsFixed(2);
      _accountId = txn.accountId;
      _toAccountId = txn.toAccountId;
      _categoryId = txn.categoryId;
      _occurredAt = DateTime.fromMillisecondsSinceEpoch(
        txn.occurredAt,
        isUtc: true,
      ).toLocal();
      _noteController.text = txn.note ?? '';
      _attachmentPaths.addAll(
        parseAttachmentUrls(txn.attachmentUrls) ?? const <String>[],
      );
      // 手续费 / 优惠回填：状态串与输入控制器同步（转账 / 支出优惠输入框读取控制器文本）。
      if (txn.feeMinor > 0) {
        _feeAmount = Money.fromMinor(txn.feeMinor).decimal.toStringAsFixed(2);
        _feeInputController.text = _feeAmount!;
      }
      if (txn.discountMinor > 0) {
        _discountAmount =
            Money.fromMinor(txn.discountMinor).decimal.toStringAsFixed(2);
        _discountInputController.text = _discountAmount!;
      }
      if (tab == RecordTab.refund) {
        _refundOriginals
          ..clear()
          ..addAll(refundOrig == null
              ? const <Transaction>[]
              : <Transaction>[refundOrig]);
        _refundAmountAuto = false;
        _refundAmountController.text = _amount;
      } else if (tab == RecordTab.reimbursement) {
        _rbToAccountId = txn.accountId;
        _rbAmountController.text = _amount;
      }
    });
    _pageController.jumpToPage(index);
  }

  /// 编辑模式（借还）：加载原借还记录并回填借还表单，Tab 定位到借还页。
  ///
  /// 借还编辑只改本金记录的字段（方向 / 对方 / 金额 / 账户 / 利息 / 日期 / 备注），
  /// 不重跑冲销 / 还款业务逻辑；[LendRecord.status] / [LendRecord.repaidMinor]
  /// 保留原值。
  Future<void> _loadEditingLend() async {
    final LendRecord? rec =
        await ref.read(lendRepositoryProvider).getById(widget.editLendId!);
    if (!mounted) return;
    if (rec == null) {
      _toast('借还记录不存在或已被删除');
      context.pop();
      return;
    }
    await _applyLendEdit(rec);
  }

  /// 把借还记录回填进借还 Tab（编辑模式核心）。
  /// 两个入口共用：借还页 [RecordSheet.editLendId] 直达、
  /// 流水列表点编辑借还本金流水转跳（见 [_loadEditingTxn]）。
  Future<void> _applyLendEdit(LendRecord rec) async {
    final int index = _tabs.indexOf(RecordTab.lend).clamp(0, _tabs.length - 1);
    setState(() {
      _editingLend = rec;
      _tab = _tabs[index];
      _tabController.index = index;
      _lendDir = rec.direction;
      _lendAction = _LendActionType.borrow; // 编辑界面显示借入 / 借出
      _dueAt = rec.dueAt;
      _counterpartyController.text = rec.counterparty;
      _amount = Money.fromMinor(rec.amountMinor).decimal.toStringAsFixed(2);
      _accountId = rec.accountId;
      _toAccountId = rec.toAccountId;
      _occurredAt = DateTime.fromMillisecondsSinceEpoch(
        rec.occurredAt,
        isUtc: true,
      ).toLocal();
      _noteController.text = rec.note ?? '';
      // 利息 / 优惠共用一个输入框（_lendFeeInputType 决定语义）。
      if (rec.feeMinor > 0) {
        _lendFeeAmount =
            Money.fromMinor(rec.feeMinor).decimal.toStringAsFixed(2);
        _lendFeeInputType = _FeeInputType.fee;
        _lendFeeController.text = _lendFeeAmount!;
      }
      if (rec.discountMinor > 0) {
        _lendDiscountAmount =
            Money.fromMinor(rec.discountMinor).decimal.toStringAsFixed(2);
        _lendFeeInputType = _FeeInputType.discount;
        _lendFeeController.text = _lendDiscountAmount!;
      }
    });
    _pageController.jumpToPage(index);
  }

  /// [TabController] 的 index 变化（点击 Tab 或页面拖拽越过中点）时更新表单逻辑状态。
  /// 这里只做轻量状态更新并 [setState]：重活（8 套表单）已被 [PageView.builder]
  /// + [AutomaticKeepAlive] 缓存，单次重建开销很小，无需延迟到动画结束。
  void _onTabChanged() {
    final int index = _tabController.index;
    if (index == _tab.index) return;
    _tab = _tabs[index];
    _categoryId = null;
    // 编辑模式：附件属于被编辑的流水本身，切 Tab（改类型）不能清掉原附件。
    if (!_isEdit) {
      _attachmentPaths.clear();
    }
    _clearFeeKeyboardTarget();
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
    _onSystemFieldFocusChanged();
  }

  /// 任一系统输入框（备注 / 借还利息）焦点变化时统一裁决
  /// 自定义数字键盘的展开 / 收起。
  ///
  /// 优惠 / 手续费 / 借还利息均为工程内键盘录入（readOnly，不取系统焦点），
  /// 不参与本裁决；系统键盘字段仅剩备注输入框。
  void _onSystemFieldFocusChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bool anyFocused = _noteFocusNode.hasFocus;
      if (anyFocused) {
        // 系统键盘输入中：收起自定义数字键盘，避免双键盘同屏。
        if (_keyboardExpanded) {
          setState(() => _keyboardExpanded = false);
        }
      } else {
        // 全部系统输入结束：恢复金额数字键盘。
        FocusManager.instance.primaryFocus?.unfocus();
        if (!_keyboardExpanded) {
          setState(() => _keyboardExpanded = true);
        }
      }
    });
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScrolled);
    _pageController.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _noteFocusNode.removeListener(_onNoteFocusChanged);
    _noteFocusNode.dispose();
    _feeInputController.dispose();
    _discountInputController.dispose();
    _discountFocusNode.dispose();
    _feeFocusNode.dispose();
    _lendFeeFocusNode.dispose();
    _lendFeeController.dispose();
    _noteController.dispose();
    _counterpartyController.dispose();
    _rbPayerController.dispose();
    _rbAmountController.dispose();
    _rbAmountFocusNode.dispose();
    _refundAmountController.dispose();
    _flowAnim.dispose();
    _swapAnim.dispose();
    super.dispose();
  }

  int get _amountMinor {
    if (_tab == RecordTab.refund) return _refundAmountMinor;
    return Money.tryParse(_effectiveAmount).minor;
  }

  /// 退款页实际退款金额（分）。
  ///
  /// - 全额退款 + 自动：以选中账单金额之和作为退款金额（多选时合并为一条）。
  /// - AA 付款 + 自动：按弹窗参数计算——人均 = 原账单总额 ÷ 总AA人数
  ///   （按 [_aaRounding] 取整），本次收款 = 人均 × 本次收款人数；
  ///   在弹窗里手动改过金额则用改后的值。
  /// - 自定义：读取输入框。
  int get _refundAmountMinor {
    if (_refundOriginals.isNotEmpty && _refundAmountAuto) {
      final int total = _refundOriginals.fold<int>(
        0,
        (int sum, Transaction t) => sum + t.amountMinor,
      );
      if (_refundMode == RefundMode.aa) {
        return _aaCollectMinor(total);
      }
      return total;
    }
    return Money.tryParse(_refundAmountController.text).minor;
  }

  /// AA 人均金额（分）：总金额 ÷ 总AA人数，按 [_aaRounding] 取整。
  int _aaPerHeadMinor(int totalMinor) {
    final int n = _aaHeadcount < 2 ? 2 : _aaHeadcount;
    switch (_aaRounding) {
      case _AaRounding.down:
        return totalMinor ~/ n;
      case _AaRounding.half:
        return (2 * totalMinor + n) ~/ (2 * n);
      case _AaRounding.up:
        return (totalMinor + n - 1) ~/ n;
    }
  }

  /// AA 本次收款金额（分）：人均 × 本次收款人数；弹窗里手动改过则取改后值。
  int _aaCollectMinor(int totalMinor) {
    final int? overrideMinor = _aaCollectOverrideMinor;
    if (overrideMinor != null) return overrideMinor < 0 ? 0 : overrideMinor;
    return _aaPerHeadMinor(totalMinor) * _aaCollectCount;
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
    // 模板模式：保存不写入任何流水，只校验后携带草稿返回模板页。
    if (widget.templateMode) {
      await _saveAsTemplate();
      return;
    }
    // 编辑模式：保存即返回，无「再记」。
    if (_isEdit) {
      andMore = false;
    }
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
          // 账户可不选（「不选择具体账户」）：落库为空串（游离账单，
          // 仅计入收支账单不计入资产，与筛选页账户 Tab 口径一致）。
          if (_isEdit) {
            // 编辑：走 updateTransaction（回滚旧余额 → 写新值 → 应用新余额）。
            // sourceModule / 标签 / 不计收支等标记由仓储按规则保留原值；
            // 手续费 / 优惠已从原流水回填，用户清空即归零。
            await ref.read(transactionRepositoryProvider).updateTransaction(
                  original: _editingTxn!,
                  type: _tab == RecordTab.expense
                      ? TxnType.expense
                      : TxnType.income,
                  amountMinor: minor,
                  // 空串 = 明确清空账户（「不选择具体账户」）；
                  // updateTransaction 里 '' 直接落库，不会被原值兜底覆盖。
                  accountId: _accountId ?? '',
                  categoryId: _categoryId,
                  note: _noteController.text.trim(),
                  occurredAt: occurredAt,
                  discountMinor: _discountMinor,
                  attachmentUrls: List<String>.of(_attachmentPaths),
                );
            savedId = _editingTxn!.id;
            break;
          }
          savedId = await ref.read(transactionRepositoryProvider).add(
                bookId: bookId,
                type: _tab == RecordTab.expense
                    ? TxnType.expense
                    : TxnType.income,
                amountMinor: minor,
                accountId: _accountId ?? '',
                categoryId: _categoryId,
                note: _noteController.text.trim(),
                occurredAt: occurredAt,
                sourceModule: SourceModule.ledger,
                discountMinor: _discountMinor,
                tags: _tags,
                excludeFromStats: _excludeFromStats,
                excludeFromBudget: _excludeFromBudget,
                isReimbursable: _isReimbursable,
                reimbursementAccountId:
                    _isReimbursable ? _reimbAccountId : null,
                attachmentUrls: _attachmentPaths,
              );
          // 勾选「可报销」且指定了报销账户：同步建一条待报销记录，
          // 让报销资产页能跟踪这笔垫付（transactionId 关联本条流水）。
          if (_isReimbursable && _reimbAccountId != null) {
            String? catName;
            if (_categoryId != null) {
              for (final Category c
                  in ref.read(expenseCategoriesProvider).valueOrNull ??
                      const <Category>[]) {
                if (c.id == _categoryId) {
                  catName = c.name;
                  break;
                }
              }
            }
            final String noteFirst =
                _noteController.text.trim().split('\n').first.trim();
            await ref.read(reimbursementRepositoryProvider).add(
                  bookId: bookId,
                  title: noteFirst.isNotEmpty ? noteFirst : (catName ?? '报销'),
                  status: ReimbursementStatus.pending,
                  amountMinor: minor,
                  payer: '本人',
                  occurredAt: occurredAt,
                  accountId: _reimbAccountId,
                  transactionId: savedId,
                );
          }
        case RecordTab.transfer:
          if (_accountId == null || _toAccountId == null) {
            _toast('请选择转出与转入账户');
            return;
          }
          if (_accountId == _toAccountId) {
            _toast('转出与转入账户不能相同');
            return;
          }
          if (_isEdit) {
            // 编辑：手续费 / 优惠已从原流水回填，用户清空即归零。
            await ref.read(transactionRepositoryProvider).updateTransaction(
                  original: _editingTxn!,
                  type: TxnType.transfer,
                  amountMinor: minor,
                  accountId: _accountId,
                  toAccountId: _toAccountId,
                  note: _noteController.text.trim(),
                  occurredAt: occurredAt,
                  feeMinor: _feeMinor,
                  discountMinor: _discountMinor,
                  attachmentUrls: List<String>.of(_attachmentPaths),
                );
            savedId = _editingTxn!.id;
            break;
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
          // 编辑模式：更新原退款流水（保留 sourceModule=refund / relatedId）。
          if (_editingTxn != null) {
            await ref.read(transactionRepositoryProvider).updateTransaction(
              original: _editingTxn!,
              type: TxnType.income,
              amountMinor: minor,
              accountId: _accountId,
              note: _noteController.text.trim(),
              occurredAt: occurredAt,
              attachmentUrls: List<String>.of(_attachmentPaths),
            );
            savedId = _editingTxn!.id;
            break;
          }
          if (_refundOriginals.isEmpty) {
            _toast('请选择需要退款的账单');
            return;
          }
          if (minor <= 0) {
            _toast('请输入退款金额');
            return;
          }
          // 退款 = 钱退回账户，按「收入」方向增加账户余额，来源标记为 refund。
          // 账户可空置（详情卡退款入口）：空串 = 游离账单，不动账户余额。
          final String modeText =
              _refundMode == RefundMode.full ? '全额退款' : 'AA 付款';
          String refundNote = _noteController.text.trim();

          final int originalTotalMinor = _refundOriginalTotalMinor;
          final String originalAmounts = _refundOriginals
              .map((Transaction t) => Money.fromMinor(t.amountMinor).format())
              .join(' + ');
          final String aaDetail = _refundMode == RefundMode.aa
              ? '，AA：$_aaHeadcount 人${_aaIncludeSelf ? '（含自己）' : '（不含自己）'}'
                  '·人均 ${Money.fromMinor(_aaPerHeadMinor(originalTotalMinor)).format(showSymbol: false)}'
                  '·本次收款 $_aaCollectCount 人'
              : '';
          final String detail = '[$modeText] 原账单合计：'
              '${Money.fromMinor(originalTotalMinor).format()}'
              '（$originalAmounts）'
              '$aaDetail';
          refundNote = refundNote.isEmpty ? detail : '$refundNote\n$detail';

          // 单选时保留 relatedId 语义；多选时通过 note 记录关联关系。
          final String? relatedId =
              _refundOriginals.length == 1 ? _refundOriginals.first.id : null;

          // 系统分类「退款」：ensureNamed 自动重建（isSystem=1，用户分类
          // 选择器隐藏），退款流水统一归到「退款」类目下。
          final String refundCategoryId = await ref
              .read(categoryRepositoryProvider)
              .ensureNamed(
                bookId: bookId,
                name: '退款',
                type: CategoryType.income,
                iconKey: 'refund',
                colorValue: 0xFF8E8A7E,
                isSystem: true,
              );
          savedId = await ref.read(transactionRepositoryProvider).add(
                bookId: bookId,
                type: TxnType.income,
                amountMinor: minor,
                accountId: _accountId ?? '',
                categoryId: refundCategoryId,
                note: refundNote,
                occurredAt: occurredAt,
                sourceModule: SourceModule.refund,
                relatedId: relatedId,
                attachmentUrls: _attachmentPaths,
              );
        case RecordTab.lend:
          // 编辑模式：直接更新原借还记录（保留 status / repaidMinor 等原值），
          // 不重跑 add / repay / debtReduction 的业务逻辑。
          if (_editingLend != null) {
            await ref.read(lendRepositoryProvider).update(
              id: _editingLend!.id,
              direction: _lendDir,
              status: _editingLend!.status,
              counterparty: _counterpartyController.text.trim(),
              amountMinor: minor,
              repaidMinor: _editingLend!.repaidMinor,
              occurredAt: occurredAt,
              dueAt: _dueAt,
              note: _noteController.text.trim(),
              accountId: _accountId,
              toAccountId: _toAccountId,
              feeMinor: _lendFeeMinor,
              discountMinor: _lendDiscountMinor,
            );
            savedId = _editingLend!.id;
            break;
          }
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
                    // 还债 / 收债不是收支：与借还本金流水同口径排除统计与预算。
                    excludeFromStats: true,
                    excludeFromBudget: true,
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
          // 编辑模式：更新原报销收入流水（保留 sourceModule / 关联台账不动）。
          if (_editingTxn != null) {
            await ref.read(transactionRepositoryProvider).updateTransaction(
              original: _editingTxn!,
              type: TxnType.income,
              amountMinor: minor,
              accountId: _rbToAccountId,
              note: _noteController.text.trim(),
              occurredAt: occurredAt,
              attachmentUrls: List<String>.of(_attachmentPaths),
            );
            savedId = _editingTxn!.id;
            break;
          }
          // 报销账户可不选：账单走「未指定报销账户」路径（补建记录
          // accountId 为空、不动报销账户余额），收入仍落收款账户并
          // 关联原账单。收款账户仍必选。
          if (_rbToAccountId == null) {
            _toast('请选择收款账户');
            return;
          }
          savedId = await _saveReimbursementIncome(
            bookId: bookId,
            minor: minor,
            occurredAt: occurredAt,
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
          _rbPayerController.text = '本人';
          _rbAmountController.clear();
          _rbAccountId = null;
          _rbToAccountId = null;
          _rbExclude = true;
          _rbHistIds.clear();
          _rbFinishIds.clear();
          _refundOriginals.clear();
          _refundAmountController.clear();
          _refundAmountAuto = true;
          _refundMode = RefundMode.full;
          _aaHeadcount = 2;
          _aaIncludeSelf = true;
          _aaCollectCount = 1;
          _aaRounding = _AaRounding.half;
          _aaCollectOverrideMinor = null;
          _feeAmount = null;
          _discountAmount = null;
          _feeInputController.clear();
          _discountInputController.clear();
          _clearFeeKeyboardTarget();
          _tags.clear();
          _isReimbursable = false;
          _reimbAccountId = null;
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

  /// 报销收入落账（报销 Tab 保存）。
  ///
  /// 1. **抵扣所选账单**：按勾选顺序把收入金额分摊到 `_rbHistIds` 对应的
  ///    报销记录上——
  ///    - 覆盖完整笔 → 「待报销」自动转「已报销」（deduct 翻转，receivedAt=now）；
  ///    - 部分覆盖 → 原记录待收金额减少，保持「待报销」；**不再**在「已报销」
  ///      形成等额记录，实收款统一归入报销页的「报销收入」分组；
  ///    - 无报销记录的旧账单 → 补建全额待报销记录再抵扣（全额时同样自动翻转）；
  ///    - 已全额报销的账单不再重复抵扣，金额全部走超额收入。
  /// 2. **资金落账**：实收金额记一笔「报销收入」**收入**（income，非转账）
  ///    进收款账户，计入收支（受「不计收支」开关控制）；
  ///    报销账户侧的垫付挂账按抵扣合计直接核销（不生成转账流水）。
  /// 3. 全部写入走仓储原子事务 + 同步入队，报销页汇总 / 账户余额 /
  ///    账单明细全局同步变动。
  ///
  /// 返回收入流水的 ID（票据照片挂在这一条上）。
  Future<String?> _saveReimbursementIncome({
    required String bookId,
    required int minor,
    required int occurredAt,
  }) async {
    final TransactionRepository txnRepo =
        ref.read(transactionRepositoryProvider);
    final ReimbursementRepository reimbRepo =
        ref.read(reimbursementRepositoryProvider);
    final String userNote = _noteController.text.trim();

    // 1. 资金落账：实收金额记一笔「报销收入」收入进收款账户，
    //    类目固定为「报销收入」（无则自动创建），收支 / 账户明细全局同步。
    String? firstLegId;
    if (minor > 0) {
      final String reimbCategoryId =
          await ref.read(categoryRepositoryProvider).ensureNamed(
                bookId: bookId,
                name: '报销收入',
                type: CategoryType.income,
                iconKey: 'reimburse_income',
                colorValue: 0xFF45936A,
                isSystem: true,
              );
      firstLegId = await txnRepo.add(
        bookId: bookId,
        type: TxnType.income,
        amountMinor: minor,
        accountId: _rbToAccountId!,
        categoryId: reimbCategoryId,
        occurredAt: occurredAt,
        note: userNote.isEmpty ? '报销收入' : userNote,
        sourceModule: SourceModule.reimbursement,
        excludeFromStats: _rbExclude,
        // 报销收入不参与预算（表单无预算开关，恒排除；收支侧由上方开关控制）。
        excludeFromBudget: true,
        attachmentUrls: _attachmentPaths,
      );
    }

    // 2. 按勾选顺序抵扣所选账单，抵扣关联写回收款流水 ID，
    //    供账单明细弹窗反向展示「关联账单」。
    //    勾选「完成报销(结束此报销)」的账单（_rbFinishIds）：整笔核销翻
    //    「已报销」，不占用本次收入金额（视同已一并结清），核销额一并
    //    计入报销账户挂账核销合计，保持「余额 = 待收垫付」不变量。
    int left = minor;
    final List<Transaction> bills = _rbHistIds.isEmpty
        ? const <Transaction>[]
        : await txnRepo.getByIds(_rbHistIds.toList());
    // 第一遍：按勾选顺序做封顶分摊计划。勾选「完成报销(结束此报销)」的
    // 账单（_rbFinishIds）整笔核销翻「已报销」，不占用本次收入金额。
    final List<({Transaction bill, Reimbursement? linked, bool finish, int alloc, int remaining})>
        plan = <({Transaction bill, Reimbursement? linked, bool finish, int alloc, int remaining})>[];
    for (final Transaction t in bills) {
      final bool finish = _rbFinishIds.contains(t.id);
      final Reimbursement? linked = await reimbRepo.byTransaction(t.id);
      if (linked != null &&
          linked.status == ReimbursementStatus.reimbursed) {
        // 已全额报销的账单不再重复抵扣，金额全部留在收入里。
        continue;
      }
      final int remaining = linked?.amountMinor ?? t.amountMinor;
      final int alloc;
      if (finish) {
        alloc = remaining;
      } else {
        if (left <= 0) break;
        alloc = left < remaining ? left : remaining;
        left -= alloc;
      }
      if (alloc <= 0) continue;
      plan.add((
        bill: t,
        linked: linked,
        finish: finish,
        alloc: alloc,
        remaining: remaining,
      ));
    }
    // 报销收入超出所选账单待收总额时，超出部分并入最后一个非「完成报销」
    // 账单的台账（超额报销）：台账记收入实际金额，「已报」随之同步为
    // 实际收到的收入总额，账单详情与流水列表展示「超额报销」标签。
    if (left > 0) {
      for (int i = plan.length - 1; i >= 0; i--) {
        if (!plan[i].finish) {
          plan[i] = (
            bill: plan[i].bill,
            linked: plan[i].linked,
            finish: plan[i].finish,
            alloc: plan[i].alloc + left,
            remaining: plan[i].remaining,
          );
          left = 0;
          break;
        }
      }
    }
    // 第二遍：落地抵扣。台账记收入实际分摊额（可超额），报销账户垫付
    // 核销按封顶额——超额部分是进收款账户的新钱，不动报销账户。
    int writeOffMinor = 0;
    for (final ({Transaction bill, Reimbursement? linked, bool finish, int alloc, int remaining}) p
        in plan) {
      final Reimbursement? linked = p.linked;
      final String billTitle = p.bill.note?.trim().isNotEmpty == true
          ? p.bill.note!.trim()
          : '报销';
      if (linked != null) {
        // 全额 → 自动翻「已报销」；部分 → 待收金额减少，保持「待报销」。
        await reimbRepo.deduct(
          linked.id,
          p.alloc,
          incomeTransactionId: firstLegId,
        );
      } else {
        // 旧数据 / 记支出时未指定报销账户的账单：补建全额待报销记录再抵扣，
        // deduct 内部覆盖完整笔时自动翻「已报销」，明细开关有记录可联动。
        // 这类账单落账时没挂过报销账户余额，先补挂垫付再核销抵扣部分，
        // 保证「报销账户余额 = 待收垫付」。
        final String createdId = await reimbRepo.add(
          bookId: bookId,
          title: billTitle,
          status: ReimbursementStatus.pending,
          amountMinor: p.remaining,
          payer: '本人',
          occurredAt: p.bill.occurredAt,
          accountId: _rbAccountId,
          toAccountId: _rbToAccountId,
          transactionId: p.bill.id,
        );
        if (_rbAccountId != null) {
          await reimbRepo.hangAdvance(_rbAccountId!, p.remaining);
        }
        await reimbRepo.deduct(
          createdId,
          p.alloc,
          incomeTransactionId: firstLegId,
        );
      }
      writeOffMinor += p.alloc < p.remaining ? p.alloc : p.remaining;
    }

    // 3. 核销报销账户的垫付挂账（按封顶额合计；超额部分本来就是进收款
    //    账户的新钱，不动报销账户）。
    if (writeOffMinor > 0 && _rbAccountId != null) {
      await reimbRepo.writeOffReceivable(_rbAccountId!, writeOffMinor);
    }
    return firstLegId;
  }

  void _toast(String message) {
    if (!mounted) return;
    showAppToast(context, message);
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
            setState(() => _occurredAt = v ?? localNow()),
      );

  /// 记一笔日期选择：直接调用全局共用组件 [CalendarSheet]（小青账式滑动交互）。
  /// 不再经旧的 date_picker_sheet 中转（已删除，全工程统一走 CalendarSheet），
  /// 确保功能 / 配色 / 风格 / 交互与共享组件完全一致。
  Future<void> _pickDate() async {
    final CalendarSelection? picked = await CalendarSheet.show(
      context,
      mode: CalendarSheetMode.day,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2107, 12, 31),
      showTime: true,
      showQuickChips: true,
      weekStart: CalendarWeekStart.sunday,
    );
    if (picked == null || !mounted) return;
    // day 模式返回单日（含所选时分）；若用户经粒度 chip 选了周期，
    // 取其起点日并保留记一笔原有的时分。
    final DateTime resolved;
    if (picked is CalendarDay) {
      resolved = picked.date;
    } else if (picked is CalendarPeriod) {
      final DateTime s = picked.start;
      resolved = DateTime(s.year, s.month, s.day, _occurredAt.hour, _occurredAt.minute);
    } else {
      return;
    }
    setState(() => _occurredAt = resolved);
  }

  Widget _noteField() => TextField(
        controller: _noteController,
        decoration: const InputDecoration(labelText: '备注'),
        maxLines: 2,
      );

  /// 存钱计划区主体（中间区域）：直接内嵌「我的计划」列表。
  ///
  /// - 已有计划 → 逐张 [SavingsGoalTile]（存入 / 取出 / 归档 / 删除），
  ///   底部保留「去储蓄页新建计划」跳转卡；
  /// - 还没有计划 → 占位跳转栏（点击跳「储蓄」页选模式创建）。
  Widget _buildSavingsGoalZone() {
    final AsyncValue<List<SavingsGoal>> goals = ref.watch(savingsListProvider);
    final List<SavingsGoal> list = goals.value ?? const <SavingsGoal>[];
    if (list.isEmpty) {
      return _rbCard(
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          context.push(Routes.savings);
        },
        child: Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: ForestGreen.soft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.savings_outlined,
                size: 18,
                color: ForestGreen.deep,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '暂无存钱计划',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _Sage.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '去「储蓄」页选择模式创建',
                    style: TextStyle(fontSize: 11, color: _Sage.ink3),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: _Sage.ink3),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final SavingsGoal g in list) SavingsGoalTile(goal: g),
        const SizedBox(height: AppDimens.spaceSm),
        _rbCard(
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
            context.push(Routes.savings);
          },
          child: Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: ForestGreen.soft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.add_circle_outline,
                  size: 18,
                  color: ForestGreen.deep,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '去「储蓄」页新建计划',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _Sage.ink,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: _Sage.ink3),
            ],
          ),
        ),
      ],
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
      case RecordTab.refund:
      case RecordTab.savings:
      case RecordTab.installment:
        // 报销 / 退款 / 存钱 / 分期均使用独立布局，不走 legacy 表单。
        return const <Widget>[SizedBox.shrink()];
    }
  }

  // ---- 小青账风格：支出 / 收入主体 ----

  /// 小青账统一布局：顶部滚动表单 + 底部固定功能栏/金额栏/日期备注栏/键盘。
  /// 适用于 支出 / 收入 / 转账 / 借还。
  Widget _buildNewLayoutBody() {
    final double viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    // 借还利息/优惠已改工程内键盘（readOnly 不取系统焦点），系统键盘仅备注框会唤起。
    final bool systemKeyboardOpen =
        viewInsetsBottom > 0 && _noteFocusNode.hasFocus;
    return Column(
      children: <Widget>[
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints viewport) {
              // 可视高度（扣除滚动区上下 padding）：借还页用它把「方向/类型/
              // 账户卡」主组撑到正好抵住底部功能键上沿（lend 分支用），
              // 其余 Tab 不受影响（minHeight 只对借还生效）。
              final double viewportHeight =
                  viewport.maxHeight - 2 * AppDimens.spaceLg;
              return SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(AppDimens.spaceLg),
                // 点击表单空白处（按钮/输入框之外的区域）→ 移除焦点：
                // 借还利息/转账费用框退回主金额录入，备注框收起系统键盘。
                // 子级可交互控件（TextField/按钮）的手势在竞技场中优先胜出，不受影响。
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _onNewLayoutTapAway,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _buildNewLayoutScrollArea(minHeight: viewportHeight),
                    ],
                  ),
                ),
              );
            },
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

  /// 点击新布局表单区空白处：移除焦点。
  /// - 费用键盘目标（借还利息 / 转账优惠 / 手续费）→ 清除，键盘回主金额；
  /// - 备注框等系统输入焦点 → 收起系统键盘（由焦点监听恢复数字键盘）。
  void _onNewLayoutTapAway() {
    if (_feeKeyboardTarget != null) {
      setState(_clearFeeKeyboardTarget);
    }
    FocusManager.instance.primaryFocus?.unfocus();
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
        // 过滤口径（展示与选择器共用）：资金类（默认）排除应收 / 应付；
        // allowedTypes 按具体类型过滤，allowedCategories 按大类过滤，
        // 二选一（allowedTypes 优先）。
        List<Account> match(List<Account> src) {
          List<Account> s;
          if (allowedTypes != null) {
            s = src
                .where((Account a) => allowedTypes!.contains(a.type))
                .toList(growable: false);
          } else if (allowedCategories == null) {
            s = fundAccountsOnly(src);
          } else {
            s = src
                .where(
                  (Account a) => allowedCategories!.contains(a.type.category),
                )
                .toList(growable: false);
          }
          if (excludeId != null && s.length > 1) {
            s = s.where((Account a) => a.id != excludeId).toList();
          }
          return s;
        }

        final List<Account> shown = match(list);
        final String? safe =
            shown.any((Account a) => a.id == value) ? value : null;
        final Account? selected =
            safe == null ? null : shown.firstWhere((Account a) => a.id == safe);
        return Row(
          children: <Widget>[
            // 左侧：账户栏卡片。
            Expanded(
              child: InkWell(
                // 空列表也打开选择器（弹窗内「＋添加」兜底），不禁用点击。
                onTap: () => _showTransferAccountPicker(
                          label: label,
                          // 选择器实时 watch 账户流并套用同一过滤口径
                          filter: match,
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
                    color: AppPalette.surfaceLight,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    border: Border.all(color: Theme.of(context).colorScheme.outline),
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
                                        ? AppPalette.textPrimary
                                        : AppPalette.textTertiary,
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
                color: AppPalette.surfaceLight,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                border: Border.all(color: Theme.of(context).colorScheme.outline),
              ),
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppPalette.textPrimary,
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
  /// （添加、资产管理页压在弹窗上，返回后弹窗原位）。默认账户必选、不显示
  /// 「不选择具体账户」行；[allowNone] 为 true 时显示该行，点选后回传 null
  /// （仅借还等数据层允许无账户的场景传入）。
  Future<void> _showTransferAccountPicker({
    required String label,

    /// 可选项过滤口径：弹窗内部实时 watch 账户流并套用该过滤，
    /// 弹窗内新建的账户只要符合口径立即出现在列表里。
    required AccountListFilter filter,
    required String? selectedId,
    required ValueChanged<String?> onChanged,
    String? conflictId,
    bool allowNone = false,
    String? noneSubtitle,
  }) async {
    final String? result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => AccountPickerSheet(
        filter: filter,
        selectedId: selectedId,
        title: '选择$label',
        showNoneRow: allowNone,
        noneSubtitle: noneSubtitle,
        // 同账户不能互转：冲突校验在弹窗内就地提示（不关弹窗）。
        conflictId: conflictId,
        conflictMessage: '转出与转入账户不能相同',
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
    if (result == null || !mounted) return;
    // 「不选择具体账户」以空串回传：清空账户（onChanged 收到 null）。
    onChanged(result.isEmpty ? null : result);
  }

  // ══════════ 转账中间区 · A 方案「纽带流动」 ══════════

  /// 转账中间区（A 方案「光点续流」）：标题行 + 错位双卡 + S 形光带 + 居中互换钮。
  ///
  /// 转出卡靠左、转入卡靠右（各占 87% 宽），两卡之间 10px 缝隙由鼠尾草渐变
  /// S 形纽带连接，白色光点沿曲线流动；居中 48px 渐变圆钮点击互换两账户。
  Widget _buildTransferFlowZone() {
    final AsyncValue<List<Account>> accounts = ref.watch(accountsProvider);
    return accounts.when(
      data: (List<Account> list) {
        final List<Account> shown = fundAccountsOnly(list);
        Account? pick(String? id) => shown
            .cast<Account?>()
            .firstWhere((Account? a) => a?.id == id, orElse: () => null);
        final Account? outAcc = pick(_accountId);
        final Account? inAcc = pick(_toAccountId);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.sync_alt, size: 14, color: ForestGreen.deep),
                const SizedBox(width: 6),
                const Text(
                  '账户互转',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ForestGreen.deep,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildTransferFlowBody(outAcc: outAcc, inAcc: inAcc),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (Object e, StackTrace? s) => Text('账户加载失败：$e'),
    );
  }

  /// 错位双卡 + 纽带光带 + 居中互换按钮的 Stack 布局。
  ///
  /// 几何与设计稿对齐：卡高 74、缝高 10（总高 158）；光带位于 y 66→92 的
  /// 26px 横带内（与 HTML 稿 1:1），互换按钮居中于 y 79。
  Widget _buildTransferFlowBody({
    required Account? outAcc,
    required Account? inAcc,
  }) {
    const double cardH = 74;
    return Stack(
      children: <Widget>[
        Column(
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                // 80% 宽：转出卡右缘左退，内容整体左移（错位更明显）。
                widthFactor: 0.80,
                child: _buildFlowAccountCard(
                  account: outAcc,
                  isOut: true,
                  height: cardH,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                // 80% 宽：转入卡左缘右退，内容整体右移（与转出卡对峙）。
                widthFactor: 0.80,
                child: _buildFlowAccountCard(
                  account: inAcc,
                  isOut: false,
                  height: cardH,
                ),
              ),
            ),
          ],
        ),
        // 纽带光带：覆盖整个错位区，两端精确落在两卡头像中心
        // （头像 48px + 水平内边距 14 → 头像中心距卡缘 38px）。
        // IgnorePointer：CustomPaint 有 painter 时会命中自身吞掉点击，
        // 必须穿透，否则下方账户卡无法点选。
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: cardH * 2 + 10,
          child: IgnorePointer(
            child: _TransferFlowRibbon(progress: _flowAnim),
          ),
        ),
        // 居中互换按钮（曲线中点）。
        Positioned.fill(
          child: Center(child: _buildFlowSwapButton()),
        ),
      ],
    );
  }

  /// 纽带流区里的单张账户卡（黏土风）：黏土头像 + 账户名/余额。
  ///
  /// 转入卡做镜像布局：头像靠右、文字右对齐，与转出卡形成方向对峙。
  Widget _buildFlowAccountCard({
    required Account? account,
    required bool isOut,
    required double height,
  }) {
    final String placeholder = isOut ? '转出账户' : '转入账户';
    final String hint = isOut ? '点击选择付款账户' : '点击选择收款账户';
    final String label = isOut ? '扣款账户' : '入款账户';
    final bool mirrored = !isOut;
    final Money? money = account == null
        ? null
        : Money.fromMinor(account.balanceMinor, currency: account.currency);
    final Widget avatar = _buildFlowAvatar(context,
      icon: accountIcon(account?.type ?? AccountType.cash),
      picked: account != null,
    );
    final Widget textCol = Expanded(
      child: Column(
        // 标题/副标题偏居中：在头像之外的剩余空间里居中展示。
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            account?.name ?? placeholder,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ForestNeutral.textPrimary,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            money?.format() ?? hint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: ForestNeutral.textTertiary,
              letterSpacing: 0.3,
              fontFeatures: const <FontFeature>[
                FontFeature.tabularFigures(),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
    return InkWell(
      // 空列表也打开选择器：弹窗内有「暂无账户，点击右上角添加」兜底。
      onTap: () => _showTransferAccountPicker(
            label: label,
            // 选择器实时 watch 账户流：资金类账户（排除应收 / 应付）
            filter: fundAccountsOnly,
            selectedId: account?.id,
            // 同账户不能互转：把对方当前所选账户作为冲突项传入。
            conflictId: isOut ? _toAccountId : _accountId,
            onChanged: (String? v) => setState(() {
              if (isOut) {
                _accountId = v;
              } else {
                _toAccountId = v;
              }
            }),
          ),
      borderRadius: BorderRadius.circular(ForestRadius.md),
      child: Container(
        height: height,
        // 纵向 11：74 卡高 - 上下描边 2 - 22 内边距 = 50 ≥ 头像 48，
        // 留 2px 余量防止 RenderFlex 底部溢出（原 13 时内容区 46 < 48）。
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: ForestSurface.card,
          borderRadius: BorderRadius.circular(ForestRadius.md),
          border: Border.all(color: ForestNeutral.hairline),
          boxShadow: <BoxShadow>[
            // 转出卡泛珊瑚红微光、转入卡泛绿微光（与设计稿同语言）。
            BoxShadow(
              color: isOut ? AppPalette.expenseDark.withValues(alpha: 0.122) : AppPalette.stockDown.withValues(alpha: 0.122),
              blurRadius: 9,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: mirrored
              ? <Widget>[textCol, const SizedBox(width: 12), avatar]
              : <Widget>[avatar, const SizedBox(width: 12), textCol],
        ),
      ),
    );
  }

  /// 黏土账户头像：未选 = 米白黏土 + 线稿图标；已选 = sage 渐变 + 白图标。
  Widget _buildFlowAvatar(BuildContext context, {required IconData icon, required bool picked}) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: picked
            ? ForestGradients.sage
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[AppPalette.creamBright, AppPalette.sandPale],
              ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: picked ? Colors.transparent : Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: picked ? AppPalette.sage600.withValues(alpha: 0.42) : AppPalette.ink.withValues(alpha: 0.188),
            blurRadius: picked ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          // 黏土釉面高光（左上径向白光）。
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: RadialGradient(
                  center: Alignment(-0.24, -0.4),
                  radius: 1.4,
                  colors: <Color>[
                    Theme.of(context).colorScheme.surface.withValues(alpha: picked ? 0.35 : 0.9),
                    Theme.of(context).colorScheme.surface.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Icon(
              icon,
              size: 22,
              color: picked ? Theme.of(context).colorScheme.onPrimary : ForestNeutral.deepInk,
            ),
          ),
        ],
      ),
    );
  }

  /// 居中互换按钮：48px sage 渐变圆钮 + 卡面描边，点击旋转 180°。
  Widget _buildFlowSwapButton() {
    return GestureDetector(
      onTap: () {
        _swapTransferAccounts();
        _swapAnim.forward(from: 0);
      },
      child: RotationTransition(
        turns: _swapAnim,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: ForestGradients.sage,
            shape: BoxShape.circle,
            border: Border.all(color: ForestSurface.card, width: 3),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppPalette.sage600.withValues(alpha: 0.451),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Icon(Icons.sync_alt, size: 20, color: Theme.of(context).colorScheme.onPrimary),
        ),
      ),
    );
  }

  /// 转账页「优惠 / 手续费」双输入框 + 计算器。
  ///
  /// 三个胶囊框均分整行：优惠 / 手续费（可输入）+ 净额（只读展示）。
  /// 有值时转绿底高亮；三槽等宽，间距 8px。
  Widget _buildTransferFeeRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: _buildTransferFeeBox(
            icon: (Color fg) => _FeeTicketIcon(color: fg),
            label: '优惠',
            controller: _discountInputController,
            focusNode: _discountFocusNode,
            value: _discountAmount,
            active: _feeKeyboardTarget == 'discount',
            onActivate: () => _activateFeeKeyboard('discount'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTransferFeeBox(
            icon: (Color fg) => _FeeYuanIcon(color: fg),
            label: '手续费',
            controller: _feeInputController,
            focusNode: _feeFocusNode,
            value: _feeAmount,
            active: _feeKeyboardTarget == 'fee',
            onActivate: () => _activateFeeKeyboard('fee'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _buildTransferNetBadge()),
      ],
    );
  }

  /// 转账净额显示框：图标 + 「净额」标题 + ¥ + 转出金额 − 优惠 + 手续费。
  ///
  /// 与优惠 / 手续费框同构同高 44，恒为浅绿底（只读计算值，不参与键盘录入），
  /// 无弹窗入口；金额过长时 FittedBox 缩放防溢出。
  Widget _buildTransferNetBadge() {
    final int netMinor = _amountMinor - _discountMinor + _feeMinor;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      // baseline Row 高度只到文字高，需显式居中，否则内容贴顶。
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: ForestGreen.soft,
        border: Border.all(color: ForestGreen.softBorder),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.sync_alt, size: 13, color: ForestGreen.deep),
          const SizedBox(width: 5),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                const Text(
                  '净额',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ForestGreen.deep,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(width: 5),
                Text(
                  '¥',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ForestGreen.deep.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      Money.fromMinor(netMinor).format(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ForestGreen.deep,
                        fontFeatures: <FontFeature>[
                          FontFeature.tabularFigures()
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 单个费用胶囊输入框（优惠 / 手续费）。
  ///
  /// 图标 + 标签 + ¥ + 直填金额；有值时整框转 [ForestGreen.soft] 绿底 + 绿描边，
  /// 图标与文字转深绿，提示「显示框」语义（对标 HTML fee-box）。
  /// 点击优惠 / 手续费输入框：收起系统键盘，工程内数字键盘切到对应字段，
  /// 并让目标只读框持有焦点以显示光标（readOnly 不弹系统键盘）。
  void _activateFeeKeyboard(String target) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _feeKeyboardTarget = target;
      if (!_keyboardExpanded) _keyboardExpanded = true;
    });
    if (target == 'lendFee') {
      _lendFeeFocusNode.requestFocus();
    } else if (target == 'rbAmount') {
      _rbAmountFocusNode.requestFocus();
    } else {
      (target == 'discount' ? _discountFocusNode : _feeFocusNode)
          .requestFocus();
    }
  }

  /// 清除费用键盘目标：光标随焦点一起移除（切 Tab / 回主金额 / 保存重置用）。
  void _clearFeeKeyboardTarget() {
    _discountFocusNode.unfocus();
    _feeFocusNode.unfocus();
    _lendFeeFocusNode.unfocus();
    _rbAmountFocusNode.unfocus();
    _feeKeyboardTarget = null;
  }

  /// 单个费用胶囊输入框（优惠 / 手续费）。
  ///
  /// 图标 + 标签 + ¥ + 金额显示框：只读展示，点击后由工程内（自定义）
  /// 数字键盘录入（见 [_activateFeeKeyboard] / [_buildCollapsibleKeypad]）。
  /// 有值时整框转 [ForestGreen.soft] 绿底 + 绿描边；激活时描边高亮（对标 HTML fee-box）。
  Widget _buildTransferFeeBox({
    required Widget Function(Color fg) icon,
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String? value,
    required bool active,
    required VoidCallback onActivate,
  }) {
    final bool hasVal = value != null && value.isNotEmpty;
    final Color fg = hasVal ? ForestGreen.deep : ForestNeutral.deepInk;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      // baseline Row 高度只到文字高，需显式居中，否则内容贴顶。
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: hasVal ? ForestGreen.soft : ForestSurface.card,
        border: Border.all(
          color: active
              ? ForestGreen.softBorder
              : hasVal
                  ? ForestGreen.softBorder
                  : ForestNeutral.hairline,
          width: active ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onActivate,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // 图标随内层文字块整体垂直居中，不参与基线对齐。
            icon(fg),
            const SizedBox(width: 5),
            Expanded(
              child: Row(
                // 基线对齐：¥ 符号与输入数字字号不同，center 对齐会一高一低，
                // 按 alphabetic 基线对齐才能视觉同行。
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: fg,
                    ),
                  ),
                  SizedBox(width: 5),
                  Text(
                    '¥',
                    style: TextStyle(
                      fontSize: 13,
                      color: fg.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    // IgnorePointer：TextField 的选择手势识别器在手势竞技场中
                    // 层级更深、优先胜出，会把点击吞掉导致外层 GestureDetector
                    // 的 onActivate 不触发（优惠/手续费「点不中」）。
                    // 只读显示框本就不需要指针事件，直接屏蔽让点击穿透。
                    child: IgnorePointer(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        // 只读显示框：录入走工程内数字键盘，不唤起系统键盘；
                        // 焦点由 _activateFeeKeyboard 程序化赋予，光标可闪烁。
                        readOnly: true,
                        showCursor: active,
                        cursorColor: fg,
                        textAlign: TextAlign.left,
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          // 显式覆盖所有状态的边框：胶囊描边由外层 Container 负责，
                          // 避免 AppTheme 默认 inputDecorationTheme 在聚焦时再画一圈。
                          filled: true,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: '0',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppPalette.sage800.withValues(alpha: 0.349),
                          ),
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: fg,
                          fontFeatures: <FontFeature>[
                            FontFeature.tabularFigures()
                          ],
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 转账页说明文案。
  Widget _buildTransferHint() {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppPalette.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.info_outline,
            size: 16,
            color: AppPalette.textTertiary,
          ),
          SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Text(
              '转账、信用卡还款、取现可以用这个功能哦。\n'
              '转出账户 = 转出金额 + 手续费\n'
              '转出账户 = 转出金额 - 优惠',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppPalette.textTertiary,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- 借还页（小青账风格） ----

  /// 借还页顶部「借入 / 借出」分段开关（ForestSage V1 · 纸感细线）。
  Widget _buildLendDirectionToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _Sage.card,
        border: Border.all(color: _Sage.hairline),
        borderRadius: BorderRadius.circular(14),
        boxShadow: _Sage.shadow,
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: selected ? _Sage.sage : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppPalette.sage600.withValues(alpha: 0.349),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Theme.of(context).colorScheme.onPrimary : _Sage.ink2,
            letterSpacing: selected ? 4 : 3,
          ),
        ),
      ),
    );
  }

  /// 借还页动作图标网格：借入/借出、还债/收债、债务削减/坏账计提。
  /// 方向切换时三种动作的标签随 [LendDirection] 自动改写，故始终保持 3 个。
  Widget _buildLendActionGrid() {
    const List<_LendActionType> actions = _LendActionType.values;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          for (final _LendActionType action in actions)
            _buildLendActionItem(action),
        ],
      ),
    );
  }

  Widget _buildLendActionItem(_LendActionType action) {
    final bool selected = _lendAction == action;
    return InkWell(
      onTap: () => setState(() {
        _lendAction = action;
        _repayAccountId = null;
      }),
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedContainer(
              duration: Duration(milliseconds: 220),
              width: 50,
              height: 50,
              transform: selected
                  ? Matrix4.translationValues(0, -2, 0)
                  : Matrix4.identity(),
              decoration: BoxDecoration(
                gradient: selected ? _Sage.sage : null,
                color: selected ? null : _Sage.card,
                border: Border.all(
                  color: selected ? Colors.transparent : _Sage.hairline,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: selected
                    ? <BoxShadow>[
                        BoxShadow(
                          color: AppPalette.sage600.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ]
                    : _Sage.shadow,
              ),
              child: Icon(
                action.icon(_lendDir),
                size: 20,
                color: selected ? Theme.of(context).colorScheme.onPrimary : _Sage.ink2,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              action.label(_lendDir),
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? _Sage.greenDeep : _Sage.ink2,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              width: 34,
              height: 3,
              decoration: BoxDecoration(
                gradient: selected ? _Sage.sage : null,
                color: selected ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 借还页账户选择卡片（借入/借出账户、资产账户、还款/收款账户）。
  /// [allowedCategories] 非空时只展示对应大类的账户；借入/借出账户通常限定为
  /// 应付 / 应收，资产账户则保持全部账户或另行传入资金类。
  /// [hint] 非空时在卡片内底部渲染一行小字说明（ForestSage V1 · 纸感细线）。
  Widget _buildLendAccountCard({
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
    required String placeholder,
    bool autoFillCounterparty = true,
    List<AccountCategory>? allowedCategories,
    List<AccountType>? allowedTypes,
    String? hint,
  }) {
    final AsyncValue<List<Account>> accounts = ref.watch(accountsProvider);
    return accounts.when(
      data: (List<Account> list) {
        // allowedTypes 非空（借入/借出账户）：只展示对应类型（报销同款
        // 「指定账户」口径，借出→lend、借入→borrow）；allowedCategories
        // 非空按分类过滤；其余（资产账户、还款/收款账户）是资金类，
        // 排除应收应付对方虚拟账户。展示与选择器共用同一过滤口径。
        List<Account> match(List<Account> src) =>
            allowedCategories == null && allowedTypes == null
                ? fundAccountsOnly(src)
                : src
                    .where(
                      (Account a) =>
                          (allowedCategories == null ||
                              allowedCategories!.contains(a.type.category)) &&
                          (allowedTypes == null ||
                              allowedTypes!.contains(a.type)),
                    )
                    .toList(growable: false);
        final List<Account> shown = match(list);
        final String? safe =
            shown.any((Account a) => a.id == value) ? value : null;
        final Account? selected =
            safe == null ? null : shown.firstWhere((Account a) => a.id == safe);
        final bool picked = selected != null;
        final bool isAsset = label == '资产账户';
        return InkWell(
          // 空列表也允许打开选择器：弹窗内有「暂无账户，点击右上角添加」
          // 兜底（＋添加可创建借入/借出账户），禁用点击会卡死无账户场景。
          onTap: () => _showTransferAccountPicker(
                    label: label,
                    // 选择器实时 watch 账户流并套用同一过滤口径
                    filter: match,
                    selectedId: safe,
                    // 借入/借出账户可不选（对方已填时仅建债务不动资金）；
                    // 「资产账户」是还债/收债的资金通道，保存必选。
                    allowNone: label != '资产账户',
                    noneSubtitle: '仅计入收支账单，不计入资产',
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
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: _Sage.card,
              border: Border.all(
                color: picked ? _Sage.greenSoftBd : _Sage.hairline,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: picked ? _Sage.pickShadow : _Sage.shadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          gradient: picked ? _Sage.sage : null,
                          color: picked ? null : _Sage.greenSoft,
                          border: Border.all(
                            color:
                                picked ? Colors.transparent : _Sage.greenSoftBd,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isAsset
                              ? Icons.account_balance_wallet_outlined
                              : Icons.account_box_outlined,
                          size: 17,
                          color: picked ? Theme.of(context).colorScheme.onPrimary : _Sage.greenDeep,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                if (picked)
                                  Container(
                                    width: 5,
                                    height: 5,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: _Sage.sageB,
                                      borderRadius: BorderRadius.circular(2.5),
                                    ),
                                  ),
                                Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: _Sage.ink,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              selected?.name ??
                                  (shown.isEmpty
                                      ? '暂无账户，点击创建'
                                      : placeholder),
                              style: TextStyle(
                                fontSize: 12,
                                color: picked ? _Sage.greenDeep : _Sage.ink3,
                                fontWeight: picked
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: picked ? _Sage.greenDeep : _Sage.ink3,
                      ),
                    ],
                  ),
                ),
                if (hint != null) _buildSageCardHint(hint),
              ],
            ),
          ),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (Object e, _) => Text('账户加载失败：$e'),
    );
  }

  /// ForestSage V1 · 账户卡内底部小字说明行（info 线稿图标 + 12px 三级文字）。
  Widget _buildSageCardHint(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 14, 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.info_outline,
            size: 12,
            color: _Sage.sageB,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11.5,
                color: _Sage.ink3,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 借还页「对方账户」输入框的提示词：
  /// - 还债 / 债务削减 / 借入（借入方向）→ 借入账户
  /// - 收债 / 坏账损失 / 借出（借出方向）→ 借出账户
  String get _lendCounterpartyHint =>
      _lendDir == LendDirection.borrowIn ? '借入账户' : '借出账户';

  /// 债务削减 / 坏账计提 / 借还页对方的账户选择器（ForestSage V1 · 纸感细线）。
  /// 点击后从当前方向对应的应收/应付真实账户中选择，不再显示资金、投资等账户；
  /// 也支持手动输入新账户。视觉等同 V1 的「对方账户」卡片。
  Widget _buildLendCounterpartyField({String? hint}) {
    final String current = _counterpartyController.text.trim();
    final bool hasValue = current.isNotEmpty;
    final bool picked = hasValue;
    final String placeholder = '未选择 · ${_lendCounterpartyHint}';
    return InkWell(
      onTap: _showLendCounterpartyPicker,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _Sage.card,
          border: Border.all(
            color: picked ? _Sage.greenSoftBd : _Sage.hairline,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: picked ? _Sage.pickShadow : _Sage.shadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: picked ? _Sage.sage : null,
                      color: picked ? null : _Sage.greenSoft,
                      border: Border.all(
                        color: picked ? Colors.transparent : _Sage.greenSoftBd,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.account_box_outlined,
                      size: 17,
                      color: picked ? Theme.of(context).colorScheme.onPrimary : _Sage.greenDeep,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            if (picked)
                              Container(
                                width: 5,
                                height: 5,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: _Sage.sageB,
                                  borderRadius: BorderRadius.circular(2.5),
                                ),
                              ),
                            Text(
                              _lendCounterpartyHint,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _Sage.ink,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2),
                        Text(
                          hasValue ? current : placeholder,
                          style: TextStyle(
                            fontSize: 12,
                            color: picked ? _Sage.greenDeep : _Sage.ink3,
                            fontWeight:
                                picked ? FontWeight.w500 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: picked ? _Sage.greenDeep : _Sage.ink3,
                  ),
                ],
              ),
            ),
            if (hint != null) _buildSageCardHint(hint),
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
      builder: (BuildContext ctx) => AccountPickerSheet(
        // 实时 watch 账户流：仅当前方向的应收 / 应付真实账户
        // （弹窗内过滤已删除账户，与 lendAccountsProvider 口径一致）
        filter: (List<Account> all) => all
            .where(
              (Account a) =>
                  a.type.category ==
                  (_lendDir == LendDirection.lendOut
                      ? AccountCategory.receivable
                      : AccountCategory.payable),
            )
            .toList(growable: false),
        selectedName: _counterpartyController.text.trim(),
        title: '选择${_lendDir == LendDirection.lendOut ? '应收' : '应付'}账户',
        noneTitle: '不选择具体账户',
        noneSubtitle: '仅计入收支账单，不计入资产',
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
        onConfirm: (Account? acc) =>
            Navigator.of(ctx).pop(acc?.name ?? ''),
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

  /// 借还页利息 / 优惠 / 计算器行（ForestSage V1 · 纸感细线）。
  /// 左：奶油卡（¥ 渐变徽标 + 金额输入 + 利息/优惠 切换）；右：计算器按钮。
  /// 优惠模式下计算器禁用（优惠不支持计算）。
  Widget _buildLendFeeRow() {
    final bool isFee = _lendFeeInputType == _FeeInputType.fee;
    // 本行处于无界高度的单列滚动区，Row 不能直接用 stretch（会抛
    // "BoxConstraints forces an infinite height"，整页空白）；先包一层
    // IntrinsicHeight 计算出有限高度，stretch 才能把左右两侧拉成等高。
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(13, 11, 12, 11),
              decoration: BoxDecoration(
                color: _Sage.card,
                border: Border.all(color: _Sage.hairline),
                borderRadius: BorderRadius.circular(18),
                boxShadow: _Sage.shadow,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: _Sage.sage,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppPalette.sage600.withValues(alpha: 0.302),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      '¥',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          isFee
                              ? '利息'
                              : (_lendDir == LendDirection.borrowIn
                                  ? '优惠'
                                  : '减免'),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: _Sage.ink3,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 1),
                        // 只读显示框：录入走工程内数字键盘（_feeKeyboardTarget
                        // = 'lendFee'），点击「¥ + 金额」区域即切换键盘目标；
                        // 点击表单其他位置由 _onNewLayoutTapAway 移除焦点。
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _activateFeeKeyboard('lendFee'),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              const Text(
                                '¥',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: _Sage.ink2,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                // IgnorePointer：屏蔽 TextField 自身手势，
                                // 让点击穿透到外层 GestureDetector（同转账费用框）。
                                child: IgnorePointer(
                                  child: TextField(
                                    controller: _lendFeeController,
                                    focusNode: _lendFeeFocusNode,
                                    // 只读：不唤起系统键盘；焦点由
                                    // _activateFeeKeyboard 程序化赋予，光标可闪烁。
                                    readOnly: true,
                                    showCursor: _feeKeyboardTarget == 'lendFee',
                                    cursorColor: _Sage.greenDeep,
                                    textAlignVertical: TextAlignVertical.center,
                                    decoration: const InputDecoration(
                                      hintText: '0.00',
                                      hintStyle: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: _Sage.ink3,
                                      ),
                                      // 显式覆盖全部状态的边框：主题默认样式会在
                                      // enabled/focused 态绘制边框，仅设 border:none
                                      // 挡不住；fillColor 设透明，避免主题默认
                                      // 填充色在金额输入区形成额外背景块。
                                      filled: true,
                                      fillColor: Colors.transparent,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      focusedErrorBorder: InputBorder.none,
                                      isCollapsed: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _Sage.ink,
                                    ),
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildLendFeeTypeToggle(),
                ],
              ),
            ),
          ),
          const SizedBox(width: 9),
          _buildLendCalculatorButton(context, enabled: isFee),
        ],
      ),
    );
  }

  /// 「利息 / 优惠」切换开关（ForestSage V1 · 胶囊）。
  Widget _buildLendFeeTypeToggle() {
    final bool isFee = _lendFeeInputType == _FeeInputType.fee;
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: _Sage.cardAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
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
      ),
    );
  }

  Widget _buildLendFeeTypeSegment({
    required String label,
    required bool selected,
    required _FeeInputType type,
  }) {
    return InkWell(
      onTap: () => _onLendFeeInputTypeChanged(type),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _Sage.greenDeep : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: selected ? Theme.of(context).colorScheme.onPrimary : _Sage.ink2,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// 借还计算器按钮（ForestSage V1 · 纸感细线）。
  /// 优惠模式下整体降透明度并禁用（优惠不支持计算）。
  Widget _buildLendCalculatorButton(BuildContext context, {required bool enabled}) {
    return InkWell(
      onTap: enabled ? _openLendFeeCalculator : null,
      borderRadius: BorderRadius.circular(18),
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          // 不写 height：外层 Row 已是 CrossAxisAlignment.stretch，
          // 会把按钮强行拉到与左侧利息卡等高；若写 double.infinity，
          // 无界高度（单列滚动区）下固有高度计算为无穷大会让整页布局崩溃。
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _Sage.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _Sage.hairline),
            boxShadow: enabled ? _Sage.shadow : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.calculate_outlined,
                size: 15,
                color: enabled ? _Sage.greenDeep : _Sage.ink3,
              ),
              const SizedBox(width: 6),
              Text(
                '计算器',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: enabled ? _Sage.ink : _Sage.ink3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 打开手续费计算弹窗（借还页），回填利息 / 优惠。
  Future<void> _openLendFeeCalculator() async {
    final FeeCalculatorResult? result =
        await showModalBottomSheet<FeeCalculatorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
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

  /// 借还页利息 / 优惠公式说明（ForestSage V1 · 2 格卡片）。
  /// 公式口径严格对齐设计稿：按方向（借入/借出）× 模式（利息/优惠）给出两格
  /// 「本方向首动作 / 对方动作」的账户结算等式。
  Widget _buildLendFeeHint() {
    final bool isIn = _lendDir == LendDirection.borrowIn;
    final bool isFee = _lendFeeInputType == _FeeInputType.fee;
    final String firstKey = isIn ? '借入' : '借出';
    final String oppKey = isIn ? '还债' : '收债';
    final String firstAcct = isIn ? '借入账户' : '借出账户';
    final String oppAcct = isIn ? '借入账户' : '借出账户';
    final String assetAcct = '资产账户';
    // 优惠（借入）/ 减免（借出）：借入/借出时把债务净额直接减少，
    // 后续还债 / 收债按净额结算即可，两腿公式都体现优惠。
    final String cutKey = isIn ? '优惠' : '减免';
    final List<List<String>> cells = isIn
        ? (isFee
            ? <List<String>>[
                <String>[
                  '$firstKey：',
                  '$firstAcct = 借入金额 + 利息',
                  '$assetAcct = 借入金额'
                ],
                <String>[
                  '$oppKey：',
                  '$oppAcct = 借入金额',
                  '$assetAcct = 借入金额 + 利息'
                ],
              ]
            : <List<String>>[
                <String>[
                  '$firstKey：',
                  '$firstAcct = 借入金额 − 优惠',
                  '$assetAcct = 借入金额'
                ],
                <String>[
                  '$oppKey：',
                  '$oppAcct = 借入金额 − 优惠',
                  '$assetAcct = 借入金额 − 优惠'
                ],
              ])
        : (isFee
            ? <List<String>>[
                <String>[
                  '$firstKey：',
                  '$firstAcct = 借出金额 + 利息',
                  '$assetAcct = 借出金额'
                ],
                <String>[
                  '$oppKey：',
                  '$oppAcct = 借出金额',
                  '$assetAcct = 借出金额 + 利息'
                ],
              ]
            : <List<String>>[
                <String>[
                  '$firstKey：',
                  '$firstAcct = 借出金额 − 减免',
                  '$assetAcct = 借出金额'
                ],
                <String>[
                  '$oppKey：',
                  '$oppAcct = 借出金额 − 减免',
                  '$assetAcct = 借出金额 − 减免'
                ],
              ]);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
      decoration: BoxDecoration(
        color: _Sage.greenSoft,
        border: Border.all(color: _Sage.greenSoftBd),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.info_outline,
                size: 14,
                color: _Sage.greenDeep,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  isFee
                      ? '利息根据个人需求可在${isIn ? "借入" : "借出"}或者${isIn ? "还债" : "收债"}时候添加；一般在一方添加即可'
                      : '$cutKey在$firstKey时候添加即可；债务将按「金额 − $cutKey」自动结算，$oppKey时无需再减',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppPalette.ink3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: _buildSageFormulaCell(context, cells[0])),
              SizedBox(width: 8),
              Expanded(child: _buildSageFormulaCell(context, cells[1])),
            ],
          ),
        ],
      ),
    );
  }

  /// V1 公式格（浅绿卡片 + 标题 + 两行等式）。
  Widget _buildSageFormulaCell(BuildContext context, List<String> cell) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.651),
        border: Border.all(color: AppPalette.sage100.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.only(right: 5),
                decoration: BoxDecoration(
                  color: _Sage.sageB,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              Text(
                cell[0],
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: _Sage.greenDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          for (int i = 1; i < cell.length; i++) _buildSageFormulaLine(cell[i]),
        ],
      ),
    );
  }

  /// 把等式 "账户 = 表达式" 拆成「账户」加粗、表达式次级色的富文本。
  Widget _buildSageFormulaLine(String line) {
    final int idx = line.indexOf(' = ');
    if (idx < 0) {
      return Text(
        line,
        style: const TextStyle(fontSize: 11.5, height: 1.6, color: _Sage.ink2),
      );
    }
    final String left = line.substring(0, idx);
    final String right = line.substring(idx + 3);
    return RichText(
      text: TextSpan(
        children: <TextSpan>[
          TextSpan(
            text: '$left = ',
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.6,
              color: _Sage.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: right,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.6,
              color: _Sage.ink2,
            ),
          ),
        ],
      ),
    );
  }

  /// 小青账布局顶部滚动区：根据 Tab 显示分类网格、转账字段或借还字段。
  /// [minHeight] 仅借还 Tab 使用：把「方向 / 类型 / 账户卡 / 利息区 / 公式块」
  /// 整组至少撑到可视高度，键盘收起时一屏内完整显示（无需滚动）。
  Widget _buildNewLayoutScrollArea({double minHeight = 0}) {
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
            _buildTransferFlowZone(),
            const SizedBox(height: 14),
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
        final String virtualHint = _lendDir == LendDirection.borrowIn
            ? '虚拟账户：如找小明借钱，小明就是此账户'
            : '虚拟账户：如借给小明，小明就是此账户';
        // 主组 = 方向开关 / 类型网格 / 账户卡；尾组 = 利息区 / 公式块。
        // 两组一起放进「最小可视高度 + spaceBetween」的首屏容器：剩余空间
        // 在各块间距之间均分，键盘收起时无需滚动即可看到完整借还界面
        //（含利息组件）；内容超出可视高度时自然增高，正常滚动不受影响。
        final List<Widget> primary;
        final List<Widget> tail;
        if (usesCounterparty) {
          primary = <Widget>[
            _buildLendDirectionToggle(),
            const SizedBox(height: 12),
            _buildLendActionGrid(),
            const SizedBox(height: 14),
            _buildLendCounterpartyField(
              hint: isRepay
                  ? (_lendDir == LendDirection.borrowIn
                      ? '输入欠款对象，将冲销其名下未结清借入债务（按发生时间从早到晚抵扣）；不选择具体账户时仅记资金流水'
                      : '输入借款对象，将冲销其名下未结清借出债务（按发生时间从早到晚抵扣）；不选择具体账户时仅记资金流水')
                  : virtualHint,
            ),
            if (isRepay) ...<Widget>[
              const SizedBox(height: 10), // --sp-2
              _buildLendAccountCard(
                label: _lendDir == LendDirection.borrowIn ? '还款账户' : '收款账户',
                value: _repayAccountId,
                placeholder: _lendDir == LendDirection.borrowIn
                    ? '选择还款账户（现金从此扣出）'
                    : '选择收款账户（现金存入此账户）',
                onChanged: (String? v) => setState(() => _repayAccountId = v),
                autoFillCounterparty: false,
                hint: _lendDir == LendDirection.borrowIn
                    ? '还债：现金从该账户扣出，余额相应减少'
                    : '收债：现金存入该账户，余额相应增加',
              ),
            ],
          ];
          tail = isRepay
              ? <Widget>[
                  const SizedBox(height: 12),
                  _buildLendFeeHint(),
                ]
              : const <Widget>[];
        } else {
          primary = <Widget>[
            _buildLendDirectionToggle(),
            const SizedBox(height: 12),
            _buildLendActionGrid(),
            const SizedBox(height: 14),
            _buildLendAccountCard(
              label: _lendDir == LendDirection.borrowIn ? '借入账户' : '借出账户',
              value: _accountId,
              placeholder: _lendDir == LendDirection.borrowIn ? '借入账户' : '借出账户',
              onChanged: (String? v) => setState(() => _accountId = v),
              // 指定借入/借出账户（报销「指定报销账户」同款）：
              // 只列借入(borrow)/借出(lend)类型账户，可选（不选=非指定）。
              allowedTypes: <AccountType>[
                _lendDir == LendDirection.borrowIn
                    ? AccountType.borrow
                    : AccountType.lend,
              ],
              hint: virtualHint,
            ),
            const SizedBox(height: 10), // --sp-2
            _buildLendAccountCard(
              label: '资产账户',
              value: _toAccountId,
              placeholder: '资产账户',
              onChanged: (String? v) => setState(() => _toAccountId = v),
              hint: '资产账户：将金额累计到这个账户里',
            ),
          ];
          tail = <Widget>[
            const SizedBox(height: 12), // 利息区上间距
            _buildLendFeeRow(),
            const SizedBox(height: 10), // --sp-2
            _buildLendFeeHint(),
          ];
        }
        // 只有「借入/借出 + 资产账户」分支带利息区，才需要撑满首屏让
        // 利息组件免滚动可见；「还债 / 债务削减」内容块少（2–4 个），
        // 撑满会把间距均分得过大（视觉节奏拉散），恢复 V1 固定间距、
        // 顶部对齐的自然布局（minHeight 传 0 即不撑满）。
        final double effectiveMinHeight = usesCounterparty ? 0 : minHeight;
        return ConstrainedBox(
          // minHeight 传入的是已扣除滚动区 padding 的可视高度；
          // 主组 + 尾组整体纳入首屏：spaceBetween 把剩余高度均分到各块
          // 间距上，利息区 / 公式块不再被挤到折叠线以下。
          constraints: BoxConstraints(minHeight: effectiveMinHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[...primary, ...tail],
          ),
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
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
          fourColumns: true,
        ),
        ),
      ],
    );
  }

  /// 存钱 Tab 独立布局：「存钱计划」标题栏 +「我的计划」列表。
  ///
  /// 进行中的计划从储蓄页移入本 Tab 直接管理（存入 / 取出 / 归档 / 删除），
  /// 新建计划仍跳「储蓄」页选模式；金额行与数字键盘保持移除。
  Widget _buildSavingsBody() {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildSectionTitle('存钱计划'),
          const SizedBox(height: AppDimens.spaceSm),
          _buildSavingsGoalZone(),
        ],
      ),
    );
  }

  /// 报销页独立布局（小青账模板）：顶部滚动表单 + 底部固定「保存」按钮。
  ///
  /// 报销使用自带「报销收入」输入框（系统数字键盘），不使用自定义数字键盘，
  /// 因此底部不渲染键盘栏，只放一个「保存」按钮。
  Widget _buildReimbursementBody() {
    // 报销金额键盘激活时：底部用工程内数字键盘**覆盖**「保存」栏
    // （键盘自带 ✓ 保存键，保存功能不丢失）；收起后恢复保存栏。
    final bool keypadActive =
        _feeKeyboardTarget == 'rbAmount' && _keyboardExpanded;
    return Column(
      children: <Widget>[
        Expanded(
          child: Container(
            color: _Sage.paper,
            child: GestureDetector(
              // 点击表单空白处：收起工程内键盘（保存栏随之恢复）。
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (_feeKeyboardTarget != null) {
                  setState(_clearFeeKeyboardTarget);
                } else {
                  FocusScope.of(context).unfocus();
                }
              },
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceLg,
                  AppDimens.spaceMd,
                  AppDimens.spaceLg,
                  AppDimens.spaceLg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildReimbursementForm(),
                ),
              ),
            ),
          ),
        ),
        if (keypadActive)
          // 键盘浮于纸底（与主布局同款边距），占住底部替换保存栏。
          _buildCollapsibleKeypad()
        else
          _buildSaveFooter(),
      ],
    );
  }

  List<Widget> _buildReimbursementForm() {
    return <Widget>[
      _rbSectionHeader(
        '报销账户',
        onPick: () => _pickRbAccount(
          label: '报销账户',
          value: _rbAccountId,
          allowedTypes: const <AccountType>[AccountType.reimbursement],
          onChanged: (String? v) => setState(() {
            if (v != _rbAccountId) {
              _rbHistIds.clear();
              _rbFinishIds.clear();
            }
            _rbAccountId = v;
          }),
        ),
      ),
      const SizedBox(height: 8),
      _buildRbAccountCard(),
      const SizedBox(height: 16),
      _rbSectionHeader('报销账单', onPick: _showRbHistoryPicker),
      const SizedBox(height: 8),
      _buildRbBillCard(),
      const SizedBox(height: 12),
      _buildRbPhotoCard(),
      const SizedBox(height: 16),
      _rbSectionHeader(
        '报销收入',
        onPick: _fillRbFullAmount,
        pickLabel: '全额报销',
        pickIcon: false,
      ),
      const SizedBox(height: 8),
      _buildRbAmountCard(),
      const SizedBox(height: 16),
      _buildRbDateCard(),
      const SizedBox(height: 12),
      _buildRbExcludeCard(),
      const SizedBox(height: 12),
      _buildRbNoteCard(),
      const SizedBox(height: 16),
      _microLabel('收款账户'),
      const SizedBox(height: 8),
      _buildRbAccountPair(
        label: '收款账户',
        value: _rbToAccountId,
        placeholder: '请选择收款账户',
        onChanged: (String? v) => setState(() => _rbToAccountId = v),
      ),
      const SizedBox(height: 16),
      _buildRbBookRow(context),
      const SizedBox(height: 8),
    ];
  }

  /// 微标签（纯中文、加字距）。
  Widget _microLabel(String t) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          t,
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.5,
            color: _Sage.ink2,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  /// 报销页节头（对齐参考稿）：绿色竖条 + 加粗标题 + 右侧「选取」胶囊。
  Widget _rbSectionHeader(
    String title, {
    VoidCallback? onPick,
    String pickLabel = '选取',
    bool pickIcon = true,
  }) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          children: <Widget>[
            Container(
              width: 3.5,
              height: 14,
              decoration: BoxDecoration(
                color: _Sage.sageB,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: _Sage.ink,
              ),
            ),
            const Spacer(),
            if (onPick != null)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPick,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: ForestBg.sunken,
                      border: Border.all(color: _Sage.hairline),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (pickIcon) ...<Widget>[
                          const Icon(
                            Icons.grid_view_outlined,
                            size: 13,
                            color: _Sage.ink2,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          pickLabel,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: _Sage.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  /// 报销账户主卡（对齐参考稿）：圆形头像 + 名称/类型 + 右侧绿色余额。
  /// 未选账户时显示占位提示；点卡片或节头「选取」打开账户选择浮层。
  Widget _buildRbAccountCard() {
    final AsyncValue<List<Account>> accounts = ref.watch(accountsProvider);
    return accounts.when(
      data: (List<Account> list) {
        final List<Account> shown = list
            .where((Account a) => a.type == AccountType.reimbursement)
            .toList(growable: false);
        final String? safe =
            shown.any((Account a) => a.id == _rbAccountId) ? _rbAccountId : null;
        final Account? selected =
            safe == null ? null : shown.firstWhere((Account a) => a.id == safe);
        final bool picked = selected != null;
        return _rbCard(
          picked: picked,
          onTap: () => _pickRbAccount(
            label: '报销账户',
            value: safe,
            allowedTypes: const <AccountType>[AccountType.reimbursement],
            onChanged: (String? v) => setState(() {
              // 报销账户变更后，已提取的账单归属随之失效，清空重选。
              if (v != _rbAccountId) {
                _rbHistIds.clear();
                _rbFinishIds.clear();
              }
              _rbAccountId = v;
            }),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: picked ? _Sage.greenSoft : ForestBg.sunken,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: picked ? _Sage.greenSoftBd : _Sage.hairline,
                  ),
                ),
                child: Icon(
                  accountIcon(selected?.type ?? AccountType.reimbursement),
                  size: 20,
                  color: picked ? _Sage.greenDeep : _Sage.ink3,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      selected?.name ?? '请选择报销账户',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: picked ? _Sage.ink : _Sage.ink2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      selected?.type.label ?? '报销',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: _Sage.ink2,
                      ),
                    ),
                  ],
                ),
              ),
              if (picked) ...<Widget>[
                const SizedBox(width: 10),
                Text(
                  Money.fromMinor(
                    selected!.balanceMinor,
                    currency: selected.currency,
                  ).format(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _Sage.greenDeep,
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        height: 56,
        child: LinearProgressIndicator(
          color: _Sage.sageB,
          backgroundColor: _Sage.greenSoft,
        ),
      ),
      error: (Object e, _) => Text('账户加载失败：$e'),
    );
  }

  /// 卡片左侧 LineIcon 圆角徽标（软绿底 + 浅绿描边，与借还区账户徽标同规格）。
  Widget _sageLead(LineIconKind kind) => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: _Sage.greenSoft,
          border: Border.all(color: _Sage.greenSoftBd),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(child: LineIcon(kind, size: 17, color: _Sage.greenDeep)),
      );

  /// 选中态勾选圆（鼠尾草渐变）。
  Widget _sageCheck(bool picked) => AnimatedOpacity(
        opacity: picked ? 1 : 0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[_Sage.sageA, _Sage.sageB],
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(Icons.check, size: 14, color: Theme.of(context).colorScheme.onPrimary),
          ),
        ),
      );

  /// 圆形勾选指示（历史账单多选）。
  Widget _sageCircle(bool sel) => Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: sel ? Colors.transparent : AppPalette.sand,
            width: 1.5,
          ),
          gradient: sel
              ? LinearGradient(
                  colors: <Color>[_Sage.sageA, _Sage.sageB],
                )
              : null,
        ),
        child: sel
            ? Icon(Icons.check, size: 13, color: Theme.of(context).colorScheme.onPrimary)
            : null,
      );

  /// 奶油整卡（1px 发丝线圆角）。
  Widget _rbCard({
    required Widget child,
    VoidCallback? onTap,
    bool picked = false,
  }) =>
      Material(
        color: _Sage.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: picked ? _Sage.sageA : _Sage.hairline,
              ),
              // 设计稿 --shadow 常驻：让奶油卡从纸底上「浮」起来，
              // 否则 #FFFCF5 与 #FBF6EA 只差数个色阶，整页发白。
              boxShadow: picked
                  ? <BoxShadow>[
                      BoxShadow(
                        color: AppPalette.sage600.withValues(alpha: 0.078),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                      ..._Sage.shadow,
                    ]
                  : _Sage.shadow,
            ),
            child: child,
          ),
        ),
      );

  /// 报销 / 收款账户：整条选择框（点击打开账户选择浮层）。
  Widget _buildRbAccountPair({
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
    String placeholder = '请选择',
    List<AccountType>? allowedTypes,
  }) {
    final AsyncValue<List<Account>> accounts = ref.watch(accountsProvider);
    return accounts.when(
      data: (List<Account> list) {
        final List<Account> shown = allowedTypes != null
            ? list
                .where((Account a) => allowedTypes.contains(a.type))
                .toList(growable: false)
            : fundAccountsOnly(list);
        final String? safe =
            shown.any((Account a) => a.id == value) ? value : null;
        final Account? selected =
            safe == null ? null : shown.firstWhere((Account a) => a.id == safe);
        final bool picked = selected != null;
        return _rbCard(
          picked: picked,
          onTap: () => _pickRbAccount(
            label: label,
            value: safe,
            allowedTypes: allowedTypes,
            onChanged: onChanged,
          ),
          child: Row(
            children: <Widget>[
              _sageLead(LineIconKind.account),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _Sage.ink2,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selected?.name ?? placeholder,
                      style: TextStyle(
                        fontSize: 15,
                        color: picked ? _Sage.ink : _Sage.ink2,
                        fontWeight: picked ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _sageCheck(picked),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        height: 56,
        child: LinearProgressIndicator(
          color: _Sage.sageB,
          backgroundColor: _Sage.greenSoft,
        ),
      ),
      error: (Object e, _) => Text('账户加载失败：$e'),
    );
  }

  Future<void> _pickRbAccount({
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
    List<AccountType>? allowedTypes,
  }) async {
    await _showTransferAccountPicker(
      label: label,
      // 选择器实时 watch 账户流并套用同一过滤口径（指定类型 / 资金类）
      filter: (List<Account> all) {
        if (allowedTypes != null) {
          return all
              .where((Account a) => allowedTypes!.contains(a.type))
              .toList(growable: false);
        }
        return fundAccountsOnly(all);
      },
      selectedId: value,
      onChanged: onChanged,
    );
  }

  /// 报销账单卡（对齐参考稿）：总金额行 + 全部结束胶囊 + 账单行
  /// （类目图标 + 标题/报徽章 + 日期时间 + 金额/排除标注 + 完成报销勾选），
  /// 账单组之间点线分隔；票据照片行保留。点账单行进入选择页（可取消勾选）。
  Widget _buildRbBillCard() {
    final List<Transaction> expenses =
        ref.watch(bookExpenseTransactionsProvider).valueOrNull ??
            const <Transaction>[];
    final List<Transaction> sel = expenses
        .where((Transaction t) => _rbHistIds.contains(t.id))
        .toList(growable: false);
    final int totalMinor =
        sel.fold<int>(0, (int s, Transaction t) => s + t.amountMinor);
    final bool allDone = sel.isNotEmpty &&
        sel.every((Transaction t) => _rbFinishIds.contains(t.id));
    return _rbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (sel.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  '请选择需要报销的账单',
                  style: TextStyle(fontSize: 13.5, color: _Sage.ink2),
                ),
              ),
            )
          else ...<Widget>[
            // 总金额 + 全部结束。
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '账单总金额: ${Money.fromMinor(totalMinor).format()}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: _Sage.ink,
                    ),
                  ),
                ),
                _rbFinishAllPill(allDone: allDone, count: sel.length),
              ],
            ),
            const SizedBox(height: 4),
            for (int i = 0; i < sel.length; i++) ...<Widget>[
              if (i > 0) _dottedDivider(),
              _rbBillRow(sel[i]),
            ],
          ],
        ],
        ),
      );
  }

  /// 「全部结束」琥珀胶囊：一键把所选账单全部标记/取消「完成报销」。
  Widget _rbFinishAllPill({required bool allDone, required int count}) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() {
            if (allDone) {
              _rbFinishIds.clear();
            } else {
              _rbFinishIds
                ..clear()
                ..addAll(_rbHistIds);
            }
          }),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: allDone ? _Sage.greenSoft : AppPalette.goldSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              allDone ? '取消全部结束' : '全部结束',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: allDone ? _Sage.greenDeep : AppPalette.goldAmber,
              ),
            ),
          ),
        ),
      );

  /// 账单组间点线分隔。
  Widget _dottedDivider() {
    final int count = 46;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < count; i++)
            Expanded(
              child: Container(
                height: 1.2,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i.isEven ? _Sage.hairline : Colors.transparent,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 单笔报销账单行（参考稿）：圆角方类目图标 + 标题/「报」徽章 +
  /// 日期/时间 + 右侧金额与排除标注；行下方「完成报销(结束此报销)」圆选。
  Widget _rbBillRow(Transaction t) {
    final Map<String, Category> categories =
        ref.watch(categoryMapProvider).valueOrNull ?? const <String, Category>{};
    final Category? cat = categories[t.categoryId];
    final Color tint = cat?.colorValue != null
        ? Color(cat!.colorValue!)
        : _Sage.greenDeep;
    final IconData icon = cat?.iconKey != null && cat!.iconKey!.isNotEmpty
        ? categoryIconData(cat.iconKey)
        : Icons.receipt_long;
    final String title =
        cat?.name ?? (t.note?.isNotEmpty == true ? t.note! : '支出');
    final DateTime occurred = DateTime.fromMillisecondsSinceEpoch(
      t.occurredAt,
      isUtc: true,
    ).toLocal();
    final List<String> excludeLabels = <String>[
      if (t.excludeFromStats) '不计收支',
      if (t.excludeFromBudget) '不计预算',
    ];
    final bool finish = _rbFinishIds.contains(t.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InkWell(
          onTap: _showRbHistoryPicker,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // 类目图标（圆角方，类目色浅底）。
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: tint),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _Sage.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: _Sage.greenSoft,
                              border: Border.all(color: _Sage.greenSoftBd),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '报',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _Sage.greenDeep,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        DateFormat('M月d日').format(occurred),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: _Sage.ink2,
                        ),
                      ),
                      Text(
                        DateFormat('HH:mm').format(occurred),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: _Sage.ink3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '-${Money.fromMinor(t.amountMinor).format()}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: finish ? _Sage.ink2 : _Sage.ink,
                        // 勾选「完成报销」后金额划掉。
                        decoration:
                            finish ? TextDecoration.lineThrough : null,
                        decorationColor: _Sage.ink3,
                        decorationThickness: 1.6,
                      ),
                    ),
                    if (excludeLabels.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          excludeLabels.join('、'),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: ForestSemantic.expense,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // 完成报销勾选行。
        InkWell(
          onTap: () => setState(() {
            if (finish) {
              _rbFinishIds.remove(t.id);
            } else {
              _rbFinishIds.add(t.id);
            }
          }),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2, top: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _sageCircle(finish),
                const SizedBox(width: 8),
                Text(
                  '完成报销(结束此报销)',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: finish ? _Sage.greenDeep : _Sage.ink2,
                    fontWeight: finish ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 票据照片卡（独立卡片，对齐参考稿布局重设计）：
  /// 头部 = 照片徽标 + 标题/副标题 + 右侧张数胶囊（N/9）；
  /// 下方 = 票据缩略图单行横向排列（64×64 圆角方，点击进入管理弹窗：
  /// 查看/删除/拖动排序），末尾绿色「添加」格，上限 9 张，横向滑动查看。
  Widget _buildRbPhotoCard() {
    final int photos = _attachmentPaths.length;
    return _rbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              _sageLead(LineIconKind.photo),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '票据照片',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _Sage.ink,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '拍照或从相册补充票据',
                      style: TextStyle(fontSize: 12, color: _Sage.ink2),
                    ),
                  ],
                ),
              ),
              if (photos > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _Sage.greenSoft,
                    border: Border.all(color: _Sage.greenSoftBd),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$photos/9',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _Sage.greenDeep,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // 单行横向排列，超出一屏左右滑动查看。
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: <Widget>[
                for (int i = 0; i < photos; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _rbPhotoThumb(_attachmentPaths[i]),
                  ),
                if (photos < 9) _rbAddSlot(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 票据缩略图：64×64 圆角方图片预览，点击打开图片管理弹窗。
  Widget _rbPhotoThumb(String path) => Material(
        color: ForestBg.raised,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _onAddImage,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _Sage.hairline),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: LineIcon(
                    LineIconKind.photo,
                    size: 20,
                    color: _Sage.ink2,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  /// 「添加」格：拍照/相册入口（浅绿底 + 描边 + 加号）。
  Widget _rbAddSlot() => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _onAddImage,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _Sage.greenSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _Sage.sageA, width: 1.5),
            ),
            child: const Center(
              child: Icon(Icons.add, size: 22, color: _Sage.greenDeep),
            ),
          ),
        ),
      );

  /// 「全额报销」：把报销收入金额一键填为所选账单的**未报销金额总额**。
  /// 口径与保存时的抵扣链路一致：
  /// - 勾「完成报销」的账单正是本次要结清的，按其未报销余额计入
  ///   （保存时整笔核销、不占用收入抵扣，但金额属于本次收到的报销款）；
  /// - 已全额报销（status == reimbursed）的账单无剩余 → 不计入；
  /// - 待报销账单取报销记录的 amountMinor（即被部分抵扣后的剩余额），
  ///   无报销记录的账单取账单全额。
  void _fillRbFullAmount() {
    if (_rbHistIds.isEmpty) {
      _toast('请先选择需要报销的账单');
      return;
    }
    final List<Transaction> expenses =
        ref.read(bookExpenseTransactionsProvider).valueOrNull ??
            const <Transaction>[];
    // 报销记录按关联账单 transactionId 建索引，反查各账单的报销状态。
    final Map<String, Reimbursement> rbByTxn = <String, Reimbursement>{
      for (final Reimbursement r
          in ref.read(reimbursementListProvider).valueOrNull ??
              const <Reimbursement>[])
        if (r.transactionId != null) r.transactionId!: r,
    };
    final int needMinor = expenses
        .where((Transaction t) => _rbHistIds.contains(t.id))
        .fold<int>(0, (int s, Transaction t) {
      final Reimbursement? linked = rbByTxn[t.id];
      if (linked != null &&
          linked.status == ReimbursementStatus.reimbursed) {
        return s; // 已全额报销，无未报销余额。
      }
      return s + (linked?.amountMinor ?? t.amountMinor);
    });
    if (needMinor <= 0) {
      _toast('所选账单均无待报销金额');
      return;
    }
    setState(() {
      _rbAmountController.text =
          Money.fromMinor(needMinor).format(showSymbol: false);
      _activateFeeKeyboard('rbAmount');
    });
  }

  /// 报销收入金额卡（对齐参考稿）：胶囊形输入框，占位「报销金额」；
  /// ¥ 渐变徽标 + 只读数字输入（录入走工程内数字键盘）。
  Widget _buildRbAmountCard() => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: const BoxDecoration(
          color: ForestBg.sunken,
          borderRadius: BorderRadius.all(Radius.circular(999)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[_Sage.sageA, _Sage.sageB],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '¥',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 只读显示框：录入走工程内数字键盘（_feeKeyboardTarget =
            // 'rbAmount'），点击「¥ + 金额」区域即切换键盘目标；
            // 点击表单其他位置由报销页 tap-away 移除焦点。
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _activateFeeKeyboard('rbAmount'),
                child: IgnorePointer(
                  // 屏蔽 TextField 自身手势，让点击穿透到外层 GestureDetector。
                  child: TextField(
                    controller: _rbAmountController,
                    focusNode: _rbAmountFocusNode,
                    // 只读：不唤起系统键盘；焦点由 _activateFeeKeyboard
                    // 程序化赋予，光标可闪烁。
                    readOnly: true,
                    showCursor: _feeKeyboardTarget == 'rbAmount',
                    cursorColor: _Sage.greenDeep,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: const InputDecoration(
                      hintText: '报销金额',
                      hintStyle: TextStyle(
                        fontSize: 15,
                        color: _Sage.ink2,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      filled: true,
                      fillColor: Colors.transparent,
                      contentPadding: EdgeInsets.zero,
                      isCollapsed: true,
                    ),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _Sage.ink,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  /// 账本（只读展示当前账本名）。
  /// 账本（只读展示当前账本名，V1 奶油卡）。
  Widget _buildRbBookRow(BuildContext context) {
    final AsyncValue<Book?> book = ref.watch(currentBookProvider);
    return _rbCard(
      child: Row(
        children: <Widget>[
          _sageLead(LineIconKind.book),
          const SizedBox(width: 12),
          const Text(
            '账本',
            style: TextStyle(fontSize: 13, color: _Sage.ink),
          ),
          const Spacer(),
          Text(
            book.valueOrNull?.name ?? '账本',
            style: const TextStyle(fontSize: 14, color: _Sage.ink2),
          ),
          const SizedBox(width: 6),
          const LineIcon(LineIconKind.chevronRight, size: 14, color: _Sage.ink3),
        ],
      ),
    );
  }

  /// 日期卡（V1 奶油卡 + LineIcon 日历）。
  Widget _buildRbDateCard() => _rbCard(
        onTap: _pickDate,
        child: Row(
          children: <Widget>[
            _sageLead(LineIconKind.calendar),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    '日期',
                    style: TextStyle(
                      fontSize: 13,
                      color: _Sage.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _rbDateLabel(),
                    style: const TextStyle(fontSize: 12, color: _Sage.ink2),
                  ),
                ],
              ),
            ),
            Text(
              _isSameDay(_occurredAt, DateTime.now()) ? '今天' : '',
              style: const TextStyle(fontSize: 11.5, color: _Sage.ink2),
            ),
          ],
        ),
      );

  String _rbDateLabel() =>
      DateFormat('yyyy-MM-dd HH:mm').format(_occurredAt);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 不计入收支开关卡（V1 奶油卡 + 自定义开关）。
  Widget _buildRbExcludeCard() => _rbCard(
        child: Row(
          children: <Widget>[
            _sageLead(LineIconKind.excludeStats),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    '不计入收支',
                    style: TextStyle(
                      fontSize: 13,
                      color: _Sage.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    '确需计入日常收支时可手动关闭',
                    style: TextStyle(fontSize: 12, color: _Sage.ink2),
                  ),
                ],
              ),
            ),
            _sageSwitch(
              _rbExclude,
              (bool v) => setState(() => _rbExclude = v),
              context,
            ),
          ],
        ),
      );

  /// 鼠尾草风格开关（关=沙底 / 开=渐变）。
  Widget _sageSwitch(bool v, ValueChanged<bool> onChanged, BuildContext context) => GestureDetector(
        onTap: () => onChanged(!v),
        child: Container(
          width: 50,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: v ? _Sage.sageB : AppPalette.sandTaupe,
          ),
          child: Stack(
            children: <Widget>[
              AnimatedPositioned(
                left: v ? 23 : 3,
                top: 3,
                duration: Duration(milliseconds: 200),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.2),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  /// 备注卡（V1 奶油卡 + LineIcon 铅笔）。
  Widget _buildRbNoteCard() => _rbCard(
        child: Row(
          children: <Widget>[
            _sageLead(LineIconKind.pencil),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  hintText: '补充报销说明…',
                  hintStyle: TextStyle(fontSize: 14, color: _Sage.ink2),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: EdgeInsets.zero,
                  isCollapsed: true,
                ),
                style: const TextStyle(fontSize: 14, color: _Sage.ink),
                maxLines: 1,
              ),
            ),
          ],
        ),
      );

  /// 从历史账单选择：跳转独立整页「选择账单」，可多选关联。
  ///
  /// 门禁：只有先选定「报销账户」才能提取账单——
  /// 页内只列「需要报销」的支出，且分两类：
  /// ① 所选报销分支账户下的账单；② 未选取报销账户的账单。
  /// 归属其他报销分支账户的账单不显示，避免跨账户重复提取。
  Future<void> _showRbHistoryPicker() async {
    // 未选报销账户也可进入：页内只列「未指定报销账户」的账单；
    // 选了账户则同时列出该账户分支账单。保存时仍要求先选报销账户。
    final Set<String>? result = await context.push<Set<String>>(
      Routes.reimbursementBillPicker,
      extra: ReimbBillPickerArgs(
        accountId: _rbAccountId,
        initialSelected: Set<String>.from(_rbHistIds),
      ),
    );
    if (result != null) {
      setState(() {
        _rbHistIds
          ..clear()
          ..addAll(result);
      });
    }
  }

  /// 独立布局页（报销 / 退款）底部「保存」按钮。
  /// V1 设计稿 .bottom：奶油底栏（发丝线上边框）+ ForestSage 主色按钮。
  /// 此前按钮直接走主题 primary（#0F9D70 亮青绿），是整页唯一脱离
  /// ForestSage 令牌的部件——借还/支出页底部为自定义功能键栏不受影响，
  /// 仅报销 / 退款页露出，造成「跟工程内色调不一致」。
  Widget _buildSaveFooter() {
    return Container(
      decoration: BoxDecoration(
        color: _Sage.card,
        border: Border(top: BorderSide(color: _Sage.hairline)),
      ),
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
          style: FilledButton.styleFrom(
            // 官方令牌：按钮 / FAB = ForestGreen.cta 深绿实色。
            backgroundColor: ForestGreen.cta,
            disabledBackgroundColor: ForestGreen.cta.withValues(alpha: 0.45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _saving
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
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
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
      _buildSectionTitle(
        '原账单',
        note: _refundOriginals.isEmpty ? null : '已选 ${_refundOriginals.length} 笔',
      ),
      const SizedBox(height: AppDimens.spaceSm),
      _buildRefundOriginalField(),
      const SizedBox(height: AppDimens.spaceMd),
      _buildSectionTitle('退款信息'),
      const SizedBox(height: AppDimens.spaceSm),
      _buildRefundAmountRow(),
      const SizedBox(height: AppDimens.spaceMd),
      _buildRefundDateCard(),
      const SizedBox(height: AppDimens.spaceMd),
      _buildRefundNoteField(),
      const SizedBox(height: AppDimens.spaceMd),
      // 账户标题行：右侧「原账单账户」快捷键，点击自动填充原账单账户。
      Row(
        children: <Widget>[
          Expanded(child: _buildSectionTitle('账户')),
          _refundMiniButton(
            '原账单账户',
            onTap: _fillRefundOriginalAccount,
          ),
        ],
      ),
      const SizedBox(height: AppDimens.spaceSm),
      _buildRefundAccountRow(),
      const SizedBox(height: AppDimens.spaceMd),
      _buildAttachmentSection(),
      const SizedBox(height: AppDimens.spaceMd),
      _buildRefundBookRow(),
    ];
  }

  /// 带绿色竖线的分组标题（方案 A：渐变竖条 + 可选右侧灰字备注）。
  Widget _buildSectionTitle(String label, {String? note}) {
    return Row(
      children: <Widget>[
        Container(
          width: 4,
          height: 15,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[_Sage.sageA, _Sage.sageB],
            ),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: AppDimens.spaceSm),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: _Sage.ink,
              ),
        ),
        if (note != null) ...<Widget>[
          const Spacer(),
          Text(
            note,
            style: TextStyle(fontSize: 11, color: _Sage.ink3),
          ),
        ],
      ],
    );
  }

  /// 方案 A 迷你按钮：
  /// - 默认（深沙底 + 发丝线描边）：搜索 / 入款账户。
  /// - primary（鼠尾草渐变 + 白字 + 绿影）：选取。
  Widget _refundMiniButton(
    String label, {
    required VoidCallback onTap,
    bool primary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: primary ? null : ForestBg.sunken,
            gradient: primary ? ForestGradients.sage : null,
            borderRadius: BorderRadius.circular(13),
            border: primary ? null : Border.all(color: _Sage.hairline),
            boxShadow: primary
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppPalette.sage600.withValues(alpha: 0.278),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: primary ? Theme.of(context).colorScheme.onPrimary : _Sage.ink,
            ),
          ),
        ),
      ),
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
    return _rbCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              display,
              style: TextStyle(
                fontSize: 14,
                color: txns.isEmpty ? _Sage.ink3 : _Sage.ink,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          _refundMiniButton('搜索', onTap: _onSearchRefundOriginal),
          const SizedBox(width: 10),
          _refundMiniButton(
            '选取',
            primary: true,
            onTap: _pickRefundOriginal,
          ),
        ],
      ),
    );
  }

  Future<void> _onSearchRefundOriginal() async {
    _toast('账单搜索功能开发中');
  }

  /// 退款页「账户」整行卡（方案 A）：单张卡片内左侧账户胶囊 +
  /// 右侧「原账单账户」快捷键（自动填充为原账单的资产账户）。
  /// 左侧账户胶囊点击打开账户选择弹窗，可手动改选。
  ///
  /// 取第一笔有效（账户存在且为资金类）的原账单账户；
  /// 未选原账单或原账单均无有效账户时 toast 提示。
  void _fillRefundOriginalAccount() {
    if (_refundOriginals.isEmpty) {
      _toast('请先选择原账单');
      return;
    }
    final List<Account> accounts =
        ref.read(accountsProvider).value ?? const <Account>[];
    final String aid = _refundOriginals
        .map((Transaction t) => t.accountId)
        .firstWhere(
          (String id) =>
              id.isNotEmpty && accounts.any((Account a) => a.id == id),
          orElse: () => '',
        );
    if (aid.isEmpty) {
      _toast('原账单未选择资产账户');
      return;
    }
    setState(() => _accountId = aid);
  }

  /// 「原账单备注」快捷键：把备注自动填充为原账单的备注。
  ///
  /// 取第一笔备注非空的原账单（多选时与原账单栏「首条备注」口径一致）；
  /// 未选原账单或原账单均无备注时 toast 提示。
  void _fillRefundOriginalNote() {
    if (_refundOriginals.isEmpty) {
      _toast('请先选择原账单');
      return;
    }
    final String note = _refundOriginals
        .map((Transaction t) => (t.note ?? '').trim())
        .firstWhere(
          (String n) => n.isNotEmpty,
          orElse: () => '',
        );
    if (note.isEmpty) {
      _toast('原账单未填写备注');
      return;
    }
    setState(() => _noteController.text = note);
  }

  Widget _buildRefundAccountRow() {
    final AsyncValue<List<Account>> accounts = ref.watch(accountsProvider);
    return accounts.when(
      data: (List<Account> list) {
        final List<Account> shown = fundAccountsOnly(list);
        final String? safe =
            shown.any((Account a) => a.id == _accountId) ? _accountId : null;
        final Account? selected =
            safe == null ? null : shown.firstWhere((Account a) => a.id == safe);
        void pick() {
          _showTransferAccountPicker(
            label: '入款账户',
            // 选择器实时 watch 账户流：资金类账户（排除应收 / 应付）
            filter: fundAccountsOnly,
            selectedId: safe,
            onChanged: (String? v) => setState(() => _accountId = v),
          );
        }
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _Sage.card,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(color: ForestNeutral.hairline),
          ),
          child: Row(
            children: <Widget>[
              // 左：账户胶囊（深沙底；选中绿描边），点击同样进入选择弹窗。
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    // 空列表也打开选择器：弹窗内「＋添加」兜底
                    onTap: pick,
                    borderRadius: BorderRadius.circular(13),
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: ForestBg.sunken,
                        borderRadius: BorderRadius.circular(13),
                        border: selected == null
                            ? null
                            : Border.all(color: _Sage.sageB, width: 1.4),
                      ),
                      child: Text(
                        selected?.name ?? '请选择入款账户',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              selected == null ? FontWeight.w400 : FontWeight.w600,
                          color: selected == null ? _Sage.ink3 : _Sage.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 右：「原账单账户」快捷键（深沙底 + 发丝线描边，方案 A 中性钮），
              // 一键把账户填充为原账单的资产账户；手动改选走左侧胶囊。
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _fillRefundOriginalAccount,
                  borderRadius: BorderRadius.circular(13),
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ForestBg.sunken,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: _Sage.hairline),
                    ),
                    child: const Text(
                      '原账单账户',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _Sage.ink,
                      ),
                    ),
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
      // 原账单变化后，AA 手动改过的收款金额随旧总额失效，恢复自动计算。
      _aaCollectOverrideMinor = null;
    });
  }

  /// 弹出「AA付款」分摊参数弹窗（小青账模板），确认后把参数写回退款表单
  /// 并切到 AA 模式；金额保持「自动」由 [_aaCollectMinor] 计算。
  Future<void> _showAaPaymentSheet() async {
    if (_refundOriginals.isEmpty) {
      _toast('请先选择需要退款的账单');
      return;
    }
    final int totalMinor = _refundOriginalTotalMinor;
    final _AaPaymentResult? result =
        await showModalBottomSheet<_AaPaymentResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) => _AaPaymentSheet(
        totalMinor: totalMinor,
        initial: _AaPaymentResult(
          headcount: _aaHeadcount,
          includeSelf: _aaIncludeSelf,
          collectCount: _aaCollectCount,
          rounding: _aaRounding,
          collectMinor: _aaCollectMinor(totalMinor),
          manual: _aaCollectOverrideMinor != null,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _refundMode = RefundMode.aa;
      _aaHeadcount = result.headcount;
      _aaIncludeSelf = result.includeSelf;
      _aaCollectCount = result.collectCount;
      _aaRounding = result.rounding;
      _aaCollectOverrideMinor = result.manual ? result.collectMinor : null;
    });
  }

  /// 退款模式：AA 付款 / 全额退款（迷你胶囊，置于「退款金额」标题行右侧）。
  ///
  /// 点「AA 付款」弹出分摊参数弹窗（再次点击可重新调整）；
  /// 点「全额退款」直接切换并清除 AA 参数覆盖。
  Widget _refundModePill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[_Sage.sageA, _Sage.sageB],
                  )
                : null,
            color: selected ? null : _Sage.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? Colors.transparent : ForestNeutral.hairline,
              width: selected ? 0 : 1,
            ),
          ),
          child: Text(
            selected ? '✓ $label' : label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? Theme.of(context).colorScheme.onPrimary : _Sage.ink2,
            ),
          ),
        ),
      ),
    );
  }

  /// 退款金额区：标题行（灰字标签 + 右侧 AA付款/全额退款 迷你胶囊）
  /// + 金额奶油卡（¥ 大数 + 右侧「自动/自定义」分段 + 绿点提示行）。
  Widget _buildRefundAmountRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Text(
              '退款金额',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: _Sage.ink2,
              ),
            ),
            const Spacer(),
            _refundModePill(
              label: 'AA 付款',
              selected: _refundMode == RefundMode.aa,
              onTap: _showAaPaymentSheet,
            ),
            const SizedBox(width: 8),
            _refundModePill(
              label: '全额退款',
              selected: _refundMode == RefundMode.full,
              onTap: () => setState(() {
                _refundMode = RefundMode.full;
                _aaCollectOverrideMinor = null;
              }),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildRefundAmountCard(),
      ],
    );
  }

  /// 自动/自定义分段单格（金额卡内迷你款：选中奶油胶囊 + 鼠尾草绿字）。
  Widget _refundAmtSeg(bool isAuto) {
    final bool on = isAuto == _refundAmountAuto;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() {
          _refundAmountAuto = isAuto;
          if (_refundAmountAuto) {
            _refundAmountController.clear();
          }
        }),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: on ? _Sage.card : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: on
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppPalette.ink3.withValues(alpha: 0.18),
                      blurRadius: 5,
                      offset: Offset(0, 1.5),
                    ),
                  ]
                : null,
          ),
          child: Text(
            isAuto ? (on ? '✓ 自动' : '自动') : '自定义',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: on ? _Sage.sageB : _Sage.ink2,
            ),
          ),
        ),
      ),
    );
  }

  /// 金额奶油卡：¥ 前缀 + 正常字号金额（自动=展示 / 自定义=输入），
  /// 输入行右侧为「自动/自定义」迷你分段；AA 模式在底部显示人均入口。
  Widget _buildRefundAmountCard() {
    final int m = _refundAmountMinor;
    final int originalTotal = _refundOriginalTotalMinor;
    final bool isAa = _refundMode == RefundMode.aa && originalTotal > 0;
    return _rbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text(
                '¥',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _Sage.sageB,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _refundAmountAuto
                    ? Text(
                        m <= 0
                            ? '0.00'
                            : Money.fromMinor(m).format(showSymbol: false),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: _Sage.ink,
                        ),
                      )
                    : KeypadField(
                        controller: _refundAmountController,
                        allowDecimal: true,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: _Sage.ink,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          // 显式覆盖所有状态边框 + 透明填充，
                          // 避免主题默认填充色在奶油卡内形成额外背景块。
                          filled: true,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          hintText: '请输入退款金额',
                          hintStyle: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: _Sage.ink3,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
              ),
              const SizedBox(width: 8),
              // 「自动/自定义」分段：移入金额输入框内右侧（深沙容器）。
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: ForestBg.sunken,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _refundAmtSeg(true),
                    _refundAmtSeg(false),
                  ],
                ),
              ),
            ],
          ),
          if (isAa)
            // AA 模式：人均入口行（点文案重新打开 AA 付款弹窗调整分摊参数）。
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: <Widget>[
                  const Spacer(),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _showAaPaymentSheet,
                    child: Text(
                      '每人均 ${Money.fromMinor(_aaPerHeadMinor(originalTotal)).format(showSymbol: false)}'
                      '（${_aaHeadcount}人AA）›',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _Sage.sageB,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 退款备注卡（方案 A 奶油卡内无边框输入，保留线稿信息图标）。
  Widget _buildRefundNoteField() {
    return _rbCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 9),
            child: LineIcon(
              LineIconKind.info,
              size: 17,
              color: _Sage.ink3,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _noteController,
              decoration: InputDecoration(
                isDense: true,
                // 显式覆盖所有状态边框 + 透明填充，
                // 避免主题默认填充色在奶油卡内形成额外背景块。
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                hintText: '备注（选填）',
                hintStyle: const TextStyle(fontSize: 14, color: _Sage.ink3),
              ),
              style: const TextStyle(fontSize: 14, color: _Sage.ink),
              maxLines: 2,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _refundMiniButton(
              '原账单备注',
              onTap: _fillRefundOriginalNote,
            ),
          ),
        ],
      ),
    );
  }

  /// 方案 A 时间卡：深沙圆角图标位 + 「时间/日期时间」两行 + 跳转箭头。
  Widget _buildRefundDateCard() {
    return _rbCard(
      onTap: _pickDate,
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: ForestBg.sunken,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Center(
              child: LineIcon(
                LineIconKind.calendar,
                size: 17,
                color: _Sage.ink2,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  '时间',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _Sage.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(_occurredAt),
                  style: const TextStyle(fontSize: 12.5, color: _Sage.ink2),
                ),
              ],
            ),
          ),
          const LineIcon(
            LineIconKind.chevronRight,
            size: 15,
            color: _Sage.ink3,
          ),
        ],
      ),
    );
  }

  /// 方案 A 账本卡：浅绿渐变图标位 + 账本名 + 跳转箭头。
  /// （与报销区 [_buildRbBookRow] 分离，避免改动波及报销 Tab。）
  Widget _buildRefundBookRow() {
    final AsyncValue<Book?> book = ref.watch(currentBookProvider);
    return _rbCard(
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[AppPalette.sageHaze, AppPalette.sageLine],
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Center(
              child: LineIcon(
                LineIconKind.book,
                size: 17,
                color: _Sage.greenDeep,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            '账本',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _Sage.ink,
            ),
          ),
          const Spacer(),
          Text(
            book.valueOrNull?.name ?? '账本',
            style: const TextStyle(fontSize: 13, color: _Sage.ink2),
          ),
          const SizedBox(width: 4),
          const LineIcon(
            LineIconKind.chevronRight,
            size: 14,
            color: _Sage.ink3,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(List<Category> categories) {
    // 系统分类（借入/借出/转账/报销/退款/分期/存款等）由 ensureNamed 自动
    // 重建挂分类，用户记一笔的分类选择器隐藏，避免污染手动选类。
    final List<Category> parents = categories
        .where((Category c) => c.parentId == null && !c.isSystem)
        .toList(growable: false);

    // 当前选中的分类（父或子）。选中子分类时，主网格对应父格子
    // 自动替换为该子分类的名称/图标并高亮（小青账同款回显交互）。
    Category? selectedCat;
    for (final Category c in categories) {
      if (c.id == _categoryId) {
        selectedCat = c;
        break;
      }
    }

    return GridView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        // 375 宽下格子 ≈60.6×80（设计稿 8+42+6+16+8 内容高），比例 0.76
        childAspectRatio: 0.76,
      ),
      itemCount: parents.length + 1,
      itemBuilder: (BuildContext context, int index) {
        if (index == parents.length) {
          return _CategoryItem(
            label: '设置',
            lineKind: LineIconKind.settings,
            color: AppPalette.textTertiary,
            onTap: () => context.push('/categories'),
          );
        }
        final Category cat = parents[index];
        final int colorIndex = index % AppPalette.chartPalette.length;
        final Color color = cat.colorValue != null
            ? Color(cat.colorValue!)
            : AppPalette.chartPalette[colorIndex];

        // 回显判定：直接选中该父分类，或选中了它的某个子分类
        Category display = cat;
        bool isSelected = false;
        if (selectedCat != null) {
          if (selectedCat.id == cat.id) {
            isSelected = true;
          } else if (selectedCat.parentId != null &&
              selectedCat.parentId == cat.id) {
            display = selectedCat;
            isSelected = true;
          }
        }

        return _CategoryItem(
          label: display.name,
          lineKind: categoryLineKind(display.iconKey),
          fallbackIcon: categoryIconData(display.iconKey),
          color: color,
          selected: isSelected,
          onTap: () => _onCategoryTap(cat, categories),
        );
      },
    );
  }

  void _onCategoryTap(Category parent, List<Category> all) {
    final List<Category> children = all
        .where((Category c) => c.parentId == parent.id && !c.isSystem)
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
          // 已选账户时对齐小青账：chip 显示账户名并高亮；
          // 「不选择具体账户」（空串）等同未选，不高亮。
          label: (_accountId == null || _accountId!.isEmpty)
              ? '账户'
              : (_accountNameOf(_accountId) ?? '账户'),
          icon: LineIconKind.account,
          onTap: _onSelectAccount,
          active: _accountId != null && _accountId!.isNotEmpty,
        ),
      // 编辑模式：updateTransaction 不支持改报销挂账，隐藏报销相关键，
      // 防止「改了却不落库」的假开关。
      if (isExpense && !_isEdit)
        _FunctionItem(
          label: '报销',
          icon: LineIconKind.reimbursement,
          onTap: () => setState(() {
            _isReimbursable = !_isReimbursable;
            // 垫付类支出默认不计入收支与预算，由报销页「报销收入」单独统计；
            // 取消报销时一并恢复，保持该开关与两个排除项状态一致。
            if (_isReimbursable) {
              _excludeFromStats = true;
              _excludeFromBudget = true;
            } else {
              _excludeFromStats = false;
              _excludeFromBudget = false;
            }
          }),
          active: _isReimbursable,
        ),
      // 报销账户：平时隐藏；勾选「报销」后出现在报销键右侧。
      // 已选时对齐账户键口径：chip 显示账户名并高亮。
      if (isExpense && _isReimbursable && !_isEdit)
        _FunctionItem(
          label: _reimbAccountId == null
              ? '报销账户'
              : (_accountNameOf(_reimbAccountId) ?? '报销账户'),
          icon: LineIconKind.account,
          onTap: _onSelectReimbAccount,
          active: _reimbAccountId != null,
        ),
      if (isExpense)
        _FunctionItem(
          // 已设优惠时对齐小青账：chip 显示「优惠50.00」并高亮
          label: _discountAmount == null || _discountAmount!.isEmpty
              ? '优惠'
              : '优惠${Money.tryParse(_discountAmount!).decimal.toStringAsFixed(2)}',
          icon: LineIconKind.discount,
          onTap: _onDiscount,
          active: _discountAmount != null && _discountAmount!.isNotEmpty,
        ),
      _FunctionItem(
        label:
            _attachmentPaths.isEmpty ? '图片' : '图片 ${_attachmentPaths.length}',
        icon: LineIconKind.photo,
        onTap: _onAddImage,
        active: _attachmentPaths.isNotEmpty,
      ),
      // 标签 / 不计收支 / 不计预算：编辑模式不支持改写（updateTransaction
      // 保留原值），隐藏避免假开关；新增模式正常显示。
      if (!_isEdit)
        _FunctionItem(
          label: _tags.isEmpty ? '标签' : '标签 ${_tags.length}',
          icon: LineIconKind.tag,
          onTap: _onAddTag,
        ),
      _FunctionItem(
        // 账本占位：展示当前账本名；多账本切换功能待接入（点击暂不响应）。
        label: ref.watch(currentBookProvider).value?.name ?? '账本',
        icon: LineIconKind.book,
        onTap: () {},
      ),
      // 不计收支 / 不计预算：两颗常驻显示，各自独立切换，互不干涉。
      if (showAccountStats && !_isEdit)
        _FunctionItem(
          label: '不计收支',
          icon: LineIconKind.excludeStats,
          onTap: () => setState(() => _excludeFromStats = !_excludeFromStats),
          active: _excludeFromStats,
        ),
      if (showAccountStats && !_isEdit)
        _FunctionItem(
          label: '不计预算',
          icon: LineIconKind.excludeBudget,
          onTap: () => setState(() => _excludeFromBudget = !_excludeFromBudget),
          active: _excludeFromBudget,
        ),
      // 模板模式：自身就是「新建模板」入口，不再提供「存为模板」键；编辑模式同理隐藏。
      if (!widget.templateMode && !_isEdit)
        _FunctionItem(
          label: '模板',
          icon: LineIconKind.template,
          onTap: _onSaveTemplate,
        ),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
    // A3 设计稿 .chip：图标恒为深墨深墨线稿色 #3E443A；激活时文字与图标统一切
    // 深绿墨 --deep(#2E6B49) + w700；底/描边为浅绿 soft/softBorder。
    final Color labelColor =
        active ? ForestGreen.deep : AppPalette.textSecondary;
    final Color iconColor = active ? ForestGreen.deep : ForestNeutral.deepInk;
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          // A3 设计稿：功能 pill = 奶油卡 + 发丝线；激活 = 浅绿选中底。
          color: active ? ForestGreen.soft : ForestSurface.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? ForestGreen.softBorder : ForestNeutral.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            LineIcon(item.icon, size: 15, color: iconColor),
            const SizedBox(width: 5),
            Text(
              item.label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: labelColor,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              ),
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
    final (String?, String)? result =
        await showModalBottomSheet<(String?, String)>(
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
    if (result == null || !mounted) return;
    final (String? base, String value) = result;
    if (base != null) {
      // 「输入原价和实付」模式：原价 = 交易金额（amountMinor 口径），
      // 同步主页面金额与优惠（优惠 = 原价 − 实付，弹窗内已反推）。
      setState(() {
        _amount = base;
        _pendingAmount = '';
        _pendingOperator = null;
        _discountAmount = value.trim().isEmpty ? null : value.trim();
      });
    } else if (value.trim().isNotEmpty) {
      // 「输入优惠金额」模式：主页面金额不动，仅记录优惠。
      setState(() => _discountAmount = value.trim());
    }
    // 从优惠弹窗返回：自动弹出金额键盘继续记账（弹窗内曾临时收起）。
    if (mounted) {
      FocusManager.instance.primaryFocus?.unfocus();
      if (!_keyboardExpanded) {
        setState(() => _keyboardExpanded = true);
      }
    }
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
      builder: (BuildContext ctx) => AccountPickerSheet(
        // 实时 watch 账户流：资金类账户（排除应收 / 应付对方虚拟账户）
        filter: fundAccountsOnly,
        selectedId: _accountId,
        title: isExpense ? '选择支出账户' : '选择收入账户',
        noneTitle: '不选择具体账户',
        noneSubtitle: '仅计入收支账单，不计入资产',
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
    if (selected == null || !mounted) return;
    if (selected.isEmpty) {
      // 「不选择具体账户」：清空已选账户。
      setState(() => _accountId = null);
      return;
    }
    setState(() => _accountId = selected);
  }

  /// 报销账户选择：仅列出「报销」类型账户（与报销页 _buildReimbursementForm
  /// 的 allowedTypes 同口径），支持「不选择具体账户」清除已选。
  Future<void> _onSelectReimbAccount() async {
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => AccountPickerSheet(
        // 实时 watch 账户流：仅「报销」类型账户（与报销页表单同口径）
        filter: (List<Account> all) => all
            .where((Account a) => a.type == AccountType.reimbursement)
            .toList(growable: false),
        selectedId: _reimbAccountId,
        title: '选择报销账户',
        noneSubtitle: '暂不关联报销账户',
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
    if (selected == null || !mounted) return;
    if (selected.isEmpty) {
      // 「不选择具体账户」：清除已选报销账户。
      setState(() => _reimbAccountId = null);
      return;
    }
    setState(() => _reimbAccountId = selected);
  }

  /// 图片功能键弹窗：复刻「森林手账·鼠尾草绿」账单图片模板（对齐小青账）。
  /// 暖纸皮肤（与设计交付模板 bill-photo-sheet-forest.html FINAL 同源）：
  ///   · 纸底 ForestBg.paper ｜ 奶油卡 ForestSurface.card ｜ 沙底关闭钮 ForestBg.sunken
  ///   · 选中态 = 鼠尾草绿渐变 ForestGradients.sage(#93BF9A→#5F9A6E) + 白字
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
        final List<XFile> picked =
            await ImagePicker().pickMultiImage(imageQuality: 80, limit: remain);
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
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                for (int i = 0; i < _attachmentPaths.length; i++) ...<Widget>[
                  if (i > 0) SizedBox(width: AppDimens.spaceSm),
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
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppPalette.sage800.withValues(alpha: 0.333),
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
                    ? Border.all(color: AppPalette.ctaForest, width: 2.5)
                    : null,
                color: hovered ? AppPalette.stockDown.withValues(alpha: 0.102) : null,
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
    if (selected != null && mounted) {
      setState(() => _tags
        ..clear()
        ..addAll(selected));
    }
    // 从标签弹窗返回：自动弹出金额键盘继续记账（弹窗内曾临时收起）。
    if (mounted) {
      FocusManager.instance.primaryFocus?.unfocus();
      if (!_keyboardExpanded) {
        setState(() => _keyboardExpanded = true);
      }
    }
  }

  /// 模板模式保存：按当前 Tab 校验必填项后，把已填内容打包成
  /// [RecordTemplateDraft] 返回给模板页（不写 Transactions / LendRecords）。
  Future<void> _saveAsTemplate() async {
    final int minor = _amountMinor;
    if (minor <= 0) {
      _toast('请输入大于 0 的金额');
      return;
    }
    switch (_tab) {
      case RecordTab.expense:
      case RecordTab.income:
        // 账户可不选（「不选择具体账户」），模板无需校验账户。
        break;
      case RecordTab.transfer:
        if (_accountId == null || _toAccountId == null) {
          _toast('请选择转出与转入账户');
          return;
        }
        if (_accountId == _toAccountId) {
          _toast('转出与转入账户不能相同');
          return;
        }
      case RecordTab.lend:
        if (_counterpartyController.text.trim().isEmpty && _accountId == null) {
          _toast('请选择或填写对方账户');
          return;
        }
      case RecordTab.reimbursement:
      case RecordTab.refund:
      case RecordTab.savings:
      case RecordTab.installment:
        // 模板模式不开放这些 Tab，理论不可达；兜底直接返回。
        return;
    }
    final RecordTemplateDraft draft = RecordTemplateDraft(
      tabIndex: _tab.index,
      amountMinor: minor,
      discountMinor: _discountMinor,
      accountId: _accountId,
      toAccountId: _tab == RecordTab.transfer ? _toAccountId : null,
      counterparty:
          _tab == RecordTab.lend ? _counterpartyController.text.trim() : null,
      categoryId: _categoryId,
      note: _noteController.text.trim(),
      tags: _tags.isEmpty ? null : jsonEncode(_tags),
      excludeFromStats: _excludeFromStats,
      excludeFromBudget: _excludeFromBudget,
      isReimbursable: _isReimbursable,
    );
    if (!mounted) return;
    Navigator.of(context).pop(draft);
  }

  /// 打开「记一笔模板」面板：可一键套用已有模板，也可进入模板管理页。
  Future<void> _onSaveTemplate() async {
    await RecordTemplateSheet.show(context: context, onApply: _applyTemplate);
  }

  /// 套用模板：填充 Tab / 金额 / 账户 / 分类 / 备注 / 标签 / 开关，
  /// 并让 PageView 跟随切页（否则表单停留在旧 Tab，与 _tab 脱节）。
  void _applyTemplate(RecordTemplate t) {
    final int targetIndex = _tabs.indexOf(RecordTab.values[t.tabIndex]);
    if (targetIndex < 0) return;
    setState(() => _applyTemplateFields(t));
    if ((_pageController.page?.round() ?? targetIndex) != targetIndex) {
      _pageAnimating = true;
      _pageController
          .animateToPage(
            targetIndex,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          )
          .whenComplete(() => _pageAnimating = false);
    }
  }

  bool get _hasExpression =>
      _pendingOperator != null && _pendingAmount.isNotEmpty;

  /// 把模板内容写入表单字段（纯赋值，不 setState、不切页）。
  /// 套模板（[_applyTemplate]）与编辑预填（initState）共用。
  void _applyTemplateFields(RecordTemplate t) {
    _tab = RecordTab.values[t.tabIndex];
    _accountId = t.accountId;
    _toAccountId = t.toAccountId;
    _categoryId = t.categoryId;
    // 模板带示例金额（>0）时直接带入，可再改。
    if (t.amountMinor > 0) {
      _amount = Money.fromMinor(t.amountMinor).decimal.toStringAsFixed(2);
    }
    // 模板带示例优惠（>0）时带入；转账内联输入框文本同步，避免显示脱节。
    if (t.discountMinor > 0) {
      final String d =
          Money.fromMinor(t.discountMinor).decimal.toStringAsFixed(2);
      _discountAmount = d;
      _discountInputController.text = d;
    } else {
      _discountAmount = null;
      _discountInputController.clear();
    }
    _counterpartyController.text = t.counterparty ?? '';
    _noteController.text = t.note ?? '';
    _tags.clear();
    if (t.tags != null && t.tags!.isNotEmpty) {
      final List<dynamic>? decoded = jsonDecode(t.tags!) as List<dynamic>?;
      if (decoded != null) _tags.addAll(decoded.cast<String>());
    }
    _excludeFromStats = t.excludeFromStats;
    _excludeFromBudget = t.excludeFromBudget;
    _isReimbursable = t.isReimbursable;
  }

  Widget _buildInlineAmount() {
    final ThemeData theme = Theme.of(context);
    final String shown = _displayAmount;
    // 设计稿：金额直接落在纸底上，深绿墨色大字（不再包奶油卡）。
    const Color amountColor = ForestGreen.deep;
    final Widget amountRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              // 收起系统键盘，切回自定义数字键盘并指向主金额。
              FocusManager.instance.primaryFocus?.unfocus();
              setState(() {
                _clearFeeKeyboardTarget();
                _keyboardExpanded = true;
              });
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                // ¥ 符号小于数字，基线对齐（同设计稿比例）。
                Text(
                  '¥',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: amountColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    shown,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: amountColor,
                      letterSpacing: 0.5,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            _keyboardExpanded
                ? Icons.keyboard_arrow_down
                : Icons.keyboard_arrow_up,
            size: 22,
          ),
          iconSize: 22,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: _keyboardExpanded ? '收起键盘' : '展开键盘',
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            setState(() {
              _clearFeeKeyboardTarget();
              _keyboardExpanded = !_keyboardExpanded;
            });
          },
        ),
      ],
    );

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
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
        color: AppPalette.textSecondary,
        height: 1,
      ),
    );
  }

  Widget _buildDateNoteRow() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      decoration: BoxDecoration(
        // A3 设计稿：日期备注行 = 深沙底、无边框。
        color: ForestBg.sunken,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
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
    final double bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    if (!_keyboardExpanded) {
      // 折叠态不再保留键盘栏：由金额右侧的按键负责重新展开。
      return const SizedBox.shrink();
    }

    // 工程内键盘按目标分发：默认录主金额；点优惠/手续费/借还利息输入框后切到对应字段。
    final String? target = _feeKeyboardTarget;
    final bool feeMode = target != null;
    final String keypadValue = target == 'discount'
        ? _discountInputController.text
        : target == 'fee'
            ? _feeInputController.text
            : target == 'lendFee'
                ? _lendFeeController.text
                : target == 'rbAmount'
                    ? _rbAmountController.text
                    : _amount;

    return Container(
      margin: EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        0,
        AppDimens.spaceMd,
        AppDimens.spaceSm + bottomSafe,
      ),
      // A3 设计稿：键盘无独立白色面板，按键直接铺在暖纸底上。
      padding: const EdgeInsets.all(AppDimens.spaceSm),
      child: AmountKeypad(
        value: keypadValue,
        enabled: !_saving,
        onChanged: (String v) {
          setState(() {
            if (target == 'discount') {
              _discountInputController.text = v;
              _discountAmount = v.isEmpty ? null : v;
            } else if (target == 'fee') {
              _feeInputController.text = v;
              _feeAmount = v.isEmpty ? null : v;
            } else if (target == 'lendFee') {
              // 借还利息 / 优惠共用一个只读显示框，写入哪个由当前模式决定。
              _lendFeeController.text = v;
              if (_lendFeeInputType == _FeeInputType.fee) {
                _lendFeeAmount = v.isEmpty ? null : v;
              } else {
                _lendDiscountAmount = v.isEmpty ? null : v;
              }
            } else if (target == 'rbAmount') {
              // 报销收入金额：直接写显示框控制器（保存时读取）。
              _rbAmountController.text = v;
            } else {
              _amount = v;
            }
          });
        },
        // 优惠 / 手续费不支持 + - 表达式，运算符与跨字段回退均忽略。
        onOperator: feeMode ? (_) {} : _onOperator,
        onBackspace: feeMode ? () {} : _onBackspace,
        // 模板模式保存即返回、「再记」无意义 → 置 null 置灰；编辑模式同理。
        onSave: () => _save(),
        onSaveAndMore:
            widget.templateMode || _isEdit ? null : () => _save(andMore: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Scaffold(
      // A3 设计稿：整页暖纸底（此前漏设，落成主题默认白底）。
      backgroundColor: ForestBg.paper,
      appBar: AppBar(
        backgroundColor: ForestBg.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
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
                // 模板模式经 MaterialPageRoute push，不走 go_router 返回。
                onPressed: () => widget.templateMode
                    ? Navigator.of(context).pop()
                    : context.pop(),
                tooltip: '返回',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 24,
                  height: 24,
                ),
              ),
              // 返回键→首 Tab 间距 40：首 Tab 左侧 labelPadding 为 18（指示器
              // indicatorPadding 再收 2），故留白 20 抵消，箭头到首个 pill ≈ 40。
              const SizedBox(width: 20),
              Expanded(
                child: Theme(
                  // 覆盖默认 TabBar 点击水波纹，避免与 pill 选中态视觉冲突。
                  data: theme.copyWith(
                    splashFactory: NoSplash.splashFactory,
                    highlightColor: Colors.transparent,
                  ),
                  // A3 设计稿：深沙轨道胶囊（padding 3 + 999 圆角）包住 TabBar，
                  // 选中 pill = 鼠尾草绿渐变 + 投影 + 白字。
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: ForestBg.sunken,
                      borderRadius: BorderRadius.circular(999),
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
                          duration: Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        )
                            .then((_) {
                          _pageAnimating = false;
                        });
                      },
                      tabAlignment: TabAlignment.start,
                      padding: EdgeInsets.zero,
                      // Tab 宽 = 文字28 + labelPadding(18×2)=64；指示器用 tab 模式
                      // 覆盖整个 Tab（label 模式的 tabWidth 不含 labelPadding，
                      // 胶囊会缩成贴文字的圆），再由 indicatorPadding 左右各收 2
                      // → 胶囊 60×34、相邻 pill 间隙 4（对齐 .tabs gap:4px）。
                      labelPadding: const EdgeInsets.symmetric(horizontal: 18),
                      indicatorPadding:
                          const EdgeInsets.symmetric(horizontal: 2),
                      dividerHeight: 0,
                      indicator: BoxDecoration(
                        // 设计稿 .tabs button.on：--sageGrad 135°(#93BF9A→#5F9A6E)
                        gradient: ForestGradients.sage,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: <BoxShadow>[
                          // 设计稿 0 3px 8px rgba(95,154,110,.35)
                          BoxShadow(
                            color: AppPalette.sage600.withValues(alpha: 0.349),
                            offset: Offset(0, 3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Theme.of(context).colorScheme.onPrimary,
                      unselectedLabelColor: ForestNeutral.textSecondary,
                      labelStyle: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle:
                          theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      tabs: _tabs
                          .map(
                            (RecordTab t) => Tab(
                              height: 34,
                              child: Center(child: Text(t.label)),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 40),
              IconButton(
                icon: const LineIcon(LineIconKind.settings, size: 24),
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
            _tab = _tabs[index];
            _categoryId = null;
            _attachmentPaths.clear();
            FocusManager.instance.primaryFocus?.unfocus();
            if (mounted) setState(() {});
          }
        },
        itemCount: _tabs.length,
        // 懒构建：只创建当前页与相邻页，避免首帧一次性构建 8 套完整表单。
        itemBuilder: (BuildContext context, int index) {
          final RecordTab tab = _tabs[index];
          if (tab == RecordTab.installment) {
            return AddInstallmentPage(showAppBar: false);
          } else if (tab == RecordTab.reimbursement) {
            return _KeepAlivePage(
              key: ValueKey<RecordTab>(tab),
              builder: (_) => _buildReimbursementBody(),
            );
          } else if (tab == RecordTab.savings) {
            return _KeepAlivePage(
              key: ValueKey<RecordTab>(tab),
              builder: (_) => _buildSavingsBody(),
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

/// 分类网格项 —— A3 黏土卡规格（对齐 record-page-A3-lineart.html）：
/// 奶油卡 #FFFCF5 + 发丝线边框，图标为 42×42 黏土渐变容器（白→分类彩
/// 双色渐变 + 左上高光斑 + 长投影）内嵌简笔画线稿；选中 = 整卡鼠尾草绿
/// 渐变白字、图标容器转实体分类色、线条转白。
class _CategoryItem extends StatelessWidget {
  const _CategoryItem({
    required this.label,
    required this.color,
    required this.onTap,
    this.lineKind,
    this.fallbackIcon,
    this.selected = false,
  });

  final String label;

  /// 分类色（未选中 = 线稿色 / 选中 = 容器实体色）。
  final Color color;

  /// A3 简笔画线稿（优先）；为 null 时用 [fallbackIcon] 兜底。
  final LineIconKind? lineKind;
  final IconData? fallbackIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
        decoration: BoxDecoration(
          color: selected ? null : ForestSurface.card,
          gradient: selected ? ForestGradients.sage : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.transparent : ForestNeutral.hairline,
          ),
          boxShadow: selected
              ? <BoxShadow>[
                  // 设计稿 rgba(95,154,110,.35)
                  BoxShadow(
                    color: AppPalette.sage600.withValues(alpha: 0.349),
                    offset: Offset(0, 6),
                    blurRadius: 14,
                  ),
                ]
              : <BoxShadow>[
                  // 设计稿 0 1px 2px rgba(60,55,40,.04)
                  BoxShadow(
                    color: AppPalette.ink.withValues(alpha: 0.039),
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _ClayIconTile(
                color: color, selected: selected, child: _buildIcon(context)),
            SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.2,
                // 设计稿 .cat.on .lb：白字 w700（渐变已换 sageGrad 中饱和绿，
                // 白字对比达标；此前浅粉彩渐变下用 ForestSage.ink 属权宜之计）
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Theme.of(context).colorScheme.onPrimary : ForestNeutral.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    // 未选中描边加深：向暖墨色收敛 22%，避免 22px 线稿在高光斑上被冲淡
    final Color iconColor = selected
        ? Theme.of(context).colorScheme.onPrimary
        : Color.lerp(color, AppPalette.ink, 0.22)!;
    if (lineKind != null) {
      return LineIcon(lineKind!, size: 22, color: iconColor);
    }
    return Icon(fallbackIcon ?? Icons.category_outlined,
        size: 22, color: iconColor);
  }
}

/// A3 黏土图标容器：白→分类彩双色渐变软糖底 + 左上高光斑 + 长投影。
/// 选中态转实体分类色、去高光（对齐设计稿 `.va.i3 .cat .ic`）。
class _ClayIconTile extends StatelessWidget {
  const _ClayIconTile({
    required this.color,
    required this.selected,
    required this.child,
  });

  final Color color;
  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 加深黏土底：分类色混入比例 0.32 → 0.5（用户反馈图标整体偏淡）
    final Color tint = Color.lerp(Colors.white, color, 0.5)!; // ignore: no_raw_colors
    return Container(
      width: 42,
      height: 42,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? color : null,
        gradient: selected
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Colors.white, tint], // ignore: no_raw_colors
                stops: const <double>[0, 0.78],
              ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: selected
              ? Colors.transparent
              : Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        ),
        boxShadow: <BoxShadow>[
          // 未选中：设计稿 5px 7px 14px rgba(74,66,46,.20)（微收敛防格间溢出）
          // 选中：0 6px 14px rgba(74,66,46,.22)
          BoxShadow(
            color: AppPalette.ink.withValues(alpha: 0.2),
            offset: selected ? const Offset(0, 6) : const Offset(3, 4),
            blurRadius: selected ? 14 : 10,
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          if (!selected)
            // 左上高光斑：铺满整块的 radial-gradient
            // （circle at 40% 35%, rgba(255,255,255,.92), transparent 70%）。
            // 注意结束色必须用「透明白」而非 Colors.transparent——后者是
            // 透明黑，RGBA 直插值中途会变成半透明灰，在浅底上显示为灰斑。
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: RadialGradient(
                    center: Alignment(-0.2, -0.3),
                    radius: 0.9,
                    colors: <Color>[
                      Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
                      Theme.of(context).colorScheme.surface.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          Center(child: child),
        ],
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
        SizedBox(width: AppDimens.spaceSm),
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
      : AppPalette.primary;

  /// 分类头像：优先手绘 LineIcon，无映射时兜底 Material 图标，
  /// 与记一笔主网格（[_CategoryItem]）视觉一致。
  Widget _categoryLeadIcon(String? iconKey, Color color) {
    final LineIconKind? kind = categoryLineKind(iconKey);
    if (kind != null) {
      return LineIcon(kind, size: 22, color: color);
    }
    return Icon(categoryIconData(iconKey), size: 22, color: color);
  }

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
                    color: Theme.of(context).colorScheme.outline,
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
                      child: _categoryLeadIcon(widget.parent.iconKey, color),
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
                              color: AppPalette.textTertiary,
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
              SizedBox(height: AppDimens.spaceMd),
              if (widget.children.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                  child: Text(
                    '暂无子分类，可选择上方「${widget.parent.name}」，或点右上角「添加」新建',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppPalette.textTertiary,
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
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      shrinkWrap: true,
      crossAxisCount: 5,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.76,
      children: <Widget>[
        for (final Category child in widget.children)
          _CategoryItem(
            label: child.name,
            lineKind: categoryLineKind(child.iconKey),
            fallbackIcon: categoryIconData(child.iconKey),
            color: color,
            selected: child.id == widget.selectedId,
            onTap: () => Navigator.of(context).pop(child.id),
          ),
      ],
    );
  }

  Widget _buildList(ThemeData theme, Color color) {
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      shrinkWrap: true,
      itemCount: widget.children.length,
      itemBuilder: (BuildContext context, int index) {
        final Category child = widget.children[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: _categoryLeadIcon(child.iconKey, color),
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
/// 键盘复用工程标准 [AmountKeypad]（4 列：数字 + 删除/−/+ + 再记/0/•/保存）。
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
    // 优惠前金额预填上一页输入的金额。保持原始字符串（不做 _fmt2 预格式化）：
    // 键盘按字符串追加/删除编辑，若预填成 "100.00"（小数位已满 2 位）会导致
    // 「输入原价和实付」模式下原价无法键入任何数字；0 值（主页面未输金额）归一
    // 为空串，首键直接替换。展示层的两位小数由摘要卡 _fmt2 / 胶囊 _display 兜底。
    final String rawBase = widget.base?.trim() ?? '';
    _base = _toDouble(rawBase) == 0 ? '' : rawBase;
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

  /// 确认回传 (原价, 优惠)：
  /// - 「输入原价和实付」模式：原价是用户显式定义的交易金额，需回传给主页面
  ///   同步金额（amountMinor = 原价，优惠 = 原价 − 实付）；原价为空时不同步
  ///   （此时实付已被钳为 0、优惠为 0，等同未录）。
  /// - 「输入优惠金额」模式：优惠前锁定为上一页金额，主页面金额不动，只回传
  ///   优惠（base 为 null）。
  void _confirm() {
    final String? base =
        _mode == 'original' && _base.trim().isNotEmpty ? _base.trim() : null;
    Navigator.of(context).pop((base, _amt));
  }

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
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppDimens.radiusLg)),
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
            SizedBox(width: 6),
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
            color: on ? ForestGreen.deep : ForestNeutral.textSecondary,
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
          gradient: selected ? ForestGradients.sage : null,
          color: selected ? null : ForestSurface.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppPalette.sage800.withValues(alpha: 0.251) // rgba(46,91,57,.25)
                : ForestNeutral.hairline,
            width: 1.5,
          ),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppPalette.stockDown.withValues(alpha: 0.2), // rgba(60,138,96,.20)
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
                    ? Icon(Icons.check, size: 12, color: Theme.of(context).colorScheme.onPrimary)
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
                color: selected ? Theme.of(context).colorScheme.onPrimary : ForestNeutral.textTertiary,
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
                    style: TextStyle(
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
    final String keypadValue = focused == 'base'
        ? _base
        : focused == 'paid'
            ? _paid
            : _amt;
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
                color: AppPalette.sage800.withValues(alpha: 0.2), // rgba(46,91,57,.20)
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
                      SizedBox(width: 6),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: ForestSurface.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ForestNeutral.hairline),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppPalette.sage900.withValues(alpha: 0.078), // rgba(44,51,41,.08)
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
                          style: TextStyle(
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: ForestGreen.soft,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: focused == 'paid'
                          ? <BoxShadow>[
                              BoxShadow(
                                color: AppPalette.stockDown.withValues(alpha: 0.349), // rgba(46,138,96,.35)
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
                    algoLabel: typingPaid ? 'Ⓢ 优惠后' : 'Ⓢ 优惠前',
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
            child: AmountKeypad(
              value: keypadValue,
              onChanged: _onKey,
              onSave: _confirm,
              onSaveAndMore: null,
              onOperator: null,
              onBackspace: null,
              fourColumns: true,
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
  final LineIconKind icon;
  final VoidCallback onTap;
  final bool? active;
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
                        color: AppPalette.ink3,
                      ),
                    ),
                  ),
                ),
                const Text(
                  '账单图片',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.ink,
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
                          color: AppPalette.ink3,
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
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
            style: const TextStyle(fontSize: 11.5, color: AppPalette.ink3),
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
          SizedBox(height: 4),
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
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppPalette.sage800.withValues(alpha: 0.333),
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
            duration: Duration(milliseconds: 120),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: hovered
                    ? Border.all(color: ForestGreen.deep, width: 2.5)
                    : null,
                color: hovered ? AppPalette.stockDown.withValues(alpha: 0.102) : null,
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
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 22,
                  color: AppPalette.ink3,
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
              child: Icon(Icons.close, size: 12, color: Theme.of(context).colorScheme.onPrimary),
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
            gradient: selected ? ForestGradients.sage : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppPalette.stockDown.withValues(alpha: 0.2),
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
                color: selected ? Theme.of(context).colorScheme.onPrimary : ForestSage.label,
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
    this.color = AppPalette.sandMuted,
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

/// 转账纽带光带（A 方案「光点续流」）。
///
/// S 形鼠尾草渐变曲线连接错位双卡：底层 5px 渐变曲线 + 沿路径流动的
/// 白色光点（PathMetrics 短划线，相位随 [progress] 推进）+ 两端脉动接口节点。
/// 几何与 HTML 设计稿 1:1：26px 高横带内，起点 31% 宽 / y3，终点 69% 宽 / y23。
class _TransferFlowRibbon extends StatelessWidget {
  const _TransferFlowRibbon({required this.progress});

  /// 循环流动动画（0..1 相位）。
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (BuildContext context, Widget? child) => CustomPaint(
        painter: _TransferFlowRibbonPainter(
          t: progress.value,
          surface: Theme.of(context).colorScheme.surface,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _TransferFlowRibbonPainter extends CustomPainter {
  _TransferFlowRibbonPainter({required this.t, required this.surface});

  /// 0..1 循环相位：驱动光点流动与节点脉动。
  final double t;

  /// 高光芯 / 光点使用的表面色（由调用方自主题取）。
  final Color surface;

  static const Color _sage1 = AppPalette.sageMist;
  static const Color _sage2 = AppPalette.sageRibbon;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    // 落点在头像内侧边缘（黄点示意）：头像 48px、卡片水平内边距 14 →
    // 转出卡头像右缘 x=14+48=62，转入卡头像左缘 x=w-62；y 取头像垂直中心
    // （卡高 74 垂直居中 → 37 / 121）。
    final Offset p0 = Offset(62, 37);
    final Offset p1 = Offset(w - 62, 121);
    final Path path = Path()
      ..moveTo(p0.dx, p0.dy)
      ..cubicTo(w * 0.40, 37, w * 0.60, 121, p1.dx, p1.dy);

    // 柔和光晕：同路径粗描边低透明，营造马克笔墨晕。
    final Paint glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = _sage1.withValues(alpha: 0.18);
    canvas.drawPath(path, glow);

    // 主笔触：水平渐变细曲线。
    final Paint base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(colors: <Color>[_sage1, _sage2])
          .createShader(Rect.fromLTWH(0, 0, w, size.height));
    canvas.drawPath(path, base);

    // 高光芯：笔触中央一条细亮线，模拟马克笔的湿润反光。
    final Paint core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = surface.withValues(alpha: 0.45);
    canvas.drawPath(path, core);

    // 光点：沿路径的白色短划线，相位随动画推进形成「续流」。
    final PathMetric metric = path.computeMetrics().first;
    const double dashLen = 3;
    const double cycle = dashLen + 13;
    final double phase = (t % 1) * cycle;
    final Path dots = Path();
    for (double d = -phase; d < metric.length; d += cycle) {
      final double s = d < 0 ? 0 : d;
      final double e =
          d + dashLen < metric.length ? d + dashLen : metric.length;
      if (e > s) dots.addPath(metric.extractPath(s, e), Offset.zero);
    }
    final Paint dotPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = surface.withValues(alpha: 0.95);
    canvas.drawPath(dots, dotPaint);
  }

  @override
  bool shouldRepaint(_TransferFlowRibbonPainter oldDelegate) =>
      oldDelegate.t != t;
}

/// 设计稿同款票券图标（优惠）：两侧半圆缺口 + 中缝三段虚线孔。
///
/// 1:1 复刻 HTML 稿 svg（viewBox 24，描边 1.7，圆头圆角），渲染尺寸 13px。
class _FeeTicketIcon extends StatelessWidget {
  const _FeeTicketIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(13),
      painter: _FeeTicketPainter(color),
    );
  }
}

class _FeeTicketPainter extends CustomPainter {
  const _FeeTicketPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24);
    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    // 票券外轮廓：M3 9 a3 3 0 0 1 0 6 v3 a1 1 ... h16 ... z
    final Path outline = Path()
      ..moveTo(3, 9)
      ..arcToPoint(
        const Offset(3, 15),
        radius: const Radius.circular(3),
        clockwise: true,
      )
      ..lineTo(3, 18)
      ..arcToPoint(
        const Offset(4, 19),
        radius: const Radius.circular(1),
        clockwise: false,
      )
      ..lineTo(20, 19)
      ..arcToPoint(
        const Offset(21, 18),
        radius: const Radius.circular(1),
        clockwise: false,
      )
      ..lineTo(21, 15)
      ..arcToPoint(
        const Offset(21, 9),
        radius: const Radius.circular(3),
        clockwise: true,
      )
      ..lineTo(21, 6)
      ..arcToPoint(
        const Offset(20, 5),
        radius: const Radius.circular(1),
        clockwise: false,
      )
      ..lineTo(4, 5)
      ..arcToPoint(
        const Offset(3, 6),
        radius: const Radius.circular(1),
        clockwise: false,
      )
      ..close();
    canvas.drawPath(outline, p);

    // 中缝虚线孔：M13 7v2 M13 11v2 M13 15v2
    final Path slots = Path()
      ..moveTo(13, 7)
      ..lineTo(13, 9)
      ..moveTo(13, 11)
      ..lineTo(13, 13)
      ..moveTo(13, 15)
      ..lineTo(13, 17);
    canvas.drawPath(slots, p);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FeeTicketPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 设计稿同款圆圈 ¥ 图标（手续费）：细线圆 + ¥ 竖笔与双横杠（右端圆弧钩）。
class _FeeYuanIcon extends StatelessWidget {
  const _FeeYuanIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(13),
      painter: _FeeYuanPainter(color),
    );
  }
}

class _FeeYuanPainter extends CustomPainter {
  const _FeeYuanPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24);
    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    // 外圈：circle cx=12 cy=12 r=9
    canvas.drawPath(
      Path()
        ..addOval(
          Rect.fromCircle(center: const Offset(12, 12), radius: 9),
        ),
      p,
    );

    // ¥：M12 7v10 + 双横杠（M9.5 9.5h3.6 a1.8 ... H9.5 h4 a1.8 ... H9.5）
    final Path yuan = Path()
      ..moveTo(12, 7)
      ..lineTo(12, 17)
      ..moveTo(9.5, 9.5)
      ..lineTo(13.1, 9.5)
      ..arcToPoint(
        const Offset(13.1, 13.1),
        radius: const Radius.circular(1.8),
        clockwise: true,
      )
      ..lineTo(9.5, 13.1)
      ..moveTo(9.5, 13.1)
      ..lineTo(13.5, 13.1)
      ..arcToPoint(
        const Offset(13.5, 16.7),
        radius: const Radius.circular(1.8),
        clockwise: true,
      )
      ..lineTo(9.5, 16.7);
    canvas.drawPath(yuan, p);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FeeYuanPainter oldDelegate) => oldDelegate.color != color;
}

/// 「AA付款」弹窗回传结果：分摊参数 + 本次收款金额。
class _AaPaymentResult {
  const _AaPaymentResult({
    required this.headcount,
    required this.includeSelf,
    required this.collectCount,
    required this.rounding,
    required this.collectMinor,
    required this.manual,
  });

  final int headcount; // 总AA人数
  final bool includeSelf; // 计算方式：包含自己 / 不包含自己
  final int collectCount; // 本次收款人数
  final _AaRounding rounding; // 人均取整方式
  final int collectMinor; // 本次收款金额（分）
  final bool manual; // collectMinor 是否为手动改过的值
}

/// AA 付款分摊弹窗（小青账模板 · ForestSage 皮肤）：
/// 总金额卡（总金额 / 每人均 / 本次收款(约) + 向下·四舍·向上取整）
/// → 总AA人数（横滑胶囊）→ 计算方式（包含/不包含自己）
/// → 本次收款人数 → 鼠尾草渐变「确认」。
class _AaPaymentSheet extends StatefulWidget {
  const _AaPaymentSheet({
    required this.totalMinor,
    required this.initial,
  });

  /// 原账单总额（分），即「总金额」。
  final int totalMinor;

  final _AaPaymentResult initial;

  @override
  State<_AaPaymentSheet> createState() => _AaPaymentSheetState();
}

class _AaPaymentSheetState extends State<_AaPaymentSheet> {
  late int _headcount = widget.initial.headcount;
  late bool _includeSelf = widget.initial.includeSelf;
  late int _collectCount = widget.initial.collectCount;
  late _AaRounding _rounding = widget.initial.rounding;

  /// 手动改过的「本次收款(约)」金额（分）；null = 按参数自动计算。
  /// 任一参数变化时清空，恢复自动。初始值在 [initState] 里取弹窗入参。
  int? _manualMinor;
  final TextEditingController _collectController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initial.manual) {
      _manualMinor = widget.initial.collectMinor;
    }
    _collectController.text =
        Money.fromMinor(_collect).format(showSymbol: false);
  }

  @override
  void dispose() {
    _collectController.dispose();
    super.dispose();
  }

  /// 人均金额（分）：总金额 ÷ 总AA人数，按取整方式取整。
  int get _perHead {
    final int total = widget.totalMinor;
    final int n = _headcount;
    switch (_rounding) {
      case _AaRounding.down:
        return total ~/ n;
      case _AaRounding.half:
        return (2 * total + n) ~/ (2 * n);
      case _AaRounding.up:
        return (total + n - 1) ~/ n;
    }
  }

  /// 本次收款（分）：手动值优先，否则人均 × 本次收款人数。
  int get _collect => _manualMinor ?? _perHead * _collectCount;

  /// 本次收款人数可选项：包含自己只收 1 笔（自己那份直接留存）；
  /// 不包含自己可从 1 到总AA人数中选本次向几人收款。
  List<int> get _collectOptions =>
      List<int>.generate(_includeSelf ? 1 : _headcount, (int i) => i + 1);

  void _syncCollectText() {
    _collectController.text =
        Money.fromMinor(_collect).format(showSymbol: false);
  }

  /// 参数变化：清手动覆盖并重算收款金额。
  void _onParamsChanged(VoidCallback apply) {
    setState(() {
      apply();
      _manualMinor = null;
      // 切换计算方式 / 人数后，收款人数可能越界，钳到可选范围内。
      final List<int> options = _collectOptions;
      if (!options.contains(_collectCount)) {
        _collectCount = options.last;
      }
      _syncCollectText();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _Sage.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewPadding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildAmountCard(context),
                const SizedBox(height: 18),
                _label('总AA人数'),
                const SizedBox(height: 10),
                _buildHeadcountPills(),
                const SizedBox(height: 16),
                _label('计算方式'),
                const SizedBox(height: 10),
                _buildIncludePills(),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    _label('本次收款人数'),
                    const SizedBox(width: 6),
                    const LineIcon(
                      LineIconKind.person,
                      size: 13,
                      color: _Sage.ink2,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildCollectCountPills(),
                const SizedBox(height: 22),
                _buildConfirmButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 头部：左 × 关闭 + 居中标题 ──────────────────────────────────
  Widget _buildHeader() {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          const Text(
            'AA付款',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _Sage.ink,
            ),
          ),
          Positioned(
            left: 16,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: _Sage.cardAlt,
                    shape: BoxShape.circle,
                  ),
                  child: const LineIcon(
                    LineIconKind.close,
                    size: 17,
                    color: _Sage.ink2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 总金额卡：总金额 + 每人均 + 本次收款(约) + 取整胶囊 ─────────
  Widget _buildAmountCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Sage.greenSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '总金额',
                    style: TextStyle(fontSize: 12.5, color: _Sage.ink2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Money.fromMinor(widget.totalMinor).format(),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _Sage.greenDeep,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: <Widget>[
                    const Text(
                      '每人均',
                      style: TextStyle(fontSize: 11.5, color: _Sage.ink2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Money.fromMinor(_perHead).format(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _Sage.greenDeep,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '本次收款(约)',
            style: TextStyle(fontSize: 12, color: _Sage.ink2),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: KeypadField(
                  controller: _collectController,
                  allowDecimal: true,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _Sage.ink,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (String v) {
                    final int? minor = Money.tryParse(v).minor;
                    setState(() {
                      _manualMinor = minor == null || minor <= 0 ? null : minor;
                    });
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _roundingPill('向下', _AaRounding.down),
                    _roundingPill('四舍', _AaRounding.half),
                    _roundingPill('向上', _AaRounding.up),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roundingPill(String label, _AaRounding value) {
    final bool selected = _rounding == value;
    return GestureDetector(
      onTap: () => _onParamsChanged(() => _rounding = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _Sage.greenSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? _Sage.greenDeep : _Sage.ink2,
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: _Sage.ink,
        ),
      );

  // ── 通用胶囊（选中：浅绿底 + 绿描边 + 深绿字） ──────────────────
  Widget _pill({
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _Sage.greenSoft : _Sage.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? _Sage.sageB : ForestNeutral.hairline,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? _Sage.greenDeep : _Sage.ink2,
            ),
          ),
        ),
      ),
    );
  }

  /// 总AA人数：2 ~ 12 人，横向滑动。
  Widget _buildHeadcountPills() {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List<Widget>.generate(11, (int i) {
          final int n = i + 2;
          return Padding(
            padding: EdgeInsets.only(right: i == 10 ? 0 : 8),
            child: _pill(
              text: '$n人',
              selected: _headcount == n,
              onTap: () => _onParamsChanged(() => _headcount = n),
            ),
          );
        }),
      ),
    );
  }

  /// 计算方式：包含自己 / 不包含自己（互斥）。
  Widget _buildIncludePills() {
    return Row(
      children: <Widget>[
        _pill(
          text: '包含自己',
          selected: _includeSelf,
          onTap: () => _onParamsChanged(() => _includeSelf = true),
        ),
        const SizedBox(width: 8),
        _pill(
          text: '不包含自己',
          selected: !_includeSelf,
          onTap: () => _onParamsChanged(() => _includeSelf = false),
        ),
      ],
    );
  }

  /// 本次收款人数：包含自己 → 仅 1 人；不包含自己 → 1 ~ 总AA人数。
  Widget _buildCollectCountPills() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _collectOptions
          .map(
            (int k) => _pill(
              text: '$k人',
              selected: _collectCount == k,
              onTap: () => _onParamsChanged(() => _collectCount = k),
            ),
          )
          .toList(growable: false),
    );
  }

  // ── 确认：鼠尾草渐变全宽胶囊 ──────────────────────────────────
  Widget _buildConfirmButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _confirm,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[_Sage.sageA, _Sage.sageB],
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '确认',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }

  void _confirm() {
    final int collect = _collect;
    if (collect <= 0) {
      showAppToast(context, '本次收款金额需大于 0');
      return;
    }
    Navigator.of(context).pop(
      _AaPaymentResult(
        headcount: _headcount,
        includeSelf: _includeSelf,
        collectCount: _collectCount,
        rounding: _rounding,
        collectMinor: collect,
        manual: _manualMinor != null,
      ),
    );
  }
}
