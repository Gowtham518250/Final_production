/// Identity-based reconciliation for invoice mirrors and restored sales.
///
/// A bill can exist as a local sale, a local invoice and a cloud-restored row.
/// Use all stable identifiers and merge connected alias groups; never merge
/// separate transactions merely because their amounts or contents look alike.
class InvoiceDedupHelper {
  static const List<String> _transactionFields = <String>[
    'invoice_number',
    'number',
    'sale_id',
    'offline_id',
  ];

  static const List<String> _backendIdFields = <String>[
    'invoice_id',
    'backend_id',
    'invoiceId',
    'id',
  ];

  static double _number(dynamic value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static String _normalized(dynamic value) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    if (text.isEmpty || text == 'null' || text == '0') return '';
    return text;
  }

  static Set<String> identityTokens(Map<String, dynamic> row) {
    final tokens = <String>{};

    for (final field in _transactionFields) {
      final value = _normalized(row[field]);
      if (value.isNotEmpty) tokens.add('transaction:' + value);
    }

    for (final field in _backendIdFields) {
      final value = _normalized(row[field]);
      if (value.isEmpty) continue;

      final isNumericId = value.codeUnits.every(
        (code) => code >= 48 && code <= 57,
      );
      if (isNumericId) {
        // Namespaces prevent invoice number "12" matching database id 12.
        tokens.add('backend:' + value);
      } else {
        // Legacy clients sometimes put the customer-facing bill number in id fields.
        tokens
          ..add('backend:' + value)
          ..add('transaction:' + value);
      }
    }

    return tokens;
  }

  static bool sameInvoice(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    final leftTokens = identityTokens(left);
    if (leftTokens.isEmpty) return false;
    return leftTokens.intersection(identityTokens(right)).isNotEmpty;
  }

  static int _timestamp(dynamic value) {
    if (value is DateTime) return value.millisecondsSinceEpoch;
    if (value is num) return value.toInt();
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return 0;
    return DateTime.tryParse(text)?.millisecondsSinceEpoch ?? 0;
  }

  static int _rowTimestamp(Map<String, dynamic> row) {
    return _timestamp(
      row['updated_at'] ??
          row['last_updated'] ??
          row['modified_at'] ??
          row['created_at'] ??
          row['invoice_date'] ??
          row['date'],
    );
  }

  static double _rowTotal(Map<String, dynamic> row) {
    for (final field in const <String>[
      'total_amount',
      'totalAmount',
      'total',
      'invoice_total',
      'grand_total',
      'final_amount',
      'amount',
    ]) {
      final value = _number(row[field], -1);
      if (value > 0) return value;
    }
    return 0;
  }

  static double _rowPaid(Map<String, dynamic> row, double total) {
    var paid = 0.0;
    for (final field in const <String>[
      'paid_amount',
      'amount_paid',
      'paid',
      'received_amount',
    ]) {
      final value = row[field];
      if (value != null) {
        final parsed = _number(value, -1);
        if (parsed > paid) paid = parsed;
      }
    }

    final paymentStatus = (row['payment_status'] ?? '')
        .toString()
        .split('.')
        .last
        .trim()
        .toUpperCase();
    final invoiceStatus = (row['status'] ?? '')
        .toString()
        .split('.')
        .last
        .trim()
        .toUpperCase();

    if (total > 0 &&
        paid <= 0 &&
        (paymentStatus == 'PAID' || invoiceStatus == 'PAID')) {
      // Some legacy rows say PAID but did not persist paid_amount.
      paid = total;
    }
    return paid.clamp(0.0, total).toDouble();
  }

  static Map<String, dynamic> _mergeGroup(
    List<Map<String, dynamic>> group,
  ) {
    final ordered = List<Map<String, dynamic>>.from(group)
      ..sort((a, b) => _rowTimestamp(a).compareTo(_rowTimestamp(b)));

    final merged = <String, dynamic>{};
    final mergedLines = <Map<String, dynamic>>[];
    var highestPaid = 0.0;
    var newestTotal = 0.0;
    var anyPaymentState = false;

    String lineName(Map<String, dynamic> line) =>
        (line['product_name'] ??
                line['product'] ??
                line['item'] ??
                line['description'] ??
                line['name'] ??
                '')
            .toString()
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

    bool sameLine(Map<String, dynamic> left, Map<String, dynamic> right) {
      final leftId = (left['product_id'] ?? '').toString().trim();
      final rightId = (right['product_id'] ?? '').toString().trim();
      final leftName = lineName(left);
      final rightName = lineName(right);
      // Local and cloud catalog IDs can differ for the same visible item.
      // Match by stable ID OR normalized name, then require the same quantity,
      // price and financial modifiers below. Snapshot matching remains
      // one-to-one, so two intentional identical lines in one bill are kept.
      final sameProductById =
          leftId.isNotEmpty && rightId.isNotEmpty && leftId == rightId;
      final sameProductByName =
          leftName.isNotEmpty && leftName == rightName;
      if (!sameProductById && !sameProductByName) return false;
      final leftQty = _number(left['quantity'] ?? left['qty'], 1);
      final rightQty = _number(right['quantity'] ?? right['qty'], 1);
      if (leftQty.toStringAsFixed(3) != rightQty.toStringAsFixed(3)) {
        return false;
      }
      final leftPriceRaw = left['unit_price'] ?? left['price'];
      final rightPriceRaw = right['unit_price'] ?? right['price'];
      // A partial mirror may omit price. Compare only when both sides include
      // a price, rather than turning missing data into a false mismatch.
      if (leftPriceRaw != null && rightPriceRaw != null) {
        final leftPrice = _number(leftPriceRaw);
        final rightPrice = _number(rightPriceRaw);
        if (leftPrice.toStringAsFixed(2) != rightPrice.toStringAsFixed(2)) {
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
        if (_number(a, -1) != _number(b, -1)) return false;
      }
      return true;
    }

    void addNestedSnapshot(List<Map<String, dynamic>> incoming) {
      if (incoming.isEmpty) return;
      if (mergedLines.isEmpty) {
        mergedLines.addAll(incoming);
        return;
      }
      // One-to-one matching preserves repeated identical products in a bill.
      final matched = <int>{};
      for (final line in incoming) {
        var matchIndex = -1;
        for (var i = 0; i < mergedLines.length; i++) {
          if (matched.contains(i)) continue;
          if (sameLine(mergedLines[i], line)) {
            matchIndex = i;
            break;
          }
        }
        if (matchIndex < 0) {
          mergedLines.add(line);
        } else {
          matched.add(matchIndex);
          mergedLines[matchIndex] = <String, dynamic>{
            ...mergedLines[matchIndex],
            ...line,
          }..removeWhere((key, value) => value == null);
        }
      }
    }

    final flatLines = <Map<String, dynamic>>[];
    var hasNestedSnapshot = false;

    void addRowLines(Map<String, dynamic> row) {
      // items and line_items are often aliases of the same collection.
      // Read one canonical alias rather than importing the collection twice.
      final lineItems = row['line_items'];
      final items = row['items'];
      final raw = lineItems is List && lineItems.isNotEmpty
          ? lineItems
          : items is List
              ? items
              : lineItems;

      if (raw is List && raw.isNotEmpty) {
        final incoming = raw
            .whereType<Map>()
            .map((value) => Map<String, dynamic>.from(value))
            .toList();
        if (!hasNestedSnapshot) {
          mergedLines.addAll(incoming);
          hasNestedSnapshot = true;
        } else {
          addNestedSnapshot(incoming);
        }

        // Some clients serialize partial line collections independently under
        // items and line_items. Merge the alternate list too when it is not
        // the exact same list object; identical snapshots reconcile one-to-one.
        if (lineItems is List &&
            items is List &&
            !identical(lineItems, items)) {
          final alternate = identical(raw, lineItems) ? items : lineItems;
          final alternateLines = alternate
              .whereType<Map>()
              .map((value) => Map<String, dynamic>.from(value))
              .toList();
          addNestedSnapshot(alternateLines);
        }
        return;
      }

      // Legacy invoice feeds can expose one product per top-level row. Keep
      // every flattened row, including records with incomplete financial data.
      final name = (row['product_name'] ??
              row['product'] ??
              row['item'] ??
              row['name'] ??
              row['description'] ??
              '')
          .toString()
          .trim();
      if (name.isEmpty && row['product_id'] == null) return;
      final quantity = _number(row['quantity'] ?? row['qty'], 1);
      final unitPrice = _number(row['unit_price'] ?? row['price']);
      final lineTotal = _number(
        row['line_total'] ??
            row['final_amount'] ??
            row['total'] ??
            row['totalAmount'],
      );
      flatLines.add(<String, dynamic>{
        ...row,
        'product_name': name,
        'description': row['description'] ?? name,
        'quantity': quantity,
        'qty': quantity,
        'unit_price': unitPrice,
        'price': unitPrice,
        'line_total': lineTotal > 0 ? lineTotal : unitPrice * quantity,
        'total': lineTotal > 0 ? lineTotal : unitPrice * quantity,
      });
    }

    for (final row in ordered) {
      addRowLines(row);
    }

    // Flat rows can mirror a nested snapshot from another representation.
    // Pair each match once; unmatched rows remain legitimate invoice lines.
    final matchedNested = <int>{};
    for (final line in flatLines) {
      var matchIndex = -1;
      for (var i = 0; i < mergedLines.length; i++) {
        if (matchedNested.contains(i)) continue;
        if (sameLine(mergedLines[i], line)) {
          matchIndex = i;
          break;
        }
      }
      if (matchIndex < 0) {
        mergedLines.add(line);
      } else {
        matchedNested.add(matchIndex);
        mergedLines[matchIndex] = <String, dynamic>{
          ...mergedLines[matchIndex],
          ...line,
        }..removeWhere((key, value) => value == null);
      }
    }

    for (final row in ordered) {
      final total = _rowTotal(row);
      if (total > 0) newestTotal = total;

      final paid = _rowPaid(row, total);
      if (paid > highestPaid) highestPaid = paid;

      final payStatus = (row['payment_status'] ?? row['status'] ?? '')
          .toString()
          .split('.')
          .last
          .trim()
          .toUpperCase();
      if (payStatus == 'PAID' ||
          payStatus == 'PARTIAL' ||
          payStatus == 'UNPAID') {
        anyPaymentState = true;
      }

      // Later records win, but blank/null values cannot erase useful aliases
      // or line items that only exist in an older local representation.
      for (final entry in row.entries) {
        final value = entry.value;
        if (value == null) continue;
        if (value is String && value.trim().isEmpty) continue;
        merged[entry.key] = value;
      }
    }

    if (newestTotal > 0) {
      final total = newestTotal;
      final paid = highestPaid.clamp(0.0, total).toDouble();
      final status = paid >= total - 0.01
          ? 'PAID'
          : (paid > 0 ? 'PARTIAL' : 'UNPAID');

      merged['total_amount'] = total;
      merged['paid_amount'] = double.parse(paid.toStringAsFixed(2));
      merged['pending_amount'] =
          (total - paid).clamp(0.0, double.infinity).toDouble();

      if (anyPaymentState || paid > 0) {
        merged['payment_status'] = status;
      }
      if (status == 'PAID' || status == 'PARTIAL') {
        merged['status'] = status;
      } else {
        final oldStatus = (merged['status'] ?? '')
            .toString()
            .split('.')
            .last
            .trim()
            .toUpperCase();
        if (oldStatus == 'PAID' || oldStatus == 'PARTIAL') {
          merged['status'] = 'UNPAID';
        }
      }
    }

    if (mergedLines.isNotEmpty) {
      merged['items'] = mergedLines;
      merged['line_items'] = mergedLines;
    }

    return merged;
  }

  static Set<String> _fieldValues(
    Map<String, dynamic> row,
    List<String> fields,
  ) => fields
      .map((field) => _normalized(row[field]))
      .where((value) => value.isNotEmpty)
      .toSet();

  /// Invoice Analytics is an invoice ledger, not the general sales ledger.
  /// Standalone retail sales remain in Sales reporting. Only sales with an
  /// explicit invoice foreign key/number or shared offline-sale key are merged
  /// as mirrors of a real invoice.
  static List<Map<String, dynamic>> canonicalizeInvoiceLedger(
    List<dynamic> invoices,
    List<dynamic> sales,
  ) {
    final invoiceRows = invoices
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

    final saleRows = sales
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

    // Index each explicit invoice link once. The previous implementation
    // scanned every invoice for every sale row (O(invoices × sales)), which
    // made opening Khata increasingly slow as a shop's history grew.
    final invoiceIds = <String>{};
    final invoiceNumbers = <String>{};
    final invoiceSaleReferences = <String>{};

    for (final invoice in invoiceRows) {
      invoiceIds.addAll(
        _fieldValues(invoice, const [
          'id', 'invoice_id', 'invoiceId', 'backend_id', 'server_id',
        ]),
      );
      invoiceNumbers.addAll(
        _fieldValues(invoice, const [
          'invoice_number', 'invoice_no', 'bill_number', 'bill_no', 'number',
        ]),
      );
      invoiceSaleReferences.addAll(
        _fieldValues(invoice, const [
          'sale_id', 'offline_id', 'local_sale_id', 'source_sale_id',
          'original_sale_id',
        ]),
      );
    }

    final saleMirrors = <Map<String, dynamic>>[];
    for (final sale in saleRows) {
      final foreignKeys = _fieldValues(sale, const [
        'invoice_id', 'invoiceId', 'backend_invoice_id',
      ]);
      final billNumbers = _fieldValues(sale, const [
        'invoice_number', 'invoice_no', 'bill_number', 'bill_no',
      ]);
      final saleReferences = _fieldValues(sale, const [
        'sale_id', 'offline_id', 'local_sale_id', 'source_sale_id', 'id',
      ]);

      if (foreignKeys.any(invoiceIds.contains) ||
          billNumbers.any(invoiceNumbers.contains) ||
          saleReferences.any(invoiceSaleReferences.contains)) {
        saleMirrors.add(sale);
      }
    }

    return canonicalizeInvoices(<dynamic>[
      ...invoiceRows,
      ...saleMirrors,
    ]);
  }

  static List<Map<String, dynamic>> canonicalizeInvoices(
    List<dynamic> rawRows,
  ) {
    final rows = rawRows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

    if (rows.length < 2) {
      return rows.map((row) => _mergeGroup(<Map<String, dynamic>>[row])).toList();
    }

    final parents = List<int>.generate(rows.length, (index) => index);

    int root(int value) {
      var index = value;
      while (parents[index] != index) {
        parents[index] = parents[parents[index]];
        index = parents[index];
      }
      return index;
    }

    void union(int left, int right) {
      final a = root(left);
      final b = root(right);
      if (a != b) parents[b] = a;
    }

    final tokenOwner = <String, int>{};
    for (var i = 0; i < rows.length; i++) {
      for (final token in identityTokens(rows[i])) {
        final previous = tokenOwner[token];
        if (previous == null) {
          tokenOwner[token] = i;
        } else {
          union(i, previous);
        }
      }
    }

    // Build groups only after all unions: one bridge row may connect two groups.
    final groups = <int, List<Map<String, dynamic>>>{};
    for (var i = 0; i < rows.length; i++) {
      groups.putIfAbsent(root(i), () => <Map<String, dynamic>>[]).add(rows[i]);
    }

    return groups.values
        .map((group) => _mergeGroup(group))
        .toList();
  }
}
