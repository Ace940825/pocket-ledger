// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $BooksTable extends Books with TableInfo<$BooksTable, Book> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
      'dirty', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("dirty" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('CNY'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        updatedAt,
        deleted,
        dirty,
        syncedAt,
        id,
        name,
        currency,
        createdAt,
        sortOrder
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(Insertable<Book> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('dirty')) {
      context.handle(
          _dirtyMeta, dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Book map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Book(
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      dirty: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}dirty'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}synced_at']),
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
    );
  }

  @override
  $BooksTable createAlias(String alias) {
    return $BooksTable(attachedDatabase, alias);
  }
}

class Book extends DataClass implements Insertable<Book> {
  final int updatedAt;
  final bool deleted;
  final bool dirty;
  final int? syncedAt;
  final String id;
  final String name;
  final String currency;
  final int createdAt;
  final int sortOrder;
  const Book(
      {required this.updatedAt,
      required this.deleted,
      required this.dirty,
      this.syncedAt,
      required this.id,
      required this.name,
      required this.currency,
      required this.createdAt,
      required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<int>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<int>(syncedAt);
    }
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['currency'] = Variable<String>(currency);
    map['created_at'] = Variable<int>(createdAt);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  BooksCompanion toCompanion(bool nullToAbsent) {
    return BooksCompanion(
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      dirty: Value(dirty),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      id: Value(id),
      name: Value(name),
      currency: Value(currency),
      createdAt: Value(createdAt),
      sortOrder: Value(sortOrder),
    );
  }

  factory Book.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Book(
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      syncedAt: serializer.fromJson<int?>(json['syncedAt']),
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      currency: serializer.fromJson<String>(json['currency']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'syncedAt': serializer.toJson<int?>(syncedAt),
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'currency': serializer.toJson<String>(currency),
      'createdAt': serializer.toJson<int>(createdAt),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  Book copyWith(
          {int? updatedAt,
          bool? deleted,
          bool? dirty,
          Value<int?> syncedAt = const Value.absent(),
          String? id,
          String? name,
          String? currency,
          int? createdAt,
          int? sortOrder}) =>
      Book(
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        dirty: dirty ?? this.dirty,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
        id: id ?? this.id,
        name: name ?? this.name,
        currency: currency ?? this.currency,
        createdAt: createdAt ?? this.createdAt,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  Book copyWithCompanion(BooksCompanion data) {
    return Book(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      currency: data.currency.present ? data.currency.value : this.currency,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Book(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('currency: $currency, ')
          ..write('createdAt: $createdAt, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(updatedAt, deleted, dirty, syncedAt, id, name,
      currency, createdAt, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Book &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.syncedAt == this.syncedAt &&
          other.id == this.id &&
          other.name == this.name &&
          other.currency == this.currency &&
          other.createdAt == this.createdAt &&
          other.sortOrder == this.sortOrder);
}

class BooksCompanion extends UpdateCompanion<Book> {
  final Value<int> updatedAt;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<int?> syncedAt;
  final Value<String> id;
  final Value<String> name;
  final Value<String> currency;
  final Value<int> createdAt;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const BooksCompanion({
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.currency = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BooksCompanion.insert({
    required int updatedAt,
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    required String id,
    required String name,
    this.currency = const Value.absent(),
    required int createdAt,
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : updatedAt = Value(updatedAt),
        id = Value(id),
        name = Value(name),
        createdAt = Value(createdAt);
  static Insertable<Book> custom({
    Expression<int>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<int>? syncedAt,
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? currency,
    Expression<int>? createdAt,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (currency != null) 'currency': currency,
      if (createdAt != null) 'created_at': createdAt,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BooksCompanion copyWith(
      {Value<int>? updatedAt,
      Value<bool>? deleted,
      Value<bool>? dirty,
      Value<int?>? syncedAt,
      Value<String>? id,
      Value<String>? name,
      Value<String>? currency,
      Value<int>? createdAt,
      Value<int>? sortOrder,
      Value<int>? rowid}) {
    return BooksCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      syncedAt: syncedAt ?? this.syncedAt,
      id: id ?? this.id,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BooksCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('currency: $currency, ')
          ..write('createdAt: $createdAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AccountsTable extends Accounts with TableInfo<$AccountsTable, Account> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
      'dirty', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("dirty" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
      'book_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumnWithTypeConverter<AccountType, int> type =
      GeneratedColumn<int>('type', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<AccountType>($AccountsTable.$convertertype);
  static const VerificationMeta _balanceMinorMeta =
      const VerificationMeta('balanceMinor');
  @override
  late final GeneratedColumn<int> balanceMinor = GeneratedColumn<int>(
      'balance_minor', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('CNY'));
  static const VerificationMeta _iconKeyMeta =
      const VerificationMeta('iconKey');
  @override
  late final GeneratedColumn<String> iconKey = GeneratedColumn<String>(
      'icon_key', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _colorValueMeta =
      const VerificationMeta('colorValue');
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
      'color_value', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _creditLimitMinorMeta =
      const VerificationMeta('creditLimitMinor');
  @override
  late final GeneratedColumn<int> creditLimitMinor = GeneratedColumn<int>(
      'credit_limit_minor', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _billingDayMeta =
      const VerificationMeta('billingDay');
  @override
  late final GeneratedColumn<int> billingDay = GeneratedColumn<int>(
      'billing_day', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _dueDayMeta = const VerificationMeta('dueDay');
  @override
  late final GeneratedColumn<int> dueDay = GeneratedColumn<int>(
      'due_day', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _isArchivedMeta =
      const VerificationMeta('isArchived');
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
      'is_archived', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_archived" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        updatedAt,
        deleted,
        dirty,
        syncedAt,
        id,
        bookId,
        name,
        type,
        balanceMinor,
        currency,
        iconKey,
        colorValue,
        creditLimitMinor,
        billingDay,
        dueDay,
        isArchived,
        sortOrder
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(Insertable<Account> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('dirty')) {
      context.handle(
          _dirtyMeta, dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    context.handle(_typeMeta, const VerificationResult.success());
    if (data.containsKey('balance_minor')) {
      context.handle(
          _balanceMinorMeta,
          balanceMinor.isAcceptableOrUnknown(
              data['balance_minor']!, _balanceMinorMeta));
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('icon_key')) {
      context.handle(_iconKeyMeta,
          iconKey.isAcceptableOrUnknown(data['icon_key']!, _iconKeyMeta));
    }
    if (data.containsKey('color_value')) {
      context.handle(
          _colorValueMeta,
          colorValue.isAcceptableOrUnknown(
              data['color_value']!, _colorValueMeta));
    }
    if (data.containsKey('credit_limit_minor')) {
      context.handle(
          _creditLimitMinorMeta,
          creditLimitMinor.isAcceptableOrUnknown(
              data['credit_limit_minor']!, _creditLimitMinorMeta));
    }
    if (data.containsKey('billing_day')) {
      context.handle(
          _billingDayMeta,
          billingDay.isAcceptableOrUnknown(
              data['billing_day']!, _billingDayMeta));
    }
    if (data.containsKey('due_day')) {
      context.handle(_dueDayMeta,
          dueDay.isAcceptableOrUnknown(data['due_day']!, _dueDayMeta));
    }
    if (data.containsKey('is_archived')) {
      context.handle(
          _isArchivedMeta,
          isArchived.isAcceptableOrUnknown(
              data['is_archived']!, _isArchivedMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      dirty: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}dirty'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}synced_at']),
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      type: $AccountsTable.$convertertype.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}type'])!),
      balanceMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}balance_minor'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      iconKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon_key']),
      colorValue: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}color_value']),
      creditLimitMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}credit_limit_minor']),
      billingDay: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}billing_day']),
      dueDay: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}due_day']),
      isArchived: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_archived'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AccountType, int, int> $convertertype =
      const EnumIndexConverter<AccountType>(AccountType.values);
}

class Account extends DataClass implements Insertable<Account> {
  final int updatedAt;
  final bool deleted;
  final bool dirty;
  final int? syncedAt;
  final String id;
  final String bookId;
  final String name;
  final AccountType type;

  /// 余额（分）。信用卡为负数表示欠款。
  final int balanceMinor;
  final String currency;

  /// 图标与颜色以字符串 / 整数存储，避免引入二进制资源依赖
  final String? iconKey;
  final int? colorValue;

  /// 信用卡额度（分），仅信用卡账户有意义
  final int? creditLimitMinor;

  /// 信用卡账单日 / 还款日（1-31）
  final int? billingDay;
  final int? dueDay;
  final bool isArchived;
  final int sortOrder;
  const Account(
      {required this.updatedAt,
      required this.deleted,
      required this.dirty,
      this.syncedAt,
      required this.id,
      required this.bookId,
      required this.name,
      required this.type,
      required this.balanceMinor,
      required this.currency,
      this.iconKey,
      this.colorValue,
      this.creditLimitMinor,
      this.billingDay,
      this.dueDay,
      required this.isArchived,
      required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<int>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<int>(syncedAt);
    }
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['name'] = Variable<String>(name);
    {
      map['type'] = Variable<int>($AccountsTable.$convertertype.toSql(type));
    }
    map['balance_minor'] = Variable<int>(balanceMinor);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || iconKey != null) {
      map['icon_key'] = Variable<String>(iconKey);
    }
    if (!nullToAbsent || colorValue != null) {
      map['color_value'] = Variable<int>(colorValue);
    }
    if (!nullToAbsent || creditLimitMinor != null) {
      map['credit_limit_minor'] = Variable<int>(creditLimitMinor);
    }
    if (!nullToAbsent || billingDay != null) {
      map['billing_day'] = Variable<int>(billingDay);
    }
    if (!nullToAbsent || dueDay != null) {
      map['due_day'] = Variable<int>(dueDay);
    }
    map['is_archived'] = Variable<bool>(isArchived);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      dirty: Value(dirty),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      id: Value(id),
      bookId: Value(bookId),
      name: Value(name),
      type: Value(type),
      balanceMinor: Value(balanceMinor),
      currency: Value(currency),
      iconKey: iconKey == null && nullToAbsent
          ? const Value.absent()
          : Value(iconKey),
      colorValue: colorValue == null && nullToAbsent
          ? const Value.absent()
          : Value(colorValue),
      creditLimitMinor: creditLimitMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(creditLimitMinor),
      billingDay: billingDay == null && nullToAbsent
          ? const Value.absent()
          : Value(billingDay),
      dueDay:
          dueDay == null && nullToAbsent ? const Value.absent() : Value(dueDay),
      isArchived: Value(isArchived),
      sortOrder: Value(sortOrder),
    );
  }

  factory Account.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      syncedAt: serializer.fromJson<int?>(json['syncedAt']),
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      name: serializer.fromJson<String>(json['name']),
      type: $AccountsTable.$convertertype
          .fromJson(serializer.fromJson<int>(json['type'])),
      balanceMinor: serializer.fromJson<int>(json['balanceMinor']),
      currency: serializer.fromJson<String>(json['currency']),
      iconKey: serializer.fromJson<String?>(json['iconKey']),
      colorValue: serializer.fromJson<int?>(json['colorValue']),
      creditLimitMinor: serializer.fromJson<int?>(json['creditLimitMinor']),
      billingDay: serializer.fromJson<int?>(json['billingDay']),
      dueDay: serializer.fromJson<int?>(json['dueDay']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'syncedAt': serializer.toJson<int?>(syncedAt),
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'name': serializer.toJson<String>(name),
      'type':
          serializer.toJson<int>($AccountsTable.$convertertype.toJson(type)),
      'balanceMinor': serializer.toJson<int>(balanceMinor),
      'currency': serializer.toJson<String>(currency),
      'iconKey': serializer.toJson<String?>(iconKey),
      'colorValue': serializer.toJson<int?>(colorValue),
      'creditLimitMinor': serializer.toJson<int?>(creditLimitMinor),
      'billingDay': serializer.toJson<int?>(billingDay),
      'dueDay': serializer.toJson<int?>(dueDay),
      'isArchived': serializer.toJson<bool>(isArchived),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  Account copyWith(
          {int? updatedAt,
          bool? deleted,
          bool? dirty,
          Value<int?> syncedAt = const Value.absent(),
          String? id,
          String? bookId,
          String? name,
          AccountType? type,
          int? balanceMinor,
          String? currency,
          Value<String?> iconKey = const Value.absent(),
          Value<int?> colorValue = const Value.absent(),
          Value<int?> creditLimitMinor = const Value.absent(),
          Value<int?> billingDay = const Value.absent(),
          Value<int?> dueDay = const Value.absent(),
          bool? isArchived,
          int? sortOrder}) =>
      Account(
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        dirty: dirty ?? this.dirty,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        name: name ?? this.name,
        type: type ?? this.type,
        balanceMinor: balanceMinor ?? this.balanceMinor,
        currency: currency ?? this.currency,
        iconKey: iconKey.present ? iconKey.value : this.iconKey,
        colorValue: colorValue.present ? colorValue.value : this.colorValue,
        creditLimitMinor: creditLimitMinor.present
            ? creditLimitMinor.value
            : this.creditLimitMinor,
        billingDay: billingDay.present ? billingDay.value : this.billingDay,
        dueDay: dueDay.present ? dueDay.value : this.dueDay,
        isArchived: isArchived ?? this.isArchived,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      balanceMinor: data.balanceMinor.present
          ? data.balanceMinor.value
          : this.balanceMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      iconKey: data.iconKey.present ? data.iconKey.value : this.iconKey,
      colorValue:
          data.colorValue.present ? data.colorValue.value : this.colorValue,
      creditLimitMinor: data.creditLimitMinor.present
          ? data.creditLimitMinor.value
          : this.creditLimitMinor,
      billingDay:
          data.billingDay.present ? data.billingDay.value : this.billingDay,
      dueDay: data.dueDay.present ? data.dueDay.value : this.dueDay,
      isArchived:
          data.isArchived.present ? data.isArchived.value : this.isArchived,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('balanceMinor: $balanceMinor, ')
          ..write('currency: $currency, ')
          ..write('iconKey: $iconKey, ')
          ..write('colorValue: $colorValue, ')
          ..write('creditLimitMinor: $creditLimitMinor, ')
          ..write('billingDay: $billingDay, ')
          ..write('dueDay: $dueDay, ')
          ..write('isArchived: $isArchived, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      updatedAt,
      deleted,
      dirty,
      syncedAt,
      id,
      bookId,
      name,
      type,
      balanceMinor,
      currency,
      iconKey,
      colorValue,
      creditLimitMinor,
      billingDay,
      dueDay,
      isArchived,
      sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.syncedAt == this.syncedAt &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.name == this.name &&
          other.type == this.type &&
          other.balanceMinor == this.balanceMinor &&
          other.currency == this.currency &&
          other.iconKey == this.iconKey &&
          other.colorValue == this.colorValue &&
          other.creditLimitMinor == this.creditLimitMinor &&
          other.billingDay == this.billingDay &&
          other.dueDay == this.dueDay &&
          other.isArchived == this.isArchived &&
          other.sortOrder == this.sortOrder);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<int> updatedAt;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<int?> syncedAt;
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> name;
  final Value<AccountType> type;
  final Value<int> balanceMinor;
  final Value<String> currency;
  final Value<String?> iconKey;
  final Value<int?> colorValue;
  final Value<int?> creditLimitMinor;
  final Value<int?> billingDay;
  final Value<int?> dueDay;
  final Value<bool> isArchived;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const AccountsCompanion({
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.balanceMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.iconKey = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.creditLimitMinor = const Value.absent(),
    this.billingDay = const Value.absent(),
    this.dueDay = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsCompanion.insert({
    required int updatedAt,
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    required String id,
    required String bookId,
    required String name,
    required AccountType type,
    this.balanceMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.iconKey = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.creditLimitMinor = const Value.absent(),
    this.billingDay = const Value.absent(),
    this.dueDay = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : updatedAt = Value(updatedAt),
        id = Value(id),
        bookId = Value(bookId),
        name = Value(name),
        type = Value(type);
  static Insertable<Account> custom({
    Expression<int>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<int>? syncedAt,
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? name,
    Expression<int>? type,
    Expression<int>? balanceMinor,
    Expression<String>? currency,
    Expression<String>? iconKey,
    Expression<int>? colorValue,
    Expression<int>? creditLimitMinor,
    Expression<int>? billingDay,
    Expression<int>? dueDay,
    Expression<bool>? isArchived,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (balanceMinor != null) 'balance_minor': balanceMinor,
      if (currency != null) 'currency': currency,
      if (iconKey != null) 'icon_key': iconKey,
      if (colorValue != null) 'color_value': colorValue,
      if (creditLimitMinor != null) 'credit_limit_minor': creditLimitMinor,
      if (billingDay != null) 'billing_day': billingDay,
      if (dueDay != null) 'due_day': dueDay,
      if (isArchived != null) 'is_archived': isArchived,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsCompanion copyWith(
      {Value<int>? updatedAt,
      Value<bool>? deleted,
      Value<bool>? dirty,
      Value<int?>? syncedAt,
      Value<String>? id,
      Value<String>? bookId,
      Value<String>? name,
      Value<AccountType>? type,
      Value<int>? balanceMinor,
      Value<String>? currency,
      Value<String?>? iconKey,
      Value<int?>? colorValue,
      Value<int?>? creditLimitMinor,
      Value<int?>? billingDay,
      Value<int?>? dueDay,
      Value<bool>? isArchived,
      Value<int>? sortOrder,
      Value<int>? rowid}) {
    return AccountsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      syncedAt: syncedAt ?? this.syncedAt,
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      name: name ?? this.name,
      type: type ?? this.type,
      balanceMinor: balanceMinor ?? this.balanceMinor,
      currency: currency ?? this.currency,
      iconKey: iconKey ?? this.iconKey,
      colorValue: colorValue ?? this.colorValue,
      creditLimitMinor: creditLimitMinor ?? this.creditLimitMinor,
      billingDay: billingDay ?? this.billingDay,
      dueDay: dueDay ?? this.dueDay,
      isArchived: isArchived ?? this.isArchived,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] =
          Variable<int>($AccountsTable.$convertertype.toSql(type.value));
    }
    if (balanceMinor.present) {
      map['balance_minor'] = Variable<int>(balanceMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (iconKey.present) {
      map['icon_key'] = Variable<String>(iconKey.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (creditLimitMinor.present) {
      map['credit_limit_minor'] = Variable<int>(creditLimitMinor.value);
    }
    if (billingDay.present) {
      map['billing_day'] = Variable<int>(billingDay.value);
    }
    if (dueDay.present) {
      map['due_day'] = Variable<int>(dueDay.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('balanceMinor: $balanceMinor, ')
          ..write('currency: $currency, ')
          ..write('iconKey: $iconKey, ')
          ..write('colorValue: $colorValue, ')
          ..write('creditLimitMinor: $creditLimitMinor, ')
          ..write('billingDay: $billingDay, ')
          ..write('dueDay: $dueDay, ')
          ..write('isArchived: $isArchived, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
      'dirty', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("dirty" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
      'book_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumnWithTypeConverter<CategoryType, int> type =
      GeneratedColumn<int>('type', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<CategoryType>($CategoriesTable.$convertertype);
  static const VerificationMeta _parentIdMeta =
      const VerificationMeta('parentId');
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
      'parent_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _iconKeyMeta =
      const VerificationMeta('iconKey');
  @override
  late final GeneratedColumn<String> iconKey = GeneratedColumn<String>(
      'icon_key', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _colorValueMeta =
      const VerificationMeta('colorValue');
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
      'color_value', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _isArchivedMeta =
      const VerificationMeta('isArchived');
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
      'is_archived', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_archived" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        updatedAt,
        deleted,
        dirty,
        syncedAt,
        id,
        bookId,
        name,
        type,
        parentId,
        iconKey,
        colorValue,
        sortOrder,
        isArchived
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(Insertable<Category> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('dirty')) {
      context.handle(
          _dirtyMeta, dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    context.handle(_typeMeta, const VerificationResult.success());
    if (data.containsKey('parent_id')) {
      context.handle(_parentIdMeta,
          parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta));
    }
    if (data.containsKey('icon_key')) {
      context.handle(_iconKeyMeta,
          iconKey.isAcceptableOrUnknown(data['icon_key']!, _iconKeyMeta));
    }
    if (data.containsKey('color_value')) {
      context.handle(
          _colorValueMeta,
          colorValue.isAcceptableOrUnknown(
              data['color_value']!, _colorValueMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('is_archived')) {
      context.handle(
          _isArchivedMeta,
          isArchived.isAcceptableOrUnknown(
              data['is_archived']!, _isArchivedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      dirty: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}dirty'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}synced_at']),
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      type: $CategoriesTable.$convertertype.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}type'])!),
      parentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_id']),
      iconKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon_key']),
      colorValue: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}color_value']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      isArchived: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_archived'])!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CategoryType, int, int> $convertertype =
      const EnumIndexConverter<CategoryType>(CategoryType.values);
}

class Category extends DataClass implements Insertable<Category> {
  final int updatedAt;
  final bool deleted;
  final bool dirty;
  final int? syncedAt;
  final String id;
  final String bookId;
  final String name;
  final CategoryType type;
  final String? parentId;
  final String? iconKey;
  final int? colorValue;
  final int sortOrder;
  final bool isArchived;
  const Category(
      {required this.updatedAt,
      required this.deleted,
      required this.dirty,
      this.syncedAt,
      required this.id,
      required this.bookId,
      required this.name,
      required this.type,
      this.parentId,
      this.iconKey,
      this.colorValue,
      required this.sortOrder,
      required this.isArchived});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<int>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<int>(syncedAt);
    }
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['name'] = Variable<String>(name);
    {
      map['type'] = Variable<int>($CategoriesTable.$convertertype.toSql(type));
    }
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    if (!nullToAbsent || iconKey != null) {
      map['icon_key'] = Variable<String>(iconKey);
    }
    if (!nullToAbsent || colorValue != null) {
      map['color_value'] = Variable<int>(colorValue);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_archived'] = Variable<bool>(isArchived);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      dirty: Value(dirty),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      id: Value(id),
      bookId: Value(bookId),
      name: Value(name),
      type: Value(type),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      iconKey: iconKey == null && nullToAbsent
          ? const Value.absent()
          : Value(iconKey),
      colorValue: colorValue == null && nullToAbsent
          ? const Value.absent()
          : Value(colorValue),
      sortOrder: Value(sortOrder),
      isArchived: Value(isArchived),
    );
  }

  factory Category.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      syncedAt: serializer.fromJson<int?>(json['syncedAt']),
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      name: serializer.fromJson<String>(json['name']),
      type: $CategoriesTable.$convertertype
          .fromJson(serializer.fromJson<int>(json['type'])),
      parentId: serializer.fromJson<String?>(json['parentId']),
      iconKey: serializer.fromJson<String?>(json['iconKey']),
      colorValue: serializer.fromJson<int?>(json['colorValue']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'syncedAt': serializer.toJson<int?>(syncedAt),
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'name': serializer.toJson<String>(name),
      'type':
          serializer.toJson<int>($CategoriesTable.$convertertype.toJson(type)),
      'parentId': serializer.toJson<String?>(parentId),
      'iconKey': serializer.toJson<String?>(iconKey),
      'colorValue': serializer.toJson<int?>(colorValue),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isArchived': serializer.toJson<bool>(isArchived),
    };
  }

  Category copyWith(
          {int? updatedAt,
          bool? deleted,
          bool? dirty,
          Value<int?> syncedAt = const Value.absent(),
          String? id,
          String? bookId,
          String? name,
          CategoryType? type,
          Value<String?> parentId = const Value.absent(),
          Value<String?> iconKey = const Value.absent(),
          Value<int?> colorValue = const Value.absent(),
          int? sortOrder,
          bool? isArchived}) =>
      Category(
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        dirty: dirty ?? this.dirty,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        name: name ?? this.name,
        type: type ?? this.type,
        parentId: parentId.present ? parentId.value : this.parentId,
        iconKey: iconKey.present ? iconKey.value : this.iconKey,
        colorValue: colorValue.present ? colorValue.value : this.colorValue,
        sortOrder: sortOrder ?? this.sortOrder,
        isArchived: isArchived ?? this.isArchived,
      );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      iconKey: data.iconKey.present ? data.iconKey.value : this.iconKey,
      colorValue:
          data.colorValue.present ? data.colorValue.value : this.colorValue,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isArchived:
          data.isArchived.present ? data.isArchived.value : this.isArchived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('parentId: $parentId, ')
          ..write('iconKey: $iconKey, ')
          ..write('colorValue: $colorValue, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isArchived: $isArchived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(updatedAt, deleted, dirty, syncedAt, id,
      bookId, name, type, parentId, iconKey, colorValue, sortOrder, isArchived);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.syncedAt == this.syncedAt &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.name == this.name &&
          other.type == this.type &&
          other.parentId == this.parentId &&
          other.iconKey == this.iconKey &&
          other.colorValue == this.colorValue &&
          other.sortOrder == this.sortOrder &&
          other.isArchived == this.isArchived);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<int> updatedAt;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<int?> syncedAt;
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> name;
  final Value<CategoryType> type;
  final Value<String?> parentId;
  final Value<String?> iconKey;
  final Value<int?> colorValue;
  final Value<int> sortOrder;
  final Value<bool> isArchived;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.parentId = const Value.absent(),
    this.iconKey = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required int updatedAt,
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    required String id,
    required String bookId,
    required String name,
    required CategoryType type,
    this.parentId = const Value.absent(),
    this.iconKey = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : updatedAt = Value(updatedAt),
        id = Value(id),
        bookId = Value(bookId),
        name = Value(name),
        type = Value(type);
  static Insertable<Category> custom({
    Expression<int>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<int>? syncedAt,
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? name,
    Expression<int>? type,
    Expression<String>? parentId,
    Expression<String>? iconKey,
    Expression<int>? colorValue,
    Expression<int>? sortOrder,
    Expression<bool>? isArchived,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (parentId != null) 'parent_id': parentId,
      if (iconKey != null) 'icon_key': iconKey,
      if (colorValue != null) 'color_value': colorValue,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isArchived != null) 'is_archived': isArchived,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith(
      {Value<int>? updatedAt,
      Value<bool>? deleted,
      Value<bool>? dirty,
      Value<int?>? syncedAt,
      Value<String>? id,
      Value<String>? bookId,
      Value<String>? name,
      Value<CategoryType>? type,
      Value<String?>? parentId,
      Value<String?>? iconKey,
      Value<int?>? colorValue,
      Value<int>? sortOrder,
      Value<bool>? isArchived,
      Value<int>? rowid}) {
    return CategoriesCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      syncedAt: syncedAt ?? this.syncedAt,
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      name: name ?? this.name,
      type: type ?? this.type,
      parentId: parentId ?? this.parentId,
      iconKey: iconKey ?? this.iconKey,
      colorValue: colorValue ?? this.colorValue,
      sortOrder: sortOrder ?? this.sortOrder,
      isArchived: isArchived ?? this.isArchived,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] =
          Variable<int>($CategoriesTable.$convertertype.toSql(type.value));
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (iconKey.present) {
      map['icon_key'] = Variable<String>(iconKey.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('parentId: $parentId, ')
          ..write('iconKey: $iconKey, ')
          ..write('colorValue: $colorValue, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isArchived: $isArchived, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, Transaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
      'dirty', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("dirty" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
      'book_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumnWithTypeConverter<TxnType, int> type =
      GeneratedColumn<int>('type', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<TxnType>($TransactionsTable.$convertertype);
  static const VerificationMeta _amountMinorMeta =
      const VerificationMeta('amountMinor');
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
      'amount_minor', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('CNY'));
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _toAccountIdMeta =
      const VerificationMeta('toAccountId');
  @override
  late final GeneratedColumn<String> toAccountId = GeneratedColumn<String>(
      'to_account_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
      'category_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _occurredAtMeta =
      const VerificationMeta('occurredAt');
  @override
  late final GeneratedColumn<int> occurredAt = GeneratedColumn<int>(
      'occurred_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _attachmentUrlsMeta =
      const VerificationMeta('attachmentUrls');
  @override
  late final GeneratedColumn<String> attachmentUrls = GeneratedColumn<String>(
      'attachment_urls', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
      'tags', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceModuleMeta =
      const VerificationMeta('sourceModule');
  @override
  late final GeneratedColumnWithTypeConverter<SourceModule, int> sourceModule =
      GeneratedColumn<int>('source_module', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<SourceModule>(
              $TransactionsTable.$convertersourceModule);
  static const VerificationMeta _relatedIdMeta =
      const VerificationMeta('relatedId');
  @override
  late final GeneratedColumn<String> relatedId = GeneratedColumn<String>(
      'related_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _transferGroupIdMeta =
      const VerificationMeta('transferGroupId');
  @override
  late final GeneratedColumn<String> transferGroupId = GeneratedColumn<String>(
      'transfer_group_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        updatedAt,
        deleted,
        dirty,
        syncedAt,
        id,
        bookId,
        type,
        amountMinor,
        currency,
        accountId,
        toAccountId,
        categoryId,
        occurredAt,
        note,
        attachmentUrls,
        tags,
        sourceModule,
        relatedId,
        transferGroupId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(Insertable<Transaction> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('dirty')) {
      context.handle(
          _dirtyMeta, dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    context.handle(_typeMeta, const VerificationResult.success());
    if (data.containsKey('amount_minor')) {
      context.handle(
          _amountMinorMeta,
          amountMinor.isAcceptableOrUnknown(
              data['amount_minor']!, _amountMinorMeta));
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('to_account_id')) {
      context.handle(
          _toAccountIdMeta,
          toAccountId.isAcceptableOrUnknown(
              data['to_account_id']!, _toAccountIdMeta));
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
          _occurredAtMeta,
          occurredAt.isAcceptableOrUnknown(
              data['occurred_at']!, _occurredAtMeta));
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('attachment_urls')) {
      context.handle(
          _attachmentUrlsMeta,
          attachmentUrls.isAcceptableOrUnknown(
              data['attachment_urls']!, _attachmentUrlsMeta));
    }
    if (data.containsKey('tags')) {
      context.handle(
          _tagsMeta, tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta));
    }
    context.handle(_sourceModuleMeta, const VerificationResult.success());
    if (data.containsKey('related_id')) {
      context.handle(_relatedIdMeta,
          relatedId.isAcceptableOrUnknown(data['related_id']!, _relatedIdMeta));
    }
    if (data.containsKey('transfer_group_id')) {
      context.handle(
          _transferGroupIdMeta,
          transferGroupId.isAcceptableOrUnknown(
              data['transfer_group_id']!, _transferGroupIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transaction(
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      dirty: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}dirty'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}synced_at']),
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_id'])!,
      type: $TransactionsTable.$convertertype.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}type'])!),
      amountMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}amount_minor'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id'])!,
      toAccountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}to_account_id']),
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category_id']),
      occurredAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}occurred_at'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      attachmentUrls: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}attachment_urls']),
      tags: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tags']),
      sourceModule: $TransactionsTable.$convertersourceModule.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.int, data['${effectivePrefix}source_module'])!),
      relatedId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}related_id']),
      transferGroupId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}transfer_group_id']),
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TxnType, int, int> $convertertype =
      const EnumIndexConverter<TxnType>(TxnType.values);
  static JsonTypeConverter2<SourceModule, int, int> $convertersourceModule =
      const EnumIndexConverter<SourceModule>(SourceModule.values);
}

class Transaction extends DataClass implements Insertable<Transaction> {
  final int updatedAt;
  final bool deleted;
  final bool dirty;
  final int? syncedAt;
  final String id;
  final String bookId;
  final TxnType type;

  /// 金额（分），恒为正数，方向由 [type] 决定
  final int amountMinor;
  final String currency;

  /// 支出/收入账户；转账时为转出账户
  final String accountId;

  /// 转账时的转入账户，其余场景为空
  final String? toAccountId;
  final String? categoryId;

  /// 业务发生时间（UTC 毫秒）
  final int occurredAt;
  final String? note;

  /// 票据图片地址，JSON 数组字符串
  final String? attachmentUrls;

  /// 标签，JSON 数组字符串
  final String? tags;

  /// 注意：intEnum 列不能用 Constant(int) 作为默认值（类型不匹配），
  /// 因此写入时由 Companions 显式提供枚举值。
  final SourceModule sourceModule;

  /// 关联的业务记录 ID（如借还记录、分期计划）
  final String? relatedId;

  /// 同一笔转账的两条流水共享此 ID
  final String? transferGroupId;
  const Transaction(
      {required this.updatedAt,
      required this.deleted,
      required this.dirty,
      this.syncedAt,
      required this.id,
      required this.bookId,
      required this.type,
      required this.amountMinor,
      required this.currency,
      required this.accountId,
      this.toAccountId,
      this.categoryId,
      required this.occurredAt,
      this.note,
      this.attachmentUrls,
      this.tags,
      required this.sourceModule,
      this.relatedId,
      this.transferGroupId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<int>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<int>(syncedAt);
    }
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    {
      map['type'] =
          Variable<int>($TransactionsTable.$convertertype.toSql(type));
    }
    map['amount_minor'] = Variable<int>(amountMinor);
    map['currency'] = Variable<String>(currency);
    map['account_id'] = Variable<String>(accountId);
    if (!nullToAbsent || toAccountId != null) {
      map['to_account_id'] = Variable<String>(toAccountId);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['occurred_at'] = Variable<int>(occurredAt);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || attachmentUrls != null) {
      map['attachment_urls'] = Variable<String>(attachmentUrls);
    }
    if (!nullToAbsent || tags != null) {
      map['tags'] = Variable<String>(tags);
    }
    {
      map['source_module'] = Variable<int>(
          $TransactionsTable.$convertersourceModule.toSql(sourceModule));
    }
    if (!nullToAbsent || relatedId != null) {
      map['related_id'] = Variable<String>(relatedId);
    }
    if (!nullToAbsent || transferGroupId != null) {
      map['transfer_group_id'] = Variable<String>(transferGroupId);
    }
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      dirty: Value(dirty),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      id: Value(id),
      bookId: Value(bookId),
      type: Value(type),
      amountMinor: Value(amountMinor),
      currency: Value(currency),
      accountId: Value(accountId),
      toAccountId: toAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(toAccountId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      occurredAt: Value(occurredAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      attachmentUrls: attachmentUrls == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentUrls),
      tags: tags == null && nullToAbsent ? const Value.absent() : Value(tags),
      sourceModule: Value(sourceModule),
      relatedId: relatedId == null && nullToAbsent
          ? const Value.absent()
          : Value(relatedId),
      transferGroupId: transferGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(transferGroupId),
    );
  }

  factory Transaction.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transaction(
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      syncedAt: serializer.fromJson<int?>(json['syncedAt']),
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      type: $TransactionsTable.$convertertype
          .fromJson(serializer.fromJson<int>(json['type'])),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      currency: serializer.fromJson<String>(json['currency']),
      accountId: serializer.fromJson<String>(json['accountId']),
      toAccountId: serializer.fromJson<String?>(json['toAccountId']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      occurredAt: serializer.fromJson<int>(json['occurredAt']),
      note: serializer.fromJson<String?>(json['note']),
      attachmentUrls: serializer.fromJson<String?>(json['attachmentUrls']),
      tags: serializer.fromJson<String?>(json['tags']),
      sourceModule: $TransactionsTable.$convertersourceModule
          .fromJson(serializer.fromJson<int>(json['sourceModule'])),
      relatedId: serializer.fromJson<String?>(json['relatedId']),
      transferGroupId: serializer.fromJson<String?>(json['transferGroupId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'syncedAt': serializer.toJson<int?>(syncedAt),
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'type': serializer
          .toJson<int>($TransactionsTable.$convertertype.toJson(type)),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'currency': serializer.toJson<String>(currency),
      'accountId': serializer.toJson<String>(accountId),
      'toAccountId': serializer.toJson<String?>(toAccountId),
      'categoryId': serializer.toJson<String?>(categoryId),
      'occurredAt': serializer.toJson<int>(occurredAt),
      'note': serializer.toJson<String?>(note),
      'attachmentUrls': serializer.toJson<String?>(attachmentUrls),
      'tags': serializer.toJson<String?>(tags),
      'sourceModule': serializer.toJson<int>(
          $TransactionsTable.$convertersourceModule.toJson(sourceModule)),
      'relatedId': serializer.toJson<String?>(relatedId),
      'transferGroupId': serializer.toJson<String?>(transferGroupId),
    };
  }

  Transaction copyWith(
          {int? updatedAt,
          bool? deleted,
          bool? dirty,
          Value<int?> syncedAt = const Value.absent(),
          String? id,
          String? bookId,
          TxnType? type,
          int? amountMinor,
          String? currency,
          String? accountId,
          Value<String?> toAccountId = const Value.absent(),
          Value<String?> categoryId = const Value.absent(),
          int? occurredAt,
          Value<String?> note = const Value.absent(),
          Value<String?> attachmentUrls = const Value.absent(),
          Value<String?> tags = const Value.absent(),
          SourceModule? sourceModule,
          Value<String?> relatedId = const Value.absent(),
          Value<String?> transferGroupId = const Value.absent()}) =>
      Transaction(
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        dirty: dirty ?? this.dirty,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        type: type ?? this.type,
        amountMinor: amountMinor ?? this.amountMinor,
        currency: currency ?? this.currency,
        accountId: accountId ?? this.accountId,
        toAccountId: toAccountId.present ? toAccountId.value : this.toAccountId,
        categoryId: categoryId.present ? categoryId.value : this.categoryId,
        occurredAt: occurredAt ?? this.occurredAt,
        note: note.present ? note.value : this.note,
        attachmentUrls:
            attachmentUrls.present ? attachmentUrls.value : this.attachmentUrls,
        tags: tags.present ? tags.value : this.tags,
        sourceModule: sourceModule ?? this.sourceModule,
        relatedId: relatedId.present ? relatedId.value : this.relatedId,
        transferGroupId: transferGroupId.present
            ? transferGroupId.value
            : this.transferGroupId,
      );
  Transaction copyWithCompanion(TransactionsCompanion data) {
    return Transaction(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      type: data.type.present ? data.type.value : this.type,
      amountMinor:
          data.amountMinor.present ? data.amountMinor.value : this.amountMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      toAccountId:
          data.toAccountId.present ? data.toAccountId.value : this.toAccountId,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      occurredAt:
          data.occurredAt.present ? data.occurredAt.value : this.occurredAt,
      note: data.note.present ? data.note.value : this.note,
      attachmentUrls: data.attachmentUrls.present
          ? data.attachmentUrls.value
          : this.attachmentUrls,
      tags: data.tags.present ? data.tags.value : this.tags,
      sourceModule: data.sourceModule.present
          ? data.sourceModule.value
          : this.sourceModule,
      relatedId: data.relatedId.present ? data.relatedId.value : this.relatedId,
      transferGroupId: data.transferGroupId.present
          ? data.transferGroupId.value
          : this.transferGroupId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transaction(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('type: $type, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('accountId: $accountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('note: $note, ')
          ..write('attachmentUrls: $attachmentUrls, ')
          ..write('tags: $tags, ')
          ..write('sourceModule: $sourceModule, ')
          ..write('relatedId: $relatedId, ')
          ..write('transferGroupId: $transferGroupId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      updatedAt,
      deleted,
      dirty,
      syncedAt,
      id,
      bookId,
      type,
      amountMinor,
      currency,
      accountId,
      toAccountId,
      categoryId,
      occurredAt,
      note,
      attachmentUrls,
      tags,
      sourceModule,
      relatedId,
      transferGroupId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.syncedAt == this.syncedAt &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.type == this.type &&
          other.amountMinor == this.amountMinor &&
          other.currency == this.currency &&
          other.accountId == this.accountId &&
          other.toAccountId == this.toAccountId &&
          other.categoryId == this.categoryId &&
          other.occurredAt == this.occurredAt &&
          other.note == this.note &&
          other.attachmentUrls == this.attachmentUrls &&
          other.tags == this.tags &&
          other.sourceModule == this.sourceModule &&
          other.relatedId == this.relatedId &&
          other.transferGroupId == this.transferGroupId);
}

class TransactionsCompanion extends UpdateCompanion<Transaction> {
  final Value<int> updatedAt;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<int?> syncedAt;
  final Value<String> id;
  final Value<String> bookId;
  final Value<TxnType> type;
  final Value<int> amountMinor;
  final Value<String> currency;
  final Value<String> accountId;
  final Value<String?> toAccountId;
  final Value<String?> categoryId;
  final Value<int> occurredAt;
  final Value<String?> note;
  final Value<String?> attachmentUrls;
  final Value<String?> tags;
  final Value<SourceModule> sourceModule;
  final Value<String?> relatedId;
  final Value<String?> transferGroupId;
  final Value<int> rowid;
  const TransactionsCompanion({
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.type = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.accountId = const Value.absent(),
    this.toAccountId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.note = const Value.absent(),
    this.attachmentUrls = const Value.absent(),
    this.tags = const Value.absent(),
    this.sourceModule = const Value.absent(),
    this.relatedId = const Value.absent(),
    this.transferGroupId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionsCompanion.insert({
    required int updatedAt,
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    required String id,
    required String bookId,
    required TxnType type,
    required int amountMinor,
    this.currency = const Value.absent(),
    required String accountId,
    this.toAccountId = const Value.absent(),
    this.categoryId = const Value.absent(),
    required int occurredAt,
    this.note = const Value.absent(),
    this.attachmentUrls = const Value.absent(),
    this.tags = const Value.absent(),
    required SourceModule sourceModule,
    this.relatedId = const Value.absent(),
    this.transferGroupId = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : updatedAt = Value(updatedAt),
        id = Value(id),
        bookId = Value(bookId),
        type = Value(type),
        amountMinor = Value(amountMinor),
        accountId = Value(accountId),
        occurredAt = Value(occurredAt),
        sourceModule = Value(sourceModule);
  static Insertable<Transaction> custom({
    Expression<int>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<int>? syncedAt,
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<int>? type,
    Expression<int>? amountMinor,
    Expression<String>? currency,
    Expression<String>? accountId,
    Expression<String>? toAccountId,
    Expression<String>? categoryId,
    Expression<int>? occurredAt,
    Expression<String>? note,
    Expression<String>? attachmentUrls,
    Expression<String>? tags,
    Expression<int>? sourceModule,
    Expression<String>? relatedId,
    Expression<String>? transferGroupId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (type != null) 'type': type,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (currency != null) 'currency': currency,
      if (accountId != null) 'account_id': accountId,
      if (toAccountId != null) 'to_account_id': toAccountId,
      if (categoryId != null) 'category_id': categoryId,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (note != null) 'note': note,
      if (attachmentUrls != null) 'attachment_urls': attachmentUrls,
      if (tags != null) 'tags': tags,
      if (sourceModule != null) 'source_module': sourceModule,
      if (relatedId != null) 'related_id': relatedId,
      if (transferGroupId != null) 'transfer_group_id': transferGroupId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionsCompanion copyWith(
      {Value<int>? updatedAt,
      Value<bool>? deleted,
      Value<bool>? dirty,
      Value<int?>? syncedAt,
      Value<String>? id,
      Value<String>? bookId,
      Value<TxnType>? type,
      Value<int>? amountMinor,
      Value<String>? currency,
      Value<String>? accountId,
      Value<String?>? toAccountId,
      Value<String?>? categoryId,
      Value<int>? occurredAt,
      Value<String?>? note,
      Value<String?>? attachmentUrls,
      Value<String?>? tags,
      Value<SourceModule>? sourceModule,
      Value<String?>? relatedId,
      Value<String?>? transferGroupId,
      Value<int>? rowid}) {
    return TransactionsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      syncedAt: syncedAt ?? this.syncedAt,
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      type: type ?? this.type,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      categoryId: categoryId ?? this.categoryId,
      occurredAt: occurredAt ?? this.occurredAt,
      note: note ?? this.note,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      tags: tags ?? this.tags,
      sourceModule: sourceModule ?? this.sourceModule,
      relatedId: relatedId ?? this.relatedId,
      transferGroupId: transferGroupId ?? this.transferGroupId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (type.present) {
      map['type'] =
          Variable<int>($TransactionsTable.$convertertype.toSql(type.value));
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (toAccountId.present) {
      map['to_account_id'] = Variable<String>(toAccountId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<int>(occurredAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (attachmentUrls.present) {
      map['attachment_urls'] = Variable<String>(attachmentUrls.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (sourceModule.present) {
      map['source_module'] = Variable<int>(
          $TransactionsTable.$convertersourceModule.toSql(sourceModule.value));
    }
    if (relatedId.present) {
      map['related_id'] = Variable<String>(relatedId.value);
    }
    if (transferGroupId.present) {
      map['transfer_group_id'] = Variable<String>(transferGroupId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('type: $type, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('accountId: $accountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('note: $note, ')
          ..write('attachmentUrls: $attachmentUrls, ')
          ..write('tags: $tags, ')
          ..write('sourceModule: $sourceModule, ')
          ..write('relatedId: $relatedId, ')
          ..write('transferGroupId: $transferGroupId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LendRecordsTable extends LendRecords
    with TableInfo<$LendRecordsTable, LendRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LendRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
      'dirty', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("dirty" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
      'book_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _directionMeta =
      const VerificationMeta('direction');
  @override
  late final GeneratedColumnWithTypeConverter<LendDirection, int> direction =
      GeneratedColumn<int>('direction', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<LendDirection>($LendRecordsTable.$converterdirection);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumnWithTypeConverter<LendStatus, int> status =
      GeneratedColumn<int>('status', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<LendStatus>($LendRecordsTable.$converterstatus);
  static const VerificationMeta _counterpartyMeta =
      const VerificationMeta('counterparty');
  @override
  late final GeneratedColumn<String> counterparty = GeneratedColumn<String>(
      'counterparty', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _amountMinorMeta =
      const VerificationMeta('amountMinor');
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
      'amount_minor', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('CNY'));
  static const VerificationMeta _repaidMinorMeta =
      const VerificationMeta('repaidMinor');
  @override
  late final GeneratedColumn<int> repaidMinor = GeneratedColumn<int>(
      'repaid_minor', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _occurredAtMeta =
      const VerificationMeta('occurredAt');
  @override
  late final GeneratedColumn<int> occurredAt = GeneratedColumn<int>(
      'occurred_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<int> dueAt = GeneratedColumn<int>(
      'due_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        updatedAt,
        deleted,
        dirty,
        syncedAt,
        id,
        bookId,
        direction,
        status,
        counterparty,
        amountMinor,
        currency,
        repaidMinor,
        occurredAt,
        dueAt,
        note,
        accountId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lend_records';
  @override
  VerificationContext validateIntegrity(Insertable<LendRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('dirty')) {
      context.handle(
          _dirtyMeta, dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    context.handle(_directionMeta, const VerificationResult.success());
    context.handle(_statusMeta, const VerificationResult.success());
    if (data.containsKey('counterparty')) {
      context.handle(
          _counterpartyMeta,
          counterparty.isAcceptableOrUnknown(
              data['counterparty']!, _counterpartyMeta));
    } else if (isInserting) {
      context.missing(_counterpartyMeta);
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
          _amountMinorMeta,
          amountMinor.isAcceptableOrUnknown(
              data['amount_minor']!, _amountMinorMeta));
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('repaid_minor')) {
      context.handle(
          _repaidMinorMeta,
          repaidMinor.isAcceptableOrUnknown(
              data['repaid_minor']!, _repaidMinorMeta));
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
          _occurredAtMeta,
          occurredAt.isAcceptableOrUnknown(
              data['occurred_at']!, _occurredAtMeta));
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('due_at')) {
      context.handle(
          _dueAtMeta, dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LendRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LendRecord(
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      dirty: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}dirty'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}synced_at']),
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_id'])!,
      direction: $LendRecordsTable.$converterdirection.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}direction'])!),
      status: $LendRecordsTable.$converterstatus.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!),
      counterparty: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}counterparty'])!,
      amountMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}amount_minor'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      repaidMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}repaid_minor'])!,
      occurredAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}occurred_at'])!,
      dueAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}due_at']),
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id']),
    );
  }

  @override
  $LendRecordsTable createAlias(String alias) {
    return $LendRecordsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<LendDirection, int, int> $converterdirection =
      const EnumIndexConverter<LendDirection>(LendDirection.values);
  static JsonTypeConverter2<LendStatus, int, int> $converterstatus =
      const EnumIndexConverter<LendStatus>(LendStatus.values);
}

class LendRecord extends DataClass implements Insertable<LendRecord> {
  final int updatedAt;
  final bool deleted;
  final bool dirty;
  final int? syncedAt;
  final String id;
  final String bookId;
  final LendDirection direction;
  final LendStatus status;
  final String counterparty;
  final int amountMinor;
  final String currency;

  /// 已还金额（分）
  final int repaidMinor;
  final int occurredAt;
  final int? dueAt;
  final String? note;
  final String? accountId;
  const LendRecord(
      {required this.updatedAt,
      required this.deleted,
      required this.dirty,
      this.syncedAt,
      required this.id,
      required this.bookId,
      required this.direction,
      required this.status,
      required this.counterparty,
      required this.amountMinor,
      required this.currency,
      required this.repaidMinor,
      required this.occurredAt,
      this.dueAt,
      this.note,
      this.accountId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<int>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<int>(syncedAt);
    }
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    {
      map['direction'] =
          Variable<int>($LendRecordsTable.$converterdirection.toSql(direction));
    }
    {
      map['status'] =
          Variable<int>($LendRecordsTable.$converterstatus.toSql(status));
    }
    map['counterparty'] = Variable<String>(counterparty);
    map['amount_minor'] = Variable<int>(amountMinor);
    map['currency'] = Variable<String>(currency);
    map['repaid_minor'] = Variable<int>(repaidMinor);
    map['occurred_at'] = Variable<int>(occurredAt);
    if (!nullToAbsent || dueAt != null) {
      map['due_at'] = Variable<int>(dueAt);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<String>(accountId);
    }
    return map;
  }

  LendRecordsCompanion toCompanion(bool nullToAbsent) {
    return LendRecordsCompanion(
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      dirty: Value(dirty),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      id: Value(id),
      bookId: Value(bookId),
      direction: Value(direction),
      status: Value(status),
      counterparty: Value(counterparty),
      amountMinor: Value(amountMinor),
      currency: Value(currency),
      repaidMinor: Value(repaidMinor),
      occurredAt: Value(occurredAt),
      dueAt:
          dueAt == null && nullToAbsent ? const Value.absent() : Value(dueAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
    );
  }

  factory LendRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LendRecord(
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      syncedAt: serializer.fromJson<int?>(json['syncedAt']),
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      direction: $LendRecordsTable.$converterdirection
          .fromJson(serializer.fromJson<int>(json['direction'])),
      status: $LendRecordsTable.$converterstatus
          .fromJson(serializer.fromJson<int>(json['status'])),
      counterparty: serializer.fromJson<String>(json['counterparty']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      currency: serializer.fromJson<String>(json['currency']),
      repaidMinor: serializer.fromJson<int>(json['repaidMinor']),
      occurredAt: serializer.fromJson<int>(json['occurredAt']),
      dueAt: serializer.fromJson<int?>(json['dueAt']),
      note: serializer.fromJson<String?>(json['note']),
      accountId: serializer.fromJson<String?>(json['accountId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'syncedAt': serializer.toJson<int?>(syncedAt),
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'direction': serializer
          .toJson<int>($LendRecordsTable.$converterdirection.toJson(direction)),
      'status': serializer
          .toJson<int>($LendRecordsTable.$converterstatus.toJson(status)),
      'counterparty': serializer.toJson<String>(counterparty),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'currency': serializer.toJson<String>(currency),
      'repaidMinor': serializer.toJson<int>(repaidMinor),
      'occurredAt': serializer.toJson<int>(occurredAt),
      'dueAt': serializer.toJson<int?>(dueAt),
      'note': serializer.toJson<String?>(note),
      'accountId': serializer.toJson<String?>(accountId),
    };
  }

  LendRecord copyWith(
          {int? updatedAt,
          bool? deleted,
          bool? dirty,
          Value<int?> syncedAt = const Value.absent(),
          String? id,
          String? bookId,
          LendDirection? direction,
          LendStatus? status,
          String? counterparty,
          int? amountMinor,
          String? currency,
          int? repaidMinor,
          int? occurredAt,
          Value<int?> dueAt = const Value.absent(),
          Value<String?> note = const Value.absent(),
          Value<String?> accountId = const Value.absent()}) =>
      LendRecord(
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        dirty: dirty ?? this.dirty,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        direction: direction ?? this.direction,
        status: status ?? this.status,
        counterparty: counterparty ?? this.counterparty,
        amountMinor: amountMinor ?? this.amountMinor,
        currency: currency ?? this.currency,
        repaidMinor: repaidMinor ?? this.repaidMinor,
        occurredAt: occurredAt ?? this.occurredAt,
        dueAt: dueAt.present ? dueAt.value : this.dueAt,
        note: note.present ? note.value : this.note,
        accountId: accountId.present ? accountId.value : this.accountId,
      );
  LendRecord copyWithCompanion(LendRecordsCompanion data) {
    return LendRecord(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      direction: data.direction.present ? data.direction.value : this.direction,
      status: data.status.present ? data.status.value : this.status,
      counterparty: data.counterparty.present
          ? data.counterparty.value
          : this.counterparty,
      amountMinor:
          data.amountMinor.present ? data.amountMinor.value : this.amountMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      repaidMinor:
          data.repaidMinor.present ? data.repaidMinor.value : this.repaidMinor,
      occurredAt:
          data.occurredAt.present ? data.occurredAt.value : this.occurredAt,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      note: data.note.present ? data.note.value : this.note,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LendRecord(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('direction: $direction, ')
          ..write('status: $status, ')
          ..write('counterparty: $counterparty, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('repaidMinor: $repaidMinor, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('dueAt: $dueAt, ')
          ..write('note: $note, ')
          ..write('accountId: $accountId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      updatedAt,
      deleted,
      dirty,
      syncedAt,
      id,
      bookId,
      direction,
      status,
      counterparty,
      amountMinor,
      currency,
      repaidMinor,
      occurredAt,
      dueAt,
      note,
      accountId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LendRecord &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.syncedAt == this.syncedAt &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.direction == this.direction &&
          other.status == this.status &&
          other.counterparty == this.counterparty &&
          other.amountMinor == this.amountMinor &&
          other.currency == this.currency &&
          other.repaidMinor == this.repaidMinor &&
          other.occurredAt == this.occurredAt &&
          other.dueAt == this.dueAt &&
          other.note == this.note &&
          other.accountId == this.accountId);
}

class LendRecordsCompanion extends UpdateCompanion<LendRecord> {
  final Value<int> updatedAt;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<int?> syncedAt;
  final Value<String> id;
  final Value<String> bookId;
  final Value<LendDirection> direction;
  final Value<LendStatus> status;
  final Value<String> counterparty;
  final Value<int> amountMinor;
  final Value<String> currency;
  final Value<int> repaidMinor;
  final Value<int> occurredAt;
  final Value<int?> dueAt;
  final Value<String?> note;
  final Value<String?> accountId;
  final Value<int> rowid;
  const LendRecordsCompanion({
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.direction = const Value.absent(),
    this.status = const Value.absent(),
    this.counterparty = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.repaidMinor = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.note = const Value.absent(),
    this.accountId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LendRecordsCompanion.insert({
    required int updatedAt,
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    required String id,
    required String bookId,
    required LendDirection direction,
    required LendStatus status,
    required String counterparty,
    required int amountMinor,
    this.currency = const Value.absent(),
    this.repaidMinor = const Value.absent(),
    required int occurredAt,
    this.dueAt = const Value.absent(),
    this.note = const Value.absent(),
    this.accountId = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : updatedAt = Value(updatedAt),
        id = Value(id),
        bookId = Value(bookId),
        direction = Value(direction),
        status = Value(status),
        counterparty = Value(counterparty),
        amountMinor = Value(amountMinor),
        occurredAt = Value(occurredAt);
  static Insertable<LendRecord> custom({
    Expression<int>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<int>? syncedAt,
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<int>? direction,
    Expression<int>? status,
    Expression<String>? counterparty,
    Expression<int>? amountMinor,
    Expression<String>? currency,
    Expression<int>? repaidMinor,
    Expression<int>? occurredAt,
    Expression<int>? dueAt,
    Expression<String>? note,
    Expression<String>? accountId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (direction != null) 'direction': direction,
      if (status != null) 'status': status,
      if (counterparty != null) 'counterparty': counterparty,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (currency != null) 'currency': currency,
      if (repaidMinor != null) 'repaid_minor': repaidMinor,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (dueAt != null) 'due_at': dueAt,
      if (note != null) 'note': note,
      if (accountId != null) 'account_id': accountId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LendRecordsCompanion copyWith(
      {Value<int>? updatedAt,
      Value<bool>? deleted,
      Value<bool>? dirty,
      Value<int?>? syncedAt,
      Value<String>? id,
      Value<String>? bookId,
      Value<LendDirection>? direction,
      Value<LendStatus>? status,
      Value<String>? counterparty,
      Value<int>? amountMinor,
      Value<String>? currency,
      Value<int>? repaidMinor,
      Value<int>? occurredAt,
      Value<int?>? dueAt,
      Value<String?>? note,
      Value<String?>? accountId,
      Value<int>? rowid}) {
    return LendRecordsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      syncedAt: syncedAt ?? this.syncedAt,
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      counterparty: counterparty ?? this.counterparty,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      repaidMinor: repaidMinor ?? this.repaidMinor,
      occurredAt: occurredAt ?? this.occurredAt,
      dueAt: dueAt ?? this.dueAt,
      note: note ?? this.note,
      accountId: accountId ?? this.accountId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (direction.present) {
      map['direction'] = Variable<int>(
          $LendRecordsTable.$converterdirection.toSql(direction.value));
    }
    if (status.present) {
      map['status'] =
          Variable<int>($LendRecordsTable.$converterstatus.toSql(status.value));
    }
    if (counterparty.present) {
      map['counterparty'] = Variable<String>(counterparty.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (repaidMinor.present) {
      map['repaid_minor'] = Variable<int>(repaidMinor.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<int>(occurredAt.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<int>(dueAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LendRecordsCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('direction: $direction, ')
          ..write('status: $status, ')
          ..write('counterparty: $counterparty, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('repaidMinor: $repaidMinor, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('dueAt: $dueAt, ')
          ..write('note: $note, ')
          ..write('accountId: $accountId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReimbursementsTable extends Reimbursements
    with TableInfo<$ReimbursementsTable, Reimbursement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReimbursementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
      'dirty', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("dirty" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
      'book_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumnWithTypeConverter<ReimbursementStatus, int> status =
      GeneratedColumn<int>('status', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<ReimbursementStatus>(
              $ReimbursementsTable.$converterstatus);
  static const VerificationMeta _amountMinorMeta =
      const VerificationMeta('amountMinor');
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
      'amount_minor', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('CNY'));
  static const VerificationMeta _payerMeta = const VerificationMeta('payer');
  @override
  late final GeneratedColumn<String> payer = GeneratedColumn<String>(
      'payer', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _targetMeta = const VerificationMeta('target');
  @override
  late final GeneratedColumn<String> target = GeneratedColumn<String>(
      'target', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _occurredAtMeta =
      const VerificationMeta('occurredAt');
  @override
  late final GeneratedColumn<int> occurredAt = GeneratedColumn<int>(
      'occurred_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _receivedAtMeta =
      const VerificationMeta('receivedAt');
  @override
  late final GeneratedColumn<int> receivedAt = GeneratedColumn<int>(
      'received_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _attachmentUrlsMeta =
      const VerificationMeta('attachmentUrls');
  @override
  late final GeneratedColumn<String> attachmentUrls = GeneratedColumn<String>(
      'attachment_urls', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _transactionIdMeta =
      const VerificationMeta('transactionId');
  @override
  late final GeneratedColumn<String> transactionId = GeneratedColumn<String>(
      'transaction_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        updatedAt,
        deleted,
        dirty,
        syncedAt,
        id,
        bookId,
        title,
        status,
        amountMinor,
        currency,
        payer,
        target,
        occurredAt,
        receivedAt,
        note,
        attachmentUrls,
        transactionId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reimbursements';
  @override
  VerificationContext validateIntegrity(Insertable<Reimbursement> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('dirty')) {
      context.handle(
          _dirtyMeta, dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    context.handle(_statusMeta, const VerificationResult.success());
    if (data.containsKey('amount_minor')) {
      context.handle(
          _amountMinorMeta,
          amountMinor.isAcceptableOrUnknown(
              data['amount_minor']!, _amountMinorMeta));
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('payer')) {
      context.handle(
          _payerMeta, payer.isAcceptableOrUnknown(data['payer']!, _payerMeta));
    } else if (isInserting) {
      context.missing(_payerMeta);
    }
    if (data.containsKey('target')) {
      context.handle(_targetMeta,
          target.isAcceptableOrUnknown(data['target']!, _targetMeta));
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
          _occurredAtMeta,
          occurredAt.isAcceptableOrUnknown(
              data['occurred_at']!, _occurredAtMeta));
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('received_at')) {
      context.handle(
          _receivedAtMeta,
          receivedAt.isAcceptableOrUnknown(
              data['received_at']!, _receivedAtMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('attachment_urls')) {
      context.handle(
          _attachmentUrlsMeta,
          attachmentUrls.isAcceptableOrUnknown(
              data['attachment_urls']!, _attachmentUrlsMeta));
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
          _transactionIdMeta,
          transactionId.isAcceptableOrUnknown(
              data['transaction_id']!, _transactionIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Reimbursement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Reimbursement(
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      dirty: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}dirty'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}synced_at']),
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      status: $ReimbursementsTable.$converterstatus.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!),
      amountMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}amount_minor'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      payer: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payer'])!,
      target: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}target']),
      occurredAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}occurred_at'])!,
      receivedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}received_at']),
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      attachmentUrls: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}attachment_urls']),
      transactionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}transaction_id']),
    );
  }

  @override
  $ReimbursementsTable createAlias(String alias) {
    return $ReimbursementsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ReimbursementStatus, int, int> $converterstatus =
      const EnumIndexConverter<ReimbursementStatus>(ReimbursementStatus.values);
}

class Reimbursement extends DataClass implements Insertable<Reimbursement> {
  final int updatedAt;
  final bool deleted;
  final bool dirty;
  final int? syncedAt;
  final String id;
  final String bookId;
  final String title;
  final ReimbursementStatus status;
  final int amountMinor;
  final String currency;
  final String payer;

  /// 报销归属方（公司 / 组织 / 个人）
  final String? target;
  final int occurredAt;
  final int? receivedAt;
  final String? note;
  final String? attachmentUrls;
  final String? transactionId;
  const Reimbursement(
      {required this.updatedAt,
      required this.deleted,
      required this.dirty,
      this.syncedAt,
      required this.id,
      required this.bookId,
      required this.title,
      required this.status,
      required this.amountMinor,
      required this.currency,
      required this.payer,
      this.target,
      required this.occurredAt,
      this.receivedAt,
      this.note,
      this.attachmentUrls,
      this.transactionId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<int>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<int>(syncedAt);
    }
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['title'] = Variable<String>(title);
    {
      map['status'] =
          Variable<int>($ReimbursementsTable.$converterstatus.toSql(status));
    }
    map['amount_minor'] = Variable<int>(amountMinor);
    map['currency'] = Variable<String>(currency);
    map['payer'] = Variable<String>(payer);
    if (!nullToAbsent || target != null) {
      map['target'] = Variable<String>(target);
    }
    map['occurred_at'] = Variable<int>(occurredAt);
    if (!nullToAbsent || receivedAt != null) {
      map['received_at'] = Variable<int>(receivedAt);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || attachmentUrls != null) {
      map['attachment_urls'] = Variable<String>(attachmentUrls);
    }
    if (!nullToAbsent || transactionId != null) {
      map['transaction_id'] = Variable<String>(transactionId);
    }
    return map;
  }

  ReimbursementsCompanion toCompanion(bool nullToAbsent) {
    return ReimbursementsCompanion(
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      dirty: Value(dirty),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      id: Value(id),
      bookId: Value(bookId),
      title: Value(title),
      status: Value(status),
      amountMinor: Value(amountMinor),
      currency: Value(currency),
      payer: Value(payer),
      target:
          target == null && nullToAbsent ? const Value.absent() : Value(target),
      occurredAt: Value(occurredAt),
      receivedAt: receivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(receivedAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      attachmentUrls: attachmentUrls == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentUrls),
      transactionId: transactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(transactionId),
    );
  }

  factory Reimbursement.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Reimbursement(
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      syncedAt: serializer.fromJson<int?>(json['syncedAt']),
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      title: serializer.fromJson<String>(json['title']),
      status: $ReimbursementsTable.$converterstatus
          .fromJson(serializer.fromJson<int>(json['status'])),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      currency: serializer.fromJson<String>(json['currency']),
      payer: serializer.fromJson<String>(json['payer']),
      target: serializer.fromJson<String?>(json['target']),
      occurredAt: serializer.fromJson<int>(json['occurredAt']),
      receivedAt: serializer.fromJson<int?>(json['receivedAt']),
      note: serializer.fromJson<String?>(json['note']),
      attachmentUrls: serializer.fromJson<String?>(json['attachmentUrls']),
      transactionId: serializer.fromJson<String?>(json['transactionId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'syncedAt': serializer.toJson<int?>(syncedAt),
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'title': serializer.toJson<String>(title),
      'status': serializer
          .toJson<int>($ReimbursementsTable.$converterstatus.toJson(status)),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'currency': serializer.toJson<String>(currency),
      'payer': serializer.toJson<String>(payer),
      'target': serializer.toJson<String?>(target),
      'occurredAt': serializer.toJson<int>(occurredAt),
      'receivedAt': serializer.toJson<int?>(receivedAt),
      'note': serializer.toJson<String?>(note),
      'attachmentUrls': serializer.toJson<String?>(attachmentUrls),
      'transactionId': serializer.toJson<String?>(transactionId),
    };
  }

  Reimbursement copyWith(
          {int? updatedAt,
          bool? deleted,
          bool? dirty,
          Value<int?> syncedAt = const Value.absent(),
          String? id,
          String? bookId,
          String? title,
          ReimbursementStatus? status,
          int? amountMinor,
          String? currency,
          String? payer,
          Value<String?> target = const Value.absent(),
          int? occurredAt,
          Value<int?> receivedAt = const Value.absent(),
          Value<String?> note = const Value.absent(),
          Value<String?> attachmentUrls = const Value.absent(),
          Value<String?> transactionId = const Value.absent()}) =>
      Reimbursement(
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        dirty: dirty ?? this.dirty,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        title: title ?? this.title,
        status: status ?? this.status,
        amountMinor: amountMinor ?? this.amountMinor,
        currency: currency ?? this.currency,
        payer: payer ?? this.payer,
        target: target.present ? target.value : this.target,
        occurredAt: occurredAt ?? this.occurredAt,
        receivedAt: receivedAt.present ? receivedAt.value : this.receivedAt,
        note: note.present ? note.value : this.note,
        attachmentUrls:
            attachmentUrls.present ? attachmentUrls.value : this.attachmentUrls,
        transactionId:
            transactionId.present ? transactionId.value : this.transactionId,
      );
  Reimbursement copyWithCompanion(ReimbursementsCompanion data) {
    return Reimbursement(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      title: data.title.present ? data.title.value : this.title,
      status: data.status.present ? data.status.value : this.status,
      amountMinor:
          data.amountMinor.present ? data.amountMinor.value : this.amountMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      payer: data.payer.present ? data.payer.value : this.payer,
      target: data.target.present ? data.target.value : this.target,
      occurredAt:
          data.occurredAt.present ? data.occurredAt.value : this.occurredAt,
      receivedAt:
          data.receivedAt.present ? data.receivedAt.value : this.receivedAt,
      note: data.note.present ? data.note.value : this.note,
      attachmentUrls: data.attachmentUrls.present
          ? data.attachmentUrls.value
          : this.attachmentUrls,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Reimbursement(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('title: $title, ')
          ..write('status: $status, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('payer: $payer, ')
          ..write('target: $target, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('note: $note, ')
          ..write('attachmentUrls: $attachmentUrls, ')
          ..write('transactionId: $transactionId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      updatedAt,
      deleted,
      dirty,
      syncedAt,
      id,
      bookId,
      title,
      status,
      amountMinor,
      currency,
      payer,
      target,
      occurredAt,
      receivedAt,
      note,
      attachmentUrls,
      transactionId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reimbursement &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.syncedAt == this.syncedAt &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.title == this.title &&
          other.status == this.status &&
          other.amountMinor == this.amountMinor &&
          other.currency == this.currency &&
          other.payer == this.payer &&
          other.target == this.target &&
          other.occurredAt == this.occurredAt &&
          other.receivedAt == this.receivedAt &&
          other.note == this.note &&
          other.attachmentUrls == this.attachmentUrls &&
          other.transactionId == this.transactionId);
}

class ReimbursementsCompanion extends UpdateCompanion<Reimbursement> {
  final Value<int> updatedAt;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<int?> syncedAt;
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> title;
  final Value<ReimbursementStatus> status;
  final Value<int> amountMinor;
  final Value<String> currency;
  final Value<String> payer;
  final Value<String?> target;
  final Value<int> occurredAt;
  final Value<int?> receivedAt;
  final Value<String?> note;
  final Value<String?> attachmentUrls;
  final Value<String?> transactionId;
  final Value<int> rowid;
  const ReimbursementsCompanion({
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.title = const Value.absent(),
    this.status = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.payer = const Value.absent(),
    this.target = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.note = const Value.absent(),
    this.attachmentUrls = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReimbursementsCompanion.insert({
    required int updatedAt,
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    required String id,
    required String bookId,
    required String title,
    required ReimbursementStatus status,
    required int amountMinor,
    this.currency = const Value.absent(),
    required String payer,
    this.target = const Value.absent(),
    required int occurredAt,
    this.receivedAt = const Value.absent(),
    this.note = const Value.absent(),
    this.attachmentUrls = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : updatedAt = Value(updatedAt),
        id = Value(id),
        bookId = Value(bookId),
        title = Value(title),
        status = Value(status),
        amountMinor = Value(amountMinor),
        payer = Value(payer),
        occurredAt = Value(occurredAt);
  static Insertable<Reimbursement> custom({
    Expression<int>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<int>? syncedAt,
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? title,
    Expression<int>? status,
    Expression<int>? amountMinor,
    Expression<String>? currency,
    Expression<String>? payer,
    Expression<String>? target,
    Expression<int>? occurredAt,
    Expression<int>? receivedAt,
    Expression<String>? note,
    Expression<String>? attachmentUrls,
    Expression<String>? transactionId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (title != null) 'title': title,
      if (status != null) 'status': status,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (currency != null) 'currency': currency,
      if (payer != null) 'payer': payer,
      if (target != null) 'target': target,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (receivedAt != null) 'received_at': receivedAt,
      if (note != null) 'note': note,
      if (attachmentUrls != null) 'attachment_urls': attachmentUrls,
      if (transactionId != null) 'transaction_id': transactionId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReimbursementsCompanion copyWith(
      {Value<int>? updatedAt,
      Value<bool>? deleted,
      Value<bool>? dirty,
      Value<int?>? syncedAt,
      Value<String>? id,
      Value<String>? bookId,
      Value<String>? title,
      Value<ReimbursementStatus>? status,
      Value<int>? amountMinor,
      Value<String>? currency,
      Value<String>? payer,
      Value<String?>? target,
      Value<int>? occurredAt,
      Value<int?>? receivedAt,
      Value<String?>? note,
      Value<String?>? attachmentUrls,
      Value<String?>? transactionId,
      Value<int>? rowid}) {
    return ReimbursementsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      syncedAt: syncedAt ?? this.syncedAt,
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      title: title ?? this.title,
      status: status ?? this.status,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      payer: payer ?? this.payer,
      target: target ?? this.target,
      occurredAt: occurredAt ?? this.occurredAt,
      receivedAt: receivedAt ?? this.receivedAt,
      note: note ?? this.note,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      transactionId: transactionId ?? this.transactionId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(
          $ReimbursementsTable.$converterstatus.toSql(status.value));
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (payer.present) {
      map['payer'] = Variable<String>(payer.value);
    }
    if (target.present) {
      map['target'] = Variable<String>(target.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<int>(occurredAt.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<int>(receivedAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (attachmentUrls.present) {
      map['attachment_urls'] = Variable<String>(attachmentUrls.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<String>(transactionId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReimbursementsCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('title: $title, ')
          ..write('status: $status, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('payer: $payer, ')
          ..write('target: $target, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('note: $note, ')
          ..write('attachmentUrls: $attachmentUrls, ')
          ..write('transactionId: $transactionId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SavingsGoalsTable extends SavingsGoals
    with TableInfo<$SavingsGoalsTable, SavingsGoal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavingsGoalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
      'dirty', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("dirty" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
      'book_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _targetMinorMeta =
      const VerificationMeta('targetMinor');
  @override
  late final GeneratedColumn<int> targetMinor = GeneratedColumn<int>(
      'target_minor', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _currentMinorMeta =
      const VerificationMeta('currentMinor');
  @override
  late final GeneratedColumn<int> currentMinor = GeneratedColumn<int>(
      'current_minor', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('CNY'));
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _deadlineAtMeta =
      const VerificationMeta('deadlineAt');
  @override
  late final GeneratedColumn<int> deadlineAt = GeneratedColumn<int>(
      'deadline_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isAchievedMeta =
      const VerificationMeta('isAchieved');
  @override
  late final GeneratedColumn<bool> isAchieved = GeneratedColumn<bool>(
      'is_achieved', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_achieved" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        updatedAt,
        deleted,
        dirty,
        syncedAt,
        id,
        bookId,
        name,
        targetMinor,
        currentMinor,
        currency,
        accountId,
        deadlineAt,
        note,
        isAchieved
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'savings_goals';
  @override
  VerificationContext validateIntegrity(Insertable<SavingsGoal> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('dirty')) {
      context.handle(
          _dirtyMeta, dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('target_minor')) {
      context.handle(
          _targetMinorMeta,
          targetMinor.isAcceptableOrUnknown(
              data['target_minor']!, _targetMinorMeta));
    } else if (isInserting) {
      context.missing(_targetMinorMeta);
    }
    if (data.containsKey('current_minor')) {
      context.handle(
          _currentMinorMeta,
          currentMinor.isAcceptableOrUnknown(
              data['current_minor']!, _currentMinorMeta));
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    }
    if (data.containsKey('deadline_at')) {
      context.handle(
          _deadlineAtMeta,
          deadlineAt.isAcceptableOrUnknown(
              data['deadline_at']!, _deadlineAtMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('is_achieved')) {
      context.handle(
          _isAchievedMeta,
          isAchieved.isAcceptableOrUnknown(
              data['is_achieved']!, _isAchievedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavingsGoal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavingsGoal(
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      dirty: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}dirty'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}synced_at']),
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      targetMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}target_minor'])!,
      currentMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}current_minor'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id']),
      deadlineAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}deadline_at']),
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      isAchieved: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_achieved'])!,
    );
  }

  @override
  $SavingsGoalsTable createAlias(String alias) {
    return $SavingsGoalsTable(attachedDatabase, alias);
  }
}

class SavingsGoal extends DataClass implements Insertable<SavingsGoal> {
  final int updatedAt;
  final bool deleted;
  final bool dirty;
  final int? syncedAt;
  final String id;
  final String bookId;
  final String name;
  final int targetMinor;
  final int currentMinor;
  final String currency;
  final String? accountId;
  final int? deadlineAt;
  final String? note;
  final bool isAchieved;
  const SavingsGoal(
      {required this.updatedAt,
      required this.deleted,
      required this.dirty,
      this.syncedAt,
      required this.id,
      required this.bookId,
      required this.name,
      required this.targetMinor,
      required this.currentMinor,
      required this.currency,
      this.accountId,
      this.deadlineAt,
      this.note,
      required this.isAchieved});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<int>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<int>(syncedAt);
    }
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['name'] = Variable<String>(name);
    map['target_minor'] = Variable<int>(targetMinor);
    map['current_minor'] = Variable<int>(currentMinor);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<String>(accountId);
    }
    if (!nullToAbsent || deadlineAt != null) {
      map['deadline_at'] = Variable<int>(deadlineAt);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['is_achieved'] = Variable<bool>(isAchieved);
    return map;
  }

  SavingsGoalsCompanion toCompanion(bool nullToAbsent) {
    return SavingsGoalsCompanion(
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      dirty: Value(dirty),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      id: Value(id),
      bookId: Value(bookId),
      name: Value(name),
      targetMinor: Value(targetMinor),
      currentMinor: Value(currentMinor),
      currency: Value(currency),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      deadlineAt: deadlineAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deadlineAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      isAchieved: Value(isAchieved),
    );
  }

  factory SavingsGoal.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavingsGoal(
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      syncedAt: serializer.fromJson<int?>(json['syncedAt']),
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      name: serializer.fromJson<String>(json['name']),
      targetMinor: serializer.fromJson<int>(json['targetMinor']),
      currentMinor: serializer.fromJson<int>(json['currentMinor']),
      currency: serializer.fromJson<String>(json['currency']),
      accountId: serializer.fromJson<String?>(json['accountId']),
      deadlineAt: serializer.fromJson<int?>(json['deadlineAt']),
      note: serializer.fromJson<String?>(json['note']),
      isAchieved: serializer.fromJson<bool>(json['isAchieved']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'syncedAt': serializer.toJson<int?>(syncedAt),
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'name': serializer.toJson<String>(name),
      'targetMinor': serializer.toJson<int>(targetMinor),
      'currentMinor': serializer.toJson<int>(currentMinor),
      'currency': serializer.toJson<String>(currency),
      'accountId': serializer.toJson<String?>(accountId),
      'deadlineAt': serializer.toJson<int?>(deadlineAt),
      'note': serializer.toJson<String?>(note),
      'isAchieved': serializer.toJson<bool>(isAchieved),
    };
  }

  SavingsGoal copyWith(
          {int? updatedAt,
          bool? deleted,
          bool? dirty,
          Value<int?> syncedAt = const Value.absent(),
          String? id,
          String? bookId,
          String? name,
          int? targetMinor,
          int? currentMinor,
          String? currency,
          Value<String?> accountId = const Value.absent(),
          Value<int?> deadlineAt = const Value.absent(),
          Value<String?> note = const Value.absent(),
          bool? isAchieved}) =>
      SavingsGoal(
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        dirty: dirty ?? this.dirty,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        name: name ?? this.name,
        targetMinor: targetMinor ?? this.targetMinor,
        currentMinor: currentMinor ?? this.currentMinor,
        currency: currency ?? this.currency,
        accountId: accountId.present ? accountId.value : this.accountId,
        deadlineAt: deadlineAt.present ? deadlineAt.value : this.deadlineAt,
        note: note.present ? note.value : this.note,
        isAchieved: isAchieved ?? this.isAchieved,
      );
  SavingsGoal copyWithCompanion(SavingsGoalsCompanion data) {
    return SavingsGoal(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      name: data.name.present ? data.name.value : this.name,
      targetMinor:
          data.targetMinor.present ? data.targetMinor.value : this.targetMinor,
      currentMinor: data.currentMinor.present
          ? data.currentMinor.value
          : this.currentMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      deadlineAt:
          data.deadlineAt.present ? data.deadlineAt.value : this.deadlineAt,
      note: data.note.present ? data.note.value : this.note,
      isAchieved:
          data.isAchieved.present ? data.isAchieved.value : this.isAchieved,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavingsGoal(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('name: $name, ')
          ..write('targetMinor: $targetMinor, ')
          ..write('currentMinor: $currentMinor, ')
          ..write('currency: $currency, ')
          ..write('accountId: $accountId, ')
          ..write('deadlineAt: $deadlineAt, ')
          ..write('note: $note, ')
          ..write('isAchieved: $isAchieved')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      updatedAt,
      deleted,
      dirty,
      syncedAt,
      id,
      bookId,
      name,
      targetMinor,
      currentMinor,
      currency,
      accountId,
      deadlineAt,
      note,
      isAchieved);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavingsGoal &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.syncedAt == this.syncedAt &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.name == this.name &&
          other.targetMinor == this.targetMinor &&
          other.currentMinor == this.currentMinor &&
          other.currency == this.currency &&
          other.accountId == this.accountId &&
          other.deadlineAt == this.deadlineAt &&
          other.note == this.note &&
          other.isAchieved == this.isAchieved);
}

class SavingsGoalsCompanion extends UpdateCompanion<SavingsGoal> {
  final Value<int> updatedAt;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<int?> syncedAt;
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> name;
  final Value<int> targetMinor;
  final Value<int> currentMinor;
  final Value<String> currency;
  final Value<String?> accountId;
  final Value<int?> deadlineAt;
  final Value<String?> note;
  final Value<bool> isAchieved;
  final Value<int> rowid;
  const SavingsGoalsCompanion({
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.name = const Value.absent(),
    this.targetMinor = const Value.absent(),
    this.currentMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.accountId = const Value.absent(),
    this.deadlineAt = const Value.absent(),
    this.note = const Value.absent(),
    this.isAchieved = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavingsGoalsCompanion.insert({
    required int updatedAt,
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    required String id,
    required String bookId,
    required String name,
    required int targetMinor,
    this.currentMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.accountId = const Value.absent(),
    this.deadlineAt = const Value.absent(),
    this.note = const Value.absent(),
    this.isAchieved = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : updatedAt = Value(updatedAt),
        id = Value(id),
        bookId = Value(bookId),
        name = Value(name),
        targetMinor = Value(targetMinor);
  static Insertable<SavingsGoal> custom({
    Expression<int>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<int>? syncedAt,
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? name,
    Expression<int>? targetMinor,
    Expression<int>? currentMinor,
    Expression<String>? currency,
    Expression<String>? accountId,
    Expression<int>? deadlineAt,
    Expression<String>? note,
    Expression<bool>? isAchieved,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (name != null) 'name': name,
      if (targetMinor != null) 'target_minor': targetMinor,
      if (currentMinor != null) 'current_minor': currentMinor,
      if (currency != null) 'currency': currency,
      if (accountId != null) 'account_id': accountId,
      if (deadlineAt != null) 'deadline_at': deadlineAt,
      if (note != null) 'note': note,
      if (isAchieved != null) 'is_achieved': isAchieved,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavingsGoalsCompanion copyWith(
      {Value<int>? updatedAt,
      Value<bool>? deleted,
      Value<bool>? dirty,
      Value<int?>? syncedAt,
      Value<String>? id,
      Value<String>? bookId,
      Value<String>? name,
      Value<int>? targetMinor,
      Value<int>? currentMinor,
      Value<String>? currency,
      Value<String?>? accountId,
      Value<int?>? deadlineAt,
      Value<String?>? note,
      Value<bool>? isAchieved,
      Value<int>? rowid}) {
    return SavingsGoalsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      syncedAt: syncedAt ?? this.syncedAt,
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      name: name ?? this.name,
      targetMinor: targetMinor ?? this.targetMinor,
      currentMinor: currentMinor ?? this.currentMinor,
      currency: currency ?? this.currency,
      accountId: accountId ?? this.accountId,
      deadlineAt: deadlineAt ?? this.deadlineAt,
      note: note ?? this.note,
      isAchieved: isAchieved ?? this.isAchieved,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (targetMinor.present) {
      map['target_minor'] = Variable<int>(targetMinor.value);
    }
    if (currentMinor.present) {
      map['current_minor'] = Variable<int>(currentMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (deadlineAt.present) {
      map['deadline_at'] = Variable<int>(deadlineAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (isAchieved.present) {
      map['is_achieved'] = Variable<bool>(isAchieved.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavingsGoalsCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('name: $name, ')
          ..write('targetMinor: $targetMinor, ')
          ..write('currentMinor: $currentMinor, ')
          ..write('currency: $currency, ')
          ..write('accountId: $accountId, ')
          ..write('deadlineAt: $deadlineAt, ')
          ..write('note: $note, ')
          ..write('isAchieved: $isAchieved, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InstallmentPlansTable extends InstallmentPlans
    with TableInfo<$InstallmentPlansTable, InstallmentPlan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InstallmentPlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
      'dirty', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("dirty" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
      'book_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _totalMinorMeta =
      const VerificationMeta('totalMinor');
  @override
  late final GeneratedColumn<int> totalMinor = GeneratedColumn<int>(
      'total_minor', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _totalPeriodsMeta =
      const VerificationMeta('totalPeriods');
  @override
  late final GeneratedColumn<int> totalPeriods = GeneratedColumn<int>(
      'total_periods', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _paidPeriodsMeta =
      const VerificationMeta('paidPeriods');
  @override
  late final GeneratedColumn<int> paidPeriods = GeneratedColumn<int>(
      'paid_periods', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _feePerPeriodMinorMeta =
      const VerificationMeta('feePerPeriodMinor');
  @override
  late final GeneratedColumn<int> feePerPeriodMinor = GeneratedColumn<int>(
      'fee_per_period_minor', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('CNY'));
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _firstDueAtMeta =
      const VerificationMeta('firstDueAt');
  @override
  late final GeneratedColumn<int> firstDueAt = GeneratedColumn<int>(
      'first_due_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isFinishedMeta =
      const VerificationMeta('isFinished');
  @override
  late final GeneratedColumn<bool> isFinished = GeneratedColumn<bool>(
      'is_finished', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_finished" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        updatedAt,
        deleted,
        dirty,
        syncedAt,
        id,
        bookId,
        title,
        totalMinor,
        totalPeriods,
        paidPeriods,
        feePerPeriodMinor,
        currency,
        accountId,
        firstDueAt,
        note,
        isFinished
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'installment_plans';
  @override
  VerificationContext validateIntegrity(Insertable<InstallmentPlan> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('dirty')) {
      context.handle(
          _dirtyMeta, dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('total_minor')) {
      context.handle(
          _totalMinorMeta,
          totalMinor.isAcceptableOrUnknown(
              data['total_minor']!, _totalMinorMeta));
    } else if (isInserting) {
      context.missing(_totalMinorMeta);
    }
    if (data.containsKey('total_periods')) {
      context.handle(
          _totalPeriodsMeta,
          totalPeriods.isAcceptableOrUnknown(
              data['total_periods']!, _totalPeriodsMeta));
    } else if (isInserting) {
      context.missing(_totalPeriodsMeta);
    }
    if (data.containsKey('paid_periods')) {
      context.handle(
          _paidPeriodsMeta,
          paidPeriods.isAcceptableOrUnknown(
              data['paid_periods']!, _paidPeriodsMeta));
    }
    if (data.containsKey('fee_per_period_minor')) {
      context.handle(
          _feePerPeriodMinorMeta,
          feePerPeriodMinor.isAcceptableOrUnknown(
              data['fee_per_period_minor']!, _feePerPeriodMinorMeta));
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    }
    if (data.containsKey('first_due_at')) {
      context.handle(
          _firstDueAtMeta,
          firstDueAt.isAcceptableOrUnknown(
              data['first_due_at']!, _firstDueAtMeta));
    } else if (isInserting) {
      context.missing(_firstDueAtMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('is_finished')) {
      context.handle(
          _isFinishedMeta,
          isFinished.isAcceptableOrUnknown(
              data['is_finished']!, _isFinishedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InstallmentPlan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InstallmentPlan(
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      dirty: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}dirty'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}synced_at']),
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      totalMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_minor'])!,
      totalPeriods: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_periods'])!,
      paidPeriods: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}paid_periods'])!,
      feePerPeriodMinor: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}fee_per_period_minor'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id']),
      firstDueAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}first_due_at'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      isFinished: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_finished'])!,
    );
  }

  @override
  $InstallmentPlansTable createAlias(String alias) {
    return $InstallmentPlansTable(attachedDatabase, alias);
  }
}

class InstallmentPlan extends DataClass implements Insertable<InstallmentPlan> {
  final int updatedAt;
  final bool deleted;
  final bool dirty;
  final int? syncedAt;
  final String id;
  final String bookId;
  final String title;
  final int totalMinor;
  final int totalPeriods;

  /// 已还期数
  final int paidPeriods;

  /// 每期手续费 / 利息（分）
  final int feePerPeriodMinor;
  final String currency;
  final String? accountId;
  final int firstDueAt;
  final String? note;
  final bool isFinished;
  const InstallmentPlan(
      {required this.updatedAt,
      required this.deleted,
      required this.dirty,
      this.syncedAt,
      required this.id,
      required this.bookId,
      required this.title,
      required this.totalMinor,
      required this.totalPeriods,
      required this.paidPeriods,
      required this.feePerPeriodMinor,
      required this.currency,
      this.accountId,
      required this.firstDueAt,
      this.note,
      required this.isFinished});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<int>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<int>(syncedAt);
    }
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['title'] = Variable<String>(title);
    map['total_minor'] = Variable<int>(totalMinor);
    map['total_periods'] = Variable<int>(totalPeriods);
    map['paid_periods'] = Variable<int>(paidPeriods);
    map['fee_per_period_minor'] = Variable<int>(feePerPeriodMinor);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<String>(accountId);
    }
    map['first_due_at'] = Variable<int>(firstDueAt);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['is_finished'] = Variable<bool>(isFinished);
    return map;
  }

  InstallmentPlansCompanion toCompanion(bool nullToAbsent) {
    return InstallmentPlansCompanion(
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      dirty: Value(dirty),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      id: Value(id),
      bookId: Value(bookId),
      title: Value(title),
      totalMinor: Value(totalMinor),
      totalPeriods: Value(totalPeriods),
      paidPeriods: Value(paidPeriods),
      feePerPeriodMinor: Value(feePerPeriodMinor),
      currency: Value(currency),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      firstDueAt: Value(firstDueAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      isFinished: Value(isFinished),
    );
  }

  factory InstallmentPlan.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InstallmentPlan(
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      syncedAt: serializer.fromJson<int?>(json['syncedAt']),
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      title: serializer.fromJson<String>(json['title']),
      totalMinor: serializer.fromJson<int>(json['totalMinor']),
      totalPeriods: serializer.fromJson<int>(json['totalPeriods']),
      paidPeriods: serializer.fromJson<int>(json['paidPeriods']),
      feePerPeriodMinor: serializer.fromJson<int>(json['feePerPeriodMinor']),
      currency: serializer.fromJson<String>(json['currency']),
      accountId: serializer.fromJson<String?>(json['accountId']),
      firstDueAt: serializer.fromJson<int>(json['firstDueAt']),
      note: serializer.fromJson<String?>(json['note']),
      isFinished: serializer.fromJson<bool>(json['isFinished']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'syncedAt': serializer.toJson<int?>(syncedAt),
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'title': serializer.toJson<String>(title),
      'totalMinor': serializer.toJson<int>(totalMinor),
      'totalPeriods': serializer.toJson<int>(totalPeriods),
      'paidPeriods': serializer.toJson<int>(paidPeriods),
      'feePerPeriodMinor': serializer.toJson<int>(feePerPeriodMinor),
      'currency': serializer.toJson<String>(currency),
      'accountId': serializer.toJson<String?>(accountId),
      'firstDueAt': serializer.toJson<int>(firstDueAt),
      'note': serializer.toJson<String?>(note),
      'isFinished': serializer.toJson<bool>(isFinished),
    };
  }

  InstallmentPlan copyWith(
          {int? updatedAt,
          bool? deleted,
          bool? dirty,
          Value<int?> syncedAt = const Value.absent(),
          String? id,
          String? bookId,
          String? title,
          int? totalMinor,
          int? totalPeriods,
          int? paidPeriods,
          int? feePerPeriodMinor,
          String? currency,
          Value<String?> accountId = const Value.absent(),
          int? firstDueAt,
          Value<String?> note = const Value.absent(),
          bool? isFinished}) =>
      InstallmentPlan(
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        dirty: dirty ?? this.dirty,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        title: title ?? this.title,
        totalMinor: totalMinor ?? this.totalMinor,
        totalPeriods: totalPeriods ?? this.totalPeriods,
        paidPeriods: paidPeriods ?? this.paidPeriods,
        feePerPeriodMinor: feePerPeriodMinor ?? this.feePerPeriodMinor,
        currency: currency ?? this.currency,
        accountId: accountId.present ? accountId.value : this.accountId,
        firstDueAt: firstDueAt ?? this.firstDueAt,
        note: note.present ? note.value : this.note,
        isFinished: isFinished ?? this.isFinished,
      );
  InstallmentPlan copyWithCompanion(InstallmentPlansCompanion data) {
    return InstallmentPlan(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      title: data.title.present ? data.title.value : this.title,
      totalMinor:
          data.totalMinor.present ? data.totalMinor.value : this.totalMinor,
      totalPeriods: data.totalPeriods.present
          ? data.totalPeriods.value
          : this.totalPeriods,
      paidPeriods:
          data.paidPeriods.present ? data.paidPeriods.value : this.paidPeriods,
      feePerPeriodMinor: data.feePerPeriodMinor.present
          ? data.feePerPeriodMinor.value
          : this.feePerPeriodMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      firstDueAt:
          data.firstDueAt.present ? data.firstDueAt.value : this.firstDueAt,
      note: data.note.present ? data.note.value : this.note,
      isFinished:
          data.isFinished.present ? data.isFinished.value : this.isFinished,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InstallmentPlan(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('title: $title, ')
          ..write('totalMinor: $totalMinor, ')
          ..write('totalPeriods: $totalPeriods, ')
          ..write('paidPeriods: $paidPeriods, ')
          ..write('feePerPeriodMinor: $feePerPeriodMinor, ')
          ..write('currency: $currency, ')
          ..write('accountId: $accountId, ')
          ..write('firstDueAt: $firstDueAt, ')
          ..write('note: $note, ')
          ..write('isFinished: $isFinished')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      updatedAt,
      deleted,
      dirty,
      syncedAt,
      id,
      bookId,
      title,
      totalMinor,
      totalPeriods,
      paidPeriods,
      feePerPeriodMinor,
      currency,
      accountId,
      firstDueAt,
      note,
      isFinished);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InstallmentPlan &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.syncedAt == this.syncedAt &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.title == this.title &&
          other.totalMinor == this.totalMinor &&
          other.totalPeriods == this.totalPeriods &&
          other.paidPeriods == this.paidPeriods &&
          other.feePerPeriodMinor == this.feePerPeriodMinor &&
          other.currency == this.currency &&
          other.accountId == this.accountId &&
          other.firstDueAt == this.firstDueAt &&
          other.note == this.note &&
          other.isFinished == this.isFinished);
}

class InstallmentPlansCompanion extends UpdateCompanion<InstallmentPlan> {
  final Value<int> updatedAt;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<int?> syncedAt;
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> title;
  final Value<int> totalMinor;
  final Value<int> totalPeriods;
  final Value<int> paidPeriods;
  final Value<int> feePerPeriodMinor;
  final Value<String> currency;
  final Value<String?> accountId;
  final Value<int> firstDueAt;
  final Value<String?> note;
  final Value<bool> isFinished;
  final Value<int> rowid;
  const InstallmentPlansCompanion({
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.title = const Value.absent(),
    this.totalMinor = const Value.absent(),
    this.totalPeriods = const Value.absent(),
    this.paidPeriods = const Value.absent(),
    this.feePerPeriodMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.accountId = const Value.absent(),
    this.firstDueAt = const Value.absent(),
    this.note = const Value.absent(),
    this.isFinished = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InstallmentPlansCompanion.insert({
    required int updatedAt,
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    required String id,
    required String bookId,
    required String title,
    required int totalMinor,
    required int totalPeriods,
    this.paidPeriods = const Value.absent(),
    this.feePerPeriodMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.accountId = const Value.absent(),
    required int firstDueAt,
    this.note = const Value.absent(),
    this.isFinished = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : updatedAt = Value(updatedAt),
        id = Value(id),
        bookId = Value(bookId),
        title = Value(title),
        totalMinor = Value(totalMinor),
        totalPeriods = Value(totalPeriods),
        firstDueAt = Value(firstDueAt);
  static Insertable<InstallmentPlan> custom({
    Expression<int>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<int>? syncedAt,
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? title,
    Expression<int>? totalMinor,
    Expression<int>? totalPeriods,
    Expression<int>? paidPeriods,
    Expression<int>? feePerPeriodMinor,
    Expression<String>? currency,
    Expression<String>? accountId,
    Expression<int>? firstDueAt,
    Expression<String>? note,
    Expression<bool>? isFinished,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (title != null) 'title': title,
      if (totalMinor != null) 'total_minor': totalMinor,
      if (totalPeriods != null) 'total_periods': totalPeriods,
      if (paidPeriods != null) 'paid_periods': paidPeriods,
      if (feePerPeriodMinor != null) 'fee_per_period_minor': feePerPeriodMinor,
      if (currency != null) 'currency': currency,
      if (accountId != null) 'account_id': accountId,
      if (firstDueAt != null) 'first_due_at': firstDueAt,
      if (note != null) 'note': note,
      if (isFinished != null) 'is_finished': isFinished,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InstallmentPlansCompanion copyWith(
      {Value<int>? updatedAt,
      Value<bool>? deleted,
      Value<bool>? dirty,
      Value<int?>? syncedAt,
      Value<String>? id,
      Value<String>? bookId,
      Value<String>? title,
      Value<int>? totalMinor,
      Value<int>? totalPeriods,
      Value<int>? paidPeriods,
      Value<int>? feePerPeriodMinor,
      Value<String>? currency,
      Value<String?>? accountId,
      Value<int>? firstDueAt,
      Value<String?>? note,
      Value<bool>? isFinished,
      Value<int>? rowid}) {
    return InstallmentPlansCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      syncedAt: syncedAt ?? this.syncedAt,
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      title: title ?? this.title,
      totalMinor: totalMinor ?? this.totalMinor,
      totalPeriods: totalPeriods ?? this.totalPeriods,
      paidPeriods: paidPeriods ?? this.paidPeriods,
      feePerPeriodMinor: feePerPeriodMinor ?? this.feePerPeriodMinor,
      currency: currency ?? this.currency,
      accountId: accountId ?? this.accountId,
      firstDueAt: firstDueAt ?? this.firstDueAt,
      note: note ?? this.note,
      isFinished: isFinished ?? this.isFinished,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (totalMinor.present) {
      map['total_minor'] = Variable<int>(totalMinor.value);
    }
    if (totalPeriods.present) {
      map['total_periods'] = Variable<int>(totalPeriods.value);
    }
    if (paidPeriods.present) {
      map['paid_periods'] = Variable<int>(paidPeriods.value);
    }
    if (feePerPeriodMinor.present) {
      map['fee_per_period_minor'] = Variable<int>(feePerPeriodMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (firstDueAt.present) {
      map['first_due_at'] = Variable<int>(firstDueAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (isFinished.present) {
      map['is_finished'] = Variable<bool>(isFinished.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InstallmentPlansCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('title: $title, ')
          ..write('totalMinor: $totalMinor, ')
          ..write('totalPeriods: $totalPeriods, ')
          ..write('paidPeriods: $paidPeriods, ')
          ..write('feePerPeriodMinor: $feePerPeriodMinor, ')
          ..write('currency: $currency, ')
          ..write('accountId: $accountId, ')
          ..write('firstDueAt: $firstDueAt, ')
          ..write('note: $note, ')
          ..write('isFinished: $isFinished, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InstallmentPeriodsTable extends InstallmentPeriods
    with TableInfo<$InstallmentPeriodsTable, InstallmentPeriod> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InstallmentPeriodsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
      'dirty', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("dirty" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
      'plan_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _periodIndexMeta =
      const VerificationMeta('periodIndex');
  @override
  late final GeneratedColumn<int> periodIndex = GeneratedColumn<int>(
      'period_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _amountMinorMeta =
      const VerificationMeta('amountMinor');
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
      'amount_minor', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<int> dueAt = GeneratedColumn<int>(
      'due_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _paidAtMeta = const VerificationMeta('paidAt');
  @override
  late final GeneratedColumn<int> paidAt = GeneratedColumn<int>(
      'paid_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _transactionIdMeta =
      const VerificationMeta('transactionId');
  @override
  late final GeneratedColumn<String> transactionId = GeneratedColumn<String>(
      'transaction_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        updatedAt,
        deleted,
        dirty,
        syncedAt,
        id,
        planId,
        periodIndex,
        amountMinor,
        dueAt,
        paidAt,
        transactionId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'installment_periods';
  @override
  VerificationContext validateIntegrity(Insertable<InstallmentPeriod> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('dirty')) {
      context.handle(
          _dirtyMeta, dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(_planIdMeta,
          planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta));
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('period_index')) {
      context.handle(
          _periodIndexMeta,
          periodIndex.isAcceptableOrUnknown(
              data['period_index']!, _periodIndexMeta));
    } else if (isInserting) {
      context.missing(_periodIndexMeta);
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
          _amountMinorMeta,
          amountMinor.isAcceptableOrUnknown(
              data['amount_minor']!, _amountMinorMeta));
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('due_at')) {
      context.handle(
          _dueAtMeta, dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta));
    } else if (isInserting) {
      context.missing(_dueAtMeta);
    }
    if (data.containsKey('paid_at')) {
      context.handle(_paidAtMeta,
          paidAt.isAcceptableOrUnknown(data['paid_at']!, _paidAtMeta));
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
          _transactionIdMeta,
          transactionId.isAcceptableOrUnknown(
              data['transaction_id']!, _transactionIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InstallmentPeriod map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InstallmentPeriod(
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      dirty: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}dirty'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}synced_at']),
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      planId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plan_id'])!,
      periodIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}period_index'])!,
      amountMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}amount_minor'])!,
      dueAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}due_at'])!,
      paidAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}paid_at']),
      transactionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}transaction_id']),
    );
  }

  @override
  $InstallmentPeriodsTable createAlias(String alias) {
    return $InstallmentPeriodsTable(attachedDatabase, alias);
  }
}

class InstallmentPeriod extends DataClass
    implements Insertable<InstallmentPeriod> {
  final int updatedAt;
  final bool deleted;
  final bool dirty;
  final int? syncedAt;
  final String id;
  final String planId;
  final int periodIndex;
  final int amountMinor;
  final int dueAt;
  final int? paidAt;
  final String? transactionId;
  const InstallmentPeriod(
      {required this.updatedAt,
      required this.deleted,
      required this.dirty,
      this.syncedAt,
      required this.id,
      required this.planId,
      required this.periodIndex,
      required this.amountMinor,
      required this.dueAt,
      this.paidAt,
      this.transactionId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<int>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<int>(syncedAt);
    }
    map['id'] = Variable<String>(id);
    map['plan_id'] = Variable<String>(planId);
    map['period_index'] = Variable<int>(periodIndex);
    map['amount_minor'] = Variable<int>(amountMinor);
    map['due_at'] = Variable<int>(dueAt);
    if (!nullToAbsent || paidAt != null) {
      map['paid_at'] = Variable<int>(paidAt);
    }
    if (!nullToAbsent || transactionId != null) {
      map['transaction_id'] = Variable<String>(transactionId);
    }
    return map;
  }

  InstallmentPeriodsCompanion toCompanion(bool nullToAbsent) {
    return InstallmentPeriodsCompanion(
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      dirty: Value(dirty),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      id: Value(id),
      planId: Value(planId),
      periodIndex: Value(periodIndex),
      amountMinor: Value(amountMinor),
      dueAt: Value(dueAt),
      paidAt:
          paidAt == null && nullToAbsent ? const Value.absent() : Value(paidAt),
      transactionId: transactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(transactionId),
    );
  }

  factory InstallmentPeriod.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InstallmentPeriod(
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      syncedAt: serializer.fromJson<int?>(json['syncedAt']),
      id: serializer.fromJson<String>(json['id']),
      planId: serializer.fromJson<String>(json['planId']),
      periodIndex: serializer.fromJson<int>(json['periodIndex']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      dueAt: serializer.fromJson<int>(json['dueAt']),
      paidAt: serializer.fromJson<int?>(json['paidAt']),
      transactionId: serializer.fromJson<String?>(json['transactionId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'syncedAt': serializer.toJson<int?>(syncedAt),
      'id': serializer.toJson<String>(id),
      'planId': serializer.toJson<String>(planId),
      'periodIndex': serializer.toJson<int>(periodIndex),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'dueAt': serializer.toJson<int>(dueAt),
      'paidAt': serializer.toJson<int?>(paidAt),
      'transactionId': serializer.toJson<String?>(transactionId),
    };
  }

  InstallmentPeriod copyWith(
          {int? updatedAt,
          bool? deleted,
          bool? dirty,
          Value<int?> syncedAt = const Value.absent(),
          String? id,
          String? planId,
          int? periodIndex,
          int? amountMinor,
          int? dueAt,
          Value<int?> paidAt = const Value.absent(),
          Value<String?> transactionId = const Value.absent()}) =>
      InstallmentPeriod(
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        dirty: dirty ?? this.dirty,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
        id: id ?? this.id,
        planId: planId ?? this.planId,
        periodIndex: periodIndex ?? this.periodIndex,
        amountMinor: amountMinor ?? this.amountMinor,
        dueAt: dueAt ?? this.dueAt,
        paidAt: paidAt.present ? paidAt.value : this.paidAt,
        transactionId:
            transactionId.present ? transactionId.value : this.transactionId,
      );
  InstallmentPeriod copyWithCompanion(InstallmentPeriodsCompanion data) {
    return InstallmentPeriod(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      id: data.id.present ? data.id.value : this.id,
      planId: data.planId.present ? data.planId.value : this.planId,
      periodIndex:
          data.periodIndex.present ? data.periodIndex.value : this.periodIndex,
      amountMinor:
          data.amountMinor.present ? data.amountMinor.value : this.amountMinor,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      paidAt: data.paidAt.present ? data.paidAt.value : this.paidAt,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InstallmentPeriod(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('periodIndex: $periodIndex, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('dueAt: $dueAt, ')
          ..write('paidAt: $paidAt, ')
          ..write('transactionId: $transactionId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(updatedAt, deleted, dirty, syncedAt, id,
      planId, periodIndex, amountMinor, dueAt, paidAt, transactionId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InstallmentPeriod &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.syncedAt == this.syncedAt &&
          other.id == this.id &&
          other.planId == this.planId &&
          other.periodIndex == this.periodIndex &&
          other.amountMinor == this.amountMinor &&
          other.dueAt == this.dueAt &&
          other.paidAt == this.paidAt &&
          other.transactionId == this.transactionId);
}

class InstallmentPeriodsCompanion extends UpdateCompanion<InstallmentPeriod> {
  final Value<int> updatedAt;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<int?> syncedAt;
  final Value<String> id;
  final Value<String> planId;
  final Value<int> periodIndex;
  final Value<int> amountMinor;
  final Value<int> dueAt;
  final Value<int?> paidAt;
  final Value<String?> transactionId;
  final Value<int> rowid;
  const InstallmentPeriodsCompanion({
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.planId = const Value.absent(),
    this.periodIndex = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.paidAt = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InstallmentPeriodsCompanion.insert({
    required int updatedAt,
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    required String id,
    required String planId,
    required int periodIndex,
    required int amountMinor,
    required int dueAt,
    this.paidAt = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : updatedAt = Value(updatedAt),
        id = Value(id),
        planId = Value(planId),
        periodIndex = Value(periodIndex),
        amountMinor = Value(amountMinor),
        dueAt = Value(dueAt);
  static Insertable<InstallmentPeriod> custom({
    Expression<int>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<int>? syncedAt,
    Expression<String>? id,
    Expression<String>? planId,
    Expression<int>? periodIndex,
    Expression<int>? amountMinor,
    Expression<int>? dueAt,
    Expression<int>? paidAt,
    Expression<String>? transactionId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (id != null) 'id': id,
      if (planId != null) 'plan_id': planId,
      if (periodIndex != null) 'period_index': periodIndex,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (dueAt != null) 'due_at': dueAt,
      if (paidAt != null) 'paid_at': paidAt,
      if (transactionId != null) 'transaction_id': transactionId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InstallmentPeriodsCompanion copyWith(
      {Value<int>? updatedAt,
      Value<bool>? deleted,
      Value<bool>? dirty,
      Value<int?>? syncedAt,
      Value<String>? id,
      Value<String>? planId,
      Value<int>? periodIndex,
      Value<int>? amountMinor,
      Value<int>? dueAt,
      Value<int?>? paidAt,
      Value<String?>? transactionId,
      Value<int>? rowid}) {
    return InstallmentPeriodsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      syncedAt: syncedAt ?? this.syncedAt,
      id: id ?? this.id,
      planId: planId ?? this.planId,
      periodIndex: periodIndex ?? this.periodIndex,
      amountMinor: amountMinor ?? this.amountMinor,
      dueAt: dueAt ?? this.dueAt,
      paidAt: paidAt ?? this.paidAt,
      transactionId: transactionId ?? this.transactionId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (periodIndex.present) {
      map['period_index'] = Variable<int>(periodIndex.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<int>(dueAt.value);
    }
    if (paidAt.present) {
      map['paid_at'] = Variable<int>(paidAt.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<String>(transactionId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InstallmentPeriodsCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('periodIndex: $periodIndex, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('dueAt: $dueAt, ')
          ..write('paidAt: $paidAt, ')
          ..write('transactionId: $transactionId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BudgetsTable extends Budgets with TableInfo<$BudgetsTable, Budget> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
      'dirty', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("dirty" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
      'book_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumnWithTypeConverter<BudgetScope, int> scope =
      GeneratedColumn<int>('scope', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<BudgetScope>($BudgetsTable.$converterscope);
  static const VerificationMeta _periodMeta = const VerificationMeta('period');
  @override
  late final GeneratedColumnWithTypeConverter<BudgetPeriod, int> period =
      GeneratedColumn<int>('period', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<BudgetPeriod>($BudgetsTable.$converterperiod);
  static const VerificationMeta _amountMinorMeta =
      const VerificationMeta('amountMinor');
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
      'amount_minor', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('CNY'));
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
      'category_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
      'year', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _periodIndexMeta =
      const VerificationMeta('periodIndex');
  @override
  late final GeneratedColumn<int> periodIndex = GeneratedColumn<int>(
      'period_index', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _alertEnabledMeta =
      const VerificationMeta('alertEnabled');
  @override
  late final GeneratedColumn<bool> alertEnabled = GeneratedColumn<bool>(
      'alert_enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("alert_enabled" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _alertThresholdMeta =
      const VerificationMeta('alertThreshold');
  @override
  late final GeneratedColumn<int> alertThreshold = GeneratedColumn<int>(
      'alert_threshold', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(80));
  @override
  List<GeneratedColumn> get $columns => [
        updatedAt,
        deleted,
        dirty,
        syncedAt,
        id,
        bookId,
        scope,
        period,
        amountMinor,
        currency,
        categoryId,
        year,
        periodIndex,
        alertEnabled,
        alertThreshold
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budgets';
  @override
  VerificationContext validateIntegrity(Insertable<Budget> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('dirty')) {
      context.handle(
          _dirtyMeta, dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    context.handle(_scopeMeta, const VerificationResult.success());
    context.handle(_periodMeta, const VerificationResult.success());
    if (data.containsKey('amount_minor')) {
      context.handle(
          _amountMinorMeta,
          amountMinor.isAcceptableOrUnknown(
              data['amount_minor']!, _amountMinorMeta));
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    }
    if (data.containsKey('year')) {
      context.handle(
          _yearMeta, year.isAcceptableOrUnknown(data['year']!, _yearMeta));
    } else if (isInserting) {
      context.missing(_yearMeta);
    }
    if (data.containsKey('period_index')) {
      context.handle(
          _periodIndexMeta,
          periodIndex.isAcceptableOrUnknown(
              data['period_index']!, _periodIndexMeta));
    }
    if (data.containsKey('alert_enabled')) {
      context.handle(
          _alertEnabledMeta,
          alertEnabled.isAcceptableOrUnknown(
              data['alert_enabled']!, _alertEnabledMeta));
    }
    if (data.containsKey('alert_threshold')) {
      context.handle(
          _alertThresholdMeta,
          alertThreshold.isAcceptableOrUnknown(
              data['alert_threshold']!, _alertThresholdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Budget map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Budget(
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      dirty: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}dirty'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}synced_at']),
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_id'])!,
      scope: $BudgetsTable.$converterscope.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}scope'])!),
      period: $BudgetsTable.$converterperiod.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}period'])!),
      amountMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}amount_minor'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category_id']),
      year: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}year'])!,
      periodIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}period_index'])!,
      alertEnabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}alert_enabled'])!,
      alertThreshold: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}alert_threshold'])!,
    );
  }

  @override
  $BudgetsTable createAlias(String alias) {
    return $BudgetsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<BudgetScope, int, int> $converterscope =
      const EnumIndexConverter<BudgetScope>(BudgetScope.values);
  static JsonTypeConverter2<BudgetPeriod, int, int> $converterperiod =
      const EnumIndexConverter<BudgetPeriod>(BudgetPeriod.values);
}

class Budget extends DataClass implements Insertable<Budget> {
  final int updatedAt;
  final bool deleted;
  final bool dirty;
  final int? syncedAt;
  final String id;
  final String bookId;
  final BudgetScope scope;
  final BudgetPeriod period;

  /// 预算额度（分）
  final int amountMinor;
  final String currency;

  /// scope 为 category 时必填
  final String? categoryId;

  /// 生效年份，如 2026
  final int year;

  /// 生效月份或季度序号：月度 1-12，季度 1-4，年度固定 0
  final int periodIndex;
  final bool alertEnabled;

  /// 提醒阈值，如 80 表示用掉 80% 时提醒
  final int alertThreshold;
  const Budget(
      {required this.updatedAt,
      required this.deleted,
      required this.dirty,
      this.syncedAt,
      required this.id,
      required this.bookId,
      required this.scope,
      required this.period,
      required this.amountMinor,
      required this.currency,
      this.categoryId,
      required this.year,
      required this.periodIndex,
      required this.alertEnabled,
      required this.alertThreshold});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<int>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<int>(syncedAt);
    }
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    {
      map['scope'] = Variable<int>($BudgetsTable.$converterscope.toSql(scope));
    }
    {
      map['period'] =
          Variable<int>($BudgetsTable.$converterperiod.toSql(period));
    }
    map['amount_minor'] = Variable<int>(amountMinor);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['year'] = Variable<int>(year);
    map['period_index'] = Variable<int>(periodIndex);
    map['alert_enabled'] = Variable<bool>(alertEnabled);
    map['alert_threshold'] = Variable<int>(alertThreshold);
    return map;
  }

  BudgetsCompanion toCompanion(bool nullToAbsent) {
    return BudgetsCompanion(
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      dirty: Value(dirty),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      id: Value(id),
      bookId: Value(bookId),
      scope: Value(scope),
      period: Value(period),
      amountMinor: Value(amountMinor),
      currency: Value(currency),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      year: Value(year),
      periodIndex: Value(periodIndex),
      alertEnabled: Value(alertEnabled),
      alertThreshold: Value(alertThreshold),
    );
  }

  factory Budget.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Budget(
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      syncedAt: serializer.fromJson<int?>(json['syncedAt']),
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      scope: $BudgetsTable.$converterscope
          .fromJson(serializer.fromJson<int>(json['scope'])),
      period: $BudgetsTable.$converterperiod
          .fromJson(serializer.fromJson<int>(json['period'])),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      currency: serializer.fromJson<String>(json['currency']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      year: serializer.fromJson<int>(json['year']),
      periodIndex: serializer.fromJson<int>(json['periodIndex']),
      alertEnabled: serializer.fromJson<bool>(json['alertEnabled']),
      alertThreshold: serializer.fromJson<int>(json['alertThreshold']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'syncedAt': serializer.toJson<int?>(syncedAt),
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'scope':
          serializer.toJson<int>($BudgetsTable.$converterscope.toJson(scope)),
      'period':
          serializer.toJson<int>($BudgetsTable.$converterperiod.toJson(period)),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'currency': serializer.toJson<String>(currency),
      'categoryId': serializer.toJson<String?>(categoryId),
      'year': serializer.toJson<int>(year),
      'periodIndex': serializer.toJson<int>(periodIndex),
      'alertEnabled': serializer.toJson<bool>(alertEnabled),
      'alertThreshold': serializer.toJson<int>(alertThreshold),
    };
  }

  Budget copyWith(
          {int? updatedAt,
          bool? deleted,
          bool? dirty,
          Value<int?> syncedAt = const Value.absent(),
          String? id,
          String? bookId,
          BudgetScope? scope,
          BudgetPeriod? period,
          int? amountMinor,
          String? currency,
          Value<String?> categoryId = const Value.absent(),
          int? year,
          int? periodIndex,
          bool? alertEnabled,
          int? alertThreshold}) =>
      Budget(
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        dirty: dirty ?? this.dirty,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        scope: scope ?? this.scope,
        period: period ?? this.period,
        amountMinor: amountMinor ?? this.amountMinor,
        currency: currency ?? this.currency,
        categoryId: categoryId.present ? categoryId.value : this.categoryId,
        year: year ?? this.year,
        periodIndex: periodIndex ?? this.periodIndex,
        alertEnabled: alertEnabled ?? this.alertEnabled,
        alertThreshold: alertThreshold ?? this.alertThreshold,
      );
  Budget copyWithCompanion(BudgetsCompanion data) {
    return Budget(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      scope: data.scope.present ? data.scope.value : this.scope,
      period: data.period.present ? data.period.value : this.period,
      amountMinor:
          data.amountMinor.present ? data.amountMinor.value : this.amountMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      year: data.year.present ? data.year.value : this.year,
      periodIndex:
          data.periodIndex.present ? data.periodIndex.value : this.periodIndex,
      alertEnabled: data.alertEnabled.present
          ? data.alertEnabled.value
          : this.alertEnabled,
      alertThreshold: data.alertThreshold.present
          ? data.alertThreshold.value
          : this.alertThreshold,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Budget(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('scope: $scope, ')
          ..write('period: $period, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('categoryId: $categoryId, ')
          ..write('year: $year, ')
          ..write('periodIndex: $periodIndex, ')
          ..write('alertEnabled: $alertEnabled, ')
          ..write('alertThreshold: $alertThreshold')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      updatedAt,
      deleted,
      dirty,
      syncedAt,
      id,
      bookId,
      scope,
      period,
      amountMinor,
      currency,
      categoryId,
      year,
      periodIndex,
      alertEnabled,
      alertThreshold);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Budget &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.syncedAt == this.syncedAt &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.scope == this.scope &&
          other.period == this.period &&
          other.amountMinor == this.amountMinor &&
          other.currency == this.currency &&
          other.categoryId == this.categoryId &&
          other.year == this.year &&
          other.periodIndex == this.periodIndex &&
          other.alertEnabled == this.alertEnabled &&
          other.alertThreshold == this.alertThreshold);
}

class BudgetsCompanion extends UpdateCompanion<Budget> {
  final Value<int> updatedAt;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<int?> syncedAt;
  final Value<String> id;
  final Value<String> bookId;
  final Value<BudgetScope> scope;
  final Value<BudgetPeriod> period;
  final Value<int> amountMinor;
  final Value<String> currency;
  final Value<String?> categoryId;
  final Value<int> year;
  final Value<int> periodIndex;
  final Value<bool> alertEnabled;
  final Value<int> alertThreshold;
  final Value<int> rowid;
  const BudgetsCompanion({
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.scope = const Value.absent(),
    this.period = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.year = const Value.absent(),
    this.periodIndex = const Value.absent(),
    this.alertEnabled = const Value.absent(),
    this.alertThreshold = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BudgetsCompanion.insert({
    required int updatedAt,
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    required String id,
    required String bookId,
    required BudgetScope scope,
    required BudgetPeriod period,
    required int amountMinor,
    this.currency = const Value.absent(),
    this.categoryId = const Value.absent(),
    required int year,
    this.periodIndex = const Value.absent(),
    this.alertEnabled = const Value.absent(),
    this.alertThreshold = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : updatedAt = Value(updatedAt),
        id = Value(id),
        bookId = Value(bookId),
        scope = Value(scope),
        period = Value(period),
        amountMinor = Value(amountMinor),
        year = Value(year);
  static Insertable<Budget> custom({
    Expression<int>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<int>? syncedAt,
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<int>? scope,
    Expression<int>? period,
    Expression<int>? amountMinor,
    Expression<String>? currency,
    Expression<String>? categoryId,
    Expression<int>? year,
    Expression<int>? periodIndex,
    Expression<bool>? alertEnabled,
    Expression<int>? alertThreshold,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (scope != null) 'scope': scope,
      if (period != null) 'period': period,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (currency != null) 'currency': currency,
      if (categoryId != null) 'category_id': categoryId,
      if (year != null) 'year': year,
      if (periodIndex != null) 'period_index': periodIndex,
      if (alertEnabled != null) 'alert_enabled': alertEnabled,
      if (alertThreshold != null) 'alert_threshold': alertThreshold,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BudgetsCompanion copyWith(
      {Value<int>? updatedAt,
      Value<bool>? deleted,
      Value<bool>? dirty,
      Value<int?>? syncedAt,
      Value<String>? id,
      Value<String>? bookId,
      Value<BudgetScope>? scope,
      Value<BudgetPeriod>? period,
      Value<int>? amountMinor,
      Value<String>? currency,
      Value<String?>? categoryId,
      Value<int>? year,
      Value<int>? periodIndex,
      Value<bool>? alertEnabled,
      Value<int>? alertThreshold,
      Value<int>? rowid}) {
    return BudgetsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      syncedAt: syncedAt ?? this.syncedAt,
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      scope: scope ?? this.scope,
      period: period ?? this.period,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      categoryId: categoryId ?? this.categoryId,
      year: year ?? this.year,
      periodIndex: periodIndex ?? this.periodIndex,
      alertEnabled: alertEnabled ?? this.alertEnabled,
      alertThreshold: alertThreshold ?? this.alertThreshold,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (scope.present) {
      map['scope'] =
          Variable<int>($BudgetsTable.$converterscope.toSql(scope.value));
    }
    if (period.present) {
      map['period'] =
          Variable<int>($BudgetsTable.$converterperiod.toSql(period.value));
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (periodIndex.present) {
      map['period_index'] = Variable<int>(periodIndex.value);
    }
    if (alertEnabled.present) {
      map['alert_enabled'] = Variable<bool>(alertEnabled.value);
    }
    if (alertThreshold.present) {
      map['alert_threshold'] = Variable<int>(alertThreshold.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BudgetsCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('scope: $scope, ')
          ..write('period: $period, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('categoryId: $categoryId, ')
          ..write('year: $year, ')
          ..write('periodIndex: $periodIndex, ')
          ..write('alertEnabled: $alertEnabled, ')
          ..write('alertThreshold: $alertThreshold, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InvestmentHoldingsTable extends InvestmentHoldings
    with TableInfo<$InvestmentHoldingsTable, InvestmentHolding> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InvestmentHoldingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
      'dirty', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("dirty" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
      'book_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
      'symbol', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumnWithTypeConverter<InvestmentType, int> type =
      GeneratedColumn<int>('type', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<InvestmentType>(
              $InvestmentHoldingsTable.$convertertype);
  static const VerificationMeta _quantityMicrosMeta =
      const VerificationMeta('quantityMicros');
  @override
  late final GeneratedColumn<int> quantityMicros = GeneratedColumn<int>(
      'quantity_micros', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _avgCostMinorMeta =
      const VerificationMeta('avgCostMinor');
  @override
  late final GeneratedColumn<int> avgCostMinor = GeneratedColumn<int>(
      'avg_cost_minor', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _currentPriceMinorMeta =
      const VerificationMeta('currentPriceMinor');
  @override
  late final GeneratedColumn<int> currentPriceMinor = GeneratedColumn<int>(
      'current_price_minor', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('CNY'));
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _priceUpdatedAtMeta =
      const VerificationMeta('priceUpdatedAt');
  @override
  late final GeneratedColumn<int> priceUpdatedAt = GeneratedColumn<int>(
      'price_updated_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        updatedAt,
        deleted,
        dirty,
        syncedAt,
        id,
        bookId,
        symbol,
        name,
        type,
        quantityMicros,
        avgCostMinor,
        currentPriceMinor,
        currency,
        accountId,
        priceUpdatedAt,
        note
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'investment_holdings';
  @override
  VerificationContext validateIntegrity(Insertable<InvestmentHolding> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('dirty')) {
      context.handle(
          _dirtyMeta, dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('symbol')) {
      context.handle(_symbolMeta,
          symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta));
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    context.handle(_typeMeta, const VerificationResult.success());
    if (data.containsKey('quantity_micros')) {
      context.handle(
          _quantityMicrosMeta,
          quantityMicros.isAcceptableOrUnknown(
              data['quantity_micros']!, _quantityMicrosMeta));
    }
    if (data.containsKey('avg_cost_minor')) {
      context.handle(
          _avgCostMinorMeta,
          avgCostMinor.isAcceptableOrUnknown(
              data['avg_cost_minor']!, _avgCostMinorMeta));
    }
    if (data.containsKey('current_price_minor')) {
      context.handle(
          _currentPriceMinorMeta,
          currentPriceMinor.isAcceptableOrUnknown(
              data['current_price_minor']!, _currentPriceMinorMeta));
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    }
    if (data.containsKey('price_updated_at')) {
      context.handle(
          _priceUpdatedAtMeta,
          priceUpdatedAt.isAcceptableOrUnknown(
              data['price_updated_at']!, _priceUpdatedAtMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InvestmentHolding map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InvestmentHolding(
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      dirty: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}dirty'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}synced_at']),
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_id'])!,
      symbol: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}symbol'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      type: $InvestmentHoldingsTable.$convertertype.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}type'])!),
      quantityMicros: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}quantity_micros'])!,
      avgCostMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}avg_cost_minor'])!,
      currentPriceMinor: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}current_price_minor'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id']),
      priceUpdatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}price_updated_at']),
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
    );
  }

  @override
  $InvestmentHoldingsTable createAlias(String alias) {
    return $InvestmentHoldingsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<InvestmentType, int, int> $convertertype =
      const EnumIndexConverter<InvestmentType>(InvestmentType.values);
}

class InvestmentHolding extends DataClass
    implements Insertable<InvestmentHolding> {
  final int updatedAt;
  final bool deleted;
  final bool dirty;
  final int? syncedAt;
  final String id;
  final String bookId;
  final String symbol;
  final String name;
  final InvestmentType type;

  /// 份额，放大 1e6 倍存储以保留小数精度
  final int quantityMicros;

  /// 成本均价（分）
  final int avgCostMinor;

  /// 当前价（分）
  final int currentPriceMinor;
  final String currency;
  final String? accountId;
  final int? priceUpdatedAt;
  final String? note;
  const InvestmentHolding(
      {required this.updatedAt,
      required this.deleted,
      required this.dirty,
      this.syncedAt,
      required this.id,
      required this.bookId,
      required this.symbol,
      required this.name,
      required this.type,
      required this.quantityMicros,
      required this.avgCostMinor,
      required this.currentPriceMinor,
      required this.currency,
      this.accountId,
      this.priceUpdatedAt,
      this.note});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<int>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<int>(syncedAt);
    }
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['symbol'] = Variable<String>(symbol);
    map['name'] = Variable<String>(name);
    {
      map['type'] =
          Variable<int>($InvestmentHoldingsTable.$convertertype.toSql(type));
    }
    map['quantity_micros'] = Variable<int>(quantityMicros);
    map['avg_cost_minor'] = Variable<int>(avgCostMinor);
    map['current_price_minor'] = Variable<int>(currentPriceMinor);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<String>(accountId);
    }
    if (!nullToAbsent || priceUpdatedAt != null) {
      map['price_updated_at'] = Variable<int>(priceUpdatedAt);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  InvestmentHoldingsCompanion toCompanion(bool nullToAbsent) {
    return InvestmentHoldingsCompanion(
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      dirty: Value(dirty),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      id: Value(id),
      bookId: Value(bookId),
      symbol: Value(symbol),
      name: Value(name),
      type: Value(type),
      quantityMicros: Value(quantityMicros),
      avgCostMinor: Value(avgCostMinor),
      currentPriceMinor: Value(currentPriceMinor),
      currency: Value(currency),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      priceUpdatedAt: priceUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(priceUpdatedAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory InvestmentHolding.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InvestmentHolding(
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      syncedAt: serializer.fromJson<int?>(json['syncedAt']),
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      symbol: serializer.fromJson<String>(json['symbol']),
      name: serializer.fromJson<String>(json['name']),
      type: $InvestmentHoldingsTable.$convertertype
          .fromJson(serializer.fromJson<int>(json['type'])),
      quantityMicros: serializer.fromJson<int>(json['quantityMicros']),
      avgCostMinor: serializer.fromJson<int>(json['avgCostMinor']),
      currentPriceMinor: serializer.fromJson<int>(json['currentPriceMinor']),
      currency: serializer.fromJson<String>(json['currency']),
      accountId: serializer.fromJson<String?>(json['accountId']),
      priceUpdatedAt: serializer.fromJson<int?>(json['priceUpdatedAt']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'syncedAt': serializer.toJson<int?>(syncedAt),
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'symbol': serializer.toJson<String>(symbol),
      'name': serializer.toJson<String>(name),
      'type': serializer
          .toJson<int>($InvestmentHoldingsTable.$convertertype.toJson(type)),
      'quantityMicros': serializer.toJson<int>(quantityMicros),
      'avgCostMinor': serializer.toJson<int>(avgCostMinor),
      'currentPriceMinor': serializer.toJson<int>(currentPriceMinor),
      'currency': serializer.toJson<String>(currency),
      'accountId': serializer.toJson<String?>(accountId),
      'priceUpdatedAt': serializer.toJson<int?>(priceUpdatedAt),
      'note': serializer.toJson<String?>(note),
    };
  }

  InvestmentHolding copyWith(
          {int? updatedAt,
          bool? deleted,
          bool? dirty,
          Value<int?> syncedAt = const Value.absent(),
          String? id,
          String? bookId,
          String? symbol,
          String? name,
          InvestmentType? type,
          int? quantityMicros,
          int? avgCostMinor,
          int? currentPriceMinor,
          String? currency,
          Value<String?> accountId = const Value.absent(),
          Value<int?> priceUpdatedAt = const Value.absent(),
          Value<String?> note = const Value.absent()}) =>
      InvestmentHolding(
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        dirty: dirty ?? this.dirty,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        symbol: symbol ?? this.symbol,
        name: name ?? this.name,
        type: type ?? this.type,
        quantityMicros: quantityMicros ?? this.quantityMicros,
        avgCostMinor: avgCostMinor ?? this.avgCostMinor,
        currentPriceMinor: currentPriceMinor ?? this.currentPriceMinor,
        currency: currency ?? this.currency,
        accountId: accountId.present ? accountId.value : this.accountId,
        priceUpdatedAt:
            priceUpdatedAt.present ? priceUpdatedAt.value : this.priceUpdatedAt,
        note: note.present ? note.value : this.note,
      );
  InvestmentHolding copyWithCompanion(InvestmentHoldingsCompanion data) {
    return InvestmentHolding(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      quantityMicros: data.quantityMicros.present
          ? data.quantityMicros.value
          : this.quantityMicros,
      avgCostMinor: data.avgCostMinor.present
          ? data.avgCostMinor.value
          : this.avgCostMinor,
      currentPriceMinor: data.currentPriceMinor.present
          ? data.currentPriceMinor.value
          : this.currentPriceMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      priceUpdatedAt: data.priceUpdatedAt.present
          ? data.priceUpdatedAt.value
          : this.priceUpdatedAt,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InvestmentHolding(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('symbol: $symbol, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('quantityMicros: $quantityMicros, ')
          ..write('avgCostMinor: $avgCostMinor, ')
          ..write('currentPriceMinor: $currentPriceMinor, ')
          ..write('currency: $currency, ')
          ..write('accountId: $accountId, ')
          ..write('priceUpdatedAt: $priceUpdatedAt, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      updatedAt,
      deleted,
      dirty,
      syncedAt,
      id,
      bookId,
      symbol,
      name,
      type,
      quantityMicros,
      avgCostMinor,
      currentPriceMinor,
      currency,
      accountId,
      priceUpdatedAt,
      note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InvestmentHolding &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.syncedAt == this.syncedAt &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.symbol == this.symbol &&
          other.name == this.name &&
          other.type == this.type &&
          other.quantityMicros == this.quantityMicros &&
          other.avgCostMinor == this.avgCostMinor &&
          other.currentPriceMinor == this.currentPriceMinor &&
          other.currency == this.currency &&
          other.accountId == this.accountId &&
          other.priceUpdatedAt == this.priceUpdatedAt &&
          other.note == this.note);
}

class InvestmentHoldingsCompanion extends UpdateCompanion<InvestmentHolding> {
  final Value<int> updatedAt;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<int?> syncedAt;
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> symbol;
  final Value<String> name;
  final Value<InvestmentType> type;
  final Value<int> quantityMicros;
  final Value<int> avgCostMinor;
  final Value<int> currentPriceMinor;
  final Value<String> currency;
  final Value<String?> accountId;
  final Value<int?> priceUpdatedAt;
  final Value<String?> note;
  final Value<int> rowid;
  const InvestmentHoldingsCompanion({
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.symbol = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.quantityMicros = const Value.absent(),
    this.avgCostMinor = const Value.absent(),
    this.currentPriceMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.accountId = const Value.absent(),
    this.priceUpdatedAt = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InvestmentHoldingsCompanion.insert({
    required int updatedAt,
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    required String id,
    required String bookId,
    required String symbol,
    required String name,
    required InvestmentType type,
    this.quantityMicros = const Value.absent(),
    this.avgCostMinor = const Value.absent(),
    this.currentPriceMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.accountId = const Value.absent(),
    this.priceUpdatedAt = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : updatedAt = Value(updatedAt),
        id = Value(id),
        bookId = Value(bookId),
        symbol = Value(symbol),
        name = Value(name),
        type = Value(type);
  static Insertable<InvestmentHolding> custom({
    Expression<int>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<int>? syncedAt,
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? symbol,
    Expression<String>? name,
    Expression<int>? type,
    Expression<int>? quantityMicros,
    Expression<int>? avgCostMinor,
    Expression<int>? currentPriceMinor,
    Expression<String>? currency,
    Expression<String>? accountId,
    Expression<int>? priceUpdatedAt,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (symbol != null) 'symbol': symbol,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (quantityMicros != null) 'quantity_micros': quantityMicros,
      if (avgCostMinor != null) 'avg_cost_minor': avgCostMinor,
      if (currentPriceMinor != null) 'current_price_minor': currentPriceMinor,
      if (currency != null) 'currency': currency,
      if (accountId != null) 'account_id': accountId,
      if (priceUpdatedAt != null) 'price_updated_at': priceUpdatedAt,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InvestmentHoldingsCompanion copyWith(
      {Value<int>? updatedAt,
      Value<bool>? deleted,
      Value<bool>? dirty,
      Value<int?>? syncedAt,
      Value<String>? id,
      Value<String>? bookId,
      Value<String>? symbol,
      Value<String>? name,
      Value<InvestmentType>? type,
      Value<int>? quantityMicros,
      Value<int>? avgCostMinor,
      Value<int>? currentPriceMinor,
      Value<String>? currency,
      Value<String?>? accountId,
      Value<int?>? priceUpdatedAt,
      Value<String?>? note,
      Value<int>? rowid}) {
    return InvestmentHoldingsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      syncedAt: syncedAt ?? this.syncedAt,
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      type: type ?? this.type,
      quantityMicros: quantityMicros ?? this.quantityMicros,
      avgCostMinor: avgCostMinor ?? this.avgCostMinor,
      currentPriceMinor: currentPriceMinor ?? this.currentPriceMinor,
      currency: currency ?? this.currency,
      accountId: accountId ?? this.accountId,
      priceUpdatedAt: priceUpdatedAt ?? this.priceUpdatedAt,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(
          $InvestmentHoldingsTable.$convertertype.toSql(type.value));
    }
    if (quantityMicros.present) {
      map['quantity_micros'] = Variable<int>(quantityMicros.value);
    }
    if (avgCostMinor.present) {
      map['avg_cost_minor'] = Variable<int>(avgCostMinor.value);
    }
    if (currentPriceMinor.present) {
      map['current_price_minor'] = Variable<int>(currentPriceMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (priceUpdatedAt.present) {
      map['price_updated_at'] = Variable<int>(priceUpdatedAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InvestmentHoldingsCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('symbol: $symbol, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('quantityMicros: $quantityMicros, ')
          ..write('avgCostMinor: $avgCostMinor, ')
          ..write('currentPriceMinor: $currentPriceMinor, ')
          ..write('currency: $currency, ')
          ..write('accountId: $accountId, ')
          ..write('priceUpdatedAt: $priceUpdatedAt, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InventoryItemsTable extends InventoryItems
    with TableInfo<$InventoryItemsTable, InventoryItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InventoryItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
      'dirty', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("dirty" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
      'book_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _purchasePriceMinorMeta =
      const VerificationMeta('purchasePriceMinor');
  @override
  late final GeneratedColumn<int> purchasePriceMinor = GeneratedColumn<int>(
      'purchase_price_minor', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _currentValueMinorMeta =
      const VerificationMeta('currentValueMinor');
  @override
  late final GeneratedColumn<int> currentValueMinor = GeneratedColumn<int>(
      'current_value_minor', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('CNY'));
  static const VerificationMeta _purchasedAtMeta =
      const VerificationMeta('purchasedAt');
  @override
  late final GeneratedColumn<int> purchasedAt = GeneratedColumn<int>(
      'purchased_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _warrantyUntilMeta =
      const VerificationMeta('warrantyUntil');
  @override
  late final GeneratedColumn<int> warrantyUntil = GeneratedColumn<int>(
      'warranty_until', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _photoUrlMeta =
      const VerificationMeta('photoUrl');
  @override
  late final GeneratedColumn<String> photoUrl = GeneratedColumn<String>(
      'photo_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _locationMeta =
      const VerificationMeta('location');
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
      'location', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _transactionIdMeta =
      const VerificationMeta('transactionId');
  @override
  late final GeneratedColumn<String> transactionId = GeneratedColumn<String>(
      'transaction_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        updatedAt,
        deleted,
        dirty,
        syncedAt,
        id,
        bookId,
        name,
        category,
        purchasePriceMinor,
        currentValueMinor,
        currency,
        purchasedAt,
        warrantyUntil,
        photoUrl,
        location,
        note,
        transactionId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inventory_items';
  @override
  VerificationContext validateIntegrity(Insertable<InventoryItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('dirty')) {
      context.handle(
          _dirtyMeta, dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('purchase_price_minor')) {
      context.handle(
          _purchasePriceMinorMeta,
          purchasePriceMinor.isAcceptableOrUnknown(
              data['purchase_price_minor']!, _purchasePriceMinorMeta));
    }
    if (data.containsKey('current_value_minor')) {
      context.handle(
          _currentValueMinorMeta,
          currentValueMinor.isAcceptableOrUnknown(
              data['current_value_minor']!, _currentValueMinorMeta));
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('purchased_at')) {
      context.handle(
          _purchasedAtMeta,
          purchasedAt.isAcceptableOrUnknown(
              data['purchased_at']!, _purchasedAtMeta));
    } else if (isInserting) {
      context.missing(_purchasedAtMeta);
    }
    if (data.containsKey('warranty_until')) {
      context.handle(
          _warrantyUntilMeta,
          warrantyUntil.isAcceptableOrUnknown(
              data['warranty_until']!, _warrantyUntilMeta));
    }
    if (data.containsKey('photo_url')) {
      context.handle(_photoUrlMeta,
          photoUrl.isAcceptableOrUnknown(data['photo_url']!, _photoUrlMeta));
    }
    if (data.containsKey('location')) {
      context.handle(_locationMeta,
          location.isAcceptableOrUnknown(data['location']!, _locationMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
          _transactionIdMeta,
          transactionId.isAcceptableOrUnknown(
              data['transaction_id']!, _transactionIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InventoryItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InventoryItem(
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      dirty: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}dirty'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}synced_at']),
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category']),
      purchasePriceMinor: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}purchase_price_minor'])!,
      currentValueMinor: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}current_value_minor'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      purchasedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}purchased_at'])!,
      warrantyUntil: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}warranty_until']),
      photoUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}photo_url']),
      location: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}location']),
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      transactionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}transaction_id']),
    );
  }

  @override
  $InventoryItemsTable createAlias(String alias) {
    return $InventoryItemsTable(attachedDatabase, alias);
  }
}

class InventoryItem extends DataClass implements Insertable<InventoryItem> {
  final int updatedAt;
  final bool deleted;
  final bool dirty;
  final int? syncedAt;
  final String id;
  final String bookId;
  final String name;
  final String? category;
  final int purchasePriceMinor;
  final int currentValueMinor;
  final String currency;
  final int purchasedAt;
  final int? warrantyUntil;
  final String? photoUrl;
  final String? location;
  final String? note;
  final String? transactionId;
  const InventoryItem(
      {required this.updatedAt,
      required this.deleted,
      required this.dirty,
      this.syncedAt,
      required this.id,
      required this.bookId,
      required this.name,
      this.category,
      required this.purchasePriceMinor,
      required this.currentValueMinor,
      required this.currency,
      required this.purchasedAt,
      this.warrantyUntil,
      this.photoUrl,
      this.location,
      this.note,
      this.transactionId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<int>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<int>(syncedAt);
    }
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['purchase_price_minor'] = Variable<int>(purchasePriceMinor);
    map['current_value_minor'] = Variable<int>(currentValueMinor);
    map['currency'] = Variable<String>(currency);
    map['purchased_at'] = Variable<int>(purchasedAt);
    if (!nullToAbsent || warrantyUntil != null) {
      map['warranty_until'] = Variable<int>(warrantyUntil);
    }
    if (!nullToAbsent || photoUrl != null) {
      map['photo_url'] = Variable<String>(photoUrl);
    }
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || transactionId != null) {
      map['transaction_id'] = Variable<String>(transactionId);
    }
    return map;
  }

  InventoryItemsCompanion toCompanion(bool nullToAbsent) {
    return InventoryItemsCompanion(
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      dirty: Value(dirty),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      id: Value(id),
      bookId: Value(bookId),
      name: Value(name),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      purchasePriceMinor: Value(purchasePriceMinor),
      currentValueMinor: Value(currentValueMinor),
      currency: Value(currency),
      purchasedAt: Value(purchasedAt),
      warrantyUntil: warrantyUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(warrantyUntil),
      photoUrl: photoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(photoUrl),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      transactionId: transactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(transactionId),
    );
  }

  factory InventoryItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InventoryItem(
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      syncedAt: serializer.fromJson<int?>(json['syncedAt']),
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String?>(json['category']),
      purchasePriceMinor: serializer.fromJson<int>(json['purchasePriceMinor']),
      currentValueMinor: serializer.fromJson<int>(json['currentValueMinor']),
      currency: serializer.fromJson<String>(json['currency']),
      purchasedAt: serializer.fromJson<int>(json['purchasedAt']),
      warrantyUntil: serializer.fromJson<int?>(json['warrantyUntil']),
      photoUrl: serializer.fromJson<String?>(json['photoUrl']),
      location: serializer.fromJson<String?>(json['location']),
      note: serializer.fromJson<String?>(json['note']),
      transactionId: serializer.fromJson<String?>(json['transactionId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'syncedAt': serializer.toJson<int?>(syncedAt),
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String?>(category),
      'purchasePriceMinor': serializer.toJson<int>(purchasePriceMinor),
      'currentValueMinor': serializer.toJson<int>(currentValueMinor),
      'currency': serializer.toJson<String>(currency),
      'purchasedAt': serializer.toJson<int>(purchasedAt),
      'warrantyUntil': serializer.toJson<int?>(warrantyUntil),
      'photoUrl': serializer.toJson<String?>(photoUrl),
      'location': serializer.toJson<String?>(location),
      'note': serializer.toJson<String?>(note),
      'transactionId': serializer.toJson<String?>(transactionId),
    };
  }

  InventoryItem copyWith(
          {int? updatedAt,
          bool? deleted,
          bool? dirty,
          Value<int?> syncedAt = const Value.absent(),
          String? id,
          String? bookId,
          String? name,
          Value<String?> category = const Value.absent(),
          int? purchasePriceMinor,
          int? currentValueMinor,
          String? currency,
          int? purchasedAt,
          Value<int?> warrantyUntil = const Value.absent(),
          Value<String?> photoUrl = const Value.absent(),
          Value<String?> location = const Value.absent(),
          Value<String?> note = const Value.absent(),
          Value<String?> transactionId = const Value.absent()}) =>
      InventoryItem(
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        dirty: dirty ?? this.dirty,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        name: name ?? this.name,
        category: category.present ? category.value : this.category,
        purchasePriceMinor: purchasePriceMinor ?? this.purchasePriceMinor,
        currentValueMinor: currentValueMinor ?? this.currentValueMinor,
        currency: currency ?? this.currency,
        purchasedAt: purchasedAt ?? this.purchasedAt,
        warrantyUntil:
            warrantyUntil.present ? warrantyUntil.value : this.warrantyUntil,
        photoUrl: photoUrl.present ? photoUrl.value : this.photoUrl,
        location: location.present ? location.value : this.location,
        note: note.present ? note.value : this.note,
        transactionId:
            transactionId.present ? transactionId.value : this.transactionId,
      );
  InventoryItem copyWithCompanion(InventoryItemsCompanion data) {
    return InventoryItem(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      purchasePriceMinor: data.purchasePriceMinor.present
          ? data.purchasePriceMinor.value
          : this.purchasePriceMinor,
      currentValueMinor: data.currentValueMinor.present
          ? data.currentValueMinor.value
          : this.currentValueMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      purchasedAt:
          data.purchasedAt.present ? data.purchasedAt.value : this.purchasedAt,
      warrantyUntil: data.warrantyUntil.present
          ? data.warrantyUntil.value
          : this.warrantyUntil,
      photoUrl: data.photoUrl.present ? data.photoUrl.value : this.photoUrl,
      location: data.location.present ? data.location.value : this.location,
      note: data.note.present ? data.note.value : this.note,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InventoryItem(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('purchasePriceMinor: $purchasePriceMinor, ')
          ..write('currentValueMinor: $currentValueMinor, ')
          ..write('currency: $currency, ')
          ..write('purchasedAt: $purchasedAt, ')
          ..write('warrantyUntil: $warrantyUntil, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('location: $location, ')
          ..write('note: $note, ')
          ..write('transactionId: $transactionId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      updatedAt,
      deleted,
      dirty,
      syncedAt,
      id,
      bookId,
      name,
      category,
      purchasePriceMinor,
      currentValueMinor,
      currency,
      purchasedAt,
      warrantyUntil,
      photoUrl,
      location,
      note,
      transactionId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InventoryItem &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.syncedAt == this.syncedAt &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.name == this.name &&
          other.category == this.category &&
          other.purchasePriceMinor == this.purchasePriceMinor &&
          other.currentValueMinor == this.currentValueMinor &&
          other.currency == this.currency &&
          other.purchasedAt == this.purchasedAt &&
          other.warrantyUntil == this.warrantyUntil &&
          other.photoUrl == this.photoUrl &&
          other.location == this.location &&
          other.note == this.note &&
          other.transactionId == this.transactionId);
}

class InventoryItemsCompanion extends UpdateCompanion<InventoryItem> {
  final Value<int> updatedAt;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<int?> syncedAt;
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> name;
  final Value<String?> category;
  final Value<int> purchasePriceMinor;
  final Value<int> currentValueMinor;
  final Value<String> currency;
  final Value<int> purchasedAt;
  final Value<int?> warrantyUntil;
  final Value<String?> photoUrl;
  final Value<String?> location;
  final Value<String?> note;
  final Value<String?> transactionId;
  final Value<int> rowid;
  const InventoryItemsCompanion({
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.purchasePriceMinor = const Value.absent(),
    this.currentValueMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.purchasedAt = const Value.absent(),
    this.warrantyUntil = const Value.absent(),
    this.photoUrl = const Value.absent(),
    this.location = const Value.absent(),
    this.note = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InventoryItemsCompanion.insert({
    required int updatedAt,
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    required String id,
    required String bookId,
    required String name,
    this.category = const Value.absent(),
    this.purchasePriceMinor = const Value.absent(),
    this.currentValueMinor = const Value.absent(),
    this.currency = const Value.absent(),
    required int purchasedAt,
    this.warrantyUntil = const Value.absent(),
    this.photoUrl = const Value.absent(),
    this.location = const Value.absent(),
    this.note = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : updatedAt = Value(updatedAt),
        id = Value(id),
        bookId = Value(bookId),
        name = Value(name),
        purchasedAt = Value(purchasedAt);
  static Insertable<InventoryItem> custom({
    Expression<int>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<int>? syncedAt,
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? name,
    Expression<String>? category,
    Expression<int>? purchasePriceMinor,
    Expression<int>? currentValueMinor,
    Expression<String>? currency,
    Expression<int>? purchasedAt,
    Expression<int>? warrantyUntil,
    Expression<String>? photoUrl,
    Expression<String>? location,
    Expression<String>? note,
    Expression<String>? transactionId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (purchasePriceMinor != null)
        'purchase_price_minor': purchasePriceMinor,
      if (currentValueMinor != null) 'current_value_minor': currentValueMinor,
      if (currency != null) 'currency': currency,
      if (purchasedAt != null) 'purchased_at': purchasedAt,
      if (warrantyUntil != null) 'warranty_until': warrantyUntil,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (location != null) 'location': location,
      if (note != null) 'note': note,
      if (transactionId != null) 'transaction_id': transactionId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InventoryItemsCompanion copyWith(
      {Value<int>? updatedAt,
      Value<bool>? deleted,
      Value<bool>? dirty,
      Value<int?>? syncedAt,
      Value<String>? id,
      Value<String>? bookId,
      Value<String>? name,
      Value<String?>? category,
      Value<int>? purchasePriceMinor,
      Value<int>? currentValueMinor,
      Value<String>? currency,
      Value<int>? purchasedAt,
      Value<int?>? warrantyUntil,
      Value<String?>? photoUrl,
      Value<String?>? location,
      Value<String?>? note,
      Value<String?>? transactionId,
      Value<int>? rowid}) {
    return InventoryItemsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      syncedAt: syncedAt ?? this.syncedAt,
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      name: name ?? this.name,
      category: category ?? this.category,
      purchasePriceMinor: purchasePriceMinor ?? this.purchasePriceMinor,
      currentValueMinor: currentValueMinor ?? this.currentValueMinor,
      currency: currency ?? this.currency,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      warrantyUntil: warrantyUntil ?? this.warrantyUntil,
      photoUrl: photoUrl ?? this.photoUrl,
      location: location ?? this.location,
      note: note ?? this.note,
      transactionId: transactionId ?? this.transactionId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (purchasePriceMinor.present) {
      map['purchase_price_minor'] = Variable<int>(purchasePriceMinor.value);
    }
    if (currentValueMinor.present) {
      map['current_value_minor'] = Variable<int>(currentValueMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (purchasedAt.present) {
      map['purchased_at'] = Variable<int>(purchasedAt.value);
    }
    if (warrantyUntil.present) {
      map['warranty_until'] = Variable<int>(warrantyUntil.value);
    }
    if (photoUrl.present) {
      map['photo_url'] = Variable<String>(photoUrl.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<String>(transactionId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InventoryItemsCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('purchasePriceMinor: $purchasePriceMinor, ')
          ..write('currentValueMinor: $currentValueMinor, ')
          ..write('currency: $currency, ')
          ..write('purchasedAt: $purchasedAt, ')
          ..write('warrantyUntil: $warrantyUntil, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('location: $location, ')
          ..write('note: $note, ')
          ..write('transactionId: $transactionId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingOpsTable extends PendingOps
    with TableInfo<$PendingOpsTable, PendingOp> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingOpsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localSeqMeta =
      const VerificationMeta('localSeq');
  @override
  late final GeneratedColumn<int> localSeq = GeneratedColumn<int>(
      'local_seq', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _targetTableMeta =
      const VerificationMeta('targetTable');
  @override
  late final GeneratedColumn<String> targetTable = GeneratedColumn<String>(
      'target_table', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recordIdMeta =
      const VerificationMeta('recordId');
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
      'record_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _opTypeMeta = const VerificationMeta('opType');
  @override
  late final GeneratedColumnWithTypeConverter<SyncOpType, int> opType =
      GeneratedColumn<int>('op_type', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<SyncOpType>($PendingOpsTable.$converteropType);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _retryCountMeta =
      const VerificationMeta('retryCount');
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
      'retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        localSeq,
        targetTable,
        recordId,
        opType,
        payload,
        updatedAt,
        createdAt,
        retryCount
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_ops';
  @override
  VerificationContext validateIntegrity(Insertable<PendingOp> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_seq')) {
      context.handle(_localSeqMeta,
          localSeq.isAcceptableOrUnknown(data['local_seq']!, _localSeqMeta));
    }
    if (data.containsKey('target_table')) {
      context.handle(
          _targetTableMeta,
          targetTable.isAcceptableOrUnknown(
              data['target_table']!, _targetTableMeta));
    } else if (isInserting) {
      context.missing(_targetTableMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(_recordIdMeta,
          recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta));
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    context.handle(_opTypeMeta, const VerificationResult.success());
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
          _retryCountMeta,
          retryCount.isAcceptableOrUnknown(
              data['retry_count']!, _retryCountMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localSeq};
  @override
  PendingOp map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingOp(
      localSeq: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}local_seq'])!,
      targetTable: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}target_table'])!,
      recordId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}record_id'])!,
      opType: $PendingOpsTable.$converteropType.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}op_type'])!),
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      retryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}retry_count'])!,
    );
  }

  @override
  $PendingOpsTable createAlias(String alias) {
    return $PendingOpsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SyncOpType, int, int> $converteropType =
      const EnumIndexConverter<SyncOpType>(SyncOpType.values);
}

class PendingOp extends DataClass implements Insertable<PendingOp> {
  final int localSeq;

  /// 目标表名。不能命名为 tableName，会与 Drift 内置的 tableName getter 冲突。
  final String targetTable;
  final String recordId;
  final SyncOpType opType;

  /// 操作内容 JSON；删除操作可为 null
  final String? payload;
  final int updatedAt;
  final int createdAt;

  /// 失败重试次数，用于指数退避与错误上报
  final int retryCount;
  const PendingOp(
      {required this.localSeq,
      required this.targetTable,
      required this.recordId,
      required this.opType,
      this.payload,
      required this.updatedAt,
      required this.createdAt,
      required this.retryCount});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_seq'] = Variable<int>(localSeq);
    map['target_table'] = Variable<String>(targetTable);
    map['record_id'] = Variable<String>(recordId);
    {
      map['op_type'] =
          Variable<int>($PendingOpsTable.$converteropType.toSql(opType));
    }
    if (!nullToAbsent || payload != null) {
      map['payload'] = Variable<String>(payload);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    map['created_at'] = Variable<int>(createdAt);
    map['retry_count'] = Variable<int>(retryCount);
    return map;
  }

  PendingOpsCompanion toCompanion(bool nullToAbsent) {
    return PendingOpsCompanion(
      localSeq: Value(localSeq),
      targetTable: Value(targetTable),
      recordId: Value(recordId),
      opType: Value(opType),
      payload: payload == null && nullToAbsent
          ? const Value.absent()
          : Value(payload),
      updatedAt: Value(updatedAt),
      createdAt: Value(createdAt),
      retryCount: Value(retryCount),
    );
  }

  factory PendingOp.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingOp(
      localSeq: serializer.fromJson<int>(json['localSeq']),
      targetTable: serializer.fromJson<String>(json['targetTable']),
      recordId: serializer.fromJson<String>(json['recordId']),
      opType: $PendingOpsTable.$converteropType
          .fromJson(serializer.fromJson<int>(json['opType'])),
      payload: serializer.fromJson<String?>(json['payload']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localSeq': serializer.toJson<int>(localSeq),
      'targetTable': serializer.toJson<String>(targetTable),
      'recordId': serializer.toJson<String>(recordId),
      'opType': serializer
          .toJson<int>($PendingOpsTable.$converteropType.toJson(opType)),
      'payload': serializer.toJson<String?>(payload),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'createdAt': serializer.toJson<int>(createdAt),
      'retryCount': serializer.toJson<int>(retryCount),
    };
  }

  PendingOp copyWith(
          {int? localSeq,
          String? targetTable,
          String? recordId,
          SyncOpType? opType,
          Value<String?> payload = const Value.absent(),
          int? updatedAt,
          int? createdAt,
          int? retryCount}) =>
      PendingOp(
        localSeq: localSeq ?? this.localSeq,
        targetTable: targetTable ?? this.targetTable,
        recordId: recordId ?? this.recordId,
        opType: opType ?? this.opType,
        payload: payload.present ? payload.value : this.payload,
        updatedAt: updatedAt ?? this.updatedAt,
        createdAt: createdAt ?? this.createdAt,
        retryCount: retryCount ?? this.retryCount,
      );
  PendingOp copyWithCompanion(PendingOpsCompanion data) {
    return PendingOp(
      localSeq: data.localSeq.present ? data.localSeq.value : this.localSeq,
      targetTable:
          data.targetTable.present ? data.targetTable.value : this.targetTable,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      opType: data.opType.present ? data.opType.value : this.opType,
      payload: data.payload.present ? data.payload.value : this.payload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      retryCount:
          data.retryCount.present ? data.retryCount.value : this.retryCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingOp(')
          ..write('localSeq: $localSeq, ')
          ..write('targetTable: $targetTable, ')
          ..write('recordId: $recordId, ')
          ..write('opType: $opType, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(localSeq, targetTable, recordId, opType,
      payload, updatedAt, createdAt, retryCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingOp &&
          other.localSeq == this.localSeq &&
          other.targetTable == this.targetTable &&
          other.recordId == this.recordId &&
          other.opType == this.opType &&
          other.payload == this.payload &&
          other.updatedAt == this.updatedAt &&
          other.createdAt == this.createdAt &&
          other.retryCount == this.retryCount);
}

class PendingOpsCompanion extends UpdateCompanion<PendingOp> {
  final Value<int> localSeq;
  final Value<String> targetTable;
  final Value<String> recordId;
  final Value<SyncOpType> opType;
  final Value<String?> payload;
  final Value<int> updatedAt;
  final Value<int> createdAt;
  final Value<int> retryCount;
  const PendingOpsCompanion({
    this.localSeq = const Value.absent(),
    this.targetTable = const Value.absent(),
    this.recordId = const Value.absent(),
    this.opType = const Value.absent(),
    this.payload = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.retryCount = const Value.absent(),
  });
  PendingOpsCompanion.insert({
    this.localSeq = const Value.absent(),
    required String targetTable,
    required String recordId,
    required SyncOpType opType,
    this.payload = const Value.absent(),
    required int updatedAt,
    required int createdAt,
    this.retryCount = const Value.absent(),
  })  : targetTable = Value(targetTable),
        recordId = Value(recordId),
        opType = Value(opType),
        updatedAt = Value(updatedAt),
        createdAt = Value(createdAt);
  static Insertable<PendingOp> custom({
    Expression<int>? localSeq,
    Expression<String>? targetTable,
    Expression<String>? recordId,
    Expression<int>? opType,
    Expression<String>? payload,
    Expression<int>? updatedAt,
    Expression<int>? createdAt,
    Expression<int>? retryCount,
  }) {
    return RawValuesInsertable({
      if (localSeq != null) 'local_seq': localSeq,
      if (targetTable != null) 'target_table': targetTable,
      if (recordId != null) 'record_id': recordId,
      if (opType != null) 'op_type': opType,
      if (payload != null) 'payload': payload,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (retryCount != null) 'retry_count': retryCount,
    });
  }

  PendingOpsCompanion copyWith(
      {Value<int>? localSeq,
      Value<String>? targetTable,
      Value<String>? recordId,
      Value<SyncOpType>? opType,
      Value<String?>? payload,
      Value<int>? updatedAt,
      Value<int>? createdAt,
      Value<int>? retryCount}) {
    return PendingOpsCompanion(
      localSeq: localSeq ?? this.localSeq,
      targetTable: targetTable ?? this.targetTable,
      recordId: recordId ?? this.recordId,
      opType: opType ?? this.opType,
      payload: payload ?? this.payload,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localSeq.present) {
      map['local_seq'] = Variable<int>(localSeq.value);
    }
    if (targetTable.present) {
      map['target_table'] = Variable<String>(targetTable.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (opType.present) {
      map['op_type'] =
          Variable<int>($PendingOpsTable.$converteropType.toSql(opType.value));
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingOpsCompanion(')
          ..write('localSeq: $localSeq, ')
          ..write('targetTable: $targetTable, ')
          ..write('recordId: $recordId, ')
          ..write('opType: $opType, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BooksTable books = $BooksTable(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $LendRecordsTable lendRecords = $LendRecordsTable(this);
  late final $ReimbursementsTable reimbursements = $ReimbursementsTable(this);
  late final $SavingsGoalsTable savingsGoals = $SavingsGoalsTable(this);
  late final $InstallmentPlansTable installmentPlans =
      $InstallmentPlansTable(this);
  late final $InstallmentPeriodsTable installmentPeriods =
      $InstallmentPeriodsTable(this);
  late final $BudgetsTable budgets = $BudgetsTable(this);
  late final $InvestmentHoldingsTable investmentHoldings =
      $InvestmentHoldingsTable(this);
  late final $InventoryItemsTable inventoryItems = $InventoryItemsTable(this);
  late final $PendingOpsTable pendingOps = $PendingOpsTable(this);
  late final BooksDao booksDao = BooksDao(this as AppDatabase);
  late final AccountsDao accountsDao = AccountsDao(this as AppDatabase);
  late final CategoriesDao categoriesDao = CategoriesDao(this as AppDatabase);
  late final TransactionsDao transactionsDao =
      TransactionsDao(this as AppDatabase);
  late final PendingOpsDao pendingOpsDao = PendingOpsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        books,
        accounts,
        categories,
        transactions,
        lendRecords,
        reimbursements,
        savingsGoals,
        installmentPlans,
        installmentPeriods,
        budgets,
        investmentHoldings,
        inventoryItems,
        pendingOps
      ];
}

typedef $$BooksTableCreateCompanionBuilder = BooksCompanion Function({
  required int updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> syncedAt,
  required String id,
  required String name,
  Value<String> currency,
  required int createdAt,
  Value<int> sortOrder,
  Value<int> rowid,
});
typedef $$BooksTableUpdateCompanionBuilder = BooksCompanion Function({
  Value<int> updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> syncedAt,
  Value<String> id,
  Value<String> name,
  Value<String> currency,
  Value<int> createdAt,
  Value<int> sortOrder,
  Value<int> rowid,
});

class $$BooksTableFilterComposer extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get dirty => $composableBuilder(
      column: $table.dirty, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));
}

class $$BooksTableOrderingComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get dirty => $composableBuilder(
      column: $table.dirty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));
}

class $$BooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$BooksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BooksTable,
    Book,
    $$BooksTableFilterComposer,
    $$BooksTableOrderingComposer,
    $$BooksTableAnnotationComposer,
    $$BooksTableCreateCompanionBuilder,
    $$BooksTableUpdateCompanionBuilder,
    (Book, BaseReferences<_$AppDatabase, $BooksTable, Book>),
    Book,
    PrefetchHooks Function()> {
  $$BooksTableTableManager(_$AppDatabase db, $BooksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> updatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<bool> dirty = const Value.absent(),
            Value<int?> syncedAt = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BooksCompanion(
            updatedAt: updatedAt,
            deleted: deleted,
            dirty: dirty,
            syncedAt: syncedAt,
            id: id,
            name: name,
            currency: currency,
            createdAt: createdAt,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int updatedAt,
            Value<bool> deleted = const Value.absent(),
            Value<bool> dirty = const Value.absent(),
            Value<int?> syncedAt = const Value.absent(),
            required String id,
            required String name,
            Value<String> currency = const Value.absent(),
            required int createdAt,
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BooksCompanion.insert(
            updatedAt: updatedAt,
            deleted: deleted,
            dirty: dirty,
            syncedAt: syncedAt,
            id: id,
            name: name,
            currency: currency,
            createdAt: createdAt,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BooksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BooksTable,
    Book,
    $$BooksTableFilterComposer,
    $$BooksTableOrderingComposer,
    $$BooksTableAnnotationComposer,
    $$BooksTableCreateCompanionBuilder,
    $$BooksTableUpdateCompanionBuilder,
    (Book, BaseReferences<_$AppDatabase, $BooksTable, Book>),
    Book,
    PrefetchHooks Function()>;
typedef $$AccountsTableCreateCompanionBuilder = AccountsCompanion Function({
  required int updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> syncedAt,
  required String id,
  required String bookId,
  required String name,
  required AccountType type,
  Value<int> balanceMinor,
  Value<String> currency,
  Value<String?> iconKey,
  Value<int?> colorValue,
  Value<int?> creditLimitMinor,
  Value<int?> billingDay,
  Value<int?> dueDay,
  Value<bool> isArchived,
  Value<int> sortOrder,
  Value<int> rowid,
});
typedef $$AccountsTableUpdateCompanionBuilder = AccountsCompanion Function({
  Value<int> updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> syncedAt,
  Value<String> id,
  Value<String> bookId,
  Value<String> name,
  Value<AccountType> type,
  Value<int> balanceMinor,
  Value<String> currency,
  Value<String?> iconKey,
  Value<int?> colorValue,
  Value<int?> creditLimitMinor,
  Value<int?> billingDay,
  Value<int?> dueDay,
  Value<bool> isArchived,
  Value<int> sortOrder,
  Value<int> rowid,
});

class $$AccountsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get dirty => $composableBuilder(
      column: $table.dirty, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<AccountType, AccountType, int> get type =>
      $composableBuilder(
          column: $table.type,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<int> get balanceMinor => $composableBuilder(
      column: $table.balanceMinor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconKey => $composableBuilder(
      column: $table.iconKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get colorValue => $composableBuilder(
      column: $table.colorValue, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get creditLimitMinor => $composableBuilder(
      column: $table.creditLimitMinor,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get billingDay => $composableBuilder(
      column: $table.billingDay, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dueDay => $composableBuilder(
      column: $table.dueDay, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));
}

class $$AccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get dirty => $composableBuilder(
      column: $table.dirty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get balanceMinor => $composableBuilder(
      column: $table.balanceMinor,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconKey => $composableBuilder(
      column: $table.iconKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get colorValue => $composableBuilder(
      column: $table.colorValue, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get creditLimitMinor => $composableBuilder(
      column: $table.creditLimitMinor,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get billingDay => $composableBuilder(
      column: $table.billingDay, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dueDay => $composableBuilder(
      column: $table.dueDay, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AccountType, int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get balanceMinor => $composableBuilder(
      column: $table.balanceMinor, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get iconKey =>
      $composableBuilder(column: $table.iconKey, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
      column: $table.colorValue, builder: (column) => column);

  GeneratedColumn<int> get creditLimitMinor => $composableBuilder(
      column: $table.creditLimitMinor, builder: (column) => column);

  GeneratedColumn<int> get billingDay => $composableBuilder(
      column: $table.billingDay, builder: (column) => column);

  GeneratedColumn<int> get dueDay =>
      $composableBuilder(column: $table.dueDay, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$AccountsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AccountsTable,
    Account,
    $$AccountsTableFilterComposer,
    $$AccountsTableOrderingComposer,
    $$AccountsTableAnnotationComposer,
    $$AccountsTableCreateCompanionBuilder,
    $$AccountsTableUpdateCompanionBuilder,
    (Account, BaseReferences<_$AppDatabase, $AccountsTable, Account>),
    Account,
    PrefetchHooks Function()> {
  $$AccountsTableTableManager(_$AppDatabase db, $AccountsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> updatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<bool> dirty = const Value.absent(),
            Value<int?> syncedAt = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> bookId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<AccountType> type = const Value.absent(),
            Value<int> balanceMinor = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String?> iconKey = const Value.absent(),
            Value<int?> colorValue = const Value.absent(),
            Value<int?> creditLimitMinor = const Value.absent(),
            Value<int?> billingDay = const Value.absent(),
            Value<int?> dueDay = const Value.absent(),
            Value<bool> isArchived = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AccountsCompanion(
            updatedAt: updatedAt,
            deleted: deleted,
            dirty: dirty,
            syncedAt: syncedAt,
            id: id,
            bookId: bookId,
            name: name,
            type: type,
            balanceMinor: balanceMinor,
            currency: currency,
            iconKey: iconKey,
            colorValue: colorValue,
            creditLimitMinor: creditLimitMinor,
            billingDay: billingDay,
            dueDay: dueDay,
            isArchived: isArchived,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int updatedAt,
            Value<bool> deleted = const Value.absent(),
            Value<bool> dirty = const Value.absent(),
            Value<int?> syncedAt = const Value.absent(),
            required String id,
            required String bookId,
            required String name,
            required AccountType type,
            Value<int> balanceMinor = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String?> iconKey = const Value.absent(),
            Value<int?> colorValue = const Value.absent(),
            Value<int?> creditLimitMinor = const Value.absent(),
            Value<int?> billingDay = const Value.absent(),
            Value<int?> dueDay = const Value.absent(),
            Value<bool> isArchived = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AccountsCompanion.insert(
            updatedAt: updatedAt,
            deleted: deleted,
            dirty: dirty,
            syncedAt: syncedAt,
            id: id,
            bookId: bookId,
            name: name,
            type: type,
            balanceMinor: balanceMinor,
            currency: currency,
            iconKey: iconKey,
            colorValue: colorValue,
            creditLimitMinor: creditLimitMinor,
            billingDay: billingDay,
            dueDay: dueDay,
            isArchived: isArchived,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AccountsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AccountsTable,
    Account,
    $$AccountsTableFilterComposer,
    $$AccountsTableOrderingComposer,
    $$AccountsTableAnnotationComposer,
    $$AccountsTableCreateCompanionBuilder,
    $$AccountsTableUpdateCompanionBuilder,
    (Account, BaseReferences<_$AppDatabase, $AccountsTable, Account>),
    Account,
    PrefetchHooks Function()>;
typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  required int updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> syncedAt,
  required String id,
  required String bookId,
  required String name,
  required CategoryType type,
  Value<String?> parentId,
  Value<String?> iconKey,
  Value<int?> colorValue,
  Value<int> sortOrder,
  Value<bool> isArchived,
  Value<int> rowid,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<int> updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> syncedAt,
  Value<String> id,
  Value<String> bookId,
  Value<String> name,
  Value<CategoryType> type,
  Value<String?> parentId,
  Value<String?> iconKey,
  Value<int?> colorValue,
  Value<int> sortOrder,
  Value<bool> isArchived,
  Value<int> rowid,
});

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get dirty => $composableBuilder(
      column: $table.dirty, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<CategoryType, CategoryType, int> get type =>
      $composableBuilder(
          column: $table.type,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get parentId => $composableBuilder(
      column: $table.parentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconKey => $composableBuilder(
      column: $table.iconKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get colorValue => $composableBuilder(
      column: $table.colorValue, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => ColumnFilters(column));
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get dirty => $composableBuilder(
      column: $table.dirty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parentId => $composableBuilder(
      column: $table.parentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconKey => $composableBuilder(
      column: $table.iconKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get colorValue => $composableBuilder(
      column: $table.colorValue, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => ColumnOrderings(column));
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CategoryType, int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get iconKey =>
      $composableBuilder(column: $table.iconKey, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
      column: $table.colorValue, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => column);
}

class $$CategoriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CategoriesTable,
    Category,
    $$CategoriesTableFilterComposer,
    $$CategoriesTableOrderingComposer,
    $$CategoriesTableAnnotationComposer,
    $$CategoriesTableCreateCompanionBuilder,
    $$CategoriesTableUpdateCompanionBuilder,
    (Category, BaseReferences<_$AppDatabase, $CategoriesTable, Category>),
    Category,
    PrefetchHooks Function()> {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> updatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<bool> dirty = const Value.absent(),
            Value<int?> syncedAt = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> bookId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<CategoryType> type = const Value.absent(),
            Value<String?> parentId = const Value.absent(),
            Value<String?> iconKey = const Value.absent(),
            Value<int?> colorValue = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<bool> isArchived = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CategoriesCompanion(
            updatedAt: updatedAt,
            deleted: deleted,
            dirty: dirty,
            syncedAt: syncedAt,
            id: id,
            bookId: bookId,
            name: name,
            type: type,
            parentId: parentId,
            iconKey: iconKey,
            colorValue: colorValue,
            sortOrder: sortOrder,
            isArchived: isArchived,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int updatedAt,
            Value<bool> deleted = const Value.absent(),
            Value<bool> dirty = const Value.absent(),
            Value<int?> syncedAt = const Value.absent(),
            required String id,
            required String bookId,
            required String name,
            required CategoryType type,
            Value<String?> parentId = const Value.absent(),
            Value<String?> iconKey = const Value.absent(),
            Value<int?> colorValue = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<bool> isArchived = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CategoriesCompanion.insert(
            updatedAt: updatedAt,
            deleted: deleted,
            dirty: dirty,
            syncedAt: syncedAt,
            id: id,
            bookId: bookId,
            name: name,
            type: type,
            parentId: parentId,
            iconKey: iconKey,
            colorValue: colorValue,
            sortOrder: sortOrder,
            isArchived: isArchived,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CategoriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CategoriesTable,
    Category,
    $$CategoriesTableFilterComposer,
    $$CategoriesTableOrderingComposer,
    $$CategoriesTableAnnotationComposer,
    $$CategoriesTableCreateCompanionBuilder,
    $$CategoriesTableUpdateCompanionBuilder,
    (Category, BaseReferences<_$AppDatabase, $CategoriesTable, Category>),
    Category,
    PrefetchHooks Function()>;
typedef $$TransactionsTableCreateCompanionBuilder = TransactionsCompanion
    Function({
  required int updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> syncedAt,
  required String id,
  required String bookId,
  required TxnType type,
  required int amountMinor,
  Value<String> currency,
  required String accountId,
  Value<String?> toAccountId,
  Value<String?> categoryId,
  required int occurredAt,
  Value<String?> note,
  Value<String?> attachmentUrls,
  Value<String?> tags,
  required SourceModule sourceModule,
  Value<String?> relatedId,
  Value<String?> transferGroupId,
  Value<int> rowid,
});
typedef $$TransactionsTableUpdateCompanionBuilder = TransactionsCompanion
    Function({
  Value<int> updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> syncedAt,
  Value<String> id,
  Value<String> bookId,
  Value<TxnType> type,
  Value<int> amountMinor,
  Value<String> currency,
  Value<String> accountId,
  Value<String?> toAccountId,
  Value<String?> categoryId,
  Value<int> occurredAt,
  Value<String?> note,
  Value<String?> attachmentUrls,
  Value<String?> tags,
  Value<SourceModule> sourceModule,
  Value<String?> relatedId,
  Value<String?> transferGroupId,
  Value<int> rowid,
});

class $$TransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get dirty => $composableBuilder(
      column: $table.dirty, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<TxnType, TxnType, int> get type =>
      $composableBuilder(
          column: $table.type,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get toAccountId => $composableBuilder(
      column: $table.toAccountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get attachmentUrls => $composableBuilder(
      column: $table.attachmentUrls,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<SourceModule, SourceModule, int>
      get sourceModule => $composableBuilder(
          column: $table.sourceModule,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get relatedId => $composableBuilder(
      column: $table.relatedId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get transferGroupId => $composableBuilder(
      column: $table.transferGroupId,
      builder: (column) => ColumnFilters(column));
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get dirty => $composableBuilder(
      column: $table.dirty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get toAccountId => $composableBuilder(
      column: $table.toAccountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get attachmentUrls => $composableBuilder(
      column: $table.attachmentUrls,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sourceModule => $composableBuilder(
      column: $table.sourceModule,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get relatedId => $composableBuilder(
      column: $table.relatedId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get transferGroupId => $composableBuilder(
      column: $table.transferGroupId,
      builder: (column) => ColumnOrderings(column));
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TxnType, int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get toAccountId => $composableBuilder(
      column: $table.toAccountId, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);

  GeneratedColumn<int> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get attachmentUrls => $composableBuilder(
      column: $table.attachmentUrls, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SourceModule, int> get sourceModule =>
      $composableBuilder(
          column: $table.sourceModule, builder: (column) => column);

  GeneratedColumn<String> get relatedId =>
      $composableBuilder(column: $table.relatedId, builder: (column) => column);

  GeneratedColumn<String> get transferGroupId => $composableBuilder(
      column: $table.transferGroupId, builder: (column) => column);
}

class $$TransactionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TransactionsTable,
    Transaction,
    $$TransactionsTableFilterComposer,
    $$TransactionsTableOrderingComposer,
    $$TransactionsTableAnnotationComposer,
    $$TransactionsTableCreateCompanionBuilder,
    $$TransactionsTableUpdateCompanionBuilder,
    (
      Transaction,
      BaseReferences<_$AppDatabase, $TransactionsTable, Transaction>
    ),
    Transaction,
    PrefetchHooks Function()> {
  $$TransactionsTableTableManager(_$AppDatabase db, $TransactionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> updatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<bool> dirty = const Value.absent(),
            Value<int?> syncedAt = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> bookId = const Value.absent(),
            Value<TxnType> type = const Value.absent(),
            Value<int> amountMinor = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String> accountId = const Value.absent(),
            Value<String?> toAccountId = const Value.absent(),
            Value<String?> categoryId = const Value.absent(),
            Value<int> occurredAt = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String?> attachmentUrls = const Value.absent(),
            Value<String?> tags = const Value.absent(),
            Value<SourceModule> sourceModule = const Value.absent(),
            Value<String?> relatedId = const Value.absent(),
            Value<String?> transferGroupId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TransactionsCompanion(
            updatedAt: updatedAt,
            deleted: deleted,
            dirty: dirty,
            syncedAt: syncedAt,
            id: id,
            bookId: bookId,
            type: type,
            amountMinor: amountMinor,
            currency: currency,
            accountId: accountId,
            toAccountId: toAccountId,
            categoryId: categoryId,
            occurredAt: occurredAt,
            note: note,
            attachmentUrls: attachmentUrls,
            tags: tags,
            sourceModule: sourceModule,
            relatedId: relatedId,
            transferGroupId: transferGroupId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int updatedAt,
            Value<bool> deleted = const Value.absent(),
            Value<bool> dirty = const Value.absent(),
            Value<int?> syncedAt = const Value.absent(),
            required String id,
            required String bookId,
            required TxnType type,
            required int amountMinor,
            Value<String> currency = const Value.absent(),
            required String accountId,
            Value<String?> toAccountId = const Value.absent(),
            Value<String?> categoryId = const Value.absent(),
            required int occurredAt,
            Value<String?> note = const Value.absent(),
            Value<String?> attachmentUrls = const Value.absent(),
            Value<String?> tags = const Value.absent(),
            required SourceModule sourceModule,
            Value<String?> relatedId = const Value.absent(),
            Value<String?> transferGroupId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TransactionsCompanion.insert(
            updatedAt: updatedAt,
            deleted: deleted,
            dirty: dirty,
            syncedAt: syncedAt,
            id: id,
            bookId: bookId,
            type: type,
            amountMinor: amountMinor,
            currency: currency,
            accountId: accountId,
            toAccountId: toAccountId,
            categoryId: categoryId,
            occurredAt: occurredAt,
            note: note,
            attachmentUrls: attachmentUrls,
            tags: tags,
            sourceModule: sourceModule,
            relatedId: relatedId,
            transferGroupId: transferGroupId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TransactionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TransactionsTable,
    Transaction,
    $$TransactionsTableFilterComposer,
    $$TransactionsTableOrderingComposer,
    $$TransactionsTableAnnotationComposer,
    $$TransactionsTableCreateCompanionBuilder,
    $$TransactionsTableUpdateCompanionBuilder,
    (
      Transaction,
      BaseReferences<_$AppDatabase, $TransactionsTable, Transaction>
    ),
    Transaction,
    PrefetchHooks Function()>;
typedef $$LendRecordsTableCreateCompanionBuilder = LendRecordsCompanion
    Function({
  required int updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> syncedAt,
  required String id,
  required String bookId,
  required LendDirection direction,
  required LendStatus status,
  required String counterparty,
  required int amountMinor,
  Value<String> currency,
  Value<int> repaidMinor,
  required int occurredAt,
  Value<int?> dueAt,
  Value<String?> note,
  Value<String?> accountId,
  Value<int> rowid,
});
typedef $$LendRecordsTableUpdateCompanionBuilder = LendRecordsCompanion
    Function({
  Value<int> updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> syncedAt,
  Value<String> id,
  Value<String> bookId,
  Value<LendDirection> direction,
  Value<LendStatus> status,
  Value<String> counterparty,
  Value<int> amountMinor,
  Value<String> currency,
  Value<int> repaidMinor,
  Value<int> occurredAt,
  Value<int?> dueAt,
  Value<String?> note,
  Value<String?> accountId,
  Value<int> rowid,
});

class $$LendRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $LendRecordsTable> {
  $$LendRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get dirty => $composableBuilder(
      column: $table.dirty, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<LendDirection, LendDirection, int>
      get direction => $composableBuilder(
          column: $table.direction,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnWithTypeConverterFilters<LendStatus, LendStatus, int> get status =>
      $composableBuilder(
          column: $table.status,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get counterparty => $composableBuilder(
      column: $table.counterparty, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get repaidMinor => $composableBuilder(
      column: $table.repaidMinor, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dueAt => $composableBuilder(
      column: $table.dueAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));
}

class $$LendRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $LendRecordsTable> {
  $$LendRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get dirty => $composableBuilder(
      column: $table.dirty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get direction => $composableBuilder(
      column: $table.direction, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get counterparty => $composableBuilder(
      column: $table.counterparty,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get repaidMinor => $composableBuilder(
      column: $table.repaidMinor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dueAt => $composableBuilder(
      column: $table.dueAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));
}

class $$LendRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LendRecordsTable> {
  $$LendRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LendDirection, int> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LendStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get counterparty => $composableBuilder(
      column: $table.counterparty, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get repaidMinor => $composableBuilder(
      column: $table.repaidMinor, builder: (column) => column);

  GeneratedColumn<int> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => column);

  GeneratedColumn<int> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);
}

class $$LendRecordsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LendRecordsTable,
    LendRecord,
    $$LendRecordsTableFilterComposer,
    $$LendRecordsTableOrderingComposer,
    $$LendRecordsTableAnnotationComposer,
    $$LendRecordsTableCreateCompanionBuilder,
    $$LendRecordsTableUpdateCompanionBuilder,
    (LendRecord, BaseReferences<_$AppDatabase, $LendRecordsTable, LendRecord>),
    LendRecord,
    PrefetchHooks Function()> {
  $$LendRecordsTableTableManager(_$AppDatabase db, $LendRecordsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LendRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LendRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LendRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> updatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<bool> dirty = const Value.absent(),
            Value<int?> syncedAt = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> bookId = const Value.absent(),
            Value<LendDirection> direction = const Value.absent(),
            Value<LendStatus> status = const Value.absent(),
            Value<String> counterparty = const Value.absent(),
            Value<int> amountMinor = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<int> repaidMinor = const Value.absent(),
            Value<int> occurredAt = const Value.absent(),
            Value<int?> dueAt = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String?> accountId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LendRecordsCompanion(
            updatedAt: updatedAt,
            deleted: deleted,
            dirty: dirty,
            syncedAt: syncedAt,
            id: id,
            bookId: bookId,
            direction: direction,
            status: status,
            counterparty: counterparty,
            amountMinor: amountMinor,
            currency: currency,
            repaidMinor: repaidMinor,
            occurredAt: occurredAt,
            dueAt: dueAt,
            note: note,
            accountId: accountId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int updatedAt,
            Value<bool> deleted = const Value.absent(),
            Value<bool> dirty = const Value.absent(),
            Value<int?> syncedAt = const Value.absent(),
            required String id,
            required String bookId,
            required LendDirection direction,
            required LendStatus status,
            required String counterparty,
            required int amountMinor,
            Value<String> currency = const Value.absent(),
            Value<int> repaidMinor = const Value.absent(),
            required int occurredAt,
            Value<int?> dueAt = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String?> accountId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LendRecordsCompanion.insert(
            updatedAt: updatedAt,
            deleted: deleted,
            dirty: dirty,
            syncedAt: syncedAt,
            id: id,
            bookId: bookId,
            direction: direction,
            status: status,
            counterparty: counterparty,
            amountMinor: amountMinor,
            currency: currency,
            repaidMinor: repaidMinor,
            occurredAt: occurredAt,
            dueAt: dueAt,
            note: note,
            accountId: accountId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LendRecordsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LendRecordsTable,
    LendRecord,
    $$LendRecordsTableFilterComposer,
    $$LendRecordsTableOrderingComposer,
    $$LendRecordsTableAnnotationComposer,
    $$LendRecordsTableCreateCompanionBuilder,
    $$LendRecordsTableUpdateCompanionBuilder,
    (LendRecord, BaseReferences<_$AppDatabase, $LendRecordsTable, LendRecord>),
    LendRecord,
    PrefetchHooks Function()>;
typedef $$ReimbursementsTableCreateCompanionBuilder = ReimbursementsCompanion
    Function({
  required int updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> syncedAt,
  required String id,
  required String bookId,
  required String title,
  required ReimbursementStatus status,
  required int amountMinor,
  Value<String> currency,
  required String payer,
  Value<String?> target,
  required int occurredAt,
  Value<int?> receivedAt,
  Value<String?> note,
  Value<String?> attachmentUrls,
  Value<String?> transactionId,
  Value<int> rowid,
});
typedef $$ReimbursementsTableUpdateCompanionBuilder = ReimbursementsCompanion
    Function({
  Value<int> updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> syncedAt,
  Value<String> id,
  Value<String> bookId,
  Value<String> title,
  Value<ReimbursementStatus> status,
  Value<int> amountMinor,
  Value<String> currency,
  Value<String> payer,
  Value<String?> target,
  Value<int> occurredAt,
  Value<int?> receivedAt,
  Value<String?> note,
  Value<String?> attachmentUrls,
  Value<String?> transactionId,
  Value<int> rowid,
});

class $$ReimbursementsTableFilterComposer
    extends Composer<_$AppDatabase, $ReimbursementsTable> {
  $$ReimbursementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get dirty => $composableBuilder(
      column: $table.dirty, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<ReimbursementStatus, ReimbursementStatus, int>
      get status => $composableBuilder(
          column: $table.status,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payer => $composableBuilder(
      column: $table.payer, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get target => $composableBuilder(
      column: $table.target, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get attachmentUrls => $composableBuilder(
      column: $table.attachmentUrls,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get transactionId => $composableBuilder(
      column: $table.transactionId, builder: (column) => ColumnFilters(column));
}

class $$ReimbursementsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReimbursementsTable> {
  $$ReimbursementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get dirty => $composableBuilder(
      column: $table.dirty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payer => $composableBuilder(
      column: $table.payer, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get target => $composableBuilder(
      column: $table.target, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get attachmentUrls => $composableBuilder(
      column: $table.attachmentUrls,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get transactionId => $composableBuilder(
      column: $table.transactionId,
      builder: (column) => ColumnOrderings(column));
}

class $$ReimbursementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReimbursementsTable> {
  $$ReimbursementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ReimbursementStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get payer =>
      $composableBuilder(column: $table.payer, builder: (column) => column);

  GeneratedColumn<String> get target =>
      $composableBuilder(column: $table.target, builder: (column) => column);

  GeneratedColumn<int> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => column);

  GeneratedColumn<int> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get attachmentUrls => $composableBuilder(
      column: $table.attachmentUrls, builder: (column) => column);

  GeneratedColumn<String> get transactionId => $composableBuilder(
      column: $table.transactionId, builder: (column) => column);
}

class $$ReimbursementsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ReimbursementsTable,
    Reimbursement,
    $$ReimbursementsTableFilterComposer,
    $$ReimbursementsTableOrderingComposer,
    $$ReimbursementsTableAnnotationComposer,
    $$ReimbursementsTableCreateCompanionBuilder,
    $$ReimbursementsTableUpdateCompanionBuilder,
    (
      Reimbursement,
      BaseReferences<_$AppDatabase, $ReimbursementsTable, Reimbursement>
    ),
    Reimbursement,
    PrefetchHooks Function()> {
  $$ReimbursementsTableTableManager(
      _$AppDatabase db, $ReimbursementsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReimbursementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReimbursementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReimbursementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> updatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<bool> dirty = const Value.absent(),
            Value<int?> syncedAt = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> bookId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<ReimbursementStatus> status = const Value.absent(),
            Value<int> amountMinor = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String> payer = const Value.absent(),
            Value<String?> target = const Value.absent(),
            Value<int> occurredAt = const Value.absent(),
            Value<int?> receivedAt = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String?> attachmentUrls = const Value.absent(),
            Value<String?> transactionId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReimbursementsCompanion(
            updatedAt: updatedAt,
            deleted: deleted,
            dirty: dirty,
            syncedAt: syncedAt,
            id: id,
            bookId: bookId,
            title: title,
            status: status,
            amountMinor: amountMinor,
            currency: currency,
            payer: payer,
            target: target,
            occurredAt: occurredAt,
            receivedAt: receivedAt,
            note: note,
            attachmentUrls: attachmentUrls,
            transactionId: transactionId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int updatedAt,
            Value<bool> deleted = const Value.absent(),
            Value<bool> dirty = const Value.absent(),
            Value<int?> syncedAt = const Value.absent(),
            required String id,
            required String bookId,
            required String title,
            required ReimbursementStatus status,
            required int amountMinor,
            Value<String> currency = const Value.absent(),
            required String payer,
            Value<String?> target = const Value.absent(),
            required int occurredAt,
            Value<int?> receivedAt = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String?> attachmentUrls = const Value.absent(),
            Value<String?> transactionId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReimbursementsCompanion.insert(
            updatedAt: updatedAt,
            deleted: deleted,
            dirty: dirty,
            syncedAt: syncedAt,
            id: id,
            bookId: bookId,
            title: title,
            status: status,
            amountMinor: amountMinor,
            currency: currency,
            payer: payer,
            target: target,
            occurredAt: occurredAt,
            receivedAt: receivedAt,
            note: note,
            attachmentUrls: attachmentUrls,
            transactionId: transactionId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ReimbursementsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ReimbursementsTable,
    Reimbursement,
    $$ReimbursementsTableFilterComposer,
    $$ReimbursementsTableOrderingComposer,
    $$ReimbursementsTableAnnotationComposer,
    $$ReimbursementsTableCreateCompanionBuilder,
    $$ReimbursementsTableUpdateCompanionBuilder,
    (
      Reimbursement,
      BaseReferences<_$AppDatabase, $ReimbursementsTable, Reimbursement>
    ),
    Reimbursement,
    PrefetchHooks Function()>;
typedef $$SavingsGoalsTableCreateCompanionBuilder = SavingsGoalsCompanion
    Function({
  required int updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> syncedAt,
  required String id,
  required String bookId,
  required String name,
  required int targetMinor,
  Value<int> currentMinor,
  Value<String> currency,
  Value<String?> accountId,
  Value<int?> deadlineAt,
  Value<String?> note,
  Value<bool> isAchieved,
  Value<int> rowid,
});
typedef $$SavingsGoalsTableUpdateCompanionBuilder = SavingsGoalsCompanion
    Function({
  Value<int> updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> syncedAt,
  Value<String> id,
  Value<String> bookId,
  Value<String> name,
  Value<int> targetMinor,
  Value<int> currentMinor,
  Value<String> currency,
  Value<String?> accountId,
  Value<int?> deadlineAt,
  Value<String?> note,
  Value<bool> isAchieved,
  Value<int> rowid,
});

class $$SavingsGoalsTableFilterComposer
    extends Composer<_$AppDatabase, $SavingsGoalsTable> {
  $$SavingsGoalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get dirty => $composableBuilder(
      column: $table.dirty, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get targetMinor => $composableBuilder(
      column: $table.targetMinor, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get currentMinor => $composableBuilder(
      column: $table.currentMinor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get deadlineAt => $composableBuilder(
      column: $table.deadlineAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isAchieved => $composableBuilder(
      column: $table.isAchieved, builder: (column) => ColumnFilters(column));
}

class $$SavingsGoalsTableOrderingComposer
    extends Composer<_$AppDatabase, $SavingsGoalsTable> {
  $$SavingsGoalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get dirty => $composableBuilder(
      column: $table.dirty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get targetMinor => $composableBuilder(
      column: $table.targetMinor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get currentMinor => $composableBuilder(
      column: $table.currentMinor,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get deadlineAt => $composableBuilder(
      column: $table.deadlineAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isAchieved => $composableBuilder(
      column: $table.isAchieved, builder: (column) => ColumnOrderings(column));
}

class $$SavingsGoalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavingsGoalsTable> {
  $$SavingsGoalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get targetMinor => $composableBuilder(
      column: $table.targetMinor, builder: (column) => column);

  GeneratedColumn<int> get currentMinor => $composableBuilder(
      column: $table.currentMinor, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<int> get deadlineAt => $composableBuilder(
      column: $table.deadlineAt, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<bool> get isAchieved => $composableBuilder(
      column: $table.isAchieved, builder: (column) => column);
}

class $$SavingsGoalsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SavingsGoalsTable,
    SavingsGoal,
    $$SavingsGoalsTableFilterComposer,
    $$SavingsGoalsTableOrderingComposer,
    $$SavingsGoalsTableAnnotationComposer,
    $$SavingsGoalsTableCreateCompanionBuilder,
    $$SavingsGoalsTableUpdateCompanionBuilder,
    (
      SavingsGoal,
      BaseReferences<_$AppDatabase, $SavingsGoalsTable, SavingsGoal>
    ),
    SavingsGoal,
    PrefetchHooks Function()> {
  $$SavingsGoalsTableTableManager(_$AppDatabase db, $SavingsGoalsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavingsGoalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavingsGoalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavingsGoalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> updatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<bool> dirty = const Value.absent(),
            Value<int?> syncedAt = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> bookId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> targetMinor = const Value.absent(),
            Value<int> currentMinor = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String?> accountId = const Value.absent(),
            Value<int?> deadlineAt = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<bool> isAchieved = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SavingsGoalsCompanion(
            updatedAt: updatedAt,
            deleted: deleted,
            dirty: dirty,
            syncedAt: syncedAt,
            id: id,
            bookId: bookId,
            name: name,
            targetMinor: targetMinor,
            currentMinor: currentMinor,
            currency: currency,
            accountId: accountId,
            deadlineAt: deadlineAt,
            note: note,
            isAchieved: isAchieved,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int updatedAt,
            Value<bool> deleted = const Value.absent(),
            Value<bool> dirty = const Value.absent(),
            Value<int?> syncedAt = const Value.absent(),
            required String id,
            required String bookId,
            required String name,
            required int targetMinor,
            Value<int> currentMinor = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String?> accountId = const Value.absent(),
            Value<int?> deadlineAt = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<bool> isAchieved = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SavingsGoalsCompanion.insert(
            updatedAt: updatedAt,
            deleted: deleted,
            dirty: dirty,
            syncedAt: syncedAt,
            id: id,
            bookId: bookId,
            name: name,
            targetMinor: targetMinor,
            currentMinor: currentMinor,
            currency: currency,
            accountId: accountId,
            deadlineAt: deadlineAt,
            note: note,
            isAchieved: isAchieved,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SavingsGoalsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SavingsGoalsTable,
    SavingsGoal,
    $$SavingsGoalsTableFilterComposer,
    $$SavingsGoalsTableOrderingComposer,
    $$SavingsGoalsTableAnnotationComposer,
    $$SavingsGoalsTableCreateCompanionBuilder,
    $$SavingsGoalsTableUpdateCompanionBuilder,
    (
      SavingsGoal,
      BaseReferences<_$AppDatabase, $SavingsGoalsTable, SavingsGoal>
    ),
    SavingsGoal,
    PrefetchHooks Function()>;
typedef $$InstallmentPlansTableCreateCompanionBuilder
    = InstallmentPlansCompanion Function({
  required int updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> syncedAt,
  required String id,
  required String bookId,
  required String title,
  required int totalMinor,
  required int totalPeriods,
  Value<int> paidPeriods,
  Value<int> feePerPeriodMinor,
  Value<String> currency,
  Value<String?> accountId,
  required int firstDueAt,
  Value<String?> note,
  Value<bool> isFinished,
  Value<int> rowid,
});
typedef $$InstallmentPlansTableUpdateCompanionBuilder
    = InstallmentPlansCompanion Function({
  Value<int> updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> syncedAt,
  Value<String> id,
  Value<String> bookId,
  Value<String> title,
  Value<int> totalMinor,
  Value<int> totalPeriods,
  Value<int> paidPeriods,
  Value<int> feePerPeriodMinor,
  Value<String> currency,
  Value<String?> accountId,
  Value<int> firstDueAt,
  Value<String?> note,
  Value<bool> isFinished,
  Value<int> rowid,
});

class $$InstallmentPlansTableFilterComposer
    extends Composer<_$AppDatabase, $InstallmentPlansTable> {
  $$InstallmentPlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get dirty => $composableBuilder(
      column: $table.dirty, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalMinor => $composableBuilder(
      column: $table.totalMinor, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalPeriods => $composableBuilder(
      column: $table.totalPeriods, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get paidPeriods => $composableBuilder(
      column: $table.paidPeriods, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get feePerPeriodMinor => $composableBuilder(
      column: $table.feePerPeriodMinor,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get firstDueAt => $composableBuilder(
      column: $table.firstDueAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isFinished => $composableBuilder(
      column: $table.isFinished, builder: (column) => ColumnFilters(column));
}

class $$InstallmentPlansTableOrderingComposer
    extends Composer<_$AppDatabase, $InstallmentPlansTable> {
  $$InstallmentPlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get dirty => $composableBuilder(
      column: $table.dirty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalMinor => $composableBuilder(
      column: $table.totalMinor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalPeriods => $composableBuilder(
      column: $table.totalPeriods,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get paidPeriods => $composableBuilder(
      column: $table.paidPeriods, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get feePerPeriodMinor => $composableBuilder(
      column: $table.feePerPeriodMinor,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get firstDueAt => $composableBuilder(
      column: $table.firstDueAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isFinished => $composableBuilder(
      column: $table.isFinished, builder: (column) => ColumnOrderings(column));
}

class $$InstallmentPlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $InstallmentPlansTable> {
  $$InstallmentPlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get totalMinor => $composableBuilder(
      column: $table.totalMinor, builder: (column) => column);

  GeneratedColumn<int> get totalPeriods => $composableBuilder(
      column: $table.totalPeriods, builder: (column) => column);

  GeneratedColumn<int> get paidPeriods => $composableBuilder(
      column: $table.paidPeriods, builder: (column) => column);

  GeneratedColumn<int> get feePerPeriodMinor => $composableBuilder(
      column: $table.feePerPeriodMinor, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<int> get firstDueAt => $composableBuilder(
      column: $table.firstDueAt, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<bool> get isFinished => $composableBuilder(
      column: $table.isFinished, builder: (column) => column);
}

class $$InstallmentPlansTableTableManager extends RootTableManager<
    _$AppDatabase,
    $InstallmentPlansTable,
    InstallmentPlan,
    $$InstallmentPlansTableFilterComposer,
    $$InstallmentPlansTableOrderingComposer,
    $$InstallmentPlansTableAnnotationComposer,
    $$InstallmentPlansTableCreateCompanionBuilder,
    $$InstallmentPlansTableUpdateCompanionBuilder,
    (
      InstallmentPlan,
      BaseReferences<_$AppDatabase, $InstallmentPlansTable, InstallmentPlan>
    ),
    InstallmentPlan,
    PrefetchHooks Function()> {
  $$InstallmentPlansTableTableManager(
      _$AppDatabase db, $InstallmentPlansTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InstallmentPlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InstallmentPlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InstallmentPlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> updatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<bool> dirty = const Value.absent(),
            Value<int?> syncedAt = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> bookId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<int> totalMinor = const Value.absent(),
            Value<int> totalPeriods = const Value.absent(),
            Value<int> paidPeriods = const Value.absent(),
            Value<int> feePerPeriodMinor = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String?> accountId = const Value.absent(),
            Value<int> firstDueAt = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<bool> isFinished = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              InstallmentPlansCompanion(
            updatedAt: updatedAt,
            deleted: deleted,
            dirty: dirty,
            syncedAt: syncedAt,
            id: id,
            bookId: bookId,
            title: title,
            totalMinor: totalMinor,
            totalPeriods: totalPeriods,
            paidPeriods: paidPeriods,
            feePerPeriodMinor: feePerPeriodMinor,
            currency: currency,
            accountId: accountId,
            firstDueAt: firstDueAt,
            note: note,
            isFinished: isFinished,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int updatedAt,
            Value<bool> deleted = const Value.absent(),
            Value<bool> dirty = const Value.absent(),
            Value<int?> syncedAt = const Value.absent(),
            required String id,
            required String bookId,
            required String title,
            required int totalMinor,
            required int totalPeriods,
            Value<int> paidPeriods = const Value.absent(),
            Value<int> feePerPeriodMinor = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String?> accountId = const Value.absent(),
            required int firstDueAt,
            Value<String?> note = const Value.absent(),
            Value<bool> isFinished = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              InstallmentPlansCompanion.insert(
            updatedAt: updatedAt,
            deleted: deleted,
            dirty: dirty,
            syncedAt: syncedAt,
            id: id,
            bookId: bookId,
            title: title,
            totalMinor: totalMinor,
            totalPeriods: totalPeriods,
            paidPeriods: paidPeriods,
            feePerPeriodMinor: feePerPeriodMinor,
            currency: currency,
            accountId: accountId,
            firstDueAt: firstDueAt,
            note: note,
            isFinished: isFinished,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$InstallmentPlansTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $InstallmentPlansTable,
    InstallmentPlan,
    $$InstallmentPlansTableFilterComposer,
    $$InstallmentPlansTableOrderingComposer,
    $$InstallmentPlansTableAnnotationComposer,
    $$InstallmentPlansTableCreateCompanionBuilder,
    $$InstallmentPlansTableUpdateCompanionBuilder,
    (
      InstallmentPlan,
      BaseReferences<_$AppDatabase, $InstallmentPlansTable, InstallmentPlan>
    ),
    InstallmentPlan,
    PrefetchHooks Function()>;
typedef $$InstallmentPeriodsTableCreateCompanionBuilder
    = InstallmentPeriodsCompanion Function({
  required int updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> syncedAt,
  required String id,
  required String planId,
  required int periodIndex,
  required int amountMinor,
  required int dueAt,
  Value<int?> paidAt,
  Value<String?> transactionId,
  Value<int> rowid,
});
typedef $$InstallmentPeriodsTableUpdateCompanionBuilder
    = InstallmentPeriodsCompanion Function({
  Value<int> updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> syncedAt,
  Value<String> id,
  Value<String> planId,
  Value<int> periodIndex,
  Value<int> amountMinor,
  Value<int> dueAt,
  Value<int?> paidAt,
  Value<String?> transactionId,
  Value<int> rowid,
});

class $$InstallmentPeriodsTableFilterComposer
    extends Composer<_$AppDatabase, $InstallmentPeriodsTable> {
  $$InstallmentPeriodsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get dirty => $composableBuilder(
      column: $table.dirty, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get planId => $composableBuilder(
      column: $table.planId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get periodIndex => $composableBuilder(
      column: $table.periodIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dueAt => $composableBuilder(
      column: $table.dueAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get paidAt => $composableBuilder(
      column: $table.paidAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get transactionId => $composableBuilder(
      column: $table.transactionId, builder: (column) => ColumnFilters(column));
}

class $$InstallmentPeriodsTableOrderingComposer
    extends Composer<_$AppDatabase, $InstallmentPeriodsTable> {
  $$InstallmentPeriodsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get dirty => $composableBuilder(
      column: $table.dirty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get planId => $composableBuilder(
      column: $table.planId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get periodIndex => $composableBuilder(
      column: $table.periodIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dueAt => $composableBuilder(
      column: $table.dueAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get paidAt => $composableBuilder(
      column: $table.paidAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get transactionId => $composableBuilder(
      column: $table.transactionId,
      builder: (column) => ColumnOrderings(column));
}

class $$InstallmentPeriodsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InstallmentPeriodsTable> {
  $$InstallmentPeriodsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get planId =>
      $composableBuilder(column: $table.planId, builder: (column) => column);

  GeneratedColumn<int> get periodIndex => $composableBuilder(
      column: $table.periodIndex, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => column);

  GeneratedColumn<int> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<int> get paidAt =>
      $composableBuilder(column: $table.paidAt, builder: (column) => column);

  GeneratedColumn<String> get transactionId => $composableBuilder(
      column: $table.transactionId, builder: (column) => column);
}

class $$InstallmentPeriodsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $InstallmentPeriodsTable,
    InstallmentPeriod,
    $$InstallmentPeriodsTableFilterComposer,
    $$InstallmentPeriodsTableOrderingComposer,
    $$InstallmentPeriodsTableAnnotationComposer,
    $$InstallmentPeriodsTableCreateCompanionBuilder,
    $$InstallmentPeriodsTableUpdateCompanionBuilder,
    (
      InstallmentPeriod,
      BaseReferences<_$AppDatabase, $InstallmentPeriodsTable, InstallmentPeriod>
    ),
    InstallmentPeriod,
    PrefetchHooks Function()> {
  $$InstallmentPeriodsTableTableManager(
      _$AppDatabase db, $InstallmentPeriodsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InstallmentPeriodsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InstallmentPeriodsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InstallmentPeriodsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> updatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<bool> dirty = const Value.absent(),
            Value<int?> syncedAt = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> planId = const Value.absent(),
            Value<int> periodIndex = const Value.absent(),
            Value<int> amountMinor = const Value.absent(),
            Value<int> dueAt = const Value.absent(),
            Value<int?> paidAt = const Value.absent(),
            Value<String?> transactionId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              InstallmentPeriodsCompanion(
            updatedAt: updatedAt,
            deleted: deleted,
            dirty: dirty,
            syncedAt: syncedAt,
            id: id,
            planId: planId,
            periodIndex: periodIndex,
            amountMinor: amountMinor,
            dueAt: dueAt,
            paidAt: paidAt,
            transactionId: transactionId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int updatedAt,
            Value<bool> deleted = const Value.absent(),
            Value<bool> dirty = const Value.absent(),
            Value<int?> syncedAt = const Value.absent(),
            required String id,
            required String planId,
            required int periodIndex,
            required int amountMinor,
            required int dueAt,
            Value<int?> paidAt = const Value.absent(),
            Value<String?> transactionId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              InstallmentPeriodsCompanion.insert(
            updatedAt: updatedAt,
            deleted: deleted,
            dirty: dirty,
            syncedAt: syncedAt,
            id: id,
            planId: planId,
            periodIndex: periodIndex,
            amountMinor: amountMinor,
            dueAt: dueAt,
            paidAt: paidAt,
            transactionId: transactionId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$InstallmentPeriodsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $InstallmentPeriodsTable,
    InstallmentPeriod,
    $$InstallmentPeriodsTableFilterComposer,
    $$InstallmentPeriodsTableOrderingComposer,
    $$InstallmentPeriodsTableAnnotationComposer,
    $$InstallmentPeriodsTableCreateCompanionBuilder,
    $$InstallmentPeriodsTableUpdateCompanionBuilder,
    (
      InstallmentPeriod,
      BaseReferences<_$AppDatabase, $InstallmentPeriodsTable, InstallmentPeriod>
    ),
    InstallmentPeriod,
    PrefetchHooks Function()>;
typedef $$BudgetsTableCreateCompanionBuilder = BudgetsCompanion Function({
  required int updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> syncedAt,
  required String id,
  required String bookId,
  required BudgetScope scope,
  required BudgetPeriod period,
  required int amountMinor,
  Value<String> currency,
  Value<String?> categoryId,
  required int year,
  Value<int> periodIndex,
  Value<bool> alertEnabled,
  Value<int> alertThreshold,
  Value<int> rowid,
});
typedef $$BudgetsTableUpdateCompanionBuilder = BudgetsCompanion Function({
  Value<int> updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> syncedAt,
  Value<String> id,
  Value<String> bookId,
  Value<BudgetScope> scope,
  Value<BudgetPeriod> period,
  Value<int> amountMinor,
  Value<String> currency,
  Value<String?> categoryId,
  Value<int> year,
  Value<int> periodIndex,
  Value<bool> alertEnabled,
  Value<int> alertThreshold,
  Value<int> rowid,
});

class $$BudgetsTableFilterComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get dirty => $composableBuilder(
      column: $table.dirty, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<BudgetScope, BudgetScope, int> get scope =>
      $composableBuilder(
          column: $table.scope,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnWithTypeConverterFilters<BudgetPeriod, BudgetPeriod, int> get period =>
      $composableBuilder(
          column: $table.period,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get year => $composableBuilder(
      column: $table.year, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get periodIndex => $composableBuilder(
      column: $table.periodIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get alertEnabled => $composableBuilder(
      column: $table.alertEnabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get alertThreshold => $composableBuilder(
      column: $table.alertThreshold,
      builder: (column) => ColumnFilters(column));
}

class $$BudgetsTableOrderingComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get dirty => $composableBuilder(
      column: $table.dirty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get scope => $composableBuilder(
      column: $table.scope, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get period => $composableBuilder(
      column: $table.period, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get year => $composableBuilder(
      column: $table.year, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get periodIndex => $composableBuilder(
      column: $table.periodIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get alertEnabled => $composableBuilder(
      column: $table.alertEnabled,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get alertThreshold => $composableBuilder(
      column: $table.alertThreshold,
      builder: (column) => ColumnOrderings(column));
}

class $$BudgetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<BudgetScope, int> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumnWithTypeConverter<BudgetPeriod, int> get period =>
      $composableBuilder(column: $table.period, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<int> get periodIndex => $composableBuilder(
      column: $table.periodIndex, builder: (column) => column);

  GeneratedColumn<bool> get alertEnabled => $composableBuilder(
      column: $table.alertEnabled, builder: (column) => column);

  GeneratedColumn<int> get alertThreshold => $composableBuilder(
      column: $table.alertThreshold, builder: (column) => column);
}

class $$BudgetsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BudgetsTable,
    Budget,
    $$BudgetsTableFilterComposer,
    $$BudgetsTableOrderingComposer,
    $$BudgetsTableAnnotationComposer,
    $$BudgetsTableCreateCompanionBuilder,
    $$BudgetsTableUpdateCompanionBuilder,
    (Budget, BaseReferences<_$AppDatabase, $BudgetsTable, Budget>),
    Budget,
    PrefetchHooks Function()> {
  $$BudgetsTableTableManager(_$AppDatabase db, $BudgetsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> updatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<bool> dirty = const Value.absent(),
            Value<int?> syncedAt = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> bookId = const Value.absent(),
            Value<BudgetScope> scope = const Value.absent(),
            Value<BudgetPeriod> period = const Value.absent(),
            Value<int> amountMinor = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String?> categoryId = const Value.absent(),
            Value<int> year = const Value.absent(),
            Value<int> periodIndex = const Value.absent(),
            Value<bool> alertEnabled = const Value.absent(),
            Value<int> alertThreshold = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BudgetsCompanion(
            updatedAt: updatedAt,
            deleted: deleted,
            dirty: dirty,
            syncedAt: syncedAt,
            id: id,
            bookId: bookId,
            scope: scope,
            period: period,
            amountMinor: amountMinor,
            currency: currency,
            categoryId: categoryId,
            year: year,
            periodIndex: periodIndex,
            alertEnabled: alertEnabled,
            alertThreshold: alertThreshold,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int updatedAt,
            Value<bool> deleted = const Value.absent(),
            Value<bool> dirty = const Value.absent(),
            Value<int?> syncedAt = const Value.absent(),
            required String id,
            required String bookId,
            required BudgetScope scope,
            required BudgetPeriod period,
            required int amountMinor,
            Value<String> currency = const Value.absent(),
            Value<String?> categoryId = const Value.absent(),
            required int year,
            Value<int> periodIndex = const Value.absent(),
            Value<bool> alertEnabled = const Value.absent(),
            Value<int> alertThreshold = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BudgetsCompanion.insert(
            updatedAt: updatedAt,
            deleted: deleted,
            dirty: dirty,
            syncedAt: syncedAt,
            id: id,
            bookId: bookId,
            scope: scope,
            period: period,
            amountMinor: amountMinor,
            currency: currency,
            categoryId: categoryId,
            year: year,
            periodIndex: periodIndex,
            alertEnabled: alertEnabled,
            alertThreshold: alertThreshold,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BudgetsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BudgetsTable,
    Budget,
    $$BudgetsTableFilterComposer,
    $$BudgetsTableOrderingComposer,
    $$BudgetsTableAnnotationComposer,
    $$BudgetsTableCreateCompanionBuilder,
    $$BudgetsTableUpdateCompanionBuilder,
    (Budget, BaseReferences<_$AppDatabase, $BudgetsTable, Budget>),
    Budget,
    PrefetchHooks Function()>;
typedef $$InvestmentHoldingsTableCreateCompanionBuilder
    = InvestmentHoldingsCompanion Function({
  required int updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> syncedAt,
  required String id,
  required String bookId,
  required String symbol,
  required String name,
  required InvestmentType type,
  Value<int> quantityMicros,
  Value<int> avgCostMinor,
  Value<int> currentPriceMinor,
  Value<String> currency,
  Value<String?> accountId,
  Value<int?> priceUpdatedAt,
  Value<String?> note,
  Value<int> rowid,
});
typedef $$InvestmentHoldingsTableUpdateCompanionBuilder
    = InvestmentHoldingsCompanion Function({
  Value<int> updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> syncedAt,
  Value<String> id,
  Value<String> bookId,
  Value<String> symbol,
  Value<String> name,
  Value<InvestmentType> type,
  Value<int> quantityMicros,
  Value<int> avgCostMinor,
  Value<int> currentPriceMinor,
  Value<String> currency,
  Value<String?> accountId,
  Value<int?> priceUpdatedAt,
  Value<String?> note,
  Value<int> rowid,
});

class $$InvestmentHoldingsTableFilterComposer
    extends Composer<_$AppDatabase, $InvestmentHoldingsTable> {
  $$InvestmentHoldingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get dirty => $composableBuilder(
      column: $table.dirty, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get symbol => $composableBuilder(
      column: $table.symbol, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<InvestmentType, InvestmentType, int>
      get type => $composableBuilder(
          column: $table.type,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<int> get quantityMicros => $composableBuilder(
      column: $table.quantityMicros,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get avgCostMinor => $composableBuilder(
      column: $table.avgCostMinor, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get currentPriceMinor => $composableBuilder(
      column: $table.currentPriceMinor,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get priceUpdatedAt => $composableBuilder(
      column: $table.priceUpdatedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));
}

class $$InvestmentHoldingsTableOrderingComposer
    extends Composer<_$AppDatabase, $InvestmentHoldingsTable> {
  $$InvestmentHoldingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get dirty => $composableBuilder(
      column: $table.dirty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get symbol => $composableBuilder(
      column: $table.symbol, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get quantityMicros => $composableBuilder(
      column: $table.quantityMicros,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get avgCostMinor => $composableBuilder(
      column: $table.avgCostMinor,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get currentPriceMinor => $composableBuilder(
      column: $table.currentPriceMinor,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get priceUpdatedAt => $composableBuilder(
      column: $table.priceUpdatedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));
}

class $$InvestmentHoldingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InvestmentHoldingsTable> {
  $$InvestmentHoldingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<InvestmentType, int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get quantityMicros => $composableBuilder(
      column: $table.quantityMicros, builder: (column) => column);

  GeneratedColumn<int> get avgCostMinor => $composableBuilder(
      column: $table.avgCostMinor, builder: (column) => column);

  GeneratedColumn<int> get currentPriceMinor => $composableBuilder(
      column: $table.currentPriceMinor, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<int> get priceUpdatedAt => $composableBuilder(
      column: $table.priceUpdatedAt, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$InvestmentHoldingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $InvestmentHoldingsTable,
    InvestmentHolding,
    $$InvestmentHoldingsTableFilterComposer,
    $$InvestmentHoldingsTableOrderingComposer,
    $$InvestmentHoldingsTableAnnotationComposer,
    $$InvestmentHoldingsTableCreateCompanionBuilder,
    $$InvestmentHoldingsTableUpdateCompanionBuilder,
    (
      InvestmentHolding,
      BaseReferences<_$AppDatabase, $InvestmentHoldingsTable, InvestmentHolding>
    ),
    InvestmentHolding,
    PrefetchHooks Function()> {
  $$InvestmentHoldingsTableTableManager(
      _$AppDatabase db, $InvestmentHoldingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InvestmentHoldingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InvestmentHoldingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InvestmentHoldingsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> updatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<bool> dirty = const Value.absent(),
            Value<int?> syncedAt = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> bookId = const Value.absent(),
            Value<String> symbol = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<InvestmentType> type = const Value.absent(),
            Value<int> quantityMicros = const Value.absent(),
            Value<int> avgCostMinor = const Value.absent(),
            Value<int> currentPriceMinor = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String?> accountId = const Value.absent(),
            Value<int?> priceUpdatedAt = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              InvestmentHoldingsCompanion(
            updatedAt: updatedAt,
            deleted: deleted,
            dirty: dirty,
            syncedAt: syncedAt,
            id: id,
            bookId: bookId,
            symbol: symbol,
            name: name,
            type: type,
            quantityMicros: quantityMicros,
            avgCostMinor: avgCostMinor,
            currentPriceMinor: currentPriceMinor,
            currency: currency,
            accountId: accountId,
            priceUpdatedAt: priceUpdatedAt,
            note: note,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int updatedAt,
            Value<bool> deleted = const Value.absent(),
            Value<bool> dirty = const Value.absent(),
            Value<int?> syncedAt = const Value.absent(),
            required String id,
            required String bookId,
            required String symbol,
            required String name,
            required InvestmentType type,
            Value<int> quantityMicros = const Value.absent(),
            Value<int> avgCostMinor = const Value.absent(),
            Value<int> currentPriceMinor = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String?> accountId = const Value.absent(),
            Value<int?> priceUpdatedAt = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              InvestmentHoldingsCompanion.insert(
            updatedAt: updatedAt,
            deleted: deleted,
            dirty: dirty,
            syncedAt: syncedAt,
            id: id,
            bookId: bookId,
            symbol: symbol,
            name: name,
            type: type,
            quantityMicros: quantityMicros,
            avgCostMinor: avgCostMinor,
            currentPriceMinor: currentPriceMinor,
            currency: currency,
            accountId: accountId,
            priceUpdatedAt: priceUpdatedAt,
            note: note,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$InvestmentHoldingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $InvestmentHoldingsTable,
    InvestmentHolding,
    $$InvestmentHoldingsTableFilterComposer,
    $$InvestmentHoldingsTableOrderingComposer,
    $$InvestmentHoldingsTableAnnotationComposer,
    $$InvestmentHoldingsTableCreateCompanionBuilder,
    $$InvestmentHoldingsTableUpdateCompanionBuilder,
    (
      InvestmentHolding,
      BaseReferences<_$AppDatabase, $InvestmentHoldingsTable, InvestmentHolding>
    ),
    InvestmentHolding,
    PrefetchHooks Function()>;
typedef $$InventoryItemsTableCreateCompanionBuilder = InventoryItemsCompanion
    Function({
  required int updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> syncedAt,
  required String id,
  required String bookId,
  required String name,
  Value<String?> category,
  Value<int> purchasePriceMinor,
  Value<int> currentValueMinor,
  Value<String> currency,
  required int purchasedAt,
  Value<int?> warrantyUntil,
  Value<String?> photoUrl,
  Value<String?> location,
  Value<String?> note,
  Value<String?> transactionId,
  Value<int> rowid,
});
typedef $$InventoryItemsTableUpdateCompanionBuilder = InventoryItemsCompanion
    Function({
  Value<int> updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> syncedAt,
  Value<String> id,
  Value<String> bookId,
  Value<String> name,
  Value<String?> category,
  Value<int> purchasePriceMinor,
  Value<int> currentValueMinor,
  Value<String> currency,
  Value<int> purchasedAt,
  Value<int?> warrantyUntil,
  Value<String?> photoUrl,
  Value<String?> location,
  Value<String?> note,
  Value<String?> transactionId,
  Value<int> rowid,
});

class $$InventoryItemsTableFilterComposer
    extends Composer<_$AppDatabase, $InventoryItemsTable> {
  $$InventoryItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get dirty => $composableBuilder(
      column: $table.dirty, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get purchasePriceMinor => $composableBuilder(
      column: $table.purchasePriceMinor,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get currentValueMinor => $composableBuilder(
      column: $table.currentValueMinor,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get purchasedAt => $composableBuilder(
      column: $table.purchasedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get warrantyUntil => $composableBuilder(
      column: $table.warrantyUntil, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get photoUrl => $composableBuilder(
      column: $table.photoUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get location => $composableBuilder(
      column: $table.location, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get transactionId => $composableBuilder(
      column: $table.transactionId, builder: (column) => ColumnFilters(column));
}

class $$InventoryItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $InventoryItemsTable> {
  $$InventoryItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get dirty => $composableBuilder(
      column: $table.dirty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get purchasePriceMinor => $composableBuilder(
      column: $table.purchasePriceMinor,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get currentValueMinor => $composableBuilder(
      column: $table.currentValueMinor,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get purchasedAt => $composableBuilder(
      column: $table.purchasedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get warrantyUntil => $composableBuilder(
      column: $table.warrantyUntil,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get photoUrl => $composableBuilder(
      column: $table.photoUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get location => $composableBuilder(
      column: $table.location, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get transactionId => $composableBuilder(
      column: $table.transactionId,
      builder: (column) => ColumnOrderings(column));
}

class $$InventoryItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InventoryItemsTable> {
  $$InventoryItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get purchasePriceMinor => $composableBuilder(
      column: $table.purchasePriceMinor, builder: (column) => column);

  GeneratedColumn<int> get currentValueMinor => $composableBuilder(
      column: $table.currentValueMinor, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get purchasedAt => $composableBuilder(
      column: $table.purchasedAt, builder: (column) => column);

  GeneratedColumn<int> get warrantyUntil => $composableBuilder(
      column: $table.warrantyUntil, builder: (column) => column);

  GeneratedColumn<String> get photoUrl =>
      $composableBuilder(column: $table.photoUrl, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get transactionId => $composableBuilder(
      column: $table.transactionId, builder: (column) => column);
}

class $$InventoryItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $InventoryItemsTable,
    InventoryItem,
    $$InventoryItemsTableFilterComposer,
    $$InventoryItemsTableOrderingComposer,
    $$InventoryItemsTableAnnotationComposer,
    $$InventoryItemsTableCreateCompanionBuilder,
    $$InventoryItemsTableUpdateCompanionBuilder,
    (
      InventoryItem,
      BaseReferences<_$AppDatabase, $InventoryItemsTable, InventoryItem>
    ),
    InventoryItem,
    PrefetchHooks Function()> {
  $$InventoryItemsTableTableManager(
      _$AppDatabase db, $InventoryItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InventoryItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InventoryItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InventoryItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> updatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<bool> dirty = const Value.absent(),
            Value<int?> syncedAt = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> bookId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<int> purchasePriceMinor = const Value.absent(),
            Value<int> currentValueMinor = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<int> purchasedAt = const Value.absent(),
            Value<int?> warrantyUntil = const Value.absent(),
            Value<String?> photoUrl = const Value.absent(),
            Value<String?> location = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String?> transactionId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              InventoryItemsCompanion(
            updatedAt: updatedAt,
            deleted: deleted,
            dirty: dirty,
            syncedAt: syncedAt,
            id: id,
            bookId: bookId,
            name: name,
            category: category,
            purchasePriceMinor: purchasePriceMinor,
            currentValueMinor: currentValueMinor,
            currency: currency,
            purchasedAt: purchasedAt,
            warrantyUntil: warrantyUntil,
            photoUrl: photoUrl,
            location: location,
            note: note,
            transactionId: transactionId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int updatedAt,
            Value<bool> deleted = const Value.absent(),
            Value<bool> dirty = const Value.absent(),
            Value<int?> syncedAt = const Value.absent(),
            required String id,
            required String bookId,
            required String name,
            Value<String?> category = const Value.absent(),
            Value<int> purchasePriceMinor = const Value.absent(),
            Value<int> currentValueMinor = const Value.absent(),
            Value<String> currency = const Value.absent(),
            required int purchasedAt,
            Value<int?> warrantyUntil = const Value.absent(),
            Value<String?> photoUrl = const Value.absent(),
            Value<String?> location = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String?> transactionId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              InventoryItemsCompanion.insert(
            updatedAt: updatedAt,
            deleted: deleted,
            dirty: dirty,
            syncedAt: syncedAt,
            id: id,
            bookId: bookId,
            name: name,
            category: category,
            purchasePriceMinor: purchasePriceMinor,
            currentValueMinor: currentValueMinor,
            currency: currency,
            purchasedAt: purchasedAt,
            warrantyUntil: warrantyUntil,
            photoUrl: photoUrl,
            location: location,
            note: note,
            transactionId: transactionId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$InventoryItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $InventoryItemsTable,
    InventoryItem,
    $$InventoryItemsTableFilterComposer,
    $$InventoryItemsTableOrderingComposer,
    $$InventoryItemsTableAnnotationComposer,
    $$InventoryItemsTableCreateCompanionBuilder,
    $$InventoryItemsTableUpdateCompanionBuilder,
    (
      InventoryItem,
      BaseReferences<_$AppDatabase, $InventoryItemsTable, InventoryItem>
    ),
    InventoryItem,
    PrefetchHooks Function()>;
typedef $$PendingOpsTableCreateCompanionBuilder = PendingOpsCompanion Function({
  Value<int> localSeq,
  required String targetTable,
  required String recordId,
  required SyncOpType opType,
  Value<String?> payload,
  required int updatedAt,
  required int createdAt,
  Value<int> retryCount,
});
typedef $$PendingOpsTableUpdateCompanionBuilder = PendingOpsCompanion Function({
  Value<int> localSeq,
  Value<String> targetTable,
  Value<String> recordId,
  Value<SyncOpType> opType,
  Value<String?> payload,
  Value<int> updatedAt,
  Value<int> createdAt,
  Value<int> retryCount,
});

class $$PendingOpsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingOpsTable> {
  $$PendingOpsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get localSeq => $composableBuilder(
      column: $table.localSeq, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get targetTable => $composableBuilder(
      column: $table.targetTable, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recordId => $composableBuilder(
      column: $table.recordId, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<SyncOpType, SyncOpType, int> get opType =>
      $composableBuilder(
          column: $table.opType,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnFilters(column));
}

class $$PendingOpsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingOpsTable> {
  $$PendingOpsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get localSeq => $composableBuilder(
      column: $table.localSeq, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetTable => $composableBuilder(
      column: $table.targetTable, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recordId => $composableBuilder(
      column: $table.recordId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get opType => $composableBuilder(
      column: $table.opType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnOrderings(column));
}

class $$PendingOpsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingOpsTable> {
  $$PendingOpsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get localSeq =>
      $composableBuilder(column: $table.localSeq, builder: (column) => column);

  GeneratedColumn<String> get targetTable => $composableBuilder(
      column: $table.targetTable, builder: (column) => column);

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SyncOpType, int> get opType =>
      $composableBuilder(column: $table.opType, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => column);
}

class $$PendingOpsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PendingOpsTable,
    PendingOp,
    $$PendingOpsTableFilterComposer,
    $$PendingOpsTableOrderingComposer,
    $$PendingOpsTableAnnotationComposer,
    $$PendingOpsTableCreateCompanionBuilder,
    $$PendingOpsTableUpdateCompanionBuilder,
    (PendingOp, BaseReferences<_$AppDatabase, $PendingOpsTable, PendingOp>),
    PendingOp,
    PrefetchHooks Function()> {
  $$PendingOpsTableTableManager(_$AppDatabase db, $PendingOpsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingOpsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingOpsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingOpsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> localSeq = const Value.absent(),
            Value<String> targetTable = const Value.absent(),
            Value<String> recordId = const Value.absent(),
            Value<SyncOpType> opType = const Value.absent(),
            Value<String?> payload = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
          }) =>
              PendingOpsCompanion(
            localSeq: localSeq,
            targetTable: targetTable,
            recordId: recordId,
            opType: opType,
            payload: payload,
            updatedAt: updatedAt,
            createdAt: createdAt,
            retryCount: retryCount,
          ),
          createCompanionCallback: ({
            Value<int> localSeq = const Value.absent(),
            required String targetTable,
            required String recordId,
            required SyncOpType opType,
            Value<String?> payload = const Value.absent(),
            required int updatedAt,
            required int createdAt,
            Value<int> retryCount = const Value.absent(),
          }) =>
              PendingOpsCompanion.insert(
            localSeq: localSeq,
            targetTable: targetTable,
            recordId: recordId,
            opType: opType,
            payload: payload,
            updatedAt: updatedAt,
            createdAt: createdAt,
            retryCount: retryCount,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PendingOpsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PendingOpsTable,
    PendingOp,
    $$PendingOpsTableFilterComposer,
    $$PendingOpsTableOrderingComposer,
    $$PendingOpsTableAnnotationComposer,
    $$PendingOpsTableCreateCompanionBuilder,
    $$PendingOpsTableUpdateCompanionBuilder,
    (PendingOp, BaseReferences<_$AppDatabase, $PendingOpsTable, PendingOp>),
    PendingOp,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db, _db.books);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$LendRecordsTableTableManager get lendRecords =>
      $$LendRecordsTableTableManager(_db, _db.lendRecords);
  $$ReimbursementsTableTableManager get reimbursements =>
      $$ReimbursementsTableTableManager(_db, _db.reimbursements);
  $$SavingsGoalsTableTableManager get savingsGoals =>
      $$SavingsGoalsTableTableManager(_db, _db.savingsGoals);
  $$InstallmentPlansTableTableManager get installmentPlans =>
      $$InstallmentPlansTableTableManager(_db, _db.installmentPlans);
  $$InstallmentPeriodsTableTableManager get installmentPeriods =>
      $$InstallmentPeriodsTableTableManager(_db, _db.installmentPeriods);
  $$BudgetsTableTableManager get budgets =>
      $$BudgetsTableTableManager(_db, _db.budgets);
  $$InvestmentHoldingsTableTableManager get investmentHoldings =>
      $$InvestmentHoldingsTableTableManager(_db, _db.investmentHoldings);
  $$InventoryItemsTableTableManager get inventoryItems =>
      $$InventoryItemsTableTableManager(_db, _db.inventoryItems);
  $$PendingOpsTableTableManager get pendingOps =>
      $$PendingOpsTableTableManager(_db, _db.pendingOps);
}
