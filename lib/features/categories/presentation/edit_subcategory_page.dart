import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../shared/widgets/category_icons.dart';
import '../providers/categories_providers.dart';

/// 编辑子分类页。
///
/// 通过 [GoRouterState.extra] 传入一个 record `(Category child, Category parent)`，
/// 返回时子分类已更新。
class EditSubcategoryPage extends ConsumerStatefulWidget {
  const EditSubcategoryPage({
    super.key,
    required this.child,
    required this.parent,
  });

  final Category child;
  final Category parent;

  @override
  ConsumerState<EditSubcategoryPage> createState() =>
      _EditSubcategoryPageState();
}

class _EditSubcategoryPageState extends ConsumerState<EditSubcategoryPage> {
  late final TextEditingController _nameController;
  late String? _selectedIconKey;
  late Category _selectedParent;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.child.name);
    _selectedIconKey = widget.child.iconKey ?? categoryIconOptions.first.key;
    _selectedParent = widget.parent;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color parentColor = _selectedParent.colorValue != null
        ? Color(_selectedParent.colorValue!)
        : AppColors.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑子分类'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () => context.push('/categories'),
            icon: const Icon(Icons.auto_fix_high_outlined),
            label: const Text('自定义'),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceLg,
                  AppDimens.spaceLg,
                  AppDimens.spaceLg,
                  0,
                ),
                child: _buildParentCard(theme, parentColor),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
                child: _buildNameField(theme),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
                child: _buildHint(theme),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceLg,
                    0,
                    AppDimens.spaceLg,
                    AppDimens.spaceLg,
                  ),
                  child: _buildIconPicker(theme, parentColor),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceLg,
                  0,
                  AppDimens.spaceLg,
                  AppDimens.spaceLg,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('保存'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParentCard(ThemeData theme, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: <Widget>[
          Text(
            '所属一级分类',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Icon(categoryIconData(_selectedParent.iconKey), color: color),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Text(
            _selectedParent.name,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildNameField(ThemeData theme) {
    return TextField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: '分类名称',
        border: OutlineInputBorder(),
      ),
      textInputAction: TextInputAction.done,
    );
  }

  Widget _buildHint(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.info_outline,
            size: 16,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Text(
              '分类名称需手动输入，选择图标后不会自动填充名称。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconPicker(ThemeData theme, Color color) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: AppDimens.spaceSm,
        crossAxisSpacing: AppDimens.spaceSm,
        childAspectRatio: 1,
      ),
      itemCount: categoryIconOptions.length,
      itemBuilder: (BuildContext context, int index) {
        final CategoryIconOption option = categoryIconOptions[index];
        final bool selected = option.key == _selectedIconKey;
        return InkWell(
          onTap: () => setState(() => _selectedIconKey = option.key),
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          child: Container(
            decoration: BoxDecoration(
              color: selected
                  ? color.withOpacity(0.15)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              border: Border.all(
                color: selected ? color : AppColors.divider,
              ),
            ),
            child: Center(
              child: Icon(option.icon, color: color),
            ),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      _toast('分类名称不能为空');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(categoryRepositoryProvider).update(
            id: widget.child.id,
            bookId: widget.child.bookId,
            name: name,
            type: widget.child.type,
            parentId: _selectedParent.id,
            colorValue: widget.child.colorValue,
            iconKey: _selectedIconKey,
          );
      if (mounted) {
        context.pop();
      }
    } on AppFailure catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
