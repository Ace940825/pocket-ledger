import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';

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

  /// 编辑账户（名称 / 类型 / 余额）。余额直接设为权威值，用于手动校正。
  Future<void> update({
    required String id,
    required String name,
    required AccountType type,
    required int balanceMinor,
    String currency = 'CNY',
    int? creditLimitMinor,
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
            }),
          ),
          updatedAt: Value<int>(now),
          createdAt: Value<int>(now),
        ),
      );
    });
  }
}
