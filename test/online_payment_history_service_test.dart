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
    String id = 'payment-1',
    double amount = 125.50,
    DateTime? timestamp,
  }) => PaymentEvent(
    id: id,
    amount: amount,
    timestamp: timestamp ?? DateTime(2026, 10, 22, 9),
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
      expect(records.single['merchant_confirmed'], isTrue);
      expect(records.single['verified'], isFalse);
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
    expect(records.single['merchant_confirmed'], isTrue);
    expect(records.single['verified'], isFalse);
  });

  test('marks same-reference amount conflicts for review instead of replacing history', () async {
    await OnlinePaymentHistoryService.recordIncomingPayment(
      event(amount: 125.50, id: 'initial-confirmed'),
    );

    final accepted = await OnlinePaymentHistoryService.recordIncomingPayment(
      event(
        amount: 200,
        id: 'conflicting-alert',
        timestamp: DateTime(2026, 10, 22, 9, 1),
      ),
    );

    expect(accepted, isFalse);
    final records = await OnlinePaymentHistoryService.load();
    expect(records, hasLength(1));
    expect(records.single['status'], 'CONFLICT_REVIEW');
    expect(records.single['merchant_confirmed'], isFalse);
    expect(records.single['verified'], isFalse);
    expect(records.single['conflicting_amounts'], [125.5, 200.0]);
  });

  test('keeps locally unverified history out of the verified state', () async {
    await OnlinePaymentHistoryService.recordIncomingPayment(
      event(verification: PaymentVerificationStatus.unverified),
    );

    final records = await OnlinePaymentHistoryService.load();
    expect(records.single['status'], 'PENDING_CONFIRMATION');
    expect(records.single['merchant_confirmed'], isFalse);
    expect(records.single['verified'], isFalse);
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
