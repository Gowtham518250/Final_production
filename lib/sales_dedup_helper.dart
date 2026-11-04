import 'package:flutter/foundation.dart';
import 'format_helper.dart';
import 'local_storage_service.dart';
import 'financial_math.dart';
import 'invoice_dedup_helper.dart';

/// Result of a one-time Hive sales cleanup (Option B).
class SalesCleanupResult {
  final int before;
  final int after;
  final int removed;

  const SalesCleanupResult({
    required this.before,
    required this.after,
    required this.removed,
  });
}

/// Prevents duplicate bills/lines from cloud sync + dashboard merge.
class SalesDedupHelper {
  static String _dayKey(dynamic dateStr) {
    final s = dateStr?.toString() ?? '';
    if (s.isEmpty) return '';
    return s.split('T').first.split(' ').first;
  }

  static double _num(dynamic v, [double fallback = 0]) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  /// Extracts the microsecond timestamp encoded in a 'SALE_<micros>' id
  /// (see sales_entry_page.dart: `'SALE_${DateTime.now().microsecondsSinceEpoch}'`).
  /// Returns null if the id isn't in that format.
  static int? _saleIdTimestampMicros(String saleId) {
    if (!saleId.startsWith('SALE_')) return null;
    return int.tryParse(saleId.substring(5));
  }

  static String _productKey(Map item) {
    final raw = (item['product_name'] ?? item['item'] ?? item['product'] ?? 'unknown').toString();
    return FormatHelper.normalizeName(raw);
  }

  /// Content-only fingerprint for a full bill — day + normalized items +
  /// quantities + prices + total. Deliberately does NOT include sale_id:
  /// identity (sale_id) and content must stay separate concepts, or content
  /// matching can never actually find a match between two records that
  /// differ only by ID (which is exactly what a retry/double-submission
  /// produces — same content, new SALE_<timestamp> id).
  static String billContentFingerprint(Map<String, dynamic> sale) {
    final day = _dayKey(sale['business_date'] ?? sale['sale_date'] ?? sale['created_at'] ?? sale['date']);
    final total = _num(sale['total']).toStringAsFixed(2);
    final items = sale['items'] as List? ?? [];

    if (items.isEmpty) {
      final product = FormatHelper.normalizeName((sale['product'] ?? 'unknown').toString());
      final qty = _num(sale['quantity'] ?? sale['qty'], 1).toStringAsFixed(2);
      final price = _num(sale['price']).toStringAsFixed(2);
      return '${day}_${product}_${qty}_${price}_$total';
    }

    final parts = <String>[];
    for (final raw in items) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final product = _productKey(item);
      final qty = _num(item['qty'] ?? item['quantity'], 1).toStringAsFixed(2);
      final price = _num(item['price']).toStringAsFixed(2);
      parts.add('${product}_${qty}_$price');
    }
    parts.sort();
    return '${day}_${parts.join('|')}_$total';
  }

  /// Content-only fingerprint — catches duplicate lines even with different sale_id.
  static String lineContentFingerprint(Map<String, dynamic> line) {
    final day = _dayKey(line['business_date'] ?? line['sale_date'] ?? line['created_at'] ?? line['date']);
    final product = FormatHelper.normalizeName(
      (line['product_name'] ?? line['product'] ?? line['item'] ?? 'unknown').toString(),
    );
    final qty = _num(line['quantity'] ?? line['qty'], 1).toStringAsFixed(2);
    final price = _num(line['price']).toStringAsFixed(2);
    final total = _num(line['total']).toStringAsFixed(2);
    return '${day}_${product}_${qty}_${price}_$total';
  }

  /// Prefer owner-created local bills over cloud-reimport copies.
  static bool _preferIncomingBill(Map<String, dynamic> existing, Map<String, dynamic> incoming) {
    final eId = (existing['sale_id'] ?? existing['id'] ?? '').toString();
    final iId = (incoming['sale_id'] ?? incoming['id'] ?? '').toString();
    final eCloud = existing['customer_name']?.toString() == 'Cloud Restore' || existing['is_synced'] == true;
    final iCloud = incoming['customer_name']?.toString() == 'Cloud Restore' || incoming['is_synced'] == true;

    if (eId.startsWith('SALE_') && !iId.startsWith('SALE_')) return false;
    if (iId.startsWith('SALE_') && !eId.startsWith('SALE_')) return true;
    if (!eCloud && iCloud) return false;
    if (eCloud && !iCloud) return true;
    return false;
  }

  /// Real bill only — rejects empty/zero rows that polluted dashboards.
  static bool isValidBill(Map<String, dynamic> sale) {
    if (sale['status']?.toString() == 'CANCELLED') return true;
    final total = _num(sale['total']);
    final items = sale['items'] as List? ?? [];
    if (items.isEmpty) {
      final price = _num(sale['price']);
      final qty = _num(sale['quantity'] ?? sale['qty'], 1);
      return price > 0 && qty > 0 && total > 0;
    }
    return total > 0 || items.isNotEmpty;
  }

  static String _lineName(Map<String, dynamic> line) =>
      (line['product_name'] ??
              line['product'] ??
              line['item'] ??
              line['description'] ??
              line['name'] ??
              '')
          .toString()
          .trim()
          .toLowerCase();

  static double _lineNumber(Object? value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static bool _sameBillLine(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    final leftId =
        (left['product_id'] ?? left['id'] ?? '').toString().trim();
    final rightId =
        (right['product_id'] ?? right['id'] ?? '').toString().trim();
    final leftName = _lineName(left);
    final rightName = _lineName(right);
    final sameProduct = leftId.isNotEmpty && rightId.isNotEmpty
        ? leftId == rightId
        : leftName.isNotEmpty && leftName == rightName;
    if (!sameProduct) return false;

    final leftQty = _lineNumber(left['quantity'] ?? left['qty'], 1);
    final rightQty = _lineNumber(right['quantity'] ?? right['qty'], 1);
    if (leftQty.toStringAsFixed(3) != rightQty.toStringAsFixed(3)) {
      return false;
    }
    final leftPriceRaw = left['unit_price'] ?? left['price'];
    final rightPriceRaw = right['unit_price'] ?? right['price'];
    if (leftPriceRaw != null && rightPriceRaw != null) {
      if (_lineNumber(leftPriceRaw).toStringAsFixed(2) !=
          _lineNumber(rightPriceRaw).toStringAsFixed(2)) {
        return false;
      }
    }
    for (final field in const [
      'discount',
      'discount_amount',
      'discount_rate',
      'tax',
      'tax_amount',
      'tax_rate',
      'gst_rate',
    ]) {
      final a = left[field];
      final b = right[field];
      if (a == null || b == null) continue;
      if (_lineNumber(a, -1) != _lineNumber(b, -1)) return false;
    }
    return true;
  }

  static List<Map<String, dynamic>> _saleLineSnapshot(
    Map<String, dynamic> sale,
  ) {
    final lines = <Map<String, dynamic>>[];

    void addSnapshot(dynamic raw) {
      if (raw is! List || raw.isEmpty) return;
      final incoming = raw
          .whereType<Map>()
          .map((line) => Map<String, dynamic>.from(line))
          .toList();
      if (lines.isEmpty) {
        lines.addAll(incoming);
        return;
      }

      final matched = <int>{};
      for (final line in incoming) {
        var matchIndex = -1;
        for (var i = 0; i < lines.length; i++) {
          if (matched.contains(i)) continue;
          if (_sameBillLine(lines[i], line)) {
            matchIndex = i;
            break;
          }
        }
        if (matchIndex < 0) {
          lines.add(line);
        } else {
          matched.add(matchIndex);
          lines[matchIndex] = <String, dynamic>{...lines[matchIndex], ...line}
            ..removeWhere((key, value) => value == null);
        }
      }
    }

    final itemList = sale['items'];
    final lineItemList = sale['line_items'];
    addSnapshot(
      lineItemList is List && lineItemList.isNotEmpty
          ? lineItemList
          : itemList,
    );
    if (itemList is List &&
        lineItemList is List &&
        !identical(itemList, lineItemList)) {
      addSnapshot(
        identical(lineItemList, itemList) ? const [] : itemList,
      );
    }

    if (lines.isEmpty) {
      final name = _lineName(sale);
      if (name.isNotEmpty || sale['product_id'] != null) {
        lines.add(<String, dynamic>{
          ...sale,
          if (name.isNotEmpty) 'product_name': name,
        });
      }
    }
    return lines;
  }

  static List<Map<String, dynamic>> _mergeBillLineSnapshots(
    Map<String, dynamic> existing,
    Map<String, dynamic> incoming,
  ) {
    final result = _saleLineSnapshot(existing);
    final additions = _saleLineSnapshot(incoming);
    final matched = <int>{};
    for (final line in additions) {
      var matchIndex = -1;
      for (var i = 0; i < result.length; i++) {
        if (matched.contains(i)) continue;
        if (_sameBillLine(result[i], line)) {
          matchIndex = i;
          break;
        }
      }
      if (matchIndex < 0) {
        result.add(Map<String, dynamic>.from(line));
      } else {
        matched.add(matchIndex);
        result[matchIndex] = <String, dynamic>{...result[matchIndex], ...line}
          ..removeWhere((key, value) => value == null);
      }
    }
    return result;
  }

  /// Remove only true duplicate records. Stable business identities always win;
  /// content similarity alone must NEVER merge two legitimate sales.
  static List<Map<String, dynamic>> dedupeBills(List<dynamic> raw) {
    final active = <Map<String, dynamic>>[];
    final anonymous = <Map<String, dynamic>>[];
    final cancelled = <Map<String, dynamic>>[];

    for (final entry in raw) {
      if (entry is! Map) continue;
      final sale = Map<String, dynamic>.from(entry);
      // Preserve incomplete but identified records until reconciliation. The
      // analytics layer filters invalid values; storage must not erase them.


      if (sale['status']?.toString().toUpperCase() == 'CANCELLED') {
        cancelled.add(sale);
        continue;
      }

      if (InvoiceDedupHelper.identityTokens(sale).isEmpty) {
        // Without stable identifiers it is unsafe to merge by matching amount,
        // product, or timestamp. Keep independent anonymous sales separate.
        anonymous.add(sale);
        continue;
      }
      active.add(sale);
    }

    // Treat all identifiers on a sale as aliases for the same transaction.
    // Example: a local sale may have sale_id=SALE_x and invoice_number=BILL_x,
    // while a restored copy may have sale_id=BILL_x. A single "primary ID"
    // map fails to connect these copies; connected components do not.
    final parents = List<int>.generate(active.length, (index) => index);

    int root(int index) {
      var current = index;
      while (parents[current] != current) {
        parents[current] = parents[parents[current]];
        current = parents[current];
      }
      return current;
    }

    void union(int left, int right) {
      final a = root(left);
      final b = root(right);
      if (a != b) parents[b] = a;
    }

    final tokenOwner = <String, int>{};
    for (var index = 0; index < active.length; index++) {
      for (final token in InvoiceDedupHelper.identityTokens(active[index])) {
        final previous = tokenOwner[token];
        if (previous == null) {
          tokenOwner[token] = index;
        } else {
          union(index, previous);
        }
      }
    }

    final groups = <int, List<Map<String, dynamic>>>{};
    for (var index = 0; index < active.length; index++) {
      groups.putIfAbsent(root(index), () => <Map<String, dynamic>>[]).add(active[index]);
    }

    final deduped = <Map<String, dynamic>>[];
    for (final group in groups.values) {
      var merged = Map<String, dynamic>.from(group.first);
      for (final incomingRaw in group.skip(1)) {
        final incoming = Map<String, dynamic>.from(incomingRaw);
        final previous = Map<String, dynamic>.from(merged);
        final reconciledLines = _mergeBillLineSnapshots(merged, incoming);

        if (_preferIncomingBill(merged, incoming)) {
          merged = <String, dynamic>{...merged, ...incoming};
          // Keep the losing record's aliases and useful values if the preferred
          // copy leaves a field empty, so later syncs can still match this bill.
          for (final entry in previous.entries) {
            final current = merged[entry.key];
            if (current == null || current.toString().trim().isEmpty) {
              merged[entry.key] = entry.value;
            }
          }
        } else {
          // Existing/local data wins by default, but missing server identifiers
          // and richer fields are retained for future idempotent reconciliation.
          for (final entry in incoming.entries) {
            final current = merged[entry.key];
            final value = entry.value;
            if (current == null || current.toString().trim().isEmpty) {
              merged[entry.key] = value;
            }
          }
        }
        if (reconciledLines.isNotEmpty) {
          merged['items'] = reconciledLines;
          merged['line_items'] = reconciledLines;
        }
      }
      deduped.add(merged);
    }

    return [...deduped, ...anonymous, ...cancelled];
  }

  /// Remove duplicate flattened lines shown in charts/transactions.
  /// A content fingerprint is only safe when the line is tied to a stable sale
  /// identity; anonymous lines are preserved because two real sales may have
  /// identical content.
  static List<Map<String, dynamic>> dedupeFlattenedLines(List<Map<String, dynamic>> lines) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];

    for (final line in lines) {
      final saleId = (line['sale_id'] ??
              line['invoice_number'] ??
              line['offline_id'] ??
              line['backend_id'] ??
              '')
          .toString()
          .trim();

      if (saleId.isEmpty) {
        out.add(line);
        continue;
      }

      final fp = lineContentFingerprint(line);
      final compositeKey = '${saleId}_$fp';
      if (seen.contains(compositeKey)) continue;
      seen.add(compositeKey);
      out.add(line);
    }
    return out;
  }

  /// Option B: one-time cleanup — dedupe Hive bills and persist if changed.
  static Future<SalesCleanupResult> cleanupAndPersist() async {
    final raw = await LocalStorageService.loadSales();
    final before = raw.length;
    final deduped = dedupeBills(raw);
    final after = deduped.length;

    if (after < before) {
      await LocalStorageService.saveSales(deduped);
      if (kDebugMode) debugPrint('🧹 Sales cleanup: removed ${before - after} duplicate bills ($after remain)');
    }

    return SalesCleanupResult(before: before, after: after, removed: before - after);
  }

  /// True only when the cloud and local records share a canonical identity
  /// alias. Numeric backend IDs remain namespaced apart from bill numbers.
  /// Content similarity is never sufficient to declare two sales duplicates.
  static bool isDuplicateBill(
    Map<String, dynamic> cloud,
    Iterable<Map<String, dynamic>> localBills,
  ) {
    return localBills.any(
      (local) => InvoiceDedupHelper.sameInvoice(cloud, local),
    );
  }

  /// Group API line rows (one row per item) into bills by sale_id.
  static List<Map<String, dynamic>> groupApiLinesIntoBills(List<dynamic> apiSales) {
    final Map<String, Map<String, dynamic>> grouped = {};

    for (final raw in apiSales) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);

      final price = _num(item['price']);
      final qty = _num(item['quantity'] ?? item['qty'], 1);
      if (price <= 0 || qty <= 0) continue;

      final lineTotal = _num(item['total'], CurrencyManager.multiply(price, qty));
      final timestamp = item['sale_date'] ?? item['created_at'] ?? DateTime.now().toUtc().toIso8601String();
      final saleId = (item['sale_id'] ?? item['id'] ?? 'API_${item.hashCode}').toString();
      final product = (item['product'] ?? item['product_name'] ?? item['item'] ?? item['name'] ?? item['itemName'] ?? item['title'] ?? '').toString().trim();

      if (product.isEmpty || product.toLowerCase() == 'unknown' || product.toLowerCase() == 'unknown item' || product.toLowerCase() == 'product') {
        if (kDebugMode) debugPrint('Skipping invalid restored record: $saleId');
        continue;
      }
      
      if (kDebugMode) {
        debugPrint('SALE RESTORED:\ninvoice_number: $saleId\nproduct_name: $product\nquantity: $qty\nprice: $price');
      }

      grouped.putIfAbsent(saleId, () => {
        'sale_id': saleId,
        'customer_name': item['customer_name'] ?? 'Cloud Restore',
        'items': <Map<String, dynamic>>[],
        'sale_date': timestamp,
        'created_at': timestamp,
        'date': timestamp,
        'total': 0.0,
        'paid_amount': 0.0,
        'payment_status': 'PAID',
        'is_synced': true,
      });

      final bill = grouped[saleId]!;
      (bill['items'] as List).add({
        'product_name': product,
        'item': product,
        'qty': qty,
        'quantity': qty,
        'price': price,
        'total': lineTotal,
        'total_with_tax': lineTotal,
      });
      bill['total'] = _num(bill['total']) + lineTotal;
      bill['paid_amount'] = bill['total'];
    }

    return grouped.values.map((b) => Map<String, dynamic>.from(b)).toList();
  }
}