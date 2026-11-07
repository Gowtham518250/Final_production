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

  /// Returns true when voice is deferred so a later SMS/UTR can join this receipt.
  bool notePrimary(PaymentEvent event, TUi ui) {
    if (!_shouldHold(event)) {
      _flushHeld();
      return false;
    }
    if (_held != null && _held!.event.id != event.id) {
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
        _speak(held.event, held.ui);
      }),
    );
    _held = held;
    return true;
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
    _speak(held.event, held.ui);
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
