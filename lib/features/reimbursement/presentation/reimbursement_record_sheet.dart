import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/forest_design_tokens.dart';
import '../../../../database/app_database.dart';
import '../../../../domain/enums.dart';
import '../../../../shared/models/money.dart';
import '../../ledger/presentation/transaction_detail_sheet.dart';
import '../../ledger/providers/ledger_providers.dart';
import '../data/reimbursement_repository.dart';

/// 报销账单详情底部弹窗。
///
/// 从支出账单明细的「关联收入 N 笔」进入：展示报销记录本身（事由 / 状态 /
/// 金额 / 垫付日期），并列出「报销原账单」与「关联收入账单」两节——
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

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // 头部：事由 + 状态徽章。
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          record.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: ForestNeutral.textPrimary,
                          ),
                        ),
                      ),
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
                  const SizedBox(height: 4),
                  Text(
                    Money.fromMinor(record.amountMinor).format(),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: ForestNeutral.textPrimary,
                      fontFamily: 'Georgia',
                    ),
                  ),
                  const SizedBox(height: 14),
                  // 基础信息行。
                  _kv('垫付日期', DateFormat('yyyy-MM-dd').format(occurred)),
                  if (record.payer.isNotEmpty) _kv('垫付人', record.payer),
                  if (record.target?.isNotEmpty == true)
                    _kv('报销方', record.target!),
                  // 报销原账单。
                  _sectionTitle('报销原账单'),
                  if (record.transactionId != null)
                    _BillRow(
                      transactionAsync: ref.watch(
                        transactionDetailProvider(record.transactionId!),
                      ),
                      fallbackLabel: '原账单',
                      onTap: (Transaction t) =>
                          TransactionDetailSheet.show(context, t),
                    )
                  else
                    const _EmptyHint('手动创建的记录，未关联支出账单'),
                  // 关联收入账单。
                  _sectionTitle('关联收入账单'),
                  if (incomeIds.isEmpty)
                    const _EmptyHint('尚无报销收入，待「记一笔报销收入」抵扣后生成')
                  else
                    for (int i = 0; i < incomeIds.length; i++)
                      _BillRow(
                        transactionAsync: ref.watch(
                          transactionDetailProvider(incomeIds[i]),
                        ),
                        fallbackLabel: '报销收入 ${i + 1}',
                        onTap: (Transaction t) =>
                            TransactionDetailSheet.show(context, t),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: ForestNeutral.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: ForestNeutral.textPrimary,
              ),
            ),
          ],
        ),
      );

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: ForestNeutral.textSecondary,
          ),
        ),
      );
}

/// 关联流水行：加载中占位 / 已删除或缺失提示 / 可点击行（备注 + 金额 + 箭头）。
class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.transactionAsync,
    required this.fallbackLabel,
    required this.onTap,
  });

  final AsyncValue<Transaction?> transactionAsync;
  final String fallbackLabel;
  final void Function(Transaction) onTap;

  @override
  Widget build(BuildContext context) {
    return transactionAsync.when(
      skipLoadingOnReload: true,
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          '加载中…',
          style: TextStyle(fontSize: 13, color: ForestNeutral.textTertiary),
        ),
      ),
      error: (Object e, StackTrace? s) => const _EmptyHint('流水加载失败'),
      data: (Transaction? t) {
        if (t == null) {
          return const _EmptyHint('关联流水已删除');
        }
        final String title = t.note?.trim().isNotEmpty == true
            ? t.note!.trim()
            : fallbackLabel;
        return InkWell(
          onTap: () => onTap(t),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: ForestNeutral.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  Money.fromMinor(t.amountMinor).format(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ForestNeutral.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: ForestNeutral.textTertiary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
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
