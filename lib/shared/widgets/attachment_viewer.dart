import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';

/// 图片附件展示与查看的共享组件。
///
/// 一条流水的 [attachmentUrls] 可能同时包含两类地址：
/// - **远程地址**：由云端 Worker 代理的 `/api/file/<key>`（或绝对 https URL），
///   多端同步后其他设备凭此即可查看原图；
/// - **本机路径**：未联网上传 / 历史数据遗留的应用私有绝对路径，仅本机可读。
///
/// 所有展示入口（记一笔预览、流水列表角标、编辑页）统一复用本文件，
/// 避免「本机 vs 远程」判断逻辑散落各处。

/// 是否为可被网络加载的远程附件地址。
///
/// 相对路径 `/api/file/<key>` 由 Worker 代理，需要拼接 [resolveAttachmentUrl]
/// 里的 baseUrl 才能访问；绝对 https URL 直接使用。其余视为本机文件路径。
bool isRemoteAttachmentUrl(String url) =>
    url.startsWith('http://') ||
    url.startsWith('https://') ||
    url.startsWith('/api/file/') ||
    url.startsWith('/uploads/');

/// 把附件地址解析为可直接用于 [NetworkImage] 的绝对 URL。
///
/// - 绝对 http(s) 地址：原样返回；
/// - 以 `/` 开头的相对地址：拼接 [baseUrl]（容错去掉末尾斜杠）；
/// - 其余（本机绝对路径）：原样返回，交由 [FileImage] 处理。
String resolveAttachmentUrl(String url, String baseUrl) {
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  final String base = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  if (url.startsWith('/')) return '$base$url';
  return url;
}

/// 把存储的 JSON 字符串容错解码为附件地址列表。
///
/// 历史脏数据（非 JSON / 非数组 / 空串）一律返回 null，避免读取中断。
List<String>? parseAttachmentUrls(String? json) {
  if (json == null || json.isEmpty) return null;
  try {
    final Object? decoded = jsonDecode(json);
    if (decoded is List) return decoded.cast<String>();
  } catch (_) {
    // 容错：历史脏数据不应让读取中断。
  }
  return null;
}

/// 根据地址类型构造对应的 [ImageProvider]。
ImageProvider resolveImageProvider(String url, String baseUrl) =>
    isRemoteAttachmentUrl(url)
        ? NetworkImage(resolveAttachmentUrl(url, baseUrl))
        : FileImage(File(url));

/// 附件缩略图。点击查看大图；[showDelete] 为 true 时在右上角显示删除按钮。
class AttachmentThumb extends StatelessWidget {
  const AttachmentThumb({
    required this.url,
    required this.baseUrl,
    this.size = 72,
    this.showDelete = false,
    this.onDeleted,
    super.key,
  });

  final String url;
  final String baseUrl;
  final double size;
  final bool showDelete;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final ImageProvider provider = resolveImageProvider(url, baseUrl);
    return Stack(
      children: <Widget>[
        InkWell(
          onTap: () => openImageViewer(context, <String>[url], 0, baseUrl),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            child: Image(
              image: provider,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: size,
                height: size,
                color: AppColors.surfaceLight,
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
        ),
        if (showDelete && onDeleted != null)
          Positioned(
            right: -2,
            top: -2,
            child: InkWell(
              onTap: onDeleted,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cancel, size: 18, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

/// 全屏查看大图（支持多图左右滑动）。
Future<void> openImageViewer(
  BuildContext context,
  List<String> urls,
  int index,
  String baseUrl,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(AppDimens.spaceMd),
      child: SizedBox(
        width: double.maxFinite,
        height: 360,
        child: PageView.builder(
          controller:
              PageController(initialPage: index.clamp(0, urls.length - 1)),
          itemCount: urls.length,
          itemBuilder: (BuildContext context, int i) {
            final String url = urls[i];
            final ImageProvider provider = resolveImageProvider(url, baseUrl);
            return InteractiveViewer(
              child: Image(
                image: provider,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 48,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
