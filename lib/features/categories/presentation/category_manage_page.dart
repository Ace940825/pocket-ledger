import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/errors/failures.dart';
import '../../../../database/app_database.dart';
import '../../../../domain/enums.dart';
import '../../../../shared/widgets/category_icons.dart';
import '../../../routing/app_router.dart';
import '../providers/categories_providers.dart';
import '../../../shared/widgets/app_toast.dart';

/// 分类管理页：按小青账模板重构。
///
/// - 顶部：返回、支出/收入 Tab、更多（底部菜单）
/// - 一级分类可展开查看子分类
/// - 左侧圆角浅灰图标方块，中间名称，右侧三点菜单
/// - 底部「添加分类」大按钮
class CategoryManagePage extends ConsumerStatefulWidget {
  const CategoryManagePage({super.key});

  @override
  ConsumerState<CategoryManagePage> createState() => _CategoryManagePageState();
}

class _CategoryManagePageState extends ConsumerState<CategoryManagePage> {
  CategoryType _type = CategoryType.expense;
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Category>> categories = ref.watch(
      allCategoriesProvider,
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
          IconButton(
            onPressed: () => _showSortSheet(context, ref, _type),
            icon: const Icon(Icons.sort_outlined),
            tooltip: '分类排序',
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
    final List<Category> typed =
        list.where((Category c) => c.type == _type).toList();

    final List<Category> visible = _showArchived
        ? typed
        : typed.where((Category c) => !c.isArchived).toList();

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
          onEdit: () => context.push(
            Routes.editCategory,
            extra: parent,
          ),
          onDelete: () => _confirmDelete(context, ref, parent),
          onAddChild: () => context.push(
            Routes.addSubcategory,
            extra: parent,
          ),
          onChildEdit: (Category child) {
            context.push(
              Routes.editSubcategory,
              extra: (child, parent),
            );
          },
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
          onPressed: () => context.push(
            Routes.addCategory,
            extra: _type,
          ),
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
        : widget.children.where((Category c) => !c.isArchived).toList();

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
    final String name = category.name;
    final String parentName = widget.category.name;
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
        child: SingleChildScrollView(
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
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
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
                title: Text(isParent ? '编辑分类' : '编辑子分类'),
                subtitle: Text(
                  isParent ? '修改「$name」分类' : '修改「$name」子分类',
                ),
                onTap: () => Navigator.of(sheet).pop('edit'),
              ),
              if (isParent) ...<Widget>[
                ListTile(
                  leading: const Icon(Icons.sort_outlined),
                  title: const Text('分类排序'),
                  subtitle: const Text('为主分类排序'),
                  onTap: () => Navigator.of(sheet).pop('sort'),
                ),
                ListTile(
                  leading: const Icon(Icons.subdirectory_arrow_right_outlined),
                  title: const Text('改为子分类'),
                  subtitle: Text('将「$name」归入其他主分类'),
                  onTap: () => Navigator.of(sheet).pop('toSub'),
                ),
              ] else ...<Widget>[
                ListTile(
                  leading: const Icon(Icons.vertical_align_top_outlined),
                  title: const Text('改为主分类'),
                  subtitle: Text('将「$name」变为主分类'),
                  onTap: () => Navigator.of(sheet).pop('toParent'),
                ),
                ListTile(
                  leading: const Icon(Icons.sort_outlined),
                  title: const Text('子分类排序'),
                  subtitle: Text('为「$parentName」下的子分类排序'),
                  onTap: () => Navigator.of(sheet).pop('childSort'),
                ),
              ],
              ListTile(
                leading: const Icon(Icons.swap_horiz_outlined),
                title: const Text('账单迁移'),
                subtitle: Text('仅迁移「$name」分类下的账单'),
                onTap: () => Navigator.of(sheet).pop('migrate'),
              ),
              ListTile(
                leading: Icon(
                  category.isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                title: Text(
                  category.isArchived
                      ? (isParent ? '取消封存分类' : '取消封存子分类')
                      : (isParent ? '封存分类' : '封存子分类'),
                ),
                subtitle: Text(
                  category.isArchived ? '将「$name」解封并恢复显示' : '将「$name」封存，简化分类列表',
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
                title: Text(
                  isParent ? '删除分类' : '删除子分类',
                  style: const TextStyle(color: AppColors.expense),
                ),
                subtitle: Text(
                  isParent ? '迁移账单后删除，或直接删除分类' : '迁移账单后删除，或直接删除子分类',
                ),
                onTap: () => Navigator.of(sheet).pop('delete'),
              ),
              const SizedBox(height: AppDimens.spaceMd),
            ],
          ),
        ),
      ),
    );

    if (action == null) return;
    // 底部菜单是 await 出来的，此后的操作都要用 context。
    if (!context.mounted) return;
    if (action == 'edit') {
      onEdit();
    } else if (action == 'sort') {
      await _showSortSheet(context, ref, category.type);
    } else if (action == 'childSort') {
      await _showChildSortSheet(
        context,
        ref,
        widget.category.id,
        widget.children,
      );
    } else if (action == 'toSub') {
      await _showChangeParentSheet(context, ref, category);
    } else if (action == 'toParent') {
      await _showPromoteSheet(context, ref, category);
    } else if (action == 'migrate') {
      await _showMigrateSheet(context, ref, category);
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

/// 分类排序：拖拽重排一级分类顺序。
Future<void> _showSortSheet(
  BuildContext context,
  WidgetRef ref,
  CategoryType type,
) async {
  final AsyncValue<List<Category>> prov = ref.read(allCategoriesProvider);
  final List<Category>? all = prov.value;
  if (all == null) {
    _toast(context, '数据加载中，请稍后再试');
    return;
  }

  final List<Category> items = all
      .where((Category c) => c.parentId == null)
      .toList()
    ..sort((Category a, Category b) => a.sortOrder.compareTo(b.sortOrder));
  if (items.length < 2) {
    _toast(context, '分类不足两个，无需排序');
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppDimens.radiusLg)),
    ),
    builder: (BuildContext sheet) => SafeArea(
      child: StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setSheetState) {
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.7,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(AppDimens.spaceMd),
                  child: Row(
                    children: <Widget>[
                      const SizedBox(width: 48),
                      const Expanded(
                        child: Text(
                          '分类排序',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ReorderableListView(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimens.spaceSm,
                    ),
                    buildDefaultDragHandles: true,
                    onReorderItem: (int oldIndex, int newIndex) async {
                      setSheetState(() {
                        final Category moved = items.removeAt(oldIndex);
                        items.insert(newIndex, moved);
                      });
                      final List<String> ids =
                          items.map((Category c) => c.id).toList();
                      await ref
                          .read(categoryRepositoryProvider)
                          .reorderParents(ids);
                    },
                    children: <Widget>[
                      for (final Category c in items)
                        _SortTile(key: ValueKey<String>(c.id), category: c),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimens.spaceMd),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _SortTile extends StatelessWidget {
  const _SortTile({required super.key, required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final Color color = category.colorValue != null
        ? Color(category.colorValue!)
        : AppColors.primary;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        child: Icon(categoryIconData(category.iconKey), color: color, size: 22),
      ),
      title: Text(category.name),
      trailing: const Icon(Icons.drag_handle, color: AppColors.textTertiary),
    );
  }
}

/// 改为子分类：选择新的父分类后整体挂靠。
Future<void> _showChangeParentSheet(
  BuildContext context,
  WidgetRef ref,
  Category category,
) async {
  final AsyncValue<List<Category>> prov = ref.read(allCategoriesProvider);
  final List<Category>? all = prov.value;
  if (all == null) {
    _toast(context, '数据加载中，请稍后再试');
    return;
  }

  final List<Category> candidates = all
      .where((Category c) => c.parentId == null && c.id != category.id)
      .toList()
    ..sort((Category a, Category b) => a.sortOrder.compareTo(b.sortOrder));
  if (candidates.isEmpty) {
    _toast(context, '没有其他一级分类可挂靠');
    return;
  }

  final Category? target = await showModalBottomSheet<Category>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppDimens.radiusLg)),
    ),
    builder: (BuildContext sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: () => Navigator.of(sheet).pop(),
                  icon: const Icon(Icons.close),
                ),
                const Expanded(
                  child: Text(
                    '改为子分类',
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
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: candidates.length,
              itemBuilder: (BuildContext ctx, int i) {
                final Category t = candidates[i];
                final Color color = t.colorValue != null
                    ? Color(t.colorValue!)
                    : AppColors.primary;
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    ),
                    child: Icon(categoryIconData(t.iconKey),
                        color: color, size: 22),
                  ),
                  title: Text(t.name),
                  onTap: () => Navigator.of(ctx).pop(t),
                );
              },
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
        ],
      ),
    ),
  );

  if (target == null) return;
  // 选择弹窗是 await 出来的，下面还要用 context 弹确认框。
  if (!context.mounted) return;

  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialog) => AlertDialog(
      title: const Text('改为子分类'),
      content: Text(
        '「${category.name}」将作为「${target.name}」的子分类，'
        '其原有子分类也会一并移入。',
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
    await ref
        .read(categoryRepositoryProvider)
        .changeToSubcategory(category.id, target.id);
    if (context.mounted) _toast(context, '已改为「${target.name}」的子分类');
  } on AppFailure catch (e) {
    if (context.mounted) _toast(context, e.message);
  }
}

/// 账单迁移：跳转到独立的账单迁移页。
Future<void> _showMigrateSheet(
  BuildContext context,
  WidgetRef ref,
  Category category,
) async {
  if (context.mounted) {
    await context.push(Routes.migrateCategory, extra: category);
  }
}

/// 改为主分类：将子分类提升为一级分类。
Future<void> _showPromoteSheet(
  BuildContext context,
  WidgetRef ref,
  Category category,
) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialog) => AlertDialog(
      title: const Text('改为主分类'),
      content: Text('「${category.name}」将变为主分类。'),
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
    await ref.read(categoryRepositoryProvider).promoteToParent(category.id);
    if (context.mounted) _toast(context, '「${category.name}」已变为主分类');
  } on AppFailure catch (e) {
    if (context.mounted) _toast(context, e.message);
  }
}

/// 子分类排序：拖拽重排同一主分类下的子分类顺序。
Future<void> _showChildSortSheet(
  BuildContext context,
  WidgetRef ref,
  String parentId,
  List<Category> children,
) async {
  final List<Category> items = children.toList()
    ..sort((Category a, Category b) => a.sortOrder.compareTo(b.sortOrder));
  if (items.length < 2) {
    _toast(context, '子分类不足两个，无需排序');
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppDimens.radiusLg)),
    ),
    builder: (BuildContext sheet) => SafeArea(
      child: StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setSheetState) {
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.7,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(AppDimens.spaceMd),
                  child: Row(
                    children: <Widget>[
                      const SizedBox(width: 48),
                      const Expanded(
                        child: Text(
                          '子分类排序',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ReorderableListView(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimens.spaceSm,
                    ),
                    buildDefaultDragHandles: true,
                    onReorderItem: (int oldIndex, int newIndex) async {
                      setSheetState(() {
                        final Category moved = items.removeAt(oldIndex);
                        items.insert(newIndex, moved);
                      });
                      final List<String> ids =
                          items.map((Category c) => c.id).toList();
                      await ref
                          .read(categoryRepositoryProvider)
                          .reorderChildren(parentId, ids);
                    },
                    children: <Widget>[
                      for (final Category c in items)
                        _SortTile(key: ValueKey<String>(c.id), category: c),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimens.spaceMd),
              ],
            ),
          );
        },
      ),
    ),
  );
}

void _toast(BuildContext context, String message) {
  showAppToast(context, message);
}
