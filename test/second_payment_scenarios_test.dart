import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/bill_context.dart';
import 'package:retail_mind/payment_identity_matcher.dart';
import 'package:retail_mind/sale_payment_echo_policy.dart';

final _at = DateTime(2026, 11, 1, 12);

SignalIdentity _signal(String id, String origin, {int seconds = 0}) => SignalIdentity(
  id: id,
  amount: 500,
  direction: 'credit',
  channel: '$origin|${origin == 'sms' ? 'bankSms' : 'phonePe'}',
  origin: origin,
  at: _at.add(Duration(seconds: seconds)),
);

SaleEchoCandidate _pageSignal(String id, String app, String family, {int seconds = 0}) =>
    SaleEchoCandidate(
      id: id,
      amount: 500,
      direction: 'credit',
      appKey: app,
      appFamily: family,
      at: _at.add(Duration(seconds: seconds)),
    );

void main() {
  test('Rs 1000 bill paid as two Rs 500 installments keeps the second', () {
    final bill = BillContext()..setExpected(1000);
    bill.notePending('first', 500, at: _at);
    final echoWindow = bill.weakPairWindow(500, now: _at.add(const Duration(seconds: 30)));
    final engineDecision = PaymentIdentityMatcher.resolve(
      _signal('second', 'sms', seconds: 30),
      [_signal('first', 'notification')],
      weakWindow: echoWindow,
    );
    expect(engineDecision.isEcho, isFalse);

    final pageDecision = SalePaymentEchoPolicy.classify(
      _pageSignal('second', 'bankSms', 'bankRelay', seconds: 30),
      [_pageSignal('first', 'phonePe', 'uplike')],
    );
    expect(pageDecision.verdict, SaleEchoVerdict.possibleRepeat);
    expect(
      SalePaymentEchoPolicy.billAlreadyCovered(
        remainingDue: 1000,
        pendingAmounts: const [500],
        amount: 500,
      ),
      isFalse,
    );
  });

  test('a later echo is merged when prior detections cover the bill', () {
    final bill = BillContext()..setExpected(1000);
    bill
      ..notePending('first', 500, at: _at)
      ..notePending('second', 500, at: _at.add(const Duration(seconds: 30)));
    final result = PaymentIdentityMatcher.resolve(
      _signal('third', 'sms', seconds: 180),
      [
        _signal('first', 'notification'),
        _signal('second', 'notification', seconds: 30),
      ],
      weakWindow: bill.weakPairWindow(500, now: _at.add(const Duration(minutes: 3))),
    );
    expect(result.isEcho, isFalse); // ambiguous between two events: preserve it
    expect(result.ambiguous, isTrue);
  });

  test('rejected pending alerts stop reducing tentative balance', () {
    final bill = BillContext()
      ..setExpected(1000)
      ..notePending('reject', 600, at: _at);
    bill.releasePending('reject');
    expect(bill.tentativeRemaining(now: _at), 1000);
  });
}