import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../domain/enums.dart';

/// 参与同步的表名常量。
///
/// 集中定义而不是各处硬编码字符串：仓储入队与同步引擎落库必须使用
/// **完全一致**的表名，写错一个字符就会导致数据推上去却拉不回来。
abstract final class SyncTables {
  static const String books = 'books';
  static const String transactions = 'transactions';
  static const String accounts = 'accounts';
  static const String categories = 'categories';
  static const String lendRecords = 'lend_records';
  static const String reimbursements = 'reimbursements';
  static const String savingsGoals = 'savings_goals';
  static const String installmentPlans = 'installment_plans';
  static const String installmentPeriods = 'installment_periods';
  static const String budgets = 'budgets';
  static const String investmentHoldings = 'investment_holdings';
  static const String inventoryItems = 'inventory_items';

  static const List<String> all = <String>[
    books,
    transactions,
    accounts,
    categories,
    lendRecords,
    reimbursements,
    savingsGoals,
    installmentPlans,
    installmentPeriods,
    budgets,
    investmentHoldings,
    inventoryItems,
  ];
}

/// 云端记录 → 本地 Drift 伴生对象的解码层。
///
/// **为什么单独抽出来**：解码是纯函数（入参 Map，出参 Companion），
/// 不碰数据库，因此可以在没有 Flutter 运行时的环境下直接断言测试；
/// 而 `SyncEngine` 只负责「查本地行 → 写库」这类有副作用的操作。
///
/// payload 的键名约定：与 Drift 生成的 `toJson()` 保持一致，
/// 即 **Dart 字段名驼峰**，枚举列序列化为 int。
///
/// 冲突解决沿用 LWW：调用方需先比对本地 updatedAt，本地更新则跳过解码。
abstract final class RecordCodec {
  /// 将云端 payload 解码为对应表的插入/更新伴生对象。
  ///
  /// 返回 `null` 表示表名未知（不应中断整轮同步，只跳过这一条）。
  static dynamic decode(
    String table,
    String id,
    Map<String, Object?> p, {
    required int updatedAt,
    required bool deleted,
    required int syncedAt,
  }) {
    switch (table) {
      case SyncTables.books:
        return book(
          id,
          p,
          updatedAt: updatedAt,
          deleted: deleted,
          syncedAt: syncedAt,
        );
      case SyncTables.transactions:
        return transaction(
          id,
          p,
          updatedAt: updatedAt,
          deleted: deleted,
          syncedAt: syncedAt,
        );
      case SyncTables.accounts:
        return account(
          id,
          p,
          updatedAt: updatedAt,
          deleted: deleted,
          syncedAt: syncedAt,
        );
      case SyncTables.categories:
        return category(
          id,
          p,
          updatedAt: updatedAt,
          deleted: deleted,
          syncedAt: syncedAt,
        );
      case SyncTables.lendRecords:
        return lendRecord(
          id,
          p,
          updatedAt: updatedAt,
          deleted: deleted,
          syncedAt: syncedAt,
        );
      case SyncTables.reimbursements:
        return reimbursement(
          id,
          p,
          updatedAt: updatedAt,
          deleted: deleted,
          syncedAt: syncedAt,
        );
      case SyncTables.savingsGoals:
        return savingsGoal(
          id,
          p,
          updatedAt: updatedAt,
          deleted: deleted,
          syncedAt: syncedAt,
        );
      case SyncTables.installmentPlans:
        return installmentPlan(
          id,
          p,
          updatedAt: updatedAt,
          deleted: deleted,
          syncedAt: syncedAt,
        );
      case SyncTables.installmentPeriods:
        return installmentPeriod(
          id,
          p,
          updatedAt: updatedAt,
          deleted: deleted,
          syncedAt: syncedAt,
        );
      case SyncTables.budgets:
        return budget(
          id,
          p,
          updatedAt: updatedAt,
          deleted: deleted,
          syncedAt: syncedAt,
        );
      case SyncTables.investmentHoldings:
        return investmentHolding(
          id,
          p,
          updatedAt: updatedAt,
          deleted: deleted,
          syncedAt: syncedAt,
        );
      case SyncTables.inventoryItems:
        return inventoryItem(
          id,
          p,
          updatedAt: updatedAt,
          deleted: deleted,
          syncedAt: syncedAt,
        );
      default:
        return null;
    }
  }

  static BooksCompanion book(
    String id,
    Map<String, Object?> p, {
    required int updatedAt,
    required bool deleted,
    required int syncedAt,
  }) =>
      BooksCompanion.insert(
        id: id,
        name: p['name']! as String,
        createdAt: (p['createdAt'] as int?) ?? updatedAt,
        updatedAt: updatedAt,
        currency: Value<String>((p['currency'] as String?) ?? 'CNY'),
        sortOrder: Value<int>((p['sortOrder'] as int?) ?? 0),
        deleted: Value<bool>(deleted),
        dirty: const Value<bool>(false),
        syncedAt: Value<int>(syncedAt),
      );

  static TransactionsCompanion transaction(
    String id,
    Map<String, Object?> p, {
    required int updatedAt,
    required bool deleted,
    required int syncedAt,
  }) =>
      TransactionsCompanion.insert(
        id: id,
        bookId: p['bookId']! as String,
        type: _idx(TxnType.values, p['type']),
        amountMinor: p['amountMinor']! as int,
        accountId: p['accountId']! as String,
        occurredAt: p['occurredAt']! as int,
        sourceModule: _idx(SourceModule.values, p['sourceModule']),
        updatedAt: updatedAt,
        currency: Value<String>((p['currency'] as String?) ?? 'CNY'),
        toAccountId: Value<String?>(p['toAccountId'] as String?),
        categoryId: Value<String?>(p['categoryId'] as String?),
        note: Value<String?>(p['note'] as String?),
        attachmentUrls: Value<String?>(p['attachmentUrls'] as String?),
        tags: Value<String?>(p['tags'] as String?),
        relatedId: Value<String?>(p['relatedId'] as String?),
        transferGroupId: Value<String?>(p['transferGroupId'] as String?),
        feeMinor: Value<int>((p['feeMinor'] as int?) ?? 0),
        discountMinor: Value<int>((p['discountMinor'] as int?) ?? 0),
        excludeFromStats:
            Value<bool>((p['excludeFromStats'] as bool?) ?? false),
        excludeFromBudget:
            Value<bool>((p['excludeFromBudget'] as bool?) ?? false),
        isReimbursable: Value<bool>((p['isReimbursable'] as bool?) ?? false),
        reimbursementAccountId:
            Value<String?>(p['reimbursementAccountId'] as String?),
        deleted: Value<bool>(deleted),
        dirty: const Value<bool>(false),
        syncedAt: Value<int>(syncedAt),
      );

  static AccountsCompanion account(
    String id,
    Map<String, Object?> p, {
    required int updatedAt,
    required bool deleted,
    required int syncedAt,
  }) {
    final AccountStatus status = _idx(AccountStatus.values, p['status']);
    return AccountsCompanion.insert(
      id: id,
      bookId: p['bookId']! as String,
      name: p['name']! as String,
      type: _idx(AccountType.values, p['type']),
      updatedAt: updatedAt,
      balanceMinor: Value<int>((p['balanceMinor'] as int?) ?? 0),
      currency: Value<String>((p['currency'] as String?) ?? 'CNY'),
      creditLimitMinor: Value<int?>(p['creditLimitMinor'] as int?),
      iconKey: Value<String?>(p['iconKey'] as String?),
      colorValue: Value<int?>(p['colorValue'] as int?),
      billingDay: Value<int?>(p['billingDay'] as int?),
      dueDay: Value<int?>(p['dueDay'] as int?),
      note: Value<String?>(p['note'] as String?),
      cardNumber: Value<String?>(p['cardNumber'] as String?),
      status: Value<AccountStatus>(status),
      includeInTotal: Value<bool>((p['includeInTotal'] as bool?) ?? true),
      isArchived: Value<bool>(
        (p['isArchived'] as bool?) ?? (status != AccountStatus.active),
      ),
      sortOrder: Value<int>((p['sortOrder'] as int?) ?? 0),
      deleted: Value<bool>(deleted),
      dirty: const Value<bool>(false),
      syncedAt: Value<int>(syncedAt),
    );
  }

  static CategoriesCompanion category(
    String id,
    Map<String, Object?> p, {
    required int updatedAt,
    required bool deleted,
    required int syncedAt,
  }) =>
      CategoriesCompanion.insert(
        id: id,
        bookId: p['bookId']! as String,
        name: p['name']! as String,
        type: _idx(CategoryType.values, p['type']),
        updatedAt: updatedAt,
        parentId: Value<String?>(p['parentId'] as String?),
        iconKey: Value<String?>(p['iconKey'] as String?),
        colorValue: Value<int?>(p['colorValue'] as int?),
        sortOrder: Value<int>((p['sortOrder'] as int?) ?? 0),
        isArchived: Value<bool>((p['isArchived'] as bool?) ?? false),
        isSystem: Value<bool>((p['isSystem'] as bool?) ?? false),
        deleted: Value<bool>(deleted),
        dirty: const Value<bool>(false),
        syncedAt: Value<int>(syncedAt),
      );

  static LendRecordsCompanion lendRecord(
    String id,
    Map<String, Object?> p, {
    required int updatedAt,
    required bool deleted,
    required int syncedAt,
  }) =>
      LendRecordsCompanion.insert(
        id: id,
        bookId: p['bookId']! as String,
        direction: _idx(LendDirection.values, p['direction']),
        status: _idx(LendStatus.values, p['status']),
        counterparty: p['counterparty']! as String,
        amountMinor: p['amountMinor']! as int,
        occurredAt: p['occurredAt']! as int,
        updatedAt: updatedAt,
        repaidMinor: Value<int>((p['repaidMinor'] as int?) ?? 0),
        currency: Value<String>((p['currency'] as String?) ?? 'CNY'),
        dueAt: Value<int?>(p['dueAt'] as int?),
        note: Value<String?>(p['note'] as String?),
        accountId: Value<String?>(p['accountId'] as String?),
        toAccountId: Value<String?>(p['toAccountId'] as String?),
        feeMinor: Value<int>((p['feeMinor'] as int?) ?? 0),
        discountMinor: Value<int>((p['discountMinor'] as int?) ?? 0),
        deleted: Value<bool>(deleted),
        dirty: const Value<bool>(false),
        syncedAt: Value<int>(syncedAt),
      );

  static ReimbursementsCompanion reimbursement(
    String id,
    Map<String, Object?> p, {
    required int updatedAt,
    required bool deleted,
    required int syncedAt,
  }) =>
      ReimbursementsCompanion.insert(
        id: id,
        bookId: p['bookId']! as String,
        title: p['title']! as String,
        status: _idx(ReimbursementStatus.values, p['status']),
        amountMinor: p['amountMinor']! as int,
        payer: p['payer']! as String,
        occurredAt: p['occurredAt']! as int,
        updatedAt: updatedAt,
        currency: Value<String>((p['currency'] as String?) ?? 'CNY'),
        target: Value<String?>(p['target'] as String?),
        receivedAt: Value<int?>(p['receivedAt'] as int?),
        note: Value<String?>(p['note'] as String?),
        attachmentUrls: Value<String?>(p['attachmentUrls'] as String?),
        transactionId: Value<String?>(p['transactionId'] as String?),
        // 漏掉这个字段会导致「不计入收支」开关同步到别的设备后悄悄变回 false
        // （推送侧走 row.toJson() 是全字段，只有解码侧是白名单，极易漏）。
        // self_check.dart 的「RecordCodec.<表> 覆盖全部字段」检查专门守这一条。
        excludeFromStats: Value<bool>(p['excludeFromStats'] as bool? ?? false),
        accountId: Value<String?>(p['accountId'] as String?),
        toAccountId: Value<String?>(p['toAccountId'] as String?),
        // 报销收入实时同步（schema v16/v17）：收入流水关联 + 抵扣台账。
        // 漏掉会导致「报销收入 → 关联账单」与撤收入反向恢复在别的设备失效。
        incomeTransactionId:
            Value<String?>(p['incomeTransactionId'] as String?),
        incomeAllocs: Value<String?>(p['incomeAllocs'] as String?),
        deleted: Value<bool>(deleted),
        dirty: const Value<bool>(false),
        syncedAt: Value<int>(syncedAt),
      );

  static SavingsGoalsCompanion savingsGoal(
    String id,
    Map<String, Object?> p, {
    required int updatedAt,
    required bool deleted,
    required int syncedAt,
  }) =>
      SavingsGoalsCompanion.insert(
        id: id,
        bookId: p['bookId']! as String,
        name: p['name']! as String,
        targetMinor: p['targetMinor']! as int,
        updatedAt: updatedAt,
        currentMinor: Value<int>((p['currentMinor'] as int?) ?? 0),
        currency: Value<String>((p['currency'] as String?) ?? 'CNY'),
        accountId: Value<String?>(p['accountId'] as String?),
        deadlineAt: Value<int?>(p['deadlineAt'] as int?),
        note: Value<String?>(p['note'] as String?),
        isAchieved: Value<bool>((p['isAchieved'] as bool?) ?? false),
        // 小青账储蓄计划（schema v19-v22）：归档/模式/排期/弹性存钱法/扣款账户
        isArchived: Value<bool>((p['isArchived'] as bool?) ?? false),
        mode: Value<String?>(p['mode'] as String?),
        repeatCycle: Value<String?>(p['repeatCycle'] as String?),
        endNote: Value<String?>(p['endNote'] as String?),
        depositCount: Value<int>((p['depositCount'] as int?) ?? 0),
        startedAt: Value<int?>(p['startedAt'] as int?),
        elasticMode: Value<int>((p['elasticMode'] as int?) ?? 1),
        elasticBaseMinor: Value<int?>(p['elasticBaseMinor'] as int?),
        elasticStepMinor: Value<int?>(p['elasticStepMinor'] as int?),
        elasticPercentHundred:
            Value<int?>(p['elasticPercentHundred'] as int?),
        sourceAccountId: Value<String?>(p['sourceAccountId'] as String?),
        deleted: Value<bool>(deleted),
        dirty: const Value<bool>(false),
        syncedAt: Value<int>(syncedAt),
      );

  static InstallmentPlansCompanion installmentPlan(
    String id,
    Map<String, Object?> p, {
    required int updatedAt,
    required bool deleted,
    required int syncedAt,
  }) =>
      InstallmentPlansCompanion.insert(
        id: id,
        bookId: p['bookId']! as String,
        title: p['title']! as String,
        totalMinor: p['totalMinor']! as int,
        totalPeriods: p['totalPeriods']! as int,
        firstDueAt: p['firstDueAt']! as int,
        updatedAt: updatedAt,
        paidPeriods: Value<int>((p['paidPeriods'] as int?) ?? 0),
        feePerPeriodMinor: Value<int>((p['feePerPeriodMinor'] as int?) ?? 0),
        feeByPeriodMinor: Value<String?>((p['feeByPeriodMinor'] as String?)),
        repeatRule: Value<String?>(p['repeatRule'] as String?),
        currency: Value<String>((p['currency'] as String?) ?? 'CNY'),
        accountId: Value<String?>(p['accountId'] as String?),
        note: Value<String?>(p['note'] as String?),
        isFinished: Value<bool>((p['isFinished'] as bool?) ?? false),
        deleted: Value<bool>(deleted),
        dirty: const Value<bool>(false),
        syncedAt: Value<int>(syncedAt),
      );

  static InstallmentPeriodsCompanion installmentPeriod(
    String id,
    Map<String, Object?> p, {
    required int updatedAt,
    required bool deleted,
    required int syncedAt,
  }) =>
      InstallmentPeriodsCompanion.insert(
        id: id,
        planId: p['planId']! as String,
        periodIndex: p['periodIndex']! as int,
        amountMinor: p['amountMinor']! as int,
        dueAt: p['dueAt']! as int,
        updatedAt: updatedAt,
        paidAt: Value<int?>(p['paidAt'] as int?),
        transactionId: Value<String?>(p['transactionId'] as String?),
        deleted: Value<bool>(deleted),
        dirty: const Value<bool>(false),
        syncedAt: Value<int>(syncedAt),
      );

  static BudgetsCompanion budget(
    String id,
    Map<String, Object?> p, {
    required int updatedAt,
    required bool deleted,
    required int syncedAt,
  }) =>
      BudgetsCompanion.insert(
        id: id,
        bookId: p['bookId']! as String,
        scope: _idx(BudgetScope.values, p['scope']),
        period: _idx(BudgetPeriod.values, p['period']),
        amountMinor: p['amountMinor']! as int,
        year: p['year']! as int,
        updatedAt: updatedAt,
        periodIndex: Value<int>((p['periodIndex'] as int?) ?? 0),
        currency: Value<String>((p['currency'] as String?) ?? 'CNY'),
        categoryId: Value<String?>(p['categoryId'] as String?),
        alertEnabled: Value<bool>((p['alertEnabled'] as bool?) ?? true),
        alertThreshold: Value<int>((p['alertThreshold'] as int?) ?? 80),
        deleted: Value<bool>(deleted),
        dirty: const Value<bool>(false),
        syncedAt: Value<int>(syncedAt),
      );

  static InvestmentHoldingsCompanion investmentHolding(
    String id,
    Map<String, Object?> p, {
    required int updatedAt,
    required bool deleted,
    required int syncedAt,
  }) =>
      InvestmentHoldingsCompanion.insert(
        id: id,
        bookId: p['bookId']! as String,
        symbol: p['symbol']! as String,
        name: p['name']! as String,
        type: _idx(InvestmentType.values, p['type']),
        updatedAt: updatedAt,
        quantityMicros: Value<int>((p['quantityMicros'] as int?) ?? 0),
        avgCostMinor: Value<int>((p['avgCostMinor'] as int?) ?? 0),
        currentPriceMinor: Value<int>((p['currentPriceMinor'] as int?) ?? 0),
        currency: Value<String>((p['currency'] as String?) ?? 'CNY'),
        accountId: Value<String?>(p['accountId'] as String?),
        priceUpdatedAt: Value<int?>(p['priceUpdatedAt'] as int?),
        note: Value<String?>(p['note'] as String?),
        deleted: Value<bool>(deleted),
        dirty: const Value<bool>(false),
        syncedAt: Value<int>(syncedAt),
      );

  static InventoryItemsCompanion inventoryItem(
    String id,
    Map<String, Object?> p, {
    required int updatedAt,
    required bool deleted,
    required int syncedAt,
  }) =>
      InventoryItemsCompanion.insert(
        id: id,
        bookId: p['bookId']! as String,
        name: p['name']! as String,
        purchasedAt: p['purchasedAt']! as int,
        updatedAt: updatedAt,
        category: Value<String?>(p['category'] as String?),
        purchasePriceMinor: Value<int>((p['purchasePriceMinor'] as int?) ?? 0),
        currentValueMinor: Value<int>((p['currentValueMinor'] as int?) ?? 0),
        currency: Value<String>((p['currency'] as String?) ?? 'CNY'),
        warrantyUntil: Value<int?>(p['warrantyUntil'] as int?),
        photoUrl: Value<String?>(p['photoUrl'] as String?),
        location: Value<String?>(p['location'] as String?),
        note: Value<String?>(p['note'] as String?),
        transactionId: Value<String?>(p['transactionId'] as String?),
        deleted: Value<bool>(deleted),
        dirty: const Value<bool>(false),
        syncedAt: Value<int>(syncedAt),
      );

  /// 按下标取枚举。越界时回退到第一个值而不是抛异常 ——
  /// 一条脏数据不该让整轮同步崩溃。
  static T _idx<T extends Enum>(List<T> values, Object? raw) {
    final int i = (raw as int?) ?? 0;
    if (i < 0 || i >= values.length) return values.first;
    return values[i];
  }
}
