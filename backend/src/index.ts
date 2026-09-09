/**
 * Pocket Ledger 云端同步后端
 * Cloudflare Workers + D1 + R2，永久免费层。
 *
 * 与 app 端 lib/sync/adapters/cloudflare_adapter.dart 的契约严格对齐：
 *
 *  POST /api/sync/push
 *    body:  { device, ops: [{ table, id, op, updatedAt, payload }] }
 *    resp:  { appliedIds: string[], conflictedIds: string[] }
 *
 *  GET  /api/sync/pull?since=<ms>&limit=<n>&device=<id>
 *    resp:  { records: [{ table, id, updatedAt, deleted, payload }], serverTime }
 *
 *  POST /api/upload            (multipart form: file + 可选 key)
 *    resp:  { url: "/api/file/<key>" }
 *
 *  GET  /api/file/:key         由 Worker 直接从 R2 流式返回（无需 R2 公网域名）
 *  GET  /api/health            { ok: true, time }
 *
 * 鉴权：请求头 Authorization: Bearer <API_TOKEN>（未配置 API_TOKEN 时关闭鉴权，仅用于本地调试）
 */

import { Hono } from 'hono';
import { cors } from 'hono/cors';

type Bindings = {
  DB: D1Database;
  R2: R2Bucket;
  API_TOKEN?: string;
  SYNC_SCOPE?: string;
};

type PushOp = {
  table: string;
  id: string;
  op: 'update' | 'delete' | 'insert';
  updatedAt: number;
  payload?: Record<string, unknown> | null;
};

const app = new Hono<{ Bindings: Bindings }>();

app.use(
  '*',
  cors({
    origin: '*',
    allowMethods: ['GET', 'POST', 'OPTIONS'],
    allowHeaders: ['Authorization', 'Content-Type'],
  }),
);

/** 鉴权中间件：未配置 API_TOKEN 时放行（本地调试用）。 */
app.use('/api/*', async (c, next) => {
  const expect = c.env.API_TOKEN;
  if (expect && expect.length > 0) {
    const auth = c.req.header('Authorization') ?? '';
    const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
    if (token !== expect) {
      return c.json({ error: 'unauthorized' }, 401);
    }
  }
  await next();
});

const scopeOf = (c: { env: Bindings }) => c.env.SYNC_SCOPE || 'default';

/** 健康检查（部署后用来验证 Worker 已上线）。 */
app.get('/api/health', (c) => {
  return c.json({ ok: true, time: Date.now() });
});

/**
 * 拉取 scope 内游标之后的全部记录（LWW）。
 *
 * 为什么用 (updated_at, id) **复合游标**而不是单纯的 `updated_at > since`：
 * 同一毫秒内可能有多条记录（批量导入、一次同步推上来的一批），
 * 若把游标推进到该毫秒，其余同毫秒记录就会被永久跳过 —— 静默丢数据。
 * 复合游标保证同毫秒内也能按 id 继续往下翻，是标准的 keyset 分页。
 *
 * 注意：服务端不信任客户端时钟，serverTime 返回给客户端用于校准。
 */
app.get('/api/sync/pull', async (c) => {
  const scope = scopeOf(c);
  const since = Number(c.req.query('since') || '0') || 0;
  const afterId = c.req.query('afterId') || '';
  const limit = Math.min(Number(c.req.query('limit') || '500') || 500, 1000);

  const { results } = await c.env.DB.prepare(
    `SELECT id, entity_table, updated_at, deleted, payload
       FROM sync_records
      WHERE owner_scope = ?
        AND (updated_at > ? OR (updated_at = ? AND id > ?))
      ORDER BY updated_at ASC, id ASC
      LIMIT ?`,
  )
    .bind(scope, since, since, afterId, limit)
    .all<{ id: string; entity_table: string; updated_at: number; deleted: number; payload: string }>();

  const records = (results || []).map((r) => ({
    table: r.entity_table,
    id: r.id,
    updatedAt: r.updated_at,
    deleted: r.deleted === 1,
    payload: safeParse(r.payload),
  }));

  return c.json({ records, serverTime: Date.now() });
});

/**
 * 批量推送。服务端按 LWW 判定：若已有更新的版本则判定为冲突（拒绝），
 * 让客户端在下次 pull 时拿到权威版本。删除操作置 deleted=1，payload 仍保留以便回放。
 */
app.post('/api/sync/push', async (c) => {
  const scope = scopeOf(c);
  let body: { ops?: PushOp[] };
  try {
    body = await c.req.json<{ ops?: PushOp[] }>();
  } catch {
    return c.json({ error: 'invalid json' }, 400);
  }

  const ops = Array.isArray(body.ops) ? body.ops : [];
  const appliedIds: string[] = [];
  const conflictedIds: string[] = [];

  // 单事务批量写入，保证原子性。
  await c.env.DB.batch(
    ops.map((op) => {
      const updatedAt = Number(op.updatedAt) || Date.now();
      const deleted = op.op === 'delete' ? 1 : 0;
      const payload = op.payload ? JSON.stringify(op.payload) : '{}';
      return c.env.DB.prepare(
        `INSERT INTO sync_records (id, entity_table, owner_scope, payload, updated_at, deleted)
         VALUES (?, ?, ?, ?, ?, ?)
         ON CONFLICT(owner_scope, entity_table, id) DO UPDATE SET
           payload    = excluded.payload,
           updated_at = excluded.updated_at,
           deleted    = excluded.deleted
         WHERE excluded.updated_at >= sync_records.updated_at`,
      ).bind(op.id, op.table, scope, payload, updatedAt, deleted);
    }),
  );

  // 冲突判定：仅当服务端存在更新版本时才标记冲突。
  for (const op of ops) {
    const updatedAt = Number(op.updatedAt) || Date.now();
    const row = await c.env.DB.prepare(
      `SELECT updated_at FROM sync_records WHERE owner_scope = ? AND entity_table = ? AND id = ?`,
    )
      .bind(scope, op.table, op.id)
      .first<{ updated_at: number }>();
    if (row && row.updated_at > updatedAt) {
      conflictedIds.push(op.id);
    } else {
      appliedIds.push(op.id);
    }
  }

  return c.json({ appliedIds, conflictedIds });
});

/**
 * 上传附件（multipart）。返回由 Worker 代理的 /api/file/:key，
 * 这样无需为 R2 配置公网域名即可读取，进一步降低使用门槛。
 */
app.post('/api/upload', async (c) => {
  const form = await c.req.parseBody({ all: true });
  const file = form['file'];
  if (!file || typeof file === 'string') {
    return c.json({ error: 'file required' }, 400);
  }
  const providedKey = typeof form['key'] === 'string' ? (form['key'] as string) : '';
  const original =
    file instanceof File && file.name ? file.name : 'blob';
  const key = providedKey || `${crypto.randomUUID()}-${original}`;

  const arrayBuffer =
    file instanceof File ? await file.arrayBuffer() : (file as unknown as ArrayBuffer);
  await c.env.R2.put(key, arrayBuffer);

  return c.json({ url: `/api/file/${key}`, key });
});

/** 由 Worker 从 R2 读取附件并返回（无需 R2 公网访问）。 */
app.get('/api/file/:key', async (c) => {
  const key = c.req.param('key');
  const obj = await c.env.R2.get(key);
  if (!obj) return c.json({ error: 'not found' }, 404);
  const headers = new Headers();
  headers.set('Content-Type', obj.httpMetadata?.contentType || 'application/octet-stream');
  headers.set('Cache-Control', 'public, max-age=31536000, immutable');
  return new Response(obj.body, { headers });
});

function safeParse(s: string): Record<string, unknown> {
  try {
    const v = JSON.parse(s);
    return typeof v === 'object' && v !== null ? (v as Record<string, unknown>) : {};
  } catch {
    return {};
  }
}

export default app;
