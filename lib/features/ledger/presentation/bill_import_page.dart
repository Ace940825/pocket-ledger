import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// 仅取查询构建所需符号：全量 import 会与 material 的 Column 冲突。
// BaseAggregate 提供 count()，BooleanExpressionOperators 提供 Expression<bool> 的 & 运算。
import 'package:drift/drift.dart'
    show
        BaseAggregate,
        BooleanExpressionOperators,
        Expression,
        QueryRow,
        TypedResult;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:pocket_ledger/theme/app_dimens.dart';
import 'package:uuid/uuid.dart';
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
import '../data/account_io.dart';
import '../data/bill_import_sources.dart';
import '../data/bill_io.dart';
import '../data/bill_template.dart';
import '../data/import_record_repository.dart';
import '../data/transaction_repository.dart';
import '../providers/ledger_providers.dart';
import 'bill_import_preview_page.dart';
import 'widgets/import_conflict_dialog.dart';
import 'widgets/txn_slidable.dart';

/// 「账单管理 → 账单导入」入口页（对标小青账，2026-10-20）：头部卡（云上传
/// 图标 + 标题）→ 信息条 → 空态 → 底部渐变按钮「导入账单」进入配置页。
/// 配置页 [BillImportConfigPage]（点击「导入账单」后）：数据（导入账单 /
/// 导入来源）+ 其他（关联账户资产）+ 底部常显「开始导入」→ 跳转预览页
/// [BillImportPreviewPage]（总览 + 提示 + 账单列表 + 确认导入账单）。
/// 确认后回本页执行真实导入——账户 / 分类按名称归户，缺失项自动创建
/// （账户默认现金类）。
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
        title: const Text('数据导入'),
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
                        iconWidget: const LineIcon(
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
            label: '导入数据',
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
        '系统差异可能导致导入数据需手动调整，请勿过度依赖此功能。仔细核对、'
        '分析账单，正是记账本身的乐趣与意义所在。\n'
        '与其耗费时间转换旧账目，不如放下历史记录，轻装上阵，即刻开始全新的'
        '记账体验！',
        style: TextStyle(
          fontSize: 12.5,
          color: context.forest.onSurfaceVariant,
          height: 1.5,
        ),
      ),
    );
  }

  /// 入口页空态（无导入记录时）。
  Widget _emptyRecords() {
    return const Padding(
      padding: EdgeInsets.only(top: AppDimens.lg),
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
    final String time = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
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
                          color: context.forest.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$time · 导入 ${record.importedCount} 笔'
                        '${record.skippedCount > 0 ? ' · 跳过 ${record.skippedCount} 笔' : ''}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.forest.onSurfaceVariant,
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
            ref.read(accountRepositoryProvider),
            ref.read(lendRepositoryProvider),
            ref.read(investmentRepositoryProvider),
            ref.read(reimbursementRepositoryProvider),
            ref.read(savingsRepositoryProvider),
            ref.read(installmentRepositoryProvider),
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
                    color: context.forest.onSurfaceVariant,
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
                color: context.forest.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.forest.onSurface,
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
/// 数据（导入账单 / 导入来源）+ 其他（关联账户资产）+ 底部常显「开始导入」
/// （点击跳转 [BillImportPreviewPage] 预览页）。
class BillImportConfigPage extends ConsumerStatefulWidget {
  const BillImportConfigPage({super.key, this.initialDraft});

  /// 从截图识别等外部来源直接进入确认页时传入已解析结果，
  /// 跳过文件读取输入区，点「开始导入」直达预览页。
  final ParseResult? initialDraft;

  @override
  ConsumerState<BillImportConfigPage> createState() =>
      _BillImportConfigPageState();
}

class _BillImportConfigPageState extends ConsumerState<BillImportConfigPage> {
  /// 已读取的文件文本内容（无粘贴框，仅文件通道；CSV / JSON 由解析器自动识别）。
  String _rawContent = '';

  /// 已选择的文件名（用于配置行副标题回显）；未选择时为 null。
  String? _fileName;

  ParseResult? _parsed;

  /// 模板系统（2026-10-18）：解析成功后的匹配校验与三维归集报告。
  TemplateCheckResult? _check;
  bool _importing = false;
  String? _resultMsg;

  /// 最近一次导入的「跳过 / 失败」笔数与原因清单（供结果栏「查看问题」复用）。
  int _lastSkipped = 0;
  List<String> _lastReasons = <String>[];

  /// 大批量导入进度（2026-10-22 移植自 fresh 优化版）：总行数 / 已完成行数。
  /// 导入期间在底部 CTA 上方展示确定性进度条与计数，替代原先"一直转圈、
  /// 不知死活"的观感。事务结构沿用本工程已有的「整批原子」实现（根因 #4），
  /// 此处只补进度反馈：每 500 行让出一次事件循环并刷新。
  int _progressTotal = 0;
  int _progressDone = 0;

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
    // 提取文件名（去掉路径），用于配置行副标题回显。
    final String fileName = filePath.split(Platform.pathSeparator).last;
    // 字节级解码：UTF-8 优先，失败回退 GBK（支付宝 / 云闪付导出）。
    _rawContent = decodeBillFileBytes(await File(filePath).readAsBytes());
    if (mounted) {
      setState(() => _fileName = fileName);
    }
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
    if (mounted && _parsed != null) {
      // 根据识别结果给不同提示
      final int rowCount = _parsed!.rows.length;
      final int accountCount = _parsed!.accounts.length;
      String msg;
      if (rowCount == 0 && accountCount == 0) {
        msg = '未识别到有效内容，请检查文件格式';
      } else if (rowCount > 0 && accountCount == 0) {
        msg = '已解析 $rowCount 条账单，点击「开始导入」预览';
      } else if (rowCount == 0 && accountCount > 0) {
        msg = '已识别 $accountCount 个账户，点击「开始导入」预览（仅账户）';
      } else {
        msg = '已解析 $rowCount 条账单、$accountCount 个账户，点击「开始导入」预览';
      }
      showAppToast(context, msg);
    }
  }

  Future<void> _parse() async {
    final ParseResult parsed = parseSource(_source, _rawContent);
    TemplateCheckResult? check;
    // 纯账户文件（0 账单行）同样需要校验报告：预览页的「账户段复原：
    // 新建 / 覆盖 N 个」与重名阻断提示全部来自 checkRows 的账户段归集。
    if (parsed.rows.isNotEmpty || parsed.accounts.isNotEmpty) {
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
        accounts: parsed.accounts,
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
                      color: context.forest.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.forest.onSurfaceVariant,
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

  /// 下载空白填写模板（提供账单模板和账户模板两个选择）。
  Future<void> _downloadTemplate(String type) async {
    String content;
    String fileName;
    if (type == 'account') {
      // 账户模板
      content = buildAccountTemplate();
      fileName = '账户导入模板.csv';
    } else {
      // 账单模板
      content = buildSourceTemplate(_source);
      fileName = '账单导入模板.csv';
    }

    const String ext = 'csv';
    // file_picker 8.x：Android/iOS 的 saveFile 必须直接传 bytes（由系统
    // 面板落盘，返回保存路径）；桌面端才返回所选路径、需自行写文件。
    final bool isMobile = Platform.isAndroid || Platform.isIOS;
    final String? picked = await FilePicker.platform.saveFile(
      dialogTitle: '保存导入模板',
      fileName: fileName,
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

  /// 底部「开始导入」：跳转预览页（对标小青账），确认后回本页执行真实导入。
  Future<void> _startImport() async {
    if (_importing) return;
    // 双段文件：账单行或账户段任一非空即可导入（纯账户文件修复，见
    // [hasImportableContent]）——旧门禁只看 rows，纯账户文件被误拒。
    if (_parsed == null || !hasImportableContent(_parsed!)) {
      showAppToast(context, '请先选择账单文件');
      return;
    }
    final bool? confirmed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => BillImportPreviewPage(parsed: _parsed!, check: _check),
      ),
    );
    if (confirmed != true || !mounted) return;
    // 数据库中已有数据 → 冲突处理三选一（2026-10-22：合并 / 覆盖 / 取消）。
    // 纯账户导入（无账单行）不碰任何流水：跳过冲突对话框——其文案围绕
    // 「删除流水」，对账户导入既误导、误选覆盖更会白删用户流水。
    final String bookId = ref.read(currentBookIdProvider);
    final int existing =
        _parsed!.rows.isEmpty ? 0 : await _countBookTxns(bookId);
    if (!mounted) return;
    ImportConflictMode mode = ImportConflictMode.merge;
    if (existing > 0) {
      final ImportConflictMode? picked = await showImportConflictDialog(
        context,
        existingCount: existing,
        incomingCount: _parsed!.rows.length,
      );
      if (picked == null || !mounted) return;
      if (picked == ImportConflictMode.overwrite) {
        // 覆盖不可恢复：二次危险确认，文案带具体笔数。
        final bool? dangerOk = await showConfirm(
          context,
          title: '覆盖原有数据',
          content: '将删除当前账本全部 $existing 笔流水（不可恢复），'
              '随后导入 ${_parsed!.rows.length} 笔新账单。',
          confirmText: '删除并导入',
          danger: true,
        );
        if (dangerOk != true || !mounted) return;
      }
      mode = picked;
    }
    await _import(mode: mode, existingCount: existing);
  }

  /// 当前账本未删除流水笔数（导入冲突检测用，2026-10-22）。
  Future<int> _countBookTxns(String bookId) async {
    final AppDatabase db = ref.read(appDatabaseProvider);
    final Expression<int> cnt = db.transactions.id.count();
    final TypedResult? row = await (db.selectOnly(db.transactions)
          ..addColumns(<Expression<Object>>[cnt])
          ..where(
            db.transactions.bookId.equals(bookId) &
                db.transactions.deleted.equals(false),
          ))
        .getSingleOrNull();
    return row?.read(cnt) ?? 0;
  }

  /// 执行真实导入。调用前必经 [BillImportPreviewPage] 预览页「确认导入账单」
  /// ——预览页即写入前确认环节（2026-10-20 起，替代原 showConfirm 弹窗）。
  Future<void> _import({
    ImportConflictMode mode = ImportConflictMode.merge,
    int existingCount = 0,
  }) async {
    if (_importing || _parsed == null || !hasImportableContent(_parsed!)) {
      return;
    }
    setState(() {
      _importing = true;
      // 覆盖模式的进度基数含「先删除的旧流水量」，删除与导入共用一个进度条。
      // 账户段复原也计入总量：纯账户文件（0 账单）同样有完整进度反馈。
      _progressTotal =
          _parsed!.rows.length + existingCount + _parsed!.accounts.length;
      _progressDone = 0;
    });
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
      final Map<String, List<BillRow>> instPlanRows = <String, List<BillRow>>{};
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
        list.sort(
          (BillRow a, BillRow b) => a.occurredAt.compareTo(b.occurredAt),
        );
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

      final AppDatabase db = ref.read(appDatabaseProvider);
      int imported = 0;
      int skipped = 0;
      int accCreated = 0;
      int accUpdated = 0;
      // 导入收尾要把余额校正为文件值的账户（id + 文件余额 + 类型）。
      // 只收本次真正写过的户（新建、或覆盖模式下被覆盖的户）。
      final List<({String id, AccountType type, int balanceMinor})>
          balanceFixups = <({String id, AccountType type, int balanceMinor})>[];
      final List<String> reasons = <String>[];
      // 本次导入写入的流水 ID 清单（级联删除溯源：删除导入记录时一并软删）。
      final List<String> txnIds = <String>[];

      // 整批原子导入（根因 #4）：所有写入（流水 / 借还 / 储蓄 / 分期 / 投资 /
      // 报销台账 + 同步入队 + 导入记录）包进同一个 DB 事务。逐行「数据校验
      // 不通过」仍由内层 try/catch 跳过并计入 skipped；但任何未预期的崩溃
      // （内容过多 / OOM / DB 错误 / 导入记录写入失败）会令整批回滚——含已
      // 落库的流水与已入队的 pending_ops，杜绝「导入失败却仍累计同步数 /
      // 脏数据叠加」。内层各仓库的 _db.transaction 退化为 savepoint，随外层
      // 一并提交或回滚。
      await db.transaction<void>(() async {
        // 级联删除溯源：事务前后差集 = 本次导入新建对象（账户 / 流水 / 借还 /
        // 投资 / 报销 / 储蓄 / 分期台账）。用差集而非逐个路由收集，能把借还 /
        // 投资 / 分期「订单」等各路由产生的、未显式计入 txnIds 的流水一次网全，
        // 删导入记录时清干净、不残留。快照取全部行 ID（不按 deleted 过滤），
        // 覆盖模式先软删的旧流水 ID 前后都在集合里、不会误入差集。
        Future<Set<String>> snapIds(String table) async {
          final List<QueryRow> rows =
              await db.customSelect('SELECT id FROM $table').get();
          return rows.map((QueryRow r) => r.read<String>('id')).toSet();
        }

        final Set<String> preAccounts = await snapIds('accounts');
        final Set<String> preTxns = await snapIds('transactions');
        final Set<String> preLends = await snapIds('lend_records');
        final Set<String> preInvests = await snapIds('investment_holdings');
        final Set<String> preReimbs = await snapIds('reimbursements');
        final Set<String> preSavings = await snapIds('savings_goals');
        final Set<String> preInstPlans = await snapIds('installment_plans');
        // ── 覆盖模式：先清空当前账本全部流水（2026-10-22 导入冲突处理）──
        // 不走 deleteCascade：getById 不过滤已软删行，对已删流水再 remove
        // 会重复回退余额。改为「按 bookId 批量软删流水（removeBatch 内部
        // 自理余额回退 / 同步入队 / 报销级联），再删有交集的导入记录行」。
        // 导入记录无 bookId 字段，按 txnIds 与清空集合求交集判断归属，
        // 避免误删其他账本的导入记录。删除与导入在同一外层事务内，整体原子。
        if (mode == ImportConflictMode.overwrite) {
          final List<Transaction> stale = await (db.select(db.transactions)
                ..where(
                  (t) =>
                      t.bookId.equals(currentBookId) & t.deleted.equals(false),
                ))
              .get();
          final List<String> staleIds =
              stale.map((Transaction t) => t.id).toList();
          final Set<String> staleIdSet = staleIds.toSet();
          const int kClearChunk = 500;
          for (int start = 0; start < staleIds.length; start += kClearChunk) {
            final int end = start + kClearChunk < staleIds.length
                ? start + kClearChunk
                : staleIds.length;
            await txnRepo.removeBatch(staleIds.sublist(start, end));
            if (mounted) setState(() => _progressDone = end);
            await Future.delayed(Duration.zero);
          }
          if (staleIdSet.isNotEmpty) {
            final ImportRecordRepository clearImportRepo =
                ref.read(importRecordRepositoryProvider);
            for (final ImportRecord r in await clearImportRepo.getAll()) {
              final bool touched = r.txnIds?.any(staleIdSet.contains) ?? false;
              if (touched) await clearImportRepo.deleteRow(r.id);
            }
          }
        }
        // ── 账户段复原（v3，见 account_io.dart）────────────────────────
        // 顺序很关键：账户**先**于流水落库——行处理里的 _resolveAccount 按名
        // 归户时就能命中已复原的账户（含隐藏 / 封存户），不会再建「裸账户」
        // （只有名字、没有类型 / 额度 / 图标等元数据）。
        // 余额此时先写文件值，等流水全部落完后在收尾统一校正（setRestoredBalance），
        // 避免逐笔流水把余额改飞。
        // merge（合并原有数据）：只建段内缺失的户，已存在的户一律不动；
        // overwrite（覆盖原有数据）：已存在的户按段内全量字段覆盖。
        final List<AccountRow> accRows = _parsed!.accounts;
        for (int i = 0; i < accRows.length; i++) {
          final AccountRow acc = accRows[i];
          String bookId = currentBookId;
          final String? accBook = acc.book?.trim();
          if (accBook != null && accBook.isNotEmpty) {
            final String? found = bookNameToId[accBook.toLowerCase()];
            if (found != null) {
              bookId = found;
            }
            // 未知账本：归当前账本（checkRows 已提示，此处不重复报）。
          }
          // 不走 accountsOf()：它缓存的是 watchByBook（排除隐藏 / 封存户），
          // 且会在缓存里留下复原前的旧快照。这里直接查全量（含隐藏 / 封存）。
          final List<Account> existing = await (db.select(db.accounts)
                ..where(
                  (t) => t.bookId.equals(bookId) & t.deleted.equals(false),
                ))
              .get();
          Account? hit;
          for (final Account a in existing) {
            if (a.name.trim().toLowerCase() == acc.name.trim().toLowerCase()) {
              hit = a;
              break;
            }
          }
          final bool overwriteThis =
              mode == ImportConflictMode.overwrite && hit != null;
          if (hit != null && !overwriteThis) continue; // 合并：已存在不动
          final String id = await accRepo.restoreAccount(
            bookId: bookId,
            name: acc.name,
            type: acc.type,
            balanceMinor: acc.balanceMinor,
            currency: acc.currency,
            iconKey: acc.iconKey,
            colorValue: acc.colorValue,
            creditLimitMinor: acc.creditLimitMinor,
            billingDay: acc.billingDay,
            dueDay: acc.dueDay,
            dueGraceDays: acc.dueGraceDays,
            note: acc.note,
            cardNumber: acc.cardNumber,
            status: acc.status,
            includeInTotal: acc.includeInTotal,
            sortOrder: acc.sortOrder,
            existingId: hit?.id,
            overwrite: overwriteThis,
          );
          if (hit == null) {
            accCreated++;
          } else {
            accUpdated++;
          }
          // 账户段进度：每复原一个账户推进一步（纯账户文件的进度反馈全靠它）。
          if (mounted) {
            setState(
              () =>
                  _progressDone = _parsed!.rows.length + existingCount + i + 1,
            );
          }
          balanceFixups.add(
            (
              id: id,
              type: acc.type,
              balanceMinor: acc.balanceMinor,
            ),
          );
          // 预填名称 → ID 缓存：行处理的 _resolveAccount / _resolveDesignatedAccount
          // 优先命中缓存，隐藏 / 封存户（不在 watchByBook 列表里）也能归户到
          // 刚复原的账户，不会重复建户。
          final String key = '$bookId|${acc.name.trim().toLowerCase()}';
          accCache[key] = id;
          if (acc.type == AccountType.lend || acc.type == AccountType.borrow) {
            accCache['designated|$bookId|${acc.type.index}|'
                '${acc.name.trim().toLowerCase()}'] = id;
          }
        }

        // 大批量导入进度（2026-10-22）：每 kImportChunk 行让出一次事件循环
        // 并刷新进度条；写入语义不变，仍在同一事务内（chunk 之间不提交）。
        // 行序修正（2026-10-22 真机反馈）：导出 occurredAt 倒序导致「收债/
        // 还债」排在「借出/借入」之前，冲销时债务未落库报「未找到未结清
        // 债务」；借入/借出 add 行稳定前置，其余行保持原相对顺序。
        final List<BillRow> allRows = reorderLendRowsForImport(_parsed!.rows);
        const int kImportChunk = 500;
        for (int start = 0; start < allRows.length; start += kImportChunk) {
          final int end = start + kImportChunk < allRows.length
              ? start + kImportChunk
              : allRows.length;
          for (int i = start; i < end; i++) {
            final BillRow row = allRows[i];
            try {
              // 解析目标账本：指定且存在则用之，否则归入当前账本。
              String bookId = currentBookId;
              if (row.book != null && row.book!.trim().isNotEmpty) {
                final String? found =
                    bookNameToId[row.book!.trim().toLowerCase()];
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
                  final String? found =
                      bookNameToId[row.book!.trim().toLowerCase()];
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
                source: '导入',
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
                // 位置信息（可选列）：随导入落库恢复定位显示。
                placeName: row.placeName,
                latitude: row.latitude,
                longitude: row.longitude,
              );
              txnIds.add(tid);
              imported++;
            } catch (e) {
              skipped++;
              reasons.add('${row.accountName} ${_typeLabel(row.type)} '
                  '${Money.fromMinor(row.amountMinor).format()}：$e');
            }
          }
          // 每批让出事件循环并刷新进度：进度条 / 动画有机会渲染，长导入
          // 不再像卡死（导入逻辑本身不受影响，仍在同一事务内）。覆盖模式下
          // 基数含已删除的旧流水量，进度条跨「删除 + 导入」两段连续。
          if (mounted) setState(() => _progressDone = existingCount + end);
          await Future.delayed(Duration.zero);
        }

        // ── 账户段收尾：余额校正为文件值 ──
        // 流水已全部落库（余额被逐笔调整过），这里把复原账户的余额拍到导出
        // 时刻的「当前余额」，保证新系统终态与源系统一致。报销 / 借还账户的
        // 余额是派生值，setRestoredBalance 内部跳过（由各自台账重算）。
        for (final ({String id, AccountType type, int balanceMinor}) fix
            in balanceFixups) {
          await accRepo.setRestoredBalance(
            id: fix.id,
            type: fix.type,
            balanceMinor: fix.balanceMinor,
          );
        }

        // 级联删除溯源：差集 = 本次导入新建对象（见事务开头的快照注释）。
        final List<String> newAccounts =
            (await snapIds('accounts')).difference(preAccounts).toList();
        final List<String> newTxns =
            (await snapIds('transactions')).difference(preTxns).toList();
        final List<String> newLends =
            (await snapIds('lend_records')).difference(preLends).toList();
        final List<String> newInvests = (await snapIds('investment_holdings'))
            .difference(preInvests)
            .toList();
        final List<String> newReimbs =
            (await snapIds('reimbursements')).difference(preReimbs).toList();
        final List<String> newSavings =
            (await snapIds('savings_goals')).difference(preSavings).toList();
        final List<String> newInstPlans = (await snapIds('installment_plans'))
            .difference(preInstPlans)
            .toList();

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
          // txnIds 用差集（含借还 / 投资 / 分期订单等各路由流水），比逐路由手收
          // 集更全；其余为本次新建的账户 / 台账 ID，删导入记录时一并级联清。
          txnIds: newTxns.isNotEmpty ? newTxns : null,
          accountIds: newAccounts.isNotEmpty ? newAccounts : null,
          lendRecordIds: newLends.isNotEmpty ? newLends : null,
          investmentHoldingIds: newInvests.isNotEmpty ? newInvests : null,
          reimbursementIds: newReimbs.isNotEmpty ? newReimbs : null,
          savingsGoalIds: newSavings.isNotEmpty ? newSavings : null,
          installmentPlanIds: newInstPlans.isNotEmpty ? newInstPlans : null,
        )); // ignore: require_trailing_commas
      }); // end db.transaction（整批原子提交）

      final String accMsg = (accCreated == 0 && accUpdated == 0)
          ? ''
          : (accUpdated == 0
              ? '，复原账户 $accCreated 个'
              : '，复原账户 $accCreated 个（覆盖 $accUpdated 个）');
      // 纯账户文件（0 账单行）：结果文案以账户为主体，避免「成功导入 0 笔」。
      final String msg;
      if (imported > 0) {
        msg = skipped == 0
            ? '成功导入 $imported 笔账单$accMsg'
            : '导入 $imported 笔，跳过 $skipped 笔$accMsg';
      } else if (accCreated + accUpdated > 0) {
        msg = accUpdated == 0
            ? '成功复原账户 $accCreated 个'
            : '成功复原账户 $accCreated 个（覆盖 $accUpdated 个）';
      } else {
        msg = skipped == 0 ? '没有可导入的新内容' : '跳过 $skipped 笔，无可导入内容';
      }
      // 记录最近一次导入的跳过明细（结果栏「查看问题」复用）。
      _lastSkipped = skipped;
      _lastReasons = List<String>.from(reasons);
      if (mounted) setState(() => _resultMsg = msg);
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

  /// 按「对方名 + 方向」解析指定借入/借出账户（应收/应付），匹配不到则
  /// **自动创建**（借入 → [AccountType.borrow]、借出 → [AccountType.lend]，
  /// 户名 = 对方名）。
  ///
  /// 与 [LendRepository] 内部 `_resolveDesignatedAccount` 同口径（同名 +
  /// 同方向类型即视为同一对象），区别仅在于导入场景要求账户列表中不存在
  /// 时建户（2026-10-22 用户反馈），而非留空走「非指定债务跟踪」——
  /// 后者会让导入的应收/应付在账户页不可见、无余额。
  ///
  /// 缓存 key 带账本与类型维度，避免同批导入中同对方重复建户。
  Future<String> _resolveDesignatedAccount(
    String counterparty,
    LendDirection direction,
    String bookId,
    List<Account> accounts,
    AccountRepository repo,
    Map<String, String> cache,
  ) async {
    final AccountType type = direction == LendDirection.borrowIn
        ? AccountType.borrow
        : AccountType.lend;
    final String key =
        'designated|$bookId|${type.index}|${counterparty.trim().toLowerCase()}';
    final String? cached = cache[key];
    if (cached != null) return cached;

    for (final Account a in accounts) {
      if (a.type == type &&
          a.name.trim().toLowerCase() == counterparty.trim().toLowerCase()) {
        cache[key] = a.id;
        return a.id;
      }
    }
    final String id = await repo.add(
      bookId: bookId,
      name: counterparty.trim(),
      type: type,
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
        // 指定借入/借出账户（应收/应付，2026-10-22 用户反馈「未匹配到指定
        // 账户时应支持自动创建」）：账户列解析出的是真实资产账户
        // （toAccountId），「对方」的虚拟账户（借出/借入类型）若账户列表
        // 中不存在，则按方向自动创建（lend/borrow 类型、户名=对方名），
        // 使导入的应收/应付在账户页可见；余额由仓储内
        // _reconcileDesignatedBalance 按「名下未结清合计」保持不变量。
        // 与仓储 _resolveDesignatedAccount 同口径，区别仅在于匹配不到时
        // 建户而非留空（否则退回「非指定债务跟踪」，账户页不可见）。
        final String? designatedId = counterparty.isEmpty
            ? null
            : await _resolveDesignatedAccount(
                counterparty,
                direction,
                bookId,
                accounts,
                accRepo,
                accCache,
              );
        await lendRepo.add(
          bookId: bookId,
          direction: direction,
          status: LendStatus.ongoing,
          counterparty: counterparty,
          amountMinor: row.amountMinor,
          occurredAt: occurredAt,
          note: row.note,
          accountId: designatedId,
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
          source: '导入',
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
      final Transaction? existingRepay =
          await txnRepo.getByRelatedId(relatedId);
      if (existingRepay == null) {
        final String rid = await txnRepo.add(
          source: '导入',
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
    final InvestmentType type = resolveInvestmentType(row.categoryName, symbol);
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
      source: '导入',
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
        title: const Text('数据导入'),
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
                      subtitle: _fileName ?? '选择文件开始导入',
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
              ],
            ),
          ),
          _importBar(),
        ],
      ),
    );
  }

  /// 信息卡（对标小青账）：说明文案 + 右下两个并排按钮（账单模板 / 账户模板）。
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
            '系统差异可能导致导入数据需手动调整，请勿过度依赖此功能。仔细核对、'
            '分析账单，正是记账本身的乐趣与意义所在。\n'
            '与其耗费时间转换旧账目，不如放下历史记录，轻装上阵，即刻开始全新'
            '的记账体验！\n'
            '需导入本 App 导出的 CSV / JSON、空白模板，或支付宝 / 微信 / '
            '云闪付导出的账单 CSV（编码自动识别）；解析后按分类 / 时间 / '
            '账户自动匹配校验并给出核对归集报告。',
            style: TextStyle(
              fontSize: 12.5,
              color: context.forest.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppDimens.sm),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                OutlinedButton(
                  onPressed: () => _downloadTemplate('bill'),
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
                  child: const Text('账单模板', style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: AppDimens.sm),
                OutlinedButton(
                  onPressed: () => _downloadTemplate('account'),
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
                  child: const Text('账户模板', style: TextStyle(fontSize: 13)),
                ),
              ],
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
                    color: context.forest.onSurface,
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
                      color: context.forest.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.forest.onSurfaceVariant,
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

  Widget _importBar() {
    if (_importing) {
      // 大批量导入（2026-10-22）：确定性进度条 + 已处理行数。长导入期间
      // 界面持续可感知进度，不再"只转圈像卡死"。
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.lg,
              0,
              AppDimens.lg,
              AppDimens.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  child: LinearProgressIndicator(
                    value: _progressTotal <= 0
                        ? null
                        : _progressDone >= _progressTotal
                            ? 1.0
                            : _progressDone / _progressTotal,
                    minHeight: 6,
                    backgroundColor: AppPalette.divider,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppPalette.ctaGreen,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.xs),
                Text(
                  '正在导入 $_progressDone / $_progressTotal',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.forest.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _ImportGradientCta(label: '开始导入', onTap: () {}, busy: true),
        ],
      );
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
                  color: context.forest.onSurface,
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
    // 对标小青账：底部「开始导入」常显（未选文件时点击提示），点击跳预览页。
    return _ImportGradientCta(label: '开始导入', onTap: _startImport);
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
                        color: context.forest.onSurfaceVariant,
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
                color: context.forest.onSurface,
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
