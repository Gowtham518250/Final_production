import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/language_engine.dart';
import 'package:retail_mind/queue_manager.dart';

void main() {
  test('stuck TTS task times out and the next queued announcement can run', () async {
    final queue = QueueManager();
    var timedOut = false;
    var secondAnnouncementRan = false;

    queue.enqueue(
      QueueItem(
        priority: AnnouncementPriority.low,
        ttsText: 'first payment announcement',
        timeoutSec: 1,
        task: () => Completer<void>().future,
        onTimeout: () async {
          timedOut = true;
        },
      ),
    );

    queue.enqueue(
      QueueItem(
        priority: AnnouncementPriority.high,
        ttsText: 'second payment announcement',
        timeoutSec: 2,
        task: () async {
          secondAnnouncementRan = true;
        },
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 1400));

    expect(timedOut, isTrue);
    expect(secondAnnouncementRan, isTrue);
    expect(queue.isBusy, isFalse);
  });
}
