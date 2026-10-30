import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/language_engine.dart';
import 'package:retail_mind/payment_detection_service.dart';
import 'package:retail_mind/payment_event.dart';
import 'package:retail_mind/queue_manager.dart';

QueueItem _item(Future<void> Function() task) => QueueItem(
      priority: AnnouncementPriority.normal,
      ttsText: 'payment',
      timeoutSec: 10,
      task: task,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('speech that failed after it could be audible is NOT retried', () async {
    final queue = QueueManager();
    var attempts = 0;
    queue.enqueue(_item(() async {
      attempts++;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      throw StateError('late TTS failure');
    }));
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    expect(attempts, 1, reason: 'a retry would announce the payment twice');
    expect(queue.isBusy, isFalse);
  });

  test('an immediate failure (nothing spoken yet) is still retried', () async {
    final queue = QueueManager();
    var attempts = 0;
    queue.enqueue(_item(() async {
      attempts++;
      if (attempts == 1) throw StateError('engine not ready');
    }));
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(attempts, 2);
  });

  test('already-voiced notification events are not re-emitted by the TCM drain',
      () async {
    final buffer = PendingPaymentBuffer();
    final event = PaymentEvent(
      id: 'notif-1',
      amount: 100,
      timestamp: DateTime.now(),
      app: PaymentApp.phonePe,
      rawText: 'Received Rs 100',
      direction: PaymentTransactionDirection.incomingCredit,
    );
    buffer.add(event);
    buffer.markVoiceSpoken(event.id);

    await Future<void>.delayed(const Duration(seconds: 6));
    expect(buffer.drainUnconfirmed(), isEmpty);
    buffer.dispose();
  });

  test('a buffered event nobody voiced is still drained once', () async {
    final buffer = PendingPaymentBuffer();
    buffer.add(PaymentEvent(
      id: 'notif-2',
      amount: 100,
      timestamp: DateTime.now(),
      app: PaymentApp.phonePe,
      rawText: 'Received Rs 100',
      direction: PaymentTransactionDirection.incomingCredit,
    ));
    await Future<void>.delayed(const Duration(seconds: 6));
    expect(buffer.drainUnconfirmed(), hasLength(1));
    expect(buffer.drainUnconfirmed(), isEmpty);
    buffer.dispose();
  });
}
