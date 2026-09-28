// §7 主题硬化守门（轻量版，无需 custom_lint 插件）。
//
// 运行：dart tool/guard_theme_colors.dart
// 退出码：0 = 通过；1 = 发现硬编码颜色回归。
//
// 规则（与 packages/pocket_lints 的 NoRawColorsRule 意图一致）：
//   1. 禁止任意「真实」 `Colors.xxx`（除 Colors.transparent）。
//      注意：本项目把 AppColors 作为令牌命名空间，标识符形如 AppColors.xxx；
//      由于 "AppColors" 以 "Colors" 结尾，必须用 \b 词边界，否则会把
//      AppColors.sageMist 误判成 Colors.sageMist。
//   2. 禁止裸 `Color(0xRRGGBB)` 整数字面量。
// 豁免：
//   - excludePrefixes 中的「主题/令牌定义文件」（本就以十六进制声明令牌）。
//   - 行内带 `// ignore: no_raw_colors` 注释的行（已确认的有意例外）。
//
// 背景：Dart 3.13 / Flutter 3.47 的 SDK 缺少 _macros 包，导致当前 pub 上的
// custom_lint（0.6.x/0.7.x）无法解析（其 analyzer 依赖需 macros/_macros），
// 故用本脚本作等价守门。待 Flutter/Dart 升级到 _macros 可用的版本后，可直接
// 启用 packages/pocket_lints 插件（本脚本可退役）。

import 'dart:io';

/// 主题/令牌定义目录与文件：本就以十六进制声明令牌，整段豁免。
const List<String> excludePrefixes = <String>[
  'lib/theme/', // SSOT、配色、尺寸、字体等主题基础设施
  'lib/core/theme/', // 设计令牌 Forest* 系列
  'lib/features/accounts/data/bank_data.dart', // 银行品牌色数据
];

// \b 词边界：避免把 AppColors.xxx 误判成 Colors.xxx。
final RegExp colorsRe = RegExp(r'\bColors\.([A-Za-z_]\w*)');
final RegExp hexColorRe = RegExp(r'Color\(0x[0-9A-Fa-f]');

int main() {
  final root = Directory.current.path.replaceAll('\\', '/');
  final violations = <String>[];

  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final rel = entity.path.replaceAll('\\', '/').replaceFirst('$root/', '');
    if (excludePrefixes.any((p) => rel == p || rel.startsWith(p))) continue;

    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains('// ignore: no_raw_colors')) continue;

      final m = colorsRe.firstMatch(line);
      if (m != null && m.group(1) != 'transparent') {
        violations.add('$rel:${i + 1}: 硬编码颜色 Colors.${m.group(1)}');
        continue;
      }
      if (hexColorRe.hasMatch(line)) {
        violations.add('$rel:${i + 1}: 硬编码十六进制 Color(0x..)');
      }
    }
  }

  if (violations.isEmpty) {
    print('✅ no_raw_colors 守门通过：未发现硬编码颜色回归。');
    return 0;
  }
  print('❌ 发现硬编码颜色回归（共 ${violations.length} 处）：');
  for (final v in violations) print('   $v');
  print('\n如有意例外，在该行追加 `// ignore: no_raw_colors`；'
      '颜色定义请放入 excludePrefixes 中的令牌目录。');
  // 必须用 exit(1) 才能被 CI / 钩子识别为失败（int main 的 return 不设置退出码）。
  exit(1);
}
