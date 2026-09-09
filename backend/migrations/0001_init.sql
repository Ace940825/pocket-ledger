-- Pocket Ledger 云端同步表结构
--
-- 设计要点：
--   * 采用「通用同步表」而非按业务建 13 张表。云端只负责「按 owner_scope
--     聚合的最后写入胜出（LWW）存储」，所有聚合、报表都在本地 Drift 完成，
--     因此云端零计算、零函数计费，永远停留在免费层。
--   * 多设备 / 家人共享：同一 API_TOKEN 对应同一个 SYNC_SCOPE，
--     共享全部记录。若要隔离多用户，部署多份后端或为每个用户分配独立 token+scope。
--   * 软删除：deleted=1 仍保留记录，以便其他设备同步到「删除」事件。

CREATE TABLE IF NOT EXISTS sync_records (
  id           TEXT    NOT NULL,                       -- 记录主键（UUID v7，客户端生成）
  entity_table TEXT    NOT NULL,                       -- 业务表名（与本地 Drift 表名一致）
  owner_scope  TEXT    NOT NULL,                       -- 共享范围（来自 API_TOKEN 对应的 scope）
  payload      TEXT    NOT NULL,                       -- 业务字段 JSON 字符串
  updated_at   INTEGER NOT NULL,                       -- UTC 毫秒，冲突判定依据（LWW）
  deleted      INTEGER NOT NULL DEFAULT 0,             -- 软删除标记
  created_at   INTEGER NOT NULL DEFAULT (unixepoch() * 1000),
  PRIMARY KEY (owner_scope, entity_table, id)
);

-- 覆盖 keyset 分页查询：WHERE owner_scope = ? AND (updated_at > ? OR (updated_at = ? AND id > ?))
-- id 必须进索引，否则同毫秒翻页会退化成全表扫描。
CREATE INDEX IF NOT EXISTS idx_sync_records_pull
  ON sync_records (owner_scope, updated_at, id);

-- 仅保留最近版本：同一 (scope, table, id) 只存一行，空间随记录数线性增长，
-- 不随同步次数膨胀。个人记账量级（万行）远低于 D1 免费容量。
