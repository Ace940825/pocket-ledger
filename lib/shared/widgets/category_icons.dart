import 'package:flutter/material.dart';

/// 分类图标可选项（用于新增/编辑子分类页选择图标）。
///
/// 渲染统一走 [LineIconKind] 线稿（`categoryLineKind(key)`），
/// 不再携带 Material [IconData]；此处 key 必须与
/// `categoryLineKind` / `categoryIconData` 的映射保持同步。
///
/// **去重原则（2026-10-13）**：多个 key 若经 `categoryLineKind`
/// 映射到同一线稿，选择网格里只保留一个代表项（语义最贴切的 key）。
/// 被移除的 key（如 `rice`/`heart`/`wifi` 等）在 `categoryLineKind`
/// 与 `categoryIconData` 中的映射**全部保留**——存量分类数据仍能正常
/// 渲染，仅不再出现在选择网格中。
final List<CategoryIconOption> categoryIconOptions = <CategoryIconOption>[
  // 餐饮 / 日常（每线稿一项：rice→restaurant、local_drink→beverage 已去重）
  const CategoryIconOption(key: 'restaurant', label: '餐饮'),
  const CategoryIconOption(key: 'coffee', label: '咖啡'),
  const CategoryIconOption(key: 'cake', label: '甜点'),
  const CategoryIconOption(key: 'breakfast', label: '早餐'),
  const CategoryIconOption(key: 'lunch', label: '午餐'),
  const CategoryIconOption(key: 'dinner', label: '晚餐'),
  const CategoryIconOption(key: 'beverage', label: '饮品'),
  const CategoryIconOption(key: 'groupbuy', label: '团购券'),
  const CategoryIconOption(key: 'street_food', label: '风味小吃'),
  const CategoryIconOption(key: 'daily', label: '日常'),
  const CategoryIconOption(key: 'shopping', label: '购物'),

  // 购物 / 服饰 / 美妆（face→beauty、cloth→apparel、content_cut→personal_care、
  // diamond→daily 已去重）
  const CategoryIconOption(key: 'beauty', label: '美妆'),

  // 出行 / 交通（train→transport、car_care→car、taxi_rental→taxi 已去重）
  const CategoryIconOption(key: 'transport', label: '交通'),
  const CategoryIconOption(key: 'taxi', label: '打车'),
  const CategoryIconOption(key: 'car', label: '汽车'),
  const CategoryIconOption(key: 'flight', label: '机票'),

  // 生活 / 人情 / 通讯（heart/member/social→gift、wifi/computer→phone 已去重）
  const CategoryIconOption(key: 'phone', label: '通讯'),
  const CategoryIconOption(key: 'gift', label: '礼物'),

  // 娱乐 / 旅游 / 亲子（game→music、baby/toys→daily 已去重）
  const CategoryIconOption(key: 'entertainment', label: '娱乐'),
  const CategoryIconOption(key: 'travel', label: '旅游'),
  const CategoryIconOption(key: 'music', label: '音乐'),
  const CategoryIconOption(key: 'camera', label: '摄影'),

  // 医疗 / 健康 / 运动（sports→medical、pets→pet 已去重）
  const CategoryIconOption(key: 'medical', label: '医疗'),
  const CategoryIconOption(key: 'fitness', label: '运动'),

  // 学习 / 书籍 / 办公（book→education、computer→phone 已去重）
  const CategoryIconOption(key: 'education', label: '学习'),
  const CategoryIconOption(key: 'work', label: '工作'),

  // 收入 / 投资（bonus/red_packet→red_envelope、savings/account_balance/
  // income_invest→investment 已去重）
  const CategoryIconOption(key: 'salary', label: '基本工资'),
  const CategoryIconOption(key: 'red_envelope', label: '红包'),
  const CategoryIconOption(key: 'refund', label: '退款'),
  const CategoryIconOption(key: 'investment', label: '投资'),

  // 收入树 Income Tree（记一笔·收入分类）
  // （income_invest→investment、income_funds→funds、refund_cashback→refund、
  // parttime→work、social_income→gift 已去重）
  const CategoryIconOption(key: 'income_job', label: '职业收入'),
  const CategoryIconOption(key: 'income_business', label: '经营收入'),
  const CategoryIconOption(key: 'income_side', label: '副业兼职'),
  const CategoryIconOption(key: 'performance_bonus', label: '绩效奖金'),
  const CategoryIconOption(key: 'allowance', label: '津贴补助'),
  const CategoryIconOption(key: 'sole_proprietor', label: '个体经营'),
  const CategoryIconOption(key: 'rider', label: '骑手'),
  const CategoryIconOption(key: 'video_income', label: '视频收入'),
  const CategoryIconOption(key: 'securities', label: '证券收入'),
  const CategoryIconOption(key: 'interest', label: '利息收入'),
  const CategoryIconOption(key: 'tax_reimburse', label: '退税报销'),

  // 果蔬 / 生鲜（fruit/vegetable→produce、icecream→daily 已去重）
  const CategoryIconOption(key: 'snack', label: '零食'),

  // 其他（repair→renovation 已去重）
  const CategoryIconOption(key: 'other', label: '其他'),
  const CategoryIconOption(key: 'donation', label: '公益'),
  const CategoryIconOption(key: 'settings', label: '设置'),

  // ── 全分类图标（A3 线稿设计稿·并入）──

  // 餐饮 Dining
  const CategoryIconOption(key: 'milk_tea', label: '奶茶'),
  const CategoryIconOption(key: 'juice', label: '果汁'),
  const CategoryIconOption(key: 'dim_sum', label: '点心'),

  // 购物 Shopping（apparel 吸收旧 cloth；personal_care 吸收旧 content_cut）
  const CategoryIconOption(key: 'produce', label: '果蔬蛋奶'),
  const CategoryIconOption(key: 'shipping', label: '运费'),
  const CategoryIconOption(key: 'apparel', label: '服饰鞋包'),
  const CategoryIconOption(key: 'digital', label: '数码电器'),
  const CategoryIconOption(key: 'consumable', label: '生活耗材'),
  const CategoryIconOption(key: 'tobacco', label: '烟酒茶糖'),
  const CategoryIconOption(key: 'furniture', label: '家居家具'),
  const CategoryIconOption(key: 'personal_care', label: '个护服务'),

  // 出行 Travel
  const CategoryIconOption(key: 'transit', label: '公共交通'),
  const CategoryIconOption(key: 'fuel', label: '加油充电'),
  const CategoryIconOption(key: 'intercity', label: '城际出行'),

  // 居住 Housing（renovation 吸收旧 repair）
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

  // 宠物 Pet（pets/pet_food→pet 已去重）
  const CategoryIconOption(key: 'pet', label: '宠物'),
  const CategoryIconOption(key: 'pet_supply', label: '宠物用品'),
  const CategoryIconOption(key: 'pet_medical', label: '宠物医疗'),
  const CategoryIconOption(key: 'pet_service', label: '宠物服务'),

  // 资金往来 Funds（income_funds→funds 已去重）
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

/// 分类图标可选项数据对象。
///
/// 图标渲染统一由 key 经 `categoryLineKind` 解析为线稿。
class CategoryIconOption {
  const CategoryIconOption({required this.key, required this.label});

  final String key;
  final String label;
}
