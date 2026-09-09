import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../database/sync_enqueue.dart';
import '../../../domain/enums.dart';

/// 储蓄目标仓储。
///
/// 设计取舍：目标进度 [SavingsGoals.currentMinor] 与真实账户余额**解耦**。
/// 因为「攒钱买相机」这类目标常常横跨多个账户，甚至只是心理账户，
/// 强行绑定余额会导致目标被账户间正常转账污染。存入 / 取出通过
/// [deposit] 显式记账，达标时自动置 isAchieved。
class SavingsRepository {
  const SavingsRepository(this._db);

  final AppDatabase _db;

  Stream<List<SavingsGoal>> watch(String bookId) {
    return (_db.select(_db.savingsGoals)
          ..where(
            (SavingsGoals t) =>
                t.bookId.equals(bookId) & t.deleted.equals(false),
          )
          ..orderBy(<OrderClauseGenerator<SavingsGoals>>[
            (SavingsGoals t) => OrderingTerm.asc(t.isAchieved),
            (SavingsGoals t) => OrderingTerm.asc(t.deadlineAt),
          ]))
        .watch();
  }

  Future<String> add({
    required String bookId,
    required String name,
    required int targetMinor,
    int currentMinor = 0,
    String? accountId,
    int? deadlineAt,
    String? note,
  }) {
    if (name.trim().isEmpty) throw const ValidationFailure('目标名称不能为空');
    if (targetMinor <= 0) throw const ValidationFailure('目标金额必须大于 0');

    final String id = const Uuid().v7();
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;

    return _db.transaction<String>(() async {
      await _db.into(_db.savingsGoals).insert(
            SavingsGoalsCompanion(
              id: Value<String>(id),
              bookId: Value<String>(bookId),
              name: Value<String>(name.trim()),
              targetMinor: Value<int>(targetMinor),
              currentMinor: Value<int>(currentMinor),
              accountId: Value<String?>(accountId),
              deadlineAt: Value<int?>(deadlineAt),
              note: Value<String?>(note),
              isAchieved: Value<bool>(currentMinor >= targetMinor),
              updatedAt: Value<int>(now),
              dirty: const Value<bool>(true),
            ),
          );
      await enqueueSyncOp(
        _db,
        table: 'savings_goals',
        recordId: id,
        opType: SyncOpType.insert,
        updatedAt: now,
        payload: <String, Object?>{
          'name': name.trim(),
          'targetMinor': targetMinor,
          'currentMinor': currentMinor,
          'accountId': accountId,
          'deadlineAt': deadlineAt,
          'note': note,
        },
      );
      return id;
    });
  }

  Future<void> update({
    required String id,
    required String name,
    required int targetMinor,
    required int currentMinor,
    String? accountId,
    int? deadlineAt,
    String? note,
  }) {
    if (name.trim().isEmpty) throw const ValidationFailure('目标名称不能为空');
    if (targetMinor <= 0) throw const ValidationFailure('目标金额必须大于 0');
    if (currentMinor < 0) throw const ValidationFailure('已存金额不能为负');

    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    return _db.transaction<void>(() async {
      await (_db.update(_db.savingsGoals)
            ..where((SavingsGoals t) => t.id.equals(id)))
          .write(
        SavingsGoalsCompanion(
          name: Value<String>(name.trim()),
          targetMinor: Value<int>(targetMinor),
          currentMinor: Value<int>(currentMinor),
          accountId: Value<String?>(accountId),
          deadlineAt: Value<int?>(deadlineAt),
          note: Value<String?>(note),
          isAchieved: Value<bool>(currentMinor >= targetMinor),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );
      await enqueueSyncOp(
        _db,
        table: 'savings_goals',
        recordId: id,
        opType: SyncOpType.update,
        updatedAt: now,
        payload: <String, Object?>{
          'name': name.trim(),
          'targetMinor': targetMinor,
          'currentMinor': currentMinor,
          'accountId': accountId,
          'deadlineAt': deadlineAt,
          'note': note,
        },
      );
    });
  }

  /// 存入（[deltaMinor] 为负则表示取出）。在事务内读改写，避免并发丢失更新。
  Future<void> deposit(String id, int deltaMinor) async {
    if (deltaMinor == 0) return;
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;

    await _db.transaction<void>(() async {
      final SavingsGoal? goal = await (_db.select(_db.savingsGoals)
            ..where((SavingsGoals t) => t.id.equals(id)))
          .getSingleOrNull();
      if (goal == null) throw const NotFoundFailure('储蓄目标不存在');

      final int next = goal.currentMinor + deltaMinor;
      if (next < 0) throw const ValidationFailure('取出金额超过已存金额');

      await (_db.update(_db.savingsGoals)
            ..where((SavingsGoals t) => t.id.equals(id)))
          .write(
        SavingsGoalsCompanion(
          currentMinor: Value<int>(next),
          isAchieved: Value<bool>(next >= goal.targetMinor),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );
      await enqueueSyncOp(
        _db,
        table: 'savings_goals',
        recordId: id,
        opType: SyncOpType.update,
        updatedAt: now,
        payload: <String, Object?>{'currentMinor': next},
      );
    });
  }

  Future<void> remove(String id) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.transaction<void>(() async {
      await (_db.update(_db.savingsGoals)
            ..where((SavingsGoals t) => t.id.equals(id)))
          .write(
        const SavingsGoalsCompanion(
          deleted: Value<bool>(true),
          dirty: Value<bool>(true),
        ),
      );
      await enqueueSyncOp(
        _db,
        table: 'savings_goals',
        recordId: id,
        opType: SyncOpType.delete,
        updatedAt: now,
      );
    });
  }
}
