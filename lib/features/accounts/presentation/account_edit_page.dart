import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocket_ledger/shared/widgets/clay_icon_tile.dart';
import 'package:pocket_ledger/shared/widgets/hairline_card.dart';
import 'package:pocket_ledger/shared/widgets/loading_state.dart';
import 'package:pocket_ledger/theme/app_dimens.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/amount_keypad.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/line_icon_map.dart';
import '../../../shared/widgets/line_icons.dart';
import '../../../theme/app_colors.dart';
import '../../investment/data/investment_repository.dart';
import '../../investment/providers/investment_providers.dart';
import '../data/account_icon.dart';
import '../data/repay_date.dart';
import '../providers/accounts_providers.dart';
import 'account_type_sheet.dart';
import 'bank_picker_sheet.dart';
import 'widgets/repay_date_picker_sheet.dart';

/// 编辑账户页（参照小青账编辑逻辑），按账户类型分流多种布局：
///
/// - **借出 / 借入（应收 / 应付）**：基本信息「借款给谁 / 向谁借」+
///   **借出 / 借入金额**（派生余额，只读展示——由名下未结清借还记录
///   自动计算，保存时仓储层同事务重算，不可手改）；
/// - **投资（基金 / 股票 / 期货 / 现货等）**：基本信息「账户名称」+
///   **投资余额**（派生余额，只读展示——有持仓时取「现金余额 + 名下持仓
///   市值合计」、否则保留账户现金余额；随持仓自动更新，不可手改）；与应收
///   应付同款「派生不变量」约束：落库只记现金，市值由展示层叠加；
/// - **借记卡（银行账户）**：「资产类型」两栏（账户类型 + 银行信息）+
///   基本信息（备注信息 / 银行卡号）+ **资金**（账户余额可手动校正）；
/// - **资金账户（现金 / 微信 / 支付宝等，借记卡除外）**：「资产类型」栏
///   （类型图标 + 类型名）+ 基本信息（用户名 / 账户余额可编辑）；
/// - **负债（信用卡 / 花呗等）**：「资产类型」两栏（信用卡含银行信息）+
///   基本信息 + **资金**（信用额度 / 当前欠款可编辑，剩余额度 = 额度 −
///   欠款自动计算）+ **账单/还款日期**（每月 X 日）；
/// - 共用「其他」：**资产状态** 三态胶囊（使用中 / 隐藏 / 封存）+
///   **计入总资产** 开关；底部整宽「保存」按钮。
///
/// **资产类型区（两栏布局）**：
/// - 第一栏（恒显示）：账户类型选择器，点击弹出两级类型弹层
///   （五大类 → 类下账户类型，见 [showAccountTypeSheet]）；切换类型后
///   整页布局随之切换；
/// - 第二栏（仅银行类账户——借记卡 / 信用卡）：银行信息，点击弹出银行
///   选择弹层（见 [showBankPickerSheet]）；银行类账户的名称即银行名，
///   选银行同步改名；
/// - 非银行类账户只显示第一栏（通栏）。
class AccountEditPage extends ConsumerStatefulWidget {
  const AccountEditPage({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<AccountEditPage> createState() => _AccountEditPageState();
}

class _AccountEditPageState extends ConsumerState<AccountEditPage> {
  late final TextEditingController _nameController;
  // 借记卡模式专用：备注 / 卡号 / 余额（余额为真实值，允许手动校正）。
  late final TextEditingController _noteController;
  late final TextEditingController _cardNumberController;
  late final TextEditingController _balanceController;
  // 负债模式专用：信用额度 + 账单日 / 还款日（当前欠款复用 _balanceController，
  // 负债方向账户约定正余额=欠款）。
  late final TextEditingController _creditLimitController;
  late final TextEditingController _billingDayController;

  /// 还款日设定：两种模式互斥（固定日期 / 免息期）。
  RepayMode _repayMode = RepayMode.fixedDay;
  int? _dueDayValue;
  int? _dueGraceDaysValue;

  /// 当前选中的账户类型（资产类型第一栏可改，初始为账户原类型）；
  /// 整页布局与保存分支都以它为准，实现「改类型即换布局」。
  late AccountType _selectedType;

  /// 银行类账户（借记卡 / 信用卡）的银行名：这类账户没有独立名称字段，
  /// 名称即银行名（新建时由银行选择命名），第二栏展示与修改都走它。
  /// 非银行类账户恒为 null（第二栏隐藏）。
  String? _bankName;

  late AccountStatus _status;
  late bool _includeInTotal;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final Account? account =
        ref.watch(accountByIdProvider(widget.accountId)).valueOrNull;

    if (account == null) {
      return const Scaffold(body: LoadingState());
    }

    _ensureInitialized(account);
    // 布局分支一律以「当前选中的类型」为准（第一栏可改类型 → 换布局）。
    final AccountType type = _selectedType;
    final bool isLend = type == AccountType.lend;
    final bool isDebit = type == AccountType.bankCard;
    final bool isDebt = type.isDebt;
    // 投资账户（基金 / 股票 / 期货 / 现货等）：余额随名下持仓市值派生，
    // 只读展示，与借还同款「派生不变量」约束。
    final bool isInvestment = type.category == AccountCategory.investment;
    // 定期存款：真实余额（非持仓派生），允许手动校正，与资金账户同口径。
    final bool isTimeDeposit = type == AccountType.timeDeposit;
    // 资金账户（现金 / 微信 / 支付宝 / 公积金等，借记卡单独布局）。
    final bool isFund = !isDebit &&
        !isDebt &&
        !isInvestment &&
        type.category == AccountCategory.capital;

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑账户'),
        leading: IconButton(
          icon: const LineGlyph(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(AppDimens.lg),
              children: isDebt
                  ? _debtSections(account)
                  : isDebit
                      ? _debitSections(account)
                      : isTimeDeposit
                          ? _fundSections(account)
                          : isInvestment
                              ? _investmentSections(account)
                              : isFund
                                  ? _fundSections(account)
                                  : _lendSections(account, isLend),
            ),
          ),
          _saveButton(account),
        ],
      ),
    );
  }

  // ---- 借出 / 借入（应收 / 应付）布局 ----

  /// 借出 / 借入（应收 / 应付）布局（参照小青账：区块标题收进卡片内部，
  /// 金额为派生只读字段）。
  List<Widget> _lendSections(Account account, bool isLend) => <Widget>[
        HairlineCard(
          radius: AppDimens.radiusMd,
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _cardTitle('基本信息'),
                _fieldLabel(isLend ? '借款给谁' : '向谁借'),
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.done,
                  decoration: _filledDecoration(),
                ),
                const SizedBox(height: AppDimens.md),
                _fieldLabel(isLend ? '借出金额' : '借入金额'),
                _readOnlyAmount(account.balanceMinor),
                const SizedBox(height: AppDimens.xs),
                Text(
                  '由名下未结清借还记录自动计算，不可手动修改',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.forest.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimens.lg),
        _otherSection(),
      ];

  // ---- 投资（基金 / 股票 / 期货 / 现货等）布局，与应收应付（借还）统一 ----
  //
  // 基本信息：账户名称（可改）+ 投资余额（只读，展示「现金余额 + 名下持仓
  // 市值合计」；随持仓自动更新，不可手改，防派生不变量被覆盖；落库仅记现金）。

  List<Widget> _investmentSections(Account account) {
    final List<InvestmentHolding>? holdings =
        ref.watch(investmentListProvider).valueOrNull;
    int market = 0;
    if (holdings != null) {
      for (final InvestmentHolding h in holdings) {
        if (h.accountId == account.id) market += h.marketValueMinor;
      }
    }
    final int display = account.balanceMinor + market;
    final bool hasHoldings = market != 0;
    return <Widget>[
      HairlineCard(
        radius: AppDimens.radiusMd,
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _cardTitle('基本信息'),
              _fieldLabel('账户名称'),
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.done,
                decoration: _filledDecoration(),
              ),
              const SizedBox(height: AppDimens.md),
              _fieldLabel('投资余额'),
              _readOnlyAmount(display),
              const SizedBox(height: AppDimens.xs),
              Text(
                hasHoldings
                    ? '现金 ${Money.fromMinor(account.balanceMinor)} · 持仓市值 ${Money.fromMinor(market)}（不可手动修改）'
                    : '暂无持仓，显示当前账户现金余额',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.forest.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: AppDimens.lg),
      _otherSection(),
    ];
  }

  // ---- 借记卡（银行账户）布局，参照小青账截图 ----

  List<Widget> _debitSections(Account account) => <Widget>[
        _assetTypeSection(),
        const SizedBox(height: AppDimens.lg),
        _sectionLabel('基本信息'),
        _basicInfoCard(),
        const SizedBox(height: AppDimens.lg),
        _sectionLabel('资金'),
        HairlineCard(
          radius: AppDimens.radiusMd,
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _fieldLabel('账户余额'),
                KeypadField(
                  controller: _balanceController,
                  allowDecimal: true,
                  decoration: _filledDecoration().copyWith(
                    suffixIcon: LineGlyph(
                      Icons.account_balance_wallet_outlined,
                      size: 20,
                      color: context.forest.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimens.lg),
        _otherSection(),
      ];

  // ---- 资金账户（现金 / 微信 / 支付宝等，借记卡除外）布局，参照小青账截图 ----
  //
  // 「资产类型」栏固定展示类型名（现金 / 微信钱包…）；基本信息「用户名」
  // = 账户名、「账户余额」为真实值可手动校正。

  List<Widget> _fundSections(Account account) => <Widget>[
        _assetTypeSection(),
        const SizedBox(height: AppDimens.lg),
        _sectionLabel('基本信息'),
        HairlineCard(
          radius: AppDimens.radiusMd,
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _fieldLabel('用户名'),
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: _filledDecoration(),
                ),
                const SizedBox(height: AppDimens.md),
                _fieldLabel('账户余额'),
                KeypadField(
                  controller: _balanceController,
                  allowDecimal: true,
                  decoration: _filledDecoration().copyWith(
                    suffixIcon: LineGlyph(
                      Icons.account_balance_wallet_outlined,
                      size: 20,
                      color: context.forest.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimens.lg),
        _otherSection(),
      ];

  // ---- 负债（信用卡 / 花呗等）布局，参照小青账截图 ----
  //
  // 资金口径：负债方向账户**正余额 = 当前欠款**（余额为负即多还/溢缴款）；
  // 剩余额度 = 信用额度 − 当前欠款，输入任一可编辑项即自动重算。

  List<Widget> _debtSections(Account account) => <Widget>[
        _assetTypeSection(),
        const SizedBox(height: AppDimens.lg),
        _sectionLabel('基本信息'),
        _basicInfoCard(),
        const SizedBox(height: AppDimens.lg),
        _sectionLabel('资金'),
        HairlineCard(
          radius: AppDimens.radiusMd,
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _fieldLabel('信用额度'),
                KeypadField(
                  controller: _creditLimitController,
                  allowDecimal: true,
                  decoration: _filledDecoration(),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppDimens.md),
                _fieldLabel('当前欠款'),
                KeypadField(
                  controller: _balanceController,
                  allowDecimal: true,
                  decoration: _filledDecoration(),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppDimens.md),
                _fieldLabel('剩余额度'),
                _readOnlyAmount(_remainingLimitMinor),
                const SizedBox(height: AppDimens.xs),
                Row(
                  children: <Widget>[
                    LineGlyph(
                      Icons.info_outline,
                      size: 14,
                      color: context.forest.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '当前欠款 和 信用额度 输入一个即可自动识别计算',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimens.lg),
        _sectionLabel('账单/还款日期'),
        HairlineCard(
          radius: AppDimens.radiusMd,
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _fieldLabel('账单日期'),
                KeypadField(
                  controller: _billingDayController,
                  allowDecimal: false,
                  decoration: _dayDecoration(),
                ),
                const SizedBox(height: AppDimens.md),
                _fieldLabel('还款日'),
                _RepayDateField(
                  mode: _repayMode,
                  dueDay: _dueDayValue,
                  dueGraceDays: _dueGraceDaysValue,
                  onTap: _pickRepayDate,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimens.lg),
        _otherSection(),
      ];

  /// 基本信息（备注 / 银行卡号），借记卡与负债模式共用。
  Widget _basicInfoCard() => HairlineCard(
        radius: AppDimens.radiusMd,
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _fieldLabel('备注信息'),
              TextField(
                controller: _noteController,
                textInputAction: TextInputAction.next,
                decoration: _filledDecoration(),
              ),
              const SizedBox(height: AppDimens.md),
              _fieldLabel('银行卡号'),
              TextField(
                controller: _cardNumberController,
                keyboardType: const TextInputType.numberWithOptions(),
                textInputAction: TextInputAction.done,
                decoration: _filledDecoration(),
              ),
            ],
          ),
        ),
      );

  /// 剩余额度（minor）= 信用额度 − 当前欠款；两项都为空时返回 null（显示 —）。
  int? get _remainingLimitMinor {
    final bool limitEmpty = _creditLimitController.text.trim().isEmpty;
    final bool debtEmpty = _balanceController.text.trim().isEmpty;
    if (limitEmpty && debtEmpty) return null;
    final int limit = Money.tryParse(_creditLimitController.text).minor;
    final int debt = Money.tryParse(_balanceController.text).minor;
    return limit - debt;
  }

  /// 「资产类型」区：两栏布局。
  ///
  /// - 第一栏（恒显示）：账户类型选择器（类型图标 + 类型名），点击弹
  ///   两级类型弹层；切换类型整页布局随之切换；
  /// - 第二栏（仅银行类账户——借记卡 / 信用卡）：银行信息（银行图标 +
  ///   银行名），点击弹银行选择弹层；
  /// - 非银行类账户只显示第一栏（通栏）。
  Widget _assetTypeSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _sectionLabel('资产类型'),
          Row(
            children: <Widget>[
              Expanded(
                child: _AssetColumnCard(
                  icon: accountLineKind(_selectedType) ?? LineIconKind.star,
                  label: _selectedType.label,
                  onTap: _pickAccountType,
                ),
              ),
              if (_isBank) ...<Widget>[
                const SizedBox(width: AppDimens.sm),
                Expanded(
                  child: _AssetColumnCard(
                    icon: LineIconKind.finance,
                    label: _bankName ?? '选择银行',
                    dimmed: _bankName == null,
                    onTap: _pickBank,
                  ),
                ),
              ],
            ],
          ),
        ],
      );

  /// 是否银行类账户（借记卡 / 信用卡）：这类账户有「银行」第二栏。
  bool _isBankType(AccountType type) =>
      type == AccountType.bankCard || type == AccountType.creditCard;

  bool get _isBank => _isBankType(_selectedType);

  /// 第一栏：选择账户类型（两级弹层：五大类 → 类下类型）。
  Future<void> _pickAccountType() async {
    final AccountType? picked =
        await showAccountTypeSheet(context, current: _selectedType);
    if (picked == null || !mounted || picked == _selectedType) return;
    setState(() {
      final bool wasBank = _isBank;
      _selectedType = picked;
      if (_isBankType(picked)) {
        if (!wasBank) {
          // 非银行类 → 银行类：第二栏出现，银行名待选；名称先按类型标签
          // 兜底（选完银行后由银行名覆盖，与新建流程「未选银行用类型名」一致）。
          _bankName = null;
          _nameController.text = picked.label;
        }
        // 银行类 → 银行类：保留原银行名与名称，只换类型。
      } else {
        // 切到非银行类：第二栏隐藏；名称保留（资金等布局内有名称字段可改）。
        _bankName = null;
      }
    });
  }

  /// 第二栏：选择银行（搜索 + 字母索引弹层）。
  ///
  /// 银行类账户没有独立名称字段，**名称即银行名**：选银行同步改名
  /// （「自定义」可输入列表外银行或任意名称）。
  Future<void> _pickBank() async {
    final String? picked =
        await showBankPickerSheet(context, selected: _bankName);
    if (picked == null || !mounted) return;
    setState(() {
      _bankName = picked;
      _nameController.text = picked;
    });
  }

  /// 「其他」区块：资产状态三态 + 计入总资产开关（两种模式共用，
  /// 参照小青账：区块标题收进卡片内部）。
  Widget _otherSection() => HairlineCard(
        radius: AppDimens.radiusMd,
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _cardTitle('其他'),
              _statusRow(),
              const SizedBox(height: AppDimens.md),
              _includeRow(),
            ],
          ),
        ),
      );

  // ---- 初始化（仅在首次拿到账户时回填，避免流刷新覆盖用户输入） ----

  void _ensureInitialized(Account account) {
    if (_initialized) return;
    _nameController = TextEditingController(text: account.name);
    _noteController = TextEditingController(text: account.note ?? '');
    _cardNumberController =
        TextEditingController(text: account.cardNumber ?? '');
    _balanceController = TextEditingController(
      text: Money.fromMinor(account.balanceMinor).decimal.toStringAsFixed(2),
    );
    _creditLimitController = TextEditingController(
      text: account.creditLimitMinor == null
          ? ''
          : Money.fromMinor(account.creditLimitMinor!)
              .decimal
              .toStringAsFixed(2),
    );
    _billingDayController =
        TextEditingController(text: account.billingDay?.toString() ?? '');
    // 还款日：免息期优先（dueGraceDays 非空），否则固定日期（dueDay）。
    if (account.dueGraceDays != null) {
      _repayMode = RepayMode.graceDays;
      _dueGraceDaysValue = account.dueGraceDays;
      _dueDayValue = null;
    } else {
      _repayMode = RepayMode.fixedDay;
      _dueDayValue = account.dueDay;
      _dueGraceDaysValue = null;
    }
    _selectedType = account.type;
    // 银行类账户：现有名称即银行名（如「安阳银行」），直接作为第二栏初值。
    if (_isBankType(_selectedType)) _bankName = account.name;
    _status = account.status;
    _includeInTotal = account.includeInTotal;
    _initialized = true;
  }

  // ---- 区块与字段 ----

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppDimens.sm),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.forest.onSurface,
              ),
        ),
      );

  /// 卡片内部区块标题（参照小青账：标题在卡片内第一行）。
  Widget _cardTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppDimens.md),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.forest.onSurface,
              ),
        ),
      );

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppDimens.xs),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.forest.onSurfaceVariant,
              ),
        ),
      );

  InputDecoration _filledDecoration() => InputDecoration(
        filled: true,
        fillColor: context.forest.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md,
          vertical: AppDimens.sm + 2,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: BorderSide.none,
        ),
      );

  /// 账单日 / 还款日输入框装饰：「每月 X 日」。
  InputDecoration _dayDecoration() => _filledDecoration().copyWith(
        prefixText: '每月',
        suffixText: '日',
      );

  /// 借出 / 借入金额 / 剩余额度：派生值，只读展示（灰底、不可编辑）。
  /// null 显示「—」（如剩余额度在额度与欠款均为空时）。
  Widget _readOnlyAmount(int? balanceMinor) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md,
          vertical: AppDimens.sm + 4,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .onSurfaceVariant
              .withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        child: Text(
          balanceMinor == null ? '—' : Money.fromMinor(balanceMinor).format(),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: context.forest.onSurface,
                fontWeight: FontWeight.w500,
              ),
        ),
      );

  /// 资产状态三态胶囊：使用中 / 隐藏 / 封存。
  Widget _statusRow() {
    final List<AccountStatus> statuses = <AccountStatus>[
      AccountStatus.active,
      AccountStatus.hidden,
      AccountStatus.sealed,
    ];
    return Row(
      children: <Widget>[
        Text(
          '资产状态',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.forest.onSurface,
              ),
        ),
        const SizedBox(width: AppDimens.md),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: AppDimens.sm,
              runSpacing: AppDimens.xs,
              alignment: WrapAlignment.end,
              children: statuses
                  .map(
                    (AccountStatus s) => _StatusPill(
                      label: s.label,
                      selected: _status == s,
                      onTap: () => setState(() => _status = s),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
      ],
    );
  }

  /// 计入总资产开关。
  Widget _includeRow() => Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '计入总资产',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.forest.onSurface,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '是否加入总资产计算',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.forest.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Switch(
            value: _includeInTotal,
            activeThumbColor: AppPalette.primary,
            onChanged: (bool v) => setState(() => _includeInTotal = v),
          ),
        ],
      );

  // ---- 保存 ----

  Widget _saveButton(Account account) => Padding(
        padding: const EdgeInsets.all(AppDimens.lg),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            onPressed: () => _save(account),
            child: const Text('保存', style: TextStyle(fontSize: 16)),
          ),
        ),
      );

  Future<void> _save(Account account) async {
    final String note = _noteController.text.trim();
    // 负债账户的基本信息只有「备注信息 / 银行卡号」，没有账户名称输入框：
    // 备注非空时以备注充当账户名（用户指定口径）；为空则保留原账户名。
    // 其余类型仍以「账户名称」输入框（_nameController）为准。
    final bool noteAsName = _selectedType.isDebt && note.isNotEmpty;
    final String name = noteAsName ? note : _nameController.text.trim();
    if (name.isEmpty) {
      showAppToast(context, '账户名称不能为空');
      return;
    }
    // 账单日：空 = 清除，非法或超出 1-31 视为未填。
    final int? billingDay = _parseDay(_billingDayController.text);
    // 还款日：按当前模式取其一（固定日期 / 免息期互斥）。
    final int? dueDay = _repayMode == RepayMode.fixedDay ? _dueDayValue : null;
    final int? dueGraceDays =
        _repayMode == RepayMode.graceDays ? _dueGraceDaysValue : null;
    // 保存分支以「当前选中的类型」为准（第一栏可能已改类型）。
    final AccountType type = _selectedType;
    // 非负债类型：清掉原负债专属字段（额度 / 账单日 / 还款日），避免从
    // 负债切走后库里留不可见脏数据；本就走非负债分支时是无害的空写。
    const Value<int?> nonDebtFields = Value<int?>(null);
    try {
      if (type.isDebt) {
        // 负债：正余额 = 当前欠款（输入负数即多还/溢缴款）；额度/日期
        // 输入框为空 = 清空（Value(null)），有值 = 设置（Value(x)）。
        final String limitText = _creditLimitController.text.trim();
        await ref.read(accountRepositoryProvider).update(
              id: account.id,
              name: name,
              type: type,
              balanceMinor: Money.tryParse(_balanceController.text).minor,
              creditLimitMinor: Value<int?>(
                limitText.isEmpty ? null : Money.tryParse(limitText).minor,
              ),
              billingDay: Value<int?>(billingDay),
              dueDay: Value<int?>(dueDay),
              dueGraceDays: Value<int?>(dueGraceDays),
              note: _noteController.text.trim(),
              cardNumber: _cardNumberController.text.trim(),
              status: _status,
              includeInTotal: _includeInTotal,
            );
      } else if (type == AccountType.bankCard) {
        // 借记卡：余额为真实值（允许手动校正）；备注 / 卡号传空串即清空
        // （仓储层 `?? before` 仅在 null 时保留现值，空串会正常写入）。
        await ref.read(accountRepositoryProvider).update(
              id: account.id,
              name: name,
              type: type,
              balanceMinor: Money.tryParse(_balanceController.text).minor,
              creditLimitMinor: nonDebtFields,
              billingDay: nonDebtFields,
              dueDay: nonDebtFields,
              dueGraceDays: nonDebtFields,
              note: _noteController.text.trim(),
              cardNumber: _cardNumberController.text.trim(),
              status: _status,
              includeInTotal: _includeInTotal,
            );
      } else if (type.category == AccountCategory.capital) {
        // 资金账户（现金 / 微信 / 支付宝 / 公积金等）：余额为真实值
        // （允许手动校正）；备注 / 卡号不在表单内，不传即保留现值。
        await ref.read(accountRepositoryProvider).update(
              id: account.id,
              name: name,
              type: type,
              balanceMinor: Money.tryParse(_balanceController.text).minor,
              creditLimitMinor: nonDebtFields,
              billingDay: nonDebtFields,
              dueDay: nonDebtFields,
              dueGraceDays: nonDebtFields,
              status: _status,
              includeInTotal: _includeInTotal,
            );
      } else if (type == AccountType.timeDeposit) {
        // 定期存款：余额为真实值（允许手动校正），与资金账户同口径保存。
        await ref.read(accountRepositoryProvider).update(
              id: account.id,
              name: name,
              type: type,
              balanceMinor: Money.tryParse(_balanceController.text).minor,
              creditLimitMinor: nonDebtFields,
              billingDay: nonDebtFields,
              dueDay: nonDebtFields,
              dueGraceDays: nonDebtFields,
              status: _status,
              includeInTotal: _includeInTotal,
            );
      } else if (type.category == AccountCategory.investment) {
        // 投资账户：现金余额（balanceMinor）是存储唯一口径，不随持仓市值
        // 变化；展示层用 displayBalanceWithMarket 叠加市值。此处只保留现金
        // 现值，绝不可把市值写回覆盖现金（此前 bug：编辑即把余额覆盖成市值）。
        await ref.read(accountRepositoryProvider).update(
              id: account.id,
              name: name,
              type: type,
              balanceMinor: account.balanceMinor,
              creditLimitMinor: nonDebtFields,
              billingDay: nonDebtFields,
              dueDay: nonDebtFields,
              dueGraceDays: nonDebtFields,
              status: _status,
              includeInTotal: _includeInTotal,
            );
      } else {
        // 借还账户：余额不传手改值，由仓储层同事务按名下未结清记录重算
        // （防派生不变量被覆盖）；其余字段按表单保存。
        await ref.read(accountRepositoryProvider).update(
              id: account.id,
              name: name,
              type: type,
              balanceMinor: account.balanceMinor,
              creditLimitMinor: nonDebtFields,
              billingDay: nonDebtFields,
              dueDay: nonDebtFields,
              dueGraceDays: nonDebtFields,
              status: _status,
              includeInTotal: _includeInTotal,
            );
      }
      if (!mounted) return;
      showAppToast(context, '已保存');
      context.pop();
    } on AppFailure catch (e) {
      if (mounted) {
        showAppToast(context, e.message);
      }
    }
  }

  /// 解析「每月 X 日」的天数输入：空 = null（清除），1-31 有效，
  /// 其余视为未填（null）。
  int? _parseDay(String text) {
    final int? day = int.tryParse(text.trim());
    if (day == null || day < 1 || day > 31) return null;
    return day;
  }

  /// 打开「还款日」弹窗（固定日期 / 免息期 并行）；返回后回写当前模式与值。
  Future<void> _pickRepayDate() async {
    final RepayDateResult? result = await showRepayDatePickerSheet(
      context,
      initialBillingDay: int.tryParse(_billingDayController.text),
      initialDueDay: _dueDayValue,
      initialDueGraceDays: _dueGraceDaysValue,
    );
    if (result != null && mounted) {
      setState(() {
        _repayMode = result.mode;
        _dueDayValue = result.dueDay;
        _dueGraceDaysValue = result.dueGraceDays;
      });
    }
  }
}

/// 「资产类型」两栏中的单栏卡片：黏土方糖图标 + 名称 + chevron。
///
/// 两栏并排时每栏约半宽，名称超长省略；[dimmed] 为 true（如银行未选）
/// 时名称用次级色显示「选择银行」占位。
class _AssetColumnCard extends StatelessWidget {
  const _AssetColumnCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.dimmed = false,
  });

  final LineIconKind icon;
  final String label;
  final VoidCallback onTap;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return HairlineCard(
      radius: AppDimens.radiusMd,
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.md,
            vertical: AppDimens.sm,
          ),
          child: Row(
            children: <Widget>[
              ClayIconTile(
                size: 40,
                color: AppPalette.primary,
                child: LineIcon(
                  icon,
                  size: 20,
                  color: Color.lerp(
                    AppPalette.primary,
                    theme.colorScheme.onSurface,
                    0.22,
                  )!,
                ),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: dimmed
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.xs),
              LineGlyph(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 资产状态胶囊按钮：选中绿底白字，未选中灰底。
class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppPalette.primary
              : Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected
                ? context.forest.onPrimary
                : context.forest.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// 还款日选择行（编辑/新建负债账户共用）：展示当前还款方式摘要（每月X日 /
/// 账单后N天），点击打开「固定日期 / 免息期」并行弹窗。
class _RepayDateField extends StatelessWidget {
  const _RepayDateField({
    required this.mode,
    this.dueDay,
    this.dueGraceDays,
    required this.onTap,
  });

  final RepayMode mode;
  final int? dueDay;
  final int? dueGraceDays;
  final VoidCallback onTap;

  String get _summary =>
      mode == RepayMode.graceDays ? '账单后${dueGraceDays ?? 0}天' : '每月${dueDay ?? 10}日';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.sm + 4),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _summary,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            LineGlyph(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
