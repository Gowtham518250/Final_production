import 'live_translated_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:crypto/crypto.dart';
import 'backup_service.dart';
import 'app_localizations.dart';
import 'visual_widgets.dart';
import 'security_service.dart';
import 'qr_scanner_page.dart';
import 'retail_growth_kit.dart';
import 'api_client.dart';
import 'secure_token_storage.dart';
import 'validation_helper.dart';
import 'shop_profile_persistence_service.dart';
import 'secure_preferences_service.dart';
import 'shop_logo_format.dart';
import 'scoped_shared_preferences.dart';
import 'guided_dictation_overlay.dart';

class ShopProfilePage extends StatefulWidget {
  const ShopProfilePage({super.key});

  @override
  State<ShopProfilePage> createState() => _ShopProfilePageState();
}

class _ShopProfilePageState extends State<ShopProfilePage> {
  static const _pageBackground = Color(0xFFF5F7FA);
  static const _surfaceColor = Colors.white;
  static const _primaryTextColor = Color(0xFF172033);
  static const _secondaryTextColor = Color(0xFF667085);
  static const _borderColor = Color(0xFFE4E8EF);
  static const _fieldBackground = Color(0xFFF8FAFC);

  final _formKey = GlobalKey<FormState>();
  final TextEditingController shopNameController = TextEditingController();
  final TextEditingController contactPersonController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController shopTypeController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController categoriesController = TextEditingController();
  final TextEditingController openingHourController = TextEditingController();
  final TextEditingController closingHourController = TextEditingController();
  final TextEditingController websiteController = TextEditingController();
  final TextEditingController playStoreUrlController = TextEditingController();
  final TextEditingController taglineController = TextEditingController();
  final TextEditingController upiIdController = TextEditingController();
  final TextEditingController gstController = TextEditingController();

  Uint8List? logoBytes;
  bool isLoading = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _onlineShoppingEnabled = false;
  bool _togglingOnline = false;
  String? successMessage;
  String? errorMessage;
  String? _scannedStateCode;
  double? _shopLatitude;
  double? _shopLongitude;
  double? _locationAccuracyMeters;

  @override
  void initState() {
    super.initState();
    _loadShopData();
  }

  Future<void> _loadShopData() async {
    final biometricAvailable =
        await SecurityService.isBiometricHardwareAvailable();
    final biometricEnabled = await SecurityService.isBiometricEnabled();

    // Profile fields must be user-scoped. Never restore another account's
    // legacy unscoped shop_name/location values from SharedPreferences.
    final scopedShopName =
        await ScopedSharedPreferences.getString('shop_name') ?? '';
    final scopedLocation =
        await ScopedSharedPreferences.getString('location') ?? '';
    final scopedLatitude = double.tryParse(
      await ScopedSharedPreferences.getString('shop_latitude') ?? '',
    );
    final scopedLongitude = double.tryParse(
      await ScopedSharedPreferences.getString('shop_longitude') ?? '',
    );
    final scopedShopType =
        await ScopedSharedPreferences.getString('shop_type') ?? '';
    final scopedPhone =
        await ScopedSharedPreferences.getString('shop_phone') ?? '';
    final scopedContactPerson =
        await ScopedSharedPreferences.getString('contact_person') ?? '';
    final scopedEmail =
        await ScopedSharedPreferences.getString('shop_email') ??
        await ScopedSharedPreferences.getString('email') ??
        '';
    final scopedCategories =
        await ScopedSharedPreferences.getString('shop_categories') ?? '';
    final scopedOpeningHour =
        await ScopedSharedPreferences.getString('opening_hour') ?? '09:00 AM';
    final scopedClosingHour =
        await ScopedSharedPreferences.getString('closing_hour') ?? '09:00 PM';
    final scopedWebsite =
        await ScopedSharedPreferences.getString('website') ?? '';
    final scopedPlayStore =
        await ScopedSharedPreferences.getString(
          RetailGrowthKit.kPlayStoreHint,
        ) ??
        '';
    final scopedTagline =
        await ScopedSharedPreferences.getString('shop_tagline') ??
        await ScopedSharedPreferences.getString('tagline') ??
        '';
    final scopedUpi =
        await ScopedSharedPreferences.getString('primary_upi_id') ??
        await ScopedSharedPreferences.getString('upi_id') ??
        '';
    final scopedGst =
        await ScopedSharedPreferences.getString('shop_gst') ??
        await ScopedSharedPreferences.getString('gst_number') ??
        '';
    final scopedState =
        await ScopedSharedPreferences.getString('state') ??
        await ScopedSharedPreferences.getString('shop_state');
    final logoBase64 = await ScopedSharedPreferences.getString('logo_base64');
    final onlineShopping =
        await ScopedSharedPreferences.getBool('online_shopping_enabled') ??
        false;
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;
    setState(() {
      shopNameController.text = scopedShopName;
      contactPersonController.text = scopedContactPerson.isNotEmpty
          ? scopedContactPerson
          : (prefs.getString('user_name') ?? '');
      locationController.text = scopedLocation;
      _shopLatitude = scopedLatitude;
      _shopLongitude = scopedLongitude;
      shopTypeController.text = scopedShopType;
      phoneController.text = scopedPhone;
      emailController.text = scopedEmail.isNotEmpty
          ? scopedEmail
          : (prefs.getString('user_email') ?? prefs.getString('email') ?? '');
      categoriesController.text = scopedCategories;
      openingHourController.text = scopedOpeningHour;
      closingHourController.text = scopedClosingHour;
      websiteController.text = scopedWebsite;
      playStoreUrlController.text = scopedPlayStore;
      taglineController.text = scopedTagline;
      upiIdController.text = scopedUpi;
      gstController.text = scopedGst;
      _scannedStateCode = scopedState;

      if (logoBase64 != null && logoBase64.isNotEmpty) {
        try {
          logoBytes = base64Decode(logoBase64);
        } catch (e) {
          debugPrint('Error decoding scoped logo: $e');
        }
      }

      _biometricAvailable = biometricAvailable;
      _biometricEnabled = biometricEnabled;
      _onlineShoppingEnabled = onlineShopping;
    });

    await _loadShopDataFromBackend();
  }

  Future<int> _resolveUserId() async {
    final secureId = await SecureTokenStorage.getUserId();
    if (secureId != null && secureId > 0) return secureId;

    final scopedId = await ScopedSharedPreferences.getCurrentUserId();
    if (scopedId != null && scopedId > 0) return scopedId;

    final prefs = await SharedPreferences.getInstance();
    final rawUserId = prefs.get('user_id') ?? prefs.get('userId');
    return int.tryParse(rawUserId?.toString() ?? '') ?? 0;
  }

  Future<String> _resolveAuthToken() async {
    // 🛡️ SECURITY FIX #1: Always use SecureTokenStorage, never fallback to plain prefs
    final token = await SecureTokenStorage.getToken();
    return token ?? '';
  }

  Map<String, dynamic> _buildShopPayload(int userId) {
    return {
      'user_id': userId,
      'shop_name': shopNameController.text.trim(),
      'contact_person_name': contactPersonController.text.trim(),
      'location': locationController.text.trim(),
      'latitude': _shopLatitude,
      'longitude': _shopLongitude,
      'shop_type': shopTypeController.text.trim(),
      // Backend ShopProfileCreate/Update accept `phone` and `upi_id`.
      // Keep legacy aliases for older clients, but send the canonical API keys too.
      'phone': phoneController.text.trim(),
      'shop_phone': phoneController.text.trim(),
      'email': emailController.text.trim(),
      'shop_categories': categoriesController.text
          .split(',')
          .map((category) => category.trim())
          .where((category) => category.isNotEmpty)
          .toList(),
      'opening_hour': openingHourController.text.trim(),
      'closing_hour': closingHourController.text.trim(),
      'website': websiteController.text.trim(),
      'shop_tagline': taglineController.text.trim(),
      'upi_id': upiIdController.text.trim(),
      'primary_upi_id': upiIdController.text.trim(),
      'gst_number': gstController.text.trim(),
      'state': _scannedStateCode ?? '',
    };
  }

  void _applyShopMapToControllers(Map<String, dynamic> shop) {
    String _pick(List<String> keys) {
      for (final key in keys) {
        final raw = shop[key];
        if (raw != null) {
          final txt = raw.toString().trim();
          if (txt.isNotEmpty) return txt;
        }
      }
      return '';
    }

    if (!mounted) return;
    setState(() {
      final shopName = _pick(['shop_name', 'name']);
      final location = _pick(['location', 'address']);
      final shopType = _pick(['shop_type', 'type']);
      final phone = _pick(['shop_phone', 'phone', 'mobile']);
      final contactPerson = _pick([
        'contact_person_name',
        'contact_person',
        'owner_name',
      ]);
      final email = _pick(['email', 'shop_email', 'contact_person_email']);
      final categories = shop['shop_categories'];
      final openingHour = _pick(['opening_hour', 'opening_time']);
      final closingHour = _pick(['closing_hour', 'closing_time']);
      final website = _pick(['website']);
      final tagline = _pick([
        'shop_tagline',
        'tagline',
      ]); // 🔧 Try backend key first
      final upiId = _pick([
        'primary_upi_id',
        'upi_id',
        'upi',
      ]); // 🔧 Try backend key first
      final gst = _pick(['shop_gst', 'gst_number', 'gstin']);
      final state = _pick(['state', 'shop_state']); // 🔧 Try backend key first
      final playStore = _pick([
        'play_store_url',
        'play_store_link',
        'app_link',
      ]);
      final latitude = double.tryParse(_pick(['latitude', 'shop_latitude']));
      final longitude = double.tryParse(_pick(['longitude', 'shop_longitude']));

      _shopLatitude = latitude;
      _shopLongitude = longitude;
      if (shopName.isNotEmpty) shopNameController.text = shopName;
      if (location.isNotEmpty) locationController.text = location;
      if (shopType.isNotEmpty) shopTypeController.text = shopType;
      if (phone.isNotEmpty) phoneController.text = phone;
      if (contactPerson.isNotEmpty) {
        contactPersonController.text = contactPerson;
      }
      if (email.isNotEmpty) emailController.text = email;
      if (categories is List) {
        categoriesController.text = categories
            .map((category) => category.toString())
            .join(', ');
      } else if (categories != null) {
        categoriesController.text = categories.toString();
      }
      if (openingHour.isNotEmpty) openingHourController.text = openingHour;
      if (closingHour.isNotEmpty) closingHourController.text = closingHour;
      if (website.isNotEmpty) websiteController.text = website;
      if (tagline.isNotEmpty) taglineController.text = tagline;
      if (upiId.isNotEmpty) upiIdController.text = upiId;
      if (gst.isNotEmpty) gstController.text = gst;
      if (state.isNotEmpty) _scannedStateCode = state;
      if (playStore.isNotEmpty) playStoreUrlController.text = playStore;
    });
  }

  Future<void> _persistShopFieldsLocally() async {
    // Keep the compatibility keys, but scope them to the authenticated user.
    await ScopedSharedPreferences.setString(
      'shop_name',
      shopNameController.text.trim(),
    );
    await ScopedSharedPreferences.setString(
      'contact_person',
      contactPersonController.text.trim(),
    );
    await ScopedSharedPreferences.setString(
      'location',
      locationController.text.trim(),
    );
    await ScopedSharedPreferences.setString(
      'shop_latitude',
      _shopLatitude?.toString() ?? '',
    );
    await ScopedSharedPreferences.setString(
      'shop_longitude',
      _shopLongitude?.toString() ?? '',
    );
    await ScopedSharedPreferences.setString(
      'shop_type',
      shopTypeController.text.trim(),
    );
    await ScopedSharedPreferences.setString(
      'shop_phone',
      phoneController.text.trim(),
    );
    await ScopedSharedPreferences.setString(
      'shop_email',
      emailController.text.trim(),
    );
    await ScopedSharedPreferences.setString(
      'email',
      emailController.text.trim(),
    );
    await ScopedSharedPreferences.setString(
      'shop_categories',
      categoriesController.text.trim(),
    );
    await ScopedSharedPreferences.setString(
      'opening_hour',
      openingHourController.text.trim(),
    );
    await ScopedSharedPreferences.setString(
      'closing_hour',
      closingHourController.text.trim(),
    );
    await ScopedSharedPreferences.setString(
      'website',
      websiteController.text.trim(),
    );
    await ScopedSharedPreferences.setString(
      RetailGrowthKit.kPlayStoreHint,
      playStoreUrlController.text.trim(),
    );
    await ScopedSharedPreferences.setString(
      'shop_tagline',
      taglineController.text.trim(),
    );
    await ScopedSharedPreferences.setString(
      'primary_upi_id',
      upiIdController.text.trim(),
    );
    await ScopedSharedPreferences.setString(
      'upi_id',
      upiIdController.text.trim(),
    );

    // Keep the encrypted UPI value used by the Sales Dashboard in sync with
    // first-time setup and every subsequent profile save/load.
    await SecurePreferencesService.setUpiId(upiIdController.text.trim());
    await ScopedSharedPreferences.setString(
      'shop_gst',
      gstController.text.trim(),
    );
    await ScopedSharedPreferences.setString(
      'gst_number',
      gstController.text.trim(),
    );

    if (_scannedStateCode != null) {
      await ScopedSharedPreferences.setString('state', _scannedStateCode!);
    }
    if (logoBytes != null) {
      await ScopedSharedPreferences.setString(
        'logo_base64',
        base64Encode(logoBytes!),
      );
    }
  }

  Future<void> _loadShopDataFromBackend() async {
    try {
      final userId = await _resolveUserId();
      if (userId <= 0) {
        if (kDebugMode) debugPrint('⚠️ User ID not found for backend load');
        return;
      }

      final token = await _resolveAuthToken();
      if (token.isEmpty) {
        if (kDebugMode) debugPrint('⚠️ Auth token not found for backend load');
        return;
      }

      if (kDebugMode) debugPrint('🔄 Loading shop profile from backend...');

      final resp = await ApiClient.getJson(
        '${ApiClient.shopProfile}',
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 12));

      if (kDebugMode)
        debugPrint('📥 Backend response: ${resp.statusCode} - ${resp.body}');

      if (resp.statusCode != 200) {
        if (kDebugMode)
          debugPrint('⚠️ Backend load failed with status ${resp.statusCode}');
        return;
      }

      final decoded = json.decode(resp.body);
      Map<String, dynamic>? map;

      if (decoded is Map<String, dynamic>) {
        final dynamic nested =
            decoded['profile'] ?? decoded['shop'] ?? decoded['data'];
        if (nested is Map<String, dynamic>) {
          map = nested;
        } else {
          map = decoded;
        }
      }

      if (map == null || map.isEmpty) {
        if (kDebugMode) debugPrint('⚠️ Backend response is empty or invalid');
        return;
      }

      if (kDebugMode)
        debugPrint('✅ Shop profile loaded from backend successfully');
      _applyShopMapToControllers(map);
      await _persistShopFieldsLocally();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Backend load error: $e');
      // Keep local-first behavior if backend is unavailable.
    }
  }

  Future<bool> _saveShopProfileToBackend() async {
    final userId = await _resolveUserId();
    if (userId <= 0) {
      if (kDebugMode) debugPrint('❌ User ID not found');
      return false;
    }

    final token = await _resolveAuthToken();
    if (token.isEmpty) {
      if (kDebugMode) debugPrint('❌ Auth token not found');
      return false;
    }

    final payload = _buildShopPayload(userId);
    final headers = <String, String>{
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    try {
      if (kDebugMode)
        debugPrint('🔄 Attempting to save shop profile to backend...');
      if (kDebugMode)
        debugPrint('📤 Payload: ${_redactSensitiveData(payload)}');

      // Try PUT method first for updates
      try {
        final putResp = await ApiClient.putJson(
          '${ApiClient.shopProfile}',
          payload,
          headers: headers,
        ).timeout(const Duration(seconds: 15));

        if (kDebugMode)
          debugPrint(
            '📥 PUT response: ${putResp.statusCode} - ${putResp.body}',
          );

        if (putResp.statusCode == 200 || putResp.statusCode == 201) {
          final verified = await _verifyPersistedProfile(
            token,
            userId,
            payload,
          );
          if (verified) {
            if (kDebugMode)
              debugPrint('✅ Shop profile persisted and verified via PUT');
            return true;
          }
          if (kDebugMode)
            debugPrint(
              '❌ PUT returned success but persisted profile verification failed',
            );
        }
        if (kDebugMode)
          debugPrint(
            '⚠️ PUT to profile failed with status ${putResp.statusCode}: ${putResp.body}',
          );
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ PUT to profile request failed: $e');
      }

      // If PUT fails, try CREATE (new shop) using POST
      try {
        if (kDebugMode) debugPrint('🔄 Trying CREATE endpoint with POST...');
        final postResp = await ApiClient.postJson(
          '${ApiClient.shopCreate}',
          payload,
          headers: headers,
        ).timeout(const Duration(seconds: 15));

        if (kDebugMode)
          debugPrint(
            '📥 POST create response: ${postResp.statusCode} - ${postResp.body}',
          );

        if (postResp.statusCode == 200 || postResp.statusCode == 201) {
          final verified = await _verifyPersistedProfile(
            token,
            userId,
            payload,
          );
          if (verified) {
            if (kDebugMode)
              debugPrint('✅ Shop profile created and verified via POST');
            return true;
          }
          if (kDebugMode)
            debugPrint(
              '❌ POST returned success but persisted profile verification failed',
            );
        }
        if (kDebugMode)
          debugPrint(
            '⚠️ POST to create failed with status ${postResp.statusCode}: ${postResp.body}',
          );
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ POST to create request failed: $e');
      }

      // Last fallback: try POST to profile endpoint
      try {
        if (kDebugMode) debugPrint('🔄 Trying POST method as fallback...');
        final postResp = await ApiClient.postJson(
          ApiClient.shopProfile,
          payload,
          headers: headers,
        ).timeout(const Duration(seconds: 15));

        if (kDebugMode)
          debugPrint(
            '📥 POST profile response: ${postResp.statusCode} - ${postResp.body}',
          );

        if (postResp.statusCode == 200 || postResp.statusCode == 201) {
          final verified = await _verifyPersistedProfile(
            token,
            userId,
            payload,
          );
          if (verified) {
            if (kDebugMode)
              debugPrint(
                '✅ Shop profile persisted and verified via POST fallback',
              );
            return true;
          }
          if (kDebugMode)
            debugPrint(
              '❌ POST fallback returned success but persisted profile verification failed',
            );
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ POST to profile request failed: $e');
      }

      if (kDebugMode) debugPrint('❌ All backend sync attempts failed');
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Backend sync error: $e');
      return false;
    }
  }

  Future<bool> _verifyPersistedProfile(
    String token,
    int expectedUserId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final resp = await ApiClient.getJson(
        ApiClient.shopProfile,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) {
        if (kDebugMode)
          debugPrint('❌ Profile verification GET failed: ${resp.statusCode}');
        return false;
      }

      final decoded = json.decode(resp.body);
      if (decoded is! Map) return false;

      final outer = Map<String, dynamic>.from(decoded);
      final rawProfile = outer['profile'];
      final profile = rawProfile is Map
          ? Map<String, dynamic>.from(rawProfile)
          : outer;

      final returnedUserId =
          int.tryParse(
            '${profile['shop_id'] ?? profile['user_id'] ?? outer['shop_id'] ?? outer['user_id'] ?? 0}',
          ) ??
          0;

      final expectedName = (payload['shop_name'] ?? '').toString().trim();
      final returnedName = (profile['shop_name'] ?? '').toString().trim();
      final expectedUpi = (payload['upi_id'] ?? payload['primary_upi_id'] ?? '')
          .toString()
          .trim();
      final returnedUpi = (profile['upi_id'] ?? profile['primary_upi_id'] ?? '')
          .toString()
          .trim();

      final identityMatches = returnedUserId == expectedUserId;
      final nameMatches = expectedName.isEmpty || returnedName == expectedName;
      // Do not report a successful save if the server silently dropped the UPI ID.
      final upiMatches = expectedUpi.isEmpty || returnedUpi == expectedUpi;

      if (kDebugMode) {
        debugPrint(
          '🔎 Profile verification: expectedUser=$expectedUserId returnedUser=$returnedUserId '
          'expectedName="$expectedName" returnedName="$returnedName"',
        );
      }

      return identityMatches && nameMatches && upiMatches;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Persisted profile verification error: $e');
      return false;
    }
  }

  // Helper to redact sensitive data for logging
  Map<String, dynamic> _redactSensitiveData(Map<String, dynamic> data) {
    final sensitiveKeys = ['token', 'password', 'upi_id', 'gst', 'phone'];
    final redacted = Map<String, dynamic>.from(data);
    sensitiveKeys.forEach((key) {
      if (redacted.containsKey(key) && redacted[key] != null) {
        final value = redacted[key].toString();
        if (value.length > 3) {
          redacted[key] = '${value.substring(0, 3)}***';
        } else {
          redacted[key] = '***';
        }
      }
    });
    return redacted;
  }

  Future<void> scanUpiQr() async {
    final String? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QrScannerPage()),
    );

    if (result != null && result.isNotEmpty) {
      // Parse UPI URL: upi://pay?pa=address@bank&pn=Name...
      try {
        final uri = Uri.parse(result);
        if (uri.scheme == 'upi') {
          final upiId = uri.queryParameters['pa'];
          if (upiId != null) {
            setState(() {
              upiIdController.text = upiId;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: LiveTranslatedText('✅ UPI ID detected: $upiId'),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          } else {
            throw 'UPI ID (pa) missing in code';
          }
        } else {
          // Maybe it's just the raw ID?
          if (result.contains('@')) {
            setState(() => upiIdController.text = result);
          } else {
            throw 'Invalid UPI QR format';
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: LiveTranslatedText('❌ Could not read UPI ID: $e')),
        );
      }
    }
  }

  Future<void> pickLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (kIsWeb) {
          setState(() {
            logoBytes = file.bytes;
          });
        } else {
          final bytes = await File(file.path!).readAsBytes();
          setState(() {
            logoBytes = bytes;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: LiveTranslatedText('Error picking image: $e')),
      );
    }
  }

  /// 🔧 Upload logo to backend using POST /api/shop/upload-logo
  Future<bool> _uploadLogoToBackend() async {
    final bytes = logoBytes;
    if (bytes == null || bytes.isEmpty) {
      return false;
    }

    final imageFormat = ShopLogoFormat.detect(bytes);
    if (imageFormat == null) {
      if (kDebugMode) {
        debugPrint(
          '❌ Unsupported logo image format. Choose a PNG, JPEG, GIF, or WebP image.',
        );
      }
      return false;
    }

    try {
      final userId = await _resolveUserId();
      if (userId <= 0) return false;

      final token = await _resolveAuthToken();
      if (token.isEmpty) return false;

      // Match both the backend's multipart field name and the actual file MIME
      // type. Uploading every picked image as application/octet-stream/PNG
      // causes valid JPEG and WebP uploads to be rejected with HTTP 400.
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename:
            'shop_logo_${DateTime.now().millisecondsSinceEpoch}.${imageFormat.extension}',
        contentType: imageFormat.contentType,
      );

      final resp = await ApiClient.postMultipart(
        ApiClient.shopUploadLogo,
        <String, String>{},
        headers: {'Authorization': 'Bearer $token'},
        files: <http.MultipartFile>[multipartFile],
      ).timeout(const Duration(seconds: 30));

      final statusCode = resp.statusCode;
      final responseBody = await resp.stream.bytesToString();
      if (kDebugMode) {
        debugPrint('📥 Logo upload response: $statusCode - $responseBody');
      }

      if (statusCode != 200 && statusCode != 201) {
        return false;
      }

      final decoded = json.decode(responseBody);
      final body = decoded is Map ? decoded : null;
      final logoUrl = body?['logo_url']?.toString() ?? '';
      final persisted =
          body?['status']?.toString().toLowerCase() == 'success' &&
          logoUrl.isNotEmpty;

      if (!persisted) {
        if (kDebugMode) {
          debugPrint(
            '❌ Logo upload returned success without a persisted logo_url',
          );
        }
        return false;
      }

      await ScopedSharedPreferences.setString('shop_logo_url', logoUrl);
      await ScopedSharedPreferences.setString(
        'logo_base64',
        base64Encode(bytes),
      );
      final version = body?['logo_version']?.toString();
      if (version != null && version.isNotEmpty) {
        await ScopedSharedPreferences.setString('shop_logo_version', version);
      }

      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Logo upload failed: $e');
      return false;
    }
  }

  Future<void> _openGoogleMapsSearch() async {
    final name = shopNameController.text.trim();
    final address = locationController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LiveTranslatedText('Enter your shop name first.')),
      );
      return;
    }
    final query = [name, address].where((part) => part.isNotEmpty).join(', ');
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LiveTranslatedText('Could not open Google Maps.')),
      );
    }
  }

  Future<void> _openGoogleBusinessProfile() async {
    final name = shopNameController.text.trim();
    final address = locationController.text.trim();
    if (name.isEmpty || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LiveTranslatedText(
          'Add your shop name and address before registering on Google Maps.',
        )),
      );
      return;
    }

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Show your shop on Google Maps'),
        content: const Text(
          'First search for an existing listing to avoid duplicates. If it is missing, use Google Business Profile to add or claim your shop. Google may ask you to verify ownership before the listing is published.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'cancel'),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, 'search'),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Check existing listing'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, 'register'),
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Register / claim'),
          ),
        ],
      ),
    );
    if (!mounted || action == null || action == 'cancel') return;
    final uri = action == 'search'
        ? Uri.https('www.google.com', '/maps/search/', {
            'api': '1',
            'query': [name, address].where((part) => part.isNotEmpty).join(', '),
          })
        : Uri.parse('https://business.google.com/add');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LiveTranslatedText('Could not open the Google Maps registration page.')),
      );
    }
  }

  Widget _buildGoogleMapsSetupCard() {
    final hasCoordinates = _shopLatitude != null && _shopLongitude != null;
    final accuracy = _locationAccuracyMeters;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.location_on_rounded, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Google Maps listing',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasCoordinates
                          ? 'Store coordinates saved: ${_shopLatitude!.toStringAsFixed(6)}, ${_shopLongitude!.toStringAsFixed(6)}'
                          : 'Set your storefront location so customers can navigate to you.',
                      style: GoogleFonts.poppins(fontSize: 11.5, color: _secondaryTextColor),
                    ),
                    if (accuracy != null)
                      Text(
                        'GPS accuracy: ±${accuracy.toStringAsFixed(0)} m${accuracy > 50 ? ' — retry outdoors for better accuracy' : ''}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: accuracy > 50 ? Colors.deepOrange : Colors.green.shade700,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Stand at your shop entrance and tap the location pin above. Then check whether your shop already exists on Google Maps.',
            style: GoogleFonts.poppins(fontSize: 11.5, color: _secondaryTextColor),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _fetchLocation,
                icon: const Icon(Icons.my_location_rounded, size: 18),
                label: const Text('Capture location'),
              ),
              OutlinedButton.icon(
                onPressed: _openGoogleMapsSearch,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Find on Maps'),
              ),
              FilledButton.icon(
                onPressed: _openGoogleBusinessProfile,
                icon: const Icon(Icons.add_business_outlined, size: 18),
                label: const Text('Register / claim'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _fetchLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: LiveTranslatedText(
              'Turn on location services, then stand at your shop and try again.',
            )),
          );
        }
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LiveTranslatedText(
              'Location permission denied forever. Please enable in settings.',
            ),
          ),
        );
        return;
      }

      // Capture the storefront coordinates as well as a readable address.
      // Ask the owner to stand at the shop entrance before using this action.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      setState(() {
        _shopLatitude = position.latitude;
        _shopLongitude = position.longitude;
        _locationAccuracyMeters = position.accuracy;
      });
      await ScopedSharedPreferences.setString(
        'shop_latitude',
        position.latitude.toString(),
      );
      await ScopedSharedPreferences.setString(
        'shop_longitude',
        position.longitude.toString(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LiveTranslatedText('Fetching address details...'),
        ),
      );

      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=jsonv2&lat=${position.latitude}&lon=${position.longitude}&addressdetails=1&accept-language=en',
      );

      try {
        final resp = await http
            .get(
              url,
              headers: kIsWeb ? {} : {'User-Agent': 'AiShopkeeperApp/1.0'},
            )
            .timeout(const Duration(seconds: 8));

        if (resp.statusCode == 200) {
          final data = json.decode(resp.body) as Map<String, dynamic>;
          final addr = data['address'] as Map<String, dynamic>? ?? {};

          final stateName = (addr['state'] ?? addr['state_district'] ?? '')
              .toString()
              .trim();
          String discoveredStateCode = 'MH'; // Default
          if (stateName.toLowerCase().contains('maharashtra'))
            discoveredStateCode = 'MH';
          else if (stateName.toLowerCase().contains('uttar pradesh'))
            discoveredStateCode = 'UP';
          else if (stateName.toLowerCase().contains('karnataka'))
            discoveredStateCode = 'KA';
          else if (stateName.toLowerCase().contains('delhi'))
            discoveredStateCode = 'DL';
          else if (stateName.toLowerCase().contains('tamil nadu'))
            discoveredStateCode = 'TN';
          else if (stateName.toLowerCase().contains('gujarat'))
            discoveredStateCode = 'GJ';
          else if (stateName.toLowerCase().contains('telangana'))
            discoveredStateCode = 'TS';

          final parts = <String>[
            if ((addr['road'] ?? addr['street'] ?? addr['pedestrian'] ?? '')
                .toString()
                .trim()
                .isNotEmpty)
              (addr['road'] ?? addr['street'] ?? addr['pedestrian'])
                  .toString()
                  .trim(),
            if ((addr['suburb'] ??
                    addr['neighbourhood'] ??
                    addr['quarter'] ??
                    '')
                .toString()
                .trim()
                .isNotEmpty)
              (addr['suburb'] ?? addr['neighbourhood'] ?? addr['quarter'])
                  .toString()
                  .trim(),
            if ((addr['city'] ??
                    addr['town'] ??
                    addr['village'] ??
                    addr['county'] ??
                    '')
                .toString()
                .trim()
                .isNotEmpty)
              (addr['city'] ??
                      addr['town'] ??
                      addr['village'] ??
                      addr['county'])
                  .toString()
                  .trim(),
            if (stateName.isNotEmpty) stateName,
            if ((addr['country'] ?? '').toString().trim().isNotEmpty)
              (addr['country']).toString().trim(),
          ];

          String readableAddress;
          if (parts.length >= 2) {
            readableAddress = parts.join(', ');
          } else if (data['display_name'] != null) {
            final displayParts = (data['display_name'] as String).split(', ');
            final meaningful = displayParts
                .where((p) => !RegExp(r'^\d+$').hasMatch(p.trim()))
                .toList();
            readableAddress = meaningful.length > 4
                ? meaningful.sublist(meaningful.length - 4).join(', ')
                : meaningful.join(', ');
          } else {
            readableAddress =
                '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
          }

          setState(() {
            locationController.text = readableAddress;
            _scannedStateCode = discoveredStateCode;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: LiveTranslatedText(
                '📍 Bound to State: $stateName ($discoveredStateCode) for Auto-Pricing!',
              ),
            ),
          );
        } else {
          throw Exception('HTTP ${resp.statusCode}');
        }
      } catch (e) {
        // Fallback to coordinates
        setState(() {
          locationController.text =
              '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LiveTranslatedText(
              'Could not get address, showing coordinates.',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: LiveTranslatedText('Error fetching location: $e')),
      );
    }
  }

  Future<void> _pickBusinessTime(TextEditingController controller) async {
    final parsed = _parseTimeOfDay(controller.text);
    final selected = await showTimePicker(
      context: context,
      initialTime: parsed ?? TimeOfDay.now(),
    );
    if (selected == null || !mounted) return;
    controller.text = selected.format(context);
  }

  TimeOfDay? _parseTimeOfDay(String value) {
    final trimmed = value.trim();
    final twelveHour = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (twelveHour != null) {
      var hour = int.tryParse(twelveHour.group(1)!) ?? -1;
      final minute = int.tryParse(twelveHour.group(2)!) ?? -1;
      final period = twelveHour.group(3)!.toUpperCase();
      if (hour < 1 || hour > 12 || minute < 0 || minute > 59) return null;
      if (period == 'AM') {
        hour = hour == 12 ? 0 : hour;
      } else {
        hour = hour == 12 ? 12 : hour + 12;
      }
      return TimeOfDay(hour: hour, minute: minute);
    }

    final twentyFourHour = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(trimmed);
    if (twentyFourHour == null) return null;
    final hour = int.tryParse(twentyFourHour.group(1)!) ?? -1;
    final minute = int.tryParse(twentyFourHour.group(2)!) ?? -1;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _forceRetrySync() async {
    try {
      setState(() {
        isLoading = true;
        successMessage = 'Retrying sync...';
        errorMessage = null;
      });

      final success = await ShopProfilePersistenceService.forceSyncPending();

      setState(() {
        isLoading = false;
        if (success) {
          successMessage = '✅ Sync completed successfully!';
        } else {
          successMessage = null;
          errorMessage = '⚠️ Sync still pending - will retry automatically';
        }
      });

      // Reload data after sync
      await _loadShopDataFromBackend();
    } catch (e) {
      setState(() {
        isLoading = false;
        successMessage = null;
        errorMessage = 'Sync failed: $e';
      });
    }
  }

  Future<void> _toggleOnlineShopping(bool enable) async {
    setState(() {
      _togglingOnline = true;
      errorMessage = null;
      successMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId =
          prefs.getString('shop_id') ??
          prefs.getInt('user_id')?.toString() ??
          '';

      // Optimistic update
      setState(() => _onlineShoppingEnabled = enable);

      // Backend expects 'enable' as query param, not JSON body
      final enableParam = enable ? 'true' : 'false';
      final resp = await ApiClient.postJson(
        '${ApiClient.shopToggleOnlineStore}?enable=$enableParam',
        {},
      );

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        await prefs.setBool('online_shopping_enabled', enable);
        setState(() {
          successMessage = enable
              ? 'Online store enabled ✅'
              : 'Online store disabled';
        });
      } else {
        // Revert optimistic
        setState(() => _onlineShoppingEnabled = !enable);
        final body = resp.body;
        setState(() {
          errorMessage = 'Failed to update online store (${resp.statusCode})';
        });
        if (kDebugMode) debugPrint('Toggle online store failed: $body');
      }
    } catch (e) {
      setState(() {
        _onlineShoppingEnabled = !_onlineShoppingEnabled;
        errorMessage = 'Network error: $e';
      });
    } finally {
      setState(() => _togglingOnline = false);
      // Clear messages after a few seconds
      Future.delayed(const Duration(seconds: 4), () {
        if (!mounted) return;
        setState(() {
          successMessage = null;
          errorMessage = null;
        });
      });
    }
  }

  Widget _buildSyncStatusIndicator() {
    return FutureBuilder<Map<String, dynamic>>(
      future: ShopProfilePersistenceService.getSyncStatus(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final status = snapshot.data!;
        final hasPending = status['has_pending_sync'] == true;
        final isSyncing = status['is_syncing'] == true;

        if (!hasPending && !isSyncing) return const SizedBox.shrink();

        final Color bgColor;
        final Color iconColor;
        final IconData icon;
        final String message;

        if (isSyncing) {
          bgColor = Colors.blue.shade50;
          iconColor = Colors.blue.shade700;
          icon = Icons.sync;
          message = 'Syncing profile...';
        } else if (hasPending) {
          bgColor = Colors.orange.shade50;
          iconColor = Colors.orange.shade700;
          icon = Icons.cloud_off;
          message = 'Profile pending sync - will retry automatically';
        } else {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: bgColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: LiveTranslatedText(
                  message,
                  style: TextStyle(color: iconColor, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> saveShopProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // First check sync status before saving
    final syncStatus = await ShopProfilePersistenceService.getSyncStatus();
    if (syncStatus['has_pending_sync'] == true) {
      // Try to sync pending first
      if (kDebugMode)
        debugPrint('🔄 Attempting to sync pending profile before save...');
      await ShopProfilePersistenceService.forceSyncPending();
    }

    setState(() {
      isLoading = true;
      successMessage = null;
      errorMessage = null;
    });

    try {
      // Build the profile payload
      final userId = await _resolveUserId();
      final profile = _buildShopPayload(userId);

      // 🔧 IMPORTANT: Use ShopProfilePersistenceService to save and sync
      await ShopProfilePersistenceService.saveProfileLocally(profile);
      if (kDebugMode) debugPrint('✅ Shop profile saved locally');

      // 🔧 Try to sync to backend
      final syncResult =
          await ShopProfilePersistenceService.syncProfileToBackend(profile);
      final synced = syncResult['success'] == true;
      if (kDebugMode) debugPrint('🔄 Backend sync result: $syncResult');

      // 🔧 If sync failed, mark for background retry
      if (!synced) {
        await ShopProfilePersistenceService.markForSync(profile);
        if (kDebugMode) debugPrint('📝 Profile marked for background sync');
      }

      // 🔧 NEW: Upload logo if available
      bool logoUploaded = false;
      if (logoBytes != null && logoBytes!.isNotEmpty) {
        logoUploaded = await _uploadLogoToBackend();
        if (kDebugMode) debugPrint('🔄 Logo upload result: $logoUploaded');
      }

      // Also persist individual fields for backwards compatibility
      await _persistShopFieldsLocally();

      setState(() {
        if (synced && logoUploaded) {
          successMessage = '✅ Shop profile & logo saved to cloud! 🎉';
          errorMessage = null;
        } else if (synced && !logoUploaded && logoBytes != null) {
          successMessage = '✅ Profile saved to cloud. Logo upload pending...';
          errorMessage = null;
        } else if (synced) {
          successMessage = '✅ Shop profile saved to cloud! 🎉';
          errorMessage = null;
        } else {
          // Saved locally, waiting for sync
          successMessage =
              '💾 Profile saved locally. Will sync when internet is available.';
          errorMessage = syncResult['error'] != null
              ? '⚠️ Backend sync failed: ${syncResult['error']}'
              : '⚠️ Backend sync failed - will retry automatically';
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: LiveTranslatedText(
              synced
                  ? (logoUploaded
                        ? '✅ Profile & logo synced to backend!'
                        : '✅ Profile synced to backend!')
                  : '💾 Profile saved locally. Will sync online.',
            ),
            backgroundColor: synced
                ? const Color(0xFF10B981)
                : Colors.orange[600],
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error saving profile: $e');
      setState(() {
        errorMessage = 'Error: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: LiveTranslatedText('❌ Error: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    shopNameController.dispose();
    contactPersonController.dispose();
    locationController.dispose();
    shopTypeController.dispose();
    phoneController.dispose();
    emailController.dispose();
    categoriesController.dispose();
    openingHourController.dispose();
    closingHourController.dispose();
    websiteController.dispose();
    playStoreUrlController.dispose();
    taglineController.dispose();
    upiIdController.dispose();
    gstController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.light,
        scaffoldBackgroundColor: _pageBackground,
        colorScheme: Theme.of(context).colorScheme.copyWith(
          brightness: Brightness.light,
          surface: _surfaceColor,
          onSurface: _primaryTextColor,
        ),
      ),
      child: BackendLoadingOverlay(
        isVisible: isLoading,
        title: 'Saving your profile',
        subtitle: 'Uploading your shop details and syncing with the backend',
        icon: Icons.cloud_upload_rounded,
        accentColor: AppColors.primary,
        child: PopScope(
          canPop: true,
          onPopInvoked: (didPop) {
            if (didPop) return;
            final hasChanges =
                shopNameController.text.isNotEmpty ||
                locationController.text.isNotEmpty ||
                taglineController.text.isNotEmpty ||
                upiIdController.text.isNotEmpty;
            if (hasChanges) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: _surfaceColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  title: const LiveTranslatedText(
                    'Discard Changes?',
                    style: TextStyle(color: _primaryTextColor),
                  ),
                  content: const LiveTranslatedText(
                    'You have unsaved shop profile changes.',
                    style: TextStyle(color: _secondaryTextColor),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const LiveTranslatedText('Keep Editing'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      child: const LiveTranslatedText('Discard'),
                    ),
                  ],
                ),
              );
            } else {
              Navigator.pop(context);
            }
          },
          child: GuidedDictationExclusion(
            child: Scaffold(
              backgroundColor: _pageBackground,
              body: Stack(
                children: [
                  SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () =>
                                        Navigator.maybePop(context),
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(
                                      Icons.arrow_back_rounded,
                                      color: _secondaryTextColor,
                                      size: 21,
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        LiveTranslatedText(
                                          'Shop Profile',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: _primaryTextColor,
                                            letterSpacing: -0.35,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        LiveTranslatedText(
                                          'Manage all your shop details and settings here.',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(
                                            fontSize: 10.5,
                                            color: _secondaryTextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () async {
                                      try {
                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        final shopId =
                                            prefs.getString('shop_id') ??
                                            prefs
                                                .getInt('user_id')
                                                ?.toString() ??
                                            '1';
                                        final shopName =
                                            prefs.getString('shop_name') ??
                                            shopNameController.text.trim();
                                        final shopUrl =
                                            'https://retail-mind-web.onrender.com/shop/$shopId';
                                        await Share.share(
                                          '🛍️ Browse products from $shopName\n$shopUrl',
                                          subject: 'Visit $shopName',
                                        );
                                      } catch (e) {
                                        if (kDebugMode) {
                                          debugPrint('Share failed: $e');
                                        }
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: LiveTranslatedText(
                                                'Could not share shop',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(
                                      Icons.ios_share_rounded,
                                      color: _secondaryTextColor,
                                      size: 19,
                                    ),
                                    tooltip: 'Share Shop',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 13),
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.96, end: 1),
                                duration: const Duration(milliseconds: 520),
                                curve: Curves.easeOutCubic,
                                builder: (context, scale, child) =>
                                    Transform.scale(scale: scale, child: child),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: _surfaceColor,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: _borderColor),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF172033,
                                        ).withValues(alpha: 0.06),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.10),
                                              borderRadius:
                                                  BorderRadius.circular(9),
                                            ),
                                            child: const Icon(
                                              Icons.storefront_rounded,
                                              color: AppColors.primary,
                                              size: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                LiveTranslatedText(
                                                  'Store profile',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: _primaryTextColor,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                LiveTranslatedText(
                                                  'Business information',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 9.5,
                                                    color: _secondaryTextColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF10B981,
                                              ).withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color: const Color(
                                                  0xFF10B981,
                                                ).withValues(alpha: 0.22),
                                              ),
                                            ),
                                            child: const LiveTranslatedText(
                                              'All details',
                                              style: TextStyle(
                                                color: Color(0xFF15803D),
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 13),
                                      _buildLogoPicker(),
                                      const SizedBox(height: 12),
                                      _buildForm(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoPicker() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.88, end: 1),
      duration: const Duration(milliseconds: 620),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Column(
        children: [
          GestureDetector(
            onTap: pickLogo,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: _fieldBackground,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.42),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
                image: logoBytes != null
                    ? DecorationImage(
                        image: MemoryImage(logoBytes!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: logoBytes == null
                  ? const Icon(
                      Icons.add_a_photo_rounded,
                      size: 28,
                      color: AppColors.primary,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          LiveTranslatedText(
            logoBytes == null ? 'Tap to add shop logo' : 'Tap to change logo',
            style: GoogleFonts.inter(
              color: _secondaryTextColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 12, 11, 10),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: LiveTranslatedText(
                'Essential business details',
                style: GoogleFonts.inter(
                  color: _primaryTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _StyledField(
              controller: shopNameController,
              label: 'Shop Name',
              icon: Icons.storefront_rounded,
              hint: 'e.g. Shiva Shakthi Stores',
              validator: (v) => v!.isEmpty ? 'Please enter shop name' : null,
            ),
            const SizedBox(height: 11),
            _StyledField(
              controller: contactPersonController,
              label: 'Owner / Contact Person',
              icon: Icons.person_outline_rounded,
              hint: 'Enter owner or manager name',
              validator: (v) => v!.trim().isEmpty
                  ? 'Please enter owner or contact name'
                  : null,
            ),
            const SizedBox(height: 11),
            _StyledField(
              controller: locationController,
              label: 'Location',
              icon: Icons.location_on_rounded,
              hint: 'Street, area, city',
              suffixIcon: IconButton(
                icon: const Icon(Icons.my_location, color: _secondaryTextColor),
                tooltip: 'Capture storefront location',
                onPressed: _fetchLocation,
              ),
              validator: (v) => v!.isEmpty ? 'Please enter location' : null,
            ),
            const SizedBox(height: 8),
            _buildGoogleMapsSetupCard(),
            const SizedBox(height: 11),
            _StyledField(
              controller: shopTypeController,
              label: 'Shop Type',
              icon: Icons.category_rounded,
              hint: 'e.g. Grocery, Clothing, Electronics',
              validator: (v) =>
                  v!.trim().isEmpty ? 'Please enter your shop type' : null,
            ),
            const SizedBox(height: 11),
            _StyledField(
              controller: phoneController,
              label: 'Shop Phone Number',
              icon: Icons.phone_android_rounded,
              hint: 'e.g. +91 9876543210',
              keyboardType: TextInputType.phone,
              validator: (v) {
                final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                return digits.length < 10 ? 'Enter a valid phone number' : null;
              },
            ),
            const SizedBox(height: 11),
            _StyledField(
              controller: emailController,
              label: 'Shop Email',
              icon: Icons.email_outlined,
              hint: 'shop@example.com',
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                final email = v?.trim() ?? '';
                return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
                    ? null
                    : 'Enter a valid email address';
              },
            ),
            const SizedBox(height: 11),
            _StyledField(
              controller: categoriesController,
              label: 'Product Categories',
              icon: Icons.inventory_2_outlined,
              hint: 'e.g. Groceries, Snacks, Beverages',
              validator: (v) => v!.trim().isEmpty
                  ? 'Enter at least one product category'
                  : null,
            ),
            const SizedBox(height: 11),
            _StyledField(
              controller: openingHourController,
              label: 'Opening Time',
              icon: Icons.schedule_rounded,
              hint: 'Choose opening time',
              readOnly: true,
              onTap: () => _pickBusinessTime(openingHourController),
              suffixIcon: const Icon(Icons.access_time_rounded),
            ),
            const SizedBox(height: 11),
            _StyledField(
              controller: closingHourController,
              label: 'Closing Time',
              icon: Icons.schedule_rounded,
              hint: 'Choose closing time',
              readOnly: true,
              onTap: () => _pickBusinessTime(closingHourController),
              suffixIcon: const Icon(Icons.access_time_rounded),
            ),
            const SizedBox(height: 11),
            _StyledField(
              controller: websiteController,
              label: 'Website',
              icon: Icons.language_rounded,
              hint: 'optional',
            ),
            const SizedBox(height: 11),
            _StyledField(
              controller: playStoreUrlController,
              label: 'Play Store / invite link',
              icon: Icons.shop_two_rounded,
              hint:
                  'https://play.google.com/... (optional, for Share from dashboard)',
              keyboardType: TextInputType.url,
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return null;
                final u = Uri.tryParse(t);
                if (u == null ||
                    !u.hasScheme ||
                    (u.scheme != 'http' && u.scheme != 'https')) {
                  return 'Use a full URL starting with https://';
                }
                return null;
              },
            ),
            const SizedBox(height: 11),
            _StyledField(
              controller: upiIdController,
              label: 'UPI ID (VPA) for Payments',
              hint: 'e.g. shopname@okicici',
              icon: Icons.alternate_email_rounded,
              suffixIcon: IconButton(
                icon: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.indigoAccent,
                ),
                onPressed: scanUpiQr,
                tooltip: 'Scan existing QR to auto-fill',
              ),
              validator: (v) =>
                  InputValidator.validateUpiId(v), // 🔧 Added UPI validation
            ),
            const SizedBox(height: 11),
            _StyledField(
              controller: taglineController,
              label: 'Shop Tagline (Optional)',
              icon: Icons.auto_awesome_rounded,
            ),
            const SizedBox(height: 11),
            _StyledField(
              controller: gstController,
              label: 'GSTIN (Optional)',
              hint: 'e.g. 27AAAAA0000A1Z5',
              icon: Icons.receipt_long_rounded,
            ),
            const SizedBox(height: 16),
            // Enable Online Shopping toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: _fieldBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.shopping_bag_rounded,
                    color: _secondaryTextColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LiveTranslatedText(
                          'Enable Online Shopping',
                          style: GoogleFonts.poppins(
                            color: _primaryTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        LiveTranslatedText(
                          'Allow customers to browse & order online',
                          style: GoogleFonts.poppins(
                            color: _secondaryTextColor,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _onlineShoppingEnabled,
                    onChanged: _togglingOnline
                        ? null
                        : (v) => _toggleOnlineShopping(v),
                    activeColor: Colors.green.shade700,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- QR CODE PREVIEW ---
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: upiIdController,
              builder: (context, value, _) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return Center(
                  child: Column(
                    children: [
                      const LiveTranslatedText(
                        'Live Payment QR',
                        style: TextStyle(
                          color: _secondaryTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _surfaceColor,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF6366F1,
                              ).withValues(alpha: 0.3),
                              blurRadius: 25,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data:
                              "upi://pay?pa=${value.text.trim()}&pn=${shopNameController.text.trim()}&cu=INR",
                          version: QrVersions.auto,
                          size: 148.0,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Color(0xFF1E293B),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      LiveTranslatedText(
                        value.text,
                        style: const TextStyle(
                          color: Colors.indigoAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 16),
            _buildBiometricSection(),
            const SizedBox(height: 16),
            _buildBackupSection(),
            const SizedBox(height: 16),
            _buildSecuritySection(),
            const SizedBox(height: 16),
            _buildDeleteAccountSection(),
            const SizedBox(height: 16),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              LiveTranslatedText(
                errorMessage!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
            if (successMessage != null) ...[
              const SizedBox(height: 16),
              LiveTranslatedText(
                successMessage!,
                style: const TextStyle(color: AppColors.secondary),
              ),
            ],
            const SizedBox(height: 16),
            _buildSyncStatusIndicator(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : saveShopProfile,
                      child: isLoading
                          ? const CircularProgressIndicator(
                              color: _surfaceColor,
                            )
                          : const LiveTranslatedText('Save Profile'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 48,
                  width: 48,
                  child: IconButton(
                    icon: const Icon(Icons.sync),
                    onPressed: isLoading ? null : _forceRetrySync,
                    tooltip: 'Retry Sync',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.cloud_upload_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              LiveTranslatedText(
                AppLocalizations.of(context).translate('backup') ??
                    'Backup & Restore',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _primaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LiveTranslatedText(
            'Keep your shop data safe by creating periodic backups. You can restore your data if you switch devices.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: _secondaryTextColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleCreateBackup(),
                  icon: const Icon(Icons.backup_rounded, size: 18),
                  label: const LiveTranslatedText('Backup Now'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    side: const BorderSide(color: AppColors.secondary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleRestoreBackup(),
                  icon: const Icon(Icons.restore_rounded, size: 18),
                  label: const LiveTranslatedText('Restore'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _fieldBackground,
                    foregroundColor: _primaryTextColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleCreateBackup() async {
    setState(() => isLoading = true);
    try {
      final result = await BackupService.createBackup();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'last_backup_time',
        DateTime.now().toIso8601String(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: LiveTranslatedText(
              '✅ Backup created: ${result['size']} KB',
            ),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: LiveTranslatedText('❌ Backup failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
    setState(() => isLoading = false);
  }

  Future<void> _handleRestoreBackup() async {
    try {
      final backups = await BackupService.listBackups();
      if (backups.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: LiveTranslatedText('No backups found to restore'),
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      final selectedBackup = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: _surfaceColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LiveTranslatedText(
                'Select Backup to Restore',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _primaryTextColor,
                ),
              ),
              const SizedBox(height: 16),
              ...backups
                  .map(
                    (b) => ListTile(
                      leading: const Icon(
                        Icons.insert_drive_file,
                        color: AppColors.primary,
                      ),
                      title: LiveTranslatedText(
                        b['date'],
                        style: const TextStyle(color: _primaryTextColor),
                      ),
                      subtitle: LiveTranslatedText(
                        '${b['fileSize']} KB',
                        style: TextStyle(color: _secondaryTextColor),
                      ),
                      onTap: () => Navigator.pop(ctx, b['path']),
                    ),
                  )
                  .toList(),
            ],
          ),
        ),
      );

      if (selectedBackup != null) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _surfaceColor,
            title: const LiveTranslatedText(
              'Confirm Restore?',
              style: TextStyle(color: _primaryTextColor),
            ),
            content: const LiveTranslatedText(
              'This will overwrite current data with backup data. Continue?',
              style: TextStyle(color: _secondaryTextColor),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const LiveTranslatedText('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const LiveTranslatedText('Restore'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          setState(() => isLoading = true);
          await BackupService.restoreBackup(selectedBackup);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: LiveTranslatedText(
                  '✅ Restore complete! Please restart the app.',
                ),
                backgroundColor: AppColors.secondary,
              ),
            );
          }
          setState(() => isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: LiveTranslatedText('❌ Restore failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildBiometricSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.fingerprint_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              LiveTranslatedText(
                'Biometric Login',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _primaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LiveTranslatedText(
            'Keep biometric access private on this device only. Use this setting to enable or disable fingerprint or face unlock for owner verification and protected sections.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: _secondaryTextColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LiveTranslatedText(
                      _biometricAvailable
                          ? 'Device biometrics ready'
                          : 'Biometric unavailable',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    LiveTranslatedText(
                      _biometricAvailable
                          ? 'Fingerprint or face unlock can be managed here.'
                          : 'This device does not support biometric enrollment.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: _secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _biometricEnabled,
                onChanged: _biometricAvailable ? _toggleBiometric : null,
                activeColor: AppColors.primary,
              ),
            ],
          ),
          if (!_biometricAvailable)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: LiveTranslatedText(
                'Biometric login requires device support and must be activated after registration.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: _secondaryTextColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _toggleBiometric(bool enabled) async {
    if (!await SecurityService.isBiometricHardwareAvailable()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LiveTranslatedText(
              'Biometric hardware unavailable on this device.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    if (enabled) {
      final authenticated = await SecurityService.authenticateBiometrically(
        reason: 'Confirm to enable biometric login for Owner access',
      );
      if (!authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: LiveTranslatedText(
                'Biometric verification failed. Login not enabled.',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }
      await SecurityService.setOwnerBiometricStatusVerified();
      await SecurityService.setBiometricEnabled(true);
      if (mounted) {
        setState(() => _biometricEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LiveTranslatedText(
              '✅ Biometric login enabled on this device.',
            ),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } else {
      await SecurityService.setBiometricEnabled(false);
      if (mounted) {
        setState(() => _biometricEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LiveTranslatedText('Biometric login disabled.'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    }
  }

  Widget _buildSecuritySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.electric.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.security_rounded,
                  color: AppColors.electric,
                ),
              ),
              const SizedBox(width: 16),
              LiveTranslatedText(
                'Access Control',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _primaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LiveTranslatedText(
            'The Master PIN protects sensitive sections like Inventory, Shop Details, and Analytics from unauthorized employee access.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: _secondaryTextColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LiveTranslatedText(
                      'Master App PIN',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _primaryTextColor,
                      ),
                    ),
                    LiveTranslatedText(
                      'Default is 0000',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: _secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _showChangePinDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.electric.withValues(alpha: 0.2),
                  foregroundColor: AppColors.electric,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: AppColors.electric.withValues(alpha: 0.3),
                  ),
                ),
                child: const LiveTranslatedText('Change PIN'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showChangePinDialog() {
    final oldController = TextEditingController();
    final newController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: LiveTranslatedText(
          'Change Master PIN',
          style: GoogleFonts.poppins(
            color: _primaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              style: const TextStyle(color: _primaryTextColor),
              decoration: InputDecoration(
                filled: true,
                fillColor: _fieldBackground,
                label: LiveTranslatedText('Current PIN'),
                labelStyle: const TextStyle(color: _secondaryTextColor),
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              style: const TextStyle(color: _primaryTextColor),
              decoration: InputDecoration(
                filled: true,
                fillColor: _fieldBackground,
                label: LiveTranslatedText('New 4-Digit PIN'),
                labelStyle: const TextStyle(color: _secondaryTextColor),
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const LiveTranslatedText('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              final current = await SecurityService.getMasterPin();
              final h = sha256
                  .convert(utf8.encode(oldController.text))
                  .toString();
              if (h == current) {
                if (newController.text.length == 4) {
                  await SecurityService.setMasterPin(newController.text);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: LiveTranslatedText('✅ Master PIN updated!'),
                      backgroundColor: AppColors.secondary,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: LiveTranslatedText('❌ New PIN must be 4 digits'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: LiveTranslatedText('❌ Current PIN is incorrect'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.electric,
            ),
            child: const LiveTranslatedText('UPDATE'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteAccountSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(width: 16),
              LiveTranslatedText(
                'Danger Zone',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LiveTranslatedText(
            'Permanently delete your account and all associated data. This action cannot be undone.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: _secondaryTextColor,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/delete-account'),
              icon: const Icon(Icons.delete_forever_rounded, size: 20),
              label: const LiveTranslatedText('Delete Account Permanently'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;

  const _StyledField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.validator,
    this.suffixIcon,
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LiveTranslatedText(
          label,
          style: GoogleFonts.poppins(
            color: _ShopProfilePageState._primaryTextColor,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          readOnly: readOnly,
          onTap: onTap,
          style: GoogleFonts.poppins(
            color: _ShopProfilePageState._primaryTextColor,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hint: hint == null
                ? null
                : LiveTranslatedText(
                    hint!,
                    style: GoogleFonts.poppins(
                      color: _ShopProfilePageState._secondaryTextColor,
                      fontSize: 11.5,
                    ),
                  ),
            prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: _ShopProfilePageState._fieldBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: _ShopProfilePageState._borderColor,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: _ShopProfilePageState._borderColor,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.72),
                width: 1.2,
              ),
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
          ),
        ),
      ],
    );
  }
}
