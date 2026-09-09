/// 应用全局配置开关。
///
/// 设计原则：云端是**可选增强**，不是必需依赖。
/// 把 [Env.cloudSyncEnabled] 置为 false，应用即退化为功能完整的纯本地记账工具，
/// 所有网络请求停止，无需任何服务端。
abstract final class Env {
  /// 应用名称
  static const String appName = '口袋账本';

  /// 是否启用云同步。关闭后 SyncAdapter 自动切换为 OfflineAdapter。
  static const bool cloudSyncEnabled = true;

  /// Cloudflare Workers 同步端点。
  /// 部署后形如 https://pocket-ledger.<your-subdomain>.workers.dev
  /// 也可使用免费提供的 *.workers.dev 子域，无需购买域名。
  static const String syncBaseUrl = String.fromEnvironment(
    'SYNC_BASE_URL',
    defaultValue: 'https://pocket-ledger.example.workers.dev',
  );

  /// 同步访问令牌。生产环境建议通过 --dart-define 注入，不要硬编码。
  static const String syncToken = String.fromEnvironment(
    'SYNC_TOKEN',
    defaultValue: '',
  );

  /// 单次拉取的最大记录数，避免一次请求过大。
  static const int syncPullBatchSize = 500;

  /// 同步失败时的最大重试次数（指数退避）。
  static const int syncMaxRetries = 3;

  /// 本地数据库文件名（SQLCipher 加密）。
  static const String databaseName = 'pocket_ledger.db';

  /// 本地数据库密钥在 flutter_secure_storage 中的键名。
  static const String databaseKeyStorageKey = 'db_encryption_key';

  /// 同步游标的存储键（UTC 毫秒）。
  ///
  /// 注意：这是**服务端权威时间**，表示「已应用到本地的最后一条记录的时间」，
  /// 不是本地时钟 —— 用本地时钟做游标，一旦本机时间偏快就会永久跳过未拉取的记录。
  static const String lastPulledAtStorageKey = 'sync_last_pulled_at';

  /// 同步游标的 id 部分，与 [lastPulledAtStorageKey] 组成复合游标 `(updatedAt, id)`。
  static const String lastPulledIdStorageKey = 'sync_last_pulled_id';

  /// 上次成功完成同步的**本地**时间，仅用于设置页展示，不参与同步逻辑。
  static const String lastSyncedAtStorageKey = 'sync_last_synced_at';

  /// 云同步开关的存储键。云端是可选增强，默认关闭，
  /// 用户在设置页填入自己的 Workers 端点与令牌后才启用。
  static const String syncEnabledStorageKey = 'sync_enabled';

  /// 用户自定义同步端点（覆盖编译期默认值）
  static const String syncBaseUrlStorageKey = 'sync_base_url';

  /// 用户自定义同步令牌
  static const String syncTokenStorageKey = 'sync_token';

  /// 设备唯一标识存储键，用于多设备区分同步来源。
  static const String deviceIdStorageKey = 'device_id';
}
