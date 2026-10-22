import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/config/env.dart';
import '../../../core/config/secrets.dart';
import '../../../providers/app_providers.dart';
import '../../../sync/sync_options.dart';
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
    final String? modeStored = await storage.read(key: Env.syncModeStorageKey);
    final String? directionStored =
        await storage.read(key: Env.syncDirectionStorageKey);
    final String? conflictPolicyStored =
        await storage.read(key: Env.syncConflictPolicyStorageKey);

    // 内置凭据作为默认值：优先编译期注入（CI --dart-define），其次 gitignored
    // 的 secrets.dart（本地构建）。用户未在设置页手动填时，云同步开箱可用。
    //
    // 迁移：设置页保存任意配置时会把回显的内置端点一并落盘（见 [_persist]），
    // 旧值由此以「用户自定义」的名义驻留 storage，钉死内置端点轮换。
    // 凡存储值命中历史内置名单，视为未自定义，回退到当前内置值。
    final bool baseUrlIsLegacy =
        Env.legacyBuiltInSyncBaseUrls.contains(baseUrlStored);
    final String baseUrl =
        (baseUrlStored?.isNotEmpty == true && !baseUrlIsLegacy)
            ? baseUrlStored!
            : kSyncBaseUrlBuiltIn;
    final String token =
        (tokenStored?.isNotEmpty == true) ? tokenStored! : kSyncTokenBuiltIn;

    // 未显式关闭（stored=='false'）时：若内置凭据齐全则默认开启云同步；
    // 用户已在设置页显式开启/关闭则以存储值为准。
    final bool enabled = enabledStored == 'false'
        ? false
        : (enabledStored == 'true' ? true : (baseUrl.isNotEmpty && token.isNotEmpty));

    final SyncMode mode = SyncMode.values.firstWhere(
      (SyncMode e) => e.name == modeStored,
      orElse: () => SyncMode.auto,
    );
    final SyncDirection defaultDirection = SyncDirection.values.firstWhere(
      (SyncDirection e) => e.name == directionStored,
      orElse: () => SyncDirection.merge,
    );
    final ConflictPolicy conflictPolicy = ConflictPolicy.values.firstWhere(
      (ConflictPolicy e) => e.name == conflictPolicyStored,
      orElse: () => ConflictPolicy.auto,
    );

    return SyncSettings(
      enabled: enabled,
      mode: mode,
      defaultDirection: defaultDirection,
      conflictPolicy: conflictPolicy,
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

  /// 切换同步模式（auto / manual）。
  Future<void> setMode(SyncMode value) async {
    await _persist((_current ?? const SyncSettings()).copyWith(mode: value));
  }

  /// 设置手动同步的默认方向。
  Future<void> setDirection(SyncDirection value) async {
    await _persist(
      (_current ?? const SyncSettings()).copyWith(defaultDirection: value),
    );
  }

  /// 设置冲突处理策略（auto / prompt）。
  Future<void> setConflictPolicy(ConflictPolicy value) async {
    await _persist(
      (_current ?? const SyncSettings()).copyWith(conflictPolicy: value),
    );
  }

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
    // 端点/令牌等于内置值时写空串（= 未自定义），而非把回显值落盘——
    // 否则日后轮换内置端点，旧回显会以「用户自定义」名义驻留 storage
    // 钉死配置（本次修复的根因）。
    await storage.write(
      key: Env.syncBaseUrlStorageKey,
      value: next.baseUrl == kSyncBaseUrlBuiltIn ? '' : next.baseUrl,
    );
    await storage.write(
      key: Env.syncTokenStorageKey,
      value: next.token == kSyncTokenBuiltIn ? '' : next.token,
    );
    await storage.write(key: Env.syncModeStorageKey, value: next.mode.name);
    await storage.write(
      key: Env.syncDirectionStorageKey,
      value: next.defaultDirection.name,
    );
    await storage.write(
      key: Env.syncConflictPolicyStorageKey,
      value: next.conflictPolicy.name,
    );

    state = AsyncData<SyncSettings>(next);
  }
}
