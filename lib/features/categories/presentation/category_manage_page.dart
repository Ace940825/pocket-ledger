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
/// - 顶部：返回、支出/收入 Tab、更多（底部菜单）
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
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
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
            ),
          ),
          GestureDetector(
            onTap: () => _showMoreSheet(context),
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

  Widget _buildArchivedToggle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceSm,
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
          const SizedBox(width: AppDimens.spaceSm),
          Switch(
            value: _showArchived,
            onChanged: (bool value) => setState(() => _showArchived = value),
          ),
          const Spacer(),
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
          ref: ref,
          onEdit: () => _showEditor(context, ref, category: parent),
          onDelete: () => _confirmDelete(context, ref, parent),
          onAddChild: () => _showEditor(
            context,
            ref,
            type: parent.type,
            parentId: parent.id,
          ),
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
    String? parentId,
  }) async {
    final TextEditingController nameController =
        TextEditingController(text: category?.name ?? '');
    int? colorValue = category?.colorValue;
    String? iconKey = category?.iconKey;
    final CategoryType editorType = category?.type ?? type ?? _type;

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setState) => Dialog(
          insetPadding: const EdgeInsets.all(AppDimens.spaceLg),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              maxWidth: 400,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.spaceLg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    category == null ? '新增分类' : '编辑分类',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppDimens.spaceLg),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: '分类名称',
                            ),
                          ),
                          const SizedBox(height: AppDimens.spaceMd),
                          Text(
                            '图标',
                            style: Theme.of(ctx).textTheme.bodySmall,
                          ),
                          const SizedBox(height: AppDimens.spaceSm),
                          _IconPicker(
                            selectedKey: iconKey,
                            onSelected: (String key) =>
                                setState(() => iconKey = key),
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
                                onTap: () =>
                                    setState(() => colorValue = null),
                              ),
                              ..._palette.map(
                                (int c) => _ColorChip(
                                  selected: colorValue == c,
                                  color: Color(c),
                                  onTap: () =>
                                      setState(() => colorValue = c),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceLg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(dialog).pop(false),
                        child: const Text('取消'),
                      ),
                      const SizedBox(width: AppDimens.spaceSm),
                      FilledButton(
                        onPressed: () => Navigator.of(dialog).pop(true),
                        child: const Text('保存'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
          parentId: parentId,
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

  Future<void> _showMoreSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusLg),
        ),
      ),
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceSm,
              ),
              child: Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close),
                  ),
                  const Expanded(
                    child: Text(
                      '更多',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.sort_outlined),
              title: const Text('分类排序'),
              subtitle: const Text('为主分类排序'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(ctx).pop();
                _toast(context, '排序功能后续开放');
              },
            ),
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('常见问题'),
              subtitle: const Text('查看疑惑解答'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(ctx).pop();
                _toast(context, '常见问题后续开放');
              },
            ),
            const SizedBox(height: AppDimens.spaceMd),
          ],
        ),
      ),
    );
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
    required this.ref,
    required this.onEdit,
    required this.onDelete,
    required this.onAddChild,
    required this.onChildEdit,
    required this.onChildDelete,
  });

  final Category category;
  final List<Category> children;
  final bool showArchived;
  final WidgetRef ref;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddChild;
  final ValueChanged<Category> onChildEdit;
  final ValueChanged<Category> onChildDelete;

  @override
  State<_ParentCategoryTile> createState() => _ParentCategoryTileState();
}

class _ParentCategoryTileState extends State<_ParentCategoryTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
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
          leading: _ExpandArrow(
            expanded: _expanded,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          onTap: () => setState(() => _expanded = !_expanded),
          onMore: () => _showCategoryMenu(
            context,
            widget.ref,
            widget.category,
            onEdit: widget.onEdit,
            onDelete: widget.onDelete,
            onAddChild: widget.onAddChild,
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '子分类更改或删除请点击对应子分类图标哦~',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textTertiary,
                              fontSize: 12,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 16,
                  children: <Widget>[
                    ...visibleChildren.map(
                      (Category child) => _SubcategoryChip(
                        category: child,
                        onTap: () => _showCategoryMenu(
                          context,
                          widget.ref,
                          child,
                          onEdit: () => widget.onChildEdit(child),
                          onDelete: () => widget.onChildDelete(child),
                        ),
                      ),
                    ),
                    _SubcategoryChip.add(onTap: widget.onAddChild),
                  ],
                ),
              ],
            ),
          ),
        const Divider(height: 1, indent: 56),
      ],
    );
  }

  Future<void> _showCategoryMenu(
    BuildContext context,
    WidgetRef ref,
    Category category, {
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    VoidCallback? onAddChild,
  }) async {
    final bool isParent = category.parentId == null;
    final Color color = category.colorValue != null
        ? Color(category.colorValue!)
        : AppColors.primary;

    final String? action = await showModalBottomSheet<String>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusLg),
        ),
      ),
      builder: (BuildContext sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusMd),
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheet).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑分类'),
              onTap: () => Navigator.of(sheet).pop('edit'),
            ),
            if (isParent)
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('添加子分类'),
                onTap: () => Navigator.of(sheet).pop('addChild'),
              ),
            ListTile(
              leading: Icon(
                category.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
              ),
              title: Text(
                category.isArchived ? '取消封存分类' : '封存分类',
              ),
              onTap: () => Navigator.of(sheet).pop(
                category.isArchived ? 'unarchive' : 'archive',
              ),
            ),
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppColors.expense,
              ),
              title: const Text(
                '删除分类',
                style: TextStyle(color: AppColors.expense),
              ),
              onTap: () => Navigator.of(sheet).pop('delete'),
            ),
            const SizedBox(height: AppDimens.spaceMd),
          ],
        ),
      ),
    );

    if (action == null) return;
    if (action == 'edit') {
      onEdit();
    } else if (action == 'addChild' && onAddChild != null) {
      onAddChild();
    } else if (action == 'archive') {
      try {
        await ref.read(categoryRepositoryProvider).archive(category.id);
      } on AppFailure catch (e) {
        if (context.mounted) _toast(context, e.message);
      }
    } else if (action == 'unarchive') {
      try {
        await ref.read(categoryRepositoryProvider).unarchive(category.id);
      } on AppFailure catch (e) {
        if (context.mounted) _toast(context, e.message);
      }
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
  });

  final Category category;
  final Widget leading;
  final VoidCallback onTap;
  final VoidCallback onMore;

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
                      fontWeight: FontWeight.w500,
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

class _SubcategoryChip extends StatelessWidget {
  const _SubcategoryChip({
    required this.category,
    required this.onTap,
  }) : isAdd = false;

  const _SubcategoryChip.add({required this.onTap})
      : category = null,
        isAdd = true;

  final Category? category;
  final VoidCallback onTap;
  final bool isAdd;

  @override
  Widget build(BuildContext context) {
    final Color color = category?.colorValue != null
        ? Color(category!.colorValue!)
        : AppColors.primary;

    return SizedBox(
      width: 64,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
              child: Icon(
                isAdd
                    ? Icons.add_circle_outline
                    : categoryIconData(category!.iconKey),
                color: isAdd ? AppColors.primary : color,
                size: 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isAdd ? '添加子分类' : category!.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isAdd ? AppColors.textSecondary : null,
                    fontSize: 12,
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

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}
