import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_dimens.dart';
import '../../../routing/app_router.dart';

/// 更多功能入口：收纳转账、借还、报销、储蓄、分期、投资、物品七大模块。
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  static const List<({
    String title,
    String description,
    IconData icon,
    String route,
  })> _modules = <({
    String title,
    String description,
    IconData icon,
    String route,
  })>[
    (
      title: '转账',
      description: '账户间资金划转',
      icon: Icons.swap_horiz,
      route: Routes.transfer,
    ),
    (
      title: '借还',
      description: '借出借入与还款',
      icon: Icons.handshake_outlined,
      route: Routes.lend,
    ),
    (
      title: '退款 / 报销',
      description: '报销全流程跟踪',
      icon: Icons.receipt_outlined,
      route: Routes.reimbursement,
    ),
    (
      title: '储蓄',
      description: '目标储蓄进度',
      icon: Icons.savings_outlined,
      route: Routes.savings,
    ),
    (
      title: '分期',
      description: '分期计划与每期应还',
      icon: Icons.calendar_month_outlined,
      route: Routes.installment,
    ),
    (
      title: '投资',
      description: '持仓与盈亏（涨红跌绿）',
      icon: Icons.trending_up,
      route: Routes.investment,
    ),
    (
      title: '物品',
      description: '贵重物品与估值',
      icon: Icons.inventory_2_outlined,
      route: Routes.inventory,
    ),
    (
      title: '分类管理',
      description: '自定义收支分类',
      icon: Icons.category_outlined,
      route: Routes.categories,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('全部功能')),
      body: GridView.builder(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: AppDimens.spaceMd,
          mainAxisSpacing: AppDimens.spaceMd,
          childAspectRatio: 1.5,
        ),
        itemCount: _modules.length,
        itemBuilder: (BuildContext context, int index) {
          final ({
            String title,
            String description,
            IconData icon,
            String route,
          }) module = _modules[index];

          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              onTap: () => context.push(module.route),
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.spaceLg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(module.icon, size: 28),
                    const SizedBox(height: AppDimens.spaceSm),
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
