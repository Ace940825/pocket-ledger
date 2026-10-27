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

  /// 按入队顺序（localSeq 升序）取待同步操作。
  ///
  /// [exclude] 用于在「整轮排空」时跳过上一批已确认失败、反复推送无意义的 op，
  /// 避免失败 op 永远卡在队首导致死循环。
  Future<List<PendingOp>> pending({int limit = 200, Set<int>? exclude}) {
    final q = select(pendingOps)
      ..orderBy([
        (PendingOps tbl) => OrderingTerm.asc(tbl.localSeq),
      ]);
    if (exclude != null && exclude.isNotEmpty) {
      q.where((PendingOps tbl) => tbl.localSeq.isNotIn(exclude.toList()));
    }
    q.limit(limit);
    return q.get();
  }

  Stream<int> watchCount() {
    final Expression<int> count = countAll();
    return (selectOnly(pendingOps)..addColumns(<Expression<Object>>[count]))
        .map((TypedResult row) => row.read(count) ?? 0)
        .watchSingle();
  }

  /// 入队一条同步操作。
  ///
  /// **去重（修复「待同步累计统计异常」根因）**：同一 `(targetTable, recordId)`
  /// 在离线期间可能产生「创建→修改→删除」多条 op，旧逻辑每条都直接追加，导致
  /// 队列无限膨胀（实测出现 3 万+ 的虚高计数）。这里先删除该记录已有的旧 op，
  /// 再插入最新一条，使队列条数收敛到「有未同步变更的记录数」——既还原真实计数，
  /// 又保证「最新操作」永远在队首（清空账单产生的 delete 不会被埋在队尾推不到）。
  ///
  /// 同一记录的 op 可安全折叠为单条：推送时以本地当前行（`_buildPayload` 走
  /// `syncRowAsJson`）为权威数据源，upsert 既能建也能改；最新若是 delete 则按
  /// delete 推送，云端随之删除。事务包裹确保「删旧 + 插新」原子。
  Future<void> enqueue(PendingOpsCompanion companion) {
    return transaction(() async {
      final String? table =
          companion.targetTable.present ? companion.targetTable.value : null;
      final String? id =
          companion.recordId.present ? companion.recordId.value : null;
      if (table != null && id != null) {
        await (delete(pendingOps)
              ..where((PendingOps tbl) =>
                  tbl.targetTable.equals(table) & tbl.recordId.equals(id),))
            .go();
      }
      await into(pendingOps).insert(companion);
    });
  }

  /// 启动一次性折叠历史重复 op（修复旧库已累积的 3 万+ 队列）。
  ///
  /// 同一 `(target_table, record_id)` 只保留 `local_seq` 最大（最新）的一条，
  /// 其余删除。返回被清除的重复行数（用于启动日志）。幂等：清理后再次运行删除 0 条。
  /// 必须在 [clearSystemCategoryOps] 之后调用，以免被清掉的系统分类 op 又因
  /// 折叠逻辑被「保留最新」而复活。
  Future<int> dedupePendingOps() async {
    final List<QueryRow> groups = await customSelect(
      'SELECT target_table, record_id, MAX(local_seq) AS keep_seq '
      'FROM pending_ops GROUP BY target_table, record_id',
      readsFrom: {pendingOps},
    ).get();
    if (groups.isEmpty) return 0;
    final List<int> keep =
        groups.map((QueryRow r) => r.read<int>('keep_seq')).toList();
    final int deleted = await (delete(pendingOps)
          ..where((PendingOps tbl) => tbl.localSeq.isNotIn(keep)))
        .go();
    return deleted;
  }

  /// 按表统计待同步 op 数（供「云端同步数据（本地镜像）」面板按业务表展示分布）。
  Future<List<({String table, int count})>> pendingCountByTable() async {
    final List<QueryRow> rows = await customSelect(
      'SELECT target_table, COUNT(*) AS cnt '
      'FROM pending_ops GROUP BY target_table ORDER BY cnt DESC',
      readsFrom: {pendingOps},
    ).get();
    return rows
        .map((QueryRow r) {
          final String table = r.read<String>('target_table');
          final int count = r.read<int>('cnt');
          return (table: table, count: count);
        }).toList();
  }

  /// 同步成功后移除已确认的操作
  Future<int> removeBySeq(List<int> seqs) {
    return (delete(pendingOps)
          ..where((PendingOps tbl) => tbl.localSeq.isIn(seqs)))
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

  /// 清理历史遗留的系统分类同步 op（启动种子曾误把 11 个系统分类的 insert
  /// 入队，导致「无任何用户记录却显示 N 条待同步」）。系统分类为本地不变量、
  /// 永不参与同步；删除这些孤儿 op 使待同步计数归零。仅删 `is_system=1`
  /// 的分类相关 op，不影响任何用户数据。返回被清除的行数（用于启动日志）。
  Future<int> clearSystemCategoryOps() {
    return (delete(pendingOps)
          ..where(
            (PendingOps tbl) =>
                tbl.targetTable.equals('categories') &
                tbl.recordId.isInQuery(
                  attachedDatabase.selectOnly(attachedDatabase.categories)
                    ..addColumns([attachedDatabase.categories.id])
                    ..where(attachedDatabase.categories.isSystem.equals(true)),
                ),
          ))
        .go();
  }
}
