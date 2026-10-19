import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pocket_ledger/theme/app_dimens.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/line_icon_map.dart';
import '../../../theme/app_colors.dart';
import '../../../features/ledger/data/transaction_repository.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../lend/providers/lend_providers.dart';
import '../../savings/data/savings_repository.dart';
import '../../savings/providers/savings_providers.dart';
import '../../installment/data/installment_repository.dart';
import '../../installment/providers/installment_providers.dart';
import '../../investment/data/investment_repository.dart';
import '../../investment/providers/investment_providers.dart';
import '../data/bill_io.dart';
import '../data/bill_template.dart';
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
/// 把当前账本全部账单（含转账）导出为 CSV / JSON：写入应用 Documents 目录，
/// 并支持一键复制文本内容（用于粘贴到微信 / 备忘录等）。不依赖系统分享组件，
/// 在 iOS 沙盒下也能稳定工作。
class BillExportPage extends ConsumerStatefulWidget {
  const BillExportPage({super.key});

  @override
  ConsumerState<BillExportPage> createState() => _BillExportPageState();
}

class _BillExportPageState extends ConsumerState<BillExportPage> {
  bool _asJson = false;
  bool _busy = false;
  String? _content;
  String? _path;
  int _count = 0;

  /// 当前 [_content] 是否为空白模板（影响结果卡徽标文案）。
  bool _isTemplate = false;

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
      final Map<String, String> lendCounterparty =
          <String, String>{};
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
        final List<SavingsGoal> goals =
            await sRepo.watch(currentBookId).first;
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
            subcategoryName: t.subcategory,
            categoryName:
                t.categoryId == null ? null : catMap[t.categoryId]?.name,
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
            counterparty: t.sourceModule == SourceModule.lend &&
                    t.relatedId != null
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
          date = DateTime.fromMillisecondsSinceEpoch(d.depositedAt,
                  isUtc: true)
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
      if (txns.any((Transaction t) => t.sourceModule == SourceModule.installment)) {
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
              date = DateTime.fromMillisecondsSinceEpoch(period.dueAt,
                      isUtc: true)
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
      if (txns.any((Transaction t) => t.sourceModule == SourceModule.investment)) {
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

      setState(() {
        _content = content;
        _path = outPath;
        _count = rows.length;
        _isTemplate = false;
      });
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

  /// 下载空白填写模板：含字段说明注释行 + 表头，格式跟随上方选择
  /// （CSV / JSON）。模板系统（2026-10-18）：导出与导入共用同一套字段规范。
  Future<void> _downloadTemplate() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final String content = _asJson ? buildTemplateJson() : buildTemplateCsv();
      final String ext = _asJson ? 'json' : 'csv';
      // file_picker 8.x：Android/iOS 的 saveFile 必须直接传 bytes（由系统
      // 面板落盘，返回保存路径）；桌面端才返回所选路径、需自行写文件。
      final bool isMobile = Platform.isAndroid || Platform.isIOS;
      final String? picked = await FilePicker.platform.saveFile(
        dialogTitle: '保存账单导入模板',
        fileName: '账单导入模板.$ext',
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
      setState(() {
        _content = content;
        _path = outPath;
        _count = 0;
        _isTemplate = true;
      });
      if (mounted) showAppToast(context, '模板已保存，按说明填写后可导入');
    } catch (e) {
      if (mounted) showAppToast(context, '模板保存失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    if (_content == null) return;
    await Clipboard.setData(ClipboardData(text: _content!));
    if (mounted) showAppToast(context, '已复制全部内容');
  }

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
                _formatCard(),
                const SizedBox(height: AppDimens.sm),
                // 模板系统（2026-10-18）：提供统一空白模板供用户填写，
                // 与导出字段结构一致，导入时按分类/账户/时间自动匹配校验。
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _downloadTemplate,
                    icon: const LineGlyph(Icons.download_outlined, size: 18),
                    label: const Text('下载空白填写模板（含字段说明）'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppPalette.ctaGreen,
                      side: const BorderSide(color: AppPalette.ctaGreen),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.md),
                Container(
                  decoration: BoxDecoration(
                    color: AppPalette.softGreen,
                    borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                  ),
                  padding: const EdgeInsets.all(AppDimens.md),
                  child: Text(
                    '导出当前账本全部账单（含转账）。点「保存到文件」选本地位置存为 '
                    'CSV / JSON 文件；下方「复制内容」可把文本粘贴到微信 / 备忘录等作他用。',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
                if (_content != null) ...<Widget>[
                  const SizedBox(height: AppDimens.lg),
                  _resultCard(),
                ],
              ],
            ),
          ),
          _actionBar(),
        ],
      ),
    );
  }

  Widget _formatCard() {
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
              '导出格式',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          _formatRow(
            title: 'CSV 表格',
            subtitle: '用 Excel /  Numbers 打开，便于查看与二次编辑',
            selected: !_asJson,
            onTap: () => setState(() => _asJson = false),
          ),
          const Divider(height: 1, indent: 16, color: AppPalette.divider),
          _formatRow(
            title: 'JSON 数据',
            subtitle: '保留完整字段，便于与本 App 再次导入往返',
            selected: _asJson,
            onTap: () => setState(() => _asJson = true),
          ),
        ],
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

  Widget _resultCard() {
    final List<String> lines = _content!.split('\n');
    final String preview = lines.length > 60
        ? '${lines.take(60).join('\n')}\n…（共 ${lines.length} 行）'
        : _content!;
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      padding: const EdgeInsets.all(AppDimens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppPalette.softGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _isTemplate ? '空白模板' : '已导出 $_count 笔',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.ctaGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.sm),
          SelectableText(
            _path ?? '',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimens.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimens.sm),
            decoration: BoxDecoration(
              color: AppPalette.graySurface,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: SelectableText(
              preview,
              style: TextStyle(
                fontSize: 11.5,
                fontFamily: 'RobotoMono',
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: AppDimens.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _copy,
              icon: const LineGlyph(Icons.copy_outlined, size: 18),
              label: const Text('复制全部内容'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppPalette.ctaGreen,
                side: const BorderSide(color: AppPalette.ctaGreen),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
              ),
            ),
          ),
        ],
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
        child: ElevatedButton(
          onPressed: _busy ? null : _export,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppPalette.ctaGreen,
            foregroundColor: AppPalette.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
          ),
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppPalette.white,
                  ),
                )
              : const Text('保存到文件'),
        ),
      ),
    );
  }
}
