// 口袋账本 · 图标令牌（语义映射 + 自定义字体扩展点）
// 落点：lib/theme/app_icons.dart
//
// 设计原则：
//  - 唯一图标源：cupertino_icons（iOS 原生观感）为基底。
//  - 禁止混用 Material Icons / 裸 PNG / emoji 作为功能图标。
//  - 品牌字形走自定义字体 PocketIcons（见下方注释接入步骤）。
//
// pubspec.yaml 需包含：
//   dependencies:
//     cupertino_icons: ^1.0.8
//   fonts:
//     - family: PocketIcons
//       fonts:
//         - asset: assets/fonts/PocketIcons.ttf

import 'package:flutter/material.dart';
// CupertinoIcons 由 Flutter 框架提供（cupertino_icons 只是字体资源包）。
// 用 show 限定导入，避免与 material 命名冲突。
import 'package:flutter/cupertino.dart' show CupertinoIcons;

/// 语义图标映射（唯一事实来源）
@immutable
class AppIcons {
  const AppIcons._();

  // ---- 通用操作 ----
  static const IconData add = CupertinoIcons.plus;
  static const IconData close = CupertinoIcons.xmark;
  static const IconData check = CupertinoIcons.check_mark;
  static const IconData search = CupertinoIcons.search;
  static const IconData chevronRight = CupertinoIcons.chevron_right;
  static const IconData chevronDown = CupertinoIcons.chevron_down;
  static const IconData ellipsis = CupertinoIcons.ellipsis;

  // ---- 业务语义 ----
  static const IconData template = CupertinoIcons.doc_text; // 账单模板
  static const IconData category = CupertinoIcons.square_grid_2x2; // 分类
  static const IconData note = CupertinoIcons.doc_plaintext; // 备注
  static const IconData book = CupertinoIcons.book; // 账本
  static const IconData reimbursement = CupertinoIcons.money_dollar; // 报销
  static const IconData calendar = CupertinoIcons.calendar; // 日期
  static const IconData filter = CupertinoIcons.slider_horizontal_3; // 筛选
  static const IconData help = CupertinoIcons.question_circle; // 帮助
  static const IconData expenseArrow = CupertinoIcons.arrow_up; // 支出
  static const IconData incomeArrow = CupertinoIcons.arrow_down; // 收入
  static const IconData transfer = CupertinoIcons.arrow_left_right; // 转账

  // ---- 自定义品牌字形（占位，注册 PocketIcons 字体后启用）----
  // 从 iconfont.cn 导出 ttf，替换 0xe900 等码位。
  // static const IconData brandLogo =
  //     IconData(0xe900, fontFamily: 'PocketIcons');
  // static const IconData brandLeaf =
  //     IconData(0xe901, fontFamily: 'PocketIcons');
}
