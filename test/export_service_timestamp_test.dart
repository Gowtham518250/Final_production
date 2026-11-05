import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/export_service.dart';

void main() {
  group('ExportService recorded sale timestamps', () {
    test('prefers the recorded event timestamp over a date-only business date', () {
      final sale = <String, dynamic>{
        'date': '2026-11-02',
        'business_date': '2026-11-02',
        'created_at': '2026-11-02T17:21:05Z',
      };

      final resolved = ExportService.resolveSalesDate(sale);
      final recorded = ExportService.resolveSalesEventTime(sale);

      expect(resolved, isNotNull);
      expect(recorded, isNotNull);
      expect(resolved!.toUtc(), DateTime.utc(2026, 11, 2, 17, 21, 5));
      expect(recorded!.toUtc(), DateTime.utc(2026, 11, 2, 17, 21, 5));
      expect(ExportService.formatSalesDate(resolved), '02/11/2026');
      expect(ExportService.formatSalesTime(recorded), isNot('Not recorded'));
    });

    test('does not invent a recorded time for date-only legacy sales', () {
      final sale = <String, dynamic>{
        'date': '2026-11-02',
        'business_date': '2026-11-02',
      };

      expect(ExportService.resolveSalesDate(sale), isNotNull);
      expect(ExportService.resolveSalesEventTime(sale), isNull);
      expect(ExportService.formatSalesTime(null), 'Not recorded');
    });

    test('flattens invoice item rows and inherits parent recorded time', () {
      final rows = ExportService.flattenSalesForExport([
        {
          'invoice_number': 'BILL-EXPORT-1',
          'total_amount': 100.0,
          'business_date': '2026-11-05',
          'created_at': '2026-11-05T14:30:00Z',
          'payment_method': 'CASH',
          'items': [
            {
              'product_id': 12,
              'product_name': 'Tea Powder',
              'quantity': 1,
              'unit_price': 10,
              'line_total': 9.26,
              'total_with_tax': 10,
            },
            {
              'product_id': 13,
              'product_name': 'Pencil',
              'quantity': 2,
              'unit_price': 5,
            },
          ],
        },
      ]);

      expect(rows, hasLength(2));
      expect(rows.map((row) => row['product_name']),
          containsAll(['Tea Powder', 'Pencil']));
      expect(rows.first['export_total'], 10.0);
      expect(rows.last['export_total'], 10.0);
      expect(rows.first['total_amount'], 100.0);
      expect(
        ExportService.resolveSalesEventTime(rows.first)!.toUtc(),
        DateTime.utc(2026, 11, 5, 14, 30),
      );
      expect(rows.first['payment_method'], 'CASH');
    });

    test('flat legacy sales rows retain product aliases without a fake invoice amount', () {
      final rows = ExportService.flattenSalesForExport([
        {
          'sale_id': 'SALE-FLAT-1',
          'product_name': 'Rice',
          'quantity': 3,
          'price': 20,
          'total': 60,
          'created_at': '2026-11-05T14:30:00Z',
        },
      ]);

      expect(rows, hasLength(1));
      expect(rows.single['product'], 'Rice');
      expect(rows.single['export_total'], 60.0);
    });

    test('resolves nested raw sale timestamps used by transaction history', () {
      final sale = <String, dynamic>{
        'date': '2026-11-02',
        'raw': {
          'event_timestamp': '2026-11-02T18:30:00Z',
        },
      };

      expect(
        ExportService.resolveSalesEventTime(sale)!.toUtc(),
        DateTime.utc(2026, 11, 2, 18, 30),
      );
    });
  });
}
