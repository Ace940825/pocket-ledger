import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_dimens.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../theme/app_colors.dart';
import '../data/bill_io.dart';
import '../providers/ledger_providers.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../categories/providers/categories_providers.dart';

/// 「账单管理 → 账单导出」页。
///
/// 把当前账本全部账单（含转账）导出为 CSV / JSON：写入应用 Documents 目录，
/// 并支持一键复制文本内容（用于粘贴到微信 / 备忘录等）。不依赖系统分享组件，
/// 在 iOS 沙盒下也能稳定工作。
class BillExportPage extends ConsumerStatefulWidget {
  const BillExportPage({super.key});

  @override
  ConsumerState<BillExportPage> createState() => _BillExportPageState();
}

class _BillExportPageState extends ConsumerState<BillExportPage> {
  bool _asJson = false;
  bool _busy = false;
  String? _content;
  String? _path;
  int _count = 0;

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final String bookId = ref.read(currentBookIdProvider);
      final List<Transaction> txns =
          await ref.read(bookAllTransactionsProvider.future);
      final List<Account> accounts = await ref.read(accountsProvider.future);
      final Map<String, Category> catMap =
          await ref.read(categoryMapProvider.future);

      final Map<String, String> accountNames = <String, String>{};
      for (final Account a in accounts) {
        accountNames[a.id] = a.name;
      }

      final List<BillRow> rows = <BillRow>[
        for (final Transaction t in txns)
          BillRow(
            occurredAt: DateTime.fromMillisecondsSinceEpoch(t.occurredAt,
                    isUtc: true)
                .toLocal(),
            type: t.type,
            amountMinor: t.amountMinor,
            accountName: accountNames[t.accountId] ?? '未知账户',
            toAccountName: t.toAccountId == null
                ? null
                : accountNames[t.toAccountId] ?? '未知账户',
            categoryName: t.categoryId == null ? null : catMap[t.categoryId]?.name,
            note: t.note,
            currency: t.currency,
          ),
      ];

      final String content =
          _asJson ? buildJson(rows) : buildCsv(rows);

      final Directory dir = await getApplicationDocumentsDirectory();
      final String stamp = _timeStamp();
      final String ext = _asJson ? 'json' : 'csv';
      final File file =
          File('${dir.path}/账单导出_$stamp.$ext');
      await file.writeAsString(content);

      setState(() {
        _content = content;
        _path = file.path;
        _count = rows.length;
      });
      if (mounted) {
        showAppToast(context, _asJson ? '已导出 JSON' : '已导出 CSV');
      }
    } catch (e) {
      if (mounted) showAppToast(context, '导出失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _timeStamp() {
    final DateTime now = DateTime.now();
    String p(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${p(now.month)}${p(now.day)}_${p(now.hour)}${p(now.minute)}${p(now.second)}';
  }

  Future<void> _copy() async {
    if (_content == null) return;
    await Clipboard.setData(ClipboardData(text: _content!));
    if (mounted) showAppToast(context, '已复制全部内容');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账单导出'),
        centerTitle: true,
        leading: const BackButton(),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceLg,
                AppDimens.spaceMd,
                AppDimens.spaceLg,
                AppDimens.spaceLg,
              ),
              children: <Widget>[
                _formatCard(),
                const SizedBox(height: AppDimens.spaceMd),
                Container(
                  decoration: BoxDecoration(
                    color: AppPalette.softGreen,
                    borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                  ),
                  padding: const EdgeInsets.all(AppDimens.spaceMd),
                  child: const Text(
                    '导出当前账本全部账单（含转账）。文件保存在应用 Documents 目录，'
                    '可点下方「复制内容」粘贴到微信 / 备忘录，或通过电脑文件共享取出。',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppPalette.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
                if (_content != null) ...<Widget>[
                  const SizedBox(height: AppDimens.spaceLg),
                  _resultCard(),
                ],
              ],
            ),
          ),
          _actionBar(),
        ],
      ),
    );
  }

  Widget _formatCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '导出格式',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppPalette.textPrimary,
              ),
            ),
          ),
          _formatRow(
            title: 'CSV 表格',
            subtitle: '用 Excel /  Numbers 打开，便于查看与二次编辑',
            selected: !_asJson,
            onTap: () => setState(() => _asJson = false),
          ),
          const Divider(height: 1, indent: 16, color: AppPalette.divider),
          _formatRow(
            title: 'JSON 数据',
            subtitle: '保留完整字段，便于与本 App 再次导入往返',
            selected: _asJson,
            onTap: () => setState(() => _asJson = true),
          ),
        ],
      ),
    );
  }

  Widget _formatRow({
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
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppPalette.textSecondary,
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
                        decoration: BoxDecoration(
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

  Widget _resultCard() {
    final List<String> lines = _content!.split('\n');
    final String preview = lines.length > 60
        ? '${lines.take(60).join('\n')}\n…（共 ${lines.length} 行）'
        : _content!;
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppPalette.softGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '已导出 $_count 笔',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.ctaGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceSm),
          SelectableText(
            _path ?? '',
            style: const TextStyle(fontSize: 12, color: AppPalette.textSecondary),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimens.spaceSm),
            decoration: BoxDecoration(
              color: AppPalette.graySurface,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: SelectableText(
              preview,
              style: const TextStyle(
                fontSize: 11.5,
                fontFamily: 'RobotoMono',
                color: AppPalette.textPrimary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _copy,
              icon: const Icon(Icons.copy_outlined, size: 18),
              label: const Text('复制全部内容'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppPalette.ctaGreen,
                side: const BorderSide(color: AppPalette.ctaGreen),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceSm,
        AppDimens.spaceLg,
        AppDimens.spaceLg,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _busy ? null : _export,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppPalette.ctaGreen,
            foregroundColor: AppPalette.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
          ),
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppPalette.white,
                  ),
                )
              : const Text('导出到文件'),
        ),
      ),
    );
  }
}
