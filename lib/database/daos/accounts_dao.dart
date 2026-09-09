import 'package:drift/drift.dart';

import '../app_database.dart';

part 'accounts_dao.g.dart';

/// 账户数据访问
@DriftAccessor(tables: <Type>[Accounts])
class AccountsDao extends DatabaseAccessor<AppDatabase>
    with _$AccountsDaoMixin {
  AccountsDao(super.attachedDatabase);

  /// 实时监听账户列表（排除已归档）
  Stream<List<Account>> watchByBook(String bookId) {
    return (select(accounts)
          ..where(($AccountsTable tbl) =>
              tbl.bookId.equals(bookId) & tbl.isArchived.equals(false),)
          ..orderBy([
            ($AccountsTable tbl) => OrderingTerm.asc(tbl.sortOrder),
          ]))
        .watch();
  }

  /// 实时监听净资产 = 资产账户余额 - 负债（信用卡欠款）
  ///
  /// 信用卡余额为负数，直接对所有账户求和即为净资产。
  Stream<int> watchNetAssets(String bookId) {
    final Expression<int> total = accounts.balanceMinor.sum();
    return (selectOnly(accounts)
          ..addColumns(<Expression<Object>>[total])
          ..where(
            accounts.bookId.equals(bookId) &
                accounts.deleted.equals(false) &
                accounts.isArchived.equals(false),
          ))
        .map((TypedResult row) => row.read(total) ?? 0)
        .watchSingle();
  }

  /// 实时监听总资产（仅正数余额账户之和）
  Stream<int> watchTotalAssets(String bookId) {
    final Expression<int> total = accounts.balanceMinor.sum();
    return (selectOnly(accounts)
          ..addColumns(<Expression<Object>>[total])
          ..where(
            accounts.bookId.equals(bookId) &
                accounts.deleted.equals(false) &
                accounts.isArchived.equals(false) &
                accounts.balanceMinor.isBiggerThanValue(0),
          ))
        .map((TypedResult row) => row.read(total) ?? 0)
        .watchSingle();
  }

  Future<Account?> getById(String id) {
    return (select(accounts)
          ..where(($AccountsTable tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  /// 调整账户余额（分），正负号由调用方决定。
  /// 必须在事务中调用，保证与流水写入的原子性。
  Future<void> adjustBalance(String id, int deltaMinor, int updatedAt) {
    return customStatement(
      'UPDATE accounts SET balance_minor = balance_minor + ?, '
      'updated_at = ?, dirty = 1 WHERE id = ?',
      <Object?>[deltaMinor, updatedAt, id],
    );
  }

  Future<void> insertAccount(AccountsCompanion companion) {
    return into(accounts).insert(companion);
  }

  Future<bool> updateAccount(AccountsCompanion companion) {
    return update(accounts).replace(companion);
  }

  /// 软删除
  Future<int> softDelete(String id, int updatedAt) {
    return (update(accounts)
          ..where(($AccountsTable tbl) => tbl.id.equals(id)))
        .write(
      AccountsCompanion(
        deleted: const Value<bool>(true),
        isArchived: const Value<bool>(true),
        dirty: const Value<bool>(true),
        updatedAt: Value<int>(updatedAt),
      ),
    );
  }

  Future<List<Account>> dirtyAccounts({int limit = 200}) {
    return (select(accounts)
          ..where(($AccountsTable tbl) => tbl.dirty.equals(true))
          ..limit(limit))
        .get();
  }
}
