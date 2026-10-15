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
import '../../../theme/app_colors.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../categories/data/category_repository.dart';
import '../../categories/providers/categories_providers.dart';
import '../data/bill_io.dart';
import '../data/transaction_repository.dart';
import '../providers/ledger_providers.dart';
import '../../../shared/widgets/line_icon_map.dart';

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
    _parse();
    if (mounted) showAppToast(context, '已读取文件内容');
  }

  void _parse() {
    setState(() {
      _parsed = parseInput(_text.text);
      _resultMsg = null;
    });
  }

  Future<void> _import() async {
    if (_importing || _parsed == null || _parsed!.rows.isEmpty) return;
    setState(() => _importing = true);
    try {
      final String bookId = ref.read(currentBookIdProvider);
      final List<Account> accounts = await ref.read(accountsProvider.future);
      final List<Category> categories =
          await ref.read(allCategoriesProvider.future);

      final TransactionRepository txnRepo =
          ref.read(transactionRepositoryProvider);
      final AccountRepository accRepo = ref.read(accountRepositoryProvider);
      final CategoryRepository catRepo = ref.read(categoryRepositoryProvider);

      // 名称（小写）→ ID 缓存，避免重复扫描与重复建账户 / 分类。
      final Map<String, String> accCache = <String, String>{};
      final Map<String, String> catCache = <String, String>{};

      int imported = 0;
      int skipped = 0;
      final List<String> reasons = <String>[];

      for (final BillRow row in _parsed!.rows) {
        try {
          final String accountId = await _resolveAccount(
            row.accountName,
            accCache,
            accounts,
            accRepo,
            bookId,
          );
          final String? toAccountId = row.toAccountName == null
              ? null
              : await _resolveAccount(
                  row.toAccountName!,
                  accCache,
                  accounts,
                  accRepo,
                  bookId,
                );
          final String? categoryId = row.categoryName == null
              ? null
              : await _resolveCategory(
                  row.categoryName!,
                  row.type,
                  catCache,
                  categories,
                  catRepo,
                  bookId,
                );

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
    } catch (e) {
      if (mounted) showAppToast(context, '导入失败：$e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<String> _resolveAccount(
    String name,
    Map<String, String> cache,
    List<Account> accounts,
    AccountRepository repo,
    String bookId,
  ) async {
    final String key = name.trim().toLowerCase();
    final String? cached = cache[key];
    if (cached != null) return cached;
    for (final Account a in accounts) {
      if (a.name.trim().toLowerCase() == key) {
        cache[key] = a.id;
        return a.id;
      }
    }
    final String id = await repo.add(
      bookId: bookId,
      name: name.trim(),
      type: AccountType.cash,
    );
    cache[key] = id;
    return id;
  }

  Future<String> _resolveCategory(
    String name,
    TxnType type,
    Map<String, String> cache,
    List<Category> categories,
    CategoryRepository repo,
    String bookId,
  ) async {
    final String key = '${type.index}:${name.trim().toLowerCase()}';
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
                      '.csv / .json。账户 / 分类按名称归户，'
                      '缺失项会自动创建（账户默认现金类）。',
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
                          icon: const LineGlyph(Icons.folder_open_outlined,
                              size: 18),
                          label: const Text('选择文件'),
                          style: _outlineStyle(),
                        ),
                      ),
                      const SizedBox(width: AppDimens.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _text.text.trim().isEmpty ? null : _parse,
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
                '以下问题行将被跳过：',
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
          ],
        ),
      ),
    ];
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
