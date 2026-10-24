import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/online_order_service.dart';

void main() {
  group('Cancelled online-order invoice cleanup', () {
    test('matches canonical ONL invoice after cloud restore changes its source', () {
      expect(
        OnlineOrderService.invoiceBelongsToOrder(
          {
            'id': 900,
            'invoice_number': 'ONL-101-1761234567',
            'source': 'cloud_restore',
            'sync_status': 'synced',
          },
          {'order_id': 101, 'status': 'CANCELLED'},
        ),
        isTrue,
      );
    });

    test('matches explicit online-order note after cloud restore', () {
      expect(
        OnlineOrderService.invoiceBelongsToOrder(
          {
            'id': 901,
            'invoice_number': 'INV-9004',
            'notes': 'Online Order #101 | Delivery: Store Pickup',
            'source': 'cloud_restore',
          },
          {'order_id': 101, 'status': 'CANCELLED'},
        ),
        isTrue,
      );
    });

    test('does not match a neighboring order id by numeric prefix', () {
      expect(
        OnlineOrderService.invoiceBelongsToOrder(
          {
            'id': 902,
            'invoice_number': 'ONL-1010-1761234567',
            'source': 'cloud_restore',
          },
          {'order_id': 101, 'status': 'CANCELLED'},
        ),
        isFalse,
      );
    });

    test('filters the cancelled order invoice from an invoice snapshot', () {
      final result = OnlineOrderService.excludeCancelledOrderInvoices(
        [
          {
            'id': 900,
            'invoice_number': 'ONL-101-1761234567',
            'source': 'cloud_restore',
          },
          {
            'id': 901,
            'invoice_number': 'ONL-202-1761234567',
            'source': 'cloud_restore',
          },
        ],
        [
          {'order_id': 101, 'status': 'CANCELLED'},
          {'order_id': 202, 'status': 'DELIVERED'},
        ],
      );

      expect(result, hasLength(1));
      expect(result.single['invoice_number'], 'ONL-202-1761234567');
    });
  });
}
