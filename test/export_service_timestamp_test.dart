import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/data_export_widget.dart';
import 'package:retail_mind/export_service.dart';

void main() {
  group('ExportService recorded sale timestamps', () {
    test(
      'prefers the recorded event timestamp over a date-only business date',
      () {
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
      },
    );

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
          'total_amount': 40.0,
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
              'productName': 'Pencil',
              'quantity': 2,
              'unit_price': 5,
              'created_at': null,
              'payment_method': ' ',
            },
          ],
        },
      ]);

      expect(rows, hasLength(3));
      expect(
        rows.take(2).map((row) => row['product_name']),
        containsAll(['Tea Powder', 'Pencil']),
      );
      expect(rows.first['export_total'], 10.0);
      expect(rows[1]['export_total'], 10.0);
      expect(rows.last['product_name'], 'Invoice Adjustment');
      expect(rows.last['export_total'], 20.0);
      expect(rows.last['quantity'], 0);
      expect(
        rows.fold<double>(
          0,
          (sum, row) => sum + (row['export_total'] as num).toDouble(),
        ),
        40.0,
      );
      expect(
        ExportService.totalProductsSold([
          {
            'total_amount': 40.0,
            'items': [
              {
                'product_name': 'Tea Powder',
                'quantity': 1,
                'unit_price': 10,
                'total_with_tax': 10,
              },
              {
                'product_name': 'Pencil',
                'quantity': 2,
                'unit_price': 5,
                'total_with_tax': 10,
              },
            ],
          },
        ]),
        3.0,
      );
      expect(rows.first['total_amount'], 40.0);
      expect(
        ExportService.resolveSalesEventTime(rows.first)!.toUtc(),
        DateTime.utc(2026, 11, 5, 14, 30),
      );
      expect(rows.first['payment_method'], 'CASH');
      expect(rows[1]['payment_method'], 'CASH');
      expect(
        ExportService.resolveSalesEventTime(rows[1])!.toUtc(),
        DateTime.utc(2026, 11, 5, 14, 30),
      );
    });

    test(
      'flat legacy sales rows retain product aliases without a fake invoice amount',
      () {
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
      },
    );

    test('resolves nested raw sale timestamps used by transaction history', () {
      final sale = <String, dynamic>{
        'date': '2026-11-02',
        'raw': {'event_timestamp': '2026-11-02T18:30:00Z'},
      };

      expect(
        ExportService.resolveSalesEventTime(sale)!.toUtc(),
        DateTime.utc(2026, 11, 2, 18, 30),
      );
    });

    test('export summaries use invoice revenue and sold quantities', () {
      final sales = <Map<String, dynamic>>[
        {
          'total_amount': 120,
          'total_with_tax': 140,
          'line_items': [
            {'product_name': 'Tea', 'quantity': 2, 'unit_price': 20},
            {'product_name': 'Rice', 'quantity': 3, 'unit_price': 20},
          ],
        },
        {
          'total': 50,
          'items': [
            {'product_name': 'Pencil', 'qty': 1, 'price': 50},
          ],
        },
      ];

      expect(ExportService.totalInvoiceRevenue(sales), 170);
      expect(ExportService.totalProductsSold(sales), 6);
      expect(ExportService.formatProductQuantity(6), '6');
      expect(ExportService.formatProductQuantity(1.5), '1.5');
    });

    test(
      'time-filtered export sales are canonicalized like dashboard sales',
      () {
        final today = DateTime.now();
        final businessDate =
            '${today.year.toString().padLeft(4, '0')}-'
            '${today.month.toString().padLeft(2, '0')}-'
            '${today.day.toString().padLeft(2, '0')}';
        final sales = <Map<String, dynamic>>[
          {
            'sale_id': 'DUPLICATE-EXPORT-1',
            'business_date': businessDate,
            'total_amount': 120,
            'items': [
              {'product_name': 'Tea', 'quantity': 2, 'unit_price': 60},
            ],
          },
          {
            'sale_id': 'DUPLICATE-EXPORT-1',
            'business_date': businessDate,
            'total_amount': 120,
            'items': [
              {'product_name': 'Tea', 'quantity': 2, 'unit_price': 60},
            ],
          },
        ];

        final filtered = DataExportWidget.filterSalesByTimeRange(
          allSales: sales,
          range: ExportTimeRange.today,
        );

        expect(filtered, hasLength(1));
        expect(ExportService.totalInvoiceRevenue(filtered), 120);
      },
    );

    test(
      'CSV and Excel sales exports include a separate recorded-time column',
      () async {
        final sale = <String, dynamic>{
          'invoice_number': 'BILL-EXPORT-TIME',
          'business_date': '2026-11-05',
          'created_at': '2026-11-05T14:30:00Z',
          'product_name': 'Tea',
          'quantity': 1,
          'price': 25,
          'total': 25,
          'total_amount': 25,
          'total_with_tax': 45,
        };
        final expectedTime = ExportService.formatSalesTime(
          ExportService.resolveSalesEventTime(sale),
        );

        final csvRows = const CsvToListConverter().convert(
          await ExportService.generateCSV([sale]),
        );
        final csvTimeIndex = csvRows.first.indexOf('Recorded Time');
        expect(csvTimeIndex, greaterThanOrEqualTo(0));
        expect(csvRows[1][csvTimeIndex], expectedTime);
        final csvTotalIndex = csvRows.first.indexOf('Total');
        expect(csvRows[1][csvTotalIndex], 'Rs.25.00');

        final workbook = Excel.decodeBytes(
          await ExportService.generateExcel([sale]),
        );
        final headers = workbook.tables['Sales Report']!.rows.first;
        final excelTimeIndex = headers.indexWhere(
          (cell) => cell?.value.toString() == 'Recorded Time',
        );
        expect(excelTimeIndex, greaterThanOrEqualTo(0));
        expect(
          workbook.tables['Sales Report']!.rows[1][excelTimeIndex]?.value
              .toString(),
          expectedTime,
        );
        final totalIndex = headers.indexWhere(
          (cell) => cell?.value.toString() == 'Total',
        );
        expect(
          workbook.tables['Sales Report']!.rows[1][totalIndex]?.value
              .toString(),
          'Rs.25.00',
        );

        final summaryRows = workbook.tables['Summary']!.rows;
        expect(summaryRows[1][0]?.value.toString(), 'Transactions');
        expect(summaryRows[1][1]?.value.toString(), '1');
        expect(summaryRows[2][0]?.value.toString(), 'Products Sold');
        expect(summaryRows[2][1]?.value.toString(), '1');
        expect(summaryRows[3][0]?.value.toString(), 'Total Revenue');
        expect(summaryRows[3][1]?.value.toString(), '25');
      },
    );
  });
}
