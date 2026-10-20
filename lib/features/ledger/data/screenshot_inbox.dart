import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../providers/app_providers.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../categories/providers/categories_providers.dart';
import '../providers/ledger_providers.dart';
import 'bill_io.dart';
import 'import_record_repository.dart';
import 'screenshot_bill_writer.dart';
import 'screenshot_ocr.dart';

// ── 快捷指令交接文件名（与 ios/Runner/ScreenshotIntent.swift 严格对应）──
// iOS「识别账单」App Intent 把截图与元信息写入容器临时目录后拉起本 APP，
// Dart 侧启动 / 回前台时扫描这两个标记文件完成交接。

/// 交接截图文件名（在 `getTemporaryDirectory()` 下）。
const String kPendingScreenshotImage = 'pl_pending_screenshot.jpg';

/// 交接元信息文件名（最后写入，作为「截图已就绪」的完成标记）。
const String kPendingScreenshotMeta = 'pl_pending_screenshot.meta.json';

/// 超过该时长的交接文件视为陈旧残留，直接丢弃不处理。
const Duration _kStaleAfter = Duration(minutes: 30);

/// 回前台后的轮询窗口：快捷指令可能先拉起 APP、后写完文件，
/// 在窗口内每 500ms 扫一次，避免错过交接。
const int _kPollAttempts = 8;
const Duration _kPollInterval = Duration(milliseconds: 500);

/// 截图收件箱状态机。
enum ScreenshotInboxStatus { idle, parsing, saved, failed }

/// 收件箱当前状态（驱动顶部通知条）。
class ScreenshotInboxState {
  const ScreenshotInboxState({
    this.status = ScreenshotInboxStatus.idle,
    this.txnIds = const <String>[],
    this.skipReasons = const <String>[],
    this.firstRow,
    this.error,
  });

  final ScreenshotInboxStatus status;

  /// 成功写入的流水 ID（首笔挂了截图附件）。
  final List<String> txnIds;

  /// 被跳过笔数的原因。
  final List<String> skipReasons;

  /// 首笔解析行（通知条展示 账户 / 备注 / 时间 / 金额 用）。
  final BillRow? firstRow;

  /// 失败原因（status=failed 时非空）。
  final String? error;
}

/// 截图收件箱控制器：扫描快捷指令交接文件 → OCR 解析 → 自动落库。
///
/// 「自动落库草稿流水」口径（2026-10-20 用户确认）：识别成功即写入真实流水
/// （金额必须 > 0 由仓储校验兜底），顶部通知条点开即账单详情页，可改 / 可删。
class ScreenshotInboxController extends Notifier<ScreenshotInboxState> {
  bool _busy = false;

  @override
  ScreenshotInboxState build() => const ScreenshotInboxState();

  /// 扫描交接文件并处理。APP 启动后与每次回前台各调一次；
  /// iOS 下在短窗口内轮询，规避「先拉起 APP 后写文件」的时序竞争。
  Future<void> checkAndProcess() async {
    if (_busy || state.status == ScreenshotInboxStatus.parsing) return;
    final int attempts = Platform.isIOS ? _kPollAttempts : 1;
    for (int i = 0; i < attempts; i++) {
      final XFile? image = await _takeIncoming();
      if (image != null) {
        await submit(image);
        return;
      }
      if (i < attempts - 1) {
        await Future<void>.delayed(_kPollInterval);
      }
    }
  }

  /// 处理一张收到的账单截图：OCR → 自动落库 → 记导入台账 → 更新状态。
  Future<void> submit(XFile image) async {
    if (_busy) return;
    _busy = true;
    state = const ScreenshotInboxState(status: ScreenshotInboxStatus.parsing);
    try {
      final ParseResult parsed =
          await ScreenshotOcrService.instance.recognize(<XFile>[image]);
      if (parsed.rows.isEmpty) {
        state = ScreenshotInboxState(
          status: ScreenshotInboxStatus.failed,
          error: parsed.errors.isEmpty ? '未从截图中识别出账单' : parsed.errors.first,
        );
        return;
      }

      // 截图持久化为附件，挂在第一笔流水（对标咔皮记账详情带原图）。
      final String? attachment = await copyScreenshotToAttachments(image);
      final String bookId = ref.read(currentBookIdProvider);
      final ScreenshotBillSaveOutcome outcome = await saveScreenshotBillRows(
        txnRepo: ref.read(transactionRepositoryProvider),
        accRepo: ref.read(accountRepositoryProvider),
        catRepo: ref.read(categoryRepositoryProvider),
        accountsDao: ref.read(accountsDaoProvider),
        categoriesDao: ref.read(categoriesDaoProvider),
        bookId: bookId,
        rows: parsed.rows,
        screenshotPath: attachment,
      );

      // 记导入台账：账单管理「导入记录」可溯源，左滑删除级联删本批账单。
      await ref.read(importRecordRepositoryProvider).insert(
            ImportRecord(
              id: const Uuid().v7(),
              source: 'screenshot',
              sourceLabel: '快捷指令截图',
              importedCount: outcome.txnIds.length,
              skippedCount: outcome.skippedReasons.length,
              createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
              failReasons: outcome.skippedReasons.isEmpty
                  ? null
                  : outcome.skippedReasons,
              txnIds: outcome.txnIds.isEmpty ? null : outcome.txnIds,
            ),
          ); // ignore: require_trailing_commas

      if (outcome.txnIds.isEmpty) {
        state = ScreenshotInboxState(
          status: ScreenshotInboxStatus.failed,
          error: outcome.skippedReasons.isEmpty
              ? '识别结果无法入账'
              : outcome.skippedReasons.first,
        );
        return;
      }
      state = ScreenshotInboxState(
        status: ScreenshotInboxStatus.saved,
        txnIds: outcome.txnIds,
        skipReasons: outcome.skippedReasons,
        firstRow: parsed.rows.first,
      );
    } catch (e) {
      state = ScreenshotInboxState(
        status: ScreenshotInboxStatus.failed,
        error: '截图识别失败：$e',
      );
    } finally {
      _busy = false;
      // OCR 已读走字节，临时交接图即弃（附件副本已另存）。
      try {
        final File f = File(image.path);
        if (await f.exists()) await f.delete();
      } on Exception {
        // 清理失败不影响主流程。
      }
    }
  }

  /// 通知条关闭后回到待命态。
  void dismiss() {
    if (state.status != ScreenshotInboxStatus.idle) {
      state = const ScreenshotInboxState();
    }
  }

  /// 取走一份就绪的交接截图（含陈旧丢弃）；无交接返回 null。
  Future<XFile?> _takeIncoming() async {
    try {
      final Directory tmp = await getTemporaryDirectory();
      final File img = File('${tmp.path}/$kPendingScreenshotImage');
      final File meta = File('${tmp.path}/$kPendingScreenshotMeta');
      if (!await img.exists()) return null;
      // 元信息缺失 = 上次处理中断的残留，直接清掉防误用旧图。
      if (!await meta.exists()) {
        await img.delete();
        return null;
      }
      final Map<String, dynamic> m =
          jsonDecode(await meta.readAsString()) as Map<String, dynamic>;
      final int receivedAt = (m['receivedAt'] as num?)?.toInt() ?? 0;
      final bool stale =
          DateTime.now().millisecondsSinceEpoch - receivedAt >
              _kStaleAfter.inMilliseconds;
      if (stale) {
        await img.delete();
        await meta.delete();
        return null;
      }
      // 先消费元信息标记（防重复处理），截图留待 OCR 读完字节后在 submit 清理。
      await meta.delete();
      return XFile(img.path);
    } catch (e) {
      return null;
    }
  }
}

/// 截图收件箱 Provider。
final NotifierProvider<ScreenshotInboxController, ScreenshotInboxState>
    screenshotInboxProvider =
    NotifierProvider<ScreenshotInboxController, ScreenshotInboxState>(
  ScreenshotInboxController.new,
);
