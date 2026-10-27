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
import 'growth_marketing_helpers.dart';
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
            for (final key in const [
              'shop_name',
              'business_name',
              'shopName',
              'name',
            ]) {
              final candidate = decoded[key]?.toString().trim() ?? '';
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

      if (!mounted) return;
      setState(() {
        _shopController.text = shopName.isEmpty ? 'My Shop' : shopName;
        _products = products;
        _campaigns = campaigns;
        _selectedProductKey = products.isEmpty ? null : _productKey(products.first, 0);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Could not load shop data. You can still create a general shop ad.';
      });
    }
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
    final id = campaign['id']?.toString();
    _campaigns.removeWhere((item) => item['id']?.toString() == id);
    _campaigns.insert(0, Map<String, dynamic>.from(campaign));
    if (_campaigns.length > 20) {
      _campaigns = _campaigns.take(20).toList();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_campaignStorageKey, jsonEncode(_campaigns));
    if (mounted) setState(() {});
  }

  Future<void> _generateCampaign() async {
    if (_busy) return;
    final shop = _shopController.text.trim();
    if (shop.isEmpty) {
      _showMessage('Enter your shop name first.');
      return;
    }

    final product = _selectedProduct;
    final now = DateTime.now();
    final code = GrowthAdCopy.offerCode(now);
    final goalText = _goal;
    final productName = product?['name']?.toString() ?? '';
    final price = _productPrice(product);
    final headline = GrowthAdCopy.headline(_goal, _language);
    final caption = GrowthAdCopy.caption(
      shopName: shop,
      goal: _goal,
      language: _language,
      productName: productName,
      price: price,
      offer: _offerController.text,
      offerCode: code,
    );

    final draft = <String, dynamic>{
      'id': now.microsecondsSinceEpoch.toString(),
      'shop_name': shop,
      'goal': goalText,
      'language': _language,
      'template': _template,
      'ad_format': _adFormat,
      'product_name': productName,
      'product_price': price,
      'headline': headline,
      'caption': caption,
      'offer': _offerController.text.trim(),
      'offer_code': code,
      'created_at': now.toIso8601String(),
      'redemptions': 0,
      'tracking_mode': 'manual_local',
    };

    setState(() {
      _currentDraft = draft;
      _headlineController.text = headline;
      _captionController.text = caption;
      _busy = true;
    });
    try {
      await _persistCampaign(draft);
      _showMessage('Ad draft saved on this device. No advertising spend used.');
    } catch (_) {
      _showMessage('Ad created, but the draft could not be saved.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Map<String, dynamic>?> _saveCurrentEdits() async {
    final current = _currentDraft;
    if (current == null) return null;

    final shopName = _shopController.text.trim();
    final offer = _offerController.text.trim();
    var caption = _captionController.text.trim();
    final originalCaption = current['caption']?.toString().trim() ?? '';
    final captionWasNotManuallyEdited = caption == originalCaption;
    final shopChanged = shopName != (current['shop_name']?.toString() ?? '');
    final offerChanged = offer != (current['offer']?.toString() ?? '');

    // Keep the default caption consistent with shop/offer edits. If the owner
    // has written a custom caption, preserve their wording.
    if (captionWasNotManuallyEdited && (shopChanged || offerChanged)) {
      final rawPrice = current['product_price'];
      final price = rawPrice is num ? rawPrice.toDouble() : null;
      caption = GrowthAdCopy.caption(
        shopName: shopName,
        goal: current['goal']?.toString() ?? 'nearby',
        language: current['language']?.toString() ?? 'en',
        productName: current['product_name']?.toString(),
        price: price,
        offer: offer,
        offerCode: current['offer_code']?.toString() ?? '',
      );
      _captionController.text = caption;
    }

    final updated = Map<String, dynamic>.from(current)
      ..['shop_name'] = shopName
      ..['headline'] = _headlineController.text.trim()
      ..['caption'] = caption
      ..['offer'] = offer
      ..['template'] = _template
      ..['ad_format'] = _adFormat;
    _currentDraft = updated;
    await _persistCampaign(updated);
    return updated;
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
      _offerController.text = draft['offer']?.toString() ?? '';
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'Grow My Shop',
          style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh shop data',
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
                            label: Text(_busy
                                ? 'Preparing poster…'
                                : 'Share poster and caption'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _purple,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _shareCaption(_currentDraft!),
                            icon: const Icon(Icons.text_snippet_outlined),
                            label: const Text('Share text only'),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  _sectionTitle('3. Your campaign history',
                      'Drafts are saved locally on this device.'),
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 30),
              SizedBox(width: 10),
              Expanded(
                child: Text(
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
          Text(
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
        Text(title,
            style: const TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            )),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12)),
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
              labelText: 'Shop name',
              prefixIcon: Icon(Icons.storefront_rounded),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _goal,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'What do you want to achieve?',
              prefixIcon: Icon(Icons.flag_outlined),
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'nearby',
                child: Text('Attract nearby customers'),
              ),
              DropdownMenuItem(
                value: 'new_product',
                child: Text('Promote a product'),
              ),
              DropdownMenuItem(
                value: 'clear_stock',
                child: Text('Promote available stock'),
              ),
              DropdownMenuItem(
                value: 'regular_customers',
                child: Text('Invite regular customers back'),
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
              labelText: 'Advertisement language',
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
              labelText: 'Feature an in-stock product (optional)',
              prefixIcon: const Icon(Icons.inventory_2_outlined),
              border: const OutlineInputBorder(),
              helperText: _products.isEmpty
                  ? 'No in-stock products loaded. You can still create a general shop ad.'
                  : _products.length.toString() + ' in-stock products available',
            ),
            items: <DropdownMenuItem<String>>[
              const DropdownMenuItem<String>(
                value: '',
                child: Text('General shop ad — no specific product'),
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
                : (value) => setState(() => _selectedProductKey = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _offerController,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            maxLength: 90,
            decoration: const InputDecoration(
              labelText: 'Offer details (optional)',
              hintText: 'Only enter a discount if you really offer it',
              prefixIcon: Icon(Icons.local_offer_outlined),
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _busy ? null : _generateCampaign,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Create free ad'),
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
        const Text(
          'Choose an ad design',
          style: TextStyle(
            color: _ink,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
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
                      Text(
                        entry['name']!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _ink,
                          fontSize: 10.5,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      Text(
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
        labelText: 'Ad placement / image size',
        prefixIcon: Icon(Icons.aspect_ratio_rounded),
        border: OutlineInputBorder(),
        helperText: 'Exports target 1080px wide: feed ads, square posts, or vertical Stories/Status.',
      ),
      items: const [
        DropdownMenuItem(
          value: 'feed',
          child: Text('Feed ad · 4:5 · 1080×1350'),
        ),
        DropdownMenuItem(
          value: 'square',
          child: Text('Square ad · 1:1 · 1080×1080'),
        ),
        DropdownMenuItem(
          value: 'story',
          child: Text('Story / Status · 9:16 · 1080×1920'),
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
      child: const Column(
        children: [
          Icon(Icons.campaign_outlined, size: 44, color: _purple),
          SizedBox(height: 10),
          Text(
            'Your advertisement will appear here',
            style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 5),
          Text(
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
              labelText: 'Poster headline',
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
            decoration: const InputDecoration(
              labelText: 'Caption to share',
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
              label: const Text('Save edits'),
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
        child: const Text(
          'Your saved advertisements will show here.',
          style: TextStyle(color: _muted),
        ),
      );
    }
    return Column(
      children: _campaigns.map((campaign) {
        final product = campaign['product_name']?.toString() ?? '';
        final code = campaign['offer_code']?.toString() ?? '';
        final date = DateTime.tryParse(campaign['created_at']?.toString() ?? '');
        final dateLabel = date == null
            ? ''
            : date.day.toString().padLeft(2, '0') +
                '/' +
                date.month.toString().padLeft(2, '0') +
                '/' +
                date.year.toString();
        final redemptions = _number(campaign['redemptions']).toInt();
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
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          (product.isEmpty ? 'Shop promotion' : product) +
                              (dateLabel.isEmpty ? '' : ' · ' + dateLabel),
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Share caption',
                    onPressed: () => _shareCaption(campaign),
                    icon: const Icon(Icons.share_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip('Code: ' + code, Icons.confirmation_number_outlined),
                  _chip('Redemptions: ' + redemptions.toString(),
                      Icons.local_offer_outlined),
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
                    label: const Text('Open draft'),
                  ),
                  TextButton.icon(
                    onPressed: () => _markRedeemed(campaign),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: const Text('Record redemption'),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
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
            child: Text(
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
    final hasOffer = offer.trim().isNotEmpty;
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
    final priceText = price == null
        ? ''
        : '₹' +
            (price == price!.truncateToDouble()
                ? price!.toStringAsFixed(0)
                : price!.toStringAsFixed(2));

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
