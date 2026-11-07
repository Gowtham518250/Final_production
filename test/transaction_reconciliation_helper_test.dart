import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/transaction_reconciliation_helper.dart';

void main() {
  group('TransactionReconciliationHelper', () {
    test(
      'canonical bill rows partition into categories without changing count',
      () {
        final sales = <Map<String, dynamic>>[
          {'sale_id': 'CASH-1', 'total_amount': 100, 'payment_method': 'Cash'},
          {'sale_id': 'ONLINE-1', 'total_amount': 50, 'source': 'ONLINE_ORDER'},
          {
            'sale_id': 'KHATA-1',
            'total_amount': 75,
            'transaction_kind': 'credit sale',
          },
        ];

        final rows =
            TransactionReconciliationHelper.buildCanonicalSalesTransactions(
              sales: sales,
              businessDateOf: (_) => DateTime(2026, 11, 7),
              eventTimeOf: (_) => null,
              isKhataSale: (sale) => sale['transaction_kind'] == 'credit sale',
              isOnlineSale: (sale) => sale['source'] == 'ONLINE_ORDER',
            );
        final cash = rows.where((row) => row['type'] == 'Cash Sale').length;
        final online = rows.where((row) => row['type'] == 'Online Sale').length;
        final khata = rows.where((row) => row['type'] == 'Khata Sale').length;

        expect(rows, hasLength(3));
        expect(cash + online + khata, rows.length);
        expect([cash, online, khata], [1, 1, 1]);
        expect(rows.map((row) => row['amount']), [100.0, 50.0, 75.0]);
        expect(
          rows.fold<double>(0, (sum, row) => sum + (row['amount'] as double)),
          225,
        );
      },
    );

    test('serializes a localized event timestamp as explicit UTC', () {
      final local = DateTime(2026, 10, 13, 21, 47);
      final serialized = TransactionReconciliationHelper.serializeEventTime(
        local,
      )!;

      expect(serialized.endsWith('Z'), isTrue);
      expect(DateTime.parse(serialized).toLocal(), local);
    });

    test('converts UTC payment timestamps to local display time', () {
      final parsed = TransactionReconciliationHelper.parseEventTime(
        '2026-11-07T04:42:00.000Z',
      );

      expect(parsed, DateTime.parse('2026-11-07T04:42:00.000Z').toLocal());
      expect(parsed!.isUtc, isFalse);
    });

    test(
      'keeps date-only values local and parses timezone-free event times as UTC',
      () {
        expect(
          TransactionReconciliationHelper.parseEventTime('2026-11-07'),
          DateTime(2026, 11, 7),
        );
        expect(
          TransactionReconciliationHelper.parseEventTime('2026-11-07T04:42:00'),
          DateTime.parse('2026-11-07T04:42:00Z').toLocal(),
        );
      },
    );

    test(
      'merges a local sale and its backend invoice by shared invoice number',
      () {
      final localSale = <String, dynamic>{
        'id': 'SALE_1791928020000000',
        'type': 'Cash Sale',
        'amount': 12.0,
        'raw': <String, dynamic>{
          'sale_id': 'SALE_1791928020000000',
          'offline_id': 'SALE_1791928020000000',
          'invoice_number': 'BILL-0007',
          'total_amount': 12.0,
        },
      };
      final backendInvoice = <String, dynamic>{
        'id': 'BILL-0007',
        'type': 'Invoice',
        'amount': 12.0,
        'items_count': 1,
        'raw': <String, dynamic>{
          'id': 42,
          'invoice_id': 42,
          'invoice_number': 'BILL-0007',
          'total_amount': 12.0,
        },
      };

        final result = TransactionReconciliationHelper.dedupe([
          localSale,
          backendInvoice,
        ]);

      expect(result, hasLength(1));
      expect(result.single['type'], 'Invoice');
      expect(result.single['raw']['sale_id'], 'SALE_1791928020000000');
      expect(result.single['raw']['invoice_id'], 42);
      },
    );

    test('preserves local Khata sales when adding remote Khata history', () {
      final localKhataSale = <String, dynamic>{
        'id': 'SALE_KHATA_1',
        'type': 'Khata Sale',
        'amount': 250.0,
        'raw': <String, dynamic>{
          'sale_id': 'SALE_KHATA_1',
          'invoice_number': 'BILL-KHATA-1',
        },
      };
      final remoteKhataPayment = <String, dynamic>{
        'id': 'KHATA-PAYMENT-1',
        'type': 'Payment',
        'amount': 100.0,
        'raw': <String, dynamic>{'transaction_id': 'KHATA-PAYMENT-1'},
      };

      final result = TransactionReconciliationHelper.mergeAndDedupe(
        [localKhataSale],
        [remoteKhataPayment],
      );

      expect(result, hasLength(2));
      expect(result.map((row) => row['id']), contains('SALE_KHATA_1'));
      expect(result.map((row) => row['id']), contains('KHATA-PAYMENT-1'));
    });

    test(
      'does not merge different sales just because their content matches',
      () {
      final first = <String, dynamic>{
        'id': 'SALE_A',
        'type': 'Cash Sale',
        'amount': 12.0,
        'raw': <String, dynamic>{
          'sale_id': 'SALE_A',
          'invoice_number': 'BILL-0001',
          'total_amount': 12.0,
        },
      };
      final second = <String, dynamic>{
        'id': 'SALE_B',
        'type': 'Cash Sale',
        'amount': 12.0,
        'raw': <String, dynamic>{
          'sale_id': 'SALE_B',
          'invoice_number': 'BILL-0002',
          'total_amount': 12.0,
        },
      };

      expect(
        TransactionReconciliationHelper.dedupe([first, second]),
        hasLength(2),
      );
      },
    );
  });
}
