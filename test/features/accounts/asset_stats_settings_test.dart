import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/providers/asset_stats_settings.dart';

/// 「资产月消费统计」设置的模型与持久化回归测试。
void main() {
  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  group('AssetStatsSettings · 模型', () {
    test('默认值对齐参考设计：三个统计开关全关、资产账户分组开、报销账户分组关', () {
      const AssetStatsSettings s = AssetStatsSettings();
      expect(s.expenseWithTransfer, isFalse);
      expect(s.incomeWithTransfer, isFalse);
      expect(s.noOffset, isFalse);
      expect(s.groupByMonthAsset, isTrue);
      expect(s.groupByMonthReimburse, isFalse);
    });

    test('copyWith 只覆盖传入字段', () {
      const AssetStatsSettings s = AssetStatsSettings();
      final AssetStatsSettings next = s.copyWith(noOffset: true);
      expect(next.noOffset, isTrue);
      expect(next.expenseWithTransfer, isFalse, reason: '未传字段保持原值');
      expect(next.groupByMonthAsset, isTrue);
    });

    test('copyWith 可以把分开关掉', () {
      const AssetStatsSettings s = AssetStatsSettings();
      expect(s.copyWith(groupByMonthAsset: false).groupByMonthAsset, isFalse);
      expect(s.copyWith(noOffset: false).noOffset, isFalse);
    });

    test('toJson / fromJson 往返一致', () {
      const AssetStatsSettings s = AssetStatsSettings(
        expenseWithTransfer: true,
        incomeWithTransfer: true,
        noOffset: true,
        groupByMonthAsset: false,
        groupByMonthReimburse: true,
      );
      expect(AssetStatsSettings.fromJson(s.toJson()), s);
    });

    test('fromJson 字段缺失时回退到默认值', () {
      final AssetStatsSettings s =
          AssetStatsSettings.fromJson(<String, Object?>{});
      expect(s, const AssetStatsSettings());
    });

    test('兼容旧版本 JSON：新字段回退默认，同名的 noOffset 继续沿用', () {
      // 旧版本写下的形态：expenseEnabled / incomeEnabled / compactList。
      final AssetStatsSettings s = AssetStatsSettings.fromJson(
        <String, Object?>{
          'expenseEnabled': true,
          'incomeEnabled': true,
          'noOffset': true,
          'compactList': true,
        },
      );
      expect(s.noOffset, isTrue, reason: 'noOffset 同名，应保留');
      expect(s.expenseWithTransfer, isFalse, reason: '旧字段不再有含义');
      expect(s.incomeWithTransfer, isFalse);
      expect(s.groupByMonthAsset, isTrue);
      expect(s.groupByMonthReimburse, isFalse);
    });

    test('== 与 hashCode 基于全部字段', () {
      const AssetStatsSettings a = AssetStatsSettings();
      const AssetStatsSettings b = AssetStatsSettings();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == a.copyWith(groupByMonthAsset: false), isFalse);
      expect(a == a.copyWith(expenseWithTransfer: true), isFalse);
    });
  });

  group('AssetStatsSettingsNotifier · 持久化', () {
    test('load 解析 JSON 并恢复设置', () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        'asset_stats_settings': '{"expenseWithTransfer":true,'
            '"incomeWithTransfer":true,"noOffset":true,'
            '"groupByMonthAsset":false,"groupByMonthReimburse":true}',
      });
      final AssetStatsSettingsNotifier n =
          AssetStatsSettingsNotifier(const FlutterSecureStorage());
      await n.load();
      expect(n.state.expenseWithTransfer, isTrue);
      expect(n.state.incomeWithTransfer, isTrue);
      expect(n.state.noOffset, isTrue);
      expect(n.state.groupByMonthAsset, isFalse);
      expect(n.state.groupByMonthReimburse, isTrue);
    });

    test('损坏的 JSON 不抛异常，保持默认值', () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        'asset_stats_settings': 'not-a-json',
      });
      final AssetStatsSettingsNotifier n =
          AssetStatsSettingsNotifier(const FlutterSecureStorage());
      await n.load();
      expect(n.state, const AssetStatsSettings());
    });

    test('save 更新 state 并落库，新实例 load 能还原', () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      final AssetStatsSettingsNotifier n =
          AssetStatsSettingsNotifier(const FlutterSecureStorage());
      const AssetStatsSettings next = AssetStatsSettings(
        expenseWithTransfer: true,
        groupByMonthAsset: false,
      );
      await n.save(next);
      expect(n.state, next, reason: 'save 后 state 立即更新');

      final AssetStatsSettingsNotifier restored =
          AssetStatsSettingsNotifier(const FlutterSecureStorage());
      await restored.load();
      expect(restored.state, next, reason: '重新 load 应还原退出前的设置');
    });
  });
}
