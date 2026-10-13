import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pocket_ledger/shared/widgets/app_toast.dart';
import 'package:pocket_ledger/theme/app_theme.dart';

import '../../../providers/app_providers.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/amount_keypad.dart';
import '../../../shared/widgets/hairline_card.dart';
import '../../../theme/app_colors.dart';
import '../domain/rolling_calculator.dart';
import '../domain/savings_rolling_plan.dart';
import '../providers/savings_providers.dart';

/// 36 期滚存法创建 / 编辑页。
///
/// 「方便」：用户只填首期本金 / 年利率 / 期限 / 期数 / 取整 / 自动滚存 /
/// 追投 / 滚存停止方式（6–8 个数）；右侧（或下方）
/// 实时调用 [RollingCalculator.simulate] 预览预计利息与到期总额。
/// 「计算多」：引擎算 36 笔建仓 + 滚存链的每笔利息 / 到期额 / 等效年化。
/// 利率 / 金额调整记录在**计划详情页**维护（创建后随时间推移才会用到）。
class SavingsRollingCreatePage extends ConsumerStatefulWidget {
  const SavingsRollingCreatePage({super.key, this.editGoalId});

  /// 非空表示编辑已有计划（暂以新建体验为主，编辑复用同表单预填）。
  final String? editGoalId;

  @override
  ConsumerState<SavingsRollingCreatePage> createState() =>
      _SavingsRollingCreatePageState();
}

enum _RollMode { permanent, rounds, target }

class _SavingsRollingCreatePageState
    extends ConsumerState<SavingsRollingCreatePage> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _baseCtrl = TextEditingController(text: '1000');
  final TextEditingController _rateCtrl = TextEditingController(text: '2.50');
  final TextEditingController _termCtrl = TextEditingController(text: '36');
  final TextEditingController _periodsCtrl = TextEditingController(text: '36');
  final TextEditingController _roundsCtrl = TextEditingController(text: '5');
  final TextEditingController _targetCtrl =
      TextEditingController(text: '100000');

  RoundStrategy _round = RoundStrategy.floor;
  bool _autoRoll = true;
  bool _rollAddNew = true;
  _RollMode _rollMode = _RollMode.permanent;

  RollingResult? _result;

  @override
  void initState() {
    super.initState();
    for (final TextEditingController c in <TextEditingController>[
      _nameCtrl,
      _baseCtrl,
      _rateCtrl,
      _termCtrl,
      _periodsCtrl,
      _roundsCtrl,
      _targetCtrl,
    ]) {
      c.addListener(_recompute);
    }
    _recompute();
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _nameCtrl,
      _baseCtrl,
      _rateCtrl,
      _termCtrl,
      _periodsCtrl,
      _roundsCtrl,
      _targetCtrl,
    ]) {
      c.removeListener(_recompute);
      c.dispose();
    }
    super.dispose();
  }

  int _int(TextEditingController c, int def) =>
      int.tryParse(c.text.trim()) ?? def;
  double _dbl(TextEditingController c, double def) =>
      double.tryParse(c.text.trim()) ?? def;

  /// 用当前表单输入构建一份临时计划并跑模拟，刷新预览。
  void _recompute() {
    final SavingsRollingPlan plan = _buildPlan();
    setState(() {
      _result = RollingCalculator.simulate(plan);
    });
  }

  SavingsRollingPlan _buildPlan() {
    return SavingsRollingPlan(
      id: '',
      goalId: '',
      bookId: '',
      baseMinor: Money.fromDecimal(_dbl(_baseCtrl, 0)).minor,
      annualRateBp: (_dbl(_rateCtrl, 0) * 100).round(),
      termMonths: _int(_termCtrl, 36),
      periods: _int(_periodsCtrl, 36),
      roundStrategy: _round,
      autoRoll: _autoRoll,
      rollAddNew: _rollAddNew,
      rollRounds: _rollMode == _RollMode.rounds ? _int(_roundsCtrl, 5) : 0,
      rollTargetMinor: _rollMode == _RollMode.target
          ? Money.fromDecimal(_dbl(_targetCtrl, 0)).minor
          : null,
      updatedAt: 0,
    );
  }

  Future<void> _save() async {
    try {
      final String bookId = ref.read(currentBookIdProvider);
      final String name =
          _nameCtrl.text.trim().isEmpty ? '36期滚存存钱计划' : _nameCtrl.text.trim();
      final SavingsRollingPlan plan = _buildPlan();
      final String goalId = await ref
          .read(savingsRepositoryProvider)
          .createRolling(bookId: bookId, name: name, plan: plan);
      if (mounted) Navigator.of(context).pop(goalId);
    } catch (e) {
      // 失败必须可见：仓储事务异常若被吞掉，用户看到的就是「点了没反应」。
      if (mounted) {
        showAppToast(context, '保存失败：$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('36期滚存法'),
        actions: <Widget>[
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: GestureDetector(
        // 点击空白处收起系统键盘（计划名称框仍用系统输入法）。
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _sectionLabel('基础设置'),
              _textField(_nameCtrl, '计划名称', '36期滚存存钱计划'),
              _textField(
                _baseCtrl,
                '每月存入本金（元）',
                '1000',
                keypad: true,
                allowDecimal: true,
                prefix: '¥',
              ),
              _textField(
                _rateCtrl,
                '年利率（%，如 2.50）',
                '2.50',
                keypad: true,
                allowDecimal: true,
                prefix: '%',
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _textField(_termCtrl, '单笔期限（月）', '36', keypad: true),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child:
                        _textField(_periodsCtrl, '建仓期数（月）', '36', keypad: true),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _sectionLabel('取整策略（到期本息带小数，取整后存入）'),
              _segmentRow<RoundStrategy>(
                items: const <(RoundStrategy, String)>[
                  (RoundStrategy.round, '四舍五入'),
                  (RoundStrategy.ceil, '向上取整'),
                  (RoundStrategy.floor, '向下取整'),
                ],
                selected: _round,
                onSelected: (RoundStrategy s) {
                  setState(() => _round = s);
                  _recompute();
                },
              ),
              const SizedBox(height: 16),
              _sectionLabel('滚存'),
              HairlineCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    SwitchListTile(
                      title: const Text('自动滚存'),
                      subtitle: const Text('存单到期后本息自动续存为新定期'),
                      value: _autoRoll,
                      activeThumbColor: AppPalette.primary,
                      onChanged: (bool v) {
                        setState(() => _autoRoll = v);
                        _recompute();
                      },
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    SwitchListTile(
                      title: const Text('滚存阶段继续每月追投'),
                      subtitle: const Text('到期后仍每月存一笔固定本金，本金增长更快'),
                      value: _rollAddNew && _autoRoll,
                      activeThumbColor: AppPalette.primary,
                      onChanged: _autoRoll
                          ? (bool v) {
                              setState(() => _rollAddNew = v);
                              _recompute();
                            }
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _sectionLabel('滚存停止方式'),
              _segmentRow<_RollMode>(
                items: const <(_RollMode, String)>[
                  (_RollMode.permanent, '永久'),
                  (_RollMode.rounds, 'N 轮'),
                  (_RollMode.target, '到目标'),
                ],
                selected: _rollMode,
                onSelected: (_RollMode s) {
                  setState(() => _rollMode = s);
                  _recompute();
                },
              ),
              if (_rollMode == _RollMode.rounds)
                _textField(_roundsCtrl, '滚存轮数（每轮 = 建仓期数个月）', '5', keypad: true),
              if (_rollMode == _RollMode.target)
                _textField(
                  _targetCtrl,
                  '滚存到累计到期额达到（元）',
                  '100000',
                  keypad: true,
                  allowDecimal: true,
                  prefix: '¥',
                ),
              const SizedBox(height: 20),
              if (_result != null) _PreviewCard(result: _result!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );

  /// 全站口径输入框：上方小标签 + 无边框薄雾底圆角框（对齐 365 天创建页）。
  ///
  /// [prefix] 为文本前缀（金额框传 `¥`、利率框传 `%`，全站货币口径）。
  /// [keypad] 为 true 时走工程内共享数字键盘 [KeypadField]（弹层录入，
  /// 不唤起系统键盘）；文本框（如计划名称）仍用系统输入法。
  Widget _textField(
    TextEditingController ctrl,
    String label,
    String hint, {
    bool keypad = false,
    bool allowDecimal = false,
    bool dense = false,
    String? prefix,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 6),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (keypad)
              KeypadField(
                controller: ctrl,
                title: label,
                allowDecimal: allowDecimal,
                maxDecimalDigits: 2,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  isDense: dense,
                  prefixIcon: prefix == null
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(left: 16, right: 8),
                          child: Text(
                            prefix,
                            style: TextStyle(
                              fontSize: dense ? 14 : 15,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.deepGreen,
                            ),
                          ),
                        ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                  filled: true,
                  fillColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: dense ? 10 : 13,
                  ),
                ),
              )
            else
              TextField(
                controller: ctrl,
                style: TextStyle(
                  fontSize: dense ? 14 : 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  isDense: dense,
                  filled: true,
                  fillColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: dense ? 10 : 13,
                  ),
                ),
              ),
          ],
        ),
      );

  /// 全站口径胶囊分段行：选中 = 软绿底 + 深绿字 + 勾；未选 = 奶油底 + 发丝线。
  Widget _segmentRow<T>({
    required List<(T, String)> items,
    required T selected,
    required ValueChanged<T> onSelected,
  }) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < items.length; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelected(items[i].$1),
              child: Container(
                height: 38,
                margin: EdgeInsets.only(right: i == items.length - 1 ? 0 : 8),
                decoration: BoxDecoration(
                  color: items[i].$1 == selected
                      ? AppPalette.softGreen
                      : context.colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: items[i].$1 == selected
                        ? AppPalette.sage300
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (items[i].$1 == selected) ...<Widget>[
                      const Icon(
                        Icons.check,
                        size: 15,
                        color: AppPalette.deepGreen,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      items[i].$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: items[i].$1 == selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: items[i].$1 == selected
                            ? AppPalette.deepGreen
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 实时预览卡：展示模拟得到的利息与到期总额。
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.result});

  final RollingResult result;

  @override
  Widget build(BuildContext context) {
    final NumberFormat fmt = NumberFormat('#,##0.00', 'zh_CN');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.softGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.sage200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '预计收益预览',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppPalette.deepGreen,
            ),
          ),
          const SizedBox(height: 12),
          _row(context, '实际累计现金', '${fmt.format(result.cashPrincipalYuan)} 元'),
          _row(
            context,
            '预计总利息',
            '${fmt.format(result.totalInterestYuan)} 元',
            color: AppPalette.income,
          ),
          _row(
            context,
            '预计到期总额',
            '${fmt.format(result.finalMaturityYuan)} 元',
            color: AppPalette.primary,
            bold: true,
          ),
          _row(
            context,
            '等效年化',
            '${result.effectiveAnnualRatePct.toStringAsFixed(2)}%',
          ),
          const SizedBox(height: 8),
          Text(
            '首笔存 ${result.deposits.isNotEmpty ? (result.deposits.first.principalMinor / 100).toStringAsFixed(0) : '0'} 元'
            ' @${result.deposits.isNotEmpty ? result.deposits.first.ratePct.toStringAsFixed(2) : '0'}%'
            ' 利息 ${result.deposits.isNotEmpty ? result.deposits.first.interestYuan.toStringAsFixed(2) : '0'} 元'
            '，到期 ${result.deposits.isNotEmpty ? result.deposits.first.maturityYuan.toStringAsFixed(2) : '0'} 元'
            '（共模拟 ${result.simulatedMonths} 个月）',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    Color? color,
    bool bold = false,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: bold ? 16 : 14,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: color ?? Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      );
}
