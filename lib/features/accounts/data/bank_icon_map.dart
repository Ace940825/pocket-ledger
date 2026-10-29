/// 银行名称到图标路径的映射表。
///
/// 用于根据账户名称自动匹配银行 logo，导入账户时如果没有指定图标，
/// 就根据账户名称自动匹配对应的银行图标。
const Map<String, String> kBankIconMap = <String, String>{
  // 国有六大行
  '工商银行': 'assets/bank_icons/icbc.png',
  '中国工商银行': 'assets/bank_icons/icbc.png',
  '建设银行': 'assets/bank_icons/ccb.png',
  '中国建设银行': 'assets/bank_icons/ccb.png',
  '农业银行': 'assets/bank_icons/abc.png',
  '中国农业银行': 'assets/bank_icons/abc.png',
  '中国银行': 'assets/bank_icons/boc.png',
  '交通银行': 'assets/bank_icons/bocom.png',
  '邮政储蓄银行': 'assets/bank_icons/psbc.png',
  '中国邮政储蓄银行': 'assets/bank_icons/psbc.png',

  // 股份制商业银行
  '招商银行': 'assets/bank_icons/cmb.png',
  '招行': 'assets/bank_icons/cmb.png',
  '浦发银行': 'assets/bank_icons/spdb.png',
  '浦发': 'assets/bank_icons/spdb.png',
  '中信银行': 'assets/bank_icons/citic.png',
  '中信': 'assets/bank_icons/citic.png',
  '民生银行': 'assets/bank_icons/cmbc.png',
  '民生': 'assets/bank_icons/cmbc.png',
  '兴业银行': 'assets/bank_icons/cib.png',
  '兴业': 'assets/bank_icons/cib.png',
  '光大银行': 'assets/bank_icons/ceb.png',
  '光大': 'assets/bank_icons/ceb.png',
  '华夏银行': 'assets/bank_icons/hxb.png',
  '华夏': 'assets/bank_icons/hxb.png',
  '平安银行': 'assets/bank_icons/pab.png',
  '平安': 'assets/bank_icons/pab.png',
  '广发银行': 'assets/bank_icons/cgb.png',
  '广发': 'assets/bank_icons/cgb.png',
  '渤海银行': 'assets/bank_icons/cbhb.png',
  '渤海': 'assets/bank_icons/cbhb.png',
  '浙商银行': 'assets/bank_icons/hfbank.png',
  '浙商': 'assets/bank_icons/hfbank.png',
  '恒丰银行': 'assets/bank_icons/czb.png',
  '恒丰': 'assets/bank_icons/czb.png',

  // 城市商业银行
  '北京银行': 'assets/bank_icons/beijing.png',
  '上海银行': 'assets/bank_icons/shanghai.png',
  '江苏银行': 'assets/bank_icons/jiangsu.png',
  '南京银行': 'assets/bank_icons/nanjing.png',
  '宁波银行': 'assets/bank_icons/ningbo.png',
  '杭州银行': 'assets/bank_icons/hangzhou.png',
  '苏州银行': 'assets/bank_icons/suzhou.png',
  '长沙银行': 'assets/bank_icons/changsha.png',
  '成都银行': 'assets/bank_icons/chengdu.png',
  '重庆银行': 'assets/bank_icons/chongqing.png',
  '青岛银行': 'assets/bank_icons/qingdao.png',
  '郑州银行': 'assets/bank_icons/zhengzhou.png',
  '天津银行': 'assets/bank_icons/tianjin.png',
  '大连银行': 'assets/bank_icons/dalian.png',
  '东莞银行': 'assets/bank_icons/dongguan.png',
  '哈尔滨银行': 'assets/bank_icons/harbin.png',
  '盛京银行': 'assets/bank_icons/shengjing.png',
  '贵阳银行': 'assets/bank_icons/guiyang.png',
  '兰州银行': 'assets/bank_icons/lanzhou.png',
  '西安银行': 'assets/bank_icons/xian.png',
  '厦门银行': 'assets/bank_icons/xiamen.png',
  '福州银行': 'assets/bank_icons/fudian.png',
  '济南银行': 'assets/bank_icons/jinshang.png',
  '齐鲁银行': 'assets/bank_icons/qilu.png',
  '威海银行': 'assets/bank_icons/weihai.png',
  '烟台银行': 'assets/bank_icons/yantai.png',
  '温州银行': 'assets/bank_icons/wenzhou.png',
  '南昌银行': 'assets/bank_icons/jiangxi.png',
  '赣州银行': 'assets/bank_icons/ganzhou.png',
  '上饶银行': 'assets/bank_icons/shangrao.png',
  '泉州银行': 'assets/bank_icons/quanzhou.png',
  '洛阳银行': 'assets/bank_icons/luoyang.png',
  '焦作银行': 'assets/bank_icons/jiaozuo.png',
  '珠海华润银行': 'assets/bank_icons/zhhuarun.png',
  '中原银行': 'assets/bank_icons/zhongyuan.png',
  '汉口银行': 'assets/bank_icons/hubei.png',
  '武昌银行': 'assets/bank_icons/hubei.png',
  '广州银行': 'assets/bank_icons/guangzhou.png',
  '深圳银行': 'assets/bank_icons/shenzhen_rcb.png',
  '顺德银行': 'assets/bank_icons/shunde_rcb.png',
  '常熟银行': 'assets/bank_icons/changshu_rcb.png',
  '昆山银行': 'assets/bank_icons/kunshan_rcb.png',
  '无锡银行': 'assets/bank_icons/wuxi_rcb.png',
  '江阴银行': 'assets/bank_icons/jiangyin_rcb.png',
  '张家港银行': 'assets/bank_icons/zhangjiagang_rcb.png',
  '上海农商银行': 'assets/bank_icons/shanghai_rcb.png',
  '北京农商银行': 'assets/bank_icons/beijing_rcb.png',
  '广州农商银行': 'assets/bank_icons/guangzhou_rcb.png',
  '深圳农商银行': 'assets/bank_icons/shenzhen_rcb.png',
  '成都农商银行': 'assets/bank_icons/chengdu_rcb.png',
  '武汉农商银行': 'assets/bank_icons/wuhan_rcb.png',
  '天津农商银行': 'assets/bank_icons/tianjin_rcb.png',
  '重庆农商银行': 'assets/bank_icons/chongqing_rcb.png',
  '苏州农商银行': 'assets/bank_icons/suzhou_rcb.png',

  // 外资银行
  '汇丰银行': 'assets/bank_icons/hsbc.png',
  '渣打银行': 'assets/bank_icons/standard_chartered.png',
  '花旗银行': 'assets/bank_icons/citibank.png',
  '花旗': 'assets/bank_icons/citibank.png',
  '东亚银行': 'assets/bank_icons/bea.png',
  '恒生银行': 'assets/bank_icons/hang_seng.png',
  '星展银行': 'assets/bank_icons/dbs.png',
  '三菱日联银行': 'assets/bank_icons/mufg.png',
  '三井住友银行': 'assets/bank_icons/smbc.png',
  '瑞穗银行': 'assets/bank_icons/mizuho.png',
};

/// 根据银行名称匹配图标路径。
///
/// 优先精确匹配，其次模糊匹配（包含关系）。
/// 匹配失败返回 null，调用方使用默认线稿图标。
String? matchBankIcon(String bankName) {
  final String name = bankName.trim();
  if (name.isEmpty) return null;

  // 精确匹配
  if (kBankIconMap.containsKey(name)) {
    return kBankIconMap[name];
  }

  // 模糊匹配：账户名称包含银行关键词
  for (final MapEntry<String, String> entry in kBankIconMap.entries) {
    if (name.contains(entry.key)) {
      return entry.value;
    }
  }

  return null;
}
