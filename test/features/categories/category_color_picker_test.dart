import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/categories/presentation/add_category_page.dart';
import 'package:pocket_ledger/shared/widgets/color_chip.dart';
import 'package:pocket_ledger/shared/widgets/line_icons.dart';

/// 第 38 批颜色选择器重构测试：
/// - 「分类颜色」由 Wrap 两行改横向滚动一排（可左滑看全 24 色）；
/// - 色板 12 → 24（原 12 色 + 4 个 bootstrap 种子色 + 8 个新增色）；
/// - 圆点 40 → 32（ColorChip 外侧 6px padding 保 44px 触控区）。
void main() {
  testWidgets('分类颜色：横向一排可滑动 + 默认色 + 24 色', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AddCategoryPage(type: CategoryType.expense),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('分类颜色'), findsOneWidget);

    // 1 默认色 + 24 色板 = 25 枚圆点。
    expect(find.byType(ColorChip), findsNWidgets(25));

    // 圆点必须身在横向滚动的 Row 里（修复前是 Wrap，两行放不下还截断）。
    final Finder chip = find.byType(ColorChip).first;
    final Finder scroll = find.ancestor(
      of: chip,
      matching: find.byType(SingleChildScrollView),
    );
    expect(scroll, findsOneWidget);
    expect(
      tester.widget<SingleChildScrollView>(scroll).scrollDirection,
      Axis.horizontal,
    );
    expect(find.ancestor(of: chip, matching: find.byType(Row)), findsOneWidget);
    expect(find.byType(Wrap), findsNothing);

    // 默认色（isDefault）排在首位。
    final ColorChip first = tester.widget<ColorChip>(chip);
    expect(first.isDefault, isTrue);

    // 点第二枚（第一个真实颜色）→ 选中态出现对勾线稿。
    await tester.tap(find.byType(ColorChip).at(1));
    await tester.pumpAndSettle();
    final Finder check = find.byWidgetPredicate(
      (Widget w) => w is LineIcon && w.kind == LineIconKind.check,
    );
    expect(check, findsOneWidget);
  });
}
