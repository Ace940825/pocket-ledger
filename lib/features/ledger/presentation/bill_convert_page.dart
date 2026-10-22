import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pocket_ledger/core/theme/forest_design_tokens.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/accounts/providers/accounts_providers.dart';
import 'package:pocket_ledger/features/ledger/presentation/ledger_filter_page.dart';
import 'package:pocket_ledger/features/ledger/presentation/widgets/txn_icon.dart';
import 'package:pocket_ledger/features/ledger/providers/ledger_providers.dart';
import 'package:pocket_ledger/features/record/presentation/account_picker_sheet.dart';
import 'package:pocket_ledger/shared/models/money.dart';
import 'package:pocket_ledger/shared/widgets/app_toast.dart';
import 'package:pocket_ledger/shared/widgets/calendar_sheet.dart';
import 'package:pocket_ledger/shared/widgets/clay_icon_tile.dart';
import 'package:pocket_ledger/shared/widgets/confirm_dialog.dart';
import 'package:pocket_ledger/shared/widgets/empty_state.dart';
import 'package:pocket_ledger/shared/widgets/line_icon_map.dart';
import 'package:pocket_ledger/shared/widgets/line_icons.dart';
import 'package:pocket_ledger/shared/widgets/sheet_scaffold.dart';
import 'package:pocket_ledger/shared/widgets/tag_pill.dart';
import 'package:pocket_ledger/theme/app_colors.dart';
import 'package:pocket_ledger/theme/app_theme.dart';

/// 「批量转换」页（我的 → 账单管理 → 批量转换）。
///
/// 与「账单清理」同款框架：周期 + 高级筛选（按分类 / 账户等条件收窄），
/// 多选取选中账单，再从底部弹出的转换面板统一改写 **分类 / 账户 / 标签 / 备注**
/// 的任意组合。整批合并进单个 DB 事务（一次提交），余额回滚与重算、同步入队、
/// 类型从属字段推导，全部复用逐笔 [TransactionRepository.updateTransaction]，
/// 语义与单笔编辑完全一致。
///
/// **收支方向并入「改分类」**（2026-10-22 真机反馈「改收支类型移除，功能合并
/// 到改分类，分类是按照支出收入方向调整的，选中分类后自动修改支出收入方向」）：
/// 分类本身按支出 / 收入方向划分，选中分类即隐含「把这笔账改成那个方向」，
/// 面板不再单列「改收支类型」开关。
///
/// 安全护栏：改账户 / 改方向只作用于「日常记账」类账单；借还 / 报销 / 储蓄 /
/// 分期 / 投资 / 物品 / 退款等联动账单的账户与类型不被平移（避免破坏核销与派生），
/// 这类账单若被选中且只开了账户开关，会被计入跳过数而非报错；若「改分类」要求
/// 改方向而该账单方向不可改，则连分类一起不应用（避免「分类方向 ≠ 收支类型」
/// 的矛盾数据）。
///
/// 2026-10-22 弹窗四连修复（真机反馈）：「点框外不能返回 / 选择分类不显示 /
/// 键盘弹起 BOTTOM OVERFLOWED BY 321 PIXELS / 改标签和备注像素不对」。
/// 前两条同根因：分类选择列表的裸 ListView 在 AppModalSheet 自适应高度
/// Column 里拿到无界高度直接崩溃，崩掉的弹窗留在栈顶只透出遮罩——点框外
/// 只关掉这个「隐形」弹窗，表现为关不掉转换面板；现列表自带
/// ConstrainedBox(45% 屏高) + shrinkWrap（与预算编辑器同款矮弹层口径）。
/// 后两条同根因：键盘弹起时 AppModalSheet 的 Padding(bottom: viewInset)
/// 与内容自适应高度叠加把卡片撑超屏幕，Column 底部溢出；现已由
/// sheet_scaffold 给 body 槽位加「屏高 − 键盘 − 铬件」上限统一修复
/// （超高 body 内部滚动，无键盘时与旧版可容纳高度一致）。
///
/// 2026-10-22 分类选择器改版（真机反馈「选择分类按照一二级做两个弹窗，
/// 并且图标按照分类图标同步」+「弹出二级分类后想返回一级分类没有路径」+
/// 「在分类弹窗点框外没反应」）：
/// - 一级 / 二级两个弹窗，一级常驻、二级**叠开在它之上**（不是关掉一级再开
///   二级），二级标题栏带返回键 → 可退回一级；二级点框外只关二级；
/// - 整个流程走 [showAppCardModal]（独立遮罩的整屏路由）→ 卡片外任意处点击
///   都能关闭（`showModalBottomSheet` 自带的透明 Material 会吃掉卡片四周的
///   留白，导致框外点击没反应）；
/// - 图标统一 `ClayIconTile` + `CategoryGlyph`（与记一笔主网格同源）。
class BillConvertPage extends ConsumerStatefulWidget {
  const BillConvertPage({super.key});

  @override
  ConsumerState<BillConvertPage> createState() => _BillConvertPageState();
}

class _BillConvertPageState extends ConsumerState<BillConvertPage> {
  late LedgerPeriod _period =
      LedgerPeriod.monthOf(DateTime(DateTime.now().year, DateTime.now().month));

  LedgerAdvancedFilter? _filter;

  final Set<String> _selected = <String>{};

  bool _converting = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Transaction>> txnsAsync =
        ref.watch(bookAllTransactionsProvider);
    final Map<String, Category> categories =
        ref.watch(categoryMapProvider).valueOrNull ?? <String, Category>{};
    final Map<String, Account> accounts = <String, Account>{
      for (final Account a
          in ref.watch(accountsProvider).valueOrNull ?? <Account>[])
        a.id: a,
    };

    return Scaffold(
      body: Stack(
        children: <Widget>[
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _header(),
                _monthFilterRow(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _TipCard(),
                ),
                Expanded(
                  child: txnsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (Object e, StackTrace? s) =>
                        Center(child: Text('加载失败：$e')),
                    data: (List<Transaction> all) {
                      final List<Transaction> list = _filtered(all, categories);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _listHeader(list),
                          Expanded(
                            child: list.isEmpty
                                ? ListView(
                                    padding: EdgeInsets.zero,
                                    children: const <Widget>[
                                      Padding(
                                        padding: EdgeInsets.only(top: 72),
                                        child: EmptyState(message: '当前周期暂无账单'),
                                      ),
                                    ],
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.only(bottom: 110),
                                    itemCount: list.length,
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                      final Transaction txn = list[index];
                                      return _ConvertTile(
                                        txn: txn,
                                        category: categories[txn.categoryId],
                                        account: accounts[txn.accountId],
                                        toAccount: accounts[txn.toAccountId],
                                        checked: _selected.contains(txn.id),
                                        onToggle: () => _toggle(txn.id),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(child: _convertPill()),
          ),
        ],
      ),
    );
  }

  // ────────────────────────── 顶部 ──────────────────────────

  Widget _header() {
    return SizedBox(
      height: 46,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Text(
            '批量转换',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: IconButton(
              icon: LineGlyph(
                Icons.arrow_back_ios_new,
                size: 19,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthFilterRow() {
    final int n = _filter?.conditionCount ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _pickPeriod,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _period.label,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  LineGlyph(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _pickFilter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Text(
                n > 0 ? '筛选(条件$n个)' : '筛选',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: n > 0
                      ? ForestGreen.deep
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────── 筛选 ──────────────────────────

  List<Transaction> _filtered(
    List<Transaction> all,
    Map<String, Category> categories,
  ) {
    final int start = _period.start.millisecondsSinceEpoch;
    final int end = _period.end.millisecondsSinceEpoch;
    final List<Transaction> monthList = all
        .where((Transaction t) => t.occurredAt >= start && t.occurredAt < end)
        .toList();
    final List<Transaction> list =
        applyLedgerAdvancedFilter(monthList, _filter, categories);
    list.sort((Transaction a, Transaction b) => b.occurredAt - a.occurredAt);
    return list;
  }

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id)) {
        _selected.add(id);
      }
    });
  }

  Future<void> _pickPeriod() async {
    final CalendarPeriodMode cm = switch (_period.mode) {
      LedgerPeriodMode.week => CalendarPeriodMode.week,
      LedgerPeriodMode.month => CalendarPeriodMode.month,
      LedgerPeriodMode.year => CalendarPeriodMode.year,
      LedgerPeriodMode.custom => CalendarPeriodMode.custom,
    };
    final CalendarSelection? r = await CalendarSheet.show(
      context,
      mode: CalendarSheetMode.day,
      showDayView: false,
      headerTitle: '转换周期',
      initialPeriod: CalendarPeriod(cm, _period.start, _period.end),
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year, 12, 31),
      weekStart: CalendarWeekStart.monday,
    );
    if (r is! CalendarPeriod) return;
    final LedgerPeriodMode lm = switch (r.mode) {
      CalendarPeriodMode.week => LedgerPeriodMode.week,
      CalendarPeriodMode.month => LedgerPeriodMode.month,
      CalendarPeriodMode.year => LedgerPeriodMode.year,
      CalendarPeriodMode.custom => LedgerPeriodMode.custom,
    };
    setState(() {
      _period = LedgerPeriod(mode: lm, start: r.start, end: r.end);
      // 反向同步：筛选带着时间条件时一并换成新周期（时间轴只认一处）。
      _filter = ledgerFilterWithPeriod(_filter, _period);
      _selected.clear();
    });
  }

  Future<void> _pickFilter() async {
    final LedgerAdvancedFilter? result =
        await Navigator.of(context, rootNavigator: true)
            .push<LedgerAdvancedFilter>(
      MaterialPageRoute<LedgerAdvancedFilter>(
        builder: (BuildContext _) => LedgerFilterPage(initial: _filter),
      ),
    );
    if (result != null) {
      setState(() {
        _filter = result.isEmpty ? null : result;
        // 筛选的「时间」即页面周期：查询后页头周期跟着切（同账单页口径）。
        _period = ledgerPeriodOfFilter(result) ?? _period;
        _selected.clear();
      });
    }
  }

  // ────────────────────────── 列表头（共 N 笔 / 全选） ──────────────────────────

  Widget _listHeader(List<Transaction> visible) {
    final int count = visible.length;
    final bool allChecked =
        count > 0 && _selected.length >= count && _selected.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: <Widget>[
          Text(
            '共 $count 笔账单',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: count == 0
                ? null
                : () => setState(() {
                      if (allChecked) {
                        _selected.clear();
                      } else {
                        _selected
                          ..clear()
                          ..addAll(visible.map((Transaction t) => t.id));
                      }
                    }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                allChecked ? '取消全选' : '全选',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: count == 0
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : ForestGreen.deep,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────── 底部转换胶囊 ──────────────────────────

  Widget _convertPill() {
    final int n = _selected.length;
    final bool enabled = n > 0 && !_converting;
    return Opacity(
      opacity: enabled ? 1 : 0.75,
      child: Material(
        color: enabled ? ForestGreen.deep : ForestGreen.soft,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: enabled ? _openConvertSheet : null,
          child: Container(
            constraints: const BoxConstraints(minWidth: 220),
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
            alignment: Alignment.center,
            child: _converting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ForestGreen.deep,
                    ),
                  )
                : Text(
                    '转换($n个)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: enabled ? AppPalette.white : ForestGreen.deep,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // ────────────────────────── 转换 ──────────────────────────

  Future<void> _openConvertSheet() async {
    final ConvertParams? params = await showAppModalSheet<ConvertParams>(
      context,
      title: '批量转换',
      isScrollControlled: true,
      body: _ConvertSheet(count: _selected.length),
    );
    if (params == null || !mounted) return;
    await _confirmConvert(params);
  }

  Future<void> _confirmConvert(ConvertParams p) async {
    final Map<String, Category> categories =
        ref.read(categoryMapProvider).valueOrNull ?? <String, Category>{};
    final Map<String, Account> accounts = <String, Account>{
      for (final Account a
          in ref.read(accountsProvider).valueOrNull ?? <Account>[])
        a.id: a,
    };
    final List<String> parts = <String>[];
    if (p.categoryId != null) {
      final Category? cat = categories[p.categoryId];
      final String name = cat?.name ?? '?';
      // 分类自带方向：改分类 = 换分类 + 按分类方向改收支类型。
      parts.add(
        p.type != null
            ? '改分类为「$name」（并按分类方向改为${p.type!.label}）'
            : '改分类为「$name」',
      );
    }
    if (p.accountId != null) {
      parts.add('改账户为「${accounts[p.accountId]?.name ?? '?'}」');
    }
    if (p.tags != null) parts.add('改写为标签：${p.tags!.join('、')}');
    if (p.note != null) parts.add('改写备注');

    final bool? ok = await showConfirm(
      context,
      title: '确认批量转换',
      content: '将对选中的 ${_selected.length} 笔账单执行：\n'
          '· ${parts.join('\n· ')}\n\n'
          '账户变更与收支方向调整会重算相关账户余额并标记同步；'
          '借还、报销、储蓄、投资、物品、退款等联动账单的账户与类型不会被改动。',
      confirmText: '转换',
    );
    if (ok != true) return;
    await _convert(p);
  }

  Future<void> _convert(ConvertParams p) async {
    setState(() => _converting = true);
    try {
      final (int converted, int skipped) =
          await ref.read(transactionRepositoryProvider).convertBatch(
        List<String>.of(_selected),
        categoryId: p.categoryId,
        accountId: p.accountId,
        type: p.type,
        tags: p.tags,
        note: p.note,
        clearNote: p.clearNote,
      );
      if (mounted) {
        showAppToast(
          context,
          skipped == 0
              ? '已转换 $converted 笔账单'
              : '已转换 $converted 笔，$skipped 笔因联动受限已跳过',
        );
      }
    } on Object catch (e) {
      if (mounted) showAppToast(context, '转换失败：$e');
    } finally {
      if (mounted) {
        setState(() {
          _converting = false;
          _selected.clear();
        });
      }
    }
  }
}

/// 批量转换面板：四个可独立开启的改写项，每项带对应选择器。
class _ConvertSheet extends ConsumerStatefulWidget {
  final int count;
  const _ConvertSheet({required this.count});

  @override
  ConsumerState<_ConvertSheet> createState() => _ConvertSheetState();
}

class _ConvertSheetState extends ConsumerState<_ConvertSheet> {
  bool _catOn = false;
  bool _accOn = false;
  bool _tagOn = false;
  bool _noteOn = false;

  Category? _cat;
  Account? _acc;

  final TextEditingController _tagCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _tagCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  List<String> _parseTags(String text) {
    final List<String> out = text
        .split(RegExp(r'[,\s、，]+'))
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toSet()
        .toList();
    return out;
  }

  /// 分类自带方向（[CategoryType].expense / income），选中分类即隐含
  /// 「这笔账要改成那个方向」（2026-10-22 真机反馈「改收支类型移除，功能
  /// 合并到改分类，分类是按照支出收入方向调整的，选中分类后自动修改支出
  /// 收入方向」）。故面板不再单列「改收支类型」开关。
  TxnType? get _catDirection {
    final Category? c = _cat;
    if (c == null) return null;
    return switch (c.type) {
      CategoryType.expense => TxnType.expense,
      CategoryType.income => TxnType.income,
      // 转账类分类是系统分类（不对用户暴露），不出现在选择器里。
      CategoryType.transfer => null,
    };
  }

  bool get _canApply {
    if (_catOn && _cat != null) return true;
    if (_accOn && _acc != null) return true;
    if (_tagOn && _parseTags(_tagCtrl.text).isNotEmpty) return true;
    if (_noteOn && _noteCtrl.text.trim().isNotEmpty) return true;
    return false;
  }

  /// 分类选择：一级 / 二级两个弹窗（小青账同款钻取，与记一笔、分期页一致）。
  ///
  /// 一级弹窗按「支出 / 收入」分段列出一级分类，带下级的行给 chevron；
  /// 点进有下级的分类**在其上叠开**二级弹窗（不是「关掉一级再开二级」）——
  /// 二级弹窗标题栏带返回键，点框外也只是退回一级，随时能换别的分类。
  /// 图标统一走 `ClayIconTile` + `CategoryGlyph`，与全应用分类图标同源。
  ///
  /// 走 [showAppCardModal]（独立遮罩的整屏路由）而非 [showAppModalSheet]：
  /// 后者的底部弹层自带一块**铺满整层**的透明 Material，把卡片四周的留白
  /// 也吃掉 → 点框外没反应（2026-10-22 真机反馈「分类弹窗点框外没反应，
  /// 只能点击批量转换的框外」）。
  Future<void> _pickCategory() async {
    final Map<String, Category> cats =
        ref.read(categoryMapProvider).valueOrNull ?? <String, Category>{};
    // 系统分类（转账/余额调整等）由落账流程自动维护，不给用户手动改挂。
    final List<Category> all = cats.values
        .where((Category c) => !c.isSystem)
        .toList(growable: false);
    final List<Category> parents =
        all.where((Category c) => c.parentId == null).toList()
          ..sort((Category a, Category b) => a.sortOrder.compareTo(b.sortOrder));
    List<Category> childrenOf(Category parent) => all
        .where((Category c) => c.parentId == parent.id)
        .toList()
      ..sort((Category a, Category b) => a.sortOrder.compareTo(b.sortOrder));

    // 一级弹窗分段：支出 / 收入（sortOrder 库内按类型各自从 0 编号，
    // 两段互不干扰），其余类型兜底成「其他」。
    final List<_CatRow> level1 = <_CatRow>[];
    void appendSegment(String header, List<Category> items) {
      for (int i = 0; i < items.length; i++) {
        final Category c = items[i];
        level1.add(
          _CatRow(
            c,
            hasChildren: childrenOf(c).isNotEmpty,
            header: i == 0 ? header : null,
          ),
        );
      }
    }

    appendSegment(
      CategoryType.expense.label,
      parents.where((Category c) => c.type == CategoryType.expense).toList(),
    );
    appendSegment(
      CategoryType.income.label,
      parents.where((Category c) => c.type == CategoryType.income).toList(),
    );
    appendSegment(
      '其他',
      parents
          .where(
            (Category c) =>
                c.type != CategoryType.expense &&
                c.type != CategoryType.income,
          )
          .toList(),
    );

    final Category? picked = await showAppCardModal<Category>(
      context,
      title: '选择分类',
      body: _CategoryLevel1Sheet(
        rows: level1,
        childrenOf: childrenOf,
        // 已选子分类时，其一级分类也带勾选态，便于回看。
        selectedId: _cat == null ? null : (_cat!.parentId ?? _cat!.id),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _cat = picked);
    }
  }
  Future<void> _pickAccount() async {
    final Account? picked = await showAppModalSheet<Account>(
      context,
      useRootNavigator: true,
      isScrollControlled: true,
      bodyPadding: EdgeInsets.zero,
      body: AccountPickerSheet(
        title: '选择账户',
        showNoneRow: false,
        onConfirm: (Account? acc) => Navigator.of(context).maybePop(acc),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _acc = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool ready = _canApply;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '已选中 ${widget.count} 笔，选择要改写的项（可多选）',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _SwitchRow(
            label: '改分类',
            value: _catOn,
            onChanged: (bool v) => setState(() => _catOn = v),
            child: _catOn
                ? _PickerRow(
                    text: _cat == null
                        ? '选择分类'
                        : '${_cat!.name}（${_catDirection?.label ?? ''}）',
                    onTap: _pickCategory,
                    onClear: _cat == null
                        ? null
                        : () => setState(() => _cat = null),
                  )
                : null,
          ),
          _SwitchRow(
            label: '改账户',
            value: _accOn,
            onChanged: (bool v) => setState(() => _accOn = v),
            child: _accOn
                ? _PickerRow(
                    text: _acc?.name ?? '选择账户',
                    onTap: _pickAccount,
                    onClear: _acc == null
                        ? null
                        : () => setState(() => _acc = null),
                  )
                : null,
          ),
          _SwitchRow(
            label: '改标签',
            value: _tagOn,
            onChanged: (bool v) => setState(() => _tagOn = v),
            child: _tagOn
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextField(
                      controller: _tagCtrl,
                      decoration: InputDecoration(
                        hintText: '用逗号或空格分隔，如：餐饮, 出差',
                        filled: true,
                        fillColor: context.colors.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  )
                : null,
          ),
          _SwitchRow(
            label: '改备注',
            value: _noteOn,
            onChanged: (bool v) => setState(() => _noteOn = v),
            child: _noteOn
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextField(
                      controller: _noteCtrl,
                      decoration: InputDecoration(
                        hintText: '填写备注内容（将覆盖原备注）',
                        filled: true,
                        fillColor: context.colors.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: ready
                  ? () {
                      final List<String>? tags =
                          _tagOn ? _parseTags(_tagCtrl.text) : null;
                      Navigator.of(context).maybePop(
                        ConvertParams(
                          categoryId: _catOn ? _cat?.id : null,
                          accountId: _accOn ? _acc?.id : null,
                          // 方向随分类走：选中分类即自动改该笔账的收支方向
                          // （分类是按支出/收入划分的）。
                          type: _catOn ? _catDirection : null,
                          tags: _tagOn ? tags : null,
                          note: _noteOn ? _noteCtrl.text.trim() : null,
                        ),
                      );
                    }
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: ForestGreen.deep,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text(
                '应用转换',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 转换面板里的单行开关 + 可选的下挂选择器。
class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? child;

  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
        if (child != null) child!,
        const SizedBox(height: 12),
      ],
    );
  }
}

/// 「选择…」行：点按打开选择器，选中后显示名称并带清除按钮。
class _PickerRow extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _PickerRow({
    required this.text,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final bool selected = onClear != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (selected)
              InkWell(
                onTap: onClear,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: LineGlyph(
                    Icons.close,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              LineGlyph(
                Icons.chevron_right,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

/// 一级分类弹层：点「有子分类」的一级 → **在自身之上叠开二级弹层**。
///
/// 二级弹层是独立路由（[showAppCardModal]），因此：
/// - 二级标题栏带返回键 → 回到一级（2026-10-22 真机反馈「弹出二级分类后想返回
///   一级分类没有路径，只能彻底返回后再进入」）；
/// - 二级点框外只关二级 → 落回一级，不会把整个选择流程清空；
/// - 一级点框外才关闭整个选择弹层。
class _CategoryLevel1Sheet extends StatelessWidget {
  const _CategoryLevel1Sheet({
    required this.rows,
    required this.childrenOf,
    this.selectedId,
  });

  final List<_CatRow> rows;

  /// 某一级分类的子分类列表。
  final List<Category> Function(Category parent) childrenOf;

  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return _CategoryPickSheet(
      rows: rows,
      selectedId: selectedId,
      onRowTap: (Category c, bool hasChildren) async {
        if (!hasChildren) {
          Navigator.of(context).maybePop(c);
          return;
        }
        final List<Category> children = childrenOf(c);
        if (children.isEmpty) {
          Navigator.of(context).maybePop(c);
          return;
        }
        // 二级弹层叠在一级之上：一级不关闭，用户可随时退回。
        final Category? picked = await showAppCardModal<Category>(
          context,
          title: c.name,
          titleLeading: IconButton(
            // 专属 key：面板里还有别的 IconButton，测试需要精确命中返回键。
            key: const Key('category-sheet-back'),
            icon: const LineGlyph(Icons.arrow_back),
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          body: _CategoryPickSheet(
            rows: <_CatRow>[
              _CatRow(c, subtitle: '直接使用一级分类'),
              for (final Category child in children) _CatRow(child),
            ],
            selectedId: selectedId,
            emptyText: '暂无子分类',
          ),
        );
        // 二级被关掉（含点框外 / 返回键）→ 回到一级，不做任何选择。
        if (picked != null && context.mounted) {
          Navigator.of(context).maybePop(picked);
        }
      },
    );
  }
}

/// 分类弹层里的一行。
///
/// [header] 非空时在该行上方插一枚分段标题（一级弹窗按「支出 / 收入」分段，
/// 与分类管理页同口径）；[subtitle] 用于二级弹窗顶部的「直接使用一级分类」行。
class _CatRow {
  const _CatRow(
    this.category, {
    this.hasChildren = false,
    this.header,
    this.subtitle,
  });

  final Category category;
  final bool hasChildren;
  final String? header;
  final String? subtitle;
}

/// 分类选择列表（转换面板内弹层，一级 / 二级共用）。
///
/// 限高矮弹层（与预算编辑器 `pickCategory` 同款口径）：约 45% 屏高、
/// 内部滚动。**必须自带高度约束**——AppModalSheet 非 constrainHeight 分支的
/// Column(mainAxisSize: min) 给 body 的是无界高度，裸 ListView 会抛
/// 「Vertical viewport was given unbounded height」直接崩掉二级弹窗
/// （2026-10-22 真机反馈「选择分类不显示」：崩掉的弹窗留在栈顶只透出
/// 遮罩，点框外也只关掉这个隐形弹窗，表现为「点框外不能返回」）。
/// shrinkWrap: true 让短列表时卡片按内容高自适应，超限才滚动。
///
/// 图标与记一笔主网格、二级分类弹层同源：`ClayIconTile` + `CategoryGlyph`
/// （手绘线稿优先、Material 兜底），不再用「分类名首字」当头像
/// （2026-10-22 真机反馈「图标按照分类图标同步」）。
class _CategoryPickSheet extends StatelessWidget {
  const _CategoryPickSheet({
    required this.rows,
    this.selectedId,
    this.emptyText = '暂无分类',
    this.onRowTap,
  });

  final List<_CatRow> rows;
  final String? selectedId;
  final String emptyText;

  /// 行点击回调（传 null 时默认「选中并关闭本弹层」）。
  final Future<void> Function(Category category, bool hasChildren)? onRowTap;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(emptyText)),
      );
    }
    final ColorScheme cs = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.45,
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
        itemCount: rows.length,
        itemBuilder: (BuildContext context, int index) {
          final _CatRow row = rows[index];
          final Category c = row.category;
          final Color tint =
              c.colorValue != null ? Color(c.colorValue!) : ForestGreen.cta;
          final bool selected = c.id == selectedId;
          final Widget tile = InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              if (onRowTap != null) {
                onRowTap!(c, row.hasChildren);
              } else {
                Navigator.of(context).maybePop(c);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: <Widget>[
                  ClayIconTile(
                    size: 40,
                    color: tint,
                    child: CategoryGlyph(
                      c.iconKey,
                      size: 22,
                      // 与记一笔主网格未选中态同口径：向暖墨色收敛 22%，
                      // 避免线稿在渐变高光上被冲淡。
                      color: Color.lerp(tint, cs.onSurface, 0.22)!,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        if (row.subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              row.subtitle!,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (row.hasChildren)
                    LineGlyph(
                      Icons.chevron_right,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    )
                  else if (selected)
                    const LineGlyph(
                      Icons.check,
                      size: 20,
                      color: AppPalette.sage600,
                    ),
                ],
              ),
            ),
          );
          if (row.header == null) return tile;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                child: Text(
                  row.header!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              tile,
            ],
          );
        },
      ),
    );
  }
}

/// 批量转换参数（转换面板 → 页面）。
class ConvertParams {
  final String? categoryId;
  final String? accountId;
  final TxnType? type;
  final List<String>? tags;
  final String? note;
  final bool clearNote;

  const ConvertParams({
    this.categoryId,
    this.accountId,
    this.type,
    this.tags,
    this.note,
    this.clearNote = false,
  });
}

// ────────────────────────── 提示卡 ──────────────────────────

/// 提示卡：白底外卡（绿竖条 + 「提示」）+ 内嵌浅灰盒。
class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 3.5,
                height: 14,
                decoration: BoxDecoration(
                  color: ForestGreen.deep,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '提示',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppPalette.neutralSoft.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                LineGlyph(
                  Icons.info_outline,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '按时间或筛选条件（分类 / 账户等）收窄账单，再多选要转换的'
                    '记录；可同时改写分类、账户、标签与备注。'
                    '分类按支出 / 收入方向划分，选中分类即自动调整该笔的收支方向；'
                    '账户变更与方向调整会重算余额并标记同步。',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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

// ────────────────────────── 账单行 ──────────────────────────

/// 可勾选账单行（与账单清理同款布局）。
class _ConvertTile extends StatelessWidget {
  const _ConvertTile({
    required this.txn,
    required this.category,
    required this.account,
    required this.toAccount,
    required this.checked,
    required this.onToggle,
  });

  final Transaction txn;
  final Category? category;
  final Account? account;
  final Account? toAccount;
  final bool checked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final DateTime occurred = DateTime.fromMillisecondsSinceEpoch(
      txn.occurredAt,
      isUtc: true,
    ).toLocal();
    final String title = txn.sourceModule == SourceModule.refund
        ? SourceModule.refund.label
        : (category?.name ?? txn.type.label);

    final List<String> tags = <String>[
      if (txn.sourceModule == SourceModule.refund &&
          (txn.relatedId?.isNotEmpty ?? false))
        '已关联',
      if (txn.sourceModule == SourceModule.savings) '存钱计划',
    ];

    final String dateLabel = occurred.year == DateTime.now().year
        ? DateFormat('M月d日').format(occurred)
        : DateFormat('yyyy年M月d日').format(occurred);

    return Material(
      color: AppPalette.white,
      child: InkWell(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppPalette.divider, width: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _icon(context),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        for (final String tag in tags) ...<Widget>[
                          const SizedBox(width: 6),
                          TagPill(tag),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      dateLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('HH:mm').format(occurred),
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _amountColumn(context),
              const SizedBox(width: 12),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: checked ? ForestGreen.deep : Colors.transparent,
                  border: Border.all(
                    width: 1.6,
                    color: checked ? ForestGreen.deep : AppPalette.divider,
                  ),
                ),
                child: checked
                    ? const LineGlyph(Icons.check, size: 14, color: AppPalette.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _icon(BuildContext context) {
    final Color tint = category?.colorValue != null
        ? Color(category!.colorValue!)
        : switch (txn.type) {
            TxnType.income => AppPalette.income,
            TxnType.expense => AppPalette.expense,
            TxnType.transfer => AppPalette.transfer,
          };
    final LineIconKind lineKind = resolveTxnLineIcon(txn, category);

    return ClayIconTile(
      size: 44,
      color: tint,
      child: Center(
        child: LineIcon(
          lineKind,
          size: 22,
          color: Color.lerp(
            tint,
            Theme.of(context).colorScheme.onSurface,
            0.22,
          )!,
        ),
      ),
    );
  }

  Widget _amountColumn(BuildContext context) {
    final bool isExpense = txn.type == TxnType.expense;
    final bool hasDiscount = isExpense && txn.discountMinor > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (hasDiscount)
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                '−${Money.fromMinor(txn.amountMinor).format()}',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  decoration: TextDecoration.lineThrough,
                  decorationColor:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                Money.fromMinor(txn.amountMinor - txn.discountMinor)
                    .format(showSymbol: false),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.expense,
                ),
              ),
            ],
          )
        else
          Text(
            switch (txn.type) {
              TxnType.income => '+${Money.fromMinor(txn.amountMinor).format()}',
              TxnType.expense =>
                '−${Money.fromMinor(txn.amountMinor).format()}',
              TxnType.transfer => Money.fromMinor(txn.amountMinor).format(),
            },
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: txn.type == TxnType.income
                  ? AppPalette.income
                  : txn.type == TxnType.expense
                      ? AppPalette.expense
                      : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        if (hasDiscount)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '优惠${Money.fromMinor(txn.discountMinor).format(showSymbol: false)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppPalette.expense,
              ),
            ),
          ),
      ],
    );
  }
}
