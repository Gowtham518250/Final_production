import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/payment_detection_service.dart';
import 'package:retail_mind/payment_event.dart';
import 'package:retail_mind/queue_manager.dart';
import 'package:retail_mind/language_engine.dart';

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

PaymentEvent _paymentWithRef(
  String id,
  String source, {
  String ref = 'UTR402518811234',
}) {
  return PaymentEvent(
    id: id,
    amount: 250,
    timestamp: DateTime.now(),
    app: PaymentApp.phonePe,
    payerName: 'Rahul Kumar',
    accountSuffix: '4222',
    referenceId: ref,
    rawText: 'You received ₹250 from Rahul Kumar in account XXXX4222 UTR $ref',
    detectionSource: source,
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
    test(
      'a successful TTS completion is remembered for that payment',
      () async {
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
      },
    );

    test(
      'failed TTS releases the spoken claim and requests audible fallback',
      () async {
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
      },
    );

    test(
      'echo of a payment whose speech failed is not announced again',
      () async {
        final queue = PriorityVoiceQueue();
        final notification = _paymentWithRef('echo-notif-1', 'notification');
        final sms = _paymentWithRef('echo-sms-1', 'sms');
        final spoken = <String>[];
        final fallbackEvents = <String>[];

        // TTS reports failure (timeout / engine error); an audible OS alert is
        // posted through onSpeakFailed instead.
        queue.speaker = (text, dedupeKey) async {
          spoken.add(text);
          return false;
        };
        queue.onSpeakFailed = (text, failedEvent) {
          if (failedEvent != null) fallbackEvents.add(failedEvent.id);
        };

        queue.enqueue(notification, _ui(notification));
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(fallbackEvents, ['echo-notif-1']);

        // The SMS for the SAME payment (same UTR) arrives afterwards. The owner
        // was already alerted by the fallback, so it must stay silent.
        queue.enqueue(sms, _ui(sms));
        await Future<void>.delayed(
          PdsConfig.voiceMinGap + const Duration(milliseconds: 180),
        );

        expect(spoken.length, 1, reason: 'SMS echo must not be spoken again');
        expect(fallbackEvents, ['echo-notif-1']);
        queue.dispose();
      },
    );

    test('a different payment is still announced after a failed one', () async {
      final queue = PriorityVoiceQueue();
      final first = _paymentWithRef('other-1', 'notification');
      final second = _paymentWithRef(
        'other-2',
        'notification',
        ref: 'UTR999999999999',
      );
      final spoken = <String>[];

      queue.speaker = (text, dedupeKey) async {
        spoken.add(text);
        return spoken.length > 1; // first fails, second succeeds
      };
      queue.onSpeakFailed = (text, failedEvent) {};

      queue.enqueue(first, _ui(first));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      queue.enqueue(second, _ui(second));
      await Future<void>.delayed(
        PdsConfig.voiceMinGap + const Duration(milliseconds: 180),
      );

      expect(spoken.length, 2);
      queue.dispose();
    });

    test('without a fallback alert the echo may still speak', () async {
      final queue = PriorityVoiceQueue();
      final notification = _paymentWithRef('nofb-notif-1', 'notification');
      final sms = _paymentWithRef('nofb-sms-1', 'sms');
      final spoken = <String>[];

      queue.speaker = (text, dedupeKey) async {
        spoken.add(text);
        return spoken.length > 1;
      };
      // No onSpeakFailed: nothing announced the first payment at all.

      queue.enqueue(notification, _ui(notification));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      queue.enqueue(sms, _ui(sms));
      await Future<void>.delayed(
        PdsConfig.voiceMinGap + const Duration(milliseconds: 180),
      );

      expect(spoken.length, 2);
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
    test(
      'critical payment announcement jumps ahead of queued routine prompts',
      () async {
        final queue = QueueManager();
        final activeSpeechStarted = Completer<void>();
        final releaseActiveSpeech = Completer<void>();
        final order = <String>[];

        queue.enqueue(
          QueueItem(
            priority: AnnouncementPriority.normal,
            ttsText: 'currently speaking',
            timeoutSec: 5,
            task: () async {
              activeSpeechStarted.complete();
              await releaseActiveSpeech.future;
              order.add('active');
            },
          ),
        );
        await activeSpeechStarted.future;

        queue.enqueue(
          QueueItem(
            priority: AnnouncementPriority.low,
            ttsText: 'routine prompt',
            timeoutSec: 5,
            task: () async => order.add('routine'),
          ),
        );
        queue.enqueue(
          QueueItem(
            priority: AnnouncementPriority.critical,
            ttsText: 'payment alert',
            timeoutSec: 5,
            task: () async => order.add('payment'),
          ),
        );

        releaseActiveSpeech.complete();
        await Future<void>.delayed(const Duration(milliseconds: 150));

        expect(order, ['active', 'payment', 'routine']);
      },
    );

    test(
      'timeout reports failure and does not block the next queued item',
      () async {
        final queue = QueueManager();
        final results = <String, bool>{};

        queue.enqueue(
          QueueItem(
            priority: AnnouncementPriority.low,
            ttsText: 'stalled payment',
            timeoutSec: 1,
            task: () => Completer<void>().future,
            onResult: (success) => results['stalled'] = success,
          ),
        );
        queue.enqueue(
          QueueItem(
            priority: AnnouncementPriority.low,
            ttsText: 'next payment',
            timeoutSec: 5,
            task: () async {},
            onResult: (success) => results['next'] = success,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 1500));

        expect(results['stalled'], isFalse);
        expect(results['next'], isTrue);
      },
    );

    test(
      'expired queued payment speech reports failure without running',
      () async {
        final queue = QueueManager();
        var ran = false;
        bool? result;

        queue.enqueue(
          QueueItem(
            priority: AnnouncementPriority.low,
            ttsText: 'expired payment',
            timeoutSec: 5,
            expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
            task: () async {
              ran = true;
            },
            onResult: (success) => result = success,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 120));

        expect(ran, isFalse);
        expect(result, isFalse);
      },
    );
  });
}
