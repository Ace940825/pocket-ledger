import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 账户页的五大分组（固定常量）。新增分组时只要在这里追加并保持默认顺序，
/// 老用户的存储里没有的新组会被 [AccountGroupOrderNotifier] 自动追加。
const List<String> kAccountGroupOrderDefault = <String>[
  '资金类',
  '负债类',
  '投资类',
  '应收类',
  '应付类',
];

const String _kStorageKey = 'account_group_order';

/// 维护账户分组顺序：
/// - 启动时从 secure storage 读，覆盖默认；
/// - 读到的顺序里缺失的默认分组会自动补到尾部（保持向后兼容）；
/// - 写回时持久化。
class AccountGroupOrderNotifier extends StateNotifier<List<String>> {
  AccountGroupOrderNotifier(this._storage) : super(_initial(_storage));

  final FlutterSecureStorage _storage;

  static List<String> _initial(FlutterSecureStorage storage) {
    // 同步拿到「可能存在的」旧值。secure storage 读取是 async 的，
    // 启动时只能先给默认；首次 reorder 写回时旧值会被覆盖，
    // 实际生效是「下一次 app 启动时正确读回」。
    // 因此这里只返回默认顺序；真正的初始化在 [_load] 里。
    return List<String>.from(kAccountGroupOrderDefault);
  }

  /// 异步从存储读出真实顺序，并在 widget tree 第一次 build 后调一次。
  ///
  /// 整个方法体都必须在 try 里：这是 **fire-and-forget** 调用（provider 里
  /// 不 await），一旦抛出就会变成未捕获的异步异常。而 `flutter_secure_storage`
  /// 在 Android 上确实会抛——Keystore 被系统重置、应用重装、从备份恢复都可能让
  /// `EncryptedSharedPreferences` 解密失败（`java.security.GeneralSecurityException`），
  /// 此时 `read()` 直接抛 `PlatformException`。
  ///
  /// 分组顺序只是 UI 偏好，读不到就退回默认顺序即可，绝不该影响启动。
  Future<void> load() async {
    try {
      final String? raw = await _storage.read(key: _kStorageKey);
      if (raw == null || raw.isEmpty) return;
      final List<String> parsed = (jsonDecode(raw) as List<dynamic>)
          .map((Object? e) => e.toString())
          .toList();
      state = _reconcile(parsed);
    } catch (_) {
      // 读取失败（Keystore 解密失败等）或解析失败（格式 / 类型不对）
      // 都保持默认顺序；下一次 reorder 成功写入时会自动修正存储值。
    }
  }

  /// 页面上只有**部分分组可见**时（空分组不显示）的拖拽落库。
  ///
  /// [visible] 是当前实际渲染出来的分组名序列，[oldIndex] / [newIndex] 是
  /// 它内部的下标（`newIndex` 已由 [SliverReorderableList.onReorderItem] 修正过）。
  /// 内部把它映射回**完整顺序**再持久化，这样隐藏中的分组不会被丢掉。
  Future<void> reorderVisible(
    List<String> visible,
    int oldIndex,
    int newIndex,
  ) async {
    final List<String> next =
        applyVisibleReorder(state, visible, oldIndex, newIndex);
    if (listEquals(next, state)) return;
    state = next;
    await _persist(next);
  }

  /// 纯函数：把 [current] 中 [oldIndex] 处的元素移到 [newIndex] 处。
  ///
  /// 下标语义对齐 [SliverReorderableList.onReorderItem]：`newIndex` 已经是
  /// 「先移除 oldIndex 那一项之后」的目标下标，**调用方不要再做 `-1` 修正**。
  /// （只有已废弃的 `onReorder` 才需要手动 `newIndex -= 1`，
  /// 重复修正会导致往下拖时错位一格。）
  /// 越界下标会被 clamp / 直接返回原顺序，不会抛异常。
  static List<String> applyReorder(
    List<String> current,
    int oldIndex,
    int newIndex,
  ) =>
      _move(current, oldIndex, newIndex);

  /// 纯函数：把「可见序列」里的拖动结果映射回「完整序列」。
  ///
  /// 做法：先在 [visible] 上算出拖动后的可见序列，找到被移动项落到了谁前面，
  /// 再在 [full] 上做同样的「移到该锚点之前」。移动到可见序列末尾时直接追加
  /// 到完整序列末尾。
  ///
  /// **为什么需要它**：页面会隐藏空分组，可见下标与完整下标不再一一对应，
  /// 若直接拿可见下标去改完整数组就会移动错分组。
  ///
  /// 前提：[visible] 必须是 [full] 的**子序列**（保持相对顺序）。页面里
  /// `shown` 由 `order.where(...)` 得到，天然满足。非子序列的输入不在契约内。
  static List<String> applyVisibleReorder(
    List<String> full,
    List<String> visible,
    int oldIndex,
    int newIndex,
  ) {
    if (oldIndex < 0 || oldIndex >= visible.length) {
      return List<String>.from(full);
    }
    // 落点没变 —— 直接当无操作返回。
    //
    // 不能省这一步：下面「落到可见末尾 → 追加到完整末尾」的规则在
    // `visible.length == 1` 时会把这一项真的挪到完整序列末尾
    // （因为 insertAt(0) >= afterMove.length-1(0)），
    // 于是一次本来没有位移的落点（如 0 -> 0）也会悄悄改变隐藏分组的相对位置。
    if (oldIndex == newIndex) {
      return List<String>.from(full);
    }
    final String moved = visible[oldIndex];
    final List<String> afterMove = _move(visible, oldIndex, newIndex);
    final int insertAt = afterMove.indexOf(moved);

    final List<String> next = List<String>.from(full)..remove(moved);
    if (insertAt >= afterMove.length - 1) {
      next.add(moved);
    } else {
      final int at = next.indexOf(afterMove[insertAt + 1]);
      next.insert(at < 0 ? next.length : at, moved);
    }
    return next;
  }

  /// 通用的「取出再插入」：越界不抛异常，返回新列表。
  static List<String> _move(List<String> list, int from, int to) {
    final List<String> next = List<String>.from(list);
    if (from < 0 || from >= next.length) return next;
    final String item = next.removeAt(from);
    next.insert(to.clamp(0, next.length), item);
    return next;
  }

  /// 把顺序重置为默认。调试 / 设置页「恢复默认」时调用。
  Future<void> reset() async {
    state = List<String>.from(kAccountGroupOrderDefault);
    await _persist(kAccountGroupOrderDefault);
  }

  /// 写回存储。失败只会让「下次启动退回默认顺序」，不该向外抛异常
  /// （调用方是拖拽回调 / provider 初始化这类没有错误 UI 的地方）。
  Future<void> _persist(List<String> order) async {
    try {
      await _storage.write(key: _kStorageKey, value: jsonEncode(order));
    } catch (_) {
      // 忽略：见方法注释。
    }
  }

  /// 读到的旧顺序里可能缺新加的默认分组；补到尾部，并过滤掉已废弃的。
  /// 不抛错：即使存储里写了乱七八糟的字符串也只会保留默认里存在的那些。
  static List<String> _reconcile(List<String> parsed) {
    final List<String> result = <String>[];
    for (final String s in parsed) {
      if (kAccountGroupOrderDefault.contains(s) && !result.contains(s)) {
        result.add(s);
      }
    }
    for (final String s in kAccountGroupOrderDefault) {
      if (!result.contains(s)) result.add(s);
    }
    return result;
  }
}

final StateNotifierProvider<AccountGroupOrderNotifier, List<String>>
    accountGroupOrderProvider =
    StateNotifierProvider<AccountGroupOrderNotifier, List<String>>(
  (Ref ref) {
    final AccountGroupOrderNotifier notifier =
        AccountGroupOrderNotifier(const FlutterSecureStorage());
    // fire-and-forget 异步加载真实顺序
    notifier.load();
    return notifier;
  },
);
