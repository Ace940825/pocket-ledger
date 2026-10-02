import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../data/bank_data.dart';

/// 银行选择页。
///
/// 从 [AddAccountPage] 选择「信用卡/借记卡」后进入此页，用户选择银行后
/// 通过 [Navigator.pop] 返回选中的银行名称。点击 AppBar 右上角「自定义」
/// 可输入任意银行名称。
class BankSelectPage extends StatefulWidget {
  const BankSelectPage({super.key, this.title = '选择银行'});

  /// 页面标题，信用卡场景为「信用卡」，借记卡场景为「借记卡」。
  final String title;

  @override
  State<BankSelectPage> createState() => _BankSelectPageState();
}

class _BankSelectPageState extends State<BankSelectPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
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

  void _selectBank(Bank bank) {
    Navigator.of(context).pop<String>(bank.name);
  }

  Future<void> _showCustomBankDialog() async {
    final TextEditingController controller = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('自定义银行'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入银行名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final String value = controller.text.trim();
              if (value.isNotEmpty) Navigator.of(context).pop<String>(value);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (name != null && mounted) {
      Navigator.of(context).pop<String>(name);
    }
  }

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
    if (key == null) return;
    final RenderObject? renderBox = key.currentContext?.findRenderObject();
    if (renderBox is! RenderBox) return;

    final double offset = renderBox.localToGlobal(Offset.zero).dy +
        _scrollController.offset -
        MediaQuery.of(context).padding.top -
        kToolbarHeight;

    _scrollController.animateTo(
      offset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Bank>> grouped = groupBanksByInitial(_filteredBanks);
    // 保持所有 section keys，避免列表为空时 keys 丢失。
    for (final String initial in grouped.keys) {
      _sectionKeys.putIfAbsent(initial, () => GlobalKey());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          TextButton(
            onPressed: _showCustomBankDialog,
            child: const Text('自定义'),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            controller: _scrollController,
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceLg,
                    AppDimens.spaceMd,
                    AppDimens.spaceLg,
                    AppDimens.spaceSm,
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '搜索银行',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: AppPalette.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceMd,
                        vertical: AppDimens.spaceSm,
                      ),
                    ),
                  ),
                ),
              ),
              if (grouped.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('未找到相关银行')),
                )
              else
                for (final MapEntry<String, List<Bank>> entry
                    in grouped.entries) ...<Widget>[
                  SliverToBoxAdapter(
                    key: _sectionKeys[entry.key],
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: AppDimens.spaceLg,
                        top: AppDimens.spaceMd,
                        bottom: AppDimens.spaceSm,
                      ),
                      child: Text(
                        entry.key,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppPalette.textPrimary,
                            ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                        final Bank bank = entry.value[index];
                        return _BankTile(
                          bank: bank,
                          onTap: () => _selectBank(bank),
                        );
                      },
                      childCount: entry.value.length,
                    ),
                  ),
                ],
              const SliverPadding(
                padding: EdgeInsets.only(bottom: AppDimens.spaceLg),
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: kToolbarHeight + MediaQuery.of(context).padding.top,
            bottom: 0,
            width: 32,
            child: _AlphabetIndex(
              initials: kBankIndexLetters,
              onTap: _scrollToInitial,
              available: grouped.keys.toSet(),
            ),
          ),
        ],
      ),
    );
  }
}

class _BankTile extends StatelessWidget {
  const _BankTile({required this.bank, required this.onTap});

  final Bank bank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceLg,
          vertical: AppDimens.spaceMd,
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
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Text(
                bank.name,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlphabetIndex extends StatelessWidget {
  const _AlphabetIndex({
    required this.initials,
    required this.onTap,
    required this.available,
  });

  final List<String> initials;
  final ValueChanged<String> onTap;
  final Set<String> available;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (DragUpdateDetails details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final double y = details.localPosition.dy.clamp(0, box.size.height);
        final int index = (y / (box.size.height / initials.length)).floor();
        if (index >= 0 && index < initials.length) {
          onTap(initials[index]);
        }
      },
      onTapUp: (TapUpDetails details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final double y = details.localPosition.dy.clamp(0, box.size.height);
        final int index = (y / (box.size.height / initials.length)).floor();
        if (index >= 0 && index < initials.length) {
          onTap(initials[index]);
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: initials.map((String initial) {
          final bool enabled = available.contains(initial) || initial == '↑';
          return Expanded(
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? AppPalette.textSecondary
                      : AppPalette.textTertiary.withValues(alpha: 0.4),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}
