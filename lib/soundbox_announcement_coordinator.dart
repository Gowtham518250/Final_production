import 'dart:async';

import 'payment_event.dart';

/// In-app TTS for one spoken receipt per real transfer.
///
/// This is not a hardware sound box. Retail Mind speaks from the phone.
/// A short hold lets the bank SMS/UTR join the first GPay/PhonePe alert
/// so the shop hears one accurate "Payment received" line.
class SoundboxAnnouncementCoordinator<TUi> {
  SoundboxAnnouncementCoordinator({
    required void Function(PaymentEvent event, TUi ui) speak,
    required Duration Function() holdWindow,
    SoundboxScheduler? schedule,
  }) : _speak = speak,
       _holdWindow = holdWindow,
       _schedule =
           schedule ??
           ((duration, callback) {
             final timer = Timer(duration, callback);
             return timer.cancel;
           });

  final void Function(PaymentEvent event, TUi ui) _speak;
  final Duration Function() _holdWindow;
  final SoundboxScheduler _schedule;

  _HeldSoundboxReceipt<TUi>? _held;
  // Track recently spoken payments to catch late-arriving SMS echoes
  final Map<String, DateTime> _recentlySpoken = {};
  final List<PaymentEvent> _recentlySpokenEvents = [];
  static const Duration _lateEchoWindow = Duration(seconds: 12);

  /// Returns true when voice is deferred or suppressed so duplicate alerts are avoided.
  bool notePrimary(PaymentEvent event, TUi ui) {
    // Clean up old entries
    final now = DateTime.now();
    _recentlySpoken.removeWhere((_, timestamp) =>
        now.difference(timestamp) > _lateEchoWindow);
    _recentlySpokenEvents.removeWhere((e) {
      final t = _recentlySpoken[e.id];
      return t == null || now.difference(t) > _lateEchoWindow;
    });
    // Safety cap: prevent unbounded growth in extreme high-volume scenarios
    while (_recentlySpokenEvents.length > 50) {
      _recentlySpokenEvents.removeAt(0);
    }

    // Check if this incoming payment is an echo of a payment already spoken recently
    if (wasRecentlySpoken(event.id) || _isEchoOfRecentlySpoken(event)) {
      _recentlySpoken[event.id] = now;
      return true; // Suppress duplicate speech for already-announced payment
    }

    // A second channel reporting the SAME payment (e.g., bank SMS while
    // the app notification is still held) must enrich the held receipt,
    // not flush it: checking this BEFORE _shouldHold ensures SMS with UTR
    // properly enriches and speaks once, instead of flushing and speaking twice.
    if (_held != null && _held!.event.id != event.id) {
      if (_isEchoOfHeld(event)) {
        final previous = _held!;
        final mergedEvent = enrich(previous.event, event);
        final mergedUi = previous.ui;
        previous.cancel();
        _held = null;
        _recentlySpoken[mergedEvent.id] = now;
        _recentlySpoken[event.id] = now;
        _recentlySpoken[previous.event.id] = now;
        _recentlySpokenEvents.add(mergedEvent);
        _speak(mergedEvent, mergedUi);
        return true;
      }
      _flushHeld();
    }

    if (!_shouldHold(event)) {
      _flushHeld();
      _recentlySpoken[event.id] = now;
      _recentlySpokenEvents.add(event);
      return false;
    }

    _held?.cancel();
    late _HeldSoundboxReceipt<TUi> held;
    held = _HeldSoundboxReceipt<TUi>(
      event: event,
      ui: ui,
      cancel: _schedule(_holdWindow(), () {
        if (!identical(_held, held)) return;
        _held = null;
        _recentlySpoken[held.event.id] = DateTime.now();
        _recentlySpokenEvents.add(held.event);
        _speak(held.event, held.ui);
      }),
    );
    _held = held;
    return true;
  }

  /// True when [event] looks like another channel's echo of the currently
  /// held payment: same amount and compatible direction, with non-conflicting identity.
  bool _isEchoOfHeld(PaymentEvent event) {
    final held = _held;
    if (held == null) return false;
    final primary = held.event;
    return _areEventsEchoPair(primary, event);
  }

  bool _isEchoOfRecentlySpoken(PaymentEvent event) {
    for (final spoken in _recentlySpokenEvents) {
      if (_areEventsEchoPair(spoken, event)) {
        return true;
      }
    }
    return false;
  }

  static bool _areEventsEchoPair(PaymentEvent a, PaymentEvent b) {
    if ((a.amount - b.amount).abs() >= 0.01) return false;

    // Must be across channels (e.g., Notification vs SMS vs Accessibility)
    if (_originOf(a.detectionSource) == _originOf(b.detectionSource)) {
      return false;
    }

    // Direction must be compatible
    final aDir = a.direction;
    final bDir = b.direction;
    if (aDir != bDir &&
        aDir != PaymentTransactionDirection.unknown &&
        bDir != PaymentTransactionDirection.unknown) {
      return false;
    }

    // Conflicting accounts means different accounts
    final aAccount = _norm(a.accountSuffix);
    final bAccount = _norm(b.accountSuffix);
    if (aAccount != null && bAccount != null && aAccount != bAccount) {
      return false;
    }

    // Conflicting payer names means different payers
    final aPayer = _norm(a.payerName);
    final bPayer = _norm(b.payerName);
    if (aPayer != null &&
        bPayer != null &&
        aPayer != bPayer &&
        !aPayer.contains(bPayer) &&
        !bPayer.contains(aPayer)) {
      return false;
    }

    // Conflicting references means different transactions
    final aRef = a.normalizedReferenceId;
    final bRef = b.normalizedReferenceId;
    if (aRef != null && bRef != null && aRef != bRef) {
      return false;
    }

    return true;
  }

  static String? _norm(String? value) {
    final t = value?.trim().toLowerCase();
    return (t == null || t.isEmpty) ? null : t;
  }

  static String _originOf(String source) {
    final value = source.toLowerCase();
    if (value.startsWith('notification')) return 'notification';
    if (value.startsWith('sms')) return 'sms';
    if (value.startsWith('accessibility')) return 'accessibility';
    if (value.startsWith('truecaller')) return 'truecaller';
    return value.split(':').first;
  }

  /// A later SMS/app echo of [primary] arrived. Speak once with any new UTR.
  void noteEcho(PaymentEvent primary, PaymentEvent echo) {
    final held = _held;
    if (held == null || held.event.id != primary.id) return;
    held.cancel();
    _held = null;
    final merged = enrich(held.event, echo);
    _speak(merged, held.ui);
  }

  /// Allow manual flush of held payment when SMS arrives late
  void flushAndSpeakHeld() {
    _flushHeld();
  }

  void reset() {
    _held?.cancel();
    _held = null;
  }

  static PaymentEvent enrich(PaymentEvent primary, PaymentEvent echo) {
    return primary.copyWith(
      referenceId: primary.normalizedReferenceId ?? echo.referenceId,
      payerName: _nonEmpty(primary.payerName) ?? echo.payerName,
      accountSuffix: _nonEmpty(primary.accountSuffix) ?? echo.accountSuffix,
      bankName: _nonEmpty(primary.bankName) ?? echo.bankName,
      vpa: _nonEmpty(primary.vpa) ?? echo.vpa,
    );
  }

  bool _shouldHold(PaymentEvent event) {
    if (_holdWindow() <= Duration.zero) return false;
    if (event.isFailed ||
        event.isDuplicate ||
        event.hasReferenceConflict ||
        event.nativeAnnouncementHandled) {
      return false;
    }
    if (event.direction == PaymentTransactionDirection.outgoingDebit) {
      return false;
    }
    if (event.direction != PaymentTransactionDirection.incomingCredit) {
      return false;
    }
    if (event.normalizedReferenceId != null) return false;
    return _holdableOrigin(event.detectionSource);
  }

  static bool _holdableOrigin(String source) {
    final value = source.toLowerCase();
    return value.startsWith('notification') ||
        value.startsWith('sms') ||
        value.startsWith('accessibility') ||
        value.startsWith('truecaller');
  }

  void _flushHeld() {
    final held = _held;
    if (held == null) return;
    held.cancel();
    _held = null;
    _recentlySpoken[held.event.id] = DateTime.now();
    _recentlySpokenEvents.add(held.event);
    _speak(held.event, held.ui);
  }

  /// Check if this payment was recently spoken (for late SMS echo detection)
  bool wasRecentlySpoken(String eventId) {
    final timestamp = _recentlySpoken[eventId];
    if (timestamp == null) return false;
    final age = DateTime.now().difference(timestamp);
    return age <= _lateEchoWindow;
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return value;
  }
}

typedef SoundboxScheduler =
    void Function() Function(Duration duration, void Function() callback);

class _HeldSoundboxReceipt<TUi> {
  _HeldSoundboxReceipt({
    required this.event,
    required this.ui,
    required this.cancel,
  });

  final PaymentEvent event;
  final TUi ui;
  final void Function() cancel;
}
