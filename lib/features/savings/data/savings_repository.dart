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

  /// 「计划」Tab：未归档目标（达标优先，其次按截止日）。
  Stream<List<SavingsGoal>> watch(String bookId) {
    return (_db.select(_db.savingsGoals)
          ..where(
            (SavingsGoals t) =>
                t.bookId.equals(bookId) &
                t.deleted.equals(false) &
                t.isArchived.equals(false),
          )
          ..orderBy(<OrderClauseGenerator<SavingsGoals>>[
            (SavingsGoals t) => OrderingTerm.asc(t.isAchieved),
            (SavingsGoals t) => OrderingTerm.asc(t.deadlineAt),
          ]))
        .watch();
  }

  /// 「归档」Tab：已归档（停止）的目标。
  Stream<List<SavingsGoal>> watchArchived(String bookId) {
    return (_db.select(_db.savingsGoals)
          ..where(
            (SavingsGoals t) =>
                t.bookId.equals(bookId) &
                t.deleted.equals(false) &
                t.isArchived.equals(true),
          )
          ..orderBy(<OrderClauseGenerator<SavingsGoals>>[
            (SavingsGoals t) => OrderingTerm.desc(t.updatedAt),
          ]))
        .watch();
  }

  /// 归档 / 恢复目标（储蓄页「计划 ↔ 归档」双 Tab 联动）。
  Future<void> setArchived(String id, {required bool archived}) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.transaction<void>(() async {
      await (_db.update(_db.savingsGoals)
            ..where((SavingsGoals t) => t.id.equals(id)))
          .write(
        SavingsGoalsCompanion(
          isArchived: Value<bool>(archived),
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
        payload: <String, Object?>{'isArchived': archived},
      );
    });
  }

  Future<String> add({
    required String bookId,
    required String name,
    required int targetMinor,
    int currentMinor = 0,
    String? accountId,
    String? sourceAccountId,
    int? deadlineAt,
    String? note,
    String? mode,
    String? repeatCycle,
    String? endNote,
    int? startedAt,
    // 弹性存钱法递增参数（非弹性模式传 null，由仓储落库默认值 / 兼容回退）。
    int? elasticMode,
    int? elasticBaseMinor,
    int? elasticStepMinor,
    int? elasticPercentHundred,
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
              sourceAccountId: Value<String?>(sourceAccountId),
              deadlineAt: Value<int?>(deadlineAt),
              note: Value<String?>(note),
              mode: Value<String?>(mode),
              repeatCycle: Value<String?>(repeatCycle),
              endNote: Value<String?>(endNote),
              startedAt: Value<int?>(startedAt),
              // 仅「有结束期（endNote!=null）或灵活模式」的有限计划达标才置已完成；
              // 不结束（定额/弹性，endNote==null）为开放式计划，永不自动达成。
              isAchieved: Value<bool>((endNote != null || mode == 'flexible') &&
                  currentMinor >= targetMinor),
              updatedAt: Value<int>(now),
              dirty: const Value<bool>(true),
              // 弹性递增参数：mode 非 null 走递增；null 落默认(金额模式)。
              elasticMode: Value<int>(elasticMode ?? 1),
              elasticBaseMinor: Value<int?>(elasticBaseMinor),
              elasticStepMinor: Value<int?>(elasticStepMinor),
              elasticPercentHundred: Value<int?>(elasticPercentHundred),
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
          'sourceAccountId': sourceAccountId,
          'deadlineAt': deadlineAt,
          'note': note,
          'mode': mode,
          'repeatCycle': repeatCycle,
          'endNote': endNote,
          'elasticMode': elasticMode,
          'elasticBaseMinor': elasticBaseMinor,
          'elasticStepMinor': elasticStepMinor,
          'elasticPercentHundred': elasticPercentHundred,
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
    String? sourceAccountId,
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
          sourceAccountId: Value<String?>(sourceAccountId),
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
          'sourceAccountId': sourceAccountId,
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

      // 已执行次数：存入 +1、取出 -1（下限 0，不计取消）。
      final int nextCount =
          (goal.depositCount + (deltaMinor > 0 ? 1 : -1)).clamp(0, 1 << 30);

      await (_db.update(_db.savingsGoals)
            ..where((SavingsGoals t) => t.id.equals(id)))
          .write(
        SavingsGoalsCompanion(
          currentMinor: Value<int>(next),
          depositCount: Value<int>(nextCount),
          isAchieved: Value<bool>(
              (goal.endNote != null || goal.mode == 'flexible') &&
                  next >= goal.targetMinor),
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
          'currentMinor': next,
          'depositCount': nextCount
        },
      );
    });
  }

  /// 到期取出：一次性把计划里已存金额取出 [amountMinor]（不超过 currentMinor）。
  ///
  /// 与 [deposit] 的逐期语义不同，这里是整笔取出：余额清零 / 扣减，
  /// 全部取出时次数归零；账本流水由调用方（详情页）同步生成。
  Future<void> withdraw(String id, int amountMinor) async {
    if (amountMinor <= 0) return;
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;

    await _db.transaction<void>(() async {
      final SavingsGoal? goal = await (_db.select(_db.savingsGoals)
            ..where((SavingsGoals t) => t.id.equals(id)))
          .getSingleOrNull();
      if (goal == null) throw const NotFoundFailure('储蓄目标不存在');

      final int next = (goal.currentMinor - amountMinor).clamp(0, 1 << 40);
      // 全部取出 → 次数归零；部分取出 → 次数减一（下限 0）。
      final int nextCount =
          next == 0 ? 0 : (goal.depositCount - 1).clamp(0, 1 << 30);

      await (_db.update(_db.savingsGoals)
            ..where((SavingsGoals t) => t.id.equals(id)))
          .write(
        SavingsGoalsCompanion(
          currentMinor: Value<int>(next),
          depositCount: Value<int>(nextCount),
          isAchieved: Value<bool>(
              (goal.endNote != null || goal.mode == 'flexible') &&
                  next >= goal.targetMinor),
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
          'currentMinor': next,
          'depositCount': nextCount,
        },
      );
    });
  }

  /// 逐期存入台账：某计划的全部「第 N 期已存入」记录（按期数升序）。
  Stream<List<SavingsDeposit>> watchDeposits(String goalId) {
    return (_db.select(_db.savingsDeposits)
          ..where((SavingsDeposits t) => t.goalId.equals(goalId))
          ..orderBy(<OrderClauseGenerator<SavingsDeposits>>[
            (SavingsDeposits t) => OrderingTerm.asc(t.dayIndex),
          ]))
        .watch();
  }

  /// 标记「第 [dayIndex] 期已存入」：落台账一行 + 目标累计增加
  /// [amountMinor]（可与计划额不同）+ 已执行次数 +1。同一天重复存入拦截。
  Future<void> depositDay({
    required String goalId,
    required int dayIndex,
    required int amountMinor,
    String? note,
  }) async {
    if (amountMinor <= 0) throw const ValidationFailure('金额必须大于 0');
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;

    await _db.transaction<void>(() async {
      final SavingsGoal? goal = await (_db.select(_db.savingsGoals)
            ..where((SavingsGoals t) => t.id.equals(goalId)))
          .getSingleOrNull();
      if (goal == null) throw const NotFoundFailure('储蓄目标不存在');

      final SavingsDeposit? dup = await (_db.select(_db.savingsDeposits)
            ..where(
              (SavingsDeposits t) =>
                  t.goalId.equals(goalId) & t.dayIndex.equals(dayIndex),
            ))
          .getSingleOrNull();
      if (dup != null) throw const ValidationFailure('该期已存入');

      final String id = const Uuid().v7();
      await _db.into(_db.savingsDeposits).insert(
            SavingsDepositsCompanion(
              id: Value<String>(id),
              bookId: Value<String>(goal.bookId),
              goalId: Value<String>(goalId),
              dayIndex: Value<int>(dayIndex),
              amountMinor: Value<int>(amountMinor),
              depositedAt: Value<int>(now),
              note: Value<String?>(note),
            ),
          );

      final int next = goal.currentMinor + amountMinor;
      await (_db.update(_db.savingsGoals)
            ..where((SavingsGoals t) => t.id.equals(goalId)))
          .write(
        SavingsGoalsCompanion(
          currentMinor: Value<int>(next),
          depositCount: Value<int>((goal.depositCount + 1).clamp(0, 1 << 30)),
          isAchieved: Value<bool>(
              (goal.endNote != null || goal.mode == 'flexible') &&
                  next >= goal.targetMinor),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );
      await enqueueSyncOp(
        _db,
        table: 'savings_goals',
        recordId: goalId,
        opType: SyncOpType.update,
        updatedAt: now,
        payload: <String, Object?>{'currentMinor': next},
      );
    });
  }

  /// 更新「第 [dayIndex] 期存入」的金额与备注，并重算目标累计。
  /// 若该期尚未存入则退回新建语义（depositDay）。
  Future<void> updateDeposit({
    required String goalId,
    required int dayIndex,
    required int amountMinor,
    String? note,
  }) async {
    if (amountMinor <= 0) throw const ValidationFailure('金额必须大于 0');
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;

    await _db.transaction<void>(() async {
      final SavingsGoal? goal = await (_db.select(_db.savingsGoals)
            ..where((SavingsGoals t) => t.id.equals(goalId)))
          .getSingleOrNull();
      if (goal == null) throw const NotFoundFailure('储蓄目标不存在');

      final SavingsDeposit? row = await (_db.select(_db.savingsDeposits)
            ..where((SavingsDeposits t) =>
                t.goalId.equals(goalId) & t.dayIndex.equals(dayIndex)))
          .getSingleOrNull();

      if (row == null) {
        // 尚未存入 → 当作新建处理。
        final String id = const Uuid().v7();
        await _db.into(_db.savingsDeposits).insert(
              SavingsDepositsCompanion(
                id: Value<String>(id),
                bookId: Value<String>(goal.bookId),
                goalId: Value<String>(goalId),
                dayIndex: Value<int>(dayIndex),
                amountMinor: Value<int>(amountMinor),
                depositedAt: Value<int>(now),
                note: Value<String?>(note),
              ),
            );
        final int next = goal.currentMinor + amountMinor;
        await (_db.update(_db.savingsGoals)
              ..where((SavingsGoals t) => t.id.equals(goalId)))
            .write(
          SavingsGoalsCompanion(
            currentMinor: Value<int>(next),
            depositCount: Value<int>((goal.depositCount + 1).clamp(0, 1 << 30)),
            isAchieved: Value<bool>(
                (goal.endNote != null || goal.mode == 'flexible') &&
                    next >= goal.targetMinor),
            updatedAt: Value<int>(now),
            dirty: const Value<bool>(true),
          ),
        );
        await enqueueSyncOp(
          _db,
          table: 'savings_goals',
          recordId: goalId,
          opType: SyncOpType.update,
          updatedAt: now,
          payload: <String, Object?>{'currentMinor': next},
        );
        return;
      }

      // 已存入：更新金额与备注（保留原始存入时间），重算累计。
      await (_db.update(_db.savingsDeposits)
            ..where((SavingsDeposits t) => t.id.equals(row.id)))
          .write(
        SavingsDepositsCompanion(
          amountMinor: Value<int>(amountMinor),
          note: Value<String?>(note),
        ),
      );

      final int next =
          (goal.currentMinor - row.amountMinor + amountMinor).clamp(0, 1 << 40);
      await (_db.update(_db.savingsGoals)
            ..where((SavingsGoals t) => t.id.equals(goalId)))
          .write(
        SavingsGoalsCompanion(
          currentMinor: Value<int>(next),
          isAchieved: Value<bool>(
              (goal.endNote != null || goal.mode == 'flexible') &&
                  next >= goal.targetMinor),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );
      await enqueueSyncOp(
        _db,
        table: 'savings_goals',
        recordId: goalId,
        opType: SyncOpType.update,
        updatedAt: now,
        payload: <String, Object?>{'currentMinor': next},
      );
    });
  }

  /// 撤销「第 [dayIndex] 期存入」：删台账行 + 目标累计扣回 + 次数 -1。
  Future<void> cancelDay({
    required String goalId,
    required int dayIndex,
  }) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.transaction<void>(() async {
      final SavingsDeposit? row = await (_db.select(_db.savingsDeposits)
            ..where(
              (SavingsDeposits t) =>
                  t.goalId.equals(goalId) & t.dayIndex.equals(dayIndex),
            ))
          .getSingleOrNull();
      if (row == null) return;

      await (_db.delete(_db.savingsDeposits)
            ..where((SavingsDeposits t) => t.id.equals(row.id)))
          .go();

      final SavingsGoal? goal = await (_db.select(_db.savingsGoals)
            ..where((SavingsGoals t) => t.id.equals(goalId)))
          .getSingleOrNull();
      if (goal == null) return;

      final int next = (goal.currentMinor - row.amountMinor).clamp(0, 1 << 40);
      await (_db.update(_db.savingsGoals)
            ..where((SavingsGoals t) => t.id.equals(goalId)))
          .write(
        SavingsGoalsCompanion(
          currentMinor: Value<int>(next),
          depositCount: Value<int>((goal.depositCount - 1).clamp(0, 1 << 30)),
          isAchieved: Value<bool>(
              (goal.endNote != null || goal.mode == 'flexible') &&
                  next >= goal.targetMinor),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );
      await enqueueSyncOp(
        _db,
        table: 'savings_goals',
        recordId: goalId,
        opType: SyncOpType.update,
        updatedAt: now,
        payload: <String, Object?>{'currentMinor': next},
      );
    });
  }

  Future<void> remove(String id) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.transaction<void>(() async {
      // 逐期台账随计划一起清理（本地表，物理删除）。
      await (_db.delete(_db.savingsDeposits)
            ..where((SavingsDeposits t) => t.goalId.equals(id)))
          .go();
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
