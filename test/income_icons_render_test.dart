import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/shared/widgets/line_icons.dart';

/// 新默认收入分类树的全部 iconKey（一级 + 二级 + 其他）。
///
/// 与 [bootstrap] 的 _defaultIncomeCategories 保持一致：用于回归守护，
/// 断言每个 key 都能解析到手绘 LineIcon（不回退 Material）。
const List<String> incomeIconKeys = <String>[
  // 职业收入
  'income_job', 'salary', 'performance_bonus', 'allowance',
  // 经营收入
  'income_business', 'sole_proprietor',
  // 副业兼职
  'income_side', 'rider', 'video_income', 'parttime',
  // 投资收入
  'income_invest', 'securities', 'interest',
  // 资金往来
  'income_funds', 'refund_cashback', 'repayment', 'social_income',
  'tax_reimburse',
  // 保留一级
  'other',
];

void main() {
  testWidgets('income icons all resolve to hand-drawn LineIcon',
      (WidgetTester tester) async {
    // 断言：每个收入 iconKey 都有 LineIcon 映射（记一笔不再回退 Material）。
    for (final String k in incomeIconKeys) {
      expect(
        categoryLineKind(k),
        isNotNull,
        reason: 'iconKey "$k" 缺少 LineIcon 映射，会回退 Material',
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          backgroundColor: Colors.white,
          body: RepaintBoundary(
            key: const Key('incomeIconGrid'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              // 同 expense 测试：用不滚动的 Wrap，避免 golden 只截到视口内的行。
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final String k in incomeIconKeys)
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
      find.byKey(const Key('incomeIconGrid')),
      matchesGoldenFile('income_icons.png'),
    );
  });
}
