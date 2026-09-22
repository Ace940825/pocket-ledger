import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/forest_design_tokens.dart';
import '../../../database/app_database.dart';
import '../../../database/daos/tags_dao.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../providers/tag_providers.dart';
import 'tag_empty_illustration.dart';
import 'tag_manage_page.dart';
import 'tag_scope_toggle.dart';

/// 标签选择弹窗（50% 半屏）。
///
/// 覆盖在记一笔页之上，是标签功能的主交互入口；点「添加」进入 [TagManagePage]
/// （全屏），返回后已选/新增标签保持同步。选中结果以「标签名列表」回写，
/// 与 [Transactions.tags] 的存储约定（JSON 字符串数组）一致。
class TagSheet extends ConsumerStatefulWidget {
  const TagSheet({super.key, this.initialSelected = const <String>[]});

  /// 外部（记一笔页）已选标签名，用于回显。
  final List<String> initialSelected;

  /// 以底部弹窗形式展示，返回最终选中的标签名列表（取消返回 null）。
  static Future<List<String>?> show(
    BuildContext context, {
    List<String> initialSelected = const <String>[],
  }) {
    return showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext ctx) => TagSheet(initialSelected: initialSelected),
    );
  }

  @override
  ConsumerState<TagSheet> createState() => _TagSheetState();
}

class _TagSheetState extends ConsumerState<TagSheet> {
  /// 选中的标签名，按作用域各自记录（计数与作用域独立）。
  late final Map<TagScope, Set<String>> _selected = <TagScope, Set<String>>{
    TagScope.general: <String>{},
    TagScope.ledger: <String>{},
  };

  final TextEditingController _searchCtl = TextEditingController();
  String _query = '';

  TagScope get _scope => ref.read(tagScopeProvider);

  /// 离屏测量两作用域列表高度用的 key（取较大者作为稳定弹窗高度）。
  final GlobalKey _measureGeneralKey = GlobalKey();
  final GlobalKey _measureLedgerKey = GlobalKey();
  /// 通用 / 账本独立作用域的稳定列表高度（取两屏较大者）。
  double? _unifiedListHeight;

  @override
  void initState() {
    super.initState();
    // 初始选中：通用作用域下预填外部传入的标签（账本独立作用域的标签名
    // 无法从纯名称判断归属，故只回显到通用集合；其余由用户自行在对应作用域点选）。
    _selected[TagScope.general]!.addAll(widget.initialSelected);
    _searchCtl.addListener(() {
      if (mounted) setState(() => _query = _searchCtl.text.trim());
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Set<String> get _current => _selected[_scope]!;

  void _toggle(String name) {
    setState(() {
      if (_current.contains(name)) {
        _current.remove(name);
      } else {
        _current.add(name);
      }
    });
  }

  void _toggleAll(TagGroupRow group, bool select) {
    final List<String> names =
        group.tags.map((Tag t) => t.name).toList();
    setState(() {
      if (select) {
        _current.addAll(names);
      } else {
        _current.removeAll(names);
      }
    });
  }

  List<String> get _allSelected =>
      <String>{..._selected[TagScope.general]!, ..._selected[TagScope.ledger]!}
          .toList();

  @override
  Widget build(BuildContext context) {
    // 同时观察两个作用域数据，用于离屏测量「两屏中较高者」作为稳定弹窗高度。
    final List<TagGroupRow> generalAll =
        ref.watch(tagsLibraryProvider(TagScope.general)).value ??
            const <TagGroupRow>[];
    final List<TagGroupRow> ledgerAll =
        ref.watch(tagsLibraryProvider(TagScope.ledger)).value ??
            const <TagGroupRow>[];
    final List<TagGroupRow> groups =
        _scope == TagScope.general ? generalAll : ledgerAll;

    final List<TagGroupRow> visible = _query.isEmpty
        ? groups
        : groups
            .map(
              (TagGroupRow g) => TagGroupRow(
                g.category,
                g.tags
                    .where(
                      (Tag t) =>
                          t.name.toLowerCase().contains(_query.toLowerCase()),
                    )
                    .toList(),
              ),
            )
            .where((TagGroupRow g) => g.tags.isNotEmpty)
            .toList();

    final double screenH = MediaQuery.of(context).size.height;

    // 帧后测量两作用域「完整 3 张卡」高度，取较大者为稳定高度（切作用域不跳变，
    // 且中间区域刚好完整显示 3 张卡、底部无空白）。
    // 注意：测量全部在 post-frame 回调里完成，build 期间不读任何 render size。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureUnifiedHeight();
    });

    return Stack(
      children: <Widget>[
        Container(
          // 上限 60% 屏高；列表统一高度超出剩余空间时被 Flexible 自动压缩。
          constraints: BoxConstraints(maxHeight: screenH * 0.6),
          decoration: BoxDecoration(
            color: ForestBg.paper,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _buildChrome(),
              // 列表区：目标高度为两作用域较大者；Flexible(loose) 保证
              // 空间不足时被压缩到剩余空间（杜绝 RenderFlex overflow）。
              Flexible(
                child: SizedBox(
                  height: _unifiedListHeight ?? 280,
                  child: _listContent(visible, groups),
                ),
              ),
              const SizedBox(height: 6),
              _buildFooter(groups),
            ],
          ),
        ),
        // 离屏测量区：Positioned 脱离 Column 布局流，Offstage 不绘制不命中，
        // 仅用于帧后读取「完整 3 张卡片」的自然高度（中间区域显示基准）。
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: Offstage(
            child: Stack(
              children: <Widget>[
                _measureThreeCards(generalAll, key: _measureGeneralKey),
                _measureThreeCards(ledgerAll, key: _measureLedgerKey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 顶部固定区：标题 / 通用·账本独立分段 / 搜索框 / 虚线分界。
  Widget _buildChrome() => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: 32,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(_allSelected),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: ForestBg.sunken,
                        shape: BoxShape.circle,
                        border: Border.all(color: ForestNeutral.hairline),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Color(0xFF6A7263),
                      ),
                    ),
                  ),
                ),
                const Text(
                  '标签',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2C3329),
                    letterSpacing: 0.02,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: () async {
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (BuildContext ctx) => const TagManagePage(),
                        ),
                      );
                      if (mounted) setState(() {});
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C3329),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '添加',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF4EFDF),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // 通用 / 账本独立 分段：居中定宽（240），两处入口尺寸一致
          Center(
            child: SizedBox(
              width: 240,
              child: TagScopeToggle(
                scope: _scope,
                onChanged: (TagScope s) {
                  ref.read(tagScopeProvider.notifier).state = s;
                  setState(() {});
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 搜索框（设计稿：沙底无边框）
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
            decoration: BoxDecoration(
              color: ForestBg.sunken,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.search, size: 18, color: Color(0xFF9AA091)),
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
                      hintStyle:
                          TextStyle(fontSize: 14, color: Color(0xFF9AA091)),
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                if (_query.isNotEmpty)
                  InkWell(
                    onTap: () {
                      _searchCtl.clear();
                      setState(() => _query = '');
                    },
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Color(0xFF9AA091),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 虚线分界
          _DashedDivider(
            label: _scope == TagScope.general
                ? '以下为通用标签'
                : '以下为账本独立标签',
          ),
          const SizedBox(height: 8),
        ],
      );

  /// 底部栏：已选计数 + 确定（上缘发丝线，对齐设计稿 .sheet-foot）。
  Widget _buildFooter(List<TagGroupRow> groups) => Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: ForestNeutral.hairline),
          ),
        ),
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: <Widget>[
            Text(
              // 设计稿口径：无分组时空白；有分组未选 →「尚未选择标签」
              groups.isEmpty
                  ? ''
                  : (_current.isEmpty
                      ? '尚未选择标签'
                      : '已选 ${_current.length} 个标签'),
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF2E6B49),
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 36,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(_allSelected),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: ForestGradients.sageMid,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x333C8A60),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    '确定',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2E5B39),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  /// 离屏测量两作用域「完整 3 张卡」高度，取较大者作为稳定列表高度。
  ///
  /// 仅在 post-frame 回调中调用（此时布局已完成，读 size 合法）。
  void _measureUnifiedHeight() {
    if (!mounted) return;
    final double? g = _measureGeneralKey.currentContext?.size?.height;
    final double? l = _measureLedgerKey.currentContext?.size?.height;
    if (g == null || l == null) return;
    final double m = max(g, l);
    if ((_unifiedListHeight ?? -1) - m > 0.5 ||
        (_unifiedListHeight ?? -1) - m < -0.5) {
      setState(() => _unifiedListHeight = m);
    }
  }

  /// 列表内容（两个作用域共用）：固定高度区内的滚动列表。
  Widget _listContent(List<TagGroupRow> visible, List<TagGroupRow> all) {
    if (all.isEmpty) {
      return const _GlobalEmpty();
    }
    if (visible.isEmpty) {
      return Center(
        child: Text(
          _query.isEmpty ? '没有发现标签哦，试着去添加一个~' : '未找到「$_query」相关标签',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF9AA091)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      itemCount: visible.length,
      separatorBuilder: (BuildContext ctx, int i) =>
          const SizedBox(height: 8),
      itemBuilder: (BuildContext ctx, int i) => _buildCard(visible[i]),
    );
  }

  /// 离屏测量基准：前 3 张卡 + 卡间隔 + 上下 padding，与滚动列表结构完全一致，
  /// 测得高度即「中间区域恰好完整显示 3 张卡片」。
  Widget _measureThreeCards(List<TagGroupRow> groups, {required Key key}) {
    if (groups.isEmpty) {
      // 无分组时以空态为基准（各屏一致，不影响统一高度）。
      return KeyedSubtree(key: key, child: const _GlobalEmpty());
    }
    final List<TagGroupRow> shown = groups.take(3).toList();
    return Padding(
      key: key,
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < shown.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 8),
            _buildCard(shown[i]),
          ],
        ],
      ),
    );
  }

  /// 单张分组卡（滚动列表与离屏测量共用同一构建，保证测高与实际渲染一致）。
  Widget _buildCard(TagGroupRow g) {
    final bool hasTags = g.tags.isNotEmpty;
    final bool allSelected =
        hasTags && g.tags.every((Tag t) => _current.contains(t.name));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ForestSurface.card,
        borderRadius: BorderRadius.circular(12),
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
                    color: Color(0xFF2C3329),
                  ),
                ),
              ),
              if (hasTags)
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _toggleAll(g, !allSelected),
                  child: Text(
                    allSelected ? '取消全选' : '全选',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C3329),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasTags)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final Tag t in g.tags)
                  _TagChip(
                    label: t.name,
                    selected: _current.contains(t.name),
                    onTap: () => _toggle(t.name),
                  ),
              ],
            )
          else
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: ForestBg.sunken,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'ⓘ「${g.category.name}」为标签分组，请添加具体的标签再使用哦~',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6A7263),
                  height: 1.7,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 标签 chip：选中 = 鼠尾草绿渐变 + 墨绿字加粗 + 投影；未选 = 沙底灰绿字。
/// 对齐设计稿 chip 结构：`#` 前缀（未选时深绿、选中时墨绿）+ 名称。
class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          gradient: selected ? ForestGradients.sageMid : null,
          color: selected ? null : ForestBg.sunken,
          borderRadius: BorderRadius.circular(999),
          border: selected
              ? null
              : Border.all(color: ForestNeutral.hairline),
          boxShadow: selected
              ? const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x2A3C8A60),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '#',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? ForestSage.ink : ForestGreen.deep,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected
                    ? ForestSage.ink
                    : ForestNeutral.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 虚线分隔（水平虚线 + 居中标签）。
class _DashedDivider extends StatelessWidget {
  const _DashedDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(child: _HorizontalDashed()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF9AA091)),
          ),
        ),
        const Expanded(child: _HorizontalDashed()),
      ],
    );
  }
}

class _HorizontalDashed extends StatelessWidget {
  const _HorizontalDashed();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HDashedPainter(color: ForestNeutral.hairline),
    );
  }
}

class _HDashedPainter extends CustomPainter {
  const _HDashedPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1.4;
    const double dash = 6;
    const double gap = 4;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// 全局空态（无任何分组时）：设计稿插画 + 文案。
class _GlobalEmpty extends StatelessWidget {
  const _GlobalEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const <Widget>[
          TagEmptyIllustration(width: 150),
          SizedBox(height: 14),
          Text(
            '没有发现标签哦，试着去添加一个~',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF9AA091),
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}
