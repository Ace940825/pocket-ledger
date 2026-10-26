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
}

/// 卡片存储 Provider，管理页/详情页/编辑页共享同一份内存态与持久化数据。
final StateNotifierProvider<CardStore, List<CardInfo>> cardStoreProvider =
    StateNotifierProvider<CardStore, List<CardInfo>>(
  (Ref ref) => CardStore(),
);
