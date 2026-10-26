import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/voice_billing_assistant.dart';

void main() {
  group('translated detected-item display and sale identity', () {
    test('catalogue-backed item keeps its canonical name and stock identity', () {
      final item = ParsedItem(
        name: 'Soap',
        qty: 1,
        unit: 'pc',
        price: 70,
        confidence: 0.99,
        catalogMatched: true,
        priceSource: 'catalog',
        barcode: 'SOAP-001',
        productId: '42',
        isConfirmed: true,
      );

      // The UI translates a separate LiveTranslatedText display value. The
      // model passed to Add to Bill must remain canonical for exact matching.
      final saleItem = item.toMap();
      expect(saleItem['name'], 'Soap');
      expect(saleItem['product_name'], 'Soap');
      expect(saleItem['product_id'], '42');
      expect(saleItem['barcode'], 'SOAP-001');
      expect(saleItem['catalog_matched'], isTrue);
    });

    test('custom detected item cannot gain catalogue identity by translation', () {
      final item = ParsedItem(
        name: 'Special Soap',
        qty: 1,
        unit: 'pc',
        price: 70,
        confidence: 0.8,
        catalogMatched: false,
        priceSource: 'manual',
        isConfirmed: true,
      );

      final saleItem = item.toMap();
      expect(saleItem['product_name'], 'Special Soap');
      expect(saleItem.containsKey('product_id'), isFalse);
      expect(saleItem.containsKey('barcode'), isFalse);
      expect(saleItem['catalog_matched'], isFalse);
    });
  });
}
