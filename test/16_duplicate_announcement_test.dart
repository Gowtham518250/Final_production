import 'package:flutter_test/flutter_test.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:retail_mind/payment_detection_service.dart';
import 'package:retail_mind/payment_event.dart';

PaymentEvent _credit({
  required String id,
  required PaymentApp app,
  required String source,
  required DateTime at,
  double amount = 5,
  String? payer,
  String? ref,
  String text = 'sent to you',
}) => PaymentEvent(
  id: id,
  amount: amount,
  timestamp: at,
  app: app,
  payerName: payer,
  referenceId: ref,
  rawText: '$id $text',
  detectionSource: source,
  direction: PaymentTransactionDirection.incomingCredit,
  decision: PaymentDecision.likely,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<PaymentEvent>> emitAll(List<PaymentEvent> inputs) async {
    final service = PaymentDetectionService();
    service.debugResetTransientDetectionState();
    service.clearBill();
    final events = <PaymentEvent>[];
    final sub = service.onPaymentDetected.listen(events.add);
    for (final e in inputs) {
      await service.debugEmitForTesting(e);
    }
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await sub.cancel();
    return events;
  }

  group('one payment -> one alert; two payments -> two alerts', () {
    test('our own notifications are never re-read as payments', () async {
      final service = PaymentDetectionService();
      service.debugResetTransientDetectionState();
      final events = <PaymentEvent>[];
      final sub = service.onPaymentDetected.listen(events.add);
      for (final content in const [
        'Credit: ₹500 via PhonePe',
        'Credit: ₹500 via PhonePe — verify before recording.',
      ]) {
        service.debugHandleNotification(
          ServiceNotificationEvent(
            packageName: 'com.retailmind.app',
            title: 'Payment Received',
            content: content,
          ),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await sub.cancel();
      expect(events, isEmpty);
    });

    test('PhonePe notification + Truecaller mirror of the same payment = 1',
        () async {
      final now = DateTime.now();
      final events = await emitAll([
        _credit(id: 'n1', app: PaymentApp.phonePe, source: 'notification', at: now),
        _credit(id: 't1', app: PaymentApp.bankApp, source: 'notification', at: now),
      ]);
      expect(events, hasLength(1));
    });

    test('same customer pays Rs 5 twice via PhonePe = 2 payments', () async {
      final now = DateTime.now();
      final events = await emitAll([
        _credit(
          id: 'n1',
          app: PaymentApp.phonePe,
          source: 'notification',
          at: now.subtract(const Duration(seconds: 40)),
          payer: 'Anna Devi',
          text: 'Anna Devi sent Rs 5 to you',
        ),
        _credit(
          id: 'n2',
          app: PaymentApp.phonePe,
          source: 'notification',
          at: now,
          payer: 'Anna Devi',
          text: 'Anna Devi sent Rs 5 to you',
        ),
      ]);
      expect(events, hasLength(2));
    });

    test('SMS arriving 20 minutes later pairs with its notification', () async {
      final now = DateTime.now();
      final events = await emitAll([
        _credit(
          id: 'n1',
          app: PaymentApp.phonePe,
          source: 'notification',
          at: now.subtract(const Duration(minutes: 20)),
        ),
        _credit(id: 's1', app: PaymentApp.bankSms, source: 'sms', at: now),
      ]);
      expect(events, hasLength(1));
    });

    test('two payments + two late SMS = 2, a third unmatched SMS = 3', () async {
      final now = DateTime.now();
      PaymentEvent n(String id, int minsAgo) => _credit(
        id: id,
        app: PaymentApp.phonePe,
        source: 'notification',
        at: now.subtract(Duration(minutes: minsAgo)),
      );
      PaymentEvent s(String id) =>
          _credit(id: id, app: PaymentApp.bankSms, source: 'sms', at: now);

      final two = await emitAll([n('n1', 21), n('n2', 20), s('s1'), s('s2')]);
      expect(two, hasLength(2));

      final three = await emitAll([
        n('n1', 21),
        n('n2', 20),
        s('s1'),
        s('s2'),
        s('s3'),
      ]);
      expect(three, hasLength(3));
    });

    test('different references are always different payments', () async {
      final now = DateTime.now();
      final events = await emitAll([
        _credit(id: 'n1', app: PaymentApp.phonePe, source: 'notification', at: now, ref: '412345678901'),
        _credit(id: 's1', app: PaymentApp.bankSms, source: 'sms', at: now, ref: '412345678902'),
      ]);
      expect(events, hasLength(2));
    });

    test('same reference on two channels is one payment', () async {
      final now = DateTime.now();
      final events = await emitAll([
        _credit(id: 'n1', app: PaymentApp.phonePe, source: 'notification', at: now, ref: '412345678901'),
        _credit(id: 's1', app: PaymentApp.bankSms, source: 'sms', at: now, ref: '412345678901'),
      ]);
      expect(events, hasLength(1));
    });

    test('SMS 90 minutes later still pairs with its notification', () async {
      final now = DateTime.now();
      final events = await emitAll([
        _credit(
          id: 'n1',
          app: PaymentApp.phonePe,
          source: 'notification',
          at: now.subtract(const Duration(minutes: 90)),
        ),
        _credit(id: 's1', app: PaymentApp.bankSms, source: 'sms', at: now),
      ]);
      expect(events, hasLength(1));
    });

    test(
      'Truecaller text updates suppress a repeat sound but keep both review candidates',
      () async {
        final originalVoiceEnabled = PdsConfig.isVoiceEnabled;
        final originalVoiceMinGap = PdsConfig.voiceMinGap;
        PdsConfig.isVoiceEnabled = true;
        PdsConfig.voiceMinGap = Duration.zero;
        final service = PaymentDetectionService();
        service.debugResetTransientDetectionState();
        service.clearBill();
        final emitted = <PaymentEvent>[];
        final spoken = <String>[];
        final sub = service.onPaymentDetected.listen(emitted.add);
        service.onSpeak = spoken.add;
        final now = DateTime.now();

        await service.debugEmitForTesting(
          PaymentEvent(
            id: 'tc-first',
            amount: 500,
            timestamp: now,
            app: PaymentApp.bankApp,
            payerName: 'Rahul Kumar',
            accountSuffix: '4222',
            rawText: 'UPI transfer from Rahul Kumar to Account 4222 + ₹500',
            detectionSource: 'truecaller_notification',
            direction: PaymentTransactionDirection.incomingCredit,
            decision: PaymentDecision.likely,
          ),
        );
        await service.debugEmitForTesting(
          PaymentEvent(
            id: 'tc-updated',
            amount: 500,
            timestamp: now.add(const Duration(seconds: 2)),
            app: PaymentApp.bankApp,
            payerName: 'Rahul Kumar',
            accountSuffix: '4222',
            rawText: 'Rahul Kumar sent ₹500 to your bank account 4222',
            detectionSource: 'truecaller_notification',
            direction: PaymentTransactionDirection.incomingCredit,
            decision: PaymentDecision.likely,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 250));

        // A heuristic must not delete an unreferenced candidate from review:
        // merchant confirmation is still required to make an accounting entry.
        expect(emitted, hasLength(2));
        expect(emitted.every((event) => !event.isMerchantConfirmed), isTrue);
        expect(spoken, hasLength(1));

        await sub.cancel();
        service.clearBill();
        service.debugResetTransientDetectionState();
        PdsConfig.isVoiceEnabled = originalVoiceEnabled;
        PdsConfig.voiceMinGap = originalVoiceMinGap;
      },
    );

    test('confirmation dialog can warn about a likely late duplicate', () async {
      final service = PaymentDetectionService();
      service.debugResetTransientDetectionState();
      final now = DateTime.now();
      final first = _credit(
        id: 'c1',
        app: PaymentApp.phonePe,
        source: 'notification',
        at: now.subtract(const Duration(minutes: 100)),
        payer: 'Anna Devi',
      );
      expect(await service.confirmDetectedPayment(first), isTrue);
      final late = _credit(
        id: 'c2',
        app: PaymentApp.bankSms,
        source: 'sms',
        at: now,
        payer: 'Anna Devi',
      );
      expect(service.similarRecentlyConfirmed(late)?.id, 'c1');
      final other = _credit(
        id: 'c3',
        app: PaymentApp.bankSms,
        source: 'sms',
        at: now,
        payer: 'Ravi Kumar',
      );
      expect(service.similarRecentlyConfirmed(other), isNull);
    });
  });
}
