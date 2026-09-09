import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
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
