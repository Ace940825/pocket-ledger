import '../../domain/enums.dart';
import '../app_database.dart';

/// 转账相对某个账户的方向。
enum TransferDirection {
  /// 本账户是转出方（`accountId == 本账户`）。
  outgoing,

  /// 本账户是转入方（`toAccountId == 本账户`）。
  incoming,
}

/// 判定一笔转账相对 [accountId] 的方向。
///
/// 数据模型：**一条腿**记录一笔转账，`accountId = 转出方`、`toAccountId = 转入方`
/// （见 `TransactionRepository.transfer`）。所以：
/// - `accountId == accountId` → 本账户是转出方 → [TransferDirection.outgoing]
/// - 否则（本账户命中 `toAccountId`）→ 转入方 → [TransferDirection.incoming]
///
/// 非转账流水、或缺少对手方的转账返回 `null`。
///
/// ⚠️ 历史遗留的「成对两条腿」数据在去重后会留下 `accountId == 本账户` 的那条，
/// 因此这类旧数据一律被判为 [TransferDirection.outgoing] —— 旧数据里方向本身
/// 已不可恢复（两条腿在字段上完全对称）。
TransferDirection? transferDirectionOf(
  Transaction transaction,
  String accountId,
) {
  if (transaction.type != TxnType.transfer) return null;
  if (transaction.toAccountId == null) return null;
  return transaction.accountId == accountId
      ? TransferDirection.outgoing
      : TransferDirection.incoming;
}

/// 转账在账户明细里去重（**只针对历史遗留的成对数据**）。
///
/// **背景**：早期 `TransactionRepository.transfer()` 会在一个事务里写**两条腿**
/// ——「转出腿」（`accountId = 转出方`）与「转入腿」（`accountId = 转入方`），
/// 两条共享同一个 `transferGroupId`。写入路径现已改为**只写一条腿**，新数据不会再重复。
///
/// **为什么还要保留这个函数**：`watchByAccount` 用 `accountId = A OR toAccountId = A`
/// 取数，旧的两条腿**都**命中 A 的条件（一条靠 `accountId`、一条靠 `toAccountId`），
/// 于是同一笔转账在 A 的明细里出现两次，月汇总的「其他」被重复累加（翻倍）。
/// 老库里已经存在这样的数据，必须在读路径兜住，否则升级后老用户看到的就是错的。
///
/// **规则**：每笔转账（按 `transferGroupId` 聚合）只保留一条腿，
/// 优先取 `accountId == accountId` 的那条。非转账流水（`transferGroupId == null`）
/// 原样保留。返回顺序与传入顺序一致。
///
/// 新数据每笔转账只有一个 `transferGroupId`，天然不会被合并，等于空操作。
List<Transaction> dedupeAccountTransfers(
  List<Transaction> transactions,
  String accountId,
) {
  final Map<String, Transaction> chosen = <String, Transaction>{};
  final List<Transaction> result = <Transaction>[];

  for (final Transaction t in transactions) {
    final String? groupId = t.transferGroupId;
    if (groupId == null) {
      result.add(t);
      continue;
    }

    final Transaction? existing = chosen[groupId];
    if (existing == null) {
      chosen[groupId] = t;
      result.add(t);
      continue;
    }

    // 同组已选过一条：若当前这条才是「属于本账户」的腿，则替换先到的那条，
    // 否则直接丢弃当前这条。
    final bool currentBelongs = t.accountId == accountId;
    final bool existingBelongs = existing.accountId == accountId;
    if (currentBelongs && !existingBelongs) {
      final int index = result.indexOf(existing);
      if (index >= 0) {
        result[index] = t;
      }
      chosen[groupId] = t;
    }
  }

  return result;
}
