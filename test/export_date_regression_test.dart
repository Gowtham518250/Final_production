import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/export_service.dart';

void main() {
  group('export row date handling', () {
    test('keeps each sale row on its own actual date', () {
      final sales = [
        {'date': '2026-11-01T08:00:00Z'},
        {'sale_date': '2026-11-02T12:30:00Z'},
        {'business_date': '2026-11-03'},
        {'created_at': '2026-11-04T09:15:00Z'},
      ];

      final dates = sales.map((sale) => ExportService.resolveSalesDate(sale)).toList();

      expect(dates[0], isNotNull);
      expect(dates[1], isNotNull);
      expect(dates[2], isNotNull);
      expect(dates[3], isNotNull);
      expect(dates[0], isNot(equals(dates[1])));
      expect(dates[1], isNot(equals(dates[2])));
      expect(dates[2], isNot(equals(dates[3])));
    });
  });
}
