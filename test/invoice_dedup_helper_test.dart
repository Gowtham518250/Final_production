import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/invoice_dedup_helper.dart';

void main() {
  group('InvoiceDedupHelper', () {
    test('merges bridged sale, backend invoice and invoice-number copies', () {
      final rows = <Map<String, dynamic>>[
        {
          'sale_id': 'SALE_LOCAL_100',
          'invoice_id': 42,
          'total_amount': 100.0,
          'paid_amount': 0.0,
          'payment_status': 'UNPAID',
          'customer_phone': '9876543210',
          'created_at': '2026-10-13T10:00:00Z',
        },
        {
          'invoice_number': 'BILL-0042',
          'id': 42,
          'total_amount': 100.0,
          'paid_amount': 25.0,
          'payment_status': 'PARTIAL',
          'updated_at': '2026-10-13T11:00:00Z',
        },
        {
          'invoice_number': 'BILL-0042',
          'total_amount': 100.0,
          'paid_amount': 100.0,
          'payment_status': 'PAID',
          'updated_at': '2026-10-13T12:00:00Z',
        },
      ];

      final result = InvoiceDedupHelper.canonicalizeInvoices(rows);

      expect(result, hasLength(1));
      expect(result.single['sale_id'], 'SALE_LOCAL_100');
      expect(result.single['invoice_number'], 'BILL-0042');
      expect(result.single['invoice_id'], 42);
      expect(result.single['paid_amount'], 100.0);
      expect(result.single['pending_amount'], 0.0);
      expect(result.single['payment_status'], 'PAID');
    });

    test('different invoice identities stay separate with identical amounts', () {
      final result = InvoiceDedupHelper.canonicalizeInvoices([
        {
          'sale_id': 'SALE_A',
          'invoice_number': 'BILL-001',
          'total_amount': 100.0,
          'paid_amount': 0.0,
        },
        {
          'sale_id': 'SALE_B',
          'invoice_number': 'BILL-002',
          'total_amount': 100.0,
          'paid_amount': 0.0,
        },
      ]);

      expect(result, hasLength(2));
    });

    test('paid state wins against a stale unpaid copy', () {
      final result = InvoiceDedupHelper.canonicalizeInvoices([
        {
          'invoice_number': 'BILL-100',
          'total_amount': 250.0,
          'paid_amount': 250.0,
          'payment_status': 'PAID',
          'updated_at': '2026-10-13T12:00:00Z',
        },
        {
          'sale_id': 'BILL-100',
          'total': 250.0,
          'paid_amount': 0.0,
          'payment_status': 'UNPAID',
          'updated_at': '2026-10-13T11:00:00Z',
        },
      ]);

      expect(result, hasLength(1));
      expect(result.single['payment_status'], 'PAID');
      expect(result.single['paid_amount'], 250.0);
      expect(result.single['pending_amount'], 0.0);
    });

    test('standalone sales do not become unpaid invoices', () {
      final result = InvoiceDedupHelper.canonicalizeInvoiceLedger(
        [
          {
            'invoice_number': 'MANUAL-001',
            'total_amount': 36.0,
            'paid_amount': 0.0,
            'customer_phone': '9876543210',
          },
        ],
        [
          {
            'sale_id': 'SALE-001',
            'total_amount': 85.0,
            'created_at': '2026-10-14T10:00:00Z',
          },
        ],
      );

      expect(result, hasLength(1));
      expect(result.single['invoice_number'], 'MANUAL-001');
      expect(result.single['total_amount'], 36.0);
    });

    test('same numeric sale and invoice IDs do not make a sale an invoice mirror', () {
      final result = InvoiceDedupHelper.canonicalizeInvoiceLedger(
        [
          {
            'id': 1,
            'invoice_number': 'MANUAL-001',
            'total_amount': 36.0,
            'paid_amount': 36.0,
            'payment_status': 'PAID',
          },
        ],
        [
          {
            'id': 1,
            'sale_id': 'SALE-001',
            'total_amount': 85.0,
            'paid_amount': 85.0,
            'payment_status': 'PAID',
          },
        ],
      );

      expect(result, hasLength(1));
      expect(result.single['invoice_number'], 'MANUAL-001');
      expect(result.single['total_amount'], 36.0);
      expect(result.single['paid_amount'], 36.0);
    });

    test('invoice mirrors combine all item rows instead of replacing them', () {
      final canonical = InvoiceDedupHelper.canonicalizeInvoiceLedger(
        [
          {
            'id': 77,
            'invoice_number': 'BILL-MULTI-77',
            'total_amount': 1800,
            'paid_amount': 1800,
            'line_items': [
              {
                'product_id': null,
                'description': 'Chicken',
                'quantity': 1,
                'unit_price': 800,
                'line_total': 800,
              },
            ],
          },
        ],
        [
          {
            'sale_id': 'SALE-77',
            'invoice_number': 'BILL-MULTI-77',
            'backend_id': 77,
            'total_amount': 1800,
            'paid_amount': 1800,
            'items': [
              {
                'product_name': 'Mutton',
                'quantity': 1,
                'unit_price': 1000,
                'line_total': 1000,
              },
            ],
          },
        ],
      );

      expect(canonical, hasLength(1));
      final row = canonical.single;
      final lines = (row['line_items'] ?? row['items']) as List;
      expect(lines, hasLength(2));
      final names = lines.map((line) {
        final item = Map<String, dynamic>.from(line as Map);
        return (item['product_name'] ?? item['description'] ?? item['product']).toString();
      }).toSet();
      expect(names, containsAll(['Chicken', 'Mutton']));
    });

    test('both items and line_items contribute unique partial lines', () {
      final result = InvoiceDedupHelper.canonicalizeInvoices([
        {
          'invoice_number': 'BILL-ALIASES-1',
          'total_amount': 300.0,
          'line_items': [
            {
              'product_name': 'Monitor',
              'quantity': 1,
              'unit_price': 200,
              'line_total': 200,
            },
          ],
          'items': [
            {
              'product_name': 'Keyboard',
              'quantity': 1,
              'unit_price': 100,
              'line_total': 100,
            },
          ],
        },
      ]);

      expect(result, hasLength(1));
      final lines = List<Map<String, dynamic>>.from(
        result.single['line_items'] as List,
      );
      expect(lines, hasLength(2));
      expect(
        lines.map((line) => line['product_name']).toSet(),
        containsAll(['Monitor', 'Keyboard']),
      );
    });

    test('missing price in an invoice mirror does not duplicate a known line', () {
      final result = InvoiceDedupHelper.canonicalizeInvoices([
        {
          'invoice_number': 'BILL-PARTIAL-LINE',
          'total_amount': 50.0,
          'items': [
            {
              'product_name': 'Tea',
              'quantity': 1,
              'unit_price': 50,
              'line_total': 50,
            },
          ],
        },
        {
          'invoice_number': 'BILL-PARTIAL-LINE',
          'total_amount': 50.0,
          'line_items': [
            {
              'description': 'Tea',
              'quantity': 1,
            },
          ],
        },
      ]);

      expect(result, hasLength(1));
      expect((result.single['line_items'] as List), hasLength(1));
      expect(
        (result.single['line_items'] as List).first['unit_price'],
        50,
      );
    });

    test('a sale mirror is merged when it matches a real invoice', () {
      final result = InvoiceDedupHelper.canonicalizeInvoiceLedger(
        [
          {
            'invoice_number': 'BILL-0042',
            'id': 42,
            'total_amount': 100.0,
            'paid_amount': 0.0,
          },
        ],
        [
          {
            'sale_id': 'SALE-42',
            'invoice_id': 42,
            'total_amount': 100.0,
            'paid_amount': 100.0,
            'payment_status': 'PAID',
          },
        ],
      );

      expect(result, hasLength(1));
      expect(result.single['paid_amount'], 100.0);
      expect(result.single['payment_status'], 'PAID');
    });

    test('legacy PAID row without paid_amount infers full settlement', () {
      final result = InvoiceDedupHelper.canonicalizeInvoices([
        {
          'invoice_number': 'BILL-LEGACY',
          'total_amount': 75.0,
          'status': 'PAID',
        },
      ]);

      expect(result, hasLength(1));
      expect(result.single['paid_amount'], 75.0);
      expect(result.single['payment_status'], 'PAID');
    });

    test('large sales history only imports rows explicitly linked to invoices', () {
      final invoices = [
        for (var i = 0; i < 600; i++)
          {
            'id': 1000 + i,
            'invoice_number': 'BILL-$i',
            'total_amount': 100.0 + i,
            'paid_amount': 0.0,
          },
      ];
      final sales = [
        for (var i = 0; i < 600; i++)
          if (i % 3 == 0)
            {
              'sale_id': 'SALE-$i',
              'invoice_id': 1000 + i,
              'invoice_number': 'BILL-$i',
              'total_amount': 100.0 + i,
              'paid_amount': 100.0 + i,
              'payment_status': 'PAID',
            }
          else
            {
              'sale_id': 'POS-$i',
              'total_amount': 25.0,
              'paid_amount': 25.0,
              'payment_status': 'PAID',
            },
      ];

      final result = InvoiceDedupHelper.canonicalizeInvoiceLedger(
        invoices,
        sales,
      );

      expect(result, hasLength(600));
      final linked = result.singleWhere(
        (row) => row['invoice_number'] == 'BILL-0',
      );
      expect(linked['sale_id'], 'SALE-0');
      expect(linked['paid_amount'], 100.0);
    });
  });
}
