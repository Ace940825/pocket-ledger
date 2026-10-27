import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocket_ledger/shared/widgets/clay_icon_tile.dart';
import 'package:pocket_ledger/shared/widgets/hairline_card.dart';

import 'package:pocket_ledger/theme/app_dimens.dart';
import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/category_icons.dart';
import '../../../shared/widgets/line_icon_map.dart';
import '../../../shared/widgets/line_icons.dart';
import '../../../theme/app_colors.dart';
import '../providers/categories_providers.dart';

/// 添加子分类页。
///
/// 通过 [GoRouterState.extra] 传入父分类 [Category]，返回时子分类已落库。
class AddSubcategoryPage extends ConsumerStatefulWidget {
  const AddSubcategoryPage({super.key, required this.parent});

  final Category parent;

  @override
  ConsumerState<AddSubcategoryPage> createState() => _AddSubcategoryPageState();
}

class _AddSubcategoryPageState extends ConsumerState<AddSubcategoryPage> {
  final TextEditingController _nameController = TextEditingController();
  String? _selectedIconKey;
  bool _saving = false;
  late Category _selectedParent;

  @override
  void initState() {
    super.initState();
    _selectedParent = widget.parent;
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
    final Color parentColor = _selectedParent.colorValue != null
        ? Color(_selectedParent.colorValue!)
        : AppPalette.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('添加子分类'),
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
                  AppDimens.lg,
                  AppDimens.lg,
                  AppDimens.lg,
                  0,
                ),
                child: _buildParentCard(theme, parentColor),
              ),
              const SizedBox(height: AppDimens.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
                child: _buildNameField(theme),
              ),
              const SizedBox(height: AppDimens.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
                child: _buildHint(theme),
              ),
              const SizedBox(height: AppDimens.lg),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.lg,
                    0,
                    AppDimens.lg,
                    AppDimens.lg,
                  ),
                  child: _buildIconPicker(theme, parentColor),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.lg,
                  0,
                  AppDimens.lg,
                  AppDimens.lg,
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
                              color: context.forest.onPrimary,
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
    return HairlineCard(
      radius: AppDimens.radiusMd,
      padding: const EdgeInsets.all(AppDimens.md),
      child: Row(
        children: <Widget>[
          Text(
            '所属一级分类',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.forest.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          ClayIconTile(
            size: 40,
            color: color,
            child: LineIcon(
              categoryLineKind(_selectedParent.iconKey) ?? LineIconKind.star,
              size: 20,
              color: Color.lerp(
                color,
                context.forest.onSurface,
                0.22,
              )!,
            ),
          ),
          const SizedBox(width: AppDimens.sm),
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
    return HairlineCard(
      radius: AppDimens.radiusMd,
      padding: const EdgeInsets.all(AppDimens.md),
      borderWidth: 0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LineGlyph(
            Icons.info_outline,
            size: 16,
            color: context.forest.onSurfaceVariant,
          ),
          const SizedBox(width: AppDimens.sm),
          Expanded(
            child: Text(
              '分类名称需手动输入，选择图标后不会自动填充名称。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.forest.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconPicker(ThemeData theme, Color color) {
    return GridView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: AppDimens.sm,
        crossAxisSpacing: AppDimens.sm,
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
                color: selected ? color : context.forest.outline,
              ),
            ),
            child: Center(
              child: LineIcon(
                categoryLineKind(option.key) ?? LineIconKind.star,
                size: 24,
                color: color,
              ),
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
            type: _selectedParent.type,
            parentId: _selectedParent.id,
            colorValue: _selectedParent.colorValue,
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
