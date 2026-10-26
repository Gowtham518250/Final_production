import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'payment_detection_service.dart';
import 'payment_event.dart';

class OnlinePaymentHistoryService {
  static const _keyPrefix = 'confirmed_online_payment';
  static const _maxEntries = 500;
  static const Duration pendingReviewReminderInterval = Duration(hours: 6);

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

    final reference = event.normalizedReferenceId;
    // A duplicate without a reference has no safe transaction identity to
    // reconcile against. Do not add a second history row for an explicitly
    // marked duplicate.
    if (event.isDuplicate && reference == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final userId = await _currentUserId(prefs);
    final fingerprint = sha256
        .convert(utf8.encode(event.fingerprint))
        .toString();
    final prefix = _userPrefix(userId);
    final key = '$prefix$fingerprint';
    final existingRaw = prefs.getString(key);
    Map<String, dynamic>? existing;
    if (existingRaw != null) {
      try {
        final decoded = jsonDecode(existingRaw);
        if (decoded is Map) existing = Map<String, dynamic>.from(decoded);
      } on FormatException {
        // Replace corrupt local history only with a valid current event.
      }
    }

    if (existing != null) {
      final oldStatus = (existing['status'] ?? '').toString().toUpperCase();
      final oldAmount = (existing['amount'] as num?)?.toDouble();

      // Once a reference is conflicted, never automatically restore it to a
      // confirmed receipt. Keep all observed amounts for the merchant review.
      if (oldStatus == 'CONFLICT_REVIEW') {
        final amounts = <double>{
          if (oldAmount != null && oldAmount.isFinite) oldAmount,
          if (existing['conflicting_amounts'] is List)
            for (final value in existing['conflicting_amounts'] as List)
              if (value is num && value.toDouble().isFinite) value.toDouble(),
          event.amount,
        }.toList()
          ..sort();
        await prefs.setString(
          key,
          jsonEncode(<String, dynamic>{
            ...existing,
            'status': 'CONFLICT_REVIEW',
            'merchant_confirmed': false,
            'verified': false,
            'conflicting_amounts': amounts,
            'conflict_detected_at': event.timestamp.toIso8601String(),
          }),
        );
        await _trimHistory(prefs, prefix);
        return false;
      }

      // Same normalized reference but a different amount is an identity
      // conflict. Persist the review state and exclude it from confirmed totals.
      if (reference != null &&
          oldAmount != null &&
          oldAmount.isFinite &&
          (oldAmount - event.amount).abs() >= 0.01) {
        final amounts = <double>{oldAmount, event.amount}.toList()..sort();
        await prefs.setString(
          key,
          jsonEncode(<String, dynamic>{
            ...existing,
            'status': 'CONFLICT_REVIEW',
            'merchant_confirmed': false,
            'verified': false,
            'reference_id': reference,
            'conflict_reason': 'same_reference_different_amount',
            'conflicting_amounts': amounts,
            'conflict_detected_at': event.timestamp.toIso8601String(),
          }),
        );
        await _trimHistory(prefs, prefix);
        return false;
      }

      // A merchant explicitly rejected this candidate. Do not silently
      // re-create it as pending on a later replay of the same reference.
      if (oldStatus == 'REJECTED' && !event.isMerchantConfirmed) {
        return false;
      }

      // Don't overwrite a good record with a duplicate callback or downgrade a
      // receipt that was already merchant-confirmed back to pending.
      if (event.isDuplicate ||
          (oldStatus == 'CONFIRMED' && !event.isMerchantConfirmed)) {
        return false;
      }
    }

    final record = <String, dynamic>{
      'amount': event.amount,
      'timestamp': event.timestamp.toIso8601String(),
      'app': event.appDisplayName,
      'status': event.isMerchantConfirmed
          ? 'CONFIRMED'
          : 'PENDING_CONFIRMATION',
      'merchant_confirmed': event.isMerchantConfirmed,
      // No bank API is consulted here: merchant confirmation is not bank
      // verification, so never label this locally observed event as verified.
      'verified': false,
      if (reference != null) 'reference_id': reference,
      'direction': event.direction.name,
    };

    await prefs.setString(key, jsonEncode(record));
    await _trimHistory(prefs, prefix);
    return true;
  }


  /// Persist the merchant's explicit "Not received" choice so the same
  /// transaction is not repeatedly offered as a fresh payment review.
  static Future<bool> rejectPendingPayment(PaymentEvent event) async {
    if (!event.amount.isFinite || event.amount <= 0) return false;
    final isIncomingCredit =
        event.direction == PaymentTransactionDirection.incomingCredit ||
        (event.direction == PaymentTransactionDirection.unknown &&
            VoiceBuilder.detectDirection(event.rawText) ==
                PaymentDirection.credited);
    if (!isIncomingCredit || event.hasReferenceConflict) return false;

    final prefs = await SharedPreferences.getInstance();
    final userId = await _currentUserId(prefs);
    final fingerprint = sha256
        .convert(utf8.encode(event.fingerprint))
        .toString();
    final key = '${_userPrefix(userId)}$fingerprint';
    final raw = prefs.getString(key);
    Map<String, dynamic> existing = <String, dynamic>{};
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) existing = Map<String, dynamic>.from(decoded);
      } on FormatException {
        // Replace corrupt pending state with an explicit rejection record.
      }
    }

    final oldStatus = (existing['status'] ?? '').toString().toUpperCase();
    if (oldStatus == 'CONFIRMED' || oldStatus == 'CONFLICT_REVIEW') {
      return false;
    }

    await prefs.setString(
      key,
      jsonEncode(<String, dynamic>{
        ...existing,
        'amount': event.amount,
        'timestamp': event.timestamp.toIso8601String(),
        'app': event.appDisplayName,
        'status': 'REJECTED',
        'merchant_confirmed': false,
        'verified': false,
        if (event.normalizedReferenceId != null)
          'reference_id': event.normalizedReferenceId,
        'direction': event.direction.name,
        'rejected_at': DateTime.now().toIso8601String(),
      }),
    );
    await _trimHistory(prefs, _userPrefix(userId));
    return true;
  }

  /// Mark repeated references before forwarding an event from the background
  /// isolate. The stored history key survives process restarts, unlike the
  /// detector's in-memory dedup cache.
  static Future<PaymentEvent> annotateKnownReferenceState(
    PaymentEvent event,
  ) async {
    final reference = event.normalizedReferenceId;
    if (reference == null) return event;

    final prefs = await SharedPreferences.getInstance();
    final userId = await _currentUserId(prefs);
    final fingerprint = sha256
        .convert(utf8.encode(event.fingerprint))
        .toString();
    final key = '${_userPrefix(userId)}$fingerprint';
    final raw = prefs.getString(key);
    if (raw == null) return event;

    Map<String, dynamic> existing;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return event;
      existing = Map<String, dynamic>.from(decoded);
    } on FormatException {
      return event;
    }

    if (existing['status']?.toString() == 'CONFLICT_REVIEW') {
      return event.copyWith(
        hasReferenceConflict: true,
        isDuplicate: false,
        decision: PaymentDecision.likely,
        verificationStatus: PaymentVerificationStatus.unverified,
      );
    }

    final oldAmount = (existing['amount'] as num?)?.toDouble();
    if (oldAmount != null &&
        oldAmount.isFinite &&
        (oldAmount - event.amount).abs() >= 0.01) {
      // recordIncomingPayment transitions the old reference into a durable
      // conflict-review state and removes it from confirmed history totals.
      await recordIncomingPayment(event);
      return event.copyWith(
        hasReferenceConflict: true,
        isDuplicate: false,
        decision: PaymentDecision.likely,
        verificationStatus: PaymentVerificationStatus.unverified,
      );
    }

    final oldStatus = (existing['status'] ?? '').toString().toUpperCase();
    if (oldStatus == 'PENDING_CONFIRMATION') {
      // A candidate left unresolved overnight is not a resolved duplicate.
      // Suppress ordinary replays for six hours, then surface the same
      // reference again as a review reminder. This does not record/confirm it.
      DateTime? lastPendingAt;
      try {
        final rawTimestamp = existing['timestamp']?.toString();
        if (rawTimestamp != null && rawTimestamp.isNotEmpty) {
          lastPendingAt = DateTime.parse(rawTimestamp);
        }
      } on FormatException {
        lastPendingAt = null;
      }
      final reminderDue = lastPendingAt == null ||
          !DateTime.now().isBefore(
            lastPendingAt.add(pendingReviewReminderInterval),
          );
      if (reminderDue) {
        return event.copyWith(
          isDuplicate: false,
          decision: PaymentDecision.likely,
          verificationStatus: PaymentVerificationStatus.unverified,
          detectionSource: '${event.detectionSource}:pending_review_reminder',
        );
      }
    }

    // Confirmed references and pending replays inside the reminder cooldown
    // are duplicates. The Dashboard suppresses their alert and confirmation UI.
    // Pending records become reviewable again only after the reminder interval.
    return event.copyWith(
      isDuplicate: true,
      decision: PaymentDecision.likely,
      verificationStatus: PaymentVerificationStatus.unverified,
    );
  }

  /// Returns true when this normalized transaction reference has a stored
  /// amount conflict. Used by the background isolate to mark the forwarded
  /// event before a POS listener can offer it as a receipt.
  static Future<bool> hasReferenceConflict(PaymentEvent event) async {
    final reference = event.normalizedReferenceId;
    if (reference == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final userId = await _currentUserId(prefs);
    final fingerprint = sha256
        .convert(utf8.encode('utr_${sha256.convert(utf8.encode(reference))}'))
        .toString();
    final raw = prefs.getString('${_userPrefix(userId)}$fingerprint');
    if (raw == null) return false;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map &&
          decoded['status']?.toString() == 'CONFLICT_REVIEW';
    } on FormatException {
      return false;
    }
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
