import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/daos/tags_dao.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';

/// 某作用域下的「分组 → 标签」实时数据。
///
/// 通用作用域固定命中 bookId = ''（全部账本共享），账本独立命中当前账本。
/// 选择器弹窗与管理页共用此 provider，新增/删除/排序即时反映，无需手动刷新。
final tagsLibraryProvider =
    StreamProvider.autoDispose.family<List<TagGroupRow>, TagScope>(
  (Ref ref, TagScope scope) {
    final String bookId = ref.watch(currentBookIdProvider);
    final String effectiveBook = scope == TagScope.general ? '' : bookId;
    return ref.watch(tagsDaoProvider).watchGroups(scope, effectiveBook);
  },
);

/// 当前标签功能作用域（选择器弹窗内的通用/账本独立分段）。
///
/// 用 [StateProvider] 让弹窗与内部管理页共享同一份作用域选择，
/// 进入管理页时继承弹窗的选择，两边切换互相同步。
final StateProvider<TagScope> tagScopeProvider =
    StateProvider<TagScope>((Ref ref) => TagScope.general);
