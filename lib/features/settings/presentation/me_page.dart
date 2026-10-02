import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_dimens.dart';
import '../../../database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_colors.dart';

/// 记账天数：当前账本最早一条流水所在自然日至今（含首尾），无流水为 0。
final AutoDisposeStreamProvider<int> recordingDaysProvider =
    StreamProvider.autoDispose<int>((Ref ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  final String bookId = ref.watch(currentBookIdProvider);
  return (db.select(db.transactions)
        ..where(
          ($TransactionsTable tbl) =>
              tbl.bookId.equals(bookId) & tbl.deleted.equals(false),
        )
        ..orderBy([
          ($TransactionsTable tbl) => drift.OrderingTerm.asc(tbl.occurredAt),
        ])
        ..limit(1))
      .watchSingleOrNull()
      .map((Transaction? first) {
    if (first == null) return 0;
    final DateTime local = DateTime.fromMillisecondsSinceEpoch(
      first.occurredAt,
      isUtc: true,
    ).toLocal();
    final DateTime now = DateTime.now();
    final DateTime a = DateTime(local.year, local.month, local.day);
    final DateTime b = DateTime(now.year, now.month, now.day);
    return b.difference(a).inDays + 1;
  });
});

/// 「我的」Tab：小青账式个人中心布局。
///
/// 绿色渐变头部（问候 + 记账天数 + 右侧功能胶囊 + 记一笔横幅）
/// + 双卡（云同步 / 关于）+ 分组宫格（常用功能 / 账单资产 / 偏好）。
class MePage extends ConsumerWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int days =
        ref.watch(recordingDaysProvider).valueOrNull ?? 0;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _buildHeader(context, ref, days),
          const SizedBox(height: AppDimens.spaceLg),
          _buildTwoCards(context, ref),
          _buildSection(context, '常用功能', _commonFeatures),
          _buildSection(context, '账单 / 资产', _billAssets),
          _buildSection(context, '偏好', _preferences),
          const SizedBox(height: AppDimens.spaceXl),
        ],
      ),
    );
  }

  // ── 绿色渐变头部 ──

  Widget _buildHeader(BuildContext context, WidgetRef ref, int days) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[AppPalette.sage300, AppPalette.sage100],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        MediaQuery.of(context).padding.top + 8,
        AppDimens.spaceLg,
        AppDimens.spaceLg,
      ),
      child: Column(
        children: <Widget>[
          // 顶部右侧：设置齿轮。
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              SizedBox(
                width: 34,
                height: 34,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 22,
                  icon: const Icon(Icons.settings_outlined,
                      color: AppPalette.white),
                  onPressed: () => context.push(Routes.settings),
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // 头像。
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppPalette.white,
                ),
                alignment: Alignment.center,
                child: const Text('💰',
                    style: TextStyle(fontSize: 28, height: 1.1)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Hi，口袋账本',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      days > 0 ? '今天是你记账的第 $days 天 ›' : '记下第一笔，开始你的账本吧 ›',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppPalette.textPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                    Text(
                      '本地优先 · 数据存在你的设备上',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppPalette.textPrimary.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 右侧三个功能胶囊。
              Column(
                children: <Widget>[
                  _headerPill('云同步', () => context.push(Routes.settings)),
                  const SizedBox(height: 6),
                  _headerPill('全部功能', () => context.push(Routes.more)),
                  const SizedBox(height: 6),
                  _headerPill('关于', () => _showAbout(context)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 记一笔横幅。
          Material(
            color: AppPalette.white,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => context.push(Routes.record),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.stars_rounded,
                        size: 18, color: AppPalette.sageLeaf),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        days > 0 ? '坚持记账第 $days 天' : '随手记一笔，养成习惯',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppPalette.textPrimary,
                        ),
                      ),
                    ),
                    const Text(
                      '记一笔 ›',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.sageLeaf,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerPill(String label, VoidCallback onTap) {
    return Material(
      color: AppPalette.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppPalette.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  // ── 双卡（云同步 / 关于） ──

  Widget _buildTwoCards(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _bigCard(
              context,
              title: '云同步',
              subtitle: '多设备备份与共享',
              icon: Icons.cloud_sync_outlined,
              onTap: () => context.push(Routes.settings),
            ),
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: _bigCard(
              context,
              title: '帮助中心',
              subtitle: '疑难解答这里找',
              icon: Icons.help_outline,
              onTap: () => _showAbout(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bigCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppPalette.white,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AppPalette.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(icon, size: 34, color: AppPalette.sageLeaf),
            ],
          ),
        ),
      ),
    );
  }

  // ── 分组宫格 ──

  static const List<({String label, IconData icon, String route})>
      _commonFeatures = <({String label, IconData icon, String route})>[
    (label: '收支分类', icon: Icons.category_outlined, route: Routes.categories),
    (label: '预算设置', icon: Icons.pie_chart_outline, route: Routes.budget),
    (label: '存钱', icon: Icons.savings_outlined, route: Routes.savings),
    (label: '转账', icon: Icons.swap_horiz, route: Routes.transfer),
    (label: '报销', icon: Icons.receipt_outlined, route: Routes.reimbursement),
    (label: '分期记账', icon: Icons.calendar_month_outlined, route: Routes.installment),
    (label: '投资', icon: Icons.trending_up, route: Routes.investment),
    (label: '账户管理', icon: Icons.credit_card, route: Routes.accountManage),
  ];

  static const List<({String label, IconData icon, String route})>
      _billAssets = <({String label, IconData icon, String route})>[
    (label: '账单管理', icon: Icons.receipt_long_outlined, route: Routes.billManage),
    (label: '资产', icon: Icons.account_balance_wallet_outlined, route: Routes.accounts),
    (label: '物品管理', icon: Icons.inventory_2_outlined, route: Routes.inventory),
    (label: '账单报告', icon: Icons.donut_large_outlined, route: Routes.report),
  ];

  static const List<({String label, IconData icon, String route})>
      _preferences = <({String label, IconData icon, String route})>[
    (label: '记账偏好', icon: Icons.tune, route: Routes.settings),
  ];

  Widget _buildSection(
    BuildContext context,
    String title,
    List<({String label, IconData icon, String route})> items,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceLg,
        AppDimens.spaceLg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            mainAxisSpacing: 14,
            childAspectRatio: 0.92,
            children: <Widget>[
              for (final ({String label, IconData icon, String route}) item
                  in items)
                _gridItem(context, item),
            ],
          ),
        ],
      ),
    );
  }

  Widget _gridItem(
    BuildContext context,
    ({String label, IconData icon, String route}) item,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      onTap: () => context.push(item.route),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppPalette.neutralMist,
            ),
            alignment: Alignment.center,
            child: Icon(item.icon, size: 22, color: AppPalette.textPrimary),
          ),
          const SizedBox(height: 7),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 12, color: AppPalette.textPrimary),
          ),
        ],
      ),
    );
  }

  // ── 关于 ──

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: '口袋账本',
      applicationVersion: '1.0.0',
      children: const <Widget>[
        Text('本地数据库：SQLite（SQLCipher 加密）'),
        Text('云端同步：Cloudflare D1（可选，永久免费额度）'),
      ],
    );
  }
}
