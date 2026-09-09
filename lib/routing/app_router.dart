import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/accounts/presentation/accounts_page.dart';
import '../features/budget/presentation/budget_page.dart';
import '../features/categories/presentation/category_manage_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/installment/presentation/installment_detail_page.dart';
import '../features/installment/presentation/installment_page.dart';
import '../features/inventory/presentation/inventory_page.dart';
import '../features/investment/presentation/investment_page.dart';
import '../features/ledger/presentation/edit_transaction_page.dart';
import '../features/ledger/presentation/ledger_page.dart';
import '../features/lend/presentation/lend_page.dart';
import '../features/more/presentation/more_page.dart';
import '../features/reimbursement/presentation/reimbursement_page.dart';
import '../features/report/presentation/report_page.dart';
import '../features/savings/presentation/savings_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/shell/app_shell.dart';
import '../features/transfer/presentation/transfer_page.dart';

/// 路由路径常量集中管理，避免到处硬编码字符串。
abstract final class Routes {
  static const String home = '/home';
  static const String ledger = '/ledger';
  static const String accounts = '/accounts';
  static const String budget = '/budget';
  static const String report = '/report';

  static const String ledgerAdd = '/ledger/add';
  static const String ledgerEdit = '/ledger/edit/:id';

  static const String more = '/more';
  static const String categories = '/categories';
  static const String transfer = '/transfer';
  static const String lend = '/lend';
  static const String reimbursement = '/reimbursement';
  static const String savings = '/savings';
  static const String installment = '/installment';
  static const String installmentDetail = '/installment/:planId';
  static const String investment = '/investment';
  static const String inventory = '/inventory';

  static const String settings = '/settings';
}

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  return GoRouter(
    initialLocation: Routes.home,
    debugLogDiagnostics: false,
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) =>
            AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.home,
                builder: (_, __) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.ledger,
                builder: (_, __) => const LedgerPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.accounts,
                builder: (_, __) => const AccountsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.budget,
                builder: (_, __) => const BudgetPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.report,
                builder: (_, __) => const ReportPage(),
              ),
            ],
          ),
        ],
      ),

      // 全屏页面（不显示底部导航）
      GoRoute(
        path: Routes.ledgerAdd,
        builder: (_, __) => const EditTransactionPage(),
      ),
      GoRoute(
        path: Routes.ledgerEdit,
        builder: (_, GoRouterState state) => EditTransactionPage(
          transactionId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: Routes.more,
        builder: (_, __) => const MorePage(),
      ),
      GoRoute(
        path: Routes.categories,
        builder: (_, __) => const CategoryManagePage(),
      ),
      GoRoute(
        path: Routes.transfer,
        builder: (_, __) => const TransferPage(),
      ),
      GoRoute(
        path: Routes.lend,
        builder: (_, __) => const LendPage(),
      ),
      GoRoute(
        path: Routes.reimbursement,
        builder: (_, __) => const ReimbursementPage(),
      ),
      GoRoute(
        path: Routes.savings,
        builder: (_, __) => const SavingsPage(),
      ),
      GoRoute(
        path: Routes.installment,
        builder: (_, __) => const InstallmentPage(),
      ),
      GoRoute(
        path: Routes.installmentDetail,
        builder: (_, GoRouterState state) =>
            InstallmentDetailPage(planId: state.pathParameters['planId'] ?? ''),
      ),
      GoRoute(
        path: Routes.investment,
        builder: (_, __) => const InvestmentPage(),
      ),
      GoRoute(
        path: Routes.inventory,
        builder: (_, __) => const InventoryPage(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (_, __) => const SettingsPage(),
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
      body: Center(child: Text('页面不存在：${state.uri}')),
    ),
  );
});
