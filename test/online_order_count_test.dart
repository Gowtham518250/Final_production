import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/online_order_service.dart';

void main() {
  test('lifetime online-order count includes delivered and cancelled orders', () {
    final rows = <Map<String, dynamic>>[
      {
        'source': 'ONLINE_ORDER',
        'reference_order_id': 'order-1',
        'order_status': 'DELIVERED',
      },
      {
        'source': 'ONLINE_ORDER',
        'reference_order_id': 'order-2',
        'order_status': 'CANCELLED',
        'cancelled_at': '2026-10-30T10:00:00Z',
      },
      {
        'source': 'ONLINE_ORDER',
        'reference_order_id': 'order-3',
        'order_status': 'PENDING',
      },
      {
        'source': 'ONLINE_ORDER',
        'reference_order_id': 'order-4',
        'order_status': 'REJECTED',
      },
      // A second invoice/line for the same order must not count twice.
      {
        'source': 'ONLINE_ORDER',
        'reference_order_id': 'order-1',
        'invoice_number': 'ONL-order-1-line-2',
        'order_status': 'DELIVERED',
      },
      // In-store sales do not contribute to online order count.
      {
        'source': 'MANUAL_ENTRY',
        'invoice_number': 'BILL-100',
        'order_status': 'PAID',
      },
    ];

    expect(
      OnlineOrderService.countDistinctOnlineOrdersFromSales(rows),
      4,
    );
  });

  test('lifetime count keeps online orders with only ONL invoice identifiers', () {
    final rows = [
      {
        'invoice_number': 'ONL-1001',
        'status': 'CANCELLED',
        'cancelled_at': '2026-10-30T10:00:00Z',
      },
      {
        'invoice_number': 'ONL-1002',
        'status': 'DELIVERED',
      },
    ];

    expect(
      OnlineOrderService.countDistinctOnlineOrdersFromSales(rows),
      2,
    );
  });
}
