import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'stock_alert_service.dart';
import 'inventory_management_service.dart';
import 'secure_token_storage.dart';
import 'financial_math.dart';
import 'sync_queue_manager.dart';
import 'local_storage_service.dart';
import 'retail_growth_kit.dart';
import 'sync_service.dart';
import 'agent_debug_log.dart';
import 'crash_recovery_service.dart';
import 'smart_reorder_ai.dart';
import 'gst_calculator.dart';

/// PRODUCTION-READY SALE SERVICE: Integrated Idempotency, Encryption, and Error Handling
class SaleService {
  static final Set<String> _pendingSales = {};

  /// Best-effort local demand history for the Smart Reorder screen. Only
  /// product rows with stable backend IDs are recorded, and the sale ID makes
  /// this idempotent across retries. Forecast history never blocks billing.
  static Future<void> _recordLocalSalesVelocity({
    required String saleId,
    required List<Map<String, dynamic>> lineItems,
  }) async {
    try {
      final quantities = <int, double>{};
      for (final item in lineItems) {
        final productId =
            int.tryParse(item['product_id']?.toString() ?? '') ?? 0;
        final rawQuantity = item['quantity'] ?? item['qty'] ?? 0;
        final quantity = rawQuantity is num
            ? rawQuantity.toDouble()
            : double.tryParse(rawQuantity.toString()) ?? 0;
        if (productId <= 0 || quantity <= 0) continue;
        quantities[productId] = (quantities[productId] ?? 0) + quantity;
      }

      for (final entry in quantities.entries) {
        await SmartReorderAIService.recordSale(
          saleId: saleId,
          productId: entry.key,
          quantity: entry.value,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Smart reorder history was skipped: $e');
    }
  }

  /// FIX: the three call sites below used to each inline
  /// `paidAmount >= grandTotal - 0.5 ? 'PAID' : ...` — a flat 50-paise
  /// tolerance. That's wide enough that a customer who genuinely still owes
  /// up to 49 paise would be marked PAID. 0.01 (1 paisa) is enough to absorb
  /// real floating-point rounding noise without masking a real balance due.
  static String paymentStatusFor(double paidAmount, double grandTotal) {
    // Compare money at paise precision so floating-point noise cannot
    // incorrectly turn a genuinely unpaid balance into PAID.
    final paidPaise = (paidAmount * 100).round();
    final totalPaise = (grandTotal * 100).round();

    if (paidPaise >= totalPaise) return 'PAID';
    if (paidPaise > 0) return 'PARTIAL';
    return 'UNPAID';
  }

  @visibleForTesting
  static Map<String, dynamic> normalizeSaleLineItem(
    Map<String, dynamic> item, {
    int? resolvedProductId,
    bool withTax = true,
  }) {
    double number(dynamic value, double fallback) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    double money(double value) => double.parse(value.toStringAsFixed(2));

    final rawName =
        item['product_name'] ??
        item['itemName'] ??
        item['name'] ??
        item['title'] ??
        item['product'];
    final name = rawName?.toString().trim() ?? '';
    if (name.isEmpty ||
        name.toLowerCase() == 'unknown' ||
        name.toLowerCase() == 'unknown item') {
      throw const FormatException('Sale item requires a valid product name.');
    }

    final rawQty = number(item['quantity'] ?? item['qty'] ?? 1, 1);
    final rawPrice = number(item['price'] ?? item['unit_price'] ?? 0, 0);
    if (!rawQty.isFinite ||
        rawQty <= 0 ||
        !rawPrice.isFinite ||
        rawPrice <= 0) {
      throw const FormatException(
        'Sale item requires a positive finite quantity and price.',
      );
    }
    final quantity = double.parse(rawQty.toStringAsFixed(3));
    final price = money(rawPrice);
    if (price <= 0) {
      throw const FormatException(
        'Sale item price must be at least one paisa.',
      );
    }

    final grossLine = money(CurrencyManager.multiply(price, quantity));
    final rawDiscount = number(
      item['discount_amount'] ?? item['discount'] ?? 0,
      0,
    );
    if (!rawDiscount.isFinite || rawDiscount < 0) {
      throw const FormatException(
        'Sale item discount must be finite and non-negative.',
      );
    }
    final discount = money(rawDiscount.clamp(0.0, grossLine).toDouble());
    final lineTotal = money(
      (grossLine - discount).clamp(0.0, double.infinity).toDouble(),
    );

    final gstRate = number(item['gst_rate'] ?? item['gst'] ?? 0, 0);
    if (!gstRate.isFinite || gstRate < 0 || gstRate > 100) {
      throw const FormatException('GST rate must be between 0 and 100.');
    }
    final taxAmount = withTax
        ? GstCalculator.calculateItemGST(
            price: lineTotal,
            quantity: 1,
            gstRate: gstRate,
          ).totalGST
        : 0.0;
    final totalWithTax = money(lineTotal + taxAmount);

    final custom =
        item['stock_tracked'] == false || item['is_custom_item'] == true;
    final rawId =
        resolvedProductId ??
        (int.tryParse((item['product_id'] ?? item['id'] ?? '0').toString()) ??
            0);
    final productId = custom ? null : (rawId > 0 ? rawId : null);

    return <String, dynamic>{
      'product_id': productId,
      'product_name': name,
      'stock_tracked': !custom,
      'is_custom_item': custom,
      'quantity': quantity,
      'qty': quantity,
      'unit_price': price,
      'line_total': lineTotal,
      'total': lineTotal,
      'discount_amount': discount,
      'gst': gstRate,
      'gst_rate': gstRate,
      'tax_amount': taxAmount,
      'total_with_tax': totalWithTax,
    };
  }

  static Future<Map<String, dynamic>> submitSale({
    required String saleId,
    required List<Map<String, dynamic>> items,
    required double grandTotal,
    required double paidAmount,
    required String customerName,
    required String customerPhone,
    String customerAddress = '',
    required bool withTax,
    required Map<String, dynamic> totals,
    String paymentMethod = 'Cash',
    bool isBorrow = false,
    String? invoiceNumber,
    bool refreshDashboard = true,
  }) async {
    const String context = 'SALE_SUBMIT';
    final recordedPaidAmount = isBorrow ? 0.0 : paidAmount;

    if (_pendingSales.contains(saleId)) {
      if (kDebugMode)
        debugPrint(
          '🚨 Sale $saleId is already being processed - skipping duplicate',
        );
      return {
        'success': false,
        'error': 'DUPLICATE_REQUEST',
        'message': 'This sale is already being processed',
      };
    }

    InventoryManagementService.suppressInventoryCallback = true;

    final isSynced = await _isSaleSynced(saleId);
    if (isSynced) {
      if (kDebugMode)
        debugPrint('⚠️ Sale $saleId already synced to backend - skipping');
      InventoryManagementService.suppressInventoryCallback = false;
      return {
        'success': true,
        'syncCount': 0,
        'saleId': saleId,
        'status': 'ALREADY_SYNCED',
        'message': 'Sale already synced to backend',
      };
    }

    final stockValidation = await _validateStockAvailabilityLocally(items);
    if (!stockValidation['valid']) {
      InventoryManagementService.suppressInventoryCallback = false;
      return {
        'success': false,
        'error': 'INSUFFICIENT_STOCK',
        'message': stockValidation['message'],
        'insufficient_items': stockValidation['insufficient_items'],
      };
    }

    _pendingSales.add(saleId);

    AgentDebugLog.log(
      location: 'sale_service.dart:submitSale:entry',
      message: 'SALE CREATION START',
      hypothesisId: 'H1',
      data: {
        'saleId': saleId,
        'grandTotal': grandTotal,
        'paymentMethod': paymentMethod,
        'itemCount': items.length,
        'isBorrow': isBorrow,
      },
    );

    // Only clear the crash-recovery marker after both the queue write and local stock
    // update succeeded. Otherwise startup recovery still has the original sale payload.
    bool recoveryCanBeCleared = false;

    try {
      if (kDebugMode) {
        debugPrint(
          '🚀 Processing ${isBorrow ? 'Invoice/Borrow' : 'Sale'} Transaction (Offline-First): $saleId',
        );
      }

      // Stable offline_id = saleId so retries remain idempotent.
      final String offlineId = saleId;
      final String canonicalInvoiceNumber =
          (invoiceNumber ?? '').trim().isNotEmpty
          ? invoiceNumber!.trim()
          : saleId;

      final localProducts = await LocalStorageService.loadLocalProducts();

      final lineItems = items.map((item) {
        final custom =
            item['stock_tracked'] == false || item['is_custom_item'] == true;
        final rawId =
            int.tryParse(
              (item['product_id'] ?? item['id'] ?? '0').toString(),
            ) ??
            0;
        int productId = custom ? 0 : (rawId > 0 ? rawId : 0);

        if (!custom && productId == 0) {
          final itemName =
              (item['product_name'] ?? item['itemName'] ?? item['name'] ?? '')
                  .toString()
                  .trim();
          final barcode = (item['barcode'] ?? '').toString();
          final productsList = localProducts is List
              ? localProducts as List
              : localProducts.values.toList();
          for (final product in productsList) {
            final candidateId = (product['id'] ?? product['product_id'] ?? '')
                .toString();
            if (int.tryParse(candidateId) == null) continue;
            final candidateName =
                (product['product_name'] ?? product['name'] ?? '')
                    .toString()
                    .trim();
            final candidateSku = (product['sku'] ?? product['barcode'] ?? '')
                .toString();
            if ((barcode.isNotEmpty && candidateSku == barcode) ||
                candidateName.toLowerCase() == itemName.toLowerCase()) {
              productId = int.parse(candidateId);
              break;
            }
          }
        }

        return normalizeSaleLineItem(
          <String, dynamic>{
            ...item,
            'product_name':
                item['product_name'] ??
                item['itemName'] ??
                item['name'] ??
                item['title'] ??
                item['product'],
            'product_id': productId > 0 ? productId : null,
          },
          resolvedProductId: productId,
          withTax: withTax,
        );
      }).toList();

      final invalidItem = lineItems.firstWhere(
        (line) =>
            (line['unit_price'] ?? 0) <= 0 ||
            (line['quantity'] ?? line['qty'] ?? 0) <= 0,
        orElse: () => {},
      );
      if (invalidItem.isNotEmpty) {
        // 🔧 FIX: saleId was added to _pendingSales above, before this
        // validation ran. Returning here without removing it left the id in
        // the set forever — a leak on every rejected sale, and since
        // _pendingSales gating is checked by saleId at the top of this
        // function, it also meant a corrected retry with a *different* new
        // saleId would work, but anything that ever reused this exact id
        // would incorrectly report itself as already-processing forever.
        _pendingSales.remove(saleId);
        InventoryManagementService.suppressInventoryCallback = false;
        return {
          'success': false,
          'error': 'INVALID_SALE_ITEM',
          'message':
              'Sale contains an invalid item with zero or negative price/quantity.',
        };
      }

      try {
        await CrashRecoveryService.instance
            .registerIncompleteTransaction('sale', {
              'sale_id': saleId,
              'customer_name': customerName.isNotEmpty
                  ? customerName
                  : 'Guest Customer',
              'customer_phone': customerPhone,
              'items': lineItems,
              'total': grandTotal.toString(),
              'total_amount': grandTotal,
              'paid_amount': recordedPaidAmount.toString(),
              'gst_applied': withTax,
              'payment_method': paymentMethod,
              'is_borrow': isBorrow,
              'sync_status': 'pending',
              'pending_sync': true,
            });
      } catch (e) {
        if (kDebugMode)
          debugPrint(
            '⚠️ Failed to register incomplete-transaction safety net: $e',
          );
      }

      // OFFLINE-FIRST: persist the sale and enqueue it BEFORE attempting any network call.
      // Capture the exact transaction timestamp once. The same value is used by
      // local history and the backend so a later sync cannot rewrite the sale time.
      final DateTime saleTimestamp = DateTime.now().toUtc();
      final String saleTimestampIso = saleTimestamp.toIso8601String();

      double parseMoney(dynamic value) {
        if (value is num) return value.toDouble();
        return double.tryParse(value?.toString() ?? '') ?? 0.0;
      }

      final declaredTax = totals.containsKey('tax')
          ? parseMoney(totals['tax'])
          : parseMoney(totals['cgst']) + parseMoney(totals['sgst']);
      final invoiceTax = withTax && declaredTax.isFinite && declaredTax > 0
          ? double.parse(declaredTax.toStringAsFixed(2))
          : 0.0;

      final invoicePayload = {
        'invoice_number': canonicalInvoiceNumber,
        'offline_id': offlineId,
        'customer_name': customerName.isNotEmpty
            ? customerName
            : 'Cash Customer',
        'customer_phone': customerPhone.isNotEmpty ? customerPhone : null,
        'customer_address': customerAddress.trim().isNotEmpty
            ? customerAddress.trim()
            : null,
        'total_amount': grandTotal,
        'paid_amount': recordedPaidAmount,
        'payment_method': paymentMethod,
        'is_borrow': isBorrow,
        'tax': invoiceTax,
        'payment_status': paymentStatusFor(recordedPaidAmount, grandTotal),
        'invoice_date': saleTimestampIso.split('T')[0],
        'sale_timestamp': saleTimestampIso,
        'created_at': saleTimestampIso,
        'notes': isBorrow
            ? 'Payment via $paymentMethod - Borrow Invoice'
            : 'Payment via $paymentMethod - Regular Sale',
        'line_items': lineItems,
      };

      final prefs = await SharedPreferences.getInstance();
      await _persistToLocalHistory(
        prefs: prefs,
        saleId: saleId,
        customerName: customerName,
        customerPhone: customerPhone,
        customerAddress: customerAddress,
        items: lineItems,
        grandTotal: grandTotal,
        paidAmount: recordedPaidAmount,
        withTax: withTax,
        totals: totals,
        invoiceTax: invoiceTax,
        paymentMethod: paymentMethod,
        syncStatus: 'pending',
        invoiceNumber: canonicalInvoiceNumber,
        isBorrow: isBorrow,
      );

      final bool queueEnqueued = await SyncQueueManager.enqueue('save_sale', {
        'is_borrow': isBorrow,
        'endpoint': ApiClient.invoicesSync,
        'payload': invoicePayload,
        'invoice_payload': invoicePayload,
        'sale_id': saleId,
        'invoice_number': canonicalInvoiceNumber,
        'retry_priority': 'high',
      });
      if (!queueEnqueued) {
        // Do not fall back to a second, competing network writer. The sale is
        // already in local history; make the outbox failure explicit for recovery.
        throw StateError(
          'SALE_OUTBOX_PERSIST_FAILED: sale is locally saved but was not queued',
        );
      }

      // Local inventory is updated once. Backend inventory is updated only by /invoices/sync.
      await InventoryManagementService.deductStockLocally(
        items,
        saleId: saleId,
      );
      unawaited(
        _recordLocalSalesVelocity(saleId: saleId, lineItems: lineItems),
      );
      if (refreshDashboard) SyncService.triggerDashboardRefresh();
      recoveryCanBeCleared = true;

      // Single upload path: the encrypted durable queue owns the request. The
      // local sale was saved and stock adjusted before returning to the cashier;
      // one queue worker uploads it, marks it synced, then removes the queue item.
      _pendingSales.remove(saleId);
      InventoryManagementService.suppressInventoryCallback = false;

      unawaited(SyncService.processQueueSafe());
      await RetailGrowthKit.recordBillCompleted();

      AgentDebugLog.log(
        location: 'sale_service.dart:submitSale:final_result',
        message: 'SALE SAVED TO DURABLE OUTBOX',
        hypothesisId: 'H5',
        data: {
          'saleId': saleId,
          'invoiceNumber': canonicalInvoiceNumber,
          'success': true,
          'syncStatus': 'pending',
          'cloudConfirmed': false,
          'localSaved': true,
          'retryQueued': true,
        },
      );

      return {
        'success': true,
        'syncCount': 0,
        'saleId': saleId,
        'invoiceNumber': canonicalInvoiceNumber,
        'syncStatus': 'pending',
        'cloudConfirmed': false,
        'localSaved': true,
        'retryQueued': true,
        'message':
            'Sale saved on this device. Cloud sync is queued and will retry automatically.',
      };
    } catch (e, st) {
      _pendingSales.remove(saleId);
      InventoryManagementService.suppressInventoryCallback = false;
      if (kDebugMode)
        debugPrint('❌ TRANSACTION CRITICAL FAILURE [$context]: $e');
      if (kDebugMode) debugPrint(st.toString());
      AgentDebugLog.log(
        location: 'sale_service.dart:submitSale:critical_failure',
        message: 'CRITICAL FAILURE',
        hypothesisId: 'H5',
        data: {'error': e.toString(), 'saleId': saleId},
      );
      return {
        'success': false,
        'error': e.toString(),
        'recovery_action': 'RETRY_SYNC',
      };
    } finally {
      _pendingSales.remove(saleId);
      if (recoveryCanBeCleared) {
        try {
          await CrashRecoveryService.instance.clearSpecificTransaction('sale', {
            'sale_id': saleId,
          });
        } catch (e) {
          if (kDebugMode)
            debugPrint(
              '⚠️ Failed to clear incomplete-transaction safety net: $e',
            );
        }
      } else if (kDebugMode) {
        debugPrint(
          '⚠️ Retaining recovery record for sale $saleId because its durable '
          'outbox/local stock step was not confirmed.',
        );
      }
      InventoryManagementService.suppressInventoryCallback = false;
      InventoryManagementService.onInventoryChanged?.call();
    }
  }

  static Future<bool> _markSaleAsSynced(String saleId) async {
    if (saleId.isEmpty) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final syncedSales = prefs.getStringList('synced_sales') ?? <String>[];
      if (!syncedSales.contains(saleId)) {
        syncedSales.add(saleId);
        if (syncedSales.length > 1000) {
          syncedSales.removeRange(0, syncedSales.length - 1000);
        }
        final saved = await prefs.setStringList('synced_sales', syncedSales);
        if (!saved) return false;
      }

      final sales = await LocalStorageService.loadSales();
      bool updated = false;
      for (int i = 0; i < sales.length; i++) {
        final raw = sales[i];
        if (raw is! Map) continue;
        final currentId =
            (raw['sale_id'] ?? raw['invoice_number'] ?? raw['id'] ?? '')
                .toString();
        if (currentId != saleId) continue;
        sales[i] = {
          ...Map<String, dynamic>.from(raw),
          'sync_status': 'synced',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'last_sync_attempt': DateTime.now().toUtc().toIso8601String(),
          'is_synced': true,
        };
        updated = true;
        break;
      }

      if (updated) {
        await LocalStorageService.saveSales(sales);
      }

      // The idempotency marker is the durable acknowledgement even if the
      // local sales cache does not currently contain the sale.
      return (await _isSaleSynced(saleId));
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to mark sale as synced: $e');
      return false;
    }
  }

  static Future<bool> _isSaleSynced(String saleId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final syncedSales = prefs.getStringList('synced_sales') ?? [];
      return syncedSales.contains(saleId);
    } catch (e) {
      return false;
    }
  }

  static Future<bool> markSaleAsSynced(String saleId) async {
    if (saleId.trim().isEmpty) return false;
    return _markSaleAsSynced(saleId.trim());
  }

  static void triggerBackgroundAlert(Map<String, dynamic> item) {
    try {
      StockAlertService.checkAndAlertLowStock(
        productName: item['product_name']?.toString() ?? 'Unknown',
        quantitySold: item['qty'] is num
            ? (item['qty'] as num).toDouble()
            : double.tryParse(item['qty']?.toString() ?? '1') ?? 1.0,
        productId:
            int.tryParse(
              (item['product_id'] ?? item['id'] ?? '0').toString(),
            ) ??
            0,
      );
    } catch (_) {}
  }

  /// Aggregate repeated bill lines into one stock request per catalog product.
  /// Selling price is deliberately not part of stock identity: two price tiers
  /// for the same physical product still consume the same inventory.
  @visibleForTesting
  static List<Map<String, dynamic>> aggregateStockRequests(
    List<Map<String, dynamic>> items,
    List<dynamic> productsList,
  ) {
    String normalizeName(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

    double number(Object? value, [double fallback = 0]) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    final catalog = productsList
        .whereType<Map>()
        .map((product) => Map<String, dynamic>.from(product))
        .toList();
    final grouped = <String, Map<String, dynamic>>{};

    for (final item in items) {
      if (item['stock_tracked'] == false || item['is_custom_item'] == true) {
        continue;
      }
      final productId =
          int.tryParse((item['product_id'] ?? item['id'] ?? '0').toString()) ??
          0;
      final itemName =
          (item['product_name'] ?? item['itemName'] ?? item['name'] ?? '')
              .toString()
              .trim();
      final normalizedItemName = normalizeName(itemName);
      if (productId <= 0 && normalizedItemName.isEmpty) continue;

      Map<String, dynamic>? found;
      if (productId > 0) {
        for (final product in catalog) {
          final candidateId =
              int.tryParse(
                (product['id'] ?? product['product_id'] ?? '').toString(),
              ) ??
              0;
          if (candidateId == productId) {
            found = product;
            break;
          }
        }
      }
      if (found == null && normalizedItemName.isNotEmpty) {
        for (final product in catalog) {
          final candidateName = normalizeName(
            (product['product_name'] ?? product['name'] ?? '').toString(),
          );
          if (candidateName == normalizedItemName) {
            found = product;
            break;
          }
        }
      }

      final foundId =
          int.tryParse(
            (found?['id'] ?? found?['product_id'] ?? '').toString(),
          ) ??
          0;
      final resolvedId = foundId > 0 ? foundId : productId;
      final identity = resolvedId > 0
          ? 'product:$resolvedId'
          : 'name:$normalizedItemName';
      final quantity = number(item['qty'] ?? item['quantity'], 1);
      final stockRaw =
          found?['current_stock'] ?? found?['stock'] ?? found?['quantity'];
      final availableStock = stockRaw == null ? 0.0 : number(stockRaw);
      final displayName = (found?['product_name'] ?? found?['name'] ?? itemName)
          .toString()
          .trim();

      final request = grouped.putIfAbsent(
        identity,
        () => {
          'product_id': resolvedId,
          'product_name': displayName,
          'requested_qty': 0.0,
          'available_stock': availableStock,
          'catalog_found': found != null,
        },
      );
      request['requested_qty'] = number(request['requested_qty']) + quantity;
      if (request['product_name'].toString().trim().isEmpty &&
          displayName.isNotEmpty) {
        request['product_name'] = displayName;
      }
    }
    return grouped.values.toList();
  }

  /// Local-only stock check. Missing stock fields default to 0 (not 9999).
  static Future<Map<String, dynamic>> _validateStockAvailabilityLocally(
    List<Map<String, dynamic>> items,
  ) async {
    try {
      final localProducts = await LocalStorageService.loadLocalProducts();
      final productsList = localProducts is List
          ? localProducts as List
          : localProducts.values.toList();
      final insufficientItems = <Map<String, dynamic>>[];
      final requests = aggregateStockRequests(items, productsList);

      for (final request in requests) {
        // Unknown/local-unsynced products cannot be safely rejected solely
        // because the local catalog is stale or unavailable. Backend
        // invoice validation remains authoritative when connectivity exists.
        if (request['catalog_found'] != true) continue;

        final requestedQty = request['requested_qty'] as double;
        final currentStock = request['available_stock'] as double;
        if (requestedQty > currentStock) {
          insufficientItems.add({
            'product_id': request['product_id'],
            'product_name': request['product_name'],
            'requested_qty': requestedQty,
            'available_stock': currentStock,
          });
        }
      }

      if (insufficientItems.isEmpty) {
        return {'valid': true, 'message': 'Stock check passed'};
      }
      final productNames = insufficientItems
          .map((i) => i['product_name'])
          .join(', ');
      return {
        'valid': false,
        'message': 'Insufficient stock for: $productNames',
        'insufficient_items': insufficientItems,
      };
    } catch (e) {
      // Local stock is an optimization/safety check, not the authority for
      // whether a bill may be created. Fresh installs, data clears and a
      // closed Hive box must never brick billing. The backend invoice-sync
      // endpoint remains authoritative when available.
      if (kDebugMode)
        debugPrint(
          '⚠️ Local stock validation unavailable; allowing sale to proceed: $e',
        );
      return {
        'valid': true,
        'message': 'Stock check skipped (catalog unavailable)',
        'stock_check_skipped': true,
      };
    }
  }

  static void clearInFlight() => _pendingSales.clear();

  static Future<void> _persistToLocalHistory({
    required SharedPreferences prefs,
    required String saleId,
    required String customerName,
    required String customerPhone,
    String customerAddress = '',
    required List<Map<String, dynamic>> items,
    required double grandTotal,
    required double paidAmount,
    required bool withTax,
    required Map<String, dynamic> totals,
    required double invoiceTax,
    String paymentMethod = 'Cash',
    String syncStatus = 'synced',
    String? invoiceNumber,
    bool isBorrow = false,
  }) async {
    final String safePhone = customerPhone.isNotEmpty
        ? customerPhone
        : 'GUEST_${saleId.length >= 6 ? saleId.substring(saleId.length - 6) : saleId.padLeft(6, '0')}';

    final String saleTimestamp = DateTime.now().toUtc().toIso8601String();

    final List<Map<String, dynamic>> normalizedItems = items.map((item) {
      final double price = (item['unit_price'] ?? item['price'] ?? 0.0) is num
          ? (item['unit_price'] ?? item['price'] ?? 0.0).toDouble()
          : double.tryParse(
                  (item['unit_price'] ?? item['price'] ?? '0').toString(),
                ) ??
                0.0;
      final double qty = (item['quantity'] ?? item['qty'] ?? 1) is num
          ? (item['quantity'] ?? item['qty'] ?? 1).toDouble()
          : double.tryParse(
                  (item['quantity'] ?? item['qty'] ?? '1').toString(),
                ) ??
                1.0;
      final double grossLine = CurrencyManager.multiply(price, qty);
      final double rawDiscount = item['discount_amount'] is num
          ? (item['discount_amount'] as num).toDouble()
          : double.tryParse(item['discount_amount']?.toString() ?? '0') ?? 0.0;
      final double discount = double.parse(
        rawDiscount.clamp(0.0, grossLine).toStringAsFixed(2),
      );
      final double lineTotal = item['line_total'] is num
          ? (item['line_total'] as num).toDouble()
          : double.parse((grossLine - discount).toStringAsFixed(2));
      final double taxAmount = item['tax_amount'] is num
          ? (item['tax_amount'] as num).toDouble()
          : double.tryParse(item['tax_amount']?.toString() ?? '0') ?? 0.0;
      final double totalWithTax = item['total_with_tax'] is num
          ? (item['total_with_tax'] as num).toDouble()
          : double.parse((lineTotal + taxAmount).toStringAsFixed(2));

      return {
        ...item,
        'price': price,
        'price_str': price.toString(),
        'unit_price': price,
        'qty': qty,
        'quantity': qty,
        'qty_str': qty.toString(),
        'discount_amount': discount,
        'tax_amount': taxAmount,
        'total': lineTotal,
        'line_total': lineTotal,
        'total_with_tax': totalWithTax,
        'product':
            item['product_name'] ?? item['product'] ?? item['item'] ?? '',
        'name': item['product_name'] ?? item['product'] ?? item['item'] ?? '',
        'item': item['product_name'] ?? item['product'] ?? item['item'] ?? '',
      };
    }).toList();

    final userId = prefs.getInt('user_id') ?? prefs.getInt('userId');

    final Map<String, dynamic> saleRecord = {
      'sale_id': saleId,
      'offline_id': saleId,
      'invoice_number': invoiceNumber ?? saleId,
      'bill_number': invoiceNumber ?? saleId,
      'invoice_display_number': invoiceNumber ?? saleId,
      'created_at': saleTimestamp,
      'sale_timestamp': saleTimestamp,
      'updated_at': saleTimestamp,
      'user_id': userId,
      'sync_status': syncStatus,
      'pending_sync': syncStatus != 'synced',
      'sync_attempts': 0,
      'last_sync_attempt': null,
      'backend_id': null,
      'is_deleted': false,
      'customer_name': customerName.isNotEmpty
          ? customerName
          : 'Guest Customer',
      'customer_phone': customerPhone,
      'customer_address': customerAddress.trim().isNotEmpty
          ? customerAddress.trim()
          : null,
      'guest_id': safePhone,
      'items': normalizedItems,
      'business_date': saleTimestamp,
      'subtotal': (totals['subtotal'] ?? (grandTotal - invoiceTax)).toString(),
      'total': grandTotal.toString(),
      'total_amount': grandTotal,
      'paid_amount': paidAmount.toString(),
      'payment_status': paymentStatusFor(paidAmount, grandTotal),
      'gst_applied': withTax,
      'payment_method': paymentMethod,
      'is_borrow': isBorrow,
      'notes': isBorrow
          ? 'Payment via $paymentMethod - Borrow Invoice'
          : 'Payment via $paymentMethod - Regular Sale',
    };

    await LocalStorageService.upsertSaleRecord(saleRecord, saleId: saleId);
    if (kDebugMode)
      debugPrint('📝 Created local sale with sync metadata: $saleId');
  }
}
