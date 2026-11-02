import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/features/sales_entry/services/voice_billing_response_policy.dart';

void main() {
  group('voice billing response safety policy', () {
    test('accepts a fully grounded line', () {
      expect(
        voiceBillingItemNeedsManualReview({
          'needs_confirmation': false,
          'unit_mismatch': false,
          'quantity_grounded': true,
        }),
        isFalse,
      );
    });

    test('requires manual review for ungrounded quantity', () {
      expect(
        voiceBillingItemNeedsManualReview({
          'needs_confirmation': true,
          'unit_mismatch': false,
          'quantity_grounded': false,
        }),
        isTrue,
      );
    });

    test('requires manual review for incompatible unit', () {
      expect(
        voiceBillingItemNeedsManualReview({
          'needs_confirmation': true,
          'unit_mismatch': true,
          'quantity_grounded': true,
        }),
        isTrue,
      );
    });

    test('requires manual review when one line in a response is unsafe', () {
      expect(
        voiceBillingResponseNeedsManualReview({
          'needs_clarification': false,
          'items': [
            {
              'needs_confirmation': false,
              'unit_mismatch': false,
              'quantity_grounded': true,
            },
            {
              'needs_confirmation': true,
              'unit_mismatch': false,
              'quantity_grounded': false,
            },
          ],
        }),
        isTrue,
      );
    });

    test('does not allow payload-level clarification to auto-add items', () {
      expect(
        voiceBillingResponseNeedsManualReview({
          'needs_clarification': true,
          'clarification_question': 'Please verify the quantity.',
          'items': [],
        }),
        isTrue,
      );
    });

    test('warning lists ambiguous catalogue choices without using IDs', () {
      final warning = voiceBillingItemReviewWarning({
        'product_name_en': 'Soap',
        'needs_confirmation': true,
        'ambiguous_candidates': [
          {'product_id': 12, 'name': 'Lux Soap 100g'},
          {'product_id': 13, 'name': 'Lux Soap 150g'},
        ],
      });
      expect(warning, contains('Lux Soap 100g'));
      expect(warning, contains('Lux Soap 150g'));
      expect(warning, isNot(contains('product_id')));
    });
  });
}
