import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/gst_calculator.dart';

void main() {
  group('GstCalculator', () {
    test('calculates half-kilo items with precise GST paise rounding', () {
      final result = GstCalculator.calculateItemGST(
        price: 199.90,
        quantity: 0.5,
        gstRate: 5,
      );

      expect(result.subtotal, 99.95);
      expect(result.cgst, 2.50);
      expect(result.sgst, 2.50);
      expect(result.totalGST, 5);
      expect(result.grandTotal, 104.95);
    });

    test('discounted fractional quantities reconcile with batch GST', () {
      final discounted = GstCalculator.calculateWithDiscount(
        price: 199.99,
        quantity: 0.25,
        discountPercent: 10,
        gstRate: 18,
      );
      final batch = GstCalculator.calculateBatchGST(
        items: [GstItem(price: 199.99, quantity: 0.25, gstRate: 18)],
      );

      expect(discounted.subtotal, closeTo(49.9975, 0.000001));
      expect(discounted.discountedPrice, 45);
      expect(discounted.cgst, 4.05);
      expect(discounted.sgst, 4.05);
      expect(discounted.totalGST, 8.10);
      expect(discounted.grandTotal, 53.10);
      expect(batch.subtotal, discounted.subtotal);
      expect(batch.cgst, 4.50);
      expect(batch.sgst, 4.50);
      expect(batch.totalGST, 9.00);
      expect(batch.cgst + batch.sgst, batch.totalGST);
    });

    test('splits an odd paise of GST without inflating the invoice tax', () {
      final result = GstCalculator.calculateItemGST(
        price: 0.10,
        quantity: 1,
        gstRate: 10,
      );

      expect(result.totalGST, 0.01);
      expect(result.cgst + result.sgst, result.totalGST);
      expect(result.grandTotal, 0.11);
    });

    test('rejects invalid quantities and non-finite prices', () {
      expect(
        () =>
            GstCalculator.calculateItemGST(price: 10, quantity: 0, gstRate: 5),
        throwsArgumentError,
      );
      expect(
        () => GstCalculator.calculateItemGST(
          price: double.infinity,
          quantity: 0.5,
          gstRate: 5,
        ),
        throwsArgumentError,
      );
    });
  });
}
