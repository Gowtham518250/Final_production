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


  static const String _aliasRecordType = 'online_payment_history_alias_v1';
  static const Duration _signalCorrelationWindow = Duration(seconds: 12);
  static const Duration _referenceCorrelationWindow = Duration(seconds: 45);

  static Map<String, dynamic>? _decodeEntry(String? raw) {
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      if (value is Map) return Map<String, dynamic>.from(value);
    } on FormatException {
      return null;
    }
    return null;
  }

  static bool _isAlias(Map<String, dynamic> entry) =>
      entry['_record_type'] == _aliasRecordType;

  /// Resolve aliases to one visible row. A missing target makes an alias stale.
  static Future<String?> _resolveCanonicalKey(
    SharedPreferences prefs,
    String key,
  ) async {
    var current = key;
    final seen = <String>{};
    for (var depth = 0; depth < 12; depth++) {
      if (!seen.add(current)) return null;
      final entry = _decodeEntry(prefs.getString(current));
      if (entry == null) return null;
      if (!_isAlias(entry)) return current;
      final target = (entry['_alias_for'] ?? '').toString();
      if (target.isEmpty) return null;
      current = target;
    }
    return null;
  }

  static Future<void> _writeAlias(
    SharedPreferences prefs,
    String aliasKey,
    String canonicalKey, {
    String? reference,
  }) async {
    final resolved = await _resolveCanonicalKey(prefs, canonicalKey);
    final target = resolved ?? canonicalKey;
    if (aliasKey == target) return;
    // Never overwrite a real row with an alias.
    final existing = _decodeEntry(prefs.getString(aliasKey));
    if (existing != null && !_isAlias(existing)) return;
    await prefs.setString(aliasKey, jsonEncode(<String, dynamic>{
      '_record_type': _aliasRecordType,
      '_alias_for': target,
      'timestamp': DateTime.now().toIso8601String(),
      if (reference != null) 'reference_id': reference,
    }));
  }

  static String _historyDirection(PaymentEvent event) {
    switch (event.direction) {
      case PaymentTransactionDirection.incomingCredit:
        return 'incomingCredit';
      case PaymentTransactionDirection.outgoingDebit:
        return 'outgoingDebit';
      case PaymentTransactionDirection.unknown:
        final detected = VoiceBuilder.detectDirection(event.rawText);
        if (detected == PaymentDirection.credited) return 'incomingCredit';
        if (detected == PaymentDirection.debited) return 'outgoingDebit';
        return 'unknown';
    }
  }

  static String _sourceChannel(String source) {
    final normalized = source.toLowerCase();
    if (normalized.contains('accessibility')) return 'accessibility';
    if (normalized.contains('sms')) return 'sms';
    if (normalized.contains('notification')) return 'notification';
    return 'unknown';
  }

  static DateTime _eventTime(PaymentEvent event) =>
      event.sourceTimestamp ?? event.timestamp;

  static DateTime? _storedTime(Map<String, dynamic> entry) {
    for (final name in const ['timestamp', 'detected_at']) {
      final value = entry[name]?.toString();
      if (value == null || value.isEmpty) continue;
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static bool _within(DateTime first, DateTime second, Duration window) {
    final delta = first.isBefore(second)
        ? second.difference(first)
        : first.difference(second);
    return delta <= window;
  }

  static String _signalSignature(PaymentEvent event) {
    final normalizedText = event.rawText
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u0080-\uFFFF]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    final payload = '${event.app.name}|${event.amount.toStringAsFixed(2)}|'
        '${_historyDirection(event)}|$normalizedText';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  static String? _payerMatchHash(PaymentEvent event) {
    final name = (event.payerName ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u0080-\uFFFF]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    if (name.length < 2) return null;
    return sha256.convert(utf8.encode(name)).toString();
  }

  static List<String> _storedStrings(Map<String, dynamic> entry, String field) {
    final value = entry[field];
    if (value is List) {
      return value.map((item) => item.toString()).where((s) => s.isNotEmpty).toList();
    }
    final single = entry[field]?.toString() ?? '';
    return single.isEmpty ? <String>[] : <String>[single];
  }

  static String? _legacyAppKey(Map<String, dynamic> entry) {
    switch ((entry['app'] ?? '').toString().trim().toLowerCase()) {
      case 'phonepe':
        return 'phonePe';
      case 'google pay':
        return 'googlePay';
      case 'paytm':
        return 'paytm';
      case 'bank sms':
        return 'bankSms';
      case 'upi app':
        return null;
      default:
        return null;
    }
  }

  static bool _hasStrongSignalLink(
    Map<String, dynamic> entry,
    PaymentEvent event,
  ) {
    final signature = _signalSignature(event);
    if (_storedStrings(entry, 'signal_signatures').contains(signature)) {
      return true;
    }
    final payerHash = _payerMatchHash(event);
    if (payerHash != null && entry['payer_match_hash'] == payerHash) {
      return true;
    }
    final channels = _storedStrings(entry, 'source_channels').toSet();
    final apps = _storedStrings(entry, 'source_apps').toSet();
    final legacyApp = _legacyAppKey(entry);
    if (legacyApp != null) apps.add(legacyApp);
    final source = _sourceChannel(event.detectionSource);
    final sameApp = apps.contains(event.app.name);
    final channelsDiffer = channels.any((previous) =>
        previous != source &&
        previous != 'unknown' &&
        source != 'unknown');
    // Same-app notification/accessibility callbacks are two views of one OS alert.
    return sameApp &&
        channelsDiffer &&
        ((channels.contains('notification') && source == 'accessibility') ||
            (channels.contains('accessibility') && source == 'notification'));
  }

  static Future<List<Map<String, dynamic>>> _findCorrelatedRows(
    SharedPreferences prefs,
    String prefix,
    PaymentEvent event, {
    required String incomingKey,
  }) async {
    final reference = event.normalizedReferenceId;
    final direction = _historyDirection(event);
    if (direction == 'unknown') return <Map<String, dynamic>>[];
    final eventTime = _eventTime(event);
    final rows = <Map<String, dynamic>>[];

    for (final key in prefs.getKeys().where((key) => key.startsWith(prefix)) {
      if (key == incomingKey) continue;
      final entry = _decodeEntry(prefs.getString(key));
      if (entry == null || _isAlias(entry)) continue;
      final status = (entry['status'] ?? '').toString().toUpperCase();
      if (status == 'CONFLICT_REVIEW' || status == 'REJECTED') continue;
      final rowAmount = (entry['amount'] as num?)?.toDouble();
      if (rowAmount == null ||
          !rowAmount.isFinite ||
          (rowAmount - event.amount).abs() >= 0.01) {
        continue;
      }
      if ((entry['direction'] ?? 'unknown').toString() != direction) continue;
      final rowTime = _storedTime(entry);
      if (rowTime == null) continue;
      final rowReference = (entry['reference_id'] ?? '').toString().trim();
      final hasRowReference = rowReference.isNotEmpty;

      if (reference != null) {
        // A bank/SMS reference may attach to one nearby unreferenced signal.
        // Never merge two independently referenced payments.
        if (hasRowReference ||
            !_within(eventTime, rowTime, _referenceCorrelationWindow)) {
          continue;
        }
        rows.add(<String, dynamic>{'key': key, 'entry': entry});
        continue;
      }

      final window =
          hasRowReference ? _referenceCorrelationWindow : _signalCorrelationWindow;
      if (!_within(eventTime, rowTime, window)) continue;
      if (!_hasStrongSignalLink(entry, event)) continue;
      rows.add(<String, dynamic>{'key': key, 'entry': entry});
    }
    return rows;
  }

  static Map<String, dynamic> _appendSignal(
    Map<String, dynamic> existing,
    PaymentEvent event,
  ) {
    final updated = Map<String, dynamic>.from(existing);
    final appKeys = _storedStrings(updated, 'source_apps').toSet();
    appKeys.add(event.app.name);
    updated['source_apps'] = appKeys.toList();

    final channels = _storedStrings(updated, 'source_channels').toSet();
    final channel = _sourceChannel(event.detectionSource);
    if (channel != 'unknown') channels.add(channel);
    updated['source_channels'] = channels.toList();

    final signatures = _storedStrings(updated, 'signal_signatures').toSet();
    signatures.add(_signalSignature(event));
    updated['signal_signatures'] = signatures.take(12).toList();

    final payerHash = _payerMatchHash(event);
    if (updated['payer_match_hash'] == null && payerHash != null) {
      updated['payer_match_hash'] = payerHash;
    }

    final signals = updated['source_signals'] is List
        ? (updated['source_signals'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
    if (!signals.any((item) =>
        item['app'] == event.appDisplayName && item['channel'] == channel)) {
      signals.add(<String, dynamic>{
        'app': event.appDisplayName,
        'channel': channel,
      });
    }
    updated['source_signals'] = signals.take(12).toList();
    return updated;
  }

  static Future<bool> recordIncomingPayment(PaymentEvent event) async {
    if (event.isFailed ||
        event.decision == PaymentDecision.rejected ||
        !event.amount.isFinite ||
        event.amount <= 0 ||
        event.hasReferenceConflict ||
        event.isDuplicate) {
      return false;
    }
    final isIncomingCredit =
        event.direction == PaymentTransactionDirection.incomingCredit ||
        (event.direction == PaymentTransactionDirection.unknown &&
            VoiceBuilder.detectDirection(event.rawText) ==
                PaymentDirection.credited);
    if (!isIncomingCredit) return false;

    final reference = event.normalizedReferenceId;
    final prefs = await SharedPreferences.getInstance();
    final userId = await _currentUserId(prefs);
    final prefix = _userPrefix(userId);
    final fingerprint = sha256.convert(utf8.encode(event.fingerprint)).toString();
    final incomingKey = '$prefix$fingerprint';

    // A reference or event ID may already be a hidden alias created when this
    // signal was linked to an earlier PhonePe/UPI/SMS row.
    var canonicalKey =
        await _resolveCanonicalKey(prefs, incomingKey) ?? incomingKey;
    var existing = _decodeEntry(prefs.getString(canonicalKey));

    if (existing == null) {
      final candidates = await _findCorrelatedRows(
        prefs,
        prefix,
        event,
        incomingKey: incomingKey,
      );
      // Amount and time alone must not merge two real same-value transfers.
      // A reference attaches only when exactly one unreferenced candidate fits.
      if (candidates.length == 1) {
        canonicalKey = candidates.single['key'] as String;
        existing = Map<String, dynamic>.from(
          candidates.single['entry'] as Map<String, dynamic>,
        );
      }
    }

    final oldStatus = (existing?['status'] ?? '').toString().toUpperCase();
    final oldAmount = (existing?['amount'] as num?)?.toDouble();

    if (existing != null &&
        reference != null &&
        (existing['reference_id']?.toString().isNotEmpty ?? false) &&
        oldAmount != null &&
        oldAmount.isFinite &&
        (oldAmount - event.amount).abs() >= 0.01) {
      final amounts = <double>{
        oldAmount,
        if (existing['conflicting_amounts'] is List)
          for (final value in existing['conflicting_amounts'] as List)
            if (value is num && value.toDouble().isFinite) value.toDouble(),
        event.amount,
      }.toList()..sort();
      await prefs.setString(
        canonicalKey,
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
      if (incomingKey != canonicalKey) {
        await _writeAlias(prefs, incomingKey, canonicalKey, reference: reference);
      }
      await _trimHistory(prefs, prefix);
      return false;
    }

    if (oldStatus == 'CONFLICT_REVIEW') {
      final amounts = <double>{
        if (oldAmount != null && oldAmount.isFinite) oldAmount,
        if (existing!['conflicting_amounts'] is List)
          for (final value in existing['conflicting_amounts'] as List)
            if (value is num && value.toDouble().isFinite) value.toDouble(),
        event.amount,
      }.toList()..sort();
      await prefs.setString(
        canonicalKey,
        jsonEncode(<String, dynamic>{
          ...existing!,
          'status': 'CONFLICT_REVIEW',
          'merchant_confirmed': false,
          'verified': false,
          'conflicting_amounts': amounts,
          'conflict_detected_at': event.timestamp.toIso8601String(),
        }),
      );
      if (incomingKey != canonicalKey) {
        await _writeAlias(prefs, incomingKey, canonicalKey, reference: reference);
      }
      await _trimHistory(prefs, prefix);
      return false;
    }

    // Persist aliases for replays without downgrading a confirmed/rejected row.
    if (oldStatus == 'REJECTED' && !event.isMerchantConfirmed) {
      if (incomingKey != canonicalKey && existing != null) {
        await _writeAlias(prefs, incomingKey, canonicalKey, reference: reference);
      }
      return false;
    }
    if (oldStatus == 'CONFIRMED' && !event.isMerchantConfirmed) {
      if (incomingKey != canonicalKey && existing != null) {
        await _writeAlias(prefs, incomingKey, canonicalKey, reference: reference);
      }
      return false;
    }

    final base = existing ?? <String, dynamic>{};
    final record = <String, dynamic>{
      ...base,
      'amount': event.amount,
      'timestamp': base['timestamp'] ?? _eventTime(event).toIso8601String(),
      'detected_at': base['detected_at'] ?? event.timestamp.toIso8601String(),
      'app': (base['app']?.toString().isNotEmpty ?? false)
          ? base['app']
          : event.appDisplayName,
      'status': event.isMerchantConfirmed
          ? 'CONFIRMED'
          : (oldStatus.isNotEmpty ? oldStatus : 'PENDING_CONFIRMATION'),
      'merchant_confirmed':
          event.isMerchantConfirmed || base['merchant_confirmed'] == true,
      // A locally observed notification is never bank-verified.
      'verified': false,
      if (reference != null) 'reference_id': reference,
      if ((base['reference_id'] ?? '').toString().isNotEmpty)
        'reference_id': base['reference_id'],
      'direction': _historyDirection(event) == 'unknown'
          ? (base['direction'] ?? 'unknown')
          : _historyDirection(event),
    };
    final withSignal = _appendSignal(record, event);
    await prefs.setString(canonicalKey, jsonEncode(withSignal));

    // Each incoming signal keeps a durable lookup key, but aliases are hidden
    // from history UI so multiple sources still represent one payment.
    if (incomingKey != canonicalKey) {
      await _writeAlias(
        prefs,
        incomingKey,
        canonicalKey,
        reference: reference,
      );
    }
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
        'timestamp':
            (event.sourceTimestamp ?? event.timestamp).toIso8601String(),
        'detected_at': event.timestamp.toIso8601String(),
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
    final fingerprint = sha256.convert(utf8.encode(event.fingerprint)).toString();
    final key = '${_userPrefix(userId)}$fingerprint';
    final canonicalKey = await _resolveCanonicalKey(prefs, key);
    if (canonicalKey == null) return event;

    final existing = _decodeEntry(prefs.getString(canonicalKey));
    if (existing == null) return event;

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
      DateTime? lastPendingAt;
      try {
        final rawTimestamp =
            (existing['detected_at'] ?? existing['timestamp'])?.toString();
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
    final key = '${_userPrefix(userId)}$fingerprint';
    final canonicalKey = await _resolveCanonicalKey(prefs, key);
    if (canonicalKey == null) return false;
    final decoded = _decodeEntry(prefs.getString(canonicalKey));
    return decoded?['status']?.toString() == 'CONFLICT_REVIEW';
  }

  static Future<List<Map<String, dynamic>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await _currentUserId(prefs);
    final prefix = _userPrefix(userId);
    final entries = <Map<String, dynamic>>[];
    for (final key in prefs.getKeys().where((key) => key.startsWith(prefix))) {
      final decoded = _decodeEntry(prefs.getString(key));
      if (decoded == null || _isAlias(decoded)) continue;
      entries.add(decoded);
    }
    entries.sort((a, b) {
      final aDate = DateTime.tryParse(a['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = DateTime.tryParse(b['timestamp']?.toString() ?? '') ??
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
      final decoded = _decodeEntry(prefs.getString(key));
      if (decoded == null || _isAlias(decoded)) continue;
      final timestamp = DateTime.tryParse(decoded['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      entries.add((key: key, timestamp: timestamp));
    }

    if (entries.length > _maxEntries) {
      entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final removed = entries
          .take(entries.length - _maxEntries)
          .map((entry) => entry.key)
          .toSet();
      for (final key in removed) {
        await prefs.remove(key);
      }
    }

    // Alias rows are internal lookup entries only; remove any whose canonical
    // row was trimmed so they cannot become orphaned pseudo-records.
    for (final key in prefs.getKeys().where((key) => key.startsWith(prefix))) {
      final decoded = _decodeEntry(prefs.getString(key));
      if (decoded == null || !_isAlias(decoded)) continue;
      final target = (decoded['_alias_for'] ?? '').toString();
      if (target.isEmpty || prefs.getString(target) == null) {
        await prefs.remove(key);
      }
    }
  }

}
