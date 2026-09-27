import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../data/reimbursement_repository.dart';

final Provider<ReimbursementRepository> reimbursementRepositoryProvider =
    Provider<ReimbursementRepository>(
  (Ref ref) => ReimbursementRepository(ref.watch(appDatabaseProvider)),
);

final StreamProvider<List<Reimbursement>> reimbursementListProvider =
    StreamProvider<List<Reimbursement>>(
  (Ref ref) => ref
      .watch(reimbursementRepositoryProvider)
      .watch(ref.watch(currentBookIdProvider)),
);

/// 含已软删除记录的完整列表（「显示已删除账单」开关开启时使用）。
final StreamProvider<List<Reimbursement>>
    reimbursementListIncludingDeletedProvider =
    StreamProvider<List<Reimbursement>>(
  (Ref ref) => ref
      .watch(reimbursementRepositoryProvider)
      .watchAll(ref.watch(currentBookIdProvider)),
);

/// 「显示已删除账单」开关（仅本会话内有效，不持久化）。
///
/// 关闭（默认）= 只显示未删除的报销；开启 = 额外展示已软删除的记录（置灰 + 可恢复）。
final StateProvider<bool> showDeletedReimbursementsProvider =
    StateProvider<bool>((Ref ref) => false);

/// 待收回的报销合计（应收类）：仅「待报销」状态计入，已报销视为已收回。
/// 开启了「不计入收支」开关的不算。
final StreamProvider<int> reimbursementPendingProvider =
    StreamProvider<int>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref.watch(reimbursementRepositoryProvider).watch(bookId).map(
        (List<Reimbursement> records) => records
            .where((Reimbursement r) =>
                r.status == ReimbursementStatus.pending && !r.excludeFromStats)
            .fold<int>(0, (int sum, Reimbursement r) => sum + r.amountMinor),
      );
});

/// 按关联流水 id 查报销记录（流水详情弹窗「是否报销」开关同步用）。
final AutoDisposeStreamProviderFamily<Reimbursement?, String>
    reimbursementByTransactionIdProvider =
    StreamProvider.autoDispose.family<Reimbursement?, String>(
  (Ref ref, String transactionId) => ref
      .watch(reimbursementRepositoryProvider)
      .watchByTransactionId(transactionId),
);

/// 被某笔「报销收入」流水抵扣的报销记录（流水详情弹窗「关联账单」用）。
final AutoDisposeStreamProviderFamily<List<Reimbursement>, String>
    reimbursementsByIncomeIdProvider =
    StreamProvider.autoDispose.family<List<Reimbursement>, String>(
  (Ref ref, String incomeId) => ref
      .watch(reimbursementRepositoryProvider)
      .watchByIncomeTransactionId(incomeId),
);

/// 报销收入流水（报销页「报销收入」胶囊分组）：
/// 报销模块产生的收入（记一笔报销收入）+ 报销类型账户内的全部收入。
final AutoDisposeStreamProvider<List<Transaction>>
    reimbursementIncomesProvider =
    StreamProvider.autoDispose<List<Transaction>>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  final List<Account> accounts =
      ref.watch(accountsProvider).valueOrNull ?? const <Account>[];
  final List<String> reimbAccountIds = <String>[
    for (final Account a in accounts)
      if (a.type == AccountType.reimbursement) a.id,
  ];
  return ref.watch(transactionsDaoProvider).watchReimbursementIncomes(
        bookId: bookId,
        reimbAccountIds: reimbAccountIds,
      );
});
