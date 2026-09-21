import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../database/daos/transactions_dao.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../data/transaction_repository.dart';

final Provider<TransactionRepository> transactionRepositoryProvider =
    Provider<TransactionRepository>(
  (Ref ref) => TransactionRepository(ref.watch(appDatabaseProvider)),
);

/// 最近流水列表。直接监听本地 Drift 流，写入后 UI 立即刷新。
final AutoDisposeStreamProvider<List<Transaction>> recentTransactionsProvider =
    StreamProvider.autoDispose<List<Transaction>>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref.watch(transactionsDaoProvider).watchRecent(bookId: bookId);
});

/// 当前账本下全部支出流水，用于退款「选择原账单」等账单选择场景。
final AutoDisposeStreamProvider<List<Transaction>>
    bookExpenseTransactionsProvider =
    StreamProvider.autoDispose<List<Transaction>>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref.watch(transactionsDaoProvider).watchExpenses(bookId: bookId);
});

/// 指定账户的全部流水（含转账的转入侧）。给账户页「点开看流水」用。
final AutoDisposeStreamProviderFamily<List<Transaction>, String>
    accountTransactionsProvider = StreamProvider.autoDispose
        .family<List<Transaction>, String>((Ref ref, String accountId) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref
      .watch(transactionsDaoProvider)
      .watchByAccount(bookId: bookId, accountId: accountId);
});

/// 单条流水详情（编辑页使用）
final AutoDisposeStreamProviderFamily<Transaction?, String>
    transactionDetailProvider =
    StreamProvider.autoDispose.family<Transaction?, String>(
  (Ref ref, String id) => ref.watch(transactionsDaoProvider).watchById(id),
);

/// 指定原账单关联的全部退款流水。
final AutoDisposeStreamProviderFamily<List<Transaction>, String>
    refundsByRelatedIdProvider =
    StreamProvider.autoDispose.family<List<Transaction>, String>(
  (Ref ref, String relatedId) {
    final String bookId = ref.watch(currentBookIdProvider);
    return ref
        .watch(transactionsDaoProvider)
        .watchRefundsByRelatedId(relatedId, bookId: bookId);
  },
);

/// 当前查看的月份（本地时区）
final StateProvider<DateTime> selectedMonthProvider =
    StateProvider<DateTime>((Ref ref) {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month);
});

/// 选中月份的 UTC 毫秒区间 [startAt, endAt)
final Provider<({int startAt, int endAt})> monthRangeProvider =
    Provider<({int startAt, int endAt})>((Ref ref) {
  final DateTime month = ref.watch(selectedMonthProvider);
  final DateTime start = DateTime(month.year, month.month);
  final DateTime end = DateTime(month.year, month.month + 1);
  return (
    startAt: start.toUtc().millisecondsSinceEpoch,
    endAt: end.toUtc().millisecondsSinceEpoch,
  );
});

final AutoDisposeStreamProvider<int> monthIncomeProvider =
    StreamProvider.autoDispose<int>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  final ({int startAt, int endAt}) range = ref.watch(monthRangeProvider);
  return ref.watch(transactionsDaoProvider).watchTotalInRange(
        bookId: bookId,
        startAt: range.startAt,
        endAt: range.endAt,
        type: TxnType.income,
      );
});

final AutoDisposeStreamProvider<int> monthExpenseProvider =
    StreamProvider.autoDispose<int>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  final ({int startAt, int endAt}) range = ref.watch(monthRangeProvider);
  return ref.watch(transactionsDaoProvider).watchTotalInRange(
        bookId: bookId,
        startAt: range.startAt,
        endAt: range.endAt,
        type: TxnType.expense,
      );
});

/// 本月支出分类聚合，用于报表饼图与首页排行
final AutoDisposeStreamProvider<List<CategoryTotal>>
    monthCategoryTotalsProvider =
    StreamProvider.autoDispose<List<CategoryTotal>>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  final ({int startAt, int endAt}) range = ref.watch(monthRangeProvider);
  return ref.watch(transactionsDaoProvider).watchCategoryTotals(
        bookId: bookId,
        startAt: range.startAt,
        endAt: range.endAt,
        type: TxnType.expense,
      );
});
