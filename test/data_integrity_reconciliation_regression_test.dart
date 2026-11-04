import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:retail_mind/cache_consistency_service.dart';
import 'package:retail_mind/sales_dedup_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('data integrity reconciliation', () {
    test('business PENDING status is not mistaken for pending sync', () {
      expect(CacheConsistencyService.isPending({'status': 'PENDING'}), isFalse);
      expect(
        CacheConsistencyService.isPending({'payment_status': 'UNPAID'}),
        isFalse,
      );
      expect(
        CacheConsistencyService.isPending({'sync_status': 'pending'}),
        isTrue,
      );
    });

    test('bridged SALE and BILL aliases resolve to one invoice mirror', () {
      final local = <String, dynamic>{
        'sale_id': 'SALE_100',
        'offline_id': 'SALE_100',
        'invoice_number': 'BILL-100',
        'total_amount': 100.0,
        'paid_amount': 25.0,
        'items': [
          {'product_name': 'Monitor', 'quantity': 1, 'unit_price': 100},
        ],
        'updated_at': '2026-11-01T10:00:00Z',
        'sync_status': 'synced',
      };
      final remote = <String, dynamic>{
        'id': 700,
        'invoice_id': 700,
        'invoice_number': 'BILL-100',
        'total_amount': 100.0,
        'paid_amount': 0.0,
        'items': [
          {'product_name': 'Monitor', 'quantity': 1, 'unit_price': 100},
        ],
        'updated_at': '2026-11-01T09:00:00Z',
        'sync_status': 'synced',
      };

      final result = CacheConsistencyService.mergeLists(
        [local],
        [remote],
        dataset: 'sales',
      );

      expect(result, hasLength(1));
      expect(result.single['sale_id'], 'SALE_100');
      expect(result.single['invoice_number'], 'BILL-100');
      expect(result.single['invoice_id'], 700);
      expect(result.single['paid_amount'], 25.0);
    });

    test('anonymous equal-content sales remain separate', () {
      final row = <String, dynamic>{
        'customer_name': 'Cash Customer',
        'total': 50.0,
        'items': [
          {'product_name': 'Rice', 'quantity': 1, 'price': 50},
        ],
      };

      final result = CacheConsistencyService.mergeLists(
        [row, row],
        const [],
        dataset: 'sales',
      );

      expect(result, hasLength(2));
    });

    test('incomplete but identified sale is retained by persistence dedupe', () {
      final incomplete = <String, dynamic>{
        'sale_id': 'SALE_INCOMPLETE_1',
        'invoice_number': 'BILL-INCOMPLETE-1',
        'status': 'PENDING',
        'customer_phone': '9876543210',
        'items': <dynamic>[],
      };

      final result = SalesDedupHelper.dedupeBills([incomplete]);

      expect(result, hasLength(1));
      expect(result.single['sale_id'], 'SALE_INCOMPLETE_1');
    });

    test('distinct stable invoice aliases stay as separate transactions', () {
      final rows = <Map<String, dynamic>>[
        {'sale_id': 'SALE_A', 'invoice_number': 'BILL-A'},
        {'sale_id': 'SALE_B', 'invoice_number': 'BILL-B'},
      ];
      final result = CacheConsistencyService.mergeLists(
        rows,
        const [],
        dataset: 'sales',
      );
      expect(result, hasLength(2));
    });
  });
}
