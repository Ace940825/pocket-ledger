import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failures.dart';
import '../../../core/utils/date_utils.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/line_icon_map.dart';
import '../../../shared/widgets/module_list_scaffold.dart' show showToast;
import '../../../shared/widgets/sheet_scaffold.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimens.dart';
import '../../categories/providers/categories_providers.dart';
import '../data/budget_repository.dart';
import '../providers/budget_providers.dart';

/// 预算编辑种子：从项卡点进编辑弹窗时预填范围/分类/周期，省手选。
class BudgetSeed {
  const BudgetSeed({
    this.scope,
    this.categoryId,
    this.categoryType,
    this.period,
    this.year,
    this.periodIndex,
  });

  final BudgetScope? scope;
  final String? categoryId;

  /// 分类下拉的候选类型（收入目标卡点进时列收入分类）。
  final CategoryType? categoryType;
  final BudgetPeriod? period;
  final int? year;
  final int? periodIndex;
}

/// 预算编辑**底部弹窗**（2026-10-14 第 18 批极简化；第 28 批收入方向
/// 改「目标」措辞）：
///
/// - 移除「范围 / 周期 / 提醒阈值 / 超支提醒 / 年份」全部表单项——
///   范围由入口决定（弹窗只添加分类预算，总预算走概览卡铅笔），
///   周期/年份默认当前查看的月/年（seed 带入），提醒参数沿用原值或默认。
/// - 分类选择改为**矮弹层**（限高约 45% 屏高）且**只列一级分类**
///   （第 21 批反馈：二级预算不在通用弹窗里建，走一级分组内入口）。
/// - 传 [parentCategory]（一级分组内「添加二级预算」入口）时，候选分类
///   锁定为该一级名下的二级分类，标题为「添加二级预算」（收入方向=
///   「添加二级目标」）。
/// - scope=overall（铅笔编辑总预算）时连分类选择也不显示，只留额度。
Future<void> showBudgetEditor(
  BuildContext context,
  WidgetRef ref, [
  Budget? budget,
  BudgetSeed? seed,
  String? bookId,
  Category? parentCategory,
]) async {
  final CategoryType categoryType =
      parentCategory?.type ?? seed?.categoryType ?? CategoryType.expense;
  // 第 28 批「收入预算→收入目标」：收入方向的标题/额度字段/提示
  // 全部走「目标」措辞。
  final bool isIncome = categoryType == CategoryType.income;
  final bool isOverall = (budget?.scope ?? seed?.scope) == BudgetScope.overall;

  // 候选分类（第 21 批口径）：通用入口只列一级分类；传 parentCategory 时
  // 只列该一级名下的二级分类。编辑历史数据若是候选外的分类（如已删挂靠），
  // 补进候选以正确回显。
  final List<Category> categories =
      ref.read(allCategoriesProvider).valueOrNull ?? const <Category>[];
  final List<Category> editorCategories;
  if (parentCategory != null) {
    editorCategories = categories
        .where(
          (Category c) =>
              c.type == categoryType &&
              !c.isSystem &&
              c.parentId == parentCategory.id,
        )
        .toList()
      ..sort((Category a, Category b) => a.sortOrder.compareTo(b.sortOrder));
  } else {
    editorCategories = categories
        .where(
          (Category c) =>
              c.type == categoryType && !c.isSystem && c.parentId == null,
        )
        .toList()
      ..sort((Category a, Category b) => a.sortOrder.compareTo(b.sortOrder));
  }
  final String? editingCategoryId = budget?.categoryId ?? seed?.categoryId;
  if (editingCategoryId != null &&
      editorCategories.every((Category c) => c.id != editingCategoryId)) {
    final Category? extra = categories.firstWhereOrNull(
      (Category c) => c.id == editingCategoryId,
    );
    if (extra != null) editorCategories.add(extra);
  }

  final TextEditingController amountController = TextEditingController(
    text: budget != null
        ? Money.fromMinor(budget.amountMinor).decimal.toStringAsFixed(2)
        : '',
  );

  String? categoryId = editingCategoryId ??
      (editorCategories.isEmpty ? null : editorCategories.first.id);

  /// 分类矮弹层：限高约 45% 屏高、内部滚动，只列候选（一级或指定父级下的二级）。
  Future<void> pickCategory(StateSetter setState) async {
    final Category? picked = await showAppModalSheet<Category>(
      context,
      title: '选择分类',
      isScrollControlled: true,
      bodyPadding: EdgeInsets.zero,
      body: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.45,
        ),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: editorCategories.length,
          itemBuilder: (BuildContext _, int i) {
            final Category c = editorCategories[i];
            final bool selected = c.id == categoryId;
            return InkWell(
              onTap: () => Navigator.of(context).pop(c),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        c.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w400,
                          color: selected
                              ? AppPalette.primary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (selected)
                      const LineGlyph(
                        Icons.check,
                        size: 18,
                        color: AppPalette.primary,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    if (picked != null) setState(() => categoryId = picked.id);
  }

  final bool? saved = await showAppModalSheet<bool>(
    context,
    title: budget == null
        ? (parentCategory != null
            ? (isIncome ? '添加二级目标' : '添加二级预算')
            : (isIncome ? '添加分类目标' : '添加分类预算'))
        : (isOverall
            ? (isIncome ? '编辑总目标' : '编辑总预算')
            : (isIncome ? '编辑分类目标' : '编辑分类预算')),
    isScrollControlled: true,
    body: StatefulBuilder(
      builder: (BuildContext ctx, StateSetter setState) =>
          SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (!isOverall)
              // 与 AmountField 同款字段风格（浅色圆角填充 + 品牌竖条），
              // 点开底部矮弹层选择（第 19 批反馈：与其他弹窗字段风格统一）。
              InkWell(
                borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                onTap: editorCategories.isEmpty
                    ? null
                    : () => pickCategory(setState),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppPalette.surfaceLight,
                    borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.md,
                    vertical: 14,
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 3,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppPalette.primary,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                      const SizedBox(width: AppDimens.md),
                      Expanded(
                        child: Text(
                          editorCategories
                                  .firstWhereOrNull(
                                    (Category c) => c.id == categoryId,
                                  )
                                  ?.name ??
                              '选择分类',
                          style: TextStyle(
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      LineGlyph(
                        Icons.expand_more,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            const FormGap(),
            AmountField(
              controller: amountController,
              label: isIncome ? '目标额度' : '预算额度',
            ),
          ],
        ),
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('取消'),
      ),
      const SizedBox(width: 8),
      // 保存：弹窗内先校验额度，不合法 toast 且不关弹层。
      InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
        onTap: () {
          final double? amount = double.tryParse(amountController.text.trim());
          if (amount == null || amount <= 0) {
            showToast(
              context,
              isIncome ? '目标额度必须大于 0' : '预算额度必须大于 0',
            );
            return;
          }
          Navigator.of(context).pop(true);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
          decoration: BoxDecoration(
            color: AppPalette.ctaGreen,
            borderRadius: BorderRadius.circular(AppDimens.radiusChip),
          ),
          child: const Text(
            '保存',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppPalette.white,
            ),
          ),
        ),
      ),
    ],
  );

  if (saved != true || !context.mounted) return;

  final double? amount = double.tryParse(amountController.text.trim());
  if (amount == null || amount <= 0) {
    showToast(context, isIncome ? '目标额度必须大于 0' : '预算额度必须大于 0');
    return;
  }

  // 周期/年份不再有 UI：编辑沿用原值；新增用入口 seed（= 当前查看的月/年），
  // seed 缺省时回落当前周期。提醒参数编辑沿用原值、新增用默认。
  final BudgetScope scope =
      budget?.scope ?? seed?.scope ?? BudgetScope.category;
  final BudgetPeriod period =
      budget?.period ?? seed?.period ?? BudgetPeriod.monthly;
  final int year = budget?.year ?? seed?.year ?? DateTime.now().year;
  final int threshold = budget?.alertThreshold ?? 80;
  final bool alertEnabled = budget?.alertEnabled ?? true;

  // 新建时默认落在当前周期（种子带周期时用种子），省掉用户手填「第几个月」。
  final int periodIndex = budget?.periodIndex ??
      seed?.periodIndex ??
      currentPeriodIndex(
        monthly: period == BudgetPeriod.monthly,
        quarterly: period == BudgetPeriod.quarterly,
      );

  final BudgetRepository repo = ref.read(budgetRepositoryProvider);
  try {
    if (budget == null) {
      // 每个分类同期只能设置一条预算：新建前查重，重复则 toast 拦下
      //（编辑走列表行点按/左滑，不经过此入口）。
      if (scope == BudgetScope.category && categoryId != null) {
        final String bid = bookId ?? ref.read(currentBookIdProvider);
        final List<Budget> existing =
            ref.read(bookBudgetsProvider(bid)).valueOrNull ?? const <Budget>[];
        final bool duplicated = existing.any(
          (Budget b) =>
              b.scope == BudgetScope.category &&
              b.categoryId == categoryId &&
              b.period == period &&
              b.year == year &&
              b.periodIndex == periodIndex,
        );
        if (duplicated) {
          showToast(
            context,
            isIncome ? '该分类本期已有目标，可在列表中左滑编辑' : '该分类本期已有预算，可在列表中左滑编辑',
          );
          return;
        }
      }
      await repo.add(
        bookId: bookId ?? ref.read(currentBookIdProvider),
        scope: scope,
        period: period,
        amountMinor: Money.fromDecimal(amount).minor,
        year: year,
        periodIndex: periodIndex,
        categoryId: categoryId,
        alertEnabled: alertEnabled,
        alertThreshold: threshold,
      );
    } else {
      await repo.update(
        id: budget.id,
        scope: scope,
        period: period,
        amountMinor: Money.fromDecimal(amount).minor,
        year: year,
        periodIndex: periodIndex,
        categoryId: categoryId,
        alertEnabled: alertEnabled,
        alertThreshold: threshold,
      );
    }
  } on AppFailure catch (e) {
    if (context.mounted) showToast(context, e.message);
  }
}
