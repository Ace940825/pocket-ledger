import '../../core/errors/failures.dart';
import '../sync_adapter.dart';

/// 纯本地适配器 —— 不做任何网络请求。
///
/// 这是"后期维护免费"的最终兜底：
/// 即使云端服务不可用、收费或关闭，应用依然是功能完整的本地记账工具。
/// 设置页可一键切换到此模式。
class OfflineAdapter implements SyncAdapter {
  const OfflineAdapter();

  @override
  String get name => '纯本地';

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<PullResult> pull({
    required String deviceId,
    required int since,
    String afterId = '',
    int limit = 500,
  }) async {
    throw const SyncFailure('当前为纯本地模式，未启用云同步');
  }

  @override
  Future<PushResult> push({
    required String deviceId,
    required List<SyncOp> ops,
  }) async {
    throw const SyncFailure('当前为纯本地模式，未启用云同步');
  }

  @override
  Future<String> uploadFile(String localPath, {String? remoteKey}) async {
    throw const SyncFailure('当前为纯本地模式，无法上传文件');
  }
}
