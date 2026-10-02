import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// 守门入口：导出 §7 主题硬化相关的全部自定义 lint 规则。
PluginBase createPlugin() => ThemeGuardPlugin();

/// §7 主题硬化守门规则集合。
///
/// 目标：防止回头使用硬编码颜色，守住「页面只取 theme colorScheme / AppColors 令牌」
/// 的成果。被本规则拦截的写法必须改为：
///   - `Theme.of(context).colorScheme.*`（语义底色）
///   - `AppColors.*`（品牌/语义令牌，见 lib/theme/app_colors.dart）
class ThemeGuardPlugin extends PluginBase {
  // PluginBase 0.6.0 无 const 构造，此处不能用 const。
  ThemeGuardPlugin();

  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => const [
        NoRawColorsRule(),
      ];
}

/// 禁止两类硬编码颜色：
/// 1. 任意 `Colors.xxx`（保留 `Colors.transparent` 作为合法的透明占位）。
/// 2. 任意裸 `Color(0xRRGGBB)` 整数字面量。
class NoRawColorsRule extends DartLintRule {
  const NoRawColorsRule()
      : super(
          code: const LintCode(
            name: 'no_raw_colors',
            problemMessage:
                '避免硬编码颜色：请改用 Theme.of(context).colorScheme.* 或 AppColors 令牌。',
          ),
        );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // 1) Colors.white / Colors.black / Colors.black54 ... 但放行 Colors.transparent
    context.registry.addPrefixedIdentifier((node) {
      if (node.prefix.name == 'Colors' && node.name != 'transparent') {
        reporter.reportErrorForNode(code, node);
      }
    });

    // 2) Color(0xFFECE3D1) 这类整数字面量硬编码
    context.registry.addInstanceCreationExpression((node) {
      final element = node.constructorName.type.element;
      if (element?.name != 'Color') return;
      final args = node.argumentList.arguments;
      if (args.length == 1 && args.first is IntegerLiteral) {
        reporter.reportErrorForNode(code, node);
      }
    });
  }
}
