import '../../../domain/enums.dart';

/// 编辑流水时，与 `type` **从属**的三个字段必须跟着类型走。
///
/// ## 为什么需要这份规则
///
/// 一条流水里只有 `type`（支出 / 收入 / 转账）是用户直接在编辑页选的，
/// 另外三个字段都是它的从属属性：
///
/// | 字段 | 从属关系 |
/// |---|---|
/// | `sourceModule` | `transfer` ⟺ 转账；`refund` ⟹ 收入 |
/// | `toAccountId` | 只有转账才有「转入账户」 |
/// | `transferGroupId` | 只有转账才属于某个转账分组 |
///
/// 早先的 `updateTransaction` 只写 `type`、**完全不碰这三个字段**，于是
/// 「改类型」的编辑会留下一个**撒谎的旧标记**。真实事故（2026-09-11）：
///
/// - 一笔 `type = income, sourceModule = refund` 的退款流水，
///   在列表里的标题由 `type` 决定 → 显示「收入」，与普通收入**长得一模一样**；
/// - 但资产页统计按 `sourceModule == refund` 判定 → 走「抵扣支出」分支，
///   于是「餐饮 −¥100 + 收入 +¥12」被算成 `支出:¥88.00 收入:¥0.00`，
///   和明细（¥100 / ¥12）彻底对不上。
///
/// 同类问题还有：转账改成支出后仍留着 `toAccountId`，
/// 这条支出就会凭 `toAccountId` 命中**转入方账户**的明细
/// （`watchByAccount` 的条件是 `accountId = A OR toAccountId = A`），
/// 并被 `transferDirectionOf` 误判成转账腿。
///
/// ## 规则
///
/// - 新类型是**转账** → `sourceModule` 必须是 `transfer`；
/// - 新类型**不是转账** → `toAccountId` 与 `transferGroupId` 一律清空；
///   若原类型是转账，`sourceModule` 退回 `ledger`；
/// - 新类型**不是收入** → 退款标记失效（退款必然是收入），退回 `ledger`；
/// - 其余模块（借还 / 报销 / 储蓄 / 分期 / 投资 / 物品）是「**谁写的**」这种
///   出处信息，与用户后来怎么改类型无关，一律原样保留 ——
///   否则会把业务归属改丢（例如把报销流水改成「日常记账」）。
///
/// 纯函数、无 IO，方便单测。
class TransactionEditIdentity {
  const TransactionEditIdentity({
    required this.sourceModule,
    required this.toAccountId,
    required this.transferGroupId,
  });

  /// 类型变更后 `sourceModule` 的应有值。
  final SourceModule sourceModule;

  /// 类型变更后 `toAccountId` 的应有值（非转账恒为 `null`）。
  final String? toAccountId;

  /// 类型变更后 `transferGroupId` 的应有值（非转账恒为 `null`）。
  final String? transferGroupId;
}

/// 按 [newType] 推导出 [`sourceModule` / `toAccountId` / `transferGroupId`] 的应有值。
///
/// [overrideSourceModule] 用于用户**显式**表态的场景（编辑页的「这是退款」开关）：
/// 它替换掉 [currentSourceModule] 作为起点，再参与规则推导。
/// 例如把一笔退款转成普通收入时，类型没变（都是收入），
/// 光靠推导无法把 `refund` 摘掉，必须由用户显式指定 `ledger`。
TransactionEditIdentity resolveEditIdentity({
  required TxnType newType,
  required SourceModule currentSourceModule,
  required String? currentToAccountId,
  required String? currentTransferGroupId,
  SourceModule? overrideSourceModule,
}) {
  final SourceModule base = overrideSourceModule ?? currentSourceModule;

  if (newType == TxnType.transfer) {
    return TransactionEditIdentity(
      sourceModule: SourceModule.transfer,
      toAccountId: currentToAccountId,
      transferGroupId: currentTransferGroupId,
    );
  }

  // 已不是转账：转账身份与它的两个附属字段全部失效。
  SourceModule module =
      base == SourceModule.transfer ? SourceModule.ledger : base;

  // 退款必定是收入；改成支出后退款标记失效。
  if (module == SourceModule.refund && newType != TxnType.income) {
    module = SourceModule.ledger;
  }

  return TransactionEditIdentity(
    sourceModule: module,
    toAccountId: null,
    transferGroupId: null,
  );
}
