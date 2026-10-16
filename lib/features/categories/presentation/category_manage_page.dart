import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocket_ledger/shared/widgets/clay_icon_tile.dart';
import 'package:pocket_ledger/shared/widgets/loading_state.dart';

import 'package:pocket_ledger/theme/app_dimens.dart';
import '../../../core/errors/failures.dart';
import '../../../core/theme/forest_design_tokens.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/action_group.dart';
import '../../../shared/widgets/action_row.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/category_widgets.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/line_icon_map.dart';
import '../../../shared/widgets/line_icons.dart';
import '../../../shared/widgets/sheet_scaffold.dart';
import '../../../theme/app_colors.dart';
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
                loading: () => const LoadingState(),
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
        horizontal: AppDimens.sm,
        vertical: AppDimens.sm,
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const LineGlyph(Icons.arrow_back_ios_new, size: 20),
          ),
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TypeTab(
                    label: '支出分类',
                    selected: _type == CategoryType.expense,
                    onTap: () => setState(() => _type = CategoryType.expense),
                  ),
                  const SizedBox(width: AppDimens.xxl),
                  TypeTab(
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
            // 字号与返回箭头对齐（20）；字形 2026-10-16 第 38 批重绘为
            // ↓↑ 双箭头（旧 ‹+↓+底线 读作漏斗，用户反馈「排序键有问题」）。
            icon: const LineGlyph(Icons.sort_outlined, size: 20),
            tooltip: '分类排序',
          ),
        ],
      ),
    );
  }

  Widget _buildArchivedToggle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.lg,
        AppDimens.sm,
        AppDimens.lg,
        0,
      ),
      child: Row(
        children: <Widget>[
          Text(
            '显示封存',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(width: AppDimens.sm),
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
    // 系统分类（借入/借出/转账/报销/退款/分期/存款等）由 ensureNamed 自动
    // 重建挂分类，用户分类管理页隐藏，不打扰手动管理。
    final List<Category> typed =
        list.where((Category c) => c.type == _type && !c.isSystem).toList();

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
        left: AppDimens.lg,
        right: AppDimens.lg,
        top: AppDimens.md,
        bottom: AppDimens.lg,
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
        AppDimens.lg,
        0,
        AppDimens.lg,
        AppDimens.lg,
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
    final bool? confirmed = await showConfirm(
      context,
      title: '删除分类？',
      content: '「${category.name}」将被删除。已使用该分类的流水会显示为「未分类」。',
      confirmText: '删除',
      danger: true,
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(categoryRepositoryProvider).remove(category.id);
    } on AppFailure catch (e) {
      if (context.mounted) _toast(context, e.message);
    }
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
          leading: ExpandArrow(
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

  /// 三点键 → 分类操作弹层（与账户详情页「账户操作」/报销页「更多」同款
  /// ActionGroup 风格，2026-10-16 第 37 批：此前用 MenuItem 设置行样式
  /// ——圆底图标 + 平铺分隔线 + 自绘标题栏（黏土砖 + 关闭钮），与全应用
  /// 操作弹层族割裂，用户截图反馈「跟其他弹窗风格不一致」）。
  ///
  /// 三组：编辑/改级/排序、数据（迁移/封存）、危险（删除）。
  /// 条目多（父 6 行 / 子 6 行），小屏/大字体下可能超出弹层高度上限——
  /// 用 ConstrainedBox 给出确定上限（Column(min) 传无界高度，裸
  /// SingleChildScrollView 不会滚、仍会溢出），内容矮时收缩包裹、超限时
  /// 弹层内滚动（同账户页注释）。
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

    final String? action = await showAppModalSheet<String>(
      context,
      title: '分类操作',
      // 条目多（最多 6 行）可能超过半屏：开 isScrollControlled 解除 9/16
      // 上限，由内部 ConstrainedBox(0.45) + SingleChildScrollView 管高度
      // （否则矮屏 + 标题 chrome 会溢出 1~2px，真机可见黄色条纹）。
      isScrollControlled: true,
      body: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.45,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ActionGroup(
                children: <Widget>[
                  ActionRow(
                    icon: const LineIcon(
                      LineIconKind.pencil,
                      size: 17,
                      color: ForestGreen.deep,
                    ),
                    title: isParent ? '编辑分类' : '编辑子分类',
                    subtitle: isParent
                        ? '修改「$name」分类'
                        : '修改「$name」子分类',
                    onTap: () => Navigator.of(context).pop('edit'),
                  ),
                  if (isParent) ...<Widget>[
                    ActionRow(
                      icon: const LineIcon(
                        LineIconKind.sortDesc,
                        size: 17,
                        color: ForestGreen.deep,
                      ),
                      title: '分类排序',
                      subtitle: '为主分类排序',
                      onTap: () => Navigator.of(context).pop('sort'),
                    ),
                    ActionRow(
                      icon: const LineIcon(
                        LineIconKind.arrowRight,
                        size: 17,
                        color: ForestGreen.deep,
                      ),
                      title: '改为子分类',
                      subtitle: '将「$name」归入其他主分类',
                      onTap: () => Navigator.of(context).pop('toSub'),
                    ),
                  ] else ...<Widget>[
                    ActionRow(
                      icon: const LineIcon(
                        LineIconKind.moveUp,
                        size: 17,
                        color: ForestGreen.deep,
                      ),
                      title: '改为主分类',
                      subtitle: '将「$name」变为主分类',
                      onTap: () => Navigator.of(context).pop('toParent'),
                    ),
                    ActionRow(
                      icon: const LineIcon(
                        LineIconKind.sortDesc,
                        size: 17,
                        color: ForestGreen.deep,
                      ),
                      title: '子分类排序',
                      subtitle: '为「$parentName」下的子分类排序',
                      onTap: () => Navigator.of(context).pop('childSort'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              ActionGroup(
                children: <Widget>[
                  ActionRow(
                    icon: const LineIcon(
                      LineIconKind.swapHorizontal,
                      size: 17,
                      color: ForestGreen.deep,
                    ),
                    title: '账单迁移',
                    subtitle: '仅迁移「$name」分类下的账单',
                    onTap: () => Navigator.of(context).pop('migrate'),
                  ),
                  ActionRow(
                    icon: const LineIcon(
                      LineIconKind.archiveBox,
                      size: 17,
                      color: ForestGreen.deep,
                    ),
                    title: category.isArchived
                        ? (isParent ? '取消封存分类' : '取消封存子分类')
                        : (isParent ? '封存分类' : '封存子分类'),
                    subtitle: category.isArchived
                        ? '将「$name」解封并恢复显示'
                        : '将「$name」封存，简化分类列表',
                    onTap: () => Navigator.of(context).pop(
                      category.isArchived ? 'unarchive' : 'archive',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ActionGroup(
                children: <Widget>[
                  ActionRow(
                    icon: const LineIcon(
                      LineIconKind.trash,
                      size: 17,
                      color: ForestSemantic.expense,
                    ),
                    title: isParent ? '删除分类' : '删除子分类',
                    subtitle: isParent
                        ? '迁移账单后删除，或直接删除分类'
                        : '迁移账单后删除，或直接删除子分类',
                    danger: true,
                    onTap: () => Navigator.of(context).pop('delete'),
                  ),
                ],
              ),
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
        : AppPalette.primary;

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: AppDimens.listTileHeight,
        child: Row(
          children: <Widget>[
            leading,
            ClayIconTile(
              size: 40,
              color: color,
              child: CategoryGlyph(
                category.iconKey,
                color: Color.lerp(
                  color,
                  Theme.of(context).colorScheme.onSurface,
                  0.22,
                )!,
                size: 22,
              ),
            ),
            const SizedBox(width: AppDimens.md),
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
                margin: const EdgeInsets.only(right: AppDimens.sm),
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
                child: Text(
                  '已封存',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                ),
              ),
            IconButton(
              onPressed: onMore,
              icon: LineGlyph(
                Icons.more_horiz,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        : AppPalette.primary;

    return SizedBox(
      width: 64,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // 第 36 批：添加瓦片改用与兄弟项同一套 [ClayIconTile] 黏土砖。
            // 此前是扁平奶油底 Container（无渐变/描边/投影/高光），混在周围
            // 渐变砖里明显割裂——用户截图反馈「跟其他图标风格不一致」。
            // 取色走全站特殊瓦片惯例（记一笔网格「设置」瓦片同款）：中性
            // onSurfaceVariant，渐变白→灰，与分类彩砖区隔「这是动作不是
            // 分类」；线稿加号与兄弟项同为 1.7 描边（字形本就是线稿，
            // 割裂的只是底砖）。
            ClayIconTile(
              size: 48,
              color: isAdd
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : color,
              child: isAdd
                  ? LineIcon(
                      LineIconKind.add,
                      size: 24,
                      color: Color.lerp(
                        Theme.of(context).colorScheme.onSurfaceVariant,
                        Theme.of(context).colorScheme.onSurface,
                        0.22,
                      )!,
                    )
                  : CategoryGlyph(
                      category!.iconKey,
                      color: Color.lerp(
                        color,
                        Theme.of(context).colorScheme.onSurface,
                        0.22,
                      )!,
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
                    color: isAdd
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : null,
                    fontSize: 12,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 分类排序：支出、收入各自独立排序一级分类。
///
/// 顶部「支出分类 / 收入分类」分段切换，只展示当前段的一级分类，两段互不干扰。
/// `sortOrder` 在库内**按类型各自从 0 编号**（见 `bootstrap.dart` 种子），
/// 所以这里只把本类型的 id 序列交给 [CategoryRepository.reorderParents]
/// 重新编号，不会打乱另一类型的顺序。
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

  // 一级分类按类型拆成两段（支出 / 收入），段内按 sortOrder 排。
  // sortOrder 在库内本就按类型各自从 0 编号，因此两段互不干扰。
  List<Category> parentsOf(CategoryType t) => all
      .where((Category c) => c.parentId == null && c.type == t && !c.isSystem)
      .toList()
    ..sort((Category a, Category b) => a.sortOrder.compareTo(b.sortOrder));

  final Map<CategoryType, List<Category>> segments =
      <CategoryType, List<Category>>{
    CategoryType.expense: parentsOf(CategoryType.expense),
    CategoryType.income: parentsOf(CategoryType.income),
  };
  final bool anySortable =
      segments.values.any((List<Category> list) => list.length > 1);
  if (!anySortable) {
    _toast(context, '分类不足两个，无需排序');
    return;
  }

  // 从哪个类型进来就默认展示哪一段。
  CategoryType current = type;

  await showAppModalSheet<void>(
    context,
    title: '分类排序',
    titleTrailing: IconButton(
      onPressed: () => Navigator.of(context).pop(),
      icon: const LineGlyph(Icons.close),
    ),
    // 第 38 批修复：body 是 Column + Expanded(ReorderableListView)，
    // 而 AppModalSheet 默认 constrainHeight=false（外壳 Column 为 min，
    // body 拿无界高度）→ Expanded 撞 SDK 断言
    // 「non-zero flex but incoming height constraints are unbounded」
    // 直接崩。isScrollControlled 只放行底层路由突破 9/16，不改外壳约束，
    // 必须 constrainHeight=true 让 body 填满有界剩余空间。
    isScrollControlled: true,
    constrainHeight: true,
    body: StatefulBuilder(
      builder: (BuildContext ctx, StateSetter setSheetState) {
        // 当前段的一级分类（与 segments 里的实例同一引用，拖拽后原地更新）。
        final List<Category> items = segments[current]!;
        return Column(
          children: <Widget>[
            // 支出 / 收入 分段切换：两段各自独立排序，互不影响。
            Padding(
              padding: const EdgeInsets.only(top: AppDimens.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  TypeTab(
                    label: _typeLabel(CategoryType.expense),
                    selected: current == CategoryType.expense,
                    onTap: () => setSheetState(
                      () => current = CategoryType.expense,
                    ),
                  ),
                  const SizedBox(width: AppDimens.xxl),
                  TypeTab(
                    label: _typeLabel(CategoryType.income),
                    selected: current == CategoryType.income,
                    onTap: () => setSheetState(
                      () => current = CategoryType.income,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.sm),
            Expanded(
              child: items.length < 2
                  ? Center(
                      child: Text(
                        '该类型分类不足两个，无需排序',
                        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    )
                  : ReorderableListView(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimens.sm,
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
                          _SortTile(
                            key: ValueKey<String>(c.id),
                            category: c,
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: AppDimens.md),
          ],
        );
      },
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
        : AppPalette.primary;
    return ListTile(
      leading: ClayIconTile(
        size: 40,
        color: color,
        child: CategoryGlyph(
          category.iconKey,
          color: Color.lerp(
            color,
            Theme.of(context).colorScheme.onSurface,
            0.22,
          )!,
          size: 22,
        ),
      ),
      title: Text(category.name),
      trailing: LineGlyph(
        Icons.drag_handle,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
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
      .where(
        (Category c) =>
            c.parentId == null && c.id != category.id && !c.isSystem,
      )
      .toList()
    ..sort((Category a, Category b) => a.sortOrder.compareTo(b.sortOrder));
  if (candidates.isEmpty) {
    _toast(context, '没有其他一级分类可挂靠');
    return;
  }

  final Category? target = await showAppModalSheet<Category>(
    context,
    title: '改为子分类',
    titleTrailing: IconButton(
      onPressed: () => Navigator.of(context).pop(),
      icon: const LineGlyph(Icons.close),
    ),
    isScrollControlled: true,
    body: ListView.builder(
      itemCount: candidates.length,
      itemBuilder: (BuildContext ctx, int i) {
        final Category t = candidates[i];
        final Color color =
            t.colorValue != null ? Color(t.colorValue!) : AppPalette.primary;
        return ListTile(
          leading: ClayIconTile(
            size: 40,
            color: color,
            child: CategoryGlyph(
              t.iconKey,
              color: Color.lerp(
                color,
                Theme.of(context).colorScheme.onSurface,
                0.22,
              )!,
              size: 22,
            ),
          ),
          title: Text(t.name),
          onTap: () => Navigator.of(ctx).pop(t),
        );
      },
    ),
  );

  if (target == null) return;
  // 选择弹窗是 await 出来的，下面还要用 context 弹确认框。
  if (!context.mounted) return;

  final bool? confirmed = await showConfirm(
    context,
    title: '改为子分类',
    content: '「${category.name}」将作为「${target.name}」的子分类，'
        '其原有子分类也会一并移入。',
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
  final bool? confirmed = await showConfirm(
    context,
    title: '改为主分类',
    content: '「${category.name}」将变为主分类。',
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

  await showAppModalSheet<void>(
    context,
    title: '子分类排序',
    titleTrailing: IconButton(
      onPressed: () => Navigator.of(context).pop(),
      icon: const LineGlyph(Icons.close),
    ),
    // 同「分类排序」：body 内纵向 Expanded 必须有界，否则无界高度断言崩。
    isScrollControlled: true,
    constrainHeight: true,
    body: StatefulBuilder(
      builder: (BuildContext ctx, StateSetter setSheetState) {
        return Column(
          children: <Widget>[
            Expanded(
              child: ReorderableListView(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimens.sm,
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
            const SizedBox(height: AppDimens.md),
          ],
        );
      },
    ),
  );
}

void _toast(BuildContext context, String message) {
  showAppToast(context, message);
}

/// 分类类型的中文名（排序页分段标题与分类管理页 Tab 共用）。
String _typeLabel(CategoryType type) =>
    type == CategoryType.income ? '收入分类' : '支出分类';
