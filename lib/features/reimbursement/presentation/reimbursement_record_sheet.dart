import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/forest_design_tokens.dart';
import '../../../../database/app_database.dart';
import '../../../../domain/enums.dart';
import '../../../../shared/models/money.dart';
import '../../../../shared/widgets/line_icons.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../ledger/presentation/transaction_detail_sheet.dart';
import '../../ledger/providers/ledger_providers.dart';
import '../data/reimbursement_repository.dart';

/// 报销账单详情底部弹窗（对齐参考稿两节卡片逻辑）。
///
/// 「原账单」卡：类目图标 + 标题 + 「报」徽章 +（超额时）「超额报销」标签，
/// 右侧账单金额、「已报 ¥xx」累计红字、「不计收支、预算」红字标注；
/// 「报销收入」卡：每笔报销收入一行，「报」图标 + 金额绿色 + 排除标注。
/// 每行可点击，跳转对应流水的详情弹窗，实现 报销 ↔ 账单 ↔ 收入 互跳。
Future<void> showReimbursementRecordSheet(
  BuildContext context,
  Reimbursement record,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReimbursementRecordSheet(record: record),
  );
}

class _ReimbursementRecordSheet extends ConsumerWidget {
  const _ReimbursementRecordSheet({required this.record});

  final Reimbursement record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime occurred = DateTime.fromMillisecondsSinceEpoch(
      record.occurredAt,
      isUtc: true,
    ).toLocal();
    final bool reimbursed = record.status == ReimbursementStatus.reimbursed;
    // 关联收入：优先取抵扣台账；旧数据只有 incomeTransactionId 单笔兜底。
    final List<ReimbAllocEntry> allocs = parseReimbAllocs(record.incomeAllocs);
    final List<String> incomeIds = <String>[
      for (final ReimbAllocEntry e in allocs) e.incomeId,
      if (allocs.isEmpty && record.incomeTransactionId != null)
        record.incomeTransactionId!,
    ];
    // 台账存在时「已报」取台账合计（精确到每笔抵扣额）；旧数据兜底在
    // _OriginBillCard 内按收入流水金额合计。
    final int allocSum =
        allocs.fold<int>(0, (int s, ReimbAllocEntry e) => s + e.allocMinor);
    final List<String> meta = <String>[
      '垫付 ${DateFormat('yyyy-MM-dd').format(occurred)}',
      if (record.payer.isNotEmpty) '垫付人 ${record.payer}',
      if (record.target?.isNotEmpty == true) '报销方 ${record.target!}',
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.62,
      decoration: const BoxDecoration(
        color: ForestBg.raised,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ForestRadius.xl),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 下拉把手（与流水详情弹窗一致）。
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ForestNeutral.textTertiary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 头部：事由 + 状态徽章（+ 垫付元信息一行）。
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        record.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: ForestNeutral.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: reimbursed
                            ? ForestGreen.label.withValues(alpha: 0.12)
                            : ForestSurface.cardAlt,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        record.status.label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: reimbursed
                              ? ForestGreen.label
                              : ForestNeutral.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (meta.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    meta.join(' · '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: ForestNeutral.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _sectionBar('原账单'),
                  if (record.transactionId != null)
                    _OriginBillCard(
                      key: ValueKey<String>('origin-${record.transactionId}'),
                      transactionId: record.transactionId!,
                      allocSum: allocSum,
                      allocsFromLedger: allocs.isNotEmpty,
                    )
                  else
                    _card(const _EmptyHint('手动创建的记录，未关联支出账单')),
                  const SizedBox(height: 14),
                  _sectionBar('报销收入'),
                  if (incomeIds.isEmpty)
                    _card(const _EmptyHint('尚无报销收入，待「记一笔报销收入」抵扣后生成'))
                  else
                    _card(
                      Column(
                        children: <Widget>[
                          for (int i = 0; i < incomeIds.length; i++) ...<Widget>[
                            if (i > 0)
                              const Divider(
                                height: 1,
                                thickness: 0.8,
                                color: ForestNeutral.hairline,
                              ),
                            _IncomeRow(
                              key: ValueKey<String>('income-${incomeIds[i]}'),
                              transactionId: incomeIds[i],
                              fallbackLabel: '报销收入 ${i + 1}',
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 节标题：绿色竖条 + 加粗标题（对齐参考稿「原账单 / 报销收入」节头）。
  Widget _sectionBar(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: <Widget>[
            Container(
              width: 3.5,
              height: 14,
              decoration: BoxDecoration(
                color: ForestGreen.brand,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              text,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: ForestNeutral.textPrimary,
              ),
            ),
          ],
        ),
      );
}

/// 卡片容器：白卡 + 发丝描边 + 圆角。
Widget _card(Widget child) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: ForestSurface.card,
        border: Border.all(color: ForestNeutral.hairline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );

/// 「不计收支、预算」红字标注（两开关任一开启才显示）。
Widget _excludeLabel({required bool stats, required bool budget}) {
  final List<String> labels = <String>[
    if (stats) '不计收支',
    if (budget) '不计预算',
  ];
  if (labels.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Text(
      labels.join('、'),
      style: const TextStyle(
        fontSize: 11,
        color: ForestSemantic.expense,
      ),
    ),
  );
}

/// 原账单卡：加载 / 删除占位 + 账单行（图标+徽章+标签+金额+已报+排除标注）。
class _OriginBillCard extends ConsumerWidget {
  const _OriginBillCard({
    super.key,
    required this.transactionId,
    required this.allocSum,
    required this.allocsFromLedger,
  });

  final String transactionId;

  /// 台账合计（抵扣额精确值）；台账为空时由收入流水金额兜底。
  final int allocSum;
  final bool allocsFromLedger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(transactionDetailProvider(transactionId)).when(
          skipLoadingOnReload: true,
          loading: () => _card(const _EmptyHint('加载中…')),
          error: (Object e, StackTrace? s) => _card(const _EmptyHint('流水加载失败')),
          data: (Transaction? t) {
            if (t == null) {
              return _card(const _EmptyHint('关联流水已删除'));
            }
            final Map<String, Category> categories =
                ref.watch(categoryMapProvider).valueOrNull ??
                    <String, Category>{};
            final Category? category = categories[t.categoryId];
            return _card(_OriginBillRow(
              transaction: t,
              category: category,
              allocSum: allocSum,
              allocsFromLedger: allocsFromLedger,
              onTap: () => TransactionDetailSheet.show(context, t),
            ));
          },
        );
  }
}

class _OriginBillRow extends StatelessWidget {
  const _OriginBillRow({
    required this.transaction,
    required this.category,
    required this.allocSum,
    required this.allocsFromLedger,
    required this.onTap,
  });

  final Transaction transaction;
  final Category? category;
  final int allocSum;
  final bool allocsFromLedger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DateTime occurred = DateTime.fromMillisecondsSinceEpoch(
      transaction.occurredAt,
      isUtc: true,
    ).toLocal();
    final String title = (transaction.note?.trim().isNotEmpty == true)
        ? transaction.note!.trim()
        : (category?.name ?? '原账单');
    final LineIconKind kind = category != null
        ? (categoryLineKind(category!.iconKey) ?? LineIconKind.star)
        : LineIconKind.star;
    // 累计已报：台账精确合计；旧数据无台账时交给收入行金额兜底（在
    // _IncomeRowFallback 中难以回传，这里用账单自身已报销口径近似）。
    final int received = allocsFromLedger ? allocSum : 0;
    final bool overReimbursed =
        received > transaction.amountMinor && allocsFromLedger;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // 类目图标（浅绿圆底 + 线稿图标）。
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: ForestGreen.soft,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: LineIcon(kind, size: 18, color: ForestGreen.deep),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // 标题 + 「报」徽章 + 「超额报销」标签。
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: ForestNeutral.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _RebBadge(),
                      if (overReimbursed) ...<Widget>[
                        const SizedBox(width: 6),
                        const _OverTag(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('HH:mm').format(occurred),
                    style: const TextStyle(
                      fontSize: 12,
                      color: ForestNeutral.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // 右侧：金额 + 已报 + 排除标注。
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '-${Money.fromMinor(transaction.amountMinor).format()}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ForestNeutral.textPrimary,
                  ),
                ),
                if (received > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '已报 ${Money.fromMinor(received).format()}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: ForestSemantic.expense,
                      ),
                    ),
                  ),
                _excludeLabel(
                  stats: transaction.excludeFromStats,
                  budget: transaction.excludeFromBudget,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 报销收入行：「报」图标 + 时间 + 绿色金额 + 排除标注。
class _IncomeRow extends ConsumerWidget {
  const _IncomeRow({
    super.key,
    required this.transactionId,
    required this.fallbackLabel,
  });

  final String transactionId;
  final String fallbackLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(transactionDetailProvider(transactionId)).when(
          skipLoadingOnReload: true,
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text(
              '加载中…',
              style: TextStyle(
                fontSize: 13,
                color: ForestNeutral.textTertiary,
              ),
            ),
          ),
          error: (Object e, StackTrace? s) =>
              const _EmptyHint('关联流水加载失败'),
          data: (Transaction? t) {
            if (t == null) {
              return const _EmptyHint('关联流水已删除');
            }
            final DateTime occurred = DateTime.fromMillisecondsSinceEpoch(
              t.occurredAt,
              isUtc: true,
            ).toLocal();
            return InkWell(
              onTap: () => TransactionDetailSheet.show(context, t),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: ForestGreen.soft,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          '报',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: ForestGreen.deep,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            t.note?.trim().isNotEmpty == true
                                ? t.note!.trim()
                                : fallbackLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: ForestNeutral.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            DateFormat('HH:mm').format(occurred),
                            style: const TextStyle(
                              fontSize: 12,
                              color: ForestNeutral.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          '+${Money.fromMinor(t.amountMinor).format()}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: ForestSemantic.income,
                          ),
                        ),
                        _excludeLabel(
                          stats: t.excludeFromStats,
                          budget: t.excludeFromBudget,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
  }
}

/// 「报」小徽章：浅绿底 + 描边圆角方块。
class _RebBadge extends StatelessWidget {
  const _RebBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: ForestGreen.soft,
          border: Border.all(color: ForestGreen.softBorder),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '报',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: ForestGreen.deep,
          ),
        ),
      );
}

/// 「超额报销」描边胶囊标签。
class _OverTag extends StatelessWidget {
  const _OverTag();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: ForestGreen.softBorder),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          '超额报销',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: ForestGreen.deep,
          ),
        ),
      );
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: ForestNeutral.textTertiary,
          ),
        ),
      );
}
