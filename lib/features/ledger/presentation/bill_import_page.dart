import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:pocket_ledger/theme/app_dimens.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/forest_design_tokens.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/line_icon_map.dart';
import '../../../shared/widgets/line_icons.dart';
import '../../../shared/widgets/sheet_scaffold.dart';
import '../../../theme/app_colors.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../categories/data/category_repository.dart';
import '../../categories/providers/categories_providers.dart';
import '../../installment/data/installment_repository.dart';
import '../../installment/providers/installment_providers.dart';
import '../../investment/data/investment_repository.dart';
import '../../investment/providers/investment_providers.dart';
import '../../lend/data/lend_repository.dart';
import '../../lend/providers/lend_providers.dart';
import '../../record/presentation/account_picker_sheet.dart';
import '../../reimbursement/data/reimbursement_repository.dart';
import '../../reimbursement/providers/reimbursement_providers.dart';
import '../../savings/data/savings_repository.dart';
import '../../savings/providers/savings_providers.dart';
import '../data/bill_import_sources.dart';
import '../data/bill_io.dart';
import '../data/bill_template.dart';
import '../data/import_record_repository.dart';
import '../data/transaction_repository.dart';
import '../providers/ledger_providers.dart';
import 'widgets/txn_slidable.dart';

/// 「账单管理 → 账单导入」入口页（对标小青账，2026-10-20）：头部卡（云上传
/// 图标 + 标题）→ 信息条 → 空态 → 底部渐变按钮「导入账单」进入配置页。
/// 配置页 [BillImportConfigPage]（点击「导入账单」后）：数据（导入账单 /
/// 导入来源）+ 其他（关联账户资产）+ 开始导入。解析后预览，确认再写入——
/// 账户 / 分类按名称归户，缺失项自动创建（账户默认现金类）。
class BillImportPage extends StatelessWidget {
  const BillImportPage({super.key, this.initialDraft});

  /// 从截图识别等外部来源直接进入配置确认页时传入已解析结果，
  /// 跳过入口页，直接展示预览与确认栏。
  final ParseResult? initialDraft;

  const BillImportPage.fromDraft(ParseResult draft, {super.key})
      : initialDraft = draft;

  @override
  Widget build(BuildContext context) {
    final ParseResult? draft = initialDraft;
    if (draft != null) {
      return BillImportConfigPage(initialDraft: draft);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('账单导入'),
        centerTitle: true,
        leading: const BackButton(),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Consumer(
              builder: (BuildContext context, WidgetRef ref, _) {
                final AsyncValue<List<ImportRecord>> records =
                    ref.watch(importRecordsProvider);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.lg,
                    AppDimens.md,
                    AppDimens.lg,
                    AppDimens.lg,
                  ),
                  children: <Widget>[
                    const _ImportHeaderCard(),
                    const SizedBox(height: AppDimens.sm),
                    _entryInfoStrip(context),
                    const SizedBox(height: AppDimens.sm),
                    records.when(
                      data: (List<ImportRecord> list) => list.isEmpty
                          ? _emptyRecords()
                          : TxnSlidableGroup(
                              child: Column(
                                children: <Widget>[
                                  for (final ImportRecord r in list)
                                    _importRecordTile(context, ref, r),
                                ],
                              ),
                            ),
                      loading: () => const Padding(
                        padding: EdgeInsets.only(top: AppDimens.lg),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (Object e, _) => EmptyState(
                        message: '加载导入记录失败：$e',
                        iconWidget: LineIcon(
                          LineIconKind.receipt,
                          size: 48,
                          color: AppPalette.expense,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          _ImportGradientCta(
            label: '导入账单',
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const BillImportConfigPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 入口页信息条（对标小青账文案口径，结合本 App 能力改写）。
  Widget _entryInfoStrip(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.softGreen,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      padding: const EdgeInsets.all(AppDimens.md),
      child: Text(
        '系统差异可能导致导入账单需手动调整，请勿过度依赖此功能。仔细核对、'
        '分析账单，正是记账本身的乐趣与意义所在。\n'
        '与其耗费时间转换旧账目，不如放下历史记录，轻装上阵，即刻开始全新的'
        '记账体验！',
        style: TextStyle(
          fontSize: 12.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
      ),
    );
  }

  /// 入口页空态（无导入记录时）。
  Widget _emptyRecords() {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimens.lg),
      child: EmptyState(
        message: '没有发现导入记录哦',
        iconWidget: LineIcon(
          LineIconKind.receipt,
          size: 56,
          color: AppPalette.sageRibbon,
        ),
      ),
    );
  }

  /// 单条导入记录行：左滑删除（级联删除本批账单）。
  Widget _importRecordTile(
    BuildContext context,
    WidgetRef ref,
    ImportRecord r,
  ) {
    return Slidable(
      key: ValueKey<String>('import-${r.id}'),
      groupTag: TxnSlidable.groupTag,
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.18,
        children: <Widget>[
          TxnSlideAction(
            icon: Icons.delete_outline,
            semanticLabel: '删除',
            color: AppPalette.danger,
            onPressed: () => _confirmDeleteImport(context, ref, r),
          ),
        ],
      ),
      child: _importRecordCard(
        context: context,
        record: r,
        onTap: () => _showImportDetailSheet(context, r),
      ),
    );
  }

  /// 导入记录卡（来源 / 时间 / 笔数；点击查看详情与问题明细）。
  Widget _importRecordCard({
    required BuildContext context,
    required ImportRecord record,
    required VoidCallback onTap,
  }) {
    final DateTime dt =
        DateTime.fromMillisecondsSinceEpoch(record.createdAt).toLocal();
    final String time =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.sm),
      decoration: BoxDecoration(
        color: AppPalette.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Material(
        color: Colors.transparent, // ignore: no_raw_colors
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.md),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppPalette.graySurface,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
                  child: const Center(
                    child: LineIcon(
                      LineIconKind.receipt,
                      size: 22,
                      color: AppPalette.sageRibbon,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        record.sourceLabel,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$time · 导入 ${record.importedCount} 笔'
                        '${record.skippedCount > 0
                            ? ' · 跳过 ${record.skippedCount} 笔'
                            : ''}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const LineGlyph(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 删除导入记录（危险确认 + 级联删除本批账单）。
  Future<void> _confirmDeleteImport(
    BuildContext context,
    WidgetRef ref,
    ImportRecord r,
  ) async {
    final bool? confirm = await showConfirm(
      context,
      title: '删除导入记录',
      content: '删除后将同时移除本次导入的 ${r.importedCount} 笔账单'
          '${r.skippedCount > 0 ? '（含 ${r.skippedCount} 笔跳过项）' : ''}，'
          '此操作不可撤销。',
      confirmText: '删除',
      danger: true,
    );
    if (confirm != true || !context.mounted) return;
    try {
      await ref.read(importRecordRepositoryProvider).deleteCascade(
            r.id,
            ref.read(transactionRepositoryProvider),
          );
      if (context.mounted) {
        showAppToast(context, '已删除导入记录及关联账单');
      }
    } catch (e) {
      if (context.mounted) showAppToast(context, '删除失败：$e');
    }
  }

  /// 导入记录详情弹层：来源 / 完成时间 / 成功笔数 / 跳过笔数，含问题明细。
  void _showImportDetailSheet(BuildContext context, ImportRecord r) {
    showAppModalSheet<void>(
      context,
      title: '导入记录详情',
      body: ListView(
        shrinkWrap: true,
        children: <Widget>[
          _detailRow(context, '来源', r.sourceLabel),
          _detailRow(context, '完成时间', _fmtImportTime(r.createdAt)),
          _detailRow(context, '成功导入', '${r.importedCount} 笔'),
          _detailRow(context, '跳过 / 失败', '${r.skippedCount} 笔'),
          if (r.failReasons != null && r.failReasons!.isNotEmpty) ...<Widget>[
            const Divider(height: 16, color: AppPalette.divider),
            const Text(
              '问题明细',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppPalette.expense,
              ),
            ),
            const SizedBox(height: 4),
            for (final String reason in r.failReasons!)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '· $reason',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtImportTime(int ms) {
    final DateTime dt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// 「账单导入」配置页（入口页点「导入账单」后，对标小青账第二屏）：
/// 数据（导入账单 / 导入来源）+ 其他（关联账户资产）+ 开始导入。
class BillImportConfigPage extends ConsumerStatefulWidget {
  const BillImportConfigPage({super.key, this.initialDraft});

  /// 从截图识别等外部来源直接进入确认页时传入已解析结果，
  /// 跳过文件读取输入区，直接展示预览与确认栏。
  final ParseResult? initialDraft;

  @override
  ConsumerState<BillImportConfigPage> createState() =>
      _BillImportConfigPageState();
}

class _BillImportConfigPageState extends ConsumerState<BillImportConfigPage> {
  /// 已读取的文件文本内容（无粘贴框，仅文件通道；CSV / JSON 由解析器自动识别）。
  String _rawContent = '';
  ParseResult? _parsed;

  /// 模板系统（2026-10-18）：解析成功后的匹配校验与三维归集报告。
  TemplateCheckResult? _check;
  bool _importing = false;
  String? _resultMsg;

  /// 最近一次导入的「跳过 / 失败」笔数与原因清单（供结果栏「查看问题」复用）。
  int _lastSkipped = 0;
  List<String> _lastReasons = <String>[];

  /// 导入来源（第三方 CSV 走专用解析器，见 bill_import_sources.dart）。
  ImportSource _source = ImportSource.pocketLedger;

  /// 关联账户（资产）：选择后通用路径所有行强制归入该账户；未选择则按
  /// 表格「账户」列自动获取（缺失自动创建，原行为）。
  String? _linkedAccountId;
  String _linkedAccountName = '';

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
    // 字节级解码：UTF-8 优先，失败回退 GBK（支付宝 / 云闪付导出）。
    _rawContent = decodeBillFileBytes(await File(filePath).readAsBytes());
    // 本 App / 空白模板选择下自动嗅探第三方表头，命中即切换来源并回显。
    if (_source == ImportSource.pocketLedger ||
        _source == ImportSource.blankTemplate) {
      final ImportSource? detected = detectSource(_rawContent);
      if (detected != null && mounted) {
        setState(() => _source = detected);
        showAppToast(context, '已识别为${_source.label}账单');
      }
    }
    await _parse();
    if (mounted) showAppToast(context, '已解析文件，请核对下方预览');
  }

  Future<void> _parse() async {
    final ParseResult parsed = parseSource(_source, _rawContent);
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

  /// 选择导入来源（对标小青账「导入来源」行）：第三方来源走专用解析器
  /// （支付宝 / 微信 / 云闪付，见 bill_import_sources.dart）。
  ///
  /// 6 个来源项每项带两行副标题，总高度可能超过弹层最大高度（2026-10-20
  /// 真机溢出 66px）：isScrollControlled 突破半屏上限 + SingleChildScrollView
  /// 兜底滚动——内容短时弹层仍按内容自适应，超长时可滚动不溢出。
  Future<void> _pickSource() async {
    await showAppModalSheet<void>(
      context,
      title: '导入来源',
      isScrollControlled: true,
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final ImportSource s in ImportSource.values) ...<Widget>[
              if (s != ImportSource.values.first)
                const Divider(height: 1, color: AppPalette.divider),
              _sourceRow(
                title: s.label,
                subtitle: s.subtitle,
                selected: _source == s,
                onTap: () {
                  setState(() => _source = s);
                  Navigator.pop(context);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 来源单选行（与导出页格式单选同款：标题 + 副标题 + 右侧圆点选中态）。
  Widget _sourceRow({
    required String title,
    required String subtitle,
    required bool selected,
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
                  const SizedBox(height: 3),
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
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppPalette.ctaGreen : AppPalette.divider,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppPalette.ctaGreen,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  /// 选择关联账户（资产）：可不选（将按表格「账户」列自动获取）。
  Future<void> _pickLinkedAccount() async {
    final String? result = await showAppModalSheet<String>(
      context,
      isScrollControlled: true,
      bodyPadding: EdgeInsets.zero,
      useRootNavigator: true,
      body: AccountPickerSheet(
        selectedId: _linkedAccountId,
        title: '选择导入资产',
        // 允许「不选择」：未选择将从表格「账户」列自动获取。
        showNoneRow: true,
        onConfirm: (Account? acc) =>
            Navigator.of(context, rootNavigator: true).pop(acc?.id ?? ''),
      ),
    );
    if (result == null || !mounted) return;
    if (result.isEmpty) {
      // 「不选择具体账户」（空串）：清除已选关联账户。
      setState(() {
        _linkedAccountId = null;
        _linkedAccountName = '';
      });
      return;
    }
    final List<Account> accounts = await ref.read(accountsProvider.future);
    String name = '';
    for (final Account a in accounts) {
      if (a.id == result) {
        name = a.name;
        break;
      }
    }
    setState(() {
      _linkedAccountId = result;
      _linkedAccountName = name;
    });
  }

  /// 下载空白填写模板（跟随所选来源：第三方来源为对应字段说明模板）。
  Future<void> _downloadTemplate() async {
    final String content = buildSourceTemplate(_source);
    const String ext = 'csv';
    // file_picker 8.x：Android/iOS 的 saveFile 必须直接传 bytes（由系统
    // 面板落盘，返回保存路径）；桌面端才返回所选路径、需自行写文件。
    final bool isMobile = Platform.isAndroid || Platform.isIOS;
    final String? picked = await FilePicker.platform.saveFile(
      dialogTitle: '保存账单导入模板',
      fileName: '账单导入模板.$ext',
      allowedExtensions: isMobile ? null : const <String>[ext],
      bytes: isMobile ? Uint8List.fromList(utf8.encode(content)) : null,
    );
    if (picked == null) {
      if (mounted) showAppToast(context, '已取消保存');
      return;
    }
    String outPath = picked;
    if (!isMobile) {
      // 桌面保存面板不强制扩展名，缺失时补足，避免存成无后缀文件。
      outPath =
          picked.toLowerCase().endsWith('.$ext') ? picked : '$picked.$ext';
      await File(outPath).writeAsString(content);
    }
    if (mounted) showAppToast(context, '模板已保存，按说明填写后可导入');
  }

  Future<void> _import() async {
    if (_importing || _parsed == null || _parsed!.rows.isEmpty) return;
    // 写入前二次确认（共享组件 showConfirm）：告知笔数及将自动新建的账户 / 分类数。
    final int newAcc = _check?.newAccounts.length ?? 0;
    final int newCat = _check?.newCategories.length ?? 0;
    final StringBuffer confirmContent = StringBuffer(
      '将导入 ${_parsed!.rows.length} 笔账单',
    );
    if (newAcc > 0 || newCat > 0) {
      confirmContent.write('，并将自动新建');
      if (newAcc > 0) confirmContent.write(' $newAcc 个账户');
      if (newCat > 0) {
        confirmContent.write('${newAcc > 0 ? '、' : ' '}$newCat 个分类');
      }
    }
    confirmContent.write('。');
    final bool? confirmed = await showConfirm(
      context,
      title: '确认导入',
      content: confirmContent.toString(),
    );
    if (confirmed != true) return;
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
      // Phase 2 储蓄路由：模块=储蓄 且「转入账户」= 计划名时，建/匹配储蓄目标并
      // 逐期存入台账；账户列 = 扣款账户（可空 = 灵活存入，无联动流水）。
      final SavingsRepository savingsRepo = ref.read(savingsRepositoryProvider);
      // 分期路由（Phase 2）：模块=分期且类型=转账、备注=计划名、转入账户=负债付款
      // 账户时，建/匹配分期计划并逐期生成「分期订单」、还款自动对账标记已还。
      final InstallmentRepository instRepo =
          ref.read(installmentRepositoryProvider);
      // 投资路由（Phase 2）：模块=投资且类型=支出/收入（买入/卖出）、对方=证券代码、
      // 分类=品种类型、备注=名称@单价时，路由到投资持仓台账（买入建/增资持仓 + 支出
      // 流水，卖出减仓 + 收入流水），账户列 = 资金账户（买款来源/卖款去向）。
      final InvestmentRepository investRepo =
          ref.read(investmentRepositoryProvider);
      // 报销路由（Phase 2）：模块=报销且类型=收入、报销账户必填时，建报销收入
      // 流水（账户列=实际收款账户）+ 建待报销记录 + 全额抵扣翻「已报销」+
      // 核销报销账户挂账，维持「报销账户余额 = 待收垫付」不变量（垫付侧在通用路径
      // 对报销账户 +实付挂账）。
      final ReimbursementRepository reimbRepo =
          ref.read(reimbursementRepositoryProvider);
      // 预汇总每个计划（按 账本#计划名）的合计金额，作为新建目标的 targetMinor。
      final Map<String, int> planTotals = <String, int>{};
      for (final BillRow row in _parsed!.rows) {
        if (row.module != SourceModule.savings) continue;
        final String? plan = row.toAccountName?.trim();
        if (plan == null || plan.isEmpty) continue;
        String pid = currentBookId;
        if (row.book != null && row.book!.trim().isNotEmpty) {
          final String? found = bookNameToId[row.book!.trim().toLowerCase()];
          if (found != null) pid = found;
        }
        planTotals['$pid#$plan'] =
            (planTotals['$pid#$plan'] ?? 0) + row.amountMinor;
      }
      final Map<String, String> planGoalId = <String, String>{};
      final Map<String, int> planDayIndex = <String, int>{};
      final Map<String, List<SavingsGoal>> savingsGoalsByBook =
          <String, List<SavingsGoal>>{};

      // 分期预聚合：按「账本#计划名」归集本批分期行（备注=计划名），计算合计金额、
      // 最早日期与行清单（按日期升序用于逐期映射）。建/匹配计划只需一次。
      final Map<String, List<BillRow>> instPlanRows =
          <String, List<BillRow>>{};
      final Map<String, int> instPlanTotals = <String, int>{};
      final Map<String, int> instPlanFirstDue = <String, int>{};
      for (final BillRow row in _parsed!.rows) {
        if (row.module != SourceModule.installment) continue;
        final String plan = (row.note ?? '').trim();
        if (plan.isEmpty) continue;
        String pid = currentBookId;
        if (row.book != null && row.book!.trim().isNotEmpty) {
          final String? found = bookNameToId[row.book!.trim().toLowerCase()];
          if (found != null) pid = found;
        }
        final String key = '$pid#$plan';
        (instPlanRows[key] ??= <BillRow>[]).add(row);
        instPlanTotals[key] = (instPlanTotals[key] ?? 0) + row.amountMinor;
        final int due = row.occurredAt.toUtc().millisecondsSinceEpoch;
        final int cur = instPlanFirstDue[key] ?? due;
        instPlanFirstDue[key] = due < cur ? due : cur;
      }
      for (final List<BillRow> list in instPlanRows.values) {
        list.sort((BillRow a, BillRow b) => a.occurredAt.compareTo(b.occurredAt));
      }
      final Map<String, String> instPlanId = <String, String>{};
      final Set<String> instPlanDone = <String>{};
      // 投资：同 账本#代码#品种 归户到同一持仓（首笔买入建仓并缓存持仓 id）。
      final Map<String, String> investHoldingId = <String, String>{};

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
      // 二级分类缓存：key 带 parentId，避免不同一级下的同名子分类互相串扰。
      final Map<String, String> subCatCache = <String, String>{};

      int imported = 0;
      int skipped = 0;
      final List<String> reasons = <String>[];
      // 本次导入写入的流水 ID 清单（级联删除溯源：删除导入记录时一并软删）。
      final List<String> txnIds = <String>[];

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

          // ── Phase 2 储蓄路由 ──
          // 模块=储蓄 且「转入账户」= 计划名时，建/匹配储蓄目标并逐期存入台账，
          // 联动真实账本「存款」流水（扣除款账户），与 in-app _syncPeriodTxn 同口径。
          if (row.module == SourceModule.savings) {
            await _importSavings(
              row,
              bookId,
              savingsRepo,
              accounts,
              accRepo,
              catRepo,
              txnRepo,
              accCache,
              planTotals,
              planGoalId,
              planDayIndex,
              savingsGoalsByBook,
              txnIds,
            );
            imported++;
            continue;
          }

          // ── Phase 2 分期路由 ──
          // 模块=分期 且类型=转账、备注=计划名、转入账户=负债付款账户时，建/匹配
          // 分期计划（addPlan 末尾自动 postDuePeriods 在负债账户生成「分期订单」），
          // 逐期导入还款转账（relatedId='${period.id}#repay'）并标记已还。整组只处理一次。
          if (row.module == SourceModule.installment) {
            final String plan = (row.note ?? '').trim();
            String pid = currentBookId;
            if (row.book != null && row.book!.trim().isNotEmpty) {
              final String? found = bookNameToId[row.book!.trim().toLowerCase()];
              if (found != null) pid = found;
            }
            final String planKey = '$pid#$plan';
            if (!instPlanDone.contains(planKey)) {
              await _importInstallmentPlan(
                planKey,
                pid,
                instRepo,
                accounts,
                accRepo,
                txnRepo,
                accCache,
                instPlanRows,
                instPlanTotals,
                instPlanFirstDue,
                instPlanId,
                txnIds,
              );
              instPlanDone.add(planKey);
            }
            imported++;
            continue;
          }

          // ── Phase 2 投资路由 ──
          // 模块=投资 且类型=支出/收入（买入/卖出）、对方=证券代码、分类=品种类型、
          // 备注=名称@单价时，路由到投资持仓台账：买入建/增资持仓 + 支出流水，卖出
          // 减仓 + 收入流水；账户列 = 资金账户（买款来源/卖款去向）。同证券同品种
          // 多次买入累加到同一持仓（按 账本#代码#品种 归户）。卖出前该证券须已有买入。
          if (row.module == SourceModule.investment) {
            await _importInvestment(
              row,
              bookId,
              investRepo,
              accounts,
              accRepo,
              accCache,
              investHoldingId,
            );
            imported++;
            continue;
          }

          // ── Phase 2 报销路由 ──
          // 模块=报销 + 收入 + 报销账户：建「报销收入」流水（账户列=实际收款账户，
          // 报销账户写回流水保证导出往返）+ 建待报销记录 + 全额抵扣翻「已报销」
          // （写回收入流水 ID 到抵扣台账，删除收入可逆向恢复）+ 核销报销账户挂账。
          // 与 in-app _saveReimbursementIncome 同口径，维持「余额 = 待收垫付」。
          if (row.module == SourceModule.reimbursement) {
            await _importReimbursement(
              row,
              bookId,
              reimbRepo,
              catRepo,
              accRepo,
              txnRepo,
              accounts,
              accCache,
              txnIds,
            );
            imported++;
            continue;
          }

          // 关联账户（资产）：用户指定时通用路径强制归入该账户；未选择则按
          // 表格「账户」列自动获取（缺失自动创建）。
          final String accountId = _linkedAccountId ??
              await _resolveAccount(
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
          // 「子分类」列结构化：非空时在该一级分类下按名找/建二级分类，
          // categoryId 改指二级（二级带 parentId，报表按 parentId 归集到一级，
          // 二级因此真正参与统计归集）；子分类文本仍落 Transactions.subcategory。
          String? txnCategoryId = categoryId;
          final String subTrim = row.subcategoryName?.trim() ?? '';
          if (categoryId != null && subTrim.isNotEmpty) {
            txnCategoryId = await _resolveSubCategory(
              subTrim,
              row.type,
              categoryId,
              bookId,
              categories,
              catRepo,
              subCatCache,
            );
          }
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

          final String tid = await txnRepo.add(
            bookId: bookId,
            type: row.type,
            amountMinor: row.amountMinor,
            accountId: accountId,
            toAccountId: toAccountId,
            categoryId: txnCategoryId,
            occurredAt: row.occurredAt.toUtc().millisecondsSinceEpoch,
            note: row.note,
            currency: row.currency,
            sourceModule: row.module,
            tags: row.tags.isEmpty ? null : row.tags,
            discountMinor: row.discountMinor,
            feeMinor: row.feeMinor,
            subcategory: row.subcategoryName,
            excludeFromBudget: row.excludeFromBudget,
            excludeFromStats: row.excludeFromStats,
            isReimbursable: row.isReimbursable,
            reimbursementAccountId: reimbursementAccountId,
          );
          txnIds.add(tid);
          imported++;
        } catch (e) {
          skipped++;
          reasons.add('${row.accountName} ${_typeLabel(row.type)} '
              '${Money.fromMinor(row.amountMinor).format()}：$e');
        }
      }

      final String msg = skipped == 0
          ? '成功导入 $imported 笔账单'
          : '导入 $imported 笔，跳过 $skipped 笔';
      // 记录最近一次导入的跳过明细（结果栏「查看问题」复用）。
      _lastSkipped = skipped;
      _lastReasons = List<String>.from(reasons);
      // 写入导入记录：入口页可查看 / 左滑删除级联删除本批账单。
      final ImportRecordRepository importRepo =
          ref.read(importRecordRepositoryProvider);
      await importRepo.insert(ImportRecord(
        id: const Uuid().v7(),
        source: _source.name,
        sourceLabel: _source.label,
        importedCount: imported,
        skippedCount: skipped,
        createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
        failReasons: skipped > 0 ? List<String>.from(reasons) : null,
        txnIds: txnIds.isNotEmpty ? List<String>.from(txnIds) : null,
      )); // ignore: require_trailing_commas
      setState(() => _resultMsg = msg);
      if (mounted) showAppToast(context, msg);
      // reasons 已留存至导入记录，结果栏提供「查看问题」入口。
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

    // 第三方账单卡号账户名（云闪付「银行卡尾号XXXX」、支付宝/微信
    // 「招商银行储蓄卡(1234)」等）：优先按卡号末四位匹配现有账户
    // （账户名含卡号，或账户 cardNumber 末四位一致），避免重复建户。
    final String? last4 = extractCardLast4(name);
    if (last4 != null) {
      final String? matched = matchAccountByCardLast4(last4, accounts);
      if (matched != null) {
        cache[key] = matched;
        return matched;
      }
    }

    for (final Account a in accounts) {
      if (a.name.trim().toLowerCase() == name.trim().toLowerCase()) {
        cache[key] = a.id;
        return a.id;
      }
    }
    // 第三方卡号账户新建时写入卡号，便于日后即使改名也能按卡号匹配；
    // 类型定为银行卡（而非默认 cash）。
    final AccountType effectiveType =
        last4 != null ? AccountType.bankCard : createType;
    final String id = await repo.add(
      bookId: bookId,
      name: name.trim(),
      type: effectiveType,
      cardNumber: last4,
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

  /// 在指定一级分类（[parentId]）下按名解析二级分类，返回二级分类 ID。
  ///
  /// 与 [_resolveCategory] 同构，但匹配/创建都带 parentId：
  /// 命中（同账本同类型同父同名）即复用；未命中则 [CategoryRepository.ensureChild]
  /// 创建二级分类（colorValue=0 继承父配色）。
  Future<String> _resolveSubCategory(
    String name,
    TxnType type,
    String parentId,
    String bookId,
    List<Category> categories,
    CategoryRepository repo,
    Map<String, String> cache,
  ) async {
    final String key = '$bookId|$parentId:${name.trim().toLowerCase()}';
    final String? cached = cache[key];
    if (cached != null) return cached;
    final CategoryType catType = CategoryType.values[type.index];
    for (final Category c in categories) {
      if (c.type == catType &&
          c.parentId == parentId &&
          c.name.trim().toLowerCase() == name.trim().toLowerCase()) {
        cache[key] = c.id;
        return c.id;
      }
    }
    final String id = await repo.ensureChild(
      bookId: bookId,
      parentId: parentId,
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

  /// Phase 2 储蓄路由落库：按 [row.toAccountName]（= 储蓄计划名）建或匹配
  /// [SavingsGoal]，逐期存入台账，并联动真实账本「存款」支出流水。
  ///
  /// - 计划名 = [row.toAccountName]；账户列 = 扣款账户（可空 = 灵活存入，无联动流水）。
  /// - 目标额：新建目标时取本计划在本次导入中的合计（[planTotals]），模式=定额。
  /// - 逐期 dayIndex 按该计划在本批导入中的出现序号 1-based 分配；[updateDeposit]
  ///   幂等（同 dayIndex 已存在则更新金额），保证导出→再导入无损。
  /// - 联动流水：扣款账户非空时建/更新一笔 `sourceModule=savings`、relatedId=
  ///   `goalId#dayIndex` 的「存款」支出流水，与 in-app [_syncPeriodTxn] 同口径。
  Future<void> _importSavings(
    BillRow row,
    String bookId,
    SavingsRepository savingsRepo,
    List<Account> accounts,
    AccountRepository accRepo,
    CategoryRepository catRepo,
    TransactionRepository txnRepo,
    Map<String, String> accCache,
    Map<String, int> planTotals,
    Map<String, String> planGoalId,
    Map<String, int> planDayIndex,
    Map<String, List<SavingsGoal>> savingsGoalsByBook,
    List<String> txnIds,
  ) async {
    final String plan = row.toAccountName!.trim();
    final String cacheKey = '$bookId#$plan';

    // 建/匹配目标（按名称，忽略大小写）。
    String? goalId = planGoalId[cacheKey];
    if (goalId == null) {
      List<SavingsGoal>? goals = savingsGoalsByBook[bookId];
      if (goals == null) {
        goals = await savingsRepo.watch(bookId).first;
        savingsGoalsByBook[bookId] = goals;
      }
      SavingsGoal? existing;
      for (final SavingsGoal g in goals) {
        if (g.name.trim().toLowerCase() == plan.toLowerCase()) {
          existing = g;
          break;
        }
      }
      goalId = existing?.id ??
          await savingsRepo.add(
            bookId: bookId,
            name: plan,
            targetMinor: planTotals[cacheKey] ?? row.amountMinor,
            mode: 'fixed',
          );
      planGoalId[cacheKey] = goalId;
    }

    // 逐期存入：dayIndex 按本计划在本次导入中的出现序号 1-based 分配。
    final int dayIndex = (planDayIndex[cacheKey] ?? 0) + 1;
    planDayIndex[cacheKey] = dayIndex;

    // 落逐期台账（updateDeposit 幂等：已存在同 dayIndex 则更新金额）。
    await savingsRepo.updateDeposit(
      goalId: goalId,
      dayIndex: dayIndex,
      amountMinor: row.amountMinor,
      note: row.note,
    );

    // 联动真实账本流水：扣款账户非空时建/更新一笔「存款」支出流水；
    // 账户为空的灵活存入不生成联动流水（纯台账记录）。
    final String acct = row.accountName.trim();
    if (acct.isNotEmpty) {
      final String sourceAccountId = await _resolveAccount(
        acct,
        bookId,
        accounts,
        accRepo,
        accCache,
      );
      final String savingsCategoryId = await catRepo.ensureNamed(
        bookId: bookId,
        name: '存款',
        type: CategoryType.expense,
        iconKey: 'deposit_in',
        isSystem: true,
      );
      final String relatedId = '$goalId#$dayIndex';
      final String note = '$plan第$dayIndex期';
      final Transaction? existingTxn = await txnRepo.getByRelatedId(relatedId);
      if (existingTxn == null) {
        final String sid = await txnRepo.add(
          bookId: bookId,
          type: TxnType.expense,
          amountMinor: row.amountMinor,
          accountId: sourceAccountId,
          categoryId: savingsCategoryId,
          occurredAt: row.occurredAt.toUtc().millisecondsSinceEpoch,
          note: note,
          sourceModule: SourceModule.savings,
          relatedId: relatedId,
          discountMinor: row.discountMinor,
          feeMinor: row.feeMinor,
          subcategory: row.subcategoryName,
          tags: row.tags.isEmpty ? null : row.tags,
          excludeFromBudget: row.excludeFromBudget,
          excludeFromStats: row.excludeFromStats,
        );
        txnIds.add(sid);
      } else {
        await txnRepo.updateTransaction(
          original: existingTxn,
          type: TxnType.expense,
          amountMinor: row.amountMinor,
          accountId: sourceAccountId,
          categoryId: savingsCategoryId,
          note: note,
          occurredAt: row.occurredAt.toUtc().millisecondsSinceEpoch,
          sourceModule: SourceModule.savings,
          discountMinor: row.discountMinor,
          feeMinor: row.feeMinor,
          subcategory: row.subcategoryName,
          tags: row.tags.isEmpty ? null : row.tags,
          excludeFromBudget: row.excludeFromBudget,
          excludeFromStats: row.excludeFromStats,
        );
      }
    }
  }

  /// Phase 2 分期路由落库：按 [planKey]（账本#计划名）建或匹配 [InstallmentPlan]，
  /// 逐期导入还款转账并标记已还。
  ///
  /// - 计划名 = [BillRow.note]；转入账户 = 负债付款账户（缺失则建为负债类
  ///   [AccountType.otherDebt]，保证 [InstallmentRepository.postDuePeriods] 与
  ///   reconcile 都能正确在负债账户内记账）。账户列 = 扣款账户。
  /// - [addPlan] 末尾自动 [postDuePeriods]：到期期次在负债账户生成「分期订单」支出
  ///   流水（relatedId=period.id、sourceModule=installment）；随后逐行导入还款转账
  ///   （账户→负债账户、type=transfer、sourceModule=installment、
  ///   relatedId='${period.id}#repay'）并 [togglePeriodPaid] 标记已还（幂等）。
  /// - 行清单按日期升序，与期次 periodIndex 升序一一对应；重复导入（已存在还款转账
  ///   或已标记）自动跳过，保证导出→再导入无损往返。
  Future<void> _importInstallmentPlan(
    String planKey,
    String bookId,
    InstallmentRepository instRepo,
    List<Account> accounts,
    AccountRepository accRepo,
    TransactionRepository txnRepo,
    Map<String, String> accCache,
    Map<String, List<BillRow>> instPlanRows,
    Map<String, int> instPlanTotals,
    Map<String, int> instPlanFirstDue,
    Map<String, String> instPlanId,
    List<String> txnIds,
  ) async {
    final List<BillRow> rows = instPlanRows[planKey]!;
    final String planName = (rows.first.note ?? '').trim();
    final String liabilityName = (rows.first.toAccountName ?? '').trim();
    if (liabilityName.isEmpty) {
      throw Exception('分期行缺少转入账户（负债付款账户）');
    }
    // 负债付款账户：缺失时建为负债类，确保 postDuePeriods 能在负债账户内记账。
    final String liabilityAccountId = await _resolveAccount(
      liabilityName,
      bookId,
      accounts,
      accRepo,
      accCache,
      createType: AccountType.otherDebt,
    );

    // 建/匹配计划（按标题忽略大小写）。全批仅一次。
    String? planId = instPlanId[planKey];
    if (planId == null) {
      final List<InstallmentPlan> existing =
          await instRepo.watchPlans(bookId).first;
      InstallmentPlan? matched;
      for (final InstallmentPlan p in existing) {
        if (p.title.trim().toLowerCase() == planName.toLowerCase()) {
          matched = p;
          break;
        }
      }
      planId = matched?.id ??
          await instRepo.addPlan(
            bookId: bookId,
            title: planName,
            totalMinor: instPlanTotals[planKey]!,
            totalPeriods: rows.length,
            firstDueAt: instPlanFirstDue[planKey]!,
            accountId: liabilityAccountId,
          );
      instPlanId[planKey] = planId;
    }

    // 逐期导入还款转账 + 标记已还（幂等）。期次按 periodIndex 升序，与按日期升序的
    // 行清单一一对应。
    final List<InstallmentPeriod> periods =
        await instRepo.watchPeriods(planId).first;
    for (int i = 0; i < rows.length && i < periods.length; i++) {
      final BillRow r = rows[i];
      final InstallmentPeriod period = periods[i];
      final String sourceAccountId = await _resolveAccount(
        r.accountName,
        bookId,
        accounts,
        accRepo,
        accCache,
      );
      final String relatedId = '${period.id}#repay';
      final Transaction? existingRepay = await txnRepo.getByRelatedId(relatedId);
      if (existingRepay == null) {
        final String rid = await txnRepo.add(
          bookId: bookId,
          type: TxnType.transfer,
          amountMinor: r.amountMinor,
          accountId: sourceAccountId,
          toAccountId: liabilityAccountId,
          categoryId: null,
          occurredAt: r.occurredAt.toUtc().millisecondsSinceEpoch,
          note: '$planName第${i + 1}期还款',
          currency: r.currency,
          sourceModule: SourceModule.installment,
          relatedId: relatedId,
          tags: r.tags.isEmpty ? null : r.tags,
          discountMinor: r.discountMinor,
          excludeFromBudget: r.excludeFromBudget,
          excludeFromStats: r.excludeFromStats,
        );
        txnIds.add(rid);
      }
      await instRepo.togglePeriodPaid(period.id, paid: true);
    }
  }

  /// Phase 2 投资路由落库：把一笔投资行路由到 [InvestmentRepository] 的买入/卖出。
  ///
  /// - 类型=支出 → 买入（[InvestmentRepository.recordBuy]）：建或增资持仓 + 支出流水
  ///   （账户扣款 = 金额 + 费，不计收支/预算）；类型=收入 → 卖出
  ///   （[InvestmentRepository.recordSell]）：减仓 + 收入流水（到账 = 金额 − 费）。
  /// - 对方 = 证券代码；分类 = 品种类型（缺省按代码兜底）；备注 = 名称@单价（单价推算份额）。
  /// - 同 账本#代码#品种 归户到同一持仓：首笔买入建仓并缓存持仓 id，后续买/卖复用。
  /// - 卖出前该证券须已有买入（持仓 id 已缓存），否则报错计入 skipped。
  /// 校验（账户/代码/名称/单价/类型）已由 [checkRows] 把关；此处直接调用仓储，任何异常
  /// 冒泡到外层 try 计入 skipped。
  Future<void> _importInvestment(
    BillRow row,
    String bookId,
    InvestmentRepository investRepo,
    List<Account> accounts,
    AccountRepository accRepo,
    Map<String, String> accCache,
    Map<String, String> holdingIdByKey,
  ) async {
    final String symbol = (row.counterparty ?? '').trim();
    final (String name, int? priceMinor, String? userNote) =
        parseInvestmentNote(row.note);
    if (priceMinor == null || priceMinor <= 0) {
      throw Exception('投资行缺少有效单价（备注格式 名称@单价）');
    }
    final InvestmentType type =
        resolveInvestmentType(row.categoryName, symbol);
    final bool isBuy = row.type == TxnType.expense;
    final String accountId = await _resolveAccount(
      row.accountName,
      bookId,
      accounts,
      accRepo,
      accCache,
    );
    final int occurredAt = row.occurredAt.toUtc().millisecondsSinceEpoch;
    final String key = '$bookId#${symbol.toUpperCase()}#${type.index}';
    if (isBuy) {
      final String hid = await investRepo.recordBuy(
        bookId: bookId,
        holdingId: holdingIdByKey[key],
        symbol: symbol,
        name: name,
        type: type,
        amountMinor: row.amountMinor,
        priceMinor: priceMinor,
        feeMinor: row.feeMinor,
        accountId: accountId,
        note: userNote,
        occurredAt: occurredAt,
      );
      holdingIdByKey[key] = hid;
    } else {
      final String? hid = holdingIdByKey[key];
      if (hid == null) {
        throw Exception('卖出前需先导入证券「$symbol」的买入');
      }
      await investRepo.recordSell(
        bookId: bookId,
        holdingId: hid,
        amountMinor: row.amountMinor,
        priceMinor: priceMinor,
        feeMinor: row.feeMinor,
        accountId: accountId,
        note: userNote,
        occurredAt: occurredAt,
      );
    }
  }

  /// Phase 2 报销路由落库：把一笔「报销到账」行路由到报销台账。
  ///
  /// - 账户列 = 实际收款账户（缺省按报销账户自身兜底），报销账户写回收入流水
  ///   [reimbursementAccountId] 保证导出 → 再导入还原 module=报销 + 报销账户；
  ///   类目固定「报销收入」（无则自动创建）、恒不计入预算。
  /// - 建一条待报销记录（独立到账、无关联垫付流水）+ 全额抵扣翻「已报销」（写回
  ///   收入流水 ID 到抵扣台账），与 in-app 抵扣链路同口径——删除收入流水时
  ///   按台账反向恢复，保证可逆。
  /// - 核销报销账户垫付挂账（writeOffReceivable），维持「报销账户余额 = 待收垫付」
  ///   不变量（垫付侧已在通用路径对报销账户 +实付挂账）。仅当收款账户与报销账户
  ///   不同才核销：否则收入已进报销账户、再核销会重复扣减致余额失真。
  /// 校验（类型=收入 / 报销账户必填）已由 [checkRows] 把关；此处直接调用仓储，任何
  /// 异常冒泡到外层 try 计入 skipped。
  Future<void> _importReimbursement(
    BillRow row,
    String bookId,
    ReimbursementRepository reimbRepo,
    CategoryRepository catRepo,
    AccountRepository accRepo,
    TransactionRepository txnRepo,
    List<Account> accounts,
    Map<String, String> accCache,
    List<String> txnIds,
  ) async {
    final int occurredAt = row.occurredAt.toUtc().millisecondsSinceEpoch;
    // 报销账户：必须指定（checkRows 已把关）；缺失按名建为报销类账户。
    final String reimbAccountId = await _resolveAccount(
      row.reimbursementAccount!,
      bookId,
      accounts,
      accRepo,
      accCache,
      createType: AccountType.reimbursement,
    );
    // 收款账户：账户列解析；缺省按报销账户自身兜底（此时不单独核销，见下方）。
    final String receiveAccountId = row.accountName.trim().isEmpty
        ? reimbAccountId
        : await _resolveAccount(
            row.accountName,
            bookId,
            accounts,
            accRepo,
            accCache,
          );

    // 1. 资金落账：报销收入进收款账户（导出往返时 module=报销 + 报销账户还原）。
    final String reimbCategoryId = await catRepo.ensureNamed(
      bookId: bookId,
      name: '报销收入',
      type: CategoryType.income,
      iconKey: 'reimburse_income',
      colorValue: 0xFF45936A,
      isSystem: true,
    );
    final String incomeTxnId = await txnRepo.add(
      bookId: bookId,
      type: TxnType.income,
      amountMinor: row.amountMinor,
      accountId: receiveAccountId,
      categoryId: reimbCategoryId,
      occurredAt: occurredAt,
      note: row.note?.isNotEmpty == true ? row.note : '报销到账',
      currency: row.currency,
      sourceModule: SourceModule.reimbursement,
      excludeFromBudget: true,
      excludeFromStats: row.excludeFromStats,
      reimbursementAccountId: reimbAccountId,
      tags: row.tags.isEmpty ? null : row.tags,
      discountMinor: row.discountMinor,
      feeMinor: row.feeMinor,
      subcategory: row.subcategoryName,
    );
    txnIds.add(incomeTxnId);

    // 2. 建待报销记录（独立到账，无关联垫付流水）→ 全额抵扣翻「已报销」。
    final String recordId = await reimbRepo.add(
      bookId: bookId,
      title: row.note?.isNotEmpty == true ? row.note! : '报销到账',
      status: ReimbursementStatus.pending,
      amountMinor: row.amountMinor,
      payer: '本人',
      occurredAt: occurredAt,
      accountId: reimbAccountId,
      note: row.note,
      excludeFromStats: row.excludeFromStats,
    );

    // 3. 全额抵扣并写回收入流水 ID（删除收入时按台账反向恢复，保证可逆）。
    await reimbRepo.deduct(
      recordId,
      row.amountMinor,
      incomeTransactionId: incomeTxnId,
    );

    // 4. 核销报销账户垫付挂账（余额 = 待收垫付，归零）。仅当收款账户与报销账户
    //    不同时才核销——否则收入已进报销账户、再核销会重复扣减导致余额失真。
    if (receiveAccountId != reimbAccountId) {
      await reimbRepo.writeOffReceivable(reimbAccountId, row.amountMinor);
    }
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
                const _ImportHeaderCard(),
                const SizedBox(height: AppDimens.sm),
                _configInfoCard(),
                const SizedBox(height: AppDimens.sm),
                _sectionCard(
                  label: '数据',
                  children: <Widget>[
                    _configRow(
                      title: '导入账单',
                      subtitle: '选择文件开始导入',
                      onTap: _pickFile,
                    ),
                    const Divider(
                      height: 1,
                      indent: 16,
                      color: AppPalette.divider,
                    ),
                    _configRow(
                      title: '导入来源',
                      subtitle: '${_source.label}（来自哪个APP）',
                      onTap: _pickSource,
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.sm),
                _sectionCard(
                  label: '其他',
                  children: <Widget>[
                    _configRow(
                      title: '关联账户(资产)',
                      subtitle: _linkedAccountName.isEmpty
                          ? '选择导入资产(未选择将从表格会自动获取)'
                          : _linkedAccountName,
                      onTap: _pickLinkedAccount,
                    ),
                  ],
                ),
                if (_parsed != null) ..._previewSection(),
              ],
            ),
          ),
          if (_parsed != null && _parsed!.rows.isNotEmpty) _importBar(),
        ],
      ),
    );
  }

  /// 信息卡（对标小青账）：说明文案 + 右下「模板」胶囊（下载空白填写模板）。
  Widget _configInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.softGreen,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      padding: const EdgeInsets.all(AppDimens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '系统差异可能导致导入账单需手动调整，请勿过度依赖此功能。仔细核对、'
            '分析账单，正是记账本身的乐趣与意义所在。\n'
            '与其耗费时间转换旧账目，不如放下历史记录，轻装上阵，即刻开始全新'
            '的记账体验！\n'
            '需导入本 App 导出的 CSV / JSON、空白模板，或支付宝 / 微信 / '
            '云闪付导出的账单 CSV（编码自动识别）；解析后按分类 / 时间 / '
            '账户自动匹配校验并给出核对归集报告。',
            style: TextStyle(
              fontSize: 12.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppDimens.sm),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: _downloadTemplate,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppPalette.ctaGreen,
                side: const BorderSide(color: AppPalette.ctaGreen),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusChip),
                ),
                minimumSize: Size.zero,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('模板', style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  /// 配置分组卡（对标小青账「数据 / 其他」）：鼠尾草竖条标题 + 行列表。
  Widget _sectionCard({
    required String label,
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
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  /// 配置行（标题 + 副标题 + 右箭头），对标小青账配置项。
  Widget _configRow({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const LineGlyph(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }

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
    if (_importing) {
      return _ImportGradientCta(label: '开始导入', onTap: () {}, busy: true);
    }
    if (_resultMsg != null) {
      // 导入完成：展示结果文案；存在被跳过 / 失败的笔数时提供「查看问题」入口。
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.lg,
          0,
          AppDimens.lg,
          AppDimens.md,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _resultMsg!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            if (_lastSkipped > 0)
              TextButton(
                onPressed: () => _showProblemSheet(context),
                child: const Text('查看问题'),
              ),
          ],
        ),
      );
    }
    return _ImportGradientCta(label: '开始导入', onTap: _import, busy: false);
  }

  /// 弹出导入问题明细（被跳过 / 失败的逐行原因），供用户核对修正后重新导入。
  void _showProblemSheet(BuildContext context) {
    showAppModalSheet<void>(
      context,
      title: '导入问题明细',
      body: _lastReasons.isEmpty
          ? const EmptyState(
              message: '没有发现问题',
              iconWidget: LineIcon(
                LineIconKind.checkCircle,
                size: 48,
                color: AppPalette.ctaGreen,
              ),
            )
          : ListView(
              shrinkWrap: true,
              children: <Widget>[
                for (final String r in _lastReasons)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      '· $r',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// 头部卡（入口页 / 配置页共用，对标小青账）：灰底云上传图标 + 标题。
class _ImportHeaderCard extends StatelessWidget {
  const _ImportHeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      padding: const EdgeInsets.all(AppDimens.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppPalette.graySurface,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: const Center(
              child: LineIcon(
                LineIconKind.cloudUp,
                size: 24,
                color: AppPalette.sageRibbon,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Text(
              '账单导入',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 底部渐变主按钮（入口页「导入账单」/ 配置页「开始导入」共用），自带外边距。
class _ImportGradientCta extends StatelessWidget {
  const _ImportGradientCta({
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
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
              onTap: busy ? null : onTap,
              child: Center(
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppPalette.white,
                        ),
                      )
                    : Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15,
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
}
