import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/payment_detection_service.dart';
import 'package:retail_mind/payment_event.dart';
import 'package:retail_mind/queue_manager.dart';

PaymentEvent _payment(String id) {
  return PaymentEvent(
    id: id,
    amount: 250,
    timestamp: DateTime.now(),
    app: PaymentApp.phonePe,
    payerName: 'Rahul Kumar',
    accountSuffix: '4222',
    rawText: 'You received ₹250 from Rahul Kumar in account XXXX4222',
    detectionSource: 'notification',
    direction: PaymentTransactionDirection.incomingCredit,
    decision: PaymentDecision.likely,
  );
}

PaymentUiState _ui(PaymentEvent event) {
  return PaymentUiState(
    id: event.id,
    decision: event.decision,
    amount: event.amount,
    payerName: event.payerName,
    bankName: event.bankName,
    isFailed: event.isFailed,
    isPartial: event.isPartialPayment,
    shortfall: event.remainingAmount,
    isBillMatch: event.isBillMatch,
    detectedAt: event.timestamp,
    rawText: event.rawText,
    direction: event.direction,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late bool originalVoiceEnabled;

  setUp(() {
    originalVoiceEnabled = PdsConfig.isVoiceEnabled;
    PdsConfig.isVoiceEnabled = true;
  });

  tearDown(() {
    PdsConfig.isVoiceEnabled = originalVoiceEnabled;
  });

  group('Payment announcement speech completion', () {
    test('a successful TTS completion is remembered for that payment', () async {
      final queue = PriorityVoiceQueue();
      final event = _payment('tts-success-1');
      final failures = <String>[];
      var speechCalls = 0;

      queue.speaker = (text, dedupeKey) async {
        speechCalls++;
        return true;
      };
      queue.onSpeakFailed = (text, failedEvent) {
        if (failedEvent != null) failures.add(failedEvent.id);
      };

      queue.enqueue(event, _ui(event));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      queue.enqueue(event, _ui(event));
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(speechCalls, 1);
      expect(failures, isEmpty);
      queue.dispose();
    });

    test('failed TTS releases the spoken claim and requests audible fallback', () async {
      final queue = PriorityVoiceQueue();
      final event = _payment('tts-failure-retry-1');
      final fallbackEvents = <String>[];
      var speechCalls = 0;

      queue.speaker = (text, dedupeKey) async {
        speechCalls++;
        return false;
      };
      queue.onSpeakFailed = (text, failedEvent) {
        if (failedEvent != null) fallbackEvents.add(failedEvent.id);
      };

      queue.enqueue(event, _ui(event));
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(speechCalls, 1);
      expect(fallbackEvents, ['tts-failure-retry-1']);

      // The same event must remain eligible for speech retry after failure.
      queue.enqueue(event, _ui(event));
      await Future<void>.delayed(
        PdsConfig.voiceMinGap + const Duration(milliseconds: 180),
      );

      expect(speechCalls, 2);
      expect(fallbackEvents, ['tts-failure-retry-1', 'tts-failure-retry-1']);
      queue.dispose();
    });

    test('a speaker exception is treated as a failed announcement', () async {
      final queue = PriorityVoiceQueue();
      final event = _payment('tts-exception-1');
      final fallbackEvents = <String>[];

      queue.speaker = (text, dedupeKey) async {
        throw StateError('TTS provider unavailable');
      };
      queue.onSpeakFailed = (text, failedEvent) {
        if (failedEvent != null) fallbackEvents.add(failedEvent.id);
      };

      queue.enqueue(event, _ui(event));
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(fallbackEvents, ['tts-exception-1']);
      queue.dispose();
    });

    test('a missing speaker does not mark a payment as spoken', () async {
      final queue = PriorityVoiceQueue();
      final event = _payment('tts-no-speaker-1');
      final fallbackEvents = <String>[];
      queue.onSpeakFailed = (text, failedEvent) {
        if (failedEvent != null) fallbackEvents.add(failedEvent.id);
      };

      queue.enqueue(event, _ui(event));
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(fallbackEvents, ['tts-no-speaker-1']);
      queue.dispose();
    });
  });

  group('QueueManager speech result delivery', () {
    test('timeout reports failure and does not block the next queued item', () async {
      final queue = QueueManager();
      final results = <String, bool>{};

      queue.enqueue(QueueItem(
        priority: AnnouncementPriority.low,
        ttsText: 'stalled payment',
        timeoutSec: 1,
        task: () => Completer<void>().future,
        onResult: (success) => results['stalled'] = success,
      ));
      queue.enqueue(QueueItem(
        priority: AnnouncementPriority.low,
        ttsText: 'next payment',
        timeoutSec: 5,
        task: () async {},
        onResult: (success) => results['next'] = success,
      ));

      await Future<void>.delayed(const Duration(milliseconds: 1500));

      expect(results['stalled'], isFalse);
      expect(results['next'], isTrue);
    });

    test('expired queued payment speech reports failure without running', () async {
      final queue = QueueManager();
      var ran = false;
      bool? result;

      queue.enqueue(QueueItem(
        priority: AnnouncementPriority.low,
        ttsText: 'expired payment',
        timeoutSec: 5,
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
        task: () async {
          ran = true;
        },
        onResult: (success) => result = success,
      ));

      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(ran, isFalse);
      expect(result, isFalse);
    });
  });
}
