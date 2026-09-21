import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 键盘主题风格。
enum KeyboardThemeStyle {
  simple('简约'),
  flat('扁平'),
  bordered('边框'),
  custom('自定色');

  const KeyboardThemeStyle(this.label);
  final String label;
}

/// 计算公式模式。
enum KeyboardFormula {
  plusMinus('+-'),
  full('+-×÷');

  const KeyboardFormula(this.label);
  final String label;
}

/// 数字键盘排序。
enum KeyboardNumberOrder {
  ascending('123.789'),
  descending('789.123');

  const KeyboardNumberOrder(this.label);
  final String label;
}

/// 高级子模式。
enum KeyboardSubMode {
  simple('简约'),
  compact('紧凑'),
  full('饱满');

  const KeyboardSubMode(this.label);
  final String label;
}

/// 记一笔内部「记账页面设置」状态。
///
/// 当前持久化到 SharedPreferences（见 RecordingSettingsNotifier），重启不丢。
class RecordingSettings {
  const RecordingSettings({
    this.themeStyle = KeyboardThemeStyle.simple,
    this.formula = KeyboardFormula.plusMinus,
    this.numberOrder = KeyboardNumberOrder.ascending,
    this.heightScale = 1.0,
    this.subMode = KeyboardSubMode.simple,
    this.topAreaRows = '1行',
    this.amountPosition = '右',
    this.funcButtonRows = '单行',
    this.iconBackground = '关闭',
    this.categoryStyle = '列表翻页',
    this.iconSize = 1.2,
    this.iconRadius = 0.7,
    this.categoryRows = 4,
    this.recordFutureBill = false,
    this.imageCrop = false,
    this.followMode = false,
    this.categoryAssetMemory = false,
    this.promptWhenNoAsset = true,
    this.balanceInsufficientCheck = false,
    this.defaultAssetAccount,
    this.accountPickerListView = false,
  });

  final KeyboardThemeStyle themeStyle;
  final KeyboardFormula formula;
  final KeyboardNumberOrder numberOrder;
  final double heightScale;
  final KeyboardSubMode subMode;

  // 高级设置
  final String topAreaRows; // '1行' / '2行'
  final String amountPosition; // '左' / '右'
  final String funcButtonRows; // '单行' / '多行'
  final String iconBackground; // '关闭' / '开启'

  // 分类设置
  final String categoryStyle;
  final double iconSize;
  final double iconRadius;
  final int categoryRows;

  // 一般设置开关
  final bool recordFutureBill;
  final bool imageCrop;

  // 默认设置开关
  final bool followMode;
  final bool categoryAssetMemory;

  // 默认资产设置
  /// 未选择资产提示：没有选择资产会弹出提示。
  final bool promptWhenNoAsset;

  /// 资产余额不足校验（仅新增）：开启后资产余额扣减不可为负数。
  final bool balanceInsufficientCheck;

  /// 记账页面默认选择的资产账户名，null = 跟随默认（"默认账户"）。
  final String? defaultAssetAccount;

  /// 账户选择弹窗视图模式记忆：true = 列表，false = 网格（默认）。
  final bool accountPickerListView;

  RecordingSettings copyWith({
    KeyboardThemeStyle? themeStyle,
    KeyboardFormula? formula,
    KeyboardNumberOrder? numberOrder,
    double? heightScale,
    KeyboardSubMode? subMode,
    String? topAreaRows,
    String? amountPosition,
    String? funcButtonRows,
    String? iconBackground,
    String? categoryStyle,
    double? iconSize,
    double? iconRadius,
    int? categoryRows,
    bool? recordFutureBill,
    bool? imageCrop,
    bool? followMode,
    bool? categoryAssetMemory,
    bool? promptWhenNoAsset,
    bool? balanceInsufficientCheck,
    String? defaultAssetAccount,
    bool? accountPickerListView,
    bool resetDefaultAssetAccount = false,
  }) {
    return RecordingSettings(
      themeStyle: themeStyle ?? this.themeStyle,
      formula: formula ?? this.formula,
      numberOrder: numberOrder ?? this.numberOrder,
      heightScale: heightScale ?? this.heightScale,
      subMode: subMode ?? this.subMode,
      topAreaRows: topAreaRows ?? this.topAreaRows,
      amountPosition: amountPosition ?? this.amountPosition,
      funcButtonRows: funcButtonRows ?? this.funcButtonRows,
      iconBackground: iconBackground ?? this.iconBackground,
      categoryStyle: categoryStyle ?? this.categoryStyle,
      iconSize: iconSize ?? this.iconSize,
      iconRadius: iconRadius ?? this.iconRadius,
      categoryRows: categoryRows ?? this.categoryRows,
      recordFutureBill: recordFutureBill ?? this.recordFutureBill,
      imageCrop: imageCrop ?? this.imageCrop,
      followMode: followMode ?? this.followMode,
      categoryAssetMemory: categoryAssetMemory ?? this.categoryAssetMemory,
      promptWhenNoAsset: promptWhenNoAsset ?? this.promptWhenNoAsset,
      balanceInsufficientCheck:
          balanceInsufficientCheck ?? this.balanceInsufficientCheck,
      defaultAssetAccount: resetDefaultAssetAccount
          ? null
          : (defaultAssetAccount ?? this.defaultAssetAccount),
      accountPickerListView: accountPickerListView ?? this.accountPickerListView,
    );
  }

  /// 序列化为 JSON（供 SharedPreferences 持久化）。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'themeStyle': themeStyle.name,
        'formula': formula.name,
        'numberOrder': numberOrder.name,
        'heightScale': heightScale,
        'subMode': subMode.name,
        'topAreaRows': topAreaRows,
        'amountPosition': amountPosition,
        'funcButtonRows': funcButtonRows,
        'iconBackground': iconBackground,
        'categoryStyle': categoryStyle,
        'iconSize': iconSize,
        'iconRadius': iconRadius,
        'categoryRows': categoryRows,
        'recordFutureBill': recordFutureBill,
        'imageCrop': imageCrop,
        'followMode': followMode,
        'categoryAssetMemory': categoryAssetMemory,
        'promptWhenNoAsset': promptWhenNoAsset,
        'balanceInsufficientCheck': balanceInsufficientCheck,
        'defaultAssetAccount': defaultAssetAccount,
        'accountPickerListView': accountPickerListView,
      };

  /// 从 JSON 还原，缺字段或解析失败回落到对应默认值（向前兼容）。
  static RecordingSettings fromJson(Map<String, dynamic> json) {
    T enumOr<T extends Enum>(String key, List<T> values, T fallback) {
      final String? raw = json[key] as String?;
      if (raw == null) return fallback;
      try {
        return values.byName(raw);
      } catch (_) {
        return fallback;
      }
    }

    double dblOr(String key, double fallback) {
      final num? raw = json[key] as num?;
      return raw?.toDouble() ?? fallback;
    }

    bool boolOr(String key, bool fallback) =>
        (json[key] as bool?) ?? fallback;

    return RecordingSettings(
      themeStyle: enumOr('themeStyle', KeyboardThemeStyle.values,
          KeyboardThemeStyle.simple),
      formula: enumOr('formula', KeyboardFormula.values,
          KeyboardFormula.plusMinus),
      numberOrder: enumOr('numberOrder', KeyboardNumberOrder.values,
          KeyboardNumberOrder.ascending),
      heightScale: dblOr('heightScale', 1.0),
      subMode: enumOr('subMode', KeyboardSubMode.values,
          KeyboardSubMode.simple),
      topAreaRows: (json['topAreaRows'] as String?) ?? '1行',
      amountPosition: (json['amountPosition'] as String?) ?? '右',
      funcButtonRows: (json['funcButtonRows'] as String?) ?? '单行',
      iconBackground: (json['iconBackground'] as String?) ?? '关闭',
      categoryStyle: (json['categoryStyle'] as String?) ?? '列表翻页',
      iconSize: dblOr('iconSize', 1.2),
      iconRadius: dblOr('iconRadius', 0.7),
      categoryRows: (json['categoryRows'] as int?) ?? 4,
      recordFutureBill: boolOr('recordFutureBill', false),
      imageCrop: boolOr('imageCrop', false),
      followMode: boolOr('followMode', false),
      categoryAssetMemory: boolOr('categoryAssetMemory', false),
      promptWhenNoAsset: boolOr('promptWhenNoAsset', true),
      balanceInsufficientCheck: boolOr('balanceInsufficientCheck', false),
      defaultAssetAccount: json['defaultAssetAccount'] as String?,
      accountPickerListView: boolOr('accountPickerListView', false),
    );
  }
}

/// 共享持久化实例。由 `main()` 在 `runApp()` 前完成初始化：
/// `appPrefs = await SharedPreferences.getInstance();`
late final SharedPreferences appPrefs;

const String _recordingSettingsKey = 'recording_settings_v1';

class RecordingSettingsNotifier extends StateNotifier<RecordingSettings> {
  RecordingSettingsNotifier() : super(_loadFromPrefs());

  /// 启动/重开时从 SharedPreferences 还原；无记录或解析失败回落默认值。
  static RecordingSettings _loadFromPrefs() {
    try {
      final String? raw = appPrefs.getString(_recordingSettingsKey);
      if (raw == null) return const RecordingSettings();
      return RecordingSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const RecordingSettings();
    }
  }

  /// 统一写入入口：更新内存态后立即持久化，避免每个 setter 散落写盘。
  void _set(RecordingSettings next) {
    state = next;
    _persist();
  }

  void _persist() {
    try {
      appPrefs.setString(_recordingSettingsKey, jsonEncode(state.toJson()));
    } catch (_) {
      // 持久化失败不阻塞内存态使用
    }
  }

  static const Map<KeyboardSubMode, Map<String, String>> _presets =
      <KeyboardSubMode, Map<String, String>>{
    KeyboardSubMode.simple: {
      'topAreaRows': '1行',
      'amountPosition': '右',
      'funcButtonRows': '单行',
      'iconBackground': '关闭',
    },
    KeyboardSubMode.compact: {
      'topAreaRows': '1行',
      'amountPosition': '右',
      'funcButtonRows': '单行',
      'iconBackground': '开启',
    },
    KeyboardSubMode.full: {
      'topAreaRows': '2行',
      'amountPosition': '左',
      'funcButtonRows': '单行',
      'iconBackground': '开启',
    },
  };

  void setThemeStyle(KeyboardThemeStyle value) {
    _set(state.copyWith(themeStyle: value));
  }

  void setFormula(KeyboardFormula value) {
    _set(state.copyWith(formula: value));
  }

  void setNumberOrder(KeyboardNumberOrder value) {
    _set(state.copyWith(numberOrder: value));
  }

  void setHeightScale(double value) {
    _set(state.copyWith(heightScale: value));
  }

  void setSubMode(KeyboardSubMode mode) {
    final Map<String, String> preset = _presets[mode]!;
    _set(state.copyWith(
      subMode: mode,
      topAreaRows: preset['topAreaRows']!,
      amountPosition: preset['amountPosition']!,
      funcButtonRows: preset['funcButtonRows']!,
      iconBackground: preset['iconBackground']!,
    ));
  }

  void setTopAreaRows(String value) {
    _set(state.copyWith(topAreaRows: value));
  }

  void setAmountPosition(String value) {
    _set(state.copyWith(amountPosition: value));
  }

  void setFuncButtonRows(String value) {
    _set(state.copyWith(funcButtonRows: value));
  }

  void setIconBackground(String value) {
    _set(state.copyWith(iconBackground: value));
  }

  void setCategoryStyle(String value) {
    _set(state.copyWith(categoryStyle: value));
  }

  void setIconSize(double value) {
    _set(state.copyWith(iconSize: value));
  }

  void setIconRadius(double value) {
    _set(state.copyWith(iconRadius: value));
  }

  void setCategoryRows(int value) {
    _set(state.copyWith(categoryRows: value));
  }

  void toggleRecordFutureBill() {
    _set(state.copyWith(recordFutureBill: !state.recordFutureBill));
  }

  void toggleImageCrop() {
    _set(state.copyWith(imageCrop: !state.imageCrop));
  }

  void toggleFollowMode() {
    _set(state.copyWith(followMode: !state.followMode));
  }

  void toggleCategoryAssetMemory() {
    _set(state.copyWith(categoryAssetMemory: !state.categoryAssetMemory));
  }

  // ── 默认资产设置 ──

  void togglePromptWhenNoAsset() {
    _set(state.copyWith(promptWhenNoAsset: !state.promptWhenNoAsset));
  }

  void toggleBalanceInsufficientCheck() {
    _set(state.copyWith(
        balanceInsufficientCheck: !state.balanceInsufficientCheck));
  }

  /// 设置默认选择的资产账户；传 null 表示恢复"默认账户"。
  void setDefaultAssetAccount(String? accountName) {
    _set(state.copyWith(
      defaultAssetAccount: accountName,
      resetDefaultAssetAccount: accountName == null,
    ));
  }

  /// 记忆账户选择弹窗的视图模式（列表 / 网格）。
  void setAccountPickerListView(bool value) {
    _set(state.copyWith(accountPickerListView: value));
  }
}

final StateNotifierProvider<RecordingSettingsNotifier, RecordingSettings>
    recordingSettingsProvider =
    StateNotifierProvider<RecordingSettingsNotifier, RecordingSettings>(
  (Ref ref) => RecordingSettingsNotifier(),
);
