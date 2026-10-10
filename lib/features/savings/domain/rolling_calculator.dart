import 'savings_rolling_plan.dart';

/// 36 期滚存法利息 / 到期额 / 滚存链计算引擎。
///
/// 全部用**整数定点**运算，零浮点误差：
/// - 金额内部单位 U = 1/100000 元（即 1 元 = 100000 U，1 分 = 1000 U）。
/// - 单笔利息（U）= 本金分 × 利率基点 × 期限月 ÷ 120
///   （推导：利息元 = 本金元 × 利率 × 年数；1 元 = 100000 U）。
/// - 到期额（U）= 本金分 × 1000 + 利息 U。
/// - 滚存本金（分）= 到期额 U 按取整策略取整到 1000 U（1 分）。
///
/// 利率浮动：每笔存入在创建时通过 [SavingsRollingPlan.rateAtPeriod]
/// 锁定当时利率，已存部分不受后续调息影响。
///
/// 计算量集中在 [simulate]：建仓期每月存固定本金、每张单利到期；存单到期
/// 后到期本息（带小数）按策略取整，**与本月现金投入合并为一张新存单续存**
/// （每月最多新增一张存单，不另开「新存」），滚存阶段可继续追投固定本金，
/// 形成现金流瀑布。输出每一笔存单的本金 / 锁定利率 / 利息 / 到期额，
/// 以及汇总（总投入 / 总利息 / 预计到期总额 / 等效年化）。
class RollingCalculator {
  const RollingCalculator._();

  /// 把到期额 U 按策略取整到「分」（1 分 = 1000 U）。
  static int roundToCents(int maturityU, RoundStrategy s) {
    return switch (s) {
      RoundStrategy.floor => maturityU ~/ 1000,
      RoundStrategy.ceil => (maturityU + 999) ~/ 1000,
      RoundStrategy.round => (maturityU + 500) ~/ 1000,
    };
  }

  /// 单笔存单的利息（U）与到期额（U）。
  ///
  /// [principalMinor] 本金（分，整数）；[rateBp] 锁定利率（基点）；
  /// [termMonths] 期限（月）。纯函数，可单独用于「某笔存 X 元、利率 Y、
  /// 存 N 月，利息多少、到期多少」的实时预览。
  static ({int interestU, int maturityU}) depositOutcome({
    required int principalMinor,
    required int rateBp,
    required int termMonths,
  }) {
    final int interestU = (principalMinor * rateBp * termMonths) ~/ 120;
    final int maturityU = principalMinor * 1000 + interestU;
    return (interestU: interestU, maturityU: maturityU);
  }

  /// 模拟整条滚存现金流。
  ///
  /// 返回全部存单（按创建顺序）与汇总。停止条件由 [plan.rollMode] 决定：
  /// - [RollingRollMode.permanent]：模拟到 [plan.periods] + 360 月（约 10 年滚存）；
  /// - [RollingRollMode.rounds]：模拟到 [plan.periods] × (1 + rollRounds) 月；
  /// - [RollingRollMode.target]：累计在存到期额达到 [rollTargetMinor] 即停
  ///   （最多 [plan.periods] + 600 月）。
  static RollingResult simulate(SavingsRollingPlan plan) {
    final int termMonths = plan.termMonths;
    final int periods = plan.periods;

    // 计算停止的绝对月份上限。
    final int maxMonths;
    switch (plan.rollMode) {
      case RollingRollMode.permanent:
        maxMonths = periods + 360;
      case RollingRollMode.rounds:
        maxMonths = periods + periods * plan.rollRounds;
      case RollingRollMode.target:
        maxMonths = periods + 600;
    }
    final int targetU =
        (plan.rollTargetMinor ?? 0) * 1000; // 目标额转 U（1 分 = 1000 U）

    final List<RollingDeposit> deposits = <RollingDeposit>[];
    // 在存（未到期）存单：depositMonth 用于判断本月是否到期。
    final List<_Active> active = <_Active>[];
    int seq = 0;
    int totalPrincipalMinor = 0; // 全部存单本金（含滚存本金）
    int cashPrincipalMinor = 0; // 实际掏的现金（仅 base 存款，不含滚存）
    int totalInterestU = 0;

    int month = 1;
    bool stop = false;
    while (!stop) {
      // 1) 结算本月到期存单：记录结果，到期本息（按策略取整到分）汇总，
      //    作为本月续存滚存本金。
      final int maturedRolledMinor;
      {
        int rolled = 0;
        final List<_Active> maturing =
            active.where((_Active d) => d.maturityMonth == month).toList();
        for (final _Active d in maturing) {
          active.remove(d);
          final (:int interestU, :int maturityU) = depositOutcome(
            principalMinor: d.principalMinor,
            rateBp: d.rateBp,
            termMonths: termMonths,
          );
          // 记录这笔存单的完整结果（含利息 / 到期额）。
          deposits.add(
            RollingDeposit(
              seq: d.seq,
              depositMonth: d.depositMonth,
              principalMinor: d.principalMinor,
              rateBp: d.rateBp,
              maturityMonth: d.maturityMonth,
              isRoll: d.isRoll,
              interestU: interestU,
              maturityU: maturityU,
            ),
          );
          totalInterestU += interestU;
          if (plan.autoRoll) {
            rolled += roundToCents(maturityU, plan.roundStrategy);
          }
        }
        maturedRolledMinor = rolled;
      }

      // 2) 本月现金投入：建仓期每期 base；滚存期开启「继续每月追投」也每期
      //    base（金额调整记录生效后取调整值）。追投的钱**并入本月续存存单**
      //    （到期本息 + 追投合为一张），不再另开「新存」——否则当月 base
      //    被算两遍、现金投入口径也错。
      final bool contribute =
          month <= periods || (plan.autoRoll && plan.rollAddNew);
      final int baseThisMonth = plan.baseAtPeriod(month);
      final int newCash = (contribute && baseThisMonth > 0) ? baseThisMonth : 0;

      // 3) 本月只生成一张新存单：滚存本金 + 现金投入合并存入
      //    （含滚存成分即标记为滚存存单）。
      final int combined = maturedRolledMinor + newCash;
      if (combined > 0) {
        seq++;
        active.add(
          _Active(
            seq: seq,
            depositMonth: month,
            principalMinor: combined,
            rateBp: plan.rateAtPeriod(month),
            maturityMonth: month + termMonths,
            isRoll: maturedRolledMinor > 0,
          ),
        );
        totalPrincipalMinor += combined;
        cashPrincipalMinor += newCash;
      }

      // 3) 停止条件判定。
      if (month >= maxMonths) {
        stop = true;
      } else if (plan.rollMode == RollingRollMode.target && targetU > 0) {
        int inFlightU = 0;
        for (final _Active d in active) {
          inFlightU += d.principalMinor * 1000 +
              (d.principalMinor * d.rateBp * termMonths) ~/ 120;
        }
        if (inFlightU >= targetU) stop = true;
      }

      month++;
      // 硬上限保护（防极端参数导致无限增长）。
      if (deposits.length > 2000) stop = true;
    }

    // 4) 仍在存的存单：补录其完整结果（未在计算循环里移除）。
    int activeFinalU = 0;
    for (final _Active d in active) {
      final (:int interestU, :int maturityU) = depositOutcome(
        principalMinor: d.principalMinor,
        rateBp: d.rateBp,
        termMonths: termMonths,
      );
      deposits.add(
        RollingDeposit(
          seq: d.seq,
          depositMonth: d.depositMonth,
          principalMinor: d.principalMinor,
          rateBp: d.rateBp,
          maturityMonth: d.maturityMonth,
          isRoll: d.isRoll,
          interestU: interestU,
          maturityU: maturityU,
        ),
      );
      totalInterestU += interestU;
      activeFinalU += maturityU;
    }

    // 5) 汇总。预计到期总额只算**期末仍在存**的存单：已到期续存的本金
    //    已经含在滚存存单里，若把已到期存单的到期额也加总，同一笔钱
    //    会被重复计入（滚存链越长虚高越严重）。
    final int finalMaturityU = activeFinalU;
    final double totalYears = (month - 1) / 12.0;
    // 等效年化以「实际掏的现金」为分母，避免滚存本金重复计入导致被稀释。
    final double effectiveAnnualRate;
    if (cashPrincipalMinor > 0 && totalYears > 0) {
      final double interestYuan = totalInterestU / 100000.0;
      final double principalYuan = cashPrincipalMinor / 100.0;
      effectiveAnnualRate = interestYuan / (principalYuan * totalYears) * 100;
    } else {
      effectiveAnnualRate = 0;
    }

    return RollingResult(
      deposits: deposits,
      totalPrincipalMinor: totalPrincipalMinor,
      cashPrincipalMinor: cashPrincipalMinor,
      totalInterestU: totalInterestU,
      finalMaturityU: finalMaturityU,
      simulatedMonths: month - 1,
      effectiveAnnualRatePct: effectiveAnnualRate,
    );
  }
}

/// 在存存单（模拟内部用）。
class _Active {
  _Active({
    required this.seq,
    required this.depositMonth,
    required this.principalMinor,
    required this.rateBp,
    required this.maturityMonth,
    required this.isRoll,
  });

  final int seq;
  final int depositMonth;
  final int principalMinor;
  final int rateBp;
  final int maturityMonth;
  final bool isRoll;
}

/// 单笔存单结果。
class RollingDeposit {
  const RollingDeposit({
    required this.seq,
    required this.depositMonth,
    required this.principalMinor,
    required this.rateBp,
    required this.maturityMonth,
    required this.isRoll,
    required this.interestU,
    required this.maturityU,
  });

  /// 全局序号（1-based，创建顺序）。
  final int seq;

  /// 存入期（从计划开始起算的绝对月号，1-based）。
  final int depositMonth;

  /// 存入本金（分，整数）。
  final int principalMinor;

  /// 锁定利率（基点，250 = 2.50%）。银行浮动利率下每笔可能不同。
  final int rateBp;

  /// 到期期（绝对月号）。
  final int maturityMonth;

  /// 是否滚存存单（true = 由上期到期本息续存；false = 首期/每月新存）。
  final bool isRoll;

  /// 利息（U = 1/100000 元，精确值）。
  final int interestU;

  /// 到期额（U = 1/100000 元，精确值 = 本金分 × 10000 + 利息 U）。
  final int maturityU;

  /// 利息（元，供 UI 显示）。
  double get interestYuan => interestU / 100000.0;

  /// 到期额（元，供 UI 显示）。
  double get maturityYuan => maturityU / 100000.0;

  /// 锁定利率（百分比，如 2.50）。
  double get ratePct => rateBp / 100.0;
}

/// 模拟汇总结果。
class RollingResult {
  const RollingResult({
    required this.deposits,
    required this.totalPrincipalMinor,
    required this.cashPrincipalMinor,
    required this.totalInterestU,
    required this.finalMaturityU,
    required this.simulatedMonths,
    required this.effectiveAnnualRatePct,
  });

  /// 全部存单（按创建顺序）。
  final List<RollingDeposit> deposits;

  /// 全部存单本金（分）= 所有存单本金之和（含滚存本金，仅内部参考）。
  final int totalPrincipalMinor;

  /// 实际掏的现金（分）= 仅 base 存款之和，不含滚存本金。
  final int cashPrincipalMinor;

  /// 总利息（U = 1/100000 元）。
  final int totalInterestU;

  /// 预计到期总额（U）= 期末仍在存存单的到期额之和（不含已续存滚存的）。
  final int finalMaturityU;

  /// 实际模拟月数。
  final int simulatedMonths;

  /// 等效年化收益率（%，单利近似：总利息 ÷ 实际现金 ÷ 总年数）。
  final double effectiveAnnualRatePct;

  double get totalPrincipalYuan => totalPrincipalMinor / 100.0;
  double get cashPrincipalYuan => cashPrincipalMinor / 100.0;
  double get totalInterestYuan => totalInterestU / 100000.0;
  double get finalMaturityYuan => finalMaturityU / 100000.0;

  /// 利息收益（元）= 预计到期总额 − 实际掏的现金。
  double get gainYuan =>
      (finalMaturityU - cashPrincipalMinor * 1000) / 100000.0;
}
