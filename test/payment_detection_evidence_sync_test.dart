import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/sync_queue_manager.dart';

void main() {
  group('payment detection evidence outbox policy', () {
    test('evidence writes are treated as critical offline operations', () {
      expect(
        SyncQueueManager.debugIsCriticalAction('payment_detection_evidence'),
        isTrue,
      );
    });
  });
}
