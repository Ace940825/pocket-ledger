/// 应用统一异常体系。
///
/// 分层的目的：让 UI 能针对不同失败给出不同处理
/// （网络失败提示重试，数据库失败属于严重错误需上报）。
abstract class AppFailure implements Exception {
  const AppFailure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// 云端同步失败。用户可以继续离线使用，不影响本地功能。
class SyncFailure extends AppFailure {
  const SyncFailure(super.message, {super.cause});
}

/// 网络不可用
class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, {super.cause});
}

/// 本地数据库失败。属于严重错误。
class DatabaseFailure extends AppFailure {
  const DatabaseFailure(super.message, {super.cause});
}

/// 业务校验失败（如金额为 0、账户不存在）
class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message);
}

/// 未找到目标记录
class NotFoundFailure extends AppFailure {
  const NotFoundFailure(super.message);
}
