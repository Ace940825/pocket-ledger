import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_dimens.dart';
import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/date_field.dart';
import '../data/lend_repository.dart';
import '../providers/lend_providers.dart';

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
                          DateTime.fromMillisecondsSinceEpoch(r.dueAt!, isUtc: true),
                        )}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _confirmDelete(context, ref, r),
                    ),
                  ],
                ),
                onTap: () => _showEditor(context, ref, r),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('加载失败：$e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditor(context, ref),
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

  Future<void> _showEditor(
    BuildContext context,
    WidgetRef ref, [
    LendRecord? record,
  ]) async {
    final TextEditingController counterpartyController =
        TextEditingController(text: record?.counterparty ?? '');
    final TextEditingController amountController = TextEditingController(
      text: record != null
          ? Money.fromMinor(record.amountMinor).decimal.toStringAsFixed(2)
          : '',
    );
    final TextEditingController noteController =
        TextEditingController(text: record?.note ?? '');

    LendDirection direction = record?.direction ?? LendDirection.lendOut;
    LendStatus status = record?.status ?? LendStatus.ongoing;
    DateTime occurredAt = record != null
        ? DateTime.fromMillisecondsSinceEpoch(record.occurredAt, isUtc: true)
            .toLocal()
        : DateTime.now();
    int? dueAt = record?.dueAt;

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setState) => AlertDialog(
          title: Text(record == null ? '新增借还' : '编辑借还'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: counterpartyController,
                  decoration: const InputDecoration(labelText: '对方（人/单位）'),
                  autofocus: true,
                ),
                const SizedBox(height: AppDimens.spaceMd),
                DropdownButtonFormField<LendDirection>(
                  value: direction,
                  decoration: const InputDecoration(labelText: '方向'),
                  items: <DropdownMenuItem<LendDirection>>[
                    for (final LendDirection d in LendDirection.values)
                      DropdownMenuItem<LendDirection>(
                        value: d,
                        child: Text(d.label),
                      ),
                  ],
                  onChanged: (LendDirection? v) {
                    if (v != null) setState(() => direction = v);
                  },
                ),
                const SizedBox(height: AppDimens.spaceMd),
                DropdownButtonFormField<LendStatus>(
                  value: status,
                  decoration: const InputDecoration(labelText: '状态'),
                  items: <DropdownMenuItem<LendStatus>>[
                    for (final LendStatus s in LendStatus.values)
                      DropdownMenuItem<LendStatus>(
                        value: s,
                        child: Text(s.label),
                      ),
                  ],
                  onChanged: (LendStatus? v) {
                    if (v != null) setState(() => status = v);
                  },
                ),
                const SizedBox(height: AppDimens.spaceMd),
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '金额',
                    prefixText: '¥ ',
                  ),
                ),
                const SizedBox(height: AppDimens.spaceMd),
                DateField(
                  label: '发生日期',
                  value: occurredAt,
                  onChanged: (DateTime? v) {
                    if (v != null) setState(() => occurredAt = v);
                  },
                ),
                DateField(
                  label: '到期日（可选）',
                  value: dueAt == null
                      ? null
                      : DateTime.fromMillisecondsSinceEpoch(dueAt!, isUtc: true)
                          .toLocal(),
                  onChanged: (DateTime? v) =>
                      setState(() => dueAt = v?.toUtc().millisecondsSinceEpoch),
                  allowClear: true,
                ),
                const SizedBox(height: AppDimens.spaceMd),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: '备注'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialog).pop(true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !context.mounted) return;

    final String cp = counterpartyController.text.trim();
    if (cp.isEmpty) {
      _toast(context, '对方不能为空');
      return;
    }
    final double? amt = double.tryParse(amountController.text.trim());
    if (amt == null || amt <= 0) {
      _toast(context, '金额必须大于 0');
      return;
    }
    final int amountMinor = Money.fromDecimal(amt).minor;
    final int occurredMs = occurredAt.toUtc().millisecondsSinceEpoch;

    try {
      final LendRepository repo = ref.read(lendRepositoryProvider);
      if (record == null) {
        await repo.add(
          bookId: ref.read(currentBookIdProvider),
          direction: direction,
          status: status,
          counterparty: cp,
          amountMinor: amountMinor,
          occurredAt: occurredMs,
          dueAt: dueAt,
          note: noteController.text.trim(),
        );
      } else {
        await repo.update(
          id: record.id,
          direction: direction,
          status: status,
          counterparty: cp,
          amountMinor: amountMinor,
          occurredAt: occurredMs,
          dueAt: dueAt,
          note: noteController.text.trim(),
        );
      }
    } on AppFailure catch (e) {
      if (context.mounted) _toast(context, e.message);
    }
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

/// 借还页用的配色：借出视为应收（红/支出侧），借入视为应付（绿/收入侧）。
const Color _lendOutColor = Color(0xFFE53935);
const Color _lendInColor = Color(0xFF43A047);
