import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/analytics_engine.dart';

void main() {
  group('sales performance timestamp and product revenue regressions', () {
    test(
      'hourly analytics uses event timestamp, not date-only business date',
      () {
        final engine = AnalyticsEngine();
        final raw = {
          'business_date': '2026-10-15',
          'created_at': '2026-10-15T17:45:32Z',
        };

        expect(engine.getLocalDate(raw).hour, 0);
        expect(
          engine.getEventDate(raw).toUtc(),
          DateTime.utc(2026, 10, 15, 17, 45, 32),
        );
      },
    );

    test('best hour uses a clock stored in date after business_date', () {
      final now = DateTime.now();
      final businessDate =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final sale = {
        'sale_id': 'BEST-HOUR-DATE-FALLBACK',
        'business_date': businessDate,
        'date': now.toUtc().toIso8601String(),
        'total_amount': 250.0,
      };
      final engine = AnalyticsEngine();

      engine.recalculateAnalytics([sale], 0);

      String formatHour(int hour) {
        if (hour == 0) return '12 AM';
        if (hour < 12) return '$hour AM';
        if (hour == 12) return '12 PM';
        return '${hour - 12} PM';
      }

      expect(
        engine.todayBestHourLabel,
        '${formatHour(now.hour)} - ${formatHour((now.hour + 1) % 24)}',
      );
    });

    test('preserves root or nested event time when flattening a sale', () {
      final now = DateTime.now();
      final businessDate =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final source = {
        'business_date': businessDate,
        'raw': {'created_at': now.toUtc().toIso8601String()},
      };
      final flattened = {
        'business_date': source['business_date'],
        ...AnalyticsEngine.recordedEventTimestampFields(source),
        'sale_id': 'BEST-HOUR-FLATTENED',
        'total_amount': 250.0,
      };
      final engine = AnalyticsEngine();

      engine.recalculateAnalytics([flattened], 0);

      String formatHour(int hour) {
        if (hour == 0) return '12 AM';
        if (hour < 12) return '$hour AM';
        if (hour == 12) return '12 PM';
        return '${hour - 12} PM';
      }

      expect(
        engine.todayBestHourLabel,
        '${formatHour(now.hour)} - ${formatHour((now.hour + 1) % 24)}',
      );
    });

    test('best hour does not assign date-only legacy sales to midnight', () {
      final now = DateTime.now();
      final businessDate =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final engine = AnalyticsEngine();

      engine.recalculateAnalytics([
        {
          'sale_id': 'BEST-HOUR-NO-EVENT-TIME',
          'business_date': businessDate,
          'total_amount': 250.0,
        },
      ], 0);

      expect(engine.todayRevenue, 250.0);
      expect(engine.todayBestHourLabel, 'No Sales');
    });

    test(
      'today top product uses nested line_items and description fallback',
      () {
        final now = DateTime.now();
        final businessDate =
            '${now.year.toString().padLeft(4, '0')}-'
            '${now.month.toString().padLeft(2, '0')}-'
            '${now.day.toString().padLeft(2, '0')}';
        final engine = AnalyticsEngine();

        engine.recalculateAnalytics([
          {
            'sale_id': 'INV-REGRESSION-1',
            'business_date': businessDate,
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'total_amount': 240.0,
            'line_items': [
              {
                'product_id': null,
                'description': 'Custom Grocery Bundle',
                'quantity': 2,
                'unit_price': 120.0,
                'line_total': 240.0,
              },
            ],
          },
        ], 0);

        expect(engine.todaySalesValue, 240.0);
        expect(engine.todayTopProduct, 'Custom Grocery Bundle');
      },
    );
  });
}
