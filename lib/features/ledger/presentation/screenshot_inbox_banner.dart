import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/forest_design_tokens.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/clay_icon_tile.dart';
import '../../../shared/widgets/hairline_card.dart';
import '../../../shared/widgets/line_icons.dart';
import '../../../theme/app_colors.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../data/bill_io.dart';
import '../data/screenshot_inbox.dart';
import '../providers/ledger_providers.dart';
import 'widgets/txn_icon.dart';

/// 快捷指令截图识别 · 顶部通知条（对标咔皮记账 2026-10-20 参考图）。
///
/// 经根 Overlay 挂载（高于一切路由）：识别中显示 spinner 小卡；识别成功
/// 显示「分类图标 + 分类名 + 金额 + 账户/备注/时间胶囊 + 已识别 N 笔」，
/// 点「去查看」开账单详情弹窗，点「知道了」或 10 秒超时自动收起。
class ScreenshotInboxBanner extends ConsumerStatefulWidget {
  const ScreenshotInboxBanner({
    super.key,
    required this.onDismiss,
    required this.onOpenDetail,
  });

  /// 关闭通知条（回到 idle，Overlay 由监听方移除）。
  final VoidCallback onDismiss;

  /// 「去查看」：打开首笔流水详情弹窗。
  final ValueChanged<Transaction> onOpenDetail;

  @override
  ConsumerState<ScreenshotInboxBanner> createState() =>
      _ScreenshotInboxBannerState();
}

class _ScreenshotInboxBannerState extends ConsumerState<ScreenshotInboxBanner> {
  Timer? _autoDismiss;

  static const double _kCardWidth = 340;

  @override
  void initState() {
    super.initState();
    _scheduleAutoDismiss();
  }

  @override
  void didUpdateWidget(ScreenshotInboxBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 状态从 parsing → saved/failed 换卡时重置自动收起计时。
    _scheduleAutoDismiss();
  }

  void _scheduleAutoDismiss() {
    _autoDismiss?.cancel();
    _autoDismiss = Timer(const Duration(seconds: 10), () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ScreenshotInboxState st = ref.watch(screenshotInboxProvider);
    if (st.status == ScreenshotInboxStatus.idle) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double t, Widget? child) =>
                Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, -24 * (1 - t)),
                child: child,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: _kCardWidth,
                child: switch (st.status) {
                  ScreenshotInboxStatus.parsing => _parsingCard(),
                  ScreenshotInboxStatus.saved => _savedCard(st),
                  _ => _failedCard(st),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 识别中 ──────────────────────────────────────────

  Widget _parsingCard() {
    return HairlineCard(
      radius: 20,
      shadows: ForestElevation.float,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: <Widget>[
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            '正在识别截图账单…',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // ── 识别成功 ────────────────────────────────────────

  Widget _savedCard(ScreenshotInboxState st) {
    final BillRow? row = st.firstRow;
    // 首笔流水详情：拿到真实 Transaction 后才能开详情弹窗。
    final AsyncValue<Transaction?> txnAsync = st.txnIds.isEmpty
        ? const AsyncValue<Transaction?>.data(null)
        : ref.watch(transactionDetailProvider(st.txnIds.first));
    final Transaction? txn = txnAsync.valueOrNull;
    final Map<String, Category> categories =
        ref.watch(categoryMapProvider).valueOrNull ?? <String, Category>{};
    final Category? category =
        txn == null ? null : categories[txn.categoryId];

    final bool isIncome = row?.type == TxnType.income;
    final bool isExpense = row?.type == TxnType.expense;
    final Color amountColor = isIncome
        ? ForestSemantic.income
        : isExpense
            ? ForestSemantic.expense
            : ForestSemantic.transfer;
    final String sign = switch (row?.type) {
      TxnType.income => '+',
      TxnType.expense => '-',
      _ => '',
    };
    final String amountText = row == null
        ? ''
        : '$sign${Money.fromMinor(row.amountMinor).format()}';
    final String title = category?.name ??
        (row?.categoryName?.trim().isNotEmpty == true
            ? row!.categoryName!.trim()
            : (row?.note?.trim().isNotEmpty == true
                ? row!.note!.trim()
                : '截图记账'));

    return HairlineCard(
      radius: 20,
      shadows: ForestElevation.float,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              ClayIconTile(
                size: 40,
                radius: 12,
                color: ForestGreen.deep,
                child: LineIcon(
                  txn != null
                      ? resolveTxnLineIcon(txn, category)
                      : LineIconKind.otherDots,
                  size: 20,
                  color: ForestGreen.deep,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                amountText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                ),
              ),
            ],
          ),
          if (row != null) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                if (row.accountName.trim().isNotEmpty)
                  _chip(row.accountName.trim()),
                if (row.note != null && row.note!.trim().isNotEmpty)
                  _chip(_shortNote(row.note!.trim())),
                _chip(DateFormat('MM-dd HH:mm').format(row.occurredAt)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '已识别 ${st.txnIds.length} 笔记录信息，已自动记入账本'
            '${st.skipReasons.isEmpty ? '' : '，跳过 ${st.skipReasons.length} 笔'}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(child: _knowBtn()),
              const SizedBox(width: 10),
              Expanded(
                child: _viewBtn(enabled: txn != null, txn: txn),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 识别失败 ────────────────────────────────────────

  Widget _failedCard(ScreenshotInboxState st) {
    return HairlineCard(
      radius: 20,
      shadows: ForestElevation.float,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              const ClayIconTile(
                size: 40,
                radius: 12,
                color: AppPalette.expense,
                child: LineIcon(
                  LineIconKind.info,
                  size: 20,
                  color: AppPalette.expense,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '截图识别失败',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          if (st.error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              st.error!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _knowBtn(),
              ),
              const SizedBox(width: 10),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  // ── 小件 ────────────────────────────────────────────

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ForestGreen.soft,
        borderRadius: BorderRadius.circular(ForestRadius.pill),
        border: Border.all(color: ForestGreen.softBorder),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          color: ForestGreen.deep,
        ),
      ),
    );
  }

  Widget _knowBtn() {
    return GestureDetector(
      onTap: widget.onDismiss,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(ForestRadius.pill),
        ),
        child: Text(
          '知道了',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _viewBtn({required bool enabled, required Transaction? txn}) {
    return GestureDetector(
      onTap: enabled
          ? () {
              _autoDismiss?.cancel();
              widget.onOpenDetail(txn!);
            }
          : null,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: enabled ? ForestGradients.button : null,
          color: enabled ? null : Theme.of(context).colorScheme.outline,
          borderRadius: BorderRadius.circular(ForestRadius.pill),
          boxShadow: enabled ? ForestElevation.float : null,
        ),
        child: Text(
          '去查看',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: enabled
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  String _shortNote(String note) {
    final String oneLine = note.replaceAll('\n', ' ').trim();
    if (oneLine.length <= 12) return oneLine;
    return '${oneLine.substring(0, 12)}…';
  }
}
