import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/config/env.dart';
import '../../../core/config/secrets.dart';
import '../../../providers/app_providers.dart';
import '../data/sync_settings.dart';

/// 内置同步凭据：优先取编译期 --dart-define（CI 云端分发注入），
/// 取不到时回退到 gitignored 的 [builtInSyncBaseUrl] / [builtInSyncToken]
/// （本地构建用）。二者任一为空即视为未配置，云同步默认不开启。
const String kSyncBaseUrlBuiltIn = String.fromEnvironment(
  'SYNC_BASE_URL',
  defaultValue: builtInSyncBaseUrl,
);
const String kSyncTokenBuiltIn = String.fromEnvironment(
  'SYNC_TOKEN',
  defaultValue: builtInSyncToken,
);

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

    final String? enabledStored =
        await storage.read(key: Env.syncEnabledStorageKey);
    final String? baseUrlStored =
        await storage.read(key: Env.syncBaseUrlStorageKey);
    final String? tokenStored =
        await storage.read(key: Env.syncTokenStorageKey);

    // 内置凭据作为默认值：优先编译期注入（CI --dart-define），其次 gitignored
    // 的 secrets.dart（本地构建）。用户未在设置页手动填时，云同步开箱可用。
    final String baseUrl =
        (baseUrlStored?.isNotEmpty == true) ? baseUrlStored! : kSyncBaseUrlBuiltIn;
    final String token =
        (tokenStored?.isNotEmpty == true) ? tokenStored! : kSyncTokenBuiltIn;

    // 未显式关闭（stored=='false'）时：若内置凭据齐全则默认开启云同步；
    // 用户已在设置页显式开启/关闭则以存储值为准。
    final bool enabled = enabledStored == 'false'
        ? false
        : (enabledStored == 'true' ? true : (baseUrl.isNotEmpty && token.isNotEmpty));

    return SyncSettings(
      enabled: enabled,
      baseUrl: baseUrl,
      token: token,
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
