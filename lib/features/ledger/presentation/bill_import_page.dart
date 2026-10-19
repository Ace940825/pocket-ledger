import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pocket_ledger/theme/app_dimens.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/line_icon_map.dart';
import '../../../theme/app_colors.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../categories/data/category_repository.dart';
import '../../categories/providers/categories_providers.dart';
import '../../lend/data/lend_repository.dart';
import '../../lend/providers/lend_providers.dart';
import '../data/bill_io.dart';
import '../data/bill_template.dart';
import '../data/transaction_repository.dart';
import '../providers/ledger_providers.dart';
import 'bill_import_guide_page.dart';

/// 「账单管理 → 账单导入」页。
///
/// 支持两种来源：直接粘贴本 App 导出的 CSV / JSON 内容，或从应用 Documents
/// 目录读取 `import.csv` / `import.json`。解析后预览，确认再写入——
/// 账户 / 分类按名称归户，缺失项自动创建（账户默认现金类）。
class BillImportPage extends ConsumerStatefulWidget {
  const BillImportPage({super.key, this.initialDraft});

  /// 从截图识别等外部来源直接进入确认页时传入已解析结果，
  /// 跳过粘贴 / 文件读取输入区，直接展示预览与确认栏。
  final ParseResult? initialDraft;

  const BillImportPage.fromDraft(ParseResult draft, {super.key})
      : initialDraft = draft;

  @override
  ConsumerState<BillImportPage> createState() => _BillImportPageState();
}

class _BillImportPageState extends ConsumerState<BillImportPage> {
  final TextEditingController _text = TextEditingController();
  ParseResult? _parsed;

  /// 模板系统（2026-10-18）：解析成功后的匹配校验与三维归集报告。
  TemplateCheckResult? _check;
  bool _importing = false;
  String? _resultMsg;

  @override
  void initState() {
    super.initState();
    // 截图识别等外部来源的草稿：直接进入确认页，无需粘贴输入。
    if (widget.initialDraft != null) _parsed = widget.initialDraft;
  }

  /// 弹系统文档选择器，让用户从本地任选 .csv / .json 文件，而不是只认固定文件名。
  Future<void> _pickFile() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['csv', 'json'],
      dialogTitle: '选择账单文件',
    );
    if (result == null) {
      if (mounted) showAppToast(context, '已取消选择');
      return;
    }
    final String? filePath = result.files.single.path;
    if (filePath == null) {
      if (mounted) showAppToast(context, '无法读取该文件');
      return;
    }
    _text.text = await File(filePath).readAsString();
    await _parse();
    if (mounted) showAppToast(context, '已读取文件内容');
  }

  Future<void> _parse() async {
    final ParseResult parsed = parseInput(_text.text);
    TemplateCheckResult? check;
    if (parsed.rows.isNotEmpty) {
      // 与当前账本的账户 / 分类 / 账本做匹配校验（模板系统：不再静默自动创建，
      // 未知项在报告中显式列出）。
      final List<Account> accounts = await ref.read(accountsProvider.future);
      final List<Category> categories =
          await ref.read(allCategoriesProvider.future);
      final List<Book> books = await ref.read(booksListProvider.future);
      final List<Set<String>> catNames = <Set<String>>[
        <String>{}, // income（与 CategoryType 顺序对齐）
        <String>{}, // expense
        <String>{}, // transfer
      ];
      for (final Category c in categories) {
        if (c.type.index < catNames.length) {
          catNames[c.type.index].add(c.name.trim().toLowerCase());
        }
      }
      check = checkRows(
        parsed.rows,
        accountNames: <String>{
          for (final Account a in accounts) a.name.trim().toLowerCase(),
        },
        categoryNamesByType: catNames,
        bookNames: <String>{
          for (final Book b in books) b.name.trim().toLowerCase(),
        },
      );
    }
    setState(() {
      _parsed = parsed;
      _check = check;
      _resultMsg = null;
    });
  }

  Future<void> _import() async {
    if (_importing || _parsed == null || _parsed!.rows.isEmpty) return;
    setState(() => _importing = true);
    try {
      final String currentBookId = ref.read(currentBookIdProvider);
      final List<Book> books = await ref.read(booksListProvider.future);
      final Map<String, String> bookNameToId = <String, String>{};
      for (final Book b in books) {
        bookNameToId[b.name.trim().toLowerCase()] = b.id;
      }

      final TransactionRepository txnRepo =
          ref.read(transactionRepositoryProvider);
      final AccountRepository accRepo = ref.read(accountRepositoryProvider);
      final CategoryRepository catRepo = ref.read(categoryRepositoryProvider);
      final accountsDao = ref.read(accountsDaoProvider);
      final categoriesDao = ref.read(categoriesDaoProvider);
      // Phase 2 借还路由：模块=借还 且分类为 6 类固定名时，落到借还台账而非普通交易。
      final LendRepository lendRepo = ref.read(lendRepositoryProvider);

      // 账本 → 账户 / 分类列表缓存（按目标账本隔离，支持多账本路由）。
      final Map<String, List<Account>> accByBook = <String, List<Account>>{};
      final Map<String, List<Category>> catByBook = <String, List<Category>>{};
      Future<List<Account>> accountsOf(String id) async {
        final List<Account>? cached = accByBook[id];
        if (cached != null) return cached;
        final List<Account> list = await accountsDao.watchByBook(id).first;
        accByBook[id] = list;
        return list;
      }

      Future<List<Category>> categoriesOf(String id) async {
        final List<Category>? cached = catByBook[id];
        if (cached != null) return cached;
        final List<Category> list = await categoriesDao.watchAll(id).first;
        catByBook[id] = list;
        return list;
      }

      // 名称（小写）→ ID 缓存（含账本维度，避免跨账本同名串扰）。
      final Map<String, String> accCache = <String, String>{};
      final Map<String, String> catCache = <String, String>{};

      int imported = 0;
      int skipped = 0;
      final List<String> reasons = <String>[];

      for (final BillRow row in _parsed!.rows) {
        try {
          // 解析目标账本：指定且存在则用之，否则归入当前账本。
          String bookId = currentBookId;
          if (row.book != null && row.book!.trim().isNotEmpty) {
            final String? found = bookNameToId[row.book!.trim().toLowerCase()];
            if (found != null) {
              bookId = found;
            } else {
              reasons.add('账本「${row.book!.trim()}」不存在，已归入当前账本');
            }
          }
          final List<Account> accounts = await accountsOf(bookId);
          final List<Category> categories = await categoriesOf(bookId);

          // ── Phase 2 借还路由 ──
          // 模块=借还 且分类为 6 类固定名（借入/借出/还债/收债/债务消减/坏账计提）
          // 时，落到借还台账（add/repay/debtReduction），而非普通交易。
          if (row.module == SourceModule.lend) {
            final LendOp? op = parseLendOp(row.categoryName);
            if (op == null) {
              skipped++;
              reasons.add('借还分类「${row.categoryName ?? ''}」未识别，跳过');
              continue;
            }
            await _importLend(
              row,
              op,
              bookId,
              lendRepo,
              accounts,
              accRepo,
              accCache,
            );
            imported++;
            continue;
          }

          final String accountId = await _resolveAccount(
            row.accountName,
            bookId,
            accounts,
            accRepo,
            accCache,
          );
          final String? toAccountId = row.toAccountName == null
              ? null
              : await _resolveAccount(
                  row.toAccountName!,
                  bookId,
                  accounts,
                  accRepo,
                  accCache,
                );
          final String? categoryId = row.categoryName == null
              ? null
              : await _resolveCategory(
                  row.categoryName!,
                  row.type,
                  bookId,
                  categories,
                  catRepo,
                  catCache,
                );
          // 报销账户：可报销且指定了账户名时，按名称归户；缺失则建为报销类账户。
          String? reimbursementAccountId;
          if (row.isReimbursable &&
              row.reimbursementAccount != null &&
              row.reimbursementAccount!.trim().isNotEmpty) {
            reimbursementAccountId = await _resolveAccount(
              row.reimbursementAccount!,
              bookId,
              accounts,
              accRepo,
              accCache,
              createType: AccountType.reimbursement,
            );
          }

          await txnRepo.add(
            bookId: bookId,
            type: row.type,
            amountMinor: row.amountMinor,
            accountId: accountId,
            toAccountId: toAccountId,
            categoryId: categoryId,
            occurredAt: row.occurredAt.toUtc().millisecondsSinceEpoch,
            note: row.note,
            currency: row.currency,
            sourceModule: row.module,
            tags: row.tags.isEmpty ? null : row.tags,
            discountMinor: row.discountMinor,
            excludeFromBudget: row.excludeFromBudget,
            excludeFromStats: row.excludeFromStats,
            isReimbursable: row.isReimbursable,
            reimbursementAccountId: reimbursementAccountId,
          );
          imported++;
        } catch (e) {
          skipped++;
          reasons.add('${row.accountName} ${_typeLabel(row.type)} '
              '${Money.fromMinor(row.amountMinor).format()}：$e');
        }
      }

      setState(() {
        _resultMsg = skipped == 0
            ? '成功导入 $imported 笔账单'
            : '导入 $imported 笔，跳过 $skipped 笔';
      });
      // reasons 仅用于开发期排查，不展示给用户（避免 UI 噪声）。
    } catch (e) {
      if (mounted) showAppToast(context, '导入失败：$e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<String> _resolveAccount(
    String name,
    String bookId,
    List<Account> accounts,
    AccountRepository repo,
    Map<String, String> cache, {
    AccountType createType = AccountType.cash,
  }) async {
    final String key = '$bookId|${name.trim().toLowerCase()}';
    final String? cached = cache[key];
    if (cached != null) return cached;
    for (final Account a in accounts) {
      if (a.name.trim().toLowerCase() == name.trim().toLowerCase()) {
        cache[key] = a.id;
        return a.id;
      }
    }
    final String id = await repo.add(
      bookId: bookId,
      name: name.trim(),
      type: createType,
    );
    cache[key] = id;
    return id;
  }

  Future<String> _resolveCategory(
    String name,
    TxnType type,
    String bookId,
    List<Category> categories,
    CategoryRepository repo,
    Map<String, String> cache,
  ) async {
    final String key = '$bookId|${type.index}:${name.trim().toLowerCase()}';
    final String? cached = cache[key];
    if (cached != null) return cached;
    // TxnType 与 CategoryType 枚举顺序一致（income/expense/transfer），
    // 按 index 映射；此前直接拿 CategoryType 与 TxnType 比较，恒为 false，
    // 导致已有同名分类永远匹配不上、重复建分类。
    final CategoryType catType = CategoryType.values[type.index];
    for (final Category c in categories) {
      if (c.type == catType &&
          c.name.trim().toLowerCase() == name.trim().toLowerCase()) {
        cache[key] = c.id;
        return c.id;
      }
    }
    final String id = await repo.ensureNamed(
      bookId: bookId,
      name: name.trim(),
      type: catType,
      iconKey: null,
    );
    cache[key] = id;
    return id;
  }

  /// Phase 2 借还路由落库：按 [op] 把一笔借还行路由到 [LendRepository] 的对应方法。
  ///
  /// - 借入/借出（add）：账户列 = 真实资产账户（toAccountId），对方 = counterparty，
  ///   借款本金落地 + 资金流水；未指定借入/借出账户时按对方名自动归户。
  /// - 还债/收债（repay）：账户列 = 真实资产账户（accountId），冲销同名未结清债务
  ///   + 可选资金流水。
  /// - 债务消减/坏账计提（debtReduction）：无需资产账户，仅记账备忘冲减。
  ///
  /// 校验（对方必填 / 账户必填）已由 [checkRows] 把关；此处直接调用仓储，
  /// 任何异常（如「未找到未结清债务」）冒泡到外层 try 计入 skipped。
  Future<void> _importLend(
    BillRow row,
    LendOp op,
    String bookId,
    LendRepository lendRepo,
    List<Account> accounts,
    AccountRepository accRepo,
    Map<String, String> accCache,
  ) async {
    final LendDirection direction = lendOpDirection(op);
    String? assetAccountId;
    if (lendOpNeedsAccount(op)) {
      assetAccountId = await _resolveAccount(
        row.accountName,
        bookId,
        accounts,
        accRepo,
        accCache,
      );
    }
    final String counterparty = (row.counterparty ?? '').trim();
    final int occurredAt = row.occurredAt.toUtc().millisecondsSinceEpoch;
    switch (op) {
      case LendOp.borrowAdd:
      case LendOp.lendAdd:
        await lendRepo.add(
          bookId: bookId,
          direction: direction,
          status: LendStatus.ongoing,
          counterparty: counterparty,
          amountMinor: row.amountMinor,
          occurredAt: occurredAt,
          note: row.note,
          toAccountId: assetAccountId,
          discountMinor: row.discountMinor,
        );
      case LendOp.borrowRepay:
      case LendOp.lendCollect:
        await lendRepo.repay(
          bookId: bookId,
          direction: direction,
          counterparty: counterparty,
          amountMinor: row.amountMinor,
          occurredAt: occurredAt,
          note: row.note,
          accountId: assetAccountId,
        );
      case LendOp.borrowReduce:
      case LendOp.lendBadDebt:
        await lendRepo.debtReduction(
          bookId: bookId,
          direction: direction,
          counterparty: counterparty,
          amountMinor: row.amountMinor,
          occurredAt: occurredAt,
          note: row.note,
        );
    }
  }

  String _typeLabel(TxnType t) => switch (t) {
        TxnType.income => '收入',
        TxnType.expense => '支出',
        TxnType.transfer => '转账',
      };

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账单导入'),
        centerTitle: true,
        leading: const BackButton(),
        actions: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const BillImportGuidePage(),
              ),
            ),
            icon: const LineGlyph(Icons.help_outline, size: 20),
            tooltip: '导入说明',
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.lg,
                AppDimens.md,
                AppDimens.lg,
                AppDimens.lg,
              ),
              children: <Widget>[
                if (widget.initialDraft == null) ...<Widget>[
                  Container(
                    decoration: BoxDecoration(
                      color: AppPalette.softGreen,
                      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                    ),
                    padding: const EdgeInsets.all(AppDimens.md),
                    child: Text(
                      '粘贴本 App 导出的 CSV / JSON 内容，或点「选择文件」从本地任选 '
                      '.csv / .json；空白填写模板可在「账单导出」页下载。解析后按 '
                      '分类 / 时间 / 账户自动匹配校验并给出核对归集报告：'
                      '账户 / 分类缺失项将自动创建（账户默认现金类）。',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimens.md),
                  Container(
                    decoration: BoxDecoration(
                      color: AppPalette.white,
                      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: TextField(
                      controller: _text,
                      maxLines: 8,
                      minLines: 5,
                      decoration: const InputDecoration(
                        hintText: '在此粘贴 CSV 或 JSON 内容…',
                        border: InputBorder.none,
                        hintStyle: TextStyle(fontSize: 13),
                      ),
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: AppDimens.sm),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickFile,
                          icon: const LineGlyph(
                            Icons.folder_open_outlined,
                            size: 18,
                          ),
                          label: const Text('选择文件'),
                          style: _outlineStyle(),
                        ),
                      ),
                      const SizedBox(width: AppDimens.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              _text.text.trim().isEmpty ? null : () => _parse(),
                          icon:
                              const LineGlyph(Icons.preview_outlined, size: 18),
                          label: const Text('解析预览'),
                          style: _outlineStyle(),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_parsed != null) ..._previewSection(),
              ],
            ),
          ),
          if (_parsed != null && _parsed!.rows.isNotEmpty && _resultMsg == null)
            _importBar(),
        ],
      ),
    );
  }

  ButtonStyle _outlineStyle() => OutlinedButton.styleFrom(
        foregroundColor: AppPalette.ctaGreen,
        side: const BorderSide(color: AppPalette.ctaGreen),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
      );

  List<Widget> _previewSection() {
    final ParseResult p = _parsed!;
    return <Widget>[
      const SizedBox(height: AppDimens.lg),
      Container(
        decoration: BoxDecoration(
          color: AppPalette.white,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppPalette.softGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '可导入 ${p.rows.length} 笔',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.ctaGreen,
                    ),
                  ),
                ),
                if (p.hasErrors) ...<Widget>[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppPalette.redSoftBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '跳过 ${p.errors.length} 笔',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.expense,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppDimens.sm),
            for (int i = 0; i < p.rows.length && i < 20; i++)
              _previewRow(p.rows[i]),
            if (p.rows.length > 20)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '… 仅预览前 20 笔',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (p.hasErrors) ...<Widget>[
              const Divider(height: 16, color: AppPalette.divider),
              const Text(
                '以下问题行将被跳过（解析错误）：',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.expense,
                ),
              ),
              const SizedBox(height: 4),
              for (final String e in p.errors.take(10))
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '· $e',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
            if (_check != null) ..._checkSection(_check!),
          ],
        ),
      ),
    ];
  }

  // ── 模板系统：匹配校验 + 核对归集报告 ──────────────────────────

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

  Widget _previewRow(BillRow r) {
    final Color typeColor = switch (r.type) {
      TxnType.income => AppPalette.income,
      TxnType.expense => AppPalette.expense,
      TxnType.transfer => AppPalette.transferBlueGray,
    };
    final String accountLine = r.toAccountName == null
        ? r.accountName
        : '${r.accountName} → ${r.toAccountName}';
    // 截图识别置信度偏低时高亮，提示用户核对金额 / 分类。
    final bool lowConf = r.confidence != null && r.confidence! < kLowConfidence;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _typeLabel(r.type),
              style: TextStyle(fontSize: 11, color: typeColor),
            ),
          ),
          if (lowConf)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppPalette.redSoftBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '需复核',
                  style: TextStyle(fontSize: 10, color: AppPalette.expense),
                ),
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              accountLine,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            Money.fromMinor(r.amountMinor, currency: r.currency).format(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: typeColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _importBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.lg,
        AppDimens.sm,
        AppDimens.lg,
        AppDimens.lg,
      ),
      child: Column(
        children: <Widget>[
          if (_resultMsg != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.sm),
              child: Text(
                _resultMsg!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _importing ? null : _import,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.ctaGreen,
                foregroundColor: AppPalette.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
              ),
              child: _importing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppPalette.white,
                      ),
                    )
                  : Text('确认导入 ${_parsed!.rows.length} 笔'),
            ),
          ),
        ],
      ),
    );
  }
}
