import 'package:flutter/material.dart';

/// 分类图标可选项（用于新增/编辑子分类页选择图标）。
///
/// 渲染统一走 [LineIconKind] 线稿（`categoryLineKind(key)`），
/// 不再携带 Material [IconData]；此处 key 必须与
/// `categoryLineKind` / `categoryIconData` 的映射保持同步。
final List<CategoryIconOption> categoryIconOptions = <CategoryIconOption>[
  // 餐饮 / 日常
  const CategoryIconOption(key: 'restaurant', label: '餐饮'),
  const CategoryIconOption(key: 'rice', label: '三餐'),
  const CategoryIconOption(key: 'coffee', label: '咖啡'),
  const CategoryIconOption(key: 'liquor', label: '酒水'),
  const CategoryIconOption(key: 'cake', label: '甜点'),
  const CategoryIconOption(key: 'local_drink', label: '饮品'),
  const CategoryIconOption(key: 'breakfast', label: '早餐'),
  const CategoryIconOption(key: 'lunch', label: '午餐'),
  const CategoryIconOption(key: 'dinner', label: '晚餐'),
  const CategoryIconOption(key: 'beverage', label: '饮品'),
  const CategoryIconOption(key: 'groupbuy', label: '团购券'),
  const CategoryIconOption(key: 'street_food', label: '风味小吃'),
  const CategoryIconOption(key: 'daily', label: '日常'),
  const CategoryIconOption(key: 'shopping_cart', label: '超市'),

  // 购物 / 服饰 / 美妆
  const CategoryIconOption(key: 'shopping', label: '购物'),
  const CategoryIconOption(key: 'cloth', label: '服饰'),
  const CategoryIconOption(key: 'beauty', label: '美妆'),
  const CategoryIconOption(key: 'face', label: '护肤'),
  const CategoryIconOption(key: 'content_cut', label: '理发'),
  const CategoryIconOption(key: 'diamond', label: '珠宝'),

  // 出行 / 交通
  const CategoryIconOption(key: 'transport', label: '交通'),
  const CategoryIconOption(key: 'taxi', label: '打车'),
  const CategoryIconOption(key: 'car', label: '汽车'),
  const CategoryIconOption(key: 'train', label: '火车'),
  const CategoryIconOption(key: 'flight', label: '机票'),

  // 生活 / 人情 / 通讯
  const CategoryIconOption(key: 'heart', label: '人情'),
  const CategoryIconOption(key: 'phone', label: '通讯'),
  const CategoryIconOption(key: 'wifi', label: '宽带'),
  const CategoryIconOption(key: 'member', label: '会员'),
  const CategoryIconOption(key: 'gift', label: '礼物'),

  // 娱乐 / 旅游 / 亲子
  const CategoryIconOption(key: 'entertainment', label: '娱乐'),
  const CategoryIconOption(key: 'travel', label: '旅游'),
  const CategoryIconOption(key: 'game', label: '游戏'),
  const CategoryIconOption(key: 'music', label: '音乐'),
  const CategoryIconOption(key: 'camera', label: '摄影'),
  const CategoryIconOption(key: 'baby', label: '亲子'),
  const CategoryIconOption(key: 'toys', label: '玩具'),

  // 医疗 / 健康 / 运动
  const CategoryIconOption(key: 'medical', label: '医疗'),
  const CategoryIconOption(key: 'fitness', label: '运动'),
  const CategoryIconOption(key: 'sports', label: '体育'),
  const CategoryIconOption(key: 'pets', label: '宠物'),

  // 学习 / 书籍 / 办公
  const CategoryIconOption(key: 'education', label: '学习'),
  const CategoryIconOption(key: 'book', label: '书籍'),
  const CategoryIconOption(key: 'computer', label: '办公'),
  const CategoryIconOption(key: 'work', label: '工作'),

  // 收入 / 投资
  const CategoryIconOption(key: 'salary', label: '基本工资'),
  const CategoryIconOption(key: 'bonus', label: '奖金'),
  const CategoryIconOption(key: 'red_envelope', label: '红包'),
  const CategoryIconOption(key: 'refund', label: '退款'),
  const CategoryIconOption(key: 'investment', label: '投资'),
  const CategoryIconOption(key: 'savings', label: '储蓄'),
  const CategoryIconOption(key: 'account_balance', label: '理财'),

  // 收入树 Income Tree（记一笔·收入分类）
  const CategoryIconOption(key: 'income_job', label: '职业收入'),
  const CategoryIconOption(key: 'income_business', label: '经营收入'),
  const CategoryIconOption(key: 'income_side', label: '副业兼职'),
  const CategoryIconOption(key: 'income_invest', label: '投资收入'),
  const CategoryIconOption(key: 'income_funds', label: '资金往来'),
  const CategoryIconOption(key: 'performance_bonus', label: '绩效奖金'),
  const CategoryIconOption(key: 'allowance', label: '津贴补助'),
  const CategoryIconOption(key: 'sole_proprietor', label: '个体经营'),
  const CategoryIconOption(key: 'rider', label: '骑手'),
  const CategoryIconOption(key: 'video_income', label: '视频收入'),
  const CategoryIconOption(key: 'parttime', label: '兼职'),
  const CategoryIconOption(key: 'securities', label: '证券收入'),
  const CategoryIconOption(key: 'interest', label: '利息收入'),
  const CategoryIconOption(key: 'refund_cashback', label: '退款返现'),
  const CategoryIconOption(key: 'repayment', label: '他人还款'),
  const CategoryIconOption(key: 'social_income', label: '人情往来'),
  const CategoryIconOption(key: 'tax_reimburse', label: '退税报销'),

  // 果蔬 / 生鲜
  const CategoryIconOption(key: 'fruit', label: '水果'),
  const CategoryIconOption(key: 'vegetable', label: '蔬菜'),
  const CategoryIconOption(key: 'snack', label: '零食'),
  const CategoryIconOption(key: 'icecream', label: '冷饮'),

  // 其他
  const CategoryIconOption(key: 'other', label: '其他'),
  const CategoryIconOption(key: 'repair', label: '维修'),
  const CategoryIconOption(key: 'donation', label: '公益'),
  const CategoryIconOption(key: 'settings', label: '设置'),

  // ── 全分类图标（A3 线稿设计稿·并入）──

  // 餐饮 Dining
  const CategoryIconOption(key: 'milk_tea', label: '奶茶'),
  const CategoryIconOption(key: 'juice', label: '果汁'),
  const CategoryIconOption(key: 'dim_sum', label: '点心'),

  // 购物 Shopping
  const CategoryIconOption(key: 'produce', label: '果蔬蛋奶'),
  const CategoryIconOption(key: 'shipping', label: '运费'),
  const CategoryIconOption(key: 'apparel', label: '服饰鞋包'),
  const CategoryIconOption(key: 'digital', label: '数码电器'),
  const CategoryIconOption(key: 'consumable', label: '生活耗材'),
  const CategoryIconOption(key: 'tobacco', label: '烟酒茶糖'),
  const CategoryIconOption(key: 'furniture', label: '家居家具'),
  const CategoryIconOption(key: 'personal_care', label: '个护服务'),

  // 出行 Travel
  const CategoryIconOption(key: 'car_care', label: '养车'),
  const CategoryIconOption(key: 'transit', label: '公共交通'),
  const CategoryIconOption(key: 'fuel', label: '加油充电'),
  const CategoryIconOption(key: 'taxi_rental', label: '打车租车'),
  const CategoryIconOption(key: 'intercity', label: '城际出行'),

  // 居住 Housing
  const CategoryIconOption(key: 'home', label: '居住'),
  const CategoryIconOption(key: 'lodging', label: '住宿'),
  const CategoryIconOption(key: 'renovation', label: '装修维护'),
  const CategoryIconOption(key: 'rent', label: '房租房贷'),
  const CategoryIconOption(key: 'utilities', label: '水电燃物'),
  const CategoryIconOption(key: 'telecom', label: '话费网费'),

  // 娱乐 Entertainment
  const CategoryIconOption(key: 'offline_fun', label: '线下娱乐'),
  const CategoryIconOption(key: 'digital_fun', label: '数字娱乐'),
  const CategoryIconOption(key: 'travel_vacation', label: '旅游度假'),
  const CategoryIconOption(key: 'hobby', label: '收藏爱好'),

  // 医疗健康 Medical
  const CategoryIconOption(key: 'clinic', label: '就医购药'),
  const CategoryIconOption(key: 'wellness', label: '养生保健'),
  const CategoryIconOption(key: 'checkup', label: '体检疫苗'),
  const CategoryIconOption(key: 'insurance', label: '商业保险'),

  // 学习办公 Study
  const CategoryIconOption(key: 'knowledge', label: '知识付费'),
  const CategoryIconOption(key: 'stationery', label: '图文工具'),

  // 人情往来 Social
  const CategoryIconOption(key: 'social', label: '人情往来'),
  const CategoryIconOption(key: 'red_packet', label: '红包'),

  // 宠物 Pet
  const CategoryIconOption(key: 'pet', label: '宠物'),
  const CategoryIconOption(key: 'pet_food', label: '宠物食品'),
  const CategoryIconOption(key: 'pet_supply', label: '宠物用品'),
  const CategoryIconOption(key: 'pet_medical', label: '宠物医疗'),
  const CategoryIconOption(key: 'pet_service', label: '宠物服务'),

  // 资金往来 Funds
  const CategoryIconOption(key: 'funds', label: '资金往来'),
  const CategoryIconOption(key: 'repay', label: '还款'),
  const CategoryIconOption(key: 'lend', label: '借款'),
  const CategoryIconOption(key: 'accrue', label: '计提'),
  const CategoryIconOption(key: 'withdrawal', label: '取现'),
  const CategoryIconOption(key: 'internal_transfer', label: '内部转账'),

  // 投资支出 Invest
  const CategoryIconOption(key: 'tax', label: '缴税'),
  const CategoryIconOption(key: 'finance', label: '博彩理财'),
  const CategoryIconOption(key: 'dividend', label: '分红入股'),
  const CategoryIconOption(key: 'operations', label: '日常运营'),
  const CategoryIconOption(key: 'capex', label: '大额投入'),
];

/// 把 [iconKey] 解析为 Material 图标（兜底用）。
///
/// 选择网格等主渲染路径已统一走线稿（`categoryLineKind`）；
/// 本函数仅作为未迁移页面的 Material outlined 兜底，未知 key
/// 兜底返回 [Icons.category_outlined]。
IconData categoryIconData(String? iconKey) {
  if (iconKey == null || iconKey.isEmpty) {
    return Icons.category_outlined;
  }
  return switch (iconKey) {
    'restaurant' => Icons.restaurant_outlined,
    'rice' => Icons.rice_bowl_outlined,
    'coffee' => Icons.coffee_outlined,
    'liquor' => Icons.liquor_outlined,
    'cake' => Icons.cake_outlined,
    'local_drink' => Icons.local_drink_outlined,
    'breakfast' => Icons.breakfast_dining_outlined,
    'lunch' => Icons.lunch_dining_outlined,
    'dinner' => Icons.dinner_dining_outlined,
    'beverage' => Icons.emoji_food_beverage_outlined,
    'groupbuy' => Icons.confirmation_number_outlined,
    'street_food' => Icons.tapas_outlined,
    'daily' => Icons.local_convenience_store_outlined,
    'shopping_cart' => Icons.shopping_cart_outlined,
    'shopping' => Icons.shopping_bag_outlined,
    'cloth' => Icons.checkroom_outlined,
    'beauty' => Icons.brush_outlined,
    'face' => Icons.face_outlined,
    'content_cut' => Icons.content_cut_outlined,
    'diamond' => Icons.diamond_outlined,
    'transport' => Icons.directions_bus_outlined,
    'taxi' => Icons.local_taxi_outlined,
    'car' => Icons.directions_car_outlined,
    'train' => Icons.train_outlined,
    'flight' => Icons.flight_outlined,
    'home' => Icons.home_outlined,
    'heart' => Icons.favorite_outline,
    'phone' => Icons.smartphone_outlined,
    'wifi' => Icons.wifi_outlined,
    'member' => Icons.card_membership_outlined,
    'gift' => Icons.redeem_outlined,
    'entertainment' => Icons.movie_outlined,
    'travel' => Icons.flight_takeoff_outlined,
    'game' => Icons.sports_esports_outlined,
    'music' => Icons.music_note_outlined,
    'camera' => Icons.camera_alt_outlined,
    'baby' => Icons.child_care_outlined,
    'toys' => Icons.toys_outlined,
    'medical' => Icons.local_hospital_outlined,
    'fitness' => Icons.fitness_center_outlined,
    'sports' => Icons.sports_outlined,
    'pets' => Icons.pets_outlined,
    'education' => Icons.school_outlined,
    'book' => Icons.menu_book_outlined,
    'computer' => Icons.computer_outlined,
    'work' => Icons.work_outline,
    'salary' => Icons.payments_outlined,
    'bonus' => Icons.card_giftcard_outlined,
    'red_envelope' => Icons.card_giftcard_outlined,
    'refund' => Icons.replay_outlined,
    'investment' => Icons.trending_up_outlined,
    'savings' => Icons.savings_outlined,
    'account_balance' => Icons.account_balance_outlined,
    'income_job' => Icons.badge_outlined,
    'income_business' => Icons.storefront_outlined,
    'income_side' => Icons.laptop_outlined,
    'income_invest' => Icons.trending_up_outlined,
    'income_funds' => Icons.swap_horiz_outlined,
    'performance_bonus' => Icons.emoji_events_outlined,
    'allowance' => Icons.savings_outlined,
    'sole_proprietor' => Icons.store_outlined,
    'rider' => Icons.two_wheeler_outlined,
    'video_income' => Icons.videocam_outlined,
    'securities' => Icons.candlestick_chart_outlined,
    'interest' => Icons.percent_outlined,
    'refund_cashback' => Icons.replay_outlined,
    'repayment' => Icons.payment_outlined,
    'social_income' => Icons.favorite_outline,
    'tax_reimburse' => Icons.receipt_long_outlined,
    'parttime' => Icons.work_outline,
    'fruit' => Icons.apple_outlined,
    'vegetable' => Icons.eco_outlined,
    'snack' => Icons.cookie_outlined,
    'icecream' => Icons.icecream_outlined,
    'other' => Icons.more_horiz_outlined,
    'repair' => Icons.handyman_outlined,
    'donation' => Icons.volunteer_activism_outlined,
    'settings' => Icons.settings_outlined,
    'milk_tea' => Icons.local_cafe_outlined,
    'juice' => Icons.local_drink_outlined,
    'dim_sum' => Icons.cake_outlined,
    'produce' => Icons.eco_outlined,
    'shipping' => Icons.local_shipping_outlined,
    'apparel' => Icons.checkroom_outlined,
    'digital' => Icons.devices_outlined,
    'consumable' => Icons.cleaning_services_outlined,
    'tobacco' => Icons.sports_bar_outlined,
    'furniture' => Icons.chair_outlined,
    'personal_care' => Icons.content_cut_outlined,
    'car_care' => Icons.directions_car_outlined,
    'transit' => Icons.directions_bus_outlined,
    'fuel' => Icons.local_gas_station_outlined,
    'taxi_rental' => Icons.local_taxi_outlined,
    'intercity' => Icons.train_outlined,
    'renovation' => Icons.handyman_outlined,
    'rent' => Icons.vpn_key_outlined,
    'utilities' => Icons.bolt_outlined,
    'telecom' => Icons.wifi_outlined,
    'lodging' => Icons.hotel_outlined,
    'offline_fun' => Icons.confirmation_number_outlined,
    'digital_fun' => Icons.smartphone_outlined,
    'travel_vacation' => Icons.beach_access_outlined,
    'hobby' => Icons.collections_outlined,
    'clinic' => Icons.medical_services_outlined,
    'wellness' => Icons.spa_outlined,
    'checkup' => Icons.vaccines_outlined,
    'insurance' => Icons.umbrella_outlined,
    'knowledge' => Icons.menu_book_outlined,
    'stationery' => Icons.edit_note_outlined,
    'social' => Icons.favorite_outline,
    'red_packet' => Icons.card_giftcard_outlined,
    'pet' => Icons.pets_outlined,
    'pet_food' => Icons.pets_outlined,
    'pet_supply' => Icons.toys_outlined,
    'pet_medical' => Icons.vaccines_outlined,
    'pet_service' => Icons.home_outlined,
    'funds' => Icons.swap_horiz_outlined,
    'repay' => Icons.payment_outlined,
    'lend' => Icons.volunteer_activism_outlined,
    'accrue' => Icons.percent_outlined,
    'withdrawal' => Icons.local_atm_outlined,
    'internal_transfer' => Icons.swap_horiz_outlined,
    // 存款 Deposit：故意不在 categoryIconOptions（分类选择器隐藏），
    // 仅在存钱流程中按需引用；保留解析以便 categoryIconData('deposit_in') 仍可用。
    'deposit_in' => Icons.savings_outlined,
    'deposit_out' => Icons.local_atm_outlined,
    // 借还系统分类 Lend（落账自动挂分类，用户分类选择器隐藏）
    'borrow_in' => Icons.handshake_outlined,
    'lend_out' => Icons.send_outlined,
    'repay_debt' => Icons.paid_outlined,
    'collect_debt' => Icons.account_balance_wallet_outlined,
    'debt_reduce' => Icons.trending_down_outlined,
    'bad_debt' => Icons.dangerous_outlined,
    'reimburse_income' => Icons.receipt_long_outlined,
    'tax' => Icons.receipt_long_outlined,
    'finance' => Icons.account_balance_wallet_outlined,
    'dividend' => Icons.savings_outlined,
    'operations' => Icons.store_outlined,
    'capex' => Icons.business_center_outlined,
    _ => Icons.category_outlined,
  };
}

/// 分类图标可选项数据对象。
///
/// 图标渲染统一由 key 经 `categoryLineKind` 解析为线稿。
class CategoryIconOption {
  const CategoryIconOption({required this.key, required this.label});

  final String key;
  final String label;
}
