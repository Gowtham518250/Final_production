import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/payment_event.dart';

void main() {
  group('native payment announcement marker', () {
    test('survives PaymentEvent JSON round trip', () {
      final event = PaymentEvent(
        amount: 250,
        timestamp: DateTime(2026, 10, 27),
        app: PaymentApp.phonePe,
        nativeAnnouncementHandled: true,
      );

      final restored = PaymentEvent.fromJson(event.toJson());

      expect(restored.nativeAnnouncementHandled, isTrue);
      expect(restored.amount, 250);
    });

    test('defaults to false for legacy event payloads', () {
      final event = PaymentEvent.fromJson({
        'amount': 50,
        'timestamp': '2026-10-27T12:00:00.000',
        'app': 'phonePe',
        'decision': 'likely',
      });

      expect(event.nativeAnnouncementHandled, isFalse);
    });
  });
}
