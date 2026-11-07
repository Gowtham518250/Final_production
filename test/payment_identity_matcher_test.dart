import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/payment_identity_matcher.dart';

final _t0 = DateTime(2026, 10, 30, 12, 0, 0);

SignalIdentity sig(
  String id, {
  String channel = 'notification|phonepe',
  String origin = 'notification',
  String direction = 'credit',
  double amount = 500,
  int sec = 0,
  String? reference,
  String? payer,
  String? account,
  String? source,
  String? notificationStream,
  DateTime? notificationAt,
  String? notificationPayer,
  String text = '',
}) => SignalIdentity(
  id: id,
  amount: amount,
  direction: direction,
  channel: channel,
  origin: origin,
  at: _t0.add(Duration(seconds: sec)),
  reference: reference,
  payer: payer,
  account: account,
  sourceIdentity: source,
  notificationStream: notificationStream,
  notificationAt: notificationAt,
  notificationPayer: notificationPayer,
  text: text,
);

SignalIdentity sms(
  String id, {
  int sec = 0,
  String? reference,
  String? payer,
  String? account,
}) => sig(
  id,
  channel: 'sms|banksms',
  origin: 'sms',
  sec: sec,
  reference: reference,
  payer: payer,
  account: account,
);

void main() {
  group('pairwise compare', () {
    test('different amount is always distinct', () {
      final d = PaymentIdentityMatcher.compare(
        sig('a'),
        sig('b', amount: 501, source: 'x'),
      );
      expect(d.verdict, IdentityVerdict.distinct);
    });

    test('same native post with updated text is one transfer', () {
      final d = PaymentIdentityMatcher.compare(
        sig('a', source: 'p|1|100'),
        sig('b', source: 'p|1|100', sec: 3),
      );
      expect(d.verdict, IdentityVerdict.sameTransfer);
      expect(d.reason, 'same_native_post');
    });

    test('same native post but different reference stays distinct', () {
      final d = PaymentIdentityMatcher.compare(
        sig('a', source: 'p|1|100', reference: 'AAA111111111'),
        sig('b', source: 'p|1|100', reference: 'BBB222222222'),
      );
      expect(d.verdict, IdentityVerdict.distinct);
    });

    test('same reference on two channels is proof', () {
      final d = PaymentIdentityMatcher.compare(
        sig('a', reference: '412345678901'),
        sms('s', reference: '412345678901', sec: 400),
      );
      expect(d.verdict, IdentityVerdict.sameTransfer);
    });

    test('different references are different payments', () {
      final d = PaymentIdentityMatcher.compare(
        sig('a', reference: '412345678901'),
        sms('s', reference: '412345678902'),
      );
      expect(d.verdict, IdentityVerdict.distinct);
      expect(d.reason, 'different_reference');
    });

    test('same reference but credit vs debit is a conflict, not a merge', () {
      final d = PaymentIdentityMatcher.compare(
        sig('a', reference: '412345678901'),
        sig(
          'b',
          reference: '412345678901',
          direction: 'debit',
          channel: 'sms|banksms',
          origin: 'sms',
        ),
      );
      expect(d.verdict, IdentityVerdict.distinct);
    });

    test('one-sided reference does not block the weak modality pair', () {
      final d = PaymentIdentityMatcher.compare(
        sms('s', reference: '412345678901', sec: 20),
        sig('n', payer: null),
      );
      expect(d.verdict, IdentityVerdict.candidateEcho);
      expect(d.reason, 'weak_modality_pair');
    });

    test(
      'one-sided UTR plus shared account enriches inside the sound-box window',
      () {
        final d = PaymentIdentityMatcher.compare(
          sms('s', reference: '412345678901', sec: 5, account: '4222'),
          sig('n', account: '4222'),
        );
        expect(d.verdict, IdentityVerdict.candidateEcho);
        expect(d.reason, 'utr_enrichment');
      },
    );

    test(
      'one-sided UTR plus shared account stays distinct after the window',
      () {
        final d = PaymentIdentityMatcher.compare(
          sms('s', reference: '412345678901', sec: 90, account: '4222'),
          sig('n', account: '4222'),
        );
        expect(d.verdict, IdentityVerdict.distinct);
        expect(d.reason, 'one_sided_reference_not_fuzzy_matched');
      },
    );

    test('weak pair matches within 60 seconds', () {
      final d = PaymentIdentityMatcher.compare(sms('s', sec: 59), sig('n'));
      expect(d.verdict, IdentityVerdict.candidateEcho);
      expect(d.reason, 'weak_modality_pair');
    });

    test('weak amount-only pair expires after 60 seconds', () {
      final d = PaymentIdentityMatcher.compare(sms('s', sec: 61), sig('n'));
      expect(d.verdict, IdentityVerdict.distinct);
      expect(d.reason, 'no_shared_evidence');
    });

    test('two app notifications are never weak-paired (same modality)', () {
      final d = PaymentIdentityMatcher.compare(
        sig('g', channel: 'notification|googlepay', sec: 10),
        sig('p'),
      );
      expect(d.verdict, IdentityVerdict.distinct);
    });

    test('account conflict blocks a weak pair', () {
      final d = PaymentIdentityMatcher.compare(
        sms('s', sec: 10, account: '1111'),
        sig('n', account: '2222'),
      );
      expect(d.verdict, IdentityVerdict.distinct);
      expect(d.reason, 'account_conflict');
    });

    test('payer conflict blocks a weak pair', () {
      final d = PaymentIdentityMatcher.compare(
        sms('s', sec: 10, payer: 'ravi kumar'),
        sig('n', payer: 'anna devi'),
      );
      expect(d.verdict, IdentityVerdict.distinct);
      expect(d.reason, 'payer_conflict');
    });

    test('SMS 90 minutes later pairs only with shared payer', () {
      final paired = PaymentIdentityMatcher.compare(
        sms('s', sec: 90 * 60, payer: 'anna devi'),
        sig('n', payer: 'anna devi'),
      );
      expect(paired.verdict, IdentityVerdict.candidateEcho);
      final unpaired = PaymentIdentityMatcher.compare(
        sms('s', sec: 90 * 60),
        sig('n'),
      );
      expect(unpaired.verdict, IdentityVerdict.distinct);
    });

    test('unknown or different direction never fuzzy-matches', () {
      expect(
        PaymentIdentityMatcher.compare(
          sms('s', sec: 5),
          sig('n', direction: 'unknown'),
        ).verdict,
        IdentityVerdict.distinct,
      );
      expect(
        PaymentIdentityMatcher.compare(
          sms('s', sec: 5),
          sig('n', direction: 'debit'),
        ).verdict,
        IdentityVerdict.distinct,
      );
    });

    test('distinct native posts in one channel are distinct payments', () {
      final d = PaymentIdentityMatcher.compare(
        sig('b', source: 'p|2|200', sec: 5, text: 'x'),
        sig('a', source: 'p|1|100', text: 'x'),
      );
      expect(d.verdict, IdentityVerdict.distinct);
    });

    test('same notification slot update is a possible match, not proof', () {
      final d = PaymentIdentityMatcher.compare(
        sig(
          'first',
          source: 'post-a',
          notificationStream: 'package|tag|id',
          notificationAt: _t0,
          notificationPayer: 'रवि कुमार',
        ),
        sig(
          'update',
          source: 'post-b',
          notificationStream: 'package|tag|id',
          notificationAt: _t0.add(const Duration(seconds: 20)),
          notificationPayer: 'रवि कुमार',
          sec: 60,
        ),
      );

      expect(d.verdict, IdentityVerdict.candidateEcho);
      expect(d.reason, 'same_notification_update');
    });

    test('notification repost conflicts stay distinct', () {
      final first = sig(
        'first',
        source: 'post-a',
        notificationStream: 'package|tag|id',
        notificationAt: _t0,
        payer: 'first payer',
      );
      expect(
        PaymentIdentityMatcher.compare(
          first,
          sig(
            'different-payer',
            source: 'post-b',
            notificationStream: 'package|tag|id',
            notificationAt: _t0.add(const Duration(seconds: 2)),
            payer: 'different payer',
            notificationPayer: 'अन्ना देवी',
          ),
        ).verdict,
        IdentityVerdict.distinct,
      );
      expect(
        PaymentIdentityMatcher.compare(
          first,
          sig(
            'different-direction',
            source: 'post-b',
            notificationStream: 'package|tag|id',
            notificationAt: _t0.add(const Duration(seconds: 2)),
            direction: 'debit',
          ),
        ).verdict,
        IdentityVerdict.distinct,
      );
      expect(
        PaymentIdentityMatcher.compare(
          first,
          sig(
            'unknown-direction',
            source: 'post-b',
            notificationStream: 'package|tag|id',
            notificationAt: _t0.add(const Duration(seconds: 2)),
            direction: 'unknown',
          ),
        ).verdict,
        IdentityVerdict.distinct,
      );
    });

    test('notification repost outside source-time window stays distinct', () {
      final d = PaymentIdentityMatcher.compare(
        sig(
          'first',
          source: 'post-a',
          notificationStream: 'package|tag|id',
          notificationAt: _t0,
        ),
        sig(
          'later',
          source: 'post-b',
          notificationStream: 'package|tag|id',
          notificationAt: _t0.add(const Duration(seconds: 61)),
          sec: 61,
        ),
      );

      expect(d.verdict, IdentityVerdict.distinct);
    });

    test(
      'same notification slot and amount without identity is a possible match',
      () {
        final d = PaymentIdentityMatcher.compare(
          sig(
            'first',
            source: 'post-a',
            notificationStream: 'package|tag|id',
            notificationAt: _t0,
          ),
          sig(
            'repost',
            source: 'post-b',
            notificationStream: 'package|tag|id',
            notificationAt: _t0.add(const Duration(seconds: 2)),
            sec: 2,
          ),
        );

        expect(d.verdict, IdentityVerdict.candidateEcho);
        expect(d.reason, 'same_notification_stream_amount');
      },
    );

    test(
      'same-channel exact replay is only a possible match without identity',
      () {
        final inside = PaymentIdentityMatcher.compare(
          sig('b', sec: 2, text: 'paid'),
          sig('a', text: 'paid'),
        );
        expect(inside.verdict, IdentityVerdict.candidateEcho);
        final outside = PaymentIdentityMatcher.compare(
          sig('b', sec: 30, text: 'paid'),
          sig('a', text: 'paid'),
        );
        expect(outside.verdict, IdentityVerdict.distinct);
      },
    );

    test('truecaller mirror: 8s window and trusted counterpart only', () {
      SignalIdentity tc(int sec) => sig(
        't',
        channel: 'truecaller_notification|truecaller',
        origin: 'truecaller_notification',
        sec: sec,
      );
      expect(
        PaymentIdentityMatcher.compare(tc(5), sig('n')).verdict,
        IdentityVerdict.candidateEcho,
      );
      expect(
        PaymentIdentityMatcher.compare(tc(9), sig('n')).verdict,
        IdentityVerdict.distinct,
      );
      expect(
        PaymentIdentityMatcher.compare(
          tc(5),
          sig('n', channel: 'notification|randomapp'),
        ).verdict,
        IdentityVerdict.distinct,
      );
    });

    test('Truecaller bank label does not conflict with a payer name', () {
      final truecaller = sig(
        'truecaller',
        channel: 'truecaller_notification|truecaller',
        origin: 'truecaller_notification',
        payer: 'apg bank',
        account: '4222',
        sec: 5,
      );
      final paymentApp = sig('payment-app', payer: 'Anna Devi');

      final result = PaymentIdentityMatcher.compare(truecaller, paymentApp);
      expect(result.verdict, IdentityVerdict.candidateEcho);
      expect(result.reason, 'truecaller_mirror');
    });

    test('Truecaller mirror never overrides a conflicting account', () {
      final truecaller = sig(
        'truecaller',
        channel: 'truecaller_notification|truecaller',
        origin: 'truecaller_notification',
        payer: 'apg bank',
        account: '4222',
        sec: 5,
      );
      final paymentApp = sig(
        'payment-app',
        payer: 'Anna Devi',
        account: '9999',
      );

      final result = PaymentIdentityMatcher.compare(truecaller, paymentApp);
      expect(result.verdict, IdentityVerdict.distinct);
      expect(result.reason, 'account_conflict');
    });

    test('Truecaller bank label is ignored for one-sided reference checks', () {
      final truecaller = sig(
        'truecaller',
        channel: 'truecaller_notification|truecaller',
        origin: 'truecaller_notification',
        payer: 'apg bank',
        sec: 5,
      );
      final paymentApp = sig(
        'payment-app',
        payer: 'Anna Devi',
        reference: '412345678901',
      );

      final result = PaymentIdentityMatcher.compare(truecaller, paymentApp);
      expect(result.verdict, IdentityVerdict.candidateEcho);
      expect(result.reason, 'truecaller_mirror');
    });
  });

  group('resolve (uniqueness and claims)', () {
    test('notification and SMS with the same payer merge when unambiguous', () {
      final r = PaymentIdentityMatcher.resolve(
        sms('s', sec: 20, payer: 'Ravi Kumar'),
        [sig('n', payer: 'Ravi Kumar')],
      );
      expect(r.isEcho, true);
      expect(r.matchedId, 'n');
      expect(r.claimChannel, 'sms|banksms');
      expect(r.reason, 'same_payer');
    });

    test('a second SMS cannot reuse a payment already paired with SMS', () {
      final r = PaymentIdentityMatcher.resolve(
        sms('s2', sec: 30),
        [sig('n')],
        claims: {
          'n': {'sms|banksms'},
        },
      );
      expect(r.isEcho, false);
      expect(r.possibleMatch, false);
    });

    test('one SMS matching two earlier notifications keeps both separate', () {
      final r = PaymentIdentityMatcher.resolve(sms('s', sec: 15), [
        sig('n1'),
        sig('n2', channel: 'notification|googlepay', sec: 5),
      ]);
      expect(r.isEcho, false);
      expect(r.ambiguous, true);
    });

    test('shared account evidence is still only a possible match', () {
      final r = PaymentIdentityMatcher.resolve(
        sms('s', sec: 15, reference: '412345678901', account: '4222'),
        [
          sig('weak', sec: 2),
          sig(
            'account-match',
            channel: 'notification|googlepay',
            sec: 5,
            account: '4222',
          ),
        ],
      );
      expect(r.isEcho, false);
      expect(r.possibleMatch, true);
      expect(r.ambiguous, true);
    });

    test('multiple evidence-backed matches remain ambiguous', () {
      final r = PaymentIdentityMatcher.resolve(
        sms('s', sec: 15, account: '4222'),
        [
          sig('n1', account: '4222'),
          sig('n2', channel: 'notification|googlepay', sec: 5, account: '4222'),
        ],
      );
      expect(r.isEcho, false);
      expect(r.possibleMatch, true);
      expect(r.ambiguous, true);
    });

    test('a genuine second same-amount payment 90s later is not swallowed', () {
      final r = PaymentIdentityMatcher.resolve(sms('s', sec: 90), [sig('n')]);
      expect(r.isEcho, false);
    });

    test('proof wins even when other candidates exist', () {
      final r = PaymentIdentityMatcher.resolve(
        sms('s', sec: 20, reference: '412345678901'),
        [
          sig('x', channel: 'notification|googlepay'),
          sig('n', reference: '412345678901'),
        ],
      );
      expect(r.isEcho, true);
      expect(r.matchedId, 'n');
      expect(r.reason, 'same_reference');
    });

    test('weak matches stay separate and describe() is loggable', () {
      final r = PaymentIdentityMatcher.resolve(sms('s', sec: 20), [sig('n')]);
      expect(r.isEcho, false);
      expect(r.possibleMatch, true);
      expect(r.describe('s'), 'kept s separate reason=no_match');
    });
  });
  group('weak modality source scope', () {
    test('SMS plus accessibility is not enough to merge', () {
      final d = PaymentIdentityMatcher.compare(
        sms('s'),
        sig('a', channel: 'accessibility|payment-app', origin: 'accessibility'),
      );
      expect(d.verdict, IdentityVerdict.distinct);
    });

    test('SMS plus Truecaller uses the existing trusted mirror rule', () {
      final d = PaymentIdentityMatcher.compare(
        sms('s'),
        sig(
          't',
          channel: 'truecaller_notification|truecaller',
          origin: 'truecaller_notification',
          sec: 5,
        ),
      );
      expect(d.verdict, IdentityVerdict.candidateEcho);
      expect(d.reason, 'truecaller_mirror');
    });

    test('SMS plus ordinary payment notification remains eligible', () {
      final d = PaymentIdentityMatcher.compare(sms('s'), sig('n'));
      expect(d.verdict, IdentityVerdict.candidateEcho);
    });
  });
}
