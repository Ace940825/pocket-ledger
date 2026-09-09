import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  Widget build(BuildContext context) {
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
              if (head != null) {
                if (index == 0) return head;
                return itemBuilder(context, list[index - 1]);
              }
              return itemBuilder(context, list[index]);
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

/// 统一的轻提示。
void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
