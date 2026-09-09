# Pocket Ledger 云端同步后端（Cloudflare · 永久免费）

配套 `../lib/sync/adapters/cloudflare_adapter.dart` 使用。整套云端只做一件事：
**按 scope 存储「最后写入胜出（LWW）」的同步记录 + 附件存储**，所有报表/聚合都在
本地 Drift 完成，因此云端零计算、零函数调用计费，永远停在免费层。

## 免费额度与用量测算

| 资源 | 免费额度 | 个人记账实际用量 |
|------|----------|------------------|
| D1 写入 | 5 万行/日 | 约 50 行/日（0.1‰） |
| D1 读取 | 10 万行/日 | 约 100 行/日 |
| Workers 请求 | 10 万次/日 | 同步数次/日 |
| R2 存储 | 10 GB | 票据照片几十 MB |
| R2 出网 | 免费 | 附件按需取 |

→ 个人记账用量约为免费额度的 **0.01%**，且 Cloudflare 免费层**不因闲置暂停**
（对比 Supabase 免费层 7 天无流量会停）。

## 部署步骤（约 10 分钟）

```bash
# 1. 安装依赖
npm install

# 2. 登录 Cloudflare（免费，需绑定信用卡做风控，不会扣费）
npx wrangler login

# 3. 创建 D1 数据库，复制输出的 database_id 填入 wrangler.toml
npx wrangler d1 create pocket_ledger_prod

# 4. 创建 R2 桶
npx wrangler r2 bucket create pocket-ledger-attachments

# 5. 设置鉴权密钥（客户端请求头 Authorization: Bearer <此值>）
npx wrangler secret put API_TOKEN          # 输入一段随机字符串，例如 `openssl rand -hex 16`

# 6. 执行数据库迁移
npm run migrate:remote

# 7. 发布
npm run deploy
```

部署成功后记下 Worker 地址，例如 `https://pocket-ledger-sync.<sub>.workers.dev`。

## 在 App 端启用同步

编辑 `lib/core/config/env.dart`，把 `syncBaseUrl` 设为上面的地址，`syncToken` 设为
第 5 步的 `API_TOKEN`，`cloudSyncEnabled` 设为 `true`。App 启动后下拉首页即可触发同步。

- 多设备 / 家人共享：让所有设备安装同一个 `API_TOKEN` 与同一个后端地址，即共享同一
  `SYNC_SCOPE`（默认 `default`），数据自动合并（LWW 解决冲突）。
- 想要多用户隔离：部署多份后端，或为每个用户分配不同 `API_TOKEN` 并改成按 token 映射 scope。

## 本地调试

```bash
# 不加 API_TOKEN 时鉴权关闭，仅本地使用
npm run dev
curl http://127.0.0.1:8787/api/health
```

## 接口契约（与 app 端对齐）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET  | `/api/health` | 健康检查 |
| POST | `/api/sync/push` | 批量推送 `{device, ops:[{table,id,op,updatedAt,payload}]}` → `{appliedIds, conflictedIds}` |
| GET  | `/api/sync/pull?since=&afterId=&limit=&device=` | 拉取 `{records:[{table,id,updatedAt,deleted,payload}], serverTime}` |
| POST | `/api/upload` (multipart `file` + 可选 `key`) | 上传附件 → `{url:"/api/file/<key>"}` |
| GET  | `/api/file/:key` | 由 Worker 从 R2 读取附件（无需 R2 公网域名） |

**分页游标**：`since` 与 `afterId` 构成复合游标 `(updated_at, id)`，服务端按
`(updated_at, id)` 升序返回。同一毫秒内可能有多条记录，只用 `updated_at`
会把同毫秒的其余记录永久跳过 —— 这是最容易漏数据的地方，索引
`idx_sync_records_pull(owner_scope, updated_at, id)` 就是为这个查询建的。

客户端应循环拉取，每轮把游标推进到本批最后一条的 `(updatedAt, id)`，
直到返回条数小于 `limit` 为止。游标必须用**服务端返回的 `updatedAt`**，
不能用本地时钟，否则本机时间偏快会永久跳过未拉取的记录。

冲突策略：服务端收到更新时间**早于**已有版本时标记为 `conflictedIds`。
客户端应把冲突操作直接出队 —— 随后的 `pull` 会拿到权威版本覆盖本地；
若留在队列里，每次同步都会重复推一条注定失败的操作。
