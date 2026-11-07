import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/payment_event.dart';
import 'package:retail_mind/soundbox_announcement_coordinator.dart';

PaymentEvent _credit({
  required String id,
  required String source,
  String? reference,
  String? payer,
  DateTime? at,
}) => PaymentEvent(
  id: id,
  amount: 500,
  timestamp: at ?? DateTime(2026, 11, 7, 9, 0),
  app: source == 'sms' ? PaymentApp.bankSms : PaymentApp.phonePe,
  payerName: payer,
  referenceId: reference,
  rawText: 'credited 500',
  detectionSource: source,
  direction: PaymentTransactionDirection.incomingCredit,
);

void main() {
  test('no-UTR app credit waits, then SMS UTR speaks once', () {
    final spoken = <String>[];
    void Function()? pending;
    final box = SoundboxAnnouncementCoordinator<String>(
      speak: (event, _) =>
          spoken.add('${event.id}:${event.normalizedReferenceId ?? 'none'}'),
      holdWindow: () => const Duration(milliseconds: 1500),
      schedule: (duration, callback) {
        pending = callback;
        return () => pending = null;
      },
    );

    final notification = _credit(id: 'n1', source: 'notification');
    final sms = _credit(
      id: 's1',
      source: 'sms',
      reference: '412345678901',
      payer: 'Ravi',
    );

    expect(box.notePrimary(notification, 'ui'), isTrue);
    expect(spoken, isEmpty);

    box.noteEcho(notification, sms);
    expect(spoken, ['n1:412345678901']);
    expect(pending, isNull);
  });

  test('hold expires as a single sound-box announcement', () {
    final spoken = <String>[];
    void Function()? pending;
    final box = SoundboxAnnouncementCoordinator<String>(
      speak: (event, _) => spoken.add(event.id),
      holdWindow: () => const Duration(milliseconds: 1500),
      schedule: (duration, callback) {
        pending = callback;
        return () => pending = null;
      },
    );

    expect(
      box.notePrimary(_credit(id: 'n1', source: 'notification'), 'ui'),
      isTrue,
    );
    pending!.call();
    expect(spoken, ['n1']);
  });

  test('a second distinct payment flushes the first hold', () {
    final spoken = <String>[];
    void Function()? pending;
    final box = SoundboxAnnouncementCoordinator<String>(
      speak: (event, _) => spoken.add(event.id),
      holdWindow: () => const Duration(milliseconds: 1500),
      schedule: (duration, callback) {
        pending = callback;
        return () => pending = null;
      },
    );

    expect(
      box.notePrimary(_credit(id: 'n1', source: 'notification'), 'ui'),
      isTrue,
    );
    expect(
      box.notePrimary(_credit(id: 'n2', source: 'notification'), 'ui'),
      isTrue,
    );
    expect(spoken, ['n1']);
    pending!.call();
    expect(spoken, ['n1', 'n2']);
  });

  test(
    'UTR on the first alert speaks immediately like a confirmed sound box',
    () {
      final spoken = <String>[];
      final box = SoundboxAnnouncementCoordinator<String>(
        speak: (event, _) => spoken.add(event.id),
        holdWindow: () => const Duration(milliseconds: 1500),
        schedule: (duration, callback) {
          return () {};
        },
      );

      expect(
        box.notePrimary(
          _credit(id: 'n1', source: 'notification', reference: '412345678901'),
          'ui',
        ),
        isFalse,
      );
      expect(spoken, isEmpty);
    },
  );
}
