import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

import 'payment_event.dart';
import 'payment_identity_matcher.dart';

/// Shared, short-lived one-to-one cross-source suppression for payment alerts.
///
/// PaymentDetectionService runs in separate Flutter isolates in some startup
/// and fallback paths. Its in-memory replay list cannot see events seen by the
/// other isolate. This store lets the voice queue consult a small persisted
/// record before speaking.
///
/// This is an announcement guard only; it is not proof of settlement and must
/// never be used to confirm or mutate a sale.
class CrossIsolatePaymentAnnouncementDeduplicator {
  CrossIsolatePaymentAnnouncementDeduplicator._();

  static const String _storageKey = 'pds_cross_isolate_announcement_v1';
  static const int _maxEntries = 100;
  static const Duration _smsWindow = Duration(hours: 3);
  // Accessibility can emit repeated updates from a static payment screen.
  // Exact-text fallback is intentionally bounded; distinct native notification
  // identities are exempted below.
  static const Duration _sameChannelReplayWindow = Duration(minutes: 3);

  // Serialize callers within one isolate. SharedPreferences reload makes the
  // most recent stored list visible when another isolate processed a signal.
  static Future<void> _tail = Future<void>.value();

  static Future<bool> shouldSuppress(
    PaymentEvent event, {
    DateTime? now,
  }) {
    final completer = Completer<bool>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await _shouldSuppress(event, now ?? DateTime.now()));
      } catch (_) {
        // A storage error must not disable payment detection or block a valid
        // payment announcement. The caller retains its in-memory safeguards.
        completer.complete(false);
      }
    });
    return completer.future;
  }

  static Future<bool> _shouldSuppress(PaymentEvent event, DateTime now) async {
    if (event.isDuplicate ||
        event.isMerchantConfirmed ||
        event.hasReferenceConflict ||
        event.isFailed ||
        event.decision == PaymentDecision.rejected ||
        event.detectionSource.contains(':pending_review_reminder') ||
        !event.amount.isFinite ||
        event.amount <= 0) {
      return false;
    }

    if (event.nativeAnnouncementHandled) {
      // Native TTS already owns this event. Keep it eligible for UI/history
      // processing; _emit mutes the Flutter voice for this marker.
      return false;
    }

    final direction = _directionKey(event);
    if (Platform.isAndroid) {
      final identity = event.sourceEventIdentity;
      final sourcePackage = (identity?.split('|').isNotEmpty ?? false)
          ? identity!.split('|').first
          : event.app.name;
      final origin = _origin(event.detectionSource);
      final channel = '$origin|$sourcePackage';
      final nativeDecision =
          await NotificationListenerService.shouldSuppressPaymentAnnouncement({
        'amount': event.amount,
        'direction': direction,
        'referenceId': event.normalizedReferenceId,
        'sourceIdentity': identity,
        'sourceEventKey': event.sourceEventKey,
        'sourceTimestamp': event.sourceTimestamp?.millisecondsSinceEpoch,
        'timestamp': now.millisecondsSinceEpoch,
        'origin': origin,
        'channel': channel,
        'app': event.app.name,
        'payerName': event.payerName,
        'accountSuffix': event.accountSuffix,
        'bankName': event.bankName,
        'rawText': event.rawText,
      });
      if (nativeDecision != null) return nativeDecision;
    }
    if (direction == 'unknown') return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final stored = _readEntries(prefs.getString(_storageKey));
    stored.removeWhere((entry) {
      final seenAt = DateTime.tryParse((entry['seenAt'] ?? '').toString());
      return seenAt == null || now.difference(seenAt).abs() > _smsWindow;
    });

    final channel = _channelKey(event);
    final origin = _origin(event.detectionSource);
    final reference = event.normalizedReferenceId;
    final text = _normalizeText(event.rawText);
    final payer = _normalizePayer(event.payerName);
    final account = _normalizeAccount(event.accountSuffix);
    String? nonEmpty(Object? value) {
      final v = (value ?? '').toString().trim();
      return v.isEmpty ? null : v;
    }

    // All matching rules live in PaymentIdentityMatcher; this class only owns
    // persistence. Rebuild the stored observations as identities and ask it.
    final previous = <SignalIdentity>[];
    final claims = <String, Set<String>>{};
    for (final entry in stored) {
      final amount = (entry['amount'] as num?)?.toDouble();
      final seenAt = DateTime.tryParse((entry['seenAt'] ?? '').toString());
      if (amount == null || !amount.isFinite || seenAt == null) continue;
      final id = (entry['id'] ?? '').toString();
      previous.add(
        SignalIdentity(
          id: id,
          amount: amount,
          direction: (entry['direction'] ?? 'unknown').toString(),
          channel: (entry['channel'] ?? '').toString(),
          origin: (entry['origin'] ?? '').toString(),
          at: seenAt,
          reference: nonEmpty(entry['reference']),
          payer: nonEmpty(entry['payer']),
          account: nonEmpty(entry['account']),
          sourceIdentity: nonEmpty(entry['sourceEventFingerprint']),
          text: (entry['text'] ?? '').toString(),
        ),
      );
      claims[id] = (entry['claimedChannels'] is List)
          ? (entry['claimedChannels'] as List).map((v) => v.toString()).toSet()
          : <String>{};
    }

    final current = SignalIdentity(
      id: event.id,
      amount: event.amount,
      direction: direction,
      channel: channel,
      origin: origin,
      at: now,
      reference: reference,
      payer: nonEmpty(payer),
      account: nonEmpty(account),
      sourceIdentity: event.sourceEventFingerprint,
      text: text,
    );

    final resolution = PaymentIdentityMatcher.resolve(
      current,
      previous,
      claims: claims,
      // Accessibility can repeat an identical static payment screen; this
      // layer has always tolerated exact-text repeats for a few minutes.
      sameChannelReplayWindow: _sameChannelReplayWindow,
    );
    developer.log(
      resolution.describe(event.id),
      name: 'PAYMENT_DEDUP',
    );

    if (resolution.isEcho) {
      final claimChannel = resolution.claimChannel;
      if (claimChannel != null) {
        final index = stored.indexWhere((e) => e['id'] == resolution.matchedId);
        if (index >= 0) {
          final claimed = (stored[index]['claimedChannels'] is List)
              ? (stored[index]['claimedChannels'] as List)
                  .map((v) => v.toString())
                  .toSet()
              : <String>{};
          claimed.add(claimChannel);
          stored[index]['claimedChannels'] = claimed.toList();
        }
      }
      await prefs.setString(_storageKey, jsonEncode(stored));
      return true;
    }

    // Ambiguous or unmatched candidates are retained independently so a real
    // same-person same-amount payment is not silently swallowed.
    stored.add(<String, dynamic>{
      'id': event.id,
      'amount': event.amount,
      'direction': direction,
      'reference': reference,
      'channel': channel,
      'origin': origin,
      'payer': payer,
      'account': account,
      'text': text,
      'sourceEventFingerprint': event.sourceEventFingerprint,
      'seenAt': now.toIso8601String(),
      'claimedChannels': <String>[],
    });
    while (stored.length > _maxEntries) {
      stored.removeAt(0);
    }
    await prefs.setString(_storageKey, jsonEncode(stored));
    return false;
  }

  static List<Map<String, dynamic>> _readEntries(String? raw) {
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    } on FormatException {
      return <Map<String, dynamic>>[];
    } on TypeError {
      return <Map<String, dynamic>>[];
    }
  }

  static String _origin(String source) {
    final value = source.toLowerCase().trim();
    if (value.startsWith('notification+sms')) return 'notification+sms';
    if (value.startsWith('notification')) return 'notification';
    if (value.startsWith('sms')) return 'sms';
    if (value.startsWith('accessibility')) return 'accessibility';
    if (value.startsWith('truecaller_notification')) {
      return 'truecaller_notification';
    }
    return value.split(':').first;
  }

  static String _channelKey(PaymentEvent event) =>
      '${_origin(event.detectionSource)}|${event.app.name}';

  static String _directionKey(PaymentEvent event) {
    switch (event.direction) {
      case PaymentTransactionDirection.incomingCredit:
        return 'credit';
      case PaymentTransactionDirection.outgoingDebit:
        return 'debit';
      case PaymentTransactionDirection.unknown:
        final text = event.rawText.toLowerCase();
        final credit = RegExp(
          r'\b(?:credited|credit|received|deposited|money\s+received|payment\s+received|added\s+to)\b',
        ).hasMatch(text);
        final debit = RegExp(
          r'\b(?:debited|debit|withdrawn|deducted|spent|you\s+sent|payment\s+to)\b',
        ).hasMatch(text);
        if (credit != debit) return credit ? 'credit' : 'debit';
        return 'unknown';
    }
  }

  static String _normalizeText(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _normalizePayer(String? value) {
    final normalized = (value ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty ||
        const {
          'bank',
          'customer',
          'unknown',
          'unknown payer',
          'upi app',
          'payment app',
          'phonepe',
          'google pay',
          'gpay',
          'paytm',
          'bank sms',
        }.contains(normalized)) {
      return '';
    }
    return normalized;
  }

  static String _normalizeAccount(String? value) =>
      (value ?? '').replaceAll(RegExp(r'[^0-9]'), '').trim();

}
