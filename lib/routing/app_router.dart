import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../database/app_database.dart';
import '../domain/enums.dart';
import '../features/accounts/presentation/account_ledger_page.dart';
import '../features/accounts/presentation/accounts_page.dart';
import '../features/accounts/presentation/add_account_page.dart';
import '../features/budget/presentation/budget_page.dart';
import '../features/categories/presentation/add_category_page.dart';
import '../features/categories/presentation/add_subcategory_page.dart';
import '../features/categories/presentation/category_manage_page.dart';
import '../features/categories/presentation/category_migrate_page.dart';
import '../features/categories/presentation/edit_category_page.dart';
import '../features/categories/presentation/edit_subcategory_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/installment/presentation/add_installment_page.dart';
import '../features/installment/presentation/installment_detail_page.dart';
import '../features/installment/presentation/installment_page.dart';
import '../features/inventory/presentation/inventory_page.dart';
import '../features/investment/presentation/investment_page.dart';
import '../features/ledger/presentation/category_transactions_page.dart';
import '../features/ledger/presentation/edit_transaction_page.dart';
import '../features/ledger/presentation/ledger_page.dart';
import '../features/lend/presentation/lend_page.dart';
import '../features/more/presentation/more_page.dart';
import '../features/record/presentation/record_sheet.dart';
import '../features/record/record_tab.dart';
import '../features/reimbursement/presentation/reimbursement_bill_picker_page.dart';
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
  static const String accountManage = '/accounts/manage';
  static const String accountAdd = '/accounts/add';
  static const String accountLedger = '/accounts/:id/transactions';
  static const String budget = '/budget';
  static const String report = '/report';

  static const String ledgerAdd = '/ledger/add';
  static const String ledgerEdit = '/ledger/edit/:id';

  static const String more = '/more';
  static const String categories = '/categories';
  static const String addCategory = '/categories/add';
  static const String editCategory = '/categories/edit';
  static const String addSubcategory = '/categories/add-subcategory';
  static const String editSubcategory = '/categories/edit-subcategory';
  static const String migrateCategory = '/categories/migrate';
  static const String categoryTransactions = '/categories/:id/transactions';
  static const String transfer = '/transfer';
  static const String lend = '/lend';
  static const String reimbursement = '/reimbursement';
  static const String reimbursementBillPicker = '/reimbursement/bill-picker';
  static const String savings = '/savings';
  static const String installment = '/installment';
  static const String installmentAdd = '/installment/add';
  static const String installmentDetail = '/installment/:planId';
  static const String investment = '/investment';
  static const String inventory = '/inventory';

  static const String settings = '/settings';
  static const String record = '/record';
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
        path: Routes.accountAdd,
        builder: (_, __) => const AddAccountPage(),
      ),
      GoRoute(
        path: Routes.accountManage,
        builder: (_, __) => const AccountsPage(),
      ),
      GoRoute(
        path: Routes.accountLedger,
        builder: (_, GoRouterState state) =>
            AccountLedgerPage(accountId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: Routes.categories,
        builder: (_, __) => const CategoryManagePage(),
      ),
      GoRoute(
        path: Routes.addCategory,
        builder: (_, GoRouterState state) => AddCategoryPage(
          type: state.extra! as CategoryType,
        ),
      ),
      GoRoute(
        path: Routes.editCategory,
        builder: (_, GoRouterState state) => EditCategoryPage(
          category: state.extra! as Category,
        ),
      ),
      GoRoute(
        path: Routes.addSubcategory,
        builder: (_, GoRouterState state) => AddSubcategoryPage(
          parent: state.extra! as Category,
        ),
      ),
      GoRoute(
        path: Routes.editSubcategory,
        builder: (_, GoRouterState state) {
          final (Category child, Category parent) =
              state.extra! as (Category, Category);
          return EditSubcategoryPage(child: child, parent: parent);
        },
      ),
      GoRoute(
        path: Routes.migrateCategory,
        builder: (_, GoRouterState state) => CategoryMigratePage(
          source: state.extra! as Category,
        ),
      ),
      GoRoute(
        path: Routes.categoryTransactions,
        builder: (_, GoRouterState state) => CategoryTransactionsPage(
          categoryId: state.pathParameters['id'] ?? '',
        ),
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
        path: Routes.reimbursementBillPicker,
        builder: (_, GoRouterState state) => ReimbursementBillPickerPage(
          args: state.extra! as ReimbBillPickerArgs,
        ),
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
        path: Routes.installmentAdd,
        builder: (_, __) => const AddInstallmentPage(),
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
      GoRoute(
        path: Routes.record,
        builder: (_, GoRouterState state) {
          final RecordTab initialTab = state.extra is RecordTab
              ? state.extra! as RecordTab
              : RecordTab.expense;
          return RecordSheet(initialTab: initialTab);
        },
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
      body: Center(child: Text('页面不存在：${state.uri}')),
    ),
  );
});
