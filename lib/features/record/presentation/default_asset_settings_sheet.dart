/// 默认选择资产设置 Bottom Sheet（A 森林手账版落地）
///
/// 数据来源：default-asset-sheet.html 版本 A（延续定稿鼠尾草绿系统）。
/// 结构：拖拽条 → ✕ + 居中标题「默认选择资产设置」→ 分区标题（绿竖条）→
/// 三行设置：① 未选择资产提示（开关）② 资产余额不足校验（仅新增 + 开关）
/// ③ 默认选择资产账户（值胶囊 → 弹出账户选择，点卡片直接确认返回）。
///
/// 从 [AccountPickerSheet] 标题栏齿轮键打开（区别于记账页面设置）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocket_ledger/shared/widgets/hairline_card.dart';
import 'package:pocket_ledger/shared/widgets/line_icons.dart';
import 'package:pocket_ledger/shared/widgets/round_close_button.dart';
import 'package:pocket_ledger/shared/widgets/settings_tile.dart';
import 'package:pocket_ledger/shared/widgets/sheet_scaffold.dart';
import 'package:pocket_ledger/theme/app_theme.dart';

import '../../../core/theme/forest_design_tokens.dart';
import '../../../database/app_database.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/line_icon_map.dart';
import '../../../theme/app_colors.dart';
import '../providers/recording_settings_provider.dart';
import 'account_picker_sheet.dart';

class DefaultAssetSettingsSheet extends ConsumerWidget {
  const DefaultAssetSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showAppModalSheet<void>(
      context,
      isScrollControlled: true,
      bodyPadding: EdgeInsets.zero,
      body: const DefaultAssetSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RecordingSettings settings = ref.watch(recordingSettingsProvider);
    final RecordingSettingsNotifier notifier =
        ref.read(recordingSettingsProvider.notifier);

    // 多机型自适应：390 设计宽，clamp 防极端机型
    final double k = MediaQuery.widthOf(context) / 390;
    final double s = k.clamp(0.85, 1.15);

    return Padding(
      padding: EdgeInsets.fromLTRB(18 * s, 0, 18 * s, 18 * s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 标题栏：✕ + 居中标题
          Padding(
            padding: EdgeInsets.symmetric(vertical: 13 * s),
            child: Row(
              children: <Widget>[
                RoundCloseButton(
                  size: 30 * s,
                  iconSize: 16,
                  onTap: () => Navigator.pop(context),
                  backgroundColor: context.colors.surfaceContainerHighest,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '默认选择资产设置',
                      style: TextStyle(
                        fontSize: 16 * s,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.02,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 30 * s),
              ],
            ),
          ),
          // 分区标题：绿竖条
          Padding(
            padding: EdgeInsets.only(left: 2 * s, bottom: 10 * s),
            child: Row(
              children: <Widget>[
                Container(
                  width: 3 * s,
                  height: 13 * s,
                  margin: EdgeInsets.only(right: 7 * s),
                  decoration: BoxDecoration(
                    color: ForestGreen.brand,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  '默认资产设置',
                  style: TextStyle(
                    fontSize: 12.5 * s,
                    fontWeight: FontWeight.w800,
                    color: ForestSage.ink,
                  ),
                ),
              ],
            ),
          ),
          // 行卡片容器
          HairlineCard(
            backgroundColor: context.colors.surface,
            borderColor: AppPalette.sage900.withValues(alpha: 0.071),
            radius: 16 * s,
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                SettingsTile(
                  scale: s,
                  card: false,
                  leadingIcon: LineIcon(
                    LineIconKind.info,
                    size: 19 * s,
                    color: ForestGreen.deep,
                  ),
                  label: '未选择资产提示',
                  labelStyle: TextStyle(
                    fontSize: 14 * s,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  sub: '没有选择资产会弹出提示',
                  subStyle: TextStyle(
                    fontSize: 11 * s,
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  trailing: Switch(
                    value: settings.promptWhenNoAsset,
                    activeThumbColor: ForestGreen.cta,
                    activeTrackColor: ForestGreen.cta.withValues(alpha: .55),
                    onChanged: (_) => notifier.togglePromptWhenNoAsset(),
                  ),
                ),
                _hairline(s),
                SettingsTile(
                  scale: s,
                  card: false,
                  leadingIcon: LineIcon(
                    LineIconKind.shieldCheck,
                    size: 19 * s,
                    color: ForestGreen.deep,
                  ),
                  label: '资产余额不足校验',
                  labelStyle: TextStyle(
                    fontSize: 14 * s,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  badge: '仅新增',
                  badgeColor: ForestGreen.soft,
                  badgeTextColor: ForestGreen.deep,
                  badgeRadius: 999,
                  sub: '开启后，资产余额扣减不可为负数\n'
                      '如银行卡剩余1元记账2元将无法记录',
                  subStyle: TextStyle(
                    fontSize: 11 * s,
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  trailing: Switch(
                    value: settings.balanceInsufficientCheck,
                    activeThumbColor: ForestGreen.cta,
                    activeTrackColor: ForestGreen.cta.withValues(alpha: .55),
                    onChanged: (_) => notifier.toggleBalanceInsufficientCheck(),
                  ),
                ),
                _hairline(s),
                SettingsTile(
                  scale: s,
                  card: false,
                  leadingIcon: LineIcon(
                    LineIconKind.account,
                    size: 19 * s,
                    color: ForestGreen.deep,
                  ),
                  label: '默认选择资产账户',
                  labelStyle: TextStyle(
                    fontSize: 14 * s,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  sub: '记账页面默认选择的资产账户',
                  subStyle: TextStyle(
                    fontSize: 11 * s,
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  trailing: _ValuePill(
                    s: s,
                    label: settings.defaultAssetAccount ?? '默认账户',
                    onTap: () => _pickDefaultAccount(context, ref),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hairline(double s) => Divider(
        height: 1,
        thickness: 1,
        color: AppPalette.sage800.withValues(alpha: 0.102),
        indent: 14 * s,
      );

  /// 二级弹窗：完整版账户选择列表（无齿轮键），点卡片直接确认返回。
  Future<void> _pickDefaultAccount(BuildContext context, WidgetRef ref) async {
    final String? result = await showAppModalSheet<String?>(
      context,
      isScrollControlled: true,
      bodyPadding: EdgeInsets.zero,
      body: AccountPickerSheet(
        // 实时 watch 账户流：默认资产账户是真实资产账户，
        // 排除应收 / 应付对方虚拟账户
        filter: fundAccountsOnly,
        showSettings: false, // 二级弹窗不显示齿轮键
        // 不关闭当前「选择账户」弹窗，把目标页压在上面；
        // 页面返回后弹窗仍原位（回到进入添加/管理的入口界面）。
        onAdd: () {
          if (context.mounted) context.push(Routes.accountAdd);
        },
        onManage: () {
          if (context.mounted) context.push(Routes.accountManage);
        },
        // 点「不选择具体账户」时 onConfirm 收到 null，用空字符串区分
        // 「明确选择不选择」（''）与「下滑关闭」（null）。
        onConfirm: (Account? acc) => Navigator.of(context).pop(acc?.name ?? ''),
      ),
    );
    // 下拉关闭（null）不改动既有设置；空字符串 = 明确选了「不选择具体账户」，
    // 清除默认资产账户（回退为「跟随默认账户」）。
    if (result != null) {
      ref
          .read(recordingSettingsProvider.notifier)
          .setDefaultAssetAccount(result.isEmpty ? null : result);
    }
  }
}

// ───────────────────── 小组件 ─────────────────────

/// 第三行右侧值胶囊：「默认账户 ›」/「账户名 ›」
class _ValuePill extends StatelessWidget {
  final double s;
  final String label;
  final VoidCallback onTap;

  const _ValuePill({
    required this.s,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 5 * s),
        decoration: BoxDecoration(
          color: AppPalette.mintSurface,
          border:
              Border.all(color: AppPalette.stockDown.withValues(alpha: 0.302)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5 * s,
                fontWeight: FontWeight.w700,
                color: ForestSage.ink,
              ),
            ),
            SizedBox(width: 4 * s),
            LineGlyph(
              Icons.chevron_right,
              size: 14 * s,
              color: ForestSage.ink.withValues(alpha: .65),
            ),
          ],
        ),
      ),
    );
  }
}
