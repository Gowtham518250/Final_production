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
  static const Duration _lateEchoWindow = Duration(seconds: 10);

  /// Returns true when voice is deferred so a later SMS/UTR can join this receipt.
  bool notePrimary(PaymentEvent event, TUi ui) {
    // Clean up old entries
    final now = DateTime.now();
    _recentlySpoken.removeWhere((_, timestamp) =>
        now.difference(timestamp) > _lateEchoWindow);

    if (!_shouldHold(event)) {
      _flushHeld();
      // Still track spoken events even when not held
      _recentlySpoken[event.id] = now;
      return false;
    }
    if (_held != null && _held!.event.id != event.id) {
      // A second channel reporting the SAME payment (e.g., bank SMS while
      // the app notification is still held) must enrich the held receipt,
      // not flush it: flushing spoke version one and the new hold then
      // spoke version two — the same payment announced twice.
      if (_isEchoOfHeld(event)) {
        final previous = _held!;
        final mergedEvent = enrich(previous.event, event);
        // Keep the primary's UI state: merged event retains the primary's
        // classification/direction while gaining the echo's identity fields.
        final mergedUi = previous.ui;
        previous.cancel();
        late _HeldSoundboxReceipt<TUi> renewed;
        renewed = _HeldSoundboxReceipt<TUi>(
          event: mergedEvent,
          ui: mergedUi,
          cancel: _schedule(_holdWindow(), () {
            if (!identical(_held, renewed)) return;
            _held = null;
            _recentlySpoken[mergedEvent.id] = DateTime.now();
            _speak(mergedEvent, mergedUi);
          }),
        );
        _held = renewed;
        return true;
      }
      _flushHeld();
    }
    _held?.cancel();
    late _HeldSoundboxReceipt<TUi> held;
    held = _HeldSoundboxReceipt<TUi>(
      event: event,
      ui: ui,
      cancel: _schedule(_holdWindow(), () {
        if (!identical(_held, held)) return;
        _held = null;
        _recentlySpoken[held.event.id] = now;
        _speak(held.event, held.ui);
      }),
    );
    _held = held;
    return true;
  }

  /// True when [event] looks like another channel's echo of the currently
  /// held payment: same amount and compatible direction, with at least one
  /// shared identity (account/payer). STRICT: 10-second window, cross-channel only.
  bool _isEchoOfHeld(PaymentEvent event) {
    final held = _held;
    if (held == null) return false;
    final primary = held.event;
    if ((primary.amount - event.amount).abs() >= 0.01) return false;

    if (_originOf(primary.detectionSource) ==
        _originOf(event.detectionSource)) {
      return false;
    }

    // STRICT: Require at least one shared identity (account or payer) to merge.
    final primaryAccount = _norm(primary.accountSuffix);
    final eventAccount = _norm(event.accountSuffix);
    final primaryPayer = _norm(primary.payerName);
    final eventPayer = _norm(event.payerName);
    final accountMatches = (primaryAccount != null &&
        eventAccount != null &&
        primaryAccount == eventAccount);
    final payerMatches = (primaryPayer != null &&
        eventPayer != null &&
        (primaryPayer == eventPayer ||
            primaryPayer.contains(eventPayer) ||
            eventPayer.contains(primaryPayer)));
    if (!accountMatches && !payerMatches) {
      return false;
    }

    final primaryDir = primary.direction;
    final eventDir = event.direction;
    if (primaryDir != eventDir &&
        primaryDir != PaymentTransactionDirection.unknown &&
        eventDir != PaymentTransactionDirection.unknown) {
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
