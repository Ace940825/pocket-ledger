import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:pocket_ledger/theme/app_dimens.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/line_icon_map.dart';
import '../../record/presentation/record_sheet.dart';
import '../../record/record_tab.dart';

/// 更多功能入口：收纳转账、报销、储蓄、分期、投资、物品与分类管理。
/// 借还不再设独立入口——借出/借入账户在账户页管理，点击进资产详情页，
/// 借还总览可从账户页「应收/应付」汇总行进入。
///
/// 「转账」不再走独立页面，与全站记账统一走「记一笔」（转账 Tab）——
/// 旧 /transfer 独立页已移除，这里以 [openRecordSheet] 直达。
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  static const List<
      ({
        String title,
        String description,
        IconData icon,
        String route,
        RecordTab? openRecordTab,
      })> _modules = <({
    String title,
    String description,
    IconData icon,
    String route,
    RecordTab? openRecordTab,
  })>[
    (
      title: '转账',
      description: '账户间资金划转',
      icon: Icons.swap_horiz,
      route: Routes.record,
      openRecordTab: RecordTab.transfer,
    ),
    (
      title: '退款 / 报销',
      description: '报销全流程跟踪',
      icon: Icons.receipt_outlined,
      route: Routes.reimbursement,
      openRecordTab: null,
    ),
    (
      title: '储蓄',
      description: '目标储蓄进度',
      icon: Icons.savings_outlined,
      route: Routes.savings,
      openRecordTab: null,
    ),
    (
      title: '分期',
      description: '分期计划与每期应还',
      icon: Icons.calendar_month_outlined,
      route: Routes.installment,
      openRecordTab: null,
    ),
    (
      title: '投资',
      description: '持仓与盈亏（涨红跌绿）',
      icon: Icons.trending_up,
      route: Routes.investment,
      openRecordTab: null,
    ),
    (
      title: '物品',
      description: '贵重物品与估值',
      icon: Icons.inventory_2_outlined,
      route: Routes.inventory,
      openRecordTab: null,
    ),
    (
      title: '分类管理',
      description: '自定义收支分类',
      icon: Icons.category_outlined,
      route: Routes.categories,
      openRecordTab: null,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('全部功能')),
      body: GridView.builder(
        padding: const EdgeInsets.all(AppDimens.lg),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: AppDimens.md,
          mainAxisSpacing: AppDimens.md,
          childAspectRatio: 1.5,
        ),
        itemCount: _modules.length,
        itemBuilder: (BuildContext context, int index) {
          final ({
            String title,
            String description,
            IconData icon,
            String route,
            RecordTab? openRecordTab,
          }) module = _modules[index];

          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              onTap: () {
                // 记账类入口（转账）统一进「记一笔」对应 Tab；
                // 其余仍是独立页面路由。
                final RecordTab? tab = module.openRecordTab;
                if (tab != null) {
                  openRecordSheet(context, initialTab: tab);
                } else {
                  context.push(module.route);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    LineGlyph(module.icon, size: 28),
                    const SizedBox(height: AppDimens.sm),
                    Text(
                      module.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      module.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
