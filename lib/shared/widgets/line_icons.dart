import 'package:flutter/material.dart';

/// 钢笔线稿图标集 —— 对齐「森林手账·鼠尾草绿」A3 线稿设计稿。
///
/// 所有图标在 24×24 坐标系内绘制，线宽 1.7、圆角线帽/连接，颜色跟随 [color]
/// （未传时取 [IconTheme] 颜色，选中态传入主题主色即转为深绿）。与分类页使用的
/// Material outlined 图标同属细线风格，整页观感统一。
enum LineIconKind {
  account, // 账户（银行立柱）
  reimbursement, // 报销（锯齿票据）
  discount, // 优惠（虚线票券）
  photo, // 图片（相框山水）
  tag, // 标签（吊牌）
  book, // 账本（书本）
  excludeStats, // 不计收支（闭眼）
  excludeBudget, // 不计预算（饼图）
  template, // 模板（书签）
  calendar, // 日历
  settings, // 设置（齿轮）
  // ── 分类简笔画（A3 线稿设计稿）──
  food, // 餐饮（碗筷）
  bus, // 交通（巴士）
  shoppingBag, // 购物（购物袋）
  house, // 居住（小屋）
  musicNote, // 娱乐（音符）
  medicalCross, // 医疗（十字）
  openBook, // 教育（翻开的书）
  smartphone, // 通讯（手机）
  giftRibbon, // 人情（礼盒缎带）
  star, // 其他（星）
  moneyBag, // 工资（钱袋）
  briefcase, // 兼职/工作（公文包）
  trendUp, // 理财/投资（上升折线）
  redPacket, // 红包
  refundArrow, // 退款（票据+回退箭头）
  trash, // 删除（垃圾桶）
  pencil, // 编辑（铅笔）
  chevronRight, // 右箭头（跳转指示）
}

/// 分类 iconKey → 线稿图标映射（对齐 A3 线稿设计稿的分类简笔画）。
///
/// 未收录的 key 返回 null，由调用方兜底为 Material outlined 图标。
LineIconKind? categoryLineKind(String? iconKey) {
  if (iconKey == null || iconKey.isEmpty) return null;
  return switch (iconKey) {
    'restaurant' || 'rice' => LineIconKind.food,
    'transport' || 'taxi' || 'car' || 'train' => LineIconKind.bus,
    'shopping' || 'shopping_cart' => LineIconKind.shoppingBag,
    'home' => LineIconKind.house,
    'entertainment' || 'music' || 'game' => LineIconKind.musicNote,
    'medical' || 'fitness' || 'sports' => LineIconKind.medicalCross,
    'education' || 'book' => LineIconKind.openBook,
    'phone' || 'wifi' || 'computer' => LineIconKind.smartphone,
    'heart' || 'gift' || 'member' => LineIconKind.giftRibbon,
    'daily' ||
    'snack' ||
    'fruit' ||
    'vegetable' ||
    'icecream' ||
    'beauty' ||
    'cloth' ||
    'diamond' ||
    'face' ||
    'content_cut' ||
    'baby' ||
    'toys' ||
    'pets' =>
      LineIconKind.star,
    'salary' => LineIconKind.moneyBag,
    'work' => LineIconKind.briefcase,
    'account_balance' || 'investment' || 'savings' => LineIconKind.trendUp,
    'red_envelope' || 'bonus' => LineIconKind.redPacket,
    'refund' => LineIconKind.refundArrow,
    _ => null,
  };
}

/// 钢笔线稿图标。尺寸自适应，线条粗细按比例随 [size] 缩放，保持与设计稿一致。
class LineIcon extends StatelessWidget {
  const LineIcon(
    this.kind, {
    super.key,
    this.size = 16,
    this.color,
    this.strokeWidth = 1.7,
  });

  final LineIconKind kind;
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final Color resolved = color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;
    return CustomPaint(
      size: Size.square(size),
      painter: _LineIconPainter(kind, resolved, strokeWidth),
    );
  }
}

class _LineIconPainter extends CustomPainter {
  const _LineIconPainter(this.kind, this.color, this.strokeWidth);

  final LineIconKind kind;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path path = Path();
    switch (kind) {
      case LineIconKind.account:
        _account(path);
      case LineIconKind.reimbursement:
        _reimbursement(path);
      case LineIconKind.discount:
        _discount(path);
      case LineIconKind.photo:
        _photo(path);
      case LineIconKind.tag:
        _tag(path);
      case LineIconKind.book:
        _book(path);
      case LineIconKind.excludeStats:
        _excludeStats(path);
      case LineIconKind.excludeBudget:
        _excludeBudget(path);
      case LineIconKind.template:
        _template(path);
      case LineIconKind.calendar:
        _calendar(path);
      case LineIconKind.settings:
        _settings(path);
      case LineIconKind.food:
        _food(path);
      case LineIconKind.bus:
        _bus(path);
      case LineIconKind.shoppingBag:
        _shoppingBag(path);
      case LineIconKind.house:
        _house(path);
      case LineIconKind.musicNote:
        _musicNote(path);
      case LineIconKind.medicalCross:
        _medicalCross(path);
      case LineIconKind.openBook:
        _openBook(path);
      case LineIconKind.smartphone:
        _smartphone(path);
      case LineIconKind.giftRibbon:
        _giftRibbon(path);
      case LineIconKind.star:
        _star(path);
      case LineIconKind.moneyBag:
        _moneyBag(path);
      case LineIconKind.briefcase:
        _briefcase(path);
      case LineIconKind.trendUp:
        _trendUp(path);
      case LineIconKind.redPacket:
        _redPacket(path);
      case LineIconKind.refundArrow:
        _refundArrow(path);
      case LineIconKind.trash:
        _trash(path);
      case LineIconKind.pencil:
        _pencil(path);
      case LineIconKind.chevronRight:
        _chevronRight(path);
    }
    canvas.drawPath(path, paint);
    // 优惠票券的虚线中缝（SVG dasharray 原生不支持，单独描边）
    if (kind == LineIconKind.discount) {
      _dashLine(canvas, paint, 12, 6, 12, 18, 2, 2);
    }
    canvas.restore();
  }

  void _line(Path p, double x1, double y1, double x2, double y2) {
    p.moveTo(x1, y1);
    p.lineTo(x2, y2);
  }

  /// 仅用于优惠券的竖向虚线（dash=实线段长，gap=间隙）。
  void _dashLine(Canvas c, Paint paint, double x, double y1, double x2,
      double y2, double dash, double gap) {
    double y = y1;
    while (y < y2) {
      final double end = (y + dash) > y2 ? y2 : y + dash;
      c.drawLine(Offset(x, y), Offset(x2, end), paint);
      y = end + gap;
    }
  }

  void _account(Path p) {
    _line(p, 3.5, 9, 12, 5);
    _line(p, 12, 5, 20.5, 9);
    _line(p, 4, 9, 20, 9);
    _line(p, 5.5, 9, 5.5, 15);
    _line(p, 9, 9, 9, 15);
    _line(p, 15, 9, 15, 15);
    _line(p, 18.5, 9, 18.5, 15);
    _line(p, 3.5, 16, 20.5, 16);
  }

  void _reimbursement(Path p) {
    p.moveTo(6, 5);
    p.lineTo(18, 5);
    p.lineTo(18, 18.5);
    p.lineTo(16, 17.1);
    p.lineTo(14, 18.5);
    p.lineTo(12, 17.1);
    p.lineTo(10, 18.5);
    p.lineTo(8, 17.1);
    p.lineTo(6, 18.5);
    p.close();
    _line(p, 9, 9, 15, 9);
    _line(p, 9, 12, 15, 12);
  }

  void _discount(Path p) {
    p.addRRect(RRect.fromLTRBXY(4, 6, 20, 18, 2, 2));
  }

  void _photo(Path p) {
    p.addRRect(RRect.fromLTRBXY(4, 5, 20, 19, 2, 2));
    p.addOval(Rect.fromCircle(center: const Offset(9, 10), radius: 1.5));
    p.moveTo(5, 17);
    p.lineTo(9, 13);
    p.lineTo(12, 16);
    p.lineTo(15, 12);
    p.lineTo(19, 17);
  }

  void _tag(Path p) {
    p.moveTo(4, 12.5);
    p.lineTo(11.5, 5);
    p.lineTo(19, 5);
    p.lineTo(19, 12.5);
    p.lineTo(11.5, 20);
    p.close();
    p.addOval(Rect.fromCircle(center: const Offset(15.5, 9), radius: 1.4));
  }

  void _book(Path p) {
    p.addRRect(RRect.fromLTRBXY(5, 5, 19, 19, 2, 2));
    _line(p, 5, 9, 19, 9);
    _line(p, 8, 13, 16, 13);
    _line(p, 8, 16, 16, 16);
  }

  void _excludeStats(Path p) {
    // 闭眼：椭圆眼睑 + 瞳孔 + 斜杠，表「隐藏/不计」。
    p.moveTo(5, 12);
    p.quadraticBezierTo(12, 6, 19, 12);
    p.quadraticBezierTo(12, 18, 5, 12);
    p.close();
    p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 2));
    _line(p, 6, 6, 18, 18);
  }

  void _excludeBudget(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 7));
    _line(p, 12, 12, 12, 5);
    _line(p, 12, 12, 19, 12);
  }

  void _template(Path p) {
    p.moveTo(6, 4);
    p.lineTo(18, 4);
    p.lineTo(18, 20);
    p.lineTo(12, 16);
    p.lineTo(6, 20);
    p.close();
  }

  void _calendar(Path p) {
    p.addRRect(RRect.fromLTRBXY(4, 5.5, 20, 20.5, 2.5, 2.5));
    _line(p, 4, 10, 20, 10);
    _line(p, 8, 3.5, 8, 6.5);
    _line(p, 16, 3.5, 16, 6.5);
    _line(p, 8.5, 13.5, 9.5, 13.5);
    _line(p, 14.5, 13.5, 15.5, 13.5);
  }

  void _settings(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 3));
    _line(p, 12, 4.5, 12, 6.7);
    _line(p, 12, 17.3, 12, 19.5);
    _line(p, 4.5, 12, 6.7, 12);
    _line(p, 17.3, 12, 19.5, 12);
    _line(p, 7, 7, 8.6, 8.6);
    _line(p, 15.4, 15.4, 17, 17);
    _line(p, 17, 7, 15.4, 8.6);
    _line(p, 8.6, 15.4, 7, 17);
  }

  // ── 分类简笔画（A3 线稿设计稿路径移植）──

  /// 餐饮：碗 + 筷子。
  void _food(Path p) {
    _line(p, 4.5, 11.5, 19.5, 11.5);
    p.moveTo(6, 11.5);
    p.cubicTo(6, 15.7, 8.7, 18.5, 12, 18.5);
    p.cubicTo(15.3, 18.5, 18, 15.7, 18, 11.5);
    _line(p, 9.5, 3.5, 11.5, 9.5);
    _line(p, 12.5, 3.5, 13.8, 9.5);
  }

  /// 交通：巴士。
  void _bus(Path p) {
    p.addRRect(RRect.fromLTRBXY(5, 4.5, 19, 17, 2.5, 2.5));
    _line(p, 5, 11, 19, 11);
    p.addOval(Rect.fromCircle(center: const Offset(9, 18.5), radius: 1.3));
    p.addOval(Rect.fromCircle(center: const Offset(15, 18.5), radius: 1.3));
  }

  /// 购物：购物袋。
  void _shoppingBag(Path p) {
    p.moveTo(7.5, 8.5);
    p.lineTo(16.5, 8.5);
    p.lineTo(17.5, 20);
    p.lineTo(6.5, 20);
    p.close();
    p.moveTo(9.5, 8.5);
    p.lineTo(9.5, 7.5);
    p.arcToPoint(
      const Offset(14.5, 7.5),
      radius: const Radius.circular(2.5),
    );
    p.lineTo(14.5, 8.5);
  }

  /// 居住：小屋。
  void _house(Path p) {
    _line(p, 4.5, 11, 12, 5);
    _line(p, 12, 5, 19.5, 11);
    p.moveTo(6.5, 11);
    p.lineTo(6.5, 19.5);
    p.lineTo(17.5, 19.5);
    p.lineTo(17.5, 11);
    _line(p, 10, 19.5, 10, 15);
    _line(p, 10, 15, 14, 15);
    _line(p, 14, 15, 14, 19.5);
  }

  /// 娱乐：音符。
  void _musicNote(Path p) {
    _line(p, 9.5, 17.5, 9.5, 7);
    _line(p, 9.5, 7, 17.5, 5.2);
    _line(p, 17.5, 5.2, 17.5, 15);
    p.addOval(Rect.fromCircle(center: const Offset(7.5, 17.5), radius: 2));
    p.addOval(Rect.fromCircle(center: const Offset(15.5, 15), radius: 2));
  }

  /// 医疗：十字。
  void _medicalCross(Path p) {
    _line(p, 12, 5, 12, 19);
    _line(p, 5, 12, 19, 12);
  }

  /// 教育：翻开的书。
  void _openBook(Path p) {
    p.moveTo(12, 7.5);
    p.cubicTo(10, 6, 7, 6, 5.5, 7.2);
    p.lineTo(5.5, 15.8);
    p.cubicTo(7, 14.6, 10, 14.6, 12, 15.8);
    p.cubicTo(14, 14.6, 17, 14.6, 18.5, 15.8);
    p.lineTo(18.5, 7.2);
    p.cubicTo(17, 6, 14, 6, 12, 7.5);
    p.close();
    _line(p, 12, 7.5, 12, 15.8);
  }

  /// 通讯：手机。
  void _smartphone(Path p) {
    p.addRRect(RRect.fromLTRBXY(7.5, 3, 16.5, 21, 2.5, 2.5));
    _line(p, 10.5, 18.5, 13.5, 18.5);
  }

  /// 人情：礼盒 + 缎带 + 蝴蝶结。
  void _giftRibbon(Path p) {
    p.addRRect(RRect.fromLTRBXY(5.5, 9.5, 18.5, 20, 1.5, 1.5));
    _line(p, 12, 9.5, 12, 20);
    _line(p, 12, 9.5, 9, 7);
    _line(p, 12, 9.5, 15, 7);
    p.addOval(Rect.fromCircle(center: const Offset(12, 9.5), radius: 1.1));
  }

  /// 其他：星。
  void _star(Path p) {
    p.moveTo(12, 3.5);
    p.lineTo(14.5, 9);
    p.lineTo(20.3, 9.6);
    p.lineTo(15.9, 13.5);
    p.lineTo(17.2, 19.1);
    p.lineTo(12, 15.9);
    p.lineTo(6.8, 19.1);
    p.lineTo(8.1, 13.5);
    p.lineTo(3.7, 9.6);
    p.lineTo(9.5, 9);
    p.close();
  }

  /// 工资：钱袋 ¥。
  void _moneyBag(Path p) {
    p.moveTo(6, 10.5);
    p.cubicTo(6, 7.9, 9, 6.7, 12, 6.7);
    p.cubicTo(15, 6.7, 18, 7.9, 18, 10.5);
    p.cubicTo(18, 15.5, 14.7, 18.8, 12, 18.8);
    p.cubicTo(9.3, 18.8, 6, 15.5, 6, 10.5);
    p.close();
    _line(p, 12, 10, 12, 15.5);
    _line(p, 9.7, 12.2, 14.3, 12.2);
    _line(p, 10.4, 14.3, 13.6, 14.3);
  }

  /// 兼职/工作：公文包。
  void _briefcase(Path p) {
    p.addRRect(RRect.fromLTRBXY(4.5, 8, 19.5, 19, 2, 2));
    p.moveTo(9, 8);
    p.lineTo(9, 6.3);
    p.arcToPoint(
      const Offset(15, 6.3),
      radius: const Radius.circular(3),
    );
    p.lineTo(15, 8);
    _line(p, 4.5, 12.5, 19.5, 12.5);
  }

  /// 理财/投资：上升折线 + 箭头。
  void _trendUp(Path p) {
    _line(p, 4, 17, 9, 12);
    _line(p, 9, 12, 12.5, 15);
    _line(p, 12.5, 15, 20, 6.5);
    _line(p, 15.5, 6.5, 20, 6.5);
    _line(p, 20, 6.5, 20, 11);
  }

  /// 红包：红包封 + 弧线封口 + 圆印。
  void _redPacket(Path p) {
    p.addRRect(RRect.fromLTRBXY(5, 6, 19, 18, 2, 2));
    p.moveTo(5, 9);
    p.cubicTo(8, 11.4, 16, 11.4, 19, 9);
    p.addOval(Rect.fromCircle(center: const Offset(12, 13), radius: 1.5));
  }

  /// 退款：票据 + 回退箭头。
  void _refundArrow(Path p) {
    p.addRRect(RRect.fromLTRBXY(5, 9, 19, 17, 1.5, 1.5));
    _line(p, 15, 13, 12, 13);
    _line(p, 12, 13, 13.6, 11.5);
    _line(p, 12, 13, 13.6, 14.5);
  }

  /// 删除：垃圾桶（对齐设计稿 SVG 路径）。
  void _trash(Path p) {
    _line(p, 3, 6, 21, 6); // 盖顶
    _line(p, 8, 6, 8, 4); // 盖左
    _line(p, 8, 4, 16, 4); // 盖顶
    _line(p, 16, 4, 16, 6); // 盖右
    _line(p, 6, 6, 7, 20); // 桶身左
    _line(p, 7, 20, 17, 20); // 桶底
    _line(p, 17, 20, 18, 6); // 桶身右
    _line(p, 10, 10, 10, 16); // 左竖纹
    _line(p, 14, 10, 14, 16); // 右竖纹
  }

  /// 编辑：铅笔（对齐设计稿 SVG 路径）。
  void _pencil(Path p) {
    p.moveTo(17, 3);
    p.lineTo(21, 7);
    p.lineTo(7.5, 20.5);
    p.lineTo(2, 22);
    p.lineTo(3.5, 16.5);
    p.lineTo(17, 3);
    p.close();
  }

  /// 右箭头：跳转指示（›）。
  void _chevronRight(Path p) {
    _line(p, 9, 5, 16, 12);
    _line(p, 16, 12, 9, 19);
  }

  @override
  bool shouldRepaint(covariant _LineIconPainter old) =>
      old.kind != kind || old.color != color || old.strokeWidth != strokeWidth;
}
