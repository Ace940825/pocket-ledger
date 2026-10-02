import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/shared/widgets/line_icons.dart';

/// 新默认支出分类树的全部 iconKey（一级 + 二级 + 通讯/其他）。
///
/// 与 [bootstrap] 的 _defaultExpenseCategories 保持一致：用于回归守护，
/// 断言每个 key 都能解析到手绘 LineIcon（不回退 Material）。
const List<String> expenseIconKeys = <String>[
  // 餐饮
  'restaurant', 'breakfast', 'lunch', 'dinner', 'beverage', 'coffee',
  'milk_tea', 'juice', 'dim_sum', 'groupbuy', 'street_food',
  // 购物
  'shopping', 'produce', 'snack', 'shipping', 'apparel', 'beauty',
  'digital', 'consumable', 'tobacco', 'furniture', 'personal_care',
  // 出行
  'travel', 'car_care', 'transit', 'fuel', 'taxi_rental', 'intercity',
  // 居住
  'home', 'lodging', 'renovation', 'rent', 'utilities', 'telecom',
  // 娱乐
  'entertainment', 'fitness', 'offline_fun', 'digital_fun',
  'travel_vacation', 'hobby',
  // 医疗健康
  'medical', 'clinic', 'wellness', 'checkup', 'insurance',
  // 学习办公
  'education', 'knowledge', 'stationery',
  // 人情往来
  'social', 'red_packet', 'gift',
  // 宠物
  'pet', 'pet_food', 'pet_supply', 'pet_medical', 'pet_service',
  // 资金往来
  'funds', 'repay', 'lend', 'accrue',
  // 投资支出
  'investment', 'tax', 'finance', 'dividend', 'operations', 'capex',
  // 保留一级
  'phone', 'settings',
];

void main() {
  testWidgets('expense icons all resolve to hand-drawn LineIcon',
      (WidgetTester tester) async {
    // 断言：每个支出 iconKey 都有 LineIcon 映射（记一笔不再回退 Material）。
    for (final String k in expenseIconKeys) {
      expect(categoryLineKind(k), isNotNull,
          reason: 'iconKey "$k" 缺少 LineIcon 映射，会回退 Material');
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          backgroundColor: Colors.white,
          body: RepaintBoundary(
            key: const Key('expenseIconGrid'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              // 用不滚动的 Wrap：GridView 只会渲染视口内的行，
              // 会把后半段图标截在 golden 之外，目视自检不完整。
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final String k in expenseIconKeys)
                    LineIcon(
                      categoryLineKind(k)!,
                      size: 40,
                      color: const Color(0xFF2E4A26),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('expenseIconGrid')),
      matchesGoldenFile('expense_icons.png'),
    );
  });
}
