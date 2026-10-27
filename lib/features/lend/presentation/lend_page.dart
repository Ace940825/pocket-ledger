import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pocket_ledger/shared/widgets/confirm_dialog.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../routing/app_router.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/clay_icon_tile.dart';
import '../../../shared/widgets/line_icon_map.dart';
import '../../../shared/widgets/line_icons.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../theme/theme.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../record/presentation/record_sheet.dart';
import '../../record/record_tab.dart';
import '../providers/lend_providers.dart';

/// 借还页：对照报销页总览——每个借出 / 借入账户一张存钱计划样式卡片。
///
/// 行1：头像 ｜ 绿竖条 + 账户名 + 「编辑」胶囊；行2：大字未结清金额
/// （账户余额不变量 = 名下未结清合计）+「待收回 / 待归还」小标；
/// 行3：进行中 / 已结清状态胶囊 + 进入箭头。
/// 未指定账户的记录落在页尾「未指定账户的记录」平铺区，不丢数据。
///
/// 第 35 批：页面原先**只能看不能记**——唯一动作是空态里的「去账户页
/// 新建」，用户必须先建借出/借入类型账户才能开始，而第 34 批起不再
/// 预置账户，页面直接沦为死空态。现对齐报销页范式加底部常驻双按钮栏：
/// 主按钮「记一笔借还」直开记一笔的借还 Tab（不建账户也能记——填对方
/// 名即可，落「未指定账户」区；选了借出/借入类型账户则自动归户）；
/// 幽灵按钮「新建账户」直达账户页（第 46 批改名，建借出/借入类型账户
/// 后自动归户）。空态去掉自有按钮
/// （动作入口唯一，避免双按钮重复），只留图标 + 说明文案。
class LendPage extends ConsumerStatefulWidget {
  const LendPage({super.key});

  @override
  ConsumerState<LendPage> createState() => _LendPageState();
}

class _LendPageState extends ConsumerState<LendPage> {
  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Account> accountList =
        ref.watch(accountsProvider).valueOrNull ?? const <Account>[];
    final List<LendRecord> records =
        ref.watch(lendListProvider).valueOrNull ?? const <LendRecord>[];

    final List<Account> lendOutAccounts = accountList
        .where((Account a) => !a.deleted && a.type == AccountType.lend)
        .toList(growable: false);
    final List<Account> borrowInAccounts = accountList
        .where((Account a) => !a.deleted && a.type == AccountType.borrow)
        .toList(growable: false);

    // 按账户聚合状态笔数（大字金额直接用账户余额不变量，口径与账户页一致）。
    final Map<String, int> ongoingCnt = <String, int>{};
    final Map<String, int> settledCnt = <String, int>{};
    for (final LendRecord r in records) {
      final String? aid = r.accountId;
      if (aid == null || aid.isEmpty) continue;
      if (r.status == LendStatus.ongoing) {
        ongoingCnt[aid] = (ongoingCnt[aid] ?? 0) + 1;
      } else {
        // 已结清与已核销都算「已结清」口径。
        settledCnt[aid] = (settledCnt[aid] ?? 0) + 1;
      }
    }

    // 未指定借还账户的记录：平铺列出，避免无处可见。
    final List<LendRecord> unassigned = records
        .where((LendRecord r) => r.accountId == null || r.accountId!.isEmpty)
        .toList(growable: false);

    final bool pageEmpty = lendOutAccounts.isEmpty &&
        borrowInAccounts.isEmpty &&
        unassigned.isEmpty;

    return Scaffold(
      backgroundColor: isDark
          ? context.forest.surface
          : context.forest.surface,
      appBar: AppBar(
        backgroundColor: isDark
            ? context.forest.surface
            : context.forest.surface,
        foregroundColor: isDark
            ? context.forest.onSurface
            : context.forest.onSurface,
        elevation: 0,
        centerTitle: true,
        title: const Text('借还'),
      ),
      body: pageEmpty
          // 第 41 批：空态整体垂直居中（原来是 Padding + Column 顶格，
          // 文字图标挤在页面上部）。Center 居中于 body 区（不含底栏）。
          ? const Center(child: _NoLendEmpty())
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: <Widget>[
                if (lendOutAccounts.isNotEmpty) ...<Widget>[
                  const SectionHeader(title: '借出账户'),
                  for (final Account a in lendOutAccounts)
                    _LendAccountCard(
                      account: a,
                      isLendOut: true,
                      ongoingCount: ongoingCnt[a.id] ?? 0,
                      settledCount: settledCnt[a.id] ?? 0,
                      isDark: isDark,
                      onTap: () =>
                          context.push('/accounts/${a.id}/transactions'),
                      onEdit: () => context.push('/accounts/${a.id}/edit'),
                    ),
                ],
                if (borrowInAccounts.isNotEmpty) ...<Widget>[
                  const SectionHeader(title: '借入账户'),
                  for (final Account a in borrowInAccounts)
                    _LendAccountCard(
                      account: a,
                      isLendOut: false,
                      ongoingCount: ongoingCnt[a.id] ?? 0,
                      settledCount: settledCnt[a.id] ?? 0,
                      isDark: isDark,
                      onTap: () =>
                          context.push('/accounts/${a.id}/transactions'),
                      onEdit: () => context.push('/accounts/${a.id}/edit'),
                    ),
                ],
                if (unassigned.isNotEmpty) ...<Widget>[
                  const SectionHeader(title: '未指定账户的记录'),
                  for (final LendRecord r in unassigned)
                    _UnassignedTile(
                      record: r,
                      onDelete: () => _confirmDelete(context, ref, r),
                      onTap: () => openRecordSheet(context, editLendId: r.id),
                    ),
                ],
              ],
            ),
      // 第 35 批：底部常驻双按钮栏（空态也显示，动作入口唯一）。
      // 报销页同款布局：幽灵次级 + 渐变主按钮。
      bottomNavigationBar: _bottomBar(context, isDark),
    );
  }

  /// 底部双按钮栏：主「记一笔借还」直开记一笔借还 Tab（不建账户也能记，
  /// 填对方名落「未指定账户」区；选借出/借入类型账户则自动归户）；
  /// 次级「新建账户」直达账户页（第 46 批改名，原「去账户页新建」）。
  Widget _bottomBar(BuildContext context, bool isDark) {
    final Color ghostBg =
        isDark ? context.forest.surface : context.forest.surface;
    final Color ghostBorder = isDark
        ? context.forest.outline
        : ForestNeutral.hairlineStrong;
    return SafeArea(
      child: Container(
        color: isDark
            ? context.forest.surface
            : context.forest.surface,
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
        child: Row(
          children: <Widget>[
            // 第 44 批：次级必须显式 flex:100——此前默认 flex:1 对主按钮
            // flex:135，被压成 ~2.5px 细条（真机只见一条竖线描边）。
            Expanded(
              flex: 100,
              child: _LendPillButton(
                onPressed: () => context.push(Routes.accounts),
                backgroundColor: ghostBg,
                border: Border.all(color: ghostBorder),
                textColor: isDark
                    ? context.forest.onSurface
                    : context.forest.onSurface,
                label: '新建账户',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 135,
              child: _LendPillButton(
                onPressed: () =>
                    openRecordSheet(context, initialTab: RecordTab.lend),
                gradient: ForestGradients.button,
                textColor: context.forest.onPrimary,
                icon: LineGlyph(
                  Icons.add,
                  size: 18,
                  color: context.forest.onPrimary,
                ),
                label: '记一笔借还',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    LendRecord record,
  ) async {
    final bool? confirmed = await showConfirm(
      context,
      title: '删除这条借还记录？',
      content: '删除后不可撤销。',
      confirmText: '删除',
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(lendRepositoryProvider).remove(record.id);
    } on AppFailure catch (e) {
      if (context.mounted) showAppToast(context, e.message);
    }
  }
}

// ── 分区头（报销页同款绿竖条） ─────────────────────────────

// ── 借还账户卡（报销页 _ReimbAccountCard 同款布局） ─────────

/// 行1：头像 ｜ 绿竖条 + 账户名 + 「编辑」胶囊；行2：大字未结清金额
/// （账户余额不变量）+「待收回 / 待归还」小标；行3：状态胶囊 + 进入箭头。
class _LendAccountCard extends StatelessWidget {
  const _LendAccountCard({
    required this.account,
    required this.isLendOut,
    required this.ongoingCount,
    required this.settledCount,
    required this.isDark,
    required this.onTap,
    required this.onEdit,
  });

  final Account account;
  final bool isLendOut;
  final int ongoingCount;
  final int settledCount;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // 行1：头像 ｜ 绿竖条 + 账户名 + 编辑胶囊（图标与名称并排）。
              Row(
                children: <Widget>[
                  ClayIconTile(
                    size: 38,
                    color: isDark ? ForestGreen.brand : ForestGreen.deep,
                    child: LineIcon(
                      LineIconKind.lend,
                      size: 20,
                      color: Color.lerp(
                        isDark ? ForestGreen.brand : ForestGreen.deep,
                        context.forest.onSurface,
                        0.22,
                      )!,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 4,
                          height: 14,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                AppPalette.sageMist,
                                AppPalette.sageRibbon,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            account.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onEdit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '编辑',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 行2：大字未结清金额 +「待收回 / 待归还」小标（右对齐、同行）。
              Row(
                children: <Widget>[
                  const Spacer(),
                  Text(
                    Money.fromMinor(account.balanceMinor).format(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? context.forest.onSurface
                          : context.forest.onSurface,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isLendOut ? '待收回' : '待归还',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.forest.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 行3：状态胶囊 + 进入箭头。
              Row(
                children: <Widget>[
                  _capsule(
                    '进行中 $ongoingCount 笔',
                    isDark
                        ? ForestGreen.deep.withValues(alpha: 0.22)
                        : ForestGreen.soft,
                    isDark ? ForestGreen.brand : ForestGreen.deep,
                  ),
                  const SizedBox(width: 8),
                  _capsule(
                    '已结清 $settledCount 笔',
                    ForestAccent.gold.withValues(alpha: 0.14),
                    ForestAccent.gold,
                  ),
                  const Spacer(),
                  LineGlyph(
                    Icons.chevron_right,
                    size: 18,
                    color: context.forest.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _capsule(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: fg),
        ),
      );
}

// ── 未指定账户的记录：平铺行（保留删除 / 编辑入口） ─────────

class _UnassignedTile extends StatelessWidget {
  const _UnassignedTile({
    required this.record,
    required this.onDelete,
    required this.onTap,
  });

  final LendRecord record;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isOut = record.direction == LendDirection.lendOut;
    return ListTile(
      leading: LineGlyph(
        isOut ? Icons.north_east : Icons.south_west,
        color: isOut ? AppPalette.expense : AppPalette.income,
      ),
      title: Text(
        record.counterparty.isEmpty ? '未填写对方' : record.counterparty,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${record.direction.label} · ${record.status.label} · '
        '${Money.fromMinor(record.amountMinor).format()}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (record.dueAt != null)
            Text(
              '到期 ${DateFormat('MM-dd').format(
                DateTime.fromMillisecondsSinceEpoch(record.dueAt!, isUtc: true),
              )}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          IconButton(
            icon: const LineGlyph(Icons.delete_outline, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _NoLendEmpty extends StatelessWidget {
  const _NoLendEmpty();

  @override
  Widget build(BuildContext context) {
    // 第 41 批：去掉垂直顶格 padding（居中由外层 Center 负责），
    // 仅留水平呼吸边距；Column mainAxisSize.min 整体居中。
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _LendEmptyIcon(),
          SizedBox(height: 14),
          _LendEmptyTitle(),
          SizedBox(height: 6),
          _LendEmptyHint(),
        ],
      ),
    );
  }
}

/// 空态主文案（深色，onSurface）。
class _LendEmptyTitle extends StatelessWidget {
  const _LendEmptyTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      '还没有借还记录',
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: context.forest.onSurface,
      ),
    );
  }
}

/// 空态次级说明（弱化色，onSurfaceVariant）。
class _LendEmptyHint extends StatelessWidget {
  const _LendEmptyHint();

  @override
  Widget build(BuildContext context) {
    return Text(
      // 第 46 批：语义随底栏改名对齐——幽灵键已是「新建账户」，次行
      // 不再写「到账户页」，直接引用底栏按钮名。
      '点下方「记一笔借还」即可开始；\n'
      '也可以点「新建账户」建立借出 / 借入类型账户，之后自动归户',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        color: context.forest.onSurfaceVariant,
      ),
    );
  }
}

/// 借还空态线稿图标圆牌（鼠尾草软底，报销页空态同款）。
class _LendEmptyIcon extends StatelessWidget {
  const _LendEmptyIcon();

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: isDark
            ? ForestGreen.deep.withValues(alpha: 0.18)
            : ForestGreen.soft,
        border: Border.all(
          color: isDark
              ? ForestGreen.deep.withValues(alpha: 0.30)
              : ForestGreen.softBorder,
        ),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: LineIcon(
        LineIconKind.lend,
        size: 34,
        color: isDark ? ForestGreen.brand : ForestGreen.label,
      ),
    );
  }
}

/// 底部栏胶囊按钮（报销页 [_PillButton] 同款布局，借还页私有）。
class _LendPillButton extends StatelessWidget {
  const _LendPillButton({
    required this.onPressed,
    this.backgroundColor,
    this.gradient,
    this.border,
    required this.textColor,
    this.icon,
    required this.label,
  });

  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Gradient? gradient;
  final BoxBorder? border;
  final Color textColor;
  final Widget? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    // 第 41 批：渐变/底色/描边必须由 Container 自绘，不能用 Ink——
    // Ink 装饰画在最近 Material 的 ink 层，会被本页 _bottomBar 的
    // 不透明 Container(color: surface) 整体遮盖（真机事故：按钮隐形
    // 但可点）。报销页空态按钮同款 Container 自绘渲染正常。
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          gradient: gradient,
          border: border,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null)
                Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: icon,
                ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
