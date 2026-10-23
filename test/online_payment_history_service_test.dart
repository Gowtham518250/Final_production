import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:retail_mind/payment_event.dart';
import 'package:retail_mind/online_payment_history_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'user_id': 72});
  });

  PaymentEvent event({
    PaymentDecision decision = PaymentDecision.confirmed,
    PaymentVerificationStatus verification =
        PaymentVerificationStatus.merchantConfirmed,
    PaymentTransactionDirection direction =
        PaymentTransactionDirection.incomingCredit,
    bool isFailed = false,
    bool isDuplicate = false,
    String referenceId = 'UTR-12345',
  }) => PaymentEvent(
    id: 'payment-1',
    amount: 125.50,
    timestamp: DateTime(2026, 10, 22, 9),
    app: PaymentApp.phonePe,
    referenceId: referenceId,
    rawText: 'Sensitive notification text should never be persisted',
    decision: decision,
    verificationStatus: verification,
    direction: direction,
    isFailed: isFailed,
    isDuplicate: isDuplicate,
  );

  test(
    'stores incoming credits as pending until merchant confirmation',
    () async {
      expect(
        await OnlinePaymentHistoryService.recordIncomingPayment(
          event(verification: PaymentVerificationStatus.unverified),
        ),
        isTrue,
      );
      expect(
        await OnlinePaymentHistoryService.recordIncomingPayment(
          event(direction: PaymentTransactionDirection.outgoingDebit),
        ),
        isFalse,
      );
      expect(
        await OnlinePaymentHistoryService.recordIncomingPayment(
          event(isFailed: true),
        ),
        isFalse,
      );

      expect(
        await OnlinePaymentHistoryService.recordIncomingPayment(event()),
        isTrue,
      );

      final records = await OnlinePaymentHistoryService.load();
      expect(records, hasLength(1));
      expect(records.single['amount'], 125.50);
      expect(records.single['app'], 'PhonePe');
      expect(records.single['verified'], isTrue);
      expect(records.single['status'], 'CONFIRMED');
      expect(records.single.containsKey('rawText'), isFalse);
      expect(records.single.containsKey('referenceId'), isFalse);
    },
  );

  test('promotes a pending detection when it is confirmed', () async {
    await OnlinePaymentHistoryService.recordIncomingPayment(
      event(verification: PaymentVerificationStatus.unverified),
    );
    var records = await OnlinePaymentHistoryService.load();
    expect(records, hasLength(1));
    expect(records.single['status'], 'PENDING_CONFIRMATION');

    await OnlinePaymentHistoryService.recordIncomingPayment(event());
    records = await OnlinePaymentHistoryService.load();

    expect(records, hasLength(1));
    expect(records.single['status'], 'CONFIRMED');
    expect(records.single['verified'], isTrue);
  });

  test('does not store rejected or outgoing payments', () async {
    expect(
      await OnlinePaymentHistoryService.recordIncomingPayment(
        event(decision: PaymentDecision.rejected),
      ),
      isFalse,
    );
    expect(
      await OnlinePaymentHistoryService.recordIncomingPayment(
        event(direction: PaymentTransactionDirection.outgoingDebit),
      ),
      isFalse,
    );
    expect(await OnlinePaymentHistoryService.load(), isEmpty);
  });
}
