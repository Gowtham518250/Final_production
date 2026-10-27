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
      product['unit_price'] =
          _number(product['unit_price'] ?? product['selling_price'] ?? product['price']);
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
    final price = product == null ? null : _number(product['unit_price']);
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
    final updated = Map<String, dynamic>.from(current)
      ..['shop_name'] = _shopController.text.trim()
      ..['headline'] = _headlineController.text.trim()
      ..['caption'] = _captionController.text.trim()
      ..['offer'] = _offerController.text.trim();
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

      final pixelRatio = math.max(2.0, MediaQuery.of(context).devicePixelRatio).toDouble();
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
              final price = _number(product['unit_price']);
              return DropdownMenuItem<String>(
                value: key,
                child: Text(
                  product['name'].toString() +
                      ' · ₹' +
                      (price == price.truncateToDouble()
                          ? price.toStringAsFixed(0)
                          : price.toStringAsFixed(2)),
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
    return Center(
      child: RepaintBoundary(
        key: _posterKey,
        child: SizedBox(
          width: width,
          height: width * 1.24,
          child: _PosterArtwork(
            shopName: _shopController.text.trim().isEmpty
                ? 'My Shop'
                : _shopController.text.trim(),
            headline: _headlineController.text.trim(),
            productName: product,
            price: price,
            offer: _offerController.text.trim(),
            offerCode: _currentDraft!['offer_code'].toString(),
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
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _markRedeemed(campaign),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Record redemption'),
                ),
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
  });

  final String shopName;
  final String headline;
  final String productName;
  final double? price;
  final String offer;
  final String offerCode;

  @override
  Widget build(BuildContext context) {
    final hasProduct = productName.trim().isNotEmpty;
    final priceText = price == null
        ? ''
        : '₹' +
            (price == price!.truncateToDouble()
                ? price!.toStringAsFixed(0)
                : price!.toStringAsFixed(2));

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF101638),
              Color(0xFF4C1D95),
              Color(0xFF7C3AED),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -50,
              top: -40,
              child: Container(
                width: 190,
                height: 190,
                decoration: const BoxDecoration(
                  color: Color(0x227C3AED),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.storefront_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          shopName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    headline.isEmpty ? 'Your neighbourhood shop' : headline,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      height: 1.08,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 15),
                  if (hasProduct)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_mall_rounded,
                              color: Color(0xFFFDE68A), size: 34),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              productName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (priceText.isNotEmpty)
                            Text(
                              priceText,
                              style: const TextStyle(
                                color: Color(0xFFFDE68A),
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (offer.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDE68A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        offer,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF422006),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  const Divider(color: Colors.white30),
                  Text(
                    'VISIT US TODAY',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Offer code: ' + offerCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Made with Retail Mind',
                    style: TextStyle(color: Colors.white60, fontSize: 9),
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
