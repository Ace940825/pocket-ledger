import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// 账户选择胶囊：未选显示 [label] 占位，已选显示账户名（深绿加粗 + 绿底）。
///
/// 抽自储蓄「建计划 / 编辑计划 / 计划详情」三处手搓的账户选择胶囊
/// （转出/扣款账户、转入/入款账户、定存入款账户等）。纯展示，
/// 账户名由调用方解析后传入（不持有 provider），点击回调由调用方注入。
class AccountSelectPill extends StatelessWidget {
  const AccountSelectPill({
    super.key,
    required this.label,
    this.accountName,
    required this.onTap,
  });

  final String label;
  final String? accountName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool selected = accountName != null && accountName!.isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? AppPalette.softGreen : AppPalette.surfaceMist,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              selected ? Icons.check : Icons.account_balance_wallet_outlined,
              size: 18,
              color: selected ? AppPalette.deepGreen : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selected ? accountName! : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: selected ? AppPalette.deepGreen : cs.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
