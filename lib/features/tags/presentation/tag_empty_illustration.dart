import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

/// 空态插画：复刻 tag-forest-FINAL `emptySvg`（160×116 viewBox）。
///
/// 元素：底部绿影 → 小票卡（#FFFCF5 + 深墨描边）→ 黄色折角 →
/// $ 金币 → 票内两行文字线 → 地面线 → 四周灰色火花。
class TagEmptyIllustration extends StatelessWidget {
  const TagEmptyIllustration({super.key, this.width = 150});

  /// 设计稿中弹窗空态 150px、管理页空态 120px。
  final double width;

  @override
  Widget build(BuildContext context) {
    final double w = width;
    return CustomPaint(
      size: Size(w, w * 116 / 160),
      painter: _EmptySvgPainter(),
    );
  }
}

class _EmptySvgPainter extends CustomPainter {
  static const double _vw = 160;
  static const double _vh = 116;

  static const Color _ink = AppColors.ink;
  static const Color _gold = AppColors.sunGold;
  static const Color _shadow = AppColors.sagePale;
  static const Color _spark = AppColors.ink3;
  static const Color _paper = AppColors.cream;
  static const Color _sunken = AppColors.sunkenCream;

  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / _vw;
    final double sy = size.height / _vh;
    canvas.scale(sx, sy);

    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = _ink;

    // 1) 底部绿影
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(80, 70),
        width: 92,
        height: 60,
      ),
      Paint()..color = _shadow.withValues(alpha: 0.55),
    );

    // 2) 小票卡
    final RRect receipt = RRect.fromRectAndCorners(
      const Rect.fromLTWH(46, 22, 62, 72),
      topLeft: const Radius.circular(8),
      topRight: const Radius.circular(8),
      bottomLeft: const Radius.circular(8),
      bottomRight: const Radius.circular(8),
    );
    canvas.drawRRect(receipt, Paint()..color = _paper);
    canvas.drawRRect(receipt, stroke);

    // 3) 左上角小沙角（装饰）
    canvas.drawPath(
      Path()
        ..moveTo(46, 30)
        ..arcToPoint(const Offset(54, 22), radius: const Radius.circular(8))
        ..lineTo(46, 22)
        ..close(),
      Paint()..color = _sunken,
    );

    // 4) 右上折角（黄色）
    canvas.drawPath(
      Path()
        ..moveTo(96, 22)
        ..quadraticBezierTo(110, 26, 108, 40)
        ..lineTo(96, 42)
        ..close(),
      Paint()..color = _gold,
    );
    canvas.drawPath(
      Path()
        ..moveTo(96, 22)
        ..quadraticBezierTo(110, 26, 108, 40)
        ..lineTo(96, 42)
        ..close(),
      stroke,
    );

    // 5) $ 金币
    canvas.drawCircle(const Offset(77, 48), 10, Paint()..color = _gold);
    canvas.drawCircle(const Offset(77, 48), 10, stroke);
    _dollarText(canvas);

    // 6) 票内两行文字线
    final Paint line1 = Paint()..color = _ink.withValues(alpha: 0.8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(60, 66, 34, 4),
        const Radius.circular(2),
      ),
      line1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(60, 75, 24, 4),
        const Radius.circular(2),
      ),
      Paint()..color = _ink.withValues(alpha: 0.4),
    );

    // 7) 地面长线 + 三段短线
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(24, 100, 112, 3),
        const Radius.circular(1.5),
      ),
      Paint()..color = _ink.withValues(alpha: 0.85),
    );
    final Paint ground = Paint()
      ..color = _ink
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(30, 108), const Offset(50, 108), ground);
    canvas.drawLine(const Offset(118, 108), const Offset(134, 108), ground);
    canvas.drawLine(const Offset(70, 110), const Offset(90, 110), ground);

    // 8) 火花（× 两组 + 十字一组）
    final Paint spark = Paint()
      ..color = _spark
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(36, 40), const Offset(42, 46), spark);
    canvas.drawLine(const Offset(42, 40), const Offset(36, 46), spark);
    canvas.drawLine(const Offset(124, 34), const Offset(130, 40), spark);
    canvas.drawLine(const Offset(130, 34), const Offset(124, 40), spark);
    canvas.drawLine(const Offset(128, 78), const Offset(128, 86), spark);
    canvas.drawLine(const Offset(124, 82), const Offset(132, 82), spark);
  }

  void _dollarText(Canvas canvas) {
    final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: 12),
    )
      ..pushStyle(
        ui.TextStyle(
          color: _ink,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      )
      ..addText(r'$');
    final ui.Paragraph p = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 24));
    canvas.drawParagraph(p, const Offset(77 - 12, 48 - 7));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
