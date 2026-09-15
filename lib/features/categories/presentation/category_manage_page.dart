import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/errors/failures.dart';
import '../../../../database/app_database.dart';
import '../../../../domain/enums.dart';
import '../../../../providers/app_providers.dart';
import '../../../../shared/widgets/category_icons.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../data/category_repository.dart';
import '../providers/categories_providers.dart';

/// 分类管理页：按小青账模板重构。
///
/// - 顶部：返回、支出/收入 Tab、更多
/// - 显示封存开关
/// - 一级分类可展开查看子分类
/// - 左侧圆角浅灰图标方块，中间名称，右侧三点菜单
/// - 底部「添加分类」大按钮
class CategoryManagePage extends ConsumerStatefulWidget {
  const CategoryManagePage({super.key});

  @override
  ConsumerState<CategoryManagePage> createState() =>
      _CategoryManagePageState();
}

class _CategoryManagePageState extends ConsumerState<CategoryManagePage> {
  CategoryType _type = CategoryType.expense;
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Category>> categories = ref.watch(
      _type == CategoryType.income
          ? incomeCategoriesProvider
          : expenseCategoriesProvider,
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildHeader(context),
            _buildTypeTabs(context),
            _buildArchivedToggle(context),
            Expanded(
              child: categories.when(
                data: (List<Category> list) => _buildList(list),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object e, _) => Center(child: Text('加载失败：$e')),
              ),
            ),
            _buildAddButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: AppDimens.spaceSm,
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'sort') {
                _toast(context, '排序功能后续开放');
              } else if (value == 'batch') {
                _toast(context, '批量管理后续开放');
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'sort',
                child: Text('分类排序'),
              ),
              const PopupMenuItem<String>(
                value: 'batch',
                child: Text('批量管理'),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.all(AppDimens.spaceMd),
              child: Text(
                '更多',
                style: TextStyle(fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTabs(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
      child: Row(
        children: <Widget>[
          _TypeTab(
            label: '支出分类',
            selected: _type == CategoryType.expense,
            onTap: () => setState(() => _type = CategoryType.expense),
          ),
          const SizedBox(width: AppDimens.spaceXl),
          _TypeTab(
            label: '收入分类',
            selected: _type == CategoryType.income,
            onTap: () => setState(() => _type = CategoryType.income),
          ),
        ],
      ),
    );
  }

  Widget _buildArchivedToggle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceMd,
        AppDimens.spaceLg,
        0,
      ),
      child: Row(
        children: <Widget>[
          Text(
            '显示封存',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const Spacer(),
          Switch(
            value: _showArchived,
            onChanged: (bool value) => setState(() => _showArchived = value),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Category> list) {
    final List<Category> visible = _showArchived
        ? list
        : list.where((Category c) => !c.isArchived).toList();

    final Map<String?, List<Category>> grouped = <String?, List<Category>>{};
    for (final Category c in visible) {
      grouped.putIfAbsent(c.parentId, () => <Category>[]).add(c);
    }

    final List<Category> roots = grouped[null] ?? <Category>[];
    roots.sort((Category a, Category b) => a.sortOrder.compareTo(b.sortOrder));

    if (roots.isEmpty) {
      return const Center(child: Text('还没有分类，点击底部按钮新增'));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(
        left: AppDimens.spaceLg,
        right: AppDimens.spaceLg,
        top: AppDimens.spaceMd,
        bottom: AppDimens.spaceLg,
      ),
      itemCount: roots.length,
      itemBuilder: (BuildContext context, int index) {
        final Category parent = roots[index];
        final List<Category> children = (grouped[parent.id] ?? <Category>[])
          ..sort(
            (Category a, Category b) => a.sortOrder.compareTo(b.sortOrder),
          );
        return _ParentCategoryTile(
          category: parent,
          children: children,
          showArchived: _showArchived,
          onEdit: () => _showEditor(context, ref, category: parent),
          onDelete: () => _confirmDelete(context, ref, parent),
          onChildEdit: (Category child) =>
              _showEditor(context, ref, category: child),
          onChildDelete: (Category child) =>
              _confirmDelete(context, ref, child),
        );
      },
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        0,
        AppDimens.spaceLg,
        AppDimens.spaceLg,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          onPressed: () => _showEditor(context, ref, type: _type),
          child: const Text('添加分类'),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('删除分类？'),
        content: Text('「${category.name}」将被删除。已使用该分类的流水会显示为「未分类」。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(categoryRepositoryProvider).remove(category.id);
    } on AppFailure catch (e) {
      if (context.mounted) _toast(context, e.message);
    }
  }

  Future<void> _showEditor(
    BuildContext context,
    WidgetRef ref, {
    Category? category,
    CategoryType? type,
  }) async {
    final TextEditingController nameController =
        TextEditingController(text: category?.name ?? '');
    int? colorValue = category?.colorValue;
    String? iconKey = category?.iconKey;
    final CategoryType editorType = category?.type ?? type ?? _type;

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setState) => AlertDialog(
          title: Text(category == null ? '新增分类' : '编辑分类'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '分类名称'),
                  autofocus: true,
                ),
                const SizedBox(height: AppDimens.spaceMd),
                Text(
                  '图标',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: AppDimens.spaceSm),
                _IconPicker(
                  selectedKey: iconKey,
                  onSelected: (String key) => setState(() => iconKey = key),
                ),
                const SizedBox(height: AppDimens.spaceMd),
                Text(
                  '颜色（可选）',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: AppDimens.spaceSm),
                Wrap(
                  spacing: AppDimens.spaceSm,
                  children: <Widget>[
                    _ColorChip(
                      selected: colorValue == null,
                      color: Colors.grey,
                      onTap: () => setState(() => colorValue = null),
                    ),
                    ..._palette.map(
                      (int c) => _ColorChip(
                        selected: colorValue == c,
                        color: Color(c),
                        onTap: () => setState(() => colorValue = c),
                      ),
                    ),
                  ],
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
    final String name = nameController.text.trim();
    if (name.isEmpty) {
      _toast(context, '分类名称不能为空');
      return;
    }

    try {
      final CategoryRepository repo = ref.read(categoryRepositoryProvider);
      if (category == null) {
        await repo.add(
          bookId: ref.read(currentBookIdProvider),
          name: name,
          type: editorType,
          colorValue: colorValue,
          iconKey: iconKey,
        );
      } else {
        await repo.update(
          id: category.id,
          bookId: category.bookId,
          name: name,
          type: editorType,
          parentId: category.parentId,
          colorValue: colorValue,
          iconKey: iconKey,
        );
      }
    } on AppFailure catch (e) {
      if (context.mounted) _toast(context, e.message);
    }
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
        selected ? theme.colorScheme.onSurface : AppColors.textTertiary;
    final FontWeight weight =
        selected ? FontWeight.w600 : FontWeight.normal;

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

class _ParentCategoryTile extends StatefulWidget {
  const _ParentCategoryTile({
    required this.category,
    required this.children,
    required this.showArchived,
    required this.onEdit,
    required this.onDelete,
    required this.onChildEdit,
    required this.onChildDelete,
  });

  final Category category;
  final List<Category> children;
  final bool showArchived;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<Category> onChildEdit;
  final ValueChanged<Category> onChildDelete;

  @override
  State<_ParentCategoryTile> createState() => _ParentCategoryTileState();
}

class _ParentCategoryTileState extends State<_ParentCategoryTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final bool hasChildren = widget.children.isNotEmpty;
    final List<Category> visibleChildren = widget.showArchived
        ? widget.children
        : widget.children
            .where((Category c) => !c.isArchived)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _CategoryRow(
          category: widget.category,
          leading: hasChildren
              ? _ExpandArrow(
                  expanded: _expanded,
                  onTap: () => setState(() => _expanded = !_expanded),
                )
              : const SizedBox(width: 32),
          onTap: hasChildren
              ? () => setState(() => _expanded = !_expanded)
              : widget.onEdit,
          onMore: () => _showCategoryMenu(
            context,
            widget.category,
            onEdit: widget.onEdit,
            onDelete: widget.onDelete,
          ),
        ),
        if (_expanded && visibleChildren.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Column(
              children: visibleChildren
                  .map(
                    (Category child) => _CategoryRow(
                      category: child,
                      leading: const SizedBox(width: 32),
                      isChild: true,
                      onTap: () => widget.onChildEdit(child),
                      onMore: () => _showCategoryMenu(
                        context,
                        child,
                        onEdit: () => widget.onChildEdit(child),
                        onDelete: () => widget.onChildDelete(child),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        const Divider(height: 1, indent: 56),
      ],
    );
  }

  Future<void> _showCategoryMenu(
    BuildContext context,
    Category category, {
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) async {
    final String? action = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑'),
              onTap: () => Navigator.of(sheet).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.expense),
              title: const Text('删除', style: TextStyle(color: AppColors.expense)),
              onTap: () => Navigator.of(sheet).pop('delete'),
            ),
            const SizedBox(height: AppDimens.spaceMd),
          ],
        ),
      ),
    );
    if (action == 'edit') {
      onEdit();
    } else if (action == 'delete') {
      onDelete();
    }
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.leading,
    required this.onTap,
    required this.onMore,
    this.isChild = false,
  });

  final Category category;
  final Widget leading;
  final VoidCallback onTap;
  final VoidCallback onMore;
  final bool isChild;

  @override
  Widget build(BuildContext context) {
    final Color color = category.colorValue != null
        ? Color(category.colorValue!)
        : AppColors.primary;

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: AppDimens.listTileHeight,
        child: Row(
          children: <Widget>[
            leading,
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
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
                      fontWeight:
                          isChild ? FontWeight.normal : FontWeight.w500,
                    ),
              ),
            ),
            if (category.isArchived)
              Container(
                margin: const EdgeInsets.only(right: AppDimens.spaceSm),
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
                child: Text(
                  '已封存',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                ),
              ),
            IconButton(
              onPressed: onMore,
              icon: const Icon(
                Icons.more_horiz,
                color: AppColors.textTertiary,
              ),
            ),
          ],
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

class _IconPicker extends StatelessWidget {
  const _IconPicker({required this.selectedKey, required this.onSelected});

  final String? selectedKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categoryIconOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppDimens.spaceSm),
        itemBuilder: (BuildContext context, int index) {
          final CategoryIconOption option = categoryIconOptions[index];
          final bool selected = option.key == selectedKey;
          return InkWell(
            onTap: () => onSelected(option.key),
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.divider,
                ),
              ),
              child: Icon(option.icon, color: AppColors.primary, size: 22),
            ),
          );
        },
      ),
    );
  }
}

/// 预设分类配色（与 AppColors.chartPalette 同源，便于视觉统一）。
const List<int> _palette = <int>[
  0xFFE57373,
  0xFFF06292,
  0xFFBA68C8,
  0xFF9575CD,
  0xFF7986CB,
  0xFF64B5F6,
  0xFF4FC3F7,
  0xFF4DB6AC,
  0xFF81C784,
  0xFFFFB74D,
  0xFFA1887F,
  0xFF90A4AE,
];

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.only(bottom: AppDimens.spaceSm),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2)
              : null,
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
}
