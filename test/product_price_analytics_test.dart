import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/charts/product_price_analytics.dart';

void main() {
  group('product and selling-price chart aggregation', () {
    test('combines repeated sales at the same product and price', () {
      final rows = ProductPriceAnalytics.aggregateSales([
        {
          'sale_id': 'bill-1',
          'items': [
            {
              'product_id': 12,
              'product_name': 'Rice',
              'quantity': 1,
              'unit_price': 50,
              'line_total': 50,
            },
          ],
        },
        {
          'sale_id': 'bill-2',
          'items': [
            {
              'product_id': 12,
              'product_name': 'Rice',
              'quantity': 2,
              'unit_price': 50,
              'line_total': 100,
            },
          ],
        },
      ]);

      expect(rows, hasLength(1));
      expect(rows.single.productName, 'Rice');
      expect(rows.single.unitPrice, 50.0);
      expect(rows.single.quantity, 3.0);
      expect(rows.single.revenue, 150.0);
      expect(rows.single.label, 'Rice · ₹50.00');
    });

    test('shows the same product as separate entries at different prices', () {
      final rows = ProductPriceAnalytics.aggregateSales([
        {
          'items': [
            {
              'product_id': 12,
              'product_name': 'Rice',
              'quantity': 1,
              'price': 50,
              'total': 50,
            },
            {
              'product_id': 12,
              'product_name': 'Rice',
              'quantity': 2,
              'price': 60,
              'total': 120,
            },
          ],
        },
      ]);

      expect(rows, hasLength(2));
      expect(rows.map((row) => row.unitPrice).toSet(), equals({50.0, 60.0}));
      expect(rows.map((row) => row.label).toSet(),
          equals({'Rice · ₹50.00', 'Rice · ₹60.00'}));
    });

    test('keeps different catalog products separate at the same price', () {
      final rows = ProductPriceAnalytics.aggregateSales([
        {
          'items': [
            {
              'product_id': 12,
              'product_name': 'Rice',
              'quantity': 1,
              'price': 50,
              'total': 50,
            },
            {
              'product_id': 13,
              'product_name': 'Flour',
              'quantity': 1,
              'price': 50,
              'total': 50,
            },
          ],
        },
      ]);

      expect(rows, hasLength(2));
      expect(rows.map((row) => row.key).toSet(), hasLength(2));
    });

    test('supports flattened legacy sales rows and normalized name identity', () {
      final rows = ProductPriceAnalytics.aggregateSales([
        {
          'product_name': '  Rice  ',
          'quantity': 1,
          'price': 50,
          'line_total': 50,
        },
        {
          'product_name': 'rice',
          'qty': 2,
          'unit_price': 50,
          'total': 100,
        },
      ]);

      expect(rows, hasLength(1));
      expect(rows.single.quantity, 3.0);
      expect(rows.single.revenue, 150.0);
    });

    test('monthly chart availability is independent of zero-only months', () {
      expect(
        ProductPriceAnalytics.hasPositiveMonthlyRevenue({
          'Jun 26': 0,
          'Jul 26': 120,
        }),
        isTrue,
      );
      expect(
        ProductPriceAnalytics.hasPositiveMonthlyRevenue({
          'Jun 26': 0,
          'Jul 26': 0,
        }),
        isFalse,
      );
      expect(ProductPriceAnalytics.hasPositiveMonthlyRevenue({}), isFalse);
    });
  });
}
