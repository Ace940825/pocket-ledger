import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// 卡片管理：独立存储「卡号基本信息」的功能模块。
///
/// 与「账户页（Account）」完全解耦——这是用户明确要求的独立功能：
/// 仅记录卡号、银行、发卡组织、有效期、安全码、还款方式等基础信息，
/// 不接入账户仓储（Accounts 表），数据以 JSON 列表形式持久化到
/// SharedPreferences，无需 build_runner。
///
/// 通过 [cardStoreProvider] 暴露，编辑/删除后所有监听页面（管理页、详情页）
/// 自动重建，实现「编辑 → 保存 → 详情回显」闭环。

/// 还款计算方式。
enum CardRepayMode {
  /// 免息期：账单日后 N 天为还款日。
  graceDays('免息期'),

  /// 固定还款日：每月第 N 号为还款日。
  fixedDay('固定还款日');

  const CardRepayMode(this.label);
  final String label;
}

/// 卡片类型。
enum CardType {
  /// 信用卡（参与还款日倒计时计算）。
  credit('信用卡'),

  /// 股票/证券账户（无还款日）。
  stock('证券账户'),

  /// 储蓄/借记卡。
  deposit('储蓄卡'),

  /// 其他。
  other('其他');

  const CardType(this.label);
  final String label;
}

/// 银行 BIN 号前缀表（策划子集，非穷举、不保证实时准确）。
///
/// 采用「两层混合」以提升识别命中率：
///  - **6 位精确 BIN**：优先匹配，能精确区分卡组织 / 卡等级，准确性最高；
///  - **4 位号段家族**（如 `6228`→农业银行、`6225`→招商银行）：兜底覆盖，
///    国内 62 开头卡前 4 位基本即可锁定银行。
/// 5 位前缀（如 `62284`）表示一段号（622840–622849），用以扩大单条覆盖。
///
/// 匹配时「最长前缀优先」：同一卡号若同时命中 4 位与 6 位，取 6 位所属银行，
/// 因此精确项总能压过号段家族。任何未命中都走「手动选择 / 不选择」兜底，绝不误判。
/// 如需更全的映射，替换此表即可，识别逻辑无需改动。
const Map<String, List<String>> _bankBinPrefixes = <String, List<String>>{
  '工商银行': <String>[
    // 4 位号段家族（兜底）
    '6202', '6212', '6215', '6217', '6220', '6221', '6222', '6223',
    // 6 位精确 BIN
    '621226', '621558', '621559', '621722', '621721', '621281', '621288',
    '622200', '622203', '622206', '622236', '622246', '622304', '622306',
    '622314', '622317', '622402', '622403', '622504', '622505', '622513',
    '622604', '622605', '622606', '622703', '622715', '622903', '622706',
    '622904', '622599', '623002', '623006', '623008', '623011', '623012',
    '623014', '623015', '623100', '623202', '623301', '623400', '623500',
    '623602', '623803', '623901', '624100', '624200', '624301', '624402',
    '624000', '625309', '625330', '625331', '625332', '625650', '625708',
    '625709', '625858', '625859', '625860', '625160', '620200', '620516',
    // 信用卡（非 62 开头）
    '402791', '427028', '427038', '548259', '524374', '550213',
    '356879', '356880', '356881', '356882', '528856',
  ],
  '建设银行': <String>[
    '6227',
    '4367',
    '4366',
    '621700',
    '622280',
    '622700',
    '436742',
    '436745',
    '621081',
    '621598',
    '620060',
    '621080',
    '625362',
  ],
  '农业银行': <String>[
    '6228', '62284', // 62284 覆盖 622840–622849
    '622841', '622848', '622821', '622823', '622820', '621282', '621336',
  ],
  '中国银行': <String>[
    '6216',
    '6013',
    '4563',
    '621256',
    '621283',
    '621660',
    '621669',
    '621678',
    '601382',
    '409666',
    '438088',
    '622752',
    '622760',
  ],
  '交通银行': <String>[
    '6014',
    '4055',
    '4349',
    '4581',
    '4910',
    '5201',
    '5229',
    '5378',
    '5528',
    '9555',
    '622250',
    '622251',
    '622252',
    '622253',
    '622254',
    '622255',
    '622256',
    '622257',
    '622258',
    '622259',
    '622260',
    '622261',
    '622262',
    '622284',
    '622285',
    '622656',
    '601428',
    '405512',
    '434910',
    '458123',
    '49104',
    '520169',
    '522964',
    '53783',
    '552853',
    '521899',
    '955590',
    '955591',
    '955592',
    '955593',
    '628216',
    '628218',
  ],
  '招商银行': <String>[
    '6225',
    '4392',
    '4792',
    '5213',
    '5124',
    '5240',
    '5456',
    '5459',
    '5525',
    '5526',
    '5187',
    '6258',
    '6282',
    '3702',
    '621286',
    '621483',
    '621485',
    '621486',
    '621299',
    '622575',
    '622576',
    '622577',
    '622578',
    '622579',
    '622580',
    '622581',
    '622582',
    '622588',
    '622598',
    '622609',
    '623126',
    '623136',
    '623262',
    '623265',
    '439188',
    '439225',
    '439226',
    '439227',
    '479228',
    '479229',
    '510529',
    '521302',
    '512425',
    '524011',
    '545619',
    '545620',
    '545621',
    '545623',
    '545947',
    '545948',
    '552534',
    '552587',
    '518710',
    '518718',
    '625802',
    '625803',
    '625657',
    '628262',
    '628362',
    '370285',
    '370286',
    '370287',
    '370289',
    '356885',
    '356886',
    '356887',
    '356888',
    '356889',
    '356890',
    '628290',
    '402658',
    '410062',
    '468203',
    '620520',
    '690755',
  ],
  '邮政储蓄银行': <String>[
    '6210',
    '6211',
    '621096',
    '621098',
    '622150',
    '622188',
    '621798',
    '621285',
  ],
  '兴业银行': <String>[
    '6229',
    '4512',
    '4619',
    '4385',
    '5230',
    '451289',
    '461982',
    '622908',
    '622909',
    '438588',
    '523036',
  ],
  '中信银行': <String>[
    '4336',
    '4338',
    '4427',
    '6217',
    '6232',
    '3769',
    '4003',
    '4033',
    '4041',
    '4042',
    '5149',
    '5589',
    '6281',
    '6283',
    '433670',
    '433680',
    '442729',
    '442730',
    '620082',
    '622690',
    '622691',
    '622692',
    '622696',
    '622698',
    '622998',
    '622999',
    '433671',
    '621771',
    '621767',
    '621768',
    '621770',
    '621772',
    '621773',
    '620527',
    '621769',
    '623280',
    '376968',
    '376969',
    '400360',
    '403391',
    '403392',
    '376966',
    '404158',
    '404159',
    '404171',
    '404172',
    '404173',
    '404174',
    '404157',
    '433667',
    '433669',
    '514906',
    '403393',
    '520108',
    '433666',
    '558916',
    '622679',
    '622680',
    '622688',
    '622689',
    '628206',
    '628209',
    '518212',
    '628208',
    '356390',
    '356391',
    '356392',
    '622916',
    '622918',
    '622919',
    '628370',
    '628371',
    '628372',
    '622766',
    '622767',
    '622768',
    '622678',
  ],
  '光大银行': <String>[
    '4864',
    '356837',
    '486497',
    '622660',
    '622662',
    '622663',
    '622668',
  ],
  '浦发银行': <String>[
    '4047',
    '5156',
    '6259',
    '6205',
    '356851',
    '356852',
    '404738',
    '404739',
    '456418',
    '498451',
    '515672',
    '356850',
    '517650',
    '525998',
    '622516',
    '622517',
    '622518',
    '622521',
    '622522',
    '622523',
    '622177',
    '622277',
    '622520',
    '628222',
    '628221',
    '622176',
    '622276',
    '622228',
    '625957',
    '625958',
    '620530',
    '625993',
    '625833',
    '622693',
    '625971',
    '625970',
    '377187',
    '625831',
    '622519',
    '622500',
  ],
  '民生银行': <String>[
    '6226',
    '4155',
    '4213',
    '5452',
    '5176',
    '415599',
    '421393',
    '545217',
    '622615',
    '622616',
    '622622',
    '407405',
    '517636',
    '512466',
    '421870',
  ],
  '广发银行': <String>[
    '4063',
    '4368',
    '4870',
    '406365',
    '436768',
    '436770',
    '487013',
    '491032',
    '491034',
  ],
  '平安银行': <String>[
    '622298',
    '622986',
    '623058',
    '622989',
    '412963',
  ],
  '北京银行': <String>[
    '6029',
    '602969',
    '621418',
    '621419',
    '621420',
    '621268',
    '621269',
  ],
  '上海银行': <String>[
    '622892',
    '622893',
    '622894',
    '622895',
    '622896',
    '622890',
    '402674',
  ],
  '华夏银行': <String>[
    '625969',
  ],
  '宁波银行': <String>[
    '512431',
    '520194',
    '622318',
    '622778',
    '622282',
  ],
};

/// 取卡号纯数字。
String _digitsOnly(String cardNumber) =>
    cardNumber.replaceAll(RegExp(r'\D'), '');

/// 判断 [digits] 前 [len] 位是否落在 [lo, hi] 闭区间。
bool _prefixInRange(String digits, int len, int lo, int hi) {
  if (digits.length < len) return false;
  final int? v = int.tryParse(digits.substring(0, len));
  return v != null && v >= lo && v <= hi;
}

/// 根据卡号自动识别发卡组织（卡组织 / 卡 Bin 的网络标识）。
///
/// 依据 ISO/IEC 7812 的 IIN 区间，属公开稳定规则，可靠性远高于银行 BIN 推断。
/// 返回与 UI「发卡组织」选择器一致的文案；无法识别返回 null。
/// 各区间基本互不冲突，按常见约定排序（银联 62 优先）。
String? identifyCardOrg(String cardNumber) {
  final String d = _digitsOnly(cardNumber);
  if (d.isEmpty) return null;

  // 银联：以 62 开头。
  if (d.startsWith('62')) return '银联 UnionPay';
  // Visa：以 4 开头。
  if (d.startsWith('4')) return 'VISA';
  // Mastercard：51–55，或 2221–2720。
  if (_prefixInRange(d, 2, 51, 55) || _prefixInRange(d, 4, 2221, 2720)) {
    return 'Mastercard';
  }
  // 美国运通：34 / 37。
  if (d.startsWith('34') || d.startsWith('37')) return '美国运通 AE';
  // JCB：3528–3589。
  if (_prefixInRange(d, 4, 3528, 3589)) return 'JCB';
  // 大莱 Diners：300–305、3095、36、38、39。
  if (_prefixInRange(d, 3, 300, 305) ||
      d.startsWith('3095') ||
      d.startsWith('36') ||
      d.startsWith('38') ||
      d.startsWith('39')) {
    return '大莱 Diners';
  }
  // 发现 Discover：6011、644–649、65。
  if (d.startsWith('6011') ||
      _prefixInRange(d, 3, 644, 649) ||
      d.startsWith('65')) {
    return '发现 Discover';
  }
  return null;
}

/// Luhn 校验（ISO/IEC 7812），判断卡号是否可能为有效卡号。
///
/// 仅作格式 / checksum 校验，不验证真实存在；卡号不足 12 位直接判否。
bool isValidCardNumber(String cardNumber) {
  final String d = _digitsOnly(cardNumber);
  if (d.length < 12) return false;
  int sum = 0;
  bool alternate = false;
  for (int i = d.length - 1; i >= 0; i--) {
    int n = int.parse(d[i]);
    if (alternate) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
    alternate = !alternate;
  }
  return sum % 10 == 0;
}

/// 根据卡号自动识别发卡行。
///
/// 取卡号纯数字，对照 [_bankBinPrefixes] 做前缀匹配，**最长前缀优先**
/// （6 位精确 BIN 命中时总会压过 4 位号段家族）。
/// 卡号不足 4 位、或卡号已较完整（>=12 位）却未通过 Luhn 校验、
/// 或未命中任何前缀时返回 `null`，由「手动选择 / 不选择」兜底。
String? identifyBank(String cardNumber) {
  final String digits = _digitsOnly(cardNumber);
  if (digits.length < 4) return null;
  // 卡号已较完整时先做 Luhn 校验：明显输错的完整卡号不再被臆测成某银行。
  // （4–11 位属于输入中途，跳过 Luhn 以便即时识别银行。）
  if (digits.length >= 12 && !isValidCardNumber(digits)) return null;
  String? bestBank;
  int bestLen = 0;
  for (final MapEntry<String, List<String>> entry in _bankBinPrefixes.entries) {
    for (final String prefix in entry.value) {
      if (digits.startsWith(prefix) && prefix.length > bestLen) {
        bestLen = prefix.length;
        bestBank = entry.key;
      }
    }
  }
  return bestBank;
}

/// 单张卡片的完整信息（独立存储，不关联账户）。
class CardInfo {
  const CardInfo({
    required this.id,
    this.cardNumber = '',
    this.bankName = '',
    this.alias = '',
    this.cardOrg = '',
    this.validity = '',
    this.cvv = '',
    this.billDay = 1,
    this.repayMode = CardRepayMode.graceDays,
    this.repayValue = 0,
    this.repayReminder = true,
    this.currency = '人民币',
    this.creditLimit = '',
    this.cardHolder = '',
    this.remark = '',
    this.cardType = CardType.credit,
  });

  final String id;
  final String cardNumber;
  final String bankName;
  final String alias;
  final String cardOrg;
  final String validity;
  final String cvv;

  /// 账单日（每月几号，1-31）。
  final int billDay;

  /// 还款计算方式。
  final CardRepayMode repayMode;

  /// 还款值：免息期模式 = 天数；固定还款日模式 = 每月第几号。
  final int repayValue;

  /// 是否开启还款日提醒。
  final bool repayReminder;

  /// 币种。
  final String currency;

  /// 固定额度（用户输入原样保存，如 "5,000"）。
  final String creditLimit;

  /// 持卡人。
  final String cardHolder;

  final String remark;
  final CardType cardType;

  CardInfo copyWith({
    String? id,
    String? cardNumber,
    String? bankName,
    String? alias,
    String? cardOrg,
    String? validity,
    String? cvv,
    int? billDay,
    CardRepayMode? repayMode,
    int? repayValue,
    bool? repayReminder,
    String? currency,
    String? creditLimit,
    String? cardHolder,
    String? remark,
    CardType? cardType,
  }) {
    return CardInfo(
      id: id ?? this.id,
      cardNumber: cardNumber ?? this.cardNumber,
      bankName: bankName ?? this.bankName,
      alias: alias ?? this.alias,
      cardOrg: cardOrg ?? this.cardOrg,
      validity: validity ?? this.validity,
      cvv: cvv ?? this.cvv,
      billDay: billDay ?? this.billDay,
      repayMode: repayMode ?? this.repayMode,
      repayValue: repayValue ?? this.repayValue,
      repayReminder: repayReminder ?? this.repayReminder,
      currency: currency ?? this.currency,
      creditLimit: creditLimit ?? this.creditLimit,
      cardHolder: cardHolder ?? this.cardHolder,
      remark: remark ?? this.remark,
      cardType: cardType ?? this.cardType,
    );
  }

  /// 卡号后四位（用于卡片列表展示）。
  String get last4 {
    final String digits = cardNumber.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
  }

  /// 脱敏卡号（保留前 4 与后 4，中间打码），用于大卡片预览。
  String get maskedNumber {
    final String digits = cardNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 4) return cardNumber;
    final String head = digits.substring(0, 4);
    final String tail = digits.substring(digits.length - 4);
    return '$head **** **** $tail';
  }

  /// 距最近还款日天数；非信用卡返回 null（如证券账户）。
  int? get repaymentDays {
    if (cardType != CardType.credit) return null;
    return computeCardSchedule(billDay, repayMode, repayValue, DateTime.now())
        .daysToRepay;
  }

  /// 还款日文案，如 "每月1日" / "50天"。
  String get repayLabel {
    if (repayMode == CardRepayMode.fixedDay) {
      return '每月$repayValue日';
    }
    return '$repayValue天';
  }

  /// 账单日文案，如 "每月1日"。
  String get billDayLabel => '每月$billDay日';

  /// 序列化为 JSON（供 SharedPreferences 持久化）。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'cardNumber': cardNumber,
        'bankName': bankName,
        'alias': alias,
        'cardOrg': cardOrg,
        'validity': validity,
        'cvv': cvv,
        'billDay': billDay,
        'repayMode': repayMode.name,
        'repayValue': repayValue,
        'repayReminder': repayReminder,
        'currency': currency,
        'creditLimit': creditLimit,
        'cardHolder': cardHolder,
        'remark': remark,
        'cardType': cardType.name,
      };

  /// 从 JSON 还原，缺字段回落默认值（向前兼容）。
  static CardInfo fromJson(Map<String, dynamic> json) {
    T enumOr<T extends Enum>(String key, List<T> values, T fallback) {
      final String? raw = json[key] as String?;
      if (raw == null) return fallback;
      try {
        return values.byName(raw);
      } catch (_) {
        return fallback;
      }
    }

    int intOr(String key, [int fallback = 0]) {
      final num? raw = json[key] as num?;
      return raw?.toInt() ?? fallback;
    }

    bool boolOr(String key, [bool fallback = false]) =>
        (json[key] as bool?) ?? fallback;

    return CardInfo(
      id: (json['id'] as String?) ?? const Uuid().v4(),
      cardNumber: (json['cardNumber'] as String?) ?? '',
      bankName: (json['bankName'] as String?) ?? '',
      alias: (json['alias'] as String?) ?? '',
      cardOrg: (json['cardOrg'] as String?) ?? '',
      validity: (json['validity'] as String?) ?? '',
      cvv: (json['cvv'] as String?) ?? '',
      billDay: intOr('billDay', 1).clamp(1, 31),
      repayMode: enumOr(
        'repayMode',
        CardRepayMode.values,
        CardRepayMode.graceDays,
      ),
      repayValue: intOr('repayValue'),
      repayReminder: boolOr('repayReminder', true),
      currency: (json['currency'] as String?) ?? '人民币',
      creditLimit: (json['creditLimit'] as String?) ?? '',
      cardHolder: (json['cardHolder'] as String?) ?? '',
      remark: (json['remark'] as String?) ?? '',
      cardType: enumOr('cardType', CardType.values, CardType.credit),
    );
  }
}

/// 信用卡日程计算结果。
class CardSchedule {
  const CardSchedule({
    required this.repayDate,
    required this.daysToRepay,
    required this.nextBillingDate,
    required this.interestFreeDays,
  });

  /// 最近一个还款日（>= 今天）。
  final DateTime repayDate;

  /// 距该还款日的天数。
  final int daysToRepay;

  /// 下期账单日。
  final DateTime nextBillingDate;

  /// 今日免息期：今天消费计入下个账单周期，可享受到的免息天数。
  final int interestFreeDays;
}

/// 当月天数（用于把账单日/还款日收敛到合法日期）。
int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// 给定某账单月，返回该期对应的还款日。
DateTime? _repayDateForBill(
  int year,
  int month,
  int billDay,
  CardRepayMode mode,
  int repayValue,
) {
  final int clampedBill = billDay.clamp(1, _daysInMonth(year, month));
  final DateTime bill = DateTime(year, month, clampedBill);
  if (mode == CardRepayMode.graceDays) {
    return bill.add(Duration(days: repayValue));
  }
  // 固定还款日：若账单日 <= 还款日，则当月还款；否则顺延至次月。
  int ry = year;
  int rm = month;
  if (clampedBill > repayValue) {
    rm += 1;
    if (rm > 12) {
      rm = 1;
      ry += 1;
    }
  }
  final int clampedRepay = repayValue.clamp(1, _daysInMonth(ry, rm));
  return DateTime(ry, rm, clampedRepay);
}

/// 根据账单日与还款方式，推算还款相关日程。
///
/// - 下期账单日：今天之后第一个 day == [billDay] 的日期（严格晚于今天）。
/// - 最近还款日：>= 今天的最近一个还款日。
/// - 今日免息期：下一个严格晚于最近还款日的还款日距今天的天数。
CardSchedule computeCardSchedule(
  int billDay,
  CardRepayMode mode,
  int repayValue,
  DateTime today,
) {
  int clampedDay(int year, int month) =>
      billDay.clamp(1, _daysInMonth(year, month));

  // 下期账单日
  DateTime nextBilling =
      DateTime(today.year, today.month, clampedDay(today.year, today.month));
  while (!nextBilling.isAfter(today)) {
    int y = nextBilling.year;
    int m = nextBilling.month + 1;
    if (m > 12) {
      m = 1;
      y += 1;
    }
    nextBilling = DateTime(y, m, clampedDay(y, m));
  }

  // 最近还款日（>= 今天）
  DateTime? soonestRepay;
  for (int offset = 0; offset < 4; offset++) {
    int y = today.year;
    int m = today.month + offset;
    while (m > 12) {
      m -= 12;
      y += 1;
    }
    final DateTime? repay = _repayDateForBill(y, m, billDay, mode, repayValue);
    if (repay == null || repay.isBefore(today)) continue;
    if (soonestRepay == null || repay.isBefore(soonestRepay)) {
      soonestRepay = repay;
    }
  }
  final DateTime repayDate = soonestRepay ?? nextBilling;

  // 今日免息期：下一个严格晚于 repayDate 的还款日距今天的天数
  DateTime? nextRepay;
  for (int offset = 0; offset < 5; offset++) {
    int y = today.year;
    int m = today.month + offset;
    while (m > 12) {
      m -= 12;
      y += 1;
    }
    final DateTime? repay = _repayDateForBill(y, m, billDay, mode, repayValue);
    if (repay != null && repay.isAfter(repayDate)) {
      nextRepay = repay;
      break;
    }
  }
  final DateTime interestFreeEnd = nextRepay ?? repayDate;
  final int interestFreeDays = interestFreeEnd.difference(today).inDays;
  final int daysToRepay = repayDate.difference(today).inDays;

  return CardSchedule(
    repayDate: repayDate,
    daysToRepay: daysToRepay,
    nextBillingDate: nextBilling,
    interestFreeDays: interestFreeDays,
  );
}

/// 共享持久化实例。由 `main()` 在 `runApp()` 前完成初始化：
/// `appPrefs = await SharedPreferences.getInstance();`
late final SharedPreferences appPrefs;

const String _cardStoreKey = 'card_store_v1';

/// 卡片存储：以 JSON 列表持久化全部卡片，提供 upsert / getById / delete。
///
/// 不接入账户仓储，是用户明确要求的独立功能。
class CardStore extends StateNotifier<List<CardInfo>> {
  CardStore() : super(_loadFromPrefs());

  /// 启动/重开时从 SharedPreferences 还原；无记录回落种子数据并落盘。
  static List<CardInfo> _loadFromPrefs() {
    try {
      final String? raw = appPrefs.getString(_cardStoreKey);
      if (raw == null) {
        final List<CardInfo> seeds = _seed();
        try {
          appPrefs.setString(
            _cardStoreKey,
            jsonEncode(seeds.map((CardInfo c) => c.toJson()).toList()),
          );
        } catch (_) {
          // 落盘失败不影响内存态
        }
        return seeds;
      }
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((dynamic e) => CardInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _seed();
    }
  }

  /// 首次安装的两张种子卡（演示数据）。
  static List<CardInfo> _seed() => <CardInfo>[
        CardInfo(
          id: const Uuid().v4(),
          cardNumber: '6228 1202 1576 6022',
          bankName: '安阳银行',
          alias: '安阳银行信用卡',
          cardOrg: 'UnionPay',
          validity: '12/28',
          cvv: '123',
          billDay: 1,
          repayMode: CardRepayMode.graceDays,
          repayValue: 50,
          repayReminder: true,
          currency: '人民币',
          creditLimit: '5,000',
          remark: '日常消费卡',
          cardType: CardType.credit,
        ),
        CardInfo(
          id: const Uuid().v4(),
          cardNumber: '6217 0000 1234 5678',
          bankName: '华泰证券',
          alias: '华泰股票账户',
          cardOrg: '证券',
          validity: '',
          cvv: '',
          billDay: 1,
          repayMode: CardRepayMode.graceDays,
          repayValue: 0,
          repayReminder: false,
          currency: '人民币',
          creditLimit: '',
          remark: '',
          cardType: CardType.stock,
        ),
      ];

  /// 统一写入入口：更新内存态后立即持久化。
  void _persist() {
    try {
      appPrefs.setString(
        _cardStoreKey,
        jsonEncode(state.map((CardInfo c) => c.toJson()).toList()),
      );
    } catch (_) {
      // 持久化失败不阻塞内存态使用
    }
  }

  /// 新增或更新一张卡（按 id 去重；id 不存在则追加）。
  void upsert(CardInfo card) {
    final int idx = state.indexWhere((CardInfo c) => c.id == card.id);
    List<CardInfo> next;
    if (idx >= 0) {
      next = List<CardInfo>.from(state)..[idx] = card;
    } else {
      next = <CardInfo>[...state, card];
    }
    state = next;
    _persist();
  }

  /// 按 id 查询单卡；不存在返回 null。
  CardInfo? getById(String id) =>
      state.where((CardInfo c) => c.id == id).firstOrNull;

  /// 删除指定 id 的卡。
  void delete(String id) {
    state = state.where((CardInfo c) => c.id != id).toList();
    _persist();
  }

  /// 清空所有卡片（用于「清空全部数据」功能）。
  void clearAll() {
    state = <CardInfo>[];
    _persist();
  }
}

/// 卡片存储 Provider，管理页/详情页/编辑页共享同一份内存态与持久化数据。
final StateNotifierProvider<CardStore, List<CardInfo>> cardStoreProvider =
    StateNotifierProvider<CardStore, List<CardInfo>>(
  (Ref ref) => CardStore(),
);
