import 'invoice_dedup_helper.dart';

/// Keeps transaction event timestamps timezone-aware when building UI view
/// models, and reconciles local sale/server invoice mirrors using all stable IDs.
class TransactionReconciliationHelper {
  /// Build the display rows for the exact canonical, date-valid bill set used
  /// by lifetime analytics. Category callbacks must partition each row once.
  static List<Map<String, dynamic>> buildCanonicalSalesTransactions({
    required List<Map<String, dynamic>> sales,
    required DateTime Function(Map<String, dynamic>) businessDateOf,
    required DateTime? Function(Map<String, dynamic>) eventTimeOf,
    required bool Function(Map<String, dynamic>) isKhataSale,
    required bool Function(Map<String, dynamic>) isOnlineSale,
  }) {
    return sales.map((sale) {
      final businessDate = businessDateOf(sale);
      final eventTime = eventTimeOf(sale);
      final id =
          sale['sale_id'] ??
          sale['invoice_number'] ??
          sale['id'] ??
          sale['transaction_key'];
      final paymentMethod = (sale['payment_method'] ?? '').toString();
      final type = isKhataSale(sale)
          ? 'Khata Sale'
          : isOnlineSale(sale)
          ? 'Online Sale'
          : 'Cash Sale';
      final eventTimestamp = serializeEventTime(eventTime);
      final date =
          eventTimestamp ??
          '${businessDate.year.toString().padLeft(4, '0')}-'
              '${businessDate.month.toString().padLeft(2, '0')}-'
              '${businessDate.day.toString().padLeft(2, '0')}';
      final items = sale['items'] ?? sale['line_items'] ?? const [];
      final amount = _amount(sale['total_amount'] ?? sale['total']);

      return <String, dynamic>{
        'id': id,
        'amount': amount,
        'date': date,
        'event_timestamp': eventTimestamp,
        'business_date':
            '${businessDate.year.toString().padLeft(4, '0')}-'
            '${businessDate.month.toString().padLeft(2, '0')}-'
            '${businessDate.day.toString().padLeft(2, '0')}',
        'customer': sale['customer_name'] ?? 'Walk-in Customer',
        'customer_phone': sale['customer_phone'],
        'items': items,
        'raw': sale,
        'type': type,
        if (type == 'Online Sale' && paymentMethod.trim().isNotEmpty)
          'payment_method': paymentMethod,
      };
    }).toList();
  }

  static double _amount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  /// Parse an event timestamp for UI display in the device's local timezone.
  /// Date-only values remain local calendar dates; timezone-free event times
  /// are UTC, matching the app's serialized event timestamp convention.
  static DateTime? parseEventTime(dynamic rawValue) {
    if (rawValue == null) return null;
    final value = rawValue.toString().trim();
    if (value.isEmpty || value == 'null') return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return parsed;
    final hasExplicitZone =
        value.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(value);
    return hasExplicitZone
        ? parsed.toLocal()
        : DateTime.parse('${value}Z').toLocal();
  }

  /// Combine local and remote rows before deduplicating, so loading a remote
  /// ledger never discards transactions already collected from local sales.
  static List<Map<String, dynamic>> mergeAndDedupe(
    List<Map<String, dynamic>> localTransactions,
    List<Map<String, dynamic>> remoteTransactions,
  ) {
    return dedupe([...localTransactions, ...remoteTransactions]);
  }

  /// Convert an already-localized DateTime back to an unambiguous UTC ISO
  /// timestamp before putting it into a string-backed view model.
  static String? serializeEventTime(DateTime? eventTime) {
    return eventTime?.toUtc().toIso8601String();
  }

  /// Deduplicate only records sharing a stable identity alias.
  /// Equal content never proves that two retail transactions are identical.
  /// Union all aliases so bridge rows connect all mirrors of one bill.
  static List<Map<String, dynamic>> dedupe(
    List<Map<String, dynamic>> transactions,
  ) {
    Map<String, dynamic> identityRow(Map<String, dynamic> row) {
      final raw = row['raw'];
      return raw is Map ? Map<String, dynamic>.from(raw) : row;
    }

    Set<String> tokens(Map<String, dynamic> row) {
      final result = InvoiceDedupHelper.identityTokens(identityRow(row));
      final id = row['id']?.toString().trim() ?? '';
      final type = (row['type'] ?? '').toString().trim().toLowerCase();
      if (id.isNotEmpty && type.isNotEmpty && id.toLowerCase() != 'null') {
        result.add('display:$type:${id.toLowerCase()}');
      }
      return result;
    }

    if (transactions.length < 2) {
      return transactions.map((row) => Map<String, dynamic>.from(row)).toList();
    }

    final parents = List<int>.generate(transactions.length, (i) => i);
    int root(int index) {
      var current = index;
      while (parents[current] != current) {
        parents[current] = parents[parents[current]];
        current = parents[current];
      }
      return current;
    }

    void union(int a, int b) {
      final left = root(a);
      final right = root(b);
      if (left != right) parents[right] = left;
    }

    final owner = <String, int>{};
    final rowTokens = <int, Set<String>>{};
    for (var i = 0; i < transactions.length; i++) {
      final currentTokens = tokens(transactions[i]);
      rowTokens[i] = currentTokens;
      for (final token in currentTokens) {
        final previous = owner[token];
        if (previous == null) {
          owner[token] = i;
        } else {
          union(i, previous);
        }
      }
    }

    final groups = <int, List<int>>{};
    final anonymous = <int>[];
    for (var i = 0; i < transactions.length; i++) {
      if (rowTokens[i]!.isEmpty) {
        anonymous.add(i);
      } else {
        groups.putIfAbsent(root(i), () => <int>[]).add(i);
      }
    }

    final result = <Map<String, dynamic>>[];
    for (final group in groups.values) {
      var merged = Map<String, dynamic>.from(transactions[group.first]);
      for (final index in group.skip(1)) {
        final incoming = transactions[index];
        final raw = <String, dynamic>{...identityRow(merged)};
        for (final entry in identityRow(incoming).entries) {
          final value = entry.value;
          if (value == null || (value is String && value.trim().isEmpty)) {
            continue;
          }
          raw[entry.key] = value;
        }
        merged = <String, dynamic>{...merged, ...incoming, 'raw': raw};
      }
      result.add(merged);
    }

    for (final index in anonymous) {
      result.add(Map<String, dynamic>.from(transactions[index]));
    }
    return result;
  }
}
