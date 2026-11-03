import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/low_stock_alerts_service.dart';

void main() {
  group('LowStockProduct decimal stock handling', () {
    test('preserves fractional current and minimum stock values', () {
      final product = LowStockProduct.fromJson({
        'id': 7,
        'product_name': 'Loose Rice',
        'sku': 'RICE-001',
        'current_stock': 0.375,
        'min_stock': 0.500,
        'reorder_level': 1.250,
        'max_stock': 25,
        'unit_price': 60,
        'category': 'Grains',
      });

      expect(product.currentStock, 0.375);
      expect(product.minStock, 0.5);
      expect(product.reorderLevel, 1.25);
      expect(product.suggestedOrderQuantity, 37.125);
      expect(product.urgencyLevel, 'CRITICAL');
    });

    test('accepts numeric strings and identifies zero stock', () {
      final product = LowStockProduct.fromJson({
        'id': '8',
        'product_name': 'Sugar',
        'current_stock': '0',
        'min_stock': '2.500',
        'max_stock': '10',
        'unit_price': '48.50',
      });

      expect(product.currentStock, 0);
      expect(product.minStock, 2.5);
      expect(product.unitPrice, 48.5);
      expect(product.daysUntilEmpty, 0);
    });
  });

  group('StockAlertDetails decimal stock handling', () {
    test('preserves fractional values from API', () {
      final details = StockAlertDetails.fromJson({
        'product_id': 12,
        'product_name': 'Cooking Oil',
        'current_stock': '0.250',
        'min_stock': '0.500',
        'reorder_level': '1.000',
        'daily_consumption': '0.125',
        'estimated_restock_days': '2',
      });

      expect(details.currentStock, 0.25);
      expect(details.minStock, 0.5);
      expect(details.reorderLevel, 1);
      expect(details.dailyConsumption, 0.125);
      expect(details.alertMessage, contains('0.25'));
    });
  });
}
