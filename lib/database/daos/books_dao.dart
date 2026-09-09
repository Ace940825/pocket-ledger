import 'package:drift/drift.dart';

import '../app_database.dart';

part 'books_dao.g.dart';

/// 账本数据访问
@DriftAccessor(tables: <Type>[Books])
class BooksDao extends DatabaseAccessor<AppDatabase> with _$BooksDaoMixin {
  BooksDao(super.attachedDatabase);

  Stream<List<Book>> watchAll() {
    return (select(books)
          ..where(($BooksTable tbl) => tbl.deleted.equals(false))
          ..orderBy([
            ($BooksTable tbl) => OrderingTerm.asc(tbl.sortOrder),
          ]))
        .watch();
  }

  Future<Book?> getById(String id) {
    return (select(books)..where(($BooksTable tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> insertBook(BooksCompanion companion) {
    return into(books).insert(companion);
  }

  Future<bool> updateBook(BooksCompanion companion) {
    return update(books).replace(companion);
  }

  Future<int> softDelete(String id, int updatedAt) {
    return (update(books)..where(($BooksTable tbl) => tbl.id.equals(id))).write(
      BooksCompanion(
        deleted: const Value<bool>(true),
        dirty: const Value<bool>(true),
        updatedAt: Value<int>(updatedAt),
      ),
    );
  }
}
