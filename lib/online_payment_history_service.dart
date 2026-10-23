import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'payment_detection_service.dart';
import 'payment_event.dart';

class OnlinePaymentHistoryService {
  static const _keyPrefix = 'confirmed_online_payment';
  static const _maxEntries = 500;

  static String _userPrefix(int userId) => '${_keyPrefix}_${userId}_';

  static Future<int> _currentUserId(SharedPreferences prefs) async {
    final userId = prefs.getInt('user_id') ?? prefs.getInt('userId') ?? 0;
    if (userId <= 0) {
      throw StateError(
        'Cannot save online payment history without a signed-in user.',
      );
    }
    return userId;
  }

  static Future<bool> recordIncomingPayment(PaymentEvent event) async {
    if (event.isFailed ||
        event.isDuplicate ||
        event.decision == PaymentDecision.rejected ||
        !event.amount.isFinite ||
        event.amount <= 0) {
      return false;
    }
    final isIncomingCredit =
        event.direction == PaymentTransactionDirection.incomingCredit ||
        (event.direction == PaymentTransactionDirection.unknown &&
            VoiceBuilder.detectDirection(event.rawText) ==
                PaymentDirection.credited);
    if (!isIncomingCredit) return false;

    final prefs = await SharedPreferences.getInstance();
    final userId = await _currentUserId(prefs);
    final fingerprint = sha256
        .convert(utf8.encode(event.fingerprint))
        .toString();
    final prefix = _userPrefix(userId);
    final key = '$prefix$fingerprint';
    final record = <String, dynamic>{
      'amount': event.amount,
      'timestamp': event.timestamp.toIso8601String(),
      'app': event.appDisplayName,
      'status': event.isMerchantConfirmed
          ? 'CONFIRMED'
          : 'PENDING_CONFIRMATION',
      'verified': event.isMerchantConfirmed,
    };

    await prefs.setString(key, jsonEncode(record));
    await _trimHistory(prefs, prefix);
    return true;
  }

  static Future<List<Map<String, dynamic>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await _currentUserId(prefs);
    final prefix = _userPrefix(userId);
    final entries = <Map<String, dynamic>>[];
    for (final key in prefs.getKeys().where((key) => key.startsWith(prefix))) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        entries.add(Map<String, dynamic>.from(decoded));
      }
    }
    entries.sort((a, b) {
      final aDate =
          DateTime.tryParse(a['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          DateTime.tryParse(b['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return entries;
  }

  static Future<void> _trimHistory(
    SharedPreferences prefs,
    String prefix,
  ) async {
    final entries = <({String key, DateTime timestamp})>[];
    for (final key in prefs.getKeys().where((key) => key.startsWith(prefix))) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) continue;
      final timestamp =
          DateTime.tryParse(decoded['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      entries.add((key: key, timestamp: timestamp));
    }
    if (entries.length <= _maxEntries) return;
    entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    for (final entry in entries.take(entries.length - _maxEntries)) {
      await prefs.remove(entry.key);
    }
  }
}
