import 'package:drift/drift.dart';

import '../../../database/app_database.dart';
import '../domain/savings_rolling_plan.dart';

/// 36 期滚存计划仓储（原生 SQL，不参与 drift 代码生成）。
///
/// 滚存计划表 [AppDatabase._ensureRollingPlansTable] 以原生 SQL 建表，
/// 故本仓储也用 `customSelect` / `customStatement` 读写，不依赖 `.g.dart`
/// 访问器。与 [SavingsGoals] 通过 goal_id 关联，纯本地、不同步。
class SavingsRollingRepository {
  const SavingsRollingRepository(this._db);

  final AppDatabase _db;

  static const String _table = 'savings_rolling_plans';

  static const List<String> _columns = <String>[
    'id',
    'goal_id',
    'book_id',
    'base_minor',
    'annual_rate_bp',
    'term_months',
    'periods',
    'round_strategy',
    'auto_roll',
    'roll_add_new',
    'roll_rounds',
    'roll_target_minor',
    'rate_overrides',
    'amount_overrides',
    'updated_at',
  ];

  /// 把一行 [QueryRow] 还原为 [SavingsRollingPlan]。
  ///
  /// drift 的 [QueryRow] 不暴露整体 map，逐列读取后组装成
  /// [SavingsRollingPlan.fromRow] 所需的 `Map<String, dynamic>`。
  SavingsRollingPlan _rowToPlan(QueryRow row) {
    final Map<String, dynamic> data = <String, dynamic>{
      'id': row.read<String>('id'),
      'goal_id': row.read<String>('goal_id'),
      'book_id': row.read<String>('book_id'),
      'base_minor': row.read<int>('base_minor'),
      'annual_rate_bp': row.read<int>('annual_rate_bp'),
      'term_months': row.read<int>('term_months'),
      'periods': row.read<int>('periods'),
      'round_strategy': row.read<int>('round_strategy'),
      'auto_roll': row.read<int>('auto_roll'),
      'roll_add_new': row.read<int>('roll_add_new'),
      'roll_rounds': row.read<int>('roll_rounds'),
      'roll_target_minor': row.read<int?>('roll_target_minor'),
      'rate_overrides': row.read<String?>('rate_overrides'),
      'amount_overrides': row.read<String?>('amount_overrides'),
      'updated_at': row.read<int>('updated_at'),
    };
    return SavingsRollingPlan.fromRow(data);
  }

  /// 按 goalId 查计划（一次性）。
  Future<SavingsRollingPlan?> getByGoalId(String goalId) async {
    final List<QueryRow> rows = await _db.customSelect(
      'SELECT * FROM $_table WHERE goal_id = ?',
      variables: <Variable<Object>>[Variable<Object>(goalId)],
    ).get();
    if (rows.isEmpty) return null;
    return _rowToPlan(rows.first);
  }

  /// 按 goalId 实时监听计划（编辑页 / 详情页用）。
  Stream<SavingsRollingPlan?> watchByGoalId(String goalId) {
    return _db
        .customSelect(
          'SELECT * FROM $_table WHERE goal_id = ?',
          variables: <Variable<Object>>[Variable<Object>(goalId)],
        )
        .watchSingleOrNull()
        .map((QueryRow? row) => row == null ? null : _rowToPlan(row));
  }

  /// 插入或覆盖（id 为主键，goal_id 关联唯一）。
  ///
  /// 注意：`customStatement` 的占位符绑定参数必须传裸值
  /// （bool/int/num/String），禁包 [Variable]——Variable 只用于
  /// `customSelect` 的 variables；包了会运行时 ArgumentError、
  /// 事务静默回滚（UI 表现为「点了没反应」）。
  Future<void> upsert(SavingsRollingPlan plan) async {
    final Map<String, dynamic> cols = plan.toColumns();
    final String colList = _columns.join(', ');
    final String placeholderList =
        List<String>.filled(_columns.length, '?').join(', ');
    await _db.customStatement(
      'INSERT OR REPLACE INTO $_table ($colList) VALUES ($placeholderList)',
      <Object?>[
        cols['id'],
        cols['goal_id'],
        cols['book_id'],
        cols['base_minor'],
        cols['annual_rate_bp'],
        cols['term_months'],
        cols['periods'],
        cols['round_strategy'],
        cols['auto_roll'],
        cols['roll_add_new'],
        cols['roll_rounds'],
        cols['roll_target_minor'],
        cols['rate_overrides'],
        cols['amount_overrides'],
        cols['updated_at'],
      ],
    );
  }

  /// 删除某 goal 的滚存计划（删除储蓄目标时级联清理）。
  Future<void> deleteByGoalId(String goalId) async {
    await _db.customStatement(
      'DELETE FROM $_table WHERE goal_id = ?',
      <Object?>[goalId],
    );
  }

  /// 删除计划（按主键 id）。
  Future<void> delete(String id) async {
    await _db.customStatement(
      'DELETE FROM $_table WHERE id = ?',
      <Object?>[id],
    );
  }
}
