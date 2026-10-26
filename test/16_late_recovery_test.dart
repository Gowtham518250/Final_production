import 'package:flutter_test/flutter_test.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:retail_mind/payment_detection_service.dart';
import 'package:retail_mind/payment_event.dart';

/// Recovered events keep their current detection timestamp for deduplication,
/// but retain the original source time for the user-facing late alert.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String keyPostedAgo(Duration ago, String suffix) {
    final millis = DateTime.now().subtract(ago).millisecondsSinceEpoch;
    return 'com.phonepe.app|42|$millis|$suffix';
  }

  group('postedAtFromEventKey', () {
    test('reads post time from a native notification key', () {
      final posted = PaymentDetectionService.postedAtFromEventKey(
        keyPostedAgo(const Duration(minutes: 10), 'abc'),
      );
      expect(posted, isNotNull);
      expect(
        DateTime.now().difference(posted!).inMinutes,
        greaterThanOrEqualTo(9),
      );
    });

    test('rejects missing and malformed keys', () {
      expect(PaymentDetectionService.postedAtFromEventKey(null), isNull);
      expect(PaymentDetectionService.postedAtFromEventKey('garbage'), isNull);
      expect(
        PaymentDetectionService.postedAtFromEventKey('pkg|1|not-a-time|hash'),
        isNull,
      );
    });

    test('clamps future post time to now', () {
      final future = DateTime.now()
          .add(const Duration(hours: 5))
          .millisecondsSinceEpoch;
      final posted = PaymentDetectionService.postedAtFromEventKey(
        'pkg|1|$future|hash',
      );
      expect(posted, isNotNull);
      expect(
        posted!.isAfter(DateTime.now().add(const Duration(seconds: 1))),
        isFalse,
      );
    });
  });

  group('late event tracking', () {
    test('notification replayed hours later is marked late without backdating event', () async {
      final service = PaymentDetectionService();
      service.debugResetTransientDetectionState();
      final events = <PaymentEvent>[];
      final subscription = service.onPaymentDetected.listen(events.add);

      service.debugHandleNotification(
        ServiceNotificationEvent(
          packageName: 'com.phonepe.app',
          title: 'PhonePe',
          content: 'UPI credit ₹11 received from Anita',
          eventKey: keyPostedAgo(const Duration(hours: 6), 'late1'),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(events, hasLength(1));
      final lateAt = service.originalTimeIfLate(events.single.id);
      expect(lateAt, isNotNull);
      expect(
        DateTime.now().difference(lateAt!).inHours,
        greaterThanOrEqualTo(5),
      );
      expect(
        DateTime.now().difference(events.single.timestamp).inMinutes,
        lessThan(1),
      );
      await subscription.cancel();
    });

    test('live notification is not marked late', () async {
      final service = PaymentDetectionService();
      service.debugResetTransientDetectionState();
      final events = <PaymentEvent>[];
      final subscription = service.onPaymentDetected.listen(events.add);

      service.debugHandleNotification(
        ServiceNotificationEvent(
          packageName: 'com.phonepe.app',
          title: 'PhonePe',
          content: 'UPI credit ₹13 received',
          eventKey: keyPostedAgo(const Duration(seconds: 3), 'live1'),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(events, hasLength(1));
      expect(service.originalTimeIfLate(events.single.id), isNull);
      await subscription.cancel();
    });

    test('queued SMS with old receive time is marked late', () async {
      final service = PaymentDetectionService();
      service.debugResetTransientDetectionState();
      final events = <PaymentEvent>[];
      final subscription = service.onPaymentDetected.listen(events.add);

      service.handleSms(
        'VM-PHONEPE',
        'Your account is credited with Rs.17. UTR 223456789012',
        receivedAt: DateTime.now().subtract(const Duration(hours: 3)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(events, hasLength(1));
      expect(service.originalTimeIfLate(events.single.id), isNotNull);
      await subscription.cancel();
    });

    test('live SMS without queued receive time is not marked late', () async {
      final service = PaymentDetectionService();
      service.debugResetTransientDetectionState();
      final events = <PaymentEvent>[];
      final subscription = service.onPaymentDetected.listen(events.add);

      service.handleSms(
        'VM-PHONEPE',
        'Your UPI credit of Rs.19 was received in your account',
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(events, hasLength(1));
      expect(service.originalTimeIfLate(events.single.id), isNull);
      await subscription.cancel();
    });
  });
}
