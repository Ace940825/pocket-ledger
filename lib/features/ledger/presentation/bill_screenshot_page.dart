import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_dimens.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../theme/app_colors.dart';
import '../data/bill_io.dart';
import '../data/screenshot_ocr.dart';

/// 「账单管理 → 从截图导入」页。
///
/// 选图（相册多选 / 拍照）→ 调 [ScreenshotOcrService] 云端识别 → 识别成功后
/// 直接把 [ParseResult] 交给账单导入确认页（复用其账户 / 分类归户与写入逻辑）。
class BillScreenshotPage extends StatefulWidget {
  const BillScreenshotPage({super.key});

  @override
  State<BillScreenshotPage> createState() => _BillScreenshotPageState();
}

class _BillScreenshotPageState extends State<BillScreenshotPage> {
  final List<XFile> _images = <XFile>[];
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;

  Future<void> _pickGallery() async {
    final List<XFile>? picked = await _picker.pickMultiImage();
    if (picked != null && picked.isNotEmpty) {
      setState(() => _images.addAll(picked));
    }
  }

  Future<void> _pickCamera() async {
    final XFile? p = await _picker.pickImage(source: ImageSource.camera);
    if (p != null) setState(() => _images.add(p));
  }

  void _remove(XFile f) => setState(() => _images.remove(f));

  Future<void> _recognize() async {
    if (_busy || _images.isEmpty) return;
    setState(() => _busy = true);
    final ParseResult result =
        await ScreenshotOcrService.instance.recognize(_images);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.rows.isNotEmpty) {
      if (mounted) context.push(Routes.billImport, extra: result);
    } else if (result.errors.isNotEmpty) {
      if (mounted) showAppToast(context, result.errors.first);
    } else {
      if (mounted) showAppToast(context, '未从截图中识别出账单');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('从截图导入'),
        centerTitle: true,
        leading: const BackButton(),
      ),
      body: Stack(
        children: <Widget>[
          ListView(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceLg,
              AppDimens.spaceMd,
              AppDimens.spaceLg,
              AppDimens.spaceXl,
            ),
            children: <Widget>[
              Container(
                decoration: BoxDecoration(
                  color: AppPalette.softGreen,
                  borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                ),
                padding: const EdgeInsets.all(AppDimens.spaceMd),
                child: const Text(
                  '选择账单 / 收据截图，云端识别后自动填好金额、收支方向与分类，'
                  '确认即可入账。截图仅用于本次识别，服务端不长期存储。',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppPalette.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              if (!ScreenshotOcrService.instance.isConfigured)
                Container(
                  margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                  decoration: BoxDecoration(
                    color: AppPalette.redSoftBg,
                    borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                  ),
                  padding: const EdgeInsets.all(AppDimens.spaceMd),
                  child: const Text(
                    '识别服务尚未配置：请在设置页填入阿里云百炼 API Key，'
                    '或在出包时加 '
                    '--dart-define=SCREENSHOT_OCR_API_KEY=<你的Key> 注入。',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppPalette.expense,
                      height: 1.5,
                    ),
                  ),
                ),
              _thumbGrid(),
            ],
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: AppPalette.scrimBlack20,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _actionBar(),
    );
  }

  Widget _thumbGrid() {
    if (_images.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text(
          '还没有选择截图',
          style: TextStyle(color: AppPalette.textSecondary),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: _images.length,
      itemBuilder: (BuildContext context, int i) {
        final XFile f = _images[i];
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(File(f.path), fit: BoxFit.cover),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _remove(f),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: AppPalette.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: AppPalette.white),
                ),
              ),
            ),
          ],
        );
      },
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
      child: Row(
        children: <Widget>[
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickGallery,
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: const Text('相册'),
            style: _outlineStyle(),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickCamera,
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: const Text('拍照'),
            style: _outlineStyle(),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _busy || _images.isEmpty ? null : _recognize,
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
                    : Text(_images.isEmpty ? '识别' : '识别 ${_images.length} 张'),
              ),
            ),
          ),
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
}
