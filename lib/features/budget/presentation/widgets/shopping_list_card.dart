import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/money.dart';
import '../../../../shared/widgets/clay_icon_tile.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/hairline_card.dart';
import '../../../../shared/widgets/line_icon_map.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/sheet_scaffold.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_dimens.dart';
import '../../../record/presentation/record_sheet.dart';
import '../../../record/record_tab.dart';
import '../../data/shopping_list_store.dart';

/// 预算页「购物清单」卡（对标小青账会员位，按现有逻辑推演为本地清单）：
///
/// - 清单存 SharedPreferences（不进账本库，重启不丢）；
/// - 「添加」弹二字段面板（名称必填 / 金额可选，金额用于快速记账预填）；
/// - 点条目右侧 ¥ 钮 → 打开「记一笔」支出页并预填金额与备注，
///   保存成功自动勾为已购；点左侧圆圈 = 手动勾选/取消；
/// - 长按条目 → 确认后删除；「清已购」批量清除已完成条目。
class ShoppingListCard extends ConsumerWidget {
  const ShoppingListCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final List<ShoppingItem> items = ref.watch(shoppingListProvider);
    final List<ShoppingItem> pending =
        items.where((ShoppingItem e) => !e.done).toList(growable: false);
    final int pendingMinor =
        pending.fold<int>(0, (int s, ShoppingItem e) => s + e.amountMinor);
    final bool hasDone = items.length != pending.length;
    // 清单区限高：最多平铺 8 条，超出折叠为「+N 项」脚注，
    // 避免本地清单无限增长把主页拉爆。
    final List<ShoppingItem> visible = items.take(8).toList(growable: false);
    final int hiddenCount = items.length - visible.length;

    return HairlineCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: '购物清单',
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 0),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (hasDone)
                  GestureDetector(
                    onTap: () =>
                        ref.read(shoppingListProvider.notifier).clearDone(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        '清已购',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                GestureDetector(
                  onTap: () => _showAddSheet(context, ref),
                  child: const ClayIconTile(
                    size: 30,
                    color: AppPalette.primary,
                    child: LineGlyph(
                      Icons.add,
                      size: 16,
                      color: AppPalette.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 4, 12, 14),
              child: Text('清单还是空的，点右上角 ＋ 记下想买的东西'),
            )
          else ...<Widget>[
            // 合计行：未购金额与条数（已购不计入合计）。
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
              child: Row(
                children: <Widget>[
                  Text(
                    pending.isEmpty ? '都已买完' : '待购 ${pending.length} 项',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    Money.fromMinor(pendingMinor).format(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: pendingMinor > 0
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            for (final ShoppingItem item in visible)
              _ShoppingItemRow(item: item),
            if (hiddenCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: Text(
                  '还有 $hiddenCount 项未展示',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// 添加条目：二字段底部面板（名称必填 / 金额可选）。
  Future<void> _showAddSheet(BuildContext context, WidgetRef ref) async {
    final TextEditingController nameCtl = TextEditingController();
    final TextEditingController amountCtl = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    final bool? saved = await showAppModalSheet<bool>(
      context,
      title: '添加购物项',
      isScrollControlled: true,
      body: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              controller: nameCtl,
              autofocus: true,
              decoration: const InputDecoration(labelText: '名称'),
              validator: (String? v) =>
                  (v == null || v.trim().isEmpty) ? '请输入名称' : null,
            ),
            const SizedBox(height: AppDimens.md),
            TextFormField(
              controller: amountCtl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '计划金额（可选）',
                hintText: '不填则记账时再输入',
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(true);
            }
          },
          child: const Text('添加'),
        ),
      ],
    );

    // 先取值再 dispose：dispose 后读 controller.text 是未定义行为。
    final String name = nameCtl.text;
    final int minor = Money.tryParse(amountCtl.text).minor;
    nameCtl.dispose();
    amountCtl.dispose();
    if (saved == true && context.mounted) {
      ref.read(shoppingListProvider.notifier).add(name, minor);
    }
  }
}

/// 清单条目行：左圆圈勾选 / 名称（已购划线）/ 金额 / 右 ¥ 快速记账；
/// 长按删除。
class _ShoppingItemRow extends ConsumerWidget {
  const _ShoppingItemRow({required this.item});

  final ShoppingItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final Color doneColor = theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onLongPress: () => _confirmDelete(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: <Widget>[
            // 勾选圈：已购实心 + 对勾，未购空心圈。
            GestureDetector(
              onTap: () =>
                  ref.read(shoppingListProvider.notifier).toggleDone(item.id),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: item.done ? AppPalette.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: item.done
                        ? AppPalette.primary
                        : theme.colorScheme.outline,
                    width: 1.5,
                  ),
                ),
                child: item.done
                    ? LineGlyph(
                        Icons.check,
                        size: 13,
                        color: theme.colorScheme.onPrimary,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            // 名称：已购划线淡出。
            Expanded(
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: item.done ? doneColor : theme.colorScheme.onSurface,
                  decoration: item.done ? TextDecoration.lineThrough : null,
                  decorationColor: doneColor,
                ),
              ),
            ),
            if (item.amountMinor > 0) ...<Widget>[
              const SizedBox(width: 8),
              Text(
                Money.fromMinor(item.amountMinor).format(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: item.done
                      ? doneColor
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(width: 8),
            // 快速记账：预填金额与备注，保存成功后自动勾选。
            GestureDetector(
              onTap: () => openRecordSheet(
                context,
                initialTab: RecordTab.expense,
                initialAmountMinor:
                    item.amountMinor > 0 ? item.amountMinor : null,
                initialNote: item.name,
                onSaved: () =>
                    ref.read(shoppingListProvider.notifier).toggleDone(item.id),
              ),
              child: const Tooltip(
                message: '记一笔',
                child: ClayIconTile(
                  size: 30,
                  color: AppPalette.primary,
                  child: LineGlyph(
                    Icons.currency_yuan_outlined,
                    size: 15,
                    color: AppPalette.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final bool confirmed = await showConfirm(
          context,
          title: '删除购物项',
          content: '确定删除「${item.name}」吗？',
        ) ??
        false;
    if (confirmed) {
      ref.read(shoppingListProvider.notifier).remove(item.id);
    }
  }
}
