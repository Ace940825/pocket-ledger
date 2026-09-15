import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../database/app_database.dart';

/// 记一笔模板仓储（本地，不参与云端同步）。
///
/// 模板只沉淀「账户 + 分类 + 备注 + 标签 + 开关」这一类常用组合，
/// 金额每次使用仍需手填，因此不写入 Transactions，也不入同步队列。
class RecordTemplateRepository {
  const RecordTemplateRepository(this._db);

  final AppDatabase _db;

  Stream<List<RecordTemplate>> watchAll(String bookId) {
    return (_db.select(_db.recordTemplates)
          ..where((RecordTemplates t) => t.bookId.equals(bookId))
          ..orderBy(
            <OrderClauseGenerator<RecordTemplates>>[
              (RecordTemplates t) => OrderingTerm.desc(t.createdAt),
            ],
          ))
        .watch();
  }

  Future<String> add({
    required String bookId,
    required String name,
    required int tabIndex,
    String? accountId,
    String? categoryId,
    String? note,
    String? tags,
    bool excludeFromStats = false,
    bool excludeFromBudget = false,
    bool isReimbursable = false,
  }) {
    if (name.trim().isEmpty) {
      throw const FormatException('模板名称不能为空');
    }
    final String id = const Uuid().v7();
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    return _db
        .into(_db.recordTemplates)
        .insertReturning(
          RecordTemplatesCompanion(
            id: Value<String>(id),
            bookId: Value<String>(bookId),
            name: Value<String>(name.trim()),
            tabIndex: Value<int>(tabIndex),
            accountId: Value<String?>(accountId),
            categoryId: Value<String?>(categoryId),
            note: Value<String?>(note),
            tags: Value<String?>(tags),
            excludeFromStats: Value<bool>(excludeFromStats),
            excludeFromBudget: Value<bool>(excludeFromBudget),
            isReimbursable: Value<bool>(isReimbursable),
            createdAt: Value<int>(now),
          ),
        )
        .then((RecordTemplate t) => t.id);
  }

  Future<void> remove(String id) {
    return (_db.delete(_db.recordTemplates)
          ..where((RecordTemplates t) => t.id.equals(id)))
        .go();
  }
}
