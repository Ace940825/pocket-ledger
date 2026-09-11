import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String _kCollapseKey = 'account_group_collapsed';

/// 账户分组的折叠状态持久化。
///
/// 状态是 `分组名 -> 是否折叠` 的映射；默认（映射里没有的）都是**展开**。
/// 这样新加的分组天然就是展开的，不用改这儿的默认值。
///
/// 与 [AccountGroupOrderNotifier] 同一套思路：分组偏好只是 UI 状态，
/// secure storage 读不到（Android Keystore 被重置 / 重装 / 恢复备份时会触发
/// `FlutterSecureStorage` 解密失败）就退回默认（全部展开），绝不该影响启动或抛未捕获异常。
class AccountGroupCollapseNotifier extends StateNotifier<Map<String, bool>> {
  AccountGroupCollapseNotifier(this._storage) : super(<String, bool>{});

  final FlutterSecureStorage _storage;

  /// 异步从存储读出真实折叠状态，并在 widget tree 第一次 build 后调一次。
  ///
  /// 整个方法体都必须在 try 里：这是 **fire-and-forget** 调用（provider 里
  /// 不 await），一旦抛出就会变成未捕获的异步异常。`FlutterSecureStorage` 在
  /// Android 上确实会抛，所以读失败就保持默认（全部展开）。
  Future<void> load() async {
    try {
      final String? raw = await _storage.read(key: _kCollapseKey);
      if (raw == null || raw.isEmpty) return;
      final Map<String, Object?> parsed =
          (jsonDecode(raw) as Map<String, Object?>).cast<String, Object?>();
      state = <String, bool>{
        for (final MapEntry<String, Object?> e in parsed.entries)
          e.key: e.value == true,
      };
    } catch (_) {
      // 读取 / 解析失败都保持默认（全部展开）。
    }
  }

  /// 某个分组是否处于折叠状态（映射里缺失 = 展开 = false）。
  bool isCollapsed(String name) => state[name] ?? false;

  /// 切换某分组的折叠状态并落库。
  Future<void> toggle(String name) async {
    final Map<String, bool> next = Map<String, bool>.from(state);
    next[name] = !(next[name] ?? false);
    state = next;
    await _persist(next);
  }

  /// 显式设置某分组的折叠状态并落库（如「全部展开」入口）。
  Future<void> setCollapsed(String name, bool collapsed) async {
    if (isCollapsed(name) == collapsed) return;
    final Map<String, bool> next = Map<String, bool>.from(state);
    next[name] = collapsed;
    state = next;
    await _persist(next);
  }

  /// 写回存储。失败只会让「下次启动退回默认（全部展开）」，不该向外抛异常
  /// （调用方是折叠回调这类没有错误 UI 的地方）。
  Future<void> _persist(Map<String, bool> collapsed) async {
    try {
      await _storage.write(key: _kCollapseKey, value: jsonEncode(collapsed));
    } catch (_) {
      // 忽略：见方法注释。
    }
  }
}

final StateNotifierProvider<AccountGroupCollapseNotifier, Map<String, bool>>
    accountGroupCollapsedProvider =
    StateNotifierProvider<AccountGroupCollapseNotifier, Map<String, bool>>(
  (Ref ref) {
    final AccountGroupCollapseNotifier notifier =
        AccountGroupCollapseNotifier(const FlutterSecureStorage());
    // fire-and-forget 异步加载真实折叠状态
    notifier.load();
    return notifier;
  },
);
