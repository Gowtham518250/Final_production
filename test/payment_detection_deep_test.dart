import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/payment_detection_service.dart';
import 'package:retail_mind/payment_event.dart';
import 'package:retail_mind/language_engine.dart';
import 'package:retail_mind/humanizer.dart';
import 'package:notification_listener_service/notification_event.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Payment reference extraction regressions', () {
    test('ordinary words are not transaction references', () {
      expect(
        PaymentDetectionService.debugExtractReferenceId(
          'Transaction successful. Payment received ₹250',
        ),
        isNull,
      );
      expect(
        PaymentDetectionService.debugExtractReferenceId(
          'Transaction confirmation: amount ₹250 credited',
        ),
        isNull,
      );
    });

    test('labelled numeric references remain detectable', () {
      expect(
        PaymentDetectionService.debugExtractReferenceId(
          'Transaction ID: 123456789012',
        ),
        '123456789012',
      );
      expect(
        PaymentDetectionService.debugExtractReferenceId(
          'Ref No 987654321098',
        ),
        '987654321098',
      );
    });
  });

  group('Durable notification identity', () {
    test('keeps native event key when decoding queued notification', () {
      final event = ServiceNotificationEvent.fromMap({
        'id': 42,
        'eventKey': 'com.example.payment|42|1792939200000|9a76',
        'packageName': 'com.example.payment',
        'title': 'Payment received',
        'content': 'Payment received ₹250',
        'hasRemoved': false,
        'canReply': false,
        'onGoing': false,
      });

      expect(event.id, 42);
      expect(event.eventKey, 'com.example.payment|42|1792939200000|9a76');
      expect(event.packageName, 'com.example.payment');
    });

    test('replayed native notification event key is suppressed after payload extras change', () async {
      final service = PaymentDetectionService();
      service.debugResetTransientDetectionState();
      service.clearBill();
      service.setBillExpected(10);
      final events = <PaymentEvent>[];
      final subscription = service.onPaymentDetected.listen(events.add);
      const nativeKey = 'com.phonepe.app|7|1792939200000|payload-sha';

      service.debugHandleNotification(
        ServiceNotificationEvent(
          packageName: 'com.phonepe.app',
          id: 7,
          eventKey: nativeKey,
          title: 'PhonePe',
          content: 'You received ₹5 from Rahul',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Native event identity stays stable for the same posted notification,
      // even if a delivery path attaches extra textLines not part of that key.
      service.debugHandleNotification(
        ServiceNotificationEvent(
          packageName: 'com.phonepe.app',
          id: 7,
          eventKey: nativeKey,
          title: 'PhonePe',
          content: 'You received ₹5 from Rahul',
          textLines: 'Delivery replay marker',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(events, hasLength(1));
      await subscription.cancel();
      service.clearBill();
      service.debugResetTransientDetectionState();
    });
  });

  group('Bill payment tracking', () {
    test(
      'trusted PhonePe credit with a short notification updates a ten-rupee bill',
      () async {
        final service = PaymentDetectionService();
        service.clearBill();
        service.setBillExpected(10);
        service.billContext.setAt = DateTime.now().subtract(
          const Duration(minutes: 31),
        );

        final received = expectLater(
          service.onPaymentDetected,
          emits(
            isA<PaymentEvent>()
                .having((payment) => payment.amount, 'amount', 5)
                .having(
                  (payment) => payment.direction,
                  'direction',
                  PaymentTransactionDirection.incomingCredit,
                )
                .having(
                  (payment) => payment.decision,
                  'decision',
                  PaymentDecision.likely,
                )
                .having(
                  (payment) => payment.isPartialPayment,
                  'isPartialPayment',
                  isTrue,
                )
                .having(
                  (payment) => payment.remainingAmount,
                  'remainingAmount',
                  5,
                ),
          ),
        );

        service.debugHandleNotification(
          ServiceNotificationEvent(
            packageName: 'com.phonepe.app',
            title: 'PhonePe',
            content: 'You received ₹5 from Rahul',
          ),
        );

        await received;
        service.clearBill();
      },
    );

    test('expanded bank SMS notification text is detected as a credit', () async {
      final service = PaymentDetectionService();
      service.clearBill();
      service.setBillExpected(10);

      final received = expectLater(
        service.onPaymentDetected,
        emits(
          isA<PaymentEvent>()
              .having((payment) => payment.amount, 'amount', 8)
              .having(
                (payment) => payment.direction,
                'direction',
                PaymentTransactionDirection.incomingCredit,
              )
              .having(
                (payment) => payment.decision,
                'decision',
                PaymentDecision.likely,
              ),
        ),
      );

      service.debugHandleNotification(
        ServiceNotificationEvent(
          packageName: 'com.google.android.apps.messaging',
          title: 'VM-APGB-T',
          content: 'Dear Customer, An amount of Rs.8/- is ...',
          bigText:
              'Dear Customer, An amount of Rs.8/- is credited to A/c XXXX4222',
        ),
      );

      await received;
      service.clearBill();
    });

    test(
      'Truecaller bank SMS notification is accepted once and deduplicated',
      () async {
        final service = PaymentDetectionService();
        service.clearBill();
        service.setBillExpected(20);
        const body =
            'Dear Customer, An amount of Rs.13/- is credited to A/c XXXX4222';
        final eventReceived = expectLater(
          service.onPaymentDetected,
          emits(
            isA<PaymentEvent>()
                .having((payment) => payment.amount, 'amount', 13)
                .having(
                  (payment) => payment.direction,
                  'direction',
                  PaymentTransactionDirection.incomingCredit,
                ),
          ),
        );
        var eventCount = 0;
        final subscription = service.onPaymentDetected.listen((_) {
          eventCount++;
        });
        final notification = ServiceNotificationEvent(
          packageName: 'com.truecaller',
          title: 'VA-APGB-T',
          content: 'Dear Customer, An amount of Rs.13/- is ...',
          bigText: body,
        );

        service.debugHandleNotification(notification);
        await eventReceived;
        service.debugHandleNotification(notification);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(eventCount, 1);
        await subscription.cancel();
        service.clearBill();
      },
    );

    test('same-UTR PhonePe notification and SMS produce one UI event', () async {
      final service = PaymentDetectionService();
      service.debugResetTransientDetectionState();
      service.clearBill();
      service.setBillExpected(10);
      final events = <PaymentEvent>[];
      final subscription = service.onPaymentDetected.listen(events.add);

      service.debugHandleNotification(
        ServiceNotificationEvent(
          packageName: 'com.phonepe.app',
          title: 'PhonePe',
          content: 'Payment received ₹5 credited to your account. UTR 123456789012',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      service.handleSms(
        'VM-PHONEPE',
        'Your account is credited with Rs.5. UTR 123456789012',
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(events, hasLength(1));
      expect(events.single.normalizedReferenceId, '123456789012');
      expect(events.every((event) => event.isMerchantConfirmed), isFalse);

      await subscription.cancel();
      service.clearBill();
    });

    test('VA-APGB SMS credit wording emits a partial payment event', () async {
      final service = PaymentDetectionService();
      const body =
          'Dear Customer, An amount of Rs.7/- is credited to A/c XXXX4222';
      service.clearBill();
      service.setBillExpected(10);

      final received = expectLater(
        service.onPaymentDetected,
        emits(
          isA<PaymentEvent>()
              .having((payment) => payment.amount, 'amount', 7)
              .having(
                (payment) => payment.direction,
                'direction',
                PaymentTransactionDirection.incomingCredit,
              )
              .having(
                (payment) => payment.decision,
                'decision',
                PaymentDecision.likely,
              ),
        ),
      );

      service.handleSms('VA-APGB-T', body);
      await received;
      service.clearBill();
    });

    test(
      'APGB transfer alerts are detected as partial incoming payments',
      () async {
        final service = PaymentDetectionService();
        service.debugResetTransientDetectionState();
        const text = 'UPI transfer from Apgbank to Account 4222 +₹5';
        service.clearBill();
        service.setBillExpected(10);

        final received = expectLater(
          service.onPaymentDetected,
          emits(
            isA<PaymentEvent>()
                .having((payment) => payment.amount, 'amount', 5)
                .having(
                  (payment) => payment.direction,
                  'direction',
                  PaymentTransactionDirection.incomingCredit,
                )
                .having(
                  (payment) => payment.decision,
                  'decision',
                  PaymentDecision.likely,
                )
                .having(
                  (payment) => payment.isPartialPayment,
                  'isPartialPayment',
                  isTrue,
                )
                .having(
                  (payment) => payment.remainingAmount,
                  'remainingAmount',
                  5,
                ),
          ),
        );

        service.handleSms('AX-APGB-T', text);
        await received;
        service.clearBill();
      },
    );

    test('Truecaller transfer fallback is narrowly constrained', () {
      const text =
          'APGB Verified Business + ₹5 UPI transfer from Apgbank to Account 4222';

      expect(PaymentDetectionService.debugClassify(text), 'passed');
      expect(PaymentDetectionService.debugExtractAmount(text), 5);
      expect(
        PaymentDetectionService.debugIsSupportedTruecallerIncomingTransfer(
          'com.truecaller',
          text,
        ),
        isTrue,
      );
      expect(
        PaymentDetectionService.debugIsSupportedTruecallerIncomingTransfer(
          'com.unknown.app',
          text,
        ),
        isFalse,
      );
      expect(
        PaymentDetectionService.debugIsSupportedTruecallerIncomingTransfer(
          'com.truecaller',
          '₹5 UPI transfer to Account 4222',
        ),
        isFalse,
      );
    });

    test('trusted UPI credit without an active bill is reviewable', () async {
      final service = PaymentDetectionService();
      service.debugResetTransientDetectionState();
      service.clearBill();
      final events = <PaymentEvent>[];
      final subscription = service.onPaymentDetected.listen(events.add);

      service.debugHandleNotification(
        ServiceNotificationEvent(
          packageName: 'com.phonepe.app',
          title: 'PhonePe',
          content: 'Payment received ₹250 credited to your account',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(events, hasLength(1));
      expect(events.single.amount, 250);
      expect(
        events.single.direction,
        PaymentTransactionDirection.incomingCredit,
      );
      expect(events.single.decision, PaymentDecision.likely);
      expect(events.single.isMerchantConfirmed, isFalse);

      await subscription.cancel();
    });

    test('APGB Truecaller Business Chat notification is detected', () async {
      final service = PaymentDetectionService();
      service.debugResetTransientDetectionState();
      final events = <PaymentEvent>[];
      final subscription = service.onPaymentDetected.listen(events.add);

      service.debugHandleNotification(
        ServiceNotificationEvent(
          packageName: 'com.truecaller',
          title: 'APGB',
          content:
              'Verified Business + ₹5 UPI transfer from Apgbank to Account 4222',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(events, hasLength(1));
      expect(events.single.amount, 5);
      expect(
        events.single.direction,
        PaymentTransactionDirection.incomingCredit,
      );
      expect(events.single.decision, PaymentDecision.likely);
      expect(events.single.detectionSource, 'truecaller_notification');

      await subscription.cancel();
    });

    test('PhonePe payment echoed by Truecaller on same account emits only once', () async {
      final service = PaymentDetectionService();
      service.debugResetTransientDetectionState();
      final events = <PaymentEvent>[];
      final subscription = service.onPaymentDetected.listen(events.add);

      service.debugHandleNotification(
        ServiceNotificationEvent(
          packageName: 'com.phonepe.app',
          title: 'PhonePe',
          content: 'UPI payment ₹5 received from Rahul, credited to A/c XXXX4222',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));

      service.debugHandleNotification(
        ServiceNotificationEvent(
          packageName: 'com.truecaller',
          title: 'APGB',
          content: 'Verified Business + ₹5 UPI transfer from Apgbank to Account 4222',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(events, hasLength(1));
      expect(events.single.amount, 5);
      expect(events.single.accountSuffix, '4222');

      await subscription.cancel();
    });

    test('same amount from Truecaller to a different account is not deduplicated', () async {
      final service = PaymentDetectionService();
      service.debugResetTransientDetectionState();
      final events = <PaymentEvent>[];
      final subscription = service.onPaymentDetected.listen(events.add);

      service.debugHandleNotification(
        ServiceNotificationEvent(
          packageName: 'com.phonepe.app',
          title: 'PhonePe',
          content: 'UPI payment ₹5 received from Rahul, credited to A/c XXXX4222',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));

      service.debugHandleNotification(
        ServiceNotificationEvent(
          packageName: 'com.truecaller',
          title: 'APGB',
          content: 'Verified Business + ₹5 UPI transfer from Apgbank to Account 1234',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(events, hasLength(2));
      expect(events.map((event) => event.accountSuffix).toSet(), {'4222', '1234'});

      await subscription.cancel();
    });

    test('bare APGB Truecaller title is not misrouted as bank SMS', () {
      expect(
        PaymentDetectionService.debugIsTrustedBankSmsNotification(
          'com.truecaller',
          'APGB',
        ),
        isFalse,
      );
      expect(
        PaymentDetectionService.debugIsTrustedBankSmsNotification(
          'com.truecaller',
          'VA-APGB-T',
        ),
        isTrue,
      );
    });

    test('unregistered bank app credit without UTR becomes a review candidate', () async {
      final service = PaymentDetectionService();
      service.debugResetTransientDetectionState();
      final received = expectLater(
        service.onPaymentDetected,
        emits(
          isA<PaymentEvent>()
              .having((payment) => payment.amount, 'amount', 25)
              .having(
                (payment) => payment.direction,
                'direction',
                PaymentTransactionDirection.incomingCredit,
              )
              .having(
                (payment) => payment.decision,
                'decision',
                PaymentDecision.likely,
              ),
        ),
      );

      service.debugHandleNotification(
        ServiceNotificationEvent(
          packageName: 'com.example.otherbank',
          title: 'Other Bank',
          content: '₹25 credited to Account XXXX6789',
        ),
      );

      await received;
    });

    test('well-formed DLT sender from an unlisted bank can emit a review candidate', () async {
      final service = PaymentDetectionService();
      service.debugResetTransientDetectionState();
      final received = expectLater(
        service.onPaymentDetected,
        emits(
          isA<PaymentEvent>()
              .having((payment) => payment.amount, 'amount', 500)
              .having(
                (payment) => payment.direction,
                'direction',
                PaymentTransactionDirection.incomingCredit,
              )
              .having(
                (payment) => payment.decision,
                'decision',
                PaymentDecision.likely,
              ),
        ),
      );

      service.handleSms(
        'VM-XYZBNK',
        'Dear Customer, INR 500 credited to A/c XXXX1234. '
        'UTR 123456789012',
      );

      await received;
    });

    test('unregistered bank debit notification is surfaced as a debit candidate', () async {
      final service = PaymentDetectionService();
      service.debugResetTransientDetectionState();
      final received = expectLater(
        service.onPaymentDetected,
        emits(
          isA<PaymentEvent>()
              .having(
                (payment) => payment.direction,
                'direction',
                PaymentTransactionDirection.outgoingDebit,
              )
              .having(
                (payment) => payment.decision,
                'decision',
                PaymentDecision.likely,
              )
              .having((payment) => payment.amount, 'amount', 500),
        ),
      );

      service.debugHandleNotification(
        ServiceNotificationEvent(
          packageName: 'com.unregistered.bank.mobile',
          title: 'Bank Alert',
          content: 'INR 500 debited from account XXXX8844',
        ),
      );

      await received;
    });

    test(
      'Truecaller transfer notification emits a partial review event',
      () async {
        final service = PaymentDetectionService();
        service.clearBill();
        service.setBillExpected(10);
        final received = expectLater(
          service.onPaymentDetected,
          emits(
            isA<PaymentEvent>()
                .having((payment) => payment.amount, 'amount', 6)
                .having(
                  (payment) => payment.direction,
                  'direction',
                  PaymentTransactionDirection.incomingCredit,
                )
                .having(
                  (payment) => payment.decision,
                  'decision',
                  PaymentDecision.likely,
                )
                .having(
                  (payment) => payment.isPartialPayment,
                  'isPartialPayment',
                  isTrue,
                )
                .having(
                  (payment) => payment.remainingAmount,
                  'remainingAmount',
                  4,
                ),
          ),
        );

        service.debugHandleTruecallerIncomingTransfer(
          'com.truecaller',
          'APGB Verified Business + ₹6 UPI transfer from Apgbank to Account 4222',
        );

        await received;
        service.clearBill();
      },
    );

    test(
      'voice queue announces both APGB incoming transfers and outgoing debits',
      () async {
        final oldVoiceEnabled = PdsConfig.isVoiceEnabled;
        PdsConfig.isVoiceEnabled = true;

        Future<String> spokenFor(PaymentEvent event) async {
          final queue = PriorityVoiceQueue();
          final spoken = <String>[];
          queue.getLanguage = () => VoiceLanguage.english;
          queue.onSpeak = spoken.add;
          queue.enqueue(
            event,
            PaymentUiState(
              id: event.id,
              decision: PaymentDecision.likely,
              amount: event.amount,
              isFailed: false,
              isPartial: false,
              isBillMatch: false,
              detectedAt: event.timestamp,
              rawText: event.rawText,
              direction: event.direction,
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 100));
          queue.dispose();
          expect(spoken, hasLength(1));
          return spoken.single.toLowerCase();
        }

        try {
          final creditText =
              'APGB Verified Business + ₹5 UPI transfer from Apgbank to Account 4222';
          final credit = PaymentEvent(
            id: 'apgb-credit-voice',
            amount: 5,
            timestamp: DateTime.now(),
            app: PaymentApp.bankApp,
            rawText: creditText,
            decision: PaymentDecision.likely,
            direction: PaymentTransactionDirection.incomingCredit,
          );
          expect(await spokenFor(credit), contains('credited'));

          final debitText = 'INR 5 debited from your account XXXX4222';
          final debit = PaymentEvent(
            id: 'apgb-debit-voice',
            amount: 5,
            timestamp: DateTime.now(),
            app: PaymentApp.bankApp,
            rawText: debitText,
            decision: PaymentDecision.likely,
            direction: PaymentTransactionDirection.outgoingDebit,
          );
          expect(await spokenFor(debit), contains('debited'));
        } finally {
          PdsConfig.isVoiceEnabled = oldVoiceEnabled;
        }
      },
    );

    test(
      'partial incoming alerts produce a partial-payment voice prompt',
      () async {
        final queue = PriorityVoiceQueue();
        final spoken = <String>[];
        queue.onSpeak = spoken.add;
        const text = 'UPI transfer from Apgbank to Account 4222 +₹5';
        final event = PaymentEvent(
          amount: 5,
          timestamp: DateTime.now(),
          app: PaymentApp.bankApp,
          rawText: text,
          decision: PaymentDecision.likely,
          isPartialPayment: true,
          remainingAmount: 5,
          direction: PaymentTransactionDirection.incomingCredit,
        );

        queue.enqueue(
          event,
          PaymentUiState(
            id: event.id,
            decision: PaymentDecision.likely,
            amount: event.amount,
            isFailed: false,
            isPartial: true,
            shortfall: 5,
            detectedAt: event.timestamp,
            direction: PaymentTransactionDirection.incomingCredit,
            rawText: text,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
        queue.dispose();

        expect(spoken, hasLength(1));
        expect(spoken.single, contains('still needs to be paid'));
      },
    );

    test(
      'debit alerts are emitted as debits, never as received payments',
      () async {
        final service = PaymentDetectionService();
        service.debugResetTransientDetectionState();
        final received = expectLater(
          service.onPaymentDetected,
          emits(
            isA<PaymentEvent>()
                .having(
                  (payment) => payment.direction,
                  'direction',
                  PaymentTransactionDirection.outgoingDebit,
                )
                .having(
                  (payment) => payment.decision,
                  'decision',
                  PaymentDecision.likely,
                ),
          ),
        );

        service.handleSms('VM-HDFCBK', 'INR 500 debited from your account');

        await received;
      },
    );

    test(
      'credit alerts remain detectable and pending merchant review',
      () async {
        final service = PaymentDetectionService();
        final received = expectLater(
          service.onPaymentDetected,
          emits(
            isA<PaymentEvent>()
                .having(
                  (payment) => payment.direction,
                  'direction',
                  PaymentTransactionDirection.incomingCredit,
                )
                .having(
                  (payment) => payment.decision,
                  'decision',
                  PaymentDecision.likely,
                ),
          ),
        );

        service.handleSms(
          'VM-HDFCBK',
          'Dear Customer, A/c *1234 credited with INR 500.00 on '
              '29-Sep-26 by UPI/412345678901/Rahul (UPI). '
              'Avl Bal: INR 12500.00 - HDFC Bank',
        );

        await received;
      },
    );

    test(
      'background payment events reach UI-isolate stream listeners',
      () async {
        final service = PaymentDetectionService();
        final event = PaymentEvent(
          id: 'background-payment',
          amount: 250,
          timestamp: DateTime(2026, 10, 9, 10, 11),
          app: PaymentApp.googlePay,
          rawText: '₹250 credited to your account',
        );

        final received = expectLater(
          service.onPaymentDetected,
          emits(
            isA<PaymentEvent>()
                .having((payment) => payment.id, 'id', event.id)
                .having(
                  (payment) => payment.decision,
                  'decision',
                  PaymentDecision.likely,
                ),
          ),
        );
        service.forwardPaymentEvent(event);
        await received;
      },
    );

    test(
      'automatically detected notifications always require confirmation',
      () {
        final notification = PaymentEvent(
          amount: 250,
          timestamp: DateTime(2026, 10, 9, 10, 11),
          app: PaymentApp.googlePay,
          rawText: '₹250 credited to your account',
          decision: PaymentDecision.confirmed,
        );

        final pending = PaymentDetectionService.requireMerchantConfirmation(
          notification,
        );

        expect(pending.decision, PaymentDecision.likely);
      },
    );

    test('merchant-confirmed events remain confirmed', () {
      final confirmed = PaymentEvent(
        amount: 250,
        timestamp: DateTime(2026, 10, 9, 10, 11),
        app: PaymentApp.googlePay,
        rawText: '₹250 credited to your account',
        decision: PaymentDecision.confirmed,
        detectionSource: 'notification:merchant_confirmed',
        verificationStatus: PaymentVerificationStatus.merchantConfirmed,
      );

      expect(
        PaymentDetectionService.requireMerchantConfirmation(confirmed).decision,
        PaymentDecision.confirmed,
      );
    });

    test(
      'merchant approval emits a confirmed incoming credit only once',
      () async {
        final service = PaymentDetectionService();
        final pending = PaymentEvent(
          id: 'manual-approval-payment',
          amount: 250,
          timestamp: DateTime(2026, 10, 9, 10, 11),
          app: PaymentApp.googlePay,
          rawText: '₹250 credited to your account',
          decision: PaymentDecision.likely,
        );
        final received = expectLater(
          service.onPaymentDetected,
          emits(
            isA<PaymentEvent>()
                .having(
                  (payment) => payment.decision,
                  'decision',
                  PaymentDecision.confirmed,
                )
                .having(
                  (payment) => payment.detectionSource,
                  'detectionSource',
                  contains(':merchant_confirmed'),
                ),
          ),
        );

        expect(await service.confirmDetectedPayment(pending), isTrue);
        await received;
        expect(await service.confirmDetectedPayment(pending), isFalse);
      },
    );

    test(
      'merchant approval cannot record a debit notification as received',
      () async {
        final pending = PaymentEvent(
          id: 'manual-approval-debit',
          amount: 250,
          timestamp: DateTime(2026, 10, 9, 10, 11),
          app: PaymentApp.googlePay,
          rawText: '₹250 debited from your account',
          decision: PaymentDecision.likely,
        );

        expect(
          await PaymentDetectionService().confirmDetectedPayment(pending),
          isFalse,
        );
      },
    );

    test('small partial payments match the active bill', () {
      final bill = BillContext()..setExpected(1000);

      expect(bill.evaluate(100), BillMatchResult.partial);
      expect(bill.remainingAmount, 1000);
    });

    test('a five-rupee receipt against a ten-rupee bill remains partial', () {
      final bill = BillContext()..setExpected(10);

      expect(bill.evaluate(5), BillMatchResult.partial);
      bill.recordPartial(5);
      expect(bill.partialReceived, 5);
      expect(bill.remainingAmount, 5);
      expect(bill.evaluate(5), BillMatchResult.exact);
    });

    test(
      'a payment slightly below the due is not treated as fully settled',
      () {
        final bill = BillContext()..setExpected(10);

        expect(bill.evaluate(9), BillMatchResult.partial);
        bill.recordPartial(9);
        expect(bill.remainingAmount, 1);
      },
    );

    test(
      'partial payment announcement includes received and remaining amounts',
      () {
        final pending = PaymentUiState(
          id: 'partial-payment',
          decision: PaymentDecision.likely,
          amount: 5,
          isFailed: false,
          isPartial: true,
          shortfall: 5,
          detectedAt: DateTime(2026, 10, 22),
          rawText: '₹5 credited to your account',
        );
        final confirmed = pending.copyWith(
          decision: PaymentDecision.confirmed,
          isUserConfirmed: true,
        );

        expect(
          pending.voiceText(VoiceLanguage.english),
          contains('₹5 detected'),
        );
        expect(pending.voiceText(VoiceLanguage.english), contains('₹5'));
        expect(
          confirmed.voiceText(VoiceLanguage.english),
          contains('₹5 received. ₹5 still needs to be paid.'),
        );
      },
    );

    test('refreshing a bill total preserves payments already received', () {
      final bill = BillContext()..setExpected(1000);
      bill.recordPartial(100);

      bill.setExpected(1000);

      expect(bill.partialReceived, 100);
      expect(bill.remainingAmount, 900);
      expect(bill.evaluate(200), BillMatchResult.partial);
    });

    test('multiple payments remain matched after total recalculation', () {
      final bill = BillContext()..setExpected(1000);
      bill.recordPartial(250);
      bill.setExpected(1200);

      expect(bill.remainingAmount, 950);
      expect(bill.evaluate(400), BillMatchResult.partial);

      bill.recordPartial(400);
      bill.setExpected(1200);

      expect(bill.partialReceived, 650);
      expect(bill.remainingAmount, 550);
      expect(bill.evaluate(550), BillMatchResult.exact);
    });

    test('starting a new bill clears the previous partial amount', () {
      final bill = BillContext()..setExpected(1000);
      bill.recordPartial(100);
      bill.clear();
      bill.setExpected(1000);

      expect(bill.partialReceived, 0);
      expect(bill.remainingAmount, 1000);
    });
  });

  group('Payment Detection Real World Scenarios', () {
    test('Google Pay Merchant Notification is confirmed and not rejected', () {
      final text = "Received ₹ 250.00 from SHUBHAM KUMAR via Google Pay";
      final event = PaymentDetectionService.analyze(
        text: text,
        source: 'notification',
        sender: null,
        amount: 250.0,
        utr: null,
        vpa: null,
      );
      expect(event.decision, equals(PaymentDecision.confirmed));
      expect(event.confidenceScore, greaterThanOrEqualTo(0.70));
      expect(event.app, equals(PaymentApp.googlePay));
    });

    test('PhonePe Business Notification is confirmed', () {
      final text = "Payment of ₹150 received from Amit on PhonePe";
      final event = PaymentDetectionService.analyze(
        text: text,
        source: 'notification',
        sender: null,
        amount: 150.0,
        utr: null,
        vpa: null,
      );
      expect(event.decision, equals(PaymentDecision.confirmed));
      expect(event.confidenceScore, greaterThanOrEqualTo(0.70));
      expect(event.app, equals(PaymentApp.phonePe));
    });

    test('Paytm Business Notification is confirmed', () {
      final text = "Received ₹500 from Ramesh via Paytm UPI";
      final event = PaymentDetectionService.analyze(
        text: text,
        source: 'notification',
        sender: null,
        amount: 500.0,
        utr: null,
        vpa: null,
      );
      expect(event.decision, equals(PaymentDecision.confirmed));
      expect(event.confidenceScore, greaterThanOrEqualTo(0.70));
      expect(event.app, equals(PaymentApp.paytm));
    });

    test('HDFC Bank SMS is confirmed with high confidence', () {
      final text =
          "Dear Customer, A/c *1234 credited with INR 500.00 on 29-Sep-26 by UPI/412345678901/Rahul (UPI). Avl Bal: INR 12500.00 - HDFC Bank";
      final event = PaymentDetectionService.analyze(
        text: text,
        source: 'sms',
        sender: 'VM-HDFCBK',
        amount: 500.0,
        utr: '412345678901',
        vpa: null,
      );
      expect(event.decision, equals(PaymentDecision.confirmed));
      expect(event.confidenceScore, greaterThanOrEqualTo(0.85));
      expect(event.app, equals(PaymentApp.bankSms));
    });

    test('APGB credit SMS with DLT service suffix is confirmed', () {
      const text = 'Dear Customer, Amount Rs.10 credited to A/c XXXX4222';
      expect(PaymentDetectionService.debugClassify(text), 'passed');
      expect(PaymentDetectionService.debugExtractAmount(text), 10);
      expect(
        PaymentDetectionService.debugIsTrustedBankSmsNotification(
          'com.google.android.apps.messaging',
          'AX-APGB-T',
        ),
        isTrue,
      );
      expect(
        PaymentDetectionService.debugIsTrustedBankSmsNotification(
          'com.unknown.app',
          'AX-APGB-T',
        ),
        isFalse,
      );

      final event = PaymentDetectionService.analyze(
        text: text,
        source: 'sms',
        sender: 'AX-APGB-T',
        amount: 10,
        utr: null,
        vpa: null,
      );

      expect(event.decision, PaymentDecision.confirmed);
      expect(event.confidenceScore, greaterThanOrEqualTo(0.70));
      expect(event.accountSuffix, '4222');
    });

    test('Extraction of amounts with Indian comma formatting', () {
      expect(
        PaymentDetectionService.debugExtractAmount('₹ 1,250 received via UPI'),
        equals(1250.0),
      );
      expect(
        PaymentDetectionService.debugExtractAmount(
          'Received ₹ 250.00 from Amit',
        ),
        equals(250.0),
      );
      expect(
        PaymentDetectionService.debugExtractAmount(
          'Rs. 10,000 credited to account',
        ),
        equals(10000.0),
      );
    });
  });

  group('Payment Announcement and Voice Generation', () {
    test('LanguageEngine resolves all major Indian languages', () {
      final engine = LanguageEngine();
      expect(engine.resolve('en-US').locale, equals('en-IN'));
      expect(engine.resolve('hi-IN').locale, equals('hi-IN'));
      expect(engine.resolve('ta-IN').locale, equals('ta-IN'));
      expect(engine.resolve('te-IN').locale, equals('te-IN'));
      expect(engine.resolve('kn-IN').locale, equals('kn-IN'));
      expect(engine.resolve('mr-IN').locale, equals('mr-IN'));
      expect(engine.resolve('gu-IN').locale, equals('gu-IN'));
      expect(engine.resolve('bn-IN').locale, equals('bn-IN'));
      expect(engine.resolve('pa-IN').locale, equals('pa-IN'));
      expect(engine.resolve('ml-IN').locale, equals('ml-IN'));
    });

    test('VoiceBuilder produces correct phrase in English and Hindi', () {
      final enText = VoiceBuilder.received(250, 'Rahul', VoiceLanguage.english);
      expect(enText, contains('250'));
      expect(enText, contains('Rahul'));

      final hiText = VoiceBuilder.received(500, 'Amit', VoiceLanguage.hindi);
      expect(hiText, contains('पेमेंट मिला'));
      expect(hiText, contains('Amit'));
    });

    test('Humanizer processes payment text into natural speakable chunks', () {
      final humanizer = Humanizer();
      final result = humanizer.process(
        rawText: '250 rupees received from Rahul, thank you',
        style: VoiceStyle.friendly,
        langKey: 'en',
      );
      expect(result.text.isNotEmpty, isTrue);
      expect(result.chunks.isNotEmpty, isTrue);
      expect(result.rate, greaterThan(0.0));
    });
  });

  group('Payment voice dedup direction', () {
    test(
      'same amount debit and credit get different fallback fingerprints',
      () {
        final now = DateTime(2026, 10, 1, 14, 30);

        final debit = PaymentEvent(
          amount: 500,
          timestamp: now,
          app: PaymentApp.phonePe,
          rawText: '₹500 debited from your account',
        );

        final credit = PaymentEvent(
          amount: 500,
          timestamp: now.add(const Duration(minutes: 1)),
          app: PaymentApp.phonePe,
          rawText: '₹500 credited to your account',
        );

        expect(debit.referenceId, isNull);
        expect(credit.referenceId, isNull);
        expect(debit.fingerprint, isNot(equals(credit.fingerprint)));
      },
    );

    test(
      'same amount/time without a reference stays ambiguous for accounting',
      () {
        final now = DateTime(2026, 10, 1, 14, 30);

        final first = PaymentEvent(
          amount: 500,
          timestamp: now,
          app: PaymentApp.phonePe,
          rawText: '₹500 credited to your account',
        );

        final second = PaymentEvent(
          amount: 500,
          timestamp: now.add(const Duration(minutes: 1)),
          app: PaymentApp.phonePe,
          rawText: 'Payment received ₹500',
        );

        expect(first.fingerprint, isNot(equals(second.fingerprint)));
        // Keep looser matching only for voice; it must not become financial
        // transaction identity without an authoritative transaction reference.
        expect(first.voiceFingerprint, equals(second.voiceFingerprint));
      },
    );
  });

  group('Duplicate notification voice protection', () {
    test(
      'identical notification delivered twice has the same voice fingerprint',
      () {
        final now = DateTime(2026, 10, 1, 14, 30);

        final first = PaymentEvent(
          amount: 750,
          timestamp: now,
          app: PaymentApp.phonePe,
          rawText: 'Payment of ₹750 received from Rahul via PhonePe',
        );

        final duplicate = PaymentEvent(
          amount: 750,
          timestamp: now.add(const Duration(seconds: 2)),
          app: PaymentApp.phonePe,
          rawText: 'Payment of ₹750 received from Rahul via PhonePe',
        );

        expect(first.voiceFingerprint, equals(duplicate.voiceFingerprint));
      },
    );

    test('alternate credit wording shares one announcement identity', () {
      final now = DateTime(2026, 10, 1, 14, 30);

      final first = PaymentEvent(
        amount: 750,
        timestamp: now,
        app: PaymentApp.phonePe,
        rawText: 'Payment of ₹750 received from Rahul via PhonePe',
      );

      final other = PaymentEvent(
        amount: 750,
        timestamp: now.add(const Duration(seconds: 4)),
        app: PaymentApp.phonePe,
        rawText: '₹750 credited to your account from Rahul',
      );

      expect(first.voiceFingerprint, equals(other.voiceFingerprint));
    });
  });

  group('Delayed same-notification payment announcement dedup', () {
    PaymentUiState stateFor(PaymentEvent event) => PaymentUiState(
      id: event.id,
      decision: event.decision,
      amount: event.amount,
      isFailed: false,
      detectedAt: event.timestamp,
      rawText: event.rawText,
      direction: event.direction,
      isPartial: event.isPartialPayment,
      shortfall: event.isPartialPayment ? event.remainingAmount : null,
    );

    test('same no-reference partial payment text is not spoken twice after 10 minutes', () async {
      final queue = PriorityVoiceQueue();
      final spoken = <String>[];
      queue.onSpeak = spoken.add;
      final firstTime = DateTime(2026, 10, 26, 12, 0);

      final first = PaymentEvent(
        id: 'partial-credit-first',
        amount: 5,
        timestamp: firstTime,
        app: PaymentApp.phonePe,
        rawText: 'Payment of ₹5 received from Rahul via PhonePe',
        detectionSource: 'notification',
        direction: PaymentTransactionDirection.incomingCredit,
        decision: PaymentDecision.likely,
        isPartialPayment: true,
        remainingAmount: 5,
      );
      final replay = PaymentEvent(
        id: 'partial-credit-reposted',
        amount: 5,
        timestamp: firstTime.add(const Duration(minutes: 10)),
        app: PaymentApp.phonePe,
        rawText: 'Payment of ₹5 received from Rahul via PhonePe',
        detectionSource: 'notification',
        direction: PaymentTransactionDirection.incomingCredit,
        decision: PaymentDecision.likely,
        isPartialPayment: true,
        remainingAmount: 5,
      );

      queue.enqueue(first, stateFor(first));
      queue.enqueue(replay, stateFor(replay));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      queue.dispose();

      expect(spoken, hasLength(1));
    });

    test('different no-reference message remains eligible as a separate payment', () async {
      final queue = PriorityVoiceQueue();
      final spoken = <String>[];
      queue.onSpeak = spoken.add;
      final firstTime = DateTime(2026, 10, 26, 12, 0);

      final first = PaymentEvent(
        id: 'partial-credit-first',
        amount: 5,
        timestamp: firstTime,
        app: PaymentApp.phonePe,
        rawText: 'Payment of ₹5 received from Rahul via PhonePe',
        detectionSource: 'notification',
        direction: PaymentTransactionDirection.incomingCredit,
        decision: PaymentDecision.likely,
      );
      final separate = PaymentEvent(
        id: 'partial-credit-second',
        amount: 5,
        timestamp: firstTime.add(const Duration(minutes: 10)),
        app: PaymentApp.phonePe,
        rawText: 'Payment of ₹5 received from Priya via PhonePe',
        detectionSource: 'notification',
        direction: PaymentTransactionDirection.incomingCredit,
        decision: PaymentDecision.likely,
      );

      queue.enqueue(first, stateFor(first));
      queue.enqueue(separate, stateFor(separate));
      // The queue intentionally spaces announcements by voiceMinGap (2s).
      await Future<void>.delayed(PdsConfig.voiceMinGap + const Duration(milliseconds: 150));
      queue.dispose();

      expect(spoken, hasLength(2));
    });
  });

  group('Payment voice direction', () {
    test('detects credited payment from bank/UPI text', () {
      expect(
        VoiceBuilder.detectDirection(
          'Your A/c is credited with INR 1000 by UPI',
        ),
        equals(PaymentDirection.credited),
      );
      expect(
        VoiceBuilder.detectedDirectional(
          1000,
          VoiceLanguage.english,
          PaymentDirection.credited,
        ),
        contains('credited'),
      );
    });

    test('detects debited payment from bank text', () {
      expect(
        VoiceBuilder.detectDirection('INR 1000 debited from your account'),
        equals(PaymentDirection.debited),
      );
      expect(
        VoiceBuilder.detectedDirectional(
          1000,
          VoiceLanguage.english,
          PaymentDirection.debited,
        ),
        contains('debited'),
      );
    });

    test('credit is not reversed by debit-card wording in the same alert', () {
      const notification =
          'Your account is credited with INR 500. Never share your debit card '
          'PIN or OTP.';

      expect(
        VoiceBuilder.detectDirection(notification),
        equals(PaymentDirection.credited),
      );
      expect(
        PaymentDetectionService.debugClassify(notification),
        equals('passed'),
      );
      expect(
        VoiceBuilder.detectedDirectional(
          500,
          VoiceLanguage.english,
          VoiceBuilder.detectDirection(notification),
        ),
        contains('credited'),
      );
    });

    test('supports incoming payment direction in Indian scripts', () {
      expect(
        VoiceBuilder.detectDirection('మీ ఖాతాలో ₹500 జమ అయింది'),
        equals(PaymentDirection.credited),
      );
      expect(
        VoiceBuilder.detectDirection('आपके खाते में ₹500 जमा'),
        equals(PaymentDirection.credited),
      );
      expect(
        VoiceBuilder.detectDirection('உங்கள் கணக்கில் ₹500 வரவு'),
        equals(PaymentDirection.credited),
      );
      expect(
        VoiceBuilder.detectDirection('તમારા ખાતામાં ₹500 જમા'),
        equals(PaymentDirection.credited),
      );
      expect(
        VoiceBuilder.detectDirection('আপনার অ্যাকাউন্টে ₹500 জমা'),
        equals(PaymentDirection.credited),
      );
      expect(
        VoiceBuilder.detectDirection('ਤੁਹਾਡੇ ਖਾਤੇ ਵਿੱਚ ₹500 ਜਮ੍ਹਾ'),
        equals(PaymentDirection.credited),
      );
      expect(
        VoiceBuilder.detectDirection('നിങ്ങളുടെ അക്കൗണ്ടിൽ ₹500 ലഭിച്ചു'),
        equals(PaymentDirection.credited),
      );
    });

    test('supports outgoing payment direction in Indian scripts', () {
      expect(
        VoiceBuilder.detectDirection('మీ ఖాతా నుండి ₹500 డెబిట్'),
        equals(PaymentDirection.debited),
      );
      expect(
        VoiceBuilder.detectDirection('आपके खाते से ₹500 डेबिट'),
        equals(PaymentDirection.debited),
      );
      expect(
        VoiceBuilder.detectDirection('உங்கள் கணக்கിൽ ₹500 பற்று'),
        equals(PaymentDirection.debited),
      );
      expect(
        VoiceBuilder.detectDirection('તમારા ખાતામાં ₹500 ડેબિટ'),
        equals(PaymentDirection.debited),
      );
      expect(
        VoiceBuilder.detectDirection('আপনার অ্যাকাউন্টে ₹500 ডেবিট'),
        equals(PaymentDirection.debited),
      );
      expect(
        VoiceBuilder.detectDirection('ਤੁਹਾਡੇ ਖਾਤੇ ਵਿੱਚ ₹500 ਡੈਬਿਟ'),
        equals(PaymentDirection.debited),
      );
      expect(
        VoiceBuilder.detectDirection('നിങ്ങളുടെ അക്കൗണ്ടിൽ ₹500 ഡെബിറ്റ്'),
        equals(PaymentDirection.debited),
      );
    });

    test('ambiguous text is never mislabeled as credit or debit', () {
      expect(
        VoiceBuilder.detectDirection('Payment of INR 1000'),
        equals(PaymentDirection.unknown),
      );
      expect(
        VoiceBuilder.detectedDirectional(
          1000,
          VoiceLanguage.english,
          PaymentDirection.unknown,
        ),
        contains('detected'),
      );
    });

    test(
      'localized payment announcements preserve credit and debit direction',
      () {
        expect(
          VoiceBuilder.receivedDirectional(
            500,
            null,
            VoiceLanguage.telugu,
            PaymentDirection.credited,
          ),
          contains('జమ'),
        );
        expect(
          VoiceBuilder.receivedDirectional(
            500,
            null,
            VoiceLanguage.telugu,
            PaymentDirection.debited,
          ),
          contains('డెబిట్'),
        );
        expect(
          PaymentDetectionService.debugClassify(
            'INR 1000 debited from your account',
          ),
          equals('debit'),
        );
        expect(
          PaymentDetectionService.debugClassify(
            'আপনার অ্যাকাউন্ট থেকে ₹500 কেটে নেওয়া হয়েছে',
          ),
          equals('debit'),
        );
        expect(
          VoiceBuilder.detectDirection('₹500 sent to your account from Rahul'),
          equals(PaymentDirection.credited),
        );
      },
    );

    test(
      'only directional transactions pass; promotional offers are ignored',
      () {
        expect(
          PaymentDetectionService.debugClassify(
            '₹500 credited to your account',
          ),
          'passed',
        );
        expect(
          PaymentDetectionService.debugClassify(
            'You paid ₹500 to Rahul using UPI',
          ),
          'debit',
        );
        expect(
          PaymentDetectionService.debugClassify(
            'Get ₹100 cashback on your next PhonePe payment. Exclusive offer!',
          ),
          'junk',
        );
        expect(
          PaymentDetectionService.debugClassify(
            'Your PhonePe account is eligible for an offer worth ₹500',
          ),
          'junk',
        );
      },
    );

    test(
      'same credit or debit transaction is announced once across text variants',
      () async {
        Future<List<String>> announceDuplicates({
          required String firstText,
          required String secondText,
        }) async {
          final queue = PriorityVoiceQueue();
          final spoken = <String>[];
          queue.onSpeak = spoken.add;
          final time = DateTime(2026, 10, 1, 14, 30);
          final first = PaymentEvent(
            amount: 500,
            timestamp: time,
            app: PaymentApp.phonePe,
            rawText: firstText,
          );
          final second = PaymentEvent(
            amount: 500,
            timestamp: time.add(const Duration(seconds: 2)),
            app: PaymentApp.phonePe,
            rawText: secondText,
          );

          PaymentUiState stateFor(PaymentEvent event) => PaymentUiState(
            id: event.id,
            decision: PaymentDecision.confirmed,
            amount: event.amount,
            isFailed: false,
            detectedAt: event.timestamp,
            rawText: event.rawText,
          );

          queue.enqueue(first, stateFor(first));
          queue.enqueue(second, stateFor(second));
          await Future<void>.delayed(const Duration(milliseconds: 100));
          queue.dispose();
          return spoken;
        }

        final credits = await announceDuplicates(
          firstText: '₹500 credited to your account',
          secondText: 'Payment of ₹500 received',
        );
        final debits = await announceDuplicates(
          firstText: '₹500 debited from your account',
          secondText: 'INR 500 was debited',
        );

        expect(credits, hasLength(1));
        expect(credits.single, contains('credited'));
        expect(debits, hasLength(1));
        expect(debits.single, contains('debited'));
      },
    );

  test('recognized PhonePe DLT sender credit stays pending for merchant review', () async {
    final service = PaymentDetectionService();
    service.clearBill();
    service.setBillExpected(10);

    final received = expectLater(
      service.onPaymentDetected,
      emits(
        isA<PaymentEvent>()
            .having((payment) => payment.amount, 'amount', 5)
            .having(
              (payment) => payment.direction,
              'direction',
              PaymentTransactionDirection.incomingCredit,
            )
            .having(
              (payment) => payment.decision,
              'decision',
              PaymentDecision.likely,
            ),
      ),
    );

    service.handleSms(
      'VM-PHONEPE',
      'Your UPI credit of Rs.5 was received in your account',
    );
    await received;
    service.clearBill();
  });

  test('short trusted PhonePe notification is a review candidate, not an auto-credit', () async {
    final service = PaymentDetectionService();
    service.debugResetTransientDetectionState();
    service.clearBill();
    service.setBillExpected(10);

    final received = expectLater(
      service.onPaymentDetected,
      emits(
        isA<PaymentEvent>()
            .having((payment) => payment.amount, 'amount', 5)
            .having(
              (payment) => payment.direction,
              'direction',
              PaymentTransactionDirection.incomingCredit,
            )
            .having(
              (payment) => payment.decision,
              'decision',
              PaymentDecision.likely,
            )
            .having(
              (payment) => payment.isMerchantConfirmed,
              'merchantConfirmed',
              isFalse,
            ),
      ),
    );

    service.debugHandleNotification(
      ServiceNotificationEvent(
        packageName: 'com.phonepe.app',
        title: 'PhonePe',
        content: 'UPI credit ₹5 received',
      ),
    );
    await received;
    service.clearBill();
  });


  test('does not suppress same-amount cross-channel payments to different accounts', () async {
    final queue = PriorityVoiceQueue();
    final spoken = <String>[];
    queue.onSpeak = spoken.add;

    final now = DateTime.now();
    final first = PaymentEvent(
      id: 'phonepe-account-1111',
      amount: 500,
      timestamp: now,
      app: PaymentApp.phonePe,
      rawText: '₹500 credited to account 1111',
      accountSuffix: '1111',
      detectionSource: 'notification',
      direction: PaymentTransactionDirection.incomingCredit,
      decision: PaymentDecision.likely,
    );
    final second = PaymentEvent(
      id: 'truecaller-account-2222',
      amount: 500,
      timestamp: now.add(const Duration(seconds: 2)),
      app: PaymentApp.bankApp,
      rawText: 'UPI transfer to account 2222 +₹500',
      accountSuffix: '2222',
      detectionSource: 'truecaller_notification',
      direction: PaymentTransactionDirection.incomingCredit,
      decision: PaymentDecision.likely,
    );

    PaymentUiState stateFor(PaymentEvent event) => PaymentUiState(
      id: event.id,
      decision: event.decision,
      amount: event.amount,
      isFailed: false,
      detectedAt: event.timestamp,
      rawText: event.rawText,
      direction: event.direction,
    );

    queue.enqueue(first, stateFor(first));
    queue.enqueue(second, stateFor(second));
    await Future<void>.delayed(PdsConfig.voiceMinGap + const Duration(milliseconds: 150));
    queue.dispose();

    expect(spoken, hasLength(2));
  });

  test('suppresses a PhonePe credit replayed by Truecaller ten minutes later', () async {
    final queue = PriorityVoiceQueue();
    final spoken = <String>[];
    queue.onSpeak = spoken.add;
    final firstTime = DateTime(2026, 10, 1, 14, 30);

    final phonePe = PaymentEvent(
      id: 'phonepe-credit',
      amount: 5,
      timestamp: firstTime,
      app: PaymentApp.phonePe,
      rawText: 'You received ₹5 from Rahul to account 4222',
      accountSuffix: '4222',
      detectionSource: 'notification',
      direction: PaymentTransactionDirection.incomingCredit,
      decision: PaymentDecision.likely,
    );
    final truecaller = PaymentEvent(
      id: 'truecaller-credit',
      amount: 5,
      timestamp: firstTime.add(const Duration(minutes: 10)),
      app: PaymentApp.bankApp,
      rawText: 'UPI transfer from Apgbank to Account 4222 +₹5',
      accountSuffix: '4222',
      detectionSource: 'truecaller_notification',
      direction: PaymentTransactionDirection.incomingCredit,
      decision: PaymentDecision.likely,
    );

    PaymentUiState stateFor(PaymentEvent event) => PaymentUiState(
      id: event.id,
      decision: event.decision,
      amount: event.amount,
      isFailed: false,
      detectedAt: event.timestamp,
      rawText: event.rawText,
      direction: event.direction,
    );

    queue.enqueue(phonePe, stateFor(phonePe));
    queue.enqueue(truecaller, stateFor(truecaller));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    queue.dispose();

    expect(spoken, hasLength(1));
    expect(spoken.single, contains('credited'));
  });

  test('duplicate and reference-conflict events are not announced', () async {
    final queue = PriorityVoiceQueue();
    final spoken = <String>[];
    queue.onSpeak = spoken.add;
    final event = PaymentEvent(
      id: 'duplicate-credit',
      amount: 5,
      timestamp: DateTime(2026, 10, 1, 14, 30),
      app: PaymentApp.phonePe,
      rawText: 'You received ₹5 from Rahul',
      direction: PaymentTransactionDirection.incomingCredit,
      decision: PaymentDecision.likely,
      isDuplicate: true,
    );
    final conflict = event.copyWith(
      id: 'conflicting-credit',
      isDuplicate: false,
      hasReferenceConflict: true,
    );

    PaymentUiState stateFor(PaymentEvent payment) => PaymentUiState(
      id: payment.id,
      decision: payment.decision,
      amount: payment.amount,
      isFailed: false,
      detectedAt: payment.timestamp,
      rawText: payment.rawText,
      direction: payment.direction,
    );

    queue.enqueue(event, stateFor(event));
    queue.enqueue(conflict, stateFor(conflict));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    queue.dispose();

    expect(spoken, isEmpty);
  });

    test('one transfer arriving as notification and SMS emits one event', () async {
      final service = PaymentDetectionService();
      service.debugResetTransientDetectionState();
      final events = <PaymentEvent>[];
      final subscription = service.onPaymentDetected.listen(events.add);
      final timestamp = DateTime.now();

      await service.debugEmitForTesting(
        PaymentEvent(
          id: 'apgb-notification-credit',
          amount: 5,
          timestamp: timestamp,
          app: PaymentApp.bankApp,
          accountSuffix: '4222',
          rawText: 'Verified Business + ₹5 UPI transfer from Apgbank to Account 4222',
          detectionSource: 'notification',
          direction: PaymentTransactionDirection.incomingCredit,
          decision: PaymentDecision.likely,
        ),
      );
      await service.debugEmitForTesting(
        PaymentEvent(
          id: 'apgb-sms-credit',
          amount: 5,
          timestamp: timestamp.add(const Duration(seconds: 5)),
          app: PaymentApp.bankSms,
          accountSuffix: '4222',
          rawText: 'An amount of Rs.5 credited to A/c XXXX4222',
          detectionSource: 'sms',
          direction: PaymentTransactionDirection.incomingCredit,
          decision: PaymentDecision.likely,
        ),
      );

      expect(events, hasLength(1));
      expect(events.single.amount, 5);
      expect(events.single.isMerchantConfirmed, isFalse);
      await subscription.cancel();
    });

    test('different UTRs are not merged even when amount and account match', () async {
      final service = PaymentDetectionService();
      service.debugResetTransientDetectionState();
      final events = <PaymentEvent>[];
      final subscription = service.onPaymentDetected.listen(events.add);
      final timestamp = DateTime.now();

      await service.debugEmitForTesting(
        PaymentEvent(
          id: 'transfer-utr-1',
          amount: 5,
          timestamp: timestamp,
          app: PaymentApp.bankApp,
          referenceId: '123456789012',
          accountSuffix: '4222',
          rawText: '₹5 credited to A/c XXXX4222 UTR 123456789012',
          detectionSource: 'notification',
          direction: PaymentTransactionDirection.incomingCredit,
          decision: PaymentDecision.likely,
        ),
      );
      await service.debugEmitForTesting(
        PaymentEvent(
          id: 'transfer-utr-2',
          amount: 5,
          timestamp: timestamp.add(const Duration(seconds: 5)),
          app: PaymentApp.bankSms,
          referenceId: '123456789013',
          accountSuffix: '4222',
          rawText: '₹5 credited to A/c XXXX4222 UTR 123456789013',
          detectionSource: 'sms',
          direction: PaymentTransactionDirection.incomingCredit,
          decision: PaymentDecision.likely,
        ),
      );

      expect(events, hasLength(2));
      expect(
        events.map((event) => event.normalizedReferenceId).toSet(),
        {'123456789012', '123456789013'},
      );
      await subscription.cancel();
    });

    test('refund, reversal, pending and collect-request alerts cannot classify as incoming sale payments', () {
      expect(
        PaymentDetectionService.debugClassify(
          'Refund of Rs.500 credited to your account',
        ),
        'fraud',
      );
      expect(
        PaymentDetectionService.debugClassify(
          '₹500 payment received but transaction reversed',
        ),
        'fraud',
      );
      expect(
        PaymentDetectionService.debugClassify(
          'Payment received ₹500, status pending',
        ),
        'fraud',
      );
      expect(
        PaymentDetectionService.debugClassify(
          'Collect request for ₹500. Please approve the request.',
        ),
        'fraud',
      );
      // The non-income guard must not break real debit direction detection.
      expect(
        PaymentDetectionService.debugClassify('₹200 debited from your account'),
        'debit',
      );
    });

    test('sale confirmation gate rejects refund-credit wording', () {
      final refundEvent = PaymentEvent(
        amount: 500,
        timestamp: DateTime.now(),
        app: PaymentApp.phonePe,
        rawText: 'Refund of Rs.500 credited to your account',
        detectionSource: 'notification',
        direction: PaymentTransactionDirection.incomingCredit,
        decision: PaymentDecision.likely,
      );

      expect(PaymentDetectionService.isSafeIncomingCredit(refundEvent), isFalse);
    });

    test('unknown app named like a UPI app cannot bypass reference/account anchor', () async {
      final service = PaymentDetectionService();
      service.debugResetTransientDetectionState();
      final events = <PaymentEvent>[];
      final subscription = service.onPaymentDetected.listen(events.add);

      service.debugHandleNotification(
        ServiceNotificationEvent(
          packageName: 'com.fake.upi',
          title: 'UPI Pay',
          content: 'Payment received ₹5000 from Rahul',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(events, isEmpty);
      await subscription.cancel();
      service.debugResetTransientDetectionState();
    });

    test('likely voice wording describes a possible transaction, not confirmed settlement', () {
      final credit = VoiceBuilder.detectedDirectional(
        500,
        VoiceLanguage.english,
        PaymentDirection.credited,
      );
      final debit = VoiceBuilder.detectedDirectional(
        500,
        VoiceLanguage.english,
        PaymentDirection.debited,
      );

      expect(credit, contains('may have been credited'));
      expect(credit, contains('verify before marking paid'));
      expect(debit, contains('may have been debited'));
    });

  });
}
