import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../record/providers/recording_settings_provider.dart' show appPrefs;

/// 购物清单条目（预算页「购物清单」推演实现，对标小青账会员位）。
///
/// 小青账该位置需会员可见，此处按现有数据逻辑推演为**本地清单**：
/// 名称 + 计划金额（可为空）+ 完成态；点项打开「记一笔」支出页并预填
/// 金额与备注，保存成功后自动标记已购。清单不进账本数据库
/// （纯本地规划工具），重启不丢。
class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    this.amountMinor = 0,
    this.done = false,
  });

  final String id;
  final String name;

  /// 计划金额（分）；0 = 未填金额。
  final int amountMinor;

  /// 是否已购（点项记账成功后自动勾上）。
  final bool done;

  ShoppingItem copyWith({
    String? name,
    int? amountMinor,
    bool? done,
  }) =>
      ShoppingItem(
        id: id,
        name: name ?? this.name,
        amountMinor: amountMinor ?? this.amountMinor,
        done: done ?? this.done,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'amountMinor': amountMinor,
        'done': done,
      };

  /// 从 JSON 还原；缺字段或类型不符回落默认值（向前兼容）。
  static ShoppingItem fromJson(Map<String, dynamic> json) => ShoppingItem(
        id: (json['id'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        amountMinor: (json['amountMinor'] as num?)?.toInt() ?? 0,
        done: (json['done'] as bool?) ?? false,
      );
}

/// 购物清单持久化 key（SharedPreferences）。
const String _shoppingListKey = 'budget_shopping_list_v1';

/// 购物清单状态：内存态 + 每次变更立即落盘（与记账设置同款模式）。
class ShoppingListNotifier extends StateNotifier<List<ShoppingItem>> {
  ShoppingListNotifier() : super(_loadFromPrefs());

  /// 启动时从 SharedPreferences 还原；无记录或解析失败回落空清单。
  static List<ShoppingItem> _loadFromPrefs() {
    try {
      final String? raw = appPrefs.getString(_shoppingListKey);
      if (raw == null || raw.isEmpty) return const <ShoppingItem>[];
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((dynamic e) => ShoppingItem.fromJson(e as Map<String, dynamic>))
          .where((ShoppingItem e) => e.id.isNotEmpty && e.name.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <ShoppingItem>[];
    }
  }

  void _persist() {
    try {
      appPrefs.setString(
        _shoppingListKey,
        jsonEncode(state.map((ShoppingItem e) => e.toJson()).toList()),
      );
    } catch (_) {
      // 持久化失败不阻塞内存态使用
    }
  }

  /// 新增条目（金额 <= 0 视为未填）。同名未购条目直接累加金额不新建，
  /// 避免「牛奶 牛奶 牛奶」式重复。
  void add(String name, int amountMinor) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final int idx = state.indexWhere(
      (ShoppingItem e) => !e.done && e.name == trimmed,
    );
    if (idx >= 0) {
      if (amountMinor <= 0) return;
      final List<ShoppingItem> next = List<ShoppingItem>.of(state);
      next[idx] = next[idx].copyWith(
        amountMinor: next[idx].amountMinor + amountMinor,
      );
      state = next;
    } else {
      state = <ShoppingItem>[
        ...state,
        ShoppingItem(
          id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
          name: trimmed,
          amountMinor: amountMinor > 0 ? amountMinor : 0,
        ),
      ];
    }
    _persist();
  }

  /// 勾选 / 取消勾选（点项记账成功后自动置 true）。
  void toggleDone(String id) {
    state = <ShoppingItem>[
      for (final ShoppingItem e in state)
        if (e.id == id) e.copyWith(done: !e.done) else e,
    ];
    _persist();
  }

  /// 删除单条。
  void remove(String id) {
    state = state.where((ShoppingItem e) => e.id != id).toList(growable: false);
    _persist();
  }

  /// 清除全部已购条目（清单区「清已购」）。
  void clearDone() {
    state = state.where((ShoppingItem e) => !e.done).toList(growable: false);
    _persist();
  }
}

final StateNotifierProvider<ShoppingListNotifier, List<ShoppingItem>>
    shoppingListProvider =
    StateNotifierProvider<ShoppingListNotifier, List<ShoppingItem>>(
  (Ref ref) => ShoppingListNotifier(),
);
