import 'package:drift/drift.dart';

import '../app_database.dart';

part 'pending_ops_dao.g.dart';

/// 待同步操作队列。
///
/// 为什么用队列而不是单条记录的 dirty 标记：
/// 一条记录在离线期间可能「先创建、再修改、最后删除」，
/// 单个标记无法表达这个时序；而队列中的多条操作可以按顺序重放。
@DriftAccessor(tables: <Type>[PendingOps])
class PendingOpsDao extends DatabaseAccessor<AppDatabase>
    with _$PendingOpsDaoMixin {
  PendingOpsDao(super.attachedDatabase);

  /// 按入队顺序取待同步操作
  Future<List<PendingOp>> pending({int limit = 200}) {
    return (select(pendingOps)
          ..orderBy([
            ($PendingOpsTable tbl) => OrderingTerm.asc(tbl.localSeq),
          ])
          ..limit(limit))
        .get();
  }

  Stream<int> watchCount() {
    final Expression<int> count = countAll();
    return (selectOnly(pendingOps)..addColumns(<Expression<Object>>[count]))
        .map((TypedResult row) => row.read(count) ?? 0)
        .watchSingle();
  }

  Future<void> enqueue(PendingOpsCompanion companion) {
    return into(pendingOps).insert(companion);
  }

  /// 同步成功后移除已确认的操作
  Future<int> removeBySeq(List<int> seqs) {
    return (delete(pendingOps)
          ..where(($PendingOpsTable tbl) => tbl.localSeq.isIn(seqs)))
        .go();
  }

  /// 失败后递增重试次数，供指数退避使用。
  ///
  /// 这里用参数化的 UPDATE ... + 1 而不是写入固定值，
  /// 否则会把计数重置为 1，导致永远无法判断该操作是否已反复失败。
  Future<void> incrementRetry(List<int> seqs) {
    return transaction(() async {
      for (final int seq in seqs) {
        await customStatement(
          'UPDATE pending_ops SET retry_count = retry_count + 1 '
          'WHERE local_seq = ?',
          <Object?>[seq],
        );
      }
    });
  }

  Future<int> clearAll() {
    return delete(pendingOps).go();
  }
}
