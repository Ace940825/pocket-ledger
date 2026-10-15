import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/calendar_sheet.dart';
import '../../../shared/widgets/clay_icon_tile.dart';
import '../../../shared/widgets/hairline_card.dart';
import '../../../shared/widgets/line_icon_map.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/segmented_row.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimens.dart';
import '../../categories/providers/categories_providers.dart';
import '../data/shopping_list_store.dart';
import '../providers/budget_providers.dart';
import 'budget_category_page.dart';
import 'budget_setup_page.dart';
import 'widgets/recent_bills_card.dart';
import 'widgets/shopping_list_card.dart';

/// 全部账本（支出/收入预算分组卡的账本网格）。
final AutoDisposeStreamProvider<List<Book>> _booksProvider =
    StreamProvider.autoDispose<List<Book>>(
  (Ref ref) => ref.watch(booksDaoProvider).watchAll(),
);

/// 预算主页（2026-10-15 第 12 批迭代 + 第 25 批反馈修正）：
///
/// - 顶部月份头卡：黏土方糖币种图标 + 「N月预算」标题。
/// - AppBar 右上两枚黏土方糖按钮：¥ 进「设置月预算」、📅 选周期
///   （月预算模式选月份、年预算模式选年份）。
/// - 操作胶囊行：「购物清单 · N」（展开本地清单，点项可预填金额/备注快速记账）
///   与「预算设置」（进设置页）。
/// - 「近3日账单」区：近 3 日流水小列（按时间/按金额切换，点项进详情）。
/// - 「支出预算」「收入预算」两张分组卡：预算金额总和 + 双列**账本**
///   项卡网格（黏土方糖钱包 + 账本名 + 预算金额/未设置）；
///   点账本卡进该账本该方向的「预算分类」页（[BudgetCategoryPage]）。
/// - 底部悬浮「月预算 / 年预算」胶囊。
///
/// 口径：总预算（scope=overall）按支出口径计入；收入方向 = 收入分类
/// 预算合计（预算表无方向字段）。
///
/// 第 25 批反馈（2026-10-15）：指标切换卡 + 进度环移除（对标小青账
/// 该位不放概览环，预算设置入口收敛到 AppBar ¥ / 胶囊行）。
class BudgetPage extends ConsumerStatefulWidget {
  const BudgetPage({super.key});

  @override
  ConsumerState<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends ConsumerState<BudgetPage> {
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  bool _yearly = false;

  /// 购物清单区是否展开（操作胶囊切换）。
  bool _showShopping = false;

  /// 行是否落在当前视图周期（月视图：monthly+年+月；年视图：yearly+年）。
  bool _inPeriod(Budget b) => _yearly
      ? (b.period == BudgetPeriod.yearly && b.year == _year)
      : (b.period == BudgetPeriod.monthly &&
          b.year == _year &&
          b.periodIndex == _month);

  /// 某账本某方向的周期预算合计：支出=总预算行+支出分类预算；
  /// 收入=收入分类预算合计（表无方向字段，按分类类型归组）。
  int _dirBudgetMinor(
    List<Budget> bookBudgets,
    CategoryType direction,
    Map<String, Category> catById,
  ) {
    final List<Budget> period =
        bookBudgets.where(_inPeriod).toList(growable: false);
    if (direction == CategoryType.expense) {
      final int overall = period
          .where((Budget b) => b.scope == BudgetScope.overall)
          .fold<int>(0, (int s, Budget b) => s + b.amountMinor);
      final int byCat = period
          .where(
            (Budget b) =>
                b.scope == BudgetScope.category &&
                catById[b.categoryId]?.type == CategoryType.expense,
          )
          .fold<int>(0, (int s, Budget b) => s + b.amountMinor);
      return overall + byCat;
    }
    return period
        .where(
          (Budget b) =>
              b.scope == BudgetScope.category &&
              catById[b.categoryId]?.type == CategoryType.income,
        )
        .fold<int>(0, (int s, Budget b) => s + b.amountMinor);
  }

  /// 周期选择：月预算选月份、年预算选年份（全局日历组件）。
  Future<void> _pickPeriod() async {
    if (_yearly) {
      final CalendarSelection? sel = await CalendarSheet.show(
        context,
        mode: CalendarSheetMode.year,
        initialYear: _year,
      );
      if (sel is! CalendarYear || !mounted) return;
      setState(() => _year = sel.year);
    } else {
      final CalendarSelection? sel = await CalendarSheet.show(
        context,
        mode: CalendarSheetMode.month,
        initialMonth: DateTime(_year, _month),
      );
      if (sel is! CalendarMonth || !mounted) return;
      setState(() {
        _year = sel.year;
        _month = sel.month;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Book> books =
        ref.watch(_booksProvider).valueOrNull ?? const <Book>[];
    final List<Category> categories =
        ref.watch(allCategoriesProvider).valueOrNull ?? const <Category>[];
    final Map<String, Category> catById = <String, Category>{
      for (final Category c in categories) c.id: c,
    };
    // 账本列表兜底：无账本时至少展示当前账本一格。
    final String currentId = ref.watch(currentBookIdProvider);
    final List<Book> tiles = books.isEmpty
        ? <Book>[
            Book(
              id: currentId,
              name: ref.watch(currentBookProvider).valueOrNull?.name ?? '默认账本',
              currency: 'CNY',
              createdAt: 0,
              updatedAt: 0,
              deleted: false,
              dirty: false,
              sortOrder: 0,
            ),
          ]
        : books;

    final String periodLabel = _yearly ? '$_year年预算' : '$_month月预算';

    // 购物清单待购条数（胶囊徽标）。
    final int shoppingPending = ref
        .watch(shoppingListProvider)
        .where((ShoppingItem e) => !e.done)
        .length;

    return Scaffold(
      appBar: AppBar(
        actions: <Widget>[
          _ClayIconButton(
            tooltip: '设置预算',
            icon: Icons.currency_yuan_outlined,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BudgetSetupPage(
                  initialTargetMonth: DateTime(_year, _month),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          _ClayIconButton(
            tooltip: _yearly ? '选择年份' : '选择月份',
            icon: Icons.calendar_month_outlined,
            onPressed: _pickPeriod,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: <Widget>[
          ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 110),
            children: <Widget>[
              _HeaderCard(periodLabel: periodLabel),
              const SizedBox(height: 12),
              // 操作胶囊行：购物清单（展开/收起 + 待购数）/ 预算设置。
              Row(
                children: <Widget>[
                  _ActionPill(
                    icon: Icons.shopping_cart_outlined,
                    label: '购物清单',
                    badge: shoppingPending > 0 ? '$shoppingPending' : null,
                    active: _showShopping,
                    onTap: () => setState(() => _showShopping = !_showShopping),
                  ),
                  const SizedBox(width: 8),
                  _ActionPill(
                    icon: Icons.settings_outlined,
                    label: '预算设置',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BudgetSetupPage(
                          initialTargetMonth: DateTime(_year, _month),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_showShopping) ...<Widget>[
                const SizedBox(height: 12),
                const ShoppingListCard(),
              ],
              const SizedBox(height: 12),
              RecentBillsCard(bookId: currentId),
              const SizedBox(height: 12),
              _BookGroupCard(
                title: '支出预算',
                direction: CategoryType.expense,
                books: tiles,
                catById: catById,
                dirBudgetMinor: _dirBudgetMinor,
                onOpen: _openCategoryPage,
              ),
              const SizedBox(height: 12),
              _BookGroupCard(
                title: '收入预算',
                direction: CategoryType.income,
                books: tiles,
                catById: catById,
                dirBudgetMinor: _dirBudgetMinor,
                onOpen: _openCategoryPage,
              ),
            ],
          ),
          // 底部悬浮「月预算 / 年预算」胶囊（居中紧凑宽度）。
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: SizedBox(
                width: 232,
                child: SegmentedRow<bool>(
                  options: const <SegmentOption<bool>>[
                    SegmentOption<bool>(value: false, label: '月预算'),
                    SegmentOption<bool>(value: true, label: '年预算'),
                  ],
                  value: _yearly,
                  variant: SegmentVariant.sageGradient,
                  radius: 999,
                  itemRadius: 999,
                  trackHasShadow: true,
                  onChanged: (bool v) => setState(() => _yearly = v),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openCategoryPage(Book book, CategoryType direction) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BudgetCategoryPage(
          initialYear: _year,
          initialMonth: _month,
          initialYearly: _yearly,
          initialDirection: direction,
          bookId: book.id,
        ),
      ),
    );
  }
}

/// 黏土方糖操作按钮（AppBar 右上角，与内容黏土图标统一风格，2026-10-14 第 10 批）。
class _ClayIconButton extends StatelessWidget {
  const _ClayIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: ClayIconTile(
          size: 40,
          color: AppPalette.primary,
          child: LineGlyph(icon, size: 20, color: AppPalette.primary),
        ),
      ),
    );
  }
}

/// 操作胶囊（指标卡下方）：「购物清单 / 预算设置」。
///
/// [active] 时整粒转 sage 实底（用于购物清单展开态）；[badge] 为右上角
/// 待购计数（空则不渲染）。
class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color fg = active
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? AppPalette.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppDimens.radiusChip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            LineGlyph(icon, size: 15, color: fg),
            const SizedBox(width: 5),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (badge != null) ...<Widget>[
              const SizedBox(width: 4),
              Text(
                badge!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 月份头卡：黏土方糖 + 周期标题。
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.periodLabel});

  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return HairlineCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          const ClayIconTile(
            color: AppPalette.primary,
            child: LineGlyph(
              Icons.currency_yuan_outlined,
              size: 22,
              color: AppPalette.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              periodLabel,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 分组卡：「支出预算 / 收入预算」+ 预算金额总和 + 双列账本项卡网格。
class _BookGroupCard extends ConsumerWidget {
  const _BookGroupCard({
    required this.title,
    required this.direction,
    required this.books,
    required this.catById,
    required this.dirBudgetMinor,
    required this.onOpen,
  });

  final String title;
  final CategoryType direction;
  final List<Book> books;
  final Map<String, Category> catById;
  final int Function(List<Budget>, CategoryType, Map<String, Category>)
      dirBudgetMinor;
  final void Function(Book, CategoryType) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final int totalMinor = books.fold<int>(
      0,
      (int s, Book b) =>
          s +
          dirBudgetMinor(
            ref.watch(bookBudgetsProvider(b.id)).valueOrNull ??
                const <Budget>[],
            direction,
            catById,
          ),
    );

    return HairlineCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(title: title, padding: EdgeInsets.zero),
          const SizedBox(height: 10),
          Text(
            '预算金额总和',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            Money.fromMinor(totalMinor).format(),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: <Widget>[
              for (final Book b in books)
                _BookTile(
                  book: b,
                  amountMinor: dirBudgetMinor(
                    ref.watch(bookBudgetsProvider(b.id)).valueOrNull ??
                        const <Budget>[],
                    direction,
                    catById,
                  ),
                  onTap: () => onOpen(b, direction),
                  key: ValueKey<String>('$title/${b.id}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 账本项卡：黏土方糖钱包 + 账本名 / 「预算金额」label + 额度或「未设置」。
/// 点击进该账本该方向的预算分类页。
class _BookTile extends StatelessWidget {
  const _BookTile({
    required this.book,
    required this.amountMinor,
    required this.onTap,
    super.key,
  });

  final Book book;
  final int amountMinor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // 标题行：黏土方糖图标靠左，账本名靠右。
            Row(
              children: <Widget>[
                const ClayIconTile(
                  size: 32,
                  color: AppPalette.primary,
                  child: LineGlyph(
                    Icons.account_balance_wallet_outlined,
                    size: 17,
                    color: AppPalette.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    book.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 「预算金额」label + 金额左对齐上下堆叠。
            Text(
              '预算金额',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              amountMinor > 0 ? Money.fromMinor(amountMinor).format() : '未设置',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: amountMinor > 0
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
