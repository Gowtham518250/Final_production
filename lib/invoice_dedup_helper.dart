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

  // Generic table IDs are not cross-table aliases. Explicit invoice IDs
  // remain namespaced separately from customer-facing invoice numbers.
  static const List<String> _backendIdFields = <String>[
    'invoice_id',
    'backend_id',
    'invoiceId',
    'server_id',
    'backend_invoice_id',
    'canonical_invoice_id',
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

  static Map<String, dynamic> _mergeGroup(
    List<Map<String, dynamic>> group,
  ) {
    final indexed = group.asMap().entries.toList()
      ..sort((a, b) {
        final byTime = _rowTimestamp(a.value).compareTo(_rowTimestamp(b.value));
        return byTime != 0 ? byTime : a.key.compareTo(b.key);
      });
    final ordered = indexed.map((entry) => entry.value).toList();
    final merged = <String, dynamic>{};
    final mergedLines = <Map<String, dynamic>>[];
    final reconciliationConflicts = <String>[];

    String lineName(Map<String, dynamic> line) =>
        (line['product_name'] ??
                line['product'] ??
                line['item'] ??
                line['description'] ??
                line['name'] ??
                '')
            .toString()
            .trim()
            .toLowerCase();

    bool sameLine(Map<String, dynamic> left, Map<String, dynamic> right) {
      final leftLineId = _normalized(
        left['line_id'] ?? left['invoice_item_id'] ?? left['item_id'],
      );
      final rightLineId = _normalized(
        right['line_id'] ?? right['invoice_item_id'] ?? right['item_id'],
      );
      if (leftLineId.isNotEmpty && rightLineId.isNotEmpty) {
        return leftLineId == rightLineId;
      }

      final leftId = _normalized(left['product_id']);
      final rightId = _normalized(right['product_id']);
      final leftName = lineName(left);
      final rightName = lineName(right);
      final sameProduct = leftId.isNotEmpty && rightId.isNotEmpty
          ? leftId == rightId
          : leftName.isNotEmpty && leftName == rightName;
      if (!sameProduct) return false;

      final leftQty = _number(left['quantity'] ?? left['qty'], 1);
      final rightQty = _number(right['quantity'] ?? right['qty'], 1);
      final leftPrice = _number(left['unit_price'] ?? left['price']);
      final rightPrice = _number(right['unit_price'] ?? right['price']);
      if (leftQty.toStringAsFixed(3) != rightQty.toStringAsFixed(3) ||
          leftPrice.toStringAsFixed(2) != rightPrice.toStringAsFixed(2)) {
        return false;
      }
      for (final field in const [
        'line_total',
        'total_with_tax',
        'discount',
        'discount_amount',
        'gst_rate',
        'tax_rate',
      ]) {
        if (left[field] == null || right[field] == null) continue;
        final leftValue = _number(left[field], double.nan);
        final rightValue = _number(right[field], double.nan);
        if (leftValue.isFinite &&
            rightValue.isFinite &&
            (leftValue - rightValue).abs() > 0.009) {
          return false;
        }
      }
      return true;
    }

    List<Map<String, dynamic>> rowLines(Map<String, dynamic> row) {
      // items and line_items are commonly aliases; use one populated list.
      var hasExplicitLineList = false;
      for (final field in const ['items', 'line_items']) {
        final raw = row[field];
        if (raw is List) {
          hasExplicitLineList = true;
          if (raw.isNotEmpty) {
            return raw
                .whereType<Map>()
                .map((value) => Map<String, dynamic>.from(value))
                .toList();
          }
        }
      }
      final hasFlatProduct = (row['product_name'] ??
              row['product'] ??
              row['item'] ??
              row['name'] ??
              row['description'] ??
              '')
          .toString()
          .trim()
          .isNotEmpty;
      if (hasExplicitLineList && !hasFlatProduct) {
        return <Map<String, dynamic>>[];
      }

      // Legacy sales endpoints expose one product at the top level per row.
      final name = (row['product_name'] ??
              row['product'] ??
              row['item'] ??
              row['name'] ??
              row['description'] ??
              '')
          .toString()
          .trim();
      if (name.isEmpty ||
          name.toLowerCase() == 'unknown' ||
          name.toLowerCase() == 'unknown product' ||
          name.toLowerCase() == 'unknown item') {
        return <Map<String, dynamic>>[];
      }

      final quantity = _number(row['quantity'] ?? row['qty'], 1);
      final unitPrice = _number(row['unit_price'] ?? row['price']);
      final lineTotal = _number(
        row['line_total'] ??
            row['final_amount'] ??
            row['total'] ??
            row['totalAmount'],
      );
      if (quantity <= 0 || (unitPrice <= 0 && lineTotal <= 0)) {
        return <Map<String, dynamic>>[];
      }

      return <Map<String, dynamic>>[
        <String, dynamic>{
          'line_id': row['_item_idx'] != null
              ? 'dashboard-index:${row['_item_idx']}'
              : (row['line_id'] ?? row['invoice_item_id'] ?? row['id']),
          'product_id': row['product_id'],
          'product_name': name,
          'description': name,
          'quantity': quantity,
          'qty': quantity,
          'unit_price': unitPrice,
          'price': unitPrice,
          'line_total': lineTotal > 0 ? lineTotal : unitPrice * quantity,
          'total': lineTotal > 0 ? lineTotal : unitPrice * quantity,
        },
      ];
    }

    var latestNestedSnapshot = -1;
    var oldestNestedTimestamp = 0;
    var newestNestedTimestamp = 0;
    for (var index = 0; index < ordered.length; index++) {
      final row = ordered[index];
      final hasLineList = row['items'] is List || row['line_items'] is List;
      final flatName = (row['product_name'] ??
              row['product'] ??
              row['item'] ??
              row['name'] ??
              row['description'] ??
              '')
          .toString()
          .trim();
      final hasNestedSnapshot = hasLineList &&
          ((row['items'] is List && (row['items'] as List).isNotEmpty) ||
              (row['line_items'] is List && (row['line_items'] as List).isNotEmpty) ||
              flatName.isEmpty);
      if (hasNestedSnapshot) {
        final timestamp = _rowTimestamp(row);
        if (latestNestedSnapshot < 0) {
          oldestNestedTimestamp = timestamp;
          newestNestedTimestamp = timestamp;
        } else {
          if (timestamp < oldestNestedTimestamp) {
            oldestNestedTimestamp = timestamp;
          }
          if (timestamp > newestNestedTimestamp) {
            newestNestedTimestamp = timestamp;
          }
        }
        latestNestedSnapshot = index;
      }
    }

    final hasNewerDatedSnapshot = latestNestedSnapshot >= 0 &&
        oldestNestedTimestamp > 0 &&
        newestNestedTimestamp > oldestNestedTimestamp;

    if (hasNewerDatedSnapshot) {
      final authoritativeLines = rowLines(ordered[latestNestedSnapshot]);
      mergedLines.addAll(authoritativeLines);

      // Enrich surviving latest lines from older mirrors one-to-one. Older
      // lines absent from the newer complete snapshot are not resurrected.
      for (var rowIndex = 0; rowIndex < latestNestedSnapshot; rowIndex++) {
        final olderLines = rowLines(ordered[rowIndex]);
        final matchedLatestIndexes = <int>{};
        for (final olderLine in olderLines) {
          for (var lineIndex = 0; lineIndex < mergedLines.length; lineIndex++) {
            if (matchedLatestIndexes.contains(lineIndex)) continue;
            if (sameLine(mergedLines[lineIndex], olderLine)) {
              matchedLatestIndexes.add(lineIndex);
              mergedLines[lineIndex] = <String, dynamic>{
                ...olderLine,
                ...mergedLines[lineIndex],
              }..removeWhere((key, value) => value == null);
              break;
            }
          }
        }
      }
    } else {
      // Without a trustworthy ordering, mirror arrays may be complementary.
      // Merge them one-to-one: preserve repeated lines in each invoice while
      // avoiding multiplication of the same repeated lines across mirror copies.
      for (final row in ordered) {
        final incomingLines = rowLines(row);
        final matchedExistingIndexes = <int>{};
        final hasNestedLines =
            (row['items'] is List && (row['items'] as List).isNotEmpty) ||
            (row['line_items'] is List && (row['line_items'] as List).isNotEmpty);

        for (final incomingLine in incomingLines) {
          var matchIndex = -1;

          // For flat one-row-per-item feeds, content equality is ambiguous:
          // two genuine identical lines may be separate rows. Only a stable
          // line ID is safe for matching flat rows across mirrors.
          final incomingLineId = _normalized(
            incomingLine['line_id'] ??
                incomingLine['invoice_item_id'] ??
                incomingLine['item_id'],
          );
          for (var lineIndex = 0; lineIndex < mergedLines.length; lineIndex++) {
            if (matchedExistingIndexes.contains(lineIndex)) continue;
            if (!hasNestedLines) {
              if (incomingLineId.isNotEmpty &&
                  incomingLineId ==
                      _normalized(
                        mergedLines[lineIndex]['line_id'] ??
                            mergedLines[lineIndex]['invoice_item_id'] ??
                            mergedLines[lineIndex]['item_id'],
                      )) {
                matchIndex = lineIndex;
                break;
              }
            } else if (sameLine(mergedLines[lineIndex], incomingLine)) {
              matchIndex = lineIndex;
              break;
            }
          }

          if (matchIndex < 0) {
            mergedLines.add(incomingLine);
            // A second identical line in this same invoice must not match the
            // line just added for the first occurrence.
            matchedExistingIndexes.add(mergedLines.length - 1);
          } else {
            matchedExistingIndexes.add(matchIndex);
            mergedLines[matchIndex] = <String, dynamic>{
              ...mergedLines[matchIndex],
              ...incomingLine,
            }..removeWhere((key, value) => value == null);
          }
        }
      }
    }

    // Ordinary fields follow the newest non-empty row.
    for (final row in ordered) {
      for (final entry in row.entries) {
        if (entry.key == 'items' || entry.key == 'line_items') continue;
        final value = entry.value;
        if (value == null) continue;
        if (value is String && value.trim().isEmpty) continue;
        merged[entry.key] = value;
      }
    }

    MapEntry<String, double>? numericField(
      Map<String, dynamic> row,
      List<String> fields,
    ) {
      for (final field in fields) {
        if (!row.containsKey(field) || row[field] == null) continue;
        final parsed = _number(row[field], double.nan);
        if (parsed.isFinite) return MapEntry(field, parsed);
      }
      return null;
    }

    const totalFields = <String>[
      'invoice_total',
      'total_amount',
      'grand_total',
      'final_amount',
      'totalAmount',
      'total',
      'amount',
    ];
    const paidFields = <String>[
      'paid_amount',
      'amount_paid',
      'paid',
      'received_amount',
    ];

    var hasTotal = false;
    var selectedTotal = 0.0;
    var totalTimestamp = -1;
    var hasPaid = false;
    var selectedPaid = 0.0;
    var paidTimestamp = -1;

    for (final row in ordered) {
      final timestamp = _rowTimestamp(row);
      final totalEntry = numericField(row, totalFields);
      if (totalEntry != null) {
        if (!hasTotal || timestamp >= totalTimestamp) {
          if (hasTotal &&
              timestamp == totalTimestamp &&
              (totalEntry.value - selectedTotal).abs() > 0.009) {
            reconciliationConflicts.add(
              'Conflicting invoice totals at the same or unknown update time; latest input row selected',
            );
          }
          hasTotal = true;
          selectedTotal = totalEntry.value;
          totalTimestamp = timestamp;
        }
      }

      final paidEntry = numericField(row, paidFields);
      if (paidEntry != null) {
        if (!hasPaid || timestamp >= paidTimestamp) {
          if (hasPaid &&
              timestamp == paidTimestamp &&
              (paidEntry.value - selectedPaid).abs() > 0.009) {
            reconciliationConflicts.add(
              'Conflicting paid amounts at the same or unknown update time; latest input row selected',
            );
          }
          hasPaid = true;
          selectedPaid = paidEntry.value;
          paidTimestamp = timestamp;
        }
      }
    }

    if (hasTotal) {
      merged['total_amount'] = double.parse(selectedTotal.toStringAsFixed(2));
      if (!hasPaid) {
        // Legacy PAID rows may omit paid_amount. Infer only when no persisted
        // payment amount exists; an explicit paid_amount: 0 remains zero.
        final status = (merged['payment_status'] ?? merged['status'] ?? '')
            .toString()
            .split('.')
            .last
            .trim()
            .toUpperCase();
        selectedPaid = status == 'PAID' ? selectedTotal : 0.0;
      }

      final paid = selectedPaid.clamp(0.0, selectedTotal).toDouble();
      merged['paid_amount'] = double.parse(paid.toStringAsFixed(2));
      merged['pending_amount'] =
          (selectedTotal - paid).clamp(0.0, double.infinity).toDouble();

      final derivedPaymentStatus = paid >= selectedTotal - 0.01
          ? 'PAID'
          : (paid > 0 ? 'PARTIAL' : 'UNPAID');
      final paymentStatus = (merged['payment_status'] ?? '')
          .toString()
          .split('.')
          .last
          .trim()
          .toUpperCase();
      if (paymentStatus.isEmpty ||
          const {'PAID', 'PARTIAL', 'UNPAID'}.contains(paymentStatus)) {
        merged['payment_status'] = derivedPaymentStatus;
      }
      final invoiceStatus = (merged['status'] ?? '')
          .toString()
          .split('.')
          .last
          .trim()
          .toUpperCase();
      if (const {'PAID', 'PARTIAL', 'UNPAID'}.contains(invoiceStatus)) {
        merged['status'] = derivedPaymentStatus;
      }
    }

    if (mergedLines.isNotEmpty) {
      merged['items'] = mergedLines;
      merged['line_items'] = mergedLines;
    }
    if (reconciliationConflicts.isNotEmpty) {
      merged['reconciliation_conflicts'] =
          reconciliationConflicts.toSet().toList();
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
        .map((row) {
          final invoice = Map<String, dynamic>.from(row);
          final explicitBackendId = _normalized(
            invoice['invoice_id'] ??
                invoice['backend_id'] ??
                invoice['invoiceId'] ??
                invoice['server_id'],
          );
          final tablePrimaryKey = _normalized(invoice['id']);
          if (explicitBackendId.isEmpty && tablePrimaryKey.isNotEmpty) {
            invoice['backend_id'] = tablePrimaryKey;
          }
          return invoice;
        })
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

    if (rows.length >= 2) {
      final explicitlyReferencedBackendIds = <String>{};
      for (final row in rows) {
        for (final field in _backendIdFields) {
          final value = _normalized(row[field]);
          if (value.isNotEmpty) {
            explicitlyReferencedBackendIds.add(value);
          }
        }
      }
      for (final row in rows) {
        final invoiceNumber = _normalized(
          row['invoice_number'] ??
              row['invoice_no'] ??
              row['bill_number'] ??
              row['bill_no'],
        );
        final genericId = _normalized(row['id']);
        if (invoiceNumber.isNotEmpty &&
            genericId.isNotEmpty &&
            explicitlyReferencedBackendIds.contains(genericId) &&
            _normalized(row['backend_id']).isEmpty) {
          row['backend_id'] = genericId;
        }
      }
    }

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
