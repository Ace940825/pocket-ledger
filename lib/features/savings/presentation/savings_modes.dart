import 'package:flutter/material.dart';

/// 存钱模式预设（参照小青账「存钱模式选择」）。
///
/// 模式只负责一件事：**创建预设**——储蓄页点「添加」先选模式，
/// 编辑表单按 [defaultName] / [presetTargetMinor] / [presetDeadlineDays] /
/// [presetNote] 预填；模式信息随名称与备注保留在目标上。
///
/// 金额数学（预填目标）：
/// - 365 天：1+2+…+365 = 66,795 元；
/// - 30 天倒数：每月 30+29+…+1 = 465 元，一年 12 个月 = 5,580 元；
/// - 星期：每周 10+20+…+70 = 280 元，一年 52 周 = 14,560 元；
/// - 52 周：每周 10+20+…+520 = 10 × (1+2+…+52) = 13,780 元。
/// 12 月定额 / 定额 / 灵活的金额完全由用户决定，不预填目标金额。
enum SavingsMode {
  fixed365(
    label: '365天存钱法',
    description: '第1天存1元，第2天存2元，依次类推，一年累计 66795 元',
    defaultName: '365天存钱挑战',
    presetTargetMinor: 6679500,
    presetDeadlineDays: 365,
    icon: Icons.savings_outlined,
  ),
  countdown30(
    label: '30天倒数存钱法',
    description: '每月1号存30元，2号存29元，依次递减到30号存1元',
    defaultName: '30天倒数存钱',
    presetTargetMinor: 558000,
    presetDeadlineDays: 365,
    icon: Icons.event_repeat_outlined,
  ),
  monthly12(
    label: '12月定额存钱法',
    description: '全年12个月，每月固定一个定期定额扣款金额',
    defaultName: '12月定额存钱',
    presetTargetMinor: null,
    presetDeadlineDays: 365,
    icon: Icons.calendar_month_outlined,
  ),
  weekday(
    label: '星期存钱法',
    description: '星期一存10元，星期二存20元，依次递增到星期日存70元',
    defaultName: '星期存钱挑战',
    presetTargetMinor: 1456000,
    presetDeadlineDays: 365,
    icon: Icons.date_range_outlined,
  ),
  weeks52(
    label: '52周存钱法',
    description: '第一周存10元，第二周存20元，每周多存10元递增到第52周',
    defaultName: '52周存钱挑战',
    // 10+20+…+520 = 10 × (1+2+…+52) = 13,780 元。
    presetTargetMinor: 1378000,
    presetDeadlineDays: 364, // 52 周 = 364 天
    icon: Icons.view_week_outlined,
  ),
  fixed(
    label: '定额存钱法',
    description: '每次存入固定金额，存N日后查看该账户的积累',
    defaultName: '定额存钱计划',
    presetTargetMinor: null,
    presetDeadlineDays: null,
    icon: Icons.check_circle_outline,
  ),
  elastic(
    label: '弹性存钱法',
    description: '设置递增系数 N，下一次存钱比上一次多 N',
    defaultName: '弹性存钱计划',
    presetTargetMinor: null,
    presetDeadlineDays: null,
    icon: Icons.trending_up_outlined,
  ),
  flexible(
    label: '灵活存钱法',
    description: '不需要设置很多，只需要一个目标，灵活存入',
    defaultName: '灵活存钱目标',
    presetTargetMinor: null,
    presetDeadlineDays: null,
    icon: Icons.auto_awesome_outlined,
  );

  const SavingsMode({
    required this.label,
    required this.description,
    required this.defaultName,
    required this.presetTargetMinor,
    required this.presetDeadlineDays,
    required this.icon,
  });

  /// 模式名（选择卡标题）。
  final String label;

  /// 一句话玩法说明（选择卡副标题，同时预填备注）。
  final String description;

  /// 预填目标名称。
  final String defaultName;

  /// 预填目标金额（分）；null = 金额由用户决定，不预填。
  final int? presetTargetMinor;

  /// 预填截止日期（从今天起算的天数）；null = 不设截止。
  final int? presetDeadlineDays;

  /// 选择卡图标。
  final IconData icon;

  /// 预填备注 = 玩法说明。
  String get presetNote => description;
}
