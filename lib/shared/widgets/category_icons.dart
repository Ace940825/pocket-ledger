import 'package:flutter/material.dart';

/// 分类图标可选项（用于新增/编辑子分类页选择图标）。
final List<CategoryIconOption> categoryIconOptions = <CategoryIconOption>[
  // 餐饮 / 日常
  const CategoryIconOption(key: 'restaurant', icon: Icons.restaurant_outlined, label: '餐饮'),
  const CategoryIconOption(key: 'rice', icon: Icons.rice_bowl_outlined, label: '三餐'),
  const CategoryIconOption(key: 'coffee', icon: Icons.coffee_outlined, label: '咖啡'),
  const CategoryIconOption(key: 'liquor', icon: Icons.liquor_outlined, label: '酒水'),
  const CategoryIconOption(key: 'cake', icon: Icons.cake_outlined, label: '甜点'),
  const CategoryIconOption(key: 'local_drink', icon: Icons.local_drink_outlined, label: '饮品'),
  const CategoryIconOption(key: 'daily', icon: Icons.local_convenience_store_outlined, label: '日常'),
  const CategoryIconOption(key: 'shopping_cart', icon: Icons.shopping_cart_outlined, label: '超市'),

  // 购物 / 服饰 / 美妆
  const CategoryIconOption(key: 'shopping', icon: Icons.shopping_bag_outlined, label: '购物'),
  const CategoryIconOption(key: 'cloth', icon: Icons.checkroom_outlined, label: '服饰'),
  const CategoryIconOption(key: 'beauty', icon: Icons.brush_outlined, label: '美妆'),
  const CategoryIconOption(key: 'face', icon: Icons.face_outlined, label: '护肤'),
  const CategoryIconOption(key: 'content_cut', icon: Icons.content_cut_outlined, label: '理发'),
  const CategoryIconOption(key: 'diamond', icon: Icons.diamond_outlined, label: '珠宝'),

  // 出行 / 交通
  const CategoryIconOption(key: 'transport', icon: Icons.directions_bus_outlined, label: '交通'),
  const CategoryIconOption(key: 'taxi', icon: Icons.local_taxi_outlined, label: '打车'),
  const CategoryIconOption(key: 'car', icon: Icons.directions_car_outlined, label: '汽车'),
  const CategoryIconOption(key: 'train', icon: Icons.train_outlined, label: '火车'),
  const CategoryIconOption(key: 'flight', icon: Icons.flight_outlined, label: '机票'),
  const CategoryIconOption(key: 'home', icon: Icons.home_outlined, label: '住宿'),

  // 生活 / 人情 / 通讯
  const CategoryIconOption(key: 'heart', icon: Icons.favorite_outline, label: '人情'),
  const CategoryIconOption(key: 'phone', icon: Icons.smartphone_outlined, label: '通讯'),
  const CategoryIconOption(key: 'wifi', icon: Icons.wifi_outlined, label: '宽带'),
  const CategoryIconOption(key: 'member', icon: Icons.card_membership_outlined, label: '会员'),
  const CategoryIconOption(key: 'gift', icon: Icons.redeem_outlined, label: '礼物'),

  // 娱乐 / 旅游 / 亲子
  const CategoryIconOption(key: 'entertainment', icon: Icons.movie_outlined, label: '娱乐'),
  const CategoryIconOption(key: 'travel', icon: Icons.flight_takeoff_outlined, label: '旅游'),
  const CategoryIconOption(key: 'game', icon: Icons.sports_esports_outlined, label: '游戏'),
  const CategoryIconOption(key: 'music', icon: Icons.music_note_outlined, label: '音乐'),
  const CategoryIconOption(key: 'camera', icon: Icons.camera_alt_outlined, label: '摄影'),
  const CategoryIconOption(key: 'baby', icon: Icons.child_care_outlined, label: '亲子'),
  const CategoryIconOption(key: 'toys', icon: Icons.toys_outlined, label: '玩具'),

  // 医疗 / 健康 / 运动
  const CategoryIconOption(key: 'medical', icon: Icons.local_hospital_outlined, label: '医疗'),
  const CategoryIconOption(key: 'fitness', icon: Icons.fitness_center_outlined, label: '运动'),
  const CategoryIconOption(key: 'sports', icon: Icons.sports_outlined, label: '体育'),
  const CategoryIconOption(key: 'pets', icon: Icons.pets_outlined, label: '宠物'),

  // 学习 / 书籍 / 办公
  const CategoryIconOption(key: 'education', icon: Icons.school_outlined, label: '学习'),
  const CategoryIconOption(key: 'book', icon: Icons.menu_book_outlined, label: '书籍'),
  const CategoryIconOption(key: 'computer', icon: Icons.computer_outlined, label: '办公'),
  const CategoryIconOption(key: 'work', icon: Icons.work_outline, label: '工作'),

  // 收入 / 投资
  const CategoryIconOption(key: 'salary', icon: Icons.payments_outlined, label: '工资'),
  const CategoryIconOption(key: 'bonus', icon: Icons.card_giftcard_outlined, label: '奖金'),
  const CategoryIconOption(key: 'investment', icon: Icons.trending_up_outlined, label: '投资'),
  const CategoryIconOption(key: 'savings', icon: Icons.savings_outlined, label: '储蓄'),
  const CategoryIconOption(key: 'account_balance', icon: Icons.account_balance_outlined, label: '理财'),

  // 果蔬 / 生鲜
  const CategoryIconOption(key: 'fruit', icon: Icons.apple_outlined, label: '水果'),
  const CategoryIconOption(key: 'vegetable', icon: Icons.eco_outlined, label: '蔬菜'),
  const CategoryIconOption(key: 'snack', icon: Icons.cookie_outlined, label: '零食'),
  const CategoryIconOption(key: 'icecream', icon: Icons.icecream_outlined, label: '冷饮'),

  // 其他
  const CategoryIconOption(key: 'repair', icon: Icons.handyman_outlined, label: '维修'),
  const CategoryIconOption(key: 'donation', icon: Icons.volunteer_activism_outlined, label: '公益'),
  const CategoryIconOption(key: 'settings', icon: Icons.settings_outlined, label: '设置'),
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
    'investment' => Icons.trending_up_outlined,
    'savings' => Icons.savings_outlined,
    'account_balance' => Icons.account_balance_outlined,
    'fruit' => Icons.apple_outlined,
    'vegetable' => Icons.eco_outlined,
    'snack' => Icons.cookie_outlined,
    'icecream' => Icons.icecream_outlined,
    'repair' => Icons.handyman_outlined,
    'donation' => Icons.volunteer_activism_outlined,
    'settings' => Icons.settings_outlined,
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
