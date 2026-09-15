import 'package:flutter/material.dart';

/// 「文字作为图标」的约定 key。
///
/// 当分类的 [iconKey] 为此时，网格/列表中显示分类名称首字，而非 Material 图标。
const String kCategoryIconText = 'text';

/// 分类图标可选项（用于新增/编辑子分类页选择图标）。
final List<CategoryIconOption> categoryIconOptions = <CategoryIconOption>[
  const CategoryIconOption(key: 'restaurant', icon: Icons.restaurant_outlined, label: '餐饮'),
  const CategoryIconOption(key: 'rice', icon: Icons.rice_bowl_outlined, label: '三餐'),
  const CategoryIconOption(key: 'shopping', icon: Icons.shopping_bag_outlined, label: '购物'),
  const CategoryIconOption(key: 'transport', icon: Icons.directions_bus_outlined, label: '交通'),
  const CategoryIconOption(key: 'taxi', icon: Icons.local_taxi_outlined, label: '打车'),
  const CategoryIconOption(key: 'home', icon: Icons.home_outlined, label: '住宿'),
  const CategoryIconOption(key: 'daily', icon: Icons.local_convenience_store_outlined, label: '日常'),
  const CategoryIconOption(key: 'heart', icon: Icons.favorite_outline, label: '人情'),
  const CategoryIconOption(key: 'entertainment', icon: Icons.movie_outlined, label: '娱乐'),
  const CategoryIconOption(key: 'travel', icon: Icons.flight_outlined, label: '旅游'),
  const CategoryIconOption(key: 'medical', icon: Icons.local_hospital_outlined, label: '医疗'),
  const CategoryIconOption(key: 'member', icon: Icons.card_membership_outlined, label: '会员'),
  const CategoryIconOption(key: 'salary', icon: Icons.payments_outlined, label: '工资'),
  const CategoryIconOption(key: 'bonus', icon: Icons.card_giftcard_outlined, label: '奖金'),
  const CategoryIconOption(key: 'investment', icon: Icons.trending_up_outlined, label: '投资'),
  const CategoryIconOption(key: 'education', icon: Icons.school_outlined, label: '学习'),
  const CategoryIconOption(key: 'fitness', icon: Icons.fitness_center_outlined, label: '运动'),
  const CategoryIconOption(key: 'pets', icon: Icons.pets_outlined, label: '宠物'),
  const CategoryIconOption(key: 'phone', icon: Icons.smartphone_outlined, label: '通讯'),
  const CategoryIconOption(key: 'car', icon: Icons.directions_car_outlined, label: '汽车'),
  const CategoryIconOption(key: 'coffee', icon: Icons.coffee_outlined, label: '咖啡'),
  const CategoryIconOption(key: 'gift', icon: Icons.redeem_outlined, label: '礼物'),
  const CategoryIconOption(key: 'book', icon: Icons.menu_book_outlined, label: '书籍'),
  const CategoryIconOption(key: 'cloth', icon: Icons.checkroom_outlined, label: '服饰'),
  const CategoryIconOption(key: 'beauty', icon: Icons.brush_outlined, label: '美妆'),
  const CategoryIconOption(key: 'baby', icon: Icons.child_care_outlined, label: '亲子'),
  const CategoryIconOption(key: 'fruit', icon: Icons.apple_outlined, label: '水果'),
  const CategoryIconOption(key: 'snack', icon: Icons.cookie_outlined, label: '零食'),
];

/// 把 [iconKey] 解析为 Material 图标。
///
/// - 返回 [kCategoryIconText] 时调用方应自行渲染文字首字。
/// - 未知 key 兜底返回 [Icons.category_outlined]。
IconData categoryIconData(String? iconKey) {
  if (iconKey == null || iconKey.isEmpty || iconKey == kCategoryIconText) {
    return Icons.category_outlined;
  }
  return switch (iconKey) {
    'restaurant' => Icons.restaurant_outlined,
    'rice' => Icons.rice_bowl_outlined,
    'shopping' => Icons.shopping_bag_outlined,
    'transport' => Icons.directions_bus_outlined,
    'taxi' => Icons.local_taxi_outlined,
    'home' => Icons.home_outlined,
    'daily' => Icons.local_convenience_store_outlined,
    'heart' => Icons.favorite_outline,
    'entertainment' => Icons.movie_outlined,
    'travel' => Icons.flight_outlined,
    'medical' => Icons.local_hospital_outlined,
    'member' => Icons.card_membership_outlined,
    'salary' => Icons.payments_outlined,
    'bonus' => Icons.card_giftcard_outlined,
    'investment' => Icons.trending_up_outlined,
    'education' => Icons.school_outlined,
    'fitness' => Icons.fitness_center_outlined,
    'pets' => Icons.pets_outlined,
    'phone' => Icons.smartphone_outlined,
    'car' => Icons.directions_car_outlined,
    'coffee' => Icons.coffee_outlined,
    'gift' => Icons.redeem_outlined,
    'book' => Icons.menu_book_outlined,
    'cloth' => Icons.checkroom_outlined,
    'beauty' => Icons.brush_outlined,
    'baby' => Icons.child_care_outlined,
    'fruit' => Icons.apple_outlined,
    'snack' => Icons.cookie_outlined,
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
