import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/voice_billing_safety_policy.dart';

void main() {
  group('VoiceBillingSafetyPolicy', () {
    test('does not merge an unpriced quantity with a priced quantity', () {
      expect(
        VoiceBillingSafetyPolicy.canMerge(
          currentName: 'Rice',
          currentUnit: 'kg',
          currentPrice: 0,
          currentPriceSource: 'missing',
          incomingName: 'Rice',
          incomingUnit: 'kg',
          incomingPrice: 50,
          incomingPriceSource: 'spoken',
        ),
        isFalse,
      );
    });

    test('merges only equal price and equal provenance', () {
      expect(
        VoiceBillingSafetyPolicy.canMerge(
          currentName: 'Rice',
          currentUnit: 'kg',
          currentPrice: 50,
          currentPriceSource: 'catalog',
          incomingName: 'rice',
          incomingUnit: 'KG',
          incomingPrice: 50,
          incomingPriceSource: 'catalog',
        ),
        isTrue,
      );
      expect(
        VoiceBillingSafetyPolicy.canMerge(
          currentName: 'Rice',
          currentUnit: 'kg',
          currentPrice: 50,
          currentPriceSource: 'catalog',
          incomingName: 'Rice',
          incomingUnit: 'kg',
          incomingPrice: 50,
          incomingPriceSource: 'spoken',
        ),
        isFalse,
      );
    });

    test('does not merge lines with different prices or units', () {
      final base = <String, Object>{
        'currentName': 'Rice',
        'currentUnit': 'kg',
        'currentPrice': 50.0,
        'currentPriceSource': 'spoken',
        'incomingName': 'Rice',
        'incomingUnit': 'kg',
        'incomingPrice': 51.0,
        'incomingPriceSource': 'spoken',
      };
      bool canMerge(Map<String, Object> values) =>
          VoiceBillingSafetyPolicy.canMerge(
            currentName: values['currentName'] as String,
            currentUnit: values['currentUnit'] as String,
            currentPrice: values['currentPrice'] as double,
            currentPriceSource: values['currentPriceSource'] as String,
            incomingName: values['incomingName'] as String,
            incomingUnit: values['incomingUnit'] as String,
            incomingPrice: values['incomingPrice'] as double,
            incomingPriceSource: values['incomingPriceSource'] as String,
          );

      expect(canMerge(base), isFalse);
      expect(
        canMerge({...base, 'incomingPrice': 50.0, 'incomingUnit': 'pc'}),
        isFalse,
      );
    });

    test('merges two unpriced lines only when their price source agrees', () {
      expect(
        VoiceBillingSafetyPolicy.canMerge(
          currentName: 'Salt',
          currentUnit: 'pkt',
          currentPrice: 0,
          currentPriceSource: 'missing',
          incomingName: 'Salt',
          incomingUnit: 'pkt',
          incomingPrice: 0,
          incomingPriceSource: 'missing',
        ),
        isTrue,
      );
      expect(
        VoiceBillingSafetyPolicy.canMerge(
          currentName: 'Salt',
          currentUnit: 'pkt',
          currentPrice: 0,
          currentPriceSource: 'missing',
          incomingName: 'Salt',
          incomingUnit: 'pkt',
          incomingPrice: 0,
          incomingPriceSource: 'manual',
        ),
        isFalse,
      );
    });

    test('recognizes all backend review and quantity-grounding flags', () {
      expect(
        VoiceBillingSafetyPolicy.requiresManualReview({
          'needs_confirmation': true,
        }),
        isTrue,
      );
      expect(
        VoiceBillingSafetyPolicy.requiresManualReview({
          'unit_mismatch': true,
        }),
        isTrue,
      );
      expect(
        VoiceBillingSafetyPolicy.requiresManualReview({
          'quantity_grounded': false,
        }),
        isTrue,
      );
      expect(
        VoiceBillingSafetyPolicy.requiresManualReview({
          'ambiguous_candidates': ['Rice 1kg', 'Rice 5kg'],
        }),
        isTrue,
      );
      expect(
        VoiceBillingSafetyPolicy.requiresManualReview({
          'needs_confirmation': false,
          'quantity_grounded': true,
          'ambiguous_candidates': <Object>[],
        }),
        isFalse,
      );
    });

    test('rejects NaN and out-of-range extraction confidence', () {
      expect(VoiceBillingSafetyPolicy.hasValidConfidence(double.nan), isFalse);
      expect(VoiceBillingSafetyPolicy.hasValidConfidence(-0.1), isFalse);
      expect(VoiceBillingSafetyPolicy.hasValidConfidence(1.1), isFalse);
      expect(VoiceBillingSafetyPolicy.hasValidConfidence(0.75), isTrue);
    });

    test('treats transient cloud status codes as retryable', () {
      expect(
        const VoiceBillingApiException(statusCode: 503, message: 'Unavailable')
            .isTransient,
        isTrue,
      );
      expect(
        const VoiceBillingApiException(statusCode: 429, message: 'Rate limited')
            .isTransient,
        isTrue,
      );
      expect(
        const VoiceBillingApiException(statusCode: 401, message: 'Unauthorized')
            .isTransient,
        isFalse,
      );
    });
  });
}
