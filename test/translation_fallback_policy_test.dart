import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/translation_fallback_policy.dart';

void main() {
  group('translation fallback policy', () {
    test('retries when the on-device model returns the original English', () {
      expect(
        TranslationFallbackPolicy.needsRemoteFallback(
          'Chicken Dum Biryani',
          'Chicken Dum Biryani',
        ),
        isTrue,
      );
    });

    test('retries when the model only changes letter case or whitespace', () {
      expect(
        TranslationFallbackPolicy.needsRemoteFallback(
          'Chicken Dum Biryani',
          ' chicken   dum biryani ',
        ),
        isTrue,
      );
    });

    test('retries when the on-device result is empty', () {
      expect(
        TranslationFallbackPolicy.needsRemoteFallback('Shampoo', '  '),
        isTrue,
      );
    });

    test('keeps a meaningful translation without a remote request', () {
      expect(
        TranslationFallbackPolicy.needsRemoteFallback(
          'Chicken Dum Biryani',
          'చికెన్ దమ్ బిర్యానీ',
        ),
        isFalse,
      );
    });

    test('does not request fallback for an empty source', () {
      expect(
        TranslationFallbackPolicy.needsRemoteFallback('', ''),
        isFalse,
      );
    });
  });
}
