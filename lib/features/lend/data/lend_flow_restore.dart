import 'package:drift/drift.dart';

import '../../../database/app_database.dart';
import '../../../database/sync_enqueue.dart';
import '../../../domain/enums.dart';

/// 借还账户余额对账与冲销反向恢复（共享工具）。
///
/// 单一事实来源：[LendRepository]（add/update/remove/purge/repay 后的
/// 余额对账、冲销流水生成时的台账写入）与 [TransactionRepository.remove]
/// （删除借还冲销流水时的反向恢复）共用本文件的实现，避免三处漂移
/// （bootstrap.dart 里另有启动兜底的一份同口径副本）。
///
/// 不变量：借出(lend)/借入(borrow)类型账户的 balanceMinor =
/// 名下未结清借还记录合计（本金 − 优惠 − 已还）。流水挂在这些账户上的
/// 余额增量是错向的（借出记支出做减法），一律以记录合计为准。
///
/// 冲销台账 `lend_flow_offsets(txn_id, lend_record_id, amount_minor)`：
/// 记录每笔还债/收债/债务消减/坏账计提流水分别冲销了哪些借还记录、
/// 各多少，供流水删除时精确反向恢复（含跨账户冲销）。

/// 借还账户余额对账（幂等）：余额重算为名下未结清记录合计，
/// 仅对 lend/borrow 类型账户生效，无偏差不写库（避免脏同步）。
Future<void> reconcileDesignatedLendBalance(
  AppDatabase db,
  String? accountId,
) async {
  if (accountId == null || accountId.isEmpty) return;
  final Account? acc = await (db.select(db.accounts)
        ..where((Accounts t) => t.id.equals(accountId)))
      .getSingleOrNull();
  if (acc == null || acc.deleted) return;
  if (acc.type != AccountType.lend.index &&
      acc.type != AccountType.borrow.index) {
    return;
  }
  final LendDirection dir = acc.type == AccountType.lend.index
      ? LendDirection.lendOut
      : LendDirection.borrowIn;
  final List<LendRecord> records = await (db.select(db.lendRecords)
        ..where((LendRecords t) =>
            t.accountId.equals(acc.id) &
            t.direction.equals(dir.index) &
            t.status.equals(LendStatus.ongoing.index) &
            t.deleted.equals(false)))
      .get();
  final int want = records.fold<int>(
    0,
    (int sum, LendRecord r) =>
        sum + r.amountMinor - r.discountMinor - r.repaidMinor,
  );
  if (acc.balanceMinor == want) return;
  await (db.update(db.accounts)..where((Accounts t) => t.id.equals(acc.id)))
      .write(
    AccountsCompanion(
      balanceMinor: Value<int>(want),
      updatedAt: Value<int>(DateTime.now().toUtc().millisecondsSinceEpoch),
      dirty: const Value<bool>(true),
    ),
  );
}

/// 写入一笔借还流水的冲销台账：记录它分别冲销了哪些借还记录、各多少。
Future<void> writeLendOffsets(
  AppDatabase db,
  String txnId,
  List<({String id, int amount})> hits,
) async {
  for (final ({String id, int amount}) h in hits) {
    await db.customStatement(
      'INSERT INTO lend_flow_offsets (txn_id, lend_record_id, amount_minor) '
      'VALUES (?, ?, ?)',
      <Object?>[txnId, h.id, h.amount],
    );
  }
}

/// 删除某笔流水的全部冲销台账。
Future<void> deleteLendOffsets(AppDatabase db, String txnId) async {
  await db.customStatement(
    'DELETE FROM lend_flow_offsets WHERE txn_id = ?',
    <Object?>[txnId],
  );
}

/// 删除指向某借还记录的冲销台账（该记录被单独删除时清理）。
Future<void> deleteLendOffsetsForRecord(
  AppDatabase db,
  String recordId,
) async {
  await db.customStatement(
    'DELETE FROM lend_flow_offsets WHERE lend_record_id = ?',
    <Object?>[recordId],
  );
}

/// 反向恢复某借还记录的已还金额（冲销流水被撤销时调用）。
/// 将 [amount] 从 [record.repaidMinor] 扣减（下限 0）；若因此低于本金，
/// 状态从「已结清」回退为「进行中」，并逐条入队同步。
Future<void> revertLendRepaid(
  AppDatabase db,
  LendRecord record,
  int amount,
) async {
  if (amount <= 0) return;
  final int newRepaid = (record.repaidMinor - amount) < 0
      ? 0
      : record.repaidMinor - amount;
  final LendStatus newStatus =
      newRepaid + record.discountMinor >= record.amountMinor
          ? LendStatus.settled
          : LendStatus.ongoing;
  final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await (db.update(db.lendRecords)
        ..where((LendRecords t) => t.id.equals(record.id)))
      .write(
    LendRecordsCompanion(
      repaidMinor: Value<int>(newRepaid),
      status: Value<LendStatus>(newStatus),
      updatedAt: Value<int>(now),
      dirty: const Value<bool>(true),
    ),
  );
  await enqueueSyncOp(
    db,
    table: 'lend_records',
    recordId: record.id,
    opType: SyncOpType.update,
    updatedAt: now,
    payload: <String, Object?>{
      'direction': record.direction.index,
      'status': newStatus.index,
      'counterparty': record.counterparty,
      'amountMinor': record.amountMinor,
      'repaidMinor': newRepaid,
      'occurredAt': record.occurredAt,
      'dueAt': record.dueAt,
      'note': record.note,
      'accountId': record.accountId,
      'toAccountId': record.toAccountId,
      'feeMinor': record.feeMinor,
      'discountMinor': record.discountMinor,
    },
  );
}

/// 借还冲销流水的备注动词前缀（还债/收债/债务消减/坏账计提四类）。
/// 本金流水（借入-xxx / 借出-xxx）不在此列，删除时不做债务恢复。
const List<String> _kOffsetNoteVerbs = <String>[
  '还债-',
  '收债-',
  '债务消减-',
  '坏账计提-',
];

/// 删除借还冲销流水（还债/收债/债务消减/坏账计提）时，反向恢复被它
/// 冲掉的债务并重建涉及账户的余额不变量。在 [TransactionRepository.remove]
/// 的事务内调用（与报销收入删除的反向抵扣同模式）。
///
/// - 台账优先：按 `lend_flow_offsets` 逐条恢复各借还记录的 repaidMinor
///   （支持一笔流水跨账户冲销多笔记录的精确恢复），随后清除该流水台账；
/// - 历史无台账兜底：备注以四动词开头且 relatedId 指向未删记录时，
///   恢复额 = min(流水金额, 记录已还额)（保守口径）；
/// - 本金流水（借入/借出）不触发恢复：删除本金流水只撤资金侧，
///   债务记录保留（余额不变量以记录为准，不受影响）。
Future<void> restoreLendOffsetOnFlowRemoved(
  AppDatabase db,
  Transaction txn,
) async {
  if (txn.sourceModule != SourceModule.lend) return;
  final String? rid = txn.relatedId;
  if (rid == null || rid.isEmpty) return;

  // 1) 台账优先：这笔流水冲销了哪些记录、各多少。
  final List<QueryRow> rows = await db.customSelect(
    'SELECT lend_record_id, amount_minor FROM lend_flow_offsets '
    'WHERE txn_id = ?',
    variables: <Variable<Object>>[Variable<String>(txn.id)],
  ).get();
  final List<({String id, int amount})> hits = <({String id, int amount})>[
    for (final QueryRow row in rows)
      (
        id: row.read<String>('lend_record_id'),
        amount: row.read<int>('amount_minor'),
      ),
  ];

  final Set<String> affectedAccounts = <String>{};
  if (hits.isNotEmpty) {
    for (final ({String id, int amount}) h in hits) {
      final LendRecord? record = await (db.select(db.lendRecords)
            ..where((LendRecords t) => t.id.equals(h.id) &
                t.deleted.equals(false)))
          .getSingleOrNull();
      if (record == null) continue;
      await revertLendRepaid(db, record, h.amount);
      if (record.accountId != null && record.accountId!.isNotEmpty) {
        affectedAccounts.add(record.accountId!);
      }
    }
    await deleteLendOffsets(db, txn.id);
  } else {
    // 2) 历史无台账兜底：备注动词判定为冲销流水才恢复（本金流水跳过）。
    final String note = txn.note ?? '';
    final bool isOffsetFlow =
        _kOffsetNoteVerbs.any((String v) => note.startsWith(v));
    if (!isOffsetFlow) return;
    final LendRecord? record = await (db.select(db.lendRecords)
          ..where((LendRecords t) =>
              t.id.equals(rid) & t.deleted.equals(false)))
        .getSingleOrNull();
    if (record == null || record.repaidMinor <= 0) return;
    final int amount = txn.amountMinor < record.repaidMinor
        ? txn.amountMinor
        : record.repaidMinor;
    await revertLendRepaid(db, record, amount);
    if (record.accountId != null && record.accountId!.isNotEmpty) {
      affectedAccounts.add(record.accountId!);
    }
  }

  // 3) 重建涉及借还账户的余额不变量。流水自身的挂账账户也一并纳入：
  //    还债流水无资产账户时挂在指定借还账户上，现金回滚
  //    （_revertBalanceDelta）对其是错向增量，靠对账覆盖修复；
  //    非借还类型账户（现金等）会被 reconcile 自动跳过。
  if (txn.accountId != null && txn.accountId!.isNotEmpty) {
    affectedAccounts.add(txn.accountId!);
  }
  for (final String acc in affectedAccounts) {
    await reconcileDesignatedLendBalance(db, acc);
  }
}
