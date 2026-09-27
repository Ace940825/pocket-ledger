import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/theme/forest_design_tokens.dart';
import '../../../../database/app_database.dart';
import '../../../../domain/enums.dart';
import '../../../../providers/app_providers.dart';
import '../../../../shared/models/money.dart';
import '../../../../shared/widgets/line_icons.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../reimbursement/data/reimbursement_repository.dart';
import '../../reimbursement/providers/reimbursement_providers.dart';
import '../providers/ledger_providers.dart';

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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      // 下拉把手 / 点空白关闭：保留默认 enableDrag + isDismissible。
      showDragHandle: false,
      builder: (_) => TransactionDetailSheet(transaction: transaction),
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

    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: const BoxDecoration(
        color: ForestBg.raised,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ForestRadius.xl),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _buildGrab(),
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
                    _buildAttachmentCard(attachments),
                  ],
                  if (transaction.type == TxnType.expense) ...<Widget>[
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
    final LineIconKind tileKind = category != null
        ? (categoryLineKind(category.iconKey) ?? LineIconKind.star)
        : LineIconKind.star;

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
      account?.name ?? '未知账户',
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: ForestSurface.card,
        border: Border.all(color: ForestNeutral.hairline),
        borderRadius: BorderRadius.circular(24),
        boxShadow: ForestElevation.card,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // 角落 ❦ 水印（奶油卡上用浅鼠尾草调）
          const Positioned(
            right: -8,
            bottom: -22,
            child: Text(
              '❦',
              style: TextStyle(fontSize: 110, color: Color(0x14557E4C)),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: ForestGreen.soft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: LineIcon(
                        tileKind,
                        size: 22,
                        color: ForestGreen.deep,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: category != null
                          ? () => context.push(
                                '/categories/edit',
                                extra: category,
                              )
                          : null,
                      child: Text(
                        category?.name ??
                            (transaction.type == TxnType.transfer
                                ? '转账'
                                : '未分类'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: ForestNeutral.textPrimary,
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
                style: const TextStyle(
                  fontSize: 12,
                  color: ForestNeutral.textSecondary,
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
        '资产账户',
        account?.name ?? '未知账户',
        onTap: account != null
            ? () => context.push('/accounts/${account.id}/transactions')
            : null,
      ),
    );
    if (tags.isNotEmpty) {
      rows.add(
        _kvCustom(
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
        children: _withDividers(rows),
      ),
    );
  }

  // ── 卡片二 · 附件 ──────────────────────────────────

  Widget _buildAttachmentCard(List<String> attachments) {
    return _Card(
      title: '附件',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          spacing: 10,
          children: <Widget>[
            for (final String src in attachments) _buildPhoto(src),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoto(String src) {
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
          border: Border.all(color: ForestNeutral.hairline),
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
        onTap: reimbursable
            ? () => context.push('/reimbursement')
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
    return Column(
      children: _withDividers(<Widget>[
        _kv(
          '报销收入',
          Money.fromMinor(transaction.amountMinor).format(),
        ),
        _kv('关联收入', '无'),
        _kvCustom(
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
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Center(
              child: Text(
                '无退款账单',
                style: TextStyle(
                  fontSize: 13,
                  color: ForestNeutral.textTertiary,
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
        final String time = DateFormat('MM-dd HH:mm')
            .format(DateTime.fromMillisecondsSinceEpoch(
          refund.occurredAt,
          isUtc: true,
        ).toLocal());
        return GestureDetector(
          onTap: () => context.push('/ledger/edit/${refund.id}'),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: ForestBg.paper,
              border: Border.all(color: ForestNeutral.hairline),
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
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: ForestGreen.label,
                            ),
                          ),
                          const SizedBox(width: 6),
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
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 11,
                          color: ForestNeutral.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
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
            style: const TextStyle(
              fontSize: 13,
              color: ForestNeutral.textTertiary,
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
    final List<Reimbursement>? linkedList = ref
        .watch(reimbursementsByIncomeIdProvider(transaction.id))
        .valueOrNull;
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
    final AsyncValue<Transaction?> billAsync =
        billId == null ? const AsyncValue<Transaction?>.data(null) : ref.watch(transactionDetailProvider(billId));
    final String time = DateFormat('yyyy-MM-dd HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(
        billAsync.valueOrNull?.occurredAt ?? r.occurredAt,
        isUtc: true,
      ).toLocal(),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      decoration: BoxDecoration(
        color: ForestSurface.card,
        border: Border.all(color: ForestNeutral.hairline),
        borderRadius: BorderRadius.circular(20),
        boxShadow: ForestElevation.card,
      ),
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
                  style: TextStyle(
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
                      color: ForestGreen.soft,
                      border: Border.all(color: ForestGreen.softBorder),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Center(
                      child: LineIcon(
                        LineIconKind.reimbursement,
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
                        Text(
                          billAsync.valueOrNull?.note?.trim()
                                      .isNotEmpty ==
                                  true
                              ? billAsync.valueOrNull!.note!.trim()
                              : r.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: ForestNeutral.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          time,
                          style: const TextStyle(
                            fontSize: 11,
                            color: ForestNeutral.textTertiary,
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
                    const LineIcon(
                      LineIconKind.chevronRight,
                      size: 14,
                      color: ForestNeutral.textTertiary,
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

  // ── 通用小组件 ─────────────────────────────────────

  Widget _buildGrab() => Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.fromLTRB(0, 12, 0, 4),
        decoration: BoxDecoration(
          color: ForestNeutral.hairlineStrong,
          borderRadius: BorderRadius.circular(ForestRadius.pill),
        ),
      );

  Widget _kv(String label, String value, {Color? valueColor}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 3,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: _kBody,
                  color: ForestNeutral.textSecondary,
                ),
              ),
            ),
            Expanded(
              flex: 7,
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: _kBody,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? ForestNeutral.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _kvTap(String label, String value,
          {Color? valueColor, VoidCallback? onTap}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 3,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: _kBody,
                  color: ForestNeutral.textSecondary,
                ),
              ),
            ),
            Expanded(
              flex: 7,
              child: GestureDetector(
                onTap: onTap,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: _kBody,
                        fontWeight: FontWeight.w500,
                        color: valueColor ?? ForestNeutral.textPrimary,
                      ),
                    ),
                    if (onTap != null) ...<Widget>[
                      const SizedBox(width: 4),
                      const LineIcon(
                        LineIconKind.chevronRight,
                        size: 14,
                        color: ForestNeutral.textTertiary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _kvCustom(String label, Widget value) => Padding(
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
                  style: const TextStyle(
                    fontSize: _kBody,
                    color: ForestNeutral.textSecondary,
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
  List<Widget> _withDividers(List<Widget> rows) {
    if (rows.length <= 1) return rows;
    final List<Widget> result = <Widget>[];
    for (int i = 0; i < rows.length; i++) {
      result.add(rows[i]);
      if (i < rows.length - 1) {
        result.add(const Divider(
          height: 1,
          thickness: 1,
          color: ForestNeutral.hairline,
        ));
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
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('删除流水'),
        content: const Text('删除后账户余额会相应回滚，此操作不可撤销。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除',
                style: TextStyle(color: ForestSemantic.expense)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(transactionRepositoryProvider).remove(transaction.id);
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已删除')));
      }
    } on AppFailure catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _onRefund(BuildContext context, WidgetRef ref) async {
    // TODO: 接入「选择原账单创建退款收入」流程与 /refund 路由。
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('退款功能将在后续版本接入')),
      );
    }
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
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
      decoration: BoxDecoration(
        color: ForestSurface.card,
        border: Border.all(color: ForestNeutral.hairline),
        borderRadius: BorderRadius.circular(20),
        boxShadow: ForestElevation.card,
      ),
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
                    style: TextStyle(
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
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: ForestSurface.card,
          border: Border.all(color: ForestNeutral.hairline),
          borderRadius: BorderRadius.circular(ForestRadius.pill),
        ),
        child: Center(
          child: LineIcon(icon, size: 15, color: ForestNeutral.deepInk),
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
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
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
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ForestBg.sunken,
        borderRadius: BorderRadius.circular(ForestRadius.pill),
      ),
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
          color: active ? ForestSurface.card : Colors.transparent,
          borderRadius: BorderRadius.circular(ForestRadius.pill),
          boxShadow: active ? ForestElevation.xs : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? ForestGreen.deep : ForestNeutral.textSecondary,
          ),
        ),
      ),
    );
  }
}
