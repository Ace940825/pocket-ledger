import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../../../theme/app_dimens.dart';
import '../data/card_store.dart';

/// 卡片管理页：信用卡卡片式列表，参照 KAKA 布局。
///
/// 每张卡以类信用卡卡片展示：银行名 + 卡组织 + 卡号后四位 + 卡片名 + 还款倒计时。
/// 数据来自独立存储 [cardStoreProvider]（不关联账户页）。
class CardManagePage extends ConsumerWidget {
  const CardManagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<CardInfo> cards = ref.watch(cardStoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('卡片管理'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push(Routes.cardEdit),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppDimens.lg),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppDimens.md),
        itemBuilder: (BuildContext context, int index) {
          return _CreditCardItem(card: cards[index]);
        },
      ),
    );
  }
}

/// 单张信用卡卡片。
class _CreditCardItem extends StatelessWidget {
  const _CreditCardItem({required this.card});

  final CardInfo card;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isUrgent =
        card.repaymentDays != null && card.repaymentDays! <= 3;

    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      onTap: () => context.push('${Routes.cardDetail}?cardId=${card.id}'),
      child: Container(
        height: 180,
        padding: const EdgeInsets.all(AppDimens.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 顶部行：银行名 + 卡组织标识
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  card.bankName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (card.cardOrg.isNotEmpty)
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
                      card.cardOrg,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            // 卡号后四位（右对齐）
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                card.last4,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppDimens.xs),
            // 卡片名称（大字号居中偏左，显式深字，避免浅色主题下默认偏白看不见）
            Text(
              card.alias.isNotEmpty ? card.alias : card.bankName,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppDimens.sm),
            // 还款倒计时（右对齐）
            Align(
              alignment: Alignment.centerRight,
              child: card.repaymentDays == null
                  ? Text(
                      '非信用卡账户',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : Text(
                      '还 · ${card.repaymentDays}天',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isUrgent
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight:
                            isUrgent ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
