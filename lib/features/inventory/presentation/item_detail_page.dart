import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';
import '../data/inventory_repository.dart';
import '../providers/inventory_providers.dart';

/// 物品详情页。
class ItemDetailPage extends ConsumerWidget {
  const ItemDetailPage({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(inventoryListProvider).valueOrNull;
    final item = items?.where((i) => i.id == itemId).firstOrNull;

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('物品详情')),
        body: const Center(child: Text('物品不存在')),
      );
    }

    final ThemeData theme = Theme.of(context);
    final DateTime now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: 跳转到编辑页
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              // TODO: 删除物品
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 基本信息卡片
          _buildSectionCard(
            theme,
            title: '基本信息',
            children: [
              _buildInfoRow(theme, '物品类型', item.itemType.label),
              _buildInfoRow(
                theme,
                '类别/地址',
                item.itemType == InventoryItemType.realEstate
                    ? (item.address ?? '未填写')
                    : (item.category ?? '未分类'),
              ),
              _buildInfoRow(
                theme,
                '购买日期',
                DateFormat('yyyy-MM-dd').format(
                  DateTime.fromMillisecondsSinceEpoch(item.purchasedAt, isUtc: true).toLocal(),
                ),
              ),
              _buildInfoRow(theme, '使用状态', item.usageStatus.label),
              _buildInfoRow(theme, '资产状态', item.assetStatus.label),
              _buildInfoRow(
                theme,
                '计入总资产',
                item.includeInTotalAssets ? '是' : '否',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 成本数据卡片
          _buildSectionCard(
            theme,
            title: '成本数据',
            children: [
              _buildInfoRow(
                theme,
                '购买金额',
                Money.fromMinor(item.purchasePriceMinor).format(),
              ),
              _buildInfoRow(
                theme,
                '当前估值',
                Money.fromMinor(item.currentValueMinor).format(),
              ),
              _buildInfoRow(
                theme,
                '折旧金额',
                Money.fromMinor(item.depreciationMinor).format(),
              ),
              if (item.itemType == InventoryItemType.realEstate) ...[
                const Divider(),
                _buildInfoRow(
                  theme,
                  '商品价格',
                  Money.fromMinor(item.productPriceMinor).format(),
                ),
                _buildInfoRow(
                  theme,
                  '利息',
                  Money.fromMinor(item.interestMinor).format(),
                ),
                _buildInfoRow(
                  theme,
                  '税费',
                  Money.fromMinor(item.taxMinor).format(),
                ),
                _buildInfoRow(
                  theme,
                  '装修',
                  Money.fromMinor(item.renovationMinor).format(),
                ),
              ],
              if (item.holdingCostType != null) ...[
                const Divider(),
                _buildInfoRow(theme, '持有成本类型', item.holdingCostType!.label),
                if (item.holdingCostAmountMinor != null)
                  _buildInfoRow(
                    theme,
                    '持有成本金额',
                    Money.fromMinor(item.holdingCostAmountMinor!).format(),
                  ),
                if (item.holdingCostEndDate != null)
                  _buildInfoRow(
                    theme,
                    '持有成本结束时间',
                    DateFormat('yyyy-MM-dd').format(
                      DateTime.fromMillisecondsSinceEpoch(item.holdingCostEndDate!, isUtc: true).toLocal(),
                    ),
                  ),
              ],
              if (item.maintenanceCostTotalMinor > 0) ...[
                const Divider(),
                _buildInfoRow(
                  theme,
                  '维护成本累计',
                  Money.fromMinor(item.maintenanceCostTotalMinor).format(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // 备注卡片
          if (item.note != null && item.note!.isNotEmpty)
            _buildSectionCard(
              theme,
              title: '备注',
              children: [
                Text(
                  item.note!,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    ThemeData theme, {
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
