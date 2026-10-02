import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/models/money.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/app_toast.dart' show showAppToast;
import '../../../routing/app_router.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../record/presentation/account_picker_sheet.dart';
import '../../../shared/widgets/calendar_sheet.dart';
import '../../../shared/widgets/calendar_month_view.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/module_list_scaffold.dart' show confirmDelete;
import '../data/savings_repository.dart';
import '../providers/savings_providers.dart';
import '../../../shared/widgets/amount_keypad.dart';
import 'savings_page.dart';
import 'savings_modes.dart';
import '../../../domain/enums.dart';
import '../../ledger/data/transaction_repository.dart';
import '../../categories/data/category_repository.dart';
import '../../ledger/providers/ledger_providers.dart';
import 'savings_schedule.dart';
import '../../../shared/widgets/line_icons.dart';

/// 储蓄计划详情页（参照小青账计划详情）：
///
/// - 顶部：计划卡（复用 [SavingsGoalTile]，点击不再弹面板）；
/// - 「日历」卡：当月月历，已存入日期绿圈标记；
/// - 「存钱进度」卡：已存 / 剩余 + 进度条 + 开始 / 结束日期；
/// - 年份筛选 + 网格/列表切换 + 逐期存入卡片（点卡存入 / 撤销）；
/// - 右下角悬浮键：一键存入下一期（按计划金额）。
class SavingsGoalDetailPage extends ConsumerStatefulWidget {
  const SavingsGoalDetailPage({super.key, required this.goalId});

  final String goalId;

  @override
  ConsumerState<SavingsGoalDetailPage> createState() =>
      _SavingsGoalDetailPageState();
}

/// 逐期排序方式（参照小青账「排序方式」弹窗六选项）。
enum _SortKey {
  timeAsc('按时间 ↑'),
  timeDesc('按时间 ↓'),
  savedAsc('按已存入金额 ↑'),
  savedDesc('按已存入金额 ↓'),
  totalAsc('按总金额 ↑'),
  totalDesc('按总金额 ↓');

  const _SortKey(this.label);

  /// 弹窗展示文案。
  final String label;
}

class _SavingsGoalDetailPageState extends ConsumerState<SavingsGoalDetailPage> {
  /// 年份筛选（null = 自动：当前年不在范围内时取第一年）。
  int? _year;

  /// 期卡展示形态：true = 网格（默认），false = 列表。
  bool _grid = true;

  /// 逐期排序方式（默认按时间升序 = 第1期在最上）。
  _SortKey _sort = _SortKey.timeAsc;

  /// 「日历」卡展开态：默认折叠，点标题行切换。
  bool _calendarExpanded = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<SavingsGoal>> goals = ref.watch(savingsListProvider);
    final List<SavingsGoal> list = goals.value ?? const <SavingsGoal>[];
    SavingsGoal? goal;
    for (final SavingsGoal g in list) {
      if (g.id == widget.goalId) goal = g;
    }

    if (goal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('计划详情')),
        body: const Center(child: Text('计划不存在或已删除')),
      );
    }

    final List<SavingsDeposit> deposits =
        ref.watch(savingsDepositsProvider(widget.goalId)).value ??
            const <SavingsDeposit>[];
    final Map<int, SavingsDeposit> depositedByIndex = <int, SavingsDeposit>{
      for (final SavingsDeposit d in deposits) d.dayIndex: d,
    };
    final List<SavingsScheduleEntry> entries = SavingsSchedule.build(goal);

    // 灵活存钱法：无逐期排期（单期灵活存入）。
    // 定额 / 弹性「不结束」（endNote == null）：有滚动排期（见
    // SavingsSchedule.build），日历 / 期卡正常展示，仅「结束」显示 —。
    final bool isFlexible = goal.mode == SavingsMode.flexible.name;
    final bool noSchedule = isFlexible;
    final bool noEnd = goal.endNote == null;

    // 年份集合 + 当前选择归位。
    final Set<int> years =
        entries.map((SavingsScheduleEntry e) => e.date.year).toSet();
    final int nowYear = DateTime.now().year;
    final int activeYear = (_year != null && years.contains(_year))
        ? _year!
        : (years.contains(nowYear)
            ? nowYear
            : (years.isEmpty ? nowYear : years.first));
    final List<SavingsScheduleEntry> yearEntries = entries
        .where((SavingsScheduleEntry e) => e.date.year == activeYear)
        .toList()
      ..sort(_entryComparator(depositedByIndex));

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.name, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          TextButton(
            onPressed: () => _showManage(context, goal!),
            child: const Text('管理', style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: <Widget>[
          // 顶部计划卡（与列表一致，点击不弹面板）。
          SavingsGoalTile(goal: goal, onTap: () {}),
          const SizedBox(height: 4),
          // 「日历」卡（默认折叠，点标题行展开 / 收起）；
          // 仅灵活存钱法无逐期排期，隐藏。
          if (!noSchedule) _calendarCard(deposits, entries),
          if (!noSchedule) const SizedBox(height: 12),
          // 「存钱进度」卡。
          _progressCard(context, goal, entries, noEnd: noEnd || isFlexible),
          const SizedBox(height: 12),
          // 灵活存钱法：无逐期排期，提供醒目「存入一笔」入口；
          // 进度按实际存入金额计算。其余模式（含不结束的滚动排期）：
          // 年份筛选 + 期卡网格/列表。
          if (noSchedule)
            _flexibleDepositButton(context, goal)
          else ...<Widget>[
            Row(
              children: <Widget>[
                // 年份选择：点「xxxx年 ∨」弹 CalendarSheet（year 模式，资产详情页同款）。
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _pickYear(years, activeYear),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          '$activeYear年',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const Icon(Icons.expand_more, size: 20),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // 排序键：底部弹窗选择排序方式（小青账「排序方式」同款）。
                IconButton(
                  tooltip: '排序方式',
                  icon: Icon(
                    Icons.schedule,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onPressed: _showSortSheet,
                ),
                // 形态切换键：单枚，点击在 网格 ⇄ 列表 间来回切换，
                // 图标始终显示「将切换到的形态」（网格态显列表键，列表态显网格键）。
                IconButton(
                  tooltip: _grid ? '切换为列表' : '切换为网格',
                  icon: Icon(
                    _grid ? Icons.view_list_rounded : Icons.grid_view_outlined,
                    size: 20,
                    color: AppPalette.deepGreen,
                  ),
                  onPressed: () => setState(() => _grid = !_grid),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (yearEntries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    '$activeYear 年暂无存入计划',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              )
            else if (_grid)
              GridView.count(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.28,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: <Widget>[
                  for (final SavingsScheduleEntry e in yearEntries)
                    _EntryCard(
                      entry: e,
                      deposit: depositedByIndex[e.index],
                      onTap: () =>
                          _onEntryTap(goal!, e, depositedByIndex[e.index]),
                    ),
                ],
              )
            else ...<Widget>[
              for (final SavingsScheduleEntry e in yearEntries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _EntryListTile(
                    entry: e,
                    deposit: depositedByIndex[e.index],
                    onTap: () =>
                        _onEntryTap(goal!, e, depositedByIndex[e.index]),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  /// 「日历」卡：绿竖条 + 标题行可点（展开 / 收起，默认折叠），
  /// 展开时渲染 [SavingsCalendarView]（小青账日历布局，可左右滑月）。
  Widget _calendarCard(
    List<SavingsDeposit> deposits,
    List<SavingsScheduleEntry> entries,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _calendarExpanded = !_calendarExpanded),
            child: Row(
              children: <Widget>[
                Container(
                  width: 4,
                  height: 14,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        AppPalette.sageMist,
                        AppPalette.sageRibbon,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '日历',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.deepGreen,
                  ),
                ),
              ],
            ),
          ),
          if (_calendarExpanded) ...<Widget>[
            const SizedBox(height: 10),
            SavingsCalendarView(deposits: deposits, entries: entries),
          ],
        ],
      ),
    );
  }

  /// 「存钱进度」卡：已存 / 剩余 + 进度条 + 开始 / 结束日期。
  /// 灵活存钱法 [isFlexible]=true 时不设结束期，结束显示「—」，
  /// 进度按实际存入金额占目标百分比计算。
  Widget _progressCard(
    BuildContext context,
    SavingsGoal goal,
    List<SavingsScheduleEntry> entries, {
    required bool noEnd,
  }) {
    final ThemeData theme = Theme.of(context);
    final double progress = goal.targetMinor == 0
        ? 0
        : (goal.currentMinor / goal.targetMinor).clamp(0.0, 1.0);
    final DateTime start = SavingsSchedule.startOf(goal);
    final DateTime? end =
        noEnd ? null : (entries.isEmpty ? null : entries.last.date);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '存钱进度',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppPalette.deepGreen,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '已存: ${Money.fromMinor(goal.currentMinor).format(showSymbol: false)}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '剩余: ${Money.fromMinor(
                  (goal.targetMinor - goal.currentMinor).clamp(0, 1 << 40),
                ).format(showSymbol: false)}',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: AppPalette.softGreen.withValues(alpha: 0.4),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppPalette.deepGreen,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(progress * 100).toStringAsFixed(2)}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.deepGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppPalette.softGreen.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '开始: ${DateFormat('yyyy-MM-dd').format(start)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Text(
                  end == null
                      ? '结束: —'
                      : '结束: ${DateFormat('yyyy-MM-dd').format(end)}',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 灵活存钱法专属：无逐期排期，提供一个醒目的「存入一笔」入口，
  /// 进度按实际存入金额占目标百分比计算。存/取走 [SavingsRepository.deposit]
  /// （仅调总额，不写逐期台账）。
  Widget _flexibleDepositButton(BuildContext context, SavingsGoal goal) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppPalette.sageMist, AppPalette.sageRibbon],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: SizedBox(
        height: 48,
        child: Center(
          child: TextButton(
            onPressed: () => _showDepositDialog(sign: 1, goal: goal),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text(
              '存入一笔',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }

  /// 期卡点击：未存入 / 已存入 均弹「存钱」底部弹窗（小青账同款）。
  /// 已存入时 [deposit] 非 null：预填金额与备注，可修改保存，或撤销存入。
  Future<void> _onEntryTap(
    SavingsGoal goal,
    SavingsScheduleEntry entry,
    SavingsDeposit? deposit,
  ) async {
    // 未存入 / 已存入 共用「存钱」底部弹窗（已存入时预填金额与备注，并支持撤销）。
    await _showDepositSheet(goal, entry, deposit: deposit);
  }

  /// 「存钱」底部弹窗（参照小青账截图）：
  ///
  /// 标题行（左 ✕ / 居中「存钱」）→ ⓘ 加油提示 →「存钱」小节
  /// （¥ 金额输入预填计划额 + 备注输入）→「账本」行 →「账户」小节
  /// （转出·扣款账户 → ¥转至 → 转入·入款账户）→ 底部常驻绿色渐变「保存」。
  ///
  /// 落库口径：depositDay / updateDeposit 写台账（含备注）；金额可改；
  /// 扣款账户为页面态快捷属性不落库；入款账户仅回显计划 accountId。
  /// [deposit] 非 null 表示「已存入」模式：预填金额与备注，保存走更新，
  /// 底部额外提供「撤销存入」。
  Future<void> _showDepositSheet(
    SavingsGoal goal,
    SavingsScheduleEntry entry, {
    SavingsDeposit? deposit,
  }) async {
    final int prefillMinor = deposit?.amountMinor ?? entry.amountMinor;
    // 金额用字符串状态 + 工程内 AmountKeypad 键盘驱动（不弹系统键盘）。
    String amountText = prefillMinor <= 0
        ? ''
        : Money.fromMinor(prefillMinor).format(showSymbol: false);
    final TextEditingController noteController =
        TextEditingController(text: deposit?.note ?? '');
    // 预载该期已关联的账本流水（关联键 goalId#dayIndex），让扣款/入款账户
    // 回显，避免重复建流水；无关联则扣款账户留空（用户自行选择）。
    final Transaction? linkedTxn = await ref
        .read(transactionRepositoryProvider)
        .getByRelatedId('${goal.id}#${entry.index}');
    String? sourceAccountId = linkedTxn?.accountId; // 转出/扣款账户
    String? targetAccountId = linkedTxn?.toAccountId ?? goal.accountId; // 入款

    // 保存：保存按钮行与底部 AmountKeypad 的确认键共用。
    Future<void> doSave() async {
      final Money amt = Money.tryParse(amountText);
      if (amt.minor <= 0) {
        showAppToast(context, '金额必须大于 0');
        return;
      }
      final NavigatorState nav = Navigator.of(context);
      try {
        if (deposit != null) {
          await ref.read(savingsRepositoryProvider).updateDeposit(
                goalId: widget.goalId,
                dayIndex: entry.index,
                amountMinor: amt.minor,
                note: noteController.text.trim(),
              );
        } else {
          await ref.read(savingsRepositoryProvider).depositDay(
                goalId: widget.goalId,
                dayIndex: entry.index,
                amountMinor: amt.minor,
                note: noteController.text.trim(),
              );
        }
        // 记账联动：与所选扣款/入款账户保持一致（新建/更新/撤销对账）。
        await _syncPeriodTxn(
          goal: goal,
          dayIndex: entry.index,
          sourceAccountId: sourceAccountId,
          targetAccountId: targetAccountId,
          amountMinor: amt.minor,
        );
        nav.pop();
        if (mounted) {
          showAppToast(
            this.context,
            deposit != null ? '已更新 ${amt.format()}' : '已存入 ${amt.format()}',
          );
        }
      } on AppFailure catch (e) {
        showAppToast(context, e.message);
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext sheetCtx) => StatefulBuilder(
        builder: (BuildContext sheetCtx,
            void Function(void Function()) setSheetState) {
          final ThemeData theme = Theme.of(sheetCtx);
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetCtx).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // 标题行：左 ✕ 圆键 + 居中「存钱」。
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 16, 0),
                    child: SizedBox(
                      height: 44,
                      child: Stack(
                        children: <Widget>[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: InkResponse(
                              onTap: () => Navigator.of(sheetCtx).pop(),
                              radius: 20,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.close,
                                  size: 17,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          const Center(
                            child: Text(
                              '存钱',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    height: 1,
                    color: theme.dividerColor.withValues(alpha: 0.4),
                  ),
                  Flexible(
                    child: ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      children: <Widget>[
                        // ⓘ 加油提示。
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppPalette.surfaceMist,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '加油，一定会圆满完成的',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        // 「存钱」小节：金额 + 备注。
                        _sheetSection(
                          title: '存钱',
                          children: <Widget>[
                            // 金额展示行：只读，由底部 AmountKeypad 驱动。
                            _sheetAmountDisplay(amountText),
                            const SizedBox(height: 12),
                            _sheetInput(
                              controller: noteController,
                              hint: '请输入备注',
                              leadingIcon: Icons.receipt_long_outlined,
                              maxLines: 1,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // 「账本」行。
                        _sheetSection(
                          title: '账本',
                          children: <Widget>[
                            Builder(builder: (BuildContext ctx) {
                              final Book? book =
                                  ref.read(currentBookProvider).valueOrNull;
                              final String bookName = book?.name ?? '默认账本';
                              return Row(
                                children: <Widget>[
                                  Container(
                                    width: 44,
                                    height: 44,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      color: AppPalette.softGreen,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      bookName.isEmpty
                                          ? '账'
                                          : bookName.characters.first,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppPalette.deepGreen,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        const Text(
                                          '账本',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          bookName,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 22,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // 「账户」小节：转出·扣款 → 转至 → 转入·入款。
                        _sheetSection(
                          title: '账户',
                          children: <Widget>[
                            Column(
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: _sheetAccountPill(
                                        sheetCtx: sheetCtx,
                                        title: '选择扣款账户',
                                        accountId: sourceAccountId,
                                        onChanged: (String? id) =>
                                            setSheetState(
                                                () => sourceAccountId = id),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _sheetLabelPill(sheetCtx, '扣款账户'),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Center(
                                  child: _sheetLabelPill(sheetCtx, '转至',
                                      icon: Icons.currency_yuan),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: _sheetAccountPill(
                                        sheetCtx: sheetCtx,
                                        title: '选择入款账户',
                                        accountId: targetAccountId,
                                        onChanged: (String? id) =>
                                            setSheetState(
                                                () => targetAccountId = id),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _sheetLabelPill(sheetCtx, '入款账户'),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 底部：已存入时左「撤销存入」+ 右「保存」；未存入仅「保存」。
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                      child: Row(
                        children: <Widget>[
                          if (deposit != null) ...<Widget>[
                            SizedBox(
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final NavigatorState nav =
                                      Navigator.of(sheetCtx);
                                  try {
                                    await ref
                                        .read(savingsRepositoryProvider)
                                        .cancelDay(
                                          goalId: widget.goalId,
                                          dayIndex: entry.index,
                                        );
                                    // 同步撤销账本侧流水（反向冲销余额，保持账本一致）。
                                    await ref
                                        .read(transactionRepositoryProvider)
                                        .removeByRelatedId(
                                          '${goal.id}#${entry.index}',
                                        );
                                    nav.pop();
                                    if (mounted) {
                                      showAppToast(this.context, '已撤销存入');
                                    }
                                  } on AppFailure catch (e) {
                                    showAppToast(sheetCtx, e.message);
                                  }
                                },
                                icon:
                                    const Icon(Icons.delete_outline, size: 18),
                                label: const Text('撤销存入'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: theme.colorScheme.error,
                                  side: BorderSide(
                                    color: theme.colorScheme.error
                                        .withValues(alpha: 0.5),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: <Color>[
                                    AppPalette.sageMist,
                                    AppPalette.sageRibbon,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: SizedBox(
                                height: 48,
                                child: Center(
                                  child: TextButton(
                                    onPressed: doSave,
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size.fromHeight(48),
                                      foregroundColor:
                                          theme.colorScheme.onPrimary,
                                    ),
                                    child: const Text(
                                      '保存',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
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
                  // 工程内数字键盘：金额输入专用（删除键占用「再记」槽位，
                  // 不渲染内置保存——保存走上方按钮行）。
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: SafeArea(
                      top: false,
                      child: AmountKeypad(
                        value: amountText,
                        onChanged: (String v) =>
                            setSheetState(() => amountText = v),
                        onBackspace: () => setSheetState(() {
                          if (amountText.isNotEmpty) {
                            amountText =
                                amountText.substring(0, amountText.length - 1);
                          }
                        }),
                        onSave: doSave,
                        showSave: false,
                      ),
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

  /// 弹窗小节：绿竖条 + 标题 + 内容。
  Widget _sheetSection(
      {required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 4,
              height: 14,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[AppPalette.sageMist, AppPalette.sageRibbon],
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppPalette.deepGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }

  /// 弹窗金额展示行：只读，由底部 [AmountKeypad] 驱动，样式同输入框。
  Widget _sheetAmountDisplay(String amountText) {
    final ThemeData theme = Theme.of(context);
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: AppPalette.surfaceMist,
        borderRadius: BorderRadius.circular(28),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.currency_yuan,
              size: 17,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              amountText.isEmpty ? '请输入金额' : amountText,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: amountText.isEmpty
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 弹窗输入框：圆角灰底 + 左侧灰方块图标。
  Widget _sheetInput({
    required TextEditingController controller,
    required String hint,
    required IconData leadingIcon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    final ThemeData theme = Theme.of(context);
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
        filled: true,
        fillColor: AppPalette.surfaceMist,
        prefixIcon: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(
            leadingIcon,
            size: 17,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 36, minHeight: 36),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  /// 弹窗账户胶囊：未选灰底显示字段名，已选绿底显示账户名（可重选/清空）。
  Widget _sheetAccountPill({
    required BuildContext sheetCtx,
    required String title,
    required String? accountId,
    required ValueChanged<String?> onChanged,
  }) {
    final ThemeData theme = Theme.of(sheetCtx);
    final List<Account> all =
        ref.read(accountsProvider).valueOrNull ?? const <Account>[];
    Account? acc;
    for (final Account a in all) {
      if (a.id == accountId) {
        acc = a;
        break;
      }
    }
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () async {
        final Account? picked = await showModalBottomSheet<Account>(
          context: sheetCtx,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (BuildContext ctx) => AccountPickerSheet(
            filter: fundAccountsOnly,
            selectedId: accountId,
            title: title,
            noneTitle: '不选择具体账户',
            onAdd: () {
              if (mounted) context.push(Routes.accountAdd);
            },
            onManage: () {
              if (mounted) context.push(Routes.accountManage);
            },
            onConfirm: (Account? a) => Navigator.of(ctx).pop(a),
          ),
        );
        onChanged(picked?.id);
      },
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: acc == null ? AppPalette.surfaceMist : AppPalette.softGreen,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              acc == null ? Icons.account_balance_wallet_outlined : Icons.check,
              size: 18,
              color: acc == null
                  ? theme.colorScheme.onSurfaceVariant
                  : AppPalette.deepGreen,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                acc?.name ?? title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: acc == null
                      ? theme.colorScheme.onSurfaceVariant
                      : AppPalette.deepGreen,
                  fontWeight: acc == null ? FontWeight.w400 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 弹窗右侧静态标签胶囊（扣款账户 / 入款账户 / ¥ 转至）。
  Widget _sheetLabelPill(BuildContext sheetCtx, String label,
      {IconData? icon}) {
    final ThemeData theme = Theme.of(sheetCtx);
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppPalette.surfaceMist,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 当前 [_sort] 下的期卡比较器：
  /// 按时间 = 期数（日期同序）；按已存入金额 = 台账实际存入额（未存入 0）；
  /// 按总金额 = 计划金额。并列时回退按期数升序保持稳定。
  Comparator<SavingsScheduleEntry> _entryComparator(
    Map<int, SavingsDeposit> depositedByIndex,
  ) {
    final bool desc = _sort == _SortKey.timeDesc ||
        _sort == _SortKey.savedDesc ||
        _sort == _SortKey.totalDesc;
    int compare(SavingsScheduleEntry a, SavingsScheduleEntry b) {
      int r;
      switch (_sort) {
        case _SortKey.timeAsc:
        case _SortKey.timeDesc:
          r = a.index.compareTo(b.index);
          break;
        case _SortKey.savedAsc:
        case _SortKey.savedDesc:
          final int av = depositedByIndex[a.index]?.amountMinor ?? 0;
          final int bv = depositedByIndex[b.index]?.amountMinor ?? 0;
          r = av.compareTo(bv);
          break;
        case _SortKey.totalAsc:
        case _SortKey.totalDesc:
          r = a.amountMinor.compareTo(b.amountMinor);
          break;
      }
      if (r == 0) r = a.index.compareTo(b.index);
      return desc ? -r : r;
    }

    return compare;
  }

  /// 年份选择：底部弹 [CalendarSheet]（year 模式，资产详情页同款），
  /// 可选范围取计划实际覆盖的年份区间（含当前选中）。
  Future<void> _pickYear(Set<int> years, int activeYear) async {
    final List<int> sorted = years.toList()..sort();
    final int min = sorted.isEmpty ? activeYear - 2 : sorted.first;
    final int max = sorted.isEmpty
        ? activeYear + 9
        : (sorted.last > activeYear ? sorted.last : activeYear);
    final CalendarSelection? sel = await CalendarSheet.show(
      context,
      mode: CalendarSheetMode.year,
      initialYear: activeYear,
      firstDate: DateTime(min, 1, 1),
      lastDate: DateTime(max, 12, 31),
    );
    if (sel is CalendarYear && sel.year != activeYear) {
      setState(() => _year = sel.year);
    }
  }

  /// 「排序方式」底部弹窗（小青账同款）：
  /// 左 ✕ 圆键 + 居中标题，六个选项行，当前项文案尾随 ✓、行尾灰箭头。
  Future<void> _showSortSheet() async {
    final ThemeData theme = Theme.of(context);
    final _SortKey? picked = await showModalBottomSheet<_SortKey>(
      context: context,
      backgroundColor: theme.colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetCtx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // 标题行：左 ✕ 圆键 + 居中「排序方式」。
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 16, 0),
              child: SizedBox(
                height: 44,
                child: Stack(
                  children: <Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkResponse(
                        onTap: () => Navigator.of(sheetCtx).pop(),
                        radius: 20,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.close,
                            size: 17,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const Center(
                      child: Text(
                        '排序方式',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 六个排序选项。
            for (final _SortKey key in _SortKey.values)
              InkWell(
                onTap: () => Navigator.of(sheetCtx).pop(key),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.35),
                        width: 0.6,
                      ),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Text(
                        key.label,
                        style: const TextStyle(fontSize: 15.5),
                      ),
                      if (key == _sort) ...<Widget>[
                        const SizedBox(width: 8),
                        const Icon(Icons.check, size: 17),
                      ],
                      const Spacer(),
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null && picked != _sort) {
      setState(() => _sort = picked);
    }
  }

  /// AppBar「管理」：存入 / 取出 / 归档 / 删除。
  Future<void> _showManage(BuildContext context, SavingsGoal goal) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                goal.name,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: LineIcon(
                categoryLineKind('deposit_in')!,
                size: 24,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
              title: const Text('存入'),
              onTap: () {
                Navigator.of(ctx).pop();
                _showDepositDialog(sign: 1, goal: goal);
              },
            ),
            if (goal.currentMinor > 0)
              ListTile(
                leading: LineIcon(
                  categoryLineKind('deposit_out')!,
                  size: 24,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
                title: const Text('取出'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showWithdrawSheet(goal);
                },
              ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('归档'),
              onTap: () async {
                Navigator.of(ctx).pop();
                try {
                  await ref
                      .read(savingsRepositoryProvider)
                      .setArchived(goal.id, archived: true);
                  if (mounted) {
                    showAppToast(context, '已归档「${goal.name}」');
                    Navigator.of(context).pop(); // 详情页随归档退出
                  }
                } on AppFailure catch (e) {
                  if (mounted) showAppToast(context, e.message);
                }
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                '删除',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                final bool ok = await confirmDelete(
                  context,
                  title: '删除目标「${goal.name}」？',
                );
                if (!ok) return;
                try {
                  await ref.read(savingsRepositoryProvider).remove(goal.id);
                  if (mounted) Navigator.of(context).pop();
                } on AppFailure catch (e) {
                  if (mounted) showAppToast(context, e.message);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 通用存入 / 取出（不计入逐期台账，仅调总额）。
  /// 灵活 / 开放式计划的「存入 / 取出」底部弹窗。
  /// 金额 + 可选「扣款 / 转入账户」：保存时除调整 [SavingsGoal.currentMinor] 外，
  /// 若选了账户则同步生成一笔真实流水（与账本对账一致）：
  /// - 有入款账户(goal.accountId) → 转账（扣款账户 ⇄ 入款账户）；
  /// - 无入款账户 → 存入记支出、取出记收入（钱离开 / 回到扣款账户）。
  Future<void> _showDepositDialog({
    required int sign,
    required SavingsGoal goal,
  }) async {
    final TextEditingController controller = TextEditingController();
    String? sourceAccountId; // 转出/转入账户（可空 = 不记账本流水）

    final bool? ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetCtx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setSt) => Container(
          decoration: const BoxDecoration(
            color: AppPalette.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Text(
                    sign > 0 ? '存入一笔' : '取出',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 16),
                AmountField(controller: controller),
                const SizedBox(height: 16),
                _sheetAccountPill(
                  sheetCtx: ctx,
                  title: sign > 0 ? '扣款账户' : '转入账户',
                  accountId: sourceAccountId,
                  onChanged: (String? v) => setSt(() => sourceAccountId = v),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              AppPalette.sageMist,
                              AppPalette.sageRibbon
                            ],
                          ),
                          borderRadius: BorderRadius.all(Radius.circular(28)),
                        ),
                        child: SizedBox(
                          height: 44,
                          child: TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  Theme.of(ctx).colorScheme.onPrimary,
                            ),
                            child: const Text('保存'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;

    final Money amt = Money.tryParse(controller.text);
    if (amt.minor <= 0) {
      showAppToast(context, '金额必须大于 0');
      return;
    }
    try {
      final SavingsRepository repo = ref.read(savingsRepositoryProvider);
      await repo.deposit(goal.id, sign * amt.minor);
      // 记账联动：选了账户才生成真实流水，否则只调储蓄总额。
      if (sourceAccountId != null) {
        await _recordSavingsTxn(
          goal: goal,
          sourceAccountId: sourceAccountId!,
          amountMinor: amt.minor,
          sign: sign,
          relatedId: goal.id,
        );
      }
      if (mounted) {
        showAppToast(
          context,
          sign > 0 ? '已存入' : '已取出',
        );
      }
    } on AppFailure catch (e) {
      if (mounted) showAppToast(context, e.message);
    }
  }

  /// 为储蓄存入 / 取出生成一笔真实账本流水（sourceModule=savings）。
  /// [sign] > 0 存入、< 0 取出；[sourceAccountId] 为弹窗所选账户；
  /// [targetAccountId] 为转入（入款）账户，缺省回退 goal.accountId；
  /// [relatedId] 关联键（灵活=goalId，逐期=goalId#dayIndex）。
  Future<void> _recordSavingsTxn({
    required SavingsGoal goal,
    required String sourceAccountId,
    required int amountMinor,
    required int sign,
    String? targetAccountId,
    required String relatedId,
  }) async {
    final TransactionRepository txnRepo =
        ref.read(transactionRepositoryProvider);
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final String note = '${sign > 0 ? '储蓄存入' : '储蓄取出'}「${goal.name}」';
    // 系统分类「存款」：ensureNamed 自动重建（isSystem=1，用户分类选择器
    // 隐藏），储蓄存入/取出流水统一归到「存款」类目下。
    final String savingsCategoryId = await CategoryRepository(
      ref.read(appDatabaseProvider),
    ).ensureNamed(
      bookId: goal.bookId,
      name: '存款',
      type: CategoryType.expense,
      iconKey: 'deposit_in',
      isSystem: true,
    );
    final String? effectiveTarget = targetAccountId ?? goal.accountId;
    if (effectiveTarget != null && effectiveTarget != sourceAccountId) {
      // 有入款账户：转账（存入 扣款→入款；取出 入款→扣款）。
      await txnRepo.add(
        bookId: goal.bookId,
        type: TxnType.transfer,
        amountMinor: amountMinor,
        accountId: sign > 0 ? sourceAccountId : effectiveTarget,
        toAccountId: sign > 0 ? effectiveTarget : sourceAccountId,
        categoryId: savingsCategoryId,
        occurredAt: now,
        note: note,
        sourceModule: SourceModule.savings,
        relatedId: relatedId,
      );
    } else {
      // 无入款账户：存入记支出、取出记收入（钱离开 / 回到扣款账户）。
      await txnRepo.add(
        bookId: goal.bookId,
        type: sign > 0 ? TxnType.expense : TxnType.income,
        amountMinor: amountMinor,
        accountId: sourceAccountId,
        categoryId: savingsCategoryId,
        occurredAt: now,
        note: note,
        sourceModule: SourceModule.savings,
        relatedId: relatedId,
      );
    }
  }

  /// 取出账本流水（sourceModule=savings）：
  /// 有转出账户 → 完整转账（转出=储蓄账户 ⇄ 转入=取回账户）；
  /// 无转出账户 → 记收入（钱回到取回账户）。关联键 relatedId = '${goal.id}#withdraw'。
  Future<void> _recordWithdrawalTxn({
    required SavingsGoal goal,
    required int amountMinor,
    String? fromAccountId,
    required String toAccountId,
    required String relatedId,
  }) async {
    final TransactionRepository txnRepo =
        ref.read(transactionRepositoryProvider);
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final String note = '储蓄取出「${goal.name}」';
    // 系统分类「存款」：与存入流水同挂（isSystem=1，用户分类选择器隐藏）。
    final String savingsCategoryId = await CategoryRepository(
      ref.read(appDatabaseProvider),
    ).ensureNamed(
      bookId: goal.bookId,
      name: '存款',
      type: CategoryType.expense,
      iconKey: 'deposit_in',
      isSystem: true,
    );
    if (fromAccountId != null && fromAccountId != toAccountId) {
      // 完整转账：转出（储蓄账户）⇄ 转入（取回账户）。
      await txnRepo.add(
        bookId: goal.bookId,
        type: TxnType.transfer,
        amountMinor: amountMinor,
        accountId: fromAccountId,
        toAccountId: toAccountId,
        categoryId: savingsCategoryId,
        occurredAt: now,
        note: note,
        sourceModule: SourceModule.savings,
        relatedId: relatedId,
      );
    } else {
      // 无转出账户：钱回到取回账户（记收入）。
      await txnRepo.add(
        bookId: goal.bookId,
        type: TxnType.income,
        amountMinor: amountMinor,
        accountId: toAccountId,
        categoryId: savingsCategoryId,
        occurredAt: now,
        note: note,
        sourceModule: SourceModule.savings,
        relatedId: relatedId,
      );
    }
  }

  /// 取出：把计划已存金额提出到「取回账户」（默认全额，可改）。
  ///
  /// - 默认金额 = 已存全额（可改，不超过已存）；
  /// - 转出账户默认计划的入款账户（goal.accountId，可改）；
  /// - 转入账户（取回）必选；
  /// - 保存时 [SavingsRepository.withdraw] 扣减计划余额，并同步生成完整转账流水
  ///   （转出=储蓄账户 ⇄ 转入=取回账户），无转出账户则记收入。
  /// 关联键 relatedId = '${goal.id}#withdraw'，与逐期存入（goalId#dayIndex）区分。
  Future<void> _showWithdrawSheet(SavingsGoal goal) async {
    String amountText =
        Money.fromMinor(goal.currentMinor).format(showSymbol: false);
    String? fromAccountId = goal.accountId; // 转出 / 储蓄账户（默认计划入款账户）
    String? toAccountId; // 取回账户（必选）

    final bool? ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetCtx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setSt) {
          final ThemeData theme = Theme.of(ctx);

          // 保存前校验：金额 / 取回账户。
          Future<void> doWithdraw() async {
            final Money amt = Money.tryParse(amountText);
            if (amt.minor <= 0) {
              showAppToast(ctx, '金额必须大于 0');
              return;
            }
            if (amt.minor > goal.currentMinor) {
              showAppToast(ctx, '取出金额不能超过已存');
              return;
            }
            if (toAccountId == null) {
              showAppToast(ctx, '请选择取回账户');
              return;
            }
            Navigator.of(ctx).pop(true);
          }

          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.9,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // 标题行：左 ✕ 圆键 + 居中「取出」。
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 16, 0),
                    child: SizedBox(
                      height: 44,
                      child: Stack(
                        children: <Widget>[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: InkResponse(
                              onTap: () => Navigator.of(ctx).pop(false),
                              radius: 20,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.close,
                                  size: 17,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          const Center(
                            child: Text(
                              '取出',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    height: 1,
                    color: theme.dividerColor.withValues(alpha: 0.4),
                  ),
                  Flexible(
                    child: ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      children: <Widget>[
                        // 金额展示行（预填已存全额，工程内键盘可改）。
                        _sheetAmountDisplay(amountText),
                        const SizedBox(height: 14),
                        // 「账户」小节：转出·储蓄账户 → ¥转至 → 转入·取回账户。
                        _sheetSection(
                          title: '账户',
                          children: <Widget>[
                            Column(
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: _sheetAccountPill(
                                        sheetCtx: sheetCtx,
                                        title: '选择转出账户',
                                        accountId: fromAccountId,
                                        onChanged: (String? id) =>
                                            setSt(() => fromAccountId = id),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _sheetLabelPill(sheetCtx, '转出账户'),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Center(
                                  child: _sheetLabelPill(sheetCtx, '转至',
                                      icon: Icons.currency_yuan),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: _sheetAccountPill(
                                        sheetCtx: sheetCtx,
                                        title: '选择取回账户',
                                        accountId: toAccountId,
                                        onChanged: (String? id) =>
                                            setSt(() => toAccountId = id),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _sheetLabelPill(sheetCtx, '取回账户'),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 底部：取消 / 取出（渐变绿）。
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('取消'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: <Color>[
                                    AppPalette.sageMist,
                                    AppPalette.sageRibbon,
                                  ],
                                ),
                                borderRadius:
                                    BorderRadius.all(Radius.circular(28)),
                              ),
                              child: SizedBox(
                                height: 44,
                                child: TextButton(
                                  onPressed: doWithdraw,
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        theme.colorScheme.onPrimary,
                                  ),
                                  child: const Text('取出'),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 工程内数字键盘（金额输入，不弹系统键盘）。
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: SafeArea(
                      top: false,
                      child: AmountKeypad(
                        value: amountText,
                        onChanged: (String v) => setSt(() => amountText = v),
                        onBackspace: () => setSt(() {
                          if (amountText.isNotEmpty) {
                            amountText =
                                amountText.substring(0, amountText.length - 1);
                          }
                        }),
                        onSave: doWithdraw,
                        showSave: false,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (ok != true || !mounted) return;

    final Money amt = Money.tryParse(amountText);
    if (amt.minor <= 0) {
      showAppToast(context, '金额必须大于 0');
      return;
    }
    if (amt.minor > goal.currentMinor) {
      showAppToast(context, '取出金额不能超过已存');
      return;
    }
    if (toAccountId == null) {
      showAppToast(context, '请选择取回账户');
      return;
    }
    try {
      final SavingsRepository repo = ref.read(savingsRepositoryProvider);
      await repo.withdraw(goal.id, amt.minor);
      // 同步账本流水：转出=储蓄账户 ⇄ 转入=取回账户（完整转账）。
      await _recordWithdrawalTxn(
        goal: goal,
        amountMinor: amt.minor,
        fromAccountId: fromAccountId,
        toAccountId: toAccountId!,
        relatedId: '${goal.id}#withdraw',
      );
      if (mounted) {
        showAppToast(
          context,
          '已取出 ${amt.format()}',
        );
      }
    } on AppFailure catch (e) {
      if (mounted) showAppToast(context, e.message);
    }
  }

  /// 逐期存入「保存 / 更新 / 撤销」时，让账本流水与页面所选账户保持一致：
  /// - 未选扣款账户：若已有关联流水则软删（撤销对账）；
  /// - 选了扣款账户且尚无流水：按同一套逻辑新建（存入=转账/支出）；
  /// - 选了扣款账户且已有流水：更新金额与账户（保持 sourceModule=savings）。
  /// 关联键 relatedId = '${goal.id}#${dayIndex}'，每期唯一。
  Future<void> _syncPeriodTxn({
    required SavingsGoal goal,
    required int dayIndex,
    required String? sourceAccountId,
    required String? targetAccountId,
    required int amountMinor,
  }) async {
    final String relatedId = '${goal.id}#$dayIndex';
    final TransactionRepository txnRepo =
        ref.read(transactionRepositoryProvider);
    final Transaction? existing = await txnRepo.getByRelatedId(relatedId);
    if (sourceAccountId == null) {
      // 用户清空扣款账户：撤销账本侧记录（反向冲销余额）。
      if (existing != null) await txnRepo.removeByRelatedId(relatedId);
      return;
    }
    final String? effectiveTarget = targetAccountId ?? goal.accountId;
    final bool isTransfer =
        effectiveTarget != null && effectiveTarget != sourceAccountId;
    final TxnType type = isTransfer ? TxnType.transfer : TxnType.expense;
    final String note = '储蓄存入「${goal.name}」';
    if (existing == null) {
      await _recordSavingsTxn(
        goal: goal,
        sourceAccountId: sourceAccountId,
        amountMinor: amountMinor,
        sign: 1,
        targetAccountId: targetAccountId,
        relatedId: relatedId,
      );
    } else {
      // 已存在：更新金额与账户方向（余额由 updateTransaction 自动回滚+重算）。
      await txnRepo.updateTransaction(
        original: existing,
        type: type,
        amountMinor: amountMinor,
        accountId: sourceAccountId,
        toAccountId: isTransfer ? effectiveTarget : null,
        note: note,
      );
    }
  }
}

/// 月历（统一内嵌月历组件 [CalendarMonthView] + 存钱日期格钩子）：
///
/// - 大字「yyyy年M月」月份标题（左对齐），**左右滑动可切换月份**；
/// - 表头 周一…周日，周一起始；跨月补位日淡灰展示；
/// - 有排期的日期显示「应存金额」：未存入红字 / 已存入绿字 +
///   右上角绿色对勾角标，今天加深绿描边；
/// - 无排期日：共享组件默认渲染（未来/今天加粗深色，过去灰字）。
///
/// 公开组件：计划详情页「日历」卡与计划卡片日历键的底部弹窗共用。
class SavingsCalendarView extends StatefulWidget {
  const SavingsCalendarView({
    super.key,
    required this.deposits,
    required this.entries,
  });

  final List<SavingsDeposit> deposits;

  /// 排期（[SavingsSchedule.build] 产出），用于逐日应存金额与月份范围。
  final List<SavingsScheduleEntry> entries;

  @override
  State<SavingsCalendarView> createState() => _SavingsCalendarViewState();
}

class _SavingsCalendarViewState extends State<SavingsCalendarView> {
  @override
  Widget build(BuildContext context) =>
      _buildSharedCalendar(context, Theme.of(context));

  /// 渲染：统一内嵌月历 [CalendarMonthView]（大字「yyyy年M月」+ 横滑翻月
  /// + 周一起始表头 + 跨月补位），存钱的排期/台账日期格通过
  /// dayCellBuilder 钩子注入，其余日期走共享组件默认渲染。
  Widget _buildSharedCalendar(BuildContext context, ThemeData theme) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    // 排期月份范围（首月 → 尾月；无排期回退当前月，由共享组件兜底）。
    DateTime? first;
    DateTime? last;
    for (final SavingsScheduleEntry e in widget.entries) {
      final DateTime m = DateTime(e.date.year, e.date.month, 1);
      if (first == null || m.isBefore(first)) first = m;
      if (last == null || m.isAfter(last)) last = m;
    }

    // 台账按期数反查（第 N 期 ↔ 排期第 N 项），再按日聚合。
    final Map<int, SavingsDeposit> depositByIndex = <int, SavingsDeposit>{
      for (final SavingsDeposit d in widget.deposits) d.dayIndex: d,
    };
    // 日 → 应存金额（排期，同日多期累加）+ 已存入台账。
    final Map<DateTime, int> schedByDay = <DateTime, int>{};
    final Map<DateTime, SavingsDeposit> depByDay = <DateTime, SavingsDeposit>{};
    for (final SavingsScheduleEntry e in widget.entries) {
      final DateTime key = DateTime(e.date.year, e.date.month, e.date.day);
      if (e.amountMinor > 0) {
        schedByDay[key] = (schedByDay[key] ?? 0) + e.amountMinor;
      }
      final SavingsDeposit? d = depositByIndex[e.index];
      if (d != null) depByDay[key] = d;
    }

    return CalendarMonthView(
      firstMonth: first,
      lastMonth: last,
      initialMonth: DateTime(now.year, now.month, 1),
      dayCellBuilder: (BuildContext c, DateTime date, bool inMonth) => inMonth
          ? _savingsCell(
              theme, date, today, schedByDay[date], depByDay[date])
          : null, // 补位日走共享组件默认淡灰渲染
    );
  }

  /// 存钱日期格：有排期或台账 → 浅绿块 + 应存额（已存绿 / 未存红）+
  /// 已存对勾角标 + 今天加深绿描边；无排期日返回 null，
  /// 走 [CalendarMonthView] 默认渲染（未来/今天加粗、过去灰字）。
  Widget? _savingsCell(
    ThemeData theme,
    DateTime date,
    DateTime today,
    int? sched,
    SavingsDeposit? dep,
  ) {
    if (sched == null && dep == null) return null;
    final bool isToday = date == today;
    final Widget number = Text(
      '${date.day}',
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: sched != null || isToday ? FontWeight.w700 : FontWeight.w400,
        color: theme.colorScheme.onSurface,
      ),
    );

    final int? amountMinor = dep?.amountMinor ?? sched;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            color: AppPalette.softGreen,
            borderRadius: BorderRadius.circular(10),
            border: isToday
                ? Border.all(color: AppPalette.deepGreen, width: 1.4)
                : null,
          ),
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              number,
              if (amountMinor != null)
                Flexible(
                  child: Text(
                    Money.fromMinor(amountMinor).format(showSymbol: false),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: dep != null
                          ? AppPalette.deepGreen
                          : AppPalette.pickerRed,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (dep != null)
          Positioned(
            top: -3,
            right: -3,
            child: Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: AppPalette.deepGreen,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.surfaceContainer,
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.check,
                size: 9,
                color: AppPalette.white,
              ),
            ),
          ),
      ],
    );
  }
}

/// 逐期存入卡（参照小青账期卡）：
/// 行1：绿竖条 + 日期 + 右上角期数角标；
/// 行2：存:计划额（大字）；
/// 行3：累计:累计额；
/// 行4：右下角状态胶囊（未存入 / 已存入）。
class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.deposit,
    required this.onTap,
  });

  final SavingsScheduleEntry entry;
  final SavingsDeposit? deposit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool deposited = deposit != null;
    final bool anyAmount = entry.amountMinor <= 0;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 3,
                  height: 13,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        AppPalette.sageMist,
                        AppPalette.sageRibbon,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    DateFormat('MM月dd日').format(entry.date),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${entry.index}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Center(
              child: Text(
                anyAmount
                    ? '存:任意'
                    : '存:${Money.fromMinor(entry.amountMinor).format(showSymbol: false)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: deposited ? AppPalette.deepGreen : null,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Center(
              child: Text(
                '累计:${Money.fromMinor(entry.cumulativeMinor).format(showSymbol: false)}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: deposited
                      ? AppPalette.softGreen
                      : AppPalette.softGreen.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  deposited
                      ? DateFormat('MM月dd日').format(
                          DateTime.fromMillisecondsSinceEpoch(
                            deposit!.depositedAt,
                            isUtc: true,
                          ).toLocal(),
                        )
                      : '未存入',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.deepGreen,
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

/// 列表形态期卡（参照小青账列表视图截图）：
/// 左「第N期」绿胶囊 + 中列（红字「yyyy年MM月dd日 · 金额」+ 灰字「存:x · 累计:y」）
/// + 右侧状态胶囊（未存入 = 琥珀 / 已存入 = 浅绿显实际存入日期）+ 灰色箭头。
class _EntryListTile extends StatelessWidget {
  const _EntryListTile({
    required this.entry,
    required this.deposit,
    required this.onTap,
  });

  final SavingsScheduleEntry entry;
  final SavingsDeposit? deposit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool deposited = deposit != null;
    final String amountText = entry.amountMinor <= 0
        ? '任意'
        : Money.fromMinor(entry.amountMinor).format(showSymbol: false);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: <Widget>[
            // 期数胶囊。
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppPalette.softGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '第${entry.index}期',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.deepGreen,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // 中列：日期 · 金额（红字）+ 存/累计（灰字）。
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${DateFormat('yyyy年MM月dd日').format(entry.date)} · $amountText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.pickerRed,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '存:$amountText · 累计:'
                    '${Money.fromMinor(entry.cumulativeMinor).format(showSymbol: false)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 状态胶囊：未存入 = 琥珀；已存入 = 浅绿 + 实际存入日期。
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: deposited
                    ? AppPalette.softGreen
                    : AppPalette.amber.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                deposited
                    ? DateFormat('MM月dd日').format(
                        DateTime.fromMillisecondsSinceEpoch(
                          deposit!.depositedAt,
                          isUtc: true,
                        ).toLocal(),
                      )
                    : '未存入',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: deposited ? AppPalette.deepGreen : AppPalette.amber,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
