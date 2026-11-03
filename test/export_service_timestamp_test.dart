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
