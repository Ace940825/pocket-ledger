import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
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

/// 待收回的报销合计（应收类）：未收到钱 + 开启了「不计入收支」开关的不算。
final StreamProvider<int> reimbursementPendingProvider =
    StreamProvider<int>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref.watch(reimbursementRepositoryProvider).watch(bookId).map(
        (List<Reimbursement> records) => records
            .where((Reimbursement r) =>
                r.status != ReimbursementStatus.received && !r.excludeFromStats)
            .fold<int>(0, (int sum, Reimbursement r) => sum + r.amountMinor),
      );
});
