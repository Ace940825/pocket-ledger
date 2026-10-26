import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/sheet_scaffold.dart';
import '../../../theme/app_dimens.dart';
import '../data/card_store.dart';

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
  final TextEditingController _remark = TextEditingController();

  String _cardOrg = 'UnionPay';
  String _currency = '人民币';
  bool _repayReminder = true;
  CardRepayMode _repayMode = CardRepayMode.graceDays;
  int _repayValue = 50;
  int _billDayValue = 1;
  CardType _cardType = CardType.credit;

  @override
  void initState() {
    super.initState();
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
        _remark.text = card.remark;
        _cardOrg = card.cardOrg;
        _cardType = card.cardType;
      }
    }
    // 兜底：若未被存储数据覆盖，给账单日/还款日一个合法默认值。
    if (_billDay.text.isEmpty) _billDay.text = '每月$_billDayValue日';
    if (_repayDays.text.isEmpty) {
      _repayDays.text = _repayMode == CardRepayMode.fixedDay
          ? '每月$_repayValue日'
          : '$_repayValue天';
    }
  }

  /// 弹出账单日选择器（选择每月几号）。
  Future<void> _pickBillDay(BuildContext context) async {
    final RegExp reg = RegExp(r'(\d+)');
    final Match? match = reg.firstMatch(_billDay.text);
    final int initialDay =
        match != null ? int.tryParse(match.group(1)!) ?? 1 : 1;

    final int? result = await showAppModalSheet<int>(
      context,
      body: _DayPickerSheet(initialDay: initialDay),
    );

    if (result != null && mounted) {
      setState(() {
        _billDayValue = result;
        _billDay.text = '每月$result日';
      });
    }
  }

  /// 弹出还款日/免息期设定弹窗（计算方式并行：固定还款日 / 固定免息期）。
  Future<void> _pickRepayDays(BuildContext context) async {
    final (CardRepayMode, int)? result =
        await showAppModalSheet<(CardRepayMode, int)>(
      context,
      isScrollControlled: true,
      bodyPadding: EdgeInsets.zero,
      body: _RepayMethodSheet(
        initialMode: _repayMode,
        initialValue: _repayValue,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _repayMode = result.$1;
        _repayValue = result.$2;
        _repayDays.text = _repayMode == CardRepayMode.fixedDay
            ? '每月$_repayValue日'
            : '$_repayValue天';
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

  /// 弹出银行选择器（常用银行列表）。
  Future<void> _pickBank(BuildContext context) async {
    final result = await showAppModalSheet<String>(
      context,
      body: _OptionsPickerSheet(
        title: '银行',
        options: const <String>[
          '工商银行',
          '建设银行',
          '农业银行',
          '中国银行',
          '交通银行',
          '招商银行',
          '邮政储蓄银行',
          '兴业银行',
          '中信银行',
          '光大银行',
          '浦发银行',
          '民生银行',
          '广发银行',
          '平安银行',
          '北京银行',
          '上海银行',
        ],
        initial: _bankName,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _bankName = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            onPressed: () {
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
                remark: _remark.text.trim(),
                cardType: _cardType,
              );
              ref.read(cardStoreProvider.notifier).upsert(card);
              context.pop();
            },
          ),
        ],
      ),
      body: ListView(
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
            suffix: IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () => showAppToast(context, '扫描银行卡功能开发中'),
            ),
          ),
          const SizedBox(height: AppDimens.sm),
          // 银行 + 别名（2列）
          Row(
            children: <Widget>[
              Expanded(
                child: _ClickableTile(
                  label: '银行',
                  value: _bankName.isEmpty ? '请选择' : _bankName,
                  onTap: () => _pickBank(context),
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Expanded(
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
                  value: _billDay.text,
                  onTap: () => _pickBillDay(context),
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Expanded(
                child: _ClickableTile(
                  label: '还款日',
                  value: _repayDays.text,
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
          // 币种 + 固定额度（2列）
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
            ],
          ),
          const SizedBox(height: AppDimens.sm),
          // 备注（占满一行）
          _TextFieldTile(
            label: '备注',
            controller: _remark,
            maxLines: 2,
          ),
        ],
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
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                bankName,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
                child: Text(
                  cardOrg,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: Text(
              cardNumber,
              style: theme.textTheme.headlineMedium?.copyWith(
                letterSpacing: 2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
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
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.md,
        AppDimens.xs,
        AppDimens.md,
        AppDimens.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: AppDimens.xs),
          TextField(
            controller: controller,
            maxLines: maxLines,
            inputFormatters: inputFormatters,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              suffixIcon: suffix,
              contentPadding: EdgeInsets.zero,
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
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
    final ThemeData theme = Theme.of(context);

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
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: AppDimens.xs),
            Row(
              children: <Widget>[
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
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
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 40,
          height: 2,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }
}

/// 日期选择底部弹窗（选择每月几号）。点选即返回，无「确定」按钮。
class _DayPickerSheet extends StatelessWidget {
  const _DayPickerSheet({required this.initialDay});

  final int initialDay;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const _CenteredUnderlineTitle('账单日'),
          const SizedBox(height: AppDimens.lg),
          // 日期网格（7列，1-31号）
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppDimens.sm,
            crossAxisSpacing: AppDimens.sm,
            childAspectRatio: 1,
            children: <Widget>[
              for (int day = 1; day <= 31; day++)
                _DayCell(
                  day: day,
                  selected: day == initialDay,
                  onTap: () => Navigator.pop(context, day),
                ),
            ],
          ),
          const SizedBox(height: AppDimens.sm),
          // 右下角「不选择」
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '不选择',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 日期格子。
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final int day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? theme.colorScheme.onSurface : Colors.transparent,
        ),
        child: Text(
          '$day',
          style: theme.textTheme.titleMedium?.copyWith(
            color: selected
                ? theme.colorScheme.surface
                : theme.colorScheme.onSurface,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// 还款日 / 免息期合并设定弹窗（对标参考图：居中下划线标题 + 计算方式胶囊切换
/// + 7 列数字网格（两种模式通用）+ 底部「确定」居中、「不选择」右下）。点选不立即返回，
/// 由「确定」回写 (计算方式, 选中值)。
class _RepayMethodSheet extends StatefulWidget {
  const _RepayMethodSheet({
    required this.initialMode,
    required this.initialValue,
  });

  /// 初始计算方式。
  final CardRepayMode initialMode;

  /// 初始选中值（免息期 = 天数；固定还款日 = 每月第几号）。
  final int initialValue;

  @override
  State<_RepayMethodSheet> createState() => _RepayMethodSheetState();
}

class _RepayMethodSheetState extends State<_RepayMethodSheet> {
  late CardRepayMode _mode;
  late int _selectedValue;

  @override
  void initState() {
    super.initState();
    // 两种计算方式共用同一个选中数字（1-31），切换模式时选中态不跳动
    _mode = widget.initialMode;
    _selectedValue = widget.initialValue.clamp(1, 31);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // 居中标题 + 文字下方短下划线
            const _CenteredUnderlineTitle('还款日'),
            const SizedBox(height: AppDimens.md),
            // 计算方式切换：固定还款日 / 固定免息期（切换键整体右对齐）
            Row(
              children: <Widget>[
                Text(
                  '计算方式：',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                _ModeCapsule(
                  label: '固定还款日',
                  selected: _mode == CardRepayMode.fixedDay,
                  onTap: () => setState(() => _mode = CardRepayMode.fixedDay),
                ),
                const SizedBox(width: AppDimens.sm),
                _ModeCapsule(
                  label: '固定免息期',
                  selected: _mode == CardRepayMode.graceDays,
                  onTap: () => setState(() => _mode = CardRepayMode.graceDays),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.md),
            // 内容区：两种计算方式共用同一 7 列数字网格（选中态不随模式切换跳动）
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppDimens.sm,
              crossAxisSpacing: AppDimens.sm,
              childAspectRatio: 1,
              children: <Widget>[
                for (int day = 1; day <= 31; day++)
                  _DayCell(
                    day: day,
                    selected: day == _selectedValue,
                    onTap: () => setState(() => _selectedValue = day),
                  ),
              ],
            ),
            const SizedBox(height: AppDimens.md),
            // 底部：确定（居中主操作）+ 不选择（右下）
            Row(
              children: <Widget>[
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context, (_mode, _selectedValue));
                      },
                      child: Text(
                        '确定',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    '不选择',
                    style: TextStyle(color: scheme.onSurfaceVariant),
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

/// 计算方式切换胶囊：选中 = 浅底深字（白底黑字观感），未选中 = 纯文字。
class _ModeCapsule extends StatelessWidget {
  const _ModeCapsule({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? scheme.onSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: selected ? scheme.surface : scheme.onSurface,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
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
    final ThemeData theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _CenteredUnderlineTitle(title),
          const SizedBox(height: AppDimens.lg),
          // 选项列表
          Wrap(
            spacing: AppDimens.sm,
            runSpacing: AppDimens.sm,
            children: <Widget>[
              for (final String option in options)
                ChoiceChip(
                  label: Text(option),
                  selected: option == initial,
                  onSelected: (_) => Navigator.pop(context, option),
                ),
            ],
          ),
          const SizedBox(height: AppDimens.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '不选择',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
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
