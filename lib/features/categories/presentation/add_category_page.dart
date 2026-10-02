import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/widgets/category_icons.dart';
import '../providers/categories_providers.dart';
import '../../../shared/widgets/app_toast.dart';

/// 添加一级分类页。
///
/// 通过 [GoRouterState.extra] 传入 [CategoryType]，返回时分类已落库。
class AddCategoryPage extends ConsumerStatefulWidget {
  const AddCategoryPage({super.key, required this.type});

  final CategoryType type;

  @override
  ConsumerState<AddCategoryPage> createState() => _AddCategoryPageState();
}

class _AddCategoryPageState extends ConsumerState<AddCategoryPage> {
  final TextEditingController _nameController = TextEditingController();
  String? _selectedIconKey;
  int? _selectedColorValue;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedIconKey = categoryIconOptions.first.key;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = _selectedColorValue != null
        ? Color(_selectedColorValue!)
        : AppPalette.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('添加分类'),
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
                child: _buildNameField(theme),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
                child: _buildHint(theme),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
                child: _buildColorPicker(theme),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceLg,
                    0,
                    AppDimens.spaceLg,
                    AppDimens.spaceLg,
                  ),
                  child: _buildIconPicker(theme, color),
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
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
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
        color: AppPalette.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.info_outline,
            size: 16,
            color: AppPalette.textTertiary,
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Text(
              '分类名称需手动输入，选择图标后不会自动填充名称。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppPalette.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPicker(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '分类颜色',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppPalette.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        Wrap(
          spacing: AppDimens.spaceSm,
          runSpacing: AppDimens.spaceSm,
          children: <Widget>[
            _ColorChip(
              selected: _selectedColorValue == null,
              color: theme.colorScheme.onSurfaceVariant,
              onTap: () => setState(() => _selectedColorValue = null),
              isDefault: true,
            ),
            for (final int value in _palette)
              _ColorChip(
                selected: _selectedColorValue == value,
                color: Color(value),
                onTap: () => setState(() => _selectedColorValue = value),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildIconPicker(ThemeData theme, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '分类图标',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppPalette.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        GridView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                      ? color.withValues(alpha: 0.15)
                      : AppPalette.surfaceLight,
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  border: Border.all(
                    color: selected ? color : Theme.of(context).colorScheme.outline,
                  ),
                ),
                child: Center(
                  child: Icon(option.icon, color: color),
                ),
              ),
            );
          },
        ),
      ],
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
            type: widget.type,
            colorValue: _selectedColorValue,
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
    showAppToast(context, message);
  }
}

/// 预设分类配色。
const List<int> _palette = <int>[
  0xFFD96F52,
  0xFF5C82B8,
  0xFFB86A9E,
  0xFF8F6FBF,
  0xFF4A96A6,
  0xFF6470C2,
  0xFF4C9E74,
  0xFFCE6478,
  0xFFA97742,
  0xFFC7A24A,
  0xFF8E8A7E,
  0xFF45936A,
];

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.selected,
    required this.color,
    required this.onTap,
    this.isDefault = false,
  });

  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final bool isDefault;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDefault ? AppPalette.surfaceLight : color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.outline,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: isDefault
            ? Icon(
                Icons.auto_awesome,
                color: selected
                    ? Theme.of(context).colorScheme.onSurface
                    : AppPalette.textTertiary,
                size: 20,
              )
            : (selected
                ? Icon(Icons.check, color: Theme.of(context).colorScheme.onPrimary, size: 20)
                : null),
      ),
    );
  }
}
