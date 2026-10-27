import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:pocket_ledger/features/ledger/presentation/widgets/txn_slidable.dart';
import 'package:pocket_ledger/shared/widgets/action_group.dart';
import 'package:pocket_ledger/shared/widgets/action_row.dart';
import 'package:pocket_ledger/shared/widgets/confirm_dialog.dart';
import 'package:pocket_ledger/shared/widgets/empty_state.dart';
import 'package:pocket_ledger/shared/widgets/hairline_card.dart';
import 'package:pocket_ledger/shared/widgets/sheet_scaffold.dart';
import 'package:pocket_ledger/shared/widgets/sunken_box.dart';
import 'package:pocket_ledger/shared/widgets/tag_chip.dart';
import 'package:uuid/uuid.dart';

import '../../../database/app_database.dart';
import '../../../database/daos/tags_dao.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/widgets/line_icon_map.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../providers/tag_providers.dart';
import 'tag_scope_toggle.dart';
import 'tag_toast.dart';

/// 标签管理页（全屏，从右滑入）。
///
/// 由 [TagSheet] 的「添加」进入；点顶部「‹ 返回」退回选择弹窗，新增/删除/
/// 排序即时同步。通用 / 账本独立作用域与弹窗共享 [tagScopeProvider]。
class TagManagePage extends ConsumerStatefulWidget {
  const TagManagePage({super.key});

  @override
  ConsumerState<TagManagePage> createState() => _TagManagePageState();
}

int _now() => DateTime.now().toUtc().millisecondsSinceEpoch;

class _TagManagePageState extends ConsumerState<TagManagePage> {
  /// 标签功能总开关（默认开）。关闭后仅显示说明卡 + 空态。
  bool _enabled = true;

  final TextEditingController _searchCtl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtl.addListener(() {
      if (mounted) setState(() => _query = _searchCtl.text.trim());
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  /// 管理页搜索过滤（对齐设计稿 filterManage：分组名或任一标签名命中即保留）。
  List<TagGroupRow> _filter(List<TagGroupRow> groups) {
    if (_query.isEmpty) return groups;
    final String q = _query.toLowerCase();
    return groups
        .where(
          (TagGroupRow g) =>
              g.category.name.toLowerCase().contains(q) ||
              g.tags.any((Tag t) => t.name.toLowerCase().contains(q)),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final TagScope scope = ref.watch(tagScopeProvider);
    final AsyncValue<List<TagGroupRow>> libAsync =
        ref.watch(tagsLibraryProvider(scope));
    final List<TagGroupRow> groups = _filter(libAsync.value ?? <TagGroupRow>[]);

    return Scaffold(
      backgroundColor: context.forest.surface,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _navBar(scope),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 110),
                children: <Widget>[
                  _headCard(scope),
                  if (_enabled) ...<Widget>[
                    if (groups.isEmpty)
                      _emptyHint(
                        '没有发现标签哦，试着去添加一个~',
                      )
                    else
                      for (final TagGroupRow g in groups)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _groupCard(g),
                        ),
                  ] else
                    _emptyHint('标签功能未开启，打开开关开始使用~'),
                ],
              ),
            ),
            if (_enabled) _addCategoryButton(),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── 顶部导航 ─────────────────────────

  Widget _navBar(TagScope scope) => Container(
        // body 已有 SafeArea，这里只需留出返回键上方的呼吸空间。
        padding: const EdgeInsets.only(top: 4),
        color: context.forest.surface,
        child: Column(
          children: <Widget>[
            // 返回键独立一行，让分段键独占下一整行 ——
            // 与弹窗内分段键同宽（屏宽-28），修复两处 tab 尺寸不一致。
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const LineGlyph(Icons.chevron_left, size: 26),
                  color: context.forest.onSurface,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Center(
                child: SizedBox(
                  width: 240,
                  child: TagScopeToggle(
                    scope: scope,
                    onChanged: (TagScope s) {
                      ref.read(tagScopeProvider.notifier).state = s;
                      setState(() {});
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  // ───────────────────── 头部大卡（标题+说明+开关+搜索，单卡） ─────────────────────

  Widget _headCard(TagScope scope) => HairlineCard(
        backgroundColor: context.forest.surface,
        borderColor: context.forest.outline,
        radius: 16,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 标题行：# 徽章 + 「标签」
            Row(
              children: <Widget>[
                SunkenBox(
                  width: 44,
                  height: 44,
                  radius: 14,
                  alignment: Alignment.center,
                  child: Text(
                    '#',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: context.forest.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '标签',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.forest.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // 说明（沙底 info-box）
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.forest.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '标签可用于区分哪个人花的钱，或哪个电商平台购买的物品。\n通用为全部账本都可用，账本独立的标签只在账本内显示。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.8,
                  color: context.forest.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 14),
            // 功能开关行
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _enabled ? '✓ 功能已开启（${scope.label}）' : '功能默认关闭，点击设置进行开启',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _enabled ? FontWeight.w700 : FontWeight.w400,
                      color: _enabled
                          ? AppPalette.deepGreen
                          : context.forest.onSurfaceVariant,
                    ),
                  ),
                ),
                _FeatureSwitch(
                  value: _enabled,
                  onChanged: (bool v) {
                    setState(() => _enabled = v);
                    showTagToast(context, v ? '标签功能已开启' : '标签功能已关闭');
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 卡内搜索框
            SunkenBox(
              radius: 12,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
              child: Row(
                children: <Widget>[
                  LineGlyph(
                    Icons.search,
                    size: 18,
                    color: context.forest.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtl,
                      decoration: InputDecoration(
                        // 覆盖全局主题：无白色填充、无任何描边（含聚焦绿框）
                        filled: false,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: '搜索标签',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: context.forest.onSurfaceVariant,
                        ),
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _emptyHint(String text) => SizedBox(
        height: 280,
        child: EmptyState(
          icon: Icons.label_outline,
          message: text,
        ),
      );

  // ───────────────────────── 分组卡 ─────────────────────────

  Widget _groupCard(TagGroupRow g) => HairlineCard(
        backgroundColor: context.forest.surface,
        borderColor: context.forest.outline,
        radius: 16,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 3.5,
                  height: 15,
                  decoration: BoxDecoration(
                    color: ForestGreen.deep,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    g.category.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: context.forest.onSurface,
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _openContextMenu(g.category),
                  child: Text(
                    '编辑',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.forest.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final Tag t in g.tags)
                  GestureDetector(
                    onLongPress: () => _openRenameTag(t),
                    child: TagChip(label: t.name),
                  ),
                _AddTagChip(category: g.category, onTap: _openAddTag),
              ],
            ),
          ],
        ),
      );

  // ───────────────────────── 底部「添加类别」 ─────────────────────────

  Widget _addCategoryButton() => SafeArea(
        top: false,
        child: Container(
          height: 50,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            gradient: context.app.sageGradientMid,
            borderRadius: BorderRadius.circular(999),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppPalette.stockDown.withValues(alpha: 0.2),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: InkWell(
            onTap: _openAddCategory,
            borderRadius: BorderRadius.circular(999),
            child: const Center(
              child: Text(
                '添加类别',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.sageInk,
                  letterSpacing: 0.08,
                ),
              ),
            ),
          ),
        ),
      );

  // ───────────────────────── 操作 ─────────────────────────

  Future<void> _insertCategory(String name) async {
    final TagScope scope = ref.read(tagScopeProvider);
    final String bookId = ref.read(currentBookIdProvider);
    final String effectiveBook = scope == TagScope.general ? '' : bookId;
    final TagsDao dao = ref.read(tagsDaoProvider);
    final int maxOrder = await dao.maxCategorySortOrder(scope, effectiveBook);
    await dao.insertCategory(
      TagCategoriesCompanion.insert(
        id: const Uuid().v4(),
        bookId: effectiveBook,
        scope: scope,
        name: name,
        sortOrder: Value<int>(maxOrder + 1),
        updatedAt: _now(),
      ),
    );
  }

  void _openAddCategory() {
    final TextEditingController ctl = TextEditingController();
    showAppModalSheet<void>(
      context,
      title: '添加类别',
      isScrollControlled: true,
      body: _NameSheet(
        controller: ctl,
        confirmLabel: '保存',
        onConfirm: (String name) async {
          await _insertCategory(name);
          if (mounted) Navigator.of(context).pop();
        },
      ),
    );
  }

  void _openAddTag(TagCategory category) {
    showAppModalSheet<void>(
      context,
      title: '添加标签',
      isScrollControlled: true,
      body: _AddTagSheet(category: category),
    );
  }

  void _openRenameCategory(TagCategory category) {
    final TextEditingController ctl =
        TextEditingController(text: category.name);
    showAppModalSheet<void>(
      context,
      title: '编辑类别',
      isScrollControlled: true,
      body: _NameSheet(
        controller: ctl,
        confirmLabel: '保存',
        onConfirm: (String name) async {
          await ref
              .read(tagsDaoProvider)
              .renameCategory(category.id, name, _now());
          if (mounted) Navigator.of(context).pop();
        },
      ),
    );
  }

  void _openRenameTag(Tag tag) {
    final TextEditingController ctl = TextEditingController(text: tag.name);
    showAppModalSheet<void>(
      context,
      title: '编辑标签',
      isScrollControlled: true,
      body: _NameSheet(
        controller: ctl,
        confirmLabel: '保存',
        onConfirm: (String name) async {
          await ref.read(tagsDaoProvider).renameTag(tag.id, name, _now());
          if (mounted) Navigator.of(context).pop();
        },
      ),
    );
  }

  /// 类别操作弹层（与账户详情页「账户操作」同款 ActionGroup 风格）。
  ///
  /// 标题走 [showAppModalSheet] 的统一标题栏（带发丝线），条目用 [ActionRow]
  /// （图标 + 标题 + 副标题 + 箭头），暗色随 ColorScheme 自动适配。
  void _openContextMenu(TagCategory category) {
    showAppModalSheet<void>(
      context,
      title: '类别操作',
      body: ActionGroup(
        children: <Widget>[
          ActionRow(
            icon: const LineGlyph(
              Icons.edit_outlined,
              size: 18,
              color: ForestGreen.deep,
            ),
            title: '编辑类别',
            subtitle: '修改类别名称',
            onTap: () {
              Navigator.of(context).pop();
              _openRenameCategory(category);
            },
          ),
          ActionRow(
            icon: const LineGlyph(Icons.swap_vert,
                size: 18, color: ForestGreen.deep,),
            title: '类别排序',
            subtitle: '拖拽调整类别顺序',
            onTap: () {
              Navigator.of(context).pop();
              _openReorderCategories(category);
            },
          ),
          ActionRow(
            icon: const LineGlyph(
              Icons.label_outline,
              size: 18,
              color: ForestGreen.deep,
            ),
            title: '标签排序',
            subtitle: '拖拽调整标签顺序',
            onTap: () {
              Navigator.of(context).pop();
              _openReorderTags(category);
            },
          ),
          ActionRow(
            icon: const LineGlyph(
              Icons.delete_outline,
              size: 18,
              color: ForestSemantic.expense,
            ),
            title: '删除类别',
            subtitle: '同时删除其下全部标签',
            danger: true,
            onTap: () {
              Navigator.of(context).pop();
              _confirmDeleteCategory(category);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteCategory(TagCategory category) async {
    final bool? ok = await showConfirm(
      context,
      title: '删除类别',
      content: '确定删除「${category.name}」？其下标签也会一并删除。',
      confirmText: '删除',
      danger: true,
    );
    if (ok != true) return;
    await ref.read(tagsDaoProvider).deleteCategory(category.id, _now());
  }

  void _openReorderCategories(TagCategory current) {
    final List<TagGroupRow> groups =
        ref.read(tagsLibraryProvider(ref.read(tagScopeProvider))).value ??
            <TagGroupRow>[];
    final List<TagCategory> cats =
        groups.map((TagGroupRow g) => g.category).toList();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => TagCategoryReorderPage(categories: cats),
      ),
    );
  }

  void _openReorderTags(TagCategory category) {
    final List<TagGroupRow> groups =
        ref.read(tagsLibraryProvider(ref.read(tagScopeProvider))).value ??
            <TagGroupRow>[];
    final TagGroupRow? found = groups
        .where((TagGroupRow g) => g.category.id == category.id)
        .firstOrNull;
    if (found == null || found.tags.isEmpty) {
      showTagToast(context, '该分组暂无标签，先添加一个吧~');
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => TagReorderPage(
          category: category,
          tags: found.tags,
        ),
      ),
    );
  }
}

/// 分组卡内「＋」快速加标签（设计稿 .chip.add：胶囊形灰绿字）。
class _AddTagChip extends StatelessWidget {
  const _AddTagChip({required this.category, required this.onTap});

  final TagCategory category;
  final ValueChanged<TagCategory> onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(category),
      borderRadius: BorderRadius.circular(999),
      child: SunkenBox(
        radius: 999,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          '＋',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: context.forest.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// 功能开关（设计稿 .switch：46×27 胶囊，on = #7FB98A，白色圆钮）。
class _FeatureSwitch extends StatelessWidget {
  const _FeatureSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: 46,
        height: 27,
        padding: const EdgeInsets.only(left: 3, right: 3),
        decoration: BoxDecoration(
          color: value ? AppPalette.sageMeadow : AppPalette.sandStone,
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: context.forest.surface,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Theme.of(context)
                      .colorScheme
                      .shadow
                      .withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 通用名称输入底部弹窗（添加/编辑类别、编辑标签复用）。
class _NameSheet extends StatelessWidget {
  const _NameSheet({
    required this.controller,
    required this.confirmLabel,
    required this.onConfirm,
  });

  final TextEditingController controller;
  final String confirmLabel;
  final Future<void> Function(String name) onConfirm;

  @override
  Widget build(BuildContext context) {
    final ValueNotifier<bool> valid = ValueNotifier<bool>(false);
    controller.addListener(() {
      valid.value = controller.text.trim().isNotEmpty;
    });
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SunkenBox(
          radius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              filled: false,
              focusedBorder: InputBorder.none,
              border: InputBorder.none,
              isCollapsed: true,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
            style: const TextStyle(fontSize: 14),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ValueListenableBuilder<bool>(
            valueListenable: valid,
            builder: (BuildContext ctx, bool v, _) => InkWell(
              onTap: v
                  ? () async {
                      await onConfirm(controller.text.trim());
                    }
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: v ? context.app.sageGradientMid : null,
                  color: v ? null : context.forest.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  confirmLabel,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: v
                        ? ForestSage.ink
                        : context.forest.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 添加标签弹窗（类别字段为只读显示框，支持「再次保存」连续添加）。
class _AddTagSheet extends ConsumerStatefulWidget {
  const _AddTagSheet({required this.category});

  final TagCategory category;

  @override
  ConsumerState<_AddTagSheet> createState() => _AddTagSheetState();
}

class _AddTagSheetState extends ConsumerState<_AddTagSheet> {
  final TextEditingController _ctl = TextEditingController();
  final ValueNotifier<bool> _valid = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _ctl.addListener(() {
      _valid.value = _ctl.text.trim().isNotEmpty;
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    _valid.dispose();
    super.dispose();
  }

  Future<void> _save(bool keepOpen) async {
    final String name = _ctl.text.trim();
    if (name.isEmpty) return;
    final TagsDao dao = ref.read(tagsDaoProvider);
    final int maxOrder = await dao.maxTagSortOrder(widget.category.id);
    await dao.insertTag(
      TagsCompanion.insert(
        id: const Uuid().v4(),
        bookId: widget.category.bookId,
        scope: widget.category.scope,
        categoryId: widget.category.id,
        name: name,
        sortOrder: Value<int>(maxOrder + 1),
        updatedAt: _now(),
      ),
    );
    if (!mounted) return;
    if (keepOpen) {
      _ctl.clear();
      showTagToast(context, '已添加「$name」');
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // 类别只读显示框
        SunkenBox(
          width: double.infinity,
          radius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: <Widget>[
              Text(
                '类别',
                style: TextStyle(
                  fontSize: 13,
                  color: context.forest.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.category.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.forest.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SunkenBox(
          radius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            controller: _ctl,
            autofocus: true,
            decoration: const InputDecoration(
              filled: false,
              focusedBorder: InputBorder.none,
              border: InputBorder.none,
              isCollapsed: true,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
            style: const TextStyle(fontSize: 14),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: SizedBox(
                height: 44,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _valid,
                  builder: (_, bool v, __) => InkWell(
                    onTap: v ? () => _save(false) : null,
                    borderRadius: BorderRadius.circular(12),
                    child: SunkenBox(
                      radius: 12,
                      alignment: Alignment.center,
                      child: Text(
                        '保存',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: v
                              ? context.forest.onSurface
                              : context.forest.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 44,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _valid,
                  builder: (_, bool v, __) => InkWell(
                    onTap: v ? () => _save(true) : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: v ? context.app.sageGradientMid : null,
                        color:
                            v ? null : context.forest.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '再次保存',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: v
                              ? ForestSage.ink
                              : context.forest.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 类别排序页（纵向拖拽，避开横向溢出坑）。
class TagCategoryReorderPage extends ConsumerStatefulWidget {
  const TagCategoryReorderPage({super.key, required this.categories});

  final List<TagCategory> categories;

  @override
  ConsumerState<TagCategoryReorderPage> createState() =>
      _TagCategoryReorderPageState();
}

class _TagCategoryReorderPageState
    extends ConsumerState<TagCategoryReorderPage> {
  late final List<TagCategory> _items = List<TagCategory>.of(widget.categories);

  Future<void> _persist() async {
    await ref.read(tagsDaoProvider).reorderCategories(
          _items.map((TagCategory c) => c.id).toList(),
          _now(),
        );
  }

  // ───────────────── 左滑动作：迁移 / 编辑 / 删除 ─────────────────

  void _renameCategory(TagCategory c) {
    final TextEditingController ctl = TextEditingController(text: c.name);
    showAppModalSheet<void>(
      context,
      title: '编辑类别',
      isScrollControlled: true,
      body: _NameSheet(
        controller: ctl,
        confirmLabel: '保存',
        onConfirm: (String name) async {
          await ref.read(tagsDaoProvider).renameCategory(c.id, name, _now());
          if (mounted) Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _deleteCategory(TagCategory c) async {
    final bool? ok = await showConfirm(
      context,
      title: '删除类别',
      content: '确定删除「${c.name}」？其下标签也会一并删除。',
      confirmText: '删除',
      danger: true,
    );
    if (ok != true) return;
    setState(() => _items.removeWhere((TagCategory e) => e.id == c.id));
    await ref.read(tagsDaoProvider).deleteCategory(c.id, _now());
  }

  void _migrateCategory(TagCategory source) {
    final List<TagCategory> targets =
        _items.where((TagCategory c) => c.id != source.id).toList();
    if (targets.isEmpty) {
      showTagToast(context, '没有其他类别可迁移');
      return;
    }
    showAppModalSheet<void>(
      context,
      title: '迁移标签到…',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final TagCategory t in targets)
            ListTile(
                title: Text(t.name),
                onTap: () {
                  Navigator.of(context).pop();
                  _confirmMigrateCategory(source, t);
                },),
        ],
      ),
    );
  }

  Future<void> _confirmMigrateCategory(
    TagCategory source,
    TagCategory target,
  ) async {
    final bool? ok = await showConfirm(
      context,
      title: '迁移标签',
      content: '「${source.name}」下的全部标签将迁移到「${target.name}」。',
      confirmText: '迁移',
    );
    if (ok != true) return;
    final int n = await ref
        .read(tagsDaoProvider)
        .migrateCategoryTags(source.id, target.id, _now());
    if (mounted) {
      showTagToast(context, n > 0 ? '已迁移 $n 个标签' : '该类别下没有标签');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.forest.surface,
      appBar: AppBar(
        backgroundColor: context.forest.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: LineGlyph(
            Icons.chevron_left,
            color: context.forest.onSurface,
          ),
        ),
        title: const Text('类别排序'),
        centerTitle: true,
      ),
      body: TxnSlidableGroup(
        child: ReorderableListView(
          padding: const EdgeInsets.all(16),
          // 关默认拖拽柄：长按整行拖拽（与左滑手势互不冲突）。
          buildDefaultDragHandles: false,
          onReorderItem: (int oldIndex, int newIndex) {
            setState(() {
              // onReorderItem 的 newIndex 已内置移除项修正，无需再 -1。
              final TagCategory item = _items.removeAt(oldIndex);
              _items.insert(newIndex, item);
            });
            _persist();
          },
          children: <Widget>[
            for (int i = 0; i < _items.length; i++)
              ReorderableDelayedDragStartListener(
                key: ValueKey<String>(_items[i].id),
                index: i,
                child: Slidable(
                  groupTag: TxnSlidable.groupTag,
                  endActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    extentRatio: 0.48,
                    children: <Widget>[
                      TxnSlideAction(
                        icon: Icons.drive_file_move_outlined,
                        semanticLabel: '迁移',
                        color: AppPalette.clayBrown,
                        onPressed: () => _migrateCategory(_items[i]),
                      ),
                      TxnSlideAction(
                        icon: Icons.edit_outlined,
                        semanticLabel: '编辑',
                        color: AppPalette.info,
                        onPressed: () => _renameCategory(_items[i]),
                      ),
                      TxnSlideAction(
                        icon: Icons.delete_outline,
                        semanticLabel: '删除',
                        color: AppPalette.danger,
                        onPressed: () => _deleteCategory(_items[i]),
                      ),
                    ],
                  ),
                  child: HairlineCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    backgroundColor: context.forest.surface,
                    borderColor: context.forest.outline,
                    radius: 14,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            _items[i].name,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: context.forest.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 标签排序页（纵向拖拽，可删除单个标签）。
class TagReorderPage extends ConsumerStatefulWidget {
  const TagReorderPage({
    super.key,
    required this.category,
    required this.tags,
  });

  final TagCategory category;
  final List<Tag> tags;

  @override
  ConsumerState<TagReorderPage> createState() => _TagReorderPageState();
}

class _TagReorderPageState extends ConsumerState<TagReorderPage> {
  late final List<Tag> _items = List<Tag>.of(widget.tags);

  Future<void> _persist() async {
    await ref.read(tagsDaoProvider).reorderTags(
          widget.category.id,
          _items.map((Tag t) => t.id).toList(),
          _now(),
        );
  }

  // ───────────────── 左滑动作：迁移 / 编辑 / 删除 ─────────────────

  void _renameTag(Tag t) {
    final TextEditingController ctl = TextEditingController(text: t.name);
    showAppModalSheet<void>(
      context,
      title: '编辑标签',
      isScrollControlled: true,
      body: _NameSheet(
        controller: ctl,
        confirmLabel: '保存',
        onConfirm: (String name) async {
          await ref.read(tagsDaoProvider).renameTag(t.id, name, _now());
          if (mounted) Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _delete(Tag tag) async {
    // 与全应用删除交互对齐：先确认再删（此前点击直接软删，易误触）。
    final bool? confirmed = await showConfirm(
      context,
      title: '删除标签',
      content: '确定删除标签「${tag.name}」吗？',
      confirmText: '删除',
      danger: true,
    );
    if (confirmed != true) return;
    setState(() => _items.removeWhere((Tag t) => t.id == tag.id));
    await ref.read(tagsDaoProvider).softDeleteTag(tag.id, _now());
  }

  /// 迁移：把流水中旧标签名的账单全部改挂到目标标签（流水只存标签名）。
  void _migrateTag(Tag source) {
    final List<Tag> targets =
        _items.where((Tag t) => t.id != source.id).toList();
    if (targets.isEmpty) {
      showTagToast(context, '没有其他标签可迁移');
      return;
    }
    showAppModalSheet<void>(
      context,
      title: '迁移账单到标签…',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final Tag t in targets)
            ListTile(
                title: Text(t.name),
                onTap: () {
                  Navigator.of(context).pop();
                  _confirmMigrateTag(source, t);
                },),
        ],
      ),
    );
  }

  Future<void> _confirmMigrateTag(Tag source, Tag target) async {
    final bool? ok = await showConfirm(
      context,
      title: '迁移标签',
      content: '「${source.name}」名下的全部账单将迁移到「${target.name}」。',
      confirmText: '迁移',
    );
    if (ok != true) return;
    final int n = await ref
        .read(transactionsDaoProvider)
        .migrateTagName(source.name, target.name, _now());
    if (mounted) {
      showTagToast(context, n > 0 ? '已迁移 $n 笔账单' : '没有使用该标签的账单');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.forest.surface,
      appBar: AppBar(
        backgroundColor: context.forest.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: LineGlyph(
            Icons.chevron_left,
            color: context.forest.onSurface,
          ),
        ),
        title: Text('${widget.category.name} · 标签排序'),
        centerTitle: true,
      ),
      body: _items.isEmpty
          ? Center(
              child: Text(
                '该分组暂无标签',
                style: TextStyle(
                  fontSize: 13.5,
                  color: context.forest.onSurfaceVariant,
                ),
              ),
            )
          : TxnSlidableGroup(
              child: ReorderableListView(
                padding: const EdgeInsets.all(16),
                // 关默认拖拽柄：长按整行拖拽（与左滑手势互不冲突）。
                buildDefaultDragHandles: false,
                onReorderItem: (int oldIndex, int newIndex) {
                  setState(() {
                    // onReorderItem 的 newIndex 已内置移除项修正，无需再 -1。
                    final Tag item = _items.removeAt(oldIndex);
                    _items.insert(newIndex, item);
                  });
                  _persist();
                },
                children: <Widget>[
                  for (int i = 0; i < _items.length; i++)
                    ReorderableDelayedDragStartListener(
                      key: ValueKey<String>(_items[i].id),
                      index: i,
                      child: Slidable(
                        groupTag: TxnSlidable.groupTag,
                        endActionPane: ActionPane(
                          motion: const DrawerMotion(),
                          extentRatio: 0.48,
                          children: <Widget>[
                            TxnSlideAction(
                              icon: Icons.drive_file_move_outlined,
                              semanticLabel: '迁移',
                              color: AppPalette.clayBrown,
                              onPressed: () => _migrateTag(_items[i]),
                            ),
                            TxnSlideAction(
                              icon: Icons.edit_outlined,
                              semanticLabel: '编辑',
                              color: AppPalette.info,
                              onPressed: () => _renameTag(_items[i]),
                            ),
                            TxnSlideAction(
                              icon: Icons.delete_outline,
                              semanticLabel: '删除',
                              color: AppPalette.danger,
                              onPressed: () => _delete(_items[i]),
                            ),
                          ],
                        ),
                        child: HairlineCard(
                          margin: const EdgeInsets.only(bottom: 10),
                          backgroundColor: context.forest.surface,
                          borderColor: context.forest.outline,
                          radius: 14,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  _items[i].name,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        context.forest.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
