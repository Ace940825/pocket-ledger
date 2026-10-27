import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_ledger/core/theme/forest_design_tokens.dart';
import 'package:pocket_ledger/providers/app_providers.dart';
import 'package:pocket_ledger/shared/widgets/app_toast.dart';
import 'package:pocket_ledger/shared/widgets/empty_state.dart';
import 'package:pocket_ledger/shared/widgets/hairline_card.dart';
import 'package:pocket_ledger/shared/widgets/line_icon_map.dart';
import 'package:pocket_ledger/sync/conflict_models.dart';
import 'package:pocket_ledger/sync/sync_field_meta.dart';
import 'package:pocket_ledger/theme/app_dimens.dart';
import 'package:pocket_ledger/theme/app_theme.dart';

/// 字段级冲突解决页。
///
/// 同步采用 [ConflictPolicy.prompt] 时，pull 阶段遇到「本地有未同步修改 + 云端更新
/// + 字段差异」的真冲突会暂存到这里，由用户逐字段选择「保留本地」或「采用云端」。
/// 全部选择后点「保存合并」落库，并（若含本地选择）重新入队回推云端，使多设备收敛。
class SyncConflictPage extends ConsumerWidget {
  const SyncConflictPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SyncConflict>> conflicts =
        ref.watch(conflictsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('冲突解决')),
      body: conflicts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('读取失败：$e')),
        data: (List<SyncConflict> rows) {
          if (rows.isEmpty) {
            return const EmptyState(
              message: '没有待解决的冲突',
              subMessage: '切换为「逐字段选择」策略后，若同步发生本地与云端不一致，'
                  '需要人工裁决的记录会显示在这里。',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppDimens.lg),
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(bottom: AppDimens.md),
                child: Text(
                  '以下记录本地与云端都改过且不一致。请逐字段选择要保留的版本，'
                  '然后点「保存合并」。默认保留本地修改。',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              for (final SyncConflict c in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppDimens.lg),
                  child: _ConflictCard(conflict: c),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 单条冲突卡片：逐字段二选一 + 全部本地 / 全部云端 / 保存合并。
class _ConflictCard extends ConsumerStatefulWidget {
  const _ConflictCard({required this.conflict});

  final SyncConflict conflict;

  @override
  ConsumerState<_ConflictCard> createState() => _ConflictCardState();
}

class _ConflictCardState extends ConsumerState<_ConflictCard> {
  late final Map<String, bool> _choices;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // 默认全部采用本地（更保守，避免丢本地编辑）。
    _choices = <String, bool>{
      for (final SyncConflictField f in _fields) f.field: true,
    };
  }

  List<SyncConflictField> get _fields =>
      SyncFieldMeta.buildFields(widget.conflict);

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final int n = await ref
          .read(syncControllerProvider.notifier)
          .resolveConflict(widget.conflict.id, Map<String, bool>.from(_choices));
      ref.invalidate(conflictsProvider);
      if (!mounted) return;
      showAppToast(context, n > 0 ? '已合并保存' : '未找到该冲突（可能已解决）');
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, '保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _useAll(bool local) =>
      setState(() => _choices.updateAll((_, __) => local));

  @override
  Widget build(BuildContext context) {
    final SyncConflict c = widget.conflict;
    final DateTime at =
        DateTime.fromMillisecondsSinceEpoch(c.conflictAt, isUtc: true).toLocal();

    return HairlineCard(
      padding: const EdgeInsets.all(AppDimens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              LineGlyph(Icons.gpp_maybe_outlined, size: 18, color: context.forest.primary),
              const SizedBox(width: AppDimens.sm),
              Expanded(
                child: Text(
                  SyncFieldMeta.tableLabel(c.table),
                  style: context.text.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${at.year}-${at.month.toString().padLeft(2, '0')}-'
                '${at.day.toString().padLeft(2, '0')} '
                '${at.hour.toString().padLeft(2, '0')}:'
                '${at.minute.toString().padLeft(2, '0')}',
                style: context.text.bodySmall
                    ?.copyWith(color: context.forest.onSurfaceVariant),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: AppDimens.sm),
            child: Text(
              '记录 ID：${c.recordId}',
              style: context.text.bodySmall
                  ?.copyWith(color: context.forest.onSurfaceVariant),
            ),
          ),
          const Divider(height: AppDimens.md),
          for (final SyncConflictField f in _fields) _FieldRow(field: f, choices: _choices),
          const SizedBox(height: AppDimens.md),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => _useAll(true),
                  child: const Text('全用本地'),
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => _useAll(false),
                  child: const Text('全用云端'),
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('保存合并'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 单个字段的二选一：本地 / 云端。
class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.field, required this.choices});

  final SyncConflictField field;
  final Map<String, bool> choices;

  @override
  Widget build(BuildContext context) {
    final bool useLocal = choices[field.field] ?? true;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            field.label,
            style: context.text.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: _Side(
                  selected: useLocal,
                  tag: '本地',
                  value: field.localDisplay,
                  onTap: () => choices[field.field] = true,
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Expanded(
                child: _Side(
                  selected: !useLocal,
                  tag: '云端',
                  value: field.remoteDisplay,
                  onTap: () => choices[field.field] = false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 本地 / 云端一侧的选择块。
class _Side extends StatelessWidget {
  const _Side({
    required this.selected,
    required this.tag,
    required this.value,
    required this.onTap,
  });

  final bool selected;
  final String tag;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color border = selected
        ? context.forest.primary
        : context.forest.outline;
    final Color bg = selected
        ? context.forest.primaryContainer
        : context.forest.surfaceContainerHighest;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md,
          vertical: AppDimens.sm,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(color: border, width: selected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              tag,
              style: context.text.bodySmall?.copyWith(
                color: selected
                    ? context.forest.primary
                    : context.forest.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: context.text.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
