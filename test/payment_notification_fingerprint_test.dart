import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/payment_detection_service.dart';

void main() {
  group('Native notification payload replay identity', () {
    const payload = 'Payment received INR 500 from Ravi';
    const packageName = 'com.phonepe.app';
    const sender = 'Payment received';

    test('same native notification slot coalesces an exact repost', () {
      final first = PaymentDetectionService.debugNotificationPayloadFingerprint(
        packageName: packageName,
        sender: sender,
        payload: payload,
        eventKey: 'com.phonepe.app|42|1794000000000|hash-a',
      );
      final repost = PaymentDetectionService.debugNotificationPayloadFingerprint(
        packageName: packageName,
        sender: sender,
        payload: payload,
        eventKey: 'com.phonepe.app|42|1794000000000|hash-b',
      );

      expect(repost, first);
    });

    test('separate native notification IDs remain distinct with identical text', () {
      final first = PaymentDetectionService.debugNotificationPayloadFingerprint(
        packageName: packageName,
        sender: sender,
        payload: payload,
        eventKey: 'com.phonepe.app|42|1794000000000|hash-a',
      );
      final second = PaymentDetectionService.debugNotificationPayloadFingerprint(
        packageName: packageName,
        sender: sender,
        payload: payload,
        eventKey: 'com.phonepe.app|43|1794000000001|hash-a',
      );

      expect(second, isNot(first));
    });

    test('a changed payload in the same notification slot is processed as an update', () {
      final pending = PaymentDetectionService.debugNotificationPayloadFingerprint(
        packageName: packageName,
        sender: sender,
        payload: 'Payment pending INR 500',
        eventKey: 'com.phonepe.app|42|1794000000000|hash-a',
      );
      final completed = PaymentDetectionService.debugNotificationPayloadFingerprint(
        packageName: packageName,
        sender: sender,
        payload: 'Payment received INR 500 from Ravi',
        eventKey: 'com.phonepe.app|42|1794000000000|hash-b',
      );

      expect(completed, isNot(pending));
    });

    test('events without a native key retain the content-based fallback', () {
      final first = PaymentDetectionService.debugNotificationPayloadFingerprint(
        packageName: packageName,
        sender: sender,
        payload: '  PAYMENT   RECEIVED INR 500 ',
      );
      final repost = PaymentDetectionService.debugNotificationPayloadFingerprint(
        packageName: packageName,
        sender: sender,
        payload: 'payment received inr 500',
      );

      expect(repost, first);
    });
  });
}
