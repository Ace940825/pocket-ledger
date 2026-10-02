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
  otherDots, // 其他（三圆点·更多）
  moneyBag, // 工资（钱袋）
  briefcase, // 兼职/工作（公文包）
  trendUp, // 理财/投资（上升折线）
  redPacket, // 红包
  refundArrow, // 退款（票据+回退箭头）
  trash, // 删除（垃圾桶）
  pencil, // 编辑（铅笔）
  chevronRight, // 右箭头（跳转指示）
  close, // 关闭（×）
  info, // 信息（圆圈 i）
  person, // 人数（头像 + 肩线，表示「人/收款对象」）
  // ── 餐饮细分（记一笔·餐饮子类）──
  breakfast, // 早餐（煎蛋）
  lunch, // 午餐（便当盒）
  dinner, // 晚餐（圆顶罩盘）
  beverage, // 饮品（带吸管外带杯）
  coupon, // 团购券（票券 + ¥）
  skewer, // 风味小吃（串签）

  // ── 全分类图标（A3 线稿设计稿·并入）──
  // 餐饮 Dining
  coffee, // 咖啡
  milkTea, // 奶茶
  juice, // 果汁
  dimSum, // 点心
  // 购物 Shopping
  produce, // 果蔬蛋奶
  snack, // 零食
  shipping, // 运费
  apparel, // 服饰鞋包
  beauty, // 美妆护肤
  digital, // 数码电器
  consumable, // 生活耗材
  tobacco, // 烟酒茶糖
  furniture, // 家居家具
  personalCare, // 个护服务
  // 出行 Travel
  travel, // 出行
  carCare, // 养车
  transit, // 公共交通
  fuel, // 加油充电
  taxiRental, // 打车租车
  intercity, // 城际出行
  // 居住 Housing
  lodging, // 住宿
  renovation, // 装修维护
  rent, // 房租房贷
  utilities, // 水电燃物
  telecom, // 话费网费
  // 娱乐 Entertainment
  fun, // 娱乐
  fitness, // 运动健身
  offlineFun, // 线下娱乐
  digitalFun, // 数字娱乐
  travelVacation, // 旅游度假
  hobby, // 收藏爱好
  // 医疗健康 Medical
  clinic, // 就医购药
  wellness, // 养生保健
  checkup, // 体检疫苗
  insurance, // 商业保险
  // 学习办公 Study
  knowledge, // 知识付费
  stationery, // 图文工具
  // 宠物 Pet
  petFood, // 宠物
  petSupply, // 宠物用品
  petMedical, // 宠物医疗
  petService, // 宠物服务
  // 资金往来 Funds
  funds, // 资金往来
  repay, // 还款
  lend, // 借款
  accrue, // 计提
  withdrawal, // 取现（信用卡 + 向下箭头）
  internalTransfer, // 内部转账（两账户 + 双向箭头）
  depositIn, // 存款存入（储蓄罐 + 罐腹内向下箭头）
  depositOut, // 存款取出（储蓄罐 + 罐腹内向上箭头）
  // 借还系统分类 Lend（落账自动挂分类，用户分类选择器隐藏）
  borrowIn, // 借入（钱进：箭头入硬币）
  lendOut, // 借出（钱出：箭头离硬币）
  repayDebt, // 还债（向下箭头入欠条）
  collectDebt, // 收债（向上箭头出欠条）
  debtReduce, // 债务消减（欠条 + 减号）
  badDebt, // 坏账计提（欠条 + 斜杠核销）
  reimburseIncome, // 报销收入（票据 + ¥）
  // 投资支出 Invest
  tax, // 缴税
  finance, // 博彩理财
  dividend, // 分红入股
  operations, // 日常运营
  capex, // 大额投入
  // ── 收入分类 Income（记一笔·收入树）──
  incomeJob, // 职业收入（工牌）
  bonusTrophy, // 绩效奖金（奖杯）
  allowance, // 津贴补助（硬币堆）
  incomeBusiness, // 经营收入（门店）
  soleProprietor, // 个体经营（推车）
  incomeSide, // 副业兼职（笔记本）
  rider, // 骑手（电动车）
  videoIncome, // 视频收入（摄像机）
  securities, // 证券收入（K线）
  interest, // 利息收入（百分号硬币）
}

/// 分类 iconKey → 线稿图标映射（对齐 A3 线稿设计稿的分类简笔画）。
///
/// 未收录的 key 返回 null，由调用方兜底为 Material outlined 图标。
LineIconKind? categoryLineKind(String? iconKey) {
  if (iconKey == null || iconKey.isEmpty) return null;
  return switch (iconKey) {
    'restaurant' || 'rice' => LineIconKind.food,
    'breakfast' => LineIconKind.breakfast,
    'lunch' => LineIconKind.lunch,
    'dinner' => LineIconKind.dinner,
    'beverage' => LineIconKind.beverage,
    'groupbuy' => LineIconKind.coupon,
    'street_food' => LineIconKind.skewer,
    'transport' || 'train' => LineIconKind.bus,
    'shopping' || 'shopping_cart' => LineIconKind.shoppingBag,
    'home' => LineIconKind.house,
    'music' || 'game' => LineIconKind.musicNote,
    'medical' || 'sports' => LineIconKind.medicalCross,
    'education' || 'book' => LineIconKind.openBook,
    'phone' || 'wifi' || 'computer' => LineIconKind.smartphone,
    'heart' || 'gift' || 'member' => LineIconKind.giftRibbon,
    'daily' || 'icecream' || 'diamond' || 'baby' || 'toys' => LineIconKind.star,
    'salary' => LineIconKind.moneyBag,
    'work' => LineIconKind.briefcase,
    'account_balance' || 'investment' || 'savings' => LineIconKind.trendUp,
    'red_envelope' || 'bonus' => LineIconKind.redPacket,
    'refund' => LineIconKind.refundArrow,
    // 餐饮 Dining
    'local_drink' => LineIconKind.beverage,
    'coffee' => LineIconKind.coffee,
    'milk_tea' => LineIconKind.milkTea,
    'juice' => LineIconKind.juice,
    'dim_sum' => LineIconKind.dimSum,
    // 购物 Shopping
    'produce' || 'fruit' || 'vegetable' => LineIconKind.produce,
    'snack' => LineIconKind.snack,
    'shipping' => LineIconKind.shipping,
    'apparel' || 'cloth' => LineIconKind.apparel,
    'beauty' || 'face' => LineIconKind.beauty,
    'digital' => LineIconKind.digital,
    'consumable' => LineIconKind.consumable,
    'tobacco' || 'liquor' => LineIconKind.tobacco,
    'furniture' => LineIconKind.furniture,
    'personal_care' || 'content_cut' => LineIconKind.personalCare,
    // 出行 Travel
    'travel' => LineIconKind.travel,
    'car_care' || 'car' => LineIconKind.carCare,
    'transit' => LineIconKind.transit,
    'fuel' => LineIconKind.fuel,
    'taxi_rental' || 'taxi' => LineIconKind.taxiRental,
    'intercity' => LineIconKind.intercity,
    // 居住 Housing
    'lodging' => LineIconKind.lodging,
    'renovation' || 'repair' => LineIconKind.renovation,
    'rent' => LineIconKind.rent,
    'utilities' => LineIconKind.utilities,
    'telecom' => LineIconKind.telecom,
    // 娱乐 Entertainment
    'entertainment' => LineIconKind.fun,
    'fitness' => LineIconKind.fitness,
    'offline_fun' => LineIconKind.offlineFun,
    'digital_fun' => LineIconKind.digitalFun,
    'travel_vacation' => LineIconKind.travelVacation,
    'hobby' => LineIconKind.hobby,
    // 医疗健康 Medical
    'clinic' => LineIconKind.clinic,
    'wellness' => LineIconKind.wellness,
    'checkup' => LineIconKind.checkup,
    'insurance' => LineIconKind.insurance,
    // 学习办公 Study
    'knowledge' => LineIconKind.knowledge,
    'stationery' => LineIconKind.stationery,
    // 人情往来 Social
    'social' => LineIconKind.giftRibbon,
    'red_packet' => LineIconKind.redPacket,
    // 宠物 Pet
    'pet' || 'pets' => LineIconKind.petFood,
    'pet_food' => LineIconKind.petFood,
    'pet_supply' => LineIconKind.petSupply,
    'pet_medical' => LineIconKind.petMedical,
    'pet_service' => LineIconKind.petService,
    // 资金往来 Funds
    'funds' => LineIconKind.funds,
    'repay' => LineIconKind.repay,
    'lend' => LineIconKind.lend,
    'accrue' => LineIconKind.accrue,
    'withdrawal' => LineIconKind.withdrawal,
    'internal_transfer' => LineIconKind.internalTransfer,
    // 存款 Deposit
    'deposit_in' => LineIconKind.depositIn,
    'deposit_out' => LineIconKind.depositOut,
    // 借还系统分类 Lend
    'borrow_in' => LineIconKind.borrowIn,
    'lend_out' => LineIconKind.lendOut,
    'repay_debt' => LineIconKind.repayDebt,
    'collect_debt' => LineIconKind.collectDebt,
    'debt_reduce' => LineIconKind.debtReduce,
    'bad_debt' => LineIconKind.badDebt,
    'reimburse_income' => LineIconKind.reimburseIncome,
    // 投资支出 Invest
    'tax' => LineIconKind.tax,
    'finance' => LineIconKind.finance,
    'dividend' => LineIconKind.dividend,
    'operations' => LineIconKind.operations,
    'capex' => LineIconKind.capex,
    // 收入分类 Income（记一笔·收入树）
    'income_job' => LineIconKind.incomeJob,
    'income_business' => LineIconKind.incomeBusiness,
    'income_side' => LineIconKind.incomeSide,
    'income_invest' => LineIconKind.trendUp,
    'income_funds' => LineIconKind.funds,
    'performance_bonus' => LineIconKind.bonusTrophy,
    'allowance' => LineIconKind.allowance,
    'sole_proprietor' => LineIconKind.soleProprietor,
    'rider' => LineIconKind.rider,
    'video_income' => LineIconKind.videoIncome,
    'securities' => LineIconKind.securities,
    'interest' => LineIconKind.interest,
    'refund_cashback' => LineIconKind.refundArrow,
    'repayment' => LineIconKind.repay,
    'social_income' => LineIconKind.giftRibbon,
    'tax_reimburse' => LineIconKind.reimbursement,
    'parttime' => LineIconKind.briefcase,
    'other' => LineIconKind.otherDots,
    'settings' => LineIconKind.settings,
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
      case LineIconKind.otherDots:
        _otherDots(path);
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
      case LineIconKind.close:
        _close(path);
      case LineIconKind.info:
        _info(path);
      case LineIconKind.person:
        _person(path);
      case LineIconKind.breakfast:
        _breakfast(path);
      case LineIconKind.lunch:
        _lunch(path);
      case LineIconKind.dinner:
        _dinner(path);
      case LineIconKind.beverage:
        _beverage(path);
      case LineIconKind.coupon:
        _coupon(path);
      case LineIconKind.skewer:
        _skewer(path);
      case LineIconKind.coffee:
        _coffee(path);
      case LineIconKind.milkTea:
        _milkTea(path);
      case LineIconKind.juice:
        _juice(path);
      case LineIconKind.dimSum:
        _dimSum(path);
      case LineIconKind.produce:
        _produce(path);
      case LineIconKind.snack:
        _snack(path);
      case LineIconKind.shipping:
        _shipping(path);
      case LineIconKind.apparel:
        _apparel(path);
      case LineIconKind.beauty:
        _beauty(path);
      case LineIconKind.digital:
        _digital(path);
      case LineIconKind.consumable:
        _consumable(path);
      case LineIconKind.tobacco:
        _tobacco(path);
      case LineIconKind.furniture:
        _furniture(path);
      case LineIconKind.personalCare:
        _personalCare(path);
      case LineIconKind.travel:
        _travel(path);
      case LineIconKind.carCare:
        _carCare(path);
      case LineIconKind.transit:
        _transit(path);
      case LineIconKind.fuel:
        _fuel(path);
      case LineIconKind.taxiRental:
        _taxiRental(path);
      case LineIconKind.intercity:
        _intercity(path);
      case LineIconKind.renovation:
        _renovation(path);
      case LineIconKind.rent:
        _rent(path);
      case LineIconKind.utilities:
        _utilities(path);
      case LineIconKind.telecom:
        _telecom(path);
      case LineIconKind.lodging:
        _lodging(path);
      case LineIconKind.fun:
        _fun(path);
      case LineIconKind.fitness:
        _fitness(path);
      case LineIconKind.offlineFun:
        _offlineFun(path);
      case LineIconKind.digitalFun:
        _digitalFun(path);
      case LineIconKind.travelVacation:
        _travelVacation(path);
      case LineIconKind.hobby:
        _hobby(path);
      case LineIconKind.clinic:
        _clinic(path);
      case LineIconKind.wellness:
        _wellness(path);
      case LineIconKind.checkup:
        _checkup(path);
      case LineIconKind.insurance:
        _insurance(path);
      case LineIconKind.knowledge:
        _knowledge(path);
      case LineIconKind.stationery:
        _stationery(path);
      case LineIconKind.petFood:
        _petFood(path);
      case LineIconKind.petSupply:
        _petSupply(path);
      case LineIconKind.petMedical:
        _petMedical(path);
      case LineIconKind.petService:
        _petService(path);
      case LineIconKind.funds:
        _funds(path);
      case LineIconKind.repay:
        _repay(path);
      case LineIconKind.lend:
        _lend(path);
      case LineIconKind.accrue:
        _accrue(path);
      case LineIconKind.withdrawal:
        _withdrawal(path);
      case LineIconKind.internalTransfer:
        _internalTransfer(path);
      case LineIconKind.depositIn:
        _depositIn(path);
      case LineIconKind.depositOut:
        _depositOut(path);
      case LineIconKind.borrowIn:
        _borrowIn(path);
      case LineIconKind.lendOut:
        _lendOut(path);
      case LineIconKind.repayDebt:
        _repayDebt(path);
      case LineIconKind.collectDebt:
        _collectDebt(path);
      case LineIconKind.debtReduce:
        _debtReduce(path);
      case LineIconKind.badDebt:
        _badDebt(path);
      case LineIconKind.reimburseIncome:
        _reimburseIncome(path);
      case LineIconKind.tax:
        _tax(path);
      case LineIconKind.finance:
        _finance(path);
      case LineIconKind.dividend:
        _dividend(path);
      case LineIconKind.operations:
        _operations(path);
      case LineIconKind.capex:
        _capex(path);
      case LineIconKind.incomeJob:
        _incomeJob(path);
      case LineIconKind.bonusTrophy:
        _bonusTrophy(path);
      case LineIconKind.allowance:
        _allowance(path);
      case LineIconKind.incomeBusiness:
        _incomeBusiness(path);
      case LineIconKind.soleProprietor:
        _soleProprietor(path);
      case LineIconKind.incomeSide:
        _incomeSide(path);
      case LineIconKind.rider:
        _rider(path);
      case LineIconKind.videoIncome:
        _videoIncome(path);
      case LineIconKind.securities:
        _securities(path);
      case LineIconKind.interest:
        _interest(path);
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
    _line(p, 3.5, 10.5, 12, 6.5);
    _line(p, 12, 6.5, 20.5, 10.5);
    _line(p, 4, 10.5, 20, 10.5);
    _line(p, 5.5, 10.5, 5.5, 16.5);
    _line(p, 9, 10.5, 9, 16.5);
    _line(p, 15, 10.5, 15, 16.5);
    _line(p, 18.5, 10.5, 18.5, 16.5);
    _line(p, 3.5, 17.5, 20.5, 17.5);
  }

  void _reimbursement(Path p) {
    p.moveTo(6, 5.25);
    p.lineTo(18, 5.25);
    p.lineTo(18, 18.75);
    p.lineTo(16, 17.35);
    p.lineTo(14, 18.75);
    p.lineTo(12, 17.35);
    p.lineTo(10, 18.75);
    p.lineTo(8, 17.35);
    p.lineTo(6, 18.75);
    p.close();
    _line(p, 9, 9.25, 15, 9.25);
    _line(p, 9, 12.25, 15, 12.25);
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
    p.moveTo(4.5, 12);
    p.lineTo(12, 4.5);
    p.lineTo(19.5, 4.5);
    p.lineTo(19.5, 12);
    p.lineTo(12, 19.5);
    p.close();
    p.addOval(Rect.fromCircle(center: const Offset(16, 8.5), radius: 1.4));
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
    _line(p, 4.5, 12.5, 19.5, 12.5);
    p.moveTo(6, 12.5);
    p.cubicTo(6, 16.7, 8.7, 19.5, 12, 19.5);
    p.cubicTo(15.3, 19.5, 18, 16.7, 18, 12.5);
    _line(p, 9.5, 4.5, 11.5, 10.5);
    _line(p, 12.5, 4.5, 13.8, 10.5);
  }

  /// 早餐：煎蛋（有机蛋白轮廓 + 蛋黄）。
  void _breakfast(Path p) {
    p.moveTo(7.25, 9);
    p.cubicTo(6.75, 6.5, 10.25, 5, 12.75, 5.5);
    p.cubicTo(16.25, 6, 18.25, 9, 17.25, 12.5);
    p.cubicTo(18.75, 16, 15.25, 19, 11.75, 18.5);
    p.cubicTo(7.75, 19, 5.25, 15.5, 6.25, 12);
    p.cubicTo(5.75, 11, 6.25, 10, 7.25, 9);
    p.close();
    p.addOval(Rect.fromCircle(center: const Offset(11.75, 12), radius: 2.6));
  }

  /// 午餐：便当盒（圆角盒 + 提手 + 分隔）。
  void _lunch(Path p) {
    p.addRRect(RRect.fromLTRBXY(5, 7.85, 19, 18.85, 2, 2));
    p.moveTo(10, 7.85);
    p.lineTo(10, 6.05);
    p.quadraticBezierTo(10, 5.15, 11, 5.15);
    p.lineTo(13, 5.15);
    p.quadraticBezierTo(14, 5.15, 14, 6.05);
    p.lineTo(14, 7.85);
    p.moveTo(5, 13.35);
    p.lineTo(19, 13.35);
  }

  /// 晚餐：圆顶罩盘（餐盖 + 顶钮 + 餐盘）。
  void _dinner(Path p) {
    p.moveTo(6.5, 14.85);
    p.cubicTo(6.5, 6.85, 17.5, 6.85, 17.5, 14.85);
    p.addOval(Rect.fromLTRB(4, 14.25, 20, 17.45));
    p.addOval(Rect.fromCircle(center: const Offset(12, 7.65), radius: 1.1));
  }

  /// 饮品：带吸管外带杯（杯身 + 盖 + 吸管）。
  void _beverage(Path p) {
    p.moveTo(8, 9.4);
    p.lineTo(9.2, 20.4);
    p.lineTo(14.8, 20.4);
    p.lineTo(16, 9.4);
    p.close();
    p.addRRect(RRect.fromLTRBXY(7.2, 7.4, 16.8, 9.8, 1, 1));
    p.moveTo(13, 7.4);
    p.lineTo(14.6, 3.6);
  }

  /// 团购券：票券（圆角票 + 两侧缺口 + ¥ 印记）。
  void _coupon(Path p) {
    p.addRRect(RRect.fromLTRBXY(4, 7.5, 20, 16.5, 2, 2));
    p.addOval(Rect.fromCircle(center: const Offset(4, 12), radius: 1.6));
    p.addOval(Rect.fromCircle(center: const Offset(20, 12), radius: 1.6));
    p.moveTo(12, 9.5);
    p.lineTo(12, 14.5);
    p.moveTo(10.2, 10);
    p.lineTo(12, 11.4);
    p.lineTo(13.8, 10);
    p.moveTo(10.2, 11.5);
    p.lineTo(13.8, 11.5);
    p.moveTo(10.4, 13.2);
    p.lineTo(13.6, 13.2);
  }

  /// 风味小吃：串签（签子 + 三颗串珠）。
  void _skewer(Path p) {
    p.moveTo(5.25, 18.75);
    p.lineTo(18.75, 5.25);
    p.addOval(Rect.fromCircle(center: const Offset(9.25, 14.75), radius: 2.2));
    p.addOval(Rect.fromCircle(center: const Offset(12.25, 11.75), radius: 2.2));
    p.addOval(Rect.fromCircle(center: const Offset(15.25, 8.75), radius: 2.2));
  }

  /// 交通：巴士。
  void _bus(Path p) {
    p.addRRect(RRect.fromLTRBXY(5, 4.35, 19, 16.85, 2.5, 2.5));
    _line(p, 5, 10.85, 19, 10.85);
    p.addOval(Rect.fromCircle(center: const Offset(9, 18.35), radius: 1.3));
    p.addOval(Rect.fromCircle(center: const Offset(15, 18.35), radius: 1.3));
  }

  /// 购物：购物袋。
  void _shoppingBag(Path p) {
    p.moveTo(7.5, 6.75);
    p.lineTo(16.5, 6.75);
    p.lineTo(17.5, 18.25);
    p.lineTo(6.5, 18.25);
    p.close();
    p.moveTo(9.5, 6.75);
    p.lineTo(9.5, 5.75);
    p.arcToPoint(
      const Offset(14.5, 5.75),
      radius: const Radius.circular(2.5),
    );
    p.lineTo(14.5, 6.75);
  }

  /// 居住：小屋。
  void _house(Path p) {
    _line(p, 4.5, 10.75, 12, 4.75);
    _line(p, 12, 4.75, 19.5, 10.75);
    p.moveTo(6.5, 10.75);
    p.lineTo(6.5, 19.25);
    p.lineTo(17.5, 19.25);
    p.lineTo(17.5, 10.75);
    _line(p, 10, 19.25, 10, 14.75);
    _line(p, 10, 14.75, 14, 14.75);
    _line(p, 14, 14.75, 14, 19.25);
  }

  /// 娱乐：音符。
  void _musicNote(Path p) {
    _line(p, 10, 17.15, 10, 6.65);
    _line(p, 10, 6.65, 18, 4.85);
    _line(p, 18, 4.85, 18, 14.65);
    p.addOval(Rect.fromCircle(center: const Offset(8, 17.15), radius: 2));
    p.addOval(Rect.fromCircle(center: const Offset(16, 14.65), radius: 2));
  }

  /// 医疗：十字。
  void _medicalCross(Path p) {
    _line(p, 12, 5, 12, 19);
    _line(p, 5, 12, 19, 12);
  }

  /// 教育：翻开的书。
  void _openBook(Path p) {
    p.moveTo(12, 8.6);
    p.cubicTo(10, 7.1, 7, 7.1, 5.5, 8.3);
    p.lineTo(5.5, 16.9);
    p.cubicTo(7, 15.7, 10, 15.7, 12, 16.9);
    p.cubicTo(14, 15.7, 17, 15.7, 18.5, 16.9);
    p.lineTo(18.5, 8.3);
    p.cubicTo(17, 7.1, 14, 7.1, 12, 8.6);
    p.close();
    _line(p, 12, 8.6, 12, 16.9);
  }

  /// 通讯：手机。
  void _smartphone(Path p) {
    p.addRRect(RRect.fromLTRBXY(7.5, 3, 16.5, 21, 2.5, 2.5));
    _line(p, 10.5, 18.5, 13.5, 18.5);
  }

  /// 人情：礼盒 + 缎带 + 蝴蝶结。
  void _giftRibbon(Path p) {
    p.addRRect(RRect.fromLTRBXY(5.5, 8, 18.5, 18.5, 1.5, 1.5));
    _line(p, 12, 8, 12, 18.5);
    _line(p, 12, 8, 9, 5.5);
    _line(p, 12, 8, 15, 5.5);
    p.addOval(Rect.fromCircle(center: const Offset(12, 8), radius: 1.1));
  }

  /// 其他：星。
  void _star(Path p) {
    p.moveTo(12, 4.2);
    p.lineTo(14.5, 9.7);
    p.lineTo(20.3, 10.3);
    p.lineTo(15.9, 14.2);
    p.lineTo(17.2, 19.8);
    p.lineTo(12, 16.6);
    p.lineTo(6.8, 19.8);
    p.lineTo(8.1, 14.2);
    p.lineTo(3.7, 10.3);
    p.lineTo(9.5, 9.7);
    p.close();
  }

  /// 其他：四点格（2×2 圆点，杂项/更多）。
  /// 其他：三圆点（更多 / other）。
  /// painter 为纯描边，小半径 + 1.7 线宽在显示尺寸下接近实心点。
  void _otherDots(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(6, 12), radius: 1.5));
    p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 1.5));
    p.addOval(Rect.fromCircle(center: const Offset(18, 12), radius: 1.5));
  }

  /// 工资：钱袋 ¥。
  void _moneyBag(Path p) {
    p.moveTo(6, 9.75);
    p.cubicTo(6, 7.15, 9, 5.95, 12, 5.95);
    p.cubicTo(15, 5.95, 18, 7.15, 18, 9.75);
    p.cubicTo(18, 14.75, 14.7, 18.05, 12, 18.05);
    p.cubicTo(9.3, 18.05, 6, 14.75, 6, 9.75);
    p.close();
    _line(p, 12, 9.25, 12, 14.75);
    _line(p, 9.7, 11.45, 14.3, 11.45);
    _line(p, 10.4, 13.55, 13.6, 13.55);
  }

  /// 兼职/工作：公文包。
  void _briefcase(Path p) {
    p.addRRect(RRect.fromLTRBXY(4.5, 7.35, 19.5, 18.35, 2, 2));
    p.moveTo(9, 7.35);
    p.lineTo(9, 5.65);
    p.arcToPoint(
      const Offset(15, 5.65),
      radius: const Radius.circular(3),
    );
    p.lineTo(15, 7.35);
    _line(p, 4.5, 11.85, 19.5, 11.85);
  }

  /// 理财/投资：上升折线 + 箭头。
  void _trendUp(Path p) {
    _line(p, 4, 17.25, 9, 12.25);
    _line(p, 9, 12.25, 12.5, 15.25);
    _line(p, 12.5, 15.25, 20, 6.75);
    _line(p, 15.5, 6.75, 20, 6.75);
    _line(p, 20, 6.75, 20, 11.25);
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
    p.addRRect(RRect.fromLTRBXY(5, 8, 19, 16, 1.5, 1.5));
    _line(p, 15, 12, 12, 12);
    _line(p, 12, 12, 13.6, 10.5);
    _line(p, 12, 12, 13.6, 13.5);
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
    p.moveTo(17.5, 2.5);
    p.lineTo(21.5, 6.5);
    p.lineTo(8, 20);
    p.lineTo(2.5, 21.5);
    p.lineTo(4, 16);
    p.lineTo(17.5, 2.5);
    p.close();
  }

  /// 右箭头：跳转指示（›）。
  void _chevronRight(Path p) {
    _line(p, 8.5, 5, 15.5, 12);
    _line(p, 15.5, 12, 8.5, 19);
  }

  /// 关闭：两条对角线交叉成 ×。
  void _close(Path p) {
    _line(p, 6.5, 6.5, 17.5, 17.5);
    _line(p, 17.5, 6.5, 6.5, 17.5);
  }

  /// 信息：圆圈 + 顶部小圆点 + 下方竖杠（i）。
  void _info(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 8));
    p.addOval(Rect.fromCircle(center: const Offset(12, 8.4), radius: 0.95));
    _line(p, 12, 10.6, 12, 16);
  }

  /// 人数：圆形头像 + 肩线，表示「人 / 收款对象」。
  void _person(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 8.5), radius: 3.5));
    _line(p, 5.5, 19, 12, 14.5);
    _line(p, 12, 14.5, 18.5, 19);
  }

  /// 咖啡（Coffee）。
  void _coffee(Path p) {
    p.moveTo(5.5, 11.5);
    p.lineTo(5.5, 17.5);
    p.quadraticBezierTo(5.5, 19.5, 7.5, 19.5);
    p.lineTo(12.5, 19.5);
    p.quadraticBezierTo(14.5, 19.5, 14.5, 17.5);
    p.lineTo(14.5, 11.5);
    p.close();
    p.moveTo(14.5, 12.5);
    p.lineTo(17.5, 12.5);
    p.quadraticBezierTo(18.5, 14.5, 16.5, 16.5);
    _line(p, 7.5, 8.5, 12.5, 8.5);
    p.moveTo(8.5, 5.5);
    p.quadraticBezierTo(9.5, 4.5, 10.5, 5.5);
    p.quadraticBezierTo(11.5, 6.5, 12.5, 5.5);
  }

  /// 奶茶（Milk Tea）。
  void _milkTea(Path p) {
    p.moveTo(8, 8.5);
    p.lineTo(9, 19.5);
    p.lineTo(15, 19.5);
    p.lineTo(16, 8.5);
    p.close();
    _line(p, 7.5, 8.5, 16.5, 8.5);
    _line(p, 10, 4.5, 11, 8.5);
    p.addOval(Rect.fromCircle(center: const Offset(11, 16.5), radius: 1));
    p.addOval(Rect.fromCircle(center: const Offset(13, 17.5), radius: 1));
  }

  /// 果汁（Juice）。
  void _juice(Path p) {
    p.moveTo(6.75, 9.5);
    p.lineTo(7.75, 19.5);
    p.lineTo(13.75, 19.5);
    p.lineTo(14.75, 9.5);
    p.close();
    _line(p, 6.25, 9.5, 15.25, 9.5);
    _line(p, 11.75, 9.5, 13.25, 4.5);
    p.addOval(Rect.fromCircle(center: const Offset(15.75, 6.5), radius: 2));
    _line(p, 15.75, 4.5, 15.75, 8.5);
    _line(p, 13.75, 6.5, 17.75, 6.5);
  }

  /// 点心（Dim Sum）。
  void _dimSum(Path p) {
    p.addOval(Rect.fromLTRB(5, 14.75, 19, 19.75));
    p.moveTo(5, 17.25);
    p.lineTo(5, 11.25);
    p.quadraticBezierTo(12, 8.25, 19, 11.25);
    p.lineTo(19, 17.25);
    _line(p, 5, 14.25, 19, 14.25);
    p.moveTo(10, 6.25);
    p.quadraticBezierTo(11, 4.25, 12, 6.25);
    p.moveTo(14, 6.25);
    p.quadraticBezierTo(15, 4.25, 16, 6.25);
  }

  /// 果蔬蛋奶（Produce）。
  void _produce(Path p) {
    p.moveTo(6, 12);
    p.lineTo(18, 12);
    p.lineTo(16.5, 19);
    p.lineTo(7.5, 19);
    p.close();
    p.moveTo(7.5, 12);
    p.lineTo(8.5, 19);
    p.moveTo(10, 12);
    p.lineTo(10.5, 19);
    p.moveTo(14, 12);
    p.lineTo(13.5, 19);
    p.moveTo(16.5, 12);
    p.lineTo(15.5, 19);
    p.addOval(Rect.fromCircle(center: const Offset(12, 9), radius: 2));
    p.moveTo(12, 7);
    p.quadraticBezierTo(13.5, 5, 15, 6);
  }

  /// 零食（Snack）。
  void _snack(Path p) {
    p.addOval(Rect.fromLTRB(5, 7, 21, 17));
    p.addOval(Rect.fromCircle(center: const Offset(10, 11), radius: 1));
    p.addOval(Rect.fromCircle(center: const Offset(15, 10), radius: 1));
    p.addOval(Rect.fromCircle(center: const Offset(16, 13), radius: 1));
    p.moveTo(5, 12);
    p.lineTo(3, 11);
    p.moveTo(5, 12);
    p.lineTo(3, 13);
  }

  /// 运费（Shipping）。
  void _shipping(Path p) {
    p.addRRect(RRect.fromLTRBXY(6, 6, 18, 15, 1, 1));
    p.moveTo(6, 9);
    p.lineTo(12, 12);
    p.lineTo(18, 9);
    p.moveTo(12, 12);
    p.lineTo(12, 6);
    p.moveTo(9, 15);
    p.lineTo(12, 18);
    p.lineTo(15, 15);
  }

  /// 服饰鞋包（Apparel）。
  void _apparel(Path p) {
    p.moveTo(12, 5);
    p.lineTo(12, 7);
    p.moveTo(7, 13);
    p.quadraticBezierTo(12, 8, 17, 13);
    p.moveTo(7, 13);
    p.lineTo(9, 19);
    p.lineTo(15, 19);
    p.lineTo(17, 13);
    p.moveTo(9, 13);
    p.lineTo(9, 19);
    p.moveTo(15, 13);
    p.lineTo(15, 19);
  }

  /// 美妆护肤（Beauty）。
  void _beauty(Path p) {
    p.addRRect(RRect.fromLTRBXY(8.15, 4, 12.15, 11, 1, 1));
    p.addRRect(RRect.fromLTRBXY(7.15, 11, 13.15, 20, 1, 1));
    _line(p, 8.15, 7, 12.15, 7);
    p.addOval(Rect.fromCircle(center: const Offset(14.65, 15), radius: 2.2));
  }

  /// 数码电器（Electronics）。
  void _digital(Path p) {
    p.addRRect(RRect.fromLTRBXY(5, 5.5, 19, 14.5, 1.5, 1.5));
    p.moveTo(9, 18.5);
    p.lineTo(15, 18.5);
    _line(p, 12, 14.5, 12, 18.5);
  }

  /// 生活耗材（Consumables）。
  void _consumable(Path p) {
    p.addRRect(RRect.fromLTRBXY(5.5, 7.5, 15.5, 16.5, 2, 2));
    p.addOval(Rect.fromCircle(center: const Offset(10.5, 12), radius: 2));
    p.moveTo(15.5, 9.5);
    p.lineTo(18.5, 9.5);
    p.moveTo(15.5, 12.5);
    p.lineTo(18.5, 12.5);
  }

  /// 烟酒茶糖（Tobacco）。
  void _tobacco(Path p) {
    p.moveTo(7.5, 5.5);
    p.lineTo(13.5, 5.5);
    p.lineTo(12, 11.5);
    p.quadraticBezierTo(10.5, 13.5, 9, 11.5);
    p.close();
    _line(p, 10.5, 13.5, 10.5, 18.5);
    _line(p, 8, 18.5, 13, 18.5);
    p.moveTo(14.5, 6.5);
    p.quadraticBezierTo(16.5, 8.5, 14.5, 10.5);
  }

  /// 家居家具（Furniture）。
  void _furniture(Path p) {
    p.moveTo(6, 7.5);
    p.lineTo(6, 14.5);
    p.moveTo(18, 7.5);
    p.lineTo(18, 14.5);
    p.moveTo(6, 7.5);
    p.lineTo(18, 7.5);
    p.moveTo(6, 10.5);
    p.lineTo(18, 10.5);
    p.moveTo(8, 14.5);
    p.lineTo(8, 16.5);
    p.moveTo(16, 14.5);
    p.lineTo(16, 16.5);
  }

  /// 个护服务（Personal Care）。
  void _personalCare(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(7.5, 17.5), radius: 2.5));
    p.addOval(Rect.fromCircle(center: const Offset(7.5, 6.5), radius: 2.5));
    _line(p, 9.6, 16.2, 19, 7.5);
    _line(p, 9.6, 7.8, 19, 16.5);
    p.addOval(Rect.fromCircle(center: const Offset(14.3, 12), radius: 0.9));
  }

  /// 出行（Travel）。
  void _travel(Path p) {
    p.moveTo(12, 3);
    p.cubicTo(8.5, 3, 6, 5.5, 6, 9);
    p.cubicTo(6, 13, 12, 21, 12, 21);
    p.cubicTo(12, 21, 18, 13, 18, 9);
    p.cubicTo(18, 5.5, 15.5, 3, 12, 3);
    p.close();
    p.addOval(Rect.fromCircle(center: const Offset(12, 9), radius: 2.5));
  }

  /// 养车（Car Care）。
  void _carCare(Path p) {
    p.moveTo(5, 14.85);
    p.lineTo(5, 11.85);
    p.quadraticBezierTo(5, 9.85, 7, 9.85);
    p.lineTo(9, 9.85);
    p.moveTo(9, 9.85);
    p.lineTo(11, 6.85);
    p.lineTo(16, 6.85);
    p.lineTo(18, 9.85);
    p.moveTo(5, 14.85);
    p.lineTo(19, 14.85);
    p.lineTo(19, 17.85);
    p.lineTo(5, 17.85);
    p.close();
    p.addOval(Rect.fromCircle(center: const Offset(8, 17.85), radius: 1.3));
    p.addOval(Rect.fromCircle(center: const Offset(16, 17.85), radius: 1.3));
    p.moveTo(15, 4.85);
    p.lineTo(17, 4.85);
    p.lineTo(18, 7.85);
    p.lineTo(14, 7.85);
    p.close();
  }

  /// 公共交通（Public Transit）。
  void _transit(Path p) {
    p.addRRect(RRect.fromLTRBXY(5, 4.9, 19, 17.9, 2.5, 2.5));
    _line(p, 5, 11.9, 19, 11.9);
    p.addOval(Rect.fromCircle(center: const Offset(8.5, 17.9), radius: 1.2));
    p.addOval(Rect.fromCircle(center: const Offset(15.5, 17.9), radius: 1.2));
    _line(p, 8, 7.9, 16, 7.9);
  }

  /// 加油充电（Fuel/Charge）。
  void _fuel(Path p) {
    p.addRRect(RRect.fromLTRBXY(6.5, 8.5, 14.5, 19.5, 1.5, 1.5));
    _line(p, 6.5, 11.5, 14.5, 11.5);
    p.moveTo(14.5, 12.5);
    p.lineTo(17.5, 12.5);
    p.lineTo(17.5, 16.5);
    p.lineTo(14.5, 16.5);
    p.moveTo(11.5, 4.5);
    p.lineTo(9.5, 9.5);
    p.lineTo(12.5, 9.5);
    p.lineTo(10.5, 14.5);
  }

  /// 打车租车（Taxi/Rental）。
  void _taxiRental(Path p) {
    p.moveTo(5, 14.85);
    p.lineTo(5, 11.85);
    p.quadraticBezierTo(5, 9.85, 7, 9.85);
    p.lineTo(9, 9.85);
    p.moveTo(9, 9.85);
    p.lineTo(11, 6.85);
    p.lineTo(16, 6.85);
    p.lineTo(18, 9.85);
    p.moveTo(5, 14.85);
    p.lineTo(19, 14.85);
    p.lineTo(19, 17.85);
    p.lineTo(5, 17.85);
    p.close();
    p.addOval(Rect.fromCircle(center: const Offset(8, 17.85), radius: 1.3));
    p.addOval(Rect.fromCircle(center: const Offset(16, 17.85), radius: 1.3));
    p.addOval(Rect.fromCircle(center: const Offset(15, 6.85), radius: 2));
    p.moveTo(15, 8.85);
    p.lineTo(15, 11.85);
    p.lineTo(18, 11.85);
  }

  /// 城际出行（Intercity）。
  void _intercity(Path p) {
    p.addRRect(RRect.fromLTRBXY(7, 6.4, 17, 17.4, 2, 2));
    _line(p, 7, 11.4, 17, 11.4);
    p.addOval(Rect.fromCircle(center: const Offset(10, 18.4), radius: 1.2));
    p.addOval(Rect.fromCircle(center: const Offset(14, 18.4), radius: 1.2));
    _line(p, 10, 6.4, 10, 4.4);
    _line(p, 14, 6.4, 14, 4.4);
  }

  /// 装修维护（Renovation）。
  void _renovation(Path p) {
    p.addRRect(RRect.fromLTRBXY(6, 5, 15, 9, 1, 1));
    _line(p, 10, 9, 10, 14);
    _line(p, 10, 14, 14, 14);
    _line(p, 6, 19, 18, 19);
  }

  /// 房租房贷（Rent/Mortgage）。
  void _rent(Path p) {
    _line(p, 4.5, 10.75, 12, 4.75);
    _line(p, 12, 4.75, 19.5, 10.75);
    _line(p, 7, 10.75, 7, 19.25);
    _line(p, 17, 10.75, 17, 19.25);
    p.addOval(Rect.fromCircle(center: const Offset(14, 13.75), radius: 1.4));
  }

  /// 水电燃物（Utilities）。
  void _utilities(Path p) {
    p.moveTo(12, 4);
    p.cubicTo(12, 4, 6, 10, 6, 14);
    p.cubicTo(6, 17.3, 8.7, 20, 12, 20);
    p.cubicTo(15.3, 20, 18, 17.3, 18, 14);
    p.cubicTo(18, 10, 12, 4, 12, 4);
    p.close();
    p.moveTo(13.2, 10.5);
    p.lineTo(10.6, 14.6);
    p.lineTo(12.7, 14.6);
    p.lineTo(11.2, 18);
  }

  /// 话费网费（Telecom）。
  void _telecom(Path p) {
    p.addRRect(RRect.fromLTRBXY(9, 4, 17, 20, 2, 2));
    _line(p, 12, 17, 14, 17);
    p.moveTo(7, 8);
    p.quadraticBezierTo(10, 5, 13, 8);
    p.moveTo(9, 10);
    p.quadraticBezierTo(11, 8, 13, 10);
  }

  /// 住宿（Lodging）。
  void _lodging(Path p) {
    _line(p, 4, 8, 4, 16);
    _line(p, 20, 11, 20, 16);
    _line(p, 4, 11, 20, 11);
    p.moveTo(4, 8);
    p.lineTo(9, 8);
    p.lineTo(9, 11);
    _line(p, 4, 16, 20, 16);
  }

  /// 娱乐（Entertainment）。
  void _fun(Path p) {
    p.moveTo(6, 8);
    p.quadraticBezierTo(12, 5, 18, 8);
    p.quadraticBezierTo(18, 15, 12, 19);
    p.quadraticBezierTo(6, 15, 6, 8);
    p.close();
    p.addOval(Rect.fromCircle(center: const Offset(9.5, 11), radius: 1));
    p.addOval(Rect.fromCircle(center: const Offset(14.5, 11), radius: 1));
    p.moveTo(9, 14);
    p.quadraticBezierTo(12, 17, 15, 14);
  }

  /// 运动健身（Fitness）。
  void _fitness(Path p) {
    _line(p, 5, 9, 5, 15);
    _line(p, 7, 8, 7, 16);
    _line(p, 17, 8, 17, 16);
    _line(p, 19, 9, 19, 15);
    _line(p, 7, 12, 17, 12);
  }

  /// 线下娱乐（Offline Fun）。
  void _offlineFun(Path p) {
    p.addRRect(RRect.fromLTRBXY(4, 7.5, 20, 16.5, 2, 2));
    _line(p, 12, 7.5, 12, 16.5);
    _line(p, 7, 10.5, 9, 10.5);
    _line(p, 7, 13, 9, 13);
  }

  /// 数字娱乐（Digital Fun）。
  void _digitalFun(Path p) {
    p.addRRect(RRect.fromLTRBXY(8, 4, 16, 20, 2, 2));
    p.moveTo(11, 10);
    p.lineTo(11, 14);
    p.lineTo(14, 12);
    p.close();
  }

  /// 旅游度假（Vacation）。
  void _travelVacation(Path p) {
    p.addRRect(RRect.fromLTRBXY(5.75, 9.25, 17.75, 20.25, 2, 2));
    p.moveTo(8.75, 9.25);
    p.lineTo(8.75, 7.25);
    p.lineTo(14.75, 7.25);
    p.lineTo(14.75, 9.25);
    _line(p, 5.75, 14.25, 17.75, 14.25);
    p.addOval(Rect.fromCircle(center: const Offset(16.75, 6.25), radius: 1.5));
    _line(p, 16.75, 3.75, 16.75, 4.75);
    _line(p, 15.25, 6.25, 18.25, 6.25);
  }

  /// 收藏爱好（Hobby）。
  void _hobby(Path p) {
    p.addRRect(RRect.fromLTRBXY(5, 6, 19, 18, 1.5, 1.5));
    p.moveTo(8, 15);
    p.lineTo(11, 11);
    p.lineTo(13, 13);
    p.lineTo(16, 9);
    p.lineTo(17, 10);
    p.addOval(Rect.fromCircle(center: const Offset(9, 9), radius: 1));
  }

  /// 就医购药（Clinic）。
  void _clinic(Path p) {
    p.addRRect(RRect.fromLTRBXY(8.5, 4.5, 15.5, 19.5, 3.5, 3.5));
    _line(p, 12, 9.5, 12, 14.5);
    _line(p, 9.5, 12, 14.5, 12);
  }

  /// 养生保健（Wellness）。
  void _wellness(Path p) {
    p.moveTo(12, 4);
    p.cubicTo(6, 8, 6, 16, 12, 20);
    p.cubicTo(18, 16, 18, 8, 12, 4);
    p.close();
    _line(p, 12, 6, 12, 18);
    p.moveTo(9, 10);
    p.quadraticBezierTo(12, 8, 15, 10);
  }

  /// 体检疫苗（Checkup）。
  void _checkup(Path p) {
    _line(p, 5, 5.5, 9, 9.5);
    _line(p, 8, 4.5, 10, 6.5);
    _line(p, 9, 9.5, 15, 15.5);
    _line(p, 13, 13.5, 19, 19.5);
    _line(p, 15, 11.5, 17, 13.5);
    _line(p, 14, 16.5, 16, 18.5);
  }

  /// 商业保险（Insurance）。
  void _insurance(Path p) {
    p.moveTo(4, 11.5);
    p.quadraticBezierTo(12, 4.5, 20, 11.5);
    p.close();
    _line(p, 12, 11.5, 12, 17.5);
    p.moveTo(12, 17.5);
    p.quadraticBezierTo(12, 19.5, 14, 19.5);
  }

  /// 知识付费（Knowledge）。
  void _knowledge(Path p) {
    p.moveTo(4, 8.75);
    p.lineTo(12, 4.75);
    p.lineTo(20, 8.75);
    p.lineTo(12, 12.75);
    p.close();
    _line(p, 12, 12.75, 12, 16.75);
    _line(p, 18, 9.75, 18, 13.75);
    p.addOval(Rect.fromCircle(center: const Offset(15, 17.75), radius: 1.5));
  }

  /// 图文工具（Stationery）。
  void _stationery(Path p) {
    p.moveTo(14, 4.5);
    p.lineTo(19, 9.5);
    p.lineTo(9, 19.5);
    p.lineTo(5, 19.5);
    p.lineTo(5, 15.5);
    p.close();
    _line(p, 14, 4.5, 16, 6.5);
    _line(p, 8, 16.5, 10, 18.5);
  }

  /// 宠物（Pet）。
  void _petFood(Path p) {
    p.moveTo(5, 12);
    p.lineTo(19, 12);
    p.quadraticBezierTo(19, 18, 12, 18);
    p.quadraticBezierTo(5, 18, 5, 12);
    p.close();
    p.addOval(Rect.fromCircle(center: const Offset(11, 14), radius: 1.5));
    p.addOval(Rect.fromCircle(center: const Offset(14, 14), radius: 1.5));
    p.moveTo(10, 8);
    p.quadraticBezierTo(12, 6, 14, 8);
  }

  /// 宠物用品（Pet Supplies）。
  void _petSupply(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 4));
    _line(p, 12, 8, 12, 16);
    _line(p, 8, 12, 16, 12);
    _line(p, 9.5, 9.5, 14.5, 14.5);
    _line(p, 9.5, 14.5, 14.5, 9.5);
  }

  /// 宠物医疗（Pet Medical）。
  void _petMedical(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(11.5, 14.55), radius: 3));
    p.addOval(Rect.fromCircle(center: const Offset(7.5, 9.55), radius: 1.6));
    p.addOval(Rect.fromCircle(center: const Offset(10.5, 8.05), radius: 1.6));
    p.addOval(Rect.fromCircle(center: const Offset(13.5, 8.05), radius: 1.6));
    p.addOval(Rect.fromCircle(center: const Offset(16.5, 9.55), radius: 1.6));
    _line(p, 10, 14.55, 13, 14.55);
    _line(p, 11.5, 13.05, 11.5, 16.05);
  }

  /// 宠物服务（Pet Service）。
  void _petService(Path p) {
    _line(p, 4.5, 10.75, 12, 4.75);
    _line(p, 12, 4.75, 19.5, 10.75);
    _line(p, 6.5, 10.75, 6.5, 19.25);
    _line(p, 17.5, 10.75, 17.5, 19.25);
    p.addOval(Rect.fromCircle(center: const Offset(12, 14.75), radius: 1.8));
  }

  /// 资金往来（Funds）。
  void _funds(Path p) {
    _line(p, 5, 9, 19, 9);
    p.moveTo(16, 6);
    p.lineTo(19, 9);
    p.lineTo(16, 12);
    _line(p, 19, 15, 5, 15);
    p.moveTo(8, 12);
    p.lineTo(5, 15);
    p.lineTo(8, 18);
  }

  /// 还款（Repay）。
  void _repay(Path p) {
    _line(p, 12, 4, 12, 14);
    p.moveTo(8, 10);
    p.lineTo(12, 14);
    p.lineTo(16, 10);
    p.addOval(Rect.fromCircle(center: const Offset(12, 18), radius: 2));
  }

  /// 借款（Lend/Borrow）。
  void _lend(Path p) {
    _line(p, 12, 20, 12, 10);
    p.moveTo(8, 14);
    p.lineTo(12, 10);
    p.lineTo(16, 14);
    p.addOval(Rect.fromCircle(center: const Offset(12, 6), radius: 2));
  }

  /// 计提（Accrual）。
  void _accrue(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(9, 9), radius: 2));
    p.addOval(Rect.fromCircle(center: const Offset(15, 15), radius: 2));
    _line(p, 7, 17, 17, 7);
  }

  /// 取现：信用卡（圆角卡 + 卡面横纹）+ 向下箭头（负债账户取出现金）。
  void _withdrawal(Path p) {
    p.addRRect(RRect.fromLTRBXY(4, 4.5, 20, 10.5, 2, 2));
    _line(p, 4, 7.5, 20, 7.5);
    _line(p, 12, 13, 12, 19.5);
    _line(p, 9.5, 17, 12, 19.5);
    _line(p, 14.5, 17, 12, 19.5);
  }

  /// 内部转账：左右两个账户 + 双向箭头（账户间内部划转）。
  void _internalTransfer(Path p) {
    p.addRRect(RRect.fromLTRBXY(3.5, 9, 8.5, 15, 1.5, 1.5));
    p.addRRect(RRect.fromLTRBXY(15.5, 9, 20.5, 15, 1.5, 1.5));
    _line(p, 8.8, 12, 15.2, 12);
    _line(p, 10.8, 10.4, 8.8, 12);
    _line(p, 10.8, 13.6, 8.8, 12);
    _line(p, 13.2, 10.4, 15.2, 12);
    _line(p, 13.2, 13.6, 15.2, 12);
  }

  // ── 存款 Deposit（储蓄罐 + 罐腹内箭头）──
  // 储蓄罐为存款语义统一底座；存入=罐腹内向下箭头、取出=罐腹内向上箭头区分。
  // 两个图标各自内联完整罐体，便于几何居中审计独立计算（审计脚本按方法体单独求包围盒）。
  // 构图：身体椭圆(14×10) + 猪鼻 + 耳朵 + 投币口 + 两条腿 + **罐腹内短箭头**
  //      （箭头全长 5.5、箭镞宽 3.8，四周留白 ≥2.1，确保与罐壁/罐口线互不相碰）。

  /// 存款存入：储蓄罐 + 罐腹内向下箭头（钱落进罐里）。
  void _depositIn(Path p) {
    // 罐体
    p.addOval(Rect.fromLTRB(5.9, 7.05, 19.9, 17.05));
    p.addOval(Rect.fromLTRB(4.1, 10.55, 6.7, 13.55));
    p.moveTo(8.4, 7.25);
    p.lineTo(9.7, 4.85);
    p.lineTo(11.2, 7.25);
    p.close();
    _line(p, 10.4, 7.25, 15.4, 7.25);
    _line(p, 9.9, 17.05, 9.9, 19.15);
    _line(p, 15.9, 17.05, 15.9, 19.15);
    // 罐腹内向下箭头（钱存入罐）
    _line(p, 12.9, 9.4, 12.9, 14.9);
    _line(p, 12.9, 14.9, 11.0, 13.0);
    _line(p, 12.9, 14.9, 14.8, 13.0);
  }

  /// 存款取出：储蓄罐 + 罐腹内向上箭头（钱从罐里取出）。
  void _depositOut(Path p) {
    // 罐体
    p.addOval(Rect.fromLTRB(5.9, 7.05, 19.9, 17.05));
    p.addOval(Rect.fromLTRB(4.1, 10.55, 6.7, 13.55));
    p.moveTo(8.4, 7.25);
    p.lineTo(9.7, 4.85);
    p.lineTo(11.2, 7.25);
    p.close();
    _line(p, 10.4, 7.25, 15.4, 7.25);
    _line(p, 9.9, 17.05, 9.9, 19.15);
    _line(p, 15.9, 17.05, 15.9, 19.15);
    // 罐腹内向上箭头（钱取出罐）
    _line(p, 12.9, 14.9, 12.9, 9.4);
    _line(p, 12.9, 9.4, 11.0, 11.3);
    _line(p, 12.9, 9.4, 14.8, 11.3);
  }

  // ── 借还系统分类 Lend（落账自动挂分类，用户分类选择器隐藏）──
  // 构图对齐既有 A3 线稿语法：小硬币 r=2.5、票据 12 宽、内部细节 ≤2 条、留白充足。

  /// 借入：硬币 + 钱进箭头（收入方向，借入资金到账）。
  void _borrowIn(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(16, 16), radius: 2.5));
    _line(p, 5.5, 5.5, 12.3, 12.3);
    _line(p, 12.3, 12.3, 9.3, 12.3);
    _line(p, 12.3, 12.3, 12.3, 9.3);
  }

  /// 借出：硬币 + 钱出箭头（支出方向，借出资金离手）。
  void _lendOut(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(8, 16), radius: 2.5));
    _line(p, 11.7, 12.3, 18.5, 5.5);
    _line(p, 18.5, 5.5, 15.5, 5.5);
    _line(p, 18.5, 5.5, 18.5, 8.5);
  }

  /// 还债：欠条 + 侧旁向下箭头（支出，向债主还款）。
  void _repayDebt(Path p) {
    p.addRRect(RRect.fromLTRBXY(4.75, 6.75, 13.75, 17.75, 1.5, 1.5));
    _line(p, 7.25, 10.25, 11.25, 10.25);
    _line(p, 7.25, 13.75, 11.25, 13.75);
    _line(p, 17.25, 6.25, 17.25, 13.25);
    _line(p, 15.25, 11.25, 17.25, 13.25);
    _line(p, 19.25, 11.25, 17.25, 13.25);
  }

  /// 收债：欠条 + 侧旁向上箭头（收入，向欠款人催收）。
  void _collectDebt(Path p) {
    p.addRRect(RRect.fromLTRBXY(10.25, 6.25, 19.25, 17.25, 1.5, 1.5));
    _line(p, 12.75, 9.75, 16.75, 9.75);
    _line(p, 12.75, 13.25, 16.75, 13.25);
    _line(p, 6.75, 17.75, 6.75, 10.75);
    _line(p, 4.75, 12.75, 6.75, 10.75);
    _line(p, 8.75, 12.75, 6.75, 10.75);
  }

  /// 债务消减：欠条 + 下方减号（部分减免 / 打折）。
  void _debtReduce(Path p) {
    p.addRRect(RRect.fromLTRBXY(7, 5.25, 17, 15.25, 1.5, 1.5));
    _line(p, 9.5, 10.25, 14.5, 10.25);
    _line(p, 9, 18.75, 15, 18.75);
  }

  /// 坏账计提：欠条 + 贯穿斜杠（核销 / 坏账作废）。
  void _badDebt(Path p) {
    p.addRRect(RRect.fromLTRBXY(7, 5.25, 17, 15.25, 1.5, 1.5));
    _line(p, 9.5, 10.25, 14.5, 10.25);
    _line(p, 5.5, 18.75, 18.5, 5.75);
  }

  /// 报销收入：锯齿票据 + ¥（报销到账；构图对齐 [_reimbursement]）。
  void _reimburseIncome(Path p) {
    p.moveTo(6, 5.25);
    p.lineTo(18, 5.25);
    p.lineTo(18, 18.75);
    p.lineTo(16, 17.35);
    p.lineTo(14, 18.75);
    p.lineTo(12, 17.35);
    p.lineTo(10, 18.75);
    p.lineTo(8, 17.35);
    p.lineTo(6, 18.75);
    p.close();
    _line(p, 12, 8.75, 12, 13.75);
    _line(p, 9.8, 10.15, 14.2, 10.15);
    _line(p, 10.5, 12.15, 13.5, 12.15);
  }

  /// 缴税（Tax）。
  void _tax(Path p) {
    p.addRRect(RRect.fromLTRBXY(6, 4, 18, 20, 1.5, 1.5));
    _line(p, 9, 9, 15, 9);
    _line(p, 9, 12, 15, 12);
    _line(p, 9, 15, 13, 15);
    _line(p, 12, 6, 12, 9);
    _line(p, 10.5, 7, 13.5, 7);
    _line(p, 10.5, 8, 13.5, 8);
  }

  /// 博彩理财（Finance）。
  void _finance(Path p) {
    _line(p, 5, 19.5, 5, 6.5);
    _line(p, 5, 19.5, 19, 19.5);
    p.moveTo(8, 15.5);
    p.lineTo(11, 11.5);
    p.lineTo(14, 14.5);
    p.lineTo(18, 8.5);
    p.addOval(Rect.fromCircle(center: const Offset(16, 6.5), radius: 2));
  }

  /// 分红入股（Dividend）。
  void _dividend(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 14.5), radius: 5));
    _line(p, 12, 11.5, 12, 14.5);
    _line(p, 10.5, 12.5, 13.5, 12.5);
    _line(p, 12, 4.5, 12, 9.5);
    p.moveTo(9, 6.5);
    p.lineTo(12, 4.5);
    p.lineTo(15, 6.5);
  }

  /// 日常运营（Operations）。
  void _operations(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 3.5));
    _line(p, 12, 5, 12, 7);
    _line(p, 12, 17, 12, 19);
    _line(p, 5, 12, 7, 12);
    _line(p, 17, 12, 19, 12);
    _line(p, 7, 7, 9, 9);
    _line(p, 15, 15, 17, 17);
    _line(p, 17, 7, 15, 9);
    _line(p, 9, 15, 7, 17);
  }

  /// 大额投入（CapEx）。
  void _capex(Path p) {
    p.addRRect(RRect.fromLTRBXY(6, 4.5, 18, 19.5, 1, 1));
    _line(p, 9, 7.5, 9, 9.5);
    _line(p, 12, 7.5, 12, 9.5);
    _line(p, 15, 7.5, 15, 9.5);
    _line(p, 9, 12.5, 9, 14.5);
    _line(p, 12, 12.5, 12, 14.5);
    _line(p, 15, 12.5, 15, 14.5);
  }

  /// 职业收入：工牌（卡片 + 挂绳 + 头像 + 文字线）。
  void _incomeJob(Path p) {
    p.addRRect(RRect.fromLTRBXY(5, 9.45, 19, 18.45, 2, 2));
    _line(p, 10.5, 9.45, 11, 6.45);
    _line(p, 13.5, 9.45, 13, 6.45);
    p.addOval(Rect.fromCircle(center: const Offset(12, 6.45), radius: 0.9));
    p.addOval(Rect.fromCircle(center: const Offset(9, 12.95), radius: 1.4));
    _line(p, 6.5, 16.45, 9, 14.95);
    _line(p, 9, 14.95, 11.5, 16.45);
    _line(p, 13.5, 12.45, 16.5, 12.45);
    _line(p, 13.5, 14.95, 16, 14.95);
  }

  /// 绩效奖金：奖杯（杯体 + 双耳 + 杯柱 + 底座）。
  void _bonusTrophy(Path p) {
    p.moveTo(8, 6.5);
    p.lineTo(16, 6.5);
    p.lineTo(15, 11.5);
    p.quadraticBezierTo(15, 13.5, 12, 13.5);
    p.quadraticBezierTo(9, 13.5, 9, 11.5);
    p.close();
    p.moveTo(6.5, 7.5);
    p.quadraticBezierTo(5, 8.5, 6.5, 10.5);
    p.moveTo(17.5, 7.5);
    p.quadraticBezierTo(19, 8.5, 17.5, 10.5);
    _line(p, 12, 13.5, 12, 16);
    _line(p, 9.5, 17.5, 14.5, 17.5);
    _line(p, 12, 16, 12, 17.5);
  }

  /// 津贴补助：硬币堆 + ¥。
  void _allowance(Path p) {
    p.addOval(Rect.fromLTRB(6, 13, 18, 17));
    p.addOval(Rect.fromLTRB(6, 10, 18, 14));
    p.addOval(Rect.fromLTRB(6, 7, 18, 11));
    _line(p, 12, 7.5, 12, 10.5);
    _line(p, 10.7, 8.3, 13.3, 8.3);
    _line(p, 11, 9.3, 13, 9.3);
  }

  /// 经营收入：门店（锯齿遮阳棚 + 门 + 地）。
  void _incomeBusiness(Path p) {
    _line(p, 4, 7.5, 20, 7.5);
    p.moveTo(4, 7.5);
    p.lineTo(6, 10.5);
    p.lineTo(8, 7.5);
    p.lineTo(10, 10.5);
    p.lineTo(12, 7.5);
    p.lineTo(14, 10.5);
    p.lineTo(16, 7.5);
    p.lineTo(18, 10.5);
    p.lineTo(20, 7.5);
    _line(p, 5, 10.5, 5, 16.5);
    _line(p, 19, 10.5, 19, 16.5);
    _line(p, 5, 16.5, 19, 16.5);
    p.addRRect(RRect.fromLTRBXY(10, 11.5, 14, 16.5, 1, 1));
  }

  /// 个体经营：手推车（车斗 + 顶棚 + 双轮）。
  void _soleProprietor(Path p) {
    p.addRRect(RRect.fromLTRBXY(6, 9.6, 18, 14.6, 1, 1));
    _line(p, 6, 9.6, 12, 5.6);
    _line(p, 18, 9.6, 12, 5.6);
    _line(p, 7, 5.6, 17, 5.6);
    p.addOval(Rect.fromCircle(center: const Offset(9.5, 17.1), radius: 1.3));
    p.addOval(Rect.fromCircle(center: const Offset(16.5, 17.1), radius: 1.3));
  }

  /// 副业兼职：笔记本（屏幕 + 键盘弧 + 内容线）。
  void _incomeSide(Path p) {
    p.addRRect(RRect.fromLTRBXY(6, 4.75, 18, 13.75, 1.5, 1.5));
    _line(p, 4, 16.75, 20, 16.75);
    p.moveTo(4, 16.75);
    p.quadraticBezierTo(12, 19.25, 20, 16.75);
    _line(p, 9, 8.75, 15, 8.75);
    _line(p, 9, 11.75, 15, 11.75);
  }

  /// 骑手：配送电动车（双轮 + 车架 + 外卖箱）。
  void _rider(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(6.5, 15.65), radius: 2.2));
    p.addOval(Rect.fromCircle(center: const Offset(17.5, 15.65), radius: 2.2));
    _line(p, 6.5, 15.65, 12, 12.15);
    _line(p, 12, 12.15, 17.5, 15.65);
    _line(p, 12, 12.15, 12.5, 6.15);
    _line(p, 10, 6.15, 15.5, 6.15);
    p.addRRect(RRect.fromLTRBXY(7.5, 8.15, 11.5, 12.15, 1, 1));
  }

  /// 视频收入：摄像机（机身 + 镜头锥 + 提带 + 录制点）。
  void _videoIncome(Path p) {
    p.addRRect(RRect.fromLTRBXY(5, 9, 15, 17, 1.5, 1.5));
    p.moveTo(15, 11.5);
    p.lineTo(19, 9.5);
    p.lineTo(19, 16.5);
    p.lineTo(15, 14.5);
    p.close();
    _line(p, 9, 9, 9, 7);
    _line(p, 9, 7, 12, 7);
    p.addOval(Rect.fromCircle(center: const Offset(10, 13), radius: 1.3));
  }

  /// 证券收入：K 线（基线 + 两根蜡烛）。
  void _securities(Path p) {
    _line(p, 4, 19, 20, 19);
    _line(p, 8, 6, 8, 18);
    p.addRRect(RRect.fromLTRBXY(6, 9, 10, 14, 1, 1));
    _line(p, 15, 5, 15, 17);
    p.addRRect(RRect.fromLTRBXY(13, 8, 17, 12, 1, 1));
  }

  /// 利息收入：百分号硬币（大圆 + %）。
  void _interest(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 7));
    p.addOval(Rect.fromCircle(center: const Offset(9, 9), radius: 1.6));
    p.addOval(Rect.fromCircle(center: const Offset(15, 15), radius: 1.6));
    _line(p, 7.5, 16.5, 16.5, 7.5);
  }

  @override
  bool shouldRepaint(covariant _LineIconPainter old) =>
      old.kind != kind || old.color != color || old.strokeWidth != strokeWidth;
}
