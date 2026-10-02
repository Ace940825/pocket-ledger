/// 账户选择 Bottom Sheet（A 模板落地）
///
/// 数据来源：森林手账 / 鼠尾草绿 A 模板，已按本项目配色与 Account 模型适配。
/// 支持网格卡片 + 列表切换、不选择具体账户、资产管理、添加账户。
/// 账户列表实时 watch 账户流（accountsProvider）：在弹窗内新建 / 改名 / 删除
/// 账户后列表即时刷新，无需「重新加载」或重开弹窗。
/// 调用方通过 [AccountPickerSheet.filter] 声明可选项口径（资金类 / 应收应付 /
/// 报销账户等），过滤在每次流推送后重新套用。

import 'dart:async';

import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_dimens.dart';
import '../../../core/theme/forest_design_tokens.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../providers/recording_settings_provider.dart';
import 'default_asset_settings_sheet.dart';

// ───────────────────── 模板专属微调色（token 未覆盖的精确值，保持与设计一致） ─────────────────────

/// 资金类账户列表：排除「应收 / 应付」对方虚拟账户。
/// 借还 tab 的借入/借出账户选择器单独按 payable/receivable 展示，不受影响。
List<Account> fundAccountsOnly(List<Account> list) => list
    .where((Account a) =>
        a.type.category != AccountCategory.payable &&
        a.type.category != AccountCategory.receivable)
    .toList();

class _SheetA {
  // 卡片描边 rgba(44,51,41,.07)
  static Color cardBorder = AppPalette.sage900.withValues(alpha: 0.071);
  // 选中卡边框 rgba(46,91,57,.25)
  static Color selBorder = AppPalette.sage800.withValues(alpha: 0.251);
  // 选中卡阴影 rgba(60,138,96,.20)
  static List<BoxShadow> selShadow = <BoxShadow>[
    BoxShadow(color: AppPalette.stockDown.withValues(alpha: 0.2), blurRadius: 14, offset: Offset(0, 4)),
  ];
  // 选中态加深余额色（浅绿底保证对比）
  static const Color selPos = AppPalette.pickerGreen;
  static const Color selNeg = AppPalette.pickerRed;
  // 关闭按钮灰绿（= transfer）
  static const Color closeIcon = AppPalette.ink3;
  // 次要文字
  static const Color dueText = AppPalette.ink3;
}

// ───────────────────── Bottom Sheet 组件 ─────────────────────

/// 账户列表过滤器：入参为账户流全量（未删除、未归档），返回该弹窗的可选项。
/// 过滤在每次账户流推送后重新套用——弹窗内新建的账户只要符合口径立即出现。
typedef AccountListFilter = List<Account> Function(List<Account> all);

class AccountPickerSheet extends ConsumerStatefulWidget {
  /// 可选项过滤口径；null = 展示全部未删除账户。
  final AccountListFilter? filter;

  /// 选中态可二选一传入：资金账户按 [selectedId] 记忆（各 tab 通用），
  /// 对方账户（应付/应收）按名称输入框记忆，传 [selectedName]。
  final String? selectedName;
  final String? selectedId;
  final String title;
  final String noneTitle;
  final String? noneSubtitle;
  final VoidCallback? onManage;
  final VoidCallback? onAdd;

  /// 确认回调：带回完整账户对象；「不选择具体账户」回 null。
  final ValueChanged<Account?> onConfirm;

  /// 标题栏是否显示齿轮键（打开「默认选择资产设置」）。
  /// 作为二级弹窗（如从默认选择资产设置里再选账户）时传 false。
  final bool showSettings;

  /// 是否显示「不选择具体账户」行。转账 / 借还 / 报销 / 退款等
  /// 账户必选的场景传 false 隐藏。
  final bool showNoneRow;

  /// 冲突账户 id（如转账另一端已选账户）：点到该账户时不确认、不关弹窗，
  /// 在弹窗内以提示条展示 [conflictMessage]（约 2.4s 自动消退）。
  final String? conflictId;
  final String conflictMessage;

  const AccountPickerSheet({
    super.key,
    this.filter,
    this.selectedName,
    this.selectedId,
    this.title = '选择账户',
    this.noneTitle = '不选择具体账户',
    this.noneSubtitle,
    this.onManage,
    this.onAdd,
    this.showSettings = true,
    this.showNoneRow = true,
    this.conflictId,
    this.conflictMessage = '不能选择相同账户',
    required this.onConfirm,
  });

  @override
  ConsumerState<AccountPickerSheet> createState() => _AccountPickerSheetState();
}

class _AccountPickerSheetState extends ConsumerState<AccountPickerSheet> {
  /// 弹窗内提示条文案（如点到了冲突账户）；null = 不显示。
  String? _hint;
  Timer? _hintTimer;

  /// 当前视图是否为列表（记忆在 recordingSettingsProvider，重开弹窗不丢）。
  bool get _listView =>
      ref.watch(recordingSettingsProvider).accountPickerListView;

  void _toggleListView() {
    ref
        .read(recordingSettingsProvider.notifier)
        .setAccountPickerListView(!_listView);
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  /// 实时账户列表：订阅账户流（watch 账户流），弹窗内新建 / 改名 / 删除
  /// 账户即时反映；先滤掉已删除账户，再套用调用方的 [AccountPickerSheet.filter]。
  List<Account> get _items {
    final List<Account> all =
        ref.watch(accountsProvider).valueOrNull ?? const <Account>[];
    final List<Account> alive =
        all.where((Account a) => !a.deleted).toList(growable: false);
    final AccountListFilter? f = widget.filter;
    return f == null ? alive : f(alive);
  }

  /// 当前高亮账户名（账户按名称记忆，兼容对方账户按名称匹配）：
  /// 优先按 [AccountPickerSheet.selectedId] 从实时列表解析（资金账户按 id 记忆），
  /// 找不到或未传时回退 [AccountPickerSheet.selectedName]（应付/应收对方账户）。
  String? get _selected {
    final List<Account> items = _items;
    if (widget.selectedId != null) {
      for (final Account a in items) {
        if (a.id == widget.selectedId) return a.name;
      }
    }
    return widget.selectedName;
  }

  /// 把内部选中的名称解析回账户对象；空 / 找不到时回 null（= 不选择）。
  Account? _accountOf(String? name) {
    if (name == null || name.isEmpty) return null;
    for (final Account a in _items) {
      if (a.name == name) return a;
    }
    return null;
  }

  void _pick(String? name) {
    final String? value = name?.isEmpty == true ? null : name;
    final Account? acc = _accountOf(value);
    // 冲突账户（如转账另一端已选）：不确认、不关弹窗，弹窗内就地提示。
    if (acc != null &&
        widget.conflictId != null &&
        acc.id == widget.conflictId) {
      _hintTimer?.cancel();
      setState(() => _hint = widget.conflictMessage);
      _hintTimer = Timer(const Duration(milliseconds: 2400), () {
        if (mounted) setState(() => _hint = null);
      });
      return;
    }
    widget.onConfirm(acc);
  }

  @override
  Widget build(BuildContext context) {
    // 桌面端默认会给可滚动区域挂系统滚动条，这里全局关掉
    final ScrollBehavior behavior =
        ScrollConfiguration.of(context).copyWith(scrollbars: false);
    return ScrollConfiguration(
      behavior: behavior,
      child: Container(
        decoration: BoxDecoration(
          color: ForestBg.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: ForestElevation.sheet,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // 拖拽条
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: AppPalette.sage800.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              _buildHeader(),
              // 弹窗内提示条（冲突提示等），出现时把主体轻轻下推。
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _hint == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppPalette.pickerCream,
                            border: Border.all(color: AppPalette.pickerClay),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(
                                Icons.info_outline,
                                size: 15,
                                color: AppPalette.clayBrown,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _hint!,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppPalette.clayBrown,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              _buildBody(),
              if (widget.showNoneRow) _buildNoneRow(),
              _buildOps(),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }

  // ── 标题栏：关闭 / 标题 / 齿轮（记账设置） / 列表 / 添加 ──
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Row(
        children: <Widget>[
          _IconBtn(
            icon: Icons.close,
            color: _SheetA.closeIcon,
            onTap: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 10),
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.02,
              color: ForestNeutral.textPrimary,
            ),
          ),
          const Spacer(),
          // 齿轮键：打开「默认选择资产设置」（区别于记账页面设置）
          if (widget.showSettings)
            _IconBtn(
              icon: Icons.settings_outlined,
              color: ForestGreen.cta,
              onTap: () => DefaultAssetSettingsSheet.show(context),
            ),
          if (widget.showSettings) const SizedBox(width: 10),
          _PillBtn(
            label: _listView ? '≡ 网格' : '≡ 列表',
            ghost: true,
            onTap: _toggleListView,
          ),
          const SizedBox(width: 8),
          _PillBtn(
            label: '＋ 添加',
            primary: true,
            onTap: widget.onAdd,
          ),
        ],
      ),
    );
  }

  // ── 账户主体（网格或列表） ──
  Widget _buildBody() {
    final List<Account> items = _items;
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Text(
          '暂无账户，点击右上角添加',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: ForestNeutral.textTertiary),
        ),
      );
    }

    // 主体区域高度与网格模式统一：最多显示 2 行卡（94*2+6=194），不足 4 卡时按行数自适应
    // （卡内文字已加 height:1.2 收紧行距，信用卡四行内容约 72px，94 卡高内不溢出）
    final int rows = (items.length + 1) ~/ 2;
    final double bodyHeight = rows >= 2 ? 94 * 2 + 6 : 94.0 * rows;

    if (_listView) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 3, 14, 6),
        child: SizedBox(
          height: bodyHeight,
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: 56,
            ),
            itemBuilder: (BuildContext ctx, int index) {
              final Account account = items[index];
              final bool selected = _selected == account.name;
              final Money money = Money.fromMinor(
                account.balanceMinor,
                currency: account.currency,
              );
              return _ListRow(
                account: account,
                selected: selected,
                money: money,
                amountColor: _amountColor(money, selected),
                onTap: () => _pick(account.name),
              );
            },
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 3, 14, 6),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // 统一卡高 94（定稿值）：信用卡内容靠 height:1.2 行距收紧适配，避免溢出
          const double gap = 6; // 网格间距
          const double cardHeight = 94;
          final double cardWidth = (constraints.maxWidth - gap) / 2;
          // 高度与列表模式统一（bodyHeight：最多 2 行 4 卡，超出内部滚动）
          return SizedBox(
            height: bodyHeight,
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
              childAspectRatio: cardWidth / cardHeight,
              padding: EdgeInsets.zero,
              children: items.map((Account account) {
                final bool selected = _selected == account.name;
                return _AccountTile(
                  account: account,
                  selected: selected,
                  onTap: () => _pick(account.name),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  // ── 「不选择具体账户」独立行 ──
  Widget _buildNoneRow() {
    final bool selected = _selected == null || _selected!.isEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: InkWell(
        onTap: () => _pick(null),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 48, // 与列表行同高
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: ForestBg.sunken,
            border: Border.all(
              color: selected ? ForestGreen.deep : AppPalette.sage900.withValues(alpha: 0.141),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: ForestSurface.raised,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.block,
                  size: 16,
                  color: ForestAccent.gold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.noneTitle,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? ForestGreen.deep
                            : ForestNeutral.textPrimary,
                      ),
                    ),
                    if (widget.noneSubtitle != null)
                      Text(
                        widget.noneSubtitle!,
                        style: const TextStyle(
                          fontSize: 10.5,
                          height: 1.2,
                          color: _SheetA.dueText,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 操作区：资产管理（账户列表实时刷新，无需手动重新加载） ──
  Widget _buildOps() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: _OpBtn(
        label: '资产管理',
        primary: false,
        onTap: widget.onManage,
      ),
    );
  }

  Color _amountColor(Money money, bool selected) {
    if (selected) {
      if (money.isPositive) return _SheetA.selPos;
      if (money.isNegative) return _SheetA.selNeg;
      return ForestNeutral.textPrimary;
    }
    if (money.isPositive) return ForestSemantic.income;
    if (money.isNegative) return ForestSemantic.expense;
    return ForestNeutral.textPrimary;
  }
}

// ───────────────────── 列表行（紧凑） ─────────────────────

class _ListRow extends StatelessWidget {
  final Account account;
  final bool selected;
  final Money money;
  final Color amountColor;
  final VoidCallback onTap;

  const _ListRow({
    required this.account,
    required this.selected,
    required this.money,
    required this.amountColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: <Widget>[
            _AccountAvatar(account: account),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                account.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ForestNeutral.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              money.format(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: amountColor,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
            if (selected) ...<Widget>[
              const SizedBox(width: 8),
              const Icon(
                Icons.check_circle,
                size: 20,
                color: ForestSage.ink,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ───────────────────── 账户卡 ─────────────────────

class _AccountTile extends StatelessWidget {
  final Account account;
  final bool selected;
  final VoidCallback onTap;

  const _AccountTile({
    required this.account,
    required this.selected,
    required this.onTap,
  });

  Color _amountColor(Money money) {
    if (selected) {
      if (money.isPositive) return _SheetA.selPos;
      if (money.isNegative) return _SheetA.selNeg;
      return ForestNeutral.textPrimary;
    }
    if (money.isPositive) return ForestSemantic.income;
    if (money.isNegative) return ForestSemantic.expense;
    return ForestNeutral.textPrimary;
  }

  @override
  Widget build(BuildContext context) {
    final Money money = Money.fromMinor(
      account.balanceMinor,
      currency: account.currency,
    );

    final Widget card = Container(
      constraints: const BoxConstraints(minHeight: 94),
      padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
      decoration: BoxDecoration(
        gradient: selected ? ForestGradients.sageMid : null,
        color: selected ? null : ForestSurface.card,
        border: Border.all(
          color: selected ? _SheetA.selBorder : _SheetA.cardBorder,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: selected ? _SheetA.selShadow : null,
      ),
      child: _CardInner(
        account: account,
        selected: selected,
        money: money,
        amountColor: _amountColor(money),
      ),
    );

    if (!selected) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      );
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: <Widget>[
          card,
          Positioned(
            top: 10,
            right: 12,
            child: SizedBox(
              width: 18,
              height: 18,
              child: Icon(
                Icons.check_circle,
                size: 18,
                color: ForestSage.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardInner extends StatelessWidget {
  final Account account;
  final bool selected;
  final Money money;
  final Color amountColor;

  const _CardInner({
    required this.account,
    required this.selected,
    required this.money,
    required this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color titleColor =
        selected ? ForestSage.ink : ForestNeutral.textPrimary;

    // 信用卡类负债账户（有授信额度）才显示「可用额度 + 还款日」；
    // 借入/借出无额度字段，天然不渲染——从组件树移除而非隐藏（定稿规则）。
    final bool hasQuota = account.creditLimitMinor != null;

    // 余额文本（右对齐）
    final Widget amount = Container(
      width: double.infinity,
      alignment: Alignment.centerRight,
      child: Text(
        money.format(),
        style: TextStyle(
          fontSize: 14,
          height: 1.2, // 模板行距节奏：收紧后信用卡四行内容稳定落在 94 卡高内
          fontWeight: FontWeight.w800,
          color: amountColor,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );

    // 标签行（左对齐）：种类 +（信用卡）还款日
    final Widget meta = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
          decoration: BoxDecoration(
            color: selected ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.549) : ForestGreen.soft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _typeLabel(account.type),
            style: TextStyle(
              fontSize: 10.5,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: selected ? ForestSage.ink : ForestGreen.deep,
            ),
          ),
        ),
        // 仅信用卡（有授信额度）显示还款日；借入/借出虽有 dueDay 字段但不展示（定稿规则）
        if (hasQuota && account.dueDay != null) ...<Widget>[
          const SizedBox(width: 6),
          Text(
            '还款 ${account.dueDay}号',
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.2,
              color: _SheetA.dueText,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          account.name,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: titleColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (hasQuota) ...<Widget>[
          const SizedBox(height: 2),
          _buildQuotaChip(),
        ],
        // 非负债卡：余额下沉贴底（Spacer 在名字之后）；
        // 信用卡：余额紧跟可用额度，Spacer 放在余额之后把标签压到底部
        if (!hasQuota) const Spacer(),
        amount,
        if (hasQuota) const Spacer(),
        const SizedBox(height: 2),
        meta,
      ],
    );
  }

  /// 「可用额度」小签：暖沙底 + 暖褐字（A 模板皮肤）
  Widget _buildQuotaChip() {
    final int availableMinor = account.creditLimitMinor! - account.balanceMinor;
    final Money available = Money.fromMinor(
      availableMinor,
      currency: account.currency,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: ForestSurface.cardAlt,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '可用 ${available.format()}',
        style: TextStyle(
          fontSize: 10,
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: AppPalette.inkWarm,
          fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  String _typeLabel(AccountType type) => type.label;
}

// ───────────────────── 列表头像 ─────────────────────

class _AccountAvatar extends StatelessWidget {
  final Account account;

  const _AccountAvatar({required this.account});

  @override
  Widget build(BuildContext context) {
    final Color color = account.colorValue != null
        ? Color(account.colorValue!)
        : ForestGreen.cta;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Icon(
        _accountIcon(account.type),
        color: Theme.of(context).colorScheme.onPrimary,
        size: 22,
      ),
    );
  }

  IconData _accountIcon(AccountType type) {
    return switch (type.category) {
      AccountCategory.capital => Icons.account_balance_wallet_outlined,
      AccountCategory.investment => Icons.trending_up,
      AccountCategory.debt => Icons.credit_card,
      AccountCategory.receivable => Icons.arrow_circle_up_outlined,
      AccountCategory.payable => Icons.arrow_circle_down_outlined,
    };
  }
}

// ───────────────────── 小组件：图标按钮 / 药丸按钮 / 操作按钮 ─────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: ForestSurface.raised,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: _SheetA.cardBorder, width: 1),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      );
}

class _PillBtn extends StatelessWidget {
  final String label;
  final bool ghost;
  final bool primary;
  final VoidCallback? onTap;

  const _PillBtn({
    required this.label,
    this.ghost = false,
    this.primary = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPrimary = primary && !ghost;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          gradient: isPrimary ? ForestGradients.button : null,
          color: isPrimary ? null : ForestSurface.raised,
          border: Border.all(
            color: isPrimary ? Colors.transparent : _SheetA.cardBorder,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: isPrimary
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppPalette.stockDown.withValues(alpha: 0.278),
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
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isPrimary ? Theme.of(context).colorScheme.onPrimary : ForestGreen.label,
            ),
          ),
        ),
      ),
    );
  }
}

class _OpBtn extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback? onTap;

  const _OpBtn({
    required this.label,
    this.primary = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        flex: primary ? 14 : 10,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              gradient: primary ? ForestGradients.button : null,
              color: primary ? null : ForestSurface.raised,
              border: Border.all(
                color: primary ? Colors.transparent : _SheetA.cardBorder,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: primary
                  ? <BoxShadow>[
                      BoxShadow(
                        color: AppPalette.stockDown.withValues(alpha: 0.278),
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
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: primary ? Theme.of(context).colorScheme.onPrimary : ForestGreen.label,
                ),
              ),
            ),
          ),
        ),
      );
}
