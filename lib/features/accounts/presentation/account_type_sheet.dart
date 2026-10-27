import 'package:flutter/material.dart';

import '../../../domain/enums.dart';
import '../../../shared/widgets/clay_icon_tile.dart';
import '../../../shared/widgets/line_icon_map.dart';
import '../../../shared/widgets/line_icons.dart';
import '../../../shared/widgets/sheet_scaffold.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimens.dart';
import '../data/account_icon.dart';
import '../data/account_type_groups.dart';

/// 「资产类型」选择弹层（编辑账户页第一栏入口）。
///
/// 两级结构（与新增账户页的五大 Tab 同源，见 [accountTypesForCategory]）：
/// - 一级：五大类（资金 / 负债 / 投资 / 应收 / 应付）；
/// - 二级：所选大类下的账户类型，顶部带「返回大类」行。
///
/// 选中类型后 `pop` 返回 [AccountType]；取消（点框外 / 下滑）返回 null。
Future<AccountType?> showAccountTypeSheet(
  BuildContext context, {
  AccountType? current,
}) {
  return showAppModalSheet<AccountType>(
    context,
    isScrollControlled: true,
    title: '资产类型',
    bodyPadding: EdgeInsets.zero,
    body: _AccountTypeSheetBody(current: current),
  );
}

class _AccountTypeSheetBody extends StatefulWidget {
  const _AccountTypeSheetBody({this.current});

  /// 当前账户类型（二级列表中标出选中项）。
  final AccountType? current;

  @override
  State<_AccountTypeSheetBody> createState() => _AccountTypeSheetBodyState();
}

class _AccountTypeSheetBodyState extends State<_AccountTypeSheetBody> {
  /// null = 一级（大类列表）；非 null = 二级（该大类下的类型列表）。
  AccountCategory? _category;

  @override
  Widget build(BuildContext context) {
    final AccountCategory? category = _category;
    // 一级 5 行 / 二级最多 9 行 + 返回行：shrinkWrap 让弹层按内容自适应，
    // 超出路由帽时在槽位内滚动（Flexible(loose) 兜底，不会溢出）。
    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      children: <Widget>[
        if (category == null)
          ..._categoryRows()
        else ...<Widget>[
          _BackRow(
            label: category.label,
            onTap: () => setState(() => _category = null),
          ),
          for (final AccountType type in accountTypesForCategory(category))
            _TypeRow(
              type: type,
              selected: type == widget.current,
              onTap: () => Navigator.of(context).pop(type),
            ),
        ],
        const SizedBox(height: AppDimens.sm),
      ],
    );
  }

  List<Widget> _categoryRows() => <Widget>[
        for (final AccountCategory category in kAccountCategoryOrder)
          _SheetRow(
            icon: accountCategoryLineKind(category),
            label: category.label,
            trailing: LineGlyph(
              Icons.chevron_right,
              size: 22,
              color: context.forest.onSurfaceVariant,
            ),
            onTap: () => setState(() => _category = category),
          ),
      ];
}

/// 弹层通用行：黏土方糖图标 + 名称 + 尾部附加件。
class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.selected = false,
  });

  final LineIconKind icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  /// 选中态：名称转主色、加粗（仅二级类型行使用）。
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md,
          vertical: AppDimens.sm,
        ),
        child: Row(
          children: <Widget>[
            ClayIconTile(
              size: 40,
              color: AppPalette.primary,
              child: LineIcon(
                icon,
                size: 20,
                color: Color.lerp(
                  AppPalette.primary,
                  theme.colorScheme.onSurface,
                  0.22,
                )!,
              ),
            ),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected
                      ? AppPalette.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: AppDimens.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 二级「返回大类」行：返回箭头 + 大类名（点击回到一级）。
class _BackRow extends StatelessWidget {
  const _BackRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md,
          vertical: AppDimens.sm,
        ),
        child: Row(
          children: <Widget>[
            LineGlyph(
              Icons.arrow_back_ios_new,
              size: 18,
              color: context.forest.onSurfaceVariant,
            ),
            const SizedBox(width: AppDimens.sm),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.forest.onSurface,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 二级「账户类型」行：选中项尾部打勾。
class _TypeRow extends StatelessWidget {
  const _TypeRow({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final AccountType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SheetRow(
      icon: accountLineKind(type) ?? LineIconKind.star,
      label: type.label,
      selected: selected,
      trailing: selected
          ? const LineGlyph(Icons.check, size: 20, color: AppPalette.primary)
          : null,
      onTap: onTap,
    );
  }
}
