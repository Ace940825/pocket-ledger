import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/models/money.dart';
import '../providers/lend_providers.dart';
import '../../record/record_tab.dart';
import '../../record/presentation/record_sheet.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../theme/theme.dart';

/// 借还页：借出 / 借入记录与状态跟踪。
class LendPage extends ConsumerStatefulWidget {
  const LendPage({super.key});

  @override
  ConsumerState<LendPage> createState() => _LendPageState();
}

class _LendPageState extends ConsumerState<LendPage> {
  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<LendRecord>> records = ref.watch(lendListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('借还')),
      body: records.when(
        data: (List<LendRecord> list) {
          if (list.isEmpty) {
            return const Center(child: Text('还没有借还记录，点右下角新增'));
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              final LendRecord r = list[index];
              return ListTile(
                leading: Icon(
                  r.direction == LendDirection.lendOut
                      ? Icons.north_east
                      : Icons.south_west,
                  color: r.direction == LendDirection.lendOut
                      ? _lendOutColor
                      : _lendInColor,
                ),
                title: Text(r.counterparty),
                subtitle: Text(
                  '${r.direction.label} · ${r.status.label} · '
                  '${Money.fromMinor(r.amountMinor).format()}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (r.dueAt != null)
                      Text(
                        '到期 ${DateFormat('MM-dd').format(
                          DateTime.fromMillisecondsSinceEpoch(r.dueAt!,
                              isUtc: true),
                        )}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _confirmDelete(context, ref, r),
                    ),
                  ],
                ),
                onTap: () => openRecordSheet(context, editLendId: r.id),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('加载失败：$e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openRecordSheet(context, initialTab: RecordTab.lend),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    LendRecord record,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('删除这条借还记录？'),
        content: const Text('删除后不可撤销。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(lendRepositoryProvider).remove(record.id);
    } on AppFailure catch (e) {
      if (context.mounted) _toast(context, e.message);
    }
  }


  void _toast(BuildContext context, String message) {
    showAppToast(context, message);
  }
}

/// 借还页用的配色：借出视为应收（红/支出侧），借入视为应付（绿/收入侧）。
const Color _lendOutColor = AppPalette.expense;
const Color _lendInColor = AppPalette.income;
