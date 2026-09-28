import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_toast.dart';

/// 各业务模块通用的「列表 + 新增 FAB」页面骨架。
///
/// 把 AsyncValue 的三态处理（加载 / 失败 / 空列表）收敛到一处，
/// 每个模块只需要提供 itemBuilder 与新增回调，不再各写一遍 when 分支。
class ModuleListScaffold<T> extends StatelessWidget {
  const ModuleListScaffold({
    super.key,
    required this.title,
    required this.items,
    required this.itemBuilder,
    required this.onCreate,
    this.emptyHint,
    this.header,
    this.actions,
    this.groupHeaderBuilder,
  });

  final String title;
  final AsyncValue<List<T>> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final VoidCallback onCreate;

  /// 空列表提示语，默认「还没有记录，点右下角新增」。
  final String? emptyHint;

  /// 列表顶部的汇总卡片等固定内容。
  final Widget? header;

  final List<Widget>? actions;

  /// 可选的分组小标题：返回非 null 时，会在 [item] 之前插入该标题。
  ///
  /// [previous] 是列表中的前一项（首项为 null），方便调用方只在
  /// 「分组发生变化」时插入标题，例如按月分组：
  /// `previous == null || monthOf(item) != monthOf(previous)`。
  ///
  /// 调用方需保证 [items] 已按分组键排好序，否则同组会被拆开。
  final Widget? Function(BuildContext context, T item, T? previous)?
      groupHeaderBuilder;

  @override
  Widget build(BuildContext context) {
    final Widget? Function(BuildContext, T, T?)? groupHead = groupHeaderBuilder;

    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: items.when(
        data: (List<T> list) {
          final Widget? head = header;
          if (list.isEmpty) {
            return Column(
              children: <Widget>[
                if (head != null) head,
                Expanded(
                  child: Center(
                    child: Text(emptyHint ?? '还没有记录，点右下角新增'),
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: list.length + (head == null ? 0 : 1),
            separatorBuilder: (BuildContext _, int __) =>
                const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              final T item;
              final T? previous;
              if (head != null) {
                if (index == 0) return head;
                final int i = index - 1;
                item = list[i];
                previous = i == 0 ? null : list[i - 1];
              } else {
                item = list[index];
                previous = index == 0 ? null : list[index - 1];
              }

              final Widget row = itemBuilder(context, item);
              if (groupHead == null) return row;

              final Widget? groupTitle = groupHead(context, item, previous);
              if (groupTitle == null) return row;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[groupTitle, row],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(child: Text('加载失败：$e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: onCreate,
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// 统一的删除二次确认弹窗。返回 true 表示用户确认删除。
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  String content = '删除后不可撤销。',
}) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialog) => AlertDialog(
      title: Text(title),
      content: Text(content),
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
  return confirmed ?? false;
}

/// 统一的轻提示（短时长、替换式，见 [showAppToast]）。
void showToast(BuildContext context, String message) {
  showAppToast(context, message);
}
