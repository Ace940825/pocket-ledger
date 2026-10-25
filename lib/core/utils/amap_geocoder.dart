import 'package:dio/dio.dart';

import '../../core/config/env.dart';
import 'geo_utils.dart' show wgs84ToGcj02;

const String _kAmapRegeoBase = 'https://restapi.amap.com/v3/geocode/regeo';

/// 从 AMap 逆地理返回里安全读取「名称」字段。
///
/// 不同版本响应里 neighborhood / building 可能是 [String] 也可能是
/// 含 `name` 的 [Map]，这里统一兜底，避免解析崩溃。
String _readName(Object? value) {
  if (value == null) return '';
  if (value is String) return value.trim();
  if (value is Map<Object?, Object?>) {
    final Object? name = value['name'];
    return name is String ? name.trim() : '';
  }
  return '';
}

/// 高德 Web 逆地理编码：输入 WGS-84，内部转 GCJ-02 请求，返回小区 / 楼栋级地名。
///
/// 高德在国内对「小区 / 楼栋 / 门牌」级 POI 覆盖远优于平台原生 CLGeocoder /
/// Geocoder，是工程「暂时无法展示小区名」的直接解法。
///
/// 参数：
/// - [latWgs] / [lngWgs]：库内 WGS-84 坐标（落库口径，与 App 全局一致）。
/// - [apiKey]：可选，覆盖 [Env.amapWebKey]（便于测试注入）。
/// - [dio]：可选，便于测试注入 mock 客户端。
///
/// 返回拼好的「区县 + 小区·楼栋·周边POI」层级地名；[key] 为空、网络失败、
/// 或高德返回非成功态时返回 null，由调用方回退平台原生逆地理（无 key 不崩）。
Future<String?> amapReverseGeocode(
  double latWgs,
  double lngWgs, {
  String? apiKey,
  Dio? dio,
}) async {
  final String key = apiKey ?? Env.amapWebKey;
  if (key.isEmpty) return null;

  // 高德收 GCJ-02：库内 WGS-84 先纠偏再请求。
  final (double glat, double glng) = wgs84ToGcj02(latWgs, lngWgs);
  final Dio client = dio ?? Dio();
  try {
    final Response<dynamic> resp = await client
        .get<dynamic>(_kAmapRegeoBase, queryParameters: <String, dynamic>{
      'location': '$glng,$glat', // 高德要求 lng,lat 顺序
      'key': key,
      'radius': 1000,
      'extensions': 'all',
      'roadlevel': 0,
    });
    final Map<String, dynamic> data = resp.data as Map<String, dynamic>;
    if (data['status'] != '1') return null; // 高德非成功态（如 key 无效 / 超限）
    final Map<String, dynamic> re = data['regeocode'] as Map<String, dynamic>;
    final Map<String, dynamic> ac =
        re['addressComponent'] as Map<String, dynamic>;

    final String nb = _readName(ac['neighborhood']);
    final String bld = _readName(ac['building']);
    final String district = (ac['district'] as String? ?? '').trim();
    final String township = (ac['township'] as String? ?? '').trim();

    final List<dynamic> pois = re['pois'] as List<dynamic>? ?? <dynamic>[];
    final String poi =
        pois.isNotEmpty ? (pois.first['name'] as String? ?? '') : '';

    final String poiName =
        <String>[nb, bld, poi].where((String s) => s.isNotEmpty).join('·');
    if (poiName.isEmpty) {
      // 连 POI 都没有：退回高德格式化地址兜底。
      final String? formatted = re['formatted_address'] as String?;
      return formatted?.trim().isNotEmpty == true ? formatted!.trim() : null;
    }
    final String prefix = district.isNotEmpty ? district : township;
    return prefix.isNotEmpty ? '$prefix$poiName' : poiName;
  } catch (_) {
    // 网络异常 / 解析异常：交回平台原生逆地理，不影响坐标落库。
    return null;
  }
}
