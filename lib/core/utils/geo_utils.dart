import 'dart:math' as math;

import 'package:geocoding/geocoding.dart';

import 'amap_geocoder.dart';

/// 地理工具：WGS-84 ⇄ GCJ-02 坐标互转 + 语义化逆地理编码。
///
/// - 定位 SDK（geolocator）给出的是 WGS-84 真实坐标，库内一律存 WGS-84；
/// - 高德瓦片底图用的是 GCJ-02（火星坐标系），小地图展示前必须偏移纠正，
///   否则定位点会相对底图偏移几百米；用户在地图上选的点再转回 WGS-84 落库。

const double _kSemimajorAxis = 6378245.0; // 克拉索夫斯基椭球长半轴
const double _kEccSquared = 0.00669342162296594323; // 第一偏心率平方

/// 是否在中国大陆纠偏范围之外（境外 GCJ-02 无定义，原样返回）。
bool _outOfChina(double lat, double lng) =>
    lng < 72.004 || lng > 137.8347 || lat < 0.8293 || lat > 55.8271;

double _transformLat(double x, double y) {
  double ret = -100.0 +
      2.0 * x +
      3.0 * y +
      0.2 * y * y +
      0.1 * x * y +
      0.2 * math.sqrt(x.abs());
  ret += (20.0 * math.sin(6.0 * x) + 20.0 * math.sin(2.0 * x)) * 2.0 / 3.0;
  ret += (20.0 * math.sin(y * 3.0) + 40.0 * math.sin(y / 3.0)) * 2.0 / 3.0;
  ret += (160.0 * math.sin(y / 12.0) + 320.0 * math.sin(y * math.pi / 30.0)) *
      2.0 /
      3.0;
  return ret;
}

double _transformLng(double x, double y) {
  double ret = 300.0 +
      x +
      2.0 * y +
      0.1 * x * x +
      0.1 * x * y +
      0.1 * math.sqrt(x.abs());
  ret += (20.0 * math.sin(6.0 * x) + 20.0 * math.sin(2.0 * x)) * 2.0 / 3.0;
  ret += (20.0 * math.sin(x * 2.0) + 40.0 * math.sin(x / 3.0)) * 2.0 / 3.0;
  ret += (150.0 * math.sin(x / 12.0) + 300.0 * math.sin(x / 30.0)) * 2.0 / 3.0;
  return ret;
}

(double, double) _offset(double lat, double lng) {
  double dLat = _transformLat(lng - 105.0, lat - 35.0);
  double dLng = _transformLng(lng - 105.0, lat - 35.0);
  final double radLat = lat / 180.0 * math.pi;
  double magic = math.sin(radLat);
  magic = 1 - _kEccSquared * magic * magic;
  final double sqrtMagic = math.sqrt(magic);
  dLat = (dLat * 180.0) /
      ((_kSemimajorAxis * (1 - _kEccSquared)) / (magic * sqrtMagic) * math.pi);
  dLng = (dLng * 180.0) /
      (_kSemimajorAxis / sqrtMagic * math.cos(radLat) * math.pi);
  return (dLat, dLng);
}

/// WGS-84 → GCJ-02。境外坐标原样返回。
(double, double) wgs84ToGcj02(double lat, double lng) {
  if (_outOfChina(lat, lng)) return (lat, lng);
  final (double dLat, double dLng) = _offset(lat, lng);
  return (lat + dLat, lng + dLng);
}

/// GCJ-02 → WGS-84。用「正向偏移反解 + 一轮校正」的近似法，
/// 残差 < 1m，对记账定位场景（POI 级）远超所需精度。境外原样返回。
(double, double) gcj02ToWgs84(double lat, double lng) {
  if (_outOfChina(lat, lng)) return (lat, lng);
  final (double dLat, double dLng) = _offset(lat, lng);
  final double lat1 = lat - dLat;
  final double lng1 = lng - dLng;
  // 一轮校正：对反解结果再算一次正向偏移，把残差补回去。
  final (double dLat2, double dLng2) = _offset(lat1, lng1);
  return (lat - dLat2, lng - dLng2);
}

/// 逆地理编码成**语义化精确地址**（小区名 / 店名 / 门牌级），供位置行展示。
///
/// 解析策略（分层回退）：
/// 1. 优先 [amapReverseGeocode]（高德 Web 逆地理）：国内小区 / 楼栋 / POI
///    级覆盖最好，直接解决「暂无地名」问题；[Env.amapWebKey] 为空或失败
///    时自动跳过。
/// 2. 回退平台原生 [Geocoding]：用 [Placemark.name]（通常即 POI 级地名，
///    如「XX小区」「星巴克咖啡」或楼门牌号）优先，拼上区县前缀保持上下文；
///    [Placemark.name] 缺失或与道路名重复时回退「省市区 + 道路 + 门牌」链。
/// 3. 所有层都失败（无网 / 平台不支持）返回 null，调用方按「仅坐标」兜底。
Future<String?> reverseGeocodeSemantic(
  double latitude,
  double longitude,
) async {
  // 1) 高德（小区级）——失败静默跳过，不阻断后续回退。
  try {
    final String? amap = await amapReverseGeocode(latitude, longitude);
    if (amap != null && amap.isNotEmpty) return amap;
  } catch (_) {
    // 继续走平台原生。
  }
  // 2) 平台原生 geocoding（无 key / 高德失败 / 境外）。
  try {
    final List<Placemark> marks =
        await Geocoding().placemarkFromCoordinates(latitude, longitude);
    if (marks.isEmpty) return null;
    final Placemark m = marks.first;
    final String poi = (m.name ?? '').trim();
    final String road = (m.thoroughfare ?? '').trim();
    final String streetNo = (m.subThoroughfare ?? '').trim();
    final String area = (m.subLocality ?? '').trim(); // 区县
    final String city = (m.locality ?? '').trim(); // 城市
    final String admin = (m.administrativeArea ?? '').trim(); // 省份
    final bool poiUsable = poi.isNotEmpty && poi != road;
    if (poiUsable) {
      final String prefix =
          area.isNotEmpty ? area : (city.isNotEmpty ? city : admin);
      return prefix.isNotEmpty ? '$prefix$poi' : poi;
    }
    final List<String> parts = <String>[
      if (admin.isNotEmpty) admin,
      if (city.isNotEmpty && city != admin) city,
      if (area.isNotEmpty) area,
      if (road.isNotEmpty) road,
      if (streetNo.isNotEmpty && streetNo != road) streetNo,
    ];
    if (parts.isEmpty) return null;
    return parts.join('');
  } catch (_) {
    // 逆地理编码失败：不影响坐标本身，地名留空由调用方兜底。
    return null;
  }
}
