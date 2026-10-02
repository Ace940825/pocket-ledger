import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// 「选择日期」底部弹窗（共享组件）：纯 1~31 数字宫格（7 列顺序排布，
/// 不带月份标题/星期表头），选中日浅绿实心圆白字；底部右侧
/// 取消 + 确定（绿色胶囊）。点击数字即选中高亮，点「确定」返回。
///
/// 适用于「每月X日」类周期日选择（信用卡账单日/还款日、负债账单日等）：
/// ```dart
/// final int? day = await showDayPickSheet(context, title: '选择日期', initialDay: 1);
/// ```
Future<int?> showDayPickSheet(
  BuildContext context, {
  String title = '选择日期',
  int initialDay = 1,
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: AppPalette.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext context) => _DayPickSheet(
      title: title,
      initialDay: initialDay.clamp(1, 31),
    ),
  );
}

class _DayPickSheet extends StatefulWidget {
  const _DayPickSheet({required this.title, required this.initialDay});

  final String title;
  final int initialDay;

  @override
  State<_DayPickSheet> createState() => _DayPickSheetState();
}

class _DayPickSheetState extends State<_DayPickSheet> {
  late int _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initialDay;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // 头部：X 圆钮（浅灰底）+ 居中标题。
            SizedBox(
              height: 32,
              child: Stack(
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppPalette.neutralSoft,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: AppPalette.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // 纯 1~31 数字宫格：7 列顺序排布（1 号固定左上，与日历星期对位无关）。
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              padding: EdgeInsets.zero,
              childAspectRatio: 1,
              children: <Widget>[
                for (int day = 1; day <= 31; day++) _dayCell(day),
              ],
            ),
            const SizedBox(height: 10),
            // 底部右侧：取消 + 确定（绿色胶囊）。
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppPalette.textSecondary,
                    textStyle: const TextStyle(fontSize: 15),
                  ),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.of(context).pop(_selectedDay),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.sageLeaf,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        '确定',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppPalette.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCell(int day) {
    final bool selected = day == _selectedDay;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selectedDay = day),
      child: Center(
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? AppPalette.sageLeaf : Colors.transparent,
          ),
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 16,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? AppPalette.white : AppPalette.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
