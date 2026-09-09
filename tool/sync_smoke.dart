// 同步协议冒烟测试：用真实的 Dart 客户端打真实的后端服务。
//
// 为什么需要它：curl 只能验证 HTTP 层，验证不了 Dart 侧的序列化
// （字段是不是驼峰、枚举是不是 int、分页循环对不对）。
// 这个脚本把 CloudflareAdapter 直接指向本地 worker，跑一遍 push + pull 往返。
//
// 前置条件（另开一个终端）：
//   cd backend
//   npx wrangler d1 migrations apply pocket_ledger_prod --local
//   npx wrangler dev --local --port 8787
//
// 用法：dart run tool/sync_smoke.dart
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/sync/adapters/cloudflare_adapter.dart';
import 'package:pocket_ledger/sync/sync_adapter.dart';

const String kBaseUrl = String.fromEnvironment(
  'SMOKE_BASE_URL',
  defaultValue: 'http://127.0.0.1:8787',
);

int _passed = 0;
final List<String> _failures = <String>[];

void check(bool condition, String description) {
  if (condition) {
    _passed++;
  } else {
    _failures.add(description);
  }
}

Future<void> main() async {
  final CloudflareAdapter adapter = CloudflareAdapter(
    baseUrl: kBaseUrl,
    token: 'smoke-token',
  );

  check(await adapter.isAvailable(), 'isAvailable：端点与令牌已配置');
  if (!(await adapter.isAvailable())) {
    print('后端不可用，跳过。请先在 backend 目录启动 wrangler dev。');
    return;
  }

  final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
  final String prefix = 'smoke-$now';

  // ---- 1. 推送：三条同毫秒记录，用来验证 keyset 分页 ----
  final List<SyncOp> ops = <SyncOp>[
    for (int i = 0; i < 3; i++)
      SyncOp(
        tableName: 'transactions',
        recordId: '$prefix-$i',
        opType: SyncOpType.insert,
        updatedAt: now,
        payload: <String, Object?>{
          'id': '$prefix-$i',
          'bookId': 'book-1',
          'type': TxnType.expense.index,
          'amountMinor': 12345 + i,
          'accountId': 'acc-1',
          'occurredAt': now,
          'sourceModule': SourceModule.ledger.index,
          'currency': 'CNY',
          'updatedAt': now,
          'deleted': false,
          'dirty': true,
          'syncedAt': null,
        },
      ),
  ];

  final PushResult push = await adapter.push(deviceId: 'smoke-dart', ops: ops);
  check(push.appliedIds.length == 3, 'push 三条全部被应用，实际 ${push.appliedIds.length}');
  check(push.conflictedIds.isEmpty, '首次推送不应有冲突');

  // ---- 2. 分页拉取：limit=2，同毫秒必须能续拉 ----
  final PullResult page1 = await adapter.pull(
    deviceId: 'smoke-dart',
    since: now - 1,
    limit: 2,
  );
  check(page1.records.length == 2, '第 1 页返回 2 条，实际 ${page1.records.length}');

  final RemoteRecord last = page1.records.last;
  final PullResult page2 = await adapter.pull(
    deviceId: 'smoke-dart',
    since: last.updatedAt,
    afterId: last.recordId,
    limit: 2,
  );
  check(page2.records.length == 1, '第 2 页返回剩余 1 条，实际 ${page2.records.length}');
  check(
    page2.records.first.recordId != last.recordId,
    '第 2 页不重复第 1 页的最后一条',
  );

  // ---- 3. 字段往返：Dart 写进去的字段能原样读回来 ----
  final RemoteRecord back = page1.records.first;
  check(back.tableName == 'transactions', '表名往返一致');
  check(back.payload['bookId'] == 'book-1', 'bookId 往返一致（驼峰键名）');
  check(back.payload['amountMinor'] is int, 'amountMinor 是整数（分为单位）');
  check(back.payload['type'] == TxnType.expense.index, '枚举序列化为 int');
  check(back.deleted == false, 'deleted 默认 false');

  // ---- 4. 软删除 ----
  await adapter.push(
    deviceId: 'smoke-dart',
    ops: <SyncOp>[
      SyncOp(
        tableName: 'transactions',
        recordId: '$prefix-0',
        opType: SyncOpType.delete,
        updatedAt: now + 1000,
        payload: null,
      ),
    ],
  );
  final PullResult deleted = await adapter.pull(
    deviceId: 'smoke-dart',
    since: now + 500,
    limit: 10,
  );
  RemoteRecord? removed;
  for (final RemoteRecord r in deleted.records) {
    if (r.recordId == '$prefix-0') removed = r;
  }
  check(removed?.deleted == true, '删除后 deleted 标记为 true');

  print('通过 $_passed 项');
  if (_failures.isNotEmpty) {
    print('失败 ${_failures.length} 项：');
    for (final String f in _failures) {
      print('  ✗ $f');
    }
    throw StateError('同步冒烟测试未通过');
  }
  print('同步冒烟测试全部通过 ✅');
}
