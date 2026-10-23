import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/daily_summary_recipient.dart';

void main() {
  group('DailySummaryRecipient', () {
    test('falls back to user_email when the legacy email key is missing', () {
      expect(
        DailySummaryRecipient.resolve([null, '  Gowtham@Example.com  ', null]),
        'gowtham@example.com',
      );
    });

    test('prefers the first valid account email candidate', () {
      expect(
        DailySummaryRecipient.resolve([
          'owner@example.com',
          'account@example.com',
        ]),
        'owner@example.com',
      );
    });

    test('ignores blank or malformed candidates and continues fallback', () {
      expect(
        DailySummaryRecipient.resolve([
          '',
          'not-an-email',
          '   ',
          'owner@example.com',
        ]),
        'owner@example.com',
      );
    });

    test('returns empty when no usable account email is available', () {
      expect(
        DailySummaryRecipient.resolve([null, '', 'not-an-email']),
        isEmpty,
      );
    });
  });
}
