import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/bill_context.dart';
import 'package:retail_mind/payment_identity_matcher.dart';

final _at = DateTime(2026, 11, 1, 12);

SignalIdentity _signal(String id, String origin, {int seconds = 0}) => SignalIdentity(
  id: id,
  amount: 500,
  direction: 'credit',
  channel: '$origin|${origin == 'sms' ? 'bankSms' : 'phonePe'}',
  origin: origin,
  at: _at.add(Duration(seconds: seconds)),
);

void main() {
  test('zero bill-aware window preserves a possible second installment', () {
    final result = PaymentIdentityMatcher.resolve(
      _signal('sms2', 'sms', seconds: 30),
      [_signal('notification1', 'notification')],
      weakWindow: Duration.zero,
    );
    expect(result.isEcho, isFalse);
  });

  test('covered bill window still merges a late SMS echo', () {
    final result = PaymentIdentityMatcher.resolve(
      _signal('sms1', 'sms', seconds: 300),
      [_signal('notification1', 'notification')],
      weakWindow: BillContext.coveredBillEchoWindow,
    );
    expect(result.isEcho, isTrue);
  });

  test('default window preserves previous behavior', () {
    expect(
      PaymentIdentityMatcher.resolve(
        _signal('sms1', 'sms', seconds: 20),
        [_signal('notification1', 'notification')],
      ).isEcho,
      isTrue,
    );
  });
}