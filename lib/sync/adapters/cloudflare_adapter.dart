import 'package:dio/dio.dart';
import 'package:retry/retry.dart';

import '../../core/config/env.dart';
import '../../core/errors/failures.dart';
import '../sync_adapter.dart';

/// Cloudflare D1 + Workers + R2 同步适配器（默认方案）。
///
/// 为什么选 Cloudflare：
/// - 免费层是官方长期策略，永久 $0，不需要信用卡
/// - **不会因闲置暂停**（Supabase 免费层 7 天无流量会暂停）
/// - R2 零出网流量费
/// - 个人记账用量约为免费额度的 0.01%
class CloudflareAdapter implements SyncAdapter {
  CloudflareAdapter({
    String? baseUrl,
    String? token,
    Dio? dio,
  })  : _baseUrl = baseUrl ?? Env.syncBaseUrl,
        _token = token ?? Env.syncToken,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? Env.syncBaseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 20),
                headers: <String, Object?>{
                  'Authorization': 'Bearer ${token ?? Env.syncToken}',
                  'Content-Type': 'application/json',
                },
              ),
            );

  final String _baseUrl;
  final String _token;
  final Dio _dio;

  @override
  String get name => 'Cloudflare D1';

  @override
  Future<bool> isAvailable() async {
    // 占位端点：说明用户还没在设置页填入自己的 Workers 地址
    if (_baseUrl.contains('example.workers.dev')) return false;
    // 令牌为空时服务端必然拒绝，不如本地直接判定不可用，
    // 免得每次同步都打一次注定失败的网络请求。
    if (_token.isEmpty) return false;
    return true;
  }

  @override
  Future<PullResult> pull({
    required String deviceId,
    required int since,
    String afterId = '',
    int limit = 500,
  }) async {
    return _withRetry(() async {
      try {
        final Response<Map<String, dynamic>> response =
            await _dio.get<Map<String, dynamic>>(
          '/api/sync/pull',
          queryParameters: <String, Object?>{
            'since': since,
            if (afterId.isNotEmpty) 'afterId': afterId,
            'limit': limit,
            'device': deviceId,
          },
        );

        final Map<String, dynamic> data = response.data ?? <String, dynamic>{};
        final List<Object?> raw =
            (data['records'] as List<Object?>?) ?? <Object?>[];
        final List<RemoteRecord> records = raw
            .whereType<Map<String, Object?>>()
            .map(RemoteRecord.fromJson)
            .toList(growable: false);

        return PullResult(
          records: records,
          serverTime: (data['serverTime'] as int?) ??
              DateTime.now().toUtc().millisecondsSinceEpoch,
        );
      } on DioException catch (e) {
        throw NetworkFailure('拉取云端数据失败：${e.message}', cause: e);
      }
    });
  }

  @override
  Future<PushResult> push({
    required String deviceId,
    required List<SyncOp> ops,
  }) async {
    if (ops.isEmpty) {
      return const PushResult(
        appliedIds: <String>[],
        conflictedIds: <String>[],
      );
    }

    return _withRetry(() async {
      try {
        final Response<Map<String, dynamic>> response =
            await _dio.post<Map<String, dynamic>>(
          '/api/sync/push',
          data: <String, Object?>{
            'device': deviceId,
            'ops': ops
                .map((SyncOp op) => op.toJson())
                .toList(growable: false),
          },
        );

        final Map<String, dynamic> data = response.data ?? <String, dynamic>{};
        return PushResult(
          appliedIds: _toStringList(data['appliedIds']),
          conflictedIds: _toStringList(data['conflictedIds']),
        );
      } on DioException catch (e) {
        throw NetworkFailure('推送本地变更失败：${e.message}', cause: e);
      }
    });
  }

  @override
  Future<String> uploadFile(String localPath, {String? remoteKey}) async {
    return _withRetry(() async {
      try {
        final FormData formData = FormData.fromMap(<String, Object?>{
          'file': await MultipartFile.fromFile(localPath),
          if (remoteKey != null) 'key': remoteKey,
        });

        final Response<Map<String, dynamic>> response =
            await _dio.post<Map<String, dynamic>>(
          '/api/upload',
          data: formData,
        );

        final String? url = response.data?['url'] as String?;
        if (url == null) {
          throw const SyncFailure('上传成功但服务端未返回文件地址');
        }
        return url;
      } on DioException catch (e) {
        throw NetworkFailure('上传文件失败：${e.message}', cause: e);
      }
    });
  }

  /// 指数退避重试。网络抖动时避免立即失败。
  Future<T> _withRetry<T>(Future<T> Function() action) {
    return retry(
      action,
      maxAttempts: Env.syncMaxRetries,
      delayFactor: const Duration(milliseconds: 500),
      retryIf: (Exception e) => e is NetworkFailure || e is DioException,
    );
  }

  List<String> _toStringList(Object? value) {
    if (value is! List<Object?>) return const <String>[];
    return value.whereType<String>().toList(growable: false);
  }
}
