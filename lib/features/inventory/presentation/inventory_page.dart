import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/date_field.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/module_list_scaffold.dart';
import '../data/inventory_repository.dart';
import '../providers/inventory_providers.dart';

/// 物品页：大件资产清单、折旧与保修跟踪。
class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<InventoryItem>> items =
        ref.watch(inventoryListProvider);

    return ModuleListScaffold<InventoryItem>(
      title: '物品',
      items: items,
      emptyHint: '还没有登记物品，点右下角新增',
      header: items.maybeWhen(
        data: (List<InventoryItem> list) => _AssetSummary(items: list),
        orElse: () => null,
      ),
      onCreate: () => showInventoryEditor(context, ref),
      itemBuilder: (BuildContext context, InventoryItem i) =>
          _ItemTile(item: i),
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
      leading: CircleAvatar(child: Text(item.name.isEmpty ? '?' : item.name[0])),
      title: Text(item.name),
      subtitle: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '${item.category ?? '未分类'}'
              '${item.location == null || item.location!.isEmpty ? '' : ' · ${item.location}'}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (warn)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: Color(0xFFE53935),
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
              color: warn ? const Color(0xFFE53935) : null,
            ),
          ),
        ],
      ),
      onTap: () => showInventoryEditor(context, ref, item),
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

/// 物品新增 / 编辑对话框。
Future<void> showInventoryEditor(
  BuildContext context,
  WidgetRef ref, [
  InventoryItem? item,
]) async {
  final TextEditingController nameController =
      TextEditingController(text: item?.name ?? '');
  final TextEditingController categoryController =
      TextEditingController(text: item?.category ?? '');
  final TextEditingController locationController =
      TextEditingController(text: item?.location ?? '');
  final TextEditingController purchaseController = TextEditingController(
    text: item != null
        ? Money.fromMinor(item.purchasePriceMinor).decimal.toStringAsFixed(2)
        : '',
  );
  final TextEditingController valueController = TextEditingController(
    text: item != null
        ? Money.fromMinor(item.currentValueMinor).decimal.toStringAsFixed(2)
        : '',
  );
  final TextEditingController noteController =
      TextEditingController(text: item?.note ?? '');

  DateTime purchasedAt = item != null
      ? DateTime.fromMillisecondsSinceEpoch(item.purchasedAt, isUtc: true)
          .toLocal()
      : DateTime.now();
  int? warrantyUntil = item?.warrantyUntil;

  final bool? saved = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialog) => StatefulBuilder(
      builder: (BuildContext ctx, StateSetter setState) => AlertDialog(
        title: Text(item == null ? '登记物品' : '编辑物品'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '名称'),
                autofocus: true,
              ),
              const FormGap(),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: '分类（如 家电 / 数码，可选）',
                ),
              ),
              const FormGap(),
              AmountField(controller: purchaseController, label: '购入价'),
              const FormGap(),
              AmountField(
                controller: valueController,
                label: '当前估值',
                helperText: '留空则默认等于购入价',
              ),
              const FormGap(),
              DateField(
                label: '购入日期',
                value: purchasedAt,
                onChanged: (DateTime? v) {
                  if (v != null) setState(() => purchasedAt = v);
                },
              ),
              DateField(
                label: '保修截止（可选）',
                value: warrantyUntil == null
                    ? null
                    : DateTime.fromMillisecondsSinceEpoch(
                        warrantyUntil!,
                        isUtc: true,
                      ).toLocal(),
                allowClear: true,
                onChanged: (DateTime? v) => setState(
                  () => warrantyUntil = v?.toUtc().millisecondsSinceEpoch,
                ),
              ),
              const FormGap(),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: '存放位置（可选）',
                ),
              ),
              const FormGap(),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: '备注'),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );

  if (saved != true || !context.mounted) return;

  final double? purchase = double.tryParse(purchaseController.text.trim());
  final double? value = double.tryParse(valueController.text.trim());
  if (purchase == null || purchase < 0) {
    showToast(context, '购入价不合法');
    return;
  }
  final int purchaseMinor = Money.fromDecimal(purchase).minor;
  final int valueMinor =
      value == null ? purchaseMinor : Money.fromDecimal(value).minor;

  final InventoryRepository repo = ref.read(inventoryRepositoryProvider);
  final String category = categoryController.text.trim();
  final String location = locationController.text.trim();
  final String note = noteController.text.trim();

  try {
    if (item == null) {
      await repo.add(
        bookId: ref.read(currentBookIdProvider),
        name: nameController.text,
        purchasePriceMinor: purchaseMinor,
        purchasedAt: purchasedAt.toUtc().millisecondsSinceEpoch,
        currentValueMinor: valueMinor,
        category: category.isEmpty ? null : category,
        warrantyUntil: warrantyUntil,
        location: location.isEmpty ? null : location,
        note: note.isEmpty ? null : note,
      );
    } else {
      await repo.update(
        id: item.id,
        name: nameController.text,
        purchasePriceMinor: purchaseMinor,
        currentValueMinor: valueMinor,
        purchasedAt: purchasedAt.toUtc().millisecondsSinceEpoch,
        category: category.isEmpty ? null : category,
        warrantyUntil: warrantyUntil,
        photoUrl: item.photoUrl,
        location: location.isEmpty ? null : location,
        note: note.isEmpty ? null : note,
      );
    }
  } on AppFailure catch (e) {
    if (context.mounted) showToast(context, e.message);
  }
}
