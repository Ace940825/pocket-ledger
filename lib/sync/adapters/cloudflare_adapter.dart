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
    int? until,
    List<String>? tables,
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
            if (until != null) 'until': until,
            if (tables != null && tables.isNotEmpty) 'tables': tables.join(','),
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
        throw NetworkFailure(_friendlyNetworkError('拉取云端数据', e), cause: e);
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
            'ops': ops.map((SyncOp op) => op.toJson()).toList(growable: false),
          },
        );

        final Map<String, dynamic> data = response.data ?? <String, dynamic>{};
        return PushResult(
          appliedIds: _toStringList(data['appliedIds']),
          conflictedIds: _toStringList(data['conflictedIds']),
        );
      } on DioException catch (e) {
        throw NetworkFailure(_friendlyNetworkError('推送本地变更', e), cause: e);
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
        throw NetworkFailure(_friendlyNetworkError('上传文件', e), cause: e);
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

  /// 把 Dio 异常翻译成**可行动**的中文提示（原始 e.message 是开发向英文长文，
  /// 如 "The request connection took longer than 0:00:10..."，用户无从下手）。
  ///
  /// 重点：`*.workers.dev` 在中国大陆普遍被 DNS 阻断/污染，典型表现就是
  /// 连接超时（10s 内 TCP 都握不上手）。换网络偶尔能通，稳定解法是给
  /// Worker 绑定自有域名后更新端点。
  String _friendlyNetworkError(String action, DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '$action失败：连接云端超时。设备连不上 Workers 端点——'
            '*.workers.dev 域名在中国大陆常被网络阻断，建议换 Wi-Fi/蜂窝网络'
            '重试，或在 Cloudflare 给 Worker 绑定自有域名后更新端点。';
      case DioExceptionType.connectionError:
        return '$action失败：无法连接云端。请检查端点地址拼写与当前网络；'
            '*.workers.dev 在中国大陆常被阻断，可绑定自有域名解决。';
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return '$action失败：云端响应超时，请稍后重试。';
      case DioExceptionType.badCertificate:
        return '$action失败：HTTPS 证书校验未通过，请确认端点未被劫持。';
      case DioExceptionType.cancel:
        return '$action已取消。';
      case DioExceptionType.badResponse:
        final int? code = e.response?.statusCode;
        final String hint = (code == 401 || code == 403)
            ? '（令牌无效或已过期，请到设置页重新保存访问令牌）'
            : '';
        return '$action失败：云端返回 HTTP $code$hint。';
      case DioExceptionType.unknown:
        final String detail = e.error?.toString() ?? '未知网络错误';
        return '$action失败：$detail';
    }
  }

  List<String> _toStringList(Object? value) {
    if (value is! List<Object?>) return const <String>[];
    return value.whereType<String>().toList(growable: false);
  }
}
