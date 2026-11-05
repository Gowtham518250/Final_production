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

  static String _normalizeInventoryIdentity(Object? value) {
    return (value?.toString() ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s-]+'), '');
  }

  static Set<String> _productCodeValues(Map<String, dynamic> product) {
    final values = <String>{};
    for (final key in [
      'sku',
      'barcode',
      'bar_code',
      'barcode_number',
      'product_code',
    ]) {
      final value = _normalizeInventoryIdentity(product[key]);
      if (value.isNotEmpty) values.add(value);
    }
    return values;
  }

  static Set<String> _productIdentityKeys(Map<String, dynamic> product) {
    final keys = <String>{};
    final id = _normalizeInventoryIdentity(
      product['id'] ??
          product['product_id'] ??
          product['backend_id'] ??
          product['server_id'],
    );
    if (id.isNotEmpty) keys.add('id:$id');
    for (final code in _productCodeValues(product)) {
      keys.add('code:$code');
    }
    return keys;
  }

  /// Marks records written by the old Sales Entry price-learning callback.
  /// These are price hints, not inventory products.
  static bool isLegacySalesPriceLearningProduct(
    Map<String, dynamic> product,
  ) {
    return product['source']?.toString().trim().toLowerCase() ==
        'self-learned (direct entry)';
  }

  /// Remove the local copy after a successful create, supporting old records
  /// that stored a barcode but did not have a sku field.
  static Map<String, dynamic> removeLocalProductAfterCreate(
    Map<String, dynamic> localProducts,
    Map<dynamic, dynamic> payload,
  ) {
    final payloadCodes = _productCodeValues(
      Map<String, dynamic>.from(payload),
    );
    if (payloadCodes.isEmpty) {
      return Map<String, dynamic>.from(localProducts);
    }

    final remaining = Map<String, dynamic>.from(localProducts);
    remaining.removeWhere((key, value) {
      if (payloadCodes.contains(_normalizeInventoryIdentity(key))) {
        return true;
      }
      if (value is! Map) return false;
      final product = Map<String, dynamic>.from(value);
      return _productCodeValues(product).any(payloadCodes.contains);
    });
    return remaining;
  }

  /// Reconcile rows shown in Inventory. Backend rows are preferred over
  /// non-pending offline copies; pending local edits remain visible. A product
  /// code (SKU/barcode) takes precedence over its display name so two genuine
  /// variants with different barcodes are never collapsed just because their
  /// names happen to match.
  static List<Map<String, dynamic>> deduplicateProductsForDisplay(
    Iterable<dynamic> products,
  ) {
    final result = <Map<String, dynamic>>[];
    final indexByIdentity = <String, int>{};

    for (final raw in products) {
      if (raw is! Map) continue;
      final incoming = normalizeProduct(Map<String, dynamic>.from(raw));
      final keys = _productIdentityKeys(incoming);

      int? duplicateIndex;
      for (final key in keys) {
        final found = indexByIdentity[key];
        if (found != null) {
          duplicateIndex = found;
          break;
        }
      }

      if (duplicateIndex == null) {
        final newIndex = result.length;
        result.add(incoming);
        for (final key in keys) {
          indexByIdentity[key] = newIndex;
        }
        continue;
      }

      final existing = result[duplicateIndex];
      final existingPending = _isPendingLocalMutation(existing);
      final incomingPending = _isPendingLocalMutation(incoming);
      final existingOffline = existing['is_offline'] == true;
      final incomingOffline = incoming['is_offline'] == true;

      final preferIncoming = existingPending != incomingPending
          ? incomingPending
          : existingOffline != incomingOffline
              ? !incomingOffline
              : true;
      final merged = preferIncoming
          ? <String, dynamic>{...existing, ...incoming}
          : <String, dynamic>{...incoming, ...existing};

      // Do not retain an offline-only marker once a backend copy is present.
      if (!existingOffline || !incomingOffline) {
        merged.remove('is_offline');
      }
      final normalizedMerged = normalizeProduct(merged);
      result[duplicateIndex] = normalizedMerged;

      for (final key in _productIdentityKeys(normalizedMerged)) {
        indexByIdentity[key] = duplicateIndex;
      }
    }

    return result;
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

    return deduplicateProductsForDisplay(merged);
  }
}
