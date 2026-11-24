import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/sale_date_parser.dart';

void main() {
  group('SaleDateParser', () {
    test('date-only values preserve the calendar day', () {
      final date = SaleDateParser.parse({'business_date': '2026-11-24'});

      expect(date.year, 2026);
      expect(date.month, 11);
      expect(date.day, 24);
      expect(date.hour, 0);
    });

    test('positive and negative UTC offsets are recognized', () {
      expect(
        SaleDateParser.hasExplicitTimezone('2026-11-24T10:00:00+05:30'),
        isTrue,
      );
      expect(
        SaleDateParser.hasExplicitTimezone('2026-11-24T10:00:00-0500'),
        isTrue,
      );
      expect(
        SaleDateParser.hasExplicitTimezone('2026-11-24T10:00:00Z'),
        isTrue,
      );
      expect(
        SaleDateParser.hasExplicitTimezone('2026-11-24T10:00:00'),
        isFalse,
      );
    });

    test('offset timestamps are converted to local time, not treated as local', () {
      final source = DateTime.parse('2026-11-24T10:00:00+05:30');
      final parsed = SaleDateParser.parse({
        'created_at': '2026-11-24T10:00:00+05:30',
      });

      expect(parsed, source.toLocal());
    });

    test('timestamps without a zone are kept as local wall-clock values', () {
      final parsed = SaleDateParser.parse({
        'created_at': '2026-11-24T10:00:00',
      });

      expect(parsed.year, 2026);
      expect(parsed.month, 11);
      expect(parsed.day, 24);
      expect(parsed.hour, 10);
    });

    test('invalid and missing values return the safe epoch fallback', () {
      expect(SaleDateParser.parse({}), DateTime(1970));
      expect(
        SaleDateParser.parse({'date': 'not-a-date'}),
        DateTime(1970),
      );
    });
  });
}
