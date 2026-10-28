import 'package:retail_mind/payment_event.dart';

/// Coalesces repeat *alerts* without collapsing distinct payments merely
/// because the payer and amount happen to be the same.
class PaymentAlertDeduplicator {
  static const Duration _referenceTtl = Duration(hours: 6);
  static const Duration _fallbackTtl = Duration(minutes: 15);
  static const Duration _sameChannelReplayWindow = Duration(seconds: 10);
  static const int _maxEntries = 500;

  final List<_AlertObservation> _seen = <_AlertObservation>[];

  bool shouldSuppress(
    PaymentEvent event, {
    DateTime? now,
  }) {
    if (event.isDuplicate && !event.hasReferenceConflict) return true;
    if (event.isMerchantConfirmed ||
        event.hasReferenceConflict ||
        event.isFailed) {
      return false;
    }
    if (!event.amount.isFinite || event.amount <= 0) return false;

    final moment = now ?? DateTime.now();
    _seen.removeWhere((entry) => !entry.expiresAt.isAfter(moment));

    final direction = _directionKey(event);
    if (direction == 'unknown') {
      _remember(event, direction, moment);
      return false;
    }

    final amount = event.amount;
    final reference = event.normalizedReferenceId;
    final sourceFingerprint = event.sourceEventFingerprint;
    final channel = _channelKey(event);
    final text = _normalizeText(event.rawText);
    final payer = _payerIdentity(event);
    final account = _normalizeAccount(event.accountSuffix);
    _AlertObservation? uniqueEchoCandidate;
    var ambiguousCandidates = false;

    for (final previous in _seen.reversed) {
      if ((previous.amount - amount).abs() >= 0.01 ||
          previous.direction != direction) {
        continue;
      }

      if (sourceFingerprint != null &&
          previous.sourceFingerprint == sourceFingerprint) {
        if (previous.reference != null &&
            reference != null &&
            previous.reference != reference) {
          continue;
        }
        if (previous.reference == null && reference != null) {
          previous.reference = reference;
          previous.expiresAt = moment.add(_referenceTtl);
        }
        return true;
      }

      if (reference != null || previous.reference != null) {
        if (reference != null && previous.reference == reference) return true;
        continue;
      }

      final age = moment.difference(previous.seenAt).abs();
      if (age > _fallbackTtl) continue;

      if (previous.channel == channel) {
        if (sourceFingerprint != null || previous.sourceFingerprint != null) {
          // A missing or distinct native identity cannot be treated as a replay.
          continue;
        }
        if (age <= _sameChannelReplayWindow &&
            text.isNotEmpty &&
            text == previous.text) {
          return true;
        }
        continue;
      }

      if (previous.claimedChannels.contains(channel)) continue;

      final differentAccounts = account.isNotEmpty &&
          previous.account.isNotEmpty &&
          account != previous.account;
      final previousPayer = previous.payer;
      final differentPayers = payer != null &&
          previousPayer != null &&
          !_payersCompatible(payer, previousPayer);
      if (differentAccounts || differentPayers) continue;

      final sameAccount =
          account.isNotEmpty && account == previous.account;
      final samePayer = payer != null &&
          previousPayer != null &&
          _payersCompatible(payer, previousPayer);
      if (!sameAccount && !samePayer) continue;

      if (uniqueEchoCandidate != null &&
          !identical(uniqueEchoCandidate, previous)) {
        ambiguousCandidates = true;
        break;
      }
      uniqueEchoCandidate = previous;
    }

    if (uniqueEchoCandidate != null && !ambiguousCandidates) {
      uniqueEchoCandidate.claimedChannels.add(channel);
      return true;
    }

    // Preserve an ambiguous cross-source event as its own alert candidate.
    _remember(event, direction, moment);
    return false;
  }

  void _remember(PaymentEvent event, String direction, DateTime moment) {
    _seen.add(
      _AlertObservation(
        amount: event.amount,
        direction: direction,
        reference: event.normalizedReferenceId,
        sourceFingerprint: event.sourceEventFingerprint,
        channel: _channelKey(event),
        payer: _payerIdentity(event),
        account: _normalizeAccount(event.accountSuffix),
        text: _normalizeText(event.rawText),
        seenAt: moment,
        expiresAt: moment.add(
          event.normalizedReferenceId != null ? _referenceTtl : _fallbackTtl,
        ),
      ),
    );
    while (_seen.length > _maxEntries) {
      _seen.removeAt(0);
    }
  }

  void clear() => _seen.clear();

  /// Keep a sounding system alert only when speech is disabled or an alert
  /// needs independent escalation. Routine speech-enabled detections use a
  /// silent OS notification so one event does not create two audible outputs.
  static bool shouldUseAudibleNotificationFallback(
    PaymentEvent event, {
    required bool voiceEnabled,
  }) {
    if (!voiceEnabled) return true;
    if (event.isDuplicate || event.hasReferenceConflict) return true;
    return event.detectionSource.contains(':pending_review_reminder');
  }

  static String _directionKey(PaymentEvent event) {
    switch (event.direction) {
      case PaymentTransactionDirection.incomingCredit:
        return 'credit';
      case PaymentTransactionDirection.outgoingDebit:
        return 'debit';
      case PaymentTransactionDirection.unknown:
        final text = event.rawText.toLowerCase();
        final debit = RegExp(
          r'\b(?:debited|debit|withdrawn|deducted|spent)\b',
        ).hasMatch(text);
        final credit = RegExp(
          r'\b(?:credited|credit|received|deposited)\b',
        ).hasMatch(text);
        if (credit != debit) return credit ? 'credit' : 'debit';
        return 'unknown';
    }
  }

  static String _channelKey(PaymentEvent event) =>
      '${_eventOrigin(event.detectionSource)}|${event.app.name}';

  static String _eventOrigin(String source) {
    final value = source.toLowerCase();
    if (value.startsWith('truecaller_notification')) {
      return 'truecaller_notification';
    }
    if (value.startsWith('notification+sms')) return 'notification+sms';
    if (value.startsWith('notification')) return 'notification';
    if (value.startsWith('sms')) return 'sms';
    if (value.startsWith('accessibility')) return 'accessibility';
    return value.split(':').first;
  }

  static String _normalizeText(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9₹]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _normalizeAccount(String? value) =>
      (value ?? '').replaceAll(RegExp(r'[^0-9]'), '').trim();

  static bool _payersCompatible(String current, String previous) =>
      current == previous ||
      current.contains(previous) ||
      previous.contains(current);

  static String? _payerIdentity(PaymentEvent event) {
    final supplied = _normalizeName(event.payerName);
    if (_isUsefulName(supplied)) return supplied;

    final text = event.rawText;
    final senderFirst = RegExp(
      r"""^\s*([A-Za-z][A-Za-z .'-]{1,40}?)\s+(?:sent|paid|transferred)\b""",
      caseSensitive: false,
    ).firstMatch(text);
    if (senderFirst != null) {
      final name = _normalizeName(senderFirst.group(1));
      if (_isUsefulName(name)) return name;
    }

    final fromSender = RegExp(
      r"""\bfrom\s+([A-Za-z][A-Za-z .'-]{1,40}?)(?=\s+(?:to|via|for|on|using|upi|utr|reference|ref|txn|id|credited|sent|paid)\b|[.,;]|₹|$)""",
      caseSensitive: false,
    ).firstMatch(text);
    if (fromSender != null) {
      final name = _normalizeName(fromSender.group(1));
      if (_isUsefulName(name)) return name;
    }
    return null;
  }

  static String? _normalizeName(String? value) => (value ?? '')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool _isUsefulName(String? name) {
    if (name == null || name.length < 2) return false;
    return !const {
      'bank',
      'bank payment',
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
      'account',
      'your account',
    }.contains(name);
  }
}

class _AlertObservation {
  _AlertObservation({
    required this.amount,
    required this.direction,
    required this.reference,
    required this.sourceFingerprint,
    required this.channel,
    required this.payer,
    required this.account,
    required this.text,
    required this.seenAt,
    required this.expiresAt,
  });

  final double amount;
  final String direction;
  String? reference;
  final String? sourceFingerprint;
  final String channel;
  final String? payer;
  final String account;
  final String text;
  final DateTime seenAt;
  DateTime expiresAt;
  final Set<String> claimedChannels = <String>{};
}
