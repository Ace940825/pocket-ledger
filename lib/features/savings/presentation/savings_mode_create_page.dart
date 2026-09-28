import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../core/errors/failures.dart';
import '../data/savings_repository.dart';
import '../providers/savings_providers.dart';
import '../../accounts/providers/accounts_providers.dart';
import 'savings_modes.dart';

/// 存钱模式创建页（参照小青账「365天存钱法 / 30天倒数存钱法 /
/// 12月定额存钱法 / 灵活存钱法」独立页面）。
///
/// 从「存钱模式选择」点进模式后进入本页，按截图布局：
/// 介绍 → 存钱信息（头像/名称/备注）→ 金额 →
/// 存钱任务（开始时间；12 月定额额外有「月末」开关；灵活存钱法整区隐藏）→
/// 存钱快捷属性（账本/转出·扣款账户/转至/转入·入款账户）
/// → 底部固定绿色渐变「保存」。
///
/// 落库口径：目标金额 = 模式预设（365 天 = 66795 元、30 天倒数 = 5580 元、
/// 12 月定额 = 起始金额自定、灵活存钱法 = 「目标金额」输入值且已存初值为 0），
/// 起始金额 = 已存金额初值（currentMinor，灵活存钱法固定 0），
/// 截止日 = 开始时间 + 模式预设天数（灵活存钱法无截止日）；
/// 「转入/入款账户」选中后写入 goal.accountId；「转出/扣款账户」仅作
/// 快捷填充选择，暂无对应字段不落库（SavingsGoal 只有 accountId）。
class SavingsModeCreatePage extends ConsumerStatefulWidget {
  const SavingsModeCreatePage({super.key, required this.mode});

  final SavingsMode mode;

  @override
  ConsumerState<SavingsModeCreatePage> createState() =>
      _SavingsModeCreatePageState();
}

class _SavingsModeCreatePageState extends ConsumerState<SavingsModeCreatePage> {
  // 小青账 sage 渐变与森林绿点缀（与存钱模式弹层同色，避免依赖重构中的主题）。
  static const Color _sageA = AppColors.sageMist;
  static const Color _sageB = AppColors.sageRibbon;
  static const Color _greenSoft = AppColors.softGreen;
  static const Color _greenDeep = AppColors.deepGreen;

  late final TextEditingController _nameController;
  late final TextEditingController _noteController;
  late final TextEditingController _amountController;
  late DateTime _startDate;
  bool _monthEnd = true; // 月末开关（12 月定额专属，暂不落库，仅页面态）
  // 重复周期 / 结束方式（定额存钱法专属，暂不落库，仅页面态）。
  String _repeatCycle = '每1天';
  String _endMethod = '按日期结束';
  static const List<String> _repeatCycleOptions = <String>[
    '每1天',
    '每7天',
    '每月1日',
  ];
  static const List<String> _endMethodOptions = <String>[
    '不结束',
    '按次数结束',
    '按日期结束',
  ];
  String? _sourceAccountId; // 转出/扣款账户（快捷填充，暂不落库）
  String? _targetAccountId; // 转入/入款账户（落库到 goal.accountId）
  // 递增系数 / 金额·百分比模式（弹性存钱法专属，暂不落库，仅页面态）。
  late final TextEditingController _elasticRateController;
  bool _elasticPercent = false; // false = 金额模式

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _noteController = TextEditingController();
    // 参照小青账：12 月定额 / 定额默认 100.0，星期 / 52 周 / 弹性默认 10.0，
    // 灵活存钱法默认目标金额 5000.0，其余 1.0。
    _amountController = TextEditingController(
        text: switch (widget.mode) {
      SavingsMode.monthly12 || SavingsMode.fixed => '100.0',
      SavingsMode.weekday ||
      SavingsMode.weeks52 ||
      SavingsMode.elastic =>
        '10.0',
      SavingsMode.flexible => '5000.0',
      _ => '1.0',
    });
    // 递增系数默认 2.0（参照小青账示例）。
    _elasticRateController = TextEditingController(text: '2.0');
    _startDate = DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    _amountController.dispose();
    _elasticRateController.dispose();
    super.dispose();
  }

  // ---- 模式文案 ----

  /// 「介绍」区块的完整玩法说明（对标小青账：比如：第1天存1元…）。
  /// 多段用空行分隔（倒数 30 天 = 玩法 / 优点 / 适用人群 三段式）。
  String get _introText => switch (widget.mode) {
        SavingsMode.fixed365 => '比如：第1天存1元，第2天存2元，依次类推，每递增1元，'
            '第365天存365元。1年下来能存下66795元。',
        SavingsMode.countdown30 => '每月1号存30元，2号存29元，依次递减，到30号存1元。'
            '每个月这样存，1年可以存下5580元。\n\n'
            '优点：每月时间越往后，存款金额越低，压力越小，容易坚持下来。\n\n'
            '适用于：青年儿童，逐步培养他们的存钱意识；学生党。',
        SavingsMode.monthly12 => '全年12个月，将工资卡绑定一个定期定额扣款工具，或者存定期。\n\n'
            '每次存入固定金额，存一年后查看该账户（可以是余额宝之类的）。'
            '届时，不需要钱的话，继续续存定额存单或其他理财产品。\n\n'
            '适用于：各类人群，可以根据自己的收入设定月存款金额。',
        SavingsMode.weekday => '星期一存10元，星期二存20元，依次递增到星期天存70元，'
            '每周可存下280元。坚持一年可以存下14560元。\n\n'
            '优点：存钱周期短，金额小。\n\n'
            '适用于：月光族、学生党、刚参加工作的职场新人、'
            '想存点私房钱的宝妈、宝爸。',
        SavingsMode.weeks52 => '每周存一笔钱。第一周存10元，第二周存20元，每周多存10元，'
            '依此类推，第52周存520元。52周刚好是一年，一年可以存13780元。\n\n'
            '优点：这样存款不会有太大的压力。存款最后的一个月也才2020元钱。\n\n'
            '适用于：月光族、学生党、刚参加工作的职场新人、'
            '想存点私房钱的宝妈、宝爸。',
        SavingsMode.fixed => '每次存入固定金额，存N日期后查看该账户（可以是余额宝之类的）。'
            '届时，不需要钱的话，继续续存定额存单或其他理财产品。\n\n'
            '优点：利率不错，收益稳定；比如定期每月都有一张存单到期，'
            '资金比较灵活，需要用钱的时候好周转。\n\n'
            '适用于：各类人群，可以根据自己的收入设定月存款金额。',
        SavingsMode.flexible => '灵活存钱法不需要设置很多，只需要一个目标、目标金额，'
            '选个配图即可开始存钱计划。',
        SavingsMode.elastic => '弹性存钱模式可以设置存钱持续天数，递增系数 N。'
            '下一次存钱金额比上一次多N金额。\n\n'
            '比如： 起始金额10元，递增系数2；第一天存10元，'
            '第二天存12元，第三天存14元，依此类推。',
        _ => widget.mode.description,
      };

  /// 金额区标签：灵活存钱法输入的是「目标金额」，其余模式为「起始金额」。
  bool get _isFlexible => widget.mode == SavingsMode.flexible;

  /// 弹性存钱法专属：递增系数 + 金额/百分比模式。
  bool get _isElastic => widget.mode == SavingsMode.elastic;

  // ---- 构建 ----

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.surfaceMist,
      appBar: AppBar(
        title: Text(widget.mode.label),
        centerTitle: true,
        backgroundColor: AppColors.surfaceMist,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: <Widget>[
                _section(
                  title: '介绍',
                  children: <Widget>[
                    _infoRow(theme, _introText),
                  ],
                ),
                const SizedBox(height: 14),
                _section(
                  title: '存钱信息',
                  children: <Widget>[
                    _avatarRow(),
                    const SizedBox(height: 12),
                    _roundedField(
                      controller: _nameController,
                      hint: '名称(最多15字符)',
                      maxLength: 15,
                    ),
                    const SizedBox(height: 12),
                    _roundedField(
                      controller: _noteController,
                      hint: '备注(最多150字符)',
                      maxLength: 150,
                      maxLines: 3,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _section(
                  title: '金额',
                  children: <Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 6),
                        child: Text(
                          // 灵活存钱法：目标金额；其余模式：起始金额。
                          _isFlexible ? '目标金额' : '起始金额',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                        ),
                      ),
                    ),
                    _amountField(),
                    // 递增系数：弹性存钱法专属（参照小青账）。
                    if (_isElastic) ...<Widget>[
                      const SizedBox(height: 14),
                      _elasticRateRow(),
                      const SizedBox(height: 12),
                      _infoRow(theme, _elasticFormulaText),
                    ],
                  ],
                ),
                // 存钱任务：灵活存钱法无开始时间/周期概念，整区隐藏。
                if (!_isFlexible) ...<Widget>[
                  const SizedBox(height: 14),
                  _section(
                    title: '存钱任务',
                    children: <Widget>[
                      // 重复周期：定额存钱法专属（参照小青账）。
                      if (widget.mode == SavingsMode.fixed) ...<Widget>[
                        _pickOptionRow(
                          icon: Icons.task_alt,
                          title: '重复周期',
                          subtitle: '根据一定规则存钱',
                          value: _repeatCycle,
                          options: _repeatCycleOptions,
                          onPicked: (String v) =>
                              setState(() => _repeatCycle = v),
                        ),
                        const SizedBox(height: 4),
                      ],
                      _startDateRow(),
                      // 月末开关：12 月定额专属（参照小青账）。
                      if (widget.mode == SavingsMode.monthly12) ...<Widget>[
                        const SizedBox(height: 4),
                        _monthEndRow(),
                      ],
                      // 结束方式：定额 / 弹性存钱法专属（参照小青账）。
                      if (widget.mode == SavingsMode.fixed ||
                          widget.mode == SavingsMode.elastic) ...<Widget>[
                        const SizedBox(height: 4),
                        _pickOptionRow(
                          icon: Icons.schedule,
                          title: '结束方式',
                          subtitle: '根据规则结束此任务',
                          value: _endMethod,
                          options: _endMethodOptions,
                          onPicked: (String v) =>
                              setState(() => _endMethod = v),
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                _section(
                  title: '存钱快捷属性',
                  children: <Widget>[
                    _infoRow(
                      theme,
                      '快捷属性适用于完成存钱任务快捷填充属性使用。',
                    ),
                    const SizedBox(height: 12),
                    _bookRow(),
                    const SizedBox(height: 12),
                    _accountPills(),
                  ],
                ),
              ],
            ),
          ),
          // 底部固定「保存」。
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[_sageA, _sageB],
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: SizedBox(
                  height: 48,
                  child: Center(
                    child: TextButton(
                      onPressed: _save,
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                      ),
                      child: const Text(
                        '保存',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 小节卡片：绿色竖条标题 + 内容。
  Widget _section({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 4,
                height: 15,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[_sageA, _sageB],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  /// ⓘ 信息行（灰字说明）。
  Widget _infoRow(ThemeData theme, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMist,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline,
              size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 头像行（🐱 圆角头像，对标小青账）。
  Widget _avatarRow() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: _greenSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: const Text('🐱', style: TextStyle(fontSize: 30)),
      ),
    );
  }

  /// 圆角灰底输入框（名称 / 备注）。
  Widget _roundedField({
    required TextEditingController controller,
    required String hint,
    required int maxLength,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 14),
        filled: true,
        fillColor: AppColors.surfaceMist,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    );
  }

  /// 起始金额输入行（💵 图标 + 数字）。
  Widget _amountField() {
    return TextField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(Icons.paid_outlined,
              size: 22, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: AppColors.surfaceMist,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  /// 递增数值说明（弹性存钱法）。
  String get _elasticFormulaText => '递增数值:\n'
      '金额模式每次存钱=上次存钱+递增数值\n'
      '百分比模式每次存钱=上次存钱*递增数值百分比+上次存钱';

  /// 递增系数行（弹性存钱法，参照小青账）：
  /// 「递增系数」标签 + $ 圆标输入框 + 右侧「金额/百分比模式」胶囊。
  Widget _elasticRateRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 6),
          child: Text(
            '递增系数',
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _elasticRateController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 14, right: 10),
                    child: Icon(Icons.currency_yuan_outlined,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                  filled: true,
                  fillColor: AppColors.surfaceMist,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _elasticModeChip(),
          ],
        ),
      ],
    );
  }

  /// 金额/百分比模式切换胶囊：显示当前模式，点击弹底部「选择模式」单选。
  Widget _elasticModeChip() {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _pickElasticMode,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _greenSoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _elasticPercent ? '百分比模式' : '金额模式',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _greenDeep,
          ),
        ),
      ),
    );
  }

  /// 「选择模式」底部弹层：金额模式 / 百分比模式（参照小青账）。
  Future<void> _pickElasticMode() async {
    final bool? percent = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      '选择模式',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 22),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                ],
              ),
              ListTile(
                title: const Text('金额模式',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '上次存钱+递增数值',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                trailing: Icon(Icons.chevron_right,
                    size: 22,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                onTap: () => Navigator.of(ctx).pop(false),
              ),
              ListTile(
                title: const Text('百分比模式',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '上次存钱*递增数值百分比+上次存钱',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                trailing: Icon(Icons.chevron_right,
                    size: 22,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                onTap: () => Navigator.of(ctx).pop(true),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (percent != null && percent != _elasticPercent) {
      setState(() => _elasticPercent = percent);
    }
  }

  /// 开始时间行（闹钟圆标 + 标题/日期 + chevron），点击弹日期选择。
  /// 通用选项行（定额存钱法「重复周期 / 结束方式」，参照小青账）：
  /// 圆标 + 标题/说明 + 右侧当前值 + chevron，点击弹底部单选。
  Widget _pickOptionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required List<String> options,
    required ValueChanged<String> onPicked,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final String? picked = await showModalBottomSheet<String>(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (BuildContext ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    '选择$title',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                ...options.map((String o) => ListTile(
                      title: Text(o, style: const TextStyle(fontSize: 15)),
                      trailing:
                          o == value ? const Icon(Icons.check, size: 20) : null,
                      onTap: () => Navigator.of(ctx).pop(o),
                    )),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
        if (picked != null && picked != value) {
          onPicked(picked);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.surfaceMist,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: AppColors.neutralGray),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                  fontSize: 13.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            Icon(Icons.chevron_right,
                size: 22,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _startDateRow() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _pickStartDate,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.surfaceMist,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.alarm,
                  size: 22, color: AppColors.neutralGray),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '开始时间',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('yyyy年M月d日').format(_startDate),
                    style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 22,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  /// 月末开关行（12 月定额专属，参照小青账）：日历圆标 + 标题/说明 + Switch。
  Widget _monthEndRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: AppColors.surfaceMist,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.calendar_today_outlined,
              size: 20, color: AppColors.neutralGray),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '月末',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '如果选择了28、29、30、31日，当月没有28、29、30、31日时，'
                '则不会执行，如果选中月末，每月会在最后一天执行',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 32,
          child: Switch(
            value: _monthEnd,
            onChanged: (bool v) => setState(() => _monthEnd = v),
            activeColor: Theme.of(context).colorScheme.onPrimary,
            activeTrackColor: _greenDeep,
          ),
        ),
      ],
    );
  }

  /// 账本行（绿色圆标 + 当前账本名 + chevron，只读展示）。
  Widget _bookRow() {
    final Book? book = ref.watch(currentBookProvider).valueOrNull;
    final String bookName = book?.name ?? '默认账本';
    return Row(
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: _greenSoft,
            shape: BoxShape.circle,
          ),
          child: Text(
            bookName.isEmpty ? '账' : bookName.characters.first,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _greenDeep,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '账本',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                bookName,
                style: TextStyle(
                    fontSize: 12.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right,
            size: 22, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ],
    );
  }

  /// 快捷属性账户区：转出账户/扣款账户 → 转至 → 转入账户/入款账户。
  Widget _accountPills() {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _accountPill(
                label: '转出账户',
                accountId: _sourceAccountId,
                onTap: () => _pickSourceAccount(),
              ),
            ),
            const SizedBox(width: 12),
            _labelPill('扣款账户'),
          ],
        ),
        const SizedBox(height: 10),
        // 「转至」分隔 chip。
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceMist,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.currency_yuan,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('转至',
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: _accountPill(
                label: '转入账户',
                accountId: _targetAccountId,
                onTap: () => _pickTargetAccount(),
              ),
            ),
            const SizedBox(width: 12),
            _labelPill('入款账户'),
          ],
        ),
      ],
    );
  }

  /// 账户选择胶囊：未选显示字段名，已选显示账户名（可重选）。
  Widget _accountPill({
    required String label,
    required String? accountId,
    required VoidCallback onTap,
  }) {
    final List<Account> all =
        ref.watch(accountsProvider).valueOrNull ?? const <Account>[];
    Account? acc;
    for (final Account a in all) {
      if (a.id == accountId) {
        acc = a;
        break;
      }
    }
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: acc == null ? AppColors.surfaceMist : _greenSoft,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              acc == null ? Icons.account_balance_wallet_outlined : Icons.check,
              size: 18,
              color: acc == null
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : _greenDeep,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                acc?.name ?? label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: acc == null
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : _greenDeep,
                  fontWeight: acc == null ? FontWeight.w400 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 右侧静态标签胶囊（扣款账户 / 入款账户）。
  Widget _labelPill(String label) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceMist,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }

  // ---- 交互 ----

  Future<void> _pickStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  /// 转出/扣款账户：仅快捷填充，暂不落库。
  Future<void> _pickSourceAccount() async {
    final Account? acc = await _pickAccount();
    if (acc != null) {
      setState(() => _sourceAccountId = acc.id);
    }
  }

  /// 转入/入款账户：落库到 goal.accountId。
  Future<void> _pickTargetAccount() async {
    final Account? acc = await _pickAccount();
    if (acc != null) {
      setState(() => _targetAccountId = acc.id);
    }
  }

  Future<Account?> _pickAccount() {
    final List<Account> accounts =
        ref.read(accountsProvider).valueOrNull ?? const <Account>[];
    return showModalBottomSheet<Account>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  '选择账户',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Flexible(
                child: accounts.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('暂无账户',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: accounts.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 16),
                        itemBuilder: (BuildContext _, int i) {
                          final Account a = accounts[i];
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: _greenSoft,
                              child: Text(
                                a.name.characters.first,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: _greenDeep,
                                ),
                              ),
                            ),
                            title: Text(a.name),
                            onTap: () => Navigator.of(ctx).pop(a),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final String name = _nameController.text.trim().isEmpty
        ? widget.mode.defaultName
        : _nameController.text.trim();
    final String note = _noteController.text.trim().isEmpty
        ? widget.mode.presetNote
        : _noteController.text.trim();
    final double amount = double.tryParse(_amountController.text.trim()) ?? -1;
    if (amount < 0) {
      showAppToast(context, _isFlexible ? '目标金额格式不正确' : '起始金额格式不正确');
      return;
    }
    final int? deadlineAt = widget.mode.presetDeadlineDays == null
        ? null
        : DateTime(_startDate.year, _startDate.month, _startDate.day)
            .add(Duration(days: widget.mode.presetDeadlineDays!))
            .toUtc()
            .millisecondsSinceEpoch;

    // 落库口径：
    // - 灵活存钱法：输入额即目标金额，已存初值 0，无截止日；
    // - 其余模式：目标 = 模式预设（365 天 66795 元），已存初值 = 起始金额。
    final int amountMinor = Money.fromDecimal(amount).minor;
    final int targetMinor = _isFlexible
        ? amountMinor
        : widget.mode.presetTargetMinor ?? amountMinor;
    final int currentMinor = _isFlexible ? 0 : amountMinor;

    try {
      await ref.read(savingsRepositoryProvider).add(
            bookId: ref.read(currentBookIdProvider),
            name: name,
            targetMinor: targetMinor,
            currentMinor: currentMinor,
            accountId: _targetAccountId,
            deadlineAt: deadlineAt,
            note: note,
          );
    } on AppFailure catch (e) {
      if (mounted) showAppToast(context, e.message);
      return;
    } catch (_) {
      if (mounted) showAppToast(context, '保存失败，请稍后重试');
      return;
    }
    if (mounted) {
      showAppToast(context, '已创建「${widget.mode.label}」目标');
      Navigator.of(context).pop();
    }
  }
}
