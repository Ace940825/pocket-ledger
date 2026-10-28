import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_ledger/shared/widgets/date_field.dart';
import 'package:pocket_ledger/shared/widgets/form_fields.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/models/money.dart';
import '../providers/inventory_providers.dart';

/// 物品编辑页（新建 / 编辑）。
class ItemEditPage extends ConsumerStatefulWidget {
  const ItemEditPage({super.key, this.itemId});

  /// 编辑时传入物品 id；新建时为 null。
  final String? itemId;

  @override
  ConsumerState<ItemEditPage> createState() => _ItemEditPageState();
}

class _ItemEditPageState extends ConsumerState<ItemEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _addressController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _currentValueController;
  late final TextEditingController _holdingCostController;
  late final TextEditingController _noteController;

  InventoryItemType _itemType = InventoryItemType.valuables;
  DateTime _purchasedAt = DateTime.now();
  HoldingCostType? _holdingCostType;
  DateTime? _holdingCostEndDate;
  UsageStatus _usageStatus = UsageStatus.inUse;
  AssetStatus _assetStatus = AssetStatus.active;
  bool _includeInTotalAssets = true;

  bool _isLoading = false;
  InventoryItem? _existingItem;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _categoryController = TextEditingController();
    _addressController = TextEditingController();
    _purchasePriceController = TextEditingController();
    _currentValueController = TextEditingController();
    _holdingCostController = TextEditingController();
    _noteController = TextEditingController();
    _loadItem();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _addressController.dispose();
    _purchasePriceController.dispose();
    _currentValueController.dispose();
    _holdingCostController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// 点击表单空白处时收起键盘。
  ///
  /// 若当前焦点落在文本输入控件（[EditableText]）上则保持不变，避免「点输入框
  /// 键盘立刻收起」的误操作；其余情况（点选类型 / 切到空白 / 滚动）一律收起，
  /// 防止键盘遮挡下方表单字段。
  void _unfocusOnTap() {
    final FocusNode? primary = FocusManager.instance.primaryFocus;
    if (primary == null || primary.hasPrimaryFocus) return;
    final Widget? focused = primary.context?.widget;
    if (focused is EditableText) return;
    primary.unfocus();
  }

  void _loadItem() {
    if (widget.itemId == null) return;
    final items = ref.read(inventoryListProvider).valueOrNull;
    if (items == null) return;
    final item = items.where((i) => i.id == widget.itemId).firstOrNull;
    if (item == null) return;
    _existingItem = item;

    _nameController.text = item.name;
    _itemType = item.itemType;
    if (item.category != null) _categoryController.text = item.category!;
    if (item.address != null) _addressController.text = item.address!;
    _purchasePriceController.text =
        Money.fromMinor(item.purchasePriceMinor).decimal.toStringAsFixed(2);
    _currentValueController.text =
        Money.fromMinor(item.currentValueMinor).decimal.toStringAsFixed(2);
    if (item.holdingCostAmountMinor != null) {
      _holdingCostController.text =
          Money.fromMinor(item.holdingCostAmountMinor!).decimal.toStringAsFixed(2);
    }
    _purchasedAt = DateTime.fromMillisecondsSinceEpoch(item.purchasedAt, isUtc: true).toLocal();
    _holdingCostType = item.holdingCostType;
    if (item.holdingCostEndDate != null) {
      _holdingCostEndDate = DateTime.fromMillisecondsSinceEpoch(item.holdingCostEndDate!, isUtc: true).toLocal();
    }
    _usageStatus = item.usageStatus;
    _assetStatus = item.assetStatus;
    _includeInTotalAssets = item.includeInTotalAssets;
    if (item.note != null) _noteController.text = item.note!;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final isEdit = widget.itemId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '编辑物品' : '新建物品'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: GestureDetector(
        // 焦点移走（点空白处 / 切换字段 / 点选类型）即收起键盘，避免遮挡下方表单。
        behavior: HitTestBehavior.translucent,
        onTap: _unfocusOnTap,
        child: Form(
          key: _formKey,
          child: ListView(
            // 滚动列表时顺手收起键盘，方便查看被遮挡字段。
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
          children: [
            // 物品类型选择
            _buildSectionTitle(theme, '物品类型'),
            const SizedBox(height: 8),
            _buildTypeSelector(theme),
            const SizedBox(height: 24),

            // 基本信息
            _buildSectionTitle(theme, '基本信息'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: '请输入物品名称',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            if (_itemType == InventoryItemType.valuables)
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: '类别',
                  hintText: '如：家电 / 数码 / 珠宝',
                ),
              )
            else
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: '地址',
                  hintText: '请输入地址',
                ),
              ),
            const SizedBox(height: 16),
            DateField(
              label: '购买日期',
              value: _purchasedAt,
              onChanged: (v) => setState(() => _purchasedAt = v ?? DateTime.now()),
            ),
            const SizedBox(height: 24),

            // 成本数据
            _buildSectionTitle(theme, '成本数据'),
            const SizedBox(height: 8),
            AmountField(
              controller: _purchasePriceController,
              label: '购买金额',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入购买金额';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            AmountField(
              controller: _currentValueController,
              label: '当前估值',
              helperText: '留空则默认等于购买金额',
            ),
            const SizedBox(height: 16),
            // 持有成本
            _buildHoldingCostSection(theme),
            const SizedBox(height: 24),

            // 其他设置
            _buildSectionTitle(theme, '其他设置'),
            const SizedBox(height: 8),
            _buildStatusSelector(theme),
            const SizedBox(height: 16),
            _buildAssetStatusSelector(theme),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('是否计入总资产'),
              value: _includeInTotalAssets,
              onChanged: (v) => setState(() => _includeInTotalAssets = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '备注',
                hintText: '请输入备注',
              ),
              maxLines: 3,
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTypeSelector(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _buildTypeOption(
            theme,
            InventoryItemType.valuables,
            '贵重物品',
            Icons.diamond_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTypeOption(
            theme,
            InventoryItemType.realEstate,
            '不动产',
            Icons.home_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildTypeOption(
    ThemeData theme,
    InventoryItemType type,
    String label,
    IconData icon,
  ) {
    final selected = _itemType == type;
    return GestureDetector(
      onTap: () => setState(() => _itemType = type),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: selected
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoldingCostSection(ThemeData theme) {
    final ColorScheme scheme = theme.colorScheme;
    return Card(
      // 「持有成本」是可选子分组，用一张轻量卡片把它从成本数据里圈出来，
      // 解决原「紧跟辅助说明、无边界、显得拥挤」的问题（复用全局 cardTheme：
      // surface 底 + outline 描边）。
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '持有成本（可选）',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<HoldingCostType>(
              value: _holdingCostType,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: '类型',
                hintText: '选择持有成本类型',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              items: HoldingCostType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.label),
                );
              }).toList(),
              onChanged: (v) => setState(() => _holdingCostType = v),
            ),
            if (_holdingCostType != null) ...<Widget>[
              const SizedBox(height: 16),
              AmountField(
                controller: _holdingCostController,
                label: '金额',
              ),
              const SizedBox(height: 16),
              DateField(
                label: '结束时间',
                value: _holdingCostEndDate,
                allowClear: true,
                onChanged: (v) => setState(() => _holdingCostEndDate = v),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '使用状态',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: UsageStatus.values.map((status) {
            final selected = _usageStatus == status;
            return ChoiceChip(
              label: Text(status.label),
              selected: selected,
              onSelected: (v) => setState(() => _usageStatus = status),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAssetStatusSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '资产状态',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: AssetStatus.values.map((status) {
            final selected = _assetStatus == status;
            return ChoiceChip(
              label: Text(status.label),
              selected: selected,
              onSelected: (v) => setState(() => _assetStatus = status),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final bookId = ref.read(currentBookIdProvider);

      final purchasePrice = double.tryParse(_purchasePriceController.text.trim());
      final currentValue = double.tryParse(_currentValueController.text.trim());
      final holdingCost = double.tryParse(_holdingCostController.text.trim());

      final purchasePriceMinor = Money.fromDecimal(purchasePrice ?? 0).minor;
      final currentValueMinor = currentValue != null
          ? Money.fromDecimal(currentValue).minor
          : purchasePriceMinor;
      final holdingCostMinor = holdingCost != null
          ? Money.fromDecimal(holdingCost).minor
          : null;

      if (widget.itemId == null) {
        await repo.add(
          bookId: bookId,
          name: _nameController.text.trim(),
          itemType: _itemType,
          purchasePriceMinor: purchasePriceMinor,
          currentValueMinor: currentValueMinor,
          purchasedAt: _purchasedAt.toUtc().millisecondsSinceEpoch,
          category: _itemType == InventoryItemType.valuables
              ? _categoryController.text.trim().isEmpty
                  ? null
                  : _categoryController.text.trim()
              : null,
          address: _itemType == InventoryItemType.realEstate
              ? _addressController.text.trim().isEmpty
                  ? null
                  : _addressController.text.trim()
              : null,
          holdingCostType: _holdingCostType,
          holdingCostAmountMinor: holdingCostMinor,
          holdingCostEndDate: _holdingCostEndDate?.toUtc().millisecondsSinceEpoch,
          usageStatus: _usageStatus,
          assetStatus: _assetStatus,
          includeInTotalAssets: _includeInTotalAssets,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        );
      } else {
        await repo.update(
          id: widget.itemId!,
          name: _nameController.text.trim(),
          itemType: _itemType,
          purchasePriceMinor: purchasePriceMinor,
          currentValueMinor: currentValueMinor,
          purchasedAt: _purchasedAt.toUtc().millisecondsSinceEpoch,
          category: _itemType == InventoryItemType.valuables
              ? _categoryController.text.trim().isEmpty
                  ? null
                  : _categoryController.text.trim()
              : null,
          address: _itemType == InventoryItemType.realEstate
              ? _addressController.text.trim().isEmpty
                  ? null
                  : _addressController.text.trim()
              : null,
          holdingCostType: _holdingCostType,
          holdingCostAmountMinor: holdingCostMinor,
          holdingCostEndDate: _holdingCostEndDate?.toUtc().millisecondsSinceEpoch,
          usageStatus: _usageStatus,
          assetStatus: _assetStatus,
          includeInTotalAssets: _includeInTotalAssets,
          photoUrl: _existingItem?.photoUrl,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功')),
        );
      }
    } catch (e, st) {
      if (mounted) {
        // 调试模式：显示完整错误信息，便于截图暴露根因
        final String errorDetail = e is AppFailure ? e.message : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败：$errorDetail'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      debugPrint('[ItemEditPage] 保存失败原始异常: $e\n$st');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
