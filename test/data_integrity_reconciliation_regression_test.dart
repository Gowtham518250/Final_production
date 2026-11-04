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

    test('flattened API sale rows retain every product line', () {
      final remote = <Map<String, dynamic>>[
        {
          'sale_id': 'SALE_MULTI_1',
          'invoice_number': 'BILL-MULTI-1',
          'product_name': 'Monitor',
          'quantity': 1,
          'price': 100,
          'total': 100,
          'total_amount': 200,
        },
        {
          'sale_id': 'SALE_MULTI_1',
          'invoice_number': 'BILL-MULTI-1',
          'product_name': 'Keyboard',
          'quantity': 2,
          'price': 50,
          'total': 100,
          'total_amount': 200,
        },
      ];

      final result = CacheConsistencyService.mergeLists(
        const [],
        remote,
        dataset: 'sales',
      );

      expect(result, hasLength(1));
      expect(result.single['total_amount'], 200);
      final lines = List<Map<String, dynamic>>.from(
        result.single['line_items'] as List,
      );
      expect(lines, hasLength(2));
      expect(
        lines.map((line) => line['product_name']).toSet(),
        containsAll(['Monitor', 'Keyboard']),
      );
    });

    test('two identical lines in one invoice stay two lines after mirror merge', () {
      final local = <String, dynamic>{
        'sale_id': 'SALE_REPEAT_1',
        'invoice_number': 'BILL-REPEAT-1',
        'total_amount': 200,
        'items': [
          {'product_name': 'Rice', 'quantity': 1, 'unit_price': 100},
          {'product_name': 'Rice', 'quantity': 1, 'unit_price': 100},
        ],
        'updated_at': '2026-11-01T10:00:00Z',
        'sync_status': 'synced',
      };
      final remote = <String, dynamic>{
        'invoice_number': 'BILL-REPEAT-1',
        'invoice_id': 501,
        'total_amount': 200,
        'line_items': [
          {'product_name': 'Rice', 'quantity': 1, 'unit_price': 100},
          {'product_name': 'Rice', 'quantity': 1, 'unit_price': 100},
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
      expect(
        (result.single['items'] as List),
        hasLength(2),
      );
      expect(result.single['invoice_id'], 501);
    });

    test('numeric sales-row IDs do not bridge different invoice aliases', () {
      final rows = <Map<String, dynamic>>[
        {'id': 12, 'sale_id': 'SALE_A', 'invoice_number': 'BILL-A'},
        {'id': 12, 'sale_id': 'SALE_B', 'invoice_number': 'BILL-B'},
      ];

      final result = CacheConsistencyService.mergeLists(
        rows,
        const [],
        dataset: 'sales',
      );

      expect(result, hasLength(2));
      expect(result.map((row) => row['invoice_number']).toSet(),
          containsAll(['BILL-A', 'BILL-B']));
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
