import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocket_ledger/shared/widgets/hairline_card.dart';

import 'package:pocket_ledger/theme/app_dimens.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/category_icons.dart';
import '../../../shared/widgets/color_chip.dart';
import '../../../shared/widgets/line_icon_map.dart';
import '../../../shared/widgets/line_icons.dart';
import '../../../theme/app_colors.dart';
import '../providers/categories_providers.dart';

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
                child: _buildNameField(theme),
              ),
              const SizedBox(height: AppDimens.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
                child: _buildHint(theme),
              ),
              const SizedBox(height: AppDimens.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
                child: _buildColorPicker(theme),
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
                  child: _buildIconPicker(theme, color),
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppDimens.sm),
          Expanded(
            child: Text(
              '分类名称需手动输入，选择图标后不会自动填充名称。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppDimens.sm),
        // 横向一排、可左滑（第 38 批）：20 色一屏放不下，改横向滚动；
        // ColorChip 自带 6px 透明 padding，相邻圆点天然 12px 间距。
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              ColorChip(
                selected: _selectedColorValue == null,
                color: theme.colorScheme.onSurfaceVariant,
                onTap: () => setState(() => _selectedColorValue = null),
                isDefault: true,
              ),
              for (final int value in _palette)
                ColorChip(
                  selected: _selectedColorValue == value,
                  color: Color(value),
                  onTap: () => setState(() => _selectedColorValue = value),
                ),
            ],
          ),
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppDimens.sm),
        GridView.builder(
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
                    color: selected
                        ? color
                        : Theme.of(context).colorScheme.outline,
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

/// 预设分类配色（ForestSage 调和色板，与 bootstrap 种子同源）。
///
/// 2026-10-16 第 38 批：12 → 24 色并改按色相环排列（中性→暖→红粉→
/// 紫→蓝→青绿），便于横向滑动时顺色找色。原 12 色 + bootstrap 种子色
/// （蜜金/苔绿/黛蓝/深青，旧色板漏收——编辑默认分类时选不回自己的色）
/// 全部保留，colorValue 存色值本身，存量分类零影响；新增选择器专用
/// 8 色（正红/暖橙/明黄/薄荷/天蓝/浅紫/蓝灰/深粉）。仅选择器选项。
const List<int> _palette = <int>[
  // 中性 / 大地
  0xFF8E8A7E, // 暖灰
  0xFF7A8B99, // 蓝灰
  0xFFA97742, // 驼棕
  0xFFC7A24A, // 赭金
  0xFFD69E3C, // 蜜金（种子色）
  // 暖 → 红粉
  0xFFE0C56A, // 明黄
  0xFFE8873F, // 暖橙
  0xFFD96F52, // 赤陶
  0xFFD9584E, // 正红
  0xFFCE6478, // 玫瑰
  0xFFC94F6E, // 深粉
  // 紫 → 蓝
  0xFFB86A9E, // 藕紫
  0xFF9B7BC8, // 浅紫
  0xFF8F6FBF, // 紫罗兰
  0xFF6470C2, // 靛蓝
  0xFF5C82B8, // 雾蓝
  0xFF6FA8DC, // 天蓝
  0xFF4E93A6, // 黛蓝（种子色）
  // 青 → 绿
  0xFF4A96A6, // 青
  0xFF3E8E8E, // 深青（种子色）
  0xFF5FB8A8, // 薄荷
  0xFF7E9B6B, // 苔绿（种子色）
  0xFF4C9E74, // 草绿
  0xFF45936A, // 松绿
];
