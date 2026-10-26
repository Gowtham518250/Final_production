import 'package:retail_mind/payment_event.dart';

/// Coalesces repeated *alerts* for a likely payment without merging accounting
/// events. It is intentionally used only for dashboard notifications and
/// confirmation prompts; payment history and the financial ledger still use
/// their own reference/idempotency rules.
class PaymentAlertDeduplicator {
  // Allow a still-pending payment to be reminded again the next morning, but
  // coalesce a burst of cross-source notifications during the same work period.
  static const Duration _referenceTtl = Duration(hours: 6);
  static const Duration _fallbackTtl = Duration(minutes: 15);
  static const int _maxEntries = 500;

  final Map<String, DateTime> _seenUntil = <String, DateTime>{};

  bool shouldSuppress(
    PaymentEvent event, {
    DateTime? now,
  }) {
    // A duplicate tied to an already-known reference is not a fresh payment
    // candidate. Unresolved candidates are deliberately marked non-duplicate
    // by OnlinePaymentHistoryService once their reminder interval has elapsed.
    if (event.isDuplicate && !event.hasReferenceConflict) return true;
    if (event.isMerchantConfirmed ||
        event.hasReferenceConflict ||
        event.isFailed) {
      return false;
    }
    if (!event.amount.isFinite || event.amount <= 0) return false;

    final moment = now ?? DateTime.now();
    _seenUntil.removeWhere((_, expiry) => !expiry.isAfter(moment));

    final direction = _directionKey(event);
    final amount = event.amount.toStringAsFixed(2);
    final reference = event.normalizedReferenceId;
    late final String key;
    late final Duration ttl;

    if (reference != null) {
      // A matching transaction reference and amount is a strong replay key.
      // The amount and direction remain part of the alert key so a conflicting
      // reference/amount/direction is never hidden as an ordinary duplicate.
      key = 'reference:$reference|$amount|$direction';
      ttl = _referenceTtl;
    } else {
      final payer = _payerIdentity(event);
      final accountSuffix = (event.accountSuffix ?? '')
          .replaceAll(RegExp(r'[^0-9]'), '')
          .trim();

      if (payer != null) {
        // This matches PhonePe and the accessibility/UPI fallback when both
        // independently parse the same sender name, amount and direction.
        key = 'payer:$payer|$amount|$direction';
      } else if (accountSuffix.isNotEmpty) {
        key = 'account:$accountSuffix|$amount|$direction';
      } else {
        final normalizedText = event.rawText
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9₹]+'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (normalizedText.isEmpty) return false;
        // No trustworthy shared identity: only coalesce an exact textual replay.
        // Amount-only/time-only matching is deliberately not used.
        key = 'payload:$normalizedText|$amount|$direction';
      }
      ttl = _fallbackTtl;
    }

    final seenExpiry = _seenUntil[key];
    if (seenExpiry != null && seenExpiry.isAfter(moment)) {
      return true;
    }

    _seenUntil[key] = moment.add(ttl);
    while (_seenUntil.length > _maxEntries) {
      _seenUntil.remove(_seenUntil.keys.first);
    }
    return false;
  }

  void clear() => _seenUntil.clear();

  /// Use an audible OS notification as a fallback when TTS is disabled or the
  /// voice queue is expected to reject this event (duplicate/conflict flags),
  /// and for an unresolved payment resurfaced after the overnight cooldown.
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

  static String? _normalizeName(String? value) {
    final normalized = (value ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized.isEmpty ? null : normalized;
  }

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
