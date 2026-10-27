import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/payment_idempotency_ledger.dart';
import 'package:retail_mind/sync_queue_manager.dart';

void main() {
  test('retains every applied payment key for replay protection', () {
    final invoice = <String, dynamic>{};

    PaymentIdempotencyLedger.remember(invoice, 'payment-a');
    PaymentIdempotencyLedger.remember(invoice, 'payment-b');

    expect(PaymentIdempotencyLedger.contains(invoice, 'payment-a'), isTrue);
    expect(PaymentIdempotencyLedger.contains(invoice, 'payment-b'), isTrue);
    expect(invoice['last_payment_idempotency_key'], 'payment-b');
  });

  test('reads legacy last-key records during migration', () {
    expect(
      PaymentIdempotencyLedger.contains({
        'last_payment_idempotency_key': 'legacy-payment',
      }, 'legacy-payment'),
      isTrue,
    );
  });

  test('payment recording remains critical under outbox pressure', () {
    expect(SyncQueueManager.debugIsCriticalAction('record_payment'), isTrue);
  });
}
