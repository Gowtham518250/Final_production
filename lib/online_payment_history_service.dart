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
    bool replaceExisting = false,
  }) async {
    final resolved = await _resolveCanonicalKey(prefs, canonicalKey);
    final target = resolved ?? canonicalKey;
    if (aliasKey == target) return;
    final existing = _decodeEntry(prefs.getString(aliasKey));
    if (existing != null && !_isAlias(existing) && !replaceExisting) return;
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

  static String? _sourceIdentityKey(String prefix, PaymentEvent event) {
    final fingerprint = event.sourceEventFingerprint;
    return fingerprint == null ? null : '$prefix$fingerprint';
  }

  /// Only exact native notification identity plus matching financial direction
  /// and amount can replay the same history row. Amount/time alone never merge.
  static bool _matchesSourceEvent(
    Map<String, dynamic> entry,
    PaymentEvent event,
  ) {
    final sourceFingerprint = event.sourceEventFingerprint;
    if (sourceFingerprint == null ||
        entry['source_event_fingerprint'] != sourceFingerprint) {
      return false;
    }

    final oldAmount = (entry['amount'] as num?)?.toDouble();
    if (oldAmount == null ||
        !oldAmount.isFinite ||
        (oldAmount - event.amount).abs() >= 0.01) {
      return false;
    }

    final oldDirection = (entry['direction'] ?? 'unknown').toString();
    final newDirection = _historyDirection(event);
    if (oldDirection != 'unknown' &&
        newDirection != 'unknown' &&
        oldDirection != newDirection) {
      return false;
    }

    final oldReference = (entry['reference_id'] ?? '').toString().trim();
    final newReference = event.normalizedReferenceId;
    if (oldReference.isNotEmpty &&
        newReference != null &&
        oldReference != newReference) {
      return false;
    }
    return true;
  }

  static Future<void> _attachReferenceToSourceRow(
    SharedPreferences prefs,
    String prefix,
    String canonicalKey,
    Map<String, dynamic> entry,
    PaymentEvent event,
  ) async {
    final reference = event.normalizedReferenceId;
    if (reference == null) return;
    final oldReference = (entry['reference_id'] ?? '').toString().trim();
    if (oldReference.isNotEmpty && oldReference != reference) return;

    final updated = <String, dynamic>{
      ...entry,
      'reference_id': reference,
      'source_event_fingerprint': event.sourceEventFingerprint,
    };
    await prefs.setString(canonicalKey, jsonEncode(updated));
    final transactionFingerprint =
        sha256.convert(utf8.encode(event.fingerprint)).toString();
    final incomingReferenceKey = '$prefix$transactionFingerprint';
    if (incomingReferenceKey != canonicalKey) {
      await _writeAlias(
        prefs,
        incomingReferenceKey,
        canonicalKey,
        reference: reference,
        replaceExisting: true,
      );
    }
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
    final source = _sourceChannel(event.detectionSource);
    if (source != 'notification' && source != 'accessibility') return false;

    // Check source pairs rather than combining app and channel sets separately.
    // A global set would let an old PhonePe notification plus an unrelated SMS
    // make a second PhonePe notification look like a cross-channel replay.
    final rawSignals = entry['source_signals'];
    if (rawSignals is! List) return false;
    final appLabel = event.appDisplayName.trim().toLowerCase();
    final previousChannels = <String>{};
    for (final signal in rawSignals.whereType<Map>()) {
      final previousApp = (signal['app'] ?? '').toString().trim().toLowerCase();
      final previousChannel = _sourceChannel(
        (signal['channel'] ?? '').toString(),
      );
      if (previousApp == appLabel && previousChannel != 'unknown') {
        previousChannels.add(previousChannel);
      }
    }

    // Only deduplicate a notification/accessibility echo of the same app.
    // Same-channel repeats can be distinct real payments with identical values.
    return source == 'notification'
        ? previousChannels.contains('accessibility')
        : previousChannels.contains('notification');
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

    for (final key in prefs.getKeys().where((key) => key.startsWith(prefix))) {
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
        // A reference may attach to nearby unreferenced signal rows. Rows with
        // their own different reference are never merged into this payment.
        if (hasRowReference ||
            !_within(eventTime, rowTime, _referenceCorrelationWindow)) {
          continue;
        }
        rows.add(<String, dynamic>{'key': key, 'entry': entry});
        continue;
      }

      if (hasRowReference) {
        // A no-reference signal may join a referenced row only when the stored
        // source evidence links the same app's notification/accessibility pair.
        // Amount + time + a single candidate are not sufficient: legitimate
        // same-amount payments can arrive seconds apart from the same app.
        if (_within(eventTime, rowTime, _referenceCorrelationWindow) &&
            _hasStrongSignalLink(entry, event)) {
          rows.add(<String, dynamic>{'key': key, 'entry': entry});
        }
        continue;
      }
      if (!_within(eventTime, rowTime, _signalCorrelationWindow)) continue;
      if (!_hasStrongSignalLink(entry, event)) continue;
      rows.add(<String, dynamic>{'key': key, 'entry': entry});
    }
    return rows;
  }

  static bool _tightCrossAppCluster(
    List<Map<String, dynamic>> candidates,
  ) {
    if (candidates.length < 2) return false;
    final times = <DateTime>[];
    final apps = <String>{};
    for (final candidate in candidates) {
      final entry = candidate['entry'] as Map<String, dynamic>;
      final time = _storedTime(entry);
      if (time == null) return false;
      times.add(time);
      final knownApps = _storedStrings(entry, 'source_apps');
      final appKey = knownApps.isNotEmpty
          ? knownApps.first
          : (entry['app'] ?? 'unknown').toString().trim().toLowerCase();
      if (appKey.isEmpty || !apps.add(appKey)) return false;
    }
    times.sort();
    return times.last.difference(times.first) <= const Duration(seconds: 6);
  }

  static Duration _distanceToEvent(Map<String, dynamic> candidate, PaymentEvent event) {
    final time = _storedTime(candidate['entry'] as Map<String, dynamic>);
    if (time == null) return const Duration(days: 36500);
    final sourceTime = _eventTime(event);
    return sourceTime.isBefore(time)
        ? time.difference(sourceTime)
        : sourceTime.difference(time);
  }

  static Map<String, dynamic>? _bestUnambiguousCandidate(
    List<Map<String, dynamic>> candidates,
    PaymentEvent event,
  ) {
    if (candidates.isEmpty) return null;
    if (candidates.length == 1) return candidates.single;
    final sorted = List<Map<String, dynamic>>.from(candidates)
      ..sort((a, b) => _distanceToEvent(a, event)
          .compareTo(_distanceToEvent(b, event)));
    final closest = _distanceToEvent(sorted[0], event);
    final next = _distanceToEvent(sorted[1], event);
    // If two equally plausible rows exist, leave them visible for review.
    // A clear nearest timestamp may safely link a delayed bank SMS to one row.
    if (next - closest >= const Duration(seconds: 8)) return sorted.first;
    return null;
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
    var linkedToExisting = false;
    final sourceIdentityKey = _sourceIdentityKey(prefix, event);
    final sourceCanonicalKey = sourceIdentityKey == null
        ? null
        : await _resolveCanonicalKey(prefs, sourceIdentityKey);
    var sourceIdentityConflict = false;
    if (sourceCanonicalKey != null) {
      final sourceEntry = _decodeEntry(prefs.getString(sourceCanonicalKey));
      if (sourceEntry != null && _matchesSourceEvent(sourceEntry, event)) {
        final status = (sourceEntry['status'] ?? '').toString().toUpperCase();
        if (event.isMerchantConfirmed ||
            event.detectionSource.contains(':pending_review_reminder')) {
          canonicalKey = sourceCanonicalKey;
          existing = sourceEntry;
          linkedToExisting = true;
        } else {
          if (reference != null &&
              (sourceEntry['reference_id'] ?? '').toString().trim().isEmpty) {
            await _attachReferenceToSourceRow(
              prefs,
              prefix,
              sourceCanonicalKey,
              sourceEntry,
              event,
            );
          }
          if (incomingKey != sourceCanonicalKey) {
            await _writeAlias(
              prefs,
              incomingKey,
              sourceCanonicalKey,
              reference: reference,
              replaceExisting: true,
            );
          }
          if (status == 'REJECTED' || status == 'CONFLICT_REVIEW') {
            return false;
          }
          return false;
        }
      } else {
        // A reused notification key with different money/reference data is
        // not a replay. Keep it separate and do not merge it by amount/time.
        sourceIdentityConflict = true;
      }
    }

    if (existing == null && !sourceIdentityConflict) {
      final candidates = await _findCorrelatedRows(
        prefs,
        prefix,
        event,
        incomingKey: incomingKey,
      );
      // If one UTR arrives after the PhonePe and UPI-app copies of the same
      // alert, collapse only a tightly timed cluster from distinct source apps.
      // Otherwise link a single candidate or an unambiguous nearest candidate.
      Map<String, dynamic>? selected;
      List<Map<String, dynamic>> cluster = <Map<String, dynamic>>[];
      if (reference != null && _tightCrossAppCluster(candidates)) {
        final preferred = candidates.firstWhere(
          (candidate) {
            final entry = candidate['entry'] as Map<String, dynamic>;
            return (entry['app'] ?? '').toString().trim().toLowerCase() !=
                'upi app';
          },
          orElse: () => candidates.first,
        );
        cluster = <Map<String, dynamic>>[
          preferred,
          ...candidates.where((candidate) => !identical(candidate, preferred)),
        ];
        selected = preferred;
      } else {
        selected = reference != null
            ? _bestUnambiguousCandidate(candidates, event)
            : (candidates.length == 1 ? candidates.single : null);
        if (selected != null) cluster = <Map<String, dynamic>>[selected];
      }
      if (selected != null) {
        linkedToExisting = true;
        canonicalKey = selected['key'] as String;
        existing = Map<String, dynamic>.from(
          selected['entry'] as Map<String, dynamic>,
        );
        // Fold tightly correlated source rows into the chosen canonical row.
        for (final candidate in cluster.skip(1)) {
          final otherKey = candidate['key'] as String;
          final other = candidate['entry'] as Map<String, dynamic>;
          final mergedSignals = <String, dynamic>{
            ...existing!,
            'source_apps': <String>{
              ..._storedStrings(existing!, 'source_apps'),
              ..._storedStrings(other, 'source_apps'),
            }.toList(),
            'source_channels': <String>{
              ..._storedStrings(existing!, 'source_channels'),
              ..._storedStrings(other, 'source_channels'),
            }.toList(),
            'signal_signatures': <String>{
              ..._storedStrings(existing!, 'signal_signatures'),
              ..._storedStrings(other, 'signal_signatures'),
            }.take(12).toList(),
            'source_signals': <Map<String, dynamic>>[
              if (existing!['source_signals'] is List)
                ...(existing!['source_signals'] as List)
                    .whereType<Map>()
                    .map((item) => Map<String, dynamic>.from(item)),
              if (other['source_signals'] is List)
                ...(other['source_signals'] as List)
                    .whereType<Map>()
                    .map((item) => Map<String, dynamic>.from(item)),
            ].toSet().toList(),
            'status': existing!['status'] == 'CONFIRMED' ||
                    other['status'] == 'CONFIRMED'
                ? 'CONFIRMED'
                : (existing!['status'] ?? other['status'] ?? 'PENDING_CONFIRMATION'),
            'merchant_confirmed': existing!['merchant_confirmed'] == true ||
                other['merchant_confirmed'] == true,
            'verified': false,
            'payer_match_hash': existing!['payer_match_hash'] ??
                other['payer_match_hash'],
          };
          existing = mergedSignals;
          await prefs.setString(canonicalKey, jsonEncode(existing));
          await _writeAlias(prefs, otherKey, canonicalKey, replaceExisting: true);
        }
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
    if (oldStatus == 'CONFIRMED' && !event.isMerchantConfirmed && !linkedToExisting) {
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
      'detected_at': event.detectionSource.contains(':pending_review_reminder')
          ? event.timestamp.toIso8601String()
          : (base['detected_at'] ?? event.timestamp.toIso8601String()),
      'app': (base['app']?.toString().isNotEmpty ?? false) &&
              (base['app']?.toString().trim().toLowerCase() != 'upi app' ||
                  event.appDisplayName == 'UPI App')
          ? base['app']
          : event.appDisplayName,
       // High-confidence detector decisions are accepted automatically, but
       // remain distinct from explicit merchant confirmation.
       'status': event.isMerchantConfirmed
           ? 'CONFIRMED'
           : event.decision == PaymentDecision.confirmed
               ? 'AUTO_ACCEPTED'
               : (oldStatus.isNotEmpty ? oldStatus : 'PENDING_CONFIRMATION'),
      'merchant_confirmed':
          event.isMerchantConfirmed || base['merchant_confirmed'] == true,
      'confirmation_mode': event.isMerchantConfirmed
          ? 'merchant'
          : event.decision == PaymentDecision.confirmed
              ? 'automatic'
              : (base['confirmation_mode'] ?? 'pending_review'),
      'confidence_score': event.confidenceScore,
      // A locally observed notification is never bank-verified.
      'verified': false,
      if (reference != null) 'reference_id': reference,
      if ((base['reference_id'] ?? '').toString().isNotEmpty)
        'reference_id': base['reference_id'],
      'direction': _historyDirection(event) == 'unknown'
          ? (base['direction'] ?? 'unknown')
          : _historyDirection(event),
      if (event.sourceEventFingerprint != null)
        'source_event_fingerprint': event.sourceEventFingerprint,
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
    if (sourceIdentityKey != null && !sourceIdentityConflict) {
      final existingSourceTarget =
          await _resolveCanonicalKey(prefs, sourceIdentityKey);
      if (existingSourceTarget == null ||
          existingSourceTarget == canonicalKey) {
        await _writeAlias(
          prefs,
          sourceIdentityKey,
          canonicalKey,
          reference: reference,
          replaceExisting: true,
        );
      }
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
    final incomingKey = '${_userPrefix(userId)}$fingerprint';
    final key = await _resolveCanonicalKey(prefs, incomingKey) ?? incomingKey;
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
    if (incomingKey != key) {
      await _writeAlias(prefs, incomingKey, key, reference: event.normalizedReferenceId);
    }
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
