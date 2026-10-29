// ============================================================================
// SMS_BACKGROUND_RECEIVER.DART
// Native SMS receiver that survives OEM app kill on Xiaomi/Vivo/OPPO/Realme
// ============================================================================

import 'dart:ui' show DartPluginRegistrant;
import 'package:flutter/services.dart';
import 'package:telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:developer' as developer;
import 'dart:convert';
import 'dart:math' as math;

/// Prefix used to identify SMS queue keys in SharedPreferences.
/// Each incoming SMS is stored under a unique key to avoid race conditions.
const String _kSmsQueuePrefix = 'bg_sms_';

const MethodChannel _nativeChannel = MethodChannel('com.retail_mind/sms_receiver');

int? smsSourceTimestampMillis(SmsMessage message) {
  try {
    final value = (message as dynamic).date;
    if (value is int && value > 0) return value;
    if (value is num && value > 0) return value.toInt();
    if (value is String) {
      final numeric = int.tryParse(value.trim());
      if (numeric != null && numeric > 0) return numeric;
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.millisecondsSinceEpoch;
    }
    if (value is DateTime) return value.millisecondsSinceEpoch;
  } catch (_) {
    // Optional on some Telephony versions.
  }
  return null;
}

DateTime _smsSourceTimestamp(SmsMessage message) {
  final millis = smsSourceTimestampMillis(message);
  return millis != null
      ? DateTime.fromMillisecondsSinceEpoch(millis)
      : DateTime.now();
}

/// Stable identity of a source SMS across listener/background-isolate replays.
/// A queue arrival ID is deliberately not used: it changes on every replay.
String? smsSourceEventKey(SmsMessage message, String sender, String body) {
  final millis = smsSourceTimestampMillis(message);
  if (millis == null) return null;
  final idValue = (() {
    try {
      final raw = (message as dynamic).id;
      if (raw == null) return '';
      final text = raw.toString().trim();
      return text == 'null' ? '' : text;
    } catch (_) {
      return '';
    }
  })();
  final senderHash = sha256.convert(utf8.encode(sender.trim())).toString();
  final bodyHash = sha256.convert(utf8.encode(body.trim())).toString();
  // If the telephony provider omits the row ID, retain body identity inside
  // the stable part of the key because the generic source-key parser strips
  // only the final payload hash.
  final stableId = idValue.isNotEmpty
      ? 'id_$idValue'
      : 'sender_${senderHash}_body_${bodyHash}';
  return 'sms|$stableId|$millis|$bodyHash';
}

/// This handler is invoked when SMS is received in the background
/// The @pragma annotation ensures this stays available even if app is killed
/// Telephony requires: void backgroundMessageHandler(SmsMessage message)
@pragma('vm:entry-point')
Future<void> smsBackgroundHandler(SmsMessage message) async {
  // Background isolates do not auto-register plugins on every Flutter version;
  // without this the SharedPreferences write below can fail silently.
  DartPluginRegistrant.ensureInitialized();

  final sender = message.address ?? 'Unknown';
  final body = message.body ?? '';
  // Telephony's background callback may replay this SMS after Retail Mind's
  // detector restarts. Preserve the SMS's own receive timestamp when the
  // platform exposes it, rather than stamping the replay time on history.
  final sourceReceivedAt = _smsSourceTimestamp(message);
  final sourceEventKey = smsSourceEventKey(message, sender, body);

  developer.log(
    'SMS received in background: from=$sender, length=${body.length}',
    name: 'sms_receiver',
  );

  try {
    // FIX (Issue 2.1): Store each SMS under a unique key to eliminate the
    // read-modify-write race condition between the background isolate (writer)
    // and the main isolate (reader/deleter).
    final prefs = await SharedPreferences.getInstance();
    
    final queuedAtMillis = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = math.Random().nextInt(999999).toString().padLeft(6, '0');
    final uniqueKey = '$_kSmsQueuePrefix${queuedAtMillis}_$randomSuffix';

    final payload = jsonEncode({
      'sender': sender,
      'body': body,
      'time': sourceReceivedAt.millisecondsSinceEpoch,
      if (sourceEventKey != null) 'source_event_key': sourceEventKey,
      'queued_at': queuedAtMillis,
    });
    
    await prefs.setString(uniqueKey, payload);
    
    developer.log(
      'SMS stored in background queue with key: $uniqueKey',
      name: 'sms_receiver',
    );
  } catch (e) {
    developer.log('Error caching SMS: $e', name: 'sms_receiver', error: e);
  }
}

/// Register the native SMS receiver
Future<bool> registerSmsBroadcastReceiver() async {
  try {
    final result = await _nativeChannel.invokeMethod<bool>(
      'registerSmsReceiver',
    );
    developer.log(
      'SMS BroadcastReceiver registered: $result',
      name: 'sms_receiver',
    );
    return result ?? false;
  } on PlatformException catch (e) {
    developer.log(
      'Failed to register SMS receiver: ${e.message}',
      name: 'sms_receiver',
      error: e,
    );
    return false;
  }
}

/// Unregister the native SMS receiver
Future<bool> unregisterSmsBroadcastReceiver() async {
  try {
    final result = await _nativeChannel.invokeMethod<bool>(
      'unregisterSmsReceiver',
    );
    developer.log(
      'SMS BroadcastReceiver unregistered: $result',
      name: 'sms_receiver',
    );
    return result ?? false;
  } on PlatformException catch (e) {
    developer.log(
      'Failed to unregister SMS receiver: ${e.message}',
      name: 'sms_receiver',
      error: e,
    );
    return false;
  }
}

/// Retrieve and clear pending background SMS
///
/// FIX (Issue 2.1): Uses atomic per-key reads to prevent data loss.
/// The reader:
///   1. Collects the set of keys that were present at call time.
///   2. Reads and decodes only those specific keys.
///   3. Deletes only the keys it successfully read.
/// Any key written by the background isolate *after* step 1 is left intact.
Future<List<Map<String, String>>> getPendingBackgroundSms() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    // The background SMS callback and the long-lived detection service can run
    // in different Dart isolates, each with its own SharedPreferences cache.
    // Reload before enumerating keys so queued writes from the other isolate
    // are visible to this reader.
    await prefs.reload();

    // 1. Snapshot the current set of SMS queue keys.
    final allKeys = prefs.getKeys()
        .where((k) => k.startsWith(_kSmsQueuePrefix))
        .toList();
    
    if (allKeys.isEmpty) return [];
    
    // 2. Read and decode each key individually.
    final result = <Map<String, String>>[];
    final keysToRemove = <String>[];
    
    for (final key in allKeys) {
      try {
        final raw = prefs.getString(key);
        if (raw != null) {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          result.add({
            'sender': (decoded['sender'] ?? '').toString(),
            'body': (decoded['body'] ?? '').toString(),
            'time': (decoded['time'] ?? '').toString(),
            'source_event_key': (decoded['source_event_key'] ?? '').toString(),
          });
          keysToRemove.add(key);
        }
      } catch (e) {
        developer.log('Error decoding SMS key $key: $e', name: 'sms_receiver');
        // Still remove the malformed key to avoid it blocking future reads.
        keysToRemove.add(key);
      }
    }
    
    // 3. Delete only the keys we successfully processed.
    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
    
    developer.log(
      'Retrieved ${result.length} pending background SMS',
      name: 'sms_receiver',
    );
    
    return result;
  } catch (e) {
    developer.log(
      'Error retrieving pending SMS: $e',
      name: 'sms_receiver',
      error: e,
    );
    return [];
  }
}

/// Check if this is an OEM-restricted device (Xiaomi/Vivo/OPPO/Realme)
Future<bool> isOemRestrictedDevice() async {
  try {
    final result = await _nativeChannel.invokeMethod<bool>(
      'isOemRestrictedDevice',
    );
    return result ?? false;
  } catch (_) {
    return false;
  }
}

/// Request battery optimization exemption status
Future<bool> isIgnoringBatteryOptimizations() async {
  try {
    final result = await _nativeChannel.invokeMethod<bool>(
      'isIgnoringBatteryOptimizations',
    );
    return result ?? false;
  } catch (_) {
    return false;
  }
}

/// Request battery optimization exemption
Future<void> requestBatteryOptimizationExemption() async {
  try {
    await _nativeChannel.invokeMethod(
      'requestBatteryOptimizationExemption',
    );
  } catch (e) {
    developer.log(
      'Failed to request battery exemption: $e',
      name: 'sms_receiver',
      error: e,
    );
  }
}
