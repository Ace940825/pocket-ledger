import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pocket_ledger/shared/widgets/confirm_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failures.dart';
import '../../../../database/app_database.dart';
import '../../../../domain/enums.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../theme/app_colors.dart';
import '../../../record/presentation/account_picker_sheet.dart';
import '../../providers/ledger_providers.dart';

/// 流水行统一滑动手势（全应用流水列表共用）。
///
/// - 左滑（endActionPane）：迁移 / 编辑 / 删除
/// - 右滑（startActionPane）：复制
/// - 点击行本身弹明细弹窗（由 child 的 onTap 承担，本组件不处理点击）。
/// - 互斥：同一列表同时只允许一行滑开——列表需用 [TxnSlidableGroup]
///   包一层（内部为 SlidableAutoCloseBehavior），打开新行时旧行自动滑回。
///
/// 用法：
/// ```dart
/// TxnSlidableGroup(
///   child: ListView(... TxnSlidable(txn: t, child: 行组件) ...),
/// )
/// ```
class TxnSlidable extends ConsumerWidget {
  const TxnSlidable({super.key, required this.txn, required this.child});

  /// 互斥分组标签——同一 [TxnSlidableGroup] 下的行共享此标签。
  static const String groupTag = 'txn-slidable-group';

  final Transaction txn;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Slidable(
      key: ValueKey<String>('slidable-${txn.id}'),
      groupTag: groupTag,
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.48,
        children: <Widget>[
          TxnSlideAction(
            icon: Icons.drive_file_move_outlined,
            semanticLabel: '迁移',
            color: AppPalette.clayBrown,
            onPressed: () => _migrate(context, ref),
          ),
          TxnSlideAction(
            icon: Icons.edit_outlined,
            semanticLabel: '编辑',
            color: AppPalette.info,
            onPressed: () => context.push('/ledger/edit/${txn.id}'),
          ),
          TxnSlideAction(
            icon: Icons.delete_outline,
            semanticLabel: '删除',
            color: AppPalette.danger,
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.16,
        children: <Widget>[
          TxnSlideAction(
            icon: Icons.content_copy,
            semanticLabel: '复制',
            color: AppPalette.primary,
            onPressed: () => _copy(context, ref),
          ),
        ],
      ),
      child: child,
    );
  }

  /// 迁移：把流水改挂到另一账户（余额先回滚旧账户再应用到新账户，
  /// 由 [TransactionRepository.updateTransaction] 统一处理）。
  Future<void> _migrate(BuildContext context, WidgetRef ref) async {
    final String? targetId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => AccountPickerSheet(
        title: '迁移到账户',
        showNoneRow: false,
        showSettings: false,
        // 借出/借入/报销账户余额为派生不变量（由各模块仓储统一维护），
        // 不允许挂普通流水；同时排除流水当前所在账户（原地迁移无意义）。
        filter: (List<Account> all) => all
            .where((Account a) =>
                a.type.category != AccountCategory.receivable &&
                a.type.category != AccountCategory.payable &&
                a.id != txn.accountId)
            .toList(),
        onConfirm: (Account? acc) => Navigator.of(ctx).pop(acc?.id),
      ),
    );
    if (targetId == null || !context.mounted) return;
    try {
      await ref.read(transactionRepositoryProvider).updateTransaction(
            original: txn,
            accountId: targetId,
          );
      if (context.mounted) showAppToast(context, '已迁移');
    } on AppFailure catch (e) {
      if (context.mounted) showAppToast(context, e.message);
    }
  }

  /// 复制：以原流水为模板立即新增一笔（发生时间取当前时刻）。
  ///
  /// 仅限普通记账（ledger）与转账（transfer）流水——借还/投资/报销/退款等
  /// 专属模块流水由各模块仓储管理，直接复制会缺关联数据。
  Future<void> _copy(BuildContext context, WidgetRef ref) async {
    final bool copyable = txn.sourceModule == SourceModule.ledger ||
        txn.sourceModule == SourceModule.transfer;
    if (!copyable) {
      if (context.mounted) showAppToast(context, '该流水由专属模块管理，不支持复制');
      return;
    }
    try {
      await ref.read(transactionRepositoryProvider).add(
            bookId: txn.bookId,
            type: txn.type,
            amountMinor: txn.amountMinor,
            accountId: txn.accountId,
            occurredAt: DateTime.now().toUtc().millisecondsSinceEpoch,
            toAccountId: txn.toAccountId,
            categoryId: txn.categoryId,
            note: txn.note,
            currency: txn.currency,
            sourceModule: txn.type == TxnType.transfer
                ? SourceModule.transfer
                : SourceModule.ledger,
            feeMinor: txn.feeMinor,
            discountMinor: txn.discountMinor,
            tags: _decodeJsonList(txn.tags),
            excludeFromStats: txn.excludeFromStats,
            excludeFromBudget: txn.excludeFromBudget,
            isReimbursable: txn.isReimbursable,
            reimbursementAccountId: txn.reimbursementAccountId,
            attachmentUrls: _decodeJsonList(txn.attachmentUrls),
            latitude: txn.latitude,
            longitude: txn.longitude,
            placeName: txn.placeName,
          );
      if (context.mounted) showAppToast(context, '已复制');
    } on AppFailure catch (e) {
      if (context.mounted) showAppToast(context, e.message);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final bool? confirm = await     showConfirm(
      context,
      title: '删除流水',
      content: '删除后账户余额会相应回滚，此操作不可撤销。',
      confirmText: '删除',
      danger: true,
    );
    if (confirm != true || !context.mounted) return;
    try {
      await ref.read(transactionRepositoryProvider).remove(txn.id);
      if (context.mounted) showAppToast(context, '已删除');
    } on AppFailure catch (e) {
      if (context.mounted) showAppToast(context, e.message);
    }
  }

  /// JSON 数组字符串（tags / attachmentUrls）解码；空/坏数据返回 null。
  List<String>? _decodeJsonList(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? v = jsonDecode(raw);
      if (v is List) return v.cast<String>();
    } catch (_) {
      // 容忍脏数据：解码失败按无数据处理。
    }
    return null;
  }
}

/// 滑动互斥组——包住整个列表（ListView/CustomScrollView 皆可），
/// 组内 [TxnSlidable] 同时只允许一行滑开，打开其他行时已开行自动滑回。
class TxnSlidableGroup extends StatelessWidget {
  const TxnSlidableGroup({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SlidableAutoCloseBehavior(child: child);
  }
}

/// 滑出动作按钮——纯图标圆形徽章样式（全应用滑动列表统一视觉）。
///
/// 设计规范：
/// - 圆形徽章 48×48，底色为动作色 14% 透明度，内圈 1px 20% 描边增加层次
/// - 图标 24px 居中，语义标签走 Icon.semanticLabel（无障碍可读，视觉零文字）
/// - 键体上下各留 8 呼吸边距，水平居中
///
/// 公开供流水以外的滑动列表复用（如投资持仓卡的编辑/删除）。
class TxnSlideAction extends StatelessWidget {
  const TxnSlideAction({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CustomSlidableAction(
      onPressed: (_) => onPressed(),
      backgroundColor: Colors.transparent,
      foregroundColor: color,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Center(
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.20)),
          ),
          alignment: Alignment.center,
          child:
              Icon(icon, size: 24, color: color, semanticLabel: semanticLabel),
        ),
      ),
    );
  }
}
