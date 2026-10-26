import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/worker_verification_policy.dart';

void main() {
  group('worker verification roster policy', () {
    test('active worker records require verification', () {
      final snapshot = WorkerRosterSnapshot(
        workers: const <Map<String, dynamic>>[
          <String, dynamic>{'id': 1, 'status': 'ACTIVE'},
        ],
        isAuthoritative: true,
      );

      expect(snapshot.hasActiveWorkers, isTrue);
      expect(snapshot.confirmedHasActiveWorkers, isTrue);
    });

    test('worker on leave remains part of the current roster', () {
      expect(
        WorkerVerificationPolicy.isActiveWorker(
          const <String, dynamic>{'status': 'on_leave'},
        ),
        isTrue,
      );
    });

    test('inactive or removed workers do not require the staff verification gate', () {
      expect(
        WorkerVerificationPolicy.isActiveWorker(
          const <String, dynamic>{'status': 'INACTIVE'},
        ),
        isFalse,
      );
      expect(
        WorkerVerificationPolicy.isActiveWorker(
          const <String, dynamic>{'status': 'DELETED'},
        ),
        isFalse,
      );
    });

    test('only a live empty roster confirms there are no active workers', () {
      const liveEmpty = WorkerRosterSnapshot(
        workers: <Map<String, dynamic>>[],
        isAuthoritative: true,
      );
      const staleEmpty = WorkerRosterSnapshot(
        workers: <Map<String, dynamic>>[],
        isAuthoritative: false,
      );

      expect(liveEmpty.confirmedHasActiveWorkers, isFalse);
      expect(staleEmpty.confirmedHasActiveWorkers, isNull);
    });

    test('a cached active worker keeps verification enabled while offline', () {
      const cached = WorkerRosterSnapshot(
        workers: <Map<String, dynamic>>[
          <String, dynamic>{'id': 10, 'status': 'active'},
        ],
        isAuthoritative: false,
      );

      expect(cached.confirmedHasActiveWorkers, isTrue);
    });
  });
}
