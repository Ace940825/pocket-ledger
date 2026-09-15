import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../data/record_template_repository.dart';

final Provider<RecordTemplateRepository> recordTemplateRepositoryProvider =
    Provider<RecordTemplateRepository>(
  (Ref ref) => RecordTemplateRepository(ref.watch(appDatabaseProvider)),
);

/// 当前账本下的记一笔模板列表（按创建时间倒序）。
final AutoDisposeStreamProvider<List<RecordTemplate>>
    recordTemplatesProvider = StreamProvider.autoDispose<List<RecordTemplate>>(
  (Ref ref) {
    final String bookId = ref.watch(currentBookIdProvider);
    return ref.watch(recordTemplateRepositoryProvider).watchAll(bookId);
  },
);
