import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../../../shared/widgets/line_icon_map.dart';
import '../../../shared/widgets/line_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocket_ledger/shared/widgets/clay_icon_tile.dart';
import 'package:pocket_ledger/shared/widgets/hairline_card.dart';
import 'package:pocket_ledger/shared/widgets/loading_state.dart';
import 'package:pocket_ledger/shared/widgets/text_input_dialog.dart';

import 'package:pocket_ledger/theme/app_dimens.dart';
import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/amount_keypad.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../theme/app_colors.dart';
import '../../investment/data/investment_repository.dart';
import '../../investment/providers/investment_providers.dart';
import '../data/account_icon.dart';
import '../providers/accounts_providers.dart';

/// 编辑账户页（参照小青账编辑逻辑），按账户类型分流多种布局：
///
/// - **借出 / 借入（应收 / 应付）**：基本信息「借款给谁 / 向谁借」+
///   **借出 / 借入金额**（派生余额，只读展示——由名下未结清借还记录
///   自动计算，保存时仓储层同事务重算，不可手改）；
/// - **投资（基金 / 股票 / 期货 / 现货等）**：基本信息「账户名称」+
///   **投资余额**（派生余额，只读展示——有持仓时取「现金余额 + 名下持仓
///   市值合计」、否则保留账户现金余额；随持仓自动更新，不可手改）；与应收
///   应付同款「派生不变量」约束：落库只记现金，市值由展示层叠加；
/// - **借记卡（银行账户）**：「资产类型」卡（银行图标 + 银行名，点击改名）+
///   基本信息（备注信息 / 银行卡号）+ **资金**（账户余额可手动校正）；
/// - **资金账户（现金 / 微信 / 支付宝等，借记卡除外）**：「资产类型」卡
///   （类型图标 + 类型名）+ 基本信息（用户名 / 账户余额可编辑）；
/// - **负债（信用卡 / 花呗等）**：资产类型卡 + 基本信息 + **资金**
///   （信用额度 / 当前欠款可编辑，剩余额度 = 额度 − 欠款自动计算）+
///   **账单/还款日期**（每月 X 日）；
/// - 共用「其他」：**资产状态** 三态胶囊（使用中 / 隐藏 / 封存）+
///   **计入总资产** 开关；底部整宽「保存」按钮。
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
  late final TextEditingController _dueDayController;
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
    final bool isLend = account.type == AccountType.lend;
    final bool isDebit = account.type == AccountType.bankCard;
    final bool isDebt = account.type.isDebt;
    // 投资账户（基金 / 股票 / 期货 / 现货等）：余额随名下持仓市值派生，
    // 只读展示，与借还同款「派生不变量」约束。
    final bool isInvestment =
        account.type.category == AccountCategory.investment;
    // 定期存款：真实余额（非持仓派生），允许手动校正，与资金账户同口径。
    final bool isTimeDeposit = account.type == AccountType.timeDeposit;
    // 资金账户（现金 / 微信 / 支付宝 / 公积金等，借记卡单独布局）。
    final bool isFund = !isDebit &&
        !isDebt &&
        !isInvestment &&
        account.type.category == AccountCategory.capital;

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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        _sectionLabel('资产类型'),
        _assetTypeCard(account),
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
  // 「资产类型」卡固定展示类型名（现金 / 微信钱包…），点击改名即改账户名；
  // 基本信息「用户名」= 账户名、「账户余额」为真实值可手动校正。

  List<Widget> _fundSections(Account account) => <Widget>[
        _sectionLabel('资产类型'),
        _assetTypeCard(account, name: account.type.label),
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        _sectionLabel('资产类型'),
        _assetTypeCard(account),
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                _fieldLabel('还款日期'),
                KeypadField(
                  controller: _dueDayController,
                  allowDecimal: false,
                  decoration: _dayDecoration(),
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

  /// 「资产类型」卡：类型图标 + 名称 + chevron，点击改名。
  /// [name] 覆盖显示文本（资金模式展示类型名而非账户名）。
  Widget _assetTypeCard(Account account, {String? name}) => HairlineCard(
        radius: AppDimens.radiusMd,
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          onTap: () => _renameDialog(account),
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.md),
            child: Row(
              children: <Widget>[
                ClayIconTile(
                  size: 40,
                  color: AppPalette.primary,
                  child: LineIcon(
                    accountLineKind(account.type) ?? LineIconKind.star,
                    size: 20,
                    color: Color.lerp(
                      AppPalette.primary,
                      Theme.of(context).colorScheme.onSurface,
                      0.22,
                    )!,
                  ),
                ),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: Text(
                    name ?? account.name,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                LineGlyph(
                  Icons.chevron_right,
                  size: 22,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      );

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

  /// 改名对话框：借记卡的「银行名」即账户名。
  Future<void> _renameDialog(Account account) async {
    final String? name = await showTextInput(
      context,
      title: '账户名称',
      initialValue: _nameController.text,
    );
    if (name != null && mounted) {
      setState(() => _nameController.text = name);
    }
  }

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
    _dueDayController =
        TextEditingController(text: account.dueDay?.toString() ?? '');
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
                color: Theme.of(context).colorScheme.onSurface,
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
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
      );

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppDimens.xs),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );

  InputDecoration _filledDecoration() => InputDecoration(
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                color: Theme.of(context).colorScheme.onSurface,
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
                color: Theme.of(context).colorScheme.onSurface,
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
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '是否加入总资产计算',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      showAppToast(context, '账户名称不能为空');
      return;
    }
    // 账单日 / 还款日：空 = 清除，非法或超出 1-31 视为未填。
    final int? billingDay = _parseDay(_billingDayController.text);
    final int? dueDay = _parseDay(_dueDayController.text);
    try {
      if (account.type.isDebt) {
        // 负债：正余额 = 当前欠款（输入负数即多还/溢缴款）；额度/日期
        // 输入框为空 = 清空（Value(null)），有值 = 设置（Value(x)）。
        final String limitText = _creditLimitController.text.trim();
        await ref.read(accountRepositoryProvider).update(
              id: account.id,
              name: name,
              type: account.type,
              balanceMinor: Money.tryParse(_balanceController.text).minor,
              creditLimitMinor: Value<int?>(
                limitText.isEmpty ? null : Money.tryParse(limitText).minor,
              ),
              billingDay: Value<int?>(billingDay),
              dueDay: Value<int?>(dueDay),
              note: _noteController.text.trim(),
              cardNumber: _cardNumberController.text.trim(),
              status: _status,
              includeInTotal: _includeInTotal,
            );
      } else if (account.type == AccountType.bankCard) {
        // 借记卡：余额为真实值（允许手动校正）；备注 / 卡号传空串即清空
        // （仓储层 `?? before` 仅在 null 时保留现值，空串会正常写入）。
        await ref.read(accountRepositoryProvider).update(
              id: account.id,
              name: name,
              type: account.type,
              balanceMinor: Money.tryParse(_balanceController.text).minor,
              note: _noteController.text.trim(),
              cardNumber: _cardNumberController.text.trim(),
              status: _status,
              includeInTotal: _includeInTotal,
            );
      } else if (account.type.category == AccountCategory.capital) {
        // 资金账户（现金 / 微信 / 支付宝 / 公积金等）：余额为真实值
        // （允许手动校正）；备注 / 卡号不在表单内，不传即保留现值。
        await ref.read(accountRepositoryProvider).update(
              id: account.id,
              name: name,
              type: account.type,
              balanceMinor: Money.tryParse(_balanceController.text).minor,
              status: _status,
              includeInTotal: _includeInTotal,
            );
      } else if (account.type == AccountType.timeDeposit) {
        // 定期存款：余额为真实值（允许手动校正），与资金账户同口径保存。
        await ref.read(accountRepositoryProvider).update(
              id: account.id,
              name: name,
              type: account.type,
              balanceMinor: Money.tryParse(_balanceController.text).minor,
              status: _status,
              includeInTotal: _includeInTotal,
            );
      } else if (account.type.category == AccountCategory.investment) {
        // 投资账户：现金余额（balanceMinor）是存储唯一口径，不随持仓市值
        // 变化；展示层用 displayBalanceWithMarket 叠加市值。此处只保留现金
        // 现值，绝不可把市值写回覆盖现金（此前 bug：编辑即把余额覆盖成市值）。
        await ref.read(accountRepositoryProvider).update(
              id: account.id,
              name: name,
              type: account.type,
              balanceMinor: account.balanceMinor,
              status: _status,
              includeInTotal: _includeInTotal,
            );
      } else {
        // 借还账户：余额不传手改值，由仓储层同事务按名下未结清记录重算
        // （防派生不变量被覆盖）；其余字段按表单保存。
        await ref.read(accountRepositoryProvider).update(
              id: account.id,
              name: name,
              type: account.type,
              balanceMinor: account.balanceMinor,
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
}

/// 圆角卡片容器（与新增账户页同风格）。

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
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
