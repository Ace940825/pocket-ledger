import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:pocket_ledger/theme/app_dimens.dart';
import '../../../database/app_database.dart';
import '../../../features/record/presentation/record_sheet.dart';
import '../../../features/record/record_tab.dart';
import '../../../providers/app_providers.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/line_icon_map.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../theme/app_colors.dart';

/// 记账天数：当前账本最早一笔流水的【真实记录时刻】所在自然日至今（含首尾），
/// 无流水为 0。
///
/// 真实记录时刻逐行择优后取最小（MIN）：
/// - `created_at` 非空且 ≠ `occurred_at` → 即真实录入时刻（v34 起落库时写入，
///   与业务日期解耦），直接采用；
/// - `created_at` 为空或 = `occurred_at` → 视为 v34 迁移被回填的老数据
///   （当时用业务时间顶替 created_at，不可信），退回 `updated_at`——它在
///   插入/编辑时始终写真实时钟，最早一行的 updated_at ≈ 真实开始记账的时间。
/// 因此补记历史账（业务日期在过去）不会把「坚持天数」撑大：
/// 例如 10 月 1 日开始记账、补记 9 月 1 日的账，天数从 10 月 1 日起算。
final AutoDisposeStreamProvider<int> recordingDaysProvider =
    StreamProvider.autoDispose<int>((Ref ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  final String bookId = ref.watch(currentBookIdProvider);
  return db
      .customSelect(
        'SELECT MIN(CASE WHEN created_at IS NULL OR created_at = occurred_at'
        ' THEN updated_at ELSE created_at END) AS start_ms'
        ' FROM transactions WHERE book_id = ? AND deleted = 0',
        variables: <drift.Variable<Object>>[drift.Variable<String>(bookId)],
        readsFrom: {db.transactions},
      )
      .watchSingleOrNull()
      .map((drift.QueryRow? row) {
        final int? startMs = row?.readNullable<int>('start_ms');
        if (startMs == null) return 0;
        final DateTime local = DateTime.fromMillisecondsSinceEpoch(
          startMs,
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
/// 绿色渐变头部（问候 + 记账天数 + 记一笔横幅；第 34 批移除右侧三个
/// 功能胶囊——云同步 / 全部功能 / 关于）
/// + 双卡（云同步 / 帮助中心）+ 分组宫格（常用功能 / 管理工具 / 偏好）。
class MePage extends ConsumerWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int days = ref.watch(recordingDaysProvider).valueOrNull ?? 0;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _buildHeader(context, ref, days),
          const SizedBox(height: AppDimens.lg),
          _buildTwoCards(context, ref),
          _buildSection(context, '常用功能', _commonFeatures),
          _buildSection(context, '管理工具', _billAssets),
          _buildSection(context, '偏好', _preferences),
          const SizedBox(height: AppDimens.xxl),
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
        AppDimens.lg,
        MediaQuery.of(context).padding.top + 8,
        AppDimens.lg,
        AppDimens.lg,
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
                  icon: const LineGlyph(
                    Icons.settings_outlined,
                    color: AppPalette.white,
                  ),
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
                child: const Text(
                  '💰',
                  style: TextStyle(fontSize: 28, height: 1.1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Hi，口袋账本',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      days > 0 ? '今天是你记账的第 $days 天 ›' : '记下第一笔，开始你的账本吧 ›',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.85),
                      ),
                    ),
                    Text(
                      '本地优先 · 数据存在你的设备上',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // 第 34 批：移除右侧三个功能胶囊（云同步 / 全部功能 / 关于）——
              // 用户要求。入口并未消失：云同步与设置走左上角齿轮（Routes.settings），
              // 全部功能入口在下方宫格分组（常用/管理工具/偏好），关于随设置页。
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
                    const LineGlyph(
                      Icons.stars_rounded,
                      size: 18,
                      color: AppPalette.sageLeaf,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        days > 0 ? '坚持记账第 $days 天' : '随手记一笔，养成习惯',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
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

  // ── 双卡（云同步 / 帮助中心） ──

  Widget _buildTwoCards(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
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
          const SizedBox(width: AppDimens.md),
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
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.md),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              LineGlyph(icon, size: 34, color: AppPalette.sageLeaf),
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
    (label: '报销', icon: Icons.receipt_outlined, route: Routes.reimbursement),
    (label: '退款', icon: Icons.assignment_return_outlined, route: Routes.refund),
    (label: '借还', icon: Icons.handshake_outlined, route: Routes.lend),
    (
      label: '分期记账',
      icon: Icons.calendar_month_outlined,
      route: Routes.installment
    ),
    (label: '投资', icon: Icons.trending_up, route: Routes.investment),
  ];

  static const List<({String label, IconData icon, String route})> _billAssets =
      <({String label, IconData icon, String route})>[
    (
      label: '账单管理',
      icon: Icons.receipt_long_outlined,
      route: Routes.billManage
    ),
    (label: '账户管理', icon: Icons.credit_card, route: Routes.accountManage),
    (label: '物品管理', icon: Icons.inventory_2_outlined, route: Routes.inventory),
    (label: '卡片管理', icon: Icons.credit_score_outlined, route: Routes.cardManage),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(title: title),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.count(
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
        ),
      ],
    );
  }

  Widget _gridItem(
    BuildContext context,
    ({String label, IconData icon, String route}) item,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      onTap: () {
        // 「存钱」宫格直达记一笔的存钱（投资/储蓄存入）Tab，而非计划列表页。
        if (item.label == '存钱') {
          openRecordSheet(context, initialTab: RecordTab.savings);
        } else if (item.route.isEmpty) {
          // 占位入口：功能开发中。
          showAppToast(context, '${item.label}功能开发中');
        } else {
          context.push(item.route);
        }
      },
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
            child: LineGlyph(
              item.icon,
              size: 22,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface,
            ),
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
