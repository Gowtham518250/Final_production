import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Read-side consistency coordinator for offline-first datasets.
/// Tracks remote freshness and local pending mutations per role/user.
class CacheConsistencyService {
  static const Duration defaultMaxAge = Duration(minutes: 2);

  static Future<String> _scope() async {
    final prefs = await SharedPreferences.getInstance();
    final role = (prefs.getString('user_type') ?? prefs.getString('role') ?? 'OWNER').trim().toUpperCase();
    final intUserId = prefs.getInt('user_id') ?? prefs.getInt('userId');
    final userId = intUserId?.toString() ??
        prefs.getString('user_id') ??
        prefs.getString('userId') ??
        'anonymous';
    return role + '_' + userId;
  }

  static Future<String> _key(String dataset) async {
    return 'cache_consistency_' + await _scope() + '_' + dataset.trim().toLowerCase();
  }

  static Future<Map<String, dynamic>> metadata(String dataset) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(await _key(dataset));
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Future<void> _write(String dataset, Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(await _key(dataset), jsonEncode(value));
  }

  static DateTime? _parse(dynamic value) => DateTime.tryParse(value?.toString() ?? '');

  static Future<void> markRemoteRefresh(String dataset, {DateTime? serverUpdatedAt, int? recordCount}) async {
    final now = DateTime.now().toUtc();
    final current = await metadata(dataset);
    current['last_remote_refresh_at'] = now.toIso8601String();
    current['last_remote_updated_at'] = (serverUpdatedAt ?? now).toUtc().toIso8601String();
    // A remote read does not ACK local mutations. Preserve dirty state until
    // durable mutations have been acknowledged explicitly.
    final pending = (current['pending_mutations'] as num?)?.toInt() ?? 0;
    current['dirty'] = pending > 0 ? true : false;
    if (recordCount != null) current['record_count'] = recordCount;
    await _write(dataset, current);
  }

  static Future<void> markLocalMutation(String dataset, {String? operationId}) async {
    final current = await metadata(dataset);
    current['dirty'] = true;
    current['pending_mutations'] =
        ((current['pending_mutations'] as num?)?.toInt() ?? 0) + 1;
    current['local_revision'] = ((current['local_revision'] as num?)?.toInt() ?? 0) + 1;
    current['last_local_mutation_at'] = DateTime.now().toUtc().toIso8601String();
    if (operationId != null && operationId.isNotEmpty) current['last_operation_id'] = operationId;
    await _write(dataset, current);
  }

  static Future<void> markLocalMutationAcknowledged(String dataset, {String? operationId}) async {
    final current = await metadata(dataset);
    final remaining =
        ((current['pending_mutations'] as num?)?.toInt() ?? 0) - 1;
    current['pending_mutations'] = remaining < 0 ? 0 : remaining;
    current['dirty'] = (current['pending_mutations'] as int) > 0;
    current['last_ack_at'] = DateTime.now().toUtc().toIso8601String();
    if (operationId != null && operationId.isNotEmpty) current['last_ack_operation_id'] = operationId;
    await _write(dataset, current);
  }

  static Future<void> markConflict(String dataset, {String? identity, String? reason}) async {
    final current = await metadata(dataset);
    current['conflict_count'] = ((current['conflict_count'] as num?)?.toInt() ?? 0) + 1;
    current['last_conflict_at'] = DateTime.now().toUtc().toIso8601String();
    if (identity != null) current['last_conflict_identity'] = identity;
    if (reason != null) current['last_conflict_reason'] = reason;
    await _write(dataset, current);
  }

  static Future<bool> isFresh(String dataset, {Duration maxAge = defaultMaxAge}) async {
    final current = await metadata(dataset);
    final last = _parse(current['last_remote_refresh_at']);
    if (last == null) return false;
    return DateTime.now().toUtc().difference(last.toUtc()) <= maxAge;
  }

  static Future<DateTime?> lastRemoteRefresh(String dataset) async {
    return _parse((await metadata(dataset))['last_remote_refresh_at']);
  }

  /// Only sync metadata is inspected; business status PENDING is not a
  /// durable local-write marker.
  static bool isPending(Map<String, dynamic> record) {
    final raw = record['sync_status'] ??
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

  /// Collect every stable business identity alias, with ID namespaces kept
  /// separate so unrelated numeric table IDs cannot collide.
  static Set<String> identityTokens(
    Map<String, dynamic> record, {
    String dataset = 'generic',
  }) {
    final tokens = <String>{};
    void add(String prefix, Iterable<String> fields) {
      for (final field in fields) {
        final value = _normalized(record[field]);
        if (value.isNotEmpty) tokens.add('$prefix:$value');
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
        if (id.isNotEmpty && !RegExp(r'^\\d+Map<String, dynamic> record, [List<String> fields = const ['operation_id','local_order_id','server_order_id','order_id','product_id','id','invoice_id','sale_id','invoice_number','sku','barcode']]) {
    for (final field in fields) {
      final value = record[field]?.toString().trim();
      if (value != null && value.isNotEmpty && value != 'null' && value != '0') return value.toLowerCase();
    }
    return '';
  }

  static DateTime? updatedAt(Map<String, dynamic> record) {
    for (final field in const ['server_updated_at','updated_at','last_updated','local_updated_at','created_at']) {
      final parsed = _parse(record[field]);
      if (parsed != null) return parsed.toUtc();
    }
    return null;
  }

  /// Unsynced local mutations stay visible until their ACK arrives.
  /// Otherwise the newer server representation wins.
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

  /// Pending local edits win until ACK. If neither row is pending, an explicit
  /// remote timestamp is required before remote data replaces local values.
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
      final remoteWins = remoteUpdated != null &&
          (localUpdated == null || !remoteUpdated.isBefore(localUpdated));
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


  /// Remove stale server-owned online-order invoices after a successful
  /// canonical snapshot. Pending/offline local writes remain until their ACK.
  static List<Map<String, dynamic>> reconcileOnlineOrderSales(
    List<dynamic> local,
    List<dynamic> remote, {
    bool authoritativeSnapshot = false,
  }) {
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

    String orderKey(String invoiceNumber) {
      final match = RegExp(r'^(ONL-\d+)(?:-|$)', caseSensitive: false)
          .firstMatch(invoiceNumber.trim());
      return match?.group(1)?.toUpperCase() ?? '';
    }

    final localRows = local
        .whereType<Map>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .toList();
    if (!authoritativeSnapshot) return localRows;

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
      return (record['notes']?.toString().toUpperCase() ?? '')
          .contains('ONLINE ORDER #');
    }

    bool isPendingLocalWrite(Map<String, dynamic> record) {
      final state = (record['sync_status'] ??
              record['syncState'] ??
              record['sync_state'] ??
              record['queue_status'])
          ?.toString()
          .trim()
          .toLowerCase();
      const pendingStates = {
        'pending',
        'pending_sync',
        'retry_wait',
        'failed',
        'dirty',
        'queued',
        'offline_pending',
      };
      return pendingStates.contains(state) ||
          record['is_offline'] == true ||
          record['is_synced'] == false ||
          record['synced'] == false ||
          record['pending_sync'] == true;
    }

    final remoteNumbers = <String>{};
    final remoteOrderKeys = <String>{};
    for (final raw in remote) {
      if (raw is! Map) continue;
      final record = Map<String, dynamic>.from(raw);
      final number = invoiceNumber(record);
      if (number.isEmpty) continue;
      remoteNumbers.add(number);
      final key = orderKey(number);
      if (key.isNotEmpty) remoteOrderKeys.add(key);
    }

    final output = <Map<String, dynamic>>[];
    for (final raw in local) {
      if (raw is! Map) continue;
      final record = Map<String, dynamic>.from(raw);
      final number = invoiceNumber(record);
      if (!isOnlineOrder(record, number) ||
          isPendingLocalWrite(record) ||
          number.isEmpty) {
        output.add(record);
        continue;
      }

      final key = orderKey(number);
      final present = remoteNumbers.contains(number) ||
          (key.isNotEmpty && remoteOrderKeys.contains(key));
      if (present) output.add(record);
      // A previously-synced online-order invoice absent from this successful,
      // validated server snapshot was cancelled/deleted remotely.
    }
    return output;
  }

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
    void union(int a, int b) {
      final left = root(a);
      final right = root(b);
      if (left != right) parents[right] = left;
    }

    final tokenOwners = <String, int>{};
    final tokensByIndex = <int, Set<String>>{};
    for (var i = 0; i < records.length; i++) {
      final tokens = identityTokens(records[i], dataset: dataset);
      tokensByIndex[i] = tokens;
      for (final token in tokens) {
        final previous = tokenOwners[token];
        if (previous == null) {
          tokenOwners[token] = i;
        } else {
          union(i, previous);
        }
      }
    }

    final groups = <int, List<int>>{};
    final anonymous = <int>[];
    for (var i = 0; i < records.length; i++) {
      if (tokensByIndex[i]!.isEmpty) {
        anonymous.add(i);
      } else {
        groups.putIfAbsent(root(i), () => <int>[]).add(i);
      }
    }

    final result = <Map<String, dynamic>>[];
    for (final group in groups.values) {
      final localRows = group
          .where((i) => !remoteFlags[i])
          .map((i) => records[i])
          .toList();
      final remoteRows = group
          .where((i) => remoteFlags[i])
          .map((i) => records[i])
          .toList();
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

    // No stable identity means no safe dedupe operation.
    for (final i in anonymous) {
      result.add(records[i]);
    }
    if (kDebugMode) {
      debugPrint(
        '[CacheConsistency] $dataset merged local=' +
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
