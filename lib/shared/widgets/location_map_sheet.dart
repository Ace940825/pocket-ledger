import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:pocket_ledger/core/theme/forest_design_tokens.dart';

import '../../core/utils/amap_geocoder.dart';
import '../../core/utils/geo_utils.dart';
import '../../theme/app_dimens.dart';
import 'line_icon_map.dart';
import 'line_icons.dart';

/// 小地图选点结果：落库用 WGS-84 坐标 + 语义化地名。
class LocationPickResult {
  const LocationPickResult({
    required this.latitude,
    required this.longitude,
    this.placeName,
  });

  final double latitude;
  final double longitude;
  final String? placeName;
}

/// 弹出小地图浮层：拖动地图 / 点选位置取点（中心定位针跟随地图中心），
/// 确认返回 [LocationPickResult]；取消返回 null。
///
/// 底图为高德瓦片（GCJ-02 坐标系，中国大陆可直连）：展示前把库内 WGS-84
/// 纠偏成 GCJ-02；用户选点后把 GCJ-02 反解回 WGS-84 落库，坐标存取口径不变。
Future<LocationPickResult?> showLocationMapSheet(
  BuildContext context, {
  required double latitude,
  required double longitude,
  String? placeName,
}) {
  return showDialog<LocationPickResult>(
    context: context,
    builder: (BuildContext context) => _LocationMapDialog(
      initialLat: latitude,
      initialLng: longitude,
      initialPlace: placeName,
    ),
  );
}

class _LocationMapDialog extends StatefulWidget {
  const _LocationMapDialog({
    required this.initialLat,
    required this.initialLng,
    this.initialPlace,
  });

  final double initialLat;
  final double initialLng;
  final String? initialPlace;

  @override
  State<_LocationMapDialog> createState() => _LocationMapDialogState();
}

class _LocationMapDialogState extends State<_LocationMapDialog> {
  final MapController _mapController = MapController();

  /// 当前选点（WGS-84，落库口径）。初始为原流水坐标。
  (double, double) _picked = (0, 0);
  String? _placeName;
  bool _naming = false;

  /// 最近一次 GPS 定位精度（米），用于绘制精度圈；用户拖动地图后清空。
  double? _accuracy;

  bool _locating = false;

  /// 附近 POI 列表（餐饮 / 购物类）。
  List<AmapPoiItem> _nearbyPois = <AmapPoiItem>[];
  bool _loadingPois = false;

  static const double _kZoom = 17;

  @override
  void initState() {
    super.initState();
    _picked = (widget.initialLat, widget.initialLng);
    _placeName = widget.initialPlace;
    // 打开小地图时自动定位到当前 GPS 位置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _locateMe();
    });
  }

  /// 库内 WGS-84 → 高德瓦片 GCJ-02 展示坐标。
  LatLng get _displayCenter {
    final (double lat, double lng) = wgs84ToGcj02(_picked.$1, _picked.$2);
    return LatLng(lat, lng);
  }

  /// 地图事件统一收口：拖动结束 / 惯性滑动结束 / 点选居中都携带最新相机，
  /// 把当前地图中心（GCJ-02）反解回 WGS-84 作为选点，并触发逆地理编码。
  void _onMapEvent(MapEvent event) {
    final LatLng center = event.camera.center;
    final (double lat, double lng) =
        gcj02ToWgs84(center.latitude, center.longitude);
    const double eps = 1e-9;
    final bool changed =
        (lat - _picked.$1).abs() > eps || (lng - _picked.$2).abs() > eps;
    if (!changed) return;
    // 用户移动了地图 → 选点已脱离「我的位置」精度圈，清空精度圈。
    setState(() {
      _picked = (lat, lng);
      _accuracy = null;
    });
    _resolveName();
  }

  /// 定位到当前 GPS 位置：高精度获取后作为选点，并绘制精度圈 + 逆地理编码。
  Future<void> _locateMe() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted) return;
      setState(() {
        _picked = (pos.latitude, pos.longitude);
        _accuracy = pos.accuracy;
      });
      // 地图居中到当前位置（GCJ-02 展示坐标）。
      _mapController.move(_displayCenter, _mapController.camera.zoom);
      await _resolveName();
      // 定位成功后自动获取附近 POI 列表
      await _loadNearbyPois();
    } catch (_) {
      // 定位失败（权限 / 超时 / 无 GPS）：保留用户当前选点，不阻断。
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// 获取附近 POI 列表（餐饮 / 购物类，500m 范围内）。
  Future<void> _loadNearbyPois() async {
    if (_loadingPois) return;
    setState(() => _loadingPois = true);
    try {
      final List<AmapPoiItem> pois = await amapSearchNearbyPois(
        _picked.$1,
        _picked.$2,
        radius: 500,
      );
      if (!mounted) return;
      setState(() {
        _nearbyPois = pois;
        _loadingPois = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPois = false);
    }
  }

  Future<void> _resolveName() async {
    setState(() => _naming = true);
    final String? name = await reverseGeocodeSemantic(_picked.$1, _picked.$2);
    if (!mounted) return;
    setState(() {
      _placeName = name;
      _naming = false;
    });
  }

  void _confirm() {
    Navigator.of(context).pop(
      LocationPickResult(
        latitude: _picked.$1,
        longitude: _picked.$2,
        placeName: _placeName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: context.forest.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '调整位置',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.forest.onSurface,
              ),
            ),
            const SizedBox(height: AppDimens.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimens.radiusCard - 4),
              child: SizedBox(
                height: 340,
                child: Stack(
                  children: <Widget>[
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _displayCenter,
                        initialZoom: _kZoom,
                        minZoom: 3,
                        maxZoom: 18,
                        onMapEvent: _onMapEvent,
                        // 点选地图：把点居中到定位针下（保留当前缩放级别）。
                        onTap: (_, LatLng tapPos) => _mapController.move(
                            tapPos, _mapController.camera.zoom,),
                      ),
                      children: <Widget>[
                        TileLayer(
                          urlTemplate: 'https://webrd0{s}.is.autonavi.com'
                              '/appmaptile?lang=zh_cn&size=1&scale=1'
                              '&style=8&x={x}&y={y}&z={z}',
                          subdomains: const <String>['1', '2', '3', '4'],
                          userAgentPackageName: 'pocket_ledger',
                          // 瓦片加载失败静默留白：无网时灰底仍可拖动选点。
                          errorTileCallback: (
                            TileImage tile,
                            Object error,
                            StackTrace? stackTrace,
                          ) {},
                        ),
                        // GPS 精度圈：仅在高精度定位成功后显示，用户拖动即消失。
                        if (_accuracy != null)
                          CircleLayer(
                            circles: <CircleMarker>[
                              CircleMarker(
                                point: _displayCenter,
                                radius: _accuracy!,
                                useRadiusInMeter: true,
                                color: context.forest.primary.withValues(alpha: 0.15),
                                borderStrokeWidth: 1,
                                borderColor: context.forest.primary,
                              ),
                            ],
                          ),
                      ],
                    ),
                    // 右上角「定位到当前位置」按钮：高精度 GPS 获取并居中。
                    Positioned(
                      top: 8,
                      right: 8,
                      child: FloatingActionButton.small(
                        heroTag: 'locate_me',
                        tooltip: '定位到当前位置',
                        backgroundColor: context.forest.surface,
                        foregroundColor: context.forest.primary,
                        onPressed: _locating ? null : _locateMe,
                        child: _locating
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: context.forest.primary,
                                ),
                              )
                            : const Icon(Icons.my_location),
                      ),
                    ),
                    // 中心定位针：固定在地图几何中心，拖动地图即移动选点。
                    // 上方 28px 让针尖（图标底部）对准几何中心。
                    IgnorePointer(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const SizedBox(height: 28),
                            LineGlyph(
                              Icons.location_on_rounded,
                              size: 36,
                              color: context.forest.primary,
                              semanticLabel: '当前选点',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimens.sm),
            // 附近 POI 列表（横向滚动），点击可快速选择店名
            if (_loadingPois)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimens.sm),
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_nearbyPois.isNotEmpty)
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _nearbyPois.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppDimens.sm),
                  itemBuilder: (BuildContext context, int index) {
                    final AmapPoiItem poi = _nearbyPois[index];
                    return ActionChip(
                      label: Text(
                        poi.name,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () {
                        setState(() {
                          _picked = (poi.latitude, poi.longitude);
                          _placeName = poi.name;
                          _accuracy = null; // 选择了 POI，清空精度圈
                        });
                        _mapController.move(_displayCenter, _mapController.camera.zoom);
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: AppDimens.sm),
            // 选点结果：语义化地址（逆地理编码中显示加载态）。
            Row(
              children: <Widget>[
                if (_naming)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.forest.primary,
                    ),
                  )
                else
                  LineIcon(
                    LineIconKind.location,
                    size: 14,
                    color: context.forest.primary,
                  ),
                const SizedBox(width: AppDimens.xs),
                Expanded(
                  child: Text(
                    _naming ? '正在解析地址…' : (_placeName ?? '已选坐标（暂无地名）'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: context.forest.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    '取消',
                    style: TextStyle(color: context.forest.onSurfaceVariant),
                  ),
                ),
                const SizedBox(width: AppDimens.sm),
                FilledButton(
                  onPressed: _confirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: context.forest.primary,
                    foregroundColor: context.forest.onPrimary,
                  ),
                  child: const Text('用此位置'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
