import 'package:drift/drift.dart';

import '../../../../database/app_database.dart';
import '../../../../domain/enums.dart';

/// 行情候选（基金/币元数据），来自第三方接口、缓存于本地 [security_meta] 表，
/// 支撑新建持仓的自动补全（本地查、秒级、离线可用）。
class SecurityCandidate {
  const SecurityCandidate({
    required this.symbol,
    required this.name,
    required this.type,
  });

  final String symbol;
  final String name;
  final InvestmentType type;
}

/// 行情候选库的本地仓储（原生 SQL 访问，表由 [AppDatabase._ensureSecurityMetaTable]
/// 创建，不参与 drift 代码生成）。
class SecurityMetaRepository {
  const SecurityMetaRepository(this._db);

  final AppDatabase _db;

  /// 确保某品种的候选库已加载且未过期；过期或为空时调用 [fetch] 重新拉取并整表重写。
  ///
  /// 整表重写（先删后插）比逐条 upsert 数千行更稳，且候选库本就是「全量覆盖」语义。
  Future<void> ensureLoaded(
    InvestmentType type,
    Future<List<SecurityCandidate>> Function() fetch, {
    Duration maxAge = const Duration(days: 7),
  }) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final List<QueryRow> rows = await _db.customSelect(
      'SELECT MAX(updated_at) AS m FROM security_meta WHERE type = ?',
      variables: <Variable<Object>>[Variable<int>(type.index)],
    ).get();
    final int? latest = rows.first.read<int?>('m');
    if (latest != null && now - latest < maxAge.inMilliseconds) return;

    final List<SecurityCandidate> list = await fetch();
    await _db.transaction(() async {
      await _db.customStatement(
        'DELETE FROM security_meta WHERE type = ?',
        <Variable<Object>>[Variable<int>(type.index)],
      );
      for (final SecurityCandidate c in list) {
      await _db.customStatement(
        'INSERT OR REPLACE INTO security_meta (symbol, name, type, updated_at) '
        'VALUES (?, ?, ?, ?)',
        <Variable<Object>>[
          Variable<String>(c.symbol),
          Variable<String>(c.name),
          Variable<int>(type.index),
          Variable<int>(now),
        ],
      );
      }
    });
  }

  /// 按关键词搜索候选：代码前缀优先、名称包含兜底，最多 [limit] 条。
  Future<List<SecurityCandidate>> search(
    String query, {
    InvestmentType? type,
    int limit = 8,
  }) async {
    final String q = query.trim();
    if (q.isEmpty) return const <SecurityCandidate>[];
    final String prefix = '${_escapeLike(q)}%';
    final String contains = '%${_escapeLike(q)}%';
    final List<Variable<Object>> vars = <Variable<Object>>[];
    final String base =
        'SELECT symbol, name, type FROM security_meta WHERE ';
    final String where;
    if (type != null) {
      where =
          'type = ? AND (symbol LIKE ? ESCAPE \'\\\' OR name LIKE ? ESCAPE \'\\\')';
      vars
        ..add(Variable<int>(type.index))
        ..add(Variable<String>(prefix))
        ..add(Variable<String>(contains));
    } else {
      where = '(symbol LIKE ? ESCAPE \'\\\' OR name LIKE ? ESCAPE \'\\\')';
      vars
        ..add(Variable<String>(prefix))
        ..add(Variable<String>(contains));
    }
    final String order =
        'ORDER BY (CASE WHEN symbol LIKE ? ESCAPE \'\\\' THEN 0 ELSE 1 END) '
        'LIMIT $limit';
    vars.add(Variable<String>(prefix));

    final List<QueryRow> rows = await _db.customSelect(
      '$base$where$order',
      variables: vars,
    ).get();
    return rows.map((QueryRow r) {
      return SecurityCandidate(
        symbol: r.read<String>('symbol'),
        name: r.read<String>('name'),
        type: InvestmentType.values[r.read<int>('type')],
      );
    }).toList();
  }

  /// 转义 LIKE 通配符，避免用户输入的 % / _ 被当作模式。
  String _escapeLike(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
}
