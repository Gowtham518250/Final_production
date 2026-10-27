import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'payment_event.dart';

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
  static const Duration _crossAppWindow = Duration(minutes: 10);
  static const Duration _sameChannelReplayWindow = Duration(seconds: 10);

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

    final direction = _directionKey(event);
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

    for (var i = 0; i < stored.length; i++) {
      final previous = stored[i];
      final previousAmount = (previous['amount'] as num?)?.toDouble();
      if (previousAmount == null ||
          !previousAmount.isFinite ||
          (previousAmount - event.amount).abs() >= 0.01 ||
          (previous['direction'] ?? 'unknown').toString() != direction) {
        continue;
      }

      final previousReference =
          (previous['reference'] ?? '').toString().trim();
      if (reference != null || previousReference.isNotEmpty) {
        // A single missing reference is not evidence that two payment signals
        // are the same transfer. Do not let fuzzy clues collapse a transfer
        // whose authoritative identity is present on only one side.
        if (reference == null || previousReference.isEmpty) continue;
        // Distinct authoritative references always represent distinct
        // transfers, even if the values and timestamps are identical.
        if (reference != previousReference) continue;
        // Same reference with conflicting amount/direction has already failed
        // the checks above and is intentionally not treated as an echo.
        return true;
      }

      final previousChannel = (previous['channel'] ?? '').toString();
      final previousOrigin = (previous['origin'] ?? '').toString();
      final previousSeenAt =
          DateTime.tryParse((previous['seenAt'] ?? '').toString());
      if (previousSeenAt == null) continue;
      final age = now.difference(previousSeenAt).abs();

      if (previousChannel == channel) {
        // Same channel may report two real transfers of the same amount.
        // Suppress only a near-immediate exact text replay without a UTR.
        final previousText = (previous['text'] ?? '').toString();
        if (reference == null &&
            previousReference.isEmpty &&
            age <= _sameChannelReplayWindow &&
            text.isNotEmpty &&
            text == previousText) {
          await prefs.setString(_storageKey, jsonEncode(stored));
          return true;
        }
        continue;
      }

      final involvesSms = _isSmsOrigin(origin) || _isSmsOrigin(previousOrigin);
      final allowedAge = involvesSms ? _smsWindow : _crossAppWindow;
      if (age > allowedAge) continue;

      final previousAccount = (previous['account'] ?? '').toString();
      if (account.isNotEmpty &&
          previousAccount.isNotEmpty &&
          account != previousAccount) {
        continue;
      }

      final previousPayer = (previous['payer'] ?? '').toString();
      if (payer.isNotEmpty &&
          previousPayer.isNotEmpty &&
          !_payersCompatible(payer, previousPayer)) {
        continue;
      }

      // One-to-one source pairing matters: two genuine same-value payments
      // should be able to pair with two notifications and two bank SMS messages.
      final claimedChannels = (previous['claimedChannels'] is List)
          ? (previous['claimedChannels'] as List)
              .map((value) => value.toString())
              .toSet()
          : <String>{};
      if (claimedChannels.contains(channel)) continue;

      claimedChannels.add(channel);
      previous['claimedChannels'] = claimedChannels.toList();
      stored[i] = previous;
      await prefs.setString(_storageKey, jsonEncode(stored));
      return true;
    }

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

  static bool _isSmsOrigin(String origin) =>
      origin == 'sms' || origin == 'notification+sms';

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

  static bool _payersCompatible(String current, String previous) =>
      current == previous ||
      current.contains(previous) ||
      previous.contains(current);
}
