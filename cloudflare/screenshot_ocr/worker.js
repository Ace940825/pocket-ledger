// 口袋账本 · 截图识别 Worker（Cloudflare Workers + Workers AI 视觉模型）
//
// 免费额度：Workers AI 每天赠送 10,000 Neurons（00:00 UTC 重置），个人记账用量远用不完。
// 视觉模型 @cf/meta/llama-3.2-vision 在 Free 计划通常可用；若返回 403（个别大模型限 Paid），
// 把 wrangler.toml 的 OCR_MODEL 变量改小模型，或升级 Workers Paid（$5/月）。
//
// 部署：
//   1) npm i -g wrangler && wrangler login
//   2) 在下方 wrangler.toml 同目录执行：wrangler deploy
//   3) 部署后得到 https://pocket-ledger-screenshot-ocr.<子域>.workers.dev（根路径，POST 该地址即可）
//   4) App 侧用 --dart-define=SCREENSHOT_OCR_ENDPOINT=<该地址> 注入（或替换 screenshot_ocr.dart 占位）

const SYSTEM_PROMPT = `你是记账助手。分析这张账单/收据截图，提取其中所有收支记录。
只输出一个 JSON 数组（不要任何解释、不要 markdown 代码块），数组每个元素形如：
{"amount": 38.0, "direction": "expense", "category": "餐饮", "date": "2026-10-02", "merchant": "星巴克", "account": "微信钱包", "toAccount": "", "note": "", "currency": "CNY", "confidence": 0.92}
字段说明：
- amount：数字，人民币默认元，不要带货币符号；优惠前的原价用 amount，优惠额写进 note。
- direction：必须是 expense（支出）/ income（收入）/ transfer（转账）之一（英文小写）。
- category：分类名（如 餐饮/交通/购物/工资/理财），转账留空。
- date：yyyy-MM-dd，看不清用今天。
- merchant：商户或对方名称，没有留空字符串。
- account：付款/收款账户名（如 微信钱包/支付宝/现金/招商银行信用卡），没有留空。
- toAccount：仅转账时填写转入账户，否则空字符串。
- note：备注，没有留空。
- currency：货币代码，人民币 CNY。
- confidence：0~1 置信度，拿不准的字段整体调低（如 0.4）。
一张图可能有多笔，请全部列出。`;

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }
    if (request.method !== 'POST') {
      return json({ error: '请使用 POST' }, 405);
    }

    let payload;
    try {
      payload = await request.json();
    } catch (e) {
      return json({ error: '请求体不是合法 JSON' }, 400);
    }

    const images = payload.images;
    if (!Array.isArray(images) || images.length === 0) {
      return json({ items: [], error: '缺少 images 字段' }, 200);
    }

    const model = env.OCR_MODEL || '@cf/meta/llama-3.2-vision';
    const items = [];
    const errors = [];

    for (const b64 of images) {
      try {
        const binary = atob(b64);
        const bytes = new Uint8Array(binary.length);
        for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);

        const out = await env.AI.run(model, {
          image: bytes,
          prompt: SYSTEM_PROMPT,
          max_tokens: 1024,
        });

        const text = (out && (out.response || out.description)) || '';
        const parsed = extractJsonArray(text);
        if (Array.isArray(parsed)) {
          for (const it of parsed) items.push(normalize(it));
        } else {
          errors.push('模型未返回有效 JSON');
        }
      } catch (e) {
        errors.push('单张识别失败：' + (e && e.message ? e.message : e));
      }
    }

    return json({ items, errors }, 200, corsHeaders());
  },
};

function extractJsonArray(text) {
  if (!text) return null;
  let s = text.trim();
  const fence = s.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fence) s = fence[1].trim();
  const start = s.indexOf('[');
  const end = s.lastIndexOf(']');
  if (start === -1 || end === -1 || end < start) return null;
  try {
    return JSON.parse(s.slice(start, end + 1));
  } catch (e) {
    return null;
  }
}

const DIRECTION_MAP = {
  expense: 'expense', '支出': 'expense', '支': 'expense',
  income: 'income', '收入': 'income', '收': 'income',
  transfer: 'transfer', '转账': 'transfer', '转': 'transfer',
};

function normalize(it) {
  const dir = DIRECTION_MAP[(it.direction || '').toString().trim()] || null;
  const today = new Date().toISOString().slice(0, 10);
  const num = (v) => {
    const n = parseFloat(String(v).replace(/[^\d.\-]/g, ''));
    return isNaN(n) ? 0 : n;
  };
  const conf = parseFloat(it.confidence);
  return {
    amount: num(it.amount),
    direction: dir,
    category: (it.category || '').toString().trim(),
    date: (it.date || today).toString().trim() || today,
    merchant: (it.merchant || '').toString().trim(),
    account: (it.account || '').toString().trim(),
    toAccount: (it.toAccount || '').toString().trim(),
    note: (it.note || '').toString().trim(),
    currency: (it.currency || 'CNY').toString().trim() || 'CNY',
    confidence: isNaN(conf) ? 0.8 : conf,
  };
}

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Content-Type': 'application/json; charset=utf-8',
  };
}

function json(data, status = 200, headers) {
  return new Response(JSON.stringify(data), {
    status,
    headers: headers || corsHeaders(),
  });
}
