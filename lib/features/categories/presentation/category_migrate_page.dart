import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../shared/widgets/category_icons.dart';
import '../../ledger/providers/ledger_providers.dart';
import '../providers/categories_providers.dart';
import '../../../shared/widgets/app_toast.dart';

/// 账单迁移页：把源分类下的全部流水改挂到目标分类。
///
/// - 全屏页面，顶部返回 + 居中标题。
/// - 支出 / 收入 Tab 切换。
/// - 一级分类左侧固定显示折叠键；有子分类时可展开折叠。
/// - 点击一级分类或子分类即选择目标，确认后执行迁移。
class CategoryMigratePage extends ConsumerStatefulWidget {
  const CategoryMigratePage({super.key, required this.source});

  final Category source;

  @override
  ConsumerState<CategoryMigratePage> createState() =>
      _CategoryMigratePageState();
}

class _CategoryMigratePageState extends ConsumerState<CategoryMigratePage> {
  final Set<String> _expanded = <String>{};
  late CategoryType _selectedType = widget.source.type;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Category>> categories = ref.watch(
      allCategoriesProvider,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _TypeTab(
              label: '支出',
              selected: _selectedType == CategoryType.expense,
              onTap: () => setState(
                () => _selectedType = CategoryType.expense,
              ),
            ),
            const SizedBox(width: AppDimens.spaceXl),
            _TypeTab(
              label: '收入',
              selected: _selectedType == CategoryType.income,
              onTap: () => setState(
                () => _selectedType = CategoryType.income,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: categories.when(
          data: (List<Category> list) => _buildList(list),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, _) => Center(child: Text('加载失败：$e')),
        ),
      ),
    );
  }

  Widget _buildList(List<Category> all) {
    final List<Category> candidates = all
        .where(
          (Category c) =>
              c.id != widget.source.id &&
              c.type == _selectedType &&
              !c.isSystem,
        )
        .toList();

    if (candidates.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppDimens.spaceLg),
        child: Center(child: Text('暂无目标分类')),
      );
    }

    final Map<String?, List<Category>> grouped = <String?, List<Category>>{};
    for (final Category c in candidates) {
      grouped.putIfAbsent(c.parentId, () => <Category>[]).add(c);
    }
    final List<Category> roots = grouped[null] ?? <Category>[];
    roots.sort((Category a, Category b) => a.sortOrder.compareTo(b.sortOrder));

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceLg,
        vertical: AppDimens.spaceSm,
      ),
      children: <Widget>[
        for (final Category parent in roots)
          _MigrateParentTile(
            parent: parent,
            children: (grouped[parent.id] ?? <Category>[])
              ..sort(
                (Category a, Category b) => a.sortOrder.compareTo(b.sortOrder),
              ),
            expanded: _expanded.contains(parent.id),
            onToggle: () => setState(() {
              if (_expanded.contains(parent.id)) {
                _expanded.remove(parent.id);
              } else {
                _expanded.add(parent.id);
              }
            }),
            onSelect: _onSelect,
          ),
      ],
    );
  }

  Future<void> _onSelect(Category target) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('账单迁移'),
        content: Text(
          '「${widget.source.name}」下的全部账单将迁移到「${target.name}」。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final int count = await ref
          .read(transactionRepositoryProvider)
          .reassignCategory(widget.source.id, target.id);
      if (mounted) {
        _toast(
          context,
          count > 0 ? '已迁移 $count 笔账单' : '该分类下没有账单',
        );
        Navigator.of(context).pop();
      }
    } on AppFailure catch (e) {
      if (mounted) _toast(context, e.message);
    }
  }
}

class _TypeTab extends StatelessWidget {
  const _TypeTab({
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
    final Color color =
        selected ? theme.colorScheme.onSurface : AppPalette.textTertiary;
    final FontWeight weight = selected ? FontWeight.w600 : FontWeight.normal;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
        decoration: BoxDecoration(
          border: selected
              ? Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.onSurface,
                    width: 2.5,
                  ),
                )
              : null,
        ),
        child: Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: weight,
          ),
        ),
      ),
    );
  }
}

class _ExpandArrow extends StatelessWidget {
  const _ExpandArrow({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: IconButton(
        onPressed: onTap,
        icon: AnimatedRotation(
          turns: expanded ? 0.25 : 0,
          duration: const Duration(milliseconds: 200),
          child: const Icon(Icons.chevron_right, size: 20),
        ),
      ),
    );
  }
}

class _MigrateParentTile extends StatelessWidget {
  const _MigrateParentTile({
    required this.parent,
    required this.children,
    required this.expanded,
    required this.onToggle,
    required this.onSelect,
  });

  final Category parent;
  final List<Category> children;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<Category> onSelect;

  @override
  Widget build(BuildContext context) {
    final Color color = parent.colorValue != null
        ? Color(parent.colorValue!)
        : AppPalette.primary;
    final bool hasChildren = children.isNotEmpty;

    return Column(
      children: <Widget>[
        SizedBox(
          height: AppDimens.listTileHeight,
          child: Row(
            children: <Widget>[
              _ExpandArrow(expanded: expanded, onTap: onToggle),
              Expanded(
                child: InkWell(
                  onTap: () => onSelect(parent),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppPalette.surfaceLight,
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusMd),
                        ),
                        child: Icon(
                          categoryIconData(parent.iconKey),
                          color: color,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AppDimens.spaceMd),
                      Expanded(
                        child: Text(
                          parent.name,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ),
                      if (hasChildren)
                        Padding(
                          padding:
                              const EdgeInsets.only(right: AppDimens.spaceSm),
                          child: Text(
                            '${children.length}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppPalette.textTertiary),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (expanded && hasChildren)
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: Column(
              children: <Widget>[
                for (final Category child in children)
                  _MigrateChildTile(
                    category: child,
                    onSelect: onSelect,
                  ),
              ],
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}

class _MigrateChildTile extends StatelessWidget {
  const _MigrateChildTile({
    required this.category,
    required this.onSelect,
  });

  final Category category;
  final ValueChanged<Category> onSelect;

  @override
  Widget build(BuildContext context) {
    final Color color = category.colorValue != null
        ? Color(category.colorValue!)
        : AppPalette.primary;

    return InkWell(
      onTap: () => onSelect(category),
      child: SizedBox(
        height: AppDimens.listTileHeight,
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppPalette.surfaceLight,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
              child: Icon(
                categoryIconData(category.iconKey),
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Text(
                category.name,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _toast(BuildContext context, String message) {
  showAppToast(context, message);
}
