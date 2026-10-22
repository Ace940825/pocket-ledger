import 'package:flutter/material.dart';

import '../../../core/theme/forest_design_tokens.dart';
import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/sheet_scaffold.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimens.dart';
import '../data/bill_io.dart';
import '../data/bill_template.dart';

/// 「账单导入预览」页（对标小青账，2026-10-20）：配置页点「开始导入」后进入。
///
/// 总览（分类 / 账户 / 新增收入账单 / 新增支出账单，可点）→ 提示（预览仅
/// 展示部分账单 + 被跳过行原因）→ 账单列表（支出 / 收入 / 其他筛选）→
/// 底部「确认导入账单」。确认后 `pop(true)` 回配置页执行真实导入——
/// 本页即「写入前确认环节」，替代原确认弹窗。
class BillImportPreviewPage extends StatefulWidget {
  const BillImportPreviewPage({super.key, required this.parsed, this.check});

  /// 解析结果（可导入行 + 解析错误行）。
  final ParseResult parsed;

  /// 模板系统匹配校验报告（核对归集 + 将自动创建项），可为 null（外部草稿）。
  final TemplateCheckResult? check;

  @override
  State<BillImportPreviewPage> createState() => _BillImportPreviewPageState();
}

class _BillImportPreviewPageState extends State<BillImportPreviewPage> {
  /// 账单列表筛选页签：0 支出 / 1 收入 / 2 其他（转账等）。
  int _tab = 0;

  static const int _maxShown = 100;

  List<BillRow> get _rows => widget.parsed.rows;

  int get _expenseCount =>
      _rows.where((BillRow r) => r.type == TxnType.expense).length;
  int get _incomeCount =>
      _rows.where((BillRow r) => r.type == TxnType.income).length;

  /// 涉及的分类（去重，保序）。
  List<String> get _categoryNames => <String>{
        for (final BillRow r in _rows)
          if (r.categoryName != null && r.categoryName!.trim().isNotEmpty)
            r.categoryName!.trim(),
      }.toList();

  /// 涉及的账户（去重，保序；转账含转入账户）。
  List<String> get _accountNames => <String>{
        for (final BillRow r in _rows) ...<String>[
          if (r.accountName.trim().isNotEmpty) r.accountName.trim(),
          if (r.toAccountName != null && r.toAccountName!.trim().isNotEmpty)
            r.toAccountName!.trim(),
        ],
      }.toList();

  /// 被跳过的行：解析错误 + 校验错误。
  List<String> get _skippedReasons => <String>[
        ...widget.parsed.errors,
        if (widget.check != null) ...widget.check!.errors,
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账单导入预览'),
        centerTitle: true,
        leading: const BackButton(),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.lg,
                AppDimens.md,
                AppDimens.lg,
                AppDimens.sm,
              ),
              children: <Widget>[
                _overviewCard(),
                const SizedBox(height: AppDimens.sm),
                _hintCard(),
                const SizedBox(height: AppDimens.sm),
                _billsCard(),
              ],
            ),
          ),
          _confirmBar(),
        ],
      ),
    );
  }

  // ── 总览 ─────────────────────────────────────────────────────

  Widget _overviewCard() {
    return _card(
      label: '总览',
      children: <Widget>[
        _overviewRow(
          title: '分类',
          subtitle: '${_categoryNames.length}个',
          onTap: () => _showNameSheet('涉及分类', _categoryNames),
        ),
        _divider(),
        _overviewRow(
          title: '账户',
          subtitle: '${_accountNames.length}个',
          onTap: () => _showNameSheet('涉及账户', _accountNames),
        ),
        _divider(),
        _overviewRow(
          title: '新增收入账单',
          subtitle: '$_incomeCount个',
          onTap: () => setState(() => _tab = 1),
        ),
        _divider(),
        _overviewRow(
          title: '新增支出账单',
          subtitle: '$_expenseCount个',
          onTap: () => setState(() => _tab = 0),
        ),
      ],
    );
  }

  Widget _overviewRow({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  // ── 提示 ─────────────────────────────────────────────────────

  Widget _hintCard() {
    final List<String> skipped = _skippedReasons;
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.softGreen,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      padding: const EdgeInsets.all(AppDimens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _cardLabel('提示'),
          const SizedBox(height: 4),
          Text(
            '下方为预览，仅显示部分账单，实际以导入为准~',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (skipped.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              '⚠️ ${skipped.length} 笔将被跳过：',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppPalette.expense,
              ),
            ),
            const SizedBox(height: 2),
            for (final String e in skipped.take(10))
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '· $e',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (skipped.length > 10)
              Text(
                '… 其余 ${skipped.length - 10} 条略',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
          if (widget.check != null) ..._checkSection(widget.check!),
        ],
      ),
    );
  }

  // ── 账单列表 ─────────────────────────────────────────────────

  Widget _billsCard() {
    final TxnType filter = switch (_tab) {
      0 => TxnType.expense,
      1 => TxnType.income,
      _ => TxnType.transfer,
    };
    final List<BillRow> filtered =
        _rows.where((BillRow r) => r.type == filter).toList();
    return _card(
      label: '账单',
      trailing: _tabPills(),
      children: <Widget>[
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              '该类型下暂无账单',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else ...<Widget>[
          for (int i = 0; i < filtered.length && i < _maxShown; i++)
            _billRow(filtered[i]),
          if (filtered.length > _maxShown)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Text(
                '… 仅显示前 $_maxShown 笔',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ],
    );
  }

  /// 右上类型筛选胶囊（对标小青账：支出 / 收入 / 其他，选中深色胶囊）。
  Widget _tabPills() {
    final Color unselected =
        Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < 3; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 10),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => setState(() => _tab = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _tab == i ? ForestNeutral.deepInk : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                switch (i) { 0 => '支出', 1 => '收入', _ => '其他' },
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _tab == i ? AppPalette.white : unselected,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _billRow(BillRow r) {
    final Color typeColor = switch (r.type) {
      TxnType.income => AppPalette.income,
      TxnType.expense => AppPalette.expense,
      TxnType.transfer => AppPalette.transferBlueGray,
    };
    final String title = (r.categoryName != null &&
            r.categoryName!.trim().isNotEmpty)
        ? r.categoryName!.trim()
        : (r.note != null && r.note!.trim().isNotEmpty
            ? r.note!.trim()
            : r.accountName);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${r.occurredAt.month}月${r.occurredAt.day}日'
                  '${r.subcategoryName == null ? '' : ' · ${r.subcategoryName}'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            Money.fromMinor(r.amountMinor, currency: r.currency).format(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: typeColor,
            ),
          ),
        ],
      ),
    );
  }

  // ── 底部确认栏 ───────────────────────────────────────────────

  Widget _confirmBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.lg,
        AppDimens.sm,
        AppDimens.lg,
        AppDimens.lg,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: ForestGradients.button,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            boxShadow: ForestElevation.float,
          ),
          child: Material(
            color: Colors.transparent, // ignore: no_raw_colors
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              onTap: () => Navigator.of(context).pop(true),
              child: const Center(
                child: Text(
                  '确认导入账单',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 通用小件 ─────────────────────────────────────────────────

  /// 白底圆角分组卡（与配置页 `_sectionCard` 同款：鼠尾草竖条标题）。
  Widget _card({
    required String label,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
            child: Row(
              children: <Widget>[
                _cardLabel(label),
                const Spacer(),
                if (trailing != null) trailing,
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _cardLabel(String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 4,
          height: 14,
          decoration: BoxDecoration(
            color: AppPalette.sage500,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 16, color: AppPalette.divider);

  /// 名称清单弹层（涉及分类 / 账户）。
  void _showNameSheet(String title, List<String> names) {
    showAppModalSheet<void>(
      context,
      title: title,
      isScrollControlled: true,
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final String n in names)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        n,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── 匹配校验与核对归集（自配置页迁入） ─────────────────────────

  String _fmtDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  /// 归集金额文本：收 / 支 / 转非零项分列（净额对账户维度有歧义）。
  String _aggAmountText(TemplateAgg a) {
    final List<String> parts = <String>[
      if (a.incomeMinor > 0) '收 ${aggAmount(a.incomeMinor)}',
      if (a.expenseMinor > 0) '支 ${aggAmount(a.expenseMinor)}',
      if (a.transferMinor > 0) '转 ${aggAmount(a.transferMinor)}',
    ];
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  /// 匹配校验与核对归集卡片：三维汇总（分类/账户/月）+ 将自动创建项
  /// + 校验错误明细。空数据行已被 [checkRows] 过滤。
  List<Widget> _checkSection(TemplateCheckResult c) {
    final TextStyle hint = TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1.5,
    );
    final bool allMatched = c.newAccounts.isEmpty && c.newCategories.isEmpty;
    return <Widget>[
      const Divider(height: 16, color: AppPalette.divider),
      Row(
        children: <Widget>[
          const Expanded(
            child: Text(
              '匹配校验与核对归集',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppPalette.ctaGreen,
              ),
            ),
          ),
          Text(
            c.spanStart != null
                ? '${_fmtDate(c.spanStart!)} ~ ${_fmtDate(c.spanEnd!)}'
                : '',
            style: hint,
          ),
        ],
      ),
      const SizedBox(height: 6),
      _aggBlock('按分类', c.byCategory, 6),
      _aggBlock('按账户', c.byAccount, 6),
      _aggBlock('按月', c.byMonth, 4),
      _aggBlock('按模块', c.byModule, 6),
      const SizedBox(height: 6),
      if (c.restoredAccounts.isNotEmpty || c.updatedAccounts.isNotEmpty) ...<Widget>[
        Text(
          '账户段复原：新建 ${c.restoredAccounts.length} 个'
          '${c.updatedAccounts.isEmpty ? '' : '、覆盖 ${c.updatedAccounts.length} 个'}'
          '（${<String>[...c.restoredAccounts, ...c.updatedAccounts].join('、')}），'
          '导入完成后余额按段内「余额」列校正。',
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
      ],
      Text(
        allMatched
            ? '✅ 账户与分类全部匹配现有数据，导入不会新建。'
            : '⚠️ 以下项不在现有数据中，导入时将自动创建：\n'
                '· 账户：${c.newAccounts.join('、')}\n'
                '· 分类：${c.newCategories.join('、')}',
        style: TextStyle(
          fontSize: 12,
          height: 1.5,
          color: allMatched
              ? AppPalette.ctaGreen
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      if (c.hasErrors) ...<Widget>[
        const SizedBox(height: 6),
        const Text(
          '以下问题行将被跳过（校验错误）：',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppPalette.expense,
          ),
        ),
        const SizedBox(height: 4),
        for (final String e in c.errors.take(10))
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text('· $e', style: hint),
          ),
      ],
      if (c.warnings.isNotEmpty) ...<Widget>[
        const SizedBox(height: 6),
        for (final String w in c.warnings.take(6))
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text('· $w', style: hint),
          ),
      ],
    ];
  }

  /// 单个归集块：标题 + 前 [max] 行聚合明细（key / 笔数 / 金额）。
  Widget _aggBlock(String title, Map<String, TemplateAgg> agg, int max) {
    if (agg.isEmpty) return const SizedBox.shrink();
    final List<MapEntry<String, TemplateAgg>> entries = agg.entries.toList()
      ..sort(
        (MapEntry<String, TemplateAgg> a, MapEntry<String, TemplateAgg> b) =>
            b.value.count - a.value.count,
      );
    final int shownTotal = entries.length > max ? max : entries.length;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$title（${agg.length} 项）',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          for (final MapEntry<String, TemplateAgg> e in entries.take(max))
            Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      e.key,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    '${e.value.count} 笔 · ${_aggAmountText(e.value)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          if (entries.length > shownTotal)
            Text(
              '… 其余 ${entries.length - shownTotal} 项略',
              style: TextStyle(
                fontSize: 11.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
