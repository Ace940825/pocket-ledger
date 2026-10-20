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
  location, // 位置（定位针）
  shieldCheck, // 余额守卫（盾牌 + 对勾）
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
  pet, // 宠物
  petFood, // 宠物食品
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
  installment, // 分期（日历 + ¥，逐期入账）
  cake, // 甜点（蛋糕 + 蜡烛）
  flight, // 机票（纸飞机）
  camera, // 摄影（相机）
  donation, // 公益（手捧爱心）

  // ── 功能 / UI 操作（全局去 Material 图标，2026-10-15）──
  add, // 新增（＋）
  minus, // 减少/移除（－）
  check, // 勾选（✓）
  checkCircle, // 勾选圆（○内✓）
  chevronLeft, // 左向箭头（‹，返回）
  chevronDown, // 下拉展开（⌄）
  chevronUp, // 上收折叠（⌃）
  arrowBack, // 返回（左箭头带尾）
  arrowRight, // 右指箭头（→）
  arrowUpRight, // 右上（↗）
  arrowUpLeft, // 左上（↖）
  arrowDownLeft, // 左下（↙）
  search, // 搜索（放大镜）
  backspace, // 退格（⌫）
  sortDesc, // 排序（降序双箭头 + 底线）
  filter, // 筛选（漏斗）
  sliders, // 调节（三条横向滑轨）
  swapHorizontal, // 横向交换（⇄，转账/内部往来）
  swapVertical, // 纵向交换（⇅）
  wallet, // 钱包（账户/资产）
  bank, // 银行（柱廊）
  card, // 银行卡
  yuan, // 人民币符号（¥）
  percent, // 百分比（%）
  receipt, // 小票（收/支凭证）
  ticket, // 票券（券码）
  barcode, // 条码（票据编号）
  handshake, // 握手（往来）
  chartLine, // 折线图
  chartBar, // 柱状图
  chartPie, // 饼图
  chartCandle, // K 线
  trendDown, // 下降趋势
  sync, // 双向同步
  refresh, // 刷新（环形箭头）
  cloud, // 云
  cloudUp, // 上传云（↑）
  cloudDown, // 下载云（↓）
  send, // 发送（纸飞机）
  link, // 链接（链条）
  copy, // 复制（双层方框）
  save, // 保存（软盘）
  bookmark, // 收藏书签
  archiveBox, // 归档（箱 + 盖线）
  inbox, // 收件箱
  folderOpen, // 打开文件夹
  docLines, // 文档（横线稿）
  docText, // 文本稿
  grid, // 网格视图（九宫格）
  listView, // 列表视图（横条）
  dragHandle, // 拖拽把手（双横杠）
  eye, // 可见
  eyeOff, // 隐藏（闭眼）
  lock, // 锁
  key, // 钥匙
  warning, // 警告（三角感叹号）
  help, // 帮助（圆圈问号）
  question, // 疑问（小问号）
  menuLines, // 菜单（三横）
  moreVert, // 更多（竖三点）
  flag, // 标记（旗）
  pin, // 图钉
  clock, // 时钟
  schedule, // 日程（时钟 + 环）
  hourglass, // 沙漏
  timer, // 计时器
  repeatArrow, // 循环箭头
  moveUp, // 上移（置顶）
  attach, // 附件（回形针）
  video, // 视频（摄像机）
  medicalBag, // 医药箱
  translate, // 翻译（文A）
  paintBrush, // 画笔（自定义分类）
  apps, // 应用九宫
  apple, // 苹果（水果）
  cameraAuto, // 自动（魔法棒 + 星）
  sparkles, // 闪亮（魔法）
  eco, // 环保（叶）
  umbrella, // 伞
  spa, // 温泉（气泡）
  hygiene, // 清洁（扫帚）
  child, // 儿童
  badge, // 徽章
  face, // 表情
  gem, // 宝石
  chair, // 椅子
  clothing, // 衣架
  membership, // 会员卡
  permission, // 权限（盾 + 勾）
  group, // 群组
  android, // 安卓（机器人）
  verified, // 已验证（勾章）
  contrast, // 明暗对比
  appsGrid, // 应用宫格
  memory, // 存储（内存条）
  textFields, // 输入框
  filterList, // 筛选列表
  monitor, // 显示器
  wall, // 挂钟
  beach, // 海滩
  swimming, // 游泳
  hiking, // 徒步
  games, // 游戏手柄
  stadium, // 场馆
  menuBook, // 菜单书
  pointOfSale, // POS 机
  loyalty, // 积分
  room, // 房间
  childCare, // 育儿
  elderly, // 长者
  handshakeMoney, // 结算
  balance, // 天平
  handyman, // 工具
  construction, // 施工
  handshakeDeal, // 成交
  uploaded, // 上传完成
  assign, // 指派（回转箭头）
  scheduleSend, // 定时发送
  autoAwesome, // 智能推荐
  magic, // 魔法棒
  translateLang, // 多语言
  attachment, // 附件
  bookmarkBorder, // 书签框
  visibility, // 可见性
  filterAlt, // 强筛选
  dashboard, // 仪表盘
  leaderboard, // 排行榜
  offline, // 离线
  vpn, // 代理
  error, // 错误
  scheduleClock, // 闹钟
  altRoute, // 备选路线
  timeline, // 时间轴
  horizontalRule, // 分割线
  deleteOutline, // 删除（桶 + 斜杠，强化「不可逆」）
  heart, // 喜欢（心形）
  circle, // 圆点（金额小数点）
  savings, // 储蓄（储蓄罐）
  store, // 商铺（店招）
  devices, // 多设备（屏 + 笔）
  calculator, // 计算器
  brokenImage, // 图片损坏（框 + 断线）
  keyboardHide, // 收起键盘（键盘 + 下箭头）
  inventory, // 库存（箱 + 层板）
}

/// 分类 iconKey → 线稿图标映射（对齐 A3 线稿设计稿的分类简笔画）。
///
/// 未收录的 key 返回 null，由调用方兜底为 Material outlined 图标。
LineIconKind? categoryLineKind(String? iconKey) {
  if (iconKey == null || iconKey.isEmpty) return null;
  return switch (iconKey) {
    'restaurant' || 'rice' => LineIconKind.food,
    'cake' => LineIconKind.cake,
    'flight' => LineIconKind.flight,
    'camera' => LineIconKind.camera,
    'donation' => LineIconKind.donation,
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
    'pet' || 'pets' => LineIconKind.pet,
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

/// 分类图标统一渲染：手绘线稿（优先），未知 key 兜底星形「其他」。
///
/// 全站分类图标（管理页 / 迁移页 / 报表 / 记一笔 / 报销选单 / 分期建单 /
/// 模板卡等）一律走它，确保「森林手账·鼠尾草绿」A3 线稿风格全局一致，
/// 不再散落 Material outlined 兜底。
class CategoryGlyph extends StatelessWidget {
  const CategoryGlyph(this.iconKey, {super.key, this.size = 22, this.color});

  final String? iconKey;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => LineIcon(
        categoryLineKind(iconKey) ?? LineIconKind.star,
        size: size,
        color: color,
      );
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
      case LineIconKind.cake:
        _cake(path);
      case LineIconKind.flight:
        _flight(path);
      case LineIconKind.camera:
        _camera(path);
      case LineIconKind.donation:
        _donation(path);
      case LineIconKind.installment:
        _installment(path);
      case LineIconKind.settings:
        _settings(path);
      case LineIconKind.location:
        _location(path);
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
      case LineIconKind.shieldCheck:
        _shieldCheck(path);
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
      case LineIconKind.pet:
        _pet(path);
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
      // ── 功能 / UI 操作 ──
      case LineIconKind.add:
        _add(path);
      case LineIconKind.minus:
        _minus(path);
      case LineIconKind.check:
        _check(path);
      case LineIconKind.checkCircle:
        _checkCircle(path);
      case LineIconKind.chevronLeft:
        _chevronLeft(path);
      case LineIconKind.chevronDown:
        _chevronDown(path);
      case LineIconKind.chevronUp:
        _chevronUp(path);
      case LineIconKind.arrowBack:
        _arrowBack(path);
      case LineIconKind.arrowRight:
        _arrowRight(path);
      case LineIconKind.arrowUpRight:
        _arrowUpRight(path);
      case LineIconKind.arrowUpLeft:
        _arrowUpLeft(path);
      case LineIconKind.arrowDownLeft:
        _arrowDownLeft(path);
      case LineIconKind.search:
        _search(path);
      case LineIconKind.backspace:
        _backspace(path);
      case LineIconKind.sortDesc:
        _sortDesc(path);
      case LineIconKind.filter:
        _filter(path);
      case LineIconKind.sliders:
        _sliders(path);
      case LineIconKind.swapHorizontal:
        _swapHorizontal(path);
      case LineIconKind.swapVertical:
        _swapVertical(path);
      case LineIconKind.wallet:
        _wallet(path);
      case LineIconKind.bank:
        _bank(path);
      case LineIconKind.card:
        _card(path);
      case LineIconKind.yuan:
        _yuan(path);
      case LineIconKind.percent:
        _percent(path);
      case LineIconKind.receipt:
        _receipt(path);
      case LineIconKind.ticket:
        _ticket(path);
      case LineIconKind.barcode:
        _barcode(path);
      case LineIconKind.handshake:
        _handshake(path);
      case LineIconKind.chartLine:
        _chartLine(path);
      case LineIconKind.chartBar:
        _chartBar(path);
      case LineIconKind.chartPie:
        _chartPie(path);
      case LineIconKind.chartCandle:
        _chartCandle(path);
      case LineIconKind.trendDown:
        _trendDown(path);
      case LineIconKind.sync:
        _sync(path);
      case LineIconKind.refresh:
        _refresh(path);
      case LineIconKind.cloud:
        _cloud(path);
      case LineIconKind.cloudUp:
        _cloudUp(path);
      case LineIconKind.cloudDown:
        _cloudDown(path);
      case LineIconKind.send:
        _send(path);
      case LineIconKind.link:
        _link(path);
      case LineIconKind.copy:
        _copy(path);
      case LineIconKind.save:
        _save(path);
      case LineIconKind.bookmark:
        _bookmark(path);
      case LineIconKind.archiveBox:
        _archiveBox(path);
      case LineIconKind.inbox:
        _inbox(path);
      case LineIconKind.folderOpen:
        _folderOpen(path);
      case LineIconKind.docLines:
        _docLines(path);
      case LineIconKind.docText:
        _docText(path);
      case LineIconKind.grid:
        _grid(path);
      case LineIconKind.listView:
        _listView(path);
      case LineIconKind.dragHandle:
        _dragHandle(path);
      case LineIconKind.eye:
        _eye(path);
      case LineIconKind.eyeOff:
        _eyeOff(path);
      case LineIconKind.lock:
        _lock(path);
      case LineIconKind.key:
        _key(path);
      case LineIconKind.warning:
        _warning(path);
      case LineIconKind.help:
        _help(path);
      case LineIconKind.question:
        _question(path);
      case LineIconKind.menuLines:
        _menuLines(path);
      case LineIconKind.moreVert:
        _moreVert(path);
      case LineIconKind.flag:
        _flag(path);
      case LineIconKind.pin:
        _pin(path);
      case LineIconKind.clock:
        _clock(path);
      case LineIconKind.schedule:
        _schedule(path);
      case LineIconKind.hourglass:
        _hourglass(path);
      case LineIconKind.timer:
        _timer(path);
      case LineIconKind.repeatArrow:
        _repeatArrow(path);
      case LineIconKind.moveUp:
        _moveUp(path);
      case LineIconKind.attach:
        _attach(path);
      case LineIconKind.video:
        _video(path);
      case LineIconKind.medicalBag:
        _medicalBag(path);
      case LineIconKind.translate:
        _translate(path);
      case LineIconKind.paintBrush:
        _paintBrush(path);
      case LineIconKind.apps:
        _apps(path);
      case LineIconKind.apple:
        _apple(path);
      case LineIconKind.cameraAuto:
        _cameraAuto(path);
      case LineIconKind.sparkles:
        _sparkles(path);
      case LineIconKind.eco:
        _eco(path);
      case LineIconKind.umbrella:
        _umbrella(path);
      case LineIconKind.spa:
        _spa(path);
      case LineIconKind.hygiene:
        _hygiene(path);
      case LineIconKind.child:
        _child(path);
      case LineIconKind.badge:
        _badge(path);
      case LineIconKind.face:
        _face(path);
      case LineIconKind.gem:
        _gem(path);
      case LineIconKind.chair:
        _chair(path);
      case LineIconKind.clothing:
        _clothing(path);
      case LineIconKind.membership:
        _membership(path);
      case LineIconKind.permission:
        _permission(path);
      case LineIconKind.group:
        _group(path);
      case LineIconKind.android:
        _android(path);
      case LineIconKind.verified:
        _verified(path);
      case LineIconKind.contrast:
        _contrast(path);
      case LineIconKind.appsGrid:
        _appsGrid(path);
      case LineIconKind.memory:
        _memory(path);
      case LineIconKind.textFields:
        _textFields(path);
      case LineIconKind.filterList:
        _filterList(path);
      case LineIconKind.monitor:
        _monitor(path);
      case LineIconKind.wall:
        _wall(path);
      case LineIconKind.beach:
        _beach(path);
      case LineIconKind.swimming:
        _swimming(path);
      case LineIconKind.hiking:
        _hiking(path);
      case LineIconKind.games:
        _games(path);
      case LineIconKind.stadium:
        _stadium(path);
      case LineIconKind.menuBook:
        _menuBook(path);
      case LineIconKind.pointOfSale:
        _pointOfSale(path);
      case LineIconKind.loyalty:
        _loyalty(path);
      case LineIconKind.room:
        _room(path);
      case LineIconKind.childCare:
        _childCare(path);
      case LineIconKind.elderly:
        _elderly(path);
      case LineIconKind.handshakeMoney:
        _handshakeMoney(path);
      case LineIconKind.balance:
        _balance(path);
      case LineIconKind.handyman:
        _handyman(path);
      case LineIconKind.construction:
        _construction(path);
      case LineIconKind.handshakeDeal:
        _handshakeDeal(path);
      case LineIconKind.uploaded:
        _uploaded(path);
      case LineIconKind.assign:
        _assign(path);
      case LineIconKind.scheduleSend:
        _scheduleSend(path);
      case LineIconKind.autoAwesome:
        _autoAwesome(path);
      case LineIconKind.magic:
        _magic(path);
      case LineIconKind.translateLang:
        _translateLang(path);
      case LineIconKind.attachment:
        _attachment(path);
      case LineIconKind.bookmarkBorder:
        _bookmarkBorder(path);
      case LineIconKind.visibility:
        _visibility(path);
      case LineIconKind.filterAlt:
        _filterAlt(path);
      case LineIconKind.dashboard:
        _dashboard(path);
      case LineIconKind.leaderboard:
        _leaderboard(path);
      case LineIconKind.offline:
        _offline(path);
      case LineIconKind.vpn:
        _vpn(path);
      case LineIconKind.error:
        _error(path);
      case LineIconKind.scheduleClock:
        _scheduleClock(path);
      case LineIconKind.altRoute:
        _altRoute(path);
      case LineIconKind.timeline:
        _timeline(path);
      case LineIconKind.horizontalRule:
        _horizontalRule(path);
      case LineIconKind.deleteOutline:
        _deleteOutline(path);
      case LineIconKind.heart:
        _heart(path);
      case LineIconKind.circle:
        _circle(path);
      case LineIconKind.savings:
        _savings(path);
      case LineIconKind.store:
        _store(path);
      case LineIconKind.devices:
        _devices(path);
      case LineIconKind.calculator:
        _calculator(path);
      case LineIconKind.brokenImage:
        _brokenImage(path);
      case LineIconKind.keyboardHide:
        _keyboardHide(path);
      case LineIconKind.inventory:
        _inventory(path);
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
  void _dashLine(
    Canvas c,
    Paint paint,
    double x,
    double y1,
    double x2,
    double y2,
    double dash,
    double gap,
  ) {
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
    p.addRRect(const RRect.fromLTRBXY(4, 6, 20, 18, 2, 2));
  }

  void _photo(Path p) {
    p.addRRect(const RRect.fromLTRBXY(4, 5, 20, 19, 2, 2));
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
    p.addRRect(const RRect.fromLTRBXY(5, 5, 19, 19, 2, 2));
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
    p.addRRect(const RRect.fromLTRBXY(4, 5.5, 20, 20.5, 2.5, 2.5));
    _line(p, 4, 10, 20, 10);
    _line(p, 8, 3.5, 8, 6.5);
    _line(p, 16, 3.5, 16, 6.5);
    _line(p, 8.5, 13.5, 9.5, 13.5);
    _line(p, 14.5, 13.5, 15.5, 13.5);
  }

  /// 分期：日历框（横线 + 双耳）+ 框内「¥」（逐期入账）。
  void _installment(Path p) {
    p.addRRect(const RRect.fromLTRBXY(4, 5.5, 20, 20.5, 2.5, 2.5));
    _line(p, 4, 10, 20, 10);
    _line(p, 8, 3.5, 8, 6.5);
    _line(p, 16, 3.5, 16, 6.5);
    // 框内「¥」：两斜肩 + 竖笔 + 短横杠。
    _line(p, 9.8, 12.6, 12, 15.4);
    _line(p, 14.2, 12.6, 12, 15.4);
    _line(p, 12, 15.4, 12, 18.4);
    _line(p, 10.4, 16.6, 13.6, 16.6);
  }

  /// 甜点（蛋糕：烛火 + 蜡烛 + 糕体 + 底盘）。
  void _cake(Path p) {
    _line(p, 5.5, 19.8, 18.5, 19.8);
    p.addRRect(const RRect.fromLTRBXY(6.5, 13.2, 17.5, 19.8, 1.5, 1.5));
    _line(p, 6.5, 15.8, 17.5, 15.8);
    _line(p, 12, 10.2, 12, 13.2);
    p.addOval(Rect.fromCircle(center: const Offset(12, 8.2), radius: 1.1));
  }

  /// 机票（纸飞机：机翼折线 + 机身三角）。
  void _flight(Path p) {
    p.moveTo(19.5, 4.5);
    p.lineTo(4.5, 11.2);
    p.lineTo(10.2, 13.8);
    p.lineTo(12.6, 19.5);
    p.close();
    _line(p, 10.2, 13.8, 19.5, 4.5);
  }

  /// 摄影（相机：机身 + 顶部取景凸起 + 镜头）。
  void _camera(Path p) {
    p.addRRect(const RRect.fromLTRBXY(3.5, 7.8, 20.5, 18.5, 2.5, 2.5));
    p.moveTo(9, 7.8);
    p.lineTo(10, 5.5);
    p.lineTo(14, 5.5);
    p.lineTo(15, 7.8);
    p.addOval(Rect.fromCircle(center: const Offset(12, 13.1), radius: 3.2));
  }

  /// 公益（手捧爱心）。
  void _donation(Path p) {
    p.moveTo(12, 10.8);
    p.quadraticBezierTo(6.8, 7.4, 9.4, 5.3);
    p.quadraticBezierTo(12, 4.0, 12, 7.0);
    p.quadraticBezierTo(12, 4.0, 14.6, 5.3);
    p.quadraticBezierTo(17.2, 7.4, 12, 10.8);
    p.moveTo(5, 15.2);
    p.lineTo(12.5, 15.2);
    p.quadraticBezierTo(17, 15.2, 18.8, 18.6);
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

  /// 位置：水滴形定位针 + 中心圆（线稿）。
  void _location(Path p) {
    p.moveTo(12, 2);
    p.cubicTo(4.5, 2, 3, 8.5, 3, 12.5);
    p.cubicTo(3, 16, 8, 20, 12, 22);
    p.cubicTo(16, 20, 21, 16, 21, 12.5);
    p.cubicTo(21, 8.5, 19.5, 2, 12, 2);
    p.close();
    p.addOval(Rect.fromCircle(center: const Offset(12, 10.5), radius: 3));
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
    p.addRRect(const RRect.fromLTRBXY(5, 7.85, 19, 18.85, 2, 2));
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
    p.addOval(const Rect.fromLTRB(4, 14.25, 20, 17.45));
    p.addOval(Rect.fromCircle(center: const Offset(12, 7.65), radius: 1.1));
  }

  /// 饮品：带吸管外带杯（杯身 + 盖 + 吸管）。
  void _beverage(Path p) {
    p.moveTo(8, 9.4);
    p.lineTo(9.2, 20.4);
    p.lineTo(14.8, 20.4);
    p.lineTo(16, 9.4);
    p.close();
    p.addRRect(const RRect.fromLTRBXY(7.2, 7.4, 16.8, 9.8, 1, 1));
    p.moveTo(13, 7.4);
    p.lineTo(14.6, 3.6);
  }

  /// 团购券：票券（圆角票 + 两侧缺口 + ¥ 印记）。
  void _coupon(Path p) {
    p.addRRect(const RRect.fromLTRBXY(4, 7.5, 20, 16.5, 2, 2));
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
    p.addRRect(const RRect.fromLTRBXY(5, 4.35, 19, 16.85, 2.5, 2.5));
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
    p.addRRect(const RRect.fromLTRBXY(7.5, 3, 16.5, 21, 2.5, 2.5));
    _line(p, 10.5, 18.5, 13.5, 18.5);
  }

  /// 人情：礼盒 + 缎带 + 蝴蝶结。
  void _giftRibbon(Path p) {
    p.addRRect(const RRect.fromLTRBXY(5.5, 8, 18.5, 18.5, 1.5, 1.5));
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
    p.addRRect(const RRect.fromLTRBXY(4.5, 7.35, 19.5, 18.35, 2, 2));
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
    p.addRRect(const RRect.fromLTRBXY(5, 6, 19, 18, 2, 2));
    p.moveTo(5, 9);
    p.cubicTo(8, 11.4, 16, 11.4, 19, 9);
    p.addOval(Rect.fromCircle(center: const Offset(12, 13), radius: 1.5));
  }

  /// 退款：票据 + 回退箭头。
  void _refundArrow(Path p) {
    p.addRRect(const RRect.fromLTRBXY(5, 8, 19, 16, 1.5, 1.5));
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

  /// 余额守卫：盾牌轮廓 + 内部对勾，表示「校验 / 余额保护」。
  void _shieldCheck(Path p) {
    p.moveTo(12, 4);
    p.lineTo(5, 7);
    p.lineTo(5, 13);
    p.lineTo(12, 20);
    p.lineTo(19, 13);
    p.lineTo(19, 7);
    p.close();
    p.moveTo(9, 12);
    p.lineTo(11, 14.5);
    p.lineTo(15.5, 9.5);
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
    p.addOval(const Rect.fromLTRB(5, 14.75, 19, 19.75));
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
    p.addOval(const Rect.fromLTRB(5, 7, 21, 17));
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
    p.addRRect(const RRect.fromLTRBXY(6, 6, 18, 15, 1, 1));
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
    p.addRRect(const RRect.fromLTRBXY(8.15, 4, 12.15, 11, 1, 1));
    p.addRRect(const RRect.fromLTRBXY(7.15, 11, 13.15, 20, 1, 1));
    _line(p, 8.15, 7, 12.15, 7);
    p.addOval(Rect.fromCircle(center: const Offset(14.65, 15), radius: 2.2));
  }

  /// 数码电器（Electronics）。
  void _digital(Path p) {
    p.addRRect(const RRect.fromLTRBXY(5, 5.5, 19, 14.5, 1.5, 1.5));
    p.moveTo(9, 18.5);
    p.lineTo(15, 18.5);
    _line(p, 12, 14.5, 12, 18.5);
  }

  /// 生活耗材（Consumables）。
  void _consumable(Path p) {
    p.addRRect(const RRect.fromLTRBXY(5.5, 7.5, 15.5, 16.5, 2, 2));
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
    p.addRRect(const RRect.fromLTRBXY(5, 4.9, 19, 17.9, 2.5, 2.5));
    _line(p, 5, 11.9, 19, 11.9);
    p.addOval(Rect.fromCircle(center: const Offset(8.5, 17.9), radius: 1.2));
    p.addOval(Rect.fromCircle(center: const Offset(15.5, 17.9), radius: 1.2));
    _line(p, 8, 7.9, 16, 7.9);
  }

  /// 加油充电（Fuel/Charge）。
  void _fuel(Path p) {
    p.addRRect(const RRect.fromLTRBXY(6.5, 8.5, 14.5, 19.5, 1.5, 1.5));
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
    p.addRRect(const RRect.fromLTRBXY(7, 6.4, 17, 17.4, 2, 2));
    _line(p, 7, 11.4, 17, 11.4);
    p.addOval(Rect.fromCircle(center: const Offset(10, 18.4), radius: 1.2));
    p.addOval(Rect.fromCircle(center: const Offset(14, 18.4), radius: 1.2));
    _line(p, 10, 6.4, 10, 4.4);
    _line(p, 14, 6.4, 14, 4.4);
  }

  /// 装修维护（Renovation）。
  void _renovation(Path p) {
    p.addRRect(const RRect.fromLTRBXY(6, 5, 15, 9, 1, 1));
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
    p.addRRect(const RRect.fromLTRBXY(9, 4, 17, 20, 2, 2));
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
    p.addRRect(const RRect.fromLTRBXY(4, 7.5, 20, 16.5, 2, 2));
    _line(p, 12, 7.5, 12, 16.5);
    _line(p, 7, 10.5, 9, 10.5);
    _line(p, 7, 13, 9, 13);
  }

  /// 数字娱乐（Digital Fun）。
  void _digitalFun(Path p) {
    p.addRRect(const RRect.fromLTRBXY(8, 4, 16, 20, 2, 2));
    p.moveTo(11, 10);
    p.lineTo(11, 14);
    p.lineTo(14, 12);
    p.close();
  }

  /// 旅游度假（Vacation）。
  void _travelVacation(Path p) {
    p.addRRect(const RRect.fromLTRBXY(5.75, 9.25, 17.75, 20.25, 2, 2));
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
    p.addRRect(const RRect.fromLTRBXY(5, 6, 19, 18, 1.5, 1.5));
    p.moveTo(8, 15);
    p.lineTo(11, 11);
    p.lineTo(13, 13);
    p.lineTo(16, 9);
    p.lineTo(17, 10);
    p.addOval(Rect.fromCircle(center: const Offset(9, 9), radius: 1));
  }

  /// 就医购药（Clinic）。
  void _clinic(Path p) {
    p.addRRect(const RRect.fromLTRBXY(8.5, 4.5, 15.5, 19.5, 3.5, 3.5));
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

  /// 宠物（Pet）：狗头——圆脸 + 两只垂耳 + 眼鼻。
  void _pet(Path p) {
    // 头部圆。
    p.addOval(Rect.fromCircle(center: const Offset(12, 14), radius: 5.5));
    // 左垂耳。
    p.moveTo(7.6, 10.4);
    p.quadraticBezierTo(5.2, 5.2, 8.8, 6.2);
    p.quadraticBezierTo(10.4, 7.2, 9.8, 9.6);
    // 右垂耳（对称）。
    p.moveTo(16.4, 10.4);
    p.quadraticBezierTo(18.8, 5.2, 15.2, 6.2);
    p.quadraticBezierTo(13.6, 7.2, 14.2, 9.6);
    // 眼睛。
    p.addOval(Rect.fromCircle(center: const Offset(9.9, 13), radius: 0.7));
    p.addOval(Rect.fromCircle(center: const Offset(14.1, 13), radius: 0.7));
    // 鼻头。
    p.addOval(Rect.fromCircle(center: const Offset(12, 15.8), radius: 0.9));
  }

  /// 宠物食品（Pet Food）。
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
    p.addRRect(const RRect.fromLTRBXY(4, 4.5, 20, 10.5, 2, 2));
    _line(p, 4, 7.5, 20, 7.5);
    _line(p, 12, 13, 12, 19.5);
    _line(p, 9.5, 17, 12, 19.5);
    _line(p, 14.5, 17, 12, 19.5);
  }

  /// 内部转账：左右两个账户 + 双向箭头（账户间内部划转）。
  void _internalTransfer(Path p) {
    p.addRRect(const RRect.fromLTRBXY(3.5, 9, 8.5, 15, 1.5, 1.5));
    p.addRRect(const RRect.fromLTRBXY(15.5, 9, 20.5, 15, 1.5, 1.5));
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
    p.addOval(const Rect.fromLTRB(5.9, 7.05, 19.9, 17.05));
    p.addOval(const Rect.fromLTRB(4.1, 10.55, 6.7, 13.55));
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
    p.addOval(const Rect.fromLTRB(5.9, 7.05, 19.9, 17.05));
    p.addOval(const Rect.fromLTRB(4.1, 10.55, 6.7, 13.55));
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
    p.addRRect(const RRect.fromLTRBXY(4.75, 6.75, 13.75, 17.75, 1.5, 1.5));
    _line(p, 7.25, 10.25, 11.25, 10.25);
    _line(p, 7.25, 13.75, 11.25, 13.75);
    _line(p, 17.25, 6.25, 17.25, 13.25);
    _line(p, 15.25, 11.25, 17.25, 13.25);
    _line(p, 19.25, 11.25, 17.25, 13.25);
  }

  /// 收债：欠条 + 侧旁向上箭头（收入，向欠款人催收）。
  void _collectDebt(Path p) {
    p.addRRect(const RRect.fromLTRBXY(10.25, 6.25, 19.25, 17.25, 1.5, 1.5));
    _line(p, 12.75, 9.75, 16.75, 9.75);
    _line(p, 12.75, 13.25, 16.75, 13.25);
    _line(p, 6.75, 17.75, 6.75, 10.75);
    _line(p, 4.75, 12.75, 6.75, 10.75);
    _line(p, 8.75, 12.75, 6.75, 10.75);
  }

  /// 债务消减：欠条 + 下方减号（部分减免 / 打折）。
  void _debtReduce(Path p) {
    p.addRRect(const RRect.fromLTRBXY(7, 5.25, 17, 15.25, 1.5, 1.5));
    _line(p, 9.5, 10.25, 14.5, 10.25);
    _line(p, 9, 18.75, 15, 18.75);
  }

  /// 坏账计提：欠条 + 贯穿斜杠（核销 / 坏账作废）。
  void _badDebt(Path p) {
    p.addRRect(const RRect.fromLTRBXY(7, 5.25, 17, 15.25, 1.5, 1.5));
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
    p.addRRect(const RRect.fromLTRBXY(6, 4, 18, 20, 1.5, 1.5));
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
    p.addRRect(const RRect.fromLTRBXY(6, 4.5, 18, 19.5, 1, 1));
    _line(p, 9, 7.5, 9, 9.5);
    _line(p, 12, 7.5, 12, 9.5);
    _line(p, 15, 7.5, 15, 9.5);
    _line(p, 9, 12.5, 9, 14.5);
    _line(p, 12, 12.5, 12, 14.5);
    _line(p, 15, 12.5, 15, 14.5);
  }

  /// 职业收入：工牌（卡片 + 挂绳 + 头像 + 文字线）。
  void _incomeJob(Path p) {
    p.addRRect(const RRect.fromLTRBXY(5, 9.45, 19, 18.45, 2, 2));
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
    p.addOval(const Rect.fromLTRB(6, 13, 18, 17));
    p.addOval(const Rect.fromLTRB(6, 10, 18, 14));
    p.addOval(const Rect.fromLTRB(6, 7, 18, 11));
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
    p.addRRect(const RRect.fromLTRBXY(10, 11.5, 14, 16.5, 1, 1));
  }

  /// 个体经营：手推车（车斗 + 顶棚 + 双轮）。
  void _soleProprietor(Path p) {
    p.addRRect(const RRect.fromLTRBXY(6, 9.6, 18, 14.6, 1, 1));
    _line(p, 6, 9.6, 12, 5.6);
    _line(p, 18, 9.6, 12, 5.6);
    _line(p, 7, 5.6, 17, 5.6);
    p.addOval(Rect.fromCircle(center: const Offset(9.5, 17.1), radius: 1.3));
    p.addOval(Rect.fromCircle(center: const Offset(16.5, 17.1), radius: 1.3));
  }

  /// 副业兼职：笔记本（屏幕 + 键盘弧 + 内容线）。
  void _incomeSide(Path p) {
    p.addRRect(const RRect.fromLTRBXY(6, 4.75, 18, 13.75, 1.5, 1.5));
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
    p.addRRect(const RRect.fromLTRBXY(7.5, 8.15, 11.5, 12.15, 1, 1));
  }

  /// 视频收入：摄像机（机身 + 镜头锥 + 提带 + 录制点）。
  void _videoIncome(Path p) {
    p.addRRect(const RRect.fromLTRBXY(5, 9, 15, 17, 1.5, 1.5));
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
    p.addRRect(const RRect.fromLTRBXY(6, 9, 10, 14, 1, 1));
    _line(p, 15, 5, 15, 17);
    p.addRRect(const RRect.fromLTRBXY(13, 8, 17, 12, 1, 1));
  }

  /// 利息收入：百分号硬币（大圆 + %）。
  void _interest(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 7));
    p.addOval(Rect.fromCircle(center: const Offset(9, 9), radius: 1.6));
    p.addOval(Rect.fromCircle(center: const Offset(15, 15), radius: 1.6));
    _line(p, 7.5, 16.5, 16.5, 7.5);
  }

  // ══════════════ 功能 / UI 操作字形（2026-10-15 全局去 Material）══════════════

  /// 新增：十字（＋）。
  void _add(Path p) {
    _line(p, 12, 4.5, 12, 19.5);
    _line(p, 4.5, 12, 19.5, 12);
  }

  /// 减少：横杠（－）。
  void _minus(Path p) {
    _line(p, 4.5, 12, 19.5, 12);
  }

  /// 勾选：对勾（✓）。
  void _check(Path p) {
    p.moveTo(4.5, 12.5);
    p.lineTo(9.5, 17.5);
    p.lineTo(19.5, 6.5);
  }

  /// 勾选圆：圆圈 + 内嵌对勾。
  void _checkCircle(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 8.5));
    p.moveTo(7.8, 12.2);
    p.lineTo(10.8, 15.2);
    p.lineTo(16.4, 8.8);
  }

  /// 左向箭头（‹）。
  void _chevronLeft(Path p) {
    _line(p, 15.5, 5, 8.5, 12);
    _line(p, 8.5, 12, 15.5, 19);
  }

  /// 下拉展开（⌄）。
  void _chevronDown(Path p) {
    _line(p, 5, 9.5, 12, 16.5);
    _line(p, 12, 16.5, 19, 9.5);
  }

  /// 上收折叠（⌃）。
  void _chevronUp(Path p) {
    _line(p, 5, 14.5, 12, 7.5);
    _line(p, 12, 7.5, 19, 14.5);
  }

  /// 返回：左箭头带尾横线。
  void _arrowBack(Path p) {
    _line(p, 20, 12, 4, 12);
    p.moveTo(11, 5);
    p.lineTo(4, 12);
    p.lineTo(11, 19);
  }

  /// 右指箭头（→）。
  void _arrowRight(Path p) {
    _line(p, 4, 12, 20, 12);
    p.moveTo(13, 5);
    p.lineTo(20, 12);
    p.lineTo(13, 19);
  }

  /// 右上（↗）。
  void _arrowUpRight(Path p) {
    _line(p, 6.5, 17.5, 17.5, 6.5);
    p.moveTo(9.5, 6.5);
    p.lineTo(17.5, 6.5);
    p.lineTo(17.5, 14.5);
  }

  /// 左上（↖）。
  void _arrowUpLeft(Path p) {
    _line(p, 17.5, 17.5, 6.5, 6.5);
    p.moveTo(14.5, 6.5);
    p.lineTo(6.5, 6.5);
    p.lineTo(6.5, 14.5);
  }

  /// 左下（↙）。
  void _arrowDownLeft(Path p) {
    _line(p, 17.5, 6.5, 6.5, 17.5);
    p.moveTo(14.5, 17.5);
    p.lineTo(6.5, 17.5);
    p.lineTo(6.5, 9.5);
  }

  /// 搜索：放大镜（圆 + 斜柄）。
  void _search(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(10.5, 10.5), radius: 6.5));
    _line(p, 15.4, 15.4, 20.5, 20.5);
  }

  /// 退格：⌫ 形状（尖角框 + 内 ×）。
  void _backspace(Path p) {
    p.moveTo(9, 5);
    p.lineTo(20, 5);
    p.lineTo(20, 19);
    p.lineTo(9, 19);
    p.lineTo(3, 12);
    p.close();
    _line(p, 12, 9.5, 17, 14.5);
    _line(p, 17, 9.5, 12, 14.5);
  }

  /// 排序：降序 + 升序双箭头（↓↑ 并排，对齐 Material Icons.sort 语义）。
  ///
  /// 2026-10-16 第 38 批重绘：旧版是「底线 + ‹ 折线 + ↓」——‹ 那条没有
  /// 箭杆、也不是 ^，24px 下整体读作漏斗/筛选，用户截图反馈「顶部右侧
  /// 排序键有问题」。改为左 ↓ 右 ↑ 的标准排序字形。
  void _sortDesc(Path p) {
    // 左：向下箭头（轴 x=8.5，箭头朝下）。
    _line(p, 8.5, 4, 8.5, 14.5);
    p.moveTo(5, 11.5);
    p.lineTo(8.5, 15);
    p.lineTo(12, 11.5);
    // 右：向上箭头（轴 x=15.5，箭头朝上）。
    _line(p, 15.5, 20, 15.5, 9.5);
    p.moveTo(12, 12.5);
    p.lineTo(15.5, 9);
    p.lineTo(19, 12.5);
  }

  /// 筛选：漏斗。
  void _filter(Path p) {
    p.moveTo(3, 5.5);
    p.lineTo(21, 5.5);
    p.lineTo(14, 13.5);
    p.lineTo(14, 20);
    p.lineTo(10, 17.5);
    p.lineTo(10, 13.5);
    p.close();
  }

  /// 调节：三条横向滑轨（各带一颗滑块）。
  void _sliders(Path p) {
    // 轨道在滑块圆环两侧断开留缺口——此前轨道直穿圆环，小尺寸（15px，
    // 如滚存计划「调整」胶囊）下线与环糊成一团实心横杠（2026-10-16 第 43 批）。
    _line(p, 3, 7, 4.4, 7);
    _line(p, 12.9, 7, 21, 7);
    p.addOval(Rect.fromCircle(center: const Offset(9, 7), radius: 2));
    _line(p, 3, 12, 11.2, 12);
    _line(p, 18.9, 12, 21, 12);
    p.addOval(Rect.fromCircle(center: const Offset(15, 12), radius: 2));
    _line(p, 3, 17, 3.7, 17);
    _line(p, 11.4, 17, 21, 17);
    p.addOval(Rect.fromCircle(center: const Offset(7.5, 17), radius: 2));
  }

  /// 横向交换（⇄）。
  void _swapHorizontal(Path p) {
    _line(p, 4, 9, 18, 9);
    p.moveTo(15, 6);
    p.lineTo(18, 9);
    p.lineTo(15, 12);
    _line(p, 20, 15, 6, 15);
    p.moveTo(9, 12);
    p.lineTo(6, 15);
    p.lineTo(9, 18);
  }

  /// 纵向交换（⇅）。
  void _swapVertical(Path p) {
    _line(p, 9, 4, 9, 18);
    p.moveTo(6, 15);
    p.lineTo(9, 18);
    p.lineTo(12, 15);
    _line(p, 15, 20, 15, 6);
    p.moveTo(12, 9);
    p.lineTo(15, 6);
    p.lineTo(18, 9);
  }

  /// 钱包：钱包身 + 前袋扣。
  void _wallet(Path p) {
    p.addRRect(const RRect.fromLTRBXY(3, 6, 21, 18.5, 2, 2));
    p.moveTo(15.5, 10.5);
    p.lineTo(21, 10.5);
    p.lineTo(21, 14.5);
    p.lineTo(15.5, 14.5);
    p.close();
    p.addOval(Rect.fromCircle(center: const Offset(17.6, 12.5), radius: 0.9));
  }

  /// 银行：柱廊（顶梁 + 三柱 + 台阶基座）。
  void _bank(Path p) {
    p.moveTo(2.5, 9.5);
    p.lineTo(12, 3.5);
    p.lineTo(21.5, 9.5);
    p.close();
    _line(p, 2.5, 9.5, 21.5, 9.5);
    _line(p, 6, 9.5, 6, 18);
    _line(p, 12, 9.5, 12, 18);
    _line(p, 18, 9.5, 18, 18);
    _line(p, 3.5, 20.5, 20.5, 20.5);
  }

  /// 银行卡：卡身 + 磁条。
  void _card(Path p) {
    p.addRRect(const RRect.fromLTRBXY(2.5, 5, 21.5, 19, 2, 2));
    _line(p, 2.5, 9.5, 21.5, 9.5);
    _line(p, 5.5, 14.5, 9.5, 14.5);
  }

  /// 人民币符号（¥）。
  void _yuan(Path p) {
    _line(p, 6.5, 5.5, 12, 12.5);
    _line(p, 17.5, 5.5, 12, 12.5);
    _line(p, 12, 12.5, 12, 19.5);
    _line(p, 7, 13.5, 17, 13.5);
    _line(p, 7, 16.5, 17, 16.5);
  }

  /// 百分比（%）：斜杠 + 两点。
  void _percent(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(7.5, 7.5), radius: 2.8));
    p.addOval(Rect.fromCircle(center: const Offset(16.5, 16.5), radius: 2.8));
    _line(p, 18.5, 5.5, 5.5, 18.5);
  }

  /// 小票：票面 + 锯齿底边。
  void _receipt(Path p) {
    p.moveTo(5.5, 3.5);
    p.lineTo(18.5, 3.5);
    p.lineTo(18.5, 20.5);
    p.lineTo(16.25, 18.75);
    p.lineTo(14, 20.5);
    p.lineTo(11.75, 18.75);
    p.lineTo(9.5, 20.5);
    p.lineTo(7.25, 18.75);
    p.lineTo(5.5, 20.5);
    p.close();
    _line(p, 8.5, 8, 15.5, 8);
    _line(p, 8.5, 11.5, 15.5, 11.5);
  }

  /// 票券：票面 + 侧边缺口。
  void _ticket(Path p) {
    p.moveTo(3, 7.5);
    p.lineTo(21, 7.5);
    p.lineTo(21, 10);
    p.arcToPoint(const Offset(21, 14), radius: const Radius.circular(2));
    p.lineTo(21, 16.5);
    p.lineTo(3, 16.5);
    p.lineTo(3, 14);
    p.arcToPoint(const Offset(3, 10), radius: const Radius.circular(2));
    p.close();
  }

  /// 条码：竖条阵列（票据编号）。
  void _barcode(Path p) {
    _line(p, 3.5, 5, 3.5, 19);
    _line(p, 6.5, 5, 6.5, 19);
    _line(p, 9.5, 5, 9.5, 19);
    _line(p, 12.5, 5, 12.5, 19);
    _line(p, 15.5, 5, 15.5, 19);
    _line(p, 18.5, 5, 18.5, 19);
  }

  /// 握手：两只相扣的手（简笔）。
  void _handshake(Path p) {
    p.moveTo(2.5, 11.5);
    p.lineTo(7, 7.5);
    p.lineTo(12, 10.5);
    p.lineTo(17, 7.5);
    p.lineTo(21.5, 11.5);
    _line(p, 2.5, 11.5, 8, 15.5);
    _line(p, 21.5, 11.5, 16, 15.5);
    p.moveTo(8, 15.5);
    p.lineTo(12, 12.5);
    p.lineTo(16, 15.5);
  }

  /// 折线图：坐标轴 + 折线 + 上升箭头。
  void _chartLine(Path p) {
    _line(p, 4, 3.5, 4, 20);
    _line(p, 4, 20, 20.5, 20);
    p.moveTo(7, 15.5);
    p.lineTo(11, 11);
    p.lineTo(14.5, 13.5);
    p.lineTo(19.5, 7.5);
    p.moveTo(15.5, 7.5);
    p.lineTo(19.5, 7.5);
    p.lineTo(19.5, 11.5);
  }

  /// 柱状图：三根立柱 + 基线。
  void _chartBar(Path p) {
    _line(p, 3.5, 20, 20.5, 20);
    p.addRRect(const RRect.fromLTRBXY(5.5, 12, 9, 20, 1, 1));
    p.addRRect(const RRect.fromLTRBXY(10.5, 7, 14, 20, 1, 1));
    p.addRRect(const RRect.fromLTRBXY(15.5, 10, 19, 20, 1, 1));
  }

  /// 饼图：外圆 + 扇形分隔线。
  void _chartPie(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 8.5));
    _line(p, 12, 3.5, 12, 12);
    _line(p, 12, 12, 19, 16.5);
  }

  /// K 线：三根蜡烛 + 影线。
  void _chartCandle(Path p) {
    _line(p, 4, 19.5, 20, 19.5);
    _line(p, 7.5, 6.5, 7.5, 17.5);
    p.addRRect(const RRect.fromLTRBXY(5.5, 9.5, 9.5, 15, 1, 1));
    _line(p, 12, 4.5, 12, 18.5);
    p.addRRect(const RRect.fromLTRBXY(10, 7, 14, 12.5, 1, 1));
    _line(p, 16.5, 8.5, 16.5, 18.5);
    p.addRRect(const RRect.fromLTRBXY(14.5, 11, 18.5, 16, 1, 1));
  }

  /// 下降趋势：折线 + 下箭头。
  void _trendDown(Path p) {
    _line(p, 3.5, 20, 20.5, 20);
    p.moveTo(6.5, 7.5);
    p.lineTo(11, 12.5);
    p.lineTo(14, 10);
    p.lineTo(19.5, 16.5);
    p.moveTo(15, 16.5);
    p.lineTo(19.5, 16.5);
    p.lineTo(19.5, 12);
  }

  /// 双向同步：两段反向弯箭头。
  void _sync(Path p) {
    p.moveTo(4, 9.5);
    p.quadraticBezierTo(12, 4.5, 20, 9.5);
    p.moveTo(17, 6.5);
    p.lineTo(20.5, 9.5);
    p.lineTo(17, 12.5);
    p.moveTo(20, 15.5);
    p.quadraticBezierTo(12, 20.5, 4, 15.5);
    p.moveTo(7, 12.5);
    p.lineTo(3.5, 15.5);
    p.lineTo(7, 18.5);
  }

  /// 刷新：环形开口箭头。
  void _refresh(Path p) {
    p.arcToPoint(
      const Offset(18.5, 8),
      radius: const Radius.circular(8),
      clockwise: false,
      largeArc: true,
    );
    p.moveTo(18.5, 3.5);
    p.lineTo(18.5, 8);
    p.lineTo(14, 8);
    p.arcToPoint(
      const Offset(5.5, 16),
      radius: const Radius.circular(8),
      clockwise: false,
      largeArc: true,
    );
    p.moveTo(5.5, 20.5);
    p.lineTo(5.5, 16);
    p.lineTo(10, 16);
  }

  /// 云：云朵轮廓。
  void _cloud(Path p) {
    p.moveTo(7, 18.5);
    p.cubicTo(4, 18.5, 3, 15.5, 5.5, 14);
    p.cubicTo(5, 10, 9.5, 7.5, 13, 9.5);
    p.cubicTo(16.5, 7.5, 20, 10, 19.5, 13.5);
    p.cubicTo(22, 15, 20.5, 18.5, 17, 18.5);
    p.close();
  }

  /// 上传云：云 + 上箭头。
  void _cloudUp(Path p) {
    _cloud(p);
    _line(p, 12, 17, 12, 11);
    p.moveTo(9, 13.5);
    p.lineTo(12, 10.5);
    p.lineTo(15, 13.5);
  }

  /// 下载云：云 + 下箭头。
  void _cloudDown(Path p) {
    _cloud(p);
    _line(p, 12, 11, 12, 17);
    p.moveTo(9, 14.5);
    p.lineTo(12, 17.5);
    p.lineTo(15, 14.5);
  }

  /// 发送：纸飞机。
  void _send(Path p) {
    p.moveTo(21, 3.5);
    p.lineTo(3, 10.5);
    p.lineTo(10, 13.5);
    p.lineTo(12.5, 20.5);
    p.close();
    _line(p, 21, 3.5, 10, 13.5);
  }

  /// 链接：两段链条。
  void _link(Path p) {
    p.moveTo(10, 14);
    p.lineTo(14, 10);
    p.moveTo(8.5, 16.5);
    p.lineTo(6, 19);
    p.arcToPoint(
      const Offset(3.5, 16.5),
      radius: const Radius.circular(2.5),
      clockwise: false,
      largeArc: true,
    );
    p.lineTo(7, 13);
    p.moveTo(15.5, 7.5);
    p.lineTo(18, 5);
    p.arcToPoint(
      const Offset(20.5, 7.5),
      radius: const Radius.circular(2.5),
      clockwise: true,
      largeArc: true,
    );
    p.lineTo(17, 11);
  }

  /// 复制：后层方框 + 前层方框。
  void _copy(Path p) {
    p.addRRect(const RRect.fromLTRBXY(8.5, 3.5, 20.5, 15.5, 2, 2));
    p.moveTo(15.5, 18.5);
    p.lineTo(5.5, 18.5);
    p.lineTo(5.5, 8.5);
    p.lineTo(8.5, 8.5);
  }

  /// 保存：软盘（身 + 上槽 + 下标签）。
  void _save(Path p) {
    p.addRRect(const RRect.fromLTRBXY(4, 4, 20, 20, 2, 2));
    p.moveTo(8, 4);
    p.lineTo(8, 9.5);
    p.lineTo(16, 9.5);
    p.lineTo(16, 4);
    p.addRRect(const RRect.fromLTRBXY(8, 14, 16, 20, 1, 1));
  }

  /// 书签：垂穗书签。
  void _bookmark(Path p) {
    p.moveTo(6, 3.5);
    p.lineTo(18, 3.5);
    p.lineTo(18, 20.5);
    p.lineTo(12, 16);
    p.lineTo(6, 20.5);
    p.close();
  }

  /// 归档：箱体 + 盖线 + 把手。
  void _archiveBox(Path p) {
    p.addRRect(const RRect.fromLTRBXY(3, 4.5, 21, 20, 2, 2));
    _line(p, 3, 9.5, 21, 9.5);
    _line(p, 10, 14.5, 14, 14.5);
  }

  /// 收件箱：箱身 + 内凹口。
  void _inbox(Path p) {
    p.moveTo(3, 13.5);
    p.lineTo(3, 18.5);
    p.lineTo(21, 18.5);
    p.lineTo(21, 13.5);
    p.lineTo(16, 13.5);
    p.lineTo(14, 10.5);
    p.lineTo(10, 10.5);
    p.lineTo(8, 13.5);
    p.close();
  }

  /// 打开文件夹：文件夹 + 前翻页。
  void _folderOpen(Path p) {
    p.moveTo(3, 19.5);
    p.lineTo(3, 5);
    p.lineTo(9.5, 5);
    p.lineTo(11.5, 7.5);
    p.lineTo(15.5, 7.5);
    p.lineTo(15.5, 10.5);
    p.moveTo(3, 19.5);
    p.lineTo(6, 12);
    p.lineTo(21.5, 12);
    p.lineTo(18, 19.5);
    p.close();
  }

  /// 文档（横线稿）：纸面 + 三条横线。
  void _docLines(Path p) {
    p.moveTo(5.5, 2.5);
    p.lineTo(14, 2.5);
    p.lineTo(19, 7.5);
    p.lineTo(19, 21.5);
    p.lineTo(5.5, 21.5);
    p.close();
    p.moveTo(14, 2.5);
    p.lineTo(14, 7.5);
    p.lineTo(19, 7.5);
    _line(p, 8.5, 12, 16, 12);
    _line(p, 8.5, 15.5, 16, 15.5);
  }

  /// 文本稿：纸面 + 短横线（备注）。
  void _docText(Path p) {
    p.moveTo(5.5, 2.5);
    p.lineTo(14, 2.5);
    p.lineTo(19, 7.5);
    p.lineTo(19, 21.5);
    p.lineTo(5.5, 21.5);
    p.close();
    p.moveTo(14, 2.5);
    p.lineTo(14, 7.5);
    p.lineTo(19, 7.5);
    _line(p, 8.5, 11.5, 16, 11.5);
    _line(p, 8.5, 15.5, 14, 15.5);
  }

  /// 网格视图：田字四格。
  void _grid(Path p) {
    p.addRRect(const RRect.fromLTRBXY(3.5, 3.5, 10.5, 10.5, 1.2, 1.2));
    p.addRRect(const RRect.fromLTRBXY(13.5, 3.5, 20.5, 10.5, 1.2, 1.2));
    p.addRRect(const RRect.fromLTRBXY(3.5, 13.5, 10.5, 20.5, 1.2, 1.2));
    p.addRRect(const RRect.fromLTRBXY(13.5, 13.5, 20.5, 20.5, 1.2, 1.2));
  }

  /// 列表视图：三条横条 + 左侧点。
  void _listView(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(4.5, 7), radius: 1.1));
    p.addOval(Rect.fromCircle(center: const Offset(4.5, 12), radius: 1.1));
    p.addOval(Rect.fromCircle(center: const Offset(4.5, 17), radius: 1.1));
    _line(p, 8.5, 7, 20, 7);
    _line(p, 8.5, 12, 20, 12);
    _line(p, 8.5, 17, 20, 17);
  }

  /// 拖拽把手：双横杠。
  void _dragHandle(Path p) {
    _line(p, 9, 7, 15, 7);
    _line(p, 9, 12, 15, 12);
    _line(p, 9, 17, 15, 17);
  }

  /// 可见：眼形 + 瞳。
  void _eye(Path p) {
    p.moveTo(2.5, 12);
    p.quadraticBezierTo(12, 5.5, 21.5, 12);
    p.quadraticBezierTo(12, 18.5, 2.5, 12);
    p.close();
    p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 2.6));
  }

  /// 隐藏：眼形 + 斜杠。
  void _eyeOff(Path p) {
    p.moveTo(2.5, 12);
    p.quadraticBezierTo(12, 5.5, 21.5, 12);
    p.quadraticBezierTo(12, 18.5, 2.5, 12);
    p.close();
    _line(p, 4, 20, 20, 4);
  }

  /// 锁：锁梁 + 锁体。
  void _lock(Path p) {
    p.addRRect(const RRect.fromLTRBXY(4.5, 10.5, 19.5, 20.5, 2, 2));
    p.moveTo(7.5, 10.5);
    p.lineTo(7.5, 7.5);
    p.cubicTo(7.5, 3.5, 16.5, 3.5, 16.5, 7.5);
    p.lineTo(16.5, 10.5);
  }

  /// 钥匙：环 + 齿。
  void _key(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(7.5, 8.5), radius: 4.5));
    _line(p, 10.6, 11.6, 19, 20);
    _line(p, 15.5, 16.5, 13, 19);
    _line(p, 17.5, 18.5, 15, 21);
  }

  /// 警告：三角 + 感叹号。
  void _warning(Path p) {
    p.moveTo(12, 3.5);
    p.lineTo(21.5, 20);
    p.lineTo(2.5, 20);
    p.close();
    _line(p, 12, 9.5, 12, 14.5);
    p.addOval(Rect.fromCircle(center: const Offset(12, 17.4), radius: 0.95));
  }

  /// 帮助：圆圈 + 问号。
  void _help(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 8.5));
    p.moveTo(9.2, 9.5);
    p.cubicTo(9.2, 7, 14.8, 7, 14.8, 9.8);
    p.cubicTo(14.8, 11.8, 12, 12.2, 12, 14.5);
    p.addOval(Rect.fromCircle(center: const Offset(12, 17.4), radius: 0.95));
  }

  /// 疑问：小问号（无外圈）。
  void _question(Path p) {
    p.moveTo(8, 7.5);
    p.cubicTo(8, 4.5, 16, 4.5, 16, 8.2);
    p.cubicTo(16, 11, 12, 11.5, 12, 15);
    p.addOval(Rect.fromCircle(center: const Offset(12, 18.4), radius: 0.95));
  }

  /// 菜单：三横。
  void _menuLines(Path p) {
    _line(p, 4, 7, 20, 7);
    _line(p, 4, 12, 20, 12);
    _line(p, 4, 17, 20, 17);
  }

  /// 更多：竖三点。
  void _moreVert(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 5.5), radius: 1.8));
    p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 1.8));
    p.addOval(Rect.fromCircle(center: const Offset(12, 18.5), radius: 1.8));
  }

  /// 标记：旗。
  void _flag(Path p) {
    _line(p, 5.5, 3, 5.5, 21.5);
    p.moveTo(5.5, 4);
    p.lineTo(18, 4);
    p.lineTo(14.5, 9);
    p.lineTo(18, 14);
    p.lineTo(5.5, 14);
  }

  /// 图钉：钉身 + 针尖。
  void _pin(Path p) {
    p.moveTo(12, 14.5);
    p.lineTo(12, 21.5);
    p.moveTo(12, 3);
    p.cubicTo(7.5, 3, 7.5, 8.5, 7.5, 8.5);
    p.lineTo(4, 12.5);
    p.lineTo(20, 12.5);
    p.lineTo(16.5, 8.5);
    p.cubicTo(16.5, 8.5, 16.5, 3, 12, 3);
    p.close();
  }

  /// 时钟：钟面 + 指针。
  void _clock(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 8.5));
    _line(p, 12, 6.5, 12, 12);
    _line(p, 12, 12, 16, 14.5);
  }

  /// 日程：钟面 + 外环刻度（待办/日程）。
  void _schedule(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 7));
    _line(p, 12, 8, 12, 12);
    _line(p, 12, 12, 15, 14);
    _line(p, 12, 1.5, 12, 4);
    _line(p, 12, 20, 12, 22.5);
    _line(p, 1.5, 12, 4, 12);
    _line(p, 20, 12, 22.5, 12);
  }

  /// 沙漏：上下壶 + 中腰。
  void _hourglass(Path p) {
    p.moveTo(5.5, 3);
    p.lineTo(18.5, 3);
    p.lineTo(18.5, 6);
    p.lineTo(13, 12);
    p.lineTo(18.5, 18);
    p.lineTo(18.5, 21);
    p.lineTo(5.5, 21);
    p.lineTo(5.5, 18);
    p.lineTo(11, 12);
    p.lineTo(5.5, 6);
    p.close();
  }

  /// 计时器：顶钮 + 钟身 + 按键。
  void _timer(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 13.5), radius: 7.5));
    _line(p, 12, 3, 12, 5.5);
    _line(p, 9, 3, 15, 3);
    _line(p, 19, 8, 20.5, 6.5);
    _line(p, 12, 10.5, 12, 13.5);
    _line(p, 12, 13.5, 15, 15.5);
  }

  /// 循环箭头：环形 + 箭头。
  void _repeatArrow(Path p) {
    p.addRRect(const RRect.fromLTRBXY(4, 6.5, 20, 17.5, 5.5, 5.5));
    p.moveTo(14.5, 4.5);
    p.lineTo(18, 6.5);
    p.lineTo(14.5, 8.5);
    p.moveTo(9.5, 19.5);
    p.lineTo(6, 17.5);
    p.lineTo(9.5, 15.5);
  }

  /// 上移（置顶）：上箭头 + 底横线。
  void _moveUp(Path p) {
    _line(p, 12, 20, 12, 5);
    p.moveTo(6.5, 10.5);
    p.lineTo(12, 5);
    p.lineTo(17.5, 10.5);
  }

  /// 附件：回形针。
  void _attach(Path p) {
    p.moveTo(20, 11.5);
    p.lineTo(11.5, 20);
    p.cubicTo(8.5, 23, 4, 18.5, 7, 15.5);
    p.lineTo(15.5, 7);
    p.cubicTo(18.5, 4, 22, 7.5, 19, 10.5);
    p.lineTo(10.5, 19);
    p.cubicTo(9, 20.5, 6.5, 18, 8, 16.5);
    p.lineTo(16, 8.5);
  }

  /// 视频：摄像机 + 镜头。
  void _video(Path p) {
    p.addRRect(const RRect.fromLTRBXY(2.5, 7.5, 14, 16.5, 2, 2));
    p.moveTo(14, 11);
    p.lineTo(20.5, 7.5);
    p.lineTo(20.5, 16.5);
    p.lineTo(14, 13);
  }

  /// 医药箱：箱体 + 十字。
  void _medicalBag(Path p) {
    p.addRRect(const RRect.fromLTRBXY(3, 6.5, 21, 20, 2, 2));
    p.moveTo(9, 6.5);
    p.lineTo(9, 4.5);
    p.lineTo(15, 4.5);
    p.lineTo(15, 6.5);
    _line(p, 12, 10, 12, 16.5);
    _line(p, 8.75, 13.25, 15.25, 13.25);
  }

  /// 翻译：文 + A 对照。
  void _translate(Path p) {
    p.moveTo(3, 6.5);
    p.lineTo(9, 6.5);
    p.moveTo(6, 4.5);
    p.lineTo(6, 6.5);
    p.cubicTo(6, 11, 4, 13.5, 3, 14.5);
    p.cubicTo(4.5, 12.5, 5.5, 12, 6, 11.5);
    p.moveTo(10.5, 19.5);
    p.lineTo(13.5, 10.5);
    p.lineTo(16.5, 19.5);
    p.moveTo(11.6, 16.5);
    p.lineTo(15.4, 16.5);
  }

  /// 画笔（自定义分类）：笔杆 + 笔尖。
  void _paintBrush(Path p) {
    p.moveTo(14.5, 3.5);
    p.lineTo(20.5, 9.5);
    p.lineTo(10, 20);
    p.lineTo(4, 14);
    p.close();
    _line(p, 4, 14, 7, 17);
    _line(p, 8.5, 9.5, 14.5, 15.5);
  }

  /// 应用：四宫格。
  void _apps(Path p) {
    p.addRRect(const RRect.fromLTRBXY(3.5, 3.5, 10.5, 10.5, 1.5, 1.5));
    p.addRRect(const RRect.fromLTRBXY(13.5, 3.5, 20.5, 10.5, 1.5, 1.5));
    p.addRRect(const RRect.fromLTRBXY(3.5, 13.5, 10.5, 20.5, 1.5, 1.5));
    p.addRRect(const RRect.fromLTRBXY(13.5, 13.5, 20.5, 20.5, 1.5, 1.5));
  }

  /// 苹果：双叶 + 果身。
  void _apple(Path p) {
    p.moveTo(12, 8.5);
    p.cubicTo(9.5, 5.5, 4.5, 6, 3.5, 11);
    p.cubicTo(2.5, 16, 6, 20.5, 9, 20.5);
    p.cubicTo(10.5, 20.5, 11, 19.5, 12, 19.5);
    p.cubicTo(13, 19.5, 13.5, 20.5, 15, 20.5);
    p.cubicTo(18, 20.5, 21.5, 16, 20.5, 11);
    p.cubicTo(19.5, 6, 14.5, 5.5, 12, 8.5);
    p.close();
    _line(p, 12, 8.5, 12, 4.5);
    p.moveTo(12, 5.5);
    p.cubicTo(13.5, 2.5, 16.5, 2.5, 17, 3.5);
    p.cubicTo(16, 5.5, 13.5, 6.5, 12, 5.5);
  }

  /// 自动：魔法棒 + 星。
  void _cameraAuto(Path p) {
    _line(p, 4, 20, 14, 10);
    _line(p, 11, 4.5, 12, 8.5);
    _line(p, 15.5, 7, 14, 10);
    _line(p, 19, 11.5, 15, 10.5);
    p.moveTo(17, 15);
    p.lineTo(18.3, 18.2);
    p.lineTo(21.5, 19.5);
    p.lineTo(18.3, 20.8);
    p.lineTo(17, 24);
    p.lineTo(15.7, 20.8);
    p.lineTo(12.5, 19.5);
    p.lineTo(15.7, 18.2);
    p.close();
  }

  /// 闪亮：三颗小星。
  void _sparkles(Path p) {
    p.moveTo(8.5, 3);
    p.lineTo(10, 6.5);
    p.lineTo(13.5, 8);
    p.lineTo(10, 9.5);
    p.lineTo(8.5, 13);
    p.lineTo(7, 9.5);
    p.lineTo(3.5, 8);
    p.lineTo(7, 6.5);
    p.close();
    p.moveTo(17, 11);
    p.lineTo(18.2, 14);
    p.lineTo(21, 15.2);
    p.lineTo(18.2, 16.4);
    p.lineTo(17, 19.5);
    p.lineTo(15.8, 16.4);
    p.lineTo(13, 15.2);
    p.lineTo(15.8, 14);
    p.close();
    p.moveTo(15.5, 18.5);
    p.lineTo(16.2, 20.5);
    p.lineTo(18, 21.2);
    p.lineTo(16.2, 21.9);
    p.lineTo(15.5, 24);
  }

  /// 环保：叶片 + 叶脉。
  void _eco(Path p) {
    p.moveTo(4, 20);
    p.cubicTo(4, 9, 12, 4, 20, 4);
    p.cubicTo(20, 13, 15, 20, 4, 20);
    p.close();
    _line(p, 4, 20, 16, 8);
  }

  /// 伞：伞面 + 伞柄。
  void _umbrella(Path p) {
    p.moveTo(2.5, 12.5);
    p.cubicTo(2.5, 6.5, 7, 4.5, 12, 4.5);
    p.cubicTo(17, 4.5, 21.5, 6.5, 21.5, 12.5);
    p.cubicTo(19.5, 10.5, 16.5, 10.5, 14.5, 12.5);
    p.cubicTo(13.5, 10.5, 10.5, 10.5, 9.5, 12.5);
    p.cubicTo(7.5, 10.5, 4.5, 10.5, 2.5, 12.5);
    p.close();
    _line(p, 12, 4.5, 12, 18.5);
    p.moveTo(12, 18.5);
    p.cubicTo(12, 21.5, 8, 21.5, 8, 19);
  }

  /// 温泉：气泡 + 蒸汽。
  void _spa(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(9, 16), radius: 5.5));
    p.addOval(Rect.fromCircle(center: const Offset(17.5, 12.5), radius: 3.5));
    p.addOval(Rect.fromCircle(center: const Offset(16, 19), radius: 2.2));
  }

  /// 清洁：扫帚。
  void _hygiene(Path p) {
    _line(p, 14.5, 3.5, 14.5, 11);
    p.moveTo(11, 11);
    p.lineTo(18, 11);
    p.lineTo(19.5, 20.5);
    p.lineTo(9.5, 20.5);
    p.close();
    _line(p, 12, 14.5, 17, 14.5);
    _line(p, 11.5, 17.5, 17.5, 17.5);
  }

  /// 儿童：小人 + 双辫。
  void _child(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 8.5), radius: 4));
    p.moveTo(6, 20.5);
    p.cubicTo(6, 15, 9, 13.5, 12, 13.5);
    p.cubicTo(15, 13.5, 18, 15, 18, 20.5);
    p.moveTo(6.5, 5.5);
    p.cubicTo(5, 8, 5, 10.5, 6, 12);
    p.moveTo(17.5, 5.5);
    p.cubicTo(19, 8, 19, 10.5, 18, 12);
  }

  /// 徽章：绶带 + 星。
  void _badge(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 9), radius: 6));
    _line(p, 8, 14, 6.5, 21.5);
    _line(p, 16, 14, 17.5, 21.5);
    _line(p, 6.5, 21.5, 10, 19);
    _line(p, 17.5, 21.5, 14, 19);
    p.moveTo(12, 5.5);
    p.lineTo(12.9, 8);
    p.lineTo(15.5, 8.2);
    p.lineTo(13.5, 9.9);
    p.lineTo(14.1, 12.4);
    p.lineTo(12, 10.9);
    p.lineTo(9.9, 12.4);
    p.lineTo(10.5, 9.9);
    p.lineTo(8.5, 8.2);
    p.lineTo(11.1, 8);
    p.close();
  }

  /// 表情：脸 + 眼 + 嘴。
  void _face(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 8.5));
    p.addOval(Rect.fromCircle(center: const Offset(9, 10), radius: 0.95));
    p.addOval(Rect.fromCircle(center: const Offset(15, 10), radius: 0.95));
    p.moveTo(8.5, 15);
    p.quadraticBezierTo(12, 18, 15.5, 15);
  }

  /// 宝石：切面菱形。
  void _gem(Path p) {
    p.moveTo(6, 4.5);
    p.lineTo(18, 4.5);
    p.lineTo(21.5, 10);
    p.lineTo(12, 21.5);
    p.lineTo(2.5, 10);
    p.close();
    _line(p, 6, 4.5, 8.5, 10);
    _line(p, 18, 4.5, 15.5, 10);
    _line(p, 2.5, 10, 21.5, 10);
    _line(p, 8.5, 10, 12, 21.5);
    _line(p, 15.5, 10, 12, 21.5);
  }

  /// 椅子：靠背 + 坐面 + 腿。
  void _chair(Path p) {
    p.moveTo(6, 3.5);
    p.lineTo(6, 12.5);
    p.lineTo(18, 12.5);
    p.lineTo(18, 3.5);
    p.moveTo(6, 8);
    p.lineTo(18, 8);
    _line(p, 4, 16.5, 20, 16.5);
    _line(p, 6, 16.5, 5, 21);
    _line(p, 18, 16.5, 19, 21);
  }

  /// 衣架：挂钩 + 三角架。
  void _clothing(Path p) {
    p.moveTo(12, 3);
    p.cubicTo(10, 3, 9.5, 5.5, 11.5, 6);
    p.lineTo(12, 7);
    p.lineTo(3.5, 13);
    p.lineTo(5, 15);
    p.lineTo(19, 15);
    p.lineTo(20.5, 13);
    p.close();
  }

  /// 会员卡：卡 + 齿。
  void _membership(Path p) {
    p.addRRect(const RRect.fromLTRBXY(2.5, 5, 21.5, 16, 2, 2));
    p.addOval(Rect.fromCircle(center: const Offset(8, 10.5), radius: 2.5));
    _line(p, 13.5, 8.5, 18, 8.5);
    _line(p, 13.5, 12, 17, 12);
    p.moveTo(7, 16);
    p.lineTo(7, 20.5);
  }

  /// 权限：盾 + 勾。
  void _permission(Path p) {
    p.moveTo(12, 3);
    p.lineTo(20, 6.5);
    p.lineTo(20, 12);
    p.cubicTo(20, 17, 16, 19.5, 12, 21.5);
    p.cubicTo(8, 19.5, 4, 17, 4, 12);
    p.lineTo(4, 6.5);
    p.close();
    p.moveTo(8.5, 12);
    p.lineTo(11, 14.5);
    p.lineTo(15.5, 9.5);
  }

  /// 群组：双人。
  void _group(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(9, 8), radius: 3.4));
    p.cubicTo(4, 12.5, 3.5, 16, 3.5, 19.5);
    p.lineTo(14.5, 19.5);
    p.cubicTo(14.5, 16, 14, 12.5, 9, 12.5);
    p.close();
    p.addArc(
      Rect.fromCircle(center: const Offset(17, 8.5), radius: 2.9),
      -1.2,
      3.4,
    );
    p.cubicTo(19.5, 13, 20.5, 16, 20.5, 19.5);
  }

  /// 安卓：机器人头 + 天线。
  void _android(Path p) {
    p.addRRect(const RRect.fromLTRBXY(5, 7.5, 19, 18, 3, 3));
    _line(p, 9, 4.5, 10.5, 7.5);
    _line(p, 15, 4.5, 13.5, 7.5);
    p.addOval(Rect.fromCircle(center: const Offset(9.5, 11), radius: 0.9));
    p.addOval(Rect.fromCircle(center: const Offset(14.5, 11), radius: 0.9));
    _line(p, 5.5, 3.5, 8.5, 4.5);
    _line(p, 18.5, 3.5, 15.5, 4.5);
  }

  /// 已验证：圆 + 勾（认证章）。
  void _verified(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 8.5));
    p.moveTo(7.8, 12.2);
    p.lineTo(10.8, 15.2);
    p.lineTo(16.4, 8.8);
  }

  /// 明暗对比：外圆 + 竖分割 + 弧。
  void _contrast(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 8.5));
    _line(p, 12, 3.5, 12, 20.5);
    p.arcToPoint(
      const Offset(12, 3.5),
      radius: const Radius.circular(8.5),
      clockwise: false,
    );
  }

  /// 应用宫格：三行圆点。
  void _appsGrid(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(6, 6), radius: 2));
    p.addOval(Rect.fromCircle(center: const Offset(12, 6), radius: 2));
    p.addOval(Rect.fromCircle(center: const Offset(18, 6), radius: 2));
    p.addOval(Rect.fromCircle(center: const Offset(6, 12), radius: 2));
    p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 2));
    p.addOval(Rect.fromCircle(center: const Offset(18, 12), radius: 2));
    p.addOval(Rect.fromCircle(center: const Offset(6, 18), radius: 2));
    p.addOval(Rect.fromCircle(center: const Offset(12, 18), radius: 2));
    p.addOval(Rect.fromCircle(center: const Offset(18, 18), radius: 2));
  }

  /// 存储（内存条）：条身 + 触点。
  void _memory(Path p) {
    p.addRRect(const RRect.fromLTRBXY(2.5, 7, 21.5, 15, 1.5, 1.5));
    _line(p, 6.5, 10.5, 17.5, 10.5);
    _line(p, 6.5, 12.5, 17.5, 12.5);
    _line(p, 5.5, 15, 5.5, 18);
    _line(p, 9.5, 15, 9.5, 18);
    _line(p, 13.5, 15, 13.5, 18);
    _line(p, 17.5, 15, 17.5, 18);
  }

  /// 输入框：框 + 光标行。
  void _textFields(Path p) {
    p.addRRect(const RRect.fromLTRBXY(3, 5, 21, 17, 2, 2));
    _line(p, 3, 10, 21, 10);
    _line(p, 6.5, 13.5, 13, 13.5);
    _line(p, 6.5, 17, 21, 17);
  }

  /// 筛选列表：三条带勾横行。
  void _filterList(Path p) {
    _line(p, 3, 7, 8, 7);
    _line(p, 11, 7, 21, 7);
    _line(p, 3, 12, 8, 12);
    _line(p, 11, 12, 21, 12);
    _line(p, 3, 17, 8, 17);
    _line(p, 11, 17, 21, 17);
  }

  /// 显示器：屏 + 底座。
  void _monitor(Path p) {
    p.addRRect(const RRect.fromLTRBXY(2.5, 4, 21.5, 16, 2, 2));
    _line(p, 12, 16, 12, 20);
    _line(p, 7.5, 20, 16.5, 20);
  }

  /// 挂钟：钟面 + 挂钉 + 指针。
  void _wall(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 13), radius: 7.5));
    _line(p, 12, 8.5, 12, 13);
    _line(p, 12, 13, 15.5, 15);
    _line(p, 9, 5.5, 15, 5.5);
    _line(p, 12, 5.5, 12, 3);
  }

  /// 海滩：遮阳伞 + 椅。
  void _beach(Path p) {
    p.moveTo(2.5, 11.5);
    p.cubicTo(2.5, 7, 7, 4.5, 11, 4.5);
    p.cubicTo(15, 4.5, 19.5, 7, 19.5, 11.5);
    p.cubicTo(17, 9.5, 14, 9.5, 11.5, 11.5);
    p.cubicTo(9, 9.5, 5, 9.5, 2.5, 11.5);
    p.close();
    _line(p, 11, 4.5, 11, 20.5);
    _line(p, 4.5, 16, 14.5, 16);
    _line(p, 4.5, 16, 3.5, 20.5);
    _line(p, 14.5, 16, 15.5, 20.5);
  }

  /// 游泳：泳池 + 泳者头。
  void _swimming(Path p) {
    _line(p, 2.5, 17, 8.5, 17);
    p.moveTo(12, 17);
    p.lineTo(18, 17);
    p.lineTo(21.5, 17);
    p.addOval(Rect.fromCircle(center: const Offset(7, 9.5), radius: 2.5));
    _line(p, 9, 11.5, 12.5, 14.5);
    _line(p, 12.5, 14.5, 16, 11.5);
  }

  /// 徒步：山 + 人。
  void _hiking(Path p) {
    p.moveTo(2.5, 19);
    p.lineTo(9.5, 7.5);
    p.lineTo(14, 14.5);
    p.lineTo(16.5, 10.5);
    p.lineTo(21.5, 19);
    p.close();
    p.addOval(Rect.fromCircle(center: const Offset(6, 4.5), radius: 1.8));
    _line(p, 6, 6.5, 6, 10);
  }

  /// 游戏：手柄。
  void _games(Path p) {
    p.addRRect(const RRect.fromLTRBXY(2, 8, 22, 17, 4.5, 4.5));
    _line(p, 6, 11, 6, 15);
    _line(p, 4, 13, 8, 13);
    p.addOval(Rect.fromCircle(center: const Offset(16, 11.5), radius: 1.2));
    p.addOval(Rect.fromCircle(center: const Offset(19, 14.5), radius: 1.2));
  }

  /// 场馆：拱顶 + 立柱。
  void _stadium(Path p) {
    p.moveTo(2.5, 20.5);
    p.lineTo(2.5, 11);
    p.cubicTo(2.5, 4, 21.5, 4, 21.5, 11);
    p.lineTo(21.5, 20.5);
    _line(p, 2.5, 20.5, 21.5, 20.5);
    _line(p, 7.5, 11, 7.5, 20.5);
    _line(p, 16.5, 11, 16.5, 20.5);
    p.moveTo(7.5, 11);
    p.cubicTo(7.5, 7.5, 16.5, 7.5, 16.5, 11);
  }

  /// 菜单书：翻开的两页。
  void _menuBook(Path p) {
    p.moveTo(12, 6.5);
    p.cubicTo(10, 4.5, 7, 4.5, 3, 5);
    p.lineTo(3, 18.5);
    p.cubicTo(7, 18, 10, 18, 12, 20);
    p.cubicTo(14, 18, 17, 18, 21, 18.5);
    p.lineTo(21, 5);
    p.cubicTo(17, 4.5, 14, 4.5, 12, 6.5);
    p.close();
    _line(p, 12, 6.5, 12, 20);
  }

  /// POS 机：机身 + 屏 + 键。
  void _pointOfSale(Path p) {
    p.addRRect(const RRect.fromLTRBXY(4, 2.5, 20, 15, 2, 2));
    p.addRRect(const RRect.fromLTRBXY(7, 5, 17, 10, 1, 1));
    _line(p, 7, 12.5, 17, 12.5);
    _line(p, 6.5, 15, 6.5, 21.5);
    _line(p, 17.5, 15, 17.5, 21.5);
  }

  /// 积分：星章 + 齿。
  void _loyalty(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 8.5));
    p.moveTo(12, 6.5);
    p.lineTo(13.4, 10.4);
    p.lineTo(17.5, 10.7);
    p.lineTo(14.2, 13.3);
    p.lineTo(15.5, 17.2);
    p.lineTo(12, 14.9);
    p.lineTo(8.5, 17.2);
    p.lineTo(9.8, 13.3);
    p.lineTo(6.5, 10.7);
    p.lineTo(10.6, 10.4);
    p.close();
  }

  /// 房间：门 + 把手。
  void _room(Path p) {
    p.addRRect(const RRect.fromLTRBXY(5, 3, 19, 21, 1.5, 1.5));
    p.addOval(Rect.fromCircle(center: const Offset(15.5, 12.5), radius: 1));
  }

  /// 育儿：大人 + 小人。
  void _childCare(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(9, 7.5), radius: 3.2));
    p.moveTo(3, 20.5);
    p.cubicTo(3, 15, 5.5, 13, 9, 13);
    p.cubicTo(12.5, 13, 15, 15, 15, 20.5);
    p.addOval(Rect.fromCircle(center: const Offset(18, 14), radius: 2.2));
    p.moveTo(14.5, 20.5);
    p.cubicTo(14.5, 17.5, 16, 16.5, 18, 16.5);
    p.cubicTo(20, 16.5, 21.5, 17.5, 21.5, 20.5);
  }

  /// 长者：拄杖老人。
  void _elderly(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(11.5, 5.5), radius: 2.8));
    p.moveTo(11.5, 8.5);
    p.lineTo(11.5, 14);
    p.moveTo(11.5, 14);
    p.lineTo(8, 20.5);
    p.moveTo(11.5, 14);
    p.lineTo(15.5, 20.5);
    _line(p, 11.5, 10.5, 16.5, 10.5);
    _line(p, 16.5, 10.5, 16.5, 21.5);
  }

  /// 结算：手 + 币。
  void _handshakeMoney(Path p) {
    p.moveTo(2.5, 14.5);
    p.lineTo(7, 10.5);
    p.lineTo(11, 13);
    p.lineTo(15, 10.5);
    p.lineTo(19.5, 14.5);
    _line(p, 2.5, 14.5, 6, 17);
    p.addOval(Rect.fromCircle(center: const Offset(16.5, 6.5), radius: 3.5));
  }

  /// 天平：横梁 + 双盘 + 立柱。
  void _balance(Path p) {
    _line(p, 12, 5, 12, 20);
    _line(p, 4, 8, 20, 8);
    _line(p, 8, 20.5, 16, 20.5);
    p.addArc(
      Rect.fromCircle(center: const Offset(4, 12), radius: 3.2),
      0,
      3.1416,
    );
    p.addArc(
      Rect.fromCircle(center: const Offset(20, 12), radius: 3.2),
      0,
      3.1416,
    );
    p.moveTo(0.8, 12);
    p.lineTo(7.2, 12);
    p.moveTo(16.8, 12);
    p.lineTo(23.2, 12);
  }

  /// 工具：扳手。
  void _handyman(Path p) {
    p.moveTo(20.5, 4);
    p.cubicTo(18, 3, 15, 4.5, 14, 7);
    p.lineTo(5.5, 15.5);
    p.cubicTo(3.5, 17.5, 4.5, 20.5, 6.5, 20.5);
    p.cubicTo(8.5, 20.5, 9.5, 18.5, 11, 17);
    p.lineTo(17.5, 6.5);
    p.cubicTo(19.5, 5, 21, 5.5, 20.5, 4);
    p.moveTo(14, 7);
    p.cubicTo(14, 4.5, 16, 2.5, 19, 3);
  }

  /// 施工：三角警示 + 斜纹。
  void _construction(Path p) {
    p.moveTo(12, 3.5);
    p.lineTo(21.5, 20);
    p.lineTo(2.5, 20);
    p.close();
    _line(p, 9.5, 12.5, 14.5, 18);
    _line(p, 14.5, 12.5, 9.5, 18);
  }

  /// 成交：双手击掌。
  void _handshakeDeal(Path p) {
    p.moveTo(2.5, 9.5);
    p.lineTo(8, 7);
    p.lineTo(12, 11);
    p.lineTo(16, 7);
    p.lineTo(21.5, 9.5);
    p.moveTo(12, 11);
    p.lineTo(12, 17.5);
    _line(p, 8, 7, 8, 13);
    _line(p, 16, 7, 16, 13);
  }

  /// 上传完成：云 + 勾。
  void _uploaded(Path p) {
    _cloud(p);
    p.moveTo(9, 14);
    p.lineTo(11.5, 16.5);
    p.lineTo(15.5, 11.5);
  }

  /// 指派：回转箭头。
  void _assign(Path p) {
    p.arcToPoint(
      const Offset(19, 8),
      radius: const Radius.circular(7.5),
      clockwise: false,
      largeArc: true,
    );
    p.moveTo(19, 3.5);
    p.lineTo(19, 8);
    p.lineTo(14.5, 8);
    _line(p, 5, 12, 5, 16.5);
    p.moveTo(5, 16.5);
    p.lineTo(8.5, 13.5);
    p.moveTo(5, 16.5);
    p.lineTo(1.5, 13.5);
  }

  /// 定时发送：钟 + 箭头。
  void _scheduleSend(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 8));
    _line(p, 12, 6.5, 12, 12);
    _line(p, 12, 12, 15.5, 14);
    p.moveTo(4.5, 20);
    p.lineTo(19.5, 20);
    p.moveTo(16.5, 17);
    p.lineTo(19.5, 20);
    p.lineTo(16.5, 23);
  }

  /// 智能推荐：魔法棒 + 环绕点。
  void _autoAwesome(Path p) {
    _line(p, 4, 20, 13, 11);
    _line(p, 10.5, 5.5, 11.5, 9.5);
    _line(p, 16, 8.5, 14.5, 11.5);
    _line(p, 19.5, 12.5, 16, 12);
    p.addOval(Rect.fromCircle(center: const Offset(18, 5.5), radius: 1.2));
    p.addOval(Rect.fromCircle(center: const Offset(5.5, 5), radius: 1.2));
    p.addOval(Rect.fromCircle(center: const Offset(20.5, 18), radius: 1.2));
  }

  /// 魔法：四角星。
  void _magic(Path p) {
    p.moveTo(12, 2.5);
    p.lineTo(14, 9);
    p.lineTo(20.5, 11);
    p.lineTo(14, 13);
    p.lineTo(12, 19.5);
    p.lineTo(10, 13);
    p.lineTo(3.5, 11);
    p.lineTo(10, 9);
    p.close();
  }

  /// 多语言：文 + A。
  void _translateLang(Path p) {
    _line(p, 2.5, 6.5, 8.5, 6.5);
    _line(p, 5.5, 4.5, 5.5, 6.5);
    p.cubicTo(5.5, 10.5, 3.5, 13, 2.5, 14);
    p.moveTo(11, 19.5);
    p.lineTo(14, 10);
    p.lineTo(17, 19.5);
    p.moveTo(12.2, 16);
    p.lineTo(15.8, 16);
    _line(p, 18.5, 4.5, 18.5, 11);
    p.moveTo(16.5, 6.5);
    p.lineTo(20.5, 6.5);
  }

  /// 附件（回形针简化）：夹子。
  void _attachment(Path p) {
    p.addArc(
      Rect.fromCircle(center: const Offset(17, 12), radius: 5),
      -1.6,
      3.2,
    );
    p.moveTo(17, 7);
    p.lineTo(17, 17);
    p.cubicTo(17, 21, 11, 21, 11, 17);
    p.lineTo(11, 8.5);
    p.cubicTo(11, 5.5, 15.5, 5.5, 15.5, 8.5);
    p.lineTo(15.5, 15);
  }

  /// 书签框：空心书签。
  void _bookmarkBorder(Path p) {
    p.moveTo(6, 3.5);
    p.lineTo(18, 3.5);
    p.lineTo(18, 20.5);
    p.lineTo(12, 16);
    p.lineTo(6, 20.5);
    p.close();
  }

  /// 可见性：眼 + 勾。
  void _visibility(Path p) {
    p.moveTo(2.5, 12);
    p.quadraticBezierTo(12, 5.5, 21.5, 12);
    p.quadraticBezierTo(12, 18.5, 2.5, 12);
    p.close();
    p.moveTo(9.5, 12.2);
    p.lineTo(11.5, 14.2);
    p.lineTo(15, 9.8);
  }

  /// 强筛选：漏斗 + 勾。
  void _filterAlt(Path p) {
    p.moveTo(3, 5.5);
    p.lineTo(21, 5.5);
    p.lineTo(14, 13.5);
    p.lineTo(14, 20);
    p.lineTo(10, 17.5);
    p.lineTo(10, 13.5);
    p.close();
  }

  /// 仪表盘：半圆表盘 + 指针。
  void _dashboard(Path p) {
    p.arcToPoint(
      const Offset(20.5, 18),
      radius: const Radius.circular(9),
      clockwise: true,
      largeArc: true,
    );
    _line(p, 3.5, 18, 20.5, 18);
    _line(p, 12, 18, 16, 12);
  }

  /// 排行榜：三阶柱。
  void _leaderboard(Path p) {
    _line(p, 3.5, 20.5, 20.5, 20.5);
    p.addRRect(const RRect.fromLTRBXY(4.5, 13, 8.5, 20.5, 1, 1));
    p.addRRect(const RRect.fromLTRBXY(10, 7, 14, 20.5, 1, 1));
    p.addRRect(const RRect.fromLTRBXY(15.5, 10, 19.5, 20.5, 1, 1));
  }

  /// 离线：云 + 斜杠。
  void _offline(Path p) {
    p.moveTo(7, 17.5);
    p.cubicTo(4.2, 17.5, 3.2, 14.8, 5.5, 13.4);
    p.cubicTo(5, 9.6, 9.2, 7.2, 12.5, 9.2);
    p.cubicTo(15.8, 7.2, 19, 9.6, 18.5, 12.8);
    p.cubicTo(20.8, 14.2, 19.4, 17.5, 16.2, 17.5);
    _line(p, 4, 21, 20, 4);
  }

  /// 代理（VPN）：盾 + 键。
  void _vpn(Path p) {
    p.moveTo(12, 3);
    p.lineTo(20, 6.5);
    p.lineTo(20, 12);
    p.cubicTo(20, 17, 16, 19.5, 12, 21.5);
    p.cubicTo(8, 19.5, 4, 17, 4, 12);
    p.lineTo(4, 6.5);
    p.close();
    p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 2.4));
    _line(p, 12, 9.6, 12, 7.4);
    _line(p, 12, 14.4, 12, 16.6);
    _line(p, 9.6, 12, 7.4, 12);
    _line(p, 14.4, 12, 16.6, 12);
  }

  /// 错误：圆 + 叉。
  void _error(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 8.5));
    _line(p, 8.5, 8.5, 15.5, 15.5);
    _line(p, 15.5, 8.5, 8.5, 15.5);
  }

  /// 闹钟：钟身 + 双铃 + 指针。
  void _scheduleClock(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 13), radius: 7));
    _line(p, 12, 9, 12, 13);
    _line(p, 12, 13, 15, 15);
    _line(p, 4, 6, 7, 3.5);
    _line(p, 20, 6, 17, 3.5);
    _line(p, 7, 19.5, 5.5, 21.5);
    _line(p, 17, 19.5, 18.5, 21.5);
  }

  /// 备选路线：分岔箭头。
  void _altRoute(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(5.5, 5.5), radius: 2.5));
    p.addOval(Rect.fromCircle(center: const Offset(18.5, 18.5), radius: 2.5));
    p.moveTo(5.5, 8);
    p.lineTo(5.5, 14);
    p.quadraticBezierTo(5.5, 18.5, 10, 18.5);
    p.lineTo(16, 18.5);
    p.moveTo(18.5, 16);
    p.lineTo(18.5, 10);
    p.quadraticBezierTo(18.5, 5.5, 14, 5.5);
    p.lineTo(10.5, 5.5);
  }

  /// 时间轴：竖线 + 三节点。
  void _timeline(Path p) {
    _line(p, 8, 3.5, 8, 20.5);
    p.addOval(Rect.fromCircle(center: const Offset(8, 7), radius: 2.2));
    p.addOval(Rect.fromCircle(center: const Offset(8, 16.5), radius: 2.2));
    _line(p, 12, 7, 20, 7);
    _line(p, 12, 16.5, 20, 16.5);
  }

  /// 分割线：中间带节点的横线。
  void _horizontalRule(Path p) {
    _line(p, 2.5, 12, 9, 12);
    _line(p, 15, 12, 21.5, 12);
    p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 2));
  }

  /// 删除：垃圾桶 + 斜杠（比 trash 更强调「不可逆」）。
  void _deleteOutline(Path p) {
    _line(p, 3, 6, 21, 6);
    _line(p, 8, 6, 8, 4);
    _line(p, 8, 4, 16, 4);
    _line(p, 16, 4, 16, 6);
    p.moveTo(6, 6);
    p.lineTo(7, 20);
    p.lineTo(17, 20);
    p.lineTo(18, 6);
    _line(p, 10, 10, 10, 16);
    _line(p, 14, 10, 14, 16);
    _line(p, 4, 20.5, 20, 3.5);
  }

  /// 喜欢：心形。
  void _heart(Path p) {
    p.moveTo(12, 20.5);
    p.cubicTo(3.5, 14.5, 3.5, 7.5, 8.5, 5.5);
    p.cubicTo(11, 4.3, 12, 6.8, 12, 8);
    p.cubicTo(12, 6.8, 13, 4.3, 15.5, 5.5);
    p.cubicTo(20.5, 7.5, 20.5, 14.5, 12, 20.5);
    p.close();
  }

  /// 圆点（金额键盘小数点）。
  void _circle(Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 4.5));
  }

  /// 储蓄：储蓄罐 + 投币口。
  void _savings(Path p) {
    p.moveTo(4, 12);
    p.cubicTo(4, 7.5, 8, 5.5, 12.5, 6);
    p.cubicTo(18, 6.5, 21, 10.5, 21, 14.5);
    p.cubicTo(21, 18, 17.5, 19.5, 13, 19.5);
    p.cubicTo(8.5, 19.5, 4, 18, 4, 12);
    p.close();
    _line(p, 10, 3.5, 15, 3.5);
    _line(p, 15.5, 7, 18.5, 8.5);
    _line(p, 5.5, 13.5, 8, 14);
    p.addOval(Rect.fromCircle(center: const Offset(17.5, 12.5), radius: 0.9));
  }

  /// 商铺：店招 + 门。
  void _store(Path p) {
    p.moveTo(3.5, 9.5);
    p.lineTo(5, 4.5);
    p.lineTo(19, 4.5);
    p.lineTo(20.5, 9.5);
    p.close();
    _line(p, 3.5, 9.5, 20.5, 9.5);
    p.moveTo(5, 9.5);
    p.lineTo(5, 20.5);
    p.lineTo(19, 20.5);
    p.lineTo(19, 9.5);
    p.moveTo(9.5, 20.5);
    p.lineTo(9.5, 14);
    p.lineTo(14.5, 14);
    p.lineTo(14.5, 20.5);
  }

  /// 多设备：屏 + 触控笔。
  void _devices(Path p) {
    p.addRRect(const RRect.fromLTRBXY(2.5, 4, 16, 16.5, 2, 2));
    _line(p, 6, 19, 12.5, 19);
    _line(p, 9.25, 16.5, 9.25, 19);
    p.moveTo(20.5, 6.5);
    p.lineTo(20.5, 21);
    p.lineTo(16.5, 21);
    p.lineTo(16.5, 19.5);
  }

  /// 计算器：机身 + 屏 + 键。
  void _calculator(Path p) {
    p.addRRect(const RRect.fromLTRBXY(4.5, 2.5, 19.5, 21.5, 2, 2));
    p.addRRect(const RRect.fromLTRBXY(7.5, 5.5, 16.5, 9, 1, 1));
    p.addOval(Rect.fromCircle(center: const Offset(8.5, 12.5), radius: 1));
    p.addOval(Rect.fromCircle(center: const Offset(12, 12.5), radius: 1));
    p.addOval(Rect.fromCircle(center: const Offset(15.5, 12.5), radius: 1));
    p.addOval(Rect.fromCircle(center: const Offset(8.5, 16.5), radius: 1));
    p.addOval(Rect.fromCircle(center: const Offset(12, 16.5), radius: 1));
    p.addOval(Rect.fromCircle(center: const Offset(15.5, 16.5), radius: 1));
  }

  /// 图片损坏：外框 + 断开的山形。
  void _brokenImage(Path p) {
    p.addRRect(const RRect.fromLTRBXY(3, 4.5, 21, 19.5, 2, 2));
    p.moveTo(3.5, 6.5);
    p.lineTo(3.5, 16);
    p.lineTo(8, 11.5);
    p.lineTo(11.5, 14.5);
    p.moveTo(14, 12.5);
    p.lineTo(17, 9.5);
    p.lineTo(20.5, 13);
    p.moveTo(20.5, 16);
    p.lineTo(20.5, 17.5);
  }

  /// 收起键盘：键盘身 + 键点 + 向下箭头。
  void _keyboardHide(Path p) {
    p.addRRect(const RRect.fromLTRBXY(2.5, 4, 21.5, 13.5, 2, 2));
    p.addOval(Rect.fromCircle(center: const Offset(6, 8), radius: 0.85));
    p.addOval(Rect.fromCircle(center: const Offset(9.5, 8), radius: 0.85));
    p.addOval(Rect.fromCircle(center: const Offset(13, 8), radius: 0.85));
    p.addOval(Rect.fromCircle(center: const Offset(16.5, 8), radius: 0.85));
    _line(p, 7.5, 11, 16.5, 11);
    p.moveTo(9.5, 16.5);
    p.lineTo(12, 19.5);
    p.lineTo(14.5, 16.5);
  }

  /// 库存：箱体 + 层板线。
  void _inventory(Path p) {
    p.addRRect(const RRect.fromLTRBXY(3, 4.5, 21, 19.5, 2, 2));
    _line(p, 3, 12, 21, 12);
    _line(p, 9.5, 4.5, 9.5, 12);
    _line(p, 15, 4.5, 15, 12);
  }

  @override
  bool shouldRepaint(covariant _LineIconPainter old) =>
      old.kind != kind || old.color != color || old.strokeWidth != strokeWidth;
}
