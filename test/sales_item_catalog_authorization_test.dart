import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/features/sales_entry/models/sales_item.dart';

void main() {
  group('SalesItem catalogue authorization', () {
    test('an unmatched voice item cannot carry a stock link', () {
      const item = SalesItem(
        id: 'voice-custom',
        itemName: 'Milk',
        productId: 42,
        catalogMatched: false,
      );

      expect(item.isStockTracked, isFalse);
      expect(item.catalogAuthorizedProductId, isNull);
    });

    test('only an explicitly matched positive ID is stock-authorized', () {
      const item = SalesItem(
        id: 'voice-matched',
        itemName: 'Milk',
        productId: 42,
        catalogMatched: true,
      );

      expect(item.isStockTracked, isTrue);
      expect(item.catalogAuthorizedProductId, 42);
    });

    test('true without a valid ID fails closed', () {
      const missingId = SalesItem(
        id: 'voice-invalid',
        itemName: 'Milk',
        catalogMatched: true,
      );
      const invalidId = SalesItem(
        id: 'voice-invalid-id',
        itemName: 'Milk',
        productId: 0,
        catalogMatched: true,
      );

      expect(missingId.isStockTracked, isFalse);
      expect(invalidId.isStockTracked, isFalse);
      expect(missingId.catalogAuthorizedProductId, isNull);
      expect(invalidId.catalogAuthorizedProductId, isNull);
    });

    test('explicit product selection can authorize a previously untracked line', () {
      const custom = SalesItem(
        id: 'voice-custom',
        itemName: 'Milk',
        catalogMatched: false,
      );

      final selected = custom.copyWith(productId: 77);

      expect(selected.isStockTracked, isTrue);
      expect(selected.catalogAuthorizedProductId, 77);
    });

    test('renaming an authorized voice item clears its stock authorization', () {
      const matched = SalesItem(
        id: 'voice-matched',
        itemName: 'Milk',
        productId: 42,
        catalogMatched: true,
      );

      final renamed = matched.copyWith(itemName: 'Almond milk');

      expect(renamed.productId, isNull);
      expect(renamed.catalogMatched, isFalse);
      expect(renamed.isStockTracked, isFalse);
    });

    test('ordinary manual entries retain backwards-compatible behaviour', () {
      const manual = SalesItem(id: 'manual', itemName: 'Milk');

      expect(manual.catalogMatched, isNull);
      expect(manual.isStockTracked, isTrue);
    });
  });
}
