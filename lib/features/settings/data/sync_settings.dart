/// 云同步的运行期配置。
///
/// 与 [Env] 的区别：Env 是**编译期**常量（可用 `--dart-define` 注入，
/// 适合打包时整体关闭云功能）；本类是**运行期**由用户在设置页填写并写入
/// Keychain 的配置，改动后立即生效，无需重新打包。
class SyncSettings {
  const SyncSettings({
    this.enabled = false,
    this.baseUrl = '',
    this.token = '',
  });

  /// 用户是否开启云同步
  final bool enabled;

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

  SyncSettings copyWith({bool? enabled, String? baseUrl, String? token}) {
    return SyncSettings(
      enabled: enabled ?? this.enabled,
      baseUrl: baseUrl ?? this.baseUrl,
      token: token ?? this.token,
    );
  }
}
