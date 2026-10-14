import 'package:flutter/material.dart';
import '../../../shared/widgets/line_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_ledger/shared/widgets/menu_item.dart';
import 'package:pocket_ledger/shared/widgets/round_close_button.dart';
import 'package:pocket_ledger/shared/widgets/settings_switch_row.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../providers/asset_stats_settings.dart';
import '../../../../shared/widgets/sheet_scaffold.dart';
import '../../../../theme/app_colors.dart';

/// 「资产月消费统计」设置面板（对齐小青账设置面板）。
///
/// 只配置**资产详情页账单列表的总金额统计方式与分组方式**，不改动流水数据本身。
///
/// 面板内容（对齐参考设计）：
/// - 三个统计开关，**副标题随开关值变化**，把当前口径直接写清楚；
/// - 「账单列表样式」→ 打开标题为「设置」的二级弹窗（按年月分组 · 资产/报销账户）；
/// - 底部绿色「保存」。
///
/// 按参考设计**面板里不出现**「结余」说明行与那段提示文案。
/// （注意：**资产详情页的当月汇总条**是有「结余」的，口径 结余 = 支出 − 收入，
/// 见 `MonthStats.balanceMinor` —— 两处别搞混：面板不含结余，汇总条含。）
class AssetStatsSettingsSheet extends ConsumerStatefulWidget {
  const AssetStatsSettingsSheet({super.key});

  /// 以底部弹窗形式打开。
  static Future<void> show(BuildContext context) {
    return showAppModalSheet<void>(
      context,
      isScrollControlled: true,
      showHandle: false,
      body: const AssetStatsSettingsSheet(),
    );
  }

  @override
  ConsumerState<AssetStatsSettingsSheet> createState() =>
      _AssetStatsSettingsSheetState();
}

class _AssetStatsSettingsSheetState
    extends ConsumerState<AssetStatsSettingsSheet> {
  late AssetStatsSettings _draft;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(assetStatsSettingsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceLg,
              AppDimens.spaceMd,
              AppDimens.spaceLg,
              AppDimens.spaceLg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const RoundCloseButton(),
                    Expanded(
                      child: Text(
                        '资产月消费统计',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const LineIcon(
                      LineIconKind.star,
                      color: AppPalette.warn,
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.spaceSm),
                SettingsSwitchRow(
                  title: '支出流水统计',
                  subtitle: _draft.expenseWithTransfer
                      ? '支出=普通支出账单+转账转出账单'
                      : '支出=普通支出账单',
                  value: _draft.expenseWithTransfer,
                  onChanged: (bool v) => setState(
                    () => _draft = _draft.copyWith(expenseWithTransfer: v),
                  ),
                ),
                SettingsSwitchRow(
                  title: '收入流水统计',
                  subtitle: _draft.incomeWithTransfer
                      ? '收入=普通收入账单+转账转入账单'
                      : '收入=普通收入账单',
                  value: _draft.incomeWithTransfer,
                  onChanged: (bool v) => setState(
                    () => _draft = _draft.copyWith(incomeWithTransfer: v),
                  ),
                ),
                SettingsSwitchRow(
                  title: '消费账单和退款账单不进行抵扣',
                  subtitle: _draft.noOffset
                      ? '开启后，消费账单和退款账单不进行抵扣'
                      : '关闭后，消费账单和退款账单进行抵扣',
                  value: _draft.noOffset,
                  onChanged: (bool v) => setState(
                    () => _draft = _draft.copyWith(noOffset: v),
                  ),
                ),
                MenuItem(
                  title: '账单列表样式',
                  onTap: _openListStyleSettings,
                ),
                const SizedBox(height: AppDimens.spaceLg),
                FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.primaryLight,
                    foregroundColor: AppPalette.primaryDark,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimens.spaceMd,
                    ),
                  ),
                  child: const Text('保存'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 打开「账单列表样式」二级弹窗（标题：设置）。
  ///
  /// 用回调把改动**实时**写回本面板的草稿，所以即使直接点空白处关掉二级弹窗，
  /// 已经拨过的开关也不会丢——最终仍由本面板的「保存」统一落库。
  Future<void> _openListStyleSettings() async {
    await showAppModalSheet<void>(
      context,
      showHandle: false,
      body: _BillListSettingsSheet(
        initial: _draft,
        onChanged: (AssetStatsSettings next) {
          if (mounted) setState(() => _draft = next);
        },
      ),
    );
  }

  Future<void> _save() async {
    await ref.read(assetStatsSettingsProvider.notifier).save(_draft);
    if (mounted) Navigator.of(context).pop();
  }
}

/// 「账单列表样式」二级弹窗：按年月分组 · 资产账户 / 报销账户。
class _BillListSettingsSheet extends StatefulWidget {
  const _BillListSettingsSheet({
    required this.initial,
    required this.onChanged,
  });

  final AssetStatsSettings initial;
  final ValueChanged<AssetStatsSettings> onChanged;

  @override
  State<_BillListSettingsSheet> createState() => _BillListSettingsSheetState();
}

class _BillListSettingsSheetState extends State<_BillListSettingsSheet> {
  late AssetStatsSettings _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
  }

  void _update(AssetStatsSettings next) {
    setState(() => _draft = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceLg,
              AppDimens.spaceMd,
              AppDimens.spaceLg,
              AppDimens.spaceSm,
            ),
            child: Row(
              children: <Widget>[
                const RoundCloseButton(),
                Expanded(
                  child: Text(
                    '设置',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // 与左侧关闭按钮等宽，保证标题真正居中。
                const SizedBox(width: 40),
              ],
            ),
          ),
          SettingsSwitchRow(
            title: '账单列表按年月分组',
            subtitle: '资产账户',
            value: _draft.groupByMonthAsset,
            showCrown: true,
            onChanged: (bool v) =>
                _update(_draft.copyWith(groupByMonthAsset: v)),
          ),
          SettingsSwitchRow(
            title: '账单列表按年月分组',
            subtitle: '报销账户',
            value: _draft.groupByMonthReimburse,
            showCrown: true,
            onChanged: (bool v) =>
                _update(_draft.copyWith(groupByMonthReimburse: v)),
          ),
          const SizedBox(height: AppDimens.spaceLg),
        ],
      ),
    );
  }
}
