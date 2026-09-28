// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tags_dao.dart';

// ignore_for_file: type=lint
mixin _$TagsDaoMixin on DatabaseAccessor<AppDatabase> {
  $TagCategoriesTable get tagCategories => attachedDatabase.tagCategories;
  $TagsTable get tags => attachedDatabase.tags;
  TagsDaoManager get managers => TagsDaoManager(this);
}

class TagsDaoManager {
  final _$TagsDaoMixin _db;
  TagsDaoManager(this._db);
  $$TagCategoriesTableTableManager get tagCategories =>
      $$TagCategoriesTableTableManager(_db.attachedDatabase, _db.tagCategories);
  $$TagsTableTableManager get tags =>
      $$TagsTableTableManager(_db.attachedDatabase, _db.tags);
}
