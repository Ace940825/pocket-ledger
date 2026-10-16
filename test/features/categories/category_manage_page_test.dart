import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/categories/presentation/category_manage_page.dart';
import 'package:pocket_ledger/features/categories/providers/categories_providers.dart';
import 'package:pocket_ledger/shared/widgets/action_group.dart';
import 'package:pocket_ledger/shared/widgets/action_row.dart';
import 'package:pocket_ledger/shared/widgets/clay_icon_tile.dart';
import 'package:pocket_ledger/shared/widgets/line_icons.dart';

/// 分类管理页整页渲染测试。
///
/// 锁定第 36 批结构：「添加子分类」瓦片与子分类瓦片共用同一套
/// [ClayIconTile] 黏土砖（此前添加瓦片是扁平奶油底 Container，
/// 与周围渐变砖割裂——用户截图反馈「跟其他图标风格不一致」）。
Category fakeCategory({
  required String id,
  required String name,
  String? parentId,
  int? colorValue = 0xFFE8A0A0,
  String? iconKey = 'food',
}) {
  return Category(
    updatedAt: 0,
    deleted: false,
    dirty: false,
    id: id,
    bookId: 'default',
    name: name,
    type: CategoryType.expense,
    parentId: parentId,
    iconKey: iconKey,
    colorValue: colorValue,
    sortOrder: 0,
    isArchived: false,
    isSystem: false,
  );
}
void main() {
  testWidgets('展开父分类：添加瓦片与子分类瓦片同为黏土砖', (
    WidgetTester tester,
  ) async {
    final List<Category> categories = <Category>[
      fakeCategory(id: 'p1', name: '餐饮'),
      fakeCategory(id: 'c1', name: '早餐', parentId: 'p1'),
      fakeCategory(id: 'c2', name: '午餐', parentId: 'p1'),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          allCategoriesProvider.overrideWith(
            (Ref ref) => Stream<List<Category>>.value(categories),
          ),
        ],
        child: const MaterialApp(home: CategoryManagePage()),
      ),
    );
    await tester.pumpAndSettle();

    // 展开「餐饮」父分类，露出子分类瓦片行与添加瓦片。
    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();

    expect(find.text('早餐'), findsOneWidget);
    expect(find.text('添加子分类'), findsOneWidget);

    // 添加瓦片的线稿加号必须身在 ClayIconTile 内（修复前是扁平 Container，
    // 加号图标找不到任何 ClayIconTile 祖先）。
    final Finder addIcon = find.byWidgetPredicate(
      (Widget w) => w is LineIcon && w.kind == LineIconKind.add,
    );
    expect(addIcon, findsOneWidget);
    expect(
      find.ancestor(of: addIcon, matching: find.byType(ClayIconTile)),
      findsOneWidget,
    );

    // 兄弟子分类瓦片（CategoryGlyph）同样身在 ClayIconTile 内——
    // 两者待遇一致是本测试的核心断言。
    final Finder childGlyph = find.byWidgetPredicate(
      (Widget w) => w is CategoryGlyph,
    );
    expect(childGlyph, findsNWidgets(3)); // 2 子分类 + 父分类行内各一
    for (int i = 0; i < 3; i++) {
      expect(
        find.ancestor(
          of: childGlyph.at(i),
          matching: find.byType(ClayIconTile),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('子分类操作弹层：ActionGroup 卡片菜单（第 37 批统一弹层风格）', (
    WidgetTester tester,
  ) async {
    final List<Category> categories = <Category>[
      fakeCategory(id: 'p1', name: '餐饮'),
      fakeCategory(id: 'c1', name: '早餐', parentId: 'p1'),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          allCategoriesProvider.overrideWith(
            (Ref ref) => Stream<List<Category>>.value(categories),
          ),
        ],
        child: const MaterialApp(home: CategoryManagePage()),
      ),
    );
    await tester.pumpAndSettle();

    // 展开父分类 → 点子分类瓦片 → 打开操作弹层。
    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('早餐'));
    await tester.pumpAndSettle();

    // 标题走 [showAppModalSheet] 统一标题栏（修复前是自绘标题栏：
    // 黏土砖 + 名称 + 关闭钮，与账户/报销页操作弹层割裂）。
    expect(find.text('分类操作'), findsOneWidget);

    // 子分类六项操作齐全。
    expect(find.text('编辑子分类'), findsOneWidget);
    expect(find.text('改为主分类'), findsOneWidget);
    expect(find.text('子分类排序'), findsOneWidget);
    expect(find.text('账单迁移'), findsOneWidget);
    expect(find.text('封存子分类'), findsOneWidget);
    expect(find.text('删除子分类'), findsOneWidget);

    // 条目必须身在 ActionGroup 卡片 + ActionRow 行内——
    // 3 组（编辑/改级/排序、数据、危险）× 子分类共 6 行。
    expect(find.byType(ActionGroup), findsNWidgets(3));
    expect(find.byType(ActionRow), findsNWidgets(6));
    final Finder editRow = find.text('编辑子分类');
    expect(
      find.ancestor(of: editRow, matching: find.byType(ActionRow)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: editRow, matching: find.byType(ActionGroup)),
      findsOneWidget,
    );

    // 删除行走 danger 语义（红底红字），非普通行。
    final Finder deleteRow = find.ancestor(
      of: find.text('删除子分类'),
      matching: find.byType(ActionRow),
    );
    expect(tester.widget<ActionRow>(deleteRow).danger, isTrue);
  });
}
