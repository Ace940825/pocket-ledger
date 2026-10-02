import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../core/errors/failures.dart';
import '../data/savings_repository.dart';
import '../../../shared/widgets/amount_keypad.dart';
import '../providers/savings_providers.dart';
import '../../../routing/app_router.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../record/presentation/account_picker_sheet.dart';
import '../../record/providers/recording_settings_provider.dart';
import '../../../shared/widgets/calendar_sheet.dart';
import 'savings_modes.dart';
import 'savings_schedule.dart';

/// 存钱模式创建页（参照小青账「365天存钱法 / 30天倒数存钱法 /
/// 12月定额存钱法 / 灵活存钱法」独立页面）。
///
/// 从「存钱模式选择」点进模式后进入本页，按截图布局：
/// 介绍 → 存钱信息（头像/名称/备注）→ 金额 →
/// 存钱任务（开始时间；12 月定额额外有「月末」开关；灵活存钱法整区隐藏）→
/// 存钱快捷属性（账本/转出·扣款账户/转至/转入·入款账户）
/// → 底部固定绿色渐变「保存」。
///
/// 落库口径：除灵活存钱法（输入=目标金额）外，其余七种模式输入=每期基数 N，
/// 目标 = N × 模式权重（默认周期合计）：365 天 = 66795×N、30 天倒数 = 5580×N、
/// 星期 = 1456×N、52 周 = 1378×N、12 月定额 = 12×N、定额 = 12×N（默认）、
/// 弹性 = 各期递增合计（非均摊）；已存初值固定 0（避免 target == current 误显已完成）；
/// 截止日 = 开始时间 + 模式预设天数（灵活存钱法无截止日）；
/// 「转入/入款账户」选中后写入 goal.accountId；「转出/扣款账户」选中后
/// 写入 goal.sourceAccountId（落库，随计划保存 / 回显）。新计划首开默认
/// 预填 App 默认资产账户，避免转出账户留空。
class SavingsModeCreatePage extends ConsumerStatefulWidget {
  const SavingsModeCreatePage({super.key, required this.mode});

  final SavingsMode mode;

  @override
  ConsumerState<SavingsModeCreatePage> createState() =>
      _SavingsModeCreatePageState();
}

class _SavingsModeCreatePageState extends ConsumerState<SavingsModeCreatePage> {
  // 小青账 sage 渐变与森林绿点缀（与存钱模式弹层同色，避免依赖重构中的主题）。
  static const Color _sageA = AppPalette.sageMist;
  static const Color _sageB = AppPalette.sageRibbon;
  static const Color _greenSoft = AppPalette.softGreen;
  static const Color _greenDeep = AppPalette.deepGreen;

  late final TextEditingController _nameController;
  late final TextEditingController _noteController;
  late final TextEditingController _amountController;
  late DateTime _startDate;
  bool _monthEnd = true; // 月末开关（12 月定额专属，暂不落库，仅页面态）
  // 重复周期 / 结束方式（定额存钱法专属，暂不落库，仅页面态）。
  String _repeatCycle = '每1天';
  // 结束方式：不结束（无结束期、不做总额预测）/ 按次数结束（底部弹层填次数）。
  String _endMethod = '按次数结束';
  int _endCount = 12; // 按次数结束的执行期数（默认 12）。
  static const List<String> _repeatCycleOptions = <String>[
    '每1天',
    '每7天',
    '每月1日',
  ];
  static const List<String> _endMethodOptions = <String>[
    '不结束',
    '按次数结束',
  ];
  String? _sourceAccountId; // 转出/扣款账户（落库 goal.sourceAccountId）
  String? _targetAccountId; // 转入/入款账户（落库到 goal.accountId）
  bool _sourceDefaultScheduled = false; // 冷启动首帧未就绪时，账户流到达后补填默认
  // 递增系数 / 金额·百分比模式（弹性存钱法专属，暂不落库，仅页面态）。
  late final TextEditingController _elasticRateController;
  bool _elasticPercent = false; // false = 金额模式

  // 工程内数字键盘（参照记账页）：null = 收起；
  // 'amount' = 起始/目标金额；'rate' = 递增系数（弹性存钱法）。
  String? _kbTarget;
  final FocusNode _amountFocus = FocusNode();
  final FocusNode _rateFocus = FocusNode();

  /// 激活工程内键盘指向目标字段（只读框持有焦点显示光标，
  /// 不唤起系统键盘）。
  void _activateKeypad(String target) {
    FocusScope.of(context).unfocus(); // 保险：收起可能残留的系统键盘。
    setState(() => _kbTarget = target);
  }

  /// 焦点转移（名称/备注等系统输入框）或点击空白处：收起工程内键盘。
  void _deactivateKeypad() {
    if (_kbTarget == null) return;
    _amountFocus.unfocus();
    _rateFocus.unfocus();
    setState(() => _kbTarget = null);
  }

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
    // 转出/扣款账户首开默认预填 App 默认资产账户（避免留空、保持与记一笔一致）。
    // 若账户流首帧尚未就绪（冷启动），由 build 内守卫在账户到达后补填。
    _sourceAccountId = _resolveDefaultAssetAccountId();
  }

  /// 账户流就绪前 _sourceAccountId 可能为空，待账户数据到达后补默认。
  void _maybeScheduleDefaultSource() {
    if (_sourceAccountId != null || _sourceDefaultScheduled) return;
    final AsyncValue<List<Account>> acc = ref.watch(accountsProvider);
    if (!acc.hasValue) return;
    _sourceDefaultScheduled = true;
    final String? def = _resolveDefaultAssetAccountId();
    if (def != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _sourceAccountId == null) {
          setState(() => _sourceAccountId = def);
        }
      });
    }
  }

  /// 解析 App 默认资产账户 ID：
  /// 1) 取记账设置里的「默认资产账户」名称，在资金类账户中按名匹配；
  /// 2) 未设置名称时，跟随资金类账户列表的第一个；
  /// 3) 无任何账户时回落 null。
  String? _resolveDefaultAssetAccountId() {
    final List<Account> all =
        ref.read(accountsProvider).valueOrNull ?? const <Account>[];
    final List<Account> fund = fundAccountsOnly(all);
    if (fund.isEmpty) return null;
    final String? named =
        ref.read(recordingSettingsProvider).defaultAssetAccount;
    if (named != null) {
      for (final Account a in fund) {
        if (a.name == named) return a.id;
      }
    }
    return fund.first.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    _amountController.dispose();
    _elasticRateController.dispose();
    _amountFocus.dispose();
    _rateFocus.dispose();
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

  /// 金额区标签：灵活存钱法输入「目标金额」，其余模式输入「每期金额」(基数 N)。
  bool get _isFlexible => widget.mode == SavingsMode.flexible;

  /// 金额区标签文案。
  String get _amountLabel => _isFlexible ? '目标金额' : '每期金额';

  /// 金额区下方提示（仅递增/递减类模式需要解释「每期金额 N」的玩法）。
  String? get _amountHint => switch (widget.mode) {
        SavingsMode.fixed365 => '第 1 天存 N 元，第 365 天存 365N 元',
        SavingsMode.weeks52 => '第 1 周存 N 元，第 52 周存 52N 元',
        SavingsMode.weekday => '周一 N 元、周日 7N 元，每周循环',
        SavingsMode.countdown30 => '每月 30→1 元递减，首日 30N 元',
        SavingsMode.elastic => _elasticPercent
            ? '首期 N 元，每期递增百分比'
            : '首期 N 元，每期递增固定额',
        _ => null,
      };

  /// 弹性存钱法专属：递增系数 + 金额/百分比模式。
  bool get _isElastic => widget.mode == SavingsMode.elastic;

  // ---- 构建 ----

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    _maybeScheduleDefaultSource();
    return Scaffold(
      backgroundColor: AppPalette.surfaceMist,
      appBar: AppBar(
        title: Text(widget.mode.label),
        centerTitle: true,
        backgroundColor: AppPalette.surfaceMist,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            // 点击表单空白处：收起工程内键盘（子组件自身的点击优先）。
            child: GestureDetector(
              onTap: _deactivateKeypad,
              behavior: HitTestBehavior.translucent,
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                            // 灵活存钱法：目标金额；其余模式：每期金额（基数 N）。
                            _amountLabel,
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                          ),
                        ),
                      ),
                      _amountField(),
                      if (_amountHint != null) ...<Widget>[
                        const SizedBox(height: 8),
                        _infoRow(theme, _amountHint!),
                      ],
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
                            value: _endMethod == '按次数结束'
                                ? '执行$_endCount次结束'
                                : _endMethod,
                            options: _endMethodOptions,
                            onPicked: (String v) =>
                                setState(() => _endMethod = v),
                            // 选「按次数结束」后再弹层填具体期数。
                            afterPicked: (String v) async {
                              if (v == '按次数结束') {
                                await _showEndCountSheet();
                              }
                            },
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
          ),
          // 底部固定「保存」+ 工程内数字键盘（键盘激活时替换 SafeArea 底距）。
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
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
                // 工程内数字键盘：激活时渲染在保存栏下方（参照截图）。
                if (_kbTarget != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: _SavingsKeypad(
                      value: _kbTarget == 'amount'
                          ? _amountController.text
                          : _elasticRateController.text,
                      onChanged: (String v) => setState(() {
                        if (_kbTarget == 'amount') {
                          _amountController.text = v;
                          _amountController.selection =
                              TextSelection.collapsed(offset: v.length);
                        } else {
                          _elasticRateController.text = v;
                          _elasticRateController.selection =
                              TextSelection.collapsed(offset: v.length);
                        }
                      }),
                      onHide: _deactivateKeypad,
                    ),
                  ),
              ],
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
        color: AppPalette.surfaceMist,
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

  /// 圆角灰底输入框（名称 / 备注）。获得系统键盘焦点时收起工程内键盘。
  Widget _roundedField({
    required TextEditingController controller,
    required String hint,
    required int maxLength,
    int maxLines = 1,
  }) {
    return Focus(
      onFocusChange: (bool got) {
        if (got) _deactivateKeypad();
      },
      child: TextField(
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
          fillColor: AppPalette.surfaceMist,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
    );
  }

  /// 起始金额输入行（💵 图标 + 数字）。只读：录入走工程内数字键盘，
  /// 不唤起系统键盘；点击即激活键盘指向本字段。
  Widget _amountField() {
    return TextField(
      controller: _amountController,
      focusNode: _amountFocus,
      readOnly: true,
      showCursor: true,
      onTap: () => _activateKeypad('amount'),
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(Icons.paid_outlined,
              size: 22, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: AppPalette.surfaceMist,
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
                focusNode: _rateFocus,
                readOnly: true,
                showCursor: true,
                onTap: () => _activateKeypad('rate'),
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
                  fillColor: AppPalette.surfaceMist,
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
    // 选中项后追加动作（如「按次数结束」需再弹层填次数）。
    Future<void> Function(String picked)? afterPicked,
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
          await afterPicked?.call(picked);
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
                color: AppPalette.surfaceMist,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: AppPalette.neutralGray),
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

  /// 「按次数结束」底部弹层：填写执行次数，保存后计划按该期数结束。
  /// 取消返回 null（保持原结束方式不变）。
  /// 录入走工程内数字键盘（[_SavingsKeypad]，整数），不唤起系统键盘。
  Future<void> _showEndCountSheet() async {
    String value = _endCount > 0 ? '$_endCount' : '';
    final int? result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setSheetState) {
          void save() {
            final int n = int.tryParse(value) ?? -1;
            if (n <= 0 || n > 9999) {
              showAppToast(context, '请填入 1~9999 之间的次数');
              return;
            }
            Navigator.of(ctx).pop(n);
          }

          return Container(
            decoration: const BoxDecoration(
              color: AppPalette.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Center(
                    child: Text(
                      '执行次数',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '计划按此次数结束（如 12 表示存满 12 期后完成）',
                    style:
                        TextStyle(fontSize: 13, color: AppPalette.neutralGray),
                  ),
                  const SizedBox(height: 12),
                  // 只读显示框：录入走工程内数字键盘，不唤起系统键盘。
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppPalette.surfaceMist,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      value.isEmpty ? '填入执行次数，如 12' : value,
                      style: TextStyle(
                        fontSize: 16,
                        color: value.isEmpty
                            ? AppPalette.neutralGray.withValues(alpha: 0.6)
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                    child: NumKeypad(
                      value: value,
                      onChanged: (String v) => setSheetState(() => value = v),
                      // 收起键 = 关闭弹层（等同取消）。
                      onHide: () => Navigator.of(ctx).pop(null),
                      onConfirm: save,
                      // 执行次数为整数，忽略「.」键。
                      allowDecimal: false,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(ctx).pop(null),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                AppPalette.sageMist,
                                AppPalette.sageRibbon
                              ],
                            ),
                            borderRadius: BorderRadius.all(Radius.circular(28)),
                          ),
                          child: SizedBox(
                            height: 44,
                            child: TextButton(
                              onPressed: save,
                              style: TextButton.styleFrom(
                                minimumSize: const Size.fromHeight(44),
                                foregroundColor: AppPalette.white,
                              ),
                              child: const Text('保存'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (result != null) setState(() => _endCount = result);
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
                color: AppPalette.surfaceMist,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.alarm,
                  size: 22, color: AppPalette.neutralGray),
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
            color: AppPalette.surfaceMist,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.calendar_today_outlined,
              size: 20, color: AppPalette.neutralGray),
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
              color: AppPalette.surfaceMist,
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
          color: acc == null ? AppPalette.surfaceMist : _greenSoft,
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
        color: AppPalette.surfaceMist,
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
    final CalendarSelection? picked = await CalendarSheet.show(
      context,
      mode: CalendarSheetMode.day,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2107, 12, 31),
      showTime: true,
      showQuickChips: true,
      weekStart: CalendarWeekStart.sunday,
    );
    if (picked == null) return;
    // day 模式返回单日（含所选时分）；若经粒度 chip 选了周期，取其起点日并保留原时分。
    final DateTime resolved;
    if (picked is CalendarDay) {
      resolved = picked.date;
    } else if (picked is CalendarPeriod) {
      final DateTime s = picked.start;
      resolved = DateTime(s.year, s.month, s.day, _startDate.hour, _startDate.minute);
    } else {
      return;
    }
    setState(() => _startDate = resolved);
  }

  /// 转出/扣款账户：仅快捷填充，暂不落库。
  Future<void> _pickSourceAccount() async {
    final Account? acc = await _pickAccount(
      title: '选择转出账户',
      selectedId: _sourceAccountId,
    );
    if (acc != null || _sourceAccountId != null) {
      setState(() => _sourceAccountId = acc?.id);
    }
  }

  /// 转入/入款账户：落库到 goal.accountId。
  Future<void> _pickTargetAccount() async {
    final Account? acc = await _pickAccount(
      title: '选择转入账户',
      selectedId: _targetAccountId,
    );
    if (acc != null || _targetAccountId != null) {
      setState(() => _targetAccountId = acc?.id);
    }
  }

  /// 账户选择：复用工程内「选择账户」A 模板弹层（网格/列表切换、
  /// 实时账户流、添加账户、资产管理），口径=资金类账户（排除应收/应付）。
  /// 「不选择具体账户」回 null，可用于清除已选。
  Future<Account?> _pickAccount({
    required String title,
    String? selectedId,
  }) {
    return showModalBottomSheet<Account>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) => AccountPickerSheet(
        filter: fundAccountsOnly,
        selectedId: selectedId,
        title: title,
        noneTitle: '不选择具体账户',
        // 点添加/资产管理：不关闭当前弹窗，把目标页压在上面；
        // 页面返回后弹窗仍原位（回到「选择账户」这个入口界面）。
        onAdd: () {
          if (mounted) context.push(Routes.accountAdd);
        },
        onManage: () {
          if (mounted) context.push(Routes.accountManage);
        },
        onConfirm: (Account? acc) => Navigator.of(ctx).pop(acc),
      ),
    );
  }

  Future<void> _save() async {
    final String name = _nameController.text.trim().isEmpty
        ? widget.mode.defaultName
        : _nameController.text.trim();
    // 备注不预置：留空即落 null，不回填模式说明（presetNote）。
    final String? note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();
    final double amount = double.tryParse(_amountController.text.trim()) ?? -1;
    if (amount < 0) {
      showAppToast(context, '$_amountLabel格式不正确');
      return;
    }
    final int? deadlineAt = widget.mode.presetDeadlineDays == null
        ? null
        : DateTime(_startDate.year, _startDate.month, _startDate.day)
            .add(Duration(days: widget.mode.presetDeadlineDays!))
            .toUtc()
            .millisecondsSinceEpoch;

    // 重复周期 / 结束方式（计划卡片胶囊展示，参照小青账）：
    // 各模式按节奏给默认周期；定额 / 弹性取用户在「存钱任务」选的值。
    final String? repeatCycle = switch (widget.mode) {
      SavingsMode.flexible => null,
      SavingsMode.fixed => _repeatCycle,
      SavingsMode.countdown30 || SavingsMode.monthly12 => '每月1日',
      SavingsMode.weekday || SavingsMode.weeks52 => '每7天',
      _ => '每1天',
    };
    final String? endNote = switch (widget.mode) {
      SavingsMode.flexible => null,
      SavingsMode.fixed365 => '执行365次结束',
      SavingsMode.countdown30 || SavingsMode.monthly12 => '执行12次结束',
      SavingsMode.weekday || SavingsMode.weeks52 => '执行52次结束',
      SavingsMode.fixed ||
      SavingsMode.elastic =>
        _endMethod == '不结束' ? null : '执行$_endCount次结束',
    };

    final int amountMinor = Money.fromDecimal(amount).minor;

    // 落库口径：
    // - 灵活存钱法：输入额 = 目标金额，已存初值 0；
    // - 弹性存钱法：首期 = 每期基数 N，各期按递增参数算出，目标 = 各期合计（非均摊），初值 0；
    // - 其余六种：输入额 = 每期基数 N，目标 = N × 模式权重（默认周期合计），初值 0。
    int? elasticMode;
    int? elasticBaseMinor;
    int? elasticStepMinor;
    int? elasticPercentHundred;
    int targetMinor;
    // 弹性递增参数（首期 = 每期基数 N）；不结束也保留参数，仅排期无终点。
    if (_isElastic) {
      final double rate =
          double.tryParse(_elasticRateController.text.trim()) ?? -1;
      if (rate < 0) {
        showAppToast(context, '递增系数格式不正确');
        return;
      }
      elasticMode = _elasticPercent ? 2 : 1;
      elasticBaseMinor = amountMinor;
      if (_elasticPercent) {
        // 百分比模式：递增百分比 ×100 落库（如 2% → 200）。
        elasticPercentHundred = (rate * 100).round();
      } else {
        // 金额模式：每期递增额（分）。
        elasticStepMinor = Money.fromDecimal(rate).minor;
      }
    }
    // 不结束：仅每期基数 N，不做总额预测（定额 / 弹性）。
    // 否则：弹性按各期递增合计、其余按模式权重（默认周期合计）。
    if (endNote == null) {
      targetMinor = amountMinor;
    } else if (_isElastic) {
      // 目标 = 各期递增合计（与详情页排期口径一致：build → elasticAmounts）。
      targetMinor = SavingsSchedule.elasticPreviewTotal(
        baseMinor: amountMinor,
        percent: _elasticPercent,
        stepMinor: elasticStepMinor,
        percentHundred: elasticPercentHundred,
        count: SavingsSchedule.countFromEndNote(endNote, 12),
      );
    } else {
      // 其余模式：目标 = 每期基数 N × 模式权重（默认周期合计）。
      final int weight =
          SavingsSchedule.totalWeight(widget.mode, endNote: endNote);
      targetMinor = weight <= 0 ? amountMinor : amountMinor * weight;
    }
    const int currentMinor = 0;

    try {
      await ref.read(savingsRepositoryProvider).add(
            bookId: ref.read(currentBookIdProvider),
            name: name,
            targetMinor: targetMinor,
            currentMinor: currentMinor,
            accountId: _targetAccountId,
            sourceAccountId: _sourceAccountId,
            deadlineAt: deadlineAt,
            note: note,
            mode: widget.mode.name,
            repeatCycle: repeatCycle,
            endNote: endNote,
            // 计划开始日期 = 创建页选的开始日（详情页逐期排期起点）。
            startedAt:
                DateTime(_startDate.year, _startDate.month, _startDate.day)
                    .toUtc()
                    .millisecondsSinceEpoch,
            // 弹性递增参数（非弹性模式为 null，由仓储落库默认值 / 兼容回退）。
            elasticMode: elasticMode,
            elasticBaseMinor: elasticBaseMinor,
            elasticStepMinor: elasticStepMinor,
            elasticPercentHundred: elasticPercentHundred,
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

/// 工程内数字键盘（存钱创建页专用，样式对齐记账页按键）：
/// 4×4 网格——数字 1-9、`.`、`0`、`00`；右列 = 删除 / 收起 / 完成。
/// 录入规则与记账页一致：整数最多 12 位、小数最多 2 位。
class _SavingsKeypad extends StatelessWidget {
  const _SavingsKeypad({
    required this.value,
    required this.onChanged,
    required this.onHide,
    this.onConfirm,
    this.allowDecimal = true,
  });

  // 与页面同款鼠尾草渐变（完成键）。
  static const Color _sageA = AppPalette.sageMist;
  static const Color _sageB = AppPalette.sageRibbon;

  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onHide;

  /// 确认键（✓）回调；缺省与 [onHide] 同义（页内录入场景=收起即完成）。
  final VoidCallback? onConfirm;

  /// 是否允许小数点（执行次数等整数场景传 false 忽略「.」键）。
  final bool allowDecimal;

  static const int _maxIntegerDigits = 12;
  static const int _maxDecimalDigits = 2;

  void _input(String s) {
    if (s == '.') {
      if (!allowDecimal) return;
      if (value.contains('.')) return;
      onChanged(value.isEmpty ? '0.' : '$value.');
      return;
    }
    if (value.contains('.') &&
        value.split('.')[1].length >= _maxDecimalDigits) {
      return;
    }
    if (value.replaceAll('.', '').length >= _maxIntegerDigits) return;
    if (value == '0') {
      onChanged(s == '00' ? '0' : s);
    } else {
      onChanged('$value$s');
    }
  }

  void _backspace() {
    if (value.isNotEmpty) onChanged(value.substring(0, value.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      height: 196,
      child: GridView.count(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        crossAxisCount: 4,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.0,
        children: <Widget>[
          _key(context, label: '1', onTap: () => _input('1')),
          _key(context, label: '2', onTap: () => _input('2')),
          _key(context, label: '3', onTap: () => _input('3')),
          _key(context, icon: Icons.backspace_outlined, onTap: _backspace),
          _key(context, label: '4', onTap: () => _input('4')),
          _key(context, label: '5', onTap: () => _input('5')),
          _key(context, label: '6', onTap: () => _input('6')),
          _key(context, icon: Icons.keyboard_hide_outlined, onTap: onHide),
          _key(context, label: '7', onTap: () => _input('7')),
          _key(context, label: '8', onTap: () => _input('8')),
          _key(context, label: '9', onTap: () => _input('9')),
          _key(context,
              icon: Icons.check, onTap: onConfirm ?? onHide, sage: true),
          _key(context, label: '.', onTap: () => _input('.')),
          _key(context, label: '0', onTap: () => _input('0')),
          _key(context, label: '00', onTap: () => _input('00')),
          // 右下角占位：保持 4×4 网格齐整（无功能）。
          const SizedBox.expand(),
        ],
      ),
    );
  }

  /// 单个按键：奶油卡 + 发丝线 + 极浅投影（对齐记账页 _Digit）；
  /// 「完成」= 鼠尾草渐变白字。
  Widget _key(
    BuildContext context, {
    String? label,
    IconData? icon,
    VoidCallback? onTap,
    bool sage = false,
  }) {
    final ThemeData theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: sage ? null : theme.colorScheme.surfaceContainerHighest,
        gradient:
            sage ? const LinearGradient(colors: <Color>[_sageA, _sageB]) : null,
        border: sage
            ? null
            : Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.06),
            offset: const Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Center(
          child: icon != null
              ? Icon(
                  icon,
                  size: 20,
                  color: sage
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                )
              : Text(
                  label ?? '',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: sage
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
