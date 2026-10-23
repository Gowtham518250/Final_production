import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:retail_mind/payment_detection_service.dart';
import 'package:retail_mind/payment_event.dart';
import 'package:retail_mind/smart_payment_matcher_service.dart';
import 'package:retail_mind/transaction_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'user_id': 42});
  });

  group('detected transaction direction', () {
    test('accepts an explicit incoming credit for merchant review', () {
      expect(
        TransactionService.classifyDetectedMessage(
          '₹500 received from a customer',
        ),
        DetectedPaymentDirection.incoming,
      );
      expect(
        TransactionService.transactionTypeForDetectedMessage(
          '₹500 received from a customer',
        ),
        TransactionType.likely,
      );
    });

    test(
      'classifies outgoing, pending, failed, and ambiguous notices safely',
      () {
        expect(
          TransactionService.classifyDetectedMessage(
            '₹500 debited from your account',
          ),
          DetectedPaymentDirection.outgoing,
        );
        expect(
          TransactionService.classifyDetectedMessage('₹500 sent to 9876543210'),
          DetectedPaymentDirection.outgoing,
        );
        expect(
          TransactionService.classifyDetectedMessage('₹500 payment processing'),
          DetectedPaymentDirection.pending,
        );
        expect(
          TransactionService.classifyDetectedMessage('₹500 credit failed'),
          DetectedPaymentDirection.failed,
        );
        expect(
          TransactionService.classifyDetectedMessage(
            '₹500 debited then credited back',
          ),
          DetectedPaymentDirection.pending,
        );
        expect(
          TransactionService.classifyDetectedMessage(
            'Payment successful for ₹500',
          ),
          DetectedPaymentDirection.pending,
        );
      },
    );

    test('parser does not interpret unqualified transfers as incoming', () {
      final outgoing = TransactionService.parseUpiNotification(
        '₹500 transferred to 9876543210',
        'GooglePay',
      );
      final unclear = TransactionService.parseSmsBanking(
        '₹500 transaction successful',
      );

      expect(outgoing?.type, 'PAID');
      expect(outgoing?.transactionType, TransactionType.pending);
      expect(unclear?.type, 'PENDING');
      expect(unclear?.transactionType, TransactionType.pending);
    });
  });

  group('transaction persistence safety', () {
    test('does not persist an unverified detected transaction', () async {
      final detected = _incomingTransaction(
        id: 'unverified',
        verificationStatus: TransactionVerificationStatus.unverified,
      );

      await expectLater(
        TransactionService.saveTransaction(detected),
        throwsA(isA<StateError>()),
      );
      expect(await TransactionService.loadTransactions(), isEmpty);
    });

    test('merchant confirmation persists actor, method, and status', () async {
      final detected = _incomingTransaction(id: 'merchant-confirmed');

      final saved = await TransactionService.confirmDetectedIncoming(detected);
      final loaded = await TransactionService.loadTransactions();

      expect(saved.type, 'RECEIVED');
      expect(saved.transactionType, TransactionType.confirmed);
      expect(
        saved.verificationStatus,
        TransactionVerificationStatus.merchantConfirmed,
      );
      expect(saved.verifiedBy, '42');
      expect(saved.verifiedAt, isNotNull);
      expect(saved.notes, contains('not bank-verified'));
      expect(loaded, hasLength(1));
    });

    test(
      'confirmation upgrades a previously stored unverified event by ID',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final oldEvent = _incomingTransaction(
          id: 'old-unverified-event',
          verificationStatus: TransactionVerificationStatus.unverified,
        );
        await prefs.setString(
          'transactions_v1',
          jsonEncode([oldEvent.toJson()]),
        );

        await TransactionService.confirmDetectedIncoming(oldEvent);

        final loaded = await TransactionService.loadTransactions();
        expect(loaded, hasLength(1));
        expect(
          loaded.single.verificationStatus,
          TransactionVerificationStatus.merchantConfirmed,
        );
      },
    );

    test('concurrent retries write one transaction for the same ID', () async {
      final txn = _incomingTransaction(
        id: 'concurrent-manual',
        verificationStatus: TransactionVerificationStatus.manualEntry,
      );

      await Future.wait([
        TransactionService.saveTransaction(txn),
        TransactionService.saveTransaction(txn),
      ]);

      expect(await TransactionService.loadTransactions(), hasLength(1));
    });

    test('failed, outgoing, or ambiguous alerts cannot be confirmed', () async {
      for (final rawMessage in [
        '₹500 debited from your account',
        '₹500 credit failed',
        '₹500 debited and credited back',
      ]) {
        final transaction = _incomingTransaction(
          id: rawMessage,
          rawMessage: rawMessage,
        );

        await expectLater(
          TransactionService.confirmDetectedIncoming(transaction),
          throwsA(isA<StateError>()),
        );
      }
      expect(await TransactionService.loadTransactions(), isEmpty);
    });
  });

  test(
    'exact amount/time match conflicts are not assigned to one sale',
    () async {
      final payment = Transaction(
        id: 'same-amount-match',
        source: 'GooglePay',
        name: 'Rahul',
        amount: 500,
        type: 'RECEIVED',
        transactionType: TransactionType.likely,
        reference: 'UPI12345',
        createdAt: DateTime(2026, 10, 21, 10),
        rawMessage: '₹500 received from Rahul',
      );
      final saleDate = DateTime(2026, 10, 21, 10).toIso8601String();
      final sales = [
        {
          'id': 'sale-a',
          'user_id': 42,
          'total': 500,
          'date': saleDate,
          'customer_name': 'Rahul',
        },
        {
          'id': 'sale-b',
          'user_id': 42,
          'total': 500,
          'date': saleDate,
          'customer_name': 'Rahul',
        },
      ];

      final result = await SmartPaymentMatcherService.matchPaymentToSale(
        payment,
        sales,
      );

      expect(result.conflicts, hasLength(2));
      expect(result.details.containsKey('matched_sale_id'), isFalse);
      expect(result.status, 'MANUAL_REVIEW');
    },
  );

  test('high matching score still requires merchant confirmation', () async {
    final matchedAt = DateTime(2026, 10, 21, 10);
    final payment = Transaction(
      id: 'high-score-payment',
      source: 'GooglePay',
      name: 'Rahul Kumar',
      phone: '9876543210',
      amount: 500,
      type: 'RECEIVED',
      transactionType: TransactionType.likely,
      reference: 'UPI67890',
      createdAt: matchedAt,
      rawMessage: '₹500 received from Rahul Kumar',
    );
    final result = await SmartPaymentMatcherService.matchPaymentToSale(
      payment,
      [
        {
          'id': 'matched-sale',
          'user_id': 42,
          'total': 500,
          'date': matchedAt.toIso8601String(),
          'customer_name': 'Rahul Kumar',
          'customer_phone': '9876543210',
        },
      ],
    );

    expect(result.score, 100);
    expect(result.status, 'NEEDS_CONFIRMATION');
    expect(result.reason, contains('verify receipt'));
  });

  group('confirmation manager guard', () {
    test('a source label cannot impersonate merchant confirmation', () {
      final event = PaymentEvent(
        id: 'forged-confirmation-label',
        amount: 250,
        timestamp: DateTime(2026, 10, 21),
        app: PaymentApp.googlePay,
        rawText: '₹250 credited to your account',
        detectionSource: 'notification:merchant_confirmed',
        decision: PaymentDecision.confirmed,
      );

      final guarded = PaymentDetectionService.requireMerchantConfirmation(
        event,
      );

      expect(guarded.decision, PaymentDecision.likely);
      expect(guarded.isMerchantConfirmed, isFalse);
    });

    test('failed events cannot retain merchant-confirmed status', () {
      final event = PaymentEvent(
        id: 'failed-merchant-confirmation',
        amount: 250,
        timestamp: DateTime(2026, 10, 21),
        app: PaymentApp.googlePay,
        rawText: '₹250 credit failed',
        isFailed: true,
        detectionSource: 'notification:merchant_confirmed',
        verificationStatus: PaymentVerificationStatus.merchantConfirmed,
        decision: PaymentDecision.confirmed,
      );

      final guarded =
          PaymentDetectionService.requireMerchantConfirmation(event);

      expect(guarded.decision, PaymentDecision.rejected);
      expect(guarded.isMerchantConfirmed, isFalse);
    });

    test(
      'rejects a debit even when the caller invokes the legacy confirm API',
      () {
        final event = PaymentEvent(
          id: 'manager-debit',
          amount: 250,
          timestamp: DateTime(2026, 10, 21),
          app: PaymentApp.googlePay,
          rawText: '₹250 debited from your account',
          decision: PaymentDecision.likely,
        );
        final manager = ConfirmationManager();
        manager.add(event, _paymentUiState(event));

        expect(manager.confirm(event.id), isNull);
      },
    );

    test(
      'promotes only incoming credits and marks them merchant-confirmed',
      () {
        final event = PaymentEvent(
          id: 'manager-credit',
          amount: 250,
          timestamp: DateTime(2026, 10, 21),
          app: PaymentApp.googlePay,
          rawText: '₹250 credited to your account',
          decision: PaymentDecision.likely,
        );
        final manager = ConfirmationManager();
        manager.add(event, _paymentUiState(event));

        final confirmed = manager.confirm(event.id);

        expect(confirmed?.isMerchantConfirmed, isTrue);
        expect(confirmed?.decision, PaymentDecision.confirmed);
        expect(
          PaymentEvent.fromJson(confirmed!.toJson()).isMerchantConfirmed,
          isTrue,
        );
      },
    );
  });
}

Transaction _incomingTransaction({
  required String id,
  String rawMessage = '₹500 received from Rahul',
  TransactionVerificationStatus verificationStatus =
      TransactionVerificationStatus.unverified,
}) {
  return Transaction(
    id: id,
    source: 'GooglePay',
    name: 'Rahul',
    amount: 500,
    type: 'RECEIVED',
    transactionType:
        verificationStatus == TransactionVerificationStatus.manualEntry
        ? TransactionType.confirmed
        : TransactionType.likely,
    rawMessage: rawMessage,
    reference: null,
    createdAt: DateTime(2026, 10, 21, 10),
    verificationStatus: verificationStatus,
  );
}

PaymentUiState _paymentUiState(PaymentEvent event) => PaymentUiState(
  id: event.id,
  decision: event.decision,
  amount: event.amount,
  isFailed: event.isFailed,
  detectedAt: event.timestamp,
  rawText: event.rawText,
);
