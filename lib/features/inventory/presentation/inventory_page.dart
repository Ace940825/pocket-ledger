import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/failures.dart';
import '../../../core/theme/forest_asset_design_tokens.dart';
import '../../../core/theme/forest_design_tokens.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../routing/app_router.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/line_icon_map.dart';
import '../../../shared/widgets/module_list_scaffold.dart';
import '../data/inventory_repository.dart';
import '../providers/inventory_providers.dart';

/// 物品页：大件资产清单、折旧与保修跟踪。
class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  InventoryItemType? _filterType;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<InventoryItem>> items =
        ref.watch(inventoryListProvider);

    final List<InventoryItem> filtered = items.maybeWhen(
      data: (List<InventoryItem> list) {
        if (_filterType == null) return list;
        return list
            .where((InventoryItem i) => i.itemType == _filterType)
            .toList();
      },
      orElse: () => <InventoryItem>[],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('物品'),
        actions: <Widget>[
          // 「新建」从底部 FAB 移到顶部 Action，便于单手操作与一致性。
          IconButton(
            icon: const LineGlyph(Icons.add, size: 22),
            tooltip: '新建物品',
            onPressed: () => context.push(Routes.itemEdit),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          // 分类标签
          _buildFilterBar(),
          // 汇总卡片
          items.maybeWhen(
            data: (List<InventoryItem> list) => _AssetSummary(items: list),
            orElse: () => const SizedBox.shrink(),
          ),
          // 物品列表
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('还没有登记物品'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (BuildContext context, int index) =>
                        _ItemTile(item: filtered[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          _FilterChip(
            label: '全部',
            selected: _filterType == null,
            onTap: () => setState(() => _filterType = null),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: '贵重物品',
            selected: _filterType == InventoryItemType.valuables,
            onTap: () =>
                setState(() => _filterType = InventoryItemType.valuables),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: '不动产',
            selected: _filterType == InventoryItemType.realEstate,
            onTap: () =>
                setState(() => _filterType = InventoryItemType.realEstate),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/// 资产汇总：购入总额 / 现值总额 / 累计折旧。
class _AssetSummary extends StatelessWidget {
  const _AssetSummary({required this.items});

  final List<InventoryItem> items;

  @override
  Widget build(BuildContext context) {
    int purchase = 0;
    int value = 0;
    for (final InventoryItem i in items) {
      purchase += i.purchasePriceMinor;
      value += i.currentValueMinor;
    }
    final ThemeData theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('购入总额', style: theme.textTheme.bodySmall),
                  Text(
                    Money.fromMinor(purchase).format(),
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('现值合计', style: theme.textTheme.bodySmall),
                  Text(
                    Money.fromMinor(value).format(),
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('累计折旧', style: theme.textTheme.bodySmall),
                  Text(
                    Money.fromMinor(purchase - value).format(),
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemTile extends ConsumerWidget {
  const _ItemTile({required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final DateTime now = DateTime.now();
    final bool expired = item.isWarrantyExpired(now);
    // 保修临期（30 天内）与已过期共用红色高亮，避免再引入第三种颜色。
    final bool expiringSoon = !expired &&
        item.warrantyUntil != null &&
        item.warrantyUntil! - now.millisecondsSinceEpoch <
            const Duration(days: 30).inMilliseconds;
    final bool warn = expired || expiringSoon;

    String warrantyText = '';
    if (item.warrantyUntil != null) {
      final String month = DateFormat('yyyy-MM').format(
        DateTime.fromMillisecondsSinceEpoch(
          item.warrantyUntil!,
          isUtc: true,
        ).toLocal(),
      );
      warrantyText = expired ? '  ·  保修已过' : '  ·  保修至 $month';
    }

    return ListTile(
      leading: CircleAvatar(
        child: Text(
          item.name.isEmpty ? '?' : item.name[0],
        ),
      ),
      title: Row(
        children: <Widget>[
          Expanded(child: Text(item.name)),
          // 物品类型标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.itemType.label,
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // 使用状态标签（语义色令牌：在用=绿 / 闲置=琥珀 / 其它=中性灰）
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: item.usageStatus == UsageStatus.inUse
                  ? ForestAssetSemantic.success.withOpacity(0.2)
                  : item.usageStatus == UsageStatus.idle
                      ? ForestAssetSemantic.warning.withOpacity(0.2)
                      : context.forest.onSurfaceVariant.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.usageStatus.label,
              style: TextStyle(
                fontSize: 10,
                color: item.usageStatus == UsageStatus.inUse
                    ? ForestAssetSemantic.success
                    : item.usageStatus == UsageStatus.idle
                        ? ForestAssetSemantic.warning
                        : context.forest.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              item.itemType == InventoryItemType.realEstate
                  ? (item.address ?? '未填写地址')
                  : (item.category ?? '未分类'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (warn)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: LineGlyph(
                Icons.warning_amber_rounded,
                size: 14,
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            Money.fromMinor(item.currentValueMinor).format(),
            style: theme.textTheme.bodyLarge,
          ),
          Text(
            '购入 ${Money.fromMinor(item.purchasePriceMinor).format()}$warrantyText',
            style: theme.textTheme.bodySmall?.copyWith(
              color: warn ? theme.colorScheme.error : null,
            ),
          ),
        ],
      ),
      onTap: () => context.push('${Routes.itemEdit}?itemId=${item.id}'),
      onLongPress: () async {
        final bool ok = await confirmDelete(
          context,
          title: '删除物品「${item.name}」？',
        );
        if (!ok || !context.mounted) return;
        try {
          await ref.read(inventoryRepositoryProvider).remove(item.id);
        } on AppFailure catch (e) {
          if (context.mounted) showToast(context, e.message);
        }
      },
    );
  }
}
