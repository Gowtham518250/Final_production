import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/sync_queue_manager.dart';

void main() {
  group('critical offline sync operations', () {
    test('payment detection evidence is protected from queue pressure', () {
      expect(
        SyncQueueManager.debugIsCriticalAction('payment_detection_evidence'),
        isTrue,
      );
    });

    test(
      'Khata invoice deadline updates are protected from queue pressure',
      () {
        expect(
          SyncQueueManager.debugIsCriticalAction('update_khata_deadline'),
          isTrue,
        );
      },
    );
  });
}
