import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/online_order_service.dart';

void main() {
  group('OnlineOrderService owner order analytics normalization', () {
    test('keeps lifetime total separate from pending and accepted counts', () {
      final metrics = OnlineOrderService.normalizeOwnerOrderAnalytics({
        'totalCount': 42,
        'pending': 3,
        'acceptedCount': 18,
        'todayCount': 2,
        'todayRevenue': 125.5,
        'totalRevenue': 4200,
        'totalPaidCount': 24,
      });

      expect(metrics, isNotNull);
      expect(metrics!['totalCount'], 42);
      expect(metrics['pending'], 3);
      expect(metrics['todayCount'], 2);
      expect(metrics['available'], isTrue);
    });

    test(
      'prefers the all-status owner-order total over accepted aggregate',
      () {
        final metrics = OnlineOrderService.normalizeOwnerOrderAnalytics({
          'totalCount': 18,
          'acceptedCount': 18,
          'pending': 3,
        }, canonicalTotalCount: 42);

        expect(metrics!['totalCount'], 42);
        expect(metrics['pending'], 3);
      },
    );

    test('reads total from owner orders list, not the current page length', () {
      expect(
        OnlineOrderService.normalizeOwnerOrdersTotal({
          'orders': List.filled(1, <String, dynamic>{}),
          'total': '42',
        }),
        42,
      );
      expect(
        OnlineOrderService.normalizeOwnerOrdersTotal({
          'orders': List.filled(1, <String, dynamic>{}),
        }),
        isNull,
      );
      expect(
        OnlineOrderService.normalizeOwnerOrdersTotal({'total': -1}),
        isNull,
      );
    });

    test('accepts numeric string count but rejects an invalid total', () {
      expect(
        OnlineOrderService.normalizeOwnerOrderAnalytics({
          'totalCount': '107',
          'pending': '8',
        })!['totalCount'],
        107,
      );
      expect(
        OnlineOrderService.normalizeOwnerOrderAnalytics({
          'pending': 8,
          'acceptedCount': 99,
        }),
        isNull,
      );
      expect(
        OnlineOrderService.normalizeOwnerOrderAnalytics({'totalCount': -1}),
        isNull,
      );
    });
  });

  group('OnlineOrderService.countDistinctOnlineOrdersFromSales', () {
    test('matches an invoice to its exact cancelled online order', () {
      expect(
        OnlineOrderService.invoiceBelongsToOrder(
          {'id': 901, 'invoice_number': 'ONL-42'},
          {'order_id': 42},
        ),
        isFalse,
      );
      expect(
        OnlineOrderService.invoiceBelongsToOrder(
          {'id': 901, 'reference_order_id': 42, 'payment_status': 'PAID'},
          {'order_id': 42},
        ),
        isTrue,
      );
      expect(
        OnlineOrderService.invoiceBelongsToOrder(
          {'id': 42, 'invoice_number': 'ONL-42'},
          {'order_id': 42, 'invoice_id': 42},
        ),
        isTrue,
      );
    });

    test('matches legacy online invoice note to its exact order only', () {
      expect(
        OnlineOrderService.invoiceBelongsToOrder(
          {'source': 'ONLINE_ORDER', 'notes': 'Online Order #42', 'id': 901},
          {'order_id': 42},
        ),
        isTrue,
      );
      expect(
        OnlineOrderService.invoiceBelongsToOrder(
          {'source': 'OFFLINE', 'notes': 'Online Order #42', 'id': 901},
          {'order_id': 42},
        ),
        isFalse,
      );
      expect(
        OnlineOrderService.invoiceBelongsToOrder(
          {'source': 'ONLINE_ORDER', 'notes': 'Online Order #420', 'id': 901},
          {'order_id': 42},
        ),
        isFalse,
      );
    });

    test('counts one order once when it creates multiple sales rows', () {
      final rows = <Map<String, dynamic>>[
        {
          'source': 'ONLINE_ORDER',
          'id': 1001,
          'reference_order_id': 42,
          'invoice_number': 'ONL-42-123',
          'total': 85.0,
        },
        {
          'source': 'ONLINE_ORDER',
          'id': 1002,
          'reference_order_id': 42,
          'invoice_number': 'ONL-42-123',
          'total': 15.0,
        },
        {
          'source': 'ONLINE_ORDER',
          'id': 1003,
          'reference_order_id': 43,
          'invoice_number': 'ONL-43-123',
          'total': 100.0,
        },
        {'source': 'OFFLINE', 'id': 1004, 'total': 250.0},
      ];

      expect(OnlineOrderService.countDistinctOnlineOrdersFromSales(rows), 2);
    });

    test(
      'falls back to a canonical online invoice when order ID is absent',
      () {
        final rows = <Map<String, dynamic>>[
          {'invoice_number': 'ONL-44-123', 'total': 85.0},
          {'invoice_number': 'ONL-44-123', 'total': 5.0},
          {'invoice_number': 'BILL-0044', 'source': 'OFFLINE', 'total': 90.0},
        ];

        expect(OnlineOrderService.countDistinctOnlineOrdersFromSales(rows), 1);
      },
    );

    test('does not interpret sales currency amounts as order counts', () {
      final rows = <Map<String, dynamic>>[
        {'source': 'ONLINE', 'reference_order_id': 99, 'total': 85.0},
      ];

      expect(OnlineOrderService.countDistinctOnlineOrdersFromSales(rows), 1);
    });

    test('counts cancelled orders in the lifetime online order total', () {
      final rows = <Map<String, dynamic>>[
        {
          'source': 'ONLINE_ORDER',
          'reference_order_id': 55,
          'status': 'DELIVERED',
          'total': 100.0,
        },
        {
          'source': 'ONLINE_ORDER',
          'reference_order_id': 55,
          'status': 'CANCELLED',
          'total': 100.0,
        },
      ];

      expect(OnlineOrderService.countDistinctOnlineOrdersFromSales(rows), 1);
    });

    test('excludes stale paid invoices linked to cancelled cloud orders', () {
      final invoices = <Map<String, dynamic>>[
        {
          'id': 901,
          'reference_order_id': 42,
          'payment_status': 'PAID',
          'total_amount': 100,
        },
        {
          'id': 902,
          'reference_order_id': 43,
          'payment_status': 'PAID',
          'total_amount': 50,
        },
      ];
      final orders = <Map<String, dynamic>>[
        {'order_id': 42, 'status': 'CANCELLED'},
        {'order_id': 43, 'status': 'DELIVERED'},
      ];

      expect(
        OnlineOrderService.excludeCancelledOrderInvoices(invoices, orders),
        [
          {
            'id': 902,
            'reference_order_id': 43,
            'payment_status': 'PAID',
            'total_amount': 50,
          },
        ],
      );
    });
  });
}
