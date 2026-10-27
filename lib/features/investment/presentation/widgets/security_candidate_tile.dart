import 'package:flutter/material.dart';
import 'package:pocket_ledger/core/theme/forest_design_tokens.dart';

import '../../../../shared/widgets/line_icon_map.dart';
import '../../data/investment_repository.dart';
import '../../data/market/security_meta_repository.dart';

/// 行情候选行：代码 + 名称 + 品种标签，点击回填。
///
/// 抽自「记一笔」与「新建持仓」两处重复的候选补全行，统一视觉与交互
/// （圆角内边距、`onSurface` 代码 + `onSurfaceVariant` 名称/标签、`north_west` 跳转图标）。
/// 仅消费投资领域模型 [SecurityCandidate]，不含业务逻辑——回填回调由调用方注入。
class SecurityCandidateTile extends StatelessWidget {
  const SecurityCandidateTile({
    super.key,
    required this.candidate,
    this.onTap,
  });

  final SecurityCandidate candidate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            Text(
              candidate.symbol,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.forest.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                candidate.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: context.forest.onSurfaceVariant),
              ),
            ),
            Text(
              investmentTypeLabel(
                candidate.type,
                candidate.symbol,
                name: candidate.name,
              ),
              style: TextStyle(fontSize: 12, color: context.forest.onSurfaceVariant),
            ),
            const SizedBox(width: 6),
            LineGlyph(Icons.north_west, size: 14, color: context.forest.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
