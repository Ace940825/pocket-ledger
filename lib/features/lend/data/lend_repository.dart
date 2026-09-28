import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../database/sync_enqueue.dart';
import '../../../domain/enums.dart';
import '../../categories/data/category_repository.dart';
import '../../ledger/data/transaction_repository.dart';

/// 借还仓储。借出 / 借入与还款进度跟踪，复用统一同步入队。
class LendRepository {
  const LendRepository(this._db, this._txnRepo);

  final AppDatabase _db;
  final TransactionRepository _txnRepo;

  /// 系统类目（借入 / 借出 / 还债 / 收债 / 坏账计提 / 债务消减）的
  /// 查找或创建，落账时给借还流水挂分类用。
  CategoryRepository get _catRepo => CategoryRepository(_db);

  Stream<List<LendRecord>> watch(String bookId) {
    return (_db.select(_db.lendRecords)
          ..where(
            (LendRecords t) =>
                t.bookId.equals(bookId) & t.deleted.equals(false),
          )
          ..orderBy([(LendRecords t) => OrderingTerm.desc(t.occurredAt)]))
        .watch();
  }

  Future<String> add({
    required String bookId,
    required LendDirection direction,
    required LendStatus status,
    required String counterparty,
    required int amountMinor,
    int repaidMinor = 0,
    required int occurredAt,
    int? dueAt,
    String? note,
    String? accountId,
    String? toAccountId,
    int feeMinor = 0,
    int discountMinor = 0,
  }) async {
    if (counterparty.trim().isEmpty) {
      throw const ValidationFailure('对方不能为空');
    }
    if (amountMinor <= 0) throw const ValidationFailure('金额必须大于 0');

    final String id = const Uuid().v7();
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    // 未指定借入/借出账户时按对方名称自动归户（见 _resolveDesignatedAccount）。
    final String? designated =
        await _resolveDesignatedAccount(direction, accountId, counterparty);

    return _db.transaction<String>(() async {
      await _db.into(_db.lendRecords).insert(
            LendRecordsCompanion(
              id: Value<String>(id),
              bookId: Value<String>(bookId),
              direction: Value<LendDirection>(direction),
              status: Value<LendStatus>(status),
              counterparty: Value<String>(counterparty.trim()),
              amountMinor: Value<int>(amountMinor),
              repaidMinor: Value<int>(repaidMinor),
              occurredAt: Value<int>(occurredAt),
              dueAt: Value<int?>(dueAt),
              note: Value<String?>(note),
              accountId: Value<String?>(designated),
              toAccountId: Value<String?>(toAccountId),
              feeMinor: Value<int>(feeMinor),
              discountMinor: Value<int>(discountMinor),
              updatedAt: Value<int>(now),
              dirty: const Value<bool>(true),
            ),
          );
      await enqueueSyncOp(
        _db,
        table: 'lend_records',
        recordId: id,
        opType: SyncOpType.insert,
        updatedAt: now,
        payload: <String, Object?>{
          'direction': direction.index,
          'status': status.index,
          'counterparty': counterparty.trim(),
          'amountMinor': amountMinor,
          'repaidMinor': repaidMinor,
          'occurredAt': occurredAt,
          'dueAt': dueAt,
          'note': note,
          'accountId': designated,
          'toAccountId': toAccountId,
          'feeMinor': feeMinor,
          'discountMinor': discountMinor,
        },
      );
      // 本金落流水（报销同款「指定 / 非指定」口径）：挂账账户 =
      // 资产账户优先（真实资金进出，余额增量联动）；未选资产账户时挂
      // 指定的借入/借出账户（应收 / 应付，余额由对账保持不变量）；
      // 两者皆无（纯文字对方的非指定债务跟踪）不落流水。
      final String? flowAccount = _flowAccountOf(toAccountId, designated);
      if (flowAccount != null) {
        await _createFlowTxn(
          bookId: bookId,
          lendId: id,
          direction: direction,
          counterparty: counterparty.trim(),
          amountMinor: amountMinor,
          accountId: flowAccount,
          occurredAt: occurredAt,
          note: note,
        );
      }
      await _reconcileDesignatedBalance(designated);
      return id;
    });
  }

  Future<void> update({
    required String id,
    required LendDirection direction,
    required LendStatus status,
    required String counterparty,
    required int amountMinor,
    int repaidMinor = 0,
    required int occurredAt,
    int? dueAt,
    String? note,
    String? accountId,
    String? toAccountId,
    int feeMinor = 0,
    int discountMinor = 0,
  }) async {
    if (counterparty.trim().isEmpty) {
      throw const ValidationFailure('对方不能为空');
    }
    if (amountMinor <= 0) throw const ValidationFailure('金额必须大于 0');

    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    // 写入前先取旧记录：旧指定账户要在写入后参与对账（改挂账户时旧
    // 账户余额才能退回；此前在写入后才读，读到的是新值，改挂账户时
    // 旧账户不会重算——一并修复）。
    final LendRecord? before = await getById(id);
    // 未指定借入/借出账户时按对方名称自动归户（新增同款口径）。
    final String? designated =
        await _resolveDesignatedAccount(direction, accountId, counterparty);
    return _db.transaction<void>(() async {
      await (_db.update(_db.lendRecords)
            ..where((LendRecords t) => t.id.equals(id)))
          .write(
        LendRecordsCompanion(
          direction: Value<LendDirection>(direction),
          status: Value<LendStatus>(status),
          counterparty: Value<String>(counterparty.trim()),
          amountMinor: Value<int>(amountMinor),
          repaidMinor: Value<int>(repaidMinor),
          occurredAt: Value<int>(occurredAt),
          dueAt: Value<int?>(dueAt),
          note: Value<String?>(note),
          accountId: Value<String?>(designated),
          toAccountId: Value<String?>(toAccountId),
          feeMinor: Value<int>(feeMinor),
          discountMinor: Value<int>(discountMinor),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );
      await enqueueSyncOp(
        _db,
        table: 'lend_records',
        recordId: id,
        opType: SyncOpType.update,
        updatedAt: now,
        payload: <String, Object?>{
          'direction': direction.index,
          'status': status.index,
          'counterparty': counterparty.trim(),
          'amountMinor': amountMinor,
          'repaidMinor': repaidMinor,
          'occurredAt': occurredAt,
          'dueAt': dueAt,
          'note': note,
          'accountId': designated,
          'toAccountId': toAccountId,
          'feeMinor': feeMinor,
          'discountMinor': discountMinor,
        },
      );
      // 流水联动：本金流水与借还记录保持同步——
      // 挂账账户 = 资产账户优先，未选资产账户时挂指定借入/借出账户；
      // 编辑改了金额 / 账户 / 日期 / 备注 / 方向 → 更新流水；两个账户
      // 都清空 → 撤掉流水；缺流水且有可挂账户 → 补建。
      final LendRecord? current = await getById(id);
      final String? oldDesignated = before?.accountId;
      final String? flowAccount = _flowAccountOf(toAccountId, designated);
      final Transaction? flow = await _findFlowTxn(id);
      if (flow != null && flowAccount == null) {
        await _txnRepo.remove(flow.id);
      } else if (flow != null) {
        await _txnRepo.updateTransaction(
          original: flow,
          type: direction == LendDirection.borrowIn
              ? TxnType.income
              : TxnType.expense,
          amountMinor: amountMinor,
          accountId: flowAccount,
          note: _flowNote(direction, counterparty.trim(), note),
          occurredAt: occurredAt,
        );
      } else if (flowAccount != null && current != null) {
        await _createFlowTxn(
          bookId: current.bookId,
          lendId: id,
          direction: direction,
          counterparty: counterparty.trim(),
          amountMinor: amountMinor,
          accountId: flowAccount,
          occurredAt: occurredAt,
          note: note,
        );
      }
      await _reconcileDesignatedBalance(designated);
      await _reconcileDesignatedBalance(oldDesignated);
    });
  }

  /// 按 ID 取单条借还记录（编辑入口用）。
  Future<LendRecord?> getById(String id) async {
    return (_db.select(_db.lendRecords)
          ..where((LendRecords t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// 本金流水的挂账账户：资产账户优先；未选资产账户时挂指定的
  /// 借入/借出账户；两者皆无返回 null（纯债务跟踪，不落流水）。
  String? _flowAccountOf(String? assetAccount, String? designatedAccount) {
    if (assetAccount != null && assetAccount.isNotEmpty) return assetAccount;
    if (designatedAccount != null && designatedAccount.isNotEmpty) {
      return designatedAccount;
    }
    return null;
  }

  /// 按对方名称自动归户：未指定借入/借出账户时，若对方名称与同方向
  /// 类型账户名一致（如借入对方「小明」、存在借入(borrow)类型账户
  /// 「小明」），自动指定该账户——借还账户本就是「对方」的虚拟化
  /// （记一笔同款提示文案），名称一致视为同一对象，账单落入该账户。
  /// 已指定 / 对方为空 / 无同名账户时原样返回。
  Future<String?> _resolveDesignatedAccount(
    LendDirection direction,
    String? accountId,
    String counterparty,
  ) async {
    if (accountId != null && accountId.isNotEmpty) return accountId;
    final String name = counterparty.trim();
    if (name.isEmpty) return null;
    final AccountType type = direction == LendDirection.borrowIn
        ? AccountType.borrow
        : AccountType.lend;
    final Account? acc = await (_db.select(_db.accounts)
          ..where((Accounts t) =>
              t.name.equals(name) &
              t.type.equals(type.index) &
              t.deleted.equals(false))
          ..limit(1))
        .getSingleOrNull();
    return acc?.id;
  }

  /// 指定借入/借出账户余额对账（报销账户同款不变量，幂等）：
  /// 余额 = 名下未结清借还记录合计（本金 − 优惠 − 已还）。
  ///
  /// 仅对 [AccountType.lend] / [AccountType.borrow] 类型账户生效——
  /// 其他应收 / 应付类型（如报销账户）的余额归各自模块管辖；
  /// 流水挂在这些账户上的增量是错向的（借出记支出会做减法），
  /// 因此每次借还变动后立即重算覆盖，无偏差不写库（避免脏同步）。
  Future<void> _reconcileDesignatedBalance(String? accountId) async {
    if (accountId == null || accountId.isEmpty) return;
    final Account? acc = await (_db.select(_db.accounts)
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
    final List<LendRecord> records = await (_db.select(_db.lendRecords)
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
    await (_db.update(_db.accounts)..where((Accounts t) => t.id.equals(acc.id)))
        .write(
      AccountsCompanion(
        balanceMinor: Value<int>(want),
        updatedAt: Value<int>(DateTime.now().toUtc().millisecondsSinceEpoch),
        dirty: const Value<bool>(true),
      ),
    );
  }

  /// 借还本金流水的备注（与还债/收债流水同款式：'借入-小明'）。
  String _flowNote(LendDirection direction, String counterparty, String? note) {
    final String verb = direction == LendDirection.borrowIn ? '借入' : '借出';
    final String? userNote = note?.trim();
    return userNote == null || userNote.isEmpty
        ? '$verb-$counterparty'
        : '$verb-$counterparty\n$userNote';
  }

  /// 借还流水的固定分类（无则自动创建）——「借入记借入、还债记还债、
  /// 借出记借出」：按操作类型落系统类目，分类类型与流水收支方向一致。
  ///
  /// - 本金：借入 → 「借入」(income) / 借出 → 「借出」(expense)；
  /// - 还款：还债 → 「还债」(expense) / 收债 → 「收债」(income)；
  /// - 冲减备忘：债务消减 / 坏账计提 → 均为「支出」(expense)。
  Future<String> _flowCategoryId({
    required String bookId,
    required LendDirection direction,
    required _LendFlowKind kind,
  }) {
    final bool borrowIn = direction == LendDirection.borrowIn;
    final String name;
    final CategoryType type;
    switch (kind) {
      case _LendFlowKind.principal:
        name = borrowIn ? '借入' : '借出';
        type = borrowIn ? CategoryType.income : CategoryType.expense;
      case _LendFlowKind.repay:
        name = borrowIn ? '还债' : '收债';
        type = borrowIn ? CategoryType.expense : CategoryType.income;
      case _LendFlowKind.reduction:
        name = borrowIn ? '债务消减' : '坏账计提';
        // 债务消减 / 坏账计提均按支出类型展示（无真实资金流动，仅记账备忘，
        // 不计入收支统计与预算；统一支出口径便于用户识别）。
        type = CategoryType.expense;
    }
    return _catRepo.ensureNamed(bookId: bookId, name: name, type: type);
  }

  /// 借还本金流水反查：relatedId 指向借还记录、来源为借还模块的流水。
  ///
  /// [includeDeleted] 为真时连同已软删的行一起查（启动补建用：
  /// 用户主动删过流水的记录不再重建，尊重删除意图）。
  Future<Transaction?> _findFlowTxn(
    String lendId, {
    bool includeDeleted = false,
  }) {
    return (_db.select(_db.transactions)
          ..where((Transactions t) =>
              t.relatedId.equals(lendId) &
              t.sourceModule.equals(SourceModule.lend.index) &
              (includeDeleted ? const Constant(true) : t.deleted.equals(false)))
          ..limit(1))
        .getSingleOrNull();
  }

  /// 本金落流水：借入 = 收入（资产账户余额增加）、借出 = 支出（减少）。
  /// 余额增量由 [TransactionRepository.add] 内部联动；excludeFromStats /
  /// excludeFromBudget 置真——借款不是收支，不污染收支统计与预算
  /// （还债 / 收债流水同口径，见 [repay]）。
  Future<void> _createFlowTxn({
    required String bookId,
    required String lendId,
    required LendDirection direction,
    required String counterparty,
    required int amountMinor,
    required String accountId,
    required int occurredAt,
    String? note,
  }) async {
    await _txnRepo.add(
      bookId: bookId,
      type: direction == LendDirection.borrowIn
          ? TxnType.income
          : TxnType.expense,
      amountMinor: amountMinor,
      accountId: accountId,
      occurredAt: occurredAt,
      categoryId: await _flowCategoryId(
        bookId: bookId,
        direction: direction,
        kind: _LendFlowKind.principal,
      ),
      note: _flowNote(direction, counterparty, note),
      sourceModule: SourceModule.lend,
      relatedId: lendId,
      excludeFromStats: true,
      excludeFromBudget: true,
    );
  }

  /// 存量借还记录补落流水（启动对账，幂等）：
  /// 有可挂账户（资产账户优先，其次指定借入/借出账户）但没有任何本金
  /// 流水（含已删）的借还记录，补建一条。用户主动删过流水的记录不再
  /// 重建。返回补建笔数。
  Future<int> backfillFlowTransactions() async {
    final List<LendRecord> records = await (_db.select(_db.lendRecords)
          ..where((LendRecords t) => t.deleted.equals(false)))
        .get();
    int created = 0;
    for (final LendRecord r in records) {
      final String? flowAccount =
          _flowAccountOf(r.toAccountId, r.accountId);
      if (flowAccount == null) continue;
      final Transaction? existing =
          await _findFlowTxn(r.id, includeDeleted: true);
      if (existing != null) continue;
      await _createFlowTxn(
        bookId: r.bookId,
        lendId: r.id,
        direction: r.direction,
        counterparty: r.counterparty,
        amountMinor: r.amountMinor,
        accountId: flowAccount,
        occurredAt: r.occurredAt,
        note: r.note,
      );
      created++;
    }
    return created;
  }

  /// 核心冲销逻辑（**不开启事务**，必须由调用方包在事务里）：
  /// 把 [amountMinor] 按发生时间从早到晚，分摊到 [direction]+[counterparty] 名下
  /// 所有「进行中(ongoing)」债务记录的剩余本金上，更新每条的
  /// [LendRecords.repaidMinor]，并在足量时把状态置为「已结清(settled)」。
  ///
  /// **不创建新记录**，仅冲减已有债务；每条被改动的记录都逐条入队同步。
  /// 找不到未结清债务、或金额超过剩余债务时会抛 [ValidationFailure]，从而让
  /// 外层事务整体回滚。
  ///
  /// [notFoundHint] / [overHint] 用于区分「减免」与「还款」两套报错文案。
  /// 返回本次被冲销（已改动）的借还记录 ID 列表，供上层（如 [repay]）
  /// 把流水关联到具体借还记录、让详情页能显示「借还账户」行。
  Future<List<_OffsetHit>> _offsetDebts({
    required String bookId,
    required LendDirection direction,
    required String counterparty,
    required int amountMinor,
    required String notFoundHint,
    required String overHint,
  }) async {
    if (counterparty.trim().isEmpty) {
      throw const ValidationFailure('对方不能为空');
    }
    if (amountMinor <= 0) throw const ValidationFailure('金额必须大于 0');

    final String trimmed = counterparty.trim();
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final List<_OffsetHit> affected = <_OffsetHit>[];

    final List<LendRecord> records = await (_db.select(_db.lendRecords)
          ..where(
            (LendRecords t) =>
                t.bookId.equals(bookId) &
                t.direction.equals(direction.index) &
                t.counterparty.equals(trimmed) &
                t.deleted.equals(false) &
                t.status.equals(LendStatus.ongoing.index),
          )
          ..orderBy([(LendRecords t) => OrderingTerm.asc(t.occurredAt)]))
        .get();

    if (records.isEmpty) {
      throw ValidationFailure(notFoundHint);
    }

    int remaining = amountMinor;
    for (final LendRecord r in records) {
      if (remaining <= 0) break;
      // 剩余债务 = 本金 − 优惠（减免）− 已还；优惠在借入/借出时已把
      // 债务净额减少，冲销与结清判断都必须把它算进去。
      final int left = r.amountMinor - r.discountMinor - r.repaidMinor;
      if (left <= 0) continue;
      final int apply = remaining < left ? remaining : left;
      final int newRepaid = r.repaidMinor + apply;
      final LendStatus newStatus =
          newRepaid + r.discountMinor >= r.amountMinor
              ? LendStatus.settled
              : r.status;

      await (_db.update(_db.lendRecords)
            ..where((LendRecords t) => t.id.equals(r.id)))
          .write(
        LendRecordsCompanion(
          repaidMinor: Value<int>(newRepaid),
          status: Value<LendStatus>(newStatus),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );
      await enqueueSyncOp(
        _db,
        table: 'lend_records',
        recordId: r.id,
        opType: SyncOpType.update,
        updatedAt: now,
        payload: <String, Object?>{
          'direction': r.direction.index,
          'status': newStatus.index,
          'counterparty': trimmed,
          'amountMinor': r.amountMinor,
          'repaidMinor': newRepaid,
          'occurredAt': r.occurredAt,
          'dueAt': r.dueAt,
          'note': r.note,
          'accountId': r.accountId,
          'toAccountId': r.toAccountId,
          'feeMinor': r.feeMinor,
          'discountMinor': r.discountMinor,
        },
      );
      affected.add(_OffsetHit(id: r.id, amount: apply));
      remaining -= apply;
    }

    if (remaining > 0) {
      throw ValidationFailure(overHint);
    }

    // 冲销改变了名下记录的已还 / 状态，受影响指定账户的余额重算
    //（写在同一事务里，失败整体回滚）。
    final Set<String> designatedAccounts = <String>{
      for (final LendRecord r in records)
        if (r.accountId != null && r.accountId!.isNotEmpty) r.accountId!,
    };
    for (final String accId in designatedAccounts) {
      await _reconcileDesignatedBalance(accId);
    }
    return affected;
  }

  /// 债务削减 / 减免：按 [counterparty] 找到该方向下所有未结清记录并冲减，
  /// 不影响资产账户余额（借出方向为坏账计提、借入方向为债务削减，均无真实
  /// 资金流动）。同时生成一笔「记账备忘」流水（关联借还记录、不计入收支 /
  /// 预算），使详情页能显示「借还账户」行——仅在被冲销记录已指定借还账户
  /// 时生成（纯文字债务无账户可挂，跳过；与还款 / 收债同口径）。
  Future<void> debtReduction({
    required String bookId,
    required LendDirection direction,
    required String counterparty,
    required int amountMinor,
    required int occurredAt,
    String? note,
  }) {
    final String dirLabel = direction == LendDirection.borrowIn ? '借入' : '借出';
    final String verb = direction == LendDirection.borrowIn
        ? '债务消减'
        : '坏账计提';
    // 债务消减 / 坏账计提均无真实资金流动，仅作记账备忘展示；按用户口径
    // 统一为支出类型（影响列表箭头 / 配色），不计入收支统计与预算。
    final TxnType txnType = TxnType.expense;
    return _db.transaction<void>(() async {
      final List<_OffsetHit> affected = await _offsetDebts(
        bookId: bookId,
        direction: direction,
        counterparty: counterparty,
        amountMinor: amountMinor,
        notFoundHint: '未找到$dirLabel给「${counterparty.trim()}」的未结清记录',
        overHint: '减免金额超过剩余债务',
      );
      // 生成记账备忘流水：关联借还记录、不计入收支 / 余额，详情页据此显示
      // 「借还账户」行。仅当被冲销记录已指定借还账户时生成（纯文字债务跳过）。
      if (affected.isNotEmpty) {
        final LendRecord? record = await getById(affected.first.id);
        final String? designated = record?.accountId;
        if (designated != null && designated.isNotEmpty) {
          final String trimmed = counterparty.trim();
          final String? userNote = note?.trim();
          final String txnNote = userNote == null || userNote.isEmpty
              ? '$verb-$trimmed'
              : '$verb-$trimmed\n$userNote';
          final String flowId = await _txnRepo.add(
            bookId: bookId,
            type: txnType,
            amountMinor: amountMinor,
            accountId: designated,
            occurredAt: occurredAt,
            categoryId: await _flowCategoryId(
              bookId: bookId,
              direction: direction,
              kind: _LendFlowKind.reduction,
            ),
            note: txnNote,
            sourceModule: SourceModule.lend,
            relatedId: affected.first.id,
            excludeFromStats: true,
            excludeFromBudget: true,
          );
          // 记冲销台账（同还债 / 收债），供跨账户删除时反向恢复其余账户。
          await _writeLendOffsets(flowId, affected);
        }
      }
    });
  }

  /// 还债 / 收债：按 [counterparty] 冲销该方向下所有未结清债务，
  /// 真正减少剩余应收 / 应付（**不新增借还记录**），状态足额时转为「已结清」。
  ///
  /// 当 [accountId] 给定时，会**同时写一条真实的资金流水**，让钱包余额随之变化
  /// （与「借还冲销」处于同一个 DB 事务，保证原子性）：
  /// - 借入方向（还债）：现金从账户流出 → 支出(expense)，余额减少；
  /// - 借出方向（收债）：现金流入账户 → 收入(income)，余额增加。
  ///
  /// [accountId] 为 null / 空时退化为「只冲销债务、不动余额」的旧行为。
  Future<void> repay({
    required String bookId,
    required LendDirection direction,
    required String counterparty,
    required int amountMinor,
    required int occurredAt,
    String? note,
    String? accountId,
  }) {
    final String verb = direction == LendDirection.borrowIn ? '还债' : '收债';
    final TxnType txnType =
        direction == LendDirection.borrowIn ? TxnType.expense : TxnType.income;

    return _db.transaction<void>(() async {
      final List<_OffsetHit> affected = await _offsetDebts(
        bookId: bookId,
        direction: direction,
        counterparty: counterparty,
        amountMinor: amountMinor,
        notFoundHint: '未找到可$verb的「${counterparty.trim()}」未结清债务',
        overHint: '$verb金额超过剩余未结清债务',
      );

      if (accountId != null && accountId.isNotEmpty) {
        final String trimmed = counterparty.trim();
        final String? userNote = note?.trim();
        final String txnNote = userNote == null || userNote.isEmpty
            ? '$verb-$trimmed'
            : '$verb-$trimmed\n$userNote';
        final String flowId = await _txnRepo.add(
          bookId: bookId,
          type: txnType,
          amountMinor: amountMinor,
          accountId: accountId,
          occurredAt: occurredAt,
          categoryId: await _flowCategoryId(
            bookId: bookId,
            direction: direction,
            kind: _LendFlowKind.repay,
          ),
          note: txnNote,
          sourceModule: SourceModule.lend,
          // 关联被冲销的借还记录（取首条被冲销记录）：详情页据此解析出
          // 「借还账户」行（与借入 / 借出本金流水同口径）。多记录冲销时
          // 取最早一条作为代表，足够定位对方借还账户。
          relatedId: affected.isNotEmpty ? affected.first.id : null,
          // 还债 / 收债同样不是收支：与借入 / 借出本金流水同口径，
          // 排除收支统计与预算（否则借款周期会在统计里虚增一笔）。
          excludeFromStats: true,
          excludeFromBudget: true,
        );
        // 记录冲销台账：本笔还债 / 收债分别冲销了哪些借还记录、各多少，
        // 供删除借还账户时跨账户反向恢复其余账户（见 purgeByDesignatedAccount）。
        if (affected.isNotEmpty) {
          await _writeLendOffsets(flowId, affected);
        }
      }
    });
  }

  Future<void> remove(String id) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.transaction<void>(() async {
      final LendRecord? current = await getById(id);
      await (_db.update(_db.lendRecords)
            ..where((LendRecords t) => t.id.equals(id)))
          .write(
        const LendRecordsCompanion(
          deleted: Value<bool>(true),
          dirty: Value<bool>(true),
        ),
      );
      await enqueueSyncOp(
        _db,
        table: 'lend_records',
        recordId: id,
        opType: SyncOpType.delete,
        updatedAt: now,
      );
      // 级联撤掉本金流水（余额回滚由 TransactionRepository.remove 内部完成）。
      final Transaction? flow = await _findFlowTxn(id);
      if (flow != null) {
        await _txnRepo.remove(flow.id);
      }
      // 清理指向本记录的冲销台账（其余账户的反向恢复不再引用它）。
      await _deleteLendOffsetsForRecord(id);
      // 删除后该账户名下未结清合计变化，重算指定账户余额。
      await _reconcileDesignatedBalance(current?.accountId);
    });
  }

  /// 清空指定借入/借出账户名下的全部借还记录及其关联流水（删除账户时级联）。
  ///
  /// 借还账户是「对方」的虚拟化：账户删除意味着这本债务账随之销户——
  /// 名下所有借还记录（含已结清）软删，关联流水（本金 + 关联借还记录
  /// 的还债/收债/债务消减/坏账计提备忘）一并撤销，真实资金账户（现金）
  /// 的余额增量由 [TransactionRepository.remove] 内部回滚。
  ///
  /// **跨账户冲销处理**：一笔还债/收债/备忘可能同时冲销挂在多个借还账户
  /// 下的记录（同对方、手动指定不同账户）。该流水被本账户删除「触及」时，
  /// 撤销它不仅要回滚现金，还要把**其余账户**下被它冲销记录的 [repaidMinor]
  /// 反向恢复（这些记录不删、债务重新生效），最后按记录重建对应借还账户的
  /// 余额不变量（[ _reconcileDesignatedBalance]）。冲销明细存于
  /// `lend_flow_offsets` 台账（[ _writeLendOffsets]）；历史无台账的流水按
  /// 「relatedId 是否指向本账户记录」兜底——指向则视为单账户撤销流水，否则
  /// 为跨账户历史数据保守保留流水，避免误伤其余账户（已知边界，新数据有台账）。
  ///
  /// 返回清除的记录数；幂等，无记录时为空操作。
  Future<int> purgeByDesignatedAccount(String accountId) async {
    if (accountId.isEmpty) return 0;
    final List<LendRecord> records = await (_db.select(_db.lendRecords)
          ..where((LendRecords t) =>
              t.accountId.equals(accountId) & t.deleted.equals(false)))
        .get();
    if (records.isEmpty) return 0;
    final Set<String> recordIds = <String>{for (final LendRecord r in records) r.id};
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final Set<String> keptAccounts = <String>{};

    await _db.transaction<void>(() async {
      // 1) 取本账户记录在冲销台账中涉及的流水（跨账户冲销会引用它们）
      final Map<String, List<_OffsetHit>> offsetByTxn =
          <String, List<_OffsetHit>>{};
      if (recordIds.isNotEmpty) {
        // 本账户记录 ID 均为系统生成的 UUID，无引号/SQL 元字符，安全插值。
        final String inClause =
            recordIds.map((String id) => "'$id'").join(', ');
        final List<QueryRow> rows = await _db.customSelect(
          'SELECT txn_id, lend_record_id, amount_minor '
          'FROM lend_flow_offsets '
          'WHERE lend_record_id IN ($inClause)',
        ).get();
        for (final QueryRow row in rows) {
          final String txnId = row.read<String>('txn_id');
          final String recId = row.read<String>('lend_record_id');
          final int amt = row.read<int>('amount_minor');
          offsetByTxn
              .putIfAbsent(txnId, () => <_OffsetHit>[])
              .add(_OffsetHit(id: recId, amount: amt));
        }
      }

      // 2) 遍历本账本全部借还模块流水，处理「触及」本账户的
      final List<Transaction> flows = await (_db.select(_db.transactions)
            ..where((Transactions t) =>
                t.sourceModule.equals(SourceModule.lend.index) &
                t.deleted.equals(false)))
          .get();
      for (final Transaction flow in flows) {
        final bool touches =
            recordIds.contains(flow.relatedId) || offsetByTxn.containsKey(flow.id);
        if (!touches) continue;

        final List<_OffsetHit> hits =
            offsetByTxn[flow.id] ?? const <_OffsetHit>[];
        if (hits.isNotEmpty) {
          // 有台账：逐条冲销明细——本账户即将删除的记录忽略；
          // 其余（保留）账户下的记录反向恢复 repaidMinor（债务重新生效）。
          for (final _OffsetHit h in hits) {
            if (recordIds.contains(h.id)) continue;
            final LendRecord? kept = await getById(h.id);
            if (kept == null) continue;
            await _revertRepaidOnRecord(kept, h.amount);
            if (kept.accountId != null && kept.accountId!.isNotEmpty) {
              keptAccounts.add(kept.accountId!);
            }
          }
          await _deleteLendOffsets(flow.id);
          // 现金整体回滚（与重新生效的债务口径一致）
          await _txnRepo.remove(flow.id);
        } else {
          // 历史无台账：relatedId 指向本账户记录即视为单账户，撤销流水；
          // 否则为跨账户历史数据，保守保留流水（不误伤其余账户）。
          if (recordIds.contains(flow.relatedId)) {
            await _txnRepo.remove(flow.id);
          }
        }
      }

      // 3) 软删本账户全部借还记录
      for (final LendRecord r in records) {
        await (_db.update(_db.lendRecords)
              ..where((LendRecords t) => t.id.equals(r.id)))
            .write(
          const LendRecordsCompanion(
            deleted: Value<bool>(true),
            dirty: Value<bool>(true),
          ),
        );
        await enqueueSyncOp(
          _db,
          table: 'lend_records',
          recordId: r.id,
          opType: SyncOpType.delete,
          updatedAt: now,
        );
      }

      // 4) 重建被跨账户冲销波及的借还账户余额不变量
      for (final String acc in keptAccounts) {
        await _reconcileDesignatedBalance(acc);
      }
    });
    return records.length;
  }

  /// 反向恢复某借还记录的已还金额（冲销流水被撤销时调用）。
  /// 将 [amount] 从 [record.repaidMinor] 扣减（下限 0）；若因此低于本金，
  /// 状态从「已结清」回退为「进行中」，并逐条入队同步。
  Future<void> _revertRepaidOnRecord(LendRecord record, int amount) async {
    final int newRepaid =
        (record.repaidMinor - amount) < 0 ? 0 : record.repaidMinor - amount;
    final LendStatus newStatus =
        newRepaid + record.discountMinor >= record.amountMinor
            ? LendStatus.settled
            : LendStatus.ongoing;
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await (_db.update(_db.lendRecords)
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
      _db,
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

  /// 写入一笔借还流水的冲销台账（[ _OffsetHit] 列表）：记录它分别冲销了
  /// 哪些借还记录、各多少。供删除借还账户时跨账户反向恢复其余账户。
  Future<void> _writeLendOffsets(String txnId, List<_OffsetHit> hits) async {
    for (final _OffsetHit h in hits) {
      await _db.customStatement(
        'INSERT INTO lend_flow_offsets (txn_id, lend_record_id, amount_minor) '
        'VALUES (?, ?, ?)',
        [txnId, h.id, h.amount],
      );
    }
  }

  /// 删除某笔流水的全部冲销台账。
  Future<void> _deleteLendOffsets(String txnId) async {
    await _db.customStatement(
      'DELETE FROM lend_flow_offsets WHERE txn_id = ?',
      [txnId],
    );
  }

  /// 删除指向某借还记录的冲销台账（该记录被单独删除时清理）。
  Future<void> _deleteLendOffsetsForRecord(String recordId) async {
    await _db.customStatement(
      'DELETE FROM lend_flow_offsets WHERE lend_record_id = ?',
      [recordId],
    );
  }
}

/// 借还流水的三类操作，决定固定分类（借入/借出、还债/收债、债务消减/坏账计提）。
enum _LendFlowKind { principal, repay, reduction }

/// 一笔借还流水冲销的某条借还记录及其金额（用于跨账户冲销反向恢复）。
class _OffsetHit {
  const _OffsetHit({required this.id, required this.amount});
  final String id;
  final int amount;
}
