import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../database/daos/tags_dao.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/forest_design_tokens.dart';
import '../../../../shared/models/money.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/amount_keypad.dart';
import '../../../../shared/widgets/calendar_sheet.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../theme/app_colors.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../categories/providers/categories_providers.dart';
import '../../tags/providers/tag_providers.dart';
import '../providers/ledger_providers.dart';

/// 流水筛选页（小青账布局）：
/// 顶部返回 + 基本/分类/标签/账户四 Tab + 重置；底部「查询(条件N个)」。
/// 基本 Tab 三个卡片区：基本信息 / 类型筛选 / 收支与预算。
/// 分类 Tab：顶部账本选择（必须选一个）+ 分类卡（支出/收入 + 全选 + 子分类选择键，
/// 开=可折叠两级列表，关=一级胶囊）+ 其他卡（十二枚系统类目）。
/// 标签 Tab：搜索框 + 标签所属分段（通用/账本独立）+ 模式(OR/AND) + 分组卡片。
/// 账户 Tab：筛选模式（包含/不包含）+ 账户列表（首行「未选择资产」游离账单）。
/// 「查询」返回 [LedgerAdvancedFilter]。
class LedgerFilterPage extends ConsumerStatefulWidget {
  const LedgerFilterPage({super.key, this.initial});

  /// 上次查询的条件（回显），null=无。
  final LedgerAdvancedFilter? initial;

  @override
  ConsumerState<LedgerFilterPage> createState() => _LedgerFilterPageState();
}

class _LedgerFilterPageState extends ConsumerState<LedgerFilterPage> {
  static const List<String> _tabLabels = <String>['基本', '分类', '标签', '账户'];

  /// 「其他」卡固定十二项（顺序按需求）。
  static const List<String> _otherLabels = <String>[
    '还款',
    '取现',
    '退款',
    '借入',
    '借出',
    '收债',
    '还债',
    '报销',
    '报销收入',
    '内部转账',
    '债务消减',
    '坏账计提',
  ];

  int _tab = 0;

  // ── 基本信息 ──
  DateTime? _day;

  /// 周期筛选（周/月/年/自定义）：[rangeStart] 含、[rangeEnd] 不含；
  /// 与 [_day] 互斥。[_rangeMode] 仅用于标签显示（月/年显整周期）。
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  CalendarPeriodMode? _rangeMode;
  final TextEditingController _minCtrl = TextEditingController();
  final TextEditingController _maxCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  // ── 类型筛选 ──
  final Set<String> _flowTypes = <String>{};
  final Set<String> _billTypes = <String>{};
  final Set<String> _sources = <String>{};

  // ── 收支与预算 ──
  bool? _statsExclude; // true=不计入收支 / false=计入收支 / null=未选
  bool? _budgetExclude;

  // ── 分类 Tab ──
  String? _bookId; // 顶部账本限定（默认当前账本）
  bool _catExpense = true; // 分类卡胶囊：true=支出 / false=收入
  bool _subOn = false; // 子分类选择键（开=两级列表）
  final Set<String> _catIds = <String>{}; // 选中的分类 id（一级或二级）
  final Set<String> _expanded = <String>{}; // 子分类列表展开中的一级 id
  final Set<String> _otherSel = <String>{}; // 「其他」卡选中项

  // ── 标签 Tab ──
  TagScope _tagScope = TagScope.general; // 标签所属：通用 / 账本独立
  bool _tagAnd = false; // 命中模式：false=OR / true=AND
  final Set<String> _tagNames = <String>{}; // 选中的标签名称
  final TextEditingController _tagSearchCtrl = TextEditingController();

  // ── 账户 Tab ──
  bool _accInclude = true; // 筛选模式：true=包含 / false=不包含
  bool _accIncludeNone = false; // 是否勾选「未选择资产」（游离账单）
  final Set<String> _accIds = <String>{}; // 选中的账户 id

  @override
  void initState() {
    super.initState();
    _bookId = ref.read(currentBookIdProvider);
    final LedgerAdvancedFilter? f = widget.initial;
    if (f != null) {
      _day = f.day;
      _rangeStart = f.rangeStart;
      _rangeEnd = f.rangeEnd;
      if (f.minMinor != null) _minCtrl.text = _minorToText(f.minMinor!);
      if (f.maxMinor != null) _maxCtrl.text = _minorToText(f.maxMinor!);
      if (f.note != null) _noteCtrl.text = f.note!;
      _flowTypes.addAll(f.flowTypes);
      _billTypes.addAll(f.billTypes);
      _sources.addAll(f.sources);
      _statsExclude = f.statsExclude;
      _budgetExclude = f.budgetExclude;
      _bookId = f.bookId ?? _bookId;
      _catIds.addAll(f.categoryIds);
      _otherSel.addAll(f.others);
      _tagNames.addAll(f.tagNames);
      _tagAnd = f.tagMatchAnd;
      _accIds.addAll(f.accountIds);
      _accIncludeNone = f.accountIncludeNone;
      _accInclude = f.accountInclude;
    }
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _noteCtrl.dispose();
    _tagSearchCtrl.dispose();
    super.dispose();
  }

  /// 分 → 输入框显示文本（元，去尾零）。
  static String _minorToText(int minor) {
    if (minor % 100 == 0) return '${minor ~/ 100}';
    final String s = (minor / 100).toString();
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  int? _parseMinor(String text) {
    final String t = text.trim();
    if (t.isEmpty) return null;
    return Money.tryParse(t)?.minor;
  }

  LedgerAdvancedFilter _buildResult() => LedgerAdvancedFilter(
        day: _day,
        rangeStart: _rangeStart,
        rangeEnd: _rangeEnd,
        minMinor: _parseMinor(_minCtrl.text),
        maxMinor: _parseMinor(_maxCtrl.text),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        flowTypes: Set<String>.of(_flowTypes),
        billTypes: Set<String>.of(_billTypes),
        sources: Set<String>.of(_sources),
        statsExclude: _statsExclude,
        budgetExclude: _budgetExclude,
        bookId: _bookId,
        categoryIds: Set<String>.of(_catIds),
        others: Set<String>.of(_otherSel),
        tagNames: Set<String>.of(_tagNames),
        tagMatchAnd: _tagAnd,
        accountIds: Set<String>.of(_accIds),
        accountIncludeNone: _accIncludeNone,
        accountInclude: _accInclude,
      );

  void _reset() {
    setState(() {
      _day = null;
      _rangeStart = null;
      _rangeEnd = null;
      _rangeMode = null;
      _minCtrl.clear();
      _maxCtrl.clear();
      _noteCtrl.clear();
      _flowTypes.clear();
      _billTypes.clear();
      _sources.clear();
      _statsExclude = null;
      _budgetExclude = null;
      _bookId = ref.read(currentBookIdProvider);
      _catExpense = true;
      _subOn = false;
      _catIds.clear();
      _expanded.clear();
      _otherSel.clear();
      _tagNames.clear();
      _tagAnd = false;
      _tagScope = TagScope.general;
      _tagSearchCtrl.clear();
      _accIds.clear();
      _accIncludeNone = false;
      _accInclude = true;
    });
  }

  /// 查询按钮的条件数：bookId 与当前账本相同视为不限，不计入。
  int _conditionCount() {
    final LedgerAdvancedFilter f = _buildResult();
    final bool bookExtra =
        f.bookId != null && f.bookId != ref.read(currentBookIdProvider);
    return f.conditionCount - (bookExtra ? 0 : 1);
  }

  // ────────────────────────── 构建 ──────────────────────────

  @override
  Widget build(BuildContext context) {
    final int count = _conditionCount();
    return Scaffold(
      backgroundColor: ForestBg.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            _buildHeader(),
            Expanded(
              child: switch (_tab) {
                0 => _buildBasicTab(),
                1 => _buildCategoryTab(),
                2 => _buildTagTab(),
                3 => _buildAccountTab(),
                _ => Center(
                    child: EmptyState(
                      message: '「${_tabLabels[_tab]}」筛选即将上线',
                    ),
                  ),
              },
            ),
            // ── 底部查询按钮 ──
            SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () =>
                        Navigator.of(context).pop(_buildResult()),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: ForestGradients.sageLight,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        count == 0 ? '查询' : '查询(条件${count}个)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.sage900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶部：返回 + 四 Tab（选中=深墨胶囊）+ 重置。
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 12, 10),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: AppPalette.textPrimary,
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (int i = 0; i < _tabLabels.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => setState(() => _tab = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _tab == i
                              ? AppPalette.sage900
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _tabLabels[i],
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _tab == i
                                ? AppPalette.white
                                : AppPalette.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _reset,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                '重置',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────── 分类 Tab ──────────────────────────

  /// 分类 Tab：账本选择行 + 分类卡 + 其他卡。
  Widget _buildCategoryTab() {
    final AsyncValue<List<Book>> booksAsync = ref.watch(booksListProvider);
    final List<Book> books = booksAsync.value ?? const <Book>[];
    final List<Category> cats =
        ref.watch(allCategoriesProvider).value ?? const <Category>[];

    // 账本必须选择一个：当前指向的账本不存在（已删）时回落到当前账本/第一个。
    if (books.isNotEmpty && !books.any((Book b) => b.id == _bookId)) {
      final String? cur = ref.read(currentBookIdProvider);
      final String fallback =
          books.any((Book b) => b.id == cur) ? cur! : books.first.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _bookId = fallback);
      });
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: <Widget>[
        _bookSelector(books),
        const SizedBox(height: 14),
        _categoryCard(cats),
        const SizedBox(height: 14),
        _otherCard(),
      ],
    );
  }

  /// 顶部账本选择：横滑胶囊，必须选择一个（不可取消到空）。
  Widget _bookSelector(List<Book> books) {
    if (books.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: books.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext ctx, int i) {
          final Book b = books[i];
          final bool active = _bookId == b.id;
          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => setState(() => _bookId = b.id),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: active ? AppPalette.sage300 : AppPalette.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.auto_stories_outlined,
                    size: 15,
                    color: active
                        ? AppPalette.sage900
                        : AppPalette.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    b.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w500,
                      color: active
                          ? AppPalette.sage900
                          : AppPalette.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 当前类型下的一级分类（隐藏系统分类——它们归「其他」卡管）。
  List<Category> _topCategories(List<Category> cats) {
    final CategoryType t =
        _catExpense ? CategoryType.expense : CategoryType.income;
    return cats
        .where((Category c) =>
            c.type == t && c.parentId == null && !c.isSystem)
        .toList();
  }

  /// 某一级分类下的子分类。
  List<Category> _subCategories(List<Category> cats, String parentId) {
    return cats
        .where((Category c) => c.parentId == parentId)
        .toList()
      ..sort((Category a, Category b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// 分类卡：支出/收入胶囊 + 全选 + 子分类选择键；下方按开关切换布局。
  Widget _categoryCard(List<Category> cats) {
    final List<Category> tops = _topCategories(cats);
    return _card(children: <Widget>[
      Row(
        children: <Widget>[
          _expenseIncomeCapsule(),
          const Spacer(),
          _selectAllChip(
            allSelected: tops.isNotEmpty &&
                tops.every((Category c) => _catIds.contains(c.id)),
            onTap: () => setState(() {
              final bool all = tops.isNotEmpty &&
                  tops.every((Category c) => _catIds.contains(c.id));
              // 全选/取消连同子分类一起，保证 (n/m) 计数同步。
              for (final Category c in tops) {
                final List<Category> subs = _subCategories(cats, c.id);
                if (all) {
                  _catIds.remove(c.id);
                  _catIds.removeAll(subs.map((Category s) => s.id));
                } else {
                  _catIds.add(c.id);
                  _catIds.addAll(subs.map((Category s) => s.id));
                }
              }
            }),
          ),
          const SizedBox(width: 12),
          _subChip(),
        ],
      ),
      const SizedBox(height: 12),
      if (!_subOn)
        _chipGrid(<Widget>[
          for (final Category c in tops)
            _wrapChip(
              c.name,
              active: _catIds.contains(c.id),
              onTap: () => setState(() {
                if (!_catIds.remove(c.id)) _catIds.add(c.id);
              }),
            ),
        ])
      else if (tops.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(
            child: Text(
              '当前类型暂无分类',
              style: TextStyle(
                  fontSize: 14, color: AppPalette.textTertiary),
            ),
          ),
        )
      else
        Column(
          children: <Widget>[
            for (final Category top in tops)
              _categoryExpandRow(cats, top),
          ],
        ),
    ]);
  }

  /// 支出/收入二段胶囊。
  Widget _expenseIncomeCapsule() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppPalette.paper2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final (bool flag, String label) in <(bool, String)>[
            (true, '支出'),
            (false, '收入'),
          ])
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => setState(() => _catExpense = flag),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _catExpense == flag
                      ? AppPalette.sage300
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: _catExpense == flag
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: _catExpense == flag
                        ? AppPalette.sage900
                        : AppPalette.textPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 「全选」小胶囊。
  Widget _selectAllChip({
    required bool allSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: allSelected ? AppPalette.sage300 : AppPalette.paper2,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '全选',
          style: TextStyle(
            fontSize: 13,
            fontWeight: allSelected ? FontWeight.w700 : FontWeight.w500,
            color:
                allSelected ? AppPalette.sage900 : AppPalette.textSecondary,
          ),
        ),
      ),
    );
  }

  /// 「子分类」选择键：开=显示两级可折叠列表，关=一级胶囊；
  /// 选中态与「全选」同款配色。
  Widget _subChip() {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => setState(() => _subOn = !_subOn),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: _subOn ? AppPalette.sage300 : AppPalette.paper2,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '子分类',
          style: TextStyle(
            fontSize: 13,
            fontWeight: _subOn ? FontWeight.w700 : FontWeight.w500,
            color: _subOn ? AppPalette.sage900 : AppPalette.textSecondary,
          ),
        ),
      ),
    );
  }

  /// 子分类模式下的一级分类行：箭头 + 名称 + (n/m) + 勾选框；
  /// 点行体展开/收起子分类，勾选框选一级（连同其子分类参与命中）。
  Widget _categoryExpandRow(List<Category> cats, Category top) {
    final List<Category> subs = _subCategories(cats, top.id);
    final bool expanded = _expanded.contains(top.id);
    final int subSel =
        subs.where((Category c) => _catIds.contains(c.id)).length;
    final bool checked = _catIds.contains(top.id) ||
        (subs.isNotEmpty && subSel == subs.length);

    return Column(
      children: <Widget>[
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() {
            if (!_expanded.remove(top.id)) _expanded.add(top.id);
          }),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Row(
              children: <Widget>[
                AnimatedRotation(
                  turns: expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppPalette.textTertiary,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    top.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                ),
                if (subs.isNotEmpty)
                  Text(
                    '($subSel/${subs.length})',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppPalette.textTertiary,
                    ),
                  ),
                const SizedBox(width: 10),
                _checkBox(checked,
                    onTap: () => setState(() {
                          if (checked) {
                            _catIds.remove(top.id);
                            _catIds
                                .removeAll(subs.map((Category c) => c.id));
                          } else {
                            // 勾选一级连同子分类一起，保证 (n/m) 计数同步。
                            _catIds.add(top.id);
                            _catIds
                                .addAll(subs.map((Category c) => c.id));
                          }
                        })),
              ],
            ),
          ),
        ),
        if (expanded && subs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 30, bottom: 8),
            child: Column(
              children: <Widget>[
                for (final Category sub in subs)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            sub.name,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppPalette.textSecondary,
                            ),
                          ),
                        ),
                        _checkBox(
                          _catIds.contains(sub.id),
                          onTap: () => setState(() {
                            if (!_catIds.remove(sub.id)) {
                              _catIds.add(sub.id);
                            }
                          }),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// 勾选框：选中=绿底白勾，未选中=纸灰底。
  Widget _checkBox(bool checked, {required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: checked ? AppPalette.ctaGreen : AppPalette.paper2,
          borderRadius: BorderRadius.circular(6),
        ),
        child: checked
            ? const Icon(Icons.check, size: 14, color: AppPalette.white)
            : null,
      ),
    );
  }

  /// 其他卡：标题 + 全选 + 十二枚等尺寸换行选择键。
  Widget _otherCard() {
    return _card(children: <Widget>[
      _cardTitle(
        '其他',
        trailing: _selectAllChip(
          allSelected:
              _otherSel.length == _otherLabels.length,
          onTap: () => setState(() {
            if (_otherSel.length == _otherLabels.length) {
              _otherSel.clear();
            } else {
              _otherSel.addAll(_otherLabels);
            }
          }),
        ),
      ),
      const SizedBox(height: 12),
      _chipGrid(<Widget>[
        for (final String label in _otherLabels)
          _wrapChip(
            label,
            active: _otherSel.contains(label),
            onTap: () => setState(() {
              if (!_otherSel.remove(label)) _otherSel.add(label);
            }),
          ),
      ]),
    ]);
  }

  /// 4 列网格选择键布局（分类一级/其他卡共用）：
  /// shrinkWrap 不滚动，随外层 ListView 滚动；每格定高 34。
  Widget _chipGrid(List<Widget> children) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      mainAxisExtent: 34,
      padding: EdgeInsets.zero,
      children: children,
    );
  }

  /// 等宽风格选择键（其他卡/分类胶囊共用）：定高胶囊；
  /// 4 列网格下空间紧，内边距收窄，文字超宽自动缩放防溢出。
  Widget _wrapChip(
    String label, {
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        height: 34,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: active ? AppPalette.sage300 : AppPalette.paper2,
          borderRadius: BorderRadius.circular(999),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 14,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? AppPalette.sage900 : AppPalette.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  // ────────────────────────── 标签 Tab ──────────────────────────

  /// 标签 Tab：搜索框 + 标签所属分段 + 模式(OR/AND) + 分组卡片列表。
  Widget _buildTagTab() {
    final String q = _tagSearchCtrl.text.trim().toLowerCase();
    final AsyncValue<List<TagGroupRow>> groupsAsync =
        ref.watch(tagsLibraryProvider(_tagScope));
    final List<TagGroupRow> allGroups =
        groupsAsync.value ?? const <TagGroupRow>[];
    final List<TagGroupRow> groups = q.isEmpty
        ? allGroups
        : allGroups
            .map((TagGroupRow g) => TagGroupRow(
                  g.category,
                  g.tags
                      .where((Tag t) => t.name.toLowerCase().contains(q))
                      .toList(),
                ))
            .where((TagGroupRow g) => g.tags.isNotEmpty)
            .toList();

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: <Widget>[
        _tagSearchField(),
        const SizedBox(height: 12),
        _tagScopeRow(),
        const SizedBox(height: 12),
        _tagModeRow(),
        const SizedBox(height: 14),
        if (groups.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: EmptyState(message: '暂无标签'),
          )
        else
          for (final TagGroupRow g in groups) _tagGroupCard(g),
      ],
    );
  }

  /// 顶部搜索框：按名称搜索标签。
  Widget _tagSearchField() {
    return TextField(
      controller: _tagSearchCtrl,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontSize: 15, color: AppPalette.textPrimary),
      decoration: InputDecoration(
        hintText: '搜索标签',
        hintStyle:
            const TextStyle(fontSize: 15, color: AppPalette.textTertiary),
        prefixIcon: const Icon(Icons.search,
            size: 20, color: AppPalette.textTertiary),
        filled: true,
        fillColor: AppPalette.paper2,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppPalette.ctaGreen),
        ),
      ),
    );
  }

  /// 标签所属分段：通用标签 / 账本独立标签。
  Widget _tagScopeRow() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppPalette.paper2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: <Widget>[
          for (final (TagScope scope, String label) in <(TagScope, String)>[
            (TagScope.general, '通用标签'),
            (TagScope.ledger, '账本独立标签'),
          ])
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => setState(() {
                  if (_tagScope == scope) return;
                  _tagScope = scope;
                  // 切换所属后重置：清空已选标签与搜索词，
                  // 避免上一作用域的选中残留进查询条件。
                  _tagNames.clear();
                  _tagSearchCtrl.clear();
                }),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: _tagScope == scope
                        ? AppPalette.sage300
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: _tagScope == scope
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: _tagScope == scope
                          ? AppPalette.sage900
                          : AppPalette.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 模式行：左标题「模式」+ 右 OR/AND 二选键。
  Widget _tagModeRow() {
    return Row(
      children: <Widget>[
        const Text(
          '模式',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppPalette.textPrimary,
          ),
        ),
        const Spacer(),
        _orAndChip('OR', !_tagAnd),
        const SizedBox(width: 8),
        _orAndChip('AND', _tagAnd),
      ],
    );
  }

  /// OR/AND 单选键（选中=深墨底白字）。
  Widget _orAndChip(String label, bool active) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => setState(() => _tagAnd = label == 'AND'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppPalette.sage900 : AppPalette.paper2,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppPalette.white : AppPalette.textSecondary,
          ),
        ),
      ),
    );
  }

  /// 单个标签分组卡片：标题 + 标签网格。
  Widget _tagGroupCard(TagGroupRow g) {
    return _card(children: <Widget>[
      _cardTitle(g.category.name),
      const SizedBox(height: 12),
      _chipGrid(<Widget>[
        for (final Tag t in g.tags)
          _wrapChip(
            t.name,
            active: _tagNames.contains(t.name),
            onTap: () => setState(() {
              if (!_tagNames.remove(t.name)) _tagNames.add(t.name);
            }),
          ),
      ]),
    ]);
  }

  // ────────────────────────── 账户 Tab ──────────────────────────

  /// 账户 Tab：筛选模式行（包含/不包含）+ 账户列表
  /// （首行「未选择资产」= accountId 为空的游离账单）。
  Widget _buildAccountTab() {
    final List<Account> accounts =
        ref.watch(accountsProvider).valueOrNull ?? const <Account>[];

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: <Widget>[
        _accModeRow(),
        const SizedBox(height: 14),
        _accNoneRow(),
        const SizedBox(height: 10),
        for (final Account a in accounts) ...<Widget>[
          _accRow(a),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  /// 筛选模式行：左标题「筛选模式：」+ 右 包含/不包含 两枚选择键。
  Widget _accModeRow() {
    return Row(
      children: <Widget>[
        const Text(
          '筛选模式：',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppPalette.textPrimary,
          ),
        ),
        const Spacer(),
        _modeChip('包含', _accInclude,
            onTap: () => setState(() => _accInclude = true)),
        const SizedBox(width: 8),
        _modeChip('不包含', !_accInclude,
            onTap: () => setState(() => _accInclude = false)),
      ],
    );
  }

  /// 包含/不包含选择键：选中=浅绿底深绿加粗，未选中=纸灰底灰字。
  Widget _modeChip(String label, bool active, {required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppPalette.sage300 : AppPalette.paper2,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppPalette.sage900 : AppPalette.textSecondary,
          ),
        ),
      ),
    );
  }

  /// 「未选择资产」行：筛选出没有选择资产的账单（游离账单）。
  Widget _accNoneRow() {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _accIncludeNone = !_accIncludeNone),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppPalette.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppPalette.paper2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 22,
                color: AppPalette.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '未选择资产',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '筛选出没有选择资产的账单(游离账单)',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppPalette.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            _accCircle(_accIncludeNone),
          ],
        ),
      ),
    );
  }

  /// 单个账户行：圆形头像 + 名称 + 备注/类型副标题 + 圆形勾选圈。
  Widget _accRow(Account a) {
    final String subtitle =
        (a.note != null && a.note!.trim().isNotEmpty) ? a.note! : a.type.label;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() {
        if (!_accIds.remove(a.id)) _accIds.add(a.id);
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppPalette.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: <Widget>[
            _accAvatar(a),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppPalette.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            _accCircle(_accIds.contains(a.id)),
          ],
        ),
      ),
    );
  }

  /// 账户圆形头像：账户色底 + 按账户类别取图标。
  Widget _accAvatar(Account a) {
    final Color color = a.colorValue != null
        ? Color(a.colorValue!)
        : AppPalette.ctaGreen;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(
        switch (a.type.category) {
          AccountCategory.capital => Icons.account_balance_wallet_outlined,
          AccountCategory.investment => Icons.trending_up,
          AccountCategory.debt => Icons.credit_card,
          AccountCategory.receivable => Icons.arrow_circle_up_outlined,
          AccountCategory.payable => Icons.arrow_circle_down_outlined,
        },
        size: 21,
        color: AppPalette.white,
      ),
    );
  }

  /// 右侧圆形勾选圈：选中=绿底白勾，未选中=灰描边空心圈。
  Widget _accCircle(bool checked) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? AppPalette.ctaGreen : Colors.transparent,
        border: Border.all(
          color: checked ? AppPalette.ctaGreen : AppPalette.textTertiary,
          width: 1.4,
        ),
      ),
      child: checked
          ? const Icon(Icons.check, size: 14, color: AppPalette.white)
          : null,
    );
  }

  // ────────────────────────── 基本 Tab ──────────────────────────

  Widget _buildBasicTab() {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: <Widget>[
        _card(children: <Widget>[
          _cardTitle('基本信息',
              trailing: _helpChip('按时间、金额区间、备注筛选账单')),
          const SizedBox(height: 12),
          _labelRow('时间',
              trailing: _timeSelector()),
          const SizedBox(height: 12),
          _labelRow(
            '金额区间',
            trailing: Expanded(
              child: Row(
                children: <Widget>[
                  Expanded(child: _amountField(_minCtrl, '最小')),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '至',
                      style: TextStyle(
                          fontSize: 14, color: AppPalette.textSecondary),
                    ),
                  ),
                  Expanded(child: _amountField(_maxCtrl, '最大')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _noteField(),
        ]),
        const SizedBox(height: 14),
        _card(children: <Widget>[
          _cardTitle('类型筛选',
              trailing: _clearChip(
                  '取消', () => setState(() {
                        _flowTypes.clear();
                        _billTypes.clear();
                        _sources.clear();
                      }))),
          const SizedBox(height: 12),
          _labelRow(
            '收支类型',
            trailing: Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  children: <Widget>[
                    for (final String v in const <String>['支出', '收入'])
                      _chip(v, _flowTypes,
                          single: false,
                          onChanged: (_) => setState(() {})),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _labelRow(
            '账单类型',
            trailing: Expanded(
              child: _scrollChips(
                const <String>[
                  '普通收支',
                  '转账',
                  '退款',
                  '借款',
                  '报销',
                  '报销收入',
                ],
                _billTypes,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _labelRow(
            '账单来源',
            trailing: Expanded(
              child: _scrollChips(
                const <String>[
                  '导入',
                  '手动记账',
                  '自动同步',
                  '存钱计划',
                  '分期记账',
                ],
                _sources,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        _card(children: <Widget>[
          _cardTitle(
            '收支与预算',
            trailing: _clearChip(
                '取消',
                () => setState(() {
                      _statsExclude = null;
                      _budgetExclude = null;
                    })),
          ),
          const SizedBox(height: 12),
          _labelRow(
            '收支',
            trailing: Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  children: <Widget>[
                    _boolChip(
                        '不计入收支', true, _statsExclude,
                        (v) => setState(() => _statsExclude = v)),
                    _boolChip(
                        '计入收支', false, _statsExclude,
                        (v) => setState(() => _statsExclude = v)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _labelRow(
            '预算',
            trailing: Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  children: <Widget>[
                    _boolChip(
                        '不计入预算', true, _budgetExclude,
                        (v) => setState(() => _budgetExclude = v)),
                    _boolChip(
                        '计入预算', false, _budgetExclude,
                        (v) => setState(() => _budgetExclude = v)),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  // ────────────────────────── 卡片与行 ──────────────────────────

  Widget _card({required List<Widget> children}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppPalette.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );

  /// 卡片标题：左侧绿色竖条 + 标题，右侧可选控件。
  Widget _cardTitle(String title, {Widget? trailing}) {
    return Row(
      children: <Widget>[
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppPalette.ctaGreen,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppPalette.textPrimary,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing,
      ],
    );
  }

  /// 行：左侧灰色胶囊标签 + 右侧内容。
  Widget _labelRow(String label, {required Widget trailing}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppPalette.paper2,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppPalette.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        trailing,
      ],
    );
  }

  /// 「帮助」小胶囊。
  Widget _helpChip(String tip) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => showAppToast(context, tip),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: AppPalette.paper2,
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          '帮助',
          style: TextStyle(
            fontSize: 13,
            color: AppPalette.textSecondary,
          ),
        ),
      ),
    );
  }

  /// 「取消」小胶囊：清空所在卡片的选择。
  Widget _clearChip(String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: AppPalette.paper2,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppPalette.textSecondary,
          ),
        ),
      ),
    );
  }

  /// 时间选择：右侧标签按所选粒度显示——
  /// 日=「2026年10月2日」/ 周·自定义=「9月28日-10月4日」/
  /// 月=「2026年10月」/ 年=「2026年」；未选=当前年份占位。
  Widget _timeSelector() {
    final String label = _timeLabel();
    final CalendarPeriod? initialPeriod = _rangeStart == null
        ? null
        : CalendarPeriod(_rangeMode ?? CalendarPeriodMode.custom,
            _rangeStart!, _rangeEnd ?? _rangeStart!);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final DateTime today = DateTime(
            DateTime.now().year, DateTime.now().month, DateTime.now().day);
        final CalendarSelection? picked = await CalendarSheet.show(
          context,
          mode: CalendarSheetMode.day,
          initialDate: _rangeStart ?? _day ?? today,
          initialPeriod: initialPeriod,
          showTime: false,
          showQuickChips: true,
          weekStart: CalendarWeekStart.sunday,
        );
        if (picked == null) return;
        setState(() {
          if (picked is CalendarDay) {
            // 单日：showTime:false → 时分归零，与旧行为一致。
            _day = DateTime(
                picked.date.year, picked.date.month, picked.date.day);
            _rangeStart = null;
            _rangeEnd = null;
            _rangeMode = null;
          } else if (picked is CalendarPeriod) {
            // 周/月/年/自定义：整体落区间（end 为排他边界）。
            _rangeStart = picked.start;
            _rangeEnd = picked.end;
            _rangeMode = picked.mode;
            _day = null;
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppPalette.textPrimary,
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: AppPalette.textPrimary,
            ),
          ],
        ),
      ),
    );
  }

  /// 「时间」行标签：按当前筛选粒度出文案。
  String _timeLabel() {
    if (_day != null) {
      return '${_day!.year}年${_day!.month}月${_day!.day}日';
    }
    if (_rangeStart != null) {
      final DateTime end = _rangeEnd ?? _rangeStart!;
      switch (_rangeMode) {
        case CalendarPeriodMode.month:
          return '${_rangeStart!.year}年${_rangeStart!.month}月';
        case CalendarPeriodMode.year:
          return '${_rangeStart!.year}年';
        case CalendarPeriodMode.week:
        case CalendarPeriodMode.custom:
        case null:
          final DateTime last =
              end.subtract(const Duration(days: 1)); // end 排他
          String md(DateTime d) => '${d.month}月${d.day}日';
          return _rangeStart!.year == last.year
              ? '${md(_rangeStart!)}-${md(last)}'
              : '${_rangeStart!.year}年${md(_rangeStart!)}-${md(last)}';
      }
    }
    return '${DateTime.now().year}年';
  }

  /// 金额输入框（工程内数字键盘），圆角胶囊灰底。
  Widget _amountField(TextEditingController ctrl, String hint) {
    return KeypadField(
      controller: ctrl,
      hintText: hint,
      allowDecimal: true,
      maxDecimalDigits: 2,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            fontSize: 14, color: AppPalette.textTertiary),
        filled: true,
        fillColor: AppPalette.paper2,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppPalette.ctaGreen),
        ),
      ),
    );
  }

  /// 备注输入框（多行）。
  Widget _noteField() {
    return TextField(
      controller: _noteCtrl,
      maxLines: 3,
      minLines: 3,
      style: const TextStyle(fontSize: 15, color: AppPalette.textPrimary),
      decoration: InputDecoration(
        hintText: '备注',
        hintStyle:
            const TextStyle(fontSize: 15, color: AppPalette.textTertiary),
        filled: true,
        fillColor: AppPalette.paper2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppPalette.ctaGreen),
        ),
      ),
    );
  }

  /// 可横滑的标签组（选中回写到 [selected]）。
  Widget _scrollChips(List<String> values, Set<String> selected) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (final String v in values)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _chip(v, selected,
                    single: false, onChanged: (_) => setState(() {})),
              ),
          ],
        ),
      ),
    );
  }

  /// 多选标签：选中=sage300 底深字，未选中=纸灰底。
  Widget _chip(
    String value,
    Set<String> selected, {
    required bool single,
    required ValueChanged<String> onChanged,
  }) {
    final bool active = selected.contains(value);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        if (active) {
          selected.remove(value);
        } else {
          selected.add(value);
        }
        onChanged(value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppPalette.sage300 : AppPalette.paper2,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppPalette.sage900 : AppPalette.textPrimary,
          ),
        ),
      ),
    );
  }

  /// 单选布尔标签（再点一次取消选择）。
  Widget _boolChip(
    String label,
    bool value,
    bool? current,
    ValueChanged<bool?> onChanged,
  ) {
    final bool active = current == value;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => onChanged(active ? null : value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppPalette.sage300 : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppPalette.sage900 : AppPalette.textPrimary,
          ),
        ),
      ),
    );
  }
}
