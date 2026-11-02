import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/bill_context.dart';

final _at = DateTime(2026, 11, 1, 12);

BillContext _bill(double amount) => BillContext()..setExpected(amount);

void main() {
  group('pending and confirmed bill amounts', () {
    test('pending never changes accounting but changes tentative balance', () {
      final bill = _bill(1000)..notePending('p1', 600, at: _at);
      expect(bill.remainingAmount, 1000);
      expect(bill.tentativeRemaining(now: _at), 400);
    });

    test('can absorb an equal second installment while balance remains', () {
      final bill = _bill(1000)..notePending('p1', 500, at: _at);
      expect(bill.canAbsorbAnother(500, now: _at), isTrue);
      expect(bill.weakPairWindow(500, now: _at), Duration.zero);
    });

    test('covered bill treats a same-amount cross-channel alert as an echo', () {
      final bill = _bill(1000)
        ..notePending('p1', 500, at: _at)
        ..notePending('p2', 500, at: _at);
      expect(bill.canAbsorbAnother(500, now: _at), isFalse);
      expect(
        bill.weakPairWindow(500, now: _at),
        BillContext.coveredBillEchoWindow,
      );
    });

    test('pending alerts expire and can be released by id or amount', () {
      final bill = _bill(1000)..notePending('old', 600, at: _at);
      expect(bill.tentativeRemaining(now: _at.add(const Duration(minutes: 16))), 1000);
      bill.notePending('reject', 200, at: _at);
      bill.releasePending('reject');
      bill.notePending('confirm', 300, at: _at);
      expect(bill.releasePendingByAmount(300), isTrue);
      expect(bill.pendingCount, 0);
    });
  });

  test('a new bill resets old pending and partial payments', () {
    final bill = _bill(1000)
      ..recordPartial(200)
      ..notePending('p1', 300, at: _at);
    bill.clear();
    bill.setExpected(800);
    expect(bill.partialReceived, 0);
    expect(bill.pendingCount, 0);
  });
}