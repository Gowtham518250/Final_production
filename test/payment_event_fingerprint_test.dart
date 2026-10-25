import 'package:flutter_test/flutter_test.dart';
import '../lib/payment_event.dart';

void main() {
  group('PaymentEvent fingerprint', () {
    test('generates unique IDs for many events created in the same clock tick', () {
      final ids = List.generate(
        100,
        (index) => PaymentEvent(
          amount: 500,
          timestamp: DateTime(2026, 10, 9, 10, 11),
          app: PaymentApp.googlePay,
          rawText: '₹500 credited to your account #$index',
        ).id,
      );

      expect(ids.toSet(), hasLength(ids.length));
    });

    test('does not merge no-reference events into an accounting identity', () {
      final first = PaymentEvent(
        amount: 500,
        timestamp: DateTime(2026, 10, 9, 10, 11),
        app: PaymentApp.googlePay,
        rawText: '₹500 credited to your account',
      );
      final variant = PaymentEvent(
        amount: 500,
        timestamp: DateTime(2026, 10, 9, 10, 14),
        app: PaymentApp.googlePay,
        rawText: '₹500 received',
      );

      // Without a transaction reference, similar amounts/times are only a
      // heuristic and must not collapse two potentially legitimate receipts.
      expect(first.fingerprint, isNot(variant.fingerprint));
      // Voice-only deduplication may stay heuristic because it does not write
      // to the financial ledger.
      expect(first.voiceFingerprint, variant.voiceFingerprint);
    });

    test('does not collide with the same amount and slot on another date', () {
      final today = PaymentEvent(
        amount: 500,
        timestamp: DateTime(2026, 10, 9, 10, 11),
        app: PaymentApp.googlePay,
        rawText: '₹500 credited to your account',
      );
      final tomorrow = PaymentEvent(
        amount: 500,
        timestamp: DateTime(2026, 10, 10, 10, 11),
        app: PaymentApp.googlePay,
        rawText: '₹500 credited to your account',
      );

      expect(today.fingerprint, isNot(tomorrow.fingerprint));
      expect(today.voiceFingerprint, isNot(tomorrow.voiceFingerprint));
    });

    test('keeps native-script credit and debit fingerprints separate', () {
      final credit = PaymentEvent(
        amount: 500,
        timestamp: DateTime(2026, 10, 9, 10, 11),
        app: PaymentApp.googlePay,
        rawText: 'మీ ఖాతాలో ₹500 జమ అయింది',
      );
      final debit = PaymentEvent(
        amount: 500,
        timestamp: DateTime(2026, 10, 9, 10, 11),
        app: PaymentApp.googlePay,
        rawText: 'మీ ఖాతా నుండి ₹500 డెబిట్',
      );

      expect(credit.fingerprint, isNot(debit.fingerprint));
      expect(credit.voiceFingerprint, isNot(debit.voiceFingerprint));
    });

    test('voice fingerprint merges alternate native-script wording', () {
      final first = PaymentEvent(
        amount: 500,
        timestamp: DateTime(2026, 10, 9, 10, 11),
        app: PaymentApp.googlePay,
        rawText: 'మీ ఖాతాలో ₹500 జమ అయింది',
      );
      final differentText = PaymentEvent(
        amount: 500,
        timestamp: DateTime(2026, 10, 9, 10, 11),
        app: PaymentApp.googlePay,
        rawText: 'మీకు ₹500 అందింది',
      );

      // Without a transaction reference, financial identity must remain
      // distinct even when amount, timestamp, and wording are similar.
      expect(first.fingerprint, isNot(differentText.fingerprint));
      // The non-ledger voice heuristic may suppress alternate wording.
      expect(first.voiceFingerprint, differentText.voiceFingerprint);
    });

    test('keeps credit and debit fingerprints separate', () {
      final credit = PaymentEvent(
        amount: 500,
        timestamp: DateTime(2026, 10, 9, 10, 11),
        app: PaymentApp.googlePay,
        rawText: '₹500 credited',
      );
      final debit = PaymentEvent(
        amount: 500,
        timestamp: DateTime(2026, 10, 9, 10, 11),
        app: PaymentApp.googlePay,
        rawText: '₹500 debited',
      );

      expect(credit.fingerprint, isNot(debit.fingerprint));
    });



    test('normalizes reference identity and excludes amount from the key', () {
      final first = PaymentEvent(
        id: 'reference-1',
        amount: 500,
        timestamp: DateTime(2026, 10, 9, 10, 11),
        app: PaymentApp.googlePay,
        referenceId: 'utr-12 34-AB',
        rawText: '₹500 credited to your account',
      );
      final conflictingAmount = PaymentEvent(
        id: 'reference-2',
        amount: 700,
        timestamp: DateTime(2026, 10, 9, 10, 12),
        app: PaymentApp.bankSms,
        referenceId: 'UTR1234AB',
        rawText: '₹700 received',
      );

      expect(first.normalizedReferenceId, 'UTR1234AB');
      expect(first.fingerprint, conflictingAmount.fingerprint);
      expect(first.hasSameReferenceAs(conflictingAmount), isTrue);
      expect(first.hasReferenceConflictWith(conflictingAmount), isTrue);
    });

    test('copyWith increments version and updates revision timestamp', () {
      final original = PaymentEvent(
        id: 'revisioned-event',
        amount: 10,
        timestamp: DateTime(2026, 10, 9, 10),
        app: PaymentApp.phonePe,
        version: 3,
        updatedAt: DateTime(2026, 10, 1),
      );

      final revised = original.copyWith(
        verificationStatus: PaymentVerificationStatus.merchantConfirmed,
        decision: PaymentDecision.confirmed,
      );

      expect(revised.version, 4);
      expect(revised.updatedAt.isAfter(original.updatedAt), isTrue);
      expect(revised.id, original.id);
    });

    test('serializes all fields needed to process a background event', () {
      final event = PaymentEvent(
        id: 'payment-1',
        amount: 250,
        timestamp: DateTime(2026, 10, 9, 10, 11),
        app: PaymentApp.phonePe,
        rawText: '₹250 credited to your account',
        decision: PaymentDecision.confirmed,
        isBillMatch: true,
        hasReferenceConflict: true,
        isPartialPayment: true,
        remainingAmount: 750,
      );

      final restored = PaymentEvent.fromJson(event.toJson());

      expect(restored.id, event.id);
      expect(restored.fingerprint, event.fingerprint);
      expect(restored.rawText, event.rawText);
      expect(restored.decision, event.decision);
      expect(restored.isBillMatch, isTrue);
      expect(restored.hasReferenceConflict, isTrue);
      expect(restored.isPartialPayment, isTrue);
      expect(restored.remainingAmount, 750);
    });
  });
}
