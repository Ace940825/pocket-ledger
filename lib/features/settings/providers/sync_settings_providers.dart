import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/config/env.dart';
import '../../../providers/app_providers.dart';
import '../data/sync_settings.dart';

/// 云同步设置。
///
/// 端点与令牌属于凭据，一律存 Keychain / Keystore，不进数据库也不进 SharedPreferences。
///
/// 刻意**不用 autoDispose**：[syncAdapterProvider] 是非 autoDispose 的 Provider，
/// 而 Riverpod 不允许「长生命周期 provider 依赖 autoDispose provider」——
/// 那会导致配置在设置页关闭后被回收，同步引擎跟着退化成离线模式。
final AsyncNotifierProvider<SyncSettingsController, SyncSettings>
    syncSettingsProvider =
    AsyncNotifierProvider<SyncSettingsController, SyncSettings>(
  SyncSettingsController.new,
);

class SyncSettingsController extends AsyncNotifier<SyncSettings> {
  @override
  Future<SyncSettings> build() async {
    final FlutterSecureStorage storage = ref.watch(secureStorageProvider);

    final String? enabled = await storage.read(key: Env.syncEnabledStorageKey);
    final String? baseUrl = await storage.read(key: Env.syncBaseUrlStorageKey);
    final String? token = await storage.read(key: Env.syncTokenStorageKey);

    return SyncSettings(
      enabled: enabled == 'true',
      baseUrl: baseUrl ?? '',
      token: token ?? '',
    );
  }

  /// 开关云同步
  Future<void> setEnabled(bool value) async {
    await _persist((_current ?? const SyncSettings()).copyWith(enabled: value));
  }

  /// 保存端点与令牌。自动 trim，避免首尾空格导致 URL 解析失败。
  Future<void> save({required String baseUrl, required String token}) async {
    await _persist(
      (_current ?? const SyncSettings()).copyWith(
        baseUrl: baseUrl.trim(),
        token: token.trim(),
      ),
    );
  }

  SyncSettings? get _current => state.value;

  /// 先落盘再更新内存状态。
  ///
  /// 顺序很重要：若先改 state，写入失败时 UI 会显示一个并未生效的配置，
  /// 用户以为已保存，重启后却回到旧值。
  Future<void> _persist(SyncSettings next) async {
    final FlutterSecureStorage storage = ref.read(secureStorageProvider);

    await storage.write(
      key: Env.syncEnabledStorageKey,
      value: next.enabled.toString(),
    );
    await storage.write(key: Env.syncBaseUrlStorageKey, value: next.baseUrl);
    await storage.write(key: Env.syncTokenStorageKey, value: next.token);

    state = AsyncData<SyncSettings>(next);
  }
}
