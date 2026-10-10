import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../database/sync_enqueue.dart';
import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';
import '../../categories/data/category_repository.dart';
import '../../ledger/data/transaction_repository.dart';
import '../domain/bill_cycle.dart';
import '../domain/fee_utils.dart';
import '../domain/installment_dates.dart';
import '../domain/repeat_rule.dart';

/// 分期仓储。计划（[InstallmentPlans]）与每期明细（[InstallmentPeriods]）成对维护。
///
/// 关键设计：创建计划时**一次性生成全部期数明细**，而不是每月动态推算。
/// 理由有两点：一是用户经常需要修改某一期的金额（提前还款、减免手续费），
/// 有实体行才好改；二是明细落库后「下一期该还多少、逾期了几期」都是简单查询，
/// 不必在 UI 层重复做日期运算。
class InstallmentRepository {
  const InstallmentRepository(this._db, this._txnRepo);

  final AppDatabase _db;
  final TransactionRepository _txnRepo;

  Stream<List<InstallmentPlan>> watchPlans(String bookId) {
    return (_db.select(_db.installmentPlans)
          ..where(
            (InstallmentPlans t) =>
                t.bookId.equals(bookId) & t.deleted.equals(false),
          )
          ..orderBy(<OrderClauseGenerator<InstallmentPlans>>[
            (InstallmentPlans t) => OrderingTerm.asc(t.isFinished),
            (InstallmentPlans t) => OrderingTerm.asc(t.firstDueAt),
          ]))
        .watch();
  }

  Stream<List<InstallmentPeriod>> watchPeriods(String planId) {
    return (_db.select(_db.installmentPeriods)
          ..where(
            (InstallmentPeriods t) =>
                t.planId.equals(planId) & t.deleted.equals(false),
          )
          ..orderBy(<OrderClauseGenerator<InstallmentPeriods>>[
            (InstallmentPeriods t) => OrderingTerm.asc(t.periodIndex),
          ]))
        .watch();
  }

  /// 账本下全部分期计划的每期明细（列表页汇总「待入账」与逾期态用）。
  ///
  /// 用子查询圈定计划集合而非 Dart 层传 planId 名单：新建计划时随期数明细
  /// 一并落库，本流会自动带出新计划的期次，不需要额外重订阅逻辑。
  ///
  /// 注意子查询必须 [selectOnly] 只取 id 列：`IN (SELECT …)` 的子查询
  /// 只允许单列，整行 select 会在 SQLite 运行时报错（静态分析查不出来）。
  Stream<List<InstallmentPeriod>> watchBookPeriods(String bookId) {
    final JoinedSelectStatement plansOfBook =
        _db.selectOnly(_db.installmentPlans)
          ..addColumns(<Expression<Object>>[_db.installmentPlans.id])
          ..where(
            _db.installmentPlans.bookId.equals(bookId) &
                _db.installmentPlans.deleted.equals(false),
          );
    return (_db.select(_db.installmentPeriods)
          ..where(
            (InstallmentPeriods t) =>
                t.planId.isInQuery(plansOfBook) & t.deleted.equals(false),
          )
          ..orderBy(<OrderClauseGenerator<InstallmentPeriods>>[
            (InstallmentPeriods t) => OrderingTerm.asc(t.dueAt),
          ]))
        .watch();
  }

  /// 创建计划并生成每期明细。
  ///
  /// 均摊余数放在**最后一期**：例如 1000 元分 3 期，前两期各 333.33，
  /// 末期 333.34，保证各期之和严格等于总额，不会因四舍五入丢分。
  ///
  /// [feeByPeriodMinor] 为可选的每期手续费/利息（分），长度必须等于 [totalPeriods]。
  /// 传 null 时，手续费按 0 处理；用于支持「按期均摊 / 首期全部扣除 / 尾期全部扣除」
  /// 等利息扣除方式。
  ///
  /// [repeatRule] 为可选的重复周期规则；传 null 时按原默认「每月」生成每期明细。
  Future<String> addPlan({
    required String bookId,
    required String title,
    required int totalMinor,
    required int totalPeriods,
    List<int>? feeByPeriodMinor,
    InstallmentRepeatRule? repeatRule,
    required int firstDueAt,
    String? accountId,
    String? note,
  }) {
    if (title.trim().isEmpty) throw const ValidationFailure('分期名称不能为空');
    if (totalMinor <= 0) throw const ValidationFailure('总金额必须大于 0');
    if (totalPeriods <= 0 || totalPeriods > 120) {
      throw const ValidationFailure('期数需在 1 - 120 之间');
    }

    final String planId = const Uuid().v7();
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final DateTime firstDue =
        DateTime.fromMillisecondsSinceEpoch(firstDueAt, isUtc: true).toLocal();

    final int base = totalMinor ~/ totalPeriods;
    final int remainder = totalMinor - base * totalPeriods;
    final List<int> feeByPeriod =
        feeByPeriodMinor ?? List<int>.filled(totalPeriods, 0, growable: false);
    final int totalFee = feeByPeriod.fold<int>(0, (int sum, int v) => sum + v);
    final int feePerPeriodMinor =
        totalPeriods == 0 ? 0 : totalFee ~/ totalPeriods;

    final List<DateTime> dueDates = computeInstallmentDueDates(
      firstDue: firstDue,
      rule: repeatRule,
      totalPeriods: totalPeriods,
    );

    final String planId = await _db.transaction<String>(() async {
      await _db.into(_db.installmentPlans).insert(
            InstallmentPlansCompanion(
              id: Value<String>(planId),
              bookId: Value<String>(bookId),
              title: Value<String>(title.trim()),
              totalMinor: Value<int>(totalMinor),
              totalPeriods: Value<int>(totalPeriods),
              feePerPeriodMinor: Value<int>(feePerPeriodMinor),
              feeByPeriodMinor: Value<String>(jsonEncode(feeByPeriod)),
              repeatRule: Value<String?>(repeatRule?.toJsonString()),
              firstDueAt: Value<int>(firstDueAt),
              accountId: Value<String?>(accountId),
              note: Value<String?>(note),
              updatedAt: Value<int>(now),
              dirty: const Value<bool>(true),
            ),
          );

      for (int i = 0; i < totalPeriods; i++) {
        final String periodId = const Uuid().v7();
        final int amount = base + (i == totalPeriods - 1 ? remainder : 0);
        final int dueAt = dueDates[i].toUtc().millisecondsSinceEpoch;
        final int periodFee = feeByPeriod.length > i ? feeByPeriod[i] : 0;

        await _db.into(_db.installmentPeriods).insert(
              InstallmentPeriodsCompanion(
                id: Value<String>(periodId),
                planId: Value<String>(planId),
                periodIndex: Value<int>(i + 1),
                amountMinor: Value<int>(amount + periodFee),
                dueAt: Value<int>(dueAt),
                updatedAt: Value<int>(now),
                dirty: const Value<bool>(true),
              ),
            );
        await enqueueSyncOp(
          _db,
          table: 'installment_periods',
          recordId: periodId,
          opType: SyncOpType.insert,
          updatedAt: now,
          payload: <String, Object?>{
            'planId': planId,
            'periodIndex': i + 1,
            'amountMinor': amount + periodFee,
            'dueAt': dueAt,
          },
        );
      }

      await enqueueSyncOp(
        _db,
        table: 'installment_plans',
        recordId: planId,
        opType: SyncOpType.insert,
        updatedAt: now,
        payload: <String, Object?>{
          'title': title.trim(),
          'totalMinor': totalMinor,
          'totalPeriods': totalPeriods,
          'feePerPeriodMinor': feePerPeriodMinor,
          'feeByPeriodMinor': jsonEncode(feeByPeriod),
          'repeatRule': repeatRule?.toJsonString(),
          'firstDueAt': firstDueAt,
          'accountId': accountId,
          'note': note,
        },
      );
      return planId;
    });
    // 创建即补账：首期到期日早于当前时刻的计划（新建时把首期日期选在过去，
    // 或当月 1 日扣款今天已过），立即在负债付款账户生成当期订单流水，
    // 不等 bootstrap / 分期列表页的惰性补账——否则用户建完计划去账单页
    // 看不到当期流水，误以为要动「已还」才出账。幂等：未到期的期次不受影响。
    await postDuePeriods();
    return planId;
  }

  /// 标记某期已还 / 撤销已还（还款进度标记），并刷新计划的已还期数与完结标记。
  ///
  /// 与流水解耦（2026-10-09 口径）：到期自动入账（[postDuePeriods]）负责在
  /// 负债付款账户内生成订单流水；勾选已还只更新 [InstallmentPeriods.paidAt]，
  /// 不产生、也不删除任何流水。
  ///
  /// [auto] 标记本次调用是否来自「还款自动对账」（[reconcileInstallmentRepayments]）：
  /// - auto=true 且 paid=true：记入 [installment_auto_paid] 溯源表；
  /// - auto=true 且 paid=false：从溯源表删除（回退）；
  /// - auto=false（手动 UI / 完结）：从溯源表删除，转为「手动」口径，
  ///   后续 reconcile 不再自动管理该期次，避免误伤用户手动勾选。
  Future<void> togglePeriodPaid(
    String periodId, {
    required bool paid,
    bool auto = false,
  }) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;

    await _db.transaction<void>(() async {
      final InstallmentPeriod? period =
          await (_db.select(_db.installmentPeriods)
                ..where((InstallmentPeriods t) => t.id.equals(periodId)))
              .getSingleOrNull();
      if (period == null) throw const NotFoundFailure('分期明细不存在');

      await (_db.update(_db.installmentPeriods)
            ..where((InstallmentPeriods t) => t.id.equals(periodId)))
          .write(
        InstallmentPeriodsCompanion(
          paidAt: paid ? Value<int?>(now) : const Value<int?>(null),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );
      await enqueueSyncOp(
        _db,
        table: 'installment_periods',
        recordId: periodId,
        opType: SyncOpType.update,
        updatedAt: now,
        payload: <String, Object?>{'paidAt': paid ? now : null},
      );

      await _refreshPlanProgress(period.planId, now);
    });

    // 自动溯源（事务外，避免长事务；溯源失败不应回滚 paidAt 主流程）。
    if (auto) {
      if (paid) {
        await _markAutoPaid(periodId, now);
      } else {
        await _unmarkAutoPaid(periodId);
      }
    } else {
      // 手动动作：清掉自动溯源，转为手动口径（reconcile 不再管理）。
      await _unmarkAutoPaid(periodId);
    }
  }

  /// 到期自动入账（幂等，可安全重复调用）。
  ///
  /// 口径（2026-10-09 与用户确认）：[InstallmentPlans.accountId] 是**分期
  /// 付款账户，只能是负债账户**（信用卡/花呗/借呗等）。每个周期到期后，
  /// 自动在负债账户内生成一笔「分期订单 + 利息」支出流水（欠款增加），
  /// 分期信息（计划名 / 期数 / 本息拆分）写进流水备注；该动作与期次是否
  /// 「已还」（[InstallmentPeriods.paidAt]）**无关**。
  ///
  /// Local-first 无后台常驻服务，入账走「惰性补账」：计划创建时（首期已
  /// 到期的计划立即出当期账单，见 [addPlan]）+ App 启动兜底
  /// （bootstrap）+ 分期列表页进入时各调一次。幂等：已入账
  /// （[InstallmentPeriods.transactionId] 指向存活账单）的期次直接跳过；
  /// 入账单被手动删除视为异常，再次运行自愈补回（订单是负债事实）。
  /// 关联账户缺失或非负债方向的计划不落账（历史数据兜底）。
  Future<void> postDuePeriods() async {
    final int nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;

    final List<InstallmentPeriod> due =
        await (_db.select(_db.installmentPeriods)
              ..where(
                (InstallmentPeriods t) =>
                    t.deleted.equals(false) &
                    t.dueAt.isSmallerOrEqualValue(nowMs),
              ))
            .get();
    if (due.isEmpty) return;

    final Set<String> planIds =
        due.map((InstallmentPeriod p) => p.planId).toSet();
    final Map<String, InstallmentPlan> plans = <String, InstallmentPlan>{};
    final Map<String, Account> accounts = <String, Account>{};
    final List<InstallmentPlan> planRows =
        await (_db.select(_db.installmentPlans)
              ..where(
                (InstallmentPlans t) =>
                    t.id.isIn(planIds) & t.deleted.equals(false),
              ))
            .get();
    for (final InstallmentPlan plan in planRows) {
      plans[plan.id] = plan;
      if (plan.accountId == null) continue;
      final Account? account = await (_db.select(_db.accounts)
            ..where((Accounts t) => t.id.equals(plan.accountId!)))
          .getSingleOrNull();
      if (account != null) accounts[plan.id] = account;
    }

    for (final InstallmentPeriod p in due) {
      final InstallmentPlan? plan = plans[p.planId];
      if (plan == null) continue; // 计划已软删：期次清理由 removePlan 负责
      // 已结束（提前结清 / 手动完结）的计划不再补账：结清订单已一次性
      // 覆盖剩余欠款，后续期次不能再生成新订单。
      if (plan.isFinished) continue;
      final Account? account = accounts[p.planId];
      // 分期付款账户必须是负债账户：非负债方向（历史误关联资产账户）不落账
      if (account == null || !account.type.isLiabilitySide) continue;

      // 幂等：已入账且账单仍存活 → 跳过；账单被删或引用悬空 → 自愈补建
      if (p.transactionId != null) {
        final Transaction? existing =
            await _db.transactionsDao.getById(p.transactionId!);
        if (existing != null && !existing.deleted) continue;
      }

      final String txId = await _postPeriodTxn(p, plan);
      await _markPosted(p.id, txId, nowMs);
    }
  }

  /// 为到期期次在负债付款账户生成「分期订单 + 利息」入账单。
  ///
  /// 支出挂负债账户 = 欠款增加（与刷卡消费同向），即账单周期入账语义；
  /// [occurredAt] 取期次到期日而非补账运行时刻，保证账期归位。
  Future<String> _postPeriodTxn(
    InstallmentPeriod period,
    InstallmentPlan plan,
  ) async {
    final List<int> fees = feeByPeriodOf(plan);
    final int feeIndex = period.periodIndex - 1;
    final int fee = feeIndex >= 0 && feeIndex < fees.length
        ? fees[feeIndex]
        : 0;
    final int principal = period.amountMinor - fee;
    // 备注两行排版：第一行标题（「XX第N期分期入账」），第二行本金/利息
    // 明细（无手续费期次省略第二行），备注行按 \n 换行展示。
    final String feeNote = fee > 0
        ? '\n本金 ${Money.fromMinor(principal).format()}＋利息 ${Money.fromMinor(fee).format()}'
        : '';
    final String catId = await CategoryRepository(_db).ensureNamed(
      bookId: plan.bookId,
      name: '分期',
      type: CategoryType.expense,
      iconKey: 'credit_card',
      isSystem: true,
    );
    return _txnRepo.add(
      bookId: plan.bookId,
      type: TxnType.expense,
      amountMinor: period.amountMinor,
      accountId: plan.accountId!,
      categoryId: catId,
      occurredAt: period.dueAt,
      note: '${plan.title}第${period.periodIndex}期分期入账$feeNote',
      sourceModule: SourceModule.installment,
      relatedId: period.id,
    );
  }

  /// 期次回填入账单引用并同步入队。
  Future<void> _markPosted(String periodId, String txId, int now) async {
    await (_db.update(_db.installmentPeriods)
          ..where((InstallmentPeriods t) => t.id.equals(periodId)))
        .write(
      InstallmentPeriodsCompanion(
        transactionId: Value<String?>(txId),
        updatedAt: Value<int>(now),
        dirty: const Value<bool>(true),
      ),
    );
    await enqueueSyncOp(
      _db,
      table: 'installment_periods',
      recordId: periodId,
      opType: SyncOpType.update,
      updatedAt: now,
      payload: <String, Object?>{'transactionId': txId},
    );
  }

  /// 分期还款自动对账（幂等，可安全重复调用）。
  ///
  /// 口径（2026-10-09 与用户确认 + 后续补充）：
  /// 负债账户有账单周期（[Accounts.billingDay]）。每期分期入账（[postDuePeriods]
  /// 生成订单流水）后归属于某个账单周期；**出账单日之后、下一个账单日之前**，若有
  /// 「从其他账户转入该负债账户的还款」覆盖该期金额，或还款合计覆盖该周期账单
  /// 金额的 [autoRepayCoverRatio]，则自动勾选对应期次「已还」（[togglePeriodPaid]）。
  ///
  /// 匹配算法（用户确认）：
  /// 1. 逐期贪心：把窗口内还款汇总，按到期日从早到晚逐期比对，还款余额≥当期
  ///    金额即标记已还并扣减；
  /// 2. 整单 70% 兜底：若还款合计 ≥ 周期账单总额 × [autoRepayCoverRatio]，
  ///    该周期全部期次一并标记已还（覆盖「部分还款但金额够大」的场景）。
  ///
  /// 「可进可退」（用户确认）：还款被删/减少导致周期不再满足条件时，自动回退那些
  /// 被本逻辑勾选的期次（记在 [installment_auto_paid] 溯源表）；用户**手动**勾选
  /// 的期次不在溯源表，reconcile 永不触碰，避免误伤。
  ///
  /// 触发：bootstrap（紧随 [postDuePeriods]）+ 分期列表页进入时各一次，
  /// 覆盖「App 长驻跨天 / 还款后回到分期页」的场景。
  Future<void> reconcileInstallmentRepayments() async {
    // 0. 负债方向且设了账单日的账户（账单周期可识别才参与）。
    final List<Account> all = await (_db.select(_db.accounts)
          ..where((Accounts a) => a.deleted.equals(false)))
        .get();
    final List<Account> targets = all
        .where((Account a) => a.type.isLiabilitySide && a.billingDay != null)
        .toList();
    if (targets.isEmpty) return;

    // 当前已被自动勾选的期次集合（用于回退判定）。
    final Set<String> autoPaid = await _autoPaidPeriodIds();

    for (final Account acc in targets) {
      final int billingDay = acc.billingDay!;

      // 1. 该账户下已入账（有订单流水）的未删期次，且关联付款账户 == acc。
      final List<InstallmentPeriod> posted = await (_db.select(_db.installmentPeriods)
            ..where((InstallmentPeriods p) =>
                p.deleted.equals(false) & p.transactionId.isNotNull()))
          .get();
      if (posted.isEmpty) continue;
      final Set<String> planIds = posted.map((InstallmentPeriod p) => p.planId).toSet();
      final List<InstallmentPlan> planRows = await (_db.select(_db.installmentPlans)
            ..where((InstallmentPlans t) =>
                t.id.isIn(planIds) & t.deleted.equals(false)))
          .get();
      final Map<String, InstallmentPlan> plans = <String, InstallmentPlan>{
        for (final InstallmentPlan p in planRows) p.id: p,
      };
      final List<InstallmentPeriod> periods = posted
          .where((InstallmentPeriod p) {
            final InstallmentPlan? plan = plans[p.planId];
            return plan != null && plan.accountId == acc.id;
          })
          .toList();
      if (periods.isEmpty) continue;

      // 2. 该账户收到的还款（转账转入腿：toAccountId == acc.id）。
      final List<Transaction> repayments = await (_db.select(_db.transactions)
            ..where((Transactions t) =>
                t.toAccountId.equals(acc.id) & t.deleted.equals(false)))
          .get();

      // 3. 按期次入账日（=订单流水 occurredAt = period.dueAt）归到账单周期。
      final Map<DateTime, List<InstallmentPeriod>> byCycle =
          <DateTime, List<InstallmentPeriod>>{};
      for (final InstallmentPeriod p in periods) {
        final DateTime postLocal =
            DateTime.fromMillisecondsSinceEpoch(p.dueAt, isUtc: true).toLocal();
        final BillCycle cy = billCycleOf(postLocal, billingDay);
        byCycle.putIfAbsent(cy.statement, () => <InstallmentPeriod>[]).add(p);
      }

      for (final MapEntry<DateTime, List<InstallmentPeriod>> entry
          in byCycle.entries) {
        final List<InstallmentPeriod> group = entry.value;
        final DateTime statement = entry.key;
        final BillCycle cy = billCycleOf(
          DateTime.fromMillisecondsSinceEpoch(group.first.dueAt, isUtc: true)
              .toLocal(),
          billingDay,
        );
        // 还款匹配窗口 [statement, next)：出账单日（含）→ 下一个账单日（不含）。
        final int winStart = statement.toUtc().millisecondsSinceEpoch;
        final int winEnd = cy.next.toUtc().millisecondsSinceEpoch;
        final List<Transaction> reps = repayments
            .where((Transaction t) =>
                t.occurredAt >= winStart && t.occurredAt < winEnd)
            .toList();
        final int totalRepaid =
            reps.fold<int>(0, (int s, Transaction t) => s + t.amountMinor);
        final int billedTotal = group.fold<int>(
            0, (int s, InstallmentPeriod p) => s + p.amountMinor);

        final Set<String> matched = <String>{};
        if (billedTotal > 0 &&
            totalRepaid * 100 >= billedTotal * (autoRepayCoverRatio * 100).round()) {
          // 整单 70% 兜底：该周期全部期次标记已还。
          for (final InstallmentPeriod p in group) matched.add(p.id);
        } else {
          // 逐期贪心：按到期日从早到晚，还款余额 ≥ 当期金额即标记并扣减。
          int remaining = totalRepaid;
          final List<InstallmentPeriod> ordered = List<InstallmentPeriod>.from(
            group,
          )..sort((InstallmentPeriod a, InstallmentPeriod b) => a.dueAt.compareTo(b.dueAt));
          for (final InstallmentPeriod p in ordered) {
            if (remaining >= p.amountMinor) {
              matched.add(p.id);
              remaining -= p.amountMinor;
            }
          }
        }

        // 应用：只动「未还」与「自动溯源」的期次；手动勾选（不在 autoPaid）不动。
        for (final InstallmentPeriod p in group) {
          final bool shouldPaid = matched.contains(p.id);
          final bool isAuto = autoPaid.contains(p.id);
          if (shouldPaid && p.paidAt == null) {
            await togglePeriodPaid(p.id, paid: true, auto: true);
          } else if (!shouldPaid && isAuto) {
            await togglePeriodPaid(p.id, paid: false, auto: true);
          }
          // 已还且非自动（手动）：保留；已还且自动且仍匹配：保留（不动）。
        }
      }
    }
  }

  /// 自动勾选覆盖阈值（占比，0-1）：还款合计 ≥ 周期账单总额 × 此值即整单标记。
  static const double autoRepayCoverRatio = 0.7;

  /// 读取当前被自动对账勾选的期次集合（溯源表）。
  Future<Set<String>> _autoPaidPeriodIds() async {
    final List<QueryRow> rows = await _db
        .customSelect('SELECT period_id FROM installment_auto_paid')
        .get();
    return rows.map((QueryRow r) => r.read<String>('period_id')).toSet();
  }

  /// 记入某期次为「自动勾选」（溯源表 upsert）。
  Future<void> _markAutoPaid(String periodId, int now) async {
    await _db.customStatement(
      'INSERT OR REPLACE INTO installment_auto_paid (period_id, auto_at) '
      'VALUES (?, ?)',
      <Variable<Object>>[Variable<String>(periodId), Variable<int>(now)],
    );
  }

  /// 从溯源表移除某期次（撤销自动勾选 / 手动动作接管）。
  Future<void> _unmarkAutoPaid(String periodId) async {
    await _db.customStatement(
      'DELETE FROM installment_auto_paid WHERE period_id = ?',
      <Variable<Object>>[Variable<String>(periodId)],
    );
  }

  /// 依据明细实际状态回写计划进度。
  ///
  /// 不用「+1 / -1」增量更新，因为撤销、批量改期、同步合并都可能让计数漂移；
  /// 直接按明细重算是唯一可靠的口径。
  Future<void> _refreshPlanProgress(String planId, int now) async {
    final List<InstallmentPeriod> periods =
        await (_db.select(_db.installmentPeriods)
              ..where(
                (InstallmentPeriods t) =>
                    t.planId.equals(planId) & t.deleted.equals(false),
              ))
            .get();

    final int paidCount =
        periods.where((InstallmentPeriod p) => p.paidAt != null).length;
    final bool finished = periods.isNotEmpty && paidCount == periods.length;

    await (_db.update(_db.installmentPlans)
          ..where((InstallmentPlans t) => t.id.equals(planId)))
        .write(
      InstallmentPlansCompanion(
        paidPeriods: Value<int>(paidCount),
        isFinished: Value<bool>(finished),
        updatedAt: Value<int>(now),
        dirty: const Value<bool>(true),
      ),
    );
    await enqueueSyncOp(
      _db,
      table: 'installment_plans',
      recordId: planId,
      opType: SyncOpType.update,
      updatedAt: now,
      payload: <String, Object?>{
        'paidPeriods': paidCount,
        'isFinished': finished,
      },
    );
  }

  /// 提前完结：把未还期次一次性标记为已还（与手动逐期勾选完全同口径，
  /// isFinished 仍由 [_refreshPlanProgress] 按明细重算），用于列表左滑「完结」。
  ///
  /// 只更新还款状态、不产生流水（2026-10-09 口径）：到期入账由
  /// [postDuePeriods] 按期次到期日独立完成，与是否已还无关。
  Future<void> finishPlan(String planId) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.transaction<void>(() async {
      final List<InstallmentPeriod> unpaid =
          await (_db.select(_db.installmentPeriods)
                ..where(
                  (InstallmentPeriods t) =>
                      t.planId.equals(planId) &
                      t.deleted.equals(false) &
                      t.paidAt.isNull(),
                ))
              .get();
      for (final InstallmentPeriod p in unpaid) {
        await (_db.update(_db.installmentPeriods)
              ..where((InstallmentPeriods t) => t.id.equals(p.id)))
            .write(
          InstallmentPeriodsCompanion(
            paidAt: Value<int?>(now),
            updatedAt: Value<int>(now),
            dirty: const Value<bool>(true),
          ),
        );
        await enqueueSyncOp(
          _db,
          table: 'installment_periods',
          recordId: p.id,
          opType: SyncOpType.update,
          updatedAt: now,
          payload: <String, Object?>{'paidAt': now},
        );
        // 完结是手动动作：清掉自动溯源，转为手动口径（reconcile 不再回退）。
        await _unmarkAutoPaid(p.id);
      }
      await _refreshPlanProgress(planId, now);
    });
  }

  /// 提前结清：为剩余未还本金生成一笔「一次性还清」订单流水，计划随即
  /// 转为已结束（[InstallmentPlans.isFinished] 由 [_refreshPlanProgress]
  /// 按明细重算），未还期次一次性标记已还（与 [finishPlan] 同口径，
  /// 清自动溯源，reconcile 不再触碰）。
  ///
  /// 口径（2026-10-10 与用户确认）：
  /// - 结清订单金额 = 剩余未还**本金**（未到期期次的利息不再收取），
  ///   在负债付款账户落一笔支出（欠款增加），随账单周期出账后一次性还清；
  /// - 分类 / 账户沿用原分期计划口径（系统分类「分期」+ [InstallmentPlans.accountId]），
  ///   备注两行：第一行「XX提前结清」，第二行剩余本金金额；
  /// - `postDuePeriods` 对已结束计划跳过补账：后续期次不再生成新订单。
  Future<void> settlePlanEarly(String planId) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;

    final InstallmentPlan? plan = await (_db.select(_db.installmentPlans)
          ..where((InstallmentPlans t) => t.id.equals(planId)))
        .getSingleOrNull();
    if (plan == null || plan.deleted) {
      throw const NotFoundFailure('分期计划不存在');
    }
    if (plan.accountId == null || plan.accountId!.isEmpty) {
      throw const ValidationFailure('该计划未关联负债账户，无法结清');
    }

    final List<InstallmentPeriod> periods =
        await (_db.select(_db.installmentPeriods)
              ..where(
                (InstallmentPeriods t) =>
                    t.planId.equals(planId) & t.deleted.equals(false),
              ))
            .get();
    final List<InstallmentPeriod> unpaid = periods
        .where((InstallmentPeriod p) => p.paidAt == null)
        .toList(growable: false);
    if (unpaid.isEmpty) throw const ValidationFailure('该计划没有待结清的期次');

    // 剩余未还本金 = 各未还期次金额 − 对应期次利息（提前结清免收未到期利息）。
    final List<int> fees = feeByPeriodOf(plan);
    int remainingPrincipal = 0;
    for (final InstallmentPeriod p in unpaid) {
      final int idx = p.periodIndex - 1;
      final int fee = idx >= 0 && idx < fees.length ? fees[idx] : 0;
      remainingPrincipal += p.amountMinor - fee;
    }
    if (remainingPrincipal <= 0) {
      throw const ValidationFailure('剩余未还本金为 0，无需结清');
    }

    // 结清订单：负债账户支出（欠款增加），随账单周期出账一次性还清。
    final String catId = await CategoryRepository(_db).ensureNamed(
      bookId: plan.bookId,
      name: '分期',
      type: CategoryType.expense,
      iconKey: 'credit_card',
      isSystem: true,
    );
    await _txnRepo.add(
      bookId: plan.bookId,
      type: TxnType.expense,
      amountMinor: remainingPrincipal,
      accountId: plan.accountId!,
      categoryId: catId,
      occurredAt: DateTime.now().toLocal().millisecondsSinceEpoch,
      note: '${plan.title}提前结清\n剩余本金 ${Money.fromMinor(remainingPrincipal).format()}',
      sourceModule: SourceModule.installment,
      relatedId: plan.id,
    );

    // 未还期次一次性标记已还（手动口径），计划进度重算后 isFinished=true。
    await _db.transaction<void>(() async {
      for (final InstallmentPeriod p in unpaid) {
        await (_db.update(_db.installmentPeriods)
              ..where((InstallmentPeriods t) => t.id.equals(p.id)))
            .write(
          InstallmentPeriodsCompanion(
            paidAt: Value<int?>(now),
            updatedAt: Value<int>(now),
            dirty: const Value<bool>(true),
          ),
        );
        await enqueueSyncOp(
          _db,
          table: 'installment_periods',
          recordId: p.id,
          opType: SyncOpType.update,
          updatedAt: now,
          payload: <String, Object?>{'paidAt': now},
        );
        // 结清是手动动作：清掉自动溯源，reconcile 不再回退。
        await _unmarkAutoPaid(p.id);
      }
      await _refreshPlanProgress(planId, now);
    });
  }

  /// 更新计划的可编辑元信息（标题 / 关联账户）。
  ///
  /// 金额、期数、利息等字段牵连已生成的期次明细与已还进度，
  /// 暂不开放编辑；如需调整，删除计划后重建。
  Future<void> updatePlanMeta({
    required String planId,
    required String title,
    String? accountId,
  }) async {
    if (title.trim().isEmpty) throw const ValidationFailure('分期名称不能为空');
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await (_db.update(_db.installmentPlans)
          ..where((InstallmentPlans t) => t.id.equals(planId)))
        .write(
      InstallmentPlansCompanion(
        title: Value<String>(title.trim()),
        accountId: Value<String?>(accountId),
        updatedAt: Value<int>(now),
        dirty: const Value<bool>(true),
      ),
    );
    await enqueueSyncOp(
      _db,
      table: 'installment_plans',
      recordId: planId,
      opType: SyncOpType.update,
      updatedAt: now,
      payload: <String, Object?>{
        'title': title.trim(),
        'accountId': accountId,
      },
    );
  }

  Future<void> removePlan(String planId) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.transaction<void>(() async {
      await (_db.update(_db.installmentPlans)
            ..where((InstallmentPlans t) => t.id.equals(planId)))
          .write(
        const InstallmentPlansCompanion(
          deleted: Value<bool>(true),
          dirty: Value<bool>(true),
        ),
      );
      await (_db.update(_db.installmentPeriods)
            ..where((InstallmentPeriods t) => t.planId.equals(planId)))
          .write(
        const InstallmentPeriodsCompanion(
          deleted: Value<bool>(true),
          dirty: Value<bool>(true),
        ),
      );
      await enqueueSyncOp(
        _db,
        table: 'installment_plans',
        recordId: planId,
        opType: SyncOpType.delete,
        updatedAt: now,
      );
    });
  }
}
