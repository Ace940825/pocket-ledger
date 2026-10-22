import '../../../sync/sync_options.dart';

/// 云同步的运行期配置。
///
/// 与 [Env] 的区别：Env 是**编译期**常量（可用 `--dart-define` 注入，
/// 适合打包时整体关闭云功能）；本类是**运行期**由用户在设置页填写并写入
/// Keychain 的配置，改动后立即生效，无需重新打包。
class SyncSettings {
  const SyncSettings({
    this.enabled = false,
    this.mode = SyncMode.auto,
    this.defaultDirection = SyncDirection.merge,
    this.conflictPolicy = ConflictPolicy.auto,
    this.baseUrl = '',
    this.token = '',
  });

  /// 用户是否开启云同步。false 即「关闭（纯本地）」，[mode] 不再生效。
  final bool enabled;

  /// 同步模式：auto 后台自动全量同步；manual 仅手动触发。
  final SyncMode mode;

  /// 手动同步的默认方向（设置页「立即同步」弹窗的初始选择）。
  final SyncDirection defaultDirection;

  /// 冲突处理策略：auto（LWW 时间戳决胜）/ prompt（逐字段选择解决）。
  final ConflictPolicy conflictPolicy;

  /// Workers 端点，如 https://pocket-ledger.xxx.workers.dev
  final String baseUrl;

  /// 访问令牌
  final String token;

  /// 端点与令牌都已填写。缺任一项都无法与服务端通信。
  bool get isConfigured => baseUrl.isNotEmpty && token.isNotEmpty;

  /// 真正可以发起同步
  bool get canSync => enabled && isConfigured;

  /// 未就绪的原因，用于设置页给出可操作的提示而不是干瘪的「同步失败」。
  String? get blockedReason {
    if (!enabled) return '云同步已关闭，当前为纯本地模式';
    if (baseUrl.isEmpty) return '尚未填写同步端点';
    if (token.isEmpty) return '尚未填写访问令牌';
    return null;
  }

  SyncSettings copyWith({
    bool? enabled,
    SyncMode? mode,
    SyncDirection? defaultDirection,
    ConflictPolicy? conflictPolicy,
    String? baseUrl,
    String? token,
  }) {
    return SyncSettings(
      enabled: enabled ?? this.enabled,
      mode: mode ?? this.mode,
      defaultDirection: defaultDirection ?? this.defaultDirection,
      conflictPolicy: conflictPolicy ?? this.conflictPolicy,
      baseUrl: baseUrl ?? this.baseUrl,
      token: token ?? this.token,
    );
  }
}
