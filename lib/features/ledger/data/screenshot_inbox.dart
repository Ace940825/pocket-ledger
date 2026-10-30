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
import 'screenshot_notification_service.dart';
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
enum ScreenshotInboxStatus { idle, parsing, pending, saved, failed }

/// 后台识别结果的处理意图（由通知 action / 冷启动路由决定）。
enum ScreenshotProcessIntent { confirm, view, pending }

/// 收件箱当前状态（驱动顶部通知条）。
class ScreenshotInboxState {
  const ScreenshotInboxState({
    this.status = ScreenshotInboxStatus.idle,
    this.txnIds = const <String>[],
    this.skipReasons = const <String>[],
    this.firstRow,
    this.error,
    this.pendingRows = const <BillRow>[],
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

  /// 待确认的 OCR 结果行（status=pending 时非空）。
  final List<BillRow> pendingRows;
}

/// 截图收件箱控制器：扫描快捷指令交接文件 → OCR 解析 → 自动落库。
///
/// 「自动落库草稿流水」口径（2026-10-20 用户确认）：识别成功即写入真实流水
/// （金额必须 > 0 由仓储校验兜底），顶部通知条点开即账单详情页，可改 / 可删。
class ScreenshotInboxController extends Notifier<ScreenshotInboxState> {
  bool _busy = false;
  bool _taking = false;

  /// 串行化对 Swift 交接文件的消费，避免冷启动 / 通知 action 并发重复落库。
  bool _swiftBusy = false;

  @override
  ScreenshotInboxState build() => const ScreenshotInboxState();

  /// 扫描交接文件并处理。
  ///
  /// [withRetry] 为 true 时（冷启动 / 回前台）在 iOS 短窗口内多次轮询，
  /// 规避「先拉起 APP 后写文件」的时序竞争；为 false 时（前台持续轮询）
  /// 只检查一次文件是否存在——前台已有 1.5s 轮询兜底，不需要再跑长循环。
  ///
  /// [intent] 仅在命中「Swift 后台识别结果文件」时生效：confirm / pending / view
  /// 三种意图现在都直接落库（识别即入账），差异仅在落库后是否跳详情（view）。
  Future<void> checkAndProcess({
    bool withRetry = true,
    ScreenshotProcessIntent intent = ScreenshotProcessIntent.pending,
  }) async {
    if (_busy || _taking || state.status == ScreenshotInboxStatus.parsing) {
      return;
    }
    // 1) 优先消费 Swift 后台识别写出的结果文件（真·不进App 路径）。
    //    该文件存在说明识别已在 Swift 侧完成，Dart 只需重建并落库。
    final Map<String, dynamic>? swift = await _readSwiftResult();
    if (swift != null) {
      await _withSwiftGuard(() => _consumeSwiftResult(swift, intent));
      return;
    }
    // 2) 否则走 Dart 兜底 OCR（image+meta 交接，App 打开时识别）。
    final int attempts = (withRetry && Platform.isIOS) ? _kPollAttempts : 1;
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

  // ── Swift 后台识别结果消费（真·不进App 路径）─────────────

  /// 串行化对 Swift 交接文件的消费，避免冷启动 / 通知 action 并发重复落库。
  Future<T?> _withSwiftGuard<T>(Future<T> Function() fn) async {
    if (_swiftBusy) return null;
    _swiftBusy = true;
    try {
      return await fn();
    } finally {
      _swiftBusy = false;
    }
  }

  /// 读取 Swift 写出的 OCR 结果文件；不存在 / 损坏 / 陈旧则返回 null。
  Future<Map<String, dynamic>?> _readSwiftResult() async {
    try {
      final Directory tmp = await getTemporaryDirectory();
      final File f = File('${tmp.path}/$kPendingOcrResult');
      if (!await f.exists()) return null;
      final Map<String, dynamic> data =
          jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final int receivedAt = (data['receivedAt'] as num?)?.toInt() ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - receivedAt >
          _kStaleAfter.inMilliseconds) {
        _safeDelete(f);
        return null;
      }
      return data;
    } catch (_) {
      return null;
    }
  }

  /// 把 Swift 结果 JSON 解析为 [BillRow]（与 Dart OCR 共用 parseOcrItems）。
  List<BillRow> _parseSwiftRows(Map<String, dynamic> data) {
    final dynamic raw = data['items'];
    if (raw is! List) return const <BillRow>[];
    return parseOcrItems(raw);
  }

  /// 解析 Swift 结果里的截图路径（Swift 给绝对路径；缺失则回退标准文件名）。
  Future<String?> _resolveSwiftImage(Map<String, dynamic> data) async {
    final dynamic img = data['image'];
    if (img is String && img.isNotEmpty && img.startsWith('/')) return img;
    final Directory tmp = await getTemporaryDirectory();
    final String fallback = '${tmp.path}/$kPendingScreenshotImage';
    return File(fallback).existsSync() ? fallback : null;
  }

  /// 删除 Swift 写出的交接文件（结果 JSON + 截图 + 旧 meta 标记）。
  Future<void> _deleteSwiftResultFile(Map<String, dynamic> data) async {
    try {
      final Directory tmp = await getTemporaryDirectory();
      final File rf = File('${tmp.path}/$kPendingOcrResult');
      if (await rf.exists()) await rf.delete();
      final File mf = File('${tmp.path}/$kPendingScreenshotMeta');
      if (await mf.exists()) await mf.delete();
      final dynamic img = data['image'];
      final String imgPath = img is String && img.isNotEmpty && img.startsWith('/')
          ? img
          : '${tmp.path}/$kPendingScreenshotImage';
      final File imf = File(imgPath);
      if (await imf.exists()) await imf.delete();
    } catch (_) {}
  }

  /// 消费 Swift 后台识别结果：按意图 confirm / view / pending 处理。
  Future<void> _consumeSwiftResult(
    Map<String, dynamic> data,
    ScreenshotProcessIntent intent,
  ) async {
    final List<BillRow> rows = _parseSwiftRows(data);
    final String? imgPath = await _resolveSwiftImage(data);
    final String bookId = ref.read(currentBookIdProvider);
    // 已读入内存，立即清理交接文件，避免重复消费。
    await _deleteSwiftResultFile(data);

    if (rows.isEmpty) {
      state = const ScreenshotInboxState(
        status: ScreenshotInboxStatus.failed,
        error: '未从截图中识别出账单',
      );
      unawaited(ScreenshotNotificationService.instance
          .showError('未从截图中识别出账单'),);
      return;
    }

    // 识别即入账：App 被唤起 / 打开的瞬间即落库（落库只能在 Dart 完成），
    // confirm / pending / view 三种意图无差别直接写入。落库后是否额外跳转
    // 详情由引导器（bootstrapper）依据通知 action 决定，这里只负责写入。
    await _saveAndNotify(rows, imgPath, bookId);
  }

  /// 用户在系统通知上点"去查看"：重建 OCR 结果并直接落库（识别即入账），
  /// 落库后由引导器跳到账单详情弹窗供查看 / 修改。
  ///
  /// 若内存中已有待查看结果（Dart 识别路径）则直接用其落库；
  /// 否则读取 Swift 后台识别结果文件落库。
  Future<void> viewFromNotification() async {
    if (pendingResult != null && pendingResult!.rows.isNotEmpty) {
      await _saveAndNotify(
        pendingResult!.rows,
        pendingResult!.screenshotPath,
        pendingResult!.bookId ?? ref.read(currentBookIdProvider),
      );
      return;
    }
    final Map<String, dynamic>? swift = await _readSwiftResult();
    if (swift == null) return;
    await _withSwiftGuard(() async {
      final List<BillRow> rows = _parseSwiftRows(swift);
      final String? imgPath = await _resolveSwiftImage(swift);
      await _deleteSwiftResultFile(swift);
      if (rows.isEmpty) return;
      await _saveAndNotify(rows, imgPath, ref.read(currentBookIdProvider));
    });
  }

  /// 处理一张收到的账单截图：OCR → 根据前后台状态决定直接落库或发通知等确认。
  Future<void> submit(XFile image) async {
    if (_busy) return;
    _busy = true;
    state = const ScreenshotInboxState(status: ScreenshotInboxStatus.parsing);
    try {
      // OCR 网络请求与截图持久化并行，省去文件复制的串行等待。
      final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
        ScreenshotOcrService.instance.recognize(<XFile>[image]),
        copyScreenshotToAttachments(image),
      ]);
      final ParseResult parsed = results[0] as ParseResult;
      if (parsed.rows.isEmpty) {
        state = ScreenshotInboxState(
          status: ScreenshotInboxStatus.failed,
          error: parsed.errors.isEmpty ? '未从截图中识别出账单' : parsed.errors.first,
        );
        // 失败也发系统通知（后台场景下用户需要知道识别失败）。
        unawaited(ScreenshotNotificationService.instance.showError(
          parsed.errors.isEmpty ? '未从截图中识别出账单' : parsed.errors.first,
        ),);
        return;
      }

      final String? attachment = results[1] as String?;
      final String bookId = ref.read(currentBookIdProvider);

      // 识别即入账：无论前后台都直接落库（落库在 Dart 完成，App 被唤起即写入）。
      // 落库后由 _saveAndNotify 弹 App 内富卡片横幅 + 发"已记账"系统通知。
      await _saveAndNotify(parsed.rows, attachment, bookId);
    } catch (e) {
      state = ScreenshotInboxState(
        status: ScreenshotInboxStatus.failed,
        error: '截图识别失败：$e',
      );
      unawaited(ScreenshotNotificationService.instance.showError('截图识别失败：$e'));
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

  /// 直接落库并更新状态（前台场景或用户点"确认入库"时调用）。
  Future<void> _saveAndNotify(
    List<BillRow> rows,
    String? attachment,
    String bookId,
  ) async {
    final ScreenshotBillSaveOutcome outcome = await saveScreenshotBillRows(
      txnRepo: ref.read(transactionRepositoryProvider),
      accRepo: ref.read(accountRepositoryProvider),
      catRepo: ref.read(categoryRepositoryProvider),
      accountsDao: ref.read(accountsDaoProvider),
      categoriesDao: ref.read(categoriesDaoProvider),
      bookId: bookId,
      rows: rows,
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
        );

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
      firstRow: rows.first,
    );
    // 落库完成：系统通知更新为"已记账"（富文本摘要），3 秒后自动移除。
    unawaited(ScreenshotNotificationService.instance.showSaved(rows));
  }

  /// 用户在系统通知上点"确认入库"。
  ///
  /// 优先用内存中的待确认结果（Dart 识别 / 后台 pending 横幅路径）；
  /// 否则尝试消费 Swift 后台识别结果文件（冷启动 / 通知确认路径）。
  Future<void> confirmFromNotification() async {
    if (state.status == ScreenshotInboxStatus.pending &&
        state.pendingRows.isNotEmpty) {
      final List<BillRow> rows = state.pendingRows;
      final ScreenshotPendingResult? pending = pendingResult;
      final String bookId = ref.read(currentBookIdProvider);
      await _saveAndNotify(rows, pending?.screenshotPath, bookId);
      return;
    }
    final Map<String, dynamic>? swift = await _readSwiftResult();
    if (swift == null) return;
    await _withSwiftGuard(() async {
      final List<BillRow> rows = _parseSwiftRows(swift);
      final String? imgPath = await _resolveSwiftImage(swift);
      await _deleteSwiftResultFile(swift);
      if (rows.isEmpty) return;
      await _saveAndNotify(rows, imgPath, ref.read(currentBookIdProvider));
    });
  }

  /// 用户在系统通知上点"取消"。
  Future<void> cancelFromNotification() async {
    pendingResult = null;
    state = const ScreenshotInboxState();
    unawaited(ScreenshotNotificationService.instance.dismiss());
    // 同时清理可能残留的 Swift 后台识别交接文件。
    await _withSwiftGuard(() async {
      try {
        final Directory tmp = await getTemporaryDirectory();
        final File rf = File('${tmp.path}/$kPendingOcrResult');
        if (await rf.exists()) await rf.delete();
      } catch (_) {}
    });
  }

  /// 通知条关闭后回到待命态。
  void dismiss() {
    if (state.status != ScreenshotInboxStatus.idle) {
      state = const ScreenshotInboxState();
    }
  }

  /// 取走一份就绪的交接截图（含陈旧丢弃）；无交接返回 null。
  Future<XFile?> _takeIncoming() async {
    if (_taking) return null;
    _taking = true;
    try {
      final Directory tmp = await getTemporaryDirectory();
      final File img = File('${tmp.path}/$kPendingScreenshotImage');
      final File meta = File('${tmp.path}/$kPendingScreenshotMeta');
      if (!await img.exists()) return null;
      // meta 未就绪：分享扩展是先写 img、后写 meta（meta 是完成标记），
      // 两次写入之间有间隔。此时不能把 img 当残留删掉——否则正在写入的新图
      // 会被轮询误删，导致 OCR 根本没机会跑、失败横幅也不弹。
      // 等下一次轮询再看；真正的残留由下面 stale 检查（30 分钟）兜底清理。
      if (!await meta.exists()) return null;

      final Map<String, dynamic> m;
      try {
        m = jsonDecode(await meta.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        // meta 损坏：清理两个文件，防永久残留。
        _safeDelete(img);
        _safeDelete(meta);
        return null;
      }
      final int receivedAt = (m['receivedAt'] as num?)?.toInt() ?? 0;
      final bool stale =
          DateTime.now().millisecondsSinceEpoch - receivedAt >
              _kStaleAfter.inMilliseconds;
      if (stale) {
        _safeDelete(img);
        _safeDelete(meta);
        return null;
      }
      // 先消费元信息标记（防重复处理），截图留待 OCR 读完字节后在 submit 清理。
      await meta.delete();
      return XFile(img.path);
    } catch (_) {
      return null;
    } finally {
      _taking = false;
    }
  }

  void _safeDelete(File f) {
    try {
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }
}

/// 截图收件箱 Provider。
final NotifierProvider<ScreenshotInboxController, ScreenshotInboxState>
    screenshotInboxProvider =
    NotifierProvider<ScreenshotInboxController, ScreenshotInboxState>(
  ScreenshotInboxController.new,
);
