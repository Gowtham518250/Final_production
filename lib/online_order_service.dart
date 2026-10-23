import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'api_client.dart';
import 'secure_token_storage.dart';
import 'payment_event.dart';
import 'analytics_engine.dart';
import 'account_data_sync_service.dart';
import 'local_storage_service.dart';

/// Online orders: analytics, UPI matching, notifications helpers.
class OnlineOrderService {
  static const _orders = 'orders';

  static const _invoiceIdentityFields = [
    'invoice_id',
    'invoice_number',
    'invoice_no',
    'sale_id',
    'sale_number',
  ];
  static const _orderReferenceFields = [
    'reference_order_id',
    'online_order_id',
    'order_id',
    'source_order_id',
  ];

  static Set<String> _values(
    Map<String, dynamic> record,
    Iterable<String> fields,
  ) => fields
      .map((field) => record[field]?.toString().trim().toLowerCase() ?? '')
      .where((value) => value.isNotEmpty && value != 'null')
      .toSet();

  static bool invoiceBelongsToOrder(
    Map<String, dynamic> invoice,
    Map<String, dynamic> order,
  ) {
    final orderReferences = _values(order, [..._orderReferenceFields, 'id']);
    final invoiceReferences = _values(invoice, _orderReferenceFields);
    if (invoiceReferences.intersection(orderReferences).isNotEmpty) {
      return true;
    }

    final orderInvoiceIds = _values(order, ['invoice_id']);
    final orderInvoiceNumbers = _values(order, [
      'invoice_number',
      'invoice_no',
      'sale_id',
      'sale_number',
    ]);
    final invoiceIds = _values(invoice, ['id', 'invoice_id']);
    final invoiceNumbers = _values(invoice, [
      'invoice_number',
      'invoice_no',
      'sale_id',
      'sale_number',
    ]);
    if (invoiceIds.intersection(orderInvoiceIds).isNotEmpty ||
        invoiceNumbers.intersection(orderInvoiceNumbers).isNotEmpty) {
      return true;
    }

    final orderId = (order['order_id'] ?? order['id'] ?? '').toString().trim();
    final invoiceSource =
        (invoice['source'] ??
                invoice['order_source'] ??
                invoice['sale_type'] ??
                '')
            .toString()
            .trim()
            .toUpperCase();
    if (orderId.isEmpty ||
        !const {
          'ONLINE_ORDER',
          'ONLINE',
          'WEB',
          'APP',
        }.contains(invoiceSource)) {
      return false;
    }

    final escapedOrderId = RegExp.escape(orderId);
    final orderNote = RegExp(
      r'(^|\b)Online Order #' + escapedOrderId + r'(\b|$)',
      caseSensitive: false,
    );
    return [
      invoice['notes'],
      invoice['note'],
      invoice['description'],
    ].any((value) => orderNote.hasMatch(value?.toString().trim() ?? ''));
  }

  static bool isCancelledOrder(Map<String, dynamic> order) {
    final status = (order['status'] ?? order['order_status'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    return const {'CANCELLED', 'CANCELED', 'REJECTED'}.contains(status) ||
        order['is_cancelled'] == true ||
        order['is_canceled'] == true;
  }

  static List<Map<String, dynamic>> excludeCancelledOrderInvoices(
    Iterable<Map<String, dynamic>> invoices,
    Iterable<Map<String, dynamic>> orders,
  ) {
    final cancelledOrders = orders.where(isCancelledOrder).toList();
    return invoices
        .where(
          (invoice) => !cancelledOrders.any(
            (order) => invoiceBelongsToOrder(invoice, order),
          ),
        )
        .toList();
  }

  static Future<int> removeCancelledOrderRecordsLocally(
    Iterable<Map<String, dynamic>> orders,
  ) async {
    final cancelledOrders = orders.where(isCancelledOrder).toList();
    if (cancelledOrders.isEmpty) return 0;

    final invoices = await LocalStorageService.loadLocalInvoices();
    final remainingInvoices = invoices.where((raw) {
      if (raw is! Map) return true;
      final invoice = Map<String, dynamic>.from(raw);
      return !cancelledOrders.any(
        (order) => invoiceBelongsToOrder(invoice, order),
      );
    }).toList();

    final sales = await LocalStorageService.loadSales();
    final remainingSales = sales.where((raw) {
      if (raw is! Map) return true;
      final sale = Map<String, dynamic>.from(raw);
      return !cancelledOrders.any(
        (order) => invoiceBelongsToOrder(sale, order),
      );
    }).toList();

    final removedCount =
        invoices.length -
        remainingInvoices.length +
        sales.length -
        remainingSales.length;
    if (removedCount == 0) return 0;

    await LocalStorageService.replaceLocalInvoices(remainingInvoices);
    await LocalStorageService.replaceSalesCanonical(remainingSales);
    return removedCount;
  }

  static Future<List<Map<String, dynamic>>>
  fetchCancelledOrdersForCloudRestore() async {
    final cancelledOrders = <Map<String, dynamic>>[];
    var skip = 0;
    const pageSize = 200;
    var expectedTotal = 0;

    do {
      final response = await ApiClient.getJson(
        '/store/owner/orders?skip=$skip&limit=$pageSize',
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception(
          'Could not check cancelled orders before cloud restore '
          '(HTTP ${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(response.body);
      final rawOrders = decoded is Map ? decoded['orders'] : decoded;
      if (rawOrders is! List) {
        throw const FormatException('Owner orders response is not a list.');
      }
      if (skip == 0) {
        final total = decoded is Map ? decoded['total'] : null;
        expectedTotal = total is num
            ? total.toInt()
            : int.tryParse(total?.toString() ?? '') ?? rawOrders.length;
      }

      for (final raw in rawOrders) {
        if (raw is! Map) continue;
        final order = Map<String, dynamic>.from(raw);
        if (isCancelledOrder(order)) cancelledOrders.add(order);
      }

      if (rawOrders.isEmpty || rawOrders.length < pageSize) break;
      skip += rawOrders.length;
    } while (skip < expectedTotal);

    return cancelledOrders;
  }

  /// Permanently remove invoice and sale records tied to a successfully
  /// cancelled online order. Only exact order/invoice identifiers are matched.
  static Future<int> deleteCancelledOrderInvoices(
    Map<String, dynamic> order,
  ) async {
    final response = await ApiClient.getJson(
      '${ApiClient.invoicesPrefix}/',
    ).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception(
        'Could not load invoices before deleting cancelled order records '
        '(HTTP ${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    final rawInvoices = decoded is List
        ? decoded
        : decoded is Map && decoded['invoices'] is List
        ? decoded['invoices'] as List
        : null;
    if (rawInvoices == null) {
      throw const FormatException('Invoice response is not a list.');
    }

    final linkedRemoteInvoices = rawInvoices
        .whereType<Map>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .where((invoice) => invoiceBelongsToOrder(invoice, order))
        .toList();
    final deletedInvoiceIdentifiers = <String>{};
    for (final invoice in linkedRemoteInvoices) {
      final id = (invoice['id'] ?? invoice['invoice_id'] ?? '')
          .toString()
          .trim();
      if (id.isEmpty) {
        throw StateError(
          'A linked invoice has no server ID; it was not deleted.',
        );
      }
      final deleted = await AccountDataSyncService.deleteInvoiceFromBackend(id);
      if (!deleted) {
        throw StateError(
          'Could not delete linked invoice $id from the server.',
        );
      }
      deletedInvoiceIdentifiers.addAll(
        _values(invoice, [..._invoiceIdentityFields, 'id']),
      );
    }

    final localInvoices = await LocalStorageService.loadLocalInvoices();
    final deletedLocalInvoiceCount = localInvoices.where((raw) {
      if (raw is! Map) return false;
      final invoice = Map<String, dynamic>.from(raw);
      return invoiceBelongsToOrder(invoice, order) ||
          _values(invoice, [
            ..._invoiceIdentityFields,
            'id',
          ]).intersection(deletedInvoiceIdentifiers).isNotEmpty;
    }).length;
    final remainingInvoices = localInvoices.where((raw) {
      if (raw is! Map) return true;
      final invoice = Map<String, dynamic>.from(raw);
      return !invoiceBelongsToOrder(invoice, order) &&
          _values(invoice, [
            ..._invoiceIdentityFields,
            'id',
          ]).intersection(deletedInvoiceIdentifiers).isEmpty;
    }).toList();
    await LocalStorageService.replaceLocalInvoices(remainingInvoices);

    final sales = await LocalStorageService.loadSales();
    final remainingSales = sales.where((raw) {
      if (raw is! Map) return true;
      final sale = Map<String, dynamic>.from(raw);
      return !invoiceBelongsToOrder(sale, order) &&
          _values(sale, [
            ..._invoiceIdentityFields,
            'id',
          ]).intersection(deletedInvoiceIdentifiers).isEmpty;
    }).toList();
    await LocalStorageService.replaceSalesCanonical(remainingSales);

    return linkedRemoteInvoices.length > deletedLocalInvoiceCount
        ? linkedRemoteInvoices.length
        : deletedLocalInvoiceCount;
  }

  /// Count distinct online orders in legacy sales rows without confusing a
  /// line-item row ID or currency amount with an order ID. Online orders write
  /// one sales row per item, so reference_order_id is the canonical grouping key.
  static int countDistinctOnlineOrdersFromSales(
    Iterable<Map<String, dynamic>> rows,
  ) {
    final cancelledOrderIds = <String>{};
    for (final row in rows) {
      if (!AnalyticsEngine.isVoidedSale(row)) continue;
      final referenceOrderId =
          (row['reference_order_id'] ??
                  row['online_order_id'] ??
                  row['order_id'] ??
                  '')
              .toString()
              .trim();
      if (referenceOrderId.isNotEmpty) {
        cancelledOrderIds.add(referenceOrderId.toLowerCase());
      }
    }

    final orderIds = <String>{};
    for (final row in rows) {
      if (AnalyticsEngine.isVoidedSale(row)) continue;
      final source = (row['source'] ?? row['order_source'] ?? 'OFFLINE')
          .toString()
          .trim()
          .toUpperCase();
      final invoiceKey =
          (row['invoice_number'] ??
                  row['sale_id'] ??
                  row['_bill_id'] ??
                  row['id'] ??
                  row['created_at'] ??
                  '')
              .toString()
              .trim();
      final isOnline =
          const {'ONLINE', 'ONLINE_ORDER', 'WEB', 'APP'}.contains(source) ||
          invoiceKey.toUpperCase().startsWith('ONL');
      if (!isOnline) continue;

      final referenceOrderId =
          (row['reference_order_id'] ??
                  row['online_order_id'] ??
                  row['order_id'] ??
                  '')
              .toString()
              .trim();
      if (cancelledOrderIds.contains(referenceOrderId.toLowerCase())) {
        continue;
      }
      if (referenceOrderId.isNotEmpty) {
        orderIds.add('order:$referenceOrderId');
      } else if (invoiceKey.isNotEmpty) {
        orderIds.add('invoice:${invoiceKey.toUpperCase()}');
      }
    }
    return orderIds.length;
  }

  /// Shop UPI for customer checkout — Firestore only (never owner prefs.upi_id).
  static Future<String?> fetchShopUpi(String shopId) async {
    if (shopId.isEmpty) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .get();
      final upi = doc.data()?['upi_id']?.toString().trim();
      if (upi != null && upi.isNotEmpty) return upi;
    } catch (e) {
      if (kDebugMode) debugPrint('fetchShopUpi Firestore: $e');
    }
    return null;
  }

  static Future<void> syncShopUpiToFirestore(String shopId) async {
    if (shopId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final upi = prefs.getString('upi_id');
    if (upi == null || upi.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('shops').doc(shopId).set({
        'upi_id': upi,
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('syncShopUpi: $e');
    }
  }

  /// Canonical online-store analytics from the same owner-order dataset
  /// used by the Online Orders page.
  static Future<Map<String, dynamic>> getAnalytics(String shopId) async {
    const empty = <String, dynamic>{
      'pending': 0,
      'todayCount': 0,
      'todayRevenue': 0.0,
      'paidCount': 0,
      'todayPaidCount': 0,
      'totalCount': 0,
      'totalRevenue': 0.0,
      'totalPaidCount': 0,
      'rejectedCount': 0,
      'cancelledCount': 0,
      'available': false,
    };

    if (shopId.isEmpty || shopId == '0')
      return Map<String, dynamic>.from(empty);

    final token = await SecureTokenStorage.getToken() ?? '';
    if (token.isEmpty) return Map<String, dynamic>.from(empty);
    final headers = {'Authorization': 'Bearer $token'};

    try {
      // Derive revenue from order rows so cancelled/returned statuses cannot
      // be hidden by an opaque aggregate response. Fetch every page to avoid
      // undercounting shops with more than one page of orders.
      final ordersById = <String, Map<String, dynamic>>{};
      var skip = 0;
      var expectedTotal = 0;
      const pageSize = 200;
      do {
        final response = await ApiClient.getJson(
          '/store/owner/orders?skip=$skip&limit=$pageSize',
          headers: headers,
        ).timeout(const Duration(seconds: 12));
        if (response.statusCode != 200) {
          throw Exception('Owner orders returned HTTP ${response.statusCode}');
        }

        final decoded = jsonDecode(response.body);
        final raw = decoded is Map ? decoded['orders'] : decoded;
        if (raw is! List) {
          throw const FormatException('Owner orders response is not a list.');
        }
        if (skip == 0 && decoded is Map) {
          final totalValue = decoded['total'];
          expectedTotal = totalValue is num
              ? totalValue.toInt()
              : int.tryParse(totalValue?.toString() ?? '') ?? raw.length;
        } else if (skip == 0) {
          expectedTotal = raw.length;
        }

        for (final item in raw) {
          if (item is! Map) continue;
          final order = Map<String, dynamic>.from(item);
          final id = (order['order_id'] ?? order['id'] ?? '').toString();
          if (id.isNotEmpty) ordersById[id] = order;
        }

        if (raw.isEmpty) break;
        skip += raw.length;
        if (raw.length < pageSize) break;
      } while (skip < expectedTotal);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      int pending = 0;
      int todayCount = 0;
      int paidCount = 0;
      int totalPaidCount = 0;
      int rejectedCount = 0;
      int cancelledCount = 0;
      double todayRevenue = 0.0;
      double totalRevenue = 0.0;

      for (final order in ordersById.values) {
        final statuses = {
          for (final field in const [
            'status',
            'order_status',
            'sale_status',
            'payment_status',
          ])
            if (order[field] != null)
              order[field].toString().trim().toUpperCase().split('.').last,
        };
        final excludedFromValue = AnalyticsEngine.isVoidedSale(order);
        final total =
            (order['total_amount'] as num?)?.toDouble() ??
            double.tryParse(order['total_amount']?.toString() ?? '0') ??
            0.0;

        if (statuses.contains('PENDING')) pending++;
        if (statuses.contains('REJECTED')) rejectedCount++;
        if (statuses.intersection({
          'CANCELLED',
          'CANCELED',
          'RETURNED',
        }).isNotEmpty) {
          cancelledCount++;
        }

        if (!excludedFromValue) totalRevenue += total;

        final paymentStatus = (order['payment_status'] ?? '')
            .toString()
            .toUpperCase();
        final isPaid = paymentStatus == 'PAID';
        if (isPaid && !excludedFromValue) totalPaidCount++;

        final rawDate =
            order['created_at'] ?? order['timestamp'] ?? order['placed_at'];
        final dt = rawDate == null
            ? null
            : DateTime.tryParse(rawDate.toString())?.toLocal();
        final isToday =
            dt != null &&
            DateTime(dt.year, dt.month, dt.day) == today &&
            !excludedFromValue;

        if (isToday) {
          todayCount++;
          todayRevenue += total;
          if (isPaid) paidCount++;
        }
      }

      return {
        'pending': pending,
        'todayCount': todayCount,
        'todayRevenue': todayRevenue,
        'paidCount': paidCount,
        'todayPaidCount': paidCount,
        'totalCount': ordersById.length,
        'totalRevenue': totalRevenue,
        'totalPaidCount': totalPaidCount,
        'rejectedCount': rejectedCount,
        'cancelledCount': cancelledCount,
        'available': true,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('getAnalytics: ' + e.toString());
      return Map<String, dynamic>.from(empty);
    }
  }

  /// Match an owner-device notification to a UPI order in PostgreSQL.
  ///
  /// This does not call a payment gateway or rely on a webhook. The backend
  /// only records an automatic match for a high-confidence confirmed event
  /// with a transaction reference and exactly one matching pending order.
  static Future<String?> tryMatchOnlineOrderPayment(
    PaymentEvent event,
    String shopId,
  ) async {
    if (shopId.isEmpty ||
        event.isFailed ||
        event.isDuplicate ||
        event.amount <= 0 ||
        event.decision != PaymentDecision.confirmed ||
        event.confidenceScore < 0.70 ||
        (event.referenceId ?? '').trim().length < 4) {
      return null;
    }

    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      if (token.isEmpty) return null;

      final response = await ApiClient.postJson(
        '/store/owner/orders/match-notification-payment',
        {
          'amount': event.amount,
          'payment_reference': event.referenceId!.trim(),
          'idempotency_key': event.fingerprint,
          if (event.saleId != null && event.saleId!.trim().isNotEmpty)
            'invoice_number': event.saleId!.trim(),
          'confidence_score': event.confidenceScore,
          'decision': event.decision.name.toUpperCase(),
          'source': event.detectionSource,
          'payer_name': event.payerName,
          'timestamp': event.timestamp.toIso8601String(),
        },
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('Online order payment match HTTP ${response.statusCode}');
        }
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['matched'] != true) {
        if (kDebugMode && decoded is Map) {
          debugPrint(
            'Online order payment not auto-matched: ${decoded['reason'] ?? 'manual review required'}',
          );
        }
        if (decoded is Map && decoded['requires_manual_review'] == true) {
          await NotificationService.show(
            'Payment needs review',
            '₹${event.amount.toStringAsFixed(2)} could not be safely matched to one online order. Verify it before marking the order paid.',
          );
        }
        return null;
      }

      final orderId = decoded['order_id']?.toString();
      if (orderId == null || orderId.isEmpty) return null;
      await NotificationService.show(
        'Online payment confirmed',
        '₹${event.amount.toStringAsFixed(2)} matched to order #${orderId.substring(0, orderId.length > 8 ? 8 : orderId.length)}',
      );
      return orderId;
    } catch (e) {
      if (kDebugMode) debugPrint('tryMatchOnlineOrderPayment: $e');
    }
    return null;
  }

  static Future<void> notifyOrderStatusChange({
    required String orderId,
    required String status,
    required String shopName,
    required double total,
  }) async {
    await NotificationService.show(
      'Order update — $shopName',
      '#${orderId.substring(0, 8)}: $status · ₹${total.toStringAsFixed(0)}',
    );
  }

  static Future<void> notifyNewOrderForOwner({
    required String orderId,
    required double total,
    required String customerEmail,
  }) async {
    await NotificationService.show(
      'New online order',
      '₹${total.toStringAsFixed(0)} from $customerEmail · Tap Online Store',
    );
  }
}
