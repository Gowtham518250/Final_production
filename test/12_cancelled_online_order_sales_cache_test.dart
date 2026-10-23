import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/cache_consistency_service.dart';

void main() {
  group('Cancelled online-order sales cache', () {
    test('prunes all synced line rows for an online invoice missing remotely', () {
      final local = <Map<String, dynamic>>[
        {
          'sale_id': 'ONL-101',
          'invoice_number': 'ONL-101',
          'product_name': 'Monitor',
          'sync_status': 'synced',
          'source': 'cloud_restore',
        },
        {
          'sale_id': 'ONL-101',
          'invoice_number': 'ONL-101',
          'product_name': 'Keyboard',
          'sync_status': 'synced',
          'source': 'cloud_restore',
        },
        {
          'sale_id': 'BILL-88',
          'invoice_number': 'BILL-88',
          'product_name': 'Mouse',
          'sync_status': 'synced',
        },
      ];

      final result =
          CacheConsistencyService.reconcileOnlineOrderSales(local, const []);

      expect(result, hasLength(1));
      expect(result.single['invoice_number'], 'BILL-88');
    });

    test('keeps online order represented by server snapshot', () {
      final local = <Map<String, dynamic>>[
        {
          'sale_id': 'ONL-202',
          'invoice_number': 'ONL-202',
          'sync_status': 'synced',
          'source': 'cloud_restore',
        },
      ];
      final remote = <Map<String, dynamic>>[
        {'sale_id': 'ONL-202', 'invoice_number': 'ONL-202', 'id': '900_0'},
      ];

      final result =
          CacheConsistencyService.reconcileOnlineOrderSales(local, remote);

      expect(result, hasLength(1));
      expect(result.single['invoice_number'], 'ONL-202');
    });

    test('preserves pending/offline local write when server has no copy yet', () {
      final local = <Map<String, dynamic>>[
        {
          'sale_id': 'ONL-303',
          'invoice_number': 'ONL-303',
          'sync_status': 'pending',
          'is_offline': true,
        },
      ];

      final result =
          CacheConsistencyService.reconcileOnlineOrderSales(local, const []);

      expect(result, hasLength(1));
      expect(result.single['sync_status'], 'pending');
    });
  });
}
