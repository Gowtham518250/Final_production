import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'scoped_shared_preferences.dart';

/// FIX-C: Redis fallback for UTR deduplication
/// Checks UTR conflicts using Redis first, falls back to local SharedPreferences
class UtrDeduplicationService {
  // FIX-1: CRITICAL — Read from dart-define at build time
  // Empty defaults = skip Redis, use local only (safe fallback)
  // Build: flutter build apk --dart-define=REDIS_BASE_URL=... --dart-define=REDIS_API_KEY=...
  static const String _redisBaseUrl = String.fromEnvironment(
    'REDIS_BASE_URL',
    defaultValue: '', // empty = skip Redis, use local only
  );
  static const String _apiKey = String.fromEnvironment(
    'REDIS_API_KEY',
    defaultValue: '', // empty = local fallback
  );
  static const int _localUtrCacheMax = 500;

  /// Cross-device Redis matching is active only when the release build
  /// passed `--dart-define=REDIS_BASE_URL=...`.
  static bool get isDistributedDedupEnabled => _redisBaseUrl.isNotEmpty;

  /// Check if a UTR has already been confirmed/registered
  /// Returns true if conflict detected (UTR already exists)
  static Future<bool> checkUtrConflict(String utr) async {
    // FIX (Issue 2.5): Skip Redis entirely when the base URL is not configured.
    // Calling Uri.parse('') on an empty string throws a FormatException.
    if (_redisBaseUrl.isNotEmpty) {
      try {
        // Try Redis first for distributed dedup
        final response = await http
            .get(
              Uri.parse('$_redisBaseUrl/check-utr/$utr'),
              headers: {'Authorization': 'Bearer $_apiKey'},
            )
            .timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['conflict'] == true;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('FIX-C: Redis unavailable for UTR check: $e');
        }
      }
    }

    final confirmed = await _loadLocalUtrs();
    return confirmed.contains(utr); // true = conflict detected
  }

  static const _utrKey = 'confirmed_utrs_local';

  static Future<List<String>> _loadLocalUtrs() async {
    final scoped = await ScopedSharedPreferences.getStringList(_utrKey) ?? [];
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getStringList(_utrKey) ?? [];
    if (legacy.isEmpty) return scoped;
    final merged = <String>{...scoped, ...legacy}.toList();
    if (merged.length > _localUtrCacheMax) {
      merged.removeRange(0, merged.length - _localUtrCacheMax);
    }
    await ScopedSharedPreferences.setStringList(_utrKey, merged);
    await prefs.remove(_utrKey);
    return merged;
  }

  /// Register a UTR as confirmed
  /// Updates both local cache and Redis (async)
  static Future<void> registerUtr(String utr) async {
    final confirmed = await _loadLocalUtrs();

    if (!confirmed.contains(utr)) {
      confirmed.add(utr);

      // Keep last 500 UTRs only (FIFO rollover)
      if (confirmed.length > _localUtrCacheMax) {
        confirmed.removeAt(0);
      }

      await ScopedSharedPreferences.setStringList(_utrKey, confirmed);
    }

    // Also try to register in Redis (fire and forget, non-blocking)
    // FIX (Issue 2.5): Skip Redis call when URL is not configured.
    if (_redisBaseUrl.isNotEmpty) {
      try {
        await http
            .post(
              Uri.parse('$_redisBaseUrl/register-utr'),
              body: jsonEncode({'utr': utr}),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_apiKey',
              },
            )
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        // Redis failure is non-blocking; local cache is always maintained
      }
    }
  }

  /// Clear old UTR cache (optional cleanup)
  static Future<void> clearOldUtrs() async {
    await ScopedSharedPreferences.remove(_utrKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_utrKey);
  }

  /// Get all registered UTRs (for debugging/audit)
  static Future<List<String>> getAllRegisteredUtrs() async {
    return _loadLocalUtrs();
  }
}
