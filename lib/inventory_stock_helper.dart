import 'dart:convert';

import 'cache_consistency_service.dart';

/// Shared parsing and stock-field handling for inventory API responses.
class InventoryStockHelper {
  static const List<String> _envelopeKeys = [
    'data',
    'products',
    'results',
    'items',
  ];

  /// Parse product lists returned directly or wrapped in common API envelopes.
  ///
  /// Supports nested envelopes and JSON-encoded strings (including a string
  /// nested inside a `data` or `products` field). Malformed responses throw
  /// instead of quietly presenting an empty inventory.
  static List<Map<String, dynamic>> parseProductsResponse(dynamic response) {
    dynamic value = response;

    for (var depth = 0; depth < 8; depth++) {
      if (value is String) {
        try {
          value = jsonDecode(value);
          continue;
        } on FormatException {
          throw const FormatException(
            'Inventory response contained invalid JSON-encoded data.',
          );
        }
      }

      if (value is List) {
        return normalizeProducts(value);
      }

      if (value is Map) {
        dynamic wrapped;
        var foundEnvelope = false;
        for (final key in _envelopeKeys) {
          if (value.containsKey(key) && value[key] != null) {
            wrapped = value[key];
            foundEnvelope = true;
            break;
          }
        }
        if (foundEnvelope) {
          value = wrapped;
          continue;
        }

        final productKeys = <String>{
          'id',
          'product_id',
          'backend_id',
          'server_id',
          'product_name',
          'name',
          'sku',
          'barcode',
        };
        if (value.keys.any((key) => productKeys.contains(key.toString()))) {
          return <Map<String, dynamic>>[
            normalizeProduct(Map<String, dynamic>.from(value)),
          ];
        }
      }

      throw const FormatException(
        'Inventory response was not a product list or supported envelope.',
      );
    }

    throw const FormatException(
      'Inventory response nesting exceeded the supported limit.',
    );
  }

  /// API uses stock/quantity, while some UI components use current_stock.
  static double readStock(Map<String, dynamic> product) {
    for (final key in [
      'current_stock',
      'stock',
      'quantity',
      'qty',
      'available_stock',
    ]) {
      final value = product[key];
      if (value == null) continue;
      final number = double.tryParse(value.toString());
      if (number != null && number.isFinite) return number;
    }
    return 0;
  }

  /// Minimum threshold shared by inventory screens and alert calculations.
  /// Missing legacy values retain the app's established default of 10.
  static double readMinimumStock(
    Map<String, dynamic> product, {
    double fallback = 10,
  }) {
    for (final key in const [
      'min_stock',
      'minStock',
      'minimum_stock',
      'minimumStock',
    ]) {
      final value = product[key];
      if (value == null) continue;
      final parsed = double.tryParse(value.toString());
      if (parsed != null && parsed.isFinite && parsed >= 0) return parsed;
    }
    return fallback;
  }

  static bool isOutOfStock(Map<String, dynamic> product) =>
      readStock(product) <= 0;

  /// "Low stock" is a positive balance at/below the reorder threshold.
  /// Zero or negative balances belong to the separate "Out of Stock" group.
  static bool isLowStock(Map<String, dynamic> product) {
    final stock = readStock(product);
    return stock > 0 && stock <= readMinimumStock(product);
  }

  static bool isInStock(Map<String, dynamic> product) {
    final stock = readStock(product);
    return stock > readMinimumStock(product);
  }

  static double? parseStockThresholdInput(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final parsed = double.tryParse(trimmed);
    if (parsed == null || !parsed.isFinite || parsed < 0) return null;
    return parsed;
  }

  static String _normalizeProductIdentity(Object? value) {
    return (value?.toString() ?? '')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
  }

  static List<Map<String, dynamic>> findDuplicateProducts(
    Iterable<dynamic> products, {
    required String productName,
    String? sku,
    int? excludeProductId,
  }) {
    final requestedName = _normalizeProductIdentity(productName);
    final requestedSku = _normalizeProductIdentity(sku);
    final matches = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final raw in products) {
      if (raw is! Map) continue;
      final product = Map<String, dynamic>.from(raw);
      final id = (product['id'] ?? product['product_id'] ?? '').toString();
      if (excludeProductId != null && id == excludeProductId.toString()) continue;

      final active = product['is_active'] != false;
      final existingName = _normalizeProductIdentity(product['product_name'] ?? product['name']);
      final existingSku = _normalizeProductIdentity(product['sku'] ?? product['barcode']);
      final types = <String>[];
      if (active && requestedName.isNotEmpty && existingName == requestedName) {
        types.add('PRODUCT_NAME');
      }
      if (requestedSku.isNotEmpty && existingSku == requestedSku) {
        types.add('BARCODE');
      }
      if (types.isEmpty) continue;

      final identity = id.isEmpty ? '$existingName|$existingSku' : id;
      if (seen.add(identity)) matches.add({'match_types': types, 'product': product});
    }
    return matches;
  }

  static void writeStock(Map<String, dynamic> product, double value) {
    product['current_stock'] = value;
    product['stock'] = value;
    product['quantity'] = value;
  }

  static Map<String, dynamic> normalizeProduct(Map<String, dynamic> raw) {
    final product = Map<String, dynamic>.from(raw);

    // Preserve the canonical backend identity for update/delete operations.
    final canonicalId =
        product['id'] ??
        product['product_id'] ??
        product['backend_id'] ??
        product['server_id'];
    if (canonicalId != null && canonicalId.toString().trim().isNotEmpty) {
      product['id'] = canonicalId;
      product['product_id'] ??= canonicalId;
    }

    final name =
        (product['product_name'] ?? product['name'] ?? product['product'] ?? '')
            .toString();
    if (name.isNotEmpty) product['product_name'] = name;

    writeStock(product, readStock(product));
    product['min_stock'] = readMinimumStock(product);
    return product;
  }

  static List<Map<String, dynamic>> normalizeProducts(List<dynamic> list) {
    return list
        .whereType<Map>()
        .map((entry) => normalizeProduct(Map<String, dynamic>.from(entry)))
        .toList();
  }

  static bool _isPendingLocalMutation(Map<String, dynamic> product) {
    return CacheConsistencyService.isPending(product) ||
        product['local_pending'] == true ||
        product['pending_sync'] == true;
  }

  /// Merge the authoritative API catalogue with cached records.
  ///
  /// Duplicate API product IDs collapse to one row. Unacknowledged local
  /// mutations remain visible, while acknowledged cached products absent from
  /// the server response are not resurrected indefinitely.
  static List<Map<String, dynamic>> mergeApiWithLocalCache(
    List<Map<String, dynamic>> apiList,
    List<Map<String, dynamic>> localList,
  ) {
    final localById = <String, Map<String, dynamic>>{};
    final deletedIds = <String>{};

    for (final raw in localList) {
      final product = normalizeProduct(Map<String, dynamic>.from(raw));
      final id =
          (product['id'] ??
                  product['product_id'] ??
                  product['sku'] ??
                  product['barcode'] ??
                  '')
              .toString()
              .trim();
      if (id.isEmpty) continue;

      if (product['is_deleted'] == true && _isPendingLocalMutation(product)) {
        deletedIds.add(id);
        localById.remove(id);
        continue;
      }

      localById[id] = product;
    }

    // De-duplicate incoming server rows by stable identity before merging.
    final apiById = <String, Map<String, dynamic>>{};
    final apiWithoutId = <Map<String, dynamic>>[];
    for (final raw in apiList) {
      final product = normalizeProduct(Map<String, dynamic>.from(raw));
      final id =
          (product['id'] ??
                  product['product_id'] ??
                  product['sku'] ??
                  product['barcode'] ??
                  '')
              .toString()
              .trim();
      if (id.isEmpty) {
        apiWithoutId.add(product);
        continue;
      }
      if (apiById.containsKey(id)) {
        apiById[id] = <String, dynamic>{...apiById[id]!, ...product};
      } else {
        apiById[id] = product;
      }
    }

    final merged = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final apiProduct in [...apiById.values, ...apiWithoutId]) {
      final id =
          (apiProduct['id'] ??
                  apiProduct['product_id'] ??
                  apiProduct['sku'] ??
                  apiProduct['barcode'] ??
                  '')
              .toString()
              .trim();

      if (id.isNotEmpty && deletedIds.contains(id)) {
        seen.add(id);
        continue;
      }

      final local = id.isEmpty ? null : localById[id];
      if (local != null) {
        final reconciled = CacheConsistencyService.mergeRecord(
          local,
          apiProduct,
          dataset: 'inventory',
        );
        merged.add(normalizeProduct(reconciled));
      } else {
        merged.add(apiProduct);
      }
      if (id.isNotEmpty) seen.add(id);
    }

    // Only keep cached records missing from the authoritative response when
    // they represent a pending local mutation. This avoids stale deleted stock
    // entries reappearing on every inventory refresh.
    for (final entry in localById.entries) {
      if (seen.contains(entry.key)) continue;
      if (_isPendingLocalMutation(entry.value)) merged.add(entry.value);
    }

    return merged;
  }
}
