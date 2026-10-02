import 'package:flutter/material.dart';

/// 分类图标可选项（用于新增/编辑子分类页选择图标）。
final List<CategoryIconOption> categoryIconOptions = <CategoryIconOption>[
  // 餐饮 / 日常
  const CategoryIconOption(
      key: 'restaurant', icon: Icons.restaurant_outlined, label: '餐饮'),
  const CategoryIconOption(
      key: 'rice', icon: Icons.rice_bowl_outlined, label: '三餐'),
  const CategoryIconOption(
      key: 'coffee', icon: Icons.coffee_outlined, label: '咖啡'),
  const CategoryIconOption(
      key: 'liquor', icon: Icons.liquor_outlined, label: '酒水'),
  const CategoryIconOption(key: 'cake', icon: Icons.cake_outlined, label: '甜点'),
  const CategoryIconOption(
      key: 'local_drink', icon: Icons.local_drink_outlined, label: '饮品'),
  const CategoryIconOption(
      key: 'breakfast', icon: Icons.breakfast_dining_outlined, label: '早餐'),
  const CategoryIconOption(
      key: 'lunch', icon: Icons.lunch_dining_outlined, label: '午餐'),
  const CategoryIconOption(
      key: 'dinner', icon: Icons.dinner_dining_outlined, label: '晚餐'),
  const CategoryIconOption(
      key: 'beverage', icon: Icons.emoji_food_beverage_outlined, label: '饮品'),
  const CategoryIconOption(
      key: 'groupbuy', icon: Icons.confirmation_number_outlined, label: '团购券'),
  const CategoryIconOption(
      key: 'street_food', icon: Icons.tapas_outlined, label: '风味小吃'),
  const CategoryIconOption(
      key: 'daily', icon: Icons.local_convenience_store_outlined, label: '日常'),
  const CategoryIconOption(
      key: 'shopping_cart', icon: Icons.shopping_cart_outlined, label: '超市'),

  // 购物 / 服饰 / 美妆
  const CategoryIconOption(
      key: 'shopping', icon: Icons.shopping_bag_outlined, label: '购物'),
  const CategoryIconOption(
      key: 'cloth', icon: Icons.checkroom_outlined, label: '服饰'),
  const CategoryIconOption(
      key: 'beauty', icon: Icons.brush_outlined, label: '美妆'),
  const CategoryIconOption(key: 'face', icon: Icons.face_outlined, label: '护肤'),
  const CategoryIconOption(
      key: 'content_cut', icon: Icons.content_cut_outlined, label: '理发'),
  const CategoryIconOption(
      key: 'diamond', icon: Icons.diamond_outlined, label: '珠宝'),

  // 出行 / 交通
  const CategoryIconOption(
      key: 'transport', icon: Icons.directions_bus_outlined, label: '交通'),
  const CategoryIconOption(
      key: 'taxi', icon: Icons.local_taxi_outlined, label: '打车'),
  const CategoryIconOption(
      key: 'car', icon: Icons.directions_car_outlined, label: '汽车'),
  const CategoryIconOption(
      key: 'train', icon: Icons.train_outlined, label: '火车'),
  const CategoryIconOption(
      key: 'flight', icon: Icons.flight_outlined, label: '机票'),

  // 生活 / 人情 / 通讯
  const CategoryIconOption(
      key: 'heart', icon: Icons.favorite_outline, label: '人情'),
  const CategoryIconOption(
      key: 'phone', icon: Icons.smartphone_outlined, label: '通讯'),
  const CategoryIconOption(key: 'wifi', icon: Icons.wifi_outlined, label: '宽带'),
  const CategoryIconOption(
      key: 'member', icon: Icons.card_membership_outlined, label: '会员'),
  const CategoryIconOption(
      key: 'gift', icon: Icons.redeem_outlined, label: '礼物'),

  // 娱乐 / 旅游 / 亲子
  const CategoryIconOption(
      key: 'entertainment', icon: Icons.movie_outlined, label: '娱乐'),
  const CategoryIconOption(
      key: 'travel', icon: Icons.flight_takeoff_outlined, label: '旅游'),
  const CategoryIconOption(
      key: 'game', icon: Icons.sports_esports_outlined, label: '游戏'),
  const CategoryIconOption(
      key: 'music', icon: Icons.music_note_outlined, label: '音乐'),
  const CategoryIconOption(
      key: 'camera', icon: Icons.camera_alt_outlined, label: '摄影'),
  const CategoryIconOption(
      key: 'baby', icon: Icons.child_care_outlined, label: '亲子'),
  const CategoryIconOption(key: 'toys', icon: Icons.toys_outlined, label: '玩具'),

  // 医疗 / 健康 / 运动
  const CategoryIconOption(
      key: 'medical', icon: Icons.local_hospital_outlined, label: '医疗'),
  const CategoryIconOption(
      key: 'fitness', icon: Icons.fitness_center_outlined, label: '运动'),
  const CategoryIconOption(
      key: 'sports', icon: Icons.sports_outlined, label: '体育'),
  const CategoryIconOption(key: 'pets', icon: Icons.pets_outlined, label: '宠物'),

  // 学习 / 书籍 / 办公
  const CategoryIconOption(
      key: 'education', icon: Icons.school_outlined, label: '学习'),
  const CategoryIconOption(
      key: 'book', icon: Icons.menu_book_outlined, label: '书籍'),
  const CategoryIconOption(
      key: 'computer', icon: Icons.computer_outlined, label: '办公'),
  const CategoryIconOption(key: 'work', icon: Icons.work_outline, label: '工作'),

  // 收入 / 投资
  const CategoryIconOption(
      key: 'salary', icon: Icons.payments_outlined, label: '基本工资'),
  const CategoryIconOption(
      key: 'bonus', icon: Icons.card_giftcard_outlined, label: '奖金'),
  const CategoryIconOption(
      key: 'red_envelope', icon: Icons.card_giftcard_outlined, label: '红包'),
  const CategoryIconOption(
      key: 'refund', icon: Icons.replay_outlined, label: '退款'),
  const CategoryIconOption(
      key: 'investment', icon: Icons.trending_up_outlined, label: '投资'),
  const CategoryIconOption(
      key: 'savings', icon: Icons.savings_outlined, label: '储蓄'),
  const CategoryIconOption(
      key: 'account_balance',
      icon: Icons.account_balance_outlined,
      label: '理财'),

  // 收入树 Income Tree（记一笔·收入分类）
  const CategoryIconOption(
      key: 'income_job', icon: Icons.badge_outlined, label: '职业收入'),
  const CategoryIconOption(
      key: 'income_business', icon: Icons.storefront_outlined, label: '经营收入'),
  const CategoryIconOption(
      key: 'income_side', icon: Icons.laptop_outlined, label: '副业兼职'),
  const CategoryIconOption(
      key: 'income_invest', icon: Icons.trending_up_outlined, label: '投资收入'),
  const CategoryIconOption(
      key: 'income_funds', icon: Icons.swap_horiz_outlined, label: '资金往来'),
  const CategoryIconOption(
      key: 'performance_bonus',
      icon: Icons.emoji_events_outlined,
      label: '绩效奖金'),
  const CategoryIconOption(
      key: 'allowance', icon: Icons.savings_outlined, label: '津贴补助'),
  const CategoryIconOption(
      key: 'sole_proprietor', icon: Icons.store_outlined, label: '个体经营'),
  const CategoryIconOption(
      key: 'rider', icon: Icons.two_wheeler_outlined, label: '骑手'),
  const CategoryIconOption(
      key: 'video_income', icon: Icons.videocam_outlined, label: '视频收入'),
  const CategoryIconOption(
      key: 'parttime', icon: Icons.work_outline, label: '兼职'),
  const CategoryIconOption(
      key: 'securities', icon: Icons.candlestick_chart_outlined, label: '证券收入'),
  const CategoryIconOption(
      key: 'interest', icon: Icons.percent_outlined, label: '利息收入'),
  const CategoryIconOption(
      key: 'refund_cashback', icon: Icons.replay_outlined, label: '退款返现'),
  const CategoryIconOption(
      key: 'repayment', icon: Icons.payment_outlined, label: '他人还款'),
  const CategoryIconOption(
      key: 'social_income', icon: Icons.favorite_outline, label: '人情往来'),
  const CategoryIconOption(
      key: 'tax_reimburse', icon: Icons.receipt_long_outlined, label: '退税报销'),

  // 果蔬 / 生鲜
  const CategoryIconOption(
      key: 'fruit', icon: Icons.apple_outlined, label: '水果'),
  const CategoryIconOption(
      key: 'vegetable', icon: Icons.eco_outlined, label: '蔬菜'),
  const CategoryIconOption(
      key: 'snack', icon: Icons.cookie_outlined, label: '零食'),
  const CategoryIconOption(
      key: 'icecream', icon: Icons.icecream_outlined, label: '冷饮'),

  // 其他
  const CategoryIconOption(
      key: 'other', icon: Icons.more_horiz_outlined, label: '其他'),
  const CategoryIconOption(
      key: 'repair', icon: Icons.handyman_outlined, label: '维修'),
  const CategoryIconOption(
      key: 'donation', icon: Icons.volunteer_activism_outlined, label: '公益'),
  const CategoryIconOption(
      key: 'settings', icon: Icons.settings_outlined, label: '设置'),

  // ── 全分类图标（A3 线稿设计稿·并入）──

  // 餐饮 Dining
  const CategoryIconOption(
      key: 'milk_tea', icon: Icons.local_cafe_outlined, label: '奶茶'),
  const CategoryIconOption(
      key: 'juice', icon: Icons.local_drink_outlined, label: '果汁'),
  const CategoryIconOption(
      key: 'dim_sum', icon: Icons.cake_outlined, label: '点心'),

  // 购物 Shopping
  const CategoryIconOption(
      key: 'produce', icon: Icons.eco_outlined, label: '果蔬蛋奶'),
  const CategoryIconOption(
      key: 'shipping', icon: Icons.local_shipping_outlined, label: '运费'),
  const CategoryIconOption(
      key: 'apparel', icon: Icons.checkroom_outlined, label: '服饰鞋包'),
  const CategoryIconOption(
      key: 'digital', icon: Icons.devices_outlined, label: '数码电器'),
  const CategoryIconOption(
      key: 'consumable', icon: Icons.cleaning_services_outlined, label: '生活耗材'),
  const CategoryIconOption(
      key: 'tobacco', icon: Icons.sports_bar_outlined, label: '烟酒茶糖'),
  const CategoryIconOption(
      key: 'furniture', icon: Icons.chair_outlined, label: '家居家具'),
  const CategoryIconOption(
      key: 'personal_care', icon: Icons.content_cut_outlined, label: '个护服务'),

  // 出行 Travel
  const CategoryIconOption(
      key: 'car_care', icon: Icons.directions_car_outlined, label: '养车'),
  const CategoryIconOption(
      key: 'transit', icon: Icons.directions_bus_outlined, label: '公共交通'),
  const CategoryIconOption(
      key: 'fuel', icon: Icons.local_gas_station_outlined, label: '加油充电'),
  const CategoryIconOption(
      key: 'taxi_rental', icon: Icons.local_taxi_outlined, label: '打车租车'),
  const CategoryIconOption(
      key: 'intercity', icon: Icons.train_outlined, label: '城际出行'),

  // 居住 Housing
  const CategoryIconOption(key: 'home', icon: Icons.home_outlined, label: '居住'),
  const CategoryIconOption(
      key: 'lodging', icon: Icons.hotel_outlined, label: '住宿'),
  const CategoryIconOption(
      key: 'renovation', icon: Icons.handyman_outlined, label: '装修维护'),
  const CategoryIconOption(
      key: 'rent', icon: Icons.vpn_key_outlined, label: '房租房贷'),
  const CategoryIconOption(
      key: 'utilities', icon: Icons.bolt_outlined, label: '水电燃物'),
  const CategoryIconOption(
      key: 'telecom', icon: Icons.wifi_outlined, label: '话费网费'),

  // 娱乐 Entertainment
  const CategoryIconOption(
      key: 'offline_fun',
      icon: Icons.confirmation_number_outlined,
      label: '线下娱乐'),
  const CategoryIconOption(
      key: 'digital_fun', icon: Icons.smartphone_outlined, label: '数字娱乐'),
  const CategoryIconOption(
      key: 'travel_vacation', icon: Icons.beach_access_outlined, label: '旅游度假'),
  const CategoryIconOption(
      key: 'hobby', icon: Icons.collections_outlined, label: '收藏爱好'),

  // 医疗健康 Medical
  const CategoryIconOption(
      key: 'clinic', icon: Icons.medical_services_outlined, label: '就医购药'),
  const CategoryIconOption(
      key: 'wellness', icon: Icons.spa_outlined, label: '养生保健'),
  const CategoryIconOption(
      key: 'checkup', icon: Icons.vaccines_outlined, label: '体检疫苗'),
  const CategoryIconOption(
      key: 'insurance', icon: Icons.umbrella_outlined, label: '商业保险'),

  // 学习办公 Study
  const CategoryIconOption(
      key: 'knowledge', icon: Icons.menu_book_outlined, label: '知识付费'),
  const CategoryIconOption(
      key: 'stationery', icon: Icons.edit_note_outlined, label: '图文工具'),

  // 人情往来 Social
  const CategoryIconOption(
      key: 'social', icon: Icons.favorite_outline, label: '人情往来'),
  const CategoryIconOption(
      key: 'red_packet', icon: Icons.card_giftcard_outlined, label: '红包'),

  // 宠物 Pet
  const CategoryIconOption(key: 'pet', icon: Icons.pets_outlined, label: '宠物'),
  const CategoryIconOption(
      key: 'pet_food', icon: Icons.pets_outlined, label: '宠物食品'),
  const CategoryIconOption(
      key: 'pet_supply', icon: Icons.toys_outlined, label: '宠物用品'),
  const CategoryIconOption(
      key: 'pet_medical', icon: Icons.vaccines_outlined, label: '宠物医疗'),
  const CategoryIconOption(
      key: 'pet_service', icon: Icons.home_outlined, label: '宠物服务'),

  // 资金往来 Funds
  const CategoryIconOption(
      key: 'funds', icon: Icons.swap_horiz_outlined, label: '资金往来'),
  const CategoryIconOption(
      key: 'repay', icon: Icons.payment_outlined, label: '还款'),
  const CategoryIconOption(
      key: 'lend', icon: Icons.volunteer_activism_outlined, label: '借款'),
  const CategoryIconOption(
      key: 'accrue', icon: Icons.percent_outlined, label: '计提'),
  const CategoryIconOption(
      key: 'withdrawal', icon: Icons.local_atm_outlined, label: '取现'),
  const CategoryIconOption(
      key: 'internal_transfer', icon: Icons.swap_horiz_outlined, label: '内部转账'),

  // 投资支出 Invest
  const CategoryIconOption(
      key: 'tax', icon: Icons.receipt_long_outlined, label: '缴税'),
  const CategoryIconOption(
      key: 'finance',
      icon: Icons.account_balance_wallet_outlined,
      label: '博彩理财'),
  const CategoryIconOption(
      key: 'dividend', icon: Icons.savings_outlined, label: '分红入股'),
  const CategoryIconOption(
      key: 'operations', icon: Icons.store_outlined, label: '日常运营'),
  const CategoryIconOption(
      key: 'capex', icon: Icons.business_center_outlined, label: '大额投入'),
];

/// 把 [iconKey] 解析为 Material 图标。
///
/// 未知 key 兜底返回 [Icons.category_outlined]。
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
class CategoryIconOption {
  const CategoryIconOption({
    required this.key,
    required this.icon,
    required this.label,
  });

  final String key;
  final IconData icon;
  final String label;
}
