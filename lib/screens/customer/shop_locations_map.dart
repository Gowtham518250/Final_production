import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Displays real shop coordinates on an OpenStreetMap layer.
/// Shops without valid coordinates are intentionally not assigned guessed pins.
class ShopLocationsMap extends StatelessWidget {
  const ShopLocationsMap({
    super.key,
    required this.shops,
    this.height = 280,
    this.onShopSelected,
  });

  final List<Map<String, dynamic>> shops;
  final double height;
  final ValueChanged<Map<String, dynamic>>? onShopSelected;

  static List<Map<String, dynamic>> shopsWithCoordinates(
    List<Map<String, dynamic>> shops,
  ) {
    return shops.where((shop) {
      final latitude = _coordinate(shop, const ['latitude', 'shop_latitude']);
      final longitude = _coordinate(shop, const ['longitude', 'shop_longitude']);
      return latitude != null &&
          longitude != null &&
          latitude >= -90 &&
          latitude <= 90 &&
          longitude >= -180 &&
          longitude <= 180;
    }).toList(growable: false);
  }

  static double? _coordinate(Map<String, dynamic> shop, List<String> keys) {
    for (final key in keys) {
      final value = shop[key];
      final parsed = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final located = shopsWithCoordinates(shops);
    if (located.isEmpty) return const SizedBox.shrink();

    final points = located.map((shop) {
      return LatLng(
        _coordinate(shop, const ['latitude', 'shop_latitude'])!,
        _coordinate(shop, const ['longitude', 'shop_longitude'])!,
      );
    }).toList(growable: false);

    final latitude = points.map((point) => point.latitude).reduce((a, b) => a + b) / points.length;
    final longitude = points.map((point) => point.longitude).reduce((a, b) => a + b) / points.length;
    final latSpan = points.map((point) => point.latitude).reduce((a, b) => a > b ? a : b) -
        points.map((point) => point.latitude).reduce((a, b) => a < b ? a : b);
    final lngSpan = points.map((point) => point.longitude).reduce((a, b) => a > b ? a : b) -
        points.map((point) => point.longitude).reduce((a, b) => a < b ? a : b);
    final span = latSpan > lngSpan ? latSpan : lngSpan;
    final zoom = points.length == 1
        ? 15.0
        : span > 1.5
            ? 6.5
            : span > 0.5
                ? 8.5
                : span > 0.15
                    ? 10.5
                    : span > 0.04
                        ? 12.0
                        : 13.5;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(latitude, longitude),
            initialZoom: zoom,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.retailmind.app',
            ),
            MarkerLayer(
              markers: [
                for (var index = 0; index < located.length; index++)
                  Marker(
                    point: points[index],
                    width: 46,
                    height: 54,
                    alignment: Alignment.bottomCenter,
                    child: GestureDetector(
                      onTap: onShopSelected == null
                          ? null
                          : () => onShopSelected!(located[index]),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1D4ED8),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 5,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Icon(Icons.location_on, size: 16, color: Color(0xFF1D4ED8)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('© OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
