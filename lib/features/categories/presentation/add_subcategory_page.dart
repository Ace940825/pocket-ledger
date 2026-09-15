import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/widgets/category_icons.dart';
import '../providers/categories_providers.dart';

/// 添加子分类页。
///
/// 通过 [GoRouterState.extra] 传入父分类 [Category]，返回时子分类已落库。
class AddSubcategoryPage extends ConsumerStatefulWidget {
  const AddSubcategoryPage({super.key, required this.parent});

  final Category parent;

  @override
  ConsumerState<AddSubcategoryPage> createState() =>
      _AddSubcategoryPageState();
}

class _AddSubcategoryPageState extends ConsumerState<AddSubcategoryPage> {
  final TextEditingController _nameController = TextEditingController();
  String? _selectedIconKey;
  bool _textAsIcon = false;
  bool _saving = false;

  static const List<String> _quickNames = <String>[
    '餐饮',
    '购物',
    '娱乐',
    '交通',
    '职业收入',
    '学习',
    '旅游',
    '医疗',
    '会员',
    '通讯',
    '日常',
    '人情',
  ];

  @override
  void initState() {
    super.initState();
    _selectedIconKey = categoryIconOptions.first.key;
    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    if (mounted && _textAsIcon) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color parentColor = widget.parent.colorValue != null
        ? Color(widget.parent.colorValue!)
        : AppColors.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('添加子分类'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () => context.push('/categories'),
            icon: const Icon(Icons.auto_fix_high_outlined),
            label: const Text('自定义'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildParentCard(theme, parentColor),
              const SizedBox(height: AppDimens.spaceLg),
              _buildNameField(theme),
              const SizedBox(height: AppDimens.spaceLg),
              _buildTextAsIconTile(theme),
              const SizedBox(height: AppDimens.spaceSm),
              _buildHint(theme),
              const SizedBox(height: AppDimens.spaceLg),
              _buildQuickNames(theme),
              const SizedBox(height: AppDimens.spaceLg),
              _buildIconPicker(theme, parentColor),
              const SizedBox(height: AppDimens.spaceXxl),
              SizedBox(
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
            '一级分类',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: widget.parent.iconKey == kCategoryIconText &&
                    widget.parent.name.isNotEmpty
                ? Text(
                    widget.parent.name[0],
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : Icon(categoryIconData(widget.parent.iconKey), color: color),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Text(
            widget.parent.name,
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
      autofocus: true,
      textInputAction: TextInputAction.done,
    );
  }

  Widget _buildTextAsIconTile(ThemeData theme) {
    return SwitchListTile(
      value: _textAsIcon,
      onChanged: (bool v) => setState(() => _textAsIcon = v),
      title: const Text('文字作为图标'),
      subtitle: const Text('开启后会将分类名称的首字作为图标'),
      contentPadding: EdgeInsets.zero,
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
              '可以用 emoji 开头，图标自动为 emoji 图标。\n'
              '选择分类图标后，名称会自动填充，也可以手动修改分类名称。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickNames(ThemeData theme) {
    return Wrap(
      spacing: AppDimens.spaceSm,
      runSpacing: AppDimens.spaceSm,
      children: _quickNames.map((String name) {
        return ActionChip(
          label: Text(name),
          onPressed: () {
            _nameController.text = name;
            _nameController.selection = TextSelection.collapsed(
              offset: name.length,
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildIconPicker(ThemeData theme, Color color) {
    if (_textAsIcon) {
      return Center(
        child: CircleAvatar(
          radius: 36,
          backgroundColor: color.withOpacity(0.15),
          child: Text(
            _nameController.text.isNotEmpty
                ? _nameController.text[0]
                : '字',
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: AppDimens.spaceSm,
        crossAxisSpacing: AppDimens.spaceSm,
        childAspectRatio: 0.85,
      ),
      itemCount: categoryIconOptions.length,
      itemBuilder: (BuildContext context, int index) {
        final CategoryIconOption option = categoryIconOptions[index];
        final bool selected = option.key == _selectedIconKey;
        return InkWell(
          onTap: () {
            setState(() => _selectedIconKey = option.key);
            if (_nameController.text.trim().isEmpty) {
              _nameController.text = option.label;
            }
          },
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(option.icon, color: color),
                const SizedBox(height: 4),
                Text(
                  option.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
      final String bookId = ref.read(currentBookIdProvider);
      await ref.read(categoryRepositoryProvider).add(
            bookId: bookId,
            name: name,
            type: widget.parent.type,
            parentId: widget.parent.id,
            colorValue: widget.parent.colorValue,
            iconKey: _textAsIcon ? kCategoryIconText : _selectedIconKey,
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
