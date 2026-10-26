import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'scoped_shared_preferences.dart';
import 'secure_token_storage.dart';
import 'worker_local_storage.dart';

/// A worker roster can be empty only when the server confirmed it.
/// If the app is offline and the only available cache is empty/stale, the
/// state is unknown so the owner verification gate fails closed.
class WorkerRosterSnapshot {
  const WorkerRosterSnapshot({
    required this.workers,
    required this.isAuthoritative,
  });

  final List<Map<String, dynamic>>? workers;
  final bool isAuthoritative;

  bool get hasActiveWorkers =>
      workers?.any(WorkerVerificationPolicy.isActiveWorker) ?? false;

  /// True when a live roster confirms active workers, false when a live
  /// roster confirms none, and null when there is not enough reliable data.
  bool? get confirmedHasActiveWorkers {
    if (hasActiveWorkers) return true;
    if (isAuthoritative && workers != null) return false;
    return null;
  }
}

/// Centralized worker-roster policy used to decide whether Staff PIN
/// verification should be offered at sign-in/startup.
class WorkerVerificationPolicy {
  WorkerVerificationPolicy._();

  static const Duration _requestTimeout = Duration(seconds: 5);

  static bool isActiveWorker(Map<String, dynamic> worker) {
    // Keep this aligned with the app's WorkerState: workers on leave are still
    // current roster members; inactive/removed workers must not open Staff Mode.
    final rawStatus = worker['status'];
    final status = (rawStatus == null ? 'ACTIVE' : rawStatus.toString())
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[ -]+'), '_');
    return status == 'ACTIVE' || status == 'ON_LEAVE';
  }

  static Future<bool?> hasActiveWorkersForShop({
    required int userId,
  }) async {
    final snapshot = await loadRoster(userId: userId);
    return snapshot.confirmedHasActiveWorkers;
  }

  /// Reads the authenticated backend first. A successful empty response is
  /// authoritative; network/auth/API failures are not treated as "no workers".
  static Future<WorkerRosterSnapshot> loadRoster({
    required int userId,
  }) async {
    if (userId <= 0) {
      return const WorkerRosterSnapshot(
        workers: null,
        isAuthoritative: false,
      );
    }

    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      final response = await ApiClient.getJson(
        '/api/attendance/workers?user_id=$userId',
        headers: token.isNotEmpty
            ? <String, String>{'Authorization': 'Bearer $token'}
            : null,
      ).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final workers = _decodeRoster(decoded);
        if (workers != null) {
          await _cacheRoster(userId, workers);
          return WorkerRosterSnapshot(
            workers: workers,
            isAuthoritative: true,
          );
        }
      }
    } catch (_) {
      // Use a cached roster if available, but never infer that a shop has no
      // workers from a failed request or malformed response.
    }

    final cached = await _readCachedRoster(userId);
    return WorkerRosterSnapshot(
      workers: cached,
      isAuthoritative: false,
    );
  }

  static List<Map<String, dynamic>>? _decodeRoster(dynamic decoded) {
    dynamic listValue;
    if (decoded is List) {
      listValue = decoded;
    } else if (decoded is Map && decoded['workers'] is List) {
      listValue = decoded['workers'];
    } else if (decoded is Map && decoded['data'] is List) {
      listValue = decoded['data'];
    } else {
      return null;
    }

    final rows = List<dynamic>.from(listValue as List);
    if (rows.any((row) => row is! Map)) return null;
    return rows
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  static Future<void> _cacheRoster(
    int userId,
    List<Map<String, dynamic>> workers,
  ) async {
    try {
      final encoded = jsonEncode(workers);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        WorkerLocalStorage.getWorkerPreferenceKey(userId),
        encoded,
      );
      await prefs.setString(
        WorkerLocalStorage.getLegacyWorkerKey(userId),
        encoded,
      );
      // Staff PIN login already reads this user-scoped cache when offline.
      await ScopedSharedPreferences.setString('workers_json', encoded);
    } catch (_) {
      // A cache write failure must not turn a successful live response into an
      // unknown roster or block navigation.
    }
  }

  static Future<List<Map<String, dynamic>>?> _readCachedRoster(
    int userId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = <String>[
        WorkerLocalStorage.getWorkerPreferenceKey(userId),
        WorkerLocalStorage.getLegacyWorkerKey(userId),
        'user_${userId}_workers_json',
      ];

      for (final key in keys) {
        final raw = prefs.getString(key);
        if (raw == null || raw.trim().isEmpty) continue;
        try {
          final decoded = _decodeRoster(jsonDecode(raw));
          if (decoded != null) return decoded;
        } catch (_) {
          continue;
        }
      }
    } catch (_) {
      // No usable local roster.
    }
    return null;
  }
}
