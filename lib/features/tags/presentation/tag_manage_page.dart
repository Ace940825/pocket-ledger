import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/forest_design_tokens.dart';
import '../../../database/app_database.dart';
import '../../../database/daos/tags_dao.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../providers/tag_providers.dart';
import 'tag_empty_illustration.dart';
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
      backgroundColor: ForestBg.paper,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _navBar(scope),
            Expanded(
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                  ]
                else
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
        color: ForestBg.paper,
        child: Column(
          children: <Widget>[
            // 返回键独立一行，让分段键独占下一整行 ——
            // 与弹窗内分段键同宽（屏宽-28），修复两处 tab 尺寸不一致。
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.chevron_left, size: 26),
                  color: AppPalette.ink,
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

  Widget _headCard(TagScope scope) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ForestSurface.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ForestNeutral.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 标题行：# 徽章 + 「标签」
            Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ForestBg.sunken,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    '#',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '标签',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.ink,
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
                color: ForestBg.sunken,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '标签可用于区分哪个人花的钱，或哪个电商平台购买的物品。\n通用为全部账本都可用，账本独立的标签只在账本内显示。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.8,
                  color: AppPalette.ink3,
                ),
              ),
            ),
            const SizedBox(height: 14),
            // 功能开关行
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _enabled
                        ? '✓ 功能已开启（${scope.label}）'
                        : '功能默认关闭，点击设置进行开启',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          _enabled ? FontWeight.w700 : FontWeight.w400,
                      color:
                          _enabled ? AppPalette.deepGreen : AppPalette.ink3,
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
              decoration: BoxDecoration(
                color: ForestBg.sunken,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.search, size: 18, color: AppPalette.ink3),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtl,
                      decoration: const InputDecoration(
                        // 覆盖全局主题：无白色填充、无任何描边（含聚焦绿框）
                        filled: false,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: '搜索标签',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: AppPalette.ink3,
                        ),
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const TagEmptyIllustration(width: 120),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppPalette.ink3,
                height: 1.7,
              ),
            ),
          ],
        ),
      );

  // ───────────────────────── 分组卡 ─────────────────────────

  Widget _groupCard(TagGroupRow g) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ForestSurface.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ForestNeutral.hairline),
        ),
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
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.ink,
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
                  child: const Text(
                    '编辑',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.ink,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final Tag t in g.tags)
                  _GroupTagChip(tag: t, onRename: _openRenameTag),
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
            gradient: ForestGradients.sageMid,
            borderRadius: BorderRadius.circular(999),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppPalette.stockDown.withValues(alpha: 0.2),
                blurRadius: 14,
                offset: Offset(0, 5),
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

  Future<void> _insertTag(TagCategory category, String name) async {
    final TagsDao dao = ref.read(tagsDaoProvider);
    final int maxOrder = await dao.maxTagSortOrder(category.id);
    await dao.insertTag(
      TagsCompanion.insert(
        id: const Uuid().v4(),
        bookId: category.bookId,
        scope: category.scope,
        categoryId: category.id,
        name: name,
        sortOrder: Value<int>(maxOrder + 1),
        updatedAt: _now(),
      ),
    );
  }

  void _openAddCategory() {
    final TextEditingController ctl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) => _NameSheet(
        title: '添加类别',
        controller: ctl,
        confirmLabel: '保存',
        onConfirm: (String name) async {
          await _insertCategory(name);
          if (mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }

  void _openAddTag(TagCategory category) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) => _AddTagSheet(category: category),
    );
  }

  void _openRenameCategory(TagCategory category) {
    final TextEditingController ctl =
        TextEditingController(text: category.name);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) => _NameSheet(
        title: '编辑类别',
        controller: ctl,
        confirmLabel: '保存',
        onConfirm: (String name) async {
          await ref
              .read(tagsDaoProvider)
              .renameCategory(category.id, name, _now());
          if (mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }

  void _openRenameTag(Tag tag) {
    final TextEditingController ctl = TextEditingController(text: tag.name);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) => _NameSheet(
        title: '编辑标签',
        controller: ctl,
        confirmLabel: '保存',
        onConfirm: (String name) async {
          await ref.read(tagsDaoProvider).renameTag(tag.id, name, _now());
          if (mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }

  void _openContextMenu(TagCategory category) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: AppPalette.sage900,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _MenuItem(
              label: '编辑类别',
              onTap: () {
                Navigator.of(ctx).pop();
                _openRenameCategory(category);
              },
            ),
            _MenuItem(
              label: '类别排序',
              onTap: () {
                Navigator.of(ctx).pop();
                _openReorderCategories(category);
              },
            ),
            _MenuItem(
              label: '标签排序',
              onTap: () {
                Navigator.of(ctx).pop();
                if (category.scope == TagScope.general) {
                  // 仅用于提示，无需额外处理
                }
                _openReorderTags(category);
              },
            ),
            _MenuItem(
              label: '删除类别',
              danger: true,
              onTap: () {
                Navigator.of(ctx).pop();
                _confirmDeleteCategory(category);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCategory(TagCategory category) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: ForestSurface.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('删除类别', style: TextStyle(fontSize: 17)),
        content: Text(
          '确定删除「${category.name}」？其下标签也会一并删除。',
          style: const TextStyle(fontSize: 14, color: AppPalette.ink3),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消', style: TextStyle(color: AppPalette.ink3)),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(tagsDaoProvider).deleteCategory(category.id, _now());
              if (mounted) Navigator.of(ctx).pop();
            },
            child: const Text('删除', style: TextStyle(color: AppPalette.salmon)),
          ),
        ],
      ),
    );
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

/// 分组卡内的标签 chip（展示态，长按可重命名）。样式对齐设计稿未选态：
/// 沙底 + 发丝描边 + `#` 深绿前缀。
class _GroupTagChip extends StatelessWidget {
  const _GroupTagChip({required this.tag, required this.onRename});

  final Tag tag;
  final ValueChanged<Tag> onRename;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => onRename(tag),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: ForestBg.sunken,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: ForestNeutral.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              '#',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppPalette.deepGreen,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              tag.name,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppPalette.ink,
              ),
            ),
          ],
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: ForestBg.sunken,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: ForestNeutral.hairline),
        ),
        child: const Text(
          '＋',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppPalette.ink3,
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
          duration: Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 深色上下文菜单项。
class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14.5,
            color: danger ? AppPalette.coralSoft : AppPalette.sunkenCream,
          ),
        ),
      ),
    );
  }
}

/// 通用名称输入底部弹窗（添加/编辑类别、编辑标签复用）。
class _NameSheet extends StatelessWidget {
  const _NameSheet({
    required this.title,
    required this.controller,
    required this.confirmLabel,
    required this.onConfirm,
  });

  final String title;
  final TextEditingController controller;
  final String confirmLabel;
  final Future<void> Function(String name) onConfirm;

  @override
  Widget build(BuildContext context) {
    final ValueNotifier<bool> valid = ValueNotifier<bool>(false);
    controller.addListener(() {
      valid.value = controller.text.trim().isNotEmpty;
    });
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: ForestSurface.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: AppPalette.ink,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: ForestBg.sunken,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ForestNeutral.hairline),
            ),
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
                    gradient: v ? ForestGradients.sageMid : null,
                    color: v ? null : ForestBg.sunken,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    confirmLabel,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: v ? ForestSage.ink : ForestNeutral.textTertiary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: ForestSurface.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '添加标签',
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: AppPalette.ink,
            ),
          ),
          const SizedBox(height: 14),
          // 类别只读显示框
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: ForestBg.sunken,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ForestNeutral.hairline),
            ),
            child: Row(
              children: <Widget>[
                const Text(
                  '类别',
                  style: TextStyle(fontSize: 13, color: AppPalette.ink3),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.category.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: ForestBg.sunken,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ForestNeutral.hairline),
            ),
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
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: ForestBg.sunken,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '保存',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: v
                                ? ForestNeutral.textPrimary
                                : ForestNeutral.textTertiary,
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
                          gradient: v ? ForestGradients.sageMid : null,
                          color: v ? null : ForestBg.sunken,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '再次保存',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: v ? ForestSage.ink : ForestNeutral.textTertiary,
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
      ),
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

class _TagCategoryReorderPageState extends ConsumerState<TagCategoryReorderPage> {
  late List<TagCategory> _items = List<TagCategory>.of(widget.categories);

  Future<void> _persist() async {
    await ref
        .read(tagsDaoProvider)
        .reorderCategories(_items.map((TagCategory c) => c.id).toList(), _now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ForestBg.paper,
      appBar: AppBar(
        backgroundColor: ForestBg.paper,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.chevron_left, color: AppPalette.ink),
        ),
        title: const Text(
          '类别排序',
          style: TextStyle(fontSize: 16.5, color: AppPalette.ink),
        ),
        centerTitle: true,
      ),
      body: ReorderableListView(
        padding: const EdgeInsets.all(16),
        onReorder: (int oldIndex, int newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex -= 1;
            final TagCategory item = _items.removeAt(oldIndex);
            _items.insert(newIndex, item);
          });
          _persist();
        },
        children: <Widget>[
          for (final TagCategory c in _items)
            Container(
              key: ValueKey<String>(c.id),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: ForestSurface.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ForestNeutral.hairline),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.drag_handle, color: AppPalette.ink3),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      c.name,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
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
  late List<Tag> _items = List<Tag>.of(widget.tags);

  Future<void> _persist() async {
    await ref.read(tagsDaoProvider).reorderTags(
          widget.category.id,
          _items.map((Tag t) => t.id).toList(),
          _now(),
        );
  }

  Future<void> _delete(Tag tag) async {
    setState(() => _items.removeWhere((Tag t) => t.id == tag.id));
    await ref.read(tagsDaoProvider).softDeleteTag(tag.id, _now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ForestBg.paper,
      appBar: AppBar(
        backgroundColor: ForestBg.paper,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.chevron_left, color: AppPalette.ink),
        ),
        title: Text(
          '${widget.category.name} · 标签排序',
          style: const TextStyle(fontSize: 16.5, color: AppPalette.ink),
        ),
        centerTitle: true,
      ),
      body: _items.isEmpty
          ? const Center(
              child: Text(
                '该分组暂无标签',
                style: TextStyle(fontSize: 13.5, color: AppPalette.ink3),
              ),
            )
          : ReorderableListView(
              padding: const EdgeInsets.all(16),
              onReorder: (int oldIndex, int newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final Tag item = _items.removeAt(oldIndex);
                  _items.insert(newIndex, item);
                });
                _persist();
              },
              children: <Widget>[
                for (final Tag t in _items)
                  Container(
                    key: ValueKey<String>(t.id),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: ForestSurface.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ForestNeutral.hairline),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.drag_handle,
                            color: AppPalette.ink3),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            t.name,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppPalette.ink,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _delete(t),
                          icon: const Icon(Icons.delete_outline,
                              color: AppPalette.salmon),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
