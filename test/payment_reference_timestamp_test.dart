import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:retail_mind/online_payment_history_service.dart';
import 'package:retail_mind/payment_detection_service.dart';
import 'package:retail_mind/payment_event.dart';

void main() {
  group('payment reference extraction and source timestamps', () {
    test('prefers the explicit UTR over an earlier app transaction ID', () {
      const text =
          'PhonePe Transaction ID: T2610261622143624563797\n'
          'UTR: 404446326411';

      expect(
        PaymentDetectionService.debugExtractReferenceId(text),
        '404446326411',
      );
    });

    test('keeps a long app transaction ID when no UTR is present', () {
      const text = 'PhonePe Transaction ID: T2610261622143624563797';

      expect(
        PaymentDetectionService.debugExtractReferenceId(text),
        'T2610261622143624563797',
      );
    });

    test('preserves source timestamp when the event crosses isolates', () {
      final sourceTime = DateTime(2026, 10, 26, 16, 22);
      final processedTime = DateTime(2026, 10, 26, 18, 15);
      final event = PaymentEvent(
        amount: 5,
        timestamp: processedTime,
        sourceTimestamp: sourceTime,
        app: PaymentApp.phonePe,
        referenceId: '404446326411',
        rawText: 'Payment received ₹5',
        direction: PaymentTransactionDirection.incomingCredit,
      );

      final restored = PaymentEvent.fromJson(event.toJson());

      expect(restored.timestamp, processedTime);
      expect(restored.sourceTimestamp, sourceTime);
      expect(restored.fingerprint, event.fingerprint);
    });

    test('history displays source time but keeps processing time for cooldowns', () async {
      SharedPreferences.setMockInitialValues({'user_id': 72});

      final sourceTime = DateTime(2026, 10, 26, 16, 22);
      final processedTime = DateTime(2026, 10, 26, 18, 15);
      final event = PaymentEvent(
        amount: 5,
        timestamp: processedTime,
        sourceTimestamp: sourceTime,
        app: PaymentApp.phonePe,
        referenceId: '404446326411',
        rawText: 'Money received ₹5',
        decision: PaymentDecision.confirmed,
        verificationStatus: PaymentVerificationStatus.merchantConfirmed,
        direction: PaymentTransactionDirection.incomingCredit,
      );

      expect(await OnlinePaymentHistoryService.recordIncomingPayment(event), isTrue);

      final rows = await OnlinePaymentHistoryService.load();
      expect(rows, hasLength(1));
      expect(rows.single['timestamp'], sourceTime.toIso8601String());
      expect(rows.single['detected_at'], processedTime.toIso8601String());
      expect(rows.single['reference_id'], '404446326411');
    });
  });
}
