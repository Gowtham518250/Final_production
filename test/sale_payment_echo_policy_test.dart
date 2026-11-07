import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/sale_payment_echo_policy.dart';

final _at = DateTime(2026, 11, 1, 12);

SaleEchoCandidate _candidate(
  String id, {
  double amount = 500,
  String app = 'phonePe',
  String family = 'uplike',
  int seconds = 0,
  String? reference,
  String? fingerprint,
  String text = '',
}) => SaleEchoCandidate(
  id: id,
  amount: amount,
  direction: 'credit',
  appKey: app,
  appFamily: family,
  at: _at.add(Duration(seconds: seconds)),
  reference: reference,
  sourceFingerprint: fingerprint,
  text: text,
);

SaleEchoCandidate _sms(
  String id, {
  int seconds = 0,
  double amount = 500,
  String? reference,
}) => _candidate(
  id,
  amount: amount,
  app: 'bankSms',
  family: 'bankRelay',
  seconds: seconds,
  reference: reference,
);

void main() {
  test('hard identity is an echo', () {
    expect(
      SalePaymentEchoPolicy.classify(_sms('second', reference: 'utr1'), [
        _candidate('first', reference: 'utr1'),
      ]).verdict,
      SaleEchoVerdict.hardEcho,
    );
  });

  test('weak cross-channel evidence is retained as a possible repeat', () {
    final result = SalePaymentEchoPolicy.classify(_sms('sms', seconds: 300), [
      _candidate('notification'),
    ]);
    expect(result.verdict, SaleEchoVerdict.possibleRepeat);
  });

  test('different references and amounts remain distinct', () {
    expect(
      SalePaymentEchoPolicy.classify(_sms('sms', reference: 'utr2'), [
        _candidate('notification', reference: 'utr1'),
      ]).verdict,
      SaleEchoVerdict.distinct,
    );
    expect(
      SalePaymentEchoPolicy.classify(_sms('sms', amount: 400), [
        _candidate('notification'),
      ]).verdict,
      SaleEchoVerdict.distinct,
    );
  });

  test(
    'uncertain same-amount alert is only droppable when bill is covered',
    () {
      expect(
        SalePaymentEchoPolicy.billAlreadyCovered(
          remainingDue: 500,
          pendingAmounts: const [],
          amount: 500,
        ),
        isFalse,
      );
      expect(
        SalePaymentEchoPolicy.billAlreadyCovered(
          remainingDue: 500,
          pendingAmounts: const [500],
          amount: 500,
        ),
        isTrue,
      );
    },
  );
}
