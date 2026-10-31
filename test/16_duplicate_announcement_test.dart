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
  String? accountSuffix,
  String? sourceEventKey,
  String text = 'sent to you',
}) => PaymentEvent(
  id: id,
  amount: amount,
  timestamp: at,
  app: app,
  payerName: payer,
  accountSuffix: accountSuffix,
  referenceId: ref,
  sourceEventKey: sourceEventKey,
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
        _credit(id: 'n1', app: PaymentApp.phonePe, source: 'notification', at: now, payer: 'Anna Devi', accountSuffix: '4222'),
        _credit(id: 't1', app: PaymentApp.bankApp, source: 'notification', at: now, payer: 'Anna Devi', accountSuffix: '4222'),
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
          payer: 'Anna Devi',
        ),
        _credit(id: 's1', app: PaymentApp.bankSms, source: 'sms', at: now, payer: 'Anna Devi'),
      ]);
      expect(events, hasLength(1));
    });

    test('two payments + two late SMS = 2, a third unmatched SMS = 3', () async {
      final now = DateTime.now();
      PaymentEvent n(String id, int minsAgo, String payer) => _credit(
        id: id,
        app: PaymentApp.phonePe,
        source: 'notification',
        at: now.subtract(Duration(minutes: minsAgo)),
        payer: payer,
      );
      PaymentEvent s(String id, String payer) => _credit(
        id: id,
        app: PaymentApp.bankSms,
        source: 'sms',
        at: now,
        payer: payer,
      );

      final two = await emitAll([
        n('n1', 21, 'Anna Devi'),
        n('n2', 20, 'Meena Devi'),
        s('s1', 'Anna Devi'),
        s('s2', 'Meena Devi'),
      ]);
      expect(two, hasLength(2));

      final three = await emitAll([
        n('n1', 21, 'Anna Devi'),
        n('n2', 20, 'Meena Devi'),
        s('s1', 'Anna Devi'),
        s('s2', 'Meena Devi'),
        s('s3', 'Ravi Kumar'),
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

    test('app notification (payer only) + bank SMS (UTR only) within 60s = 1',
        () async {
      final now = DateTime.now();
      final events = await emitAll([
        _credit(id: 'n1', app: PaymentApp.phonePe, source: 'notification', at: now, amount: 500),
        _credit(
          id: 's1',
          app: PaymentApp.bankSms,
          source: 'sms',
          at: now.add(const Duration(seconds: 20)),
          amount: 500,
          ref: '412345678901',
        ),
      ]);
      expect(events, hasLength(1));
    });

    test('same pair 5 minutes apart with no shared evidence stays 2', () async {
      final now = DateTime.now();
      final events = await emitAll([
        _credit(id: 'n1', app: PaymentApp.phonePe, source: 'notification', at: now, amount: 500),
        _credit(
          id: 's1',
          app: PaymentApp.bankSms,
          source: 'sms',
          at: now.add(const Duration(minutes: 5)),
          amount: 500,
        ),
      ]);
      expect(events, hasLength(2));
    });

    test('two same-amount app notifications 10s apart stay 2 (same modality)',
        () async {
      final now = DateTime.now();
      final events = await emitAll([
        _credit(id: 'n1', app: PaymentApp.phonePe, source: 'notification', at: now, amount: 500,
            sourceEventKey: 'com.phonepe.app|1|1000|aa'),
        _credit(id: 'n2', app: PaymentApp.googlePay, source: 'notification',
            at: now.add(const Duration(seconds: 10)), amount: 500,
            sourceEventKey: 'com.google.android.apps.nbu.paisa.user|2|2000|bb'),
      ]);
      expect(events, hasLength(2));
    });

    test('one SMS cannot swallow two earlier notifications (ambiguous = keep)',
        () async {
      final now = DateTime.now();
      final events = await emitAll([
        _credit(id: 'n1', app: PaymentApp.phonePe, source: 'notification', at: now, amount: 500),
        _credit(id: 'n2', app: PaymentApp.googlePay, source: 'notification',
            at: now.add(const Duration(seconds: 5)), amount: 500),
        _credit(id: 's1', app: PaymentApp.bankSms, source: 'sms',
            at: now.add(const Duration(seconds: 15)), amount: 500),
      ]);
      expect(events.length, greaterThanOrEqualTo(2));
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
          payer: 'Anna Devi',
        ),
        _credit(id: 's1', app: PaymentApp.bankSms, source: 'sms', at: now, payer: 'Anna Devi'),
      ]);
      expect(events, hasLength(1));
    });

    test(
      'Truecaller text updates suppress a repeat sound but keep both review candidates',
      () async {
        final originalVoiceEnabled = PdsConfig.isVoiceEnabled;
        PdsConfig.isVoiceEnabled = true;

        final service = PaymentDetectionService();
        service.debugResetTransientDetectionState();
        service.clearBill();
        final emitted = <PaymentEvent>[];
        final sub = service.onPaymentDetected.listen(emitted.add);
        final spoken = <String>[];
        final queue = PriorityVoiceQueue()..onSpeak = spoken.add;
        final now = DateTime.now();

        final first = PaymentEvent(
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
        );
        final updated = PaymentEvent(
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
        );
        PaymentUiState ui(PaymentEvent event) => PaymentUiState(
          id: event.id,
          decision: event.decision,
          amount: event.amount,
          payerName: event.payerName,
          bankName: event.bankName,
          isFailed: event.isFailed,
          detectedAt: event.timestamp,
          rawText: event.rawText,
          direction: event.direction,
        );

        await service.debugEmitForTesting(first);
        await service.debugEmitForTesting(updated);

        // Exercise the public queue directly so this assertion tests the
        // repeat-suppression policy rather than the service's platform TTS
        // adapter, which is intentionally absent in Flutter unit tests.
        queue.enqueue(first, ui(first));
        queue.enqueue(updated, ui(updated));
        await Future<void>.delayed(const Duration(milliseconds: 250));

        expect(emitted, hasLength(2));
        expect(emitted.every((event) => !event.isMerchantConfirmed), isTrue);
        expect(spoken, hasLength(1));

        queue.dispose();
        await sub.cancel();
        service.clearBill();
        service.debugResetTransientDetectionState();
        PdsConfig.isVoiceEnabled = originalVoiceEnabled;
      },
    );

    test(
      'same payer sends the same amount twice with distinct native posts: both speak',
      () async {
        final originalVoiceEnabled = PdsConfig.isVoiceEnabled;
        PdsConfig.isVoiceEnabled = true;
        final queue = PriorityVoiceQueue();
        final spoken = <String>[];
        queue.onSpeak = spoken.add;
        final firstAt = DateTime.now();
        final secondAt = firstAt.add(const Duration(seconds: 2));
        final first = PaymentEvent(
          id: 'tc-post-1',
          amount: 500,
          timestamp: firstAt,
          app: PaymentApp.bankApp,
          payerName: 'Rahul Kumar',
          accountSuffix: '4222',
          sourceEventKey:
              'com.truecaller|41|${firstAt.millisecondsSinceEpoch}|hash-a',
          rawText: 'Rahul Kumar sent ₹500 to account 4222',
          detectionSource: 'truecaller_notification',
          direction: PaymentTransactionDirection.incomingCredit,
          decision: PaymentDecision.likely,
        );
        final second = PaymentEvent(
          id: 'tc-post-2',
          amount: 500,
          timestamp: secondAt,
          app: PaymentApp.bankApp,
          payerName: 'Rahul Kumar',
          accountSuffix: '4222',
          sourceEventKey:
              'com.truecaller|42|${secondAt.millisecondsSinceEpoch}|hash-b',
          rawText: 'Rahul Kumar sent ₹500 to account 4222',
          detectionSource: 'truecaller_notification',
          direction: PaymentTransactionDirection.incomingCredit,
          decision: PaymentDecision.likely,
        );
        PaymentUiState ui(PaymentEvent event) => PaymentUiState(
          id: event.id,
          decision: event.decision,
          amount: event.amount,
          payerName: event.payerName,
          bankName: event.bankName,
          isFailed: event.isFailed,
          detectedAt: event.timestamp,
          rawText: event.rawText,
          direction: event.direction,
        );

        queue.enqueue(first, ui(first));
        queue.enqueue(second, ui(second));
        await Future<void>.delayed(const Duration(milliseconds: 2600));

        expect(spoken, hasLength(2));
        queue.dispose();
        PdsConfig.isVoiceEnabled = originalVoiceEnabled;
      },
    );

    test(
      'ambiguous same-payer same-amount cross-source match does not suppress a payment',
      () async {
        final now = DateTime.now();
        final events = await emitAll([
          _credit(
            id: 'phonepe-1',
            app: PaymentApp.phonePe,
            source: 'notification',
            at: now,
            payer: 'Rahul Kumar',
            accountSuffix: '4222',
            sourceEventKey:
                'com.phonepe.app|51|${now.millisecondsSinceEpoch}|hash-1',
            text: 'Rahul Kumar sent ₹500 to account 4222',
          ),
          _credit(
            id: 'phonepe-2',
            app: PaymentApp.phonePe,
            source: 'notification',
            at: now.add(const Duration(seconds: 1)),
            payer: 'Rahul Kumar',
            accountSuffix: '4222',
            sourceEventKey:
                'com.phonepe.app|52|${now.millisecondsSinceEpoch + 1000}|hash-2',
            text: 'Rahul Kumar sent ₹500 to account 4222',
          ),
          _credit(
            id: 'truecaller-echo',
            app: PaymentApp.bankApp,
            source: 'notification',
            at: now.add(const Duration(seconds: 2)),
            payer: 'Rahul Kumar',
            accountSuffix: '4222',
            sourceEventKey:
                'com.truecaller|53|${now.millisecondsSinceEpoch + 2000}|hash-3',
            text: 'Rahul Kumar sent ₹500 to account 4222',
          ),
        ]);

        // With two plausible originals and no shared transaction reference,
        // choosing one would risk hiding a genuine second payment.
        expect(events, hasLength(3));
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
  test('SMS echo of second same-value payment pairs with nearest notification', () async {
        final now = DateTime.now();
        final events = await emitAll([
          _credit(id: 'n1', app: PaymentApp.phonePe, source: 'notification',
              at: now, amount: 500, accountSuffix: '4222',
              sourceEventKey: 'com.phonepe.app|1|1000|aa'),
          _credit(id: 'n2', app: PaymentApp.phonePe, source: 'notification',
              at: now.add(const Duration(minutes: 5)), amount: 500,
              accountSuffix: '4222',
              sourceEventKey: 'com.phonepe.app|2|2000|bb'),
          _credit(id: 's2', app: PaymentApp.bankSms, source: 'sms',
              at: now.add(const Duration(minutes: 5, seconds: 20)), amount: 500,
              accountSuffix: '4222'),
        ]);
        expect(events, hasLength(2));
      });
  });
}
