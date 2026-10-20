import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pocket_ledger/theme/app_dimens.dart';
import '../../../core/theme/forest_design_tokens.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../features/ledger/data/transaction_repository.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/calendar_sheet.dart';
import '../../../shared/widgets/line_icon_map.dart';
import '../../../shared/widgets/line_icons.dart';
import '../../../shared/widgets/sheet_scaffold.dart';
import '../../../theme/app_colors.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../installment/data/installment_repository.dart';
import '../../installment/providers/installment_providers.dart';
import '../../investment/data/investment_repository.dart';
import '../../investment/providers/investment_providers.dart';
import '../../lend/providers/lend_providers.dart';
import '../../savings/data/savings_repository.dart';
import '../../savings/providers/savings_providers.dart';
import '../data/bill_io.dart';
import '../providers/ledger_providers.dart';

/// 把存储的标签 JSON 字符串解码回标签列表（容错：非列表 / 空串 / 异常返回空）。
List<String> _decodeTags(String? json) {
  if (json == null || json.isEmpty) return const <String>[];
  try {
    final Object? decoded = jsonDecode(json);
    if (decoded is List) return decoded.cast<String>();
  } catch (_) {
    // 历史脏数据不应让导出中断。
  }
  return const <String>[];
}

/// 导出「分类」列名：交易挂在二级分类（parentId 非空）时出**一级**（父）名。
///
/// 与导入侧的「子分类」列结构化配套：二级名走子分类列，一级名走分类列，
/// 保证「导出 → 再导入」往返不自漂移（否则二级名会被当成一级名新建）。
String? _exportCategoryName(Map<String, Category> catMap, String? categoryId) {
  if (categoryId == null) return null;
  final Category? cat = catMap[categoryId];
  if (cat == null) return null;
  if (cat.parentId != null) {
    return catMap[cat.parentId]?.name ?? cat.name;
  }
  return cat.name;
}

/// 导出「子分类」列名：二级分类交易始终还带二级名（导入侧据此挂回二级）；
/// 原文本非空则优先保留（用户手填的自由文本标签）。
String? _exportSubcategoryName(
  Map<String, Category> catMap,
  String? categoryId,
  String? subcategory,
) {
  if (subcategory != null && subcategory.trim().isNotEmpty) return subcategory;
  if (categoryId != null) {
    final Category? cat = catMap[categoryId];
    if (cat != null && cat.parentId != null) return cat.name;
  }
  return subcategory;
}

/// 从投资买卖流水备注（`买入-名称\n份额 · 单价 · 手续费 [用户备注]`）提取用户备注，
/// 即第三行及之后内容；无则返回 null。
String? _investUserNote(String? note) {
  if (note == null) return null;
  final List<String> lines = note.split('\n');
  if (lines.length <= 2) return null;
  final String rest = lines.skip(2).join('\n').trim();
  return rest.isEmpty ? null : rest;
}

/// 把「分」(int) 表示的金额格式化为「元」字符串，去除尾随多余的 0 与小数点。
/// 例：123 → '1.23'、120 → '1.2'、100 → '1'、5 → '0.05'。
String _fmtPrice(int minor) {
  final String s = (minor / 100).toStringAsFixed(2);
  return s.replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
}

/// 「账单管理 → 账单导出」页。
///
/// 对标小青账版式（2026-10-20）：头部卡（图标 + 标题，无帮助键）→ 信息条 →
/// 「时间选择」卡（开始/结束时间，默认本月 1 日 ~ 今天，点选拉起共享组件
/// [CalendarSheet]）→ 底部渐变按钮「选择导出方式」拉起共享弹层外壳
/// AppModalSheet（CSV / JSON 格式选择 + 保存为文件；空白模板下载在导入侧）。
/// 导出内容 = 所选时间范围内的全部账单（含转账），仅走文件导出/导入通道，
/// 无文本预览/复制输出框。不依赖系统分享组件，在 iOS 沙盒下也能稳定工作。
class BillExportPage extends ConsumerStatefulWidget {
  const BillExportPage({super.key});

  @override
  ConsumerState<BillExportPage> createState() => _BillExportPageState();
}

class _BillExportPageState extends ConsumerState<BillExportPage> {
  bool _asJson = false;
  bool _busy = false;

  /// 导出时间范围（本地日）。默认本月 1 日 ~ 今天，对标小青账「时间选择」。
  late DateTime _start = DateTime(DateTime.now().year, DateTime.now().month, 1);
  late DateTime _end = DateTime.now();

  /// 选日期：统一走共享组件 [CalendarSheet]（纯日模式：无时间拨盘；保留
  /// 「自定义」区间 chip——选区间则同时写入开始/结束）。单选日时保证结束
  /// 不早于开始。
  Future<void> _pickDate({required bool isStart}) async {
    final DateTime initial = isStart ? _start : _end;
    final CalendarSelection? picked = await CalendarSheet.show(
      context,
      mode: CalendarSheetMode.day,
      initialDate: initial,
      headerTitle: isStart ? '选择开始时间' : '选择结束时间',
      showTime: false,
      showCustomRange: true,
      weekStart: CalendarWeekStart.monday,
    );
    if (picked is CalendarRange) {
      setState(() {
        _start = picked.start;
        _end = picked.end;
      });
      return;
    }
    if (picked is! CalendarDay) return;
    final DateTime day = picked.date;
    setState(() {
      if (isStart) {
        _start = day;
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = day;
        if (_end.isBefore(_start)) _start = _end;
      }
    });
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final List<Transaction> txns =
          await ref.read(bookAllTransactionsProvider.future);
      final List<Account> accounts = await ref.read(accountsProvider.future);
      final Map<String, Category> catMap =
          await ref.read(categoryMapProvider.future);
      final List<Book> books = await ref.read(booksListProvider.future);

      final Map<String, String> accountNames = <String, String>{};
      for (final Account a in accounts) {
        accountNames[a.id] = a.name;
      }
      // 导出为当前账本的数据，账本列填当前账本名，便于再次导入时归户一致。
      final String currentBookId = ref.read(currentBookIdProvider);
      String? currentBookName;
      for (final Book b in books) {
        if (b.id == currentBookId) {
          currentBookName = b.name;
          break;
        }
      }

      // 借还流水（sourceModule=lend）的「对方」来自关联的借还记录——建
      // relatedId → counterparty 映射，使导出 → 再导入能无损往返落到借还台账。
      final Map<String, String> lendCounterparty = <String, String>{};
      if (txns.any((Transaction t) => t.sourceModule == SourceModule.lend)) {
        final List<LendRecord> lendRecords =
            await ref.read(lendRepositoryProvider).watch(currentBookId).first;
        for (final LendRecord r in lendRecords) {
          lendCounterparty[r.id] = r.counterparty;
        }
      }

      // 储蓄台账（Phase 2）：导出按台账逐笔回写，保证「导出 → 再导入」无损往返。
      // 期次存入台账的 relatedId = '${goalId}#${dayIndex}'；其余储蓄流水
      // （灵活存入 relatedId=goalId、取出 #withdraw 等）不在台账内，单独按流水回写。
      final Map<String, String> savingsGoalNameById = <String, String>{};
      final Set<String> handledSavingsRelated = <String>{};
      final List<SavingsDeposit> savingsLedger = <SavingsDeposit>[];
      if (txns.any((Transaction t) => t.sourceModule == SourceModule.savings)) {
        final SavingsRepository sRepo = ref.read(savingsRepositoryProvider);
        final List<SavingsGoal> goals = await sRepo.watch(currentBookId).first;
        for (final SavingsGoal g in goals) {
          savingsGoalNameById[g.id] = g.name;
        }
        for (final SavingsGoal g in goals) {
          final List<SavingsDeposit> deps =
              await sRepo.watchDeposits(g.id).first;
          savingsLedger.addAll(deps);
          for (final SavingsDeposit d in deps) {
            handledSavingsRelated.add('${g.id}#${d.dayIndex}');
          }
        }
      }

      final TransactionRepository txnRepo =
          ref.read(transactionRepositoryProvider);

      final List<BillRow> rows = <BillRow>[];
      // 普通交易（含借还/报销等）：储蓄与分期流水改由下方按台账/流水单独回写，此处跳过。
      for (final Transaction t in txns) {
        if (t.sourceModule == SourceModule.savings) continue;
        if (t.sourceModule == SourceModule.installment) continue;
        if (t.sourceModule == SourceModule.investment) continue;
        rows.add(
          BillRow(
            occurredAt:
                DateTime.fromMillisecondsSinceEpoch(t.occurredAt, isUtc: true)
                    .toLocal(),
            module: t.sourceModule,
            type: t.type,
            amountMinor: t.amountMinor,
            accountName: accountNames[t.accountId] ?? '未知账户',
            toAccountName: t.toAccountId == null
                ? null
                : accountNames[t.toAccountId] ?? '未知账户',
            discountMinor: t.discountMinor,
            feeMinor: t.feeMinor,
            subcategoryName:
                _exportSubcategoryName(catMap, t.categoryId, t.subcategory),
            categoryName: _exportCategoryName(catMap, t.categoryId),
            tags: _decodeTags(t.tags),
            book: currentBookName,
            isReimbursable: t.isReimbursable,
            reimbursementAccount: t.reimbursementAccountId == null
                ? null
                : accountNames[t.reimbursementAccountId],
            excludeFromBudget: t.excludeFromBudget,
            excludeFromStats: t.excludeFromStats,
            note: t.note,
            currency: t.currency,
            counterparty:
                t.sourceModule == SourceModule.lend && t.relatedId != null
                    ? lendCounterparty[t.relatedId]
                    : null,
          ),
        );
      }

      // 储蓄期次台账逐笔回写：优先用联动流水还原 类型/账户/日期；无联动流水（纯台账
      // 灵活存入）则默认支出、账户留空。toAccountName = 计划名（导入「转入账户」）。
      for (final SavingsDeposit d in savingsLedger) {
        final String goalName = savingsGoalNameById[d.goalId] ?? '储蓄计划';
        final String relatedId = '${d.goalId}#${d.dayIndex}';
        final Transaction? linked = await txnRepo.getByRelatedId(relatedId);
        final DateTime date;
        final TxnType type;
        final String accountName;
        final String? note;
        final int discountMinor;
        final List<String> tags;
        final bool excludeFromBudget;
        final bool excludeFromStats;
        final String currency;
        if (linked != null) {
          date = DateTime.fromMillisecondsSinceEpoch(linked.occurredAt,
                  isUtc: true)
              .toLocal();
          type = linked.type;
          accountName = accountNames[linked.accountId] ?? '未知账户';
          note = linked.note;
          discountMinor = linked.discountMinor;
          tags = _decodeTags(linked.tags);
          excludeFromBudget = linked.excludeFromBudget;
          excludeFromStats = linked.excludeFromStats;
          currency = linked.currency;
        } else {
          // 纯台账灵活存入：无联动流水，类型默认支出、账户留空，日期取台账存入时间。
          date = DateTime.fromMillisecondsSinceEpoch(d.depositedAt, isUtc: true)
              .toLocal();
          type = TxnType.expense;
          accountName = '';
          note = d.note ?? '$goalName第${d.dayIndex}期';
          discountMinor = 0;
          tags = const <String>[];
          excludeFromBudget = false;
          excludeFromStats = false;
          currency = 'CNY';
        }
        rows.add(
          BillRow(
            occurredAt: date,
            module: SourceModule.savings,
            type: type,
            amountMinor: d.amountMinor,
            accountName: accountName,
            toAccountName: goalName,
            discountMinor: discountMinor,
            categoryName: null,
            tags: tags,
            book: currentBookName,
            isReimbursable: false,
            reimbursementAccount: null,
            excludeFromBudget: excludeFromBudget,
            excludeFromStats: excludeFromStats,
            note: note,
            currency: currency,
            counterparty: null,
          ),
        );
      }

      // 其余储蓄流水（灵活存入 relatedId=goalId、取出 #withdraw 等，不在台账内）：
      // 按流水逐笔回写，toAccountName = 计划名，保证导出 → 再导入仍能路由回同一目标。
      for (final Transaction t in txns) {
        if (t.sourceModule != SourceModule.savings) continue;
        if (t.relatedId == null) continue;
        if (handledSavingsRelated.contains(t.relatedId)) continue;
        final String goalId = t.relatedId!.split('#').first;
        final String goalName = savingsGoalNameById[goalId] ?? '储蓄计划';
        rows.add(
          BillRow(
            occurredAt:
                DateTime.fromMillisecondsSinceEpoch(t.occurredAt, isUtc: true)
                    .toLocal(),
            module: SourceModule.savings,
            type: t.type,
            amountMinor: t.amountMinor,
            accountName: accountNames[t.accountId] ?? '未知账户',
            toAccountName: goalName,
            discountMinor: t.discountMinor,
            categoryName: null,
            tags: _decodeTags(t.tags),
            book: currentBookName,
            isReimbursable: t.isReimbursable,
            reimbursementAccount: t.reimbursementAccountId == null
                ? null
                : accountNames[t.reimbursementAccountId],
            excludeFromBudget: t.excludeFromBudget,
            excludeFromStats: t.excludeFromStats,
            note: t.note,
            currency: t.currency,
            counterparty: null,
          ),
        );
      }

      // 分期台账（Phase 2）：导出按计划逐期回写，保证「导出 → 再导入」无损往返。
      // 期次还款转账 relatedId = '${period.id}#repay'；还款转账类型=转账、账户=扣款账户、
      // toAccount=负债付款账户、备注=计划名（与导入分组键一致）。「分期订单」支出由
      // 导入时 addPlan 自动 postDuePeriods 重建，此处不写。
      if (txns
          .any((Transaction t) => t.sourceModule == SourceModule.installment)) {
        final InstallmentRepository instRepo =
            ref.read(installmentRepositoryProvider);
        final List<InstallmentPlan> instPlans =
            await instRepo.watchPlans(currentBookId).first;
        for (final InstallmentPlan p in instPlans) {
          final String liabilityName = accountNames[p.accountId] ?? '负债付款账户';
          final List<InstallmentPeriod> instPeriods =
              await instRepo.watchPeriods(p.id).first;
          for (final InstallmentPeriod period in instPeriods) {
            final Transaction? repay =
                await txnRepo.getByRelatedId('${period.id}#repay');
            final DateTime date;
            final int amountMinor;
            final String accountName;
            final int discountMinor;
            final List<String> tags;
            final bool excludeFromBudget;
            final bool excludeFromStats;
            final String currency;
            if (repay != null) {
              date = DateTime.fromMillisecondsSinceEpoch(repay.occurredAt,
                      isUtc: true)
                  .toLocal();
              amountMinor = repay.amountMinor;
              accountName = accountNames[repay.accountId] ?? '未知账户';
              discountMinor = repay.discountMinor;
              tags = _decodeTags(repay.tags);
              excludeFromBudget = repay.excludeFromBudget;
              excludeFromStats = repay.excludeFromStats;
              currency = repay.currency;
            } else {
              // 理论不会发生：导入必建还款转账；兜底写期次本身（无扣款账户）。
              date =
                  DateTime.fromMillisecondsSinceEpoch(period.dueAt, isUtc: true)
                      .toLocal();
              amountMinor = period.amountMinor;
              accountName = '';
              discountMinor = 0;
              tags = const <String>[];
              excludeFromBudget = false;
              excludeFromStats = false;
              currency = 'CNY';
            }
            rows.add(
              BillRow(
                occurredAt: date,
                module: SourceModule.installment,
                type: TxnType.transfer,
                amountMinor: amountMinor,
                accountName: accountName,
                toAccountName: liabilityName,
                discountMinor: discountMinor,
                categoryName: null,
                tags: tags,
                book: currentBookName,
                isReimbursable: false,
                reimbursementAccount: null,
                excludeFromBudget: excludeFromBudget,
                excludeFromStats: excludeFromStats,
                note: p.title,
                currency: currency,
                counterparty: null,
              ),
            );
          }
        }
      }

      // 投资台账（Phase 2）：按持仓遍历买卖流水无损还原，保证「导出 → 再导入」往返。
      // 买卖流水 relatedId = 持仓 id、sourceModule = investment；备注含
      // `买入-名称\n份额 · 单价 · 手续费 [用户备注]`（与 [_InvestNote] 同源）。导出回写：
      // 模块=投资、类型=支出(买入)/收入(卖出)、对方=证券代码、分类=品种类型(label)、
      // 备注=`名称@单价`(+ 用户备注)、手续费=feeMinor（独立于优惠列，避免混写）；金额
      // 还原为「成交净金额」（买入流水额含费 → 减费；卖出流水额已扣费 → 加费），
      // 使再导入份额精确还原。
      if (txns
          .any((Transaction t) => t.sourceModule == SourceModule.investment)) {
        final InvestmentRepository investRepo =
            ref.read(investmentRepositoryProvider);
        final List<InvestmentHolding> holdings =
            await investRepo.watch(currentBookId).first;
        for (final InvestmentHolding h in holdings) {
          final List<Transaction> flows = await investRepo.getFlows(h.id);
          for (final Transaction f in flows) {
            final (int rawPrice, int rawFee, int rawQty) =
                InvestmentRepository.parseTradeMeta(f.note) ?? (0, 0, 0);
            // 手续费（优惠列）：优先从流水备注元信息反解，反解失败按 0 兜底。
            final int fee = rawFee;
            // 还原成交净金额：买入流水额含费 → 减费；卖出流水额已扣费 → 加费。
            final int amountMinor = f.type == TxnType.expense
                ? f.amountMinor - fee
                : f.amountMinor + fee;
            // 反解失败（旧数据/备注被改，price=0）时兜底取持仓成本/现价，保证仍能往返。
            final int price = rawPrice > 0
                ? rawPrice
                : (f.type == TxnType.expense
                    ? h.avgCostMinor
                    : h.currentPriceMinor);
            // 用户备注：流水备注第三行（_investNote 格式）。
            final String? userNote = _investUserNote(f.note);
            final String note = userNote == null || userNote.isEmpty
                ? '${h.name}@${_fmtPrice(price)}'
                : '${h.name}@${_fmtPrice(price)} $userNote';
            rows.add(
              BillRow(
                occurredAt: DateTime.fromMillisecondsSinceEpoch(f.occurredAt,
                        isUtc: true)
                    .toLocal(),
                module: SourceModule.investment,
                type: f.type,
                amountMinor: amountMinor,
                accountName: accountNames[f.accountId] ?? '未知账户',
                toAccountName: null,
                feeMinor: fee,
                categoryName: h.type.label,
                tags: const <String>[],
                book: currentBookName,
                isReimbursable: false,
                reimbursementAccount: null,
                excludeFromBudget: true,
                excludeFromStats: true,
                note: note,
                currency: 'CNY',
                counterparty: h.symbol,
              ),
            );
          }
        }
      }

      // 仅导出所选时间范围内的账单（本地日，含起止当天）。
      final DateTime startDay = DateTime(_start.year, _start.month, _start.day);
      final DateTime endDay = DateTime(_end.year, _end.month, _end.day);
      rows.retainWhere((BillRow r) {
        final DateTime day =
            DateTime(r.occurredAt.year, r.occurredAt.month, r.occurredAt.day);
        return !day.isBefore(startDay) && !day.isAfter(endDay);
      });
      if (rows.isEmpty) {
        if (mounted) showAppToast(context, '所选时间范围内没有账单');
        return;
      }

      final String content = _asJson ? buildJson(rows) : buildCsv(rows);

      final String stamp = _timeStamp();
      final String ext = _asJson ? 'json' : 'csv';
      // 弹系统「存储到文件」面板：用户自选本地路径与文件名，直接落盘。
      // file_picker 8.x：Android/iOS 的 saveFile 必须直接传 bytes（由系统
      // 面板落盘，返回保存路径）；桌面端才返回所选路径、需自行写文件。
      final bool isMobile = Platform.isAndroid || Platform.isIOS;
      final String? picked = await FilePicker.platform.saveFile(
        dialogTitle: '保存账单导出',
        fileName: '账单导出_$stamp.$ext',
        allowedExtensions: isMobile ? null : <String>[ext],
        bytes: isMobile ? Uint8List.fromList(utf8.encode(content)) : null,
      );
      if (picked == null) {
        if (mounted) showAppToast(context, '已取消保存');
        return;
      }
      String outPath = picked;
      if (!isMobile) {
        // 桌面保存面板不强制扩展名，缺失时补足，避免存成无后缀文件。
        outPath =
            picked.toLowerCase().endsWith('.$ext') ? picked : '$picked.$ext';
        await File(outPath).writeAsString(content);
      }
      if (mounted) showAppToast(context, '已保存到文件');
    } catch (e) {
      if (mounted) showAppToast(context, '导出失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _timeStamp() {
    final DateTime now = DateTime.now();
    String p(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${p(now.month)}${p(now.day)}_${p(now.hour)}${p(now.minute)}${p(now.second)}';
  }

  /// 下载空白填写模板已迁至「账单导入」配置页（信息卡「模板」胶囊，
  /// 2026-10-20 起）：模板属导入前置物料，导出页只保留数据导出本身。

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账单导出'),
        centerTitle: true,
        leading: const BackButton(),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.lg,
                AppDimens.md,
                AppDimens.lg,
                AppDimens.lg,
              ),
              children: <Widget>[
                _headerCard(),
                const SizedBox(height: AppDimens.sm),
                _infoStrip(),
                const SizedBox(height: AppDimens.sm),
                _timeRangeCard(),
              ],
            ),
          ),
          _actionBar(),
        ],
      ),
    );
  }

  /// 头部卡（对标小青账）：鼠尾草绿渐变 + 图标 + 标题/副标题，无帮助键。
  Widget _headerCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: ForestGradients.sage,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      padding: const EdgeInsets.all(AppDimens.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppPalette.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: const Center(
              child: LineIcon(
                LineIconKind.send,
                size: 24,
                color: AppPalette.white,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '账单导出',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '导出当前账本账单，便于备份与迁移',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppPalette.white.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 信息条（替代原绿色解释盒）：一句话说明用途，保持极简。
  Widget _infoStrip() {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.softGreen,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.md,
        vertical: AppDimens.sm,
      ),
      child: Row(
        children: <Widget>[
          const LineIcon(
            LineIconKind.info,
            size: 16,
            color: AppPalette.sageRibbon,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '导出所选时间范围内的全部账单（含转账），支持 CSV / JSON。',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 时间选择卡（对标小青账「时间选择」）：开始 / 结束时间两行，点击拉起
  /// 中文本地化日期选择器。默认本月 1 日 ~ 今天（见 [_start]/[_end]）。
  Widget _timeRangeCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '时间范围',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          _timeRow(
            label: '开始时间',
            date: _start,
            onTap: () => _pickDate(isStart: true),
          ),
          const Divider(height: 1, indent: 16, color: AppPalette.divider),
          _timeRow(
            label: '结束时间',
            date: _end,
            onTap: () => _pickDate(isStart: false),
          ),
        ],
      ),
    );
  }

  Widget _timeRow({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    final DateFormat fmt = DateFormat('yyyy年M月d日');
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    fmt.format(date),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const LineGlyph(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _formatRow({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppPalette.ctaGreen : AppPalette.divider,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppPalette.ctaGreen,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.lg,
        AppDimens.sm,
        AppDimens.lg,
        AppDimens.lg,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: ForestGradients.button,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            boxShadow: ForestElevation.float,
          ),
          child: Material(
            color: Colors.transparent, // ignore: no_raw_colors
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              onTap: _showExportSheet,
              child: const Center(
                child: Text(
                  '选择导出方式',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 底部弹层（共享外壳 AppModalSheet，2026-10-20）：CSV / JSON 格式选择 +
  /// 保存为文件。格式选择用 [StatefulBuilder] 即时刷新选中态。
  Future<void> _showExportSheet() async {
    await showAppModalSheet<void>(
      context,
      title: '导出格式',
      isScrollControlled: true,
      body: StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _formatRow(
                title: 'CSV 表格',
                subtitle: '用 Excel / Numbers 打开，便于查看与二次编辑',
                selected: !_asJson,
                onTap: () {
                  setState(() => _asJson = false);
                  setSheetState(() {});
                },
              ),
              const Divider(height: 1, color: AppPalette.divider),
              _formatRow(
                title: 'JSON 数据',
                subtitle: '保留完整字段，便于与本 App 再次导入往返',
                selected: _asJson,
                onTap: () {
                  setState(() => _asJson = true);
                  setSheetState(() {});
                },
              ),
              const SizedBox(height: AppDimens.md),
              _sheetActionRow(
                icon: Icons.save_outlined,
                label: '保存为文件',
                onTap: () {
                  Navigator.pop(ctx);
                  _export();
                },
                busy: _busy,
              ),
            ],
          );
        },
      ),
    );
  }

  /// 弹层内的操作行（线稿图标 + 文字），统一描边绿胶囊按钮。
  Widget _sheetActionRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool busy = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimens.sm),
      child: SizedBox(
        width: double.infinity,
        height: 46,
        child: OutlinedButton.icon(
          onPressed: busy ? null : onTap,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppPalette.ctaGreen,
                  ),
                )
              : LineGlyph(icon, size: 18),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppPalette.ctaGreen,
            side: const BorderSide(color: AppPalette.ctaGreen),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
          ),
        ),
      ),
    );
  }
}
