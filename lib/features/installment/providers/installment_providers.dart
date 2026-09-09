import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../data/installment_repository.dart';

final Provider<InstallmentRepository> installmentRepositoryProvider =
    Provider<InstallmentRepository>(
  (Ref ref) => InstallmentRepository(ref.watch(appDatabaseProvider)),
);

final StreamProvider<List<InstallmentPlan>> installmentPlansProvider =
    StreamProvider<List<InstallmentPlan>>(
  (Ref ref) => ref
      .watch(installmentRepositoryProvider)
      .watchPlans(ref.watch(currentBookIdProvider)),
);

/// 某个计划的每期明细。用 family 让详情页按 planId 独立订阅，
/// autoDispose 保证离开页面后立刻释放数据库监听。
final AutoDisposeStreamProviderFamily<List<InstallmentPeriod>, String>
    installmentPeriodsProvider =
    StreamProvider.autoDispose.family<List<InstallmentPeriod>, String>(
  (Ref ref, String planId) =>
      ref.watch(installmentRepositoryProvider).watchPeriods(planId),
);

/// 单个计划。详情页按 planId 订阅，而不是列表页把对象传过来 ——
/// 这样详情页可以被深链直接打开，刷新后也不会持有过期快照。
final AutoDisposeStreamProviderFamily<InstallmentPlan, String>
    installmentPlanProvider =
    StreamProvider.autoDispose.family<InstallmentPlan, String>(
  (Ref ref, String planId) => (ref
          .watch(appDatabaseProvider)
          .select(ref.watch(appDatabaseProvider).installmentPlans)
        ..where((InstallmentPlans t) => t.id.equals(planId)))
      .watchSingle(),
);
