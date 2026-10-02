import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/forest_design_tokens.dart';
import '../../../database/app_database.dart';
import '../../../features/accounts/providers/accounts_providers.dart';
import '../../../features/ledger/providers/ledger_providers.dart';
import '../../../providers/app_providers.dart';
import '../../../features/tags/presentation/tag_empty_illustration.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/category_icons.dart';
import '../../../shared/widgets/money_text.dart';
import '../providers/record_template_providers.dart';
import '../record_tab.dart';
import 'record_sheet.dart';
import 'record_template_sheet.dart' show RecordTemplateDraft;
import '../../../shared/widgets/app_toast.dart';

/// 「账单模板」独立管理页（方案 C1 · 晕染延续）：
/// 晕染带（✕ 钮 + 头卡/帮助 + 虚线说明卡）→ 搜索 + 类型筛选 → 条目列表
/// （左滑露出「编辑 / 删除」）→ 底部渐变「添加」长钮（进入模板模式记一笔页，
/// 保存后回本页自动命名入库，不产生流水）。
class RecordTemplatePage extends ConsumerStatefulWidget {
  const RecordTemplatePage({super.key});

  @override
  ConsumerState<RecordTemplatePage> createState() => _RecordTemplatePageState();
}

class _RecordTemplatePageState extends ConsumerState<RecordTemplatePage> {
  final TextEditingController _searchCtl = TextEditingController();
  String _query = '';
  int _typeFilter = 0; // 0 = 全部
  bool _noteExpanded = true;

  /// 「条件」筛选（设计稿 C1）：0 分类 / 1 备注 / 2 金额 / 3 优惠后金额。
  /// 模板暂无金额字段，2/3 仅作范围占位；未勾选时默认搜「名称 + 备注」。
  final Set<int> _condFilter = <int>{};

  static const List<String> _typeLabels = <String>[
    '全部',
    '普通收支',
    '转账',
    '借款',
    '报销',
    '退款',
  ];

  static const List<String> _condLabels = <String>[
    '分类',
    '备注',
    '金额',
    '优惠后金额',
  ];

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  bool _matchType(RecordTab t) => switch (_typeFilter) {
        1 => t == RecordTab.expense ||
            t == RecordTab.income ||
            t == RecordTab.savings ||
            t == RecordTab.installment,
        2 => t == RecordTab.transfer,
        3 => t == RecordTab.lend,
        4 => t == RecordTab.reimbursement,
        5 => t == RecordTab.refund,
        _ => true,
      };

  /// 「添加」：进入模板模式记一笔页填写（支出/收入/转账/借还四 Tab），
  /// 保存后携带草稿返回 → **自动命名入库**（备注 > 对方 > 分类名 > 类型），
  /// 仅存模板、**不产生任何流水**。
  Future<void> _addFromEntry() async {
    final RecordTemplateDraft? d = await Navigator.of(context)
        .push<RecordTemplateDraft>(
      MaterialPageRoute<RecordTemplateDraft>(
        builder: (BuildContext ctx) => const RecordSheet(templateMode: true),
      ),
    );
    if (d == null || !mounted) return;

    final String name = _suggestName(d);
    await ref.read(recordTemplateRepositoryProvider).add(
          bookId: ref.read(currentBookIdProvider),
          name: name,
          tabIndex: d.tabIndex,
          amountMinor: d.amountMinor,
          discountMinor: d.discountMinor,
          accountId: d.accountId,
          toAccountId: d.toAccountId,
          counterparty: d.counterparty,
          categoryId: d.categoryId,
          note: d.note,
          tags: d.tags,
          excludeFromStats: d.excludeFromStats,
          excludeFromBudget: d.excludeFromBudget,
          isReimbursable: d.isReimbursable,
        );
    if (!mounted) return;
    showAppToast(context, '已保存模板「$name」');
  }

  /// 左滑「编辑」：进入模板模式记一笔页并预填模板内容，
  /// 保存后以草稿更新原模板（保留 id / 创建时间，不产生流水）。
  Future<void> _editTemplate(RecordTemplate t) async {
    final RecordTemplateDraft? d = await Navigator.of(context)
        .push<RecordTemplateDraft>(
      MaterialPageRoute<RecordTemplateDraft>(
        builder: (BuildContext ctx) =>
            RecordSheet(templateMode: true, initialTemplate: t),
      ),
    );
    if (d == null || !mounted) return;

    final String name = _suggestName(d);
    await ref.read(recordTemplateRepositoryProvider).updateContent(
          id: t.id,
          name: name,
          tabIndex: d.tabIndex,
          amountMinor: d.amountMinor,
          discountMinor: d.discountMinor,
          accountId: d.accountId,
          toAccountId: d.toAccountId,
          counterparty: d.counterparty,
          categoryId: d.categoryId,
          note: d.note,
          tags: d.tags,
          excludeFromStats: d.excludeFromStats,
          excludeFromBudget: d.excludeFromBudget,
          isReimbursable: d.isReimbursable,
        );
    if (!mounted) return;
    showAppToast(context, '已更新模板「$name」');
  }

  /// 建议名：备注 > 借还对方 > 分类名 > Tab 类型。
  String _suggestName(RecordTemplateDraft d) {
    final String note = (d.note ?? '').trim();
    if (note.isNotEmpty) return note;
    final String counterparty = (d.counterparty ?? '').trim();
    if (counterparty.isNotEmpty) return counterparty;
    final RecordTab tab = RecordTab.values[d.tabIndex];
    if (d.categoryId != null) {
      final AsyncValue<List<Category>> cats =
          tab == RecordTab.income
              ? ref.read(incomeCategoriesProvider)
              : ref.read(expenseCategoriesProvider);
      final String? cn = cats.maybeWhen(
        data: (List<Category> l) {
          final Category? c = l.cast<Category?>().firstWhere(
                (Category? x) => x?.id == d.categoryId,
                orElse: () => null,
              );
          return c?.name;
        },
        orElse: () => null,
      );
      if (cn != null && cn.isNotEmpty) return cn;
    }
    return tab.label;
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: ForestSurface.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          '关于模板',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: ForestNeutral.textPrimary,
          ),
        ),
        content: Text(
          '模板用于经常购买或常记的账单，如每天买水 2 元，可将固定支出保存为模板，套用时自动填充账户、分类、备注、标签与开关，快速完成记账（金额需手动输入）。',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.7,
            color: ForestNeutral.textSecondary,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              '知道了',
              style: TextStyle(
                color: ForestGreen.deep,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 胶囊筛选 chip（奶油卡 + 发丝线 / 渐变选中 · 设计稿 6px 14px · 圆角 999）。
  Widget _pill(BuildContext context, {
    required String label,
    required bool on,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: on ? ForestGradients.sageMid : null,
          color: on ? null : ForestSurface.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: on ? Colors.transparent : ForestNeutral.hairline,
          ),
          boxShadow: on
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppPalette.stockDown.withValues(alpha: 0.278),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
            color: on ? Theme.of(context).colorScheme.onPrimary : ForestNeutral.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<RecordTemplate>> templates =
        ref.watch(recordTemplatesProvider);
    final List<RecordTemplate> list = templates.value ?? <RecordTemplate>[];

    // 分类名映射（用于「条件：分类」搜索）。
    final Map<String, String> catNames = <String, String>{};
    for (final AsyncValue<List<Category>> av in <AsyncValue<List<Category>>>[
      ref.watch(expenseCategoriesProvider),
      ref.watch(incomeCategoriesProvider),
    ]) {
      av.maybeWhen(
        data: (List<Category> l) {
          for (final Category c in l) {
            catNames[c.id] = c.name;
          }
        },
        orElse: () {},
      );
    }

    bool matchQuery(RecordTemplate t) {
      final String q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      final bool hasCond = _condFilter.isNotEmpty;
      if (t.name.toLowerCase().contains(q)) return true;
      if ((!hasCond || _condFilter.contains(1)) &&
          (t.note ?? '').toLowerCase().contains(q)) {
        return true;
      }
      if (_condFilter.contains(0) && t.categoryId != null) {
        final String? cn = catNames[t.categoryId];
        if (cn != null && cn.toLowerCase().contains(q)) return true;
      }
      return false; // 金额/优惠后金额：模板无金额字段，暂不参与匹配
    }

    final List<RecordTemplate> filtered = list
        .where((RecordTemplate t) =>
            _matchType(RecordTab.values[t.tabIndex]) && matchQuery(t))
        .toList();

    return Scaffold(
      backgroundColor: ForestBg.paper,
      // 点击空白处收起键盘
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // 顶部淡绿晕染带（C1）：✕ 钮 + 头卡 + 虚线说明卡。
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[AppPalette.mintWhisper, ForestBg.paper],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // 导航行：✕ 圆钮（半透明白 + 发丝线）
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                            border: Border.all(color: ForestNeutral.hairline),
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 18,
                            color: ForestNeutral.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 6),
                    // 头卡：徽章 + 标题/副标题 + 帮助钮
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: ForestSurface.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: ForestNeutral.hairline),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppPalette.sage900.withValues(alpha: 0.051),
                            blurRadius: 14,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: ForestBg.sunken,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.bookmark_outline,
                              size: 22,
                              color: ForestGreen.deep,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  '账单模板',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: ForestNeutral.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  '常用账单保存为一键模板',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: ForestNeutral.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _showHelp,
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: ForestBg.sunken,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '帮助',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: ForestGreen.deep,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    // 虚线说明卡（可折叠，1px 沙色虚线 · 设计稿 --sand #EDE4D2）
                    CustomPaint(
                      painter: const _NoteDashedBorderPainter(),
                      child: InkWell(
                        onTap: () =>
                            setState(() => _noteExpanded = !_noteExpanded),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 10, 26, 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.info_outline,
                                  size: 15,
                                  color: AppPalette.sageRibbon,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '模板用于经常购买或常记的账单，可将固定支出保存为模板快速记账。列表按「模板时间」排序~',
                                  maxLines: _noteExpanded ? null : 1,
                                  overflow: _noteExpanded
                                      ? null
                                      : TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.8,
                                    color: ForestNeutral.textSecondary,
                                  ),
                                ),
                              ),
                              Icon(
                                _noteExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 16,
                                color: ForestNeutral.textTertiary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 搜索框（沙底圆角 14，与晕染带间距 12 · 设计稿 search margin-top）
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: ForestBg.sunken,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.search,
                          size: 16, color: AppPalette.ink3),
                      const SizedBox(width: 9),
                      Expanded(
                        child: TextField(
                          controller: _searchCtl,
                          onChanged: (String v) => setState(() => _query = v),
                          style: const TextStyle(fontSize: 13.5),
                          decoration: const InputDecoration(
                            filled: false,
                            hintText: '支持分类备注金额搜索',
                            hintStyle: TextStyle(
                              fontSize: 13.5,
                              color: AppPalette.ink3,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isCollapsed: true,
                          ),
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
                            size: 15,
                            color: AppPalette.ink3,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // 「条件」筛选行（设计稿 C1：条件：分类/备注/金额/优惠后金额）
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: <Widget>[
                    const Text(
                      '条件：',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: ForestNeutral.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: <Widget>[
                            for (int i = 0;
                                i < _condLabels.length;
                                i++) ...<Widget>[
                              _pill(context,
                                label: _condLabels[i],
                                on: _condFilter.contains(i),
                                onTap: () => setState(() {
                                  if (_condFilter.contains(i)) {
                                    _condFilter.remove(i);
                                  } else {
                                    _condFilter.add(i);
                                  }
                                }),
                              ),
                              if (i != _condLabels.length - 1)
                                const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // 类型筛选 chips（全部=渐变选中）
              SizedBox(
                height: 32,
                child: ListView.separated(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _typeLabels.length,
                  separatorBuilder: (BuildContext ctx, int i) =>
                      const SizedBox(width: 8),
                  itemBuilder: (BuildContext ctx, int i) {
                    final bool on = i == _typeFilter;
                    return _pill(context,
                      label: _typeLabels[i],
                      on: on,
                      onTap: () => setState(() => _typeFilter = i),
                    );
                  },
                ),
              ),
              const SizedBox(height: 2),
              // 模板列表（奶油卡，可删除）
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        // 键盘弹出压缩可视区时改为滚动，避免 BOTTOM OVERFLOWED。
                        child: SingleChildScrollView(
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              TagEmptyIllustration(width: 120),
                              const SizedBox(height: 12),
                              Text(
                                list.isEmpty
                                    ? '没有发现模板哦，试着去添加一个~'
                                    : '未找到符合条件的模板',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: ForestNeutral.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SlidableAutoCloseBehavior(
                        child: ListView.separated(
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          padding:
                              const EdgeInsets.fromLTRB(20, 12, 20, 12),
                          itemCount: filtered.length,
                          separatorBuilder: (BuildContext ctx, int i) =>
                              const SizedBox(height: 10),
                          itemBuilder: (BuildContext ctx, int i) {
                            final RecordTemplate t = filtered[i];
                            return Slidable(
                              key: ValueKey<String>(t.id),
                              // 左滑露出「编辑 / 删除」操作块（滑出式，占 34%）。
                              endActionPane: ActionPane(
                                motion: const BehindMotion(),
                                extentRatio: 0.34,
                                children: <Widget>[
                                  SlidableAction(
                                    onPressed: (BuildContext _) =>
                                        _editTemplate(t),
                                    backgroundColor: AppPalette.sageLeaf,
                                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                    icon: Icons.edit_outlined,
                                    label: '编辑',
                                    spacing: 2,
                                  ),
                                  SlidableAction(
                                    onPressed: (BuildContext _) =>
                                        _remove(t),
                                    backgroundColor: ForestSemantic.expense,
                                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                    icon: Icons.delete_outline,
                                    label: '删除',
                                    spacing: 2,
                                  ),
                                ],
                              ),
                              // 卡片未选中为透明底，包一层纸底避免
                              // 左滑时操作块从透明区透出。
                              child: Container(
                                color: ForestBg.paper,
                                child: RecordTemplateCard(
                                  template: t,
                                  radius: 18,
                                  iconEdge: 42,
                                  iconRadius: 14,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
              // 底部渐变「添加」长钮
              Container(
                decoration: BoxDecoration(
                  border:
                      Border(top: BorderSide(color: ForestNeutral.hairline)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: InkWell(
                        onTap: _addFromEntry,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: ForestGradients.sageMid,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: AppPalette.stockDown.withValues(alpha: 0.322),
                                blurRadius: 16,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Text(
                            '添加',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
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
      ),
    );
  }

  Future<void> _remove(RecordTemplate t) async {
    await ref.read(recordTemplateRepositoryProvider).remove(t.id);
    if (!mounted) return;
    showAppToast(context, '已删除模板「${t.name}」');
  }
}

/// 说明卡虚线边框（1px 沙色 · 设计稿 --sand #EDE4D2，原生 BorderStyle 无 dashed）。
class _NoteDashedBorderPainter extends CustomPainter {
  const _NoteDashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final RRect rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(14),
    );
    final Path path = Path()..addRRect(rrect);
    final Paint paint = Paint()
      ..color = AppPalette.sandWarm
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const double dash = 6;
    const double gap = 4;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double len =
            dash < (metric.length - distance) ? dash : metric.length - distance;
        canvas.drawPath(metric.extractPath(distance, distance + len), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 模板卡（弹窗与管理页共用），对齐流水条目布局：
/// 分类色图标块 + 名称 + 「账户摘要 · MM-dd HH:mm · 备注」副行 → 右侧着色金额。
/// 未选 = 流水条目样式（透明底 + 底部发丝线）；选中 = 鼠尾草渐变卡 + 白字。
class RecordTemplateCard extends ConsumerWidget {
  const RecordTemplateCard({
    super.key,
    required this.template,
    this.selected = false,
    this.radius = 16,
    this.iconEdge = 38,
    this.iconRadius = 12,
    this.onTap,
  });

  final RecordTemplate template;
  final bool selected;

  /// 卡片圆角：弹窗 16 / 独立页 18（对齐设计稿）。
  final double radius;

  /// 图标块边长/圆角。
  final double iconEdge;
  final double iconRadius;
  final VoidCallback? onTap;

  /// 选中态（渐变卡）用的白色金额文案：支出 − / 收入 + / 其余 ¥。
  String _signedAmountText() {
    final RecordTab tab = RecordTab.values[template.tabIndex];
    if (template.amountMinor <= 0) return tab.label;
    final String money =
        Money.fromMinor(template.amountMinor).format(showSymbol: false);
    return switch (tab) {
      RecordTab.expense => '−$money',
      RecordTab.income => '+$money',
      _ => '¥$money',
    };
  }

  /// 金额组件（对齐流水条目）：支出 −红 / 收入 +绿（MoneyText signed），
  /// 转账·借还 中性墨；旧模板金额为 0 时退化为类型文案。
  Widget _amountWidget() {
    final RecordTab tab = RecordTab.values[template.tabIndex];
    if (template.amountMinor <= 0) {
      return Text(
        tab.label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: ForestNeutral.textSecondary,
        ),
      );
    }
    final Money money = Money.fromMinor(template.amountMinor);
    return switch (tab) {
      RecordTab.expense =>
        MoneyText(Money.fromMinor(-template.amountMinor),
            signed: true, style: const TextStyle(fontSize: 15)),
      RecordTab.income => MoneyText(money,
          signed: true, style: const TextStyle(fontSize: 15)),
      _ => Text(
          '¥${money.format(showSymbol: false)}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: ForestNeutral.textPrimary,
          ),
        ),
    };
  }

  /// 图标与着色（对齐流水条目）：有分类用分类色 + 分类图标，否则按类型兜底。
  (IconData, Color) _iconStyle(Map<String, Category> categories) {
    final RecordTab tab = RecordTab.values[template.tabIndex];
    final Category? c =
        template.categoryId == null ? null : categories[template.categoryId];
    final (IconData, Color) fallback = switch (tab) {
      RecordTab.income => (Icons.south_west, ForestSemantic.income),
      RecordTab.transfer => (Icons.swap_horiz, ForestGreen.deep),
      RecordTab.lend => (Icons.handshake_outlined, ForestGreen.deep),
      _ => (Icons.shopping_bag_outlined, ForestSemantic.expense),
    };
    if (c == null) return fallback;
    final IconData icon = c.iconKey != null && c.iconKey!.isNotEmpty
        ? categoryIconData(c.iconKey)
        : fallback.$1;
    final Color tint =
        c.colorValue != null ? Color(c.colorValue!) : fallback.$2;
    return (icon, tint);
  }

  /// 账户摘要行：支出/收入 = 账户；转账 = 「A → B」；借还 = 对方（缺则账户）。
  String _accountSummary(List<Account> accounts) {
    String? nameOf(String? id) {
      if (id == null) return null;
      for (final Account a in accounts) {
        if (a.id == id) return a.name;
      }
      return null;
    }

    final RecordTab tab = RecordTab.values[template.tabIndex];
    switch (tab) {
      case RecordTab.transfer:
        final String from = nameOf(template.accountId) ?? '转出账户';
        final String to = nameOf(template.toAccountId) ?? '转入账户';
        return '$from → $to';
      case RecordTab.lend:
        final String cp = (template.counterparty ?? '').trim();
        if (cp.isNotEmpty) return cp;
        return nameOf(template.accountId) ?? '借还';
      case RecordTab.expense:
      case RecordTab.income:
      case RecordTab.reimbursement:
      case RecordTab.refund:
      case RecordTab.savings:
      case RecordTab.installment:
        return nameOf(template.accountId) ?? tab.label;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Account> accounts =
        ref.watch(accountsProvider).value ?? const <Account>[];
    final Map<String, Category> categories =
        ref.watch(categoryMapProvider).valueOrNull ?? const <String, Category>{};
    final (IconData icon, Color tint) = _iconStyle(categories);
    final Color onCard = selected ? Theme.of(context).colorScheme.onPrimary : ForestNeutral.textPrimary;
    final Color faintOnCard = selected
        ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.8)
        : ForestNeutral.textTertiary;

    // 副行与流水条目同构：「账户（或摘要）  MM-dd HH:mm  备注」。
    final DateTime created = DateTime.fromMillisecondsSinceEpoch(
      template.createdAt,
    );
    final String noteSuffix = (template.note ?? '').isEmpty
        ? ''
        : '  ${template.note}';

    final Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        // 分类图标块（分类色 12% 底 · 与流水条目一致）
        Container(
          width: iconEdge,
          height: iconEdge,
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.22)
                : tint.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(iconRadius),
          ),
          child: Icon(
            icon,
            size: 22,
            color: selected ? Theme.of(context).colorScheme.onPrimary : tint,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                template.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: onCard,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_accountSummary(accounts)}  ${DateFormat('MM-dd HH:mm').format(created)}'
                '$noteSuffix',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: faintOnCard),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        selected
            ? Text(
                _signedAmountText(),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : _amountWidget(),
      ],
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          // 未选中 = 流水条目样式（透明底 + 底部发丝线）；选中 = 鼠尾草渐变卡。
          gradient: selected ? ForestGradients.sageMid : null,
          borderRadius: BorderRadius.circular(radius),
          border: selected
              ? Border.all(color: Colors.transparent)
              : Border(
                  bottom: BorderSide(color: ForestNeutral.hairline),
                ),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppPalette.stockDown.withValues(alpha: 0.302),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: content,
      ),
    );
  }
}
