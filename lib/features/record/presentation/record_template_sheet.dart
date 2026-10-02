import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/forest_design_tokens.dart';
import '../../../database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../features/tags/presentation/tag_empty_illustration.dart';
import '../providers/record_template_providers.dart';
import '../record_tab.dart';
import 'record_template_page.dart';

/// 模板草稿：模板模式记一笔页「保存」时打包返回的可入库字段。
///
/// 金额为「示例金额」：模板卡展示用，套用时同样带入、可再改。
class RecordTemplateDraft {
  const RecordTemplateDraft({
    required this.tabIndex,
    this.amountMinor = 0,
    this.discountMinor = 0,
    this.accountId,
    this.toAccountId,
    this.counterparty,
    this.categoryId,
    this.note,
    this.tags,
    this.excludeFromStats = false,
    this.excludeFromBudget = false,
    this.isReimbursable = false,
  });

  final int tabIndex;
  final int amountMinor;

  /// 示例优惠（分）：支出/转账模板可带，套用与编辑时回填。
  final int discountMinor;
  final String? accountId;
  final String? toAccountId;
  final String? counterparty;
  final String? categoryId;
  final String? note;
  final String? tags;
  final bool excludeFromStats;
  final bool excludeFromBudget;
  final bool isReimbursable;
}

/// 「账单模板」半屏弹窗（方案 C · 鼠尾草渐变强调）：
/// 头部 ✕ / 居中标题 / 深墨「添加」胶囊（进入模板管理页），
/// 模板卡（奶油卡 / 渐变选中卡），底部「n 个模板 + 使用」。
class RecordTemplateSheet extends ConsumerStatefulWidget {
  const RecordTemplateSheet({
    super.key,
    required this.onApply,
  });

  final ValueChanged<RecordTemplate> onApply;

  /// 统一入口：透明底弹窗，圆角由内容自绘。
  static Future<void> show({
    required BuildContext context,
    required ValueChanged<RecordTemplate> onApply,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => RecordTemplateSheet(
        onApply: onApply,
      ),
    );
  }

  @override
  ConsumerState<RecordTemplateSheet> createState() =>
      _RecordTemplateSheetState();
}

class _RecordTemplateSheetState extends ConsumerState<RecordTemplateSheet> {
  /// 当前选中（待套用）的模板 id；null = 未选择。
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<RecordTemplate>> templates =
        ref.watch(recordTemplatesProvider);
    final List<RecordTemplate> list = templates.value ?? <RecordTemplate>[];

    return Container(
      // 自适应高度：卡片少时收缩包住内容，多时上限 60% 屏高、列表内部滚动。
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: const BoxDecoration(
        color: ForestBg.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 顶部淡绿晕染带（方案 C）：拖拽条 + 头部 + 「最近使用」引导语。
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[AppPalette.mintWhisper, ForestBg.paper],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // 拖拽条 grab：36×4，鼠尾草绿 35% 透明。
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppPalette.sageRibbon.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildHeader(),
                if (list.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        '最近使用',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: ForestNeutral.textSecondary,
                          letterSpacing: 0.7,
                        ),
                      ),
                      Text(
                        '轻触套用',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: ForestGreen.deep,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Flexible(
            child: list.isEmpty
                ? _buildEmpty()
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                    itemCount: list.length,
                    separatorBuilder: (BuildContext ctx, int i) =>
                        const SizedBox(height: 8),
                    itemBuilder: (BuildContext ctx, int i) {
                      final RecordTemplate t = list[i];
                      final bool selected = t.id == _selectedId;
                      return RecordTemplateCard(
                        template: t,
                        selected: selected,
                        onTap: () => setState(() {
                          _selectedId = selected ? null : t.id;
                        }),
                      );
                    },
                  ),
          ),
          if (list.isNotEmpty) ...<Widget>[
            SizedBox(height: 6),
            _buildFooter(list),
          ],
        ],
      ),
    );
  }

  // 头部：左 ✕ / 居中标题 / 右「添加」深墨胶囊（进入模板管理页）。
  Widget _buildHeader() => SizedBox(
        height: 32,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    // 设计稿 .s-close：半透明白 + 发丝线（浮在晕染带上）。
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.75),
                    shape: BoxShape.circle,
                    border: Border.all(color: ForestNeutral.hairline),
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 15,
                    color: ForestNeutral.textSecondary,
                  ),
                ),
              ),
            ),
            const Text(
              '账单模板',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: ForestNeutral.textPrimary,
                letterSpacing: 0.02,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (BuildContext ctx) => RecordTemplatePage(),
                    ),
                  );
                  if (mounted) setState(() {});
                },
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    // 设计稿 .s-add：深绿 #2E6B49 + 深绿投影。
                    color: ForestGreen.deep,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppPalette.ctaGreenDeep.withValues(alpha: 0.251),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Text(
                    '添加',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.creamSoft,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  // 空态：小票插画 + 提示（与设计稿一致）。
  Widget _buildEmpty() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const <Widget>[
          SizedBox(height: 18),
          TagEmptyIllustration(width: 150),
          SizedBox(height: 12),
          Text(
            '没有发现模板哦，试着去添加一个~',
            style: TextStyle(
              fontSize: 13.5,
              color: ForestNeutral.textTertiary,
            ),
          ),
          SizedBox(height: 18),
        ],
      );

  // 底部栏：左侧计数（选中时显示已选名称）+ 右侧深墨「套用」胶囊。
  Widget _buildFooter(List<RecordTemplate> list) {
    final bool enabled = _selectedId != null;
    return Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: ForestNeutral.hairline)),
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          10 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                enabled
                    ? '已选「${list.firstWhere((RecordTemplate x) => x.id == _selectedId).name}」'
                    : '${list.length} 个模板',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: ForestGreen.deep,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 40,
              child: InkWell(
                onTap: enabled
                    ? () {
                        final RecordTemplate t = list.firstWhere(
                          (RecordTemplate x) => x.id == _selectedId,
                        );
                        widget.onApply(t);
                        Navigator.of(context).pop();
                      }
                    : null,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    // 设计稿 .C .s-foot .go：深墨底 + 米白字。
                    color: enabled
                        ? ForestNeutral.textPrimary
                        : ForestBg.sunken,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '套用',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: enabled
                          ? AppPalette.creamSoft
                          : ForestNeutral.textTertiary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
  }
}
