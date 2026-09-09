import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/errors/failures.dart';
import '../../../../domain/enums.dart';
import '../../../../providers/app_providers.dart';
import '../../../database/app_database.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../data/category_repository.dart';
import '../providers/categories_providers.dart';

/// 分类管理页：按「支出 / 收入」切换，支持新增、编辑、删除分类。
class CategoryManagePage extends ConsumerStatefulWidget {
  const CategoryManagePage({super.key});

  @override
  ConsumerState<CategoryManagePage> createState() =>
      _CategoryManagePageState();
}

class _CategoryManagePageState extends ConsumerState<CategoryManagePage> {
  CategoryType _type = CategoryType.expense;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Category>> categories = ref.watch(
      _type == CategoryType.income
          ? incomeCategoriesProvider
          : expenseCategoriesProvider,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('分类管理')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppDimens.spaceLg),
            child: SegmentedButton<CategoryType>(
              segments: const <ButtonSegment<CategoryType>>[
                ButtonSegment<CategoryType>(
                  value: CategoryType.expense,
                  label: Text('支出'),
                ),
                ButtonSegment<CategoryType>(
                  value: CategoryType.income,
                  label: Text('收入'),
                ),
              ],
              selected: <CategoryType>{_type},
              onSelectionChanged: (Set<CategoryType> next) =>
                  setState(() => _type = next.first),
            ),
          ),
          Expanded(
            child: categories.when(
              data: (List<Category> list) {
                if (list.isEmpty) {
                  return const Center(child: Text('还没有分类，点右下角新增'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(
                    left: AppDimens.spaceLg,
                    right: AppDimens.spaceLg,
                    bottom: 88,
                  ),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    final Category c = list[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: c.colorValue != null
                            ? Color(c.colorValue!).withOpacity(0.15)
                            : AppColors.primary.withOpacity(0.12),
                        child: Text(
                          c.name.isNotEmpty ? c.name[0] : '?',
                          style: TextStyle(
                            color: c.colorValue != null
                                ? Color(c.colorValue!)
                                : AppColors.primary,
                          ),
                        ),
                      ),
                      title: Text(c.name),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => _confirmDelete(context, ref, c),
                      ),
                      onTap: () => _showEditor(context, ref, category: c),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, _) => Center(child: Text('加载失败：$e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditor(context, ref, type: _type),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('删除分类？'),
        content: Text('「${category.name}」将被删除。已使用该分类的流水会显示为「未分类」。'),
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
      await ref.read(categoryRepositoryProvider).remove(category.id);
    } on AppFailure catch (e) {
      if (context.mounted) _toast(context, e.message);
    }
  }

  Future<void> _showEditor(
    BuildContext context,
    WidgetRef ref, {
    Category? category,
    CategoryType? type,
  }) async {
    final TextEditingController nameController =
        TextEditingController(text: category?.name ?? '');
    int? colorValue = category?.colorValue;
    final CategoryType editorType = category?.type ?? type ?? _type;

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setState) => AlertDialog(
          title: Text(category == null ? '新增分类' : '编辑分类'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '分类名称'),
                  autofocus: true,
                ),
                const SizedBox(height: AppDimens.spaceMd),
                Text(
                  '颜色（可选）',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: AppDimens.spaceSm),
                Wrap(
                  spacing: AppDimens.spaceSm,
                  children: <Widget>[
                    _ColorChip(
                      selected: colorValue == null,
                      color: Colors.grey,
                      onTap: () => setState(() => colorValue = null),
                    ),
                    ..._palette.map(
                      (int c) => _ColorChip(
                        selected: colorValue == c,
                        color: Color(c),
                        onTap: () => setState(() => colorValue = c),
                      ),
                    ),
                  ],
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
    final String name = nameController.text.trim();
    if (name.isEmpty) {
      _toast(context, '分类名称不能为空');
      return;
    }

    try {
      final CategoryRepository repo = ref.read(categoryRepositoryProvider);
      if (category == null) {
        await repo.add(
          bookId: ref.read(currentBookIdProvider),
          name: name,
          type: editorType,
          colorValue: colorValue,
        );
      } else {
        await repo.update(
          id: category.id,
          bookId: category.bookId,
          name: name,
          type: editorType,
          colorValue: colorValue,
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

/// 预设分类配色（与 AppColors.chartPalette 同源，便于视觉统一）。
const List<int> _palette = <int>[
  0xFFE57373,
  0xFFF06292,
  0xFFBA68C8,
  0xFF9575CD,
  0xFF7986CB,
  0xFF64B5F6,
  0xFF4FC3F7,
  0xFF4DB6AC,
  0xFF81C784,
  0xFFFFB74D,
  0xFFA1887F,
  0xFF90A4AE,
];

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.only(bottom: AppDimens.spaceSm),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2)
              : null,
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
}
