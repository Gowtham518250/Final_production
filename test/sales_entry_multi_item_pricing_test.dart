import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/features/sales_entry/controllers/sales_entry_provider.dart';
import 'package:retail_mind/features/sales_entry/models/sales_item.dart';
import 'package:retail_mind/sale_service.dart';

void main() {
  group('multi-item sale pricing', () {
    test('rapidly added bill rows always receive distinct editor keys', () {
      final provider = SalesEntryProvider();
      provider.addEntry();
      provider.addEntry();
      provider.addEntry();

      final ids = provider.entries.map((entry) => entry.id).toSet();
      expect(ids, hasLength(provider.entries.length));
      provider.dispose();
    });

    test('allows the same catalog product twice at the same unit price', () {
      final provider = SalesEntryProvider();
      provider.entries = [
        const SalesItem(
          id: 'rice-first-line',
          itemName: 'Rice',
          productId: 7,
          quantity: 1,
          price: 50,
        ),
        const SalesItem(
          id: 'rice-second-line',
          itemName: 'Rice',
          productId: 7,
          quantity: 2,
          price: 50,
        ),
      ];

      expect(provider.entries, hasLength(2));
      expect(provider.entries.map((item) => item.id).toSet(), hasLength(2));
      expect(provider.subtotalAmount, 150.00);
      expect(provider.totalAmount, 150.00);
      provider.dispose();
    });

    test(
      "keeps each item's own price, discount and GST rate in the total",
      () async {
        final provider = SalesEntryProvider();
        provider.entries = [
          const SalesItem(
            id: 'rice',
            itemName: 'Rice',
            quantity: 2,
            price: 50,
            gst: 5,
            discount: 10,
          ),
          const SalesItem(
            id: 'flour',
            itemName: 'Flour',
            quantity: 1.5,
            price: 80,
            gst: 12,
            discount: 2,
          ),
        ];

        expect(provider.subtotalAmount, 220.00);
        expect(provider.totalDiscountAmount, 12.00);
        expect(provider.taxableSubtotalAmount, 208.00);
        expect(provider.cgstAmount, 9.33);
        expect(provider.sgstAmount, 9.33);
        expect(provider.taxAmount, 18.66);
        expect(provider.totalAmount, 226.66);

        // A row with a price but no product name must never inflate the bill
        // total or be silently omitted from the line-item upload.
        provider.entries.add(
          const SalesItem(id: 'unnamed', itemName: '', quantity: 1, price: 100),
        );
        expect(provider.totalAmount, 226.66);
        expect(await provider.submitSale(), isFalse);
        expect(provider.lastVoiceMessage, contains('item name'));
        provider.entries.removeLast();

        provider.toggleTax();
        expect(provider.taxAmount, 0.00);
        expect(provider.totalAmount, 208.00);
        provider.dispose();
      },
    );

    test('bills fractional weight using decimal GST calculations', () {
      final provider = SalesEntryProvider()
        ..entries = [
          const SalesItem(
            id: 'half-kilo',
            itemName: 'Loose rice',
            quantity: 0.5,
            price: 199.90,
            gst: 5,
          ),
        ];

      expect(provider.subtotalAmount, 99.95);
      expect(provider.taxAmount, 5.00);
      expect(provider.totalAmount, 104.95);
      provider.dispose();
    });

    test(
      'normalizes two items with separate prices and discounts for cloud sync',
      () {
        final rice = SaleService.normalizeSaleLineItem({
          'product_name': 'Rice',
          'quantity': 2,
          'price': 50,
          'discount': 10,
          'gst': 5,
        });
        final flour = SaleService.normalizeSaleLineItem({
          'product_name': 'Flour',
          'quantity': 1.5,
          'price': 80,
          'discount': 2,
          'gst': 12,
        });

        expect(rice['unit_price'], 50.00);
        expect(rice['quantity'], 2.0);
        expect(rice['discount_amount'], 10.00);
        expect(rice['line_total'], 90.00);
        expect(rice['tax_amount'], 4.50);
        expect(rice['total_with_tax'], 94.50);

        expect(flour['unit_price'], 80.00);
        expect(flour['quantity'], 1.5);
        expect(flour['discount_amount'], 2.00);
        expect(flour['line_total'], 118.00);
        expect(flour['tax_amount'], 14.16);
        expect(flour['total_with_tax'], 132.16);

        final lineSubtotal =
            (rice['line_total'] as double) + (flour['line_total'] as double);
        final invoiceTax =
            (rice['tax_amount'] as double) + (flour['tax_amount'] as double);
        final grandTotal =
            (rice['total_with_tax'] as double) +
            (flour['total_with_tax'] as double);

        expect(lineSubtotal, 208.00);
        expect(invoiceTax, 18.66);
        expect(grandTotal, 226.66);
        expect(grandTotal - invoiceTax, lineSubtotal);
      },
    );

    test('aggregates repeated product quantities before checking stock', () {
      final requests = SaleService.aggregateStockRequests(
        [
          {'product_id': 7, 'product_name': 'Rice', 'quantity': 3, 'price': 50},
          {'product_id': 7, 'product_name': 'Rice', 'quantity': 4, 'price': 55},
        ],
        [
          {'id': 7, 'product_name': 'Rice', 'current_stock': 5},
        ],
      );

      expect(requests, hasLength(1));
      expect(requests.single['requested_qty'], 7.0);
      expect(requests.single['available_stock'], 5.0);
      expect(requests.single['catalog_found'], isTrue);
    });

    test('keeps different catalog products separate in stock validation', () {
      final requests = SaleService.aggregateStockRequests(
        [
          {'product_id': 7, 'product_name': 'Rice', 'qty': 2},
          {'product_id': 8, 'product_name': 'Rice', 'qty': 3},
          {
            'product_id': 7,
            'product_name': 'Rice',
            'qty': 20,
            'is_custom_item': true,
            'stock_tracked': false,
          },
        ],
        [
          {'id': 7, 'product_name': 'Rice', 'current_stock': 5},
          {'id': 8, 'product_name': 'Rice', 'current_stock': 10},
        ],
      );

      expect(requests, hasLength(2));
      expect(
        requests.map((request) => request['requested_qty']).toSet(),
        equals({2.0, 3.0}),
      );
    });

    test('GST disabled does not add tax to any line', () {
      final line = SaleService.normalizeSaleLineItem({
        'product_name': 'Rice',
        'quantity': 2,
        'price': 50,
        'discount': 10,
        'gst': 5,
      }, withTax: false);

      expect(line['line_total'], 90.00);
      expect(line['tax_amount'], 0.00);
      expect(line['total_with_tax'], 90.00);
    });

    test('sale normalization preserves rounded GST for odd-paise totals', () {
      final line = SaleService.normalizeSaleLineItem({
        'product_name': 'Sample item',
        'quantity': 1,
        'price': 0.10,
        'gst': 10,
      });

      expect(line['line_total'], 0.10);
      expect(line['tax_amount'], 0.01);
      expect(line['total_with_tax'], 0.11);
    });
  });
}
