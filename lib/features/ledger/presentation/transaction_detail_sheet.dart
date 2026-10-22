import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pocket_ledger/core/utils/note_utils.dart';
import 'package:pocket_ledger/shared/widgets/clay_icon_tile.dart';
import 'package:pocket_ledger/shared/widgets/confirm_dialog.dart';
import 'package:pocket_ledger/shared/widgets/hairline_card.dart';
import 'package:pocket_ledger/shared/widgets/info_kv_row.dart';
import 'package:pocket_ledger/shared/widgets/location_map_sheet.dart';
import 'package:pocket_ledger/shared/widgets/sheet_scaffold.dart';
import 'package:pocket_ledger/shared/widgets/sunken_box.dart';
import 'package:pocket_ledger/theme/app_theme.dart';

import '../../../core/errors/failures.dart';
import '../../../core/theme/forest_design_tokens.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/line_icons.dart';
import '../../../theme/app_colors.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../lend/providers/lend_providers.dart';
import '../../record/presentation/record_sheet.dart';
import '../../record/record_tab.dart';
import '../../reimbursement/data/reimbursement_repository.dart';
import '../../reimbursement/presentation/reimbursement_record_sheet.dart';
import '../../reimbursement/providers/reimbursement_providers.dart';
import '../providers/ledger_providers.dart';
import 'widgets/txn_icon.dart';

/// 流水详情底部弹窗 · B1「Hero 聚焦查看」落地版（ForestSage 暖纸皮肤）。
///
/// 布局：顶部下拉把手（无 ✕ 关闭键）+ 鼠尾草渐变 Hero 卡（分类 / 大金额 / 概要 /
/// 标记）+ 三张独立明细卡（账单 / 附件 / 报销·退款）。
/// 交互：类目可点跳转类目页、资产账户可点跳转资产页、退款/报销按钮跳转对应页；
/// 下拉把手或点击弹窗外空白即可关闭；无底部保存键（修改走顶部 ✎ 跳转编辑页）。
class TransactionDetailSheet extends ConsumerWidget {
  const TransactionDetailSheet({super.key, required this.transaction});

  final Transaction transaction;

  static Future<void> show(BuildContext context, Transaction transaction) {
    // 挂在 Tab 分支导航器上（不用根导航器）；registerWithSheetRegistry 让
    // AppShell 切 Tab 时 closeAll() 统一收起，并在弹层打开期间隐藏底部导航栏。
    return showAppModalSheet<void>(
      context,
      isScrollControlled: true,
      registerWithSheetRegistry: true,
      bodyPadding: EdgeInsets.zero,
      body: TransactionDetailSheet(transaction: transaction),
    );
  }

  // —— 设计稿固定尺寸（CSS → Flutter，单位 px→dp，保持与设计稿一致）——
  static const double _kHeroAmt = 40; // .hero-amt 40px（衬线大字）
  static const double _kBody = 14; // .kv / 正文 14px
  static const double _kSection = 13; // .list-title 13px

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Map<String, Category> categories =
        ref.watch(categoryMapProvider).valueOrNull ?? <String, Category>{};
    final AsyncValue<List<Account>> accountsAsync = ref.watch(accountsProvider);
    final Book? book = ref.watch(currentBookProvider).valueOrNull;

    final Category? category = categories[transaction.categoryId];
    final Map<String, Account> accounts = <String, Account>{
      for (final Account a in accountsAsync.valueOrNull ?? <Account>[]) a.id: a,
    };
    final Account? account = accounts[transaction.accountId];

    final DateTime occurred = DateTime.fromMillisecondsSinceEpoch(
      transaction.occurredAt,
      isUtc: true,
    ).toLocal();
    final Money money = Money.fromMinor(transaction.amountMinor);

    final List<String> tags = _parseJsonList(transaction.tags);
    final List<String> attachments = _parseJsonList(transaction.attachmentUrls);

    final bool reimbursable = transaction.isReimbursable;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildHero(
                    context: context,
                    ref: ref,
                    category: category,
                    money: money,
                    occurred: occurred,
                    book: book,
                    account: account,
                  ),
                  const SizedBox(height: 14),
                  // 卡片一 · 账单
                  _buildBillCard(
                    context: context,
                    ref: ref,
                    money: money,
                    occurred: occurred,
                    book: book,
                    account: account,
                    category: category,
                    tags: tags,
                  ),
                  if (attachments.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 14),
                    // 卡片二 · 附件
                    _buildAttachmentCard(context, attachments),
                  ],
                  // 位置：不再单设卡片，合并进「账单」卡备注上方一行。
                  // 借还模块流水（借出本金 / 还债 / 债务消减 / 坏账计提）
                  // 不显示报销 / 退款卡：债务备忘没有报销与退款语义。
                  // 投资模块买卖流水同理：买入卖出没有退款语义。
                  if (transaction.type == TxnType.expense &&
                      transaction.sourceModule != SourceModule.lend &&
                      transaction.sourceModule !=
                          SourceModule.investment) ...<Widget>[
                    const SizedBox(height: 14),
                    // 卡片三 · 报销 / 退款
                    _buildReimbRefundCard(
                      context: context,
                      ref: ref,
                      reimbursable: reimbursable,
                      money: money,
                      categories: categories,
                      accounts: accounts,
                    ),
                  ],
                  // 卡片四 · 报销收入的关联账单（报销模块收入流水专属）。
                  if (transaction.type == TxnType.income &&
                      transaction.sourceModule == SourceModule.reimbursement)
                    _buildReimbLinkedCard(context, ref),
                  // 卡片五 · 源账单（退款流水专属）：展示关联的原账单，
                  // 点击跳原账单详情（对齐小青账「源账单 · 关联」）。
                  if (transaction.type == TxnType.income &&
                      transaction.sourceModule == SourceModule.refund &&
                      transaction.relatedId != null)
                    _buildRefundSourceCard(context, ref),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero（鼠尾草渐变卡）────────────────────────────

  Widget _buildHero({
    required BuildContext context,
    required WidgetRef ref,
    required Category? category,
    required Money money,
    required DateTime occurred,
    required Book? book,
    required Account? account,
  }) {
    // 储蓄存入/取出按方向走储蓄罐线稿（系统分类「存款」无 iconKey，不走判定
    // 会退回星形兜底）；其余流水走全量兜底解析（分类缺行/缺 iconKey 时按
    // 模块/系统分类名/备注前缀/类型给线稿），任何流水不再退 Material。
    final LineIconKind tileKind = resolveTxnLineIcon(transaction, category);

    final List<Widget> chips = <Widget>[];
    if (transaction.type == TxnType.expense && transaction.discountMinor > 0) {
      chips.add(
        _HeroChip(
          label: '优惠 -${Money.fromMinor(transaction.discountMinor).format()}',
        ),
      );
    }
    if (transaction.excludeFromStats) {
      chips.add(const _HeroChip(label: '不计收支', warn: true));
    }
    if (transaction.excludeFromBudget) {
      chips.add(const _HeroChip(label: '不计预算', warn: true));
    }

    final String summary = <String>[
      DateFormat('yyyy-MM-dd HH:mm').format(occurred),
      book?.name ?? '默认账本',
      account?.name ?? '无',
    ].join(' · ');

    return HairlineCard(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      radius: 24,
      shadows: ForestElevation.card,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // 角落 ❦ 水印（奶油卡上用浅鼠尾草调）
          Positioned(
            right: -8,
            bottom: -22,
            child: Text(
              '❦',
              style: TextStyle(
                fontSize: 110,
                color: AppPalette.ctaGreen.withValues(alpha: 0.078),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  // 黏土方糖 + 分类色线稿（与流水列表行同款）。
                  Builder(builder: (BuildContext ctx) {
                    final Color heroTint = category?.colorValue != null
                        ? Color(category!.colorValue!)
                        : switch (transaction.type) {
                            TxnType.income => AppPalette.income,
                            TxnType.expense => AppPalette.expense,
                            TxnType.transfer => AppPalette.transfer,
                          };
                    return ClayIconTile(
                      size: 44,
                      radius: 14,
                      color: heroTint,
                      child: LineIcon(
                        tileKind,
                        size: 22,
                        color: Color.lerp(
                          heroTint,
                          Theme.of(ctx).colorScheme.onSurface,
                          0.22,
                        )!,
                      ),
                    );
                  },),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: category != null
                          ? () => context.push(
                                '/categories/${category.id}/transactions',
                              )
                          : null,
                      child: Text(
                        category?.name ??
                            (transaction.type == TxnType.transfer
                                ? '转账'
                                : '未分类'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
                  _HeroActions(
                    onDelete: () => _confirmDelete(context, ref),
                    onEdit: () {
                      Navigator.of(context).pop();
                      context.push('/ledger/edit/${transaction.id}');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 金额：有优惠时「原价划线 + 实付」并排展示；无优惠时仅实付
              _heroAmount(money),
              const SizedBox(height: 4),
              Text(
                summary,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (chips.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: chips,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── 卡片一 · 账单 ──────────────────────────────────

  Widget _buildBillCard({
    required BuildContext context,
    required WidgetRef ref,
    required Money money,
    required DateTime occurred,
    required Book? book,
    required Account? account,
    required Category? category,
    required List<String> tags,
  }) {
    final List<Widget> rows = <Widget>[];

    if (transaction.type == TxnType.expense && transaction.discountMinor > 0) {
      rows.add(
        _kv(
          '优惠',
          '-${Money.fromMinor(transaction.discountMinor).format()}',
          valueColor: ForestSemantic.income,
        ),
      );
    }
    rows.add(_kv('时间', DateFormat('yyyy-MM-dd HH:mm').format(occurred)));
    rows.add(_kv('账本', book?.name ?? '默认账本'));
    rows.add(
      _kvTap(
        context,
        '资产账户',
        account?.name ?? '无',
        // 所有账户（含报销账户）统一进资产详情页（与账户页点击口径一致）
        onTap: account == null
            ? null
            : () => context.push('/accounts/${account.id}/transactions'),
      ),
    );
    // 位置：备注上方一行（仅当该流水附加了 GPS 坐标时显示）。
    // 只展示语义化地名（小区/店名级），不再露裸坐标；点按弹小地图
    // 拖拽/点选改点并回写流水（见 _LocationRow），长按复制地名。
    if (transaction.latitude != null) {
      rows.add(_LocationRow(transaction: transaction));
    }
    // 备注：放在「位置 / 资产账户」之下；无备注显示「无」。
    // 元信息行做不断行处理：「份额 x · 单价 y · 手续费 z」每个单元完整
    // 显示在一行，放不下时整个单元换到下一行（右对齐由 _kv 的 end 保证）。
    final String note = transaction.note?.trim() ?? '';
    rows.add(_kv('备注', note.isEmpty ? '无' : keepNoteUnitsUnbroken(note)));
    // 借还本金流水：追加「借出账户 / 借款账户」行（右边账户名可点）。
    final Widget? lendRow = _lendAccountRow(context, ref);
    if (lendRow != null) rows.add(lendRow);
    if (tags.isNotEmpty) {
      rows.add(
        _kvCustom(
          context,
          '标签',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: <Widget>[
              for (final String t in tags)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: ForestGreen.soft,
                    borderRadius: BorderRadius.circular(ForestRadius.pill),
                    border: Border.all(color: ForestGreen.softBorder),
                  ),
                  child: Text(
                    t,
                    style: const TextStyle(
                      fontSize: 13,
                      color: ForestGreen.deep,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return _Card(
      title: '账单',
      child: Column(
        children: _withDividers(context, rows),
      ),
    );
  }

  // ── 卡片二 · 附件 ──────────────────────────────────

  /// 借还本金流水的「借还账户」行：左边方向标题（借出账户 / 借款账户），
  /// 右边应收 / 应付账户名，点击跳资产详情页（与资产账户行同口径）。
  /// 非借还流水、找不到关联借还记录或未指定借还账户时不显示该行。
  Widget? _lendAccountRow(
    BuildContext context,
    WidgetRef ref,
  ) {
    final String? relatedId = transaction.relatedId;
    if (transaction.sourceModule != SourceModule.lend || relatedId == null) {
      return null;
    }
    // 关联借还记录：从当前账本借还列表里反查（旧数据可能已无对应记录）。
    final List<LendRecord> records =
        ref.watch(lendListProvider).valueOrNull ?? const <LendRecord>[];
    LendRecord? record;
    for (final LendRecord r in records) {
      if (r.id == relatedId) {
        record = r;
        break;
      }
    }
    final String? lendAccountId = record?.accountId;
    if (lendAccountId == null) return null;
    final Map<String, Account> accounts = <String, Account>{
      for (final Account a
          in ref.watch(accountsProvider).valueOrNull ?? const <Account>[])
        a.id: a,
    };
    final Account? lendAccount = accounts[lendAccountId];
    if (lendAccount == null) return null;
    final String label =
        record!.direction == LendDirection.lendOut ? '借出账户' : '借款账户';
    return _kvTap(
      context,
      label,
      lendAccount.name,
      valueColor: ForestGreen.label,
      onTap: () => context.push('/accounts/${lendAccount.id}/transactions'),
    );
  }

  Widget _buildAttachmentCard(BuildContext context, List<String> attachments) {
    return _Card(
      title: '附件',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          spacing: 10,
          children: <Widget>[
            for (final String src in attachments) _buildPhoto(context, src),
          ],
        ),
      ),
    );
  }

  /// 卡片二·b · 位置已并入「账单」卡（备注上方一行，见 _buildBillCard）。

  Widget _buildPhoto(BuildContext context, String src) {
    final Widget image =
        (src.startsWith('http://') || src.startsWith('https://'))
            ? Image.network(src, fit: BoxFit.cover)
            : Image.file(File(src), fit: BoxFit.cover);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: image,
      ),
    );
  }

  // ── 卡片三 · 报销 / 退款 ───────────────────────────

  Widget _buildReimbRefundCard({
    required BuildContext context,
    required WidgetRef ref,
    required bool reimbursable,
    required Money money,
    required Map<String, Category> categories,
    required Map<String, Account> accounts,
  }) {
    final String title = reimbursable ? '报销' : '退款';
    final String buttonLabel = reimbursable ? '报销' : '退款';

    return _Card(
      title: title,
      titleSuffix: _JumpNav(
        label: buttonLabel,
        // 报销键直接开「记一笔」报销 Tab，并预填当前账单：
        // 报销账户取账单上的报销账户，报销账单自动勾选本账单。
        onTap: reimbursable
            ? () => openRecordSheet(
                  context,
                  initialTab: RecordTab.reimbursement,
                  reimburseSourceId: transaction.id,
                )
            : () => _onRefund(context, ref),
      ),
      child: reimbursable
          ? _buildReimburseBlock(context, ref, accounts)
          : _buildRefundBlock(context, ref, money, categories),
    );
  }

  /// 报销态：报销收入 / 关联收入 / 是否报销 / 报销账户。
  /// 「是否报销」开关与报销表联动：是→已报销、否→待报销，改后全局同步。
  Widget _buildReimburseBlock(
    BuildContext context,
    WidgetRef ref,
    Map<String, Account> accounts,
  ) {
    // 报销账户：记录时选了报销类型账户则显示账户名，未选显示「无」。
    // 账户被删除后同样回落为「无」。
    final Account? reimbAccount = transaction.reimbursementAccountId == null
        ? null
        : accounts[transaction.reimbursementAccountId];
    // 关联的报销记录（记一笔勾「可报销」时自动创建，旧数据可能没有）。
    final Reimbursement? linked = ref
        .watch(reimbursementByTransactionIdProvider(transaction.id))
        .valueOrNull;
    final bool reimbursed = linked?.status == ReimbursementStatus.reimbursed;
    // 实际收到的报销收入：取抵扣台账（incomeAllocs）合计，
    // 而非账单原始金额——部分报销时两者不同。
    final List<ReimbAllocEntry> allocs = linked == null
        ? const <ReimbAllocEntry>[]
        : parseReimbAllocs(linked.incomeAllocs);
    final int receivedMinor =
        allocs.fold<int>(0, (int s, ReimbAllocEntry e) => s + e.allocMinor);
    return Column(
      children: _withDividers(context, <Widget>[
        _kv(
          '报销收入',
          linked == null ? '无' : Money.fromMinor(receivedMinor).format(),
        ),
        // 关联收入：可点击跳「报销账单详情」（原账单 + 关联收入账单互跳）。
        if (allocs.isEmpty || linked == null)
          _kv(
            '关联收入',
            allocs.isEmpty ? '无' : '${allocs.length} 笔',
          )
        else
          _kvTap(
            context,
            '关联收入',
            '${allocs.length} 笔',
            valueColor: ForestGreen.label,
            onTap: () => showReimbursementRecordSheet(context, linked),
          ),
        _kvCustom(
          context,
          '是否报销',
          // 与其它行一致：值区贴右对齐。
          Align(
            alignment: Alignment.centerRight,
            child: _ReimbSegmentToggle(
              reimbursed: reimbursed,
              onChanged: (bool value) =>
                  _onToggleReimbursed(ref, linked, value),
            ),
          ),
        ),
        if (reimbAccount != null)
          _kvTap(
            context,
            '报销账户',
            reimbAccount.name,
            valueColor: ForestGreen.label,
            onTap: () => context.push('/reimbursement'),
          )
        else
          _kv('报销账户', '无'),
      ]),
    );
  }

  /// 「是否报销」开关落库：有记录直接改状态；无记录（旧数据）补建一条再设状态。
  Future<void> _onToggleReimbursed(
    WidgetRef ref,
    Reimbursement? linked,
    bool reimbursed,
  ) async {
    final ReimbursementRepository repo =
        ref.read(reimbursementRepositoryProvider);
    if (linked != null) {
      await repo.setReimbursed(linked.id, reimbursed);
      return;
    }
    // 无关联报销记录 → 补建一条（与记一笔链路同构），标题取备注首行。
    final String note = transaction.note ?? '';
    final String title =
        note.trim().isEmpty ? '报销' : note.trim().split('\n').first;
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await repo.add(
      bookId: ref.read(currentBookIdProvider),
      title: title,
      status: reimbursed
          ? ReimbursementStatus.reimbursed
          : ReimbursementStatus.pending,
      amountMinor: transaction.amountMinor,
      payer: '本人',
      occurredAt: transaction.occurredAt,
      receivedAt: reimbursed ? now : null,
      accountId: transaction.reimbursementAccountId,
      transactionId: transaction.id,
    );
  }

  /// 退款态：按关联退款流水展示空态 / 关联卡。
  Widget _buildRefundBlock(
    BuildContext context,
    WidgetRef ref,
    Money money,
    Map<String, Category> categories,
  ) {
    final AsyncValue<List<Transaction>> refundsAsync =
        ref.watch(refundsByRelatedIdProvider(transaction.id));

    return refundsAsync.when(
      data: (List<Transaction> refunds) {
        if (refunds.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Center(
              child: Text(
                '无退款账单',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        final Transaction refund = refunds.first;
        final Category? refundCategory = categories[refund.categoryId];
        final String label = refund.note != null && refund.note!.isNotEmpty
            ? refund.note!
            : (refundCategory?.name ?? '退款');
        final String time = DateFormat('MM-dd HH:mm').format(
          DateTime.fromMillisecondsSinceEpoch(
            refund.occurredAt,
            isUtc: true,
          ).toLocal(),
        );
        return GestureDetector(
          onTap: () => context.push('/ledger/edit/${refund.id}'),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: context.colors.surface,
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: ForestGreen.soft,
                    border: Border.all(color: ForestGreen.softBorder),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Center(
                    child: LineIcon(
                      LineIconKind.refundArrow,
                      size: 15,
                      color: ForestGreen.deep,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          // 退款备注可能很长（如「[全额退款] 原账单合计…」），
                          // 必须 Flexible + 省略号，否则把右侧列顶出卡片。
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: ForestGreen.label,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // 右侧：「已关联」徽章 + 金额上下排列、右对齐。
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: ForestGreen.soft,
                        border: Border.all(color: ForestGreen.softBorder),
                        borderRadius: BorderRadius.circular(
                          ForestRadius.pill,
                        ),
                      ),
                      child: const Text(
                        '已关联',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: ForestGreen.deep,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '+${Money.fromMinor(refund.amountMinor).format()}',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: ForestSemantic.income,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (Object e, StackTrace? s) => Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            '加载失败：$e',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  // ── 卡片四 · 报销收入的关联账单 ─────────────────────

  /// 报销模块收入流水的底部关联卡：每笔被本次报销收入抵扣的账单一块——
  /// 头部左边是报销账单标题、右边「关联」徽章，下面是关联账单行
  /// （点击可打开该账单的详情）。
  Widget _buildReimbLinkedCard(BuildContext context, WidgetRef ref) {
    final List<Reimbursement>? linkedList =
        ref.watch(reimbursementsByIncomeIdProvider(transaction.id)).valueOrNull;
    if (linkedList == null || linkedList.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < linkedList.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 12),
          _buildReimbLinkedBlock(context, ref, linkedList[i]),
        ],
      ],
    );
  }

  /// 单笔关联账单块：头部「标题 + 关联徽章」，下方账单行。
  Widget _buildReimbLinkedBlock(
    BuildContext context,
    WidgetRef ref,
    Reimbursement r,
  ) {
    final String? billId = r.transactionId;
    final AsyncValue<Transaction?> billAsync = billId == null
        ? const AsyncValue<Transaction?>.data(null)
        : ref.watch(transactionDetailProvider(billId));
    final Transaction? bill = billAsync.valueOrNull;
    // 关联账单行展示原账单类目：图标 + 颜色 + 标题兜底都取账单类目。
    final Map<String, Category> categories =
        ref.watch(categoryMapProvider).valueOrNull ?? <String, Category>{};
    final Category? billCategory =
        bill == null ? null : categories[bill.categoryId];
    final LineIconKind billIcon = bill == null
        ? LineIconKind.reimbursement
        : resolveTxnLineIcon(bill, billCategory);
    final Color billTint = billCategory?.colorValue != null
        ? Color(billCategory!.colorValue!)
        : ForestGreen.deep;
    final String time = DateFormat('yyyy-MM-dd HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(
        bill?.occurredAt ?? r.occurredAt,
        isUtc: true,
      ).toLocal(),
    );

    return HairlineCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      shadows: ForestElevation.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 头部：左标题 · 右「关联」徽章
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  r.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: TransactionDetailSheet._kSection,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: ForestGreen.label,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: ForestGreen.soft,
                  border: Border.all(color: ForestGreen.softBorder),
                  borderRadius: BorderRadius.circular(ForestRadius.pill),
                ),
                child: const Text(
                  '关联',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: ForestGreen.deep,
                  ),
                ),
              ),
            ],
          ),
          // 下方：关联账单行（点击打开账单详情）
          GestureDetector(
            onTap: billAsync.valueOrNull == null
                ? null
                : () => TransactionDetailSheet.show(
                      context,
                      billAsync.valueOrNull!,
                    ),
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: billTint.withValues(alpha: 0.12),
                      border:
                          Border.all(color: billTint.withValues(alpha: 0.25)),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(
                      child: LineIcon(
                        billIcon,
                        size: 15,
                        color: billTint,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          bill?.note?.trim().isNotEmpty == true
                              ? bill!.note!.trim()
                              : (billCategory?.name ?? r.title),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '-${Money.fromMinor(billAsync.valueOrNull?.amountMinor ?? r.amountMinor).format()}',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: ForestSemantic.expense,
                    ),
                  ),
                  if (billAsync.valueOrNull != null) ...<Widget>[
                    const SizedBox(width: 4),
                    LineIcon(
                      LineIconKind.chevronRight,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 卡片五 · 退款流水的源账单 ───────────────────────

  /// 退款收入流水的底部关联卡：头部「源账单 · 关联徽章」，
  /// 下方展示关联的原账单行（类目图标 + 名称 + 时间 + 原金额），
  /// 点击打开原账单详情（与报销关联卡同款结构）。
  Widget _buildRefundSourceCard(BuildContext context, WidgetRef ref) {
    final String? billId = transaction.relatedId;
    if (billId == null) return const SizedBox.shrink();
    final AsyncValue<Transaction?> billAsync =
        ref.watch(transactionDetailProvider(billId));
    final Transaction? bill = billAsync.valueOrNull;
    // 原账单可能已被删除：数据为空时整卡不显示（避免空壳误导）。
    if (bill == null) return const SizedBox.shrink();

    final Map<String, Category> categories =
        ref.watch(categoryMapProvider).valueOrNull ?? <String, Category>{};
    // 原账单的退款标注（与流水列表同口径）：「退款 ¥X=¥Y」
    // （X=累计已退合计，Y=剩余=实付−已退）。
    final List<Transaction> refunds =
        ref.watch(refundsByRelatedIdProvider(bill.id)).valueOrNull ??
            const <Transaction>[];
    final int refundedMinor =
        refunds.fold<int>(0, (int s, Transaction r) => s + r.amountMinor);
    final Category? billCategory = categories[bill.categoryId];
    final LineIconKind billIcon = resolveTxnLineIcon(bill, billCategory);
    final Color billTint = billCategory?.colorValue != null
        ? Color(billCategory!.colorValue!)
        : ForestGreen.deep;
    final String time = DateFormat('yyyy-MM-dd HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(
        bill.occurredAt,
        isUtc: true,
      ).toLocal(),
    );

    return HairlineCard(
      radius: 20,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      shadows: ForestElevation.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 头部：左标题 · 右「关联」徽章
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  '源账单',
                  style: TextStyle(
                    fontSize: _kSection,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: ForestGreen.label,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: ForestGreen.soft,
                  border: Border.all(color: ForestGreen.softBorder),
                  borderRadius: BorderRadius.circular(ForestRadius.pill),
                ),
                child: const Text(
                  '关联',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: ForestGreen.deep,
                  ),
                ),
              ),
            ],
          ),
          // 下方：原账单行（点击打开原账单详情）
          GestureDetector(
            onTap: () => TransactionDetailSheet.show(context, bill),
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: billTint.withValues(alpha: 0.12),
                      border:
                          Border.all(color: billTint.withValues(alpha: 0.25)),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(
                      child: LineIcon(
                        billIcon,
                        size: 15,
                        color: billTint,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          bill.note?.trim().isNotEmpty == true
                              ? bill.note!.trim()
                              : (billCategory?.name ?? '原账单'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '-${Money.fromMinor(bill.amountMinor).format()}',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: ForestSemantic.expense,
                        ),
                      ),
                      if (refundedMinor > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '退款 ${Money.fromMinor(refundedMinor).format()}'
                            '=${Money.fromMinor(
                              (bill.amountMinor -
                                      bill.discountMinor -
                                      refundedMinor)
                                  .clamp(0, bill.amountMinor),
                            ).format()}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: ForestSemantic.expense,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  LineIcon(
                    LineIconKind.chevronRight,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 通用小组件 ─────────────────────────────────────

  Widget _kv(String label, String value, {Color? valueColor}) => InfoKVRow(
        label: label,
        value: Text(
          value,
          textAlign: TextAlign.end,
          style: valueColor == null
              ? null
              : TextStyle(fontWeight: FontWeight.w500, color: valueColor),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
      );

  Widget _kvTap(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
    VoidCallback? onTap,
  }) =>
      InfoKVRow(
        label: label,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 14),
        value: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Text(
              value,
              textAlign: TextAlign.end,
              style: valueColor == null
                  ? null
                  : TextStyle(fontWeight: FontWeight.w500, color: valueColor),
            ),
            if (onTap != null) ...<Widget>[
              const SizedBox(width: 4),
              LineIcon(
                LineIconKind.chevronRight,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      );

  Widget _kvCustom(BuildContext context, String label, Widget value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: _kBody,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 7,
              child: value,
            ),
          ],
        ),
      );

  /// 在行之间插入发丝线，末行不显示。
  List<Widget> _withDividers(BuildContext context, List<Widget> rows) {
    if (rows.length <= 1) return rows;
    final List<Widget> result = <Widget>[];
    for (int i = 0; i < rows.length; i++) {
      result.add(rows[i]);
      if (i < rows.length - 1) {
        result.add(
          Divider(
            height: 1,
            thickness: 1,
            color: Theme.of(context).colorScheme.outline,
          ),
        );
      }
    }
    return result;
  }

  /// 金额按收支规则配色（无正负号）。
  Color get _amountColor => switch (transaction.type) {
        TxnType.income => ForestSemantic.income,
        TxnType.expense => ForestSemantic.expense,
        TxnType.transfer => ForestSemantic.transfer,
      };

  /// Hero 金额：支出有优惠时「划线原价 + 实付」并排；其余仅一笔大字。
  Widget _heroAmount(Money money) {
    final TextStyle base = TextStyle(
      fontSize: _kHeroAmt,
      fontWeight: FontWeight.w700,
      color: _amountColor,
      fontFamily: 'serif',
      letterSpacing: 0.5,
      height: 1.1,
    );

    final bool hasDiscount =
        transaction.type == TxnType.expense && transaction.discountMinor > 0;
    if (!hasDiscount) {
      return Text(money.format(), style: base);
    }

    final Money paid = Money.fromMinor(
      transaction.amountMinor - transaction.discountMinor,
    );

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      children: <Widget>[
        // 划线原价（小号、原色弱化）
        Text(
          money.format(),
          style: base.copyWith(
            fontSize: 20,
            color: _amountColor.withValues(alpha: 0.55),
            decoration: TextDecoration.lineThrough,
            decorationColor: _amountColor.withValues(alpha: 0.55),
            decorationThickness: 2,
          ),
        ),
        // 实付（主金额）
        Text(paid.format(), style: base),
      ],
    );
  }

  List<String> _parseJsonList(String? raw) {
    if (raw == null || raw.isEmpty) return <String>[];
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((dynamic e) => e.toString()).toList();
      }
    } on Object {
      // 非 JSON：按原样作为单个值
      return <String>[raw];
    }
    return <String>[];
  }

  // ── 操作 ───────────────────────────────────────────

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final bool? confirm = await showConfirm(
      context,
      title: '删除流水',
      content: '删除后账户余额会相应回滚，此操作不可撤销。',
      confirmText: '删除',
      danger: true,
    );
    if (confirm != true) return;

    try {
      await ref.read(transactionRepositoryProvider).remove(transaction.id);
      if (context.mounted) {
        Navigator.of(context).pop();
        showAppToast(context, '已删除');
      }
    } on AppFailure catch (e) {
      if (context.mounted) {
        showAppToast(context, e.message);
      }
    }
  }

  Future<void> _onRefund(BuildContext context, WidgetRef ref) async {
    // 跳「记一笔」退款页并预关联本账单：金额/账户空置待填，
    // 保存生成退款收入流水（sourceModule=refund，relatedId 指向本账单）。
    await openRecordSheet(
      context,
      initialTab: RecordTab.refund,
      refundSourceId: transaction.id,
    );
  }
}

// ── 卡片容器 ────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.child,
    this.titleSuffix,
  });

  final String title;
  final Widget child;
  final Widget? titleSuffix;

  @override
  Widget build(BuildContext context) {
    return HairlineCard(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
      radius: 20,
      shadows: ForestElevation.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: TransactionDetailSheet._kSection,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: ForestGreen.label,
                    ),
                  ),
                ),
                if (titleSuffix != null) titleSuffix!,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// ── Hero 删除 / 编辑圆形按钮（A3 线稿 + 磨砂玻璃）────────

class _HeroActions extends StatelessWidget {
  const _HeroActions({required this.onDelete, required this.onEdit});

  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 10,
      children: <Widget>[
        _CircleBtn(icon: LineIconKind.trash, onTap: onDelete),
        _CircleBtn(icon: LineIconKind.pencil, onTap: onEdit),
      ],
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, required this.onTap});

  final LineIconKind icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 36,
        height: 36,
        child: HairlineCard(
          backgroundColor: context.colors.surface,
          borderColor: Theme.of(context).colorScheme.outline,
          radius: ForestRadius.pill,
          padding: EdgeInsets.zero,
          child: Center(
            child: LineIcon(
              icon,
              size: 15,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hero 标记小药丸 ──────────────────────────────────

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label, this.warn = false});

  final String label;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color:
            warn ? ForestAccent.gold.withValues(alpha: 0.14) : ForestGreen.soft,
        borderRadius: BorderRadius.circular(ForestRadius.pill),
        border: Border.all(
          color: warn
              ? ForestAccent.gold.withValues(alpha: 0.35)
              : ForestGreen.softBorder,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: warn ? ForestAccent.gold : ForestGreen.deep,
        ),
      ),
    );
  }
}

// ── 报销/退款跳转键（鼠尾草渐变主操作）───────────────

class _JumpNav extends StatelessWidget {
  const _JumpNav({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          gradient: ForestGradients.button,
          borderRadius: BorderRadius.circular(ForestRadius.pill),
          boxShadow: ForestElevation.float,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onPrimary,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

// ── 是否报销分段开关（受控组件：状态来自报销表，切换即落库并全局同步）──────

class _ReimbSegmentToggle extends StatelessWidget {
  const _ReimbSegmentToggle({
    required this.reimbursed,
    required this.onChanged,
  });

  final bool reimbursed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SunkenBox(
      radius: ForestRadius.pill,
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 3,
        children: <Widget>[
          _SegmentItem(
            label: '是',
            active: reimbursed,
            onTap: () => onChanged(true),
          ),
          _SegmentItem(
            label: '否',
            active: !reimbursed,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  const _SegmentItem({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: active ? context.colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(ForestRadius.pill),
          boxShadow: active ? ForestElevation.xs : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active
                ? ForestGreen.deep
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// 详情页「位置」行：自持有状态（父弹窗是不可变 ConsumerWidget，改点后局部刷新）。
///
/// - 值区只显语义化地名（小区/店名级），无地名显「已定位」，**不再露裸坐标**；
/// - 点按弹小地图浮层（[showLocationMapSheet]），拖拽/点选取新点 → 逆地理编码
///   → 确认后经 [TransactionRepository.updateTransaction] 回写坐标与地名；
/// - 长按复制地名，便于分享 / 地图检索。
class _LocationRow extends ConsumerStatefulWidget {
  const _LocationRow({required this.transaction});

  final Transaction transaction;

  @override
  ConsumerState<_LocationRow> createState() => _LocationRowState();
}

class _LocationRowState extends ConsumerState<_LocationRow> {
  late double _lat = widget.transaction.latitude!;
  late double _lng = widget.transaction.longitude!;
  late String? _place = widget.transaction.placeName;
  bool _saving = false;

  Future<void> _editOnMap() async {
    if (_saving) return;
    final LocationPickResult? result = await showLocationMapSheet(
      context,
      latitude: _lat,
      longitude: _lng,
      placeName: _place,
    );
    if (result == null) return;
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(transactionRepositoryProvider)
          .updateTransaction(
            original: widget.transaction,
            latitude: result.latitude,
            longitude: result.longitude,
            // 地点解析失败时写空串清旧名（仓储语义：null = 保留原值）。
            placeName: result.placeName ?? '',
          );
      if (!mounted) return;
      setState(() {
        _lat = result.latitude;
        _lng = result.longitude;
        _place = (result.placeName ?? '').isEmpty ? null : result.placeName;
      });
      showAppToast(context, '位置已更新');
    } on AppFailure catch (e) {
      if (mounted) showAppToast(context, e.message);
    } catch (_) {
      if (mounted) showAppToast(context, '位置更新失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _copy() {
    final String text = _place ?? '';
    Clipboard.setData(ClipboardData(text: text.isEmpty ? '已定位' : text));
    showAppToast(context, '已复制位置');
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String display =
        (_place == null || _place!.isEmpty) ? '已定位' : _place!;
    // 长按复制地名（点按走小地图改点，互不冲突）。
    return GestureDetector(
      onLongPress: _copy,
      child: InfoKVRow(
        label: '位置',
        padding: const EdgeInsets.symmetric(vertical: 14),
        onTap: _saving ? null : _editOnMap,
        value: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            if (_saving)
              SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.primary,
                ),
              )
            else
              Flexible(
                child: Text(
                  display,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            const SizedBox(width: 4),
            LineIcon(
              LineIconKind.chevronRight,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
