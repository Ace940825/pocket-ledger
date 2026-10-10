import 'dart:convert';

/// 取整策略（对应数据库 round_strategy 列）。
///
/// 银行定期到期后本息带小数，重新存入必须取整数，三种策略对应：
/// - [round]：四舍五入（零头最小，最贴近理论值）；
/// - [ceil]：向上取整（多存一点，实际收益略高，零头留在现金侧）；
/// - [floor]：向下取整（少存一点，零头留在现金侧，滚存本金略小）。
enum RoundStrategy {
  round(0),
  ceil(1),
  floor(2);

  const RoundStrategy(this.value);

  final int value;

  static RoundStrategy fromValue(int v) {
    return switch (v) {
      1 => ceil,
      2 => floor,
      _ => round,
    };
  }

  String get label {
    return switch (this) {
      RoundStrategy.ceil => '向上取整',
      RoundStrategy.floor => '向下取整',
      RoundStrategy.round => '四舍五入',
    };
  }
}

/// 单条利率调整记录。
///
/// 银行利率会浮动：在某期（[fromPeriod]，1-based 存入期号）起改用
/// [rateBp]（基点，250 = 2.50%）。已存入的存单不受影响（利率在存入时锁定），
/// 仅 [fromPeriod] 及之后的存入采用新利率。多条按 [fromPeriod] 升序生效。
class RollingRateOverride {
  const RollingRateOverride({
    required this.fromPeriod,
    required this.rateBp,
  });

  /// 起始生效期（1-based 存入期号）。
  final int fromPeriod;

  /// 利率（基点，250 = 2.50%）。
  final int rateBp;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'f': fromPeriod,
        'r': rateBp,
      };

  static RollingRateOverride fromJson(Map<String, dynamic> m) =>
      RollingRateOverride(
        fromPeriod: m['f'] as int,
        rateBp: m['r'] as int,
      );
}

/// 单条金额调整记录。
///
/// 后期想追加 / 变更每月定投金额：从 [fromPeriod]（1-based 存入期号）起，
/// 每月现金投入改用 [amountMinor]（分）。此前已存入的存单不受影响；
/// 多条按 [fromPeriod] 升序生效。与 [RollingRateOverride] 同构。
class RollingAmountOverride {
  const RollingAmountOverride({
    required this.fromPeriod,
    required this.amountMinor,
  });

  /// 起始生效期（1-based 存入期号）。
  final int fromPeriod;

  /// 起该期起每月存入金额（分，整数）。
  final int amountMinor;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'f': fromPeriod,
        'a': amountMinor,
      };

  static RollingAmountOverride fromJson(Map<String, dynamic> m) =>
      RollingAmountOverride(
        fromPeriod: m['f'] as int,
        amountMinor: m['a'] as int,
      );
}

/// 36 期滚存计划配置（普通 Dart 模型，不依赖 drift 代码生成）。
///
/// 设计要点（均来自用户需求）：
/// 1. **方便**：用户只填首期本金 / 年利率 / 期限 / 期数 / 取整 / 自动滚存 /
///    追投 / 滚存轮数（约 6–8 个数）+ 可选的利率调整记录。
/// 2. **计算多**：真正计算在 [rolling_calculator.dart]，本类只承载参数，
///    并通过 [rateAtPeriod] 提供「浮动利率」查询。
/// 3. **利率浮动**：[rateOverrides] 记录各期起生效的新利率；每笔 3 年定存
///    在存入时锁定当时利率（符合银行实际），已存部分不受后续调息影响。
class SavingsRollingPlan {
  const SavingsRollingPlan({
    required this.id,
    required this.goalId,
    required this.bookId,
    required this.baseMinor,
    required this.annualRateBp,
    required this.termMonths,
    required this.periods,
    required this.roundStrategy,
    required this.autoRoll,
    required this.rollAddNew,
    required this.rollRounds,
    this.rollTargetMinor,
    this.rateOverrides = const <RollingRateOverride>[],
    this.amountOverrides = const <RollingAmountOverride>[],
    required this.updatedAt,
  });

  final String id;
  final String goalId;
  final String bookId;

  /// 首期 / 每月固定存入本金（分，整数）。建仓期每期都是这个数。
  final int baseMinor;

  /// 默认年利率（基点，250 = 2.50%）。无利率调整记录时所有存入用此值。
  final int annualRateBp;

  /// 单笔定期期限（月），默认 36（3 年）。
  final int termMonths;

  /// 建仓期数（月），默认 36。每月存一笔固定本金，共 [periods] 笔独立存单。
  final int periods;

  /// 取整策略（见 [RoundStrategy]）。
  final RoundStrategy roundStrategy;

  /// 是否自动滚存：存单到期后本息自动续存为新定期。
  final bool autoRoll;

  /// 滚存阶段是否继续每月追加固定本金 [baseMinor]。
  final bool rollAddNew;

  /// 滚存轮数：0 = 永久滚存；>0 = 滚存 [rollRounds] 轮后停止。
  /// 「轮」= 全部 [periods] 笔存单各滚存一次（即 [periods] 个月）。
  final int rollRounds;

  /// 滚存停止目标额（分，整数）。仅 [rollMode] 为 target 时有意义。
  final int? rollTargetMinor;

  /// 利率调整记录（按 [RollingRateOverride.fromPeriod] 升序）。
  final List<RollingRateOverride> rateOverrides;

  /// 金额调整记录（按 [RollingAmountOverride.fromPeriod] 升序）。
  ///
  /// 后期追加 / 变更每月定投金额：某期起每月现金投入改用新金额，
  /// 已存入的存单不受影响（本金在存入时锁定）。
  final List<RollingAmountOverride> amountOverrides;

  final int updatedAt;

  SavingsRollingPlan copyWith({
    String? id,
    String? goalId,
    String? bookId,
    int? baseMinor,
    int? annualRateBp,
    int? termMonths,
    int? periods,
    RoundStrategy? roundStrategy,
    bool? autoRoll,
    bool? rollAddNew,
    int? rollRounds,
    int? rollTargetMinor,
    List<RollingRateOverride>? rateOverrides,
    List<RollingAmountOverride>? amountOverrides,
    int? updatedAt,
  }) {
    return SavingsRollingPlan(
      id: id ?? this.id,
      goalId: goalId ?? this.goalId,
      bookId: bookId ?? this.bookId,
      baseMinor: baseMinor ?? this.baseMinor,
      annualRateBp: annualRateBp ?? this.annualRateBp,
      termMonths: termMonths ?? this.termMonths,
      periods: periods ?? this.periods,
      roundStrategy: roundStrategy ?? this.roundStrategy,
      autoRoll: autoRoll ?? this.autoRoll,
      rollAddNew: rollAddNew ?? this.rollAddNew,
      rollRounds: rollRounds ?? this.rollRounds,
      rollTargetMinor: rollTargetMinor ?? this.rollTargetMinor,
      rateOverrides: rateOverrides ?? this.rateOverrides,
      amountOverrides: amountOverrides ?? this.amountOverrides,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 滚存停止方式。
  RollingRollMode get rollMode {
    if (rollTargetMinor != null) return RollingRollMode.target;
    if (rollRounds > 0) return RollingRollMode.rounds;
    return RollingRollMode.permanent;
  }

  /// 查询某存入期号生效的年利率（基点）。
  ///
  /// 取 [rateOverrides] 中「起始期 ≤ [period]」且起始期最大的那条；
  /// 无匹配时回退 [annualRateBp]。即银行调息后，新利率从该期起自动生效，
  /// 已存入的存单仍按其存入时的利率计息。
  int rateAtPeriod(int period) {
    int rate = annualRateBp;
    for (final RollingRateOverride o in rateOverrides) {
      if (o.fromPeriod <= period) {
        rate = o.rateBp;
      } else {
        break; // rateOverrides 已按 fromPeriod 升序
      }
    }
    return rate;
  }

  /// 查询某存入期生效的每月现金投入（分）。
  ///
  /// 取 [amountOverrides] 中「起始期 ≤ [period]」且起始期最大的那条；
  /// 无匹配时回退 [baseMinor]。即调整金额后，新金额从该期起生效，
  /// 已存入的存单仍按其存入时的本金计息。
  int baseAtPeriod(int period) {
    int base = baseMinor;
    for (final RollingAmountOverride o in amountOverrides) {
      if (o.fromPeriod <= period) {
        base = o.amountMinor;
      } else {
        break; // amountOverrides 已按 fromPeriod 升序
      }
    }
    return base;
  }

  /// 从原生 SQL 查询结果行构造（列名见 _ensureRollingPlansTable）。
  static SavingsRollingPlan fromRow(Map<String, dynamic> row) {
    final String? overridesRaw = row['rate_overrides'] as String?;
    final List<RollingRateOverride> overrides = <RollingRateOverride>[];
    if (overridesRaw != null && overridesRaw.isNotEmpty) {
      final List<dynamic> list = jsonDecode(overridesRaw) as List<dynamic>;
      for (final dynamic item in list) {
        overrides
            .add(RollingRateOverride.fromJson(item as Map<String, dynamic>));
      }
      overrides.sort(
        (RollingRateOverride a, RollingRateOverride b) =>
            a.fromPeriod.compareTo(b.fromPeriod),
      );
    }
    final String? amountsRaw = row['amount_overrides'] as String?;
    final List<RollingAmountOverride> amountOverrides =
        <RollingAmountOverride>[];
    if (amountsRaw != null && amountsRaw.isNotEmpty) {
      final List<dynamic> list = jsonDecode(amountsRaw) as List<dynamic>;
      for (final dynamic item in list) {
        amountOverrides.add(
          RollingAmountOverride.fromJson(item as Map<String, dynamic>),
        );
      }
      amountOverrides.sort(
        (RollingAmountOverride a, RollingAmountOverride b) =>
            a.fromPeriod.compareTo(b.fromPeriod),
      );
    }
    return SavingsRollingPlan(
      id: row['id'] as String,
      goalId: row['goal_id'] as String,
      bookId: row['book_id'] as String,
      baseMinor: row['base_minor'] as int,
      annualRateBp: row['annual_rate_bp'] as int,
      termMonths: row['term_months'] as int,
      periods: row['periods'] as int,
      roundStrategy: RoundStrategy.fromValue(row['round_strategy'] as int),
      autoRoll: (row['auto_roll'] as int) == 1,
      rollAddNew: (row['roll_add_new'] as int) == 1,
      rollRounds: row['roll_rounds'] as int,
      rollTargetMinor: row['roll_target_minor'] as int?,
      rateOverrides: overrides,
      amountOverrides: amountOverrides,
      updatedAt: row['updated_at'] as int,
    );
  }

  /// 转为原生 SQL 写入用的列映射。
  Map<String, dynamic> toColumns() {
    final String overridesRaw = rateOverrides.isEmpty
        ? ''
        : jsonEncode(
            rateOverrides.map((RollingRateOverride o) => o.toJson()).toList(),
          );
    final String amountsRaw = amountOverrides.isEmpty
        ? ''
        : jsonEncode(
            amountOverrides
                .map((RollingAmountOverride o) => o.toJson())
                .toList(),
          );
    return <String, dynamic>{
      'id': id,
      'goal_id': goalId,
      'book_id': bookId,
      'base_minor': baseMinor,
      'annual_rate_bp': annualRateBp,
      'term_months': termMonths,
      'periods': periods,
      'round_strategy': roundStrategy.value,
      'auto_roll': autoRoll ? 1 : 0,
      'roll_add_new': rollAddNew ? 1 : 0,
      'roll_rounds': rollRounds,
      'roll_target_minor': rollTargetMinor,
      'rate_overrides': overridesRaw,
      'amount_overrides': amountsRaw,
      'updated_at': updatedAt,
    };
  }
}

/// 滚存停止方式。
enum RollingRollMode {
  /// 永久滚存（rollRounds == 0）。
  permanent,

  /// 滚存固定轮数后停止（rollRounds > 0）。
  rounds,

  /// 滚存到累计到期额达到目标后停止（rollTargetMinor != null）。
  target,
}
