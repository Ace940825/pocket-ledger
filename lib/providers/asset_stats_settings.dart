import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String _kStatsKey = 'asset_stats_settings';

/// 资产页「资产月消费统计」口径设置（对齐小青账设置面板）。
///
/// 只影响资产详情页账单列表的**总金额统计方式与分组方式**，不改动任何流水数据。
class AssetStatsSettings {
  const AssetStatsSettings({
    this.expenseWithTransfer = false,
    this.incomeWithTransfer = false,
    this.noOffset = false,
    this.groupByMonthAsset = true,
    this.groupByMonthReimburse = false,
  });

  /// 支出流水统计。
  ///
  /// - `false`（默认）= 支出只算**普通支出账单**；
  /// - `true` = 支出 = 普通支出账单 **+ 转账转出账单**
  ///   （即本账户转出的钱也算进支出）。
  final bool expenseWithTransfer;

  /// 收入流水统计。
  ///
  /// - `false`（默认）= 收入只算**普通收入账单**；
  /// - `true` = 收入 = 普通收入账单 **+ 转账转入账单**
  ///   （即本账户转入的钱也算进收入）。
  final bool incomeWithTransfer;

  /// 消费账单和退款账单不进行抵扣。
  ///
  /// - `false`（默认，面板里的「关闭」）= **进行抵扣**：退款从「支出」里扣掉，
  ///   且不计入「收入」；
  /// - `true`（面板里的「开启」）= **不抵扣**：退款按普通收入计入「收入」，
  ///   「支出」保持原值。
  final bool noOffset;

  /// 账单列表按年月分组 · 资产账户。
  ///
  /// `true`（默认）= 资产详情页按「年 -> 月」分组展示（带月标题与月汇总条）；
  /// `false` = 整年平铺，只保留日期小标题。
  final bool groupByMonthAsset;

  /// 账单列表按年月分组 · 报销账户。
  ///
  /// `true` = 报销页在列表里插入「年 -> 月」小标题，把同月的报销归到一起；
  /// `false`（默认）= 平铺列表（与报销页原有表现一致）。
  final bool groupByMonthReimburse;

  AssetStatsSettings copyWith({
    bool? expenseWithTransfer,
    bool? incomeWithTransfer,
    bool? noOffset,
    bool? groupByMonthAsset,
    bool? groupByMonthReimburse,
  }) {
    return AssetStatsSettings(
      expenseWithTransfer: expenseWithTransfer ?? this.expenseWithTransfer,
      incomeWithTransfer: incomeWithTransfer ?? this.incomeWithTransfer,
      noOffset: noOffset ?? this.noOffset,
      groupByMonthAsset: groupByMonthAsset ?? this.groupByMonthAsset,
      groupByMonthReimburse:
          groupByMonthReimburse ?? this.groupByMonthReimburse,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'expenseWithTransfer': expenseWithTransfer,
        'incomeWithTransfer': incomeWithTransfer,
        'noOffset': noOffset,
        'groupByMonthAsset': groupByMonthAsset,
        'groupByMonthReimburse': groupByMonthReimburse,
      };

  factory AssetStatsSettings.fromJson(Map<String, Object?> json) {
    return AssetStatsSettings(
      expenseWithTransfer: json['expenseWithTransfer'] == true,
      incomeWithTransfer: json['incomeWithTransfer'] == true,
      noOffset: json['noOffset'] == true,
      groupByMonthAsset: json['groupByMonthAsset'] != false,
      groupByMonthReimburse: json['groupByMonthReimburse'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssetStatsSettings &&
          other.expenseWithTransfer == expenseWithTransfer &&
          other.incomeWithTransfer == incomeWithTransfer &&
          other.noOffset == noOffset &&
          other.groupByMonthAsset == groupByMonthAsset &&
          other.groupByMonthReimburse == groupByMonthReimburse);

  @override
  int get hashCode => Object.hash(
        expenseWithTransfer,
        incomeWithTransfer,
        noOffset,
        groupByMonthAsset,
        groupByMonthReimburse,
      );

  @override
  String toString() => 'AssetStatsSettings(expense+transfer: '
      '$expenseWithTransfer, income+transfer: $incomeWithTransfer, '
      'noOffset: $noOffset, groupAsset: $groupByMonthAsset, '
      'groupReimburse: $groupByMonthReimburse)';
}

/// 设置的读写与持久化。沿用项目里 `AccountGroupCollapseNotifier` 的
/// fire-and-forget + try/catch 兜底写法：secure storage 读不到就退回默认值，
/// 绝不影响启动、不抛未捕获异常。
///
/// 旧版本（`expenseEnabled` / `compactList`）写下的 JSON 里没有新字段，
/// `fromJson` 会逐字段回退到默认值；`noOffset` 同名可继续沿用，不做破坏性升级。
class AssetStatsSettingsNotifier extends StateNotifier<AssetStatsSettings> {
  AssetStatsSettingsNotifier(this._storage) : super(const AssetStatsSettings());

  final FlutterSecureStorage _storage;

  Future<void> load() async {
    try {
      final String? raw = await _storage.read(key: _kStatsKey);
      if (raw == null || raw.isEmpty) return;
      final Map<String, Object?> parsed =
          (jsonDecode(raw) as Map<String, Object?>).cast<String, Object?>();
      state = AssetStatsSettings.fromJson(parsed);
    } catch (_) {
      // 读取 / 解析失败都保持默认设置。
    }
  }

  Future<void> save(AssetStatsSettings next) async {
    state = next;
    try {
      await _storage.write(key: _kStatsKey, value: jsonEncode(next.toJson()));
    } catch (_) {
      // 忽略：写失败只影响下次启动的还原，不影响本次会话。
    }
  }
}

final StateNotifierProvider<AssetStatsSettingsNotifier, AssetStatsSettings>
    assetStatsSettingsProvider =
    StateNotifierProvider<AssetStatsSettingsNotifier, AssetStatsSettings>(
  (Ref ref) {
    final AssetStatsSettingsNotifier notifier =
        AssetStatsSettingsNotifier(const FlutterSecureStorage());
    notifier.load(); // fire-and-forget
    return notifier;
  },
);
