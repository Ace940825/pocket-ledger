// 端到端自检：真实「分类排序」弹层顶部留边（2026-10-20 用户截图反馈
// 「顶部已经顶到头了」）。
//
// 经真实 CategoryManagePage 点右上角排序键打开 _showSortSheet，验证
// AppModalSheet 外壳上边距修复在真实调用链上生效：
//   1) 支出分段卡片顶部停在「状态栏 + md」，不顶到头；
//   2) 切到收入分段内容正确切换、卡片几何不变；
//   3) 明暗两版 golden（真页面 + 真弹层同框）。
// 状态栏高度用 FakeViewPadding 伪造（MediaQuery 会被 Scaffold AppBar 与
// 弹层路由 removePadding 双重剥掉，只有 View.of(context).padding 是真相）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/categories/presentation/category_manage_page.dart';
import 'package:pocket_ledger/features/categories/providers/categories_providers.dart';
import 'package:pocket_ledger/shared/widgets/line_icon_map.dart';
import 'package:pocket_ledger/shared/widgets/sheet_scaffold.dart';
import 'package:pocket_ledger/theme/app_theme.dart';

const Size kPhone = Size(418, 931); // 与用户反馈截图同尺寸
const double kStatusBar = 47; // 伪造的状态栏高度
const double kEdge = 12; // AppDimens.md
const double kExpectedTopGap = kStatusBar + kEdge;

Category _cat({
  required String id,
  required String name,
  required int sortOrder,
  required CategoryType type,
  String? iconKey,
  int? colorValue,
}) {
  return Category(
    updatedAt: 0,
    deleted: false,
    dirty: false,
    id: id,
    bookId: 'default',
    name: name,
    type: type,
    parentId: null,
    iconKey: iconKey,
    colorValue: colorValue,
    sortOrder: sortOrder,
    isArchived: false,
    isSystem: false,
  );
}

/// 12 个支出一级（与种子树同名同序）+ 5 个收入一级。
List<Category> _fakeCategories() => <Category>[
  _cat(id: 'e1', name: '餐饮', sortOrder: 0, type: CategoryType.expense, iconKey: 'restaurant', colorValue: 0xFFD96F52),
  _cat(id: 'e2', name: '购物', sortOrder: 1, type: CategoryType.expense, iconKey: 'shopping', colorValue: 0xFFCE6478),
  _cat(id: 'e3', name: '出行', sortOrder: 2, type: CategoryType.expense, iconKey: 'travel', colorValue: 0xFF5C82B8),
  _cat(id: 'e4', name: '居住', sortOrder: 3, type: CategoryType.expense, iconKey: 'home', colorValue: 0xFFA97742),
  _cat(id: 'e5', name: '娱乐', sortOrder: 4, type: CategoryType.expense, iconKey: 'entertainment', colorValue: 0xFF8F6FBF),
  _cat(id: 'e6', name: '宠物', sortOrder: 5, type: CategoryType.expense, iconKey: 'pet', colorValue: 0xFF7E9B6B),
  _cat(id: 'e7', name: '医疗健康', sortOrder: 6, type: CategoryType.expense, iconKey: 'medical', colorValue: 0xFF4A96A6),
  _cat(id: 'e8', name: '学习办公', sortOrder: 7, type: CategoryType.expense, iconKey: 'education', colorValue: 0xFF6470C2),
  _cat(id: 'e9', name: '人情往来', sortOrder: 8, type: CategoryType.expense, iconKey: 'social', colorValue: 0xFFCE6478),
  _cat(id: 'e10', name: '资金往来', sortOrder: 9, type: CategoryType.expense, iconKey: 'funds', colorValue: 0xFF3E8E8E),
  _cat(id: 'e11', name: '投资支出', sortOrder: 10, type: CategoryType.expense, iconKey: 'investment', colorValue: 0xFF4E93A6),
  _cat(id: 'e12', name: '其他', sortOrder: 11, type: CategoryType.expense, iconKey: 'other', colorValue: 0xFFC7A24A),
  _cat(id: 'i1', name: '职业收入', sortOrder: 0, type: CategoryType.income, iconKey: 'income_job', colorValue: 0xFF45936A),
  _cat(id: 'i2', name: '经营收入', sortOrder: 1, type: CategoryType.income, iconKey: 'income_business', colorValue: 0xFFD69E3C),
  _cat(id: 'i3', name: '投资收入', sortOrder: 2, type: CategoryType.income, iconKey: 'income_invest', colorValue: 0xFF4E93A6),
  _cat(id: 'i4', name: '资金往来', sortOrder: 3, type: CategoryType.income, iconKey: 'income_funds', colorValue: 0xFF8E8A7E),
  _cat(id: 'i5', name: '其他', sortOrder: 4, type: CategoryType.income, iconKey: 'other', colorValue: 0xFFC7A24A),
];

/// 悬浮卡视觉盒子：AppModalSheet 里那个带圆角的 [DecoratedBox]。
/// 注意：① 不能直接用 find.byType(Container)——margin 是最外层 Padding，
/// 量到的是「含边距的整块」（通屏通高），不是卡片本身；② 必须取 .first——
/// 弹层内每个 _SortTile 的 ClayIconTile 也带圆角 DecoratedBox，先序遍历
/// 中卡片外壳排在第一个。
Finder get _cardFinder => find
    .descendant(
      of: find.byType(AppModalSheet),
      matching: find.byWidgetPredicate(
        (Widget w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).borderRadius != null,
      ),
    )
    .first;

/// 只在弹层内找文本（页面背后的列表也有同名分类，避免误匹配）。
Finder _inSheet(String text) => find.descendant(
      of: find.byType(AppModalSheet),
      matching: find.text(text),
    );

Future<void> _openRealSortSheet(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
}) async {
  tester.view.padding = const FakeViewPadding(top: kStatusBar, bottom: 34);
  await tester.binding.setSurfaceSize(kPhone);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        allCategoriesProvider.overrideWith(
          (ref) => Stream<List<Category>>.value(_fakeCategories()),
        ),
      ],
      child: MaterialApp(
        theme: brightness == Brightness.light
            ? AppThemeData.light
            : AppThemeData.dark,
        home: const CategoryManagePage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // 右上角排序键（LineGlyph 包的手绘 ↓↑ 双箭头，非 Icon）打开弹层。
  await tester.tap(
    find.byWidgetPredicate(
      (Widget w) => w is LineGlyph && w.icon == Icons.sort_outlined,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('真「分类排序」弹层：卡片顶部停在「状态栏 + md」，不顶到头', (
    WidgetTester tester,
  ) async {
    await _openRealSortSheet(tester);
    final Rect card = tester.getRect(_cardFinder);
    debugPrint('真分类排序弹层 rect=$card（期望 top=$kExpectedTopGap）');
    expect(card.top, greaterThanOrEqualTo(kExpectedTopGap - 0.5));
    expect(card.top, lessThanOrEqualTo(kExpectedTopGap + 0.5));
    expect(card.left, greaterThanOrEqualTo(kEdge - 0.5));
    expect(card.right, lessThanOrEqualTo(kPhone.width - kEdge + 0.5));
    expect(card.bottom, lessThanOrEqualTo(kPhone.height - kEdge + 0.5));
    // 标题随卡片下移，不进入状态栏区。
    expect(
      tester.getTopLeft(find.text('分类排序')).dy,
      greaterThanOrEqualTo(kExpectedTopGap),
    );
    // 默认展示支出分段（一级在列）。
    expect(_inSheet('餐饮'), findsOneWidget);
    expect(_inSheet('职业收入'), findsNothing);
  });

  testWidgets('切到收入分类：内容切换、卡片几何不变', (
    WidgetTester tester,
  ) async {
    await _openRealSortSheet(tester);
    // 只点弹层内的「收入分类」分段键（页面背后也有同名 Tab）。
    await tester.tap(_inSheet('收入分类'));
    await tester.pumpAndSettle();
    // 内容切换到收入分段。
    expect(_inSheet('职业收入'), findsOneWidget);
    expect(_inSheet('餐饮'), findsNothing);
    // 卡片仍不顶头。
    final Rect card = tester.getRect(_cardFinder);
    debugPrint('收入分段弹层 rect=$card');
    expect(card.top, greaterThanOrEqualTo(kExpectedTopGap - 0.5));
    expect(card.top, lessThanOrEqualTo(kExpectedTopGap + 0.5));
  });

  testWidgets('golden：真「分类排序」弹层亮色', (
    WidgetTester tester,
  ) async {
    await _openRealSortSheet(tester, brightness: Brightness.light);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('category_sort_sheet_top_gap_light.png'),
    );
  });

  testWidgets('golden：真「分类排序」弹层暗色', (
    WidgetTester tester,
  ) async {
    await _openRealSortSheet(tester, brightness: Brightness.dark);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('category_sort_sheet_top_gap_dark.png'),
    );
  });
}
