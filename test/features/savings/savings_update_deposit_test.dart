import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/savings/data/savings_repository.dart';

/// 储蓄「修改已存入期卡金额」回归测试（真 SQLite，内存库）。
///
/// 用户报告：已存入期卡在「存钱」弹窗改金额保存（toast 已更新）后，
/// 计划进度「已存」与台账金额未同步。本测试复现 updateDeposit 全路径。
void main() {
  late AppDatabase db;
  late SavingsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = SavingsRepository(db);
  });

  tearDown(() => db.close());

  Future<String> insertGoal() async {
    const String id = 'goal-1';
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db.into(db.savingsGoals).insert(
          SavingsGoalsCompanion.insert(
            id: id,
            bookId: 'b1',
            name: '测试计划',
            targetMinor: 990000,
            mode: const Value<String?>('fixed'),
            updatedAt: now,
          ),
        );
    return id;
  }

  test('updateDeposit 更新台账金额并重算 currentMinor（已存入分支）', () async {
    final String goalId = await insertGoal();

    // 先存 3 期，每期 100 元 → currentMinor = 30000。
    for (int i = 1; i <= 3; i++) {
      await repo.depositDay(goalId: goalId, dayIndex: i, amountMinor: 10000);
    }
    SavingsGoal goal = await (db.select(db.savingsGoals)
            ..where((SavingsGoals t) => t.id.equals(goalId)))
        .getSingle();
    expect(goal.currentMinor, 30000);
    expect(goal.depositCount, 3);

    // 修改第 2 期：100 → 10,000 元。
    await repo.updateDeposit(
      goalId: goalId,
      dayIndex: 2,
      amountMinor: 1000000,
      note: '改金额',
    );

    // 台账行金额应更新。
    final SavingsDeposit row = await (db.select(db.savingsDeposits)
            ..where((SavingsDeposits t) =>
                t.goalId.equals(goalId) & t.dayIndex.equals(2)))
        .getSingle();
    expect(row.amountMinor, 1000000);

    // 目标累计应重算：30000 − 10000 + 1000000 = 1020000。
    goal = await (db.select(db.savingsGoals)
            ..where((SavingsGoals t) => t.id.equals(goalId)))
        .getSingle();
    expect(goal.currentMinor, 1020000);
    expect(goal.depositCount, 3, reason: '更新不应改变已执行次数');
  });

  test('updateDeposit 对未存入期走新建语义', () async {
    final String goalId = await insertGoal();
    await repo.updateDeposit(goalId: goalId, dayIndex: 1, amountMinor: 5000);
    final SavingsDeposit row = await (db.select(db.savingsDeposits)
            ..where((SavingsDeposits t) =>
                t.goalId.equals(goalId) & t.dayIndex.equals(1)))
        .getSingle();
    expect(row.amountMinor, 5000);
    final SavingsGoal goal = await (db.select(db.savingsGoals)
            ..where((SavingsGoals t) => t.id.equals(goalId)))
        .getSingle();
    expect(goal.currentMinor, 5000);
    expect(goal.depositCount, 1);
  });
}
