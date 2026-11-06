import '../../live_translated_text.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'shop_locations_map.dart';
import '../../api_client.dart';
import 'dart:convert';
import '../../visual_widgets.dart';

class NearbyShopsPage extends StatefulWidget {
  const NearbyShopsPage({super.key});

  @override
  State<NearbyShopsPage> createState() => _NearbyShopsPageState();
}

class _NearbyShopsPageState extends State<NearbyShopsPage> {
  bool _isLoading = true;
  Position? _currentPosition;
  String _errorMessage = '';
  IconData _errorIcon = Icons.error_outline;

  // Real list of shops from Firestore
  List<Map<String, dynamic>> _realShops = [];

  @override
  void initState() {
    super.initState();
    _fetchLocationAndShops();
  }

  Future<void> _fetchLocationAndShops() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Location services are disabled. Please enable them to find nearby shops.';
          _errorIcon = Icons.location_off;
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Location permissions are denied. Please allow location access.';
            _errorIcon = Icons.location_disabled;
            _isLoading = false;
          });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permissions are permanently denied. Please enable them in app settings.';
          _errorIcon = Icons.location_off;
          _isLoading = false;
        });
        return;
      } 

      // Get current location
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // Fetch nearby shops from backend
      final response = await ApiClient.getJson('/store/shops/nearby?lat=${_currentPosition!.latitude}&lng=${_currentPosition!.longitude}&radius_km=10');
      
      final List<Map<String, dynamic>> loadedShops = [];

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        // The API contract is {shops: [...], count: n}; accept a raw list too
        // for compatibility with older deployments during rollout.
        final rawShops = decoded is Map && decoded['shops'] is List
            ? decoded['shops'] as List
            : decoded is List
                ? decoded
                : const <dynamic>[];
        for (final rawShop in rawShops.whereType<Map>()) {
          final shop = Map<String, dynamic>.from(rawShop);
          final distanceKm = double.tryParse(shop['distance_km']?.toString() ?? '') ?? 0;
          loadedShops.add({
            ...shop,
            'id': shop['shop_id']?.toString() ?? '',
            'name': shop['shop_name']?.toString() ?? 'Shop',
            'distance': '${distanceKm.toStringAsFixed(1)} km',
            'rating': shop['rating']?.toString() ?? 'New',
            'tags': shop['tags'] ?? shop['categories'] ?? const ['Groceries', 'Online'],
            'address': shop['address'] ?? '',
            'phone': shop['phone'] ?? '',
            'is_online': shop['is_online'] ?? true,
          });
        }
      } else if (response.statusCode == 404) {
        // No shops found - this is not an error, just empty result
        setState(() {
          _realShops = [];
          _isLoading = false;
        });
        return;
      }
      
      setState(() {
        _realShops = loadedShops;
        _isLoading = false;
      });
      
    } catch (e) {
      // Distinguish between location errors and API errors
      String errorMsg = 'Failed to fetch shops';
      IconData errorIcon = Icons.error_outline;
      
      if (e.toString().contains('Location') || e.toString().contains('GPS')) {
        errorMsg = 'Unable to get your location. Please ensure GPS is enabled.';
        errorIcon = Icons.location_disabled;
      } else if (e.toString().contains('Network') || e.toString().contains('Socket') || e.toString().contains('Connection')) {
        errorMsg = 'Network error. Please check your internet connection.';
        errorIcon = Icons.wifi_off;
      } else if (e.toString().contains('Permission') || e.toString().contains('denied')) {
        errorMsg = 'Location permission denied. Please allow location access.';
        errorIcon = Icons.location_disabled;
      } else {
        errorMsg = 'Something went wrong. Please try again.';
        errorIcon = Icons.refresh;
      }
      
      setState(() {
        _errorMessage = errorMsg;
        _errorIcon = errorIcon;
        _isLoading = false;
      });
      
      // Log the actual error for debugging
      debugPrint('Nearby shops error: $e');
      
      // Marketplace visibility is backend-controlled. Never show synthetic
      // shops after a network error because that could make a non-enabled shop
      // appear orderable.
      if (mounted) {
        setState(() {
          _realShops = [];
          _isLoading = false;
        });
      }
    }
  }

  String _shopAddress(Map<String, dynamic> shop) {
    final values = <String>[
      for (final key in const [
        'address_line1', 'address_line2', 'address', 'location', 'city', 'state', 'postal_code',
      ])
        if ((shop[key]?.toString().trim() ?? '').isNotEmpty)
          shop[key].toString().trim(),
    ];
    final seen = <String>{};
    return values.where((value) => seen.add(value.toLowerCase())).join(', ');
  }

  Future<void> _openShopDirections(Map<String, dynamic> shop) async {
    final latitude = double.tryParse(
      (shop['latitude'] ?? shop['shop_latitude'] ?? '').toString(),
    );
    final longitude = double.tryParse(
      (shop['longitude'] ?? shop['shop_longitude'] ?? '').toString(),
    );
    final address = _shopAddress(shop);
    if ((latitude == null || longitude == null) && address.isEmpty) return;

    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': latitude != null && longitude != null
          ? '$latitude,$longitude'
          : address,
      'travelmode': 'driving',
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: LiveTranslatedText('Nearby Shops', style: TextStyle(color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoading 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  LiveTranslatedText(
                    'Finding nearby shops...',
                    style: TextStyle(color: textColor),
                  ),
                ],
              ),
            )
        : _errorMessage.isNotEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_errorIcon, size: 64, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    LiveTranslatedText(_errorMessage, style: TextStyle(color: textColor), textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() { _isLoading = true; _errorMessage = ''; });
                        _fetchLocationAndShops();
                      },
                      child: const LiveTranslatedText('Try Again'),
                    )
                  ],
                ),
              ),
            )
            : RefreshIndicator(
              onRefresh: _fetchLocationAndShops,
              color: AppColors.primary,
              child: _realShops.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 100),
                        Center(
                          child: LiveTranslatedText(
                            'No registered shops found nearby.\nCheck back later!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: subTextColor, fontSize: 16),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _realShops.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (ShopLocationsMap.shopsWithCoordinates(_realShops).isNotEmpty) ...[
                                  const LiveTranslatedText(
                                    'Nearby shop locations',
                                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 10),
                                  ShopLocationsMap(
                                    shops: _realShops,
                                    height: 300,
                                    onShopSelected: _openShopDirections,
                                  ),
                                  const SizedBox(height: 8),
                                  LiveTranslatedText(
                                    'Tap a numbered pin to open directions to that shop.',
                                    style: TextStyle(fontSize: 11, color: subTextColor),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }
                        final shop = _realShops[index - 1];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: GestureDetector(
                            onTap: () {
                              // Navigate to shop storefront
                              Navigator.pushNamed(context, '/customer-home', arguments: shop['id']);
                            },
                            child: GlassContainer(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.storefront, color: AppColors.primary, size: 32),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        LiveTranslatedText(
                                          shop['name'],
                                          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on, color: AppColors.primary, size: 14),
                                            const SizedBox(width: 4),
                                            LiveTranslatedText(shop['distance'], style: TextStyle(color: subTextColor, fontSize: 13)),
                                            const SizedBox(width: 16),
                                            const Icon(Icons.star, color: Colors.amber, size: 14),
                                            const SizedBox(width: 4),
                                            LiveTranslatedText(shop['rating'], style: TextStyle(color: subTextColor, fontSize: 13)),
                                          ],
                                        ),
                                        if (_shopAddress(shop).isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          LiveTranslatedText(
                                            _shopAddress(shop),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 11, color: subTextColor),
                                          ),
                                        ],
                                        if ((shop['phone']?.toString() ?? '').isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          LiveTranslatedText(
                                            'Phone: ${shop['phone']}',
                                            style: TextStyle(fontSize: 11, color: subTextColor),
                                          ),
                                        ],
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: TextButton.icon(
                                            onPressed: () => _openShopDirections(shop),
                                            icon: const Icon(Icons.directions_outlined, size: 16),
                                            label: const LiveTranslatedText('Directions'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_ios, color: subTextColor, size: 16),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
