import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../lend/data/lend_repository.dart';
import '../../ledger/data/transaction_repository.dart';

/// 账户仓储
class AccountRepository {
  const AccountRepository(this._db);

  final AppDatabase _db;

  Future<String> add({
    required String bookId,
    required String name,
    required AccountType type,
    int balanceMinor = 0,
    String currency = 'CNY',
    int? creditLimitMinor,
    int? billingDay,
    int? dueDay,
    String? note,
    String? cardNumber,
    AccountStatus status = AccountStatus.active,
    bool includeInTotal = true,
  }) {
    if (name.trim().isEmpty) {
      throw const ValidationFailure('账户名称不能为空');
    }

    final String id = const Uuid().v7();
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;

    return _db.transaction<String>(() async {
      await _db.accountsDao.insertAccount(
        AccountsCompanion(
          id: Value<String>(id),
          bookId: Value<String>(bookId),
          name: Value<String>(name.trim()),
          type: Value<AccountType>(type),
          balanceMinor: Value<int>(balanceMinor),
          currency: Value<String>(currency),
          creditLimitMinor: Value<int?>(creditLimitMinor),
          billingDay: Value<int?>(billingDay),
          dueDay: Value<int?>(dueDay),
          note: Value<String?>(note),
          cardNumber: Value<String?>(cardNumber),
          status: Value<AccountStatus>(status),
          includeInTotal: Value<bool>(includeInTotal),
          isArchived: Value<bool>(!status.isVisible),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );

      await _db.pendingOpsDao.enqueue(
        PendingOpsCompanion(
          targetTable: const Value<String>('accounts'),
          recordId: Value<String>(id),
          opType: const Value<SyncOpType>(SyncOpType.insert),
          payload: Value<String>(
            jsonEncode(<String, Object?>{
              'bookId': bookId,
              'name': name.trim(),
              'type': type.index,
              'balanceMinor': balanceMinor,
              'currency': currency,
              'creditLimitMinor': creditLimitMinor,
              'billingDay': billingDay,
              'dueDay': dueDay,
              'note': note,
              'cardNumber': cardNumber,
              'status': status.index,
              'includeInTotal': includeInTotal,
            }),
          ),
          updatedAt: Value<int>(now),
          createdAt: Value<int>(now),
        ),
      );

      return id;
    });
  }

  Future<void> remove(String id) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.transaction<void>(() async {
      // 借还账户（借出/借入）销户即清账：名下借还记录及其关联流水
      // （本金/还债/收债/备忘）一并移除，真实资金账户余额随流水撤销
      // 回滚——流水页不再残留已销户借还账户的账目。其他类型账户名下
      // 无借还记录，此调用为空操作。
      await LendRepository(_db, TransactionRepository(_db))
          .purgeByDesignatedAccount(id);
      await _db.accountsDao.softDelete(id, now);
      await _db.pendingOpsDao.enqueue(
        PendingOpsCompanion(
          targetTable: const Value<String>('accounts'),
          recordId: Value<String>(id),
          opType: const Value<SyncOpType>(SyncOpType.delete),
          updatedAt: Value<int>(now),
          createdAt: Value<int>(now),
        ),
      );
    });
  }

  /// 隐藏账户：仅置 `isArchived = true`，数据保留，可通过 [unarchive] 恢复。
  Future<void> archive(String id) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.transaction<void>(() async {
      await _db.accountsDao.archive(id, now);
      await _db.pendingOpsDao.enqueue(
        PendingOpsCompanion(
          targetTable: const Value<String>('accounts'),
          recordId: Value<String>(id),
          opType: const Value<SyncOpType>(SyncOpType.update),
          payload: Value<String>(
            jsonEncode(<String, Object?>{'isArchived': true}),
          ),
          updatedAt: Value<int>(now),
          createdAt: Value<int>(now),
        ),
      );
    });
  }

  /// 取消隐藏（撤销 [archive]）。仅当 `deleted = false` 时才需要。
  Future<void> unarchive(String id) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.transaction<void>(() async {
      await _db.accountsDao.unarchive(id, now);
      await _db.pendingOpsDao.enqueue(
        PendingOpsCompanion(
          targetTable: const Value<String>('accounts'),
          recordId: Value<String>(id),
          opType: const Value<SyncOpType>(SyncOpType.update),
          payload: Value<String>(
            jsonEncode(<String, Object?>{'isArchived': false}),
          ),
          updatedAt: Value<int>(now),
          createdAt: Value<int>(now),
        ),
      );
    });
  }

  /// 编辑账户（名称 / 类型 / 余额 / 备注 / 卡号 / 状态 / 是否计入总资产）。
  /// 余额直接设为权威值，用于手动校正。
  Future<void> update({
    required String id,
    required String name,
    required AccountType type,
    required int balanceMinor,
    String currency = 'CNY',
    int? creditLimitMinor,
    int? billingDay,
    int? dueDay,
    String? note,
    String? cardNumber,
    AccountStatus status = AccountStatus.active,
    bool includeInTotal = true,
  }) {
    if (name.trim().isEmpty) {
      throw const ValidationFailure('账户名称不能为空');
    }

    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;

    return _db.transaction<void>(() async {
      await _db.accountsDao.updateAccount(
        AccountsCompanion(
          id: Value<String>(id),
          name: Value<String>(name.trim()),
          type: Value<AccountType>(type),
          balanceMinor: Value<int>(balanceMinor),
          currency: Value<String>(currency),
          creditLimitMinor: Value<int?>(creditLimitMinor),
          billingDay: Value<int?>(billingDay),
          dueDay: Value<int?>(dueDay),
          note: Value<String?>(note),
          cardNumber: Value<String?>(cardNumber),
          status: Value<AccountStatus>(status),
          includeInTotal: Value<bool>(includeInTotal),
          isArchived: Value<bool>(!status.isVisible),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );

      await _db.pendingOpsDao.enqueue(
        PendingOpsCompanion(
          targetTable: const Value<String>('accounts'),
          recordId: Value<String>(id),
          opType: const Value<SyncOpType>(SyncOpType.update),
          payload: Value<String>(
            jsonEncode(<String, Object?>{
              'name': name.trim(),
              'type': type.index,
              'balanceMinor': balanceMinor,
              'currency': currency,
              'creditLimitMinor': creditLimitMinor,
              'billingDay': billingDay,
              'dueDay': dueDay,
              'note': note,
              'cardNumber': cardNumber,
              'status': status.index,
              'includeInTotal': includeInTotal,
            }),
          ),
          updatedAt: Value<int>(now),
          createdAt: Value<int>(now),
        ),
      );
    });
  }
}
