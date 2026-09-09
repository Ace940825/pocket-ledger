// 纯 Dart 自检脚本。
//
// 为什么需要它：`flutter test` 依赖 flutter_tester 进程（通过 WebSocket 通信），
// 在受限的 CI / 沙箱环境里可能拉不起来。本脚本只用 `dart run` 执行，
// 不依赖任何 Flutter 运行时，因此任何环境都能验证核心不变量。
//
// 用法：dart run tool/self_check.dart
// 覆盖三块最容易出错、也最不能出错的地方：
//   1. 日期月末夹取与预算区间
//   2. 金额整数运算
//   3. 同步解码器的字段覆盖（源码级静态检查，见 _checkRecordCodecCoverage）
import 'dart:io';

import 'package:pocket_ledger/core/utils/date_utils.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/settings/data/sync_settings.dart';
import 'package:pocket_ledger/shared/models/money.dart';
import 'package:pocket_ledger/sync/sync_adapter.dart';

int _passed = 0;
final List<String> _failures = <String>[];

void check(bool condition, String description) {
  if (condition) {
    _passed++;
  } else {
    _failures.add(description);
  }
}

void main() {
  _checkDateUtils();
  _checkMoney();
  _checkBudgetRange();
  _checkRecordCodecCoverage();
  _checkSyncProtocol();
  _checkSyncSettings();

  print('通过 $_passed 项');
  if (_failures.isNotEmpty) {
    print('失败 ${_failures.length} 项：');
    for (final String f in _failures) {
      print('  ✗ $f');
    }
    throw StateError('自检未通过');
  }
  print('全部自检通过 ✅');
}

void _checkDateUtils() {
  // 普通进位
  check(addMonths(DateTime(2026, 3, 15), 1) == DateTime(2026, 4, 15),
      '3/15 +1 月 = 4/15');
  check(addMonths(DateTime(2026, 3, 15), 6) == DateTime(2026, 9, 15),
      '3/15 +6 月 = 9/15');
  check(addMonths(DateTime(2026, 11, 10), 3) == DateTime(2027, 2, 10),
      '跨年：11/10 +3 月 = 次年 2/10');
  check(addMonths(DateTime(2026, 1, 10), -2) == DateTime(2025, 11, 10),
      '回退：1/10 -2 月 = 前年 11/10');
  check(addMonths(DateTime(2026, 5, 20), 0) == DateTime(2026, 5, 20),
      '+0 月保持不变');
  check(
      addMonths(DateTime(2026, 5, 20, 13, 45), 1) ==
          DateTime(2026, 6, 20, 13, 45),
      '保留时分');

  // 月末夹取 —— 本工具存在的核心理由。
  // Dart 原生 DateTime(2026, 2, 31) 会溢出成 3 月 3 日。
  check(addMonths(DateTime(2026, 1, 31), 1) == DateTime(2026, 2, 28),
      '平年 1/31 +1 月 = 2/28');
  check(addMonths(DateTime(2024, 1, 31), 1) == DateTime(2024, 2, 29),
      '闰年 1/31 +1 月 = 2/29');
  check(addMonths(DateTime(2026, 8, 31), 1) == DateTime(2026, 9, 30),
      '8/31 +1 月 = 9/30');

  // 天数与闰年
  check(daysInMonth(2026, 1) == 31, '1 月 31 天');
  check(daysInMonth(2026, 4) == 30, '4 月 30 天');
  check(daysInMonth(2026, 2) == 28, '平年 2 月 28 天');
  check(daysInMonth(2024, 2) == 29, '闰年 2 月 29 天');
  check(isLeapYear(2024), '2024 是闰年');
  check(isLeapYear(2000), '2000 是闰年（能被 400 整除）');
  check(!isLeapYear(1900), '1900 不是闰年（能被 100 但不能被 400 整除）');
  check(!isLeapYear(2026), '2026 不是闰年');

  // 同一天不同时刻映射到同一零点
  check(
      startOfDayMs(DateTime(2026, 5, 20, 0, 0, 1)) ==
          startOfDayMs(DateTime(2026, 5, 20, 23, 59, 59)),
      'startOfDayMs 抹掉时分秒');
}

void _checkBudgetRange() {
  final ({int end, int start}) monthly = budgetRange(
    year: 2026,
    periodIndex: 3,
    monthly: true,
    quarterly: false,
  );
  // 注意：区间端点由「本地月初」转 UTC 毫秒得到，因此解读时也必须
  // 用 toLocal() 回看。若直接用 UTC 解读，东八区下会整体退回上一个月。
  final DateTime mStart = DateTime.fromMillisecondsSinceEpoch(
    monthly.start,
    isUtc: true,
  ).toLocal();
  final DateTime mEnd = DateTime.fromMillisecondsSinceEpoch(
    monthly.end,
    isUtc: true,
  ).toLocal();
  check(mStart.month == 3 && mEnd.month == 4,
      '月度区间 = [3/1, 4/1)，实际 ${mStart.month} → ${mEnd.month}');
  check(monthly.start < monthly.end, '月度区间起点早于终点');

  final ({int end, int start}) q2 = budgetRange(
    year: 2026,
    periodIndex: 2,
    monthly: false,
    quarterly: true,
  );
  final DateTime qStart = DateTime.fromMillisecondsSinceEpoch(
    q2.start,
    isUtc: true,
  ).toLocal();
  final DateTime qEnd = DateTime.fromMillisecondsSinceEpoch(
    q2.end,
    isUtc: true,
  ).toLocal();
  check(qStart.month == 4 && qEnd.month == 7,
      'Q2 区间 = [4/1, 7/1)，实际 ${qStart.month} → ${qEnd.month}');

  final ({int end, int start}) yearly = budgetRange(
    year: 2026,
    periodIndex: 0,
    monthly: false,
    quarterly: false,
  );
  final DateTime yEnd = DateTime.fromMillisecondsSinceEpoch(
    yearly.end,
    isUtc: true,
  ).toLocal();
  check(yEnd.year == 2027 && yEnd.month == 1,
      '年度区间右端点 = 次年 1/1');

  final int pMonth = currentPeriodIndex(monthly: true, quarterly: false);
  final int pQuarter = currentPeriodIndex(monthly: false, quarterly: true);
  final int pYear = currentPeriodIndex(monthly: false, quarterly: false);
  check(pMonth >= 1 && pMonth <= 12, '月度序号在 1-12');
  check(pQuarter >= 1 && pQuarter <= 4, '季度序号在 1-4');
  check(pYear == 0, '年度序号恒为 0');
}

void _checkMoney() {
  // 「分」存储
  check(Money.fromDecimal(1).minor == 100, '1 元 = 100 分');
  check(Money.fromDecimal(0.01).minor == 1, '0.01 元 = 1 分');
  check(Money.fromDecimal(0.1).minor == 10,
      '0.1 元 = 10 分（不因浮点落为 9 分）');
  check(Money.fromMinor(12345).minor == 12345, 'fromMinor 原样保留');

  // 整套金额设计的根本目的
  check((Money.fromDecimal(0.1) + Money.fromDecimal(0.2)).minor == 30,
      '0.1 + 0.2 = 0.3（30 分）');

  // 解析容错
  check(Money.tryParse('12.34').minor == 1234, "tryParse('12.34') = 1234 分");
  check(Money.tryParse(null).minor == 0, 'tryParse(null) = 0');
  check(Money.tryParse('abc').minor == 0, "tryParse('abc') = 0");

  // 符号
  check(Money.zero.isZero, '零值判定');
  check(Money.fromMinor(-1).isNegative, '负数判定');
  check(Money.fromMinor(1).isPositive, '正数判定');
  check(Money.fromMinor(-500).abs().minor == 500, 'abs');
  check(Money.fromMinor(500).negate().minor == -500, 'negate');

  // 运算
  check((Money.fromMinor(1000) - Money.fromMinor(250)).minor == 750, '减法');
  check((Money.fromMinor(100) * 3).minor == 300, '乘法');

  // AA 分账不丢分：100 元三等分，两份 + 余数 = 100 元
  final Money total = Money.fromMinor(10000);
  final Money third = total.ratio(1 / 3);
  check(third.minor * 2 + (total - third * 2).minor == 10000,
      '三等分后各部分之和仍等于总额');

  // decimal 仅用于展示
  check(Money.fromMinor(12345).decimal == 123.45, 'decimal 展示值');
}

/// 同步解码器字段覆盖检查（源码级静态分析）。
///
/// **为什么做这个检查**：[RecordCodec] 需要为每一张表的每一个字段手工写一行
/// 解码代码。只要漏写一行，另一端设备拉回来的记录就会把这个字段悄悄重置成
/// 默认值 —— 不报错、不崩溃，只是数据静默丢失。这类 bug 靠 code review 很难发现。
///
/// 这里直接对比两份源码：表定义里的字段集合，必须是解码器参数集合的子集。
void _checkRecordCodecCoverage() {
  const String tablesPath = 'lib/database/tables.dart';
  const String codecPath = 'lib/sync/record_codec.dart';

  final File tablesFile = File(tablesPath);
  final File codecFile = File(codecPath);
  check(tablesFile.existsSync(), '$tablesPath 存在');
  check(codecFile.existsSync(), '$codecPath 存在');
  if (!tablesFile.existsSync() || !codecFile.existsSync()) return;

  final String tablesSrc = tablesFile.readAsStringSync();
  final String codecSrc = codecFile.readAsStringSync();

  // ---- 1. 解析表定义 ----
  // 只匹配混入 SyncColumns 的业务表（PendingOps 是本地队列，不参与同步）
  final RegExp tableRe = RegExp(
    r'class (\w+) extends Table with SyncColumns \{(.*?)\n\}',
    dotAll: true,
  );
  final RegExp colRe = RegExp(r'\n  \w+ get (\w+) =>');

  final Map<String, Set<String>> tableFields = <String, Set<String>>{};
  for (final RegExpMatch m in tableRe.allMatches(tablesSrc)) {
    final String tableName = m.group(1)!;
    final Set<String> fields = <String>{};
    for (final RegExpMatch c in colRe.allMatches(m.group(2)!)) {
      final String field = c.group(1)!;
      if (field == 'primaryKey') continue;
      fields.add(field);
    }
    // SyncColumns mixin 提供的 4 个同步元数据字段
    fields.addAll(<String>{'updatedAt', 'deleted', 'dirty', 'syncedAt'});
    tableFields[tableName] = fields;
  }
  check(tableFields.length == 12, '解析到 12 张业务表，实际 ${tableFields.length}');

  // ---- 2. 解析解码器 ----
  // 用「定位 insert( + 括号配对」而不是一整条大正则：
  // 正则一旦依赖具体缩进或换行风格就非常脆弱，而这两个方法体是手写的。
  final RegExp sigRe = RegExp(r'static (\w+)Companion \w+\(');
  final RegExp argRe = RegExp(r'(\w+): ');

  final Map<String, Set<String>> codecFields = <String, Set<String>>{};
  for (final RegExpMatch m in sigRe.allMatches(codecSrc)) {
    final int open = codecSrc.indexOf('.insert(', m.end);
    if (open < 0) continue;

    // 从 '(' 开始配对，取参数体
    final int start = open + '.insert('.length - 1;
    int depth = 0;
    int k = start;
    while (k < codecSrc.length) {
      final String ch = codecSrc[k];
      if (ch == '(') {
        depth++;
      } else if (ch == ')') {
        depth--;
        if (depth == 0) break;
      }
      k++;
    }
    final String body = codecSrc.substring(start + 1, k);

    final Set<String> args = <String>{};
    for (final RegExpMatch a in argRe.allMatches(body)) {
      args.add(a.group(1)!);
    }
    codecFields[m.group(1)!] = args;
  }
  check(codecFields.length == 12, '解析到 12 个解码方法，实际 ${codecFields.length}');

  // ---- 3. 逐表比对字段 ----
  final List<String> sortedTables = tableFields.keys.toList()..sort();
  for (final String table in sortedTables) {
    final Set<String>? decoded = codecFields[table];
    if (decoded == null) {
      check(false, '$table 缺少对应的 RecordCodec 解码方法');
      continue;
    }
    final Set<String> missing = tableFields[table]!.difference(decoded);
    final String suffix = missing.isEmpty ? '' : '，漏了：${missing.join(', ')}';
    check(missing.isEmpty, 'RecordCodec.$table 覆盖全部字段$suffix');
  }

  // ---- 4. 表名常量与 switch 分支 ----
  final RegExp constRe = RegExp("static const String (\\w+) = '(\\w+)';");
  final Set<String> constants = <String>{};
  for (final RegExpMatch m in constRe.allMatches(codecSrc)) {
    constants.add(m.group(2)!);
  }
  check(constants.length >= 12,
      'SyncTables 至少定义 12 个表名常量，实际 ${constants.length}');

  for (final String table in sortedTables) {
    final String snake = _snakeCase(table);
    check(constants.contains(snake), 'SyncTables 含表名常量 $snake（$table）');
  }

  final int branches =
      RegExp('case SyncTables\\.\\w+:').allMatches(codecSrc).length;
  check(branches == 12,
      'RecordCodec.decode 有 12 个 switch 分支，实际 $branches');
}

/// 类名 → 蛇形表名：LendRecords → lend_records
String _snakeCase(String name) => name
    .replaceAllMapped(
      RegExp('([a-z0-9])([A-Z])'),
      (Match m) => '${m.group(1)}_${m.group(2)}',
    )
    .toLowerCase();

/// 同步协议的 Dart 侧序列化。
///
/// 客户端 → 后端走 JSON：SyncOp 的 [opType] 必须是枚举名（字符串），
/// 不是下标，否则后端 switch 会匹配不到。这里验证往返不丢字段、枚举正确。
void _checkSyncProtocol() {
  final SyncOp op = SyncOp(
    tableName: 'transactions',
    recordId: 'abc',
    opType: SyncOpType.update,
    updatedAt: 123456,
    payload: <String, Object?>{'amountMinor': 1},
  );
  final Map<String, Object?> json = op.toJson();
  check(json['op'] == 'update', 'SyncOp.opType 序列化为枚举名字符串');
  check(json['table'] == 'transactions' && json['id'] == 'abc', 'SyncOp 基本字段');

  final SyncOp round = SyncOp.fromJson(json);
  check(
    round.tableName == 'transactions' &&
        round.recordId == 'abc' &&
        round.opType == SyncOpType.update &&
        round.updatedAt == 123456,
    'SyncOp JSON 往返一致',
  );

  // RemoteRecord.fromJson 对缺省字段要有安全兜底（后端可能不返回 payload）
  final RemoteRecord record = RemoteRecord.fromJson(<String, Object?>{
    'table': 'accounts',
    'id': 'x',
    'updatedAt': 9,
  });
  check(record.deleted == false, 'RemoteRecord deleted 缺省为 false');
  check(record.payload.isEmpty, 'RemoteRecord payload 缺省为空');

  final RemoteRecord deleted = RemoteRecord.fromJson(<String, Object?>{
    'table': 'accounts',
    'id': 'x',
    'updatedAt': 9,
    'deleted': true,
    'payload': <String, Object?>{'name': '现金'},
  });
  check(deleted.deleted == true, 'RemoteRecord deleted 可反序列化');
  check(deleted.payload['name'] == '现金', 'RemoteRecord payload 为 Map');
}

/// 云同步配置模型的不变量。
///
/// 端点/令牌的**格式校验**（https 前缀）在 UI 层做，模型层只关心
/// 「开关 + 两端点齐备 ⇒ 可同步」这一组合逻辑。
void _checkSyncSettings() {
  const SyncSettings empty = SyncSettings();
  check(!empty.enabled, '默认未启用');
  check(!empty.isConfigured, '默认未配置端点与令牌');
  check(!empty.canSync, '默认不可同步');
  check(empty.blockedReason != null, '未启用给出原因提示（而非干瘪的失败）');

  final SyncSettings configured = empty.copyWith(
    enabled: true,
    baseUrl: 'https://pocket-ledger.x.workers.dev',
    token: 'tok',
  );
  check(configured.canSync, '端点 + 令牌齐备即可同步');
  check(configured.blockedReason == null, '就绪时无阻塞原因');

  check(
    empty.copyWith(enabled: true, baseUrl: 'https://x.dev').blockedReason != null,
    '缺令牌时仍提示未配置',
  );
  check(
    empty.copyWith(enabled: true, token: 'tok').blockedReason != null,
    '缺端点时仍提示未配置',
  );
}
