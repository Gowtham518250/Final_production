import 'package:flutter_test/flutter_test.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:retail_mind/payment_detection_service.dart';
import 'package:retail_mind/payment_event.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<PaymentEvent>> run(List<ServiceNotificationEvent> inputs) async {
    final service = PaymentDetectionService();
    service.debugResetTransientDetectionState();
    service.clearBill();
    final events = <PaymentEvent>[];
    final sub = service.onPaymentDetected.listen(events.add);
    for (final e in inputs) {
      service.debugHandleNotification(e);
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await sub.cancel();
    return events;
  }

  group('one payment must produce one alert', () {
    test('our own notifications are never re-read as payments', () async {
      final events = await run([
        ServiceNotificationEvent(
          packageName: 'com.retailmind.app',
          title: 'Payment Received',
          content: 'Credit: ₹500 via PhonePe',
        ),
        ServiceNotificationEvent(
          packageName: 'com.retailmind.app',
          title: 'Payment Detected',
          content: 'Credit: ₹500 via PhonePe — verify before recording.',
        ),
      ]);
      expect(events, isEmpty);
    });

    test('same credit reported twice by different wording is one event', () async {
      final events = await run([
        ServiceNotificationEvent(
          packageName: 'com.phonepe.app',
          title: 'PhonePe',
          content: 'Payment received ₹500 credited to your account',
        ),
        ServiceNotificationEvent(
          packageName: 'com.phonepe.app',
          title: 'PhonePe',
          content: 'Money received ₹500 in your account',
        ),
      ]);
      expect(events, hasLength(1));
      expect(events.single.amount, 500);
    });

    test('different payers with the same amount stay separate', () async {
      final events = await run([
        ServiceNotificationEvent(
          packageName: 'com.phonepe.app',
          title: 'PhonePe',
          content: 'Anna Devi has sent ₹500 to you',
        ),
        ServiceNotificationEvent(
          packageName: 'com.phonepe.app',
          title: 'PhonePe',
          content: 'Ravi Kumar has sent ₹500 to you',
        ),
      ]);
      expect(events, hasLength(2));
    });
  });
}
