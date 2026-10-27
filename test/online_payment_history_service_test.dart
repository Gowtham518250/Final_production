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
    String? referenceId = 'UTR-12345',
    String id = 'payment-1',
    double amount = 125.50,
    DateTime? timestamp,
    DateTime? sourceTimestamp,
    String? sourceEventKey,
    PaymentApp app = PaymentApp.phonePe,
    String detectionSource = 'notification',
    String? payerName,
    String rawText = 'Sensitive notification text should never be persisted',
  }) => PaymentEvent(
    id: id,
    amount: amount,
    timestamp: timestamp ?? DateTime(2026, 10, 22, 9),
    sourceTimestamp: sourceTimestamp,
    sourceEventKey: sourceEventKey,
    app: app,
    referenceId: referenceId,
    payerName: payerName,
    rawText: rawText,
    detectionSource: detectionSource,
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
          event(decision: PaymentDecision.likely,
          verification: PaymentVerificationStatus.unverified),
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
      event(decision: PaymentDecision.likely,
          verification: PaymentVerificationStatus.unverified),
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
    expect(await OnlinePaymentHistoryService.hasReferenceConflict(
      event(amount: 125.50, id: 'third-notification'),
    ), isTrue);
  });


  test('replayed same reference after a delay is marked duplicate across restarts', () async {
    await OnlinePaymentHistoryService.recordIncomingPayment(
      event(id: 'phonepe-first'),
    );

    final replay = await OnlinePaymentHistoryService.annotateKnownReferenceState(
      event(
        id: 'truecaller-late-replay',
        timestamp: DateTime(2026, 10, 22, 9, 10),
      ),
    );

    expect(replay.isDuplicate, isTrue);
    expect(replay.hasReferenceConflict, isFalse);
    final records = await OnlinePaymentHistoryService.load();
    expect(records, hasLength(1));
    expect(records.single['status'], 'CONFIRMED');
  });

  test('merchant rejection persists and prevents the same reference reopening review', () async {
    final candidate = event(
      id: 'rejected-candidate',
      decision: PaymentDecision.likely,
      verification: PaymentVerificationStatus.unverified,
      timestamp: DateTime.now(),
    );
    await OnlinePaymentHistoryService.recordIncomingPayment(candidate);

    expect(
      await OnlinePaymentHistoryService.rejectPendingPayment(candidate),
      isTrue,
    );

    final replay = await OnlinePaymentHistoryService.annotateKnownReferenceState(
      event(
        id: 'same-reference-replay',
        decision: PaymentDecision.likely,
        verification: PaymentVerificationStatus.unverified,
        timestamp: DateTime.now().add(const Duration(hours: 8)),
      ),
    );
    expect(replay.isDuplicate, isTrue);
    expect(
      await OnlinePaymentHistoryService.recordIncomingPayment(replay),
      isFalse,
    );

    final records = await OnlinePaymentHistoryService.load();
    expect(records, hasLength(1));
    expect(records.single['status'], 'REJECTED');
    expect(records.single['merchant_confirmed'], isFalse);
  });

  test('unresolved pending reference resurfaces as a review reminder after six hours', () async {
    final detectedAt = DateTime.now().subtract(const Duration(hours: 7));
    await OnlinePaymentHistoryService.recordIncomingPayment(
      event(
        id: 'night-payment',
        decision: PaymentDecision.likely,
        verification: PaymentVerificationStatus.unverified,
        timestamp: detectedAt,
      ),
    );

    final morning = await OnlinePaymentHistoryService.annotateKnownReferenceState(
      event(
        id: 'morning-payment',
        decision: PaymentDecision.likely,
        verification: PaymentVerificationStatus.unverified,
        timestamp: DateTime.now(),
      ),
    );

    expect(morning.isDuplicate, isFalse);
    expect(morning.decision, PaymentDecision.likely);
    expect(morning.verificationStatus, PaymentVerificationStatus.unverified);
    expect(
      morning.detectionSource,
      contains(':pending_review_reminder'),
    );
  });

  test('unresolved pending reference is coalesced during six-hour cooldown', () async {
    await OnlinePaymentHistoryService.recordIncomingPayment(
      event(
        id: 'night-payment',
        decision: PaymentDecision.likely,
        verification: PaymentVerificationStatus.unverified,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    );

    final replay = await OnlinePaymentHistoryService.annotateKnownReferenceState(
      event(
        id: 'same-morning-replay',
        decision: PaymentDecision.likely,
        verification: PaymentVerificationStatus.unverified,
        timestamp: DateTime.now(),
      ),
    );

    expect(replay.isDuplicate, isTrue);
    expect(replay.detectionSource, isNot(contains(':pending_review_reminder')));
  });

  test('delayed same-reference different amount is flagged for review', () async {
    await OnlinePaymentHistoryService.recordIncomingPayment(
      event(id: 'phonepe-first', amount: 125.50),
    );

    final replay = await OnlinePaymentHistoryService.annotateKnownReferenceState(
      event(
        id: 'truecaller-conflict',
        amount: 200,
        timestamp: DateTime(2026, 10, 22, 9, 10),
      ),
    );

    expect(replay.isDuplicate, isFalse);
    expect(replay.hasReferenceConflict, isTrue);
    expect(replay.isMerchantConfirmed, isFalse);
    final records = await OnlinePaymentHistoryService.load();
    expect(records, hasLength(1));
    expect(records.single['status'], 'CONFLICT_REVIEW');
  });

  test('auto-records high-confidence events without claiming bank verification', () async {
    await OnlinePaymentHistoryService.recordIncomingPayment(
      event(verification: PaymentVerificationStatus.unverified),
    );

    final records = await OnlinePaymentHistoryService.load();
    expect(records.single['status'], 'AUTO_ACCEPTED');
    expect(records.single['merchant_confirmed'], isFalse);
    expect(records.single['confirmation_mode'], 'automatic');
    expect(records.single['verified'], isFalse);
  });

  test('does not reopen a high-confidence auto-recorded reference for confirmation', () async {
    final first = event(
      decision: PaymentDecision.confirmed,
      verification: PaymentVerificationStatus.unverified,
      timestamp: DateTime.now().subtract(const Duration(hours: 8)),
    );
    await OnlinePaymentHistoryService.recordIncomingPayment(first);

    final replay = await OnlinePaymentHistoryService.annotateKnownReferenceState(
      event(
        id: 'late-auto-recorded-replay',
        decision: PaymentDecision.likely,
        verification: PaymentVerificationStatus.unverified,
        timestamp: DateTime.now(),
      ),
    );

    expect(replay.isDuplicate, isTrue);
    expect(replay.detectionSource, isNot(contains(':pending_review_reminder')));
    final records = await OnlinePaymentHistoryService.load();
    expect(records, hasLength(1));
    expect(records.single['status'], 'AUTO_ACCEPTED');
    expect(records.single['merchant_confirmed'], isFalse);
    expect(records.single['verified'], isFalse);
  });


  test(
    'merges PhonePe, UPI-app, bank-SMS and Messages copies into one row per UTR',
    () async {
      final now = DateTime.now().subtract(const Duration(seconds: 20));

      Future<void> addPaymentCopies({
        required double amount,
        required String utr,
        required DateTime time,
        required String prefix,
      }) async {
        // PhonePe posts a notification and accessibility exposes it again.
        await OnlinePaymentHistoryService.recordIncomingPayment(event(
          id: prefix + '-phonepe',
          amount: amount,
          referenceId: null,
          decision: PaymentDecision.likely,
          verification: PaymentVerificationStatus.unverified,
          app: PaymentApp.phonePe,
          detectionSource: 'notification',
          rawText: 'Received Rs ' + amount.toStringAsFixed(0) + ' from Ravi via PhonePe',
          timestamp: time,
          sourceTimestamp: time,
        ));
        await OnlinePaymentHistoryService.recordIncomingPayment(event(
          id: prefix + '-phonepe-accessibility',
          amount: amount,
          referenceId: null,
          decision: PaymentDecision.likely,
          verification: PaymentVerificationStatus.unverified,
          app: PaymentApp.phonePe,
          detectionSource: 'accessibility',
          rawText: 'PhonePe payment received Rs ' + amount.toStringAsFixed(0),
          timestamp: time.add(const Duration(seconds: 1)),
          sourceTimestamp: time.add(const Duration(seconds: 1)),
        ));

        // The Messages notification is parsed under the generic UPI app label.
        await OnlinePaymentHistoryService.recordIncomingPayment(event(
          id: prefix + '-messages-app',
          amount: amount,
          referenceId: null,
          decision: PaymentDecision.likely,
          verification: PaymentVerificationStatus.unverified,
          app: PaymentApp.unknown,
          detectionSource: 'notification',
          rawText: 'Payment received Rs ' + amount.toStringAsFixed(0),
          timestamp: time.add(const Duration(seconds: 2)),
          sourceTimestamp: time.add(const Duration(seconds: 2)),
        ));
        await OnlinePaymentHistoryService.recordIncomingPayment(event(
          id: prefix + '-messages-accessibility',
          amount: amount,
          referenceId: null,
          decision: PaymentDecision.likely,
          verification: PaymentVerificationStatus.unverified,
          app: PaymentApp.unknown,
          detectionSource: 'accessibility',
          rawText: 'UPI payment received Rs ' + amount.toStringAsFixed(0),
          timestamp: time.add(const Duration(seconds: 3)),
          sourceTimestamp: time.add(const Duration(seconds: 3)),
        ));

        // The bank SMS supplies the durable transaction identity after app signals.
        await OnlinePaymentHistoryService.recordIncomingPayment(event(
          id: prefix + '-bank-sms',
          amount: amount,
          referenceId: utr,
          decision: PaymentDecision.likely,
          verification: PaymentVerificationStatus.unverified,
          app: PaymentApp.bankSms,
          detectionSource: 'sms',
          rawText: 'An amount of Rs ' + amount.toStringAsFixed(0) +
              ' is credited. UPI Ref No:' + utr,
          timestamp: time.add(const Duration(seconds: 4)),
          sourceTimestamp: time.add(const Duration(seconds: 4)),
        ));
        // Android Messages can surface the same SMS as another notification.
        await OnlinePaymentHistoryService.recordIncomingPayment(event(
          id: prefix + '-messages-notification',
          amount: amount,
          referenceId: utr,
          decision: PaymentDecision.likely,
          verification: PaymentVerificationStatus.unverified,
          app: PaymentApp.bankSms,
          detectionSource: 'notification',
          rawText: 'Messages: credited Rs ' + amount.toStringAsFixed(0) +
              ' UPI Ref No:' + utr,
          timestamp: time.add(const Duration(seconds: 5)),
          sourceTimestamp: time.add(const Duration(seconds: 5)),
        ));
      }

      await addPaymentCopies(
        amount: 5,
        utr: '663292616261',
        time: now,
        prefix: 'five-a',
      );
      await addPaymentCopies(
        amount: 5,
        utr: '663292616262',
        time: now.add(const Duration(minutes: 1)),
        prefix: 'five-b',
      );
      await addPaymentCopies(
        amount: 10,
        utr: '663292616263',
        time: now.add(const Duration(minutes: 2)),
        prefix: 'ten-a',
      );

      final rows = await OnlinePaymentHistoryService.load();
      final amounts = rows.map((row) => (row['amount'] as num).toDouble()).toList()
        ..sort();
      expect(rows, hasLength(3));
      expect(amounts, [5.0, 5.0, 10.0]);
      expect(rows.map((row) => row['reference_id']).toSet(),
          {'663292616261', '663292616262', '663292616263'});
      expect(rows.every((row) => row['verified'] == false), isTrue);
      expect(rows.every((row) => row['_record_type'] == null), isTrue);
      expect(rows.every((row) => (row['source_signals'] as List).length >= 3),
          isTrue);

      final duplicate = await OnlinePaymentHistoryService.annotateKnownReferenceState(
        event(
          id: 'five-a-late-replay',
          amount: 5,
          referenceId: '663292616261',
          decision: PaymentDecision.likely,
          verification: PaymentVerificationStatus.unverified,
          app: PaymentApp.bankSms,
          detectionSource: 'sms',
          rawText: 'UPI Ref No:663292616261',
          timestamp: DateTime.now(),
        ),
      );
      expect(duplicate.isDuplicate, isTrue);
      expect(await OnlinePaymentHistoryService.load(), hasLength(3));
    },
  );

  test(
    'does not merge distinct same-amount payments with different references',
    () async {
      final now = DateTime.now();
      await OnlinePaymentHistoryService.recordIncomingPayment(event(
        id: 'payment-five-1',
        amount: 5,
        referenceId: 'UTR-FIVE-0001',
        timestamp: now,
        sourceTimestamp: now,
        app: PaymentApp.phonePe,
      ));
      await OnlinePaymentHistoryService.recordIncomingPayment(event(
        id: 'payment-five-2',
        amount: 5,
        referenceId: 'UTR-FIVE-0002',
        timestamp: now.add(const Duration(seconds: 2)),
        sourceTimestamp: now.add(const Duration(seconds: 2)),
        app: PaymentApp.phonePe,
      ));
      final rows = await OnlinePaymentHistoryService.load();
      expect(rows, hasLength(2));
      expect(rows.map((row) => row['reference_id']).toSet(),
          {'UTRFIVE0001', 'UTRFIVE0002'});
    },
  );


  test(
    'does not merge a new same-amount same-app notification into an existing UTR',
    () async {
      final now = DateTime.now();
      await OnlinePaymentHistoryService.recordIncomingPayment(event(
        id: 'previous-five',
        amount: 5,
        referenceId: 'UTR-PREVIOUS-5551',
        app: PaymentApp.phonePe,
        detectionSource: 'notification',
        rawText: 'You received Rs 5 from Ravi',
        timestamp: now,
        sourceTimestamp: now,
      ));

      await OnlinePaymentHistoryService.recordIncomingPayment(event(
        id: 'new-five',
        amount: 5,
        referenceId: null,
        decision: PaymentDecision.likely,
        verification: PaymentVerificationStatus.unverified,
        app: PaymentApp.phonePe,
        detectionSource: 'notification',
        rawText: 'You received Rs 5 from Ravi',
        timestamp: now.add(const Duration(seconds: 2)),
        sourceTimestamp: now.add(const Duration(seconds: 2)),
      ));

      final rows = await OnlinePaymentHistoryService.load();
      expect(rows, hasLength(2));
      expect(rows.where((row) => row['reference_id'] != null), hasLength(1));
      expect(rows.map((row) => (row['amount'] as num).toDouble()).toList(),
          everyElement(5.0));
    },
  );

  test(
    'replayed PhonePe notification updates stay one history row without a UTR',
    () async {
      final now = DateTime.now();
      final postedAtMs = now.millisecondsSinceEpoch;
      final first = event(
        id: 'phonepe-notification-first',
        amount: 2,
        referenceId: null,
        decision: PaymentDecision.likely,
        verification: PaymentVerificationStatus.unverified,
        timestamp: now,
        sourceTimestamp: now,
        sourceEventKey:
            'com.phonepe.app|42|$postedAtMs|payload-hash-first',
        rawText: 'You received ₹2 from a customer',
      );
      final replay = event(
        id: 'phonepe-notification-replay',
        amount: 2,
        referenceId: null,
        decision: PaymentDecision.likely,
        verification: PaymentVerificationStatus.unverified,
        timestamp: now.add(const Duration(seconds: 18)),
        sourceTimestamp: now.add(const Duration(seconds: 18)),
        // A payload hash can change when Android updates the same notification.
        // Package, notification ID, and post time still identify that same post.
        sourceEventKey:
            'com.phonepe.app|42|$postedAtMs|payload-hash-updated',
        rawText: 'Payment received ₹2',
      );

      expect(
        await OnlinePaymentHistoryService.recordIncomingPayment(first),
        isTrue,
      );
      final annotated =
          await OnlinePaymentHistoryService.annotateKnownReferenceState(replay);
      expect(annotated.isDuplicate, isTrue);
      expect(
        await OnlinePaymentHistoryService.recordIncomingPayment(annotated),
        isFalse,
      );

      final rows = await OnlinePaymentHistoryService.load();
      expect(rows, hasLength(1));
      expect(rows.single['amount'], 2.0);
      expect(rows.single['source_event_fingerprint'], first.sourceEventFingerprint);
    },
  );

  test(
    'does not merge distinct same-value native notifications',
    () async {
      final now = DateTime.now();
      final postedAt = now.millisecondsSinceEpoch;
      await OnlinePaymentHistoryService.recordIncomingPayment(event(
        id: 'phonepe-two-rupee-a',
        amount: 2,
        referenceId: null,
        decision: PaymentDecision.likely,
        verification: PaymentVerificationStatus.unverified,
        timestamp: now,
        sourceEventKey: 'com.phonepe.app|51|$postedAt|hash-a',
      ));
      await OnlinePaymentHistoryService.recordIncomingPayment(event(
        id: 'phonepe-two-rupee-b',
        amount: 2,
        referenceId: null,
        decision: PaymentDecision.likely,
        verification: PaymentVerificationStatus.unverified,
        timestamp: now.add(const Duration(seconds: 2)),
        sourceEventKey:
            'com.phonepe.app|52|${postedAt + 2000}|hash-b',
      ));

      final rows = await OnlinePaymentHistoryService.load();
      expect(rows, hasLength(2));
      expect(rows.map((row) => row['amount']).toList(), [2.0, 2.0]);
    },
  );

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
