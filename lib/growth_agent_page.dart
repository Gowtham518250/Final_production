import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cross_file/cross_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'app_localizations.dart';
import 'growth_marketing_helpers.dart';
import 'live_translated_text.dart';
import 'local_storage_service.dart';

/// Free-first marketing assistant.
///
/// Copy and poster rendering run locally. No advertising budget or paid image
/// generation service is required. Campaigns are private drafts saved on this
/// device, scoped to the signed-in user.
class GrowthAgentPage extends StatefulWidget {
  const GrowthAgentPage({super.key});

  @override
  State<GrowthAgentPage> createState() => _GrowthAgentPageState();
}

class _GrowthAgentPageState extends State<GrowthAgentPage> {
  static const Color _ink = Color(0xFF182230);
  static const Color _muted = Color(0xFF64748B);
  static const Color _purple = Color(0xFF5B3DF5);

  final _shopController = TextEditingController();
  final _offerController = TextEditingController();
  final _discountPriceController = TextEditingController();
  final _offerValidUntilController = TextEditingController();
  final _headlineController = TextEditingController();
  final _captionController = TextEditingController();
  final _posterKey = GlobalKey();

  bool _loading = true;
  bool _busy = false;
  String _message = '';
  String _goal = 'nearby';
  String _language = 'en';
  String _template = 'bold';
  String _adFormat = 'feed';
  String? _selectedProductKey;
  String _campaignStorageKey = 'retailmind_growth_campaigns_v1_guest';
  List<Map<String, dynamic>> _products = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _campaigns = <Map<String, dynamic>>[];
  Map<String, dynamic> _shopDetails = <String, dynamic>{};
  bool _automationEnabled = false;
  bool _autoNewProducts = true;
  bool _autoWeekly = false;
  int _weeklyDay = 0;
  Map<String, dynamic>? _currentDraft;

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
  }

  @override
  void dispose() {
    _shopController.dispose();
    _offerController.dispose();
    _discountPriceController.dispose();
    _offerValidUntilController.dispose();
    _headlineController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  String _productKey(Map<String, dynamic> product, int index) {
    final id = product['id'] ?? product['product_id'] ?? product['sku'];
    if (id != null && id.toString().trim().isNotEmpty) {
      return id.toString();
    }
    return (product['name'] ?? 'product').toString() +
        '_' +
        index.toString();
  }

  double _number(dynamic value) {
    if (value is num && value.isFinite) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
  double? _productPrice(Map<String, dynamic>? product) {
    if (product == null) return null;
    final raw = product['unit_price'] ??
        product['selling_price'] ??
        product['price'];
    if (raw == null || raw.toString().trim().isEmpty) return null;
    final value = raw is num ? raw.toDouble() : double.tryParse(raw.toString().trim());
    if (value == null || !value.isFinite || value < 0) return null;
    return value;
  }

  List<Map<String, dynamic>> _parseProducts(dynamic value) {
    dynamic rows = value;
    if (value is Map) {
      for (final key in const ['products', 'items', 'results', 'data']) {
        final candidate = value[key];
        if (candidate is List) {
          rows = candidate;
          break;
        }
        if (candidate is Map) {
          for (final nestedKey in const ['products', 'items', 'results']) {
            if (candidate[nestedKey] is List) {
              rows = candidate[nestedKey];
              break;
            }
          }
          if (rows is List) break;
        }
      }
    }
    if (rows is! List) return <Map<String, dynamic>>[];

    final parsed = <Map<String, dynamic>>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final product = Map<String, dynamic>.from(row);
      final name = (product['name'] ??
              product['product_name'] ??
              product['title'] ??
              '')
          .toString()
          .trim();
      if (name.isEmpty || product['is_deleted'] == true) continue;
      final stock = _number(product['current_stock'] ??
          product['stock'] ??
          product['quantity']);
      if (stock <= 0) continue;
      product['name'] = name;
      product['current_stock'] = stock;
      final price = _productPrice(product);
      if (price != null) {
        product['unit_price'] = price;
      } else {
        product.remove('unit_price');
      }
      parsed.add(product);
    }
    return parsed;
  }

  Future<void> _loadWorkspace() async {
    setState(() {
      _loading = true;
      _message = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.get('user_id') ?? prefs.get('userId') ?? 'guest';
      _campaignStorageKey = 'retailmind_growth_campaigns_v1_' + userId.toString();

      var shopName = '';
      var shopDetails = <String, dynamic>{};
      var automationEnabled = false;
      var autoNewProducts = true;
      var autoWeekly = false;
      var weeklyDay = 0;
      for (final key in const ['shop_name', 'shopName', 'business_name']) {
        final value = prefs.getString(key)?.trim() ?? '';
        if (value.isNotEmpty) {
          shopName = value;
          break;
        }
      }

      // Fetch the actual shop profile when the existing backend has it. A
      // profile failure must not stop offline campaign drafting.
      try {
        final profileResponse = await ApiClient.getJson('/api/shop/profile')
            .timeout(const Duration(seconds: 8));
        if (profileResponse.statusCode == 200) {
          final decoded = jsonDecode(profileResponse.body);
          if (decoded is Map) {
            final profileData = decoded['profile'] is Map
                ? Map<String, dynamic>.from(decoded['profile'] as Map)
                : decoded['shop_profile'] is Map
                    ? Map<String, dynamic>.from(decoded['shop_profile'] as Map)
                    : Map<String, dynamic>.from(decoded);
            shopDetails = profileData;
            for (final key in const [
              'shop_name',
              'business_name',
              'shopName',
              'name',
            ]) {
              final candidate = profileData[key]?.toString().trim() ?? '';
              if (candidate.isNotEmpty) {
                shopName = candidate;
                break;
              }
            }
          }
        }
      } catch (_) {
        // Offline/profile unavailable: use stored name or let the owner edit.
      }

      try {
        final settingsResponse = await ApiClient.getJson(
          '/growth/marketing/automation/settings',
        ).timeout(const Duration(seconds: 8));
        if (settingsResponse.statusCode == 200) {
          final decodedSettings = jsonDecode(settingsResponse.body);
          if (decodedSettings is Map) {
            automationEnabled = decodedSettings['enabled'] == true;
            autoNewProducts = decodedSettings['new_products_enabled'] != false;
            autoWeekly = decodedSettings['weekly_enabled'] == true;
            weeklyDay = int.tryParse(decodedSettings['weekly_day']?.toString() ?? '') ?? 0;
          }
        }
      } catch (_) {
        // Automation preferences are optional while the backend is offline.
      }

      var products = <Map<String, dynamic>>[];
      var remoteInventorySucceeded = false;
      try {
        final response = await ApiClient.getJson(
          ApiClient.inventoryPrefix + '/products?skip=0&limit=1000',
        ).timeout(const Duration(seconds: 12));
        if (response.statusCode == 200) {
          remoteInventorySucceeded = true;
          products = _parseProducts(jsonDecode(response.body));
        }
      } catch (_) {
        // Inventory may be offline; use the already-cached product list.
      }

      // An authoritative empty server response must not resurrect stale
      // cached products (which could be out of stock or have an old price).
      if (!remoteInventorySucceeded && products.isEmpty) {
        try {
          final cached = await LocalStorageService.loadBackendProducts();
          products = _parseProducts(cached);
        } catch (_) {
          // Continue to locally cached-only products if available.
        }
      }

      if (!remoteInventorySucceeded && products.isEmpty) {
        try {
          final local = await LocalStorageService.loadLocalProducts();
          products = _parseProducts(local.entries.map((entry) {
            final product = Map<String, dynamic>.from(entry.value as Map);
            product['id'] ??= entry.key;
            return product;
          }).toList());
        } catch (_) {
          // A newly installed account can legitimately have no products.
        }
      }

      final stored = prefs.getString(_campaignStorageKey);
      var campaigns = <Map<String, dynamic>>[];
      if (stored != null && stored.isNotEmpty) {
        try {
          final decoded = jsonDecode(stored);
          if (decoded is List) {
            campaigns = decoded
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
          }
        } catch (_) {
          campaigns = <Map<String, dynamic>>[];
        }
      }

      // Merge the server's owner-scoped campaign history with local drafts.
      // Local copies win when a recent offline edit has not reached the API.
      try {
        final historyResponse = await ApiClient.getJson('/growth/marketing/campaigns?limit=50')
            .timeout(const Duration(seconds: 10));
        if (historyResponse.statusCode == 200) {
          final decoded = jsonDecode(historyResponse.body);
          final remoteRows = decoded is Map && decoded['campaigns'] is List
              ? decoded['campaigns'] as List
              : const <dynamic>[];
          final merged = <String, Map<String, dynamic>>{};
          for (final row in remoteRows.whereType<Map>()) {
            final item = Map<String, dynamic>.from(row);
            final id = (item['campaign_id'] ?? item['id'])?.toString() ?? '';
            if (id.isNotEmpty) merged[id] = item;
          }
          for (final item in campaigns) {
            final id = (item['campaign_id'] ?? item['id'])?.toString() ?? '';
            if (id.isEmpty) continue;
            final remote = merged[id];
            final localIsPendingSync = item['pending_sync'] == true;
            final localUpdated = DateTime.tryParse(
              item['updated_at']?.toString() ?? item['created_at']?.toString() ?? '',
            );
            final remoteUpdated = remote == null
                ? null
                : DateTime.tryParse(
                    remote['updated_at']?.toString() ?? remote['created_at']?.toString() ?? '',
                  );
            if (remote == null ||
                localIsPendingSync ||
                (localUpdated != null &&
                    (remoteUpdated == null || localUpdated.isAfter(remoteUpdated)))) {
              merged[id] = item;
            }
          }
          campaigns = merged.values.toList()
            ..sort((a, b) => (b['updated_at'] ?? b['created_at'] ?? '').toString()
                .compareTo((a['updated_at'] ?? a['created_at'] ?? '').toString()));
          if (campaigns.length > 20) campaigns = campaigns.take(20).toList();
          await prefs.setString(_campaignStorageKey, jsonEncode(campaigns));
        }
      } catch (_) {
        // Remote history is optional; keep the local offline workspace intact.
      }

      if (!mounted) return;
      setState(() {
        _shopController.text = shopName.isEmpty ? 'My Shop' : shopName;
        _shopDetails = shopDetails;
        _automationEnabled = automationEnabled;
        _autoNewProducts = autoNewProducts;
        _autoWeekly = autoWeekly;
        _weeklyDay = weeklyDay.clamp(0, 6);
        _products = products;
        _campaigns = campaigns;
        _selectedProductKey = products.isEmpty ? null : _productKey(products.first, 0);
        _loading = false;
      });

      // Retry local-first drafts that could not reach the API during an offline session.
      final pendingSyncDrafts = campaigns
          .where((item) => item['pending_sync'] == true)
          .take(10)
          .toList();
      for (final pendingDraft in pendingSyncDrafts) {
        if (!mounted) break;
        await _persistCampaign(pendingDraft);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Could not load shop data. You can still create a general shop ad.';
      });
    }
  }

  bool get _hasUnsavedCampaignEdits {
    final draft = _currentDraft;
    if (draft == null) return false;
    final savedDiscount = draft['discount_price'] is num
        ? (draft['discount_price'] as num).toDouble()
        : null;
    final enteredDiscountText = _discountPriceController.text.trim();
    final enteredDiscount = enteredDiscountText.isEmpty
        ? null
        : double.tryParse(enteredDiscountText);
    final savedProductId = draft['product_id']?.toString() ?? '';
    final selectedProduct = _selectedProduct;
    final selectedRawId = selectedProduct?['id'] ?? selectedProduct?['product_id'];
    final selectedProductId = selectedRawId?.toString() ?? '';
    return
        _shopController.text.trim() != (draft['shop_name']?.toString() ?? '') ||
        _headlineController.text.trim() != (draft['headline']?.toString() ?? '') ||
        _captionController.text.trim() != (draft['caption']?.toString() ?? '') ||
        _offerController.text.trim() != (draft['offer']?.toString() ?? '') ||
        enteredDiscount != savedDiscount ||
        _offerValidUntilController.text.trim() != (draft['offer_valid_until']?.toString() ?? '') ||
        _goal != (draft['goal']?.toString() ?? 'nearby') ||
        _language != (draft['language']?.toString() ?? 'en') ||
        _template != (draft['template']?.toString() ?? 'bold') ||
        _adFormat != (draft['ad_format']?.toString() ?? 'feed') ||
        selectedProductId != savedProductId;
  }

  Map<String, dynamic>? get _selectedProduct {
    if (_selectedProductKey == null) return null;
    for (var i = 0; i < _products.length; i++) {
      if (_productKey(_products[i], i) == _selectedProductKey) {
        return _products[i];
      }
    }
    return null;
  }

  Future<void> _persistCampaign(Map<String, dynamic> campaign) async {
    final id = campaign['id']?.toString() ?? campaign['campaign_id']?.toString();
    if (id == null || id.isEmpty) return;
    final localDraft = Map<String, dynamic>.from(campaign)
      ..['id'] = id
      ..['campaign_id'] = id
      ..['pending_sync'] = true
      ..['requires_owner_review'] = true;
    _campaigns.removeWhere(
      (item) => (item['campaign_id'] ?? item['id'])?.toString() == id,
    );
    _campaigns.insert(0, localDraft);
    if (_campaigns.length > 20) {
      _campaigns = _campaigns.take(20).toList();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_campaignStorageKey, jsonEncode(_campaigns));
    if (mounted) setState(() {});

    // Local-first persistence keeps the campaign available offline. The server
    // re-reads shop and product facts using the authenticated owner's identity.
    try {
      final rawProductId = localDraft['product_id'];
      final discountValue = localDraft['discount_price'];
      final response = await ApiClient.postJson(
        '/growth/marketing/campaigns',
        <String, dynamic>{
          'campaign_id': id,
          'goal': localDraft['goal']?.toString() ?? 'nearby',
          'language': localDraft['language']?.toString() ?? 'en',
          'ad_format': localDraft['ad_format']?.toString() ?? 'feed',
          'template': localDraft['template']?.toString() ?? 'bold',
          'product_id': rawProductId == null ? null : int.tryParse(rawProductId.toString()),
          'product_name': localDraft['product_name']?.toString() ?? '',
          'product_price': localDraft['product_price'] == null
              ? null
              : _number(localDraft['product_price']),
          'discount_price': discountValue == null
              ? null
              : _number(discountValue),
          'offer_valid_until': localDraft['offer_valid_until']?.toString(),
          'headline': localDraft['headline']?.toString() ?? '',
          'caption': localDraft['caption']?.toString() ?? '',
          'offer': localDraft['offer']?.toString() ?? '',
          'offer_code': localDraft['offer_code']?.toString() ?? '',
          'generation_source': localDraft['generation_source']?.toString() ?? 'manual',
          'trigger_type': localDraft['trigger_type']?.toString() ?? 'manual',
          'submit_for_approval': true,
          'redemptions': _number(localDraft['redemptions']).toInt(),
        },
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          final remote = Map<String, dynamic>.from(decoded)
            ..['tracking_mode'] = 'manual_local'
            ..['product_price'] ??= localDraft['product_price']
            ..['pending_sync'] = false
            ..['requires_owner_review'] = true;
          _campaigns.removeWhere(
            (item) => (item['campaign_id'] ?? item['id'])?.toString() == id,
          );
          _campaigns.insert(0, remote);
          if (_currentDraft != null &&
              (_currentDraft!['campaign_id'] ?? _currentDraft!['id'])?.toString() == id) {
            _currentDraft = remote;
          }
          if (_campaigns.length > 20) {
            _campaigns = _campaigns.take(20).toList();
          }
          await prefs.setString(_campaignStorageKey, jsonEncode(_campaigns));
          if (mounted) setState(() {});
        } else {
          _showMessage('Campaign saved locally. Server response was not recognized; approval sync is pending.');
        }
      } else {
        _showMessage('Campaign saved locally. Server approval sync is pending.');
      }
    } catch (_) {
      // Keep a local pending-sync marker; the next refresh will retry this draft.
    }
  }

  String _shopAddressText() {
    final canonicalAddress = (_shopDetails['address'] ?? '').toString().trim();
    final values = <String>[
      _shopDetails['address_line1']?.toString() ?? '',
      _shopDetails['address_line2']?.toString() ?? '',
      _shopDetails['location']?.toString() ?? '',
      _shopDetails['city']?.toString() ?? '',
      _shopDetails['state']?.toString() ?? '',
      _shopDetails['postal_code']?.toString() ?? '',
    ].map((value) => value.trim()).where((value) => value.isNotEmpty).toList();
    final unique = <String>[];
    if (canonicalAddress.isNotEmpty) unique.add(canonicalAddress);
    for (final value in values) {
      if (value.isEmpty) continue;
      final alreadyIncluded = unique.any(
        (existing) => existing.toLowerCase().contains(value.toLowerCase()),
      );
      if (!alreadyIncluded) unique.add(value);
    }
    return unique.join(', ');
  }

  String _shopPhoneText() =>
      (_shopDetails['phone'] ?? _shopDetails['phone_number'] ?? '').toString().trim();

  String _formatDate(DateTime value) =>
      value.year.toString().padLeft(4, '0') + '-' +
      value.month.toString().padLeft(2, '0') + '-' +
      value.day.toString().padLeft(2, '0');

  Future<void> _saveAutomationSettings({
    bool? enabled,
    bool? newProductsEnabled,
    bool? weeklyEnabled,
    int? weeklyDay,
  }) async {
    final previousEnabled = _automationEnabled;
    final previousNewProducts = _autoNewProducts;
    final previousWeekly = _autoWeekly;
    final previousWeeklyDay = _weeklyDay;
    final nextEnabled = enabled ?? _automationEnabled;
    final nextNewProducts = newProductsEnabled ?? _autoNewProducts;
    final nextWeekly = weeklyEnabled ?? _autoWeekly;
    final nextWeeklyDay = weeklyDay ?? _weeklyDay;
    setState(() {
      _automationEnabled = nextEnabled;
      _autoNewProducts = nextNewProducts;
      _autoWeekly = nextWeekly;
      _weeklyDay = nextWeeklyDay;
    });
    try {
      final response = await ApiClient.putJson(
        '/growth/marketing/automation/settings',
        <String, dynamic>{
          'enabled': nextEnabled,
          'new_products_enabled': nextNewProducts,
          'weekly_enabled': nextWeekly,
          'weekly_day': nextWeeklyDay,
          'language': _language,
          'max_campaigns_per_week': 3,
        },
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw StateError('Could not save marketing automation settings.');
      }
      _showMessage(
        nextEnabled
            ? 'Automatic draft generation is enabled. Every generated campaign still needs owner approval.'
            : 'Automatic draft generation is paused.',
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _automationEnabled = previousEnabled;
          _autoNewProducts = previousNewProducts;
          _autoWeekly = previousWeekly;
          _weeklyDay = previousWeeklyDay;
        });
      }
      _showMessage('Could not save automation settings. Check your connection and try again.');
    }
  }

  Widget _automationSettingsCard() {
    const days = <String>[
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Automatic campaign drafts',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 4),
          const Text(
            'Retail Mind can prepare drafts from shop events. It never publishes without your approval.',
            style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable marketing automation'),
            subtitle: const Text('Master switch for automatic draft generation'),
            value: _automationEnabled,
            onChanged: _busy ? null : (value) => _saveAutomationSettings(enabled: value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('New product drafts'),
            subtitle: const Text('Prepare a draft when a new in-stock product is added'),
            value: _autoNewProducts,
            onChanged: !_automationEnabled || _busy
                ? null
                : (value) => _saveAutomationSettings(newProductsEnabled: value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Weekly shop promotion'),
            subtitle: const Text('Prepare at most one weekly product highlight'),
            value: _autoWeekly,
            onChanged: !_automationEnabled || _busy
                ? null
                : (value) => _saveAutomationSettings(weeklyEnabled: value),
          ),
          if (_automationEnabled && _autoWeekly)
            DropdownButtonFormField<int>(
              value: _weeklyDay.clamp(0, 6),
              decoration: const InputDecoration(
                labelText: 'Weekly draft day',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: List<DropdownMenuItem<int>>.generate(
                days.length,
                (index) => DropdownMenuItem<int>(
                  value: index,
                  child: Text(days[index]),
                ),
              ),
              onChanged: _busy || !_automationEnabled
                  ? null
                  : (value) {
                      if (value != null) _saveAutomationSettings(weeklyDay: value);
                    },
            ),
          const SizedBox(height: 4),
          const Text(
            'Default limit: 3 automatic drafts per rolling 7 days. New drafts appear in Campaign approvals.',
            style: TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Future<void> _generateCampaign() async {
    if (_busy) return;
    final shop = _shopController.text.trim();
    if (shop.isEmpty) {
      _showMessage('Enter your shop name first.');
      return;
    }

    final product = _selectedProduct;
    final productName = product?['name']?.toString() ?? '';
    final originalPrice = _productPrice(product);
    final rawProductId = product?['id'] ?? product?['product_id'];
    final productId = rawProductId == null ? null : int.tryParse(rawProductId.toString());
    final discountText = _discountPriceController.text.trim();
    double? discountPrice;
    if (discountText.isNotEmpty) {
      discountPrice = double.tryParse(discountText);
      if (discountPrice == null || !discountPrice.isFinite || discountPrice < 0) {
        _showMessage('Enter a valid discounted price.');
        return;
      }
      if (productId == null || originalPrice == null) {
        _showMessage('Select a server-synced product with a verified price before adding a discount.');
        return;
      }
      if (discountPrice >= originalPrice) {
        _showMessage('Discounted price must be lower than the original product price.');
        return;
      }
    }

    DateTime? offerValidUntil;
    final validUntilText = _offerValidUntilController.text.trim();
    if (validUntilText.isNotEmpty) {
      offerValidUntil = DateTime.tryParse(validUntilText);
      if (offerValidUntil == null) {
        _showMessage('Enter the offer end date as YYYY-MM-DD.');
        return;
      }
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final expiryDate = DateTime(offerValidUntil.year, offerValidUntil.month, offerValidUntil.day);
      if (expiryDate.isBefore(todayDate)) {
        _showMessage('Offer end date cannot be in the past.');
        return;
      }
      if (discountPrice == null) {
        _showMessage('Enter a discounted price before setting an offer end date.');
        return;
      }
    }

    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final code = GrowthAdCopy.offerCode(now);
      final offerText = _offerController.text.trim();
      var headline = GrowthAdCopy.headline(_goal, _language);
      var caption = GrowthAdCopy.caption(
        shopName: shop,
        goal: _goal,
        language: _language,
        productName: productName,
        price: discountPrice ?? originalPrice,
        offer: offerText,
        offerCode: code,
      );
      final locationText = _shopAddressText();
      final phoneText = _shopPhoneText();
      final discountPercent = GrowthMarketingPricing.discountPercent(
        originalPrice,
        discountPrice,
      );
      if (discountPrice != null && originalPrice != null && discountPercent != null) {
        caption += '\nOriginal price: ₹' + originalPrice.toStringAsFixed(2);
        caption += '\nDiscounted price: ₹' + discountPrice.toStringAsFixed(2);
        caption += '\n' + discountPercent.toStringAsFixed(2) + '% OFF';
      }
      if (offerValidUntil != null) {
        caption += '\nOffer valid until: ' + _formatDate(offerValidUntil);
      }
      if (locationText.isNotEmpty) caption += '\nShop location: ' + locationText;
      if (phoneText.isNotEmpty) caption += '\nContact: ' + phoneText;

      var generationSource = 'local_template';
      var authoritativeShopName = shop;
      var authoritativeShopDetails = Map<String, dynamic>.from(_shopDetails);
      var authoritativeProductId = productId;
      var authoritativeOriginalPrice = originalPrice;
      var authoritativeDiscountPrice = discountPrice;
      double? authoritativeDiscountPercent;
      authoritativeDiscountPercent = GrowthMarketingPricing.discountPercent(
        originalPrice,
        discountPrice,
      );

      try {
        final response = await ApiClient.postJson(
          '/growth/marketing/generate',
          <String, dynamic>{
            'goal': _goal,
            'language': _language,
            'ad_format': _adFormat,
            'product_id': productId,
            'product_name': productName,
            'offer': offerText,
            'offer_code': code,
            'discount_price': discountPrice,
            'offer_valid_until': offerValidUntil == null ? null : _formatDate(offerValidUntil),
          },
        ).timeout(const Duration(seconds: 18));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map) {
            final data = Map<String, dynamic>.from(decoded);
            final serverHeadline = data['headline']?.toString().trim() ?? '';
            final serverCaption = data['caption']?.toString().trim() ?? '';
            if (serverHeadline.isNotEmpty && serverCaption.isNotEmpty) {
              headline = serverHeadline;
              caption = serverCaption;
              generationSource = data['generation_source']?.toString() ?? 'server';
              authoritativeShopName = data['shop_name']?.toString() ?? shop;
              authoritativeProductId = int.tryParse(data['product_id']?.toString() ?? '') ?? productId;
              if (data['shop_details'] is Map) {
                authoritativeShopDetails = Map<String, dynamic>.from(data['shop_details'] as Map);
              }
              authoritativeOriginalPrice = data['original_price'] is num
                  ? (data['original_price'] as num).toDouble()
                  : originalPrice;
              authoritativeDiscountPrice = data['discount_price'] is num
                  ? (data['discount_price'] as num).toDouble()
                  : discountPrice;
              authoritativeDiscountPercent = data['discount_percent'] is num
                  ? (data['discount_percent'] as num).toDouble()
                  : authoritativeDiscountPercent;
              offerValidUntil = DateTime.tryParse(data['offer_valid_until']?.toString() ?? '') ?? offerValidUntil;
            }
          }
        } else if (discountPrice != null) {
          String detail = 'The server could not verify this discount. Check the product price and try again.';
          try {
            final body = jsonDecode(response.body);
            if (body is Map && body['detail'] != null) detail = body['detail'].toString();
          } catch (_) {}
          throw StateError(detail);
        }
      } catch (error) {
        if (discountPrice != null) {
          _showMessage(error is StateError ? error.message : 'Discount verification is unavailable. Try again when online.');
          return;
        }
        // A no-discount campaign can still be drafted offline using the last
        // loaded shop profile. It remains local and requires owner review.
      }

      final draft = <String, dynamic>{
        'id': now.microsecondsSinceEpoch.toString(),
        'shop_name': authoritativeShopName,
        'shop_details': authoritativeShopDetails,
        'goal': _goal,
        'language': _language,
        'template': _template,
        'ad_format': _adFormat,
        'product_id': authoritativeProductId,
        'product_name': productName,
        'product_price': authoritativeOriginalPrice,
        'original_price': authoritativeOriginalPrice,
        'discount_price': authoritativeDiscountPrice,
        'discount_percent': authoritativeDiscountPercent,
        'offer_valid_until': offerValidUntil == null ? null : _formatDate(offerValidUntil),
        'headline': headline,
        'caption': caption,
        'offer': offerText,
        'offer_code': code,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'redemptions': 0,
        'tracking_mode': 'manual_local',
        'generation_source': generationSource,
        'trigger_type': authoritativeDiscountPrice != null || offerText.isNotEmpty ? 'owner_offer' : 'manual',
        'content_version': 1,
        'status': 'PENDING_APPROVAL',
        'pending_sync': true,
        'requires_owner_review': true,
      };

      _shopDetails = authoritativeShopDetails;
      _shopController.text = authoritativeShopName;
      _discountPriceController.text = authoritativeDiscountPrice == null
          ? ''
          : authoritativeDiscountPrice.toString();
      _offerValidUntilController.text = offerValidUntil == null ? '' : _formatDate(offerValidUntil);
      _currentDraft = draft;
      _headlineController.text = headline;
      _captionController.text = caption;
      await _persistCampaign(draft);

      _showMessage(
        generationSource == 'groq'
            ? 'AI campaign draft generated. Review the shop details, price and discount before approving.'
            : generationSource == 'template_fallback'
                ? 'Campaign draft generated with verified shop data. Review it before approving.'
                : 'Campaign draft saved. Review it before approving.',
      );
    } catch (error) {
      _showMessage(error is StateError ? error.message : 'Campaign draft could not be generated or saved.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Map<String, dynamic>?> _saveCurrentEdits() async {
    final current = _currentDraft;
    if (current == null) return null;

    final shopName = _shopController.text.trim();
    final offer = _offerController.text.trim();
    final selectedProduct = _selectedProduct;
    final selectedRawId = selectedProduct?['id'] ?? selectedProduct?['product_id'];
    final selectedProductId = selectedRawId == null ? null : int.tryParse(selectedRawId.toString());
    final savedProductId = current['product_id'] == null ? null : int.tryParse(current['product_id'].toString());
    final productChanged = selectedProductId != savedProductId;
    final productName = productChanged
        ? (selectedProduct?['name']?.toString() ?? '')
        : (current['product_name']?.toString() ?? '');
    final originalPrice = productChanged
        ? _productPrice(selectedProduct)
        : current['original_price'] is num
            ? (current['original_price'] as num).toDouble()
            : current['product_price'] is num
                ? (current['product_price'] as num).toDouble()
                : null;

    final discountText = _discountPriceController.text.trim();
    double? discountPrice;
    if (discountText.isNotEmpty) {
      discountPrice = double.tryParse(discountText);
      if (discountPrice == null ||
          originalPrice == null ||
          discountPrice < 0 ||
          discountPrice >= originalPrice ||
          selectedProductId == null) {
        _showMessage('Select a server-synced product and enter a valid lower discounted price.');
        return null;
      }
    }
    DateTime? offerValidUntil;
    if (_offerValidUntilController.text.trim().isNotEmpty) {
      offerValidUntil = DateTime.tryParse(_offerValidUntilController.text.trim());
      if (offerValidUntil == null || discountPrice == null) {
        _showMessage('Enter a valid offer end date and discounted price.');
        return null;
      }
      final now = DateTime.now();
      if (DateTime(offerValidUntil.year, offerValidUntil.month, offerValidUntil.day)
          .isBefore(DateTime(now.year, now.month, now.day))) {
        _showMessage('Offer end date cannot be in the past.');
        return null;
      }
    }

    var caption = _captionController.text.trim();
    final originalCaption = current['caption']?.toString().trim() ?? '';
    final captionWasNotManuallyEdited = caption == originalCaption;
    final shopChanged = shopName != (current['shop_name']?.toString() ?? '');
    final offerChanged = offer != (current['offer']?.toString() ?? '');
    final discountChanged = discountPrice != (current['discount_price'] is num ? (current['discount_price'] as num).toDouble() : null);
    final dateText = offerValidUntil == null ? '' : _formatDate(offerValidUntil);
    final dateChanged = dateText != (current['offer_valid_until']?.toString() ?? '');
    if (captionWasNotManuallyEdited &&
        (shopChanged || offerChanged || discountChanged || dateChanged || productChanged)) {
      caption = GrowthAdCopy.caption(
        shopName: shopName,
        goal: current['goal']?.toString() ?? 'nearby',
        language: current['language']?.toString() ?? 'en',
        productName: productName,
        price: discountPrice ?? originalPrice,
        offer: offer,
        offerCode: current['offer_code']?.toString() ?? '',
      );
      final percent = GrowthMarketingPricing.discountPercent(originalPrice, discountPrice);
      if (discountPrice != null && originalPrice != null && percent != null) {
        caption += '\nOriginal price: ₹' + originalPrice.toStringAsFixed(2);
        caption += '\nDiscounted price: ₹' + discountPrice.toStringAsFixed(2);
        caption += '\n' + percent.toStringAsFixed(2) + '% OFF';
      }
      if (offerValidUntil != null) caption += '\nOffer valid until: ' + dateText;
      final address = _shopAddressText();
      final phone = _shopPhoneText();
      if (address.isNotEmpty) caption += '\nShop location: ' + address;
      if (phone.isNotEmpty) caption += '\nContact: ' + phone;
      _captionController.text = caption;
    }

    final updated = Map<String, dynamic>.from(current)
      ..['shop_name'] = shopName
      ..['product_id'] = selectedProductId
      ..['product_name'] = productName
      ..['original_price'] = originalPrice
      ..['product_price'] = originalPrice
      ..['discount_price'] = discountPrice
      ..['discount_percent'] = GrowthMarketingPricing.discountPercent(originalPrice, discountPrice)
      ..['offer_valid_until'] = offerValidUntil == null ? null : dateText
      ..['headline'] = _headlineController.text.trim()
      ..['caption'] = caption
      ..['offer'] = offer
      ..['template'] = _template
      ..['ad_format'] = _adFormat
      ..['content_version'] = (_number(current['content_version']).toInt()).clamp(1, 2147483646) + 1
      ..['approved_version'] = null
      ..['approved_by'] = null
      ..['approved_at'] = null
      ..['status'] = 'PENDING_APPROVAL'
      ..['updated_at'] = DateTime.now().toIso8601String()
      ..['requires_owner_review'] = true
      ..['pending_sync'] = true;
    _currentDraft = updated;
    await _persistCampaign(updated);
    return updated;
  }

  Future<void> _approveCampaign(Map<String, dynamic> campaign) async {
    if (_busy) return;
    if (_currentDraft != null &&
        ((_currentDraft!['campaign_id'] ?? _currentDraft!['id'])?.toString() ==
            (campaign['campaign_id'] ?? campaign['id'])?.toString()) &&
        _hasUnsavedCampaignEdits) {
      final saved = await _saveCurrentEdits();
      if (saved != null) {
        _showMessage('Your edits were saved as a new pending version. Review that version and approve it separately.');
      }
      return;
    }
    final id = (campaign['campaign_id'] ?? campaign['id'])?.toString() ?? '';
    final version = _number(campaign['content_version']).toInt();
    if (id.isEmpty || version < 1 || campaign['pending_sync'] == true) {
      _showMessage('Sync this campaign with the server before approving it.');
      return;
    }
    setState(() => _busy = true);
    try {
      final response = await ApiClient.postJson(
        '/growth/marketing/campaigns/' + Uri.encodeComponent(id) + '/approve',
        <String, dynamic>{'expected_version': version},
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw StateError('Approval failed. Refresh the campaign and review its latest version.');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw StateError('The approval response was not recognized.');
      final approved = Map<String, dynamic>.from(decoded)..['pending_sync'] = false;
      _campaigns.removeWhere((item) => (item['campaign_id'] ?? item['id'])?.toString() == id);
      _campaigns.insert(0, approved);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_campaignStorageKey, jsonEncode(_campaigns));
      if (_currentDraft != null && (_currentDraft!['id'] ?? _currentDraft!['campaign_id'])?.toString() == id) {
        _currentDraft = approved;
      }
      if (mounted) setState(() {});
      _showMessage('Campaign approved. You can now share the approved poster manually.');
    } catch (error) {
      _showMessage(error is StateError ? error.message : 'Could not approve this campaign.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rejectCampaign(Map<String, dynamic> campaign) async {
    if (_busy) return;
    final id = (campaign['campaign_id'] ?? campaign['id'])?.toString() ?? '';
    final version = _number(campaign['content_version']).toInt();
    if (id.isEmpty || version < 1 || campaign['pending_sync'] == true) {
      _showMessage('Sync this campaign with the server before rejecting it.');
      return;
    }
    setState(() => _busy = true);
    try {
      final response = await ApiClient.postJson(
        '/growth/marketing/campaigns/' + Uri.encodeComponent(id) + '/reject',
        <String, dynamic>{
          'expected_version': version,
          'reason': 'Owner rejected after reviewing the campaign.',
        },
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw StateError('Rejection failed. Refresh the campaign and try again.');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw StateError('The rejection response was not recognized.');
      final rejected = Map<String, dynamic>.from(decoded)..['pending_sync'] = false;
      _campaigns.removeWhere((item) => (item['campaign_id'] ?? item['id'])?.toString() == id);
      _campaigns.insert(0, rejected);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_campaignStorageKey, jsonEncode(_campaigns));
      if (_currentDraft != null && (_currentDraft!['id'] ?? _currentDraft!['campaign_id'])?.toString() == id) {
        _currentDraft = rejected;
      }
      if (mounted) setState(() {});
      _showMessage('Campaign rejected. It will not be eligible for sharing until a new version is reviewed.');
    } catch (error) {
      _showMessage(error is StateError ? error.message : 'Could not reject this campaign.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sharePoster() async {
    if (_busy || _currentDraft == null) return;
    setState(() => _busy = true);
    try {
      await _saveCurrentEdits();
      await WidgetsBinding.instance.endOfFrame;
      final renderObject =
          _posterKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('Advertisement preview is not ready yet.');
      }

      // Keep exported artwork at social-ad resolution regardless of the
      // device's logical preview width (feed 1080×1350; Story 1080×1920).
      final logicalWidth = renderObject.size.width;
      final pixelRatio = logicalWidth > 0
          ? (1080.0 / logicalWidth).clamp(2.0, 5.0).toDouble()
          : math.max(3.0, MediaQuery.of(context).devicePixelRatio).toDouble();
      final image = await renderObject.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) throw StateError('Could not render poster image.');

      final Uint8List bytes = byteData.buffer.asUint8List();
      final directory = await getTemporaryDirectory();
      final id = _currentDraft!['id'].toString();
      final file = File(
        directory.path + '/retailmind_ad_' + id + '.png',
      );
      await file.writeAsBytes(bytes, flush: true);

      final shareText = _captionController.text.trim();
      await Share.shareXFiles(
        <XFile>[XFile(file.path)],
        text: shareText,
        subject: 'Advertisement from ' + _shopController.text.trim(),
      );
    } catch (error) {
      _showMessage('Could not share the poster. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareCaption(Map<String, dynamic> campaign) async {
    final caption = campaign['caption']?.toString() ?? '';
    try {
      await Share.share(
        caption,
        subject: 'Advertisement from ' +
            (campaign['shop_name']?.toString() ?? 'Retail Mind'),
      );
    } catch (_) {
      _showMessage('Could not open the share menu.');
    }
  }

  Future<void> _markRedeemed(Map<String, dynamic> campaign) async {
    final updated = Map<String, dynamic>.from(campaign);
    updated['redemptions'] =
        (_number(updated['redemptions']).toInt()) + 1;
    await _persistCampaign(updated);
    _showMessage(
      'Manual redemption count updated on this device. Checkout is not connected to this tracking code.',
    );
  }
  void _openCampaignForEditing(Map<String, dynamic> campaign) {
    final draft = Map<String, dynamic>.from(campaign);
    final productName = draft['product_name']?.toString() ?? '';
    final draftPrice = draft['product_price'] is num
        ? (draft['product_price'] as num).toDouble()
        : null;
    String? matchingProductKey;
    for (var i = 0; i < _products.length; i++) {
      final product = _products[i];
      final sameName =
          (product['name']?.toString() ?? '') == productName;
      final currentPrice = _productPrice(product);
      final samePrice = draftPrice == null ||
          (currentPrice != null &&
              (currentPrice - draftPrice).abs() < 0.001);
      if (productName.isNotEmpty && sameName && samePrice) {
        matchingProductKey = _productKey(product, i);
        break;
      }
    }

    setState(() {
      _currentDraft = draft;
      _shopController.text = draft['shop_name']?.toString() ?? 'My Shop';
      _shopDetails = draft['shop_details'] is Map
          ? Map<String, dynamic>.from(draft['shop_details'] as Map)
          : _shopDetails;
      _offerController.text = draft['offer']?.toString() ?? '';
      _discountPriceController.text = draft['discount_price']?.toString() ?? '';
      _offerValidUntilController.text = draft['offer_valid_until']?.toString() ?? '';
      _headlineController.text = draft['headline']?.toString() ?? '';
      _captionController.text = draft['caption']?.toString() ?? '';
      final goal = draft['goal']?.toString() ?? 'nearby';
      _goal = const {
        'nearby',
        'new_product',
        'clear_stock',
        'regular_customers',
      }.contains(goal)
          ? goal
          : 'nearby';
      final language = draft['language']?.toString() ?? 'en';
      _language = const {'en', 'te', 'hi'}.contains(language)
          ? language
          : 'en';
      final savedTemplate = draft['template']?.toString() ?? 'bold';
      _template = const {'bold', 'festive', 'fresh', 'minimal'}
              .contains(savedTemplate)
          ? savedTemplate
          : 'bold';
      final savedFormat = draft['ad_format']?.toString() ?? 'feed';
      _adFormat = const {'feed', 'square', 'story'}.contains(savedFormat)
          ? savedFormat
          : 'feed';
      _selectedProductKey = matchingProductKey ?? '';
    });
    _showMessage(
      matchingProductKey == null && productName.isNotEmpty
          ? 'Draft reopened. Its saved product details may be out of date; check stock and price before sharing.'
          : 'Draft reopened. Review it before sharing.',
    );
  }


  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final draftStatus = _currentDraft?['status']?.toString() ?? '';
    final draftVersion = _number(_currentDraft?['content_version']).toInt();
    final isApproved = draftStatus == 'APPROVED' &&
        draftVersion > 0 &&
        _number(_currentDraft?['approved_version']).toInt() == draftVersion &&
        !_hasUnsavedCampaignEdits;
    final needsApproval = draftStatus == 'PENDING_APPROVAL';
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const LiveTranslatedText(
          'Grow My Shop',
          style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context).translate('Refresh shop data'),
            onPressed: _loading ? null : _loadWorkspace,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadWorkspace,
              color: _purple,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _hero(),
                  const SizedBox(height: 14),
                  _automationSettingsCard(),
                  const SizedBox(height: 16),
                  if (_message.isNotEmpty) ...[
                    _notice(_message),
                    const SizedBox(height: 12),
                  ],
                  _sectionTitle('1. Tell us about your promotion',
                      'The free assistant uses your real in-stock products.'),
                  const SizedBox(height: 10),
                  _buildCampaignForm(),
                  const SizedBox(height: 18),
                  _sectionTitle('2. Preview and edit your advertisement',
                      'Check every price and offer before sharing.'),
                  const SizedBox(height: 10),
                  if (_currentDraft == null)
                    _emptyPreview()
                  else
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: Column(
                        key: ValueKey<String>(_currentDraft!['id'].toString()),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _posterPreview(),
                          const SizedBox(height: 12),
                          _editFields(),
                          const SizedBox(height: 12),
                          if (needsApproval) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: const Text(
                                'Review this exact campaign version. Sharing is disabled until the owner approves it.',
                                style: TextStyle(color: Color(0xFF92400E), fontSize: 12),
                              ),
                            ),
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              onPressed: _busy ? null : () => _approveCampaign(_currentDraft!),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Approve campaign'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF15803D),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : () => _rejectCampaign(_currentDraft!),
                              icon: const Icon(Icons.cancel_outlined),
                              label: const Text('Reject campaign'),
                            ),
                          ] else if (isApproved) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFBBF7D0)),
                              ),
                              child: const Text(
                                'Approved version. You can now share this poster manually.',
                                style: TextStyle(color: Color(0xFF166534), fontSize: 12),
                              ),
                            ),
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              onPressed: _busy ? null : _sharePoster,
                              icon: _busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.share_rounded),
                              label: Text(_busy ? 'Preparing poster…' : 'Share approved poster'),
                              style: FilledButton.styleFrom(
                                backgroundColor: _purple,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : () => _shareCaption(_currentDraft!),
                              icon: const Icon(Icons.text_snippet_outlined),
                              label: const Text('Share approved caption'),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: const Text(
                                'This campaign is not approved. Save it to the server and submit it for owner review before sharing.',
                                style: TextStyle(color: _muted, fontSize: 12),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  _sectionTitle('3. Campaign approvals and history',
                      'Review pending drafts and see which campaign versions were approved.'),
                  const SizedBox(height: 10),
                  _campaignHistory(),
                  const SizedBox(height: 16),
                  _notice(
                    'Free mode: posters and captions are generated locally. '
                    'Sharing is manual. No paid ads are started and no bulk messages are sent. '
                    'Offer codes here are for manual tracking only; they are not automatically '
                    'redeemed at checkout.',
                  ),
                ],
              ),
            ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF11183F), Color(0xFF5428B8), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x224C1D95),
            blurRadius: 22,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 30),
              SizedBox(width: 10),
              Expanded(
                child: const LiveTranslatedText(
                  'Your free marketing helper',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 9),
          const LiveTranslatedText(
            'Create a shop poster, add your real products, and share it with customers. No ad budget needed.',
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LiveTranslatedText(title,
            style: const TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            )),
        const SizedBox(height: 3),
        LiveTranslatedText(subtitle, style: const TextStyle(color: _muted, fontSize: 12)),
      ],
    );
  }

  Widget _buildCampaignForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _shopController,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              label: LiveTranslatedText('Shop name'),
              prefixIcon: Icon(Icons.storefront_rounded),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Shop details on poster', style: TextStyle(fontWeight: FontWeight.w800, color: _ink)),
                const SizedBox(height: 5),
                Text(
                  _shopAddressText().isEmpty ? 'Add your shop address in Shop Profile to show its location.' : _shopAddressText(),
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
                if (_shopPhoneText().isNotEmpty)
                  Text(_shopPhoneText(), style: const TextStyle(fontSize: 12, color: _muted)),
                if (_shopAddressText().isEmpty)
                  TextButton(
                    onPressed: () => _showMessage('Open Shop Profile and save your shop address, city and PIN code.'),
                    child: const Text('Shop profile details needed'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _goal,
            isExpanded: true,
            decoration: const InputDecoration(
              label: LiveTranslatedText('What do you want to achieve?'),
              prefixIcon: Icon(Icons.flag_outlined),
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'nearby',
                child: LiveTranslatedText('Attract nearby customers'),
              ),
              DropdownMenuItem(
                value: 'new_product',
                child: LiveTranslatedText('Promote a product'),
              ),
              DropdownMenuItem(
                value: 'clear_stock',
                child: LiveTranslatedText('Promote available stock'),
              ),
              DropdownMenuItem(
                value: 'regular_customers',
                child: LiveTranslatedText('Invite regular customers back'),
              ),
            ],
            onChanged: _busy
                ? null
                : (value) {
                    if (value != null) setState(() => _goal = value);
                  },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _language,
            decoration: const InputDecoration(
              label: LiveTranslatedText('Advertisement language'),
              prefixIcon: Icon(Icons.translate_rounded),
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'te', child: Text('తెలుగు (Telugu)')),
              DropdownMenuItem(value: 'hi', child: Text('हिन्दी (Hindi)')),
            ],
            onChanged: _busy
                ? null
                : (value) {
                    if (value != null) setState(() => _language = value);
                  },
          ),
          const SizedBox(height: 16),
          _buildTemplatePicker(),
          const SizedBox(height: 12),
          _buildAdFormatPicker(),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedProductKey,
            isExpanded: true,
            decoration: InputDecoration(
              label: const LiveTranslatedText('Feature an in-stock product (optional)'),
              prefixIcon: const Icon(Icons.inventory_2_outlined),
              border: const OutlineInputBorder(),
                helper: LiveTranslatedText(_products.isEmpty
                  ? 'No in-stock products loaded. You can still create a general shop ad.'
                  : _products.length.toString() + ' in-stock products available'),
            ),
            items: <DropdownMenuItem<String>>[
              const DropdownMenuItem<String>(
                value: '',
                child: LiveTranslatedText('General shop ad — no specific product'),
              ),
              ..._products.asMap().entries.map((entry) {
              final product = entry.value;
              final key = _productKey(product, entry.key);
              final price = _productPrice(product);
              final priceLabel = price == null
                  ? ''
                  : ' · ₹' +
                      (price == price.truncateToDouble()
                          ? price.toStringAsFixed(0)
                          : price.toStringAsFixed(2));
              return DropdownMenuItem<String>(
                value: key,
                child: Text(
                  product['name'].toString() + priceLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
            ],
            onChanged: _busy || _products.isEmpty
                ? null
                : (value) => setState(() {
                      _selectedProductKey = value;
                      _discountPriceController.clear();
                      _offerValidUntilController.clear();
                    }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _offerController,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            maxLength: 90,
            decoration: const InputDecoration(
              label: LiveTranslatedText('Offer details (optional)'),
              hint: LiveTranslatedText('Only enter a discount if you really offer it'),
              prefixIcon: Icon(Icons.local_offer_outlined),
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _discountPriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Discounted price (₹, optional)',
              prefixIcon: const Icon(Icons.sell_outlined),
              border: const OutlineInputBorder(),
              helperText: _selectedProduct == null || _productPrice(_selectedProduct) == null
                  ? 'Select a server-synced product to validate a discount.'
                  : 'Original inventory price: ₹' + _productPrice(_selectedProduct)!.toStringAsFixed(2),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _offerValidUntilController,
            keyboardType: TextInputType.datetime,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Offer valid until (YYYY-MM-DD)',
              hintText: '2026-12-31',
              prefixIcon: Icon(Icons.event_outlined),
              border: OutlineInputBorder(),
              helperText: 'Optional. Only applies when a discounted price is entered.',
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _busy ? null : _generateCampaign,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const LiveTranslatedText('Create free ad'),
            style: FilledButton.styleFrom(
              backgroundColor: _purple,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _templateColors(String template) {
    switch (template) {
      case 'festive':
        return const [Color(0xFF7F1D1D), Color(0xFFDC2626), Color(0xFFF97316)];
      case 'fresh':
        return const [Color(0xFF064E3B), Color(0xFF059669), Color(0xFF84CC16)];
      case 'minimal':
        return const [Color(0xFFF8FAFC), Color(0xFFFFFFFF)];
      default:
        return const [Color(0xFF101638), Color(0xFF4C1D95), Color(0xFF7C3AED)];
    }
  }

  Widget _buildTemplatePicker() {
    const templates = <Map<String, String>>[
          {'id': 'bold', 'name': 'Bold gradient', 'subtitle': 'Big headline'},
      {'id': 'festive', 'name': 'Festive offer', 'subtitle': 'Bright & punchy'},
      {'id': 'fresh', 'name': 'Fresh & local', 'subtitle': 'Friendly colours'},
          {'id': 'minimal', 'name': 'Clean minimal', 'subtitle': 'Product first'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LiveTranslatedText(
          'Choose an ad design',
          style: TextStyle(
            color: _ink,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const LiveTranslatedText(
          'Switch designs any time before sharing.',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: templates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 9),
            itemBuilder: (context, index) {
              final entry = templates[index];
              final id = entry['id']!;
              final selected = _template == id;
              final colors = _templateColors(id);
              return InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: _busy
                    ? null
                    : () {
                        setState(() {
                          _template = id;
                          if (_currentDraft != null) {
                            _currentDraft = Map<String, dynamic>.from(
                              _currentDraft!,
                            )..['template'] = id;
                          }
                        });
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 126,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFEEF2FF) : Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: selected ? _purple : const Color(0xFFE2E8F0),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: id == 'minimal'
                                ? const Color(0xFFF8FAFC)
                                : null,
                            gradient: id == 'minimal'
                                ? null
                                : LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: colors,
                                  ),
                            borderRadius: BorderRadius.circular(9),
                            border: id == 'minimal'
                                ? Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  )
                                : null,
                          ),
                          padding: const EdgeInsets.all(7),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: 28,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: id == 'minimal'
                                      ? const Color(0xFF111827)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              Container(
                                width: id == 'festive' ? 58 : 43,
                                height: 13,
                                decoration: BoxDecoration(
                                  color: id == 'minimal'
                                      ? const Color(0xFFBE123C)
                                      : (id == 'festive'
                                          ? const Color(0xFFFDE68A)
                                          : Colors.white.withValues(alpha: 0.86)),
                                  borderRadius: BorderRadius.circular(
                                    id == 'festive' ? 3 : 5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      LiveTranslatedText(
                        entry['name']!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _ink,
                          fontSize: 10.5,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      LiveTranslatedText(
                        entry['subtitle']!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 9.5),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAdFormatPicker() {
    return DropdownButtonFormField<String>(
      value: _adFormat,
      decoration: const InputDecoration(
        label: LiveTranslatedText('Ad placement / image size'),
        prefixIcon: Icon(Icons.aspect_ratio_rounded),
        border: OutlineInputBorder(),
        helper: LiveTranslatedText(
          'Exports target 1080px wide: feed ads, square posts, or vertical Stories/Status.',
        ),
      ),
      items: const [
        DropdownMenuItem(
          value: 'feed',
          child: LiveTranslatedText('Feed ad · 4:5 · 1080×1350'),
        ),
        DropdownMenuItem(
          value: 'square',
          child: LiveTranslatedText('Square ad · 1:1 · 1080×1080'),
        ),
        DropdownMenuItem(
          value: 'story',
          child: LiveTranslatedText('Story / Status · 9:16 · 1080×1920'),
        ),
      ],
      onChanged: _busy
          ? null
          : (value) {
              if (value == null) return;
              setState(() {
                _adFormat = value;
                if (_currentDraft != null) {
                  _currentDraft = Map<String, dynamic>.from(_currentDraft!)
                      ..['ad_format'] = value;
                }
              });
            },
    );
  }

  Widget _emptyPreview() {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
            color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(Icons.campaign_outlined, size: 44, color: _purple),
          SizedBox(height: 10),
          const LiveTranslatedText(
                'Your advertisement will appear here',
            style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 5),
          const LiveTranslatedText(
                'Choose your goal and tap Create free ad.',
            style: TextStyle(color: _muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _posterPreview() {
    final product = _currentDraft!['product_name']?.toString() ?? '';
    final price = _currentDraft!['product_price'] is num
            ? (_currentDraft!['product_price'] as num).toDouble()
        : null;
    final discountText = _discountPriceController.text.trim();
    final editedDiscount = discountText.isEmpty ? null : double.tryParse(discountText);
    final previewDiscount = discountText.isEmpty
        ? (_currentDraft!['discount_price'] is num
            ? (_currentDraft!['discount_price'] as num).toDouble()
            : null)
        : editedDiscount;
    final previewDiscountPercent = GrowthMarketingPricing.discountPercent(price, previewDiscount);
    final width = math.min(360.0, MediaQuery.of(context).size.width - 48.0).toDouble();
    final template = _currentDraft!['template']?.toString() ?? _template;
    final format = _currentDraft!['ad_format']?.toString() ?? _adFormat;
    final heightFactor = switch (format) {
      'square' => 1.0,
      'story' => 16 / 9,
      _ => 5 / 4,
    };
    return Center(
      child: RepaintBoundary(
        key: _posterKey,
        child: SizedBox(
          width: width,
          height: width * heightFactor,
          child: _PosterArtwork(
            template: template,
            format: format,
            shopName: _shopController.text.trim().isEmpty
                    ? 'My Shop'
                : _shopController.text.trim(),
            headline: _headlineController.text.trim(),
            productName: product,
            price: price,
            discountPrice: previewDiscount,
            discountPercent: previewDiscountPercent,
            offerValidUntil: _offerValidUntilController.text.trim(),
            shopAddress: _shopAddressText(),
            shopPhone: _shopPhoneText(),
            offer: _offerController.text.trim(),
            offerCode: _currentDraft!['offer_code'].toString(),
            language: _currentDraft!['language']?.toString() ?? 'en',
          ),
        ),
      ),
    );
  }

  Widget _editFields() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _headlineController,
            maxLength: 80,
            decoration: const InputDecoration(
              label: LiveTranslatedText('Poster headline'),
              counterText: '',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _captionController,
            minLines: 3,
            maxLines: 6,
            maxLength: 1200,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              label: LiveTranslatedText('Caption to share'),
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _busy ? null : _saveCurrentEdits,
              icon: const Icon(Icons.save_outlined),
              label: const LiveTranslatedText('Save edits'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campaignHistory() {
    if (_campaigns.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const LiveTranslatedText(
          'Your campaign drafts and approvals will show here.',
          style: TextStyle(color: _muted),
        ),
      );
    }
    return Column(
      children: _campaigns.map((campaign) {
        final product = campaign['product_name']?.toString() ?? '';
        final code = campaign['offer_code']?.toString() ?? '';
        final status = campaign['status']?.toString() ?? 'DRAFT';
        final campaignId = (campaign['campaign_id'] ?? campaign['id'])?.toString() ?? '';
        final date = DateTime.tryParse(campaign['created_at']?.toString() ?? '');
        final dateLabel = date == null
            ? ''
            : date.day.toString().padLeft(2, '0') + '/' +
                date.month.toString().padLeft(2, '0') + '/' +
                date.year.toString();
        final redemptions = _number(campaign['redemptions']).toInt();
        final discountPrice = campaign['discount_price'] is num
            ? (campaign['discount_price'] as num).toDouble()
            : null;
        final originalPrice = campaign['original_price'] is num
            ? (campaign['original_price'] as num).toDouble()
            : campaign['product_price'] is num
                ? (campaign['product_price'] as num).toDouble()
                : null;
        final canApprove = status == 'PENDING_APPROVAL' && campaign['pending_sync'] != true;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
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
                      color: const Color(0xFFF0EBFF),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.campaign_rounded, color: _purple),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          campaign['headline']?.toString() ?? 'Shop advertisement',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _ink, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          (product.isEmpty ? 'Shop promotion' : product) +
                              (dateLabel.isEmpty ? '' : ' · ' + dateLabel),
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _statusChip(status),
                ],
              ),
              const SizedBox(height: 9),
              if (discountPrice != null && originalPrice != null)
                Text(
                  '₹' + originalPrice.toStringAsFixed(2) + ' → ₹' + discountPrice.toStringAsFixed(2) +
                      ' · ' + _number(campaign['discount_percent']).toStringAsFixed(2) + '% OFF',
                  style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w700, fontSize: 12),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (code.isNotEmpty) _chip('Code: ' + code, Icons.confirmation_number_outlined),
                  _chip('Redemptions: ' + redemptions.toString(), Icons.local_offer_outlined),
                  if (campaign['pending_sync'] == true)
                    _chip('Sync pending', Icons.sync_problem_outlined),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: () => _openCampaignForEditing(campaign),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Open campaign'),
                  ),
                  if (canApprove)
                    TextButton.icon(
                      onPressed: _busy ? null : () => _approveCampaign(campaign),
                      icon: const Icon(Icons.check_circle_outline, color: Color(0xFF15803D)),
                      label: const Text('Approve'),
                    ),
                  if (canApprove)
                    TextButton.icon(
                      onPressed: _busy ? null : () => _rejectCampaign(campaign),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Reject'),
                    ),
                  if (status == 'APPROVED')
                    TextButton.icon(
                      onPressed: () => _shareCaption(campaign),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share caption'),
                    ),
                  if (status == 'APPROVED')
                    TextButton.icon(
                      onPressed: () => _markRedeemed(campaign),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('Record redemption'),
                    ),
                ],
              ),
              if (campaignId.isEmpty)
                const Text('This local draft needs a campaign ID before it can sync.', style: TextStyle(color: _muted, fontSize: 11)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _statusChip(String status) {
    final Color background;
    final Color foreground;
    switch (status) {
      case 'APPROVED':
        background = const Color(0xFFDCFCE7);
        foreground = const Color(0xFF166534);
        break;
      case 'PENDING_APPROVAL':
        background = const Color(0xFFFEF3C7);
        foreground = const Color(0xFF92400E);
        break;
      case 'REJECTED':
        background = const Color(0xFFFEE2E2);
        foreground = const Color(0xFF991B1B);
        break;
      default:
        background = const Color(0xFFF1F5F9);
        foreground = const Color(0xFF475569);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Text(status.replaceAll('_', ' '), style: TextStyle(color: foreground, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
  Widget _chip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _purple),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11, color: _ink)),
        ],
      ),
    );
  }

  Widget _notice(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFF1D4ED8), size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: LiveTranslatedText(
              message,
              style: const TextStyle(
                color: Color(0xFF1E40AF),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterArtwork extends StatelessWidget {
  const _PosterArtwork({
    required this.shopName,
    required this.headline,
    required this.productName,
    required this.price,
    required this.discountPrice,
    required this.discountPercent,
    required this.offerValidUntil,
    required this.shopAddress,
    required this.shopPhone,
    required this.offer,
    required this.offerCode,
    required this.language,
    required this.template,
    required this.format,
  });

  final String shopName;
  final String headline;
  final String productName;
  final double? price;
  final double? discountPrice;
  final double? discountPercent;
  final String offerValidUntil;
  final String shopAddress;
  final String shopPhone;
  final String offer;
  final String offerCode;
  final String language;
  final String template;
  final String format;

  @override
  Widget build(BuildContext context) {
    final isFestive = template == 'festive';
    final isFresh = template == 'fresh';
    final isMinimal = template == 'minimal';
    final isStory = format == 'story';
    final isSquare = format == 'square';
    final hasProduct = productName.trim().isNotEmpty;
    final hasOffer = offer.trim().isNotEmpty || discountPrice != null;
    final colors = isFestive
        ? const [Color(0xFF7F1D1D), Color(0xFFDC2626), Color(0xFFF97316)]
        : isFresh
            ? const [Color(0xFF064E3B), Color(0xFF059669), Color(0xFF84CC16)]
            : const [Color(0xFF101638), Color(0xFF4C1D95), Color(0xFF7C3AED)];
    final textColor = isMinimal ? const Color(0xFF111827) : Colors.white;
    final mutedColor = isMinimal ? const Color(0xFF475569) : Colors.white70;
    final accentColor = isFestive
        ? const Color(0xFFFDE68A)
        : isFresh
            ? const Color(0xFFD9F99D)
            : isMinimal
                ? const Color(0xFFBE123C)
                : const Color(0xFFFDE68A);
    final accentTextColor = isFestive || !isMinimal
        ? const Color(0xFF422006)
        : Colors.white;
    final cardColor = isMinimal
        ? const Color(0xFFF8FAFC)
        : Colors.white.withValues(alpha: 0.13);
    final cardBorder = isMinimal
        ? const Color(0xFFCBD5E1)
        : Colors.white.withValues(alpha: 0.28);
    final cornerRadius = isFestive ? 8.0 : isMinimal ? 4.0 : 18.0;
    final visitLabel = language == 'te'
        ? 'ఈరోజే సందర్శించండి'
        : language == 'hi'
            ? 'आज ही आएँ'
            : 'VISIT US TODAY';
    final offerCodeLabel = language == 'te'
        ? 'ఆఫర్ కోడ్'
        : language == 'hi'
            ? 'ऑफ़र कोడ్'
            : 'Offer code';
    final badgeLabel = isFestive
        ? (hasOffer
            ? (language == 'te' ? 'ప్రత్యేక ఆఫర్' : language == 'hi' ? 'खास ऑफ़र' : 'SPECIAL OFFER')
            : (language == 'te' ? 'షాప్ ప్రమోషన్' : language == 'hi' ? 'दुकान प्रमोशन' : 'SHOP PROMOTION'))
        : isFresh
            ? (language == 'te' ? 'మీ స్థానిక దుకాణం' : language == 'hi' ? 'आपकी स्थानीय दुकान' : 'YOUR LOCAL SHOP')
            : isMinimal
                ? (language == 'te' ? 'దుకాణ సమాచారం' : language == 'hi' ? 'दुकान की जानकारी' : 'SHOP UPDATE')
                : (language == 'te' ? 'దుకాణ ప్రత్యేకతలు' : language == 'hi' ? 'दुकान की खास बातें' : 'SHOP HIGHLIGHTS');
    final displayPrice = discountPrice ?? price;
    final priceText = displayPrice == null
        ? ''
        : '₹' +
            (displayPrice == displayPrice.truncateToDouble()
                ? displayPrice.toStringAsFixed(0)
                : displayPrice.toStringAsFixed(2));
    final originalPriceText = price == null
        ? ''
        : '₹' +
            (price == price.truncateToDouble()
                ? price.toStringAsFixed(0)
                : price.toStringAsFixed(2));
    final discountLabel = discountPercent == null
        ? ''
        : discountPercent!.toStringAsFixed(discountPercent! % 1 == 0 ? 0 : 2) + '% OFF';

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: isMinimal
            ? const BoxDecoration(color: Colors.white)
            : BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
              ),
        child: Stack(
          children: [
            if (!isMinimal)
              Positioned(
                right: isStory ? -68 : -42,
                top: isStory ? -58 : -34,
                child: Container(
                  width: isStory ? 230 : 180,
                  height: isStory ? 230 : 180,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: isFestive ? 0.10 : 0.09),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            if (isMinimal)
              Positioned(
                left: -48,
                bottom: -54,
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFCE7F3),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.all(isStory ? 26 : isSquare ? 13 : 21),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: isStory ? 48 : 40,
                        height: isStory ? 48 : 40,
                        decoration: BoxDecoration(
                          color: isMinimal
                              ? const Color(0xFF111827)
                              : Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(isMinimal ? 8 : 13),
                        ),
                        child: Icon(
                          isFresh
                              ? Icons.eco_rounded
                              : isFestive
                                  ? Icons.celebration_rounded
                                  : isMinimal
                                      ? Icons.storefront_rounded
                                      : Icons.shopping_bag_rounded,
                          color: isMinimal ? Colors.white : accentColor,
                          size: isStory ? 28 : 24,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          shopName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w900,
                            fontSize: isStory ? 21 : 17,
                            height: 1.05,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isStory ? 28 : isSquare ? 8 : 18),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isFestive ? 10 : 11,
                      vertical: isStory ? 9 : isSquare ? 4 : 7,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(cornerRadius),
                    ),
                    child: Text(
                      badgeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accentTextColor,
                        fontSize: isStory ? 11 : isSquare ? 8 : 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: isMinimal ? 0.4 : 1.0,
                      ),
                    ),
                  ),
                  SizedBox(height: isSquare ? 7 : 14),
                  Text(
                    headline.isEmpty ? 'Your neighbourhood shop' : headline,
                    maxLines: isStory ? 4 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      height: 1.04,
                      fontSize: isStory ? 34 : isSquare ? 21 : isMinimal ? 26 : 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: isStory ? 24 : isSquare ? 7 : 15),
                  if (hasProduct)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isStory ? 17 : isSquare ? 8 : 13),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(cornerRadius),
                        border: Border.all(color: cardBorder),
                      ),
                      child: isMinimal
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  productName,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: isStory ? 20 : 16,
                                    height: 1.15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (priceText.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    priceText,
                                    style: TextStyle(
                                      color: accentColor,
                                      fontWeight: FontWeight.w900,
                                      fontSize: isStory ? 30 : 24,
                                    ),
                                  ),
                                ],
                              ],
                            )
                          : Row(
                              children: [
                                Icon(
                                  Icons.local_mall_rounded,
                                  color: accentColor,
                                  size: isStory ? 38 : isSquare ? 23 : 32,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    productName,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: isStory ? 18 : isSquare ? 11 : 15,
                                      height: 1.1,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (priceText.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      priceText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: accentColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: isStory ? 22 : isSquare ? 14 : 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                  if (discountPrice != null && originalPriceText.isNotEmpty) ...[
                    SizedBox(height: isSquare ? 4 : 8),
                    Row(
                      children: [
                        Text(
                          originalPriceText,
                          style: TextStyle(
                            color: mutedColor,
                            fontSize: isSquare ? 8 : 11,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSquare ? 6 : 9,
                            vertical: isSquare ? 3 : 5,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            discountLabel,
                            style: TextStyle(
                              color: accentTextColor,
                              fontWeight: FontWeight.w900,
                              fontSize: isSquare ? 8 : 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (hasOffer) ...[
                    SizedBox(height: isSquare ? 6 : 11),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: isStory ? 13 : isSquare ? 5 : 9,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(cornerRadius),
                      ),
                      child: Text(
                        offer,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accentTextColor,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                          fontSize: isStory ? 16 : isSquare ? 10 : 13,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Divider(color: isMinimal ? const Color(0xFFE2E8F0) : Colors.white30),
                  Text(
                    visitLabel,
                    style: TextStyle(
                      color: mutedColor,
                      fontSize: isStory ? 13 : isSquare ? 8.5 : 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: isMinimal ? 0.9 : 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    shopName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: isStory ? 15 : isSquare ? 10 : 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (shopAddress.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        shopAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: mutedColor, fontSize: isSquare ? 6.5 : 8.5, height: 1.1),
                      ),
                    ),
                  if (shopPhone.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        shopPhone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: mutedColor, fontSize: isSquare ? 6.5 : 8.5),
                      ),
                    ),
                  if (offerValidUntil.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Valid until: ' + offerValidUntil,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: mutedColor, fontSize: isSquare ? 6.5 : 8.5),
                      ),
                    ),
                  if (hasOffer) ...[
                    const SizedBox(height: 5),
                    Text(
                      offerCodeLabel + ': ' + offerCode,
                      style: TextStyle(
                        color: mutedColor,
                        fontWeight: FontWeight.w700,
                        fontSize: isStory ? 12 : isSquare ? 8 : 10,
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    'Made with Retail Mind',
                    style: TextStyle(
                      color: mutedColor,
                      fontSize: isSquare ? 7 : 8.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
