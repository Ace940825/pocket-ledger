import 'dart:convert';

import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_utils.dart';
import '../../../database/app_database.dart';
import '../../../database/daos/transactions_dao.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../data/import_record_repository.dart';
import '../data/transaction_repository.dart';

final Provider<TransactionRepository> transactionRepositoryProvider =
    Provider<TransactionRepository>(
  (Ref ref) => TransactionRepository(ref.watch(appDatabaseProvider)),
);

/// 导入记录仓储（原生 SQL 表 `import_records` 读写 + 级联删除）。
final Provider<ImportRecordRepository> importRecordRepositoryProvider =
    Provider<ImportRecordRepository>(
  (Ref ref) => ImportRecordRepository(ref.watch(appDatabaseProvider)),
);

/// 全部导入记录（按完成时间倒序）实时流，入口页「导入记录」列表用。
///
/// 导入 / 删除导入记录均伴随 transactions 表变更，[ImportRecordRepository.watchAll]
/// 据此自动重发，列表即时刷新。
final AutoDisposeStreamProvider<List<ImportRecord>> importRecordsProvider =
    StreamProvider.autoDispose<List<ImportRecord>>((Ref ref) {
  final ImportRecordRepository repo = ref.watch(importRecordRepositoryProvider);
  return repo.watchAll();
});

/// 最近流水列表。直接监听本地 Drift 流，写入后 UI 立即刷新。
final AutoDisposeStreamProvider<List<Transaction>> recentTransactionsProvider =
    StreamProvider.autoDispose<List<Transaction>>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref.watch(transactionsDaoProvider).watchRecent(bookId: bookId);
});

/// 当前账本下全部支出流水，用于退款「选择原账单」等账单选择场景。
final AutoDisposeStreamProvider<List<Transaction>>
    bookExpenseTransactionsProvider =
    StreamProvider.autoDispose<List<Transaction>>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref.watch(transactionsDaoProvider).watchExpenses(bookId: bookId);
});

/// 指定账户的全部流水（含转账的转入侧）。给账户页「点开看流水」用。
final AutoDisposeStreamProviderFamily<List<Transaction>, String>
    accountTransactionsProvider = StreamProvider.autoDispose
        .family<List<Transaction>, String>((Ref ref, String accountId) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref
      .watch(transactionsDaoProvider)
      .watchByAccount(bookId: bookId, accountId: accountId);
});

/// 当前账本下全部流水（不限周期、含转账），「账单列表」页（账单管理入口）用。
final AutoDisposeStreamProvider<List<Transaction>> bookAllTransactionsProvider =
    StreamProvider.autoDispose<List<Transaction>>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref.watch(transactionsDaoProvider).watchAll(bookId: bookId);
});

/// 指定分类的全部流水（分类账单页用：明细弹窗点分类进入）。
final AutoDisposeStreamProviderFamily<List<Transaction>, String>
    categoryTransactionsProvider = StreamProvider.autoDispose
        .family<List<Transaction>, String>((Ref ref, String categoryId) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref
      .watch(transactionsDaoProvider)
      .watchByCategory(bookId: bookId, categoryId: categoryId);
});

/// 单条流水详情（编辑页使用）
final AutoDisposeStreamProviderFamily<Transaction?, String>
    transactionDetailProvider =
    StreamProvider.autoDispose.family<Transaction?, String>(
  (Ref ref, String id) => ref.watch(transactionsDaoProvider).watchById(id),
);

/// 指定原账单关联的全部退款流水。
final AutoDisposeStreamProviderFamily<List<Transaction>, String>
    refundsByRelatedIdProvider =
    StreamProvider.autoDispose.family<List<Transaction>, String>(
  (Ref ref, String relatedId) {
    final String bookId = ref.watch(currentBookIdProvider);
    return ref
        .watch(transactionsDaoProvider)
        .watchRefundsByRelatedId(relatedId, bookId: bookId);
  },
);

/// 当前查看的月份（本地时区）
final StateProvider<DateTime> selectedMonthProvider =
    StateProvider<DateTime>((Ref ref) {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month);
});

/// 选中月份的 UTC 毫秒区间 [startAt, endAt)
final Provider<({int startAt, int endAt})> monthRangeProvider =
    Provider<({int startAt, int endAt})>((Ref ref) {
  final DateTime month = ref.watch(selectedMonthProvider);
  final DateTime start = DateTime(month.year, month.month);
  final DateTime end = DateTime(month.year, month.month + 1);
  return (
    startAt: start.toUtc().millisecondsSinceEpoch,
    endAt: end.toUtc().millisecondsSinceEpoch,
  );
});

final AutoDisposeStreamProvider<int> monthIncomeProvider =
    StreamProvider.autoDispose<int>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  final ({int startAt, int endAt}) range = ref.watch(monthRangeProvider);
  return ref.watch(transactionsDaoProvider).watchTotalInRange(
        bookId: bookId,
        startAt: range.startAt,
        endAt: range.endAt,
        type: TxnType.income,
      );
});

final AutoDisposeStreamProvider<int> monthExpenseProvider =
    StreamProvider.autoDispose<int>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  final ({int startAt, int endAt}) range = ref.watch(monthRangeProvider);
  return ref.watch(transactionsDaoProvider).watchTotalInRange(
        bookId: bookId,
        startAt: range.startAt,
        endAt: range.endAt,
        type: TxnType.expense,
      );
});

/// 本月支出分类聚合，用于报表饼图与首页排行
final AutoDisposeStreamProvider<List<CategoryTotal>>
    monthCategoryTotalsProvider =
    StreamProvider.autoDispose<List<CategoryTotal>>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  final ({int startAt, int endAt}) range = ref.watch(monthRangeProvider);
  return ref.watch(transactionsDaoProvider).watchCategoryTotals(
        bookId: bookId,
        startAt: range.startAt,
        endAt: range.endAt,
        type: TxnType.expense,
      );
});

/// 账单页周期模式：周账单 / 月账单 / 年账单 / 自定义。
enum LedgerPeriodMode { week, month, year, custom }

/// 账单页当前查看的周期（本地时区；[end] 为开区间，不含当天）。
class LedgerPeriod {
  const LedgerPeriod({
    required this.mode,
    required this.start,
    required this.end,
  });

  /// 周期模式。
  final LedgerPeriodMode mode;

  /// 起始日（含，当天 0 点）。
  final DateTime start;

  /// 结束日（不含）。
  final DateTime end;

  /// 某个自然月。
  factory LedgerPeriod.monthOf(DateTime m) => LedgerPeriod(
        mode: LedgerPeriodMode.month,
        start: DateTime(m.year, m.month),
        end: DateTime(m.year, m.month + 1),
      );

  /// 某个自然年。
  factory LedgerPeriod.yearOf(int year) => LedgerPeriod(
        mode: LedgerPeriodMode.year,
        start: DateTime(year),
        end: DateTime(year + 1),
      );

  /// 包含 [d] 的自然周（周一为一周起点）。
  factory LedgerPeriod.weekOf(DateTime d) {
    final DateTime day = DateTime(d.year, d.month, d.day);
    final DateTime monday = day.subtract(Duration(days: day.weekday - 1));
    return LedgerPeriod(
      mode: LedgerPeriodMode.week,
      start: monday,
      end: monday.add(const Duration(days: 7)),
    );
  }

  /// 以 [monday]（周一 0 点）为起点的自然周。
  factory LedgerPeriod.weekStart(DateTime monday) => LedgerPeriod(
        mode: LedgerPeriodMode.week,
        start: DateTime(monday.year, monday.month, monday.day),
        end: DateTime(monday.year, monday.month, monday.day)
            .add(const Duration(days: 7)),
      );

  /// 自定义区间 [s, e]（两端均含当天）。
  factory LedgerPeriod.customOf(DateTime s, DateTime e) {
    final DateTime s0 = DateTime(s.year, s.month, s.day);
    final DateTime e0 =
        DateTime(e.year, e.month, e.day).add(const Duration(days: 1));
    return LedgerPeriod(
      mode: LedgerPeriodMode.custom,
      start: s0,
      end: e0.isAfter(s0) ? e0 : s0.add(const Duration(days: 1)),
    );
  }

  /// 副标题行 / 选择器首行左侧的展示标签。
  String get label => switch (mode) {
        LedgerPeriodMode.month => '${start.year}年${start.month}月',
        LedgerPeriodMode.year => '${start.year}年',
        // 区间文案统一走 [formatDayRange]（跨年两端都带年份），禁止手拼。
        _ => formatDayRange(start, end.subtract(const Duration(days: 1))),
      };

  /// 统计卡前缀：周 / 月 / 年 / 空（自定义）。
  String get prefix => switch (mode) {
        LedgerPeriodMode.week => '周',
        LedgerPeriodMode.month => '月',
        LedgerPeriodMode.year => '年',
        LedgerPeriodMode.custom => '',
      };

  /// 周期总天数（≥1）。
  int get dayCount => end.difference(start).inDays;
}

/// 账单页当前查看的周期。
final StateProvider<LedgerPeriod> ledgerPeriodProvider =
    StateProvider<LedgerPeriod>((Ref ref) {
  final DateTime now = DateTime.now();
  return LedgerPeriod.monthOf(DateTime(now.year, now.month));
});

/// 当前周期的 UTC 毫秒区间 [startAt, endAt)。
final Provider<({int startAt, int endAt})> ledgerPeriodRangeProvider =
    Provider<({int startAt, int endAt})>((Ref ref) {
  final LedgerPeriod p = ref.watch(ledgerPeriodProvider);
  return (
    startAt: p.start.toUtc().millisecondsSinceEpoch,
    endAt: p.end.toUtc().millisecondsSinceEpoch,
  );
});

/// 当前周期收入合计（账单页统计卡）。
final AutoDisposeStreamProvider<int> periodIncomeProvider =
    StreamProvider.autoDispose<int>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  final ({int startAt, int endAt}) range = ref.watch(ledgerPeriodRangeProvider);
  return ref.watch(transactionsDaoProvider).watchTotalInRange(
        bookId: bookId,
        startAt: range.startAt,
        endAt: range.endAt,
        type: TxnType.income,
      );
});

/// 当前周期支出合计（账单页统计卡）。
final AutoDisposeStreamProvider<int> periodExpenseProvider =
    StreamProvider.autoDispose<int>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  final ({int startAt, int endAt}) range = ref.watch(ledgerPeriodRangeProvider);
  return ref.watch(transactionsDaoProvider).watchTotalInRange(
        bookId: bookId,
        startAt: range.startAt,
        endAt: range.endAt,
        type: TxnType.expense,
      );
});

/// 当前周期的**全部**流水（含转账、不计收支项），账单页明细与日聚合用。
final AutoDisposeStreamProvider<List<Transaction>> periodTransactionsProvider =
    StreamProvider.autoDispose<List<Transaction>>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  final ({int startAt, int endAt}) range = ref.watch(ledgerPeriodRangeProvider);
  return ref.watch(transactionsDaoProvider).watchRange(
        bookId: bookId,
        startAt: range.startAt,
        endAt: range.endAt,
      );
});

/// 高级筛选模型：筛选页（基本 Tab）产出的全部条件。
///
/// 口径说明：
/// - [day] 精确到「日」过滤 occurredAt；
/// - [minMinor]/[maxMinor] 按「实付金额」（amount − discount，分）比较；
/// - [flowTypes] 收支类型多选（支出/收入）；
/// - [billTypes] 账单类型多选（普通收支/转账/退款/借款/报销/报销收入）；
/// - [sources] 账单来源多选（手动记账/存钱计划/分期记账/导入/自动同步，
///   按流水 source 标记直接匹配）；
/// - [statsExclude]/[budgetExclude] true=仅看不计入项，false=仅看计入项，null=不过滤。
@immutable
class LedgerAdvancedFilter {
  const LedgerAdvancedFilter({
    this.day,
    this.rangeStart,
    this.rangeEnd,
    this.rangeMode,
    this.minMinor,
    this.maxMinor,
    this.note,
    this.flowTypes = const <String>{},
    this.billTypes = const <String>{},
    this.sources = const <String>{},
    this.statsExclude,
    this.budgetExclude,
    this.bookId,
    this.categoryIds = const <String>{},
    this.others = const <String>{},
    this.tagNames = const <String>{},
    this.tagMatchAnd = false,
    this.accountIds = const <String>{},
    this.accountIncludeNone = false,
    this.accountInclude = true,
  });

  final DateTime? day;

  /// 周期筛选（周/月/年/自定义）：[rangeStart] 含、[rangeEnd] 不含
  /// （end 为排他边界，与日历组件 CalendarPeriod.end 口径一致）。
  /// 与 [day] 互斥：设置区间时 day 应为 null，反之亦然。
  final DateTime? rangeStart;
  final DateTime? rangeEnd;

  /// 区间粒度：周/月/年/自定义（null 视为自定义）。
  ///
  /// 只影响**展示**（页头标签「2025年2月」而不是「2月1日-2月28日」）与
  /// 回填日历的初始粒度；区间本身仍由 [rangeStart]/[rangeEnd] 定义。
  /// 2026-10-22 加入：查询后要把页头周期切到该区间，切过去得带上原粒度，
  /// 否则选「月」筛出来页头会变成日区间文案。
  final LedgerPeriodMode? rangeMode;
  final int? minMinor;
  final int? maxMinor;
  final String? note;
  final Set<String> flowTypes;
  final Set<String> billTypes;
  final Set<String> sources;
  final bool? statsExclude;
  final bool? budgetExclude;

  /// 筛选页·分类 Tab 顶部的账本限定（null=不限；与当前账本相同视为不限）。
  final String? bookId;

  /// 选中的分类 id（一级或二级；选一级等价于连同其子分类一起命中）。
  final Set<String> categoryIds;

  /// 「其他」卡选中项（系统类目名口径：还款/取现/退款/借入/借出/收债/
  /// 还债/报销/报销收入/内部转账/债务消减/坏账计提）。
  final Set<String> others;

  /// 选中的标签名称（流水按名称命中；通用标签与账本独立标签合并为一组名称）。
  final Set<String> tagNames;

  /// 多标签命中模式：true=AND（流水须含全部选中标签），
  /// false=OR（含任一选中标签即可）。仅在 [tagNames] 非空时有意义。
  final bool tagMatchAnd;

  /// 筛选页·账户 Tab 选中的账户 id 集合（空=未按账户筛选）。
  final Set<String> accountIds;

  /// 是否勾选「未选择资产」（accountId 为空的游离账单）。
  final bool accountIncludeNone;

  /// 账户命中模式：true=包含（命中任一选中账户即可），
  /// false=不包含（排除选中的账户与游离账单）。仅在勾选了账户时有意义。
  final bool accountInclude;

  /// 是否设置了账户筛选条件。
  bool get hasAccountFilter => accountIds.isNotEmpty || accountIncludeNone;

  /// 已填条件个数（查询按钮上的 N）。
  int get conditionCount =>
      ((day != null || rangeStart != null) ? 1 : 0) +
      (minMinor != null ? 1 : 0) +
      (maxMinor != null ? 1 : 0) +
      ((note != null && note!.trim().isNotEmpty) ? 1 : 0) +
      flowTypes.length +
      billTypes.length +
      sources.length +
      (statsExclude != null ? 1 : 0) +
      (budgetExclude != null ? 1 : 0) +
      categoryIds.length +
      others.length +
      tagNames.length +
      (bookId != null ? 1 : 0) +
      accountIds.length +
      (accountIncludeNone ? 1 : 0) +
      (hasAccountFilter && !accountInclude ? 1 : 0);

  bool get isEmpty => conditionCount == 0;

  /// 展示用条件数：账本限定与当前账本相同时不算一条。
  ///
  /// [conditionCount] 把 [bookId] 也算进去了，但筛选页打开时总会带上当前账本
  /// （不是用户设的条件），于是「只选了时间」也会显成「筛选(2)」。
  /// 查询按钮与页头筛选胶囊统一走本函数，两边数字才一致。
  int conditionCountFor(String? currentBookId) {
    final bool bookExtra = bookId != null && bookId != currentBookId;
    final int n = conditionCount - (bookExtra ? 0 : 1);
    return n < 0 ? 0 : n;
  }

  /// 换掉「时间」条件后的副本（单日 [day] 一并清成区间口径），其余条件保留。
  ///
  /// 用于「页头周期变了 → 时间条件跟着换」的方向，保证时间轴只有一处真相：
  /// 否则页头显示 10 月、明细却被旧区间夹住，列表莫名空白。
  LedgerAdvancedFilter withTime({
    required DateTime? rangeStart,
    required DateTime? rangeEnd,
    required LedgerPeriodMode? rangeMode,
  }) =>
      LedgerAdvancedFilter(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        rangeMode: rangeMode,
        minMinor: minMinor,
        maxMinor: maxMinor,
        note: note,
        flowTypes: flowTypes,
        billTypes: billTypes,
        sources: sources,
        statsExclude: statsExclude,
        budgetExclude: budgetExclude,
        bookId: bookId,
        categoryIds: categoryIds,
        others: others,
        tagNames: tagNames,
        tagMatchAnd: tagMatchAnd,
        accountIds: accountIds,
        accountIncludeNone: accountIncludeNone,
        accountInclude: accountInclude,
      );
}

/// 筛选条件里「时间」部分对应的周期（null = 条件里没有时间部分）。
///
/// 筛选页的「时间」行与页头周期是同一件事的两种呈现：查询后必须用它把页头
/// 周期切过去，否则页头标签 / 统计卡 / 结余卡停在旧周期，明细却被筛到另一个
/// 区间（2026-10-22 真机反馈「查询后账单页面日期没有同步调整」）。
/// 账单页（provider 版）与清理页 / 转换页（本地 state 版）共用本函数。
LedgerPeriod? ledgerPeriodOfFilter(LedgerAdvancedFilter? f) {
  if (f == null) return null;
  DateTime day0(DateTime d) => DateTime(d.year, d.month, d.day);

  final DateTime? rs = f.rangeStart;
  if (rs != null) {
    final DateTime start = day0(rs);
    final DateTime rawEnd = day0(f.rangeEnd ?? rs.add(const Duration(days: 1)));
    return LedgerPeriod(
      mode: f.rangeMode ?? LedgerPeriodMode.custom,
      start: start,
      end: rawEnd.isAfter(start) ? rawEnd : start.add(const Duration(days: 1)),
    );
  }

  if (f.day != null) {
    // 单日：区间退化成 [当日, 次日)，页头文案由 formatDayRange 收敛成一个日期。
    final DateTime start = day0(f.day!);
    return LedgerPeriod(
      mode: LedgerPeriodMode.custom,
      start: start,
      end: start.add(const Duration(days: 1)),
    );
  }
  return null;
}

/// 页头周期变更后，把筛选条件里的「时间」换成新周期（其余条件保留）。
///
/// 条件里没有时间部分时**原样返回同一实例**（调用方可用 identical 判断免写）。
LedgerAdvancedFilter? ledgerFilterWithPeriod(
  LedgerAdvancedFilter? f,
  LedgerPeriod p,
) {
  if (f == null || (f.day == null && f.rangeStart == null)) return f;
  return f.withTime(
    rangeStart: p.start,
    rangeEnd: p.end,
    rangeMode: p.mode,
  );
}

/// 全部账本（筛选页分类 Tab 顶部账本选择用）。
final AutoDisposeStreamProvider<List<Book>> booksListProvider =
    StreamProvider.autoDispose<List<Book>>((Ref ref) {
  return ref.watch(booksDaoProvider).watchAll();
});

/// 账单页高级筛选状态（筛选页「查询」后生效，只作用于明细列表）。
final StateProvider<LedgerAdvancedFilter?> ledgerAdvancedFilterProvider =
    StateProvider<LedgerAdvancedFilter?>((Ref ref) => null);

/// 选中月份的**全部**流水（含转账、不计收支项），账单页明细与日聚合用。
/// 与 [recentTransactionsProvider] 的区别：不限 30 条、随月份切换。
final AutoDisposeStreamProvider<List<Transaction>> monthTransactionsProvider =
    StreamProvider.autoDispose<List<Transaction>>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  final ({int startAt, int endAt}) range = ref.watch(monthRangeProvider);
  return ref.watch(transactionsDaoProvider).watchRange(
        bookId: bookId,
        startAt: range.startAt,
        endAt: range.endAt,
      );
});

// ────────────────────────── 高级筛选匹配（共享） ──────────────────────────

/// 解析流水 tags 字段（JSON 字符串数组）为名称集合；空/异常返回空集。
Set<String> ledgerTxnTagNames(String? raw) {
  if (raw == null || raw.isEmpty) return const <String>{};
  try {
    final List<dynamic>? decoded = jsonDecode(raw) as List<dynamic>?;
    if (decoded == null) return const <String>{};
    return decoded.map((dynamic e) => e.toString()).toSet();
  } catch (_) {
    return const <String>{};
  }
}

/// 按高级筛选条件过滤流水。账单页明细与报表页共用同一套口径，
/// 修改此处会同时影响两个页面。
List<Transaction> applyLedgerAdvancedFilter(
  List<Transaction> all,
  LedgerAdvancedFilter? f,
  Map<String, Category> catById,
) {
  if (f == null || f.isEmpty) return List<Transaction>.of(all);

  // 账单来源：直接按流水 source 标记匹配（手动记账/存钱计划/分期记账/导入/自动同步）。
  // 这 5 个标签与写入时打的 source 完全一致，无需再映射到 sourceModule。
  final Set<String> mappedSources = f.sources.toSet();

  bool match(Transaction t) {
    // 时间：周期区间（周/月/年/自定义，start 含 end 不含）优先，
    // 其次单日（精确到日）。
    final DateTime local = DateTime.fromMillisecondsSinceEpoch(
      t.occurredAt,
      isUtc: true,
    ).toLocal();
    if (f.rangeStart != null) {
      final DateTime end = f.rangeEnd ?? f.rangeStart!;
      if (local.isBefore(f.rangeStart!) || !local.isBefore(end)) {
        return false;
      }
    } else if (f.day != null) {
      if (local.year != f.day!.year ||
          local.month != f.day!.month ||
          local.day != f.day!.day) {
        return false;
      }
    }
    // 金额区间（实付口径 = amount − discount）。
    final int net = t.amountMinor - t.discountMinor;
    if (f.minMinor != null && net < f.minMinor!) return false;
    if (f.maxMinor != null && net > f.maxMinor!) return false;
    // 备注包含（忽略大小写）。
    if (f.note != null && f.note!.isNotEmpty) {
      if (!(t.note ?? '').toLowerCase().contains(f.note!.toLowerCase())) {
        return false;
      }
    }
    // 收支类型（任一命中即可）。
    if (f.flowTypes.isNotEmpty) {
      final bool ok =
          (f.flowTypes.contains('支出') && t.type == TxnType.expense) ||
              (f.flowTypes.contains('收入') && t.type == TxnType.income);
      if (!ok) return false;
    }
    // 账单类型（任一命中即可）。
    if (f.billTypes.isNotEmpty) {
      bool ok = false;
      for (final String b in f.billTypes) {
        switch (b) {
          case '普通收支':
            ok = ok ||
                (t.sourceModule == SourceModule.ledger &&
                    t.type != TxnType.transfer);
          case '转账':
            ok = ok || t.type == TxnType.transfer;
          case '退款':
            ok = ok || t.sourceModule == SourceModule.refund;
          case '借款':
            ok = ok || t.sourceModule == SourceModule.lend;
          case '报销':
            ok = ok || (t.type == TxnType.expense && t.isReimbursable);
          case '报销收入':
            ok = ok ||
                (t.sourceModule == SourceModule.reimbursement &&
                    t.type == TxnType.income);
        }
      }
      if (!ok) return false;
    }
    // 账单来源（任一命中即可；直接按流水 source 标记匹配：手动记账 / 存钱计划 /
    // 分期记账 / 导入 / 自动同步）。
    if (mappedSources.isNotEmpty && !mappedSources.contains(t.source)) {
      return false;
    }
    // 账本限定（与当前账本相同时恒真，视为不限）。
    if (f.bookId != null && t.bookId != f.bookId) return false;
    // 分类 / 「其他」系统类目（任一命中即可）。
    // 分类命中：直接选中的分类 id，或流水分类的父分类 id（一级含子级）。
    if (f.categoryIds.isNotEmpty || f.others.isNotEmpty) {
      final Category? cat = t.categoryId == null ? null : catById[t.categoryId];
      bool ok = false;
      if (f.categoryIds.isNotEmpty && cat != null) {
        ok = f.categoryIds.contains(cat.id) ||
            (cat.parentId != null && f.categoryIds.contains(cat.parentId));
      }
      if (!ok && f.others.isNotEmpty) {
        for (final String o in f.others) {
          switch (o) {
            case '报销':
              ok = ok || (t.type == TxnType.expense && t.isReimbursable);
            case '报销收入':
              ok = ok ||
                  (t.sourceModule == SourceModule.reimbursement &&
                      t.type == TxnType.income);
            case '退款':
              ok = ok || t.sourceModule == SourceModule.refund;
            default:
              // 借还六类 / 转账三变体：按系统分类名命中。
              ok = ok || (cat != null && cat.name == o);
          }
        }
      }
      if (!ok) return false;
    }
    // 收支 / 预算计入口径。
    if (f.statsExclude != null && t.excludeFromStats != f.statsExclude) {
      return false;
    }
    if (f.budgetExclude != null && t.excludeFromBudget != f.budgetExclude) {
      return false;
    }
    // 标签命中（按名称；流水 tags 为 JSON 字符串数组）。
    // OR=含任一选中标签即可；AND=须含全部选中标签。
    if (f.tagNames.isNotEmpty) {
      final Set<String> txTags = ledgerTxnTagNames(t.tags);
      final bool hit = f.tagMatchAnd
          ? f.tagNames.every((String n) => txTags.contains(n))
          : f.tagNames.any((String n) => txTags.contains(n));
      if (!hit) return false;
    }
    // 账户（包含/不包含）。「未选择资产」= accountId 为空的游离账单。
    // 包含：命中任一选中账户（或勾选了游离账单且本单无账户）即可；
    // 不包含：排除选中的账户（及游离账单，若勾选）。
    if (f.hasAccountFilter) {
      final bool none = t.accountId.isEmpty;
      final bool hit =
          none ? f.accountIncludeNone : f.accountIds.contains(t.accountId);
      if (f.accountInclude ? !hit : hit) return false;
    }
    return true;
  }

  return all.where(match).toList(growable: true);
}
