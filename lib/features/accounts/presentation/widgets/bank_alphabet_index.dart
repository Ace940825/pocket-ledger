import 'package:flutter/material.dart';

/// 银行列表右侧字母索引条（↑ / ★ / A~Z）。
///
/// 从银行选择页抽取为公共组件：编辑账户页的「银行选择弹层」与整页
/// [BankSelectPage] 共用，避免两处索引逻辑漂移。
///
/// [available] 为当前列表中实际存在的首字母集合；不在集合内的字母置灰
/// （'↑' 恒可用，表示回到顶部）。
class BankAlphabetIndex extends StatelessWidget {
  const BankAlphabetIndex({
    super.key,
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
        _handlePosition(context, details.localPosition.dy);
      },
      onTapUp: (TapUpDetails details) {
        _handlePosition(context, details.localPosition.dy);
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
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.4),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  /// 把触点纵坐标换算成字母并回调。
  void _handlePosition(BuildContext context, double dy) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final double y = dy.clamp(0, box.size.height);
    final int index = (y / (box.size.height / initials.length)).floor();
    if (index >= 0 && index < initials.length) {
      onTap(initials[index]);
    }
  }
}
