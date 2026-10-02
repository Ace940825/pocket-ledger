import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_dimens.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_colors.dart';

/// 「我的 → 账单管理」页（小青账布局）。
///
/// 三组卡片：账单工具（模板管理 / 账单列表）、导出/导入（账单导入 /
/// 账单导出）、账单清理（账单清理）。已落地的入口走真实路由，
/// 未落地的功能点击提示开发中。
class BillManagePage extends StatelessWidget {
  const BillManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账单管理'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.spaceLg,
          AppDimens.spaceSm,
          AppDimens.spaceLg,
          AppDimens.spaceXl,
        ),
        children: <Widget>[
          _groupCard(
            context,
            title: '账单工具',
            items: <_RowItem>[
              _RowItem(
                icon: Icons.subject_rounded,
                iconBg: AppPalette.blueTintBg,
                iconColor: AppPalette.blueTint,
                label: '模板管理',
                subtitle: '记账快速选择账单模板',
                onTap: () => context.push(Routes.templates),
              ),
              _RowItem(
                icon: Icons.menu_rounded,
                iconBg: AppPalette.purpleTintBg,
                iconColor: AppPalette.purpleTint,
                label: '账单列表',
                subtitle: '根据创建时间、修改时间排序',
                onTap: () => context.push(Routes.billList),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceLg),
          _groupCard(
            context,
            title: '导出/导入',
            items: <_RowItem>[
              _RowItem(
                icon: Icons.cloud_upload_outlined,
                iconBg: AppPalette.softGreen,
                iconColor: AppPalette.income,
                label: '账单导入',
                subtitle: '辅助批量导入账单',
                onTap: () => context.push(Routes.billImport),
              ),
              _RowItem(
                icon: Icons.camera_alt_outlined,
                iconBg: AppPalette.greenTintBg,
                iconColor: AppPalette.ctaGreen,
                label: '从截图导入',
                subtitle: '拍照 / 相册自动识别账单',
                onTap: () => context.push(Routes.screenshotImport),
              ),
              _RowItem(
                icon: Icons.cloud_download_outlined,
                iconBg: AppPalette.goldSoft,
                iconColor: AppPalette.amber,
                label: '账单导出',
                subtitle: '导出app账单为表格',
                onTap: () => context.push(Routes.billExport),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceLg),
          _groupCard(
            context,
            title: '账单清理',
            items: <_RowItem>[
              _RowItem(
                icon: Icons.delete_outline,
                iconBg: AppPalette.redSoftBg,
                iconColor: AppPalette.expense,
                label: '账单清理',
                subtitle: '批量删除账单',
                onTap: () => context.push(Routes.billClean),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 分组卡片：标题（绿色小竖条）+ 行列表 ──

  Widget _groupCard(BuildContext context, {
    required String title,
    required List<_RowItem> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 6, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: <Widget>[
                Container(
                  width: 3.5,
                  height: 15,
                  decoration: BoxDecoration(
                    color: AppPalette.sageLeaf,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          for (int i = 0; i < items.length; i++) ...<Widget>[
            if (i > 0)
              const Divider(height: 1, indent: 14, color: AppPalette.divider),
            items[i],
          ],
        ],
      ),
    );
  }
}

/// 分组内一行：彩色圆角方图标 + 标题/副标题 + 右侧 chevron。
class _RowItem extends StatelessWidget {
  const _RowItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppPalette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 22,
                color: AppPalette.textSecondary),
          ],
        ),
      ),
    );
  }
}
