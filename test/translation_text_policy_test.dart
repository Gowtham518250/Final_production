import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/translation_text_policy.dart';

void main() {
  group('TranslationTextPolicy.isStandaloneNumberOrCurrency', () {
    test('preserves numeric, currency and percentage values', () {
      for (final value in [
        '500',
        '₹500',
        '₹ 1,200.00',
        '-₹350',
        '14.5%',
        'USD 20',
        'GBP 1,200.50',
      ]) {
        expect(
          TranslationTextPolicy.isStandaloneNumberOrCurrency(value),
          isTrue,
          reason: value,
        );
      }
    });

    test('does not match language-bearing descriptions', () {
      for (final value in [
        '500 grams of rice',
        'Milk under ₹80',
        'Total: ₹500',
        '',
      ]) {
        expect(
          TranslationTextPolicy.isStandaloneNumberOrCurrency(value),
          isFalse,
          reason: value,
        );
      }
    });
  });
}
