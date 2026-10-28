import 'package:flutter/material.dart';

import '../../../shared/widgets/line_icon_map.dart';
import '../../../shared/widgets/sheet_scaffold.dart';
import '../../../shared/widgets/text_input_dialog.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimens.dart';
import '../data/bank_data.dart';
import 'widgets/bank_alphabet_index.dart';

/// 银行选择弹层（编辑账户页第二栏「银行信息」入口）。
///
/// 全高底部弹层：搜索框 + 首字母分组列表 + 右侧字母索引 + 右上「自定义」。
/// 与整页 [BankSelectPage] 同源数据（[kBuiltinBanks]），选中后 `pop`
/// 返回银行名；取消返回 null。
Future<String?> showBankPickerSheet(
  BuildContext context, {
  String? selected,
  bool allowClear = false,
}) {
  return showAppModalSheet<String>(
    context,
    isScrollControlled: true,
    constrainHeight: true,
    title: '选择银行',
    titleTrailing: TextButton(
      onPressed: () => _customBank(context),
      child: const Text('自定义'),
    ),
    bodyPadding: EdgeInsets.zero,
    body: _BankPickerBody(selected: selected, allowClear: allowClear),
  );
}

/// 「自定义」入口：输入任意银行名称（不在内置列表时使用）。
Future<void> _customBank(BuildContext context) async {
  final String? name = await showTextInput(
    context,
    title: '自定义银行',
    hint: '输入银行名称',
    validator: (String v) => v.trim().isEmpty ? '请输入银行名称' : null,
  );
  if (name != null && name.trim().isNotEmpty && context.mounted) {
    Navigator.of(context).pop<String>(name.trim());
  }
}

class _BankPickerBody extends StatefulWidget {
  const _BankPickerBody({this.selected, this.allowClear = false});

  /// 当前银行名（列表中高亮）。
  final String? selected;

  /// 是否显示「不选择」按钮（返回空串，用于允许银行留空的场景，如非银行类卡片）。
  final bool allowClear;

  @override
  State<_BankPickerBody> createState() => _BankPickerBodyState();
}

class _BankPickerBodyState extends State<_BankPickerBody> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// 首字母分组头 → GlobalKey（供字母索引 ensureVisible 定位）。
  final Map<String, GlobalKey> _sectionKeys = <String, GlobalKey>{};

  List<Bank> _filteredBanks = kBuiltinBanks;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _filteredBanks = filterBanks(kBuiltinBanks, _searchController.text);
    });
  }

  /// 点字母索引：滚动到对应分组头（↑ 回顶）。
  void _scrollToInitial(String initial) {
    if (initial == '↑') {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      return;
    }
    final GlobalKey? key = _sectionKeys[initial];
    final BuildContext? ctx = key?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Bank>> grouped = groupBanksByInitial(_filteredBanks);
    for (final String initial in grouped.keys) {
      _sectionKeys.putIfAbsent(initial, () => GlobalKey());
    }

    // 拍平成分组头 + 银行行两种条目，ListView 懒加载。
    final List<Object> items = <Object>[];
    for (final MapEntry<String, List<Bank>> entry in grouped.entries) {
      items.add(entry.key);
      items.addAll(entry.value);
    }

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.lg,
            AppDimens.md,
            AppDimens.lg,
            AppDimens.sm,
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索银行',
              prefixIcon: const LineGlyph(Icons.search),
              filled: true,
              fillColor: context.forest.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppDimens.md,
                vertical: AppDimens.sm,
              ),
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: <Widget>[
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('未找到相关银行'))
                    : ListView.builder(
                        controller: _scrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.only(bottom: AppDimens.lg),
                        itemCount: items.length,
                        itemBuilder: (BuildContext context, int index) {
                          final Object item = items[index];
                          if (item is String) {
                            return Container(
                              key: _sectionKeys.putIfAbsent(
                                item,
                                () => GlobalKey(),
                              ),
                              padding: const EdgeInsets.only(
                                left: AppDimens.lg,
                                top: AppDimens.md,
                                bottom: AppDimens.sm,
                              ),
                              child: Text(
                                item,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color:
                                          context.forest.onSurface,
                                    ),
                              ),
                            );
                          }
                          final Bank bank = item as Bank;
                          return _BankRow(
                            bank: bank,
                            selected: bank.name == widget.selected,
                            onTap: () =>
                                Navigator.of(context).pop<String>(bank.name),
                          );
                        },
                      ),
              ),
              SizedBox(
                width: 28,
                child: BankAlphabetIndex(
                  initials: kBankIndexLetters,
                  onTap: _scrollToInitial,
                  available: grouped.keys.toSet(),
                ),
              ),
            ],
          ),
        ),
        if (widget.allowClear)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.lg,
              AppDimens.sm,
              AppDimens.lg,
              AppDimens.lg,
            ),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop<String>(''),
              child: const Text('不选择'),
            ),
          ),
      ],
    );
  }
}

/// 银行行：品牌色首字母圆标 + 名称；当前选中项打勾并转主色。
class _BankRow extends StatelessWidget {
  const _BankRow({
    required this.bank,
    required this.selected,
    required this.onTap,
  });

  final Bank bank;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.lg,
          vertical: AppDimens.md,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bank.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  bank.name.substring(0, 1),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: bank.color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: Text(
                bank.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : null,
                  color: selected
                      ? AppPalette.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (selected)
              const LineGlyph(Icons.check, size: 20, color: AppPalette.primary),
          ],
        ),
      ),
    );
  }
}
