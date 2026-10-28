import 'package:flutter_test/flutter_test.dart';
import '../lib/voice_billing_price_policy.dart';

void main() {
  group('VoiceBillingPricePolicy', () {
    test('keeps a spoken unit price when it differs from catalogue price', () {
      final result = VoiceBillingPricePolicy.resolveParsedPrice(
        rawPriceSource: 'spoken_unit',
        detectedPrice: 42,
        cataloguePrice: 35,
        productName: 'Rice',
      );

      expect(result.price, 42);
      expect(result.source, 'spoken_unit');
      expect(result.warning, contains('₹42.00'));
      expect(result.warning, contains('₹35.00'));
      expect(result.warning, contains('shown for review'));
    });

    test('keeps a normalized spoken line-total price', () {
      final result = VoiceBillingPricePolicy.resolveParsedPrice(
        rawPriceSource: 'spoken_line_total',
        detectedPrice: 17.5,
        cataloguePrice: 15,
        productName: 'Soap',
      );

      expect(result.price, 17.5);
      expect(result.source, 'spoken_line_total');
      expect(result.warning, isNotNull);
    });

    test('uses catalogue price when the backend says the price is catalogued',
        () {
      final result = VoiceBillingPricePolicy.resolveParsedPrice(
        rawPriceSource: 'catalog',
        detectedPrice: 42,
        cataloguePrice: 35,
        productName: 'Rice',
      );

      expect(result.price, 35);
      expect(result.source, 'catalog');
      expect(result.warning, isNull);
    });

    test('requires a positive price if neither source has a usable price', () {
      final result = VoiceBillingPricePolicy.resolveParsedPrice(
        rawPriceSource: 'spoken_unit',
        detectedPrice: 0,
        cataloguePrice: null,
        productName: 'Rice',
      );

      expect(result.hasPrice, isFalse);
      expect(result.source, 'missing');
    });

    test('allows a spoken price to be reviewed when catalogue price is absent',
        () {
      final result = VoiceBillingPricePolicy.resolveParsedPrice(
        rawPriceSource: 'spoken_unit',
        detectedPrice: 12,
        cataloguePrice: null,
        productName: 'Oil',
      );

      expect(result.price, 12);
      expect(result.source, 'spoken_unit');
      expect(result.warning, contains('No valid selling price is saved'));
    });

    test('final billing gate preserves valid spoken prices', () {
      for (final source in <String>[
        'spoken',
        'spoken_unit',
        'spoken_line_total',
      ]) {
        expect(
          VoiceBillingPricePolicy.resolveFinalPrice(
            priceSource: source,
            itemPrice: 42,
            cataloguePrice: 35,
          ),
          42,
          reason: 'Expected $source prices to be preserved',
        );
      }
    });

    test('manual edits win and catalogue items use catalogue price', () {
      expect(
        VoiceBillingPricePolicy.resolveFinalPrice(
          priceSource: 'manual',
          itemPrice: 39,
          cataloguePrice: 35,
        ),
        39,
      );
      expect(
        VoiceBillingPricePolicy.resolveFinalPrice(
          priceSource: 'catalog',
          itemPrice: 42,
          cataloguePrice: 35,
        ),
        35,
      );
    });
  });
}
