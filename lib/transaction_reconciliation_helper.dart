import 'invoice_dedup_helper.dart';

/// Keeps transaction event timestamps timezone-aware when building UI view
/// models, and reconciles local sale/server invoice mirrors using all stable IDs.
class TransactionReconciliationHelper {
  /// Convert an already-localized DateTime back to an unambiguous UTC ISO
  /// timestamp before putting it into a string-backed view model.
  static String? serializeEventTime(DateTime? eventTime) {
    return eventTime?.toUtc().toIso8601String();
  }

  /// Deduplicate only records that share a stable identity alias.
  ///
  /// Sale content (same amount/items/time) is never enough to merge records:
  /// two genuine purchases may have identical contents.
  static List<Map<String, dynamic>> dedupe(
    List<Map<String, dynamic>> transactions,
  ) {
    if (transactions.length < 2) {
      return transactions.map((row) => Map<String, dynamic>.from(row)).toList();
    }

    Map<String, dynamic> identityRow(Map<String, dynamic> transaction) {
      final raw = transaction['raw'];
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return <String, dynamic>{};
    }

    final parents = List<int>.generate(transactions.length, (index) => index);
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
    for (var index = 0; index < transactions.length; index++) {
      for (final token in InvoiceDedupHelper.identityTokens(
        identityRow(transactions[index]),
      )) {
        final previous = tokenOwner[token];
        if (previous == null) {
          tokenOwner[token] = index;
        } else {
          union(index, previous);
        }
      }
    }

    final groups = <int, List<int>>{};
    for (var index = 0; index < transactions.length; index++) {
      groups.putIfAbsent(root(index), () => <int>[]).add(index);
    }

    final output = <Map<String, dynamic>>[];
    for (final indexes in groups.values) {
      if (indexes.length == 1) {
        output.add(Map<String, dynamic>.from(transactions[indexes.first]));
        continue;
      }

      final rawRows = indexes
          .map((index) => identityRow(transactions[index]))
          .toList();
      final canonicalRows = InvoiceDedupHelper.canonicalizeInvoices(rawRows);
      final canonicalRaw = canonicalRows.isEmpty
          ? <String, dynamic>{}
          : canonicalRows.first;

      // Invoice wrappers arrive after local sale wrappers in this page; retain
      // category ordering while replacing raw data with the canonical snapshot.
      var mergedWrapper = <String, dynamic>{};
      for (final index in indexes) {
        mergedWrapper = <String, dynamic>{
          ...mergedWrapper,
          ...transactions[index],
        };
      }

      final rawTotal = canonicalRaw['total_amount'] ??
          canonicalRaw['totalAmount'] ??
          canonicalRaw['invoice_total'] ??
          canonicalRaw['grand_total'] ??
          canonicalRaw['total'];
      if (rawTotal is num) {
        mergedWrapper['amount'] = rawTotal.toDouble();
      } else if (rawTotal != null) {
        final parsed = double.tryParse(rawTotal.toString());
        if (parsed != null) mergedWrapper['amount'] = parsed;
      }

      mergedWrapper['raw'] = canonicalRaw;
      output.add(mergedWrapper);
    }
    return output;
  }
}
