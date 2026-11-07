import 'package:retail_mind/payment_event.dart';

/// Coalesces repeat *alerts* without collapsing distinct payments merely
/// because the payer and amount happen to be the same.
class PaymentAlertDeduplicator {
  static const Duration _referenceTtl = Duration(hours: 6);
  static const Duration _fallbackTtl = Duration(minutes: 15);
  static const int _maxEntries = 500;

  final List<_AlertObservation> _seen = <_AlertObservation>[];

  bool shouldSuppress(PaymentEvent event, {DateTime? now}) {
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

      if (reference != null &&
          previous.reference != null &&
          reference == previous.reference) {
        return true;
      }
    }

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
}

class _AlertObservation {
  _AlertObservation({
    required this.amount,
    required this.direction,
    required this.reference,
    required this.sourceFingerprint,
    required this.expiresAt,
  });

  final double amount;
  final String direction;
  String? reference;
  final String? sourceFingerprint;
  DateTime expiresAt;
}
