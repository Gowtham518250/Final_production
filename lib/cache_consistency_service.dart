import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Read-side consistency coordinator for offline-first datasets.
///
/// A successful HTTP response is not automatically a complete snapshot.
/// Remote omissions are not deletions unless the caller proves completeness.
/// Unacknowledged local writes stay visible until an acknowledgement arrives.
class CacheConsistencyService {
  static const Duration defaultMaxAge = Duration(minutes: 2);

  static Future<String> _scope() async {
    final prefs = await SharedPreferences.getInstance();
    final role =
        (prefs.getString('user_type') ?? prefs.getString('role') ?? 'OWNER')
            .trim()
            .toUpperCase();
    final intUserId = prefs.getInt('user_id') ?? prefs.getInt('userId');
    final userId =
        intUserId?.toString() ??
        prefs.getString('user_id') ??
        prefs.getString('userId') ??
        'anonymous';
    return role + '_' + userId;
  }

  static Future<String> _key(String dataset) async {
    return 'cache_consistency_' +
        await _scope() +
        '_' +
        dataset.trim().toLowerCase();
  }

  static Future<Map<String, dynamic>> metadata(String dataset) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(await _key(dataset));
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Future<void> _write(String dataset, Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(await _key(dataset), jsonEncode(value));
  }

  static DateTime? _parse(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '');

  static Future<void> markRemoteRefresh(
    String dataset, {
    DateTime? serverUpdatedAt,
    int? recordCount,
  }) async {
    final now = DateTime.now().toUtc();
    final current = await metadata(dataset);
    current['last_remote_refresh_at'] = now.toIso8601String();
    current['last_remote_updated_at'] = (serverUpdatedAt ?? now)
        .toUtc()
        .toIso8601String();
    final pending = (current['pending_mutations'] as num?)?.toInt() ?? 0;
    current['dirty'] = pending > 0;
    if (recordCount != null) current['record_count'] = recordCount;
    await _write(dataset, current);
  }

  static Future<void> markLocalMutation(
    String dataset, {
    String? operationId,
  }) async {
    final current = await metadata(dataset);
    current['dirty'] = true;
    current['pending_mutations'] =
        ((current['pending_mutations'] as num?)?.toInt() ?? 0) + 1;
    current['local_revision'] =
        ((current['local_revision'] as num?)?.toInt() ?? 0) + 1;
    current['last_local_mutation_at'] = DateTime.now()
        .toUtc()
        .toIso8601String();
    if (operationId != null && operationId.isNotEmpty) {
      current['last_operation_id'] = operationId;
    }
    await _write(dataset, current);
  }

  static Future<void> markLocalMutationAcknowledged(
    String dataset, {
    String? operationId,
  }) async {
    final current = await metadata(dataset);
    final remaining =
        ((current['pending_mutations'] as num?)?.toInt() ?? 0) - 1;
    current['pending_mutations'] = remaining < 0 ? 0 : remaining;
    current['dirty'] = (current['pending_mutations'] as int) > 0;
    current['last_ack_at'] = DateTime.now().toUtc().toIso8601String();
    if (operationId != null && operationId.isNotEmpty) {
      current['last_ack_operation_id'] = operationId;
    }
    await _write(dataset, current);
  }

  static Future<void> markConflict(
    String dataset, {
    String? identity,
    String? reason,
  }) async {
    final current = await metadata(dataset);
    current['conflict_count'] =
        ((current['conflict_count'] as num?)?.toInt() ?? 0) + 1;
    current['last_conflict_at'] = DateTime.now().toUtc().toIso8601String();
    if (identity != null) current['last_conflict_identity'] = identity;
    if (reason != null) current['last_conflict_reason'] = reason;
    await _write(dataset, current);
  }

  static Future<bool> isFresh(
    String dataset, {
    Duration maxAge = defaultMaxAge,
  }) async {
    final last = _parse((await metadata(dataset))['last_remote_refresh_at']);
    if (last == null) return false;
    final age = DateTime.now().toUtc().difference(last.toUtc());
    return !age.isNegative && age <= maxAge;
  }

  static Future<DateTime?> lastRemoteRefresh(String dataset) async {
    return _parse((await metadata(dataset))['last_remote_refresh_at']);
  }

  /// Only sync metadata is inspected. A business status of PENDING, UNPAID,
  /// or PARTIAL is not evidence that a row has an unacknowledged local write.
  static bool isPending(Map<String, dynamic> record) {
    final raw =
        record['sync_status'] ??
        record['syncState'] ??
        record['sync_state'] ??
        record['queue_status'];
    final state = raw?.toString().trim().toLowerCase() ?? '';
    const pendingStates = {
      'pending',
      'pending_sync',
      'retry_wait',
      'failed',
      'dirty',
      'queued',
      'offline_pending',
      'pending_confirmation',
      'syncing',
    };
    return pendingStates.contains(state) ||
        record['is_offline'] == true ||
        record['is_synced'] == false ||
        record['synced'] == false ||
        record['pending_sync'] == true;
  }

  static String _normalized(Object? value) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    if (text.isEmpty || text == 'null' || text == '0') return '';
    return text;
  }

  /// Collect all stable business identity aliases without mixing unrelated ID
  /// spaces. Amount, date, customer name, and content are never identities.
  static Set<String> identityTokens(
    Map<String, dynamic> record, {
    String dataset = 'generic',
  }) {
    final tokens = <String>{};
    void add(String prefix, Iterable<String> fields) {
      for (final field in fields) {
        final value = _normalized(record[field]);
        if (value.isNotEmpty) tokens.add(prefix + ':' + value);
      }
    }

    switch (dataset.toLowerCase()) {
      case 'sales':
      case 'invoices':
      case 'invoice':
        add('transaction', const [
          'invoice_number',
          'invoice_no',
          'bill_number',
          'bill_no',
          'number',
          'sale_id',
          'offline_id',
          'local_sale_id',
          'source_sale_id',
          'original_sale_id',
        ]);
        add('invoice_backend', const [
          'invoice_id',
          'invoiceId',
          'backend_invoice_id',
          'backend_id',
          'server_invoice_id',
        ]);
        final id = _normalized(record['id']);
        final invoiceShaped = const [
          'invoice_number',
          'invoice_no',
          'invoice_id',
          'invoiceId',
          'backend_id',
          'server_invoice_id',
          'number',
        ].any((field) => _normalized(record[field]).isNotEmpty);
        if (id.isNotEmpty && !RegExp(r'^\d+$').hasMatch(id)) {
          tokens
            ..add('transaction:' + id)
            ..add('invoice_backend:' + id);
        } else if (id.isNotEmpty &&
            (dataset.toLowerCase() == 'invoices' ||
                (invoiceShaped && dataset.toLowerCase() != 'sales'))) {
          // Numeric id in the legacy /sales feed can identify a sales line.
          tokens.add('invoice_backend:' + id);
        }
        final serverId = _normalized(record['server_id']);
        if (serverId.isNotEmpty) {
          tokens.add('invoice_backend:' + serverId);
        }
        break;

      case 'customers':
      case 'customer':
        // Only a durable ID can prove two customer rows are the same person.
        // Phone numbers are shared by families and businesses, so records
        // without stable IDs remain separate rather than being merged.
        add('customer', const ['customer_id', 'id', 'backend_id', 'server_id']);
        break;

      case 'inventory':
      case 'products':
      case 'product':
        add('product', const ['product_id', 'id', 'backend_id', 'server_id']);
        add('sku', const ['sku', 'barcode']);
        break;

      case 'expenses':
      case 'expense':
        add('expense', const [
          'expense_id',
          'id',
          'operation_id',
          'local_id',
          'client_id',
          'server_id',
        ]);
        break;

      case 'purchase_orders':
      case 'purchases':
        add('purchase', const [
          'purchase_order_id',
          'po_id',
          'id',
          'order_number',
          'po_number',
          'operation_id',
          'local_id',
          'server_id',
        ]);
        break;

      default:
        add('record', const [
          'operation_id',
          'local_id',
          'server_id',
          'id',
          'invoice_id',
          'sale_id',
          'invoice_number',
          'product_id',
          'sku',
          'barcode',
        ]);
    }
    return tokens;
  }

  static String identity(
    Map<String, dynamic> record, [
    List<String> fields = const [
      'operation_id',
      'local_order_id',
      'server_order_id',
      'order_id',
      'product_id',
      'id',
      'invoice_id',
      'sale_id',
      'invoice_number',
      'sku',
      'barcode',
    ],
  ]) {
    for (final field in fields) {
      final value = _normalized(record[field]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static DateTime? updatedAt(Map<String, dynamic> record) {
    for (final field in const [
      'server_updated_at',
      'updated_at',
      'last_updated',
      'local_updated_at',
      'created_at',
    ]) {
      final parsed = _parse(record[field]);
      if (parsed != null) return parsed.toUtc();
    }
    return null;
  }

  static bool _isEmptyValue(Object? value) =>
      value == null || (value is String && value.trim().isEmpty);

  static Map<String, dynamic> _mergeMissing(
    Map<String, dynamic> winner,
    Map<String, dynamic> fallback,
  ) {
    final result = <String, dynamic>{...winner};
    for (final entry in fallback.entries) {
      if (!result.containsKey(entry.key) || _isEmptyValue(result[entry.key])) {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  /// Pending local edits win until ACK. Without a remote timestamp, existing
  /// local state wins conservatively. All non-empty aliases are retained.
  static Map<String, dynamic> mergeRecord(
    Map<String, dynamic> local,
    Map<String, dynamic> remote, {
    String? dataset,
  }) {
    final localPending = isPending(local);
    final remotePending = isPending(remote);
    final localUpdated = updatedAt(local);
    final remoteUpdated = updatedAt(remote);
    final key = identity(remote).isNotEmpty
        ? identity(remote)
        : identity(local);

    late final Map<String, dynamic> winner;
    late final Map<String, dynamic> fallback;
    late final String conflictState;

    if (localPending || remotePending) {
      final remoteWins = remotePending && !localPending;
      winner = remoteWins ? remote : local;
      fallback = remoteWins ? local : remote;
      conflictState = localPending && remotePending
          ? 'both_pending_local_preferred'
          : localPending
          ? 'local_pending'
          : 'remote_pending';
    } else {
      final localAcknowledged =
          local['sync_status']?.toString().trim().toLowerCase() == 'synced' ||
          local['is_synced'] == true;
      // A timestamped remote row wins when it is at least as new. When the
      // server omits timestamps, a successful remote row may replace an
      // unversioned cache row, or an acknowledged local row. A timestamped,
      // non-pending local edit remains protected from an undated server row.
      final remoteWins = remoteUpdated != null
          ? localUpdated == null || !remoteUpdated.isBefore(localUpdated)
          : localUpdated == null || localAcknowledged;
      winner = remoteWins ? remote : local;
      fallback = remoteWins ? local : remote;
      conflictState = remoteWins ? 'remote_wins' : 'local_wins_conservative';
    }

    final merged = _mergeMissing(winner, fallback);
    merged['conflict_state'] = conflictState;
    if (dataset != null &&
        (localPending || remotePending) &&
        localUpdated != remoteUpdated) {
      Future<void>.microtask(
        () => markConflict(dataset, identity: key, reason: conflictState),
      );
    }
    return merged;
  }

  /// A possibly paginated response must not delete cached online orders.
  /// The destructive prune path is opt-in for independently verified snapshots.
  static List<Map<String, dynamic>> reconcileOnlineOrderSales(
    List<dynamic> local,
    List<dynamic> remote, {
    bool authoritativeSnapshot = false,
  }) {
    final localRows = local
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    if (!authoritativeSnapshot) return localRows;

    String invoiceNumber(Map<String, dynamic> record) {
      for (final field in const [
        'invoice_number',
        'invoice_no',
        'sale_id',
        'invoiceNumber',
        'saleId',
      ]) {
        final value = record[field]?.toString().trim() ?? '';
        if (value.isNotEmpty && value.toLowerCase() != 'null') {
          return value.toUpperCase();
        }
      }
      return '';
    }

    String orderKey(String number) {
      final match = RegExp(
        r'^(ONL-\d+)(?:-|$)',
        caseSensitive: false,
      ).firstMatch(number.trim());
      return match?.group(1)?.toUpperCase() ?? '';
    }

    bool isOnlineOrder(Map<String, dynamic> record, String number) {
      if (orderKey(number).isNotEmpty) return true;
      final metadata = [
        record['source'],
        record['origin'],
        record['order_source'],
        record['transaction_type'],
        record['type'],
      ].whereType<Object>().join(' ').toUpperCase();
      if (RegExp(r'ONLINE[ _-]?ORDER').hasMatch(metadata)) return true;
      return (record['notes']?.toString().toUpperCase() ?? '').contains(
        'ONLINE ORDER #',
      );
    }

    final remoteNumbers = <String>{};
    final remoteOrderKeys = <String>{};
    for (final raw in remote) {
      if (raw is! Map) continue;
      final number = invoiceNumber(Map<String, dynamic>.from(raw));
      if (number.isEmpty) continue;
      remoteNumbers.add(number);
      final key = orderKey(number);
      if (key.isNotEmpty) remoteOrderKeys.add(key);
    }

    return localRows.where((record) {
      final number = invoiceNumber(record);
      if (!isOnlineOrder(record, number) ||
          isPending(record) ||
          number.isEmpty) {
        return true;
      }
      final key = orderKey(number);
      return remoteNumbers.contains(number) ||
          (key.isNotEmpty && remoteOrderKeys.contains(key));
    }).toList();
  }

  static String _salesLineName(Map<String, dynamic> line) =>
      (line['product_name'] ??
              line['product'] ??
              line['item'] ??
              line['description'] ??
              line['name'] ??
              '')
          .toString()
          .trim()
          .toLowerCase();

  static double _salesNumber(Object? value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static bool _sameSalesLine(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    final leftId = _normalized(left['product_id'] ?? left['id']);
    final rightId = _normalized(right['product_id'] ?? right['id']);
    final leftName = _salesLineName(left);
    final rightName = _salesLineName(right);
    final sameProduct = leftId.isNotEmpty && rightId.isNotEmpty
        ? leftId == rightId
        : leftName.isNotEmpty && leftName == rightName;
    if (!sameProduct) return false;

    final leftQty = _salesNumber(left['quantity'] ?? left['qty'], 1);
    final rightQty = _salesNumber(right['quantity'] ?? right['qty'], 1);
    if (leftQty.toStringAsFixed(3) != rightQty.toStringAsFixed(3)) {
      return false;
    }
    final leftPrice = _salesNumber(left['unit_price'] ?? left['price'], -1);
    final rightPrice = _salesNumber(right['unit_price'] ?? right['price'], -1);
    if (leftPrice >= 0 &&
        rightPrice >= 0 &&
        leftPrice.toStringAsFixed(2) != rightPrice.toStringAsFixed(2)) {
      return false;
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
      final leftValue = left[field];
      final rightValue = right[field];
      if (leftValue == null || rightValue == null) continue;
      if (_salesNumber(leftValue, -1) != _salesNumber(rightValue, -1)) {
        return false;
      }
    }
    return true;
  }

  /// One source can contain a nested invoice snapshot, flattened line rows, or
  /// both. Merge mirrors one-to-one, but retain repeated lines inside a bill.
  static List<Map<String, dynamic>> _salesLinesForRows(
    List<Map<String, dynamic>> rows,
  ) {
    final nested = <Map<String, dynamic>>[];
    final flattened = <Map<String, dynamic>>[];
    var hasNestedSnapshot = false;

    void mergeNestedSnapshot(List<Map<String, dynamic>> incoming) {
      if (incoming.isEmpty) return;
      if (!hasNestedSnapshot) {
        nested.addAll(incoming);
        hasNestedSnapshot = true;
        return;
      }
      final matched = <int>{};
      for (final line in incoming) {
        var matchIndex = -1;
        for (var i = 0; i < nested.length; i++) {
          if (matched.contains(i)) continue;
          if (_sameSalesLine(nested[i], line)) {
            matchIndex = i;
            break;
          }
        }
        if (matchIndex < 0) {
          nested.add(line);
        } else {
          matched.add(matchIndex);
          nested[matchIndex] = _mergeMissing(nested[matchIndex], line);
        }
      }
    }

    for (final row in rows) {
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
            .map((line) => Map<String, dynamic>.from(line))
            .toList();
        mergeNestedSnapshot(incoming);

        // Some clients serialize partial line collections independently under
        // both fields. Merge the alternate array too when they are not the
        // exact same list object; mirrored duplicates pair one-to-one.
        if (lineItems is List &&
            items is List &&
            !identical(lineItems, items)) {
          final alternate = identical(raw, lineItems) ? items : lineItems;
          final alternateLines = alternate
              .whereType<Map>()
              .map((line) => Map<String, dynamic>.from(line))
              .toList();
          mergeNestedSnapshot(alternateLines);
        }
        continue;
      }

      final name =
          (row['product_name'] ??
                  row['product'] ??
                  row['item'] ??
                  row['description'] ??
                  row['name'] ??
                  '')
              .toString()
              .trim();
      if (name.isEmpty && _normalized(row['product_id']).isEmpty) continue;
      flattened.add(<String, dynamic>{
        ...row,
        'product_name': name,
        'quantity': row['quantity'] ?? row['qty'] ?? 1,
        'qty': row['qty'] ?? row['quantity'] ?? 1,
      });
    }

    if (!hasNestedSnapshot) return flattened;
    final matchedNested = <int>{};
    for (final flat in flattened) {
      var matchIndex = -1;
      for (var i = 0; i < nested.length; i++) {
        if (matchedNested.contains(i)) continue;
        if (_sameSalesLine(nested[i], flat)) {
          matchIndex = i;
          break;
        }
      }
      if (matchIndex < 0) {
        nested.add(flat);
      } else {
        matchedNested.add(matchIndex);
        nested[matchIndex] = _mergeMissing(nested[matchIndex], flat);
      }
    }
    return nested;
  }

  static List<Map<String, dynamic>> _mergeSalesLines(
    List<Map<String, dynamic>> local,
    List<Map<String, dynamic>> remote,
  ) {
    final result = local
        .map((line) => Map<String, dynamic>.from(line))
        .toList();
    final matchedLocal = <int>{};
    for (final incoming in remote) {
      var matchIndex = -1;
      for (var i = 0; i < result.length; i++) {
        if (matchedLocal.contains(i)) continue;
        if (_sameSalesLine(result[i], incoming)) {
          matchIndex = i;
          break;
        }
      }
      if (matchIndex < 0) {
        result.add(Map<String, dynamic>.from(incoming));
      } else {
        matchedLocal.add(matchIndex);
        result[matchIndex] = _mergeMissing(result[matchIndex], incoming);
      }
    }
    return result;
  }

  static Map<String, dynamic> _mergeSalesGroup(
    List<Map<String, dynamic>> localRows,
    List<Map<String, dynamic>> remoteRows,
  ) {
    Map<String, dynamic>? merged;
    for (final row in localRows) {
      merged = merged == null
          ? Map<String, dynamic>.from(row)
          : mergeRecord(merged, row, dataset: 'sales');
    }
    for (final row in remoteRows) {
      merged = merged == null
          ? Map<String, dynamic>.from(row)
          : mergeRecord(merged, row, dataset: 'sales');
    }

    final lines = _mergeSalesLines(
      _salesLinesForRows(localRows),
      _salesLinesForRows(remoteRows),
    );
    final result = merged ?? <String, dynamic>{};
    if (lines.isNotEmpty) {
      result['items'] = lines;
      result['line_items'] = lines;
    }

    // Explicit invoice totals have priority. A flattened /sales feed may only
    // carry line amounts in total, which must be summed over the whole bill.
    const totalFields = [
      'invoice_total',
      'total_amount',
      'grand_total',
      'final_amount',
      'totalAmount',
    ];
    final allRows = [...localRows, ...remoteRows];
    Map<String, dynamic>? newestTotalRow;
    DateTime? newestTotalAt;
    var largestExplicitTotal = 0.0;
    for (final row in allRows) {
      var explicitTotal = 0.0;
      for (final field in totalFields) {
        final value = _salesNumber(row[field]);
        if (value > 0) {
          explicitTotal = value;
          break;
        }
      }
      if (explicitTotal <= 0) continue;
      if (explicitTotal > largestExplicitTotal) {
        largestExplicitTotal = explicitTotal;
      }
      final timestamp = updatedAt(row);
      if (timestamp != null &&
          (newestTotalAt == null || timestamp.isAfter(newestTotalAt))) {
        newestTotalAt = timestamp;
        newestTotalRow = row;
      }
    }

    if (newestTotalRow != null) {
      for (final field in totalFields) {
        final value = _salesNumber(newestTotalRow[field]);
        if (value > 0) {
          result['total_amount'] = value;
          result['total'] = value;
          break;
        }
      }
    } else if (largestExplicitTotal > 0) {
      result['total_amount'] = largestExplicitTotal;
      result['total'] = largestExplicitTotal;
    } else {
      final hasFlatRows = allRows.any((row) {
        final nested = row['line_items'] ?? row['items'];
        return nested is! List || nested.isEmpty;
      });
      if (hasFlatRows && lines.isNotEmpty) {
        final derivedTotal = lines.fold<double>(0.0, (sum, line) {
          final lineTotal = _salesNumber(
            line['line_total'] ?? line['total_with_tax'] ?? line['total'],
          );
          if (lineTotal > 0) return sum + lineTotal;
          return sum +
              _salesNumber(line['unit_price'] ?? line['price']) *
                  _salesNumber(line['quantity'] ?? line['qty'], 1);
        });
        if (derivedTotal > 0) {
          result['total_amount'] = derivedTotal;
          result['total'] = derivedTotal;
        }
      }
    }

    var highestPaid = 0.0;
    for (final row in allRows) {
      for (final field in const [
        'paid_amount',
        'amount_paid',
        'paid',
        'received_amount',
      ]) {
        final value = _salesNumber(row[field]);
        if (value > highestPaid) highestPaid = value;
      }
    }
    if (highestPaid > 0) {
      final total = _salesNumber(result['total_amount'] ?? result['total']);
      result['paid_amount'] = total > 0
          ? highestPaid.clamp(0.0, total).toDouble()
          : highestPaid;
    }

    if (remoteRows.isNotEmpty && !isPending(result)) {
      result['sync_status'] = 'synced';
      result['is_synced'] = true;
    }
    return result;
  }

  /// Union all stable aliases before merging. Anonymous rows remain separate.
  static List<Map<String, dynamic>> mergeLists(
    List<dynamic> local,
    List<dynamic> remote, {
    required String dataset,
  }) {
    final records = <Map<String, dynamic>>[];
    final remoteFlags = <bool>[];
    for (final row in local) {
      if (row is Map) {
        records.add(Map<String, dynamic>.from(row));
        remoteFlags.add(false);
      }
    }
    for (final row in remote) {
      if (row is Map) {
        records.add(Map<String, dynamic>.from(row));
        remoteFlags.add(true);
      }
    }

    final parents = List<int>.generate(records.length, (index) => index);
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

    final tokenOwners = <String, int>{};
    final tokensByIndex = <int, Set<String>>{};
    for (var index = 0; index < records.length; index++) {
      final tokens = identityTokens(records[index], dataset: dataset);
      tokensByIndex[index] = tokens;
      for (final token in tokens) {
        final previous = tokenOwners[token];
        if (previous == null) {
          tokenOwners[token] = index;
        } else {
          union(index, previous);
        }
      }
    }

    final groups = <int, List<int>>{};
    final anonymous = <int>[];
    for (var index = 0; index < records.length; index++) {
      if (tokensByIndex[index]!.isEmpty) {
        anonymous.add(index);
      } else {
        groups.putIfAbsent(root(index), () => <int>[]).add(index);
      }
    }

    final result = <Map<String, dynamic>>[];
    for (final group in groups.values) {
      final localRows = group
          .where((index) => !remoteFlags[index])
          .map((index) => records[index])
          .toList();
      final remoteRows = group
          .where((index) => remoteFlags[index])
          .map((index) => records[index])
          .toList();

      if (dataset.toLowerCase() == 'sales') {
        result.add(_mergeSalesGroup(localRows, remoteRows));
        continue;
      }

      Map<String, dynamic>? merged;
      for (final row in localRows) {
        merged = merged == null
            ? Map<String, dynamic>.from(row)
            : mergeRecord(merged, row, dataset: dataset);
      }
      for (final row in remoteRows) {
        merged = merged == null
            ? Map<String, dynamic>.from(row)
            : mergeRecord(merged, row, dataset: dataset);
      }
      if (merged != null) {
        if (remoteRows.isNotEmpty && !isPending(merged)) {
          merged.putIfAbsent('sync_status', () => 'synced');
        }
        result.add(merged);
      }
    }

    for (final index in anonymous) {
      result.add(records[index]);
    }
    if (kDebugMode) {
      debugPrint(
        '[CacheConsistency] ' +
            dataset +
            ' merged local=' +
            local.length.toString() +
            ', remote=' +
            remote.length.toString() +
            ', result=' +
            result.length.toString(),
      );
    }
    return result;
  }
}
