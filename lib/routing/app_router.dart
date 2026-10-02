import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../database/app_database.dart';
import '../domain/enums.dart';
import '../features/accounts/presentation/account_edit_page.dart';
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
import '../features/ledger/presentation/bill_manage_page.dart';
import '../features/ledger/presentation/bill_list_page.dart';
import '../features/ledger/presentation/bill_export_page.dart';
import '../features/ledger/presentation/bill_import_page.dart';
import '../features/ledger/presentation/bill_clean_page.dart';
import '../features/ledger/presentation/bill_screenshot_page.dart';
import '../features/ledger/data/bill_io.dart';
import '../features/record/presentation/record_template_page.dart';
import '../features/ledger/presentation/category_transactions_page.dart';
import '../features/ledger/presentation/ledger_page.dart';
import '../features/lend/presentation/lend_page.dart';
import '../features/more/presentation/more_page.dart';
import '../features/record/presentation/record_sheet.dart';
import '../features/record/record_tab.dart';
import '../features/reimbursement/presentation/reimbursement_bill_picker_page.dart';
import '../features/reimbursement/presentation/reimbursement_page.dart';
import '../features/report/presentation/report_page.dart';
import '../features/savings/presentation/savings_page.dart';
import '../features/settings/presentation/me_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/shell/app_shell.dart';
import '../features/transfer/presentation/transfer_page.dart';

/// 路由路径常量集中管理，避免到处硬编码字符串。
abstract final class Routes {
  static const String home = '/home';
  static const String ledger = '/ledger';
  static const String accounts = '/accounts';
  static const String me = '/me';
  static const String accountManage = '/accounts/manage';
  static const String accountAdd = '/accounts/add';
  static const String accountLedger = '/accounts/:id/transactions';
  static const String accountEdit = '/accounts/:id/edit';
  static const String budget = '/budget';
  static const String report = '/report';

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
  static const String templates = '/templates';
  static const String billManage = '/bill-manage';
  static const String billList = '/bill-list';
  static const String billExport = '/bill-export';
  static const String billImport = '/bill-import';
  static const String billClean = '/bill-clean';
  static const String screenshotImport = '/screenshot-import';

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
          // 「我的」Tab：小青账式个人中心（宫格入口 + 云同步/关于），
          // 原账户 Tab 已并入「我的 → 资产」。
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.me,
                builder: (_, __) => const MePage(),
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
      // 编辑流水：统一进「记一笔」页（编辑模式，回填原流水）。
      GoRoute(
        path: Routes.ledgerEdit,
        builder: (_, GoRouterState state) => RecordSheet(
          editTxnId: state.pathParameters['id'],
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
      // 资产总览页（原底部账户 Tab，现全屏路由，从「我的 → 资产」/首页进入）。
      GoRoute(
        path: Routes.accounts,
        builder: (_, __) => const AccountsPage(),
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
      // 编辑账户页（应收/应付账户左滑「编辑」进入）。
      GoRoute(
        path: Routes.accountEdit,
        builder: (_, GoRouterState state) => AccountEditPage(
          accountId: state.pathParameters['id'] ?? '',
        ),
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
      // 记一笔模板管理页（原从记一笔模板面板进入，现也有「我的」入口）。
      GoRoute(
        path: Routes.templates,
        builder: (_, __) => const RecordTemplatePage(),
      ),
      // 账单管理（我的 → 账单管理）：模板/导入导出/清理入口聚合页。
      GoRoute(
        path: Routes.billManage,
        builder: (_, __) => const BillManagePage(),
      ),
      // 账单列表（账单管理入口）：跨周期明细 + 选取排序规则弹窗。
      GoRoute(
        path: Routes.billList,
        builder: (_, __) => const BillListPage(),
      ),
      // 账单导出（账单管理入口）：CSV / JSON 导出到应用文件夹并可复制。
      GoRoute(
        path: Routes.billExport,
        builder: (_, __) => const BillExportPage(),
      ),
      // 账单导入（账单管理入口）：粘贴 / 读取 CSV / JSON 并归户写入；
      // 截图识别等外部来源可通过 extra 直接传入已解析草稿进入确认页。
      GoRoute(
        path: Routes.billImport,
        builder: (_, GoRouterState state) => BillImportPage(
          initialDraft: state.extra is ParseResult ? state.extra as ParseResult : null,
        ),
      ),
      // 从截图导入（账单管理入口）：选图 → 云端识别 → 跳确认页。
      GoRoute(
        path: Routes.screenshotImport,
        builder: (_, __) => const BillScreenshotPage(),
      ),
      // 账单清理（账单管理入口）：批量勾选删除，余额同步回退。
      GoRoute(
        path: Routes.billClean,
        builder: (_, __) => const BillCleanPage(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (_, __) => const SettingsPage(),
      ),
      // 预算：已移出底部导航，保留全屏入口（首页收支卡/设置页可进）。
      GoRoute(
        path: Routes.budget,
        builder: (_, __) => const BudgetPage(),
      ),
      GoRoute(
        path: Routes.record,
        builder: (_, GoRouterState state) {
          final Object? extra = state.extra;
          final RecordTab initialTab;
          final String? editLendId;
          final String? refundSourceId;
          if (extra is RecordSheetLaunchArgs) {
            initialTab = extra.initialTab;
            editLendId = extra.editLendId;
            refundSourceId = extra.refundSourceId;
          } else if (extra is RecordTab) {
            initialTab = extra;
            editLendId = null;
            refundSourceId = null;
          } else {
            initialTab = RecordTab.expense;
            editLendId = null;
            refundSourceId = null;
          }
          return RecordSheet(
            initialTab: initialTab,
            editLendId: editLendId,
            refundSourceId: refundSourceId,
          );
        },
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
      body: Center(child: Text('页面不存在：${state.uri}')),
    ),
  );
});
