import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../providers/asset_stats_settings.dart';

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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AssetStatsSettingsSheet(),
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
    final Color bg = theme.colorScheme.surface;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppDimens.radiusLg),
          ),
        ),
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
                      const _RoundCloseButton(),
                      Expanded(
                        child: Text(
                          '资产月消费统计',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.workspace_premium,
                        color: AppPalette.warn,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                  _SwitchRow(
                    title: '支出流水统计',
                    subtitle: _draft.expenseWithTransfer
                        ? '支出=普通支出账单+转账转出账单'
                        : '支出=普通支出账单',
                    value: _draft.expenseWithTransfer,
                    onChanged: (bool v) => setState(
                      () => _draft = _draft.copyWith(expenseWithTransfer: v),
                    ),
                  ),
                  _SwitchRow(
                    title: '收入流水统计',
                    subtitle: _draft.incomeWithTransfer
                        ? '收入=普通收入账单+转账转入账单'
                        : '收入=普通收入账单',
                    value: _draft.incomeWithTransfer,
                    onChanged: (bool v) => setState(
                      () => _draft = _draft.copyWith(incomeWithTransfer: v),
                    ),
                  ),
                  _SwitchRow(
                    title: '消费账单和退款账单不进行抵扣',
                    subtitle: _draft.noOffset
                        ? '开启后，消费账单和退款账单不进行抵扣'
                        : '关闭后，消费账单和退款账单进行抵扣',
                    value: _draft.noOffset,
                    onChanged: (bool v) => setState(
                      () => _draft = _draft.copyWith(noOffset: v),
                    ),
                  ),
                  _NavRow(
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
      ),
    );
  }

  /// 打开「账单列表样式」二级弹窗（标题：设置）。
  ///
  /// 用回调把改动**实时**写回本面板的草稿，所以即使直接点空白处关掉二级弹窗，
  /// 已经拨过的开关也不会丢——最终仍由本面板的「保存」统一落库。
  Future<void> _openListStyleSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusLg),
        ),
      ),
      builder: (_) => _BillListSettingsSheet(
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
                const _RoundCloseButton(),
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
          _SwitchRow(
            title: '账单列表按年月分组',
            subtitle: '资产账户',
            value: _draft.groupByMonthAsset,
            showCrown: true,
            onChanged: (bool v) =>
                _update(_draft.copyWith(groupByMonthAsset: v)),
          ),
          _SwitchRow(
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

/// 圆形浅底关闭按钮（参考设计里的左上角 ✕）。
class _RoundCloseButton extends StatelessWidget {
  const _RoundCloseButton();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: () => Navigator.of(context).pop(),
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.close,
          size: 20,
          color: AppPalette.textSecondary,
        ),
      ),
    );
  }
}

/// 「标题 + 副标题 + 开关」行。副标题由调用方按当前开关值给出。
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.showCrown = false,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// 二级弹窗里开关左侧会多一个皇冠小标（对齐参考设计）。
  final bool showCrown;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppPalette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (showCrown) ...<Widget>[
            const Icon(
              Icons.workspace_premium,
              size: 18,
              color: AppPalette.warn,
            ),
            const SizedBox(width: AppDimens.spaceXs),
          ],
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// 可点击进入下级设置的导航行（右侧带箭头）。
class _NavRow extends StatelessWidget {
  const _NavRow({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceMd),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}
