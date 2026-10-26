import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:retail_mind/payment_detection_service.dart';
import 'package:retail_mind/payment_alert_deduplicator.dart';
import 'package:retail_mind/payment_event.dart';

void main() {
  group('PaymentAlertDeduplicator', () {
    final now = DateTime(2026, 10, 26, 11, 0);

    PaymentEvent event({
      String? id,
      String? referenceId,
      String? payerName,
      String rawText = 'Anna sent ₹500 to you',
      PaymentApp app = PaymentApp.phonePe,
      PaymentTransactionDirection direction =
          PaymentTransactionDirection.incomingCredit,
      bool merchantConfirmed = false,
      bool conflict = false,
      double amount = 500,
    }) {
      return PaymentEvent(
        id: id,
        amount: amount,
        timestamp: now,
        app: app,
        referenceId: referenceId,
        payerName: payerName,
        rawText: rawText,
        direction: direction,
        hasReferenceConflict: conflict,
        decision: merchantConfirmed
            ? PaymentDecision.confirmed
            : PaymentDecision.likely,
        verificationStatus: merchantConfirmed
            ? PaymentVerificationStatus.merchantConfirmed
            : PaymentVerificationStatus.unverified,
      );
    }

    test('coalesces the same UTR and amount across detection sources', () {
      final deduper = PaymentAlertDeduplicator();
      final first = event(
        id: 'phonepe-event',
        referenceId: '123456789012',
        rawText: 'PhonePe payment received ₹500 UTR 123456789012',
      );
      final second = event(
        id: 'accessibility-event',
        referenceId: '123456789012',
        app: PaymentApp.unknown,
        rawText: 'Payment credited ₹500 reference 123456789012',
      );

      expect(deduper.shouldSuppress(first, now: now), isFalse);
      expect(
        deduper.shouldSuppress(
          second,
          now: now.add(const Duration(seconds: 5)),
        ),
        isTrue,
      );
    });

    test('coalesces cross-source alerts when payer, amount and direction match', () {
      final deduper = PaymentAlertDeduplicator();
      final first = event(
        id: 'phonepe-event',
        payerName: 'Anna',
        rawText: 'Anna sent ₹500 to you',
      );
      final second = event(
        id: 'generic-upi-event',
        payerName: 'anna',
        app: PaymentApp.unknown,
        rawText: 'You received ₹500 from Anna through UPI',
      );

      expect(deduper.shouldSuppress(first, now: now), isFalse);
      expect(
        deduper.shouldSuppress(
          second,
          now: now.add(const Duration(seconds: 2)),
        ),
        isTrue,
      );
    });

    test('does not coalesce equal amounts from different named payers', () {
      final deduper = PaymentAlertDeduplicator();
      expect(
        deduper.shouldSuppress(event(payerName: 'Anna'), now: now),
        isFalse,
      );
      expect(
        deduper.shouldSuppress(
          event(payerName: 'Rahul', app: PaymentApp.unknown),
          now: now.add(const Duration(seconds: 2)),
        ),
        isFalse,
      );
    });

    test('does not use amount and time alone to merge unreferenced payments', () {
      final deduper = PaymentAlertDeduplicator();
      expect(
        deduper.shouldSuppress(
          event(rawText: '₹500 received in your account'),
          now: now,
        ),
        isFalse,
      );
      expect(
        deduper.shouldSuppress(
          event(
            app: PaymentApp.unknown,
            rawText: '₹500 credited to your account',
          ),
          now: now.add(const Duration(seconds: 1)),
        ),
        isFalse,
      );
    });

    test('direction and amount differences remain independently reviewable', () {
      final deduper = PaymentAlertDeduplicator();
      expect(
        deduper.shouldSuppress(
          event(referenceId: '123456789012', amount: 500),
          now: now,
        ),
        isFalse,
      );
      expect(
        deduper.shouldSuppress(
          event(
            referenceId: '123456789012',
            amount: 700,
            rawText: '₹700 debited from your account',
            direction: PaymentTransactionDirection.outgoingDebit,
          ),
          now: now.add(const Duration(seconds: 1)),
        ),
        isFalse,
      );
    });

    test('expired fallback window permits a later new alert', () {
      final deduper = PaymentAlertDeduplicator();
      expect(
        deduper.shouldSuppress(event(payerName: 'Anna'), now: now),
        isFalse,
      );
      expect(
        deduper.shouldSuppress(
          event(payerName: 'Anna', app: PaymentApp.unknown),
          now: now.add(const Duration(minutes: 16)),
        ),
        isFalse,
      );
    });

    test('coalesces no-reference alert bursts for fifteen minutes then allows a reminder', () {
      final deduper = PaymentAlertDeduplicator();
      expect(
        deduper.shouldSuppress(event(payerName: 'Anna'), now: now),
        isFalse,
      );
      expect(
        deduper.shouldSuppress(
          event(payerName: 'Anna', app: PaymentApp.unknown),
          now: now.add(const Duration(minutes: 10)),
        ),
        isTrue,
      );
      expect(
        deduper.shouldSuppress(
          event(payerName: 'Anna', app: PaymentApp.unknown),
          now: now.add(const Duration(minutes: 16)),
        ),
        isFalse,
      );
    });

    test('reference alert becomes eligible again after six hours', () {
      final deduper = PaymentAlertDeduplicator();
      final first = event(referenceId: '123456789012');
      expect(deduper.shouldSuppress(first, now: now), isFalse);
      expect(
        deduper.shouldSuppress(
          event(referenceId: '123456789012'),
          now: now.add(const Duration(hours: 5)),
        ),
        isTrue,
      );
      expect(
        deduper.shouldSuppress(
          event(referenceId: '123456789012'),
          now: now.add(const Duration(hours: 7)),
        ),
        isFalse,
      );
    });

    test('uses audible notification fallback when voice would not announce a reminder', () {
      final duplicate = event(id: 'old-duplicate')
          .copyWith(isDuplicate: true);
      final conflict = event(id: 'conflicting-payment')
          .copyWith(hasReferenceConflict: true);
      final reminder = event(
        id: 'morning-reminder',
      ).copyWith(
        detectionSource: 'notification:pending_review_reminder',
      );
      final ordinary = event(id: 'ordinary-payment');

      expect(
        PaymentAlertDeduplicator.shouldUseAudibleNotificationFallback(
          duplicate,
          voiceEnabled: true,
        ),
        isTrue,
      );
      expect(
        PaymentAlertDeduplicator.shouldUseAudibleNotificationFallback(
          conflict,
          voiceEnabled: true,
        ),
        isTrue,
      );
      expect(
        PaymentAlertDeduplicator.shouldUseAudibleNotificationFallback(
          reminder,
          voiceEnabled: true,
        ),
        isTrue,
      );
      expect(
        PaymentAlertDeduplicator.shouldUseAudibleNotificationFallback(
          ordinary,
          voiceEnabled: true,
        ),
        isFalse,
      );
      expect(
        PaymentAlertDeduplicator.shouldUseAudibleNotificationFallback(
          ordinary,
          voiceEnabled: false,
        ),
        isTrue,
      );
    });

    test('merchant-confirmed transition is not swallowed by an earlier alert', () {
      final deduper = PaymentAlertDeduplicator();
      expect(
        deduper.shouldSuppress(event(payerName: 'Anna'), now: now),
        isFalse,
      );
      expect(
        deduper.shouldSuppress(
          event(
            payerName: 'Anna',
            merchantConfirmed: true,
          ),
          now: now.add(const Duration(seconds: 10)),
        ),
        isFalse,
      );
    });

    test('reference conflicts are left visible for review', () {
      final deduper = PaymentAlertDeduplicator();
      expect(
        deduper.shouldSuppress(
          event(referenceId: '123456789012'),
          now: now,
        ),
        isFalse,
      );
      expect(
        deduper.shouldSuppress(
          event(
            referenceId: '123456789012',
            conflict: true,
          ),
          now: now.add(const Duration(seconds: 1)),
        ),
        isFalse,
      );
    });

    test('native notification and SHA-based UTR keys survive process restart storage', () async {
      SharedPreferences.setMockInitialValues({});
      final expiry = DateTime.now().add(const Duration(hours: 24));
      await PdsStateStore.saveDedup({
        'notification-event:native-hash': expiry,
        'utr_utr-hash': expiry,
        'utr:legacy-utr-hash': expiry,
        'event_transient': expiry,
      });

      final prefs = await SharedPreferences.getInstance();
      final serialized = prefs.getString('pds_dedup_v1');
      expect(serialized, isNotNull);
      final saved = jsonDecode(serialized!) as Map<String, dynamic>;

      expect(saved.keys, contains('notification-event:native-hash'));
      expect(saved.keys, contains('utr_utr-hash'));
      expect(saved.keys, contains('utr:legacy-utr-hash'));
      expect(saved.keys, isNot(contains('event_transient')));
    });
  });
}
