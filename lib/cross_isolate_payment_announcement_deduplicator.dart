import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

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
  // Accessibility can emit repeated updates from a static payment screen.
  // Exact-text fallback is intentionally bounded; distinct native notification
  // identities are exempted below.
  static const Duration _sameChannelReplayWindow = Duration(minutes: 3);
  static const Duration _truecallerCrossSourceEchoWindow =
      Duration(seconds: 8);

  static const Set<String> _truecallerEchoTrustedSources = {
    'googlepay',
    'phonepe',
    'paytm',
    'amazonpay',
    'bhim',
    'payzapp',
    'icici',
    'sbiyono',
    'axis',
    'hdfc',
    'banksms',
    'bankapp',
    'com.google.android.apps.nbu.paisa.user',
    'com.google.android.apps.nbu.paisa.merchant',
    'net.one97.paytm',
    'com.paytm.business',
    'com.phonepe.app',
    'com.phonepe.app.business',
    'com.phonepe.app.merchant',
    'com.phonepe.business',
    'in.org.npci.upiapp',
    'com.dreamplug.androidapp',
    'com.hdfcbank.payzapp',
    'com.icicibank.imobile',
    'com.sbi.imobile',
    'com.axis.mobile',
    'com.hdfcbank.smartbuy',
    'com.indusind.mobilebanking',
    'com.yes.mobile',
    'com.baroda.mpassbook',
    'com.canarabank.mobility',
    'com.kotak.mobile.banking',
  };

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
    final sourceFingerprint = event.sourceEventFingerprint;
    final text = _normalizeText(event.rawText);
    final payer = _normalizePayer(event.payerName);
    final account = _normalizeAccount(event.accountSuffix);
    Map<String, dynamic>? uniqueEchoCandidate;
    var ambiguousCandidates = false;

    for (var i = 0; i < stored.length; i++) {
      final previous = stored[i];
      final previousAmount = (previous['amount'] as num?)?.toDouble();
      if (previousAmount == null ||
          !previousAmount.isFinite ||
          (previousAmount - event.amount).abs() >= 0.01 ||
          (previous['direction'] ?? 'unknown').toString() != direction) {
        continue;
      }

      final previousSourceFingerprint =
          (previous['sourceEventFingerprint'] ?? '').toString();
      if (sourceFingerprint != null &&
          sourceFingerprint.isNotEmpty &&
          sourceFingerprint == previousSourceFingerprint) {
        final previousSourceReference =
            (previous['reference'] ?? '').toString().trim();
        if (reference != null &&
            previousSourceReference.isNotEmpty &&
            reference != previousSourceReference) {
          continue;
        }
        return true;
      }

      final previousReference =
          (previous['reference'] ?? '').toString().trim();
      if (reference != null || previousReference.isNotEmpty) {
        // A shared reference is the strongest cross-source identity. A
        // reference missing on one side or a different reference never pairs.
        if (reference == null || previousReference.isEmpty) continue;
        if (reference != previousReference) continue;
        return true;
      }

      final previousChannel = (previous['channel'] ?? '').toString();
      final previousOrigin = (previous['origin'] ?? '').toString();
      final previousSeenAt =
          DateTime.tryParse((previous['seenAt'] ?? '').toString());
      if (previousSeenAt == null) continue;
      final age = now.difference(previousSeenAt).abs();

      if (previousChannel == channel) {
        // When either signal has native identity, only that same identity
        // can prove a replay. Different or missing identities stay separate.
        if (sourceFingerprint != null || previousSourceFingerprint.isNotEmpty) {
          continue;
        }
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
      final previousPayer = (previous['payer'] ?? '').toString();
      final differentAccounts = account.isNotEmpty &&
          previousAccount.isNotEmpty &&
          account != previousAccount;
      final differentPayers = payer.isNotEmpty &&
          previousPayer.isNotEmpty &&
          !_payersCompatible(payer, previousPayer);
      if (differentAccounts || differentPayers) continue;

      final sameAccount =
          account.isNotEmpty && account == previousAccount;
      final samePayer =
          payer.isNotEmpty &&
          previousPayer.isNotEmpty &&
          _payersCompatible(payer, previousPayer);

      // Truecaller may mirror a trusted UPI/bank notification but omit its
      // payer, masked account, and UTR. Coalesce only a UNIQUE cross-channel
      // candidate within 8 seconds, with matching known amount/direction and
      // no conflicting payer/account evidence. Ordinary amount-only matching
      // remains disabled so unrelated same-value payments are not merged.
      final truecallerCrossAppEcho =
          age <= _truecallerCrossSourceEchoWindow &&
          ((origin == 'truecaller_notification' &&
                  previousOrigin != 'truecaller_notification' &&
                  _isTrustedTruecallerEchoCounterpart(previousChannel)) ||
              (previousOrigin == 'truecaller_notification' &&
                  origin != 'truecaller_notification' &&
                  _isTrustedTruecallerEchoCounterpart(channel)));
      if (!sameAccount && !samePayer && !truecallerCrossAppEcho) continue;

      final claimedChannels = (previous['claimedChannels'] is List)
          ? (previous['claimedChannels'] as List)
              .map((value) => value.toString())
              .toSet()
          : <String>{};
      if (claimedChannels.contains(channel)) continue;

      if (uniqueEchoCandidate != null &&
          !identical(uniqueEchoCandidate, previous)) {
        ambiguousCandidates = true;
        break;
      }
      uniqueEchoCandidate = previous;
    }

    if (uniqueEchoCandidate != null && !ambiguousCandidates) {
      final claimedChannels = (uniqueEchoCandidate['claimedChannels'] is List)
          ? (uniqueEchoCandidate['claimedChannels'] as List)
              .map((value) => value.toString())
              .toSet()
          : <String>{};
      claimedChannels.add(channel);
      uniqueEchoCandidate['claimedChannels'] = claimedChannels.toList();
      final id = uniqueEchoCandidate['id'];
      final index = stored.indexWhere((entry) => entry['id'] == id);
      if (index >= 0) stored[index] = uniqueEchoCandidate;
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

  static bool _isSmsOrigin(String origin) =>
      origin == 'sms' || origin == 'notification+sms';

  static bool _isTrustedTruecallerEchoCounterpart(String channel) {
    final parts = channel.toLowerCase().split('|');
    if (parts.isEmpty) return false;
    final origin = parts.first;
    if (origin == 'sms' || origin == 'notification+sms') return true;
    return _truecallerEchoTrustedSources.contains(parts.last);
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

  static bool _payersCompatible(String current, String previous) =>
      current == previous ||
      current.contains(previous) ||
      previous.contains(current);
}
