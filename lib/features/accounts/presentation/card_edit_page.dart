import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocket_ledger/shared/widgets/date_picker_sheet.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/sheet_scaffold.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimens.dart';
import '../data/card_store.dart';
import 'bank_picker_sheet.dart';

/// 卡片编辑页：点击详情页「编辑」后进入，或管理页「+」新建进入。
///
/// [cardId] 为 null 表示新建；非 null 表示从 CardStore 按 id 载入并覆盖表单。
/// 布局：大卡片预览 + 表单字段（卡号/银行/别名/发卡组织/有效期/安全码/账单日/免息期/额度等）。
class CardEditPage extends ConsumerStatefulWidget {
  const CardEditPage({super.key, this.cardId});

  final String? cardId;

  @override
  ConsumerState<CardEditPage> createState() => _CardEditPageState();
}

class _CardEditPageState extends ConsumerState<CardEditPage> {
  // 表单控制器（新建时为空，编辑时从 CardStore 按 cardId 载入）。
  final TextEditingController _cardNumber = TextEditingController();
  String _bankName = '';
  final TextEditingController _alias = TextEditingController();
  final TextEditingController _validity = TextEditingController();
  final TextEditingController _cvv = TextEditingController();
  final TextEditingController _billDay = TextEditingController();
  final TextEditingController _repayDays = TextEditingController();
  final TextEditingController _creditLimit = TextEditingController();
  final TextEditingController _cardHolder = TextEditingController();
  final TextEditingController _remark = TextEditingController();

  String _cardOrg = '银联 UnionPay';
  String _currency = '人民币';
  bool _repayReminder = true;
  CardRepayMode _repayMode = CardRepayMode.graceDays;
  // 需求③：固定还款日初始值设为 1（页面显示「点击选择」，弹窗默认选中 1 号）。
  int _repayValue = 1;
  int _billDayValue = 1;
  bool _billDayPicked = false; // 账单日是否真正点击选择过
  bool _repayPicked = false; // 还款日是否真正点击选择过
  bool _bankManuallySet = false; // 银行是否被用户手动选择（优先于卡号自动识别）
  bool _cardOrgManuallySet = false; // 发卡组织是否被用户手动选择（优先于卡号自动识别）

  @override
  void initState() {
    super.initState();
    // 监听卡号输入变化，同步更新大卡片预览
    _cardNumber.addListener(() => setState(() {}));
    final String? id = widget.cardId;
    if (id != null) {
      final CardInfo? card = ref.read(cardStoreProvider.notifier).getById(id);
      if (card != null) {
        _cardNumber.text = card.cardNumber;
        _bankName = card.bankName;
        _alias.text = card.alias;
        _validity.text = card.validity;
        _cvv.text = card.cvv;
        _billDayValue = card.billDay;
        _billDay.text = card.billDayLabel;
        _repayMode = card.repayMode;
        _repayValue = card.repayValue;
        _repayDays.text = card.repayLabel;
        _repayReminder = card.repayReminder;
        _currency = card.currency;
        _creditLimit.text = card.creditLimit;
        _cardHolder.text = card.cardHolder;
        _remark.text = card.remark;
        _cardOrg = card.cardOrg;
        // 编辑既有卡片：账单日/还款日已存在，视为已选。
        _billDayPicked = true;
        _repayPicked = true;
      }
    }
    // 新建：账单日/还款日不预填，由用户点击选择；
    // 若已载入卡号（如编辑），尝试按卡号自动识别银行。
    if (_bankName.isEmpty) {
      final String? bank = identifyBank(_cardNumber.text);
      if (bank != null) _bankName = bank;
    }
    _cardNumber.addListener(_onCardNumberChanged);
  }

  @override
  void dispose() {
    _cardNumber.removeListener(_onCardNumberChanged);
    super.dispose();
  }

  /// 点击表单空白处时收起键盘。
  ///
  /// 若当前焦点落在文本输入控件（[EditableText]）上则保持不变，避免「点输入框
  /// 键盘立刻收起」的误操作；其余情况（点选卡片 / 切到空白 / 滚动）一律收起，
  /// 防止键盘遮挡下方表单字段。
  void _unfocusOnTap() {
    final FocusNode? primary = FocusManager.instance.primaryFocus;
    if (primary == null || primary.hasPrimaryFocus) return;
    final Widget? focused = primary.context?.widget;
    if (focused is EditableText) return;
    primary.unfocus();
  }

  /// 卡号变化时：若用户未手动指定，则实时按卡号自动识别银行与发卡组织。
  void _onCardNumberChanged() {
    if (!_bankManuallySet) {
      final String? bank = identifyBank(_cardNumber.text);
      if (bank != null && bank != _bankName && mounted) {
        setState(() => _bankName = bank);
      }
    }
    if (!_cardOrgManuallySet) {
      final String? org = identifyCardOrg(_cardNumber.text);
      if (org != null && org != _cardOrg && mounted) {
        setState(() => _cardOrg = org);
      }
    }
  }

  /// 表单必填校验。返回 null 表示通过；否则返回缺失项提示文案。
  String? _validate() {
    final List<String> missing = <String>[];
    if (_cardNumber.text.trim().isEmpty) missing.add('卡号');
    // 账单日和还款日改为非必填项
    // if (!_billDayPicked) missing.add('账单日');
    // if (!_repayPicked) missing.add('还款日');
    if (missing.isEmpty) return null;
    return '请完善必填项：${missing.join('、')}';
  }

  /// 弹出账单日选择器（选择每月几号）。共用共享层 [showDayPickerSheet]。
  Future<void> _pickBillDay(BuildContext context) async {
    final RegExp reg = RegExp(r'(\d+)');
    final Match? match = reg.firstMatch(_billDay.text);
    final int initialDay =
        match != null ? int.tryParse(match.group(1)!) ?? 1 : 1;

    final int? result = await showDayPickerSheet(
      context,
      initialDay: initialDay,
    );

    if (result != null && mounted) {
      setState(() {
        _billDayValue = result;
        _billDay.text = '每月$result日';
        _billDayPicked = true;
      });
    }
  }

  /// 弹出还款日/免息期设定弹窗（计算方式并行：固定还款日 / 固定免息期）。
  /// 复用共享层 [showRepayDatePickerSheet]，再将其 [RepayDateResult]
  /// 映射回卡片页自己的 [CardRepayMode] / [_repayValue]（持久化模型不变）。
  Future<void> _pickRepayDays(BuildContext context) async {
    final RepayDateResult? result = await showRepayDatePickerSheet(
      context,
      initialBillingDay: _billDayPicked ? _billDayValue : null,
      initialDueDay: _repayMode == CardRepayMode.fixedDay ? _repayValue : null,
      initialDueGraceDays:
          _repayMode == CardRepayMode.graceDays ? _repayValue : null,
    );

    if (result != null && mounted) {
      final bool isFixed = result.dueDay != null;
      final int value = isFixed ? result.dueDay! : result.dueGraceDays!;
      setState(() {
        _repayMode = isFixed ? CardRepayMode.fixedDay : CardRepayMode.graceDays;
        _repayValue = value;
        _repayDays.text = isFixed ? '每月$value日' : '$value天';
        _repayPicked = true;
      });
    }
  }

  /// 弹出发卡组织选择器。
  Future<void> _pickCardOrg(BuildContext context) async {
    final result = await showAppModalSheet<String>(
      context,
      body: _OptionsPickerSheet(
        title: '发卡组织',
        options: const <String>[
          '银联 UnionPay',
          'Mastercard',
          'VISA',
          '美国运通 AE',
          'JCB',
          '大莱 Diners',
          '发现 Discover',
        ],
        initial: _cardOrg,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _cardOrg = result;
        _cardOrgManuallySet = true; // 手动指定优先于自动识别
      });
    }
  }

  /// 弹出币种选择器。
  Future<void> _pickCurrency(BuildContext context) async {
    final result = await showAppModalSheet<String>(
      context,
      body: _OptionsPickerSheet(
        title: '币种',
        options: const <String>['人民币', '美元', '日元'],
        initial: _currency,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _currency = result;
      });
    }
  }

  /// 弹出银行选择器。复用模块内共享的 [showBankPickerSheet]
  /// （搜索 + 首字母索引 + 自定义银行），而非本地硬编码银行列表。
  ///
  /// 自动识别失败时可手动选择；选「不选择」则清空银行（允许不填，如非银行类卡片）。
  Future<void> _pickBank(BuildContext context) async {
    final String? result = await showBankPickerSheet(
      context,
      selected: _bankName.isEmpty ? null : _bankName,
      allowClear: true,
    );

    if (result == null) return; // 其它方式关闭（如点遮罩）= 不变
    if (mounted) {
      setState(() {
        _bankName = result;
        // 选「不选择」返回空串 → 清空并允许后续按卡号重新自动识别；
        // 选具体银行 → 手动指定优先于自动识别。
        _bankManuallySet = result.isNotEmpty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cardId == null ? '新建' : '编辑'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            onPressed: () {
              final String? error = _validate();
              if (error != null) {
                showAppToast(context, error);
                return;
              }
              final String id = widget.cardId ?? const Uuid().v4();
              final CardInfo card = CardInfo(
                id: id,
                cardNumber: _cardNumber.text.trim(),
                bankName: _bankName.trim(),
                alias: _alias.text.trim(),
                cardOrg: _cardOrg,
                validity: _validity.text.trim(),
                cvv: _cvv.text.trim(),
                billDay: _billDayValue,
                repayMode: _repayMode,
                repayValue: _repayValue,
                repayReminder: _repayReminder,
                currency: _currency,
                creditLimit: _creditLimit.text.trim(),
                cardHolder: _cardHolder.text.trim(),
                remark: _remark.text.trim(),
                cardType: CardType.credit,
              );
              ref.read(cardStoreProvider.notifier).upsert(card);
              context.pop();
            },
          ),
        ],
      ),
      body: GestureDetector(
        // 焦点移走（点空白处 / 切换字段）即收起键盘，避免遮挡下方表单。
        behavior: HitTestBehavior.translucent,
        onTap: _unfocusOnTap,
        child: ListView(
          // 滚动列表时顺手收起键盘，方便查看被遮挡字段。
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(AppDimens.lg),
        children: <Widget>[
          // 大卡片预览
          _CardPreview(
            bankName: _bankName,
            cardNumber: _cardNumber.text,
            cardOrg: _cardOrg,
          ),
          const SizedBox(height: AppDimens.lg),
          // 卡号（占满一行）
          _TextFieldTile(
            label: '卡号',
            controller: _cardNumber,
            suffix: GestureDetector(
              onTap: () => showAppToast(context, '扫描银行卡功能开发中'),
              child: Icon(
                Icons.qr_code_scanner,
                size: 20,
                color: context.forest.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: AppDimens.sm),
          // 银行 + 别名（银行与发卡组织等宽，别名占剩余位置）
          Row(
            children: <Widget>[
              Expanded(
                flex: 1,
                child: _ClickableTile(
                  label: '银行',
                  value: _bankName.isEmpty ? '请选择' : _bankName,
                  onTap: () => _pickBank(context),
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Expanded(
                flex: 2,
                child: _TextFieldTile(
                  label: '别名',
                  controller: _alias,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.sm),
          // 发卡组织 + 有效期 + 安全码（3列）
          Row(
            children: <Widget>[
              Expanded(
                child: _ClickableTile(
                  label: '发卡组织',
                  value: _cardOrg,
                  onTap: () => _pickCardOrg(context),
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Expanded(
                child: _TextFieldTile(
                  label: '有效期 MM/YY',
                  controller: _validity,
                  keyboardType: TextInputType.datetime,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                    _ExpiryDateFormatter(),
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Expanded(
                child: _TextFieldTile(
                  label: '安全码',
                  controller: _cvv,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.sm),
          // 账单日 + 还款日 + 还款日提醒（3列）
          Row(
            children: <Widget>[
              Expanded(
                child: _ClickableTile(
                  label: '账单日',
                  value: _billDayPicked ? _billDay.text : '点击选择',
                  onTap: () => _pickBillDay(context),
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Expanded(
                child: _ClickableTile(
                  label: _repayMode == CardRepayMode.fixedDay ? '还款日' : '免息期',
                  value: _repayPicked ? _repayDays.text : '点击选择',
                  onTap: () => _pickRepayDays(context),
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Expanded(
                child: _ClickableTile(
                  label: '还款日提醒',
                  value: _repayReminder ? '已开启' : '已关闭',
                  onTap: () => setState(() => _repayReminder = !_repayReminder),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.sm),
          // 币种 + 固定额度 + 持卡人（3列）
          Row(
            children: <Widget>[
              Expanded(
                child: _ClickableTile(
                  label: '币种',
                  value: _currency,
                  onTap: () => _pickCurrency(context),
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Expanded(
                child: _TextFieldTile(
                  label: '固定额度',
                  controller: _creditLimit,
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Expanded(
                child: _TextFieldTile(
                  label: '持卡人',
                  controller: _cardHolder,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.sm),
          // 备注（所有类型）
          _TextFieldTile(
            label: '备注',
            controller: _remark,
            maxLines: 1,
          ),
        ],
        ),
      ),
    );
  }
}

/// 大卡片预览。
class _CardPreview extends StatelessWidget {
  const _CardPreview({
    required this.bankName,
    required this.cardNumber,
    required this.cardOrg,
  });

  final String bankName;
  final String cardNumber;
  final String cardOrg;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: context.forest.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  bankName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: context.forest.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: context.forest.surface,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
                child: Text(
                  cardOrg,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.forest.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(flex: 1),
          Center(
            child: Text(
              cardNumber,
              style: theme.textTheme.headlineMedium?.copyWith(
                letterSpacing: 2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }
}

/// 文本输入卡片。
class _TextFieldTile extends StatelessWidget {
  const _TextFieldTile({
    required this.label,
    required this.controller,
    this.suffix,
    this.maxLines = 1,
    this.inputFormatters,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final Widget? suffix;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.md,
        AppDimens.xs,
        AppDimens.md,
        AppDimens.xs,
      ),
      decoration: BoxDecoration(
        color: context.forest.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: context.forest.onSurfaceVariant,
              fontSize: 12,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: controller,
                    maxLines: maxLines,
                    inputFormatters: inputFormatters,
                    keyboardType: keyboardType,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
                if (suffix != null) ...[
                  const SizedBox(width: 8),
                  Center(child: suffix),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 可点击的信息卡片（点击触发选择器，不可直接编辑）。
class _ClickableTile extends StatelessWidget {
  const _ClickableTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.md,
          AppDimens.xs,
          AppDimens.md,
          AppDimens.xs,
        ),
        decoration: BoxDecoration(
          color: context.forest.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                color: context.forest.onSurfaceVariant,
                fontSize: 12,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 弹窗居中标题 + 文字下方短下划线（对标参考图：无整行分隔线、无关闭按钮）。
class _CenteredUnderlineTitle extends StatelessWidget {
  const _CenteredUnderlineTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          text,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: context.forest.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 40,
          height: 2,
          decoration: BoxDecoration(
            color: context.forest.onSurface,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }
}

/// 通用选项选择底部弹窗（字符串选项）。点选即返回，无「确定」按钮。
class _OptionsPickerSheet extends StatelessWidget {
  const _OptionsPickerSheet({
    required this.title,
    required this.options,
    required this.initial,
  });

  final String title;
  final List<String> options;
  final String initial;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _CenteredUnderlineTitle(title),
          const SizedBox(height: AppDimens.lg),
          // 选项列表：居中排布，避免 7 个选项流式时末行孤项左右失衡；
          // 选中态用 Forest 令牌（绿调底 + 绿字 + 绿勾），对比更清晰。
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppDimens.md,
            runSpacing: AppDimens.sm,
            children: <Widget>[
              for (final String option in options)
                ChoiceChip(
                  label: Text(
                    option,
                    style: TextStyle(
                      color: option == initial
                          ? context.forest.primary
                          : context.forest.onSurface,
                      fontWeight: option == initial
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  selected: option == initial,
                  selectedColor: context.forest.primaryContainer,
                  backgroundColor: context.forest.surfaceContainerHighest,
                  checkmarkColor: context.forest.primary,
                  showCheckmark: true,
                  onSelected: (_) => Navigator.pop(context, option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 有效期格式化器：输入四位数字后自动变成 MM/YY 格式。
/// 输入 1228 → 自动变成 12/28。
class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digits.length <= 2) {
      return TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );
    }

    final String month = digits.substring(0, 2);
    final String year = digits.substring(2, digits.length);
    final String formatted = '$month/$year';

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
