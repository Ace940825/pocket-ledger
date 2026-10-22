/// 同步控制层的选项定义。
///
/// 这一层把「同步方向 / 时间区间 / 数据范围」从「全自动被动上传」提升为
/// **用户可控**：既保留默认的全量自动同步（零回归），也支持手动按需同步。
///
/// 设计要点（相对初版方案的优化）：
/// - 自动模式行为完全不变，控制层是**增量增强**，不重写 LWW 引擎；
/// - 选择性同步（带区间/范围）是**一次性定向操作**，**不推进全局增量游标**，
///   否则下一次全量同步会因游标越界而永久漏拉区间外的记录；
/// - 回滚点只在「本地将被覆盖」时打快照（pull / merge 且本地已存在该行），
///   uploadOnly 不碰本地、无需快照，避免无谓膨胀；
/// - 后端只需给 `/pull` 增加 `until` + `tables` 两个可选参数，
///   推送侧的表过滤在客户端完成（根本不发范围外的 op），后端零改动。
library;

/// 同步方向。
enum SyncDirection {
  /// 双向合并（默认 LWW）：本地与云端互相同步，冲突以时间戳决胜。
  merge,

  /// 仅上传：本地覆盖云端，跳过 pull。
  pushOnly,

  /// 仅下载：云端覆盖本地，跳过 push。
  pullOnly,
}

/// 同步模式。
///
/// 与 [SyncSettings.enabled] 正交：`enabled == false` 即「关闭（纯本地）」；
/// 开启后，`auto` 后台自动跑全量同步，`manual` 只在用户点「立即同步」时跑。
enum SyncMode {
  /// 自动：保持现有行为，后台自动全量同步。
  auto,

  /// 手动：关闭自动触发，仅在用户显式发起时同步。
  manual,
}

/// 冲突处理策略（初版只实现 [auto]，[prompt] 为第二阶段）。
enum ConflictPolicy {
  /// 自动 LWW：时间戳新者胜出，无需用户介入。
  auto,

  /// 弹冲突解决页（逐字段选择保留本地 / 采用云端）。第二阶段实现。
  prompt,
}

/// 同步作用域：时间区间 + 数据范围。
///
/// `null` 的字段表示「不限制」。全为 null 即等价于全量同步。
class SyncScope {
  const SyncScope({this.fromMs, this.toMs, this.tables});

  /// 区间起点（UTC 毫秒，含）。null = 不限。
  final int? fromMs;

  /// 区间终点（UTC 毫秒，含）。null = 不限。
  final int? toMs;

  /// 参与的表名白名单（[SyncTables] 子集）。null / 空 = 全部表。
  final Set<String>? tables;

  /// 是否全量（无任何限制）。
  bool get isFull =>
      fromMs == null && toMs == null && (tables == null || tables!.isEmpty);

  /// 判断一条待推送记录是否落在作用域内。
  bool matches(String table, int updatedAt) {
    if (!isFull) {
      if (tables != null && tables!.isNotEmpty && !tables!.contains(table)) {
        return false;
      }
      if (fromMs != null && updatedAt < fromMs!) return false;
      if (toMs != null && updatedAt > toMs!) return false;
    }
    return true;
  }

  /// 传给后端的表名（逗号分隔）；null 表示全部。
  String? get tablesParam =>
      (tables != null && tables!.isNotEmpty) ? tables!.join(',') : null;

  static const SyncScope full = SyncScope();
}

/// 一次同步的可选配置。
class SyncOptions {
  const SyncOptions({
    this.direction = SyncDirection.merge,
    this.scope = SyncScope.full,
    this.conflictPolicy = ConflictPolicy.auto,
  });

  /// 同步方向。
  final SyncDirection direction;

  /// 作用域（时间区间 + 数据范围）。
  final SyncScope scope;

  /// 冲突处理策略。
  final ConflictPolicy conflictPolicy;

  /// 默认全量自动同步（兼容现有 [SyncEngine.run] 行为）。
  static const SyncOptions fullAuto = SyncOptions();
}
