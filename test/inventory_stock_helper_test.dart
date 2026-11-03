import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/inventory_stock_helper.dart';

void main() {
  group('InventoryStockHelper.parseProductsResponse', () {
    final product = <String, dynamic>{
      'id': 7,
      'name': 'Rice',
      'stock': '12.5',
      'min_stock': '4',
    };

    test('accepts a direct product list', () {
      final result = InventoryStockHelper.parseProductsResponse([product]);

      expect(result, hasLength(1));
      expect(result.single['id'], 7);
      expect(result.single['product_name'], 'Rice');
      expect(result.single['current_stock'], 12.5);
      expect(result.single['quantity'], 12.5);
    });

    for (final key in ['data', 'products', 'results', 'items']) {
      test('accepts a $key envelope', () {
        final result = InventoryStockHelper.parseProductsResponse({
          key: [product],
        });

        expect(result, hasLength(1));
        expect(result.single['product_name'], 'Rice');
      });
    }

    test('accepts nested envelopes and JSON-encoded lists', () {
      final response = jsonEncode({
        'data': jsonEncode({
          'items': [product],
        }),
      });

      final result = InventoryStockHelper.parseProductsResponse(response);

      expect(result, hasLength(1));
      expect(result.single['product_id'], 7);
    });

    test('accepts a JSON-encoded direct list', () {
      final result = InventoryStockHelper.parseProductsResponse(
        jsonEncode([product]),
      );
      expect(result, hasLength(1));
    });

    test('accepts a single product object', () {
      final result = InventoryStockHelper.parseProductsResponse(product);
      expect(result, hasLength(1));
      expect(result.single['id'], 7);
    });

    test('preserves a valid empty product list', () {
      expect(InventoryStockHelper.parseProductsResponse({'data': []}), isEmpty);
    });

    test(
      'rejects an unknown response envelope instead of showing false empty inventory',
      () {
        expect(
          () => InventoryStockHelper.parseProductsResponse({
            'message': 'temporarily unavailable',
          }),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });

  group('InventoryStockHelper.parseStockThresholdInput', () {
    test('accepts integer-shaped decimals and fractional stock thresholds', () {
      expect(InventoryStockHelper.parseStockThresholdInput('10.0'), 10.0);
      expect(InventoryStockHelper.parseStockThresholdInput('2.5'), 2.5);
    });

    test('rejects empty, negative, non-finite, and malformed values', () {
      expect(InventoryStockHelper.parseStockThresholdInput(''), isNull);
      expect(InventoryStockHelper.parseStockThresholdInput('-1'), isNull);
      expect(InventoryStockHelper.parseStockThresholdInput('NaN'), isNull);
      expect(InventoryStockHelper.parseStockThresholdInput('abc'), isNull);
    });
  });

  group('InventoryStockHelper stock classification', () {
    test('treats the minimum threshold as low stock, including decimals', () {
      final product = InventoryStockHelper.normalizeProduct({
        'id': 1,
        'product_name': 'Loose Rice',
        'current_stock': '0.500',
        'min_stock': '0.500',
        'unit': 'kg',
      });

      expect(InventoryStockHelper.isLowStock(product), isTrue);
      expect(InventoryStockHelper.isOutOfStock(product), isFalse);
      expect(InventoryStockHelper.isInStock(product), isFalse);
    });

    test('keeps zero stock in the separate out-of-stock category', () {
      final product = InventoryStockHelper.normalizeProduct({
        'id': 2,
        'product_name': 'Sugar',
        'current_stock': '0',
        'min_stock': '2.5',
      });

      expect(InventoryStockHelper.isOutOfStock(product), isTrue);
      expect(InventoryStockHelper.isLowStock(product), isFalse);
      expect(InventoryStockHelper.isInStock(product), isFalse);
    });

    test('uses the legacy default threshold of 10 when missing', () {
      final product = InventoryStockHelper.normalizeProduct({
        'id': 3,
        'product_name': 'Oil',
        'current_stock': '9.5',
      });

      expect(product['min_stock'], 10.0);
      expect(InventoryStockHelper.isLowStock(product), isTrue);
    });

    test('classifies stock above the threshold as in stock', () {
      final product = InventoryStockHelper.normalizeProduct({
        'id': 4,
        'product_name': 'Soap',
        'current_stock': '10.001',
        'min_stock': '10',
      });

      expect(InventoryStockHelper.isInStock(product), isTrue);
      expect(InventoryStockHelper.isLowStock(product), isFalse);
      expect(InventoryStockHelper.isOutOfStock(product), isFalse);
    });
  });

  group('InventoryStockHelper.findDuplicateProducts', () {
    final book = <String, dynamic>{
      'id': 42, 'product_name': 'Classmate Notebook',
      'sku': '8901234567890', 'unit_price': 45,
      'current_stock': 12, 'min_stock': 2.5,
      'unit': 'pcs', 'category': 'Stationery', 'is_active': true,
    };

    test('returns existing details for exact name and barcode matches', () {
      final matches = InventoryStockHelper.findDuplicateProducts(
        [book], productName: ' CLASSMATE   NOTEBOOK ', sku: '8901234567890',
      );
      expect(matches, hasLength(1));
      expect(matches.single['match_types'], containsAll(['PRODUCT_NAME', 'BARCODE']));
      expect(matches.single['product']['product_name'], 'Classmate Notebook');
      expect(matches.single['product']['current_stock'], 12);
      expect(matches.single['product']['min_stock'], 2.5);
    });

    test('allows editing the same product', () {
      final matches = InventoryStockHelper.findDuplicateProducts(
        [book], productName: 'Classmate Notebook',
        sku: '8901234567890', excludeProductId: 42,
      );
      expect(matches, isEmpty);
    });

    test('barcode match works when product names differ', () {
      final matches = InventoryStockHelper.findDuplicateProducts(
        [book], productName: 'Another book', sku: '8901234567890',
      );
      expect(matches.single['match_types'], ['BARCODE']);
    });
  });

  test(
    'deduplicates API products and does not resurrect acknowledged stale cache rows',
    () {
      final result = InventoryStockHelper.mergeApiWithLocalCache(
        [
          {'id': 1, 'product_name': 'Rice', 'current_stock': 10},
          {'id': 1, 'product_name': 'Rice', 'current_stock': 12},
        ],
        [
          {'id': 1, 'product_name': 'Rice', 'current_stock': 9},
          {'id': 2, 'product_name': 'Deleted item', 'current_stock': 5},
        ],
      );

      expect(result, hasLength(1));
      expect(result.single['id'], 1);
      expect(result.single['current_stock'], 12);
    },
  );
}
