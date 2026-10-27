import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:pocket_ledger/core/theme/forest_asset_design_tokens.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/accounts/data/repay_date.dart';
import 'package:pocket_ledger/shared/models/money.dart';
import 'package:pocket_ledger/shared/widgets/animated_money_text.dart';
import 'package:pocket_ledger/shared/widgets/clay_icon_tile.dart';
import 'package:pocket_ledger/shared/widgets/empty_state.dart';
import 'package:pocket_ledger/shared/widgets/line_icon_map.dart';
import 'package:pocket_ledger/shared/widgets/line_icons.dart';
import 'package:pocket_ledger/shared/widgets/loading_state.dart';
import 'package:pocket_ledger/shared/widgets/section_header.dart';
import 'package:pocket_ledger/theme/app_colors.dart';
import 'package:pocket_ledger/theme/app_dimens.dart';
import '../../../routing/app_router.dart';
import '../../record/presentation/record_sheet.dart';
import '../../record/record_tab.dart';
import '../data/account_icon.dart';
import '../providers/accounts_providers.dart';
import 'widgets/credit_card_info_section.dart';

/// 信用卡还款页（账户设置 → 信用卡管理进入）。
///
/// 结构（对齐小青账参考稿）：
/// 1. **顶部合计卡**：参考首页「三联卡」森林渐变卡——小标题「合计」+
///    副标题「总负债(元)」+ 大字总负债 + 底部并排「负债资产数量 / 今日到期数量」；
/// 2. **还款列表**：每个负债类账户一张白卡——头部（图标 + 名称|类型 + 编辑）、
///    「当前欠款 / 可用额度」双列 + 用度进度条、账单/还款两行三列日期宫格、
///    右下「还款」按钮。
///
/// 数据口径：
/// - 只列**使用中**的负债类账户（信用卡/花呗/借呗/白条/月付等，`category == debt`）；
/// - 负债方向账户**正余额 = 当前欠款**（见 [AccountEditPage] 约定）；展示按参考稿
///   取负号（`-欠款`）以表意「负债」，可用额度 = 信用额度 − 当前欠款；
/// - 「今日到期数量」= 下次还款日（固定日期 / 免息期推算）等于今日的账户数。
class CreditCardRepayPage extends ConsumerWidget {
  const CreditCardRepayPage({super.key, this.now});

  /// 可注入的「今天」（测试用）；为空时取 [DateTime.now]。
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Account>> accountsAv = ref.watch(accountsProvider);
    final DateTime now = this.now ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('信用卡还款'),
        centerTitle: true,
      ),
      body: accountsAv.when(
        data: (List<Account> list) {
          final List<Account> debts = list.where(_isActiveDebt).toList();
          debts.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

          int totalDebt = 0;
          int todayDue = 0;
          for (final Account a in debts) {
            if (a.balanceMinor > 0) totalDebt += a.balanceMinor;
            final DateTime? due = nextDueDate(a, now);
            if (due != null &&
                due.year == now.year &&
                due.month == now.month &&
                due.day == now.day) {
              todayDue++;
            }
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: AppDimens.xxl),
            children: <Widget>[
              _SummaryCard(
                totalDebtMinor: totalDebt,
                count: debts.length,
                todayDue: todayDue,
              ),
              const SectionHeader(title: '还款列表'),
              if (debts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppDimens.lg,
                    vertical: AppDimens.xl,
                  ),
                  child: EmptyState(message: '还没有信用卡 / 负债账户'),
                )
              else
                for (final Account a in debts)
                  _CreditCardCard(account: a, now: now),
            ],
          );
        },
        loading: () => const LoadingState(),
        error: (Object e, StackTrace _) => Center(child: Text('加载失败：$e')),
      ),
    );
  }
}

/// 是否为「使用中」的负债类账户（信用卡/花呗/借呗/白条/月付等）。
bool _isActiveDebt(Account a) =>
    a.type.category == AccountCategory.debt && a.status == AccountStatus.active;

/// 顶部合计卡（森林渐变，参考首页三联卡布局）。
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalDebtMinor,
    required this.count,
    required this.todayDue,
  });

  final int totalDebtMinor;
  final int count;
  final int todayDue;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(AppDimens.lg),
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        gradient: ForestAssetBg.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        boxShadow: ForestAssetElevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const LineGlyph(
                Icons.credit_card,
                size: 16,
                color: ForestAssetText.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '合计',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: ForestAssetText.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '总负债(元)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: ForestAssetText.secondary,
            ),
          ),
          const SizedBox(height: AppDimens.xs),
          // 总负债以负号表意（与参考稿一致），色走账户页「总负债」的琥珀约定。
          AnimatedMoneyText(
            Money.fromMinor(-totalDebtMinor),
            color: ForestAssetAccent.amberText,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: ForestAssetAccent.amberText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimens.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: _CountStat(
                  label: '负债资产数量',
                  value: count,
                ),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: _CountStat(
                  label: '今日到期数量',
                  value: todayDue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 合计卡底部统计项：上 label + 下整数计数。
class _CountStat extends StatelessWidget {
  const _CountStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: ForestAssetText.primary.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$value',
          style: theme.textTheme.titleLarge?.copyWith(
            color: ForestAssetText.emphasis,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
/// 单个负债账户的还款卡（对齐参考稿：头部 + 账单信息区 + 还款按钮）。
///
/// 「欠款/额度 + 日期宫格 + 分期记账」已抽为共用组件
/// [CreditCardInfoSection]（资产详情页同款），此处只保留卡片外壳与
/// 页面特有的「还款」按钮，避免两处日期宫格逻辑分叉。
class _CreditCardCard extends StatelessWidget {
  const _CreditCardCard({required this.account, this.now});

  final Account account;

  /// 可注入的「今天」（测试用）；为空时取 [DateTime.now]。
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);


    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimens.lg,
        vertical: AppDimens.sm,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 头部：图标 + 名称|类型（点按跳资产详情）+ 编辑
            Row(
              children: <Widget>[
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    onTap: () => context.push(
                      '/accounts/${account.id}/transactions',
                    ),
                    child: Row(
                      children: <Widget>[
                        ClayIconTile(
                          size: 40,
                          color: AppPalette.expense,
                          child: LineIcon(
                            accountLineKind(account.type) ?? LineIconKind.star,
                            size: 20,
                            color: Color.lerp(
                              AppPalette.expense,
                              context.forest.onSurface,
                              0.22,
                            )!,
                          ),
                        ),
                        const SizedBox(width: AppDimens.sm),
                        Expanded(
                          child: Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  account.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: context.forest.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                ' | ${account.type.label}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: context.forest.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/accounts/${account.id}/edit'),
                  child: const Text('编辑'),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.sm),
            // 账单信息区（欠款/额度 + 日期宫格，与资产详情页共用；还款列表
            // 卡片不展示「分期记账」入口）。点按跳资产详情。
            InkWell(
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              onTap: () => context.push(
                '/accounts/${account.id}/transactions',
              ),
              child: CreditCardInfoSection(
                account: account,
                now: now,
                onInstallment: () => context.push(Routes.installmentAdd),
                showInstallment: false,
              ),
            ),
            const SizedBox(height: AppDimens.sm),
            // 还款按钮（右下）——打开统一「记一笔」转账 Tab，转入账户预填为
            // 当前负债账户，其余字段空置由用户填写
            // （资金账户 → 负债账户即「还款」语义）。
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => openRecordSheet(
                  context,
                  initialTab: RecordTab.transfer,
                  initialTransferToAccountId: account.id,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  foregroundColor: Colors.white, // ignore: no_raw_colors
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.xl,
                    vertical: AppDimens.sm,
                  ),
                ),
                child: const Text('还款'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
