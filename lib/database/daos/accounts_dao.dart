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
          ..where(
            ($AccountsTable tbl) =>
                tbl.bookId.equals(bookId) & tbl.isArchived.equals(false),
          )
          ..orderBy([
            ($AccountsTable tbl) => OrderingTerm.asc(tbl.sortOrder),
          ]))
        .watch();
  }

  /// 实时监听净资产。
  ///
  /// **约定**：信用卡余额以**正数**存储，表示「欠款金额」。因此净资产 = 非信用卡账户余额之和 − 信用卡账户余额之和。
  ///
  /// 历史背景：早期版本曾把信用卡余额存为负数再用 `Σbalances` 一把算，导致用户建信用卡账户时
  /// 初始余额 1000 被算成「资产 1000、负债 0」。现已统一为「信用卡正余额=欠款」语义。
  Stream<int> watchNetAssets(String bookId) {
    return watchByBook(bookId).map(_sumNetAssets);
  }

  /// 实时监听总资产（仅非信用卡账户的正余额之和）。
  Stream<int> watchTotalAssets(String bookId) {
    return watchByBook(bookId).map(_sumTotalAssets);
  }

  /// 实时监听总负债（所有信用卡账户余额之和，正数）。
  Stream<int> watchTotalLiabilities(String bookId) {
    return watchByBook(bookId).map(_sumTotalLiabilities);
  }

  static int _sumNetAssets(List<Account> list) {
    int net = 0;
    for (final Account a in list) {
      if (a.type.isDebt) {
        net -= a.balanceMinor; // 负债正余额=欠款，从净资产里扣
      } else {
        net += a.balanceMinor;
      }
    }
    return net;
  }

  static int _sumTotalAssets(List<Account> list) {
    int total = 0;
    for (final Account a in list) {
      // 只算非负债账户的正余额。
      if (!a.type.isDebt && a.balanceMinor > 0) {
        total += a.balanceMinor;
      }
    }
    return total;
  }

  static int _sumTotalLiabilities(List<Account> list) {
    int total = 0;
    for (final Account a in list) {
      if (a.type.isDebt) {
        total += a.balanceMinor; // 正余额即欠款金额
      }
    }
    return total;
  }

  Future<Account?> getById(String id) {
    return (select(accounts)..where(($AccountsTable tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  /// 按 ID 实时监听单个账户（即使已归档/隐藏也返回）。
  Stream<Account?> watchById(String id) {
    return (select(accounts)..where(($AccountsTable tbl) => tbl.id.equals(id)))
        .watchSingleOrNull();
  }

  /// 调整账户余额（分），正负号由调用方决定。
  /// 必须在事务中调用，保证与流水写入的原子性。
  ///
  /// 必须用 [customUpdate] 并显式声明 `updates: {accounts}`，
  /// 否则 Drift 的 reactive watch（净资产 / 总资产 provider）收不到这条 UPDATE 的通知，
  /// 首页三卡永远不刷新。`customStatement` 不会触发 reactive 失效。
  Future<int> adjustBalance(String id, int deltaMinor, int updatedAt) {
    return customUpdate(
      'UPDATE accounts SET balance_minor = balance_minor + ?, '
      'updated_at = ?, dirty = 1 WHERE id = ?',
      variables: <Variable<Object>>[
        Variable<int>(deltaMinor),
        Variable<int>(updatedAt),
        Variable<String>(id),
      ],
      updates: {accounts},
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
    return (update(accounts)..where(($AccountsTable tbl) => tbl.id.equals(id)))
        .write(
      AccountsCompanion(
        deleted: const Value<bool>(true),
        isArchived: const Value<bool>(true),
        dirty: const Value<bool>(true),
        updatedAt: Value<int>(updatedAt),
      ),
    );
  }

  /// 隐藏（不计入资产/列表展示，但保留数据与流水关联）。
  /// 与 [softDelete] 区别：隐藏只置 `isArchived = true`、`deleted = false`，
  /// 后续可调用 [unarchive] 恢复。
  Future<int> archive(String id, int updatedAt) {
    return (update(accounts)..where(($AccountsTable tbl) => tbl.id.equals(id)))
        .write(
      AccountsCompanion(
        isArchived: const Value<bool>(true),
        dirty: const Value<bool>(true),
        updatedAt: Value<int>(updatedAt),
      ),
    );
  }

  /// 取消隐藏（撤销 [archive]）。不会改 `deleted` 字段。
  Future<int> unarchive(String id, int updatedAt) {
    return (update(accounts)..where(($AccountsTable tbl) => tbl.id.equals(id)))
        .write(
      AccountsCompanion(
        isArchived: const Value<bool>(false),
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
