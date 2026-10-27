import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:retail_mind/cross_isolate_payment_announcement_deduplicator.dart';
import 'package:retail_mind/payment_event.dart';

PaymentEvent _event({
  required String id,
  required DateTime timestamp,
  required String source,
  required String rawText,
  required PaymentApp app,
  double amount = 500,
  String? referenceId,
  String? payerName,
  String? accountSuffix,
  PaymentTransactionDirection direction =
      PaymentTransactionDirection.incomingCredit,
}) {
  return PaymentEvent(
    id: id,
    amount: amount,
    timestamp: timestamp,
    app: app,
    referenceId: referenceId,
    payerName: payerName,
    accountSuffix: accountSuffix,
    rawText: rawText,
    detectionSource: source,
    direction: direction,
    decision: PaymentDecision.likely,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('one notification and its SMS echo are announced once without UTR', () async {
    final time = DateTime(2026, 10, 27, 10, 0);
    final notification = _event(
      id: 'notif-1',
      timestamp: time,
      source: 'notification',
      app: PaymentApp.phonePe,
      rawText: 'Payment received ₹500',
    );
    final sms = _event(
      id: 'sms-1',
      timestamp: time.add(const Duration(seconds: 24)),
      source: 'sms',
      app: PaymentApp.bankSms,
      rawText: 'Your account has been credited by INR 500',
    );

    expect(
      await CrossIsolatePaymentAnnouncementDeduplicator.shouldSuppress(
        notification,
        now: time,
      ),
      isFalse,
    );
    expect(
      await CrossIsolatePaymentAnnouncementDeduplicator.shouldSuppress(
        sms,
        now: time.add(const Duration(seconds: 24)),
      ),
      isTrue,
    );
  });

  test('two same-value notifications can pair with two SMS messages one-to-one', () async {
    final time = DateTime(2026, 10, 27, 10, 0);
    final firstNotification = _event(
      id: 'notif-1',
      timestamp: time,
      source: 'notification',
      app: PaymentApp.phonePe,
      rawText: 'Payment received ₹5 from Ravi',
      amount: 5,
      payerName: 'Ravi',
    );
    final secondNotification = _event(
      id: 'notif-2',
      timestamp: time.add(const Duration(seconds: 4)),
      source: 'notification',
      app: PaymentApp.phonePe,
      rawText: 'Payment received ₹5 from Meena',
      amount: 5,
      payerName: 'Meena',
    );
    final firstSms = _event(
      id: 'sms-1',
      timestamp: time.add(const Duration(seconds: 8)),
      source: 'sms',
      app: PaymentApp.bankSms,
      rawText: 'A/c credited ₹5',
      amount: 5,
    );
    final secondSms = _event(
      id: 'sms-2',
      timestamp: time.add(const Duration(seconds: 12)),
      source: 'sms',
      app: PaymentApp.bankSms,
      rawText: 'A/c credited ₹5',
      amount: 5,
    );

    expect(
      await CrossIsolatePaymentAnnouncementDeduplicator.shouldSuppress(
        firstNotification,
        now: time,
      ),
      isFalse,
    );
    expect(
      await CrossIsolatePaymentAnnouncementDeduplicator.shouldSuppress(
        secondNotification,
        now: time.add(const Duration(seconds: 4)),
      ),
      isFalse,
    );
    expect(
      await CrossIsolatePaymentAnnouncementDeduplicator.shouldSuppress(
        firstSms,
        now: time.add(const Duration(seconds: 8)),
      ),
      isTrue,
    );
    expect(
      await CrossIsolatePaymentAnnouncementDeduplicator.shouldSuppress(
        secondSms,
        now: time.add(const Duration(seconds: 12)),
      ),
      isTrue,
    );
  });

  test('different authoritative references are never paired', () async {
    final time = DateTime(2026, 10, 27, 10, 0);
    final first = _event(
      id: 'notif-1',
      timestamp: time,
      source: 'notification',
      app: PaymentApp.phonePe,
      rawText: 'Payment received ₹500',
      referenceId: '123456789012',
    );
    final second = _event(
      id: 'sms-1',
      timestamp: time.add(const Duration(seconds: 4)),
      source: 'sms',
      app: PaymentApp.bankSms,
      rawText: 'A/c credited ₹500',
      referenceId: '987654321098',
    );

    expect(
      await CrossIsolatePaymentAnnouncementDeduplicator.shouldSuppress(
        first,
        now: time,
      ),
      isFalse,
    );
    expect(
      await CrossIsolatePaymentAnnouncementDeduplicator.shouldSuppress(
        second,
        now: time.add(const Duration(seconds: 4)),
      ),
      isFalse,
    );
  });

  test('a referenced transfer is not paired with an older unreferenced signal', () async {
    final time = DateTime(2026, 10, 27, 10, 0);
    final olderNotification = _event(
      id: 'notif-no-utr',
      timestamp: time,
      source: 'notification',
      app: PaymentApp.bankApp,
      rawText: '₹5 credited to account XXXX4222',
      amount: 5,
      accountSuffix: '4222',
    );
    final referencedSms = _event(
      id: 'sms-with-utr',
      timestamp: time.add(const Duration(seconds: 5)),
      source: 'sms',
      app: PaymentApp.bankSms,
      rawText: '₹5 credited to account XXXX4222 UTR 123456789013',
      amount: 5,
      referenceId: '123456789013',
      accountSuffix: '4222',
    );

    expect(
      await CrossIsolatePaymentAnnouncementDeduplicator.shouldSuppress(
        olderNotification,
        now: time,
      ),
      isFalse,
    );
    expect(
      await CrossIsolatePaymentAnnouncementDeduplicator.shouldSuppress(
        referencedSms,
        now: time.add(const Duration(seconds: 5)),
      ),
      isFalse,
    );
  });

  test('conflicting known account suffixes are never paired', () async {
    final time = DateTime(2026, 10, 27, 10, 0);
    final first = _event(
      id: 'notif-1',
      timestamp: time,
      source: 'notification',
      app: PaymentApp.phonePe,
      rawText: 'Payment received ₹500',
      accountSuffix: '1234',
    );
    final second = _event(
      id: 'sms-1',
      timestamp: time.add(const Duration(seconds: 4)),
      source: 'sms',
      app: PaymentApp.bankSms,
      rawText: 'A/c credited ₹500',
      accountSuffix: '6789',
    );

    expect(
      await CrossIsolatePaymentAnnouncementDeduplicator.shouldSuppress(
        first,
        now: time,
      ),
      isFalse,
    );
    expect(
      await CrossIsolatePaymentAnnouncementDeduplicator.shouldSuppress(
        second,
        now: time.add(const Duration(seconds: 4)),
      ),
      isFalse,
    );
  });
}
