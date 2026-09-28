import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../../theme/app_colors.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../database/app_database.dart';
import '../../../routing/app_router.dart';
import '../../record/presentation/record_sheet.dart';
import '../providers/ledger_providers.dart';
import 'transaction_detail_sheet.dart';
import 'widgets/transaction_tile.dart';
import '../../../shared/widgets/app_toast.dart';

/// 流水列表页。按日期分组，支持侧滑删除。
class LedgerPage extends ConsumerWidget {
  const LedgerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Transaction>> transactions =
        ref.watch(recentTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('流水'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showAppToast(context, '搜索功能将在后续版本提供');
            },
          ),
        ],
      ),
      body: transactions.when(
        data: (List<Transaction> list) {
          if (list.isEmpty) {
            return const EmptyState(message: '还没有记账记录，点右下角记一笔吧');
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (BuildContext context, int index) {
              final Transaction txn = list[index];
              final bool showHeader = index == 0 ||
                  !_isSameDay(list[index - 1].occurredAt, txn.occurredAt);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (showHeader) DateSectionHeader(txn.occurredAt),
                  Slidable(
                    key: ValueKey<String>(txn.id),
                    endActionPane: ActionPane(
                      motion: const DrawerMotion(),
                      children: <Widget>[
                        SlidableAction(
                          onPressed: (_) => _delete(context, ref, txn),
                          backgroundColor: AppColors.expense,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          icon: Icons.delete_outline,
                          label: '删除',
                        ),
                      ],
                    ),
                    child: TransactionTile(
                      transaction: txn,
                      onTap: () => TransactionDetailSheet.show(context, txn),
                    ),
                  ),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace? s) => Center(child: Text('加载失败：$e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openRecordSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  bool _isSameDay(int a, int b) {
    final DateTime da =
        DateTime.fromMillisecondsSinceEpoch(a, isUtc: true).toLocal();
    final DateTime db =
        DateTime.fromMillisecondsSinceEpoch(b, isUtc: true).toLocal();
    return da.year == db.year && da.month == db.month && da.day == db.day;
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Transaction txn,
  ) async {
    try {
      await ref.read(transactionRepositoryProvider).remove(txn.id);

      if (context.mounted) {
        showAppToast(context, '已删除');
      }
    } on AppFailure catch (e) {
      if (context.mounted) {
        showAppToast(context, e.message);
      }
    }
  }
}
