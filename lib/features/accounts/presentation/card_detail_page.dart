import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../../../theme/app_dimens.dart';
import '../data/card_store.dart';

/// 卡片详情页：点击卡片后进入，展示完整卡信息。
///
/// [cardId] 来自路由 query 参数，数据从 [cardStoreProvider] 按 id 读取。
class CardDetailPage extends ConsumerWidget {
  const CardDetailPage({super.key, required this.cardId});

  final String cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    final CardInfo? card = ref
        .watch(cardStoreProvider)
        .where((CardInfo c) => c.id == cardId)
        .firstOrNull;

    // 未找到卡片（被删除或 id 失效）：提示并返回。
    if (card == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('卡片详情')),
        body: Center(
          child: Text(
            '卡片不存在或已被删除',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final String bankName = card.bankName;
    final String cardName = card.alias.isNotEmpty ? card.alias : card.bankName;
    final String cardNumber = card.maskedNumber;
    final String cardOrg = card.cardOrg;
    final String remark = card.remark.isNotEmpty ? card.remark : '—';

    // 还款日程仅信用卡参与计算，其余类型（证券/储蓄等）显示占位。
    final CardSchedule? schedule = card.cardType == CardType.credit
        ? computeCardSchedule(
            card.billDay,
            card.repayMode,
            card.repayValue,
            DateTime.now(),
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(cardName),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.xxl),
        children: <Widget>[
          // 大卡片预览
          _CardPreview(
            bankName: bankName,
            cardNumber: cardNumber,
            cardOrg: cardOrg,
          ),
          const SizedBox(height: AppDimens.lg),
          // 信息网格（3列）——过滤掉空值卡片
          Builder(
            builder: (BuildContext context) {
              final List<Widget> tiles = <Widget>[
                if (schedule != null)
                  _InfoTile(
                    label: '还款日',
                    value: '${schedule.repayDate.month}月${schedule.repayDate.day}日',
                    hint: '（${schedule.daysToRepay}天）',
                  ),
                if (schedule != null)
                  _InfoTile(
                    label: '下期账单日',
                    value: '${schedule.nextBillingDate.month}月${schedule.nextBillingDate.day}日',
                  ),
                if (schedule != null)
                  _InfoTile(
                    label: '今日免息期',
                    value: '${schedule.interestFreeDays}天',
                  ),
                if (card.validity.isNotEmpty)
                  _InfoTile(label: '有效期至', value: card.validity),
                if (card.bankName.isNotEmpty)
                  _InfoTile(label: '银行', value: card.bankName),
                if (card.cardOrg.isNotEmpty)
                  _InfoTile(label: '发卡组织', value: card.cardOrg),
                if (card.cvv.isNotEmpty)
                  _CvvTile(realCvv: card.cvv),
                if (card.creditLimit.isNotEmpty)
                  _InfoTile(label: '固定额度(¥)', value: card.creditLimit),
                _InfoTile(
                  label: '还款日提醒',
                  value: card.repayReminder ? '已开启' : '已关闭',
                ),
              ];

              if (tiles.isEmpty) {
                return const SizedBox.shrink();
              }

              return GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppDimens.xs,
                crossAxisSpacing: AppDimens.xs,
                childAspectRatio: 2.0,
                children: tiles,
              );
            },
          ),
          const SizedBox(height: AppDimens.md),
          // 备注
          Container(
            padding: const EdgeInsets.all(AppDimens.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppDimens.radiusCard),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '备注',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppDimens.xs),
                Text(
                  remark,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.md),
        ],
      ),
      // 底部悬浮操作栏：编辑 / 删除，胶囊形 + 左右边距 + 阴影浮起
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.xxl,
            AppDimens.md,
            AppDimens.xxl,
            AppDimens.md,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: ElevatedButton(
                  onPressed: () =>
                      context.push('${Routes.cardEdit}?cardId=${card.id}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface,
                    foregroundColor: theme.colorScheme.primary,
                    elevation: 3,
                    shadowColor:
                        theme.colorScheme.shadow.withValues(alpha: 0.26),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('编辑'),
                ),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final bool? confirm = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext ctx) => AlertDialog(
                        title: const Text('删除卡片'),
                        content: Text('确定删除「$cardName」吗？此操作不可撤销。'),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('删除'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      ref.read(cardStoreProvider.notifier).delete(card.id);
                      if (context.mounted) context.pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                    elevation: 3,
                    shadowColor:
                        theme.colorScheme.shadow.withValues(alpha: 0.26),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('删除'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 大卡片预览（类信用卡样式）。
class _CardPreview extends StatelessWidget {
  const _CardPreview({
    required this.bankName,
    required this.cardNumber,
    required this.cardOrg,
  });

  final String bankName;
  final String cardNumber;
  final String cardOrg;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 顶部：银行名 + 卡组织
          // 银行名用 Expanded 收缩并省略，避免长别名把右侧发卡组织 chip 挤窄导致截断。
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  bankName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
                child: Text(
                  cardOrg,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          // 卡号（大字号居中）
          Center(
            child: Text(
              cardNumber,
              style: theme.textTheme.headlineMedium?.copyWith(
                letterSpacing: 2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 信息小卡片（3列网格的每个格子）。
/// [hint] 为可选的高亮后缀（如还款日的「（2天）」），以 error 红色显示。
class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    this.hint,
  });

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle labelStyle = theme.textTheme.labelSmall!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final TextStyle baseStyle = theme.textTheme.titleSmall!.copyWith(
      color: theme.colorScheme.onSurface,
    );
    final TextStyle hintStyle = baseStyle.copyWith(
      color: theme.colorScheme.error,
      fontSize: 11,
    );

    // 有倒计时提示时，值与红色提示拼在同一行（如「10月28日（1天）」），
    // 用 FittedBox 在窄格子里整体等比例缩小，避免溢出换行至两行或截断。
    final Widget valueBlock = hint != null
        ? FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RichText(
              text: TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: value, style: baseStyle),
                  TextSpan(text: hint, style: hintStyle),
                ],
              ),
            ),
          )
        : Text(
            value,
            style: baseStyle,
            softWrap: true,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          );

    return Container(
      padding: const EdgeInsets.all(AppDimens.xs),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // 标题置顶固定；上下两个 Spacer 等分剩余空间，使「标题→内容」间距
        // 等于「内容→底部」间距，内容在标题下方的剩余空间内居中。
        children: <Widget>[
          Text(label, style: labelStyle),
          const Spacer(),
          valueBlock,
          const Spacer(),
        ],
      ),
    );
  }
}

/// 安全码卡片：默认隐藏（***），点击切换显示真实安全码（带眼睛图标提示）。
class _CvvTile extends StatefulWidget {
  const _CvvTile({required this.realCvv});

  final String realCvv;

  @override
  State<_CvvTile> createState() => _CvvTileState();
}

class _CvvTileState extends State<_CvvTile> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String display = _revealed ? widget.realCvv : '***';
    final TextStyle labelStyle = theme.textTheme.labelSmall!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final TextStyle valueStyle = theme.textTheme.titleSmall!.copyWith(
      color: theme.colorScheme.onSurface,
    );

    return InkWell(
      onTap: () => setState(() => _revealed = !_revealed),
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      child: Container(
        padding: const EdgeInsets.all(AppDimens.xs),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // 与 _InfoTile 一致：标题（含眼睛图标）置顶 + 双 Spacer 对称居中
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('安全码', style: labelStyle),
                Icon(
                  _revealed ? Icons.visibility_off : Icons.visibility,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const Spacer(),
            Text(
              display,
              style: valueStyle,
              softWrap: true,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// 还款日程计算已迁移至 `features/accounts/data/card_store.dart`
/// （[computeCardSchedule] / [CardSchedule]），本页直接引用，避免重复定义。
