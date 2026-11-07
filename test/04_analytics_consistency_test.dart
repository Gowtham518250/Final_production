import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/analytics_engine.dart';
import 'package:retail_mind/invoice_analytics_snapshot.dart';

void main() {
  group('P0/P1 Analytics integrity', () {
    test('placeholder product names are detected', () {
      final engine = AnalyticsEngine();

      expect(AnalyticsEngine.isPlaceholderProductName('Product'), isTrue);
      expect(AnalyticsEngine.isPlaceholderProductName('Unknown'), isTrue);
      expect(AnalyticsEngine.isPlaceholderProductName('sale_123'), isTrue);
      expect(AnalyticsEngine.isPlaceholderProductName('invoice_77'), isTrue);
      expect(
        AnalyticsEngine.isPlaceholderProductName('Aashirvaad Atta'),
        isFalse,
      );
    });

    test('same sale data produces expected lifetime totals', () {
      final engine = AnalyticsEngine();

      engine.recalculateAnalytics([
        {
          'sale_id': 'SALE-1',
          'business_date': '2026-08-13T10:00:00Z',
          'total': 10,
          'items': [
            {
              'product_id': 1,
              'product_name': 'Rice',
              'quantity': 1,
              'price': 10,
            },
          ],
        },
        {
          'sale_id': 'SALE-2',
          'business_date': '2026-08-13T11:00:00Z',
          'total': 20,
          'items': [
            {
              'product_id': 2,
              'product_name': 'Oil',
              'quantity': 1,
              'price': 20,
            },
          ],
        },
      ], 0);

      expect(engine.totalSales, 30);
      expect(engine.totalTransactions, 2);
      expect(engine.lifetimeSalesCache, hasLength(engine.totalTransactions));
    });

    test('cancelled and returned orders are excluded from sales analytics', () {
      final engine = AnalyticsEngine();
      final today = DateTime.now().toIso8601String();

      engine.recalculateAnalytics([
        {
          'sale_id': 'SALE-VALID',
          'business_date': today,
          'total': 50,
          'items': [
            {
              'product_id': 1,
              'product_name': 'Rice',
              'quantity': 1,
              'price': 50,
            },
          ],
        },
        {
          'sale_id': 'SALE-CANCELLED',
          'business_date': today,
          'total': 120,
          'status': 'CANCELLED',
          'payment_status': 'PAID',
          'items': [
            {
              'product_id': 2,
              'product_name': 'Oil',
              'quantity': 1,
              'price': 120,
            },
          ],
        },
        {
          'sale_id': 'SALE-CANCELED',
          'business_date': today,
          'total': 80,
          'status': 'CANCELED',
        },
        {
          'sale_id': 'SALE-REJECTED',
          'business_date': today,
          'total': 70,
          'status': 'REJECTED',
        },
        {
          'sale_id': 'SALE-RETURNED',
          'business_date': today,
          'total': 60,
          'status': 'RETURNED',
        },
        {
          'sale_id': 'ONLINE-SALE-42',
          'business_date': today,
          'source': 'ONLINE_ORDER',
          'reference_order_id': '42',
          'total': 90,
        },
        {
          'sale_id': 'ONLINE-CANCEL-42',
          'business_date': today,
          'source': 'ONLINE_ORDER',
          'reference_order_id': '42',
          'status': 'CANCELLED',
          'total': 90,
        },
        {
          'sale_id': 'ONLINE-DELIVERED',
          'business_date': today,
          'source': 'ONLINE_ORDER',
          'reference_order_id': '43',
          'status': 'DELIVERED',
          'total': 30,
        },
      ], 0);

      expect(engine.totalSales, 80);
      expect(engine.totalTransactions, 2);
      expect(engine.lifetimeSalesCache, hasLength(engine.totalTransactions));
      expect(engine.todayRevenue, 80);
      expect(engine.todayTransactionsCount, 2);
      expect(
        engine.sales.map((sale) => sale['sale_id']),
        containsAll(['SALE-VALID', 'ONLINE-DELIVERED']),
      );
      expect(
        engine.sales.map((sale) => sale['sale_id']),
        isNot(contains('ONLINE-SALE-42')),
      );
    });

    test(
      'flat cloud rows for one invoice retain every product in analytics',
      () {
        final engine = AnalyticsEngine();
        final now = DateTime.now();
        final businessDate =
            '${now.year.toString().padLeft(4, '0')}-'
            '${now.month.toString().padLeft(2, '0')}-'
            '${now.day.toString().padLeft(2, '0')}';
        final timestamp = now.toUtc().toIso8601String();

        engine.recalculateAnalytics([
          {
            'id': '77_0',
            'sale_id': 'BILL-FLAT-77',
            'invoice_id': 77,
            'invoice_number': 'BILL-FLAT-77',
            'business_date': businessDate,
            'created_at': timestamp,
            'updated_at': timestamp,
            'product_name': 'Chicken',
            'price': 800,
            'quantity': 1,
            'total': 800,
            'total_amount': 1800,
            'paid_amount': 1800,
          },
          {
            'id': '77_1',
            'sale_id': 'BILL-FLAT-77',
            'invoice_id': 77,
            'invoice_number': 'BILL-FLAT-77',
            'business_date': businessDate,
            'created_at': timestamp,
            'updated_at': timestamp,
            'product_name': 'Mutton',
            'price': 1000,
            'quantity': 1,
            'total': 1000,
            'total_amount': 1800,
            'paid_amount': 1800,
          },
        ], 0);

        expect(engine.totalTransactions, 1);
        expect(engine.lifetimeRevenue, 1800);
        expect(engine.lifetimeTransactions, 1);
        expect(engine.sales, hasLength(1));
        final lines = engine.sales.single['items'] as List;
        expect(lines, hasLength(2));
        expect(lines.map((line) => (line as Map)['product_name']).toSet(), {
          'Chicken',
          'Mutton',
        });
        expect(
          engine.productAnalyticsCache.values
              .map((row) => row['total'])
              .toSet(),
          {800.0, 1000.0},
        );
      },
    );

    test('four line items remain attached to one sale', () {
      final engine = AnalyticsEngine();

      engine.recalculateAnalytics([
        {
          'sale_id': 'SALE-4',
          'business_date': '2026-08-13T12:00:00Z',
          'total': 100,
          'items': [
            {'product_id': 1, 'product_name': 'A', 'quantity': 1, 'price': 10},
            {'product_id': 2, 'product_name': 'B', 'quantity': 1, 'price': 20},
            {'product_id': 3, 'product_name': 'C', 'quantity': 1, 'price': 30},
            {'product_id': 4, 'product_name': 'D', 'quantity': 1, 'price': 40},
          ],
        },
      ], 0);

      expect(engine.totalSales, 100);
      expect(engine.totalTransactions, 1);
    });

    test(
      'invoice analytics keeps paid invoices and aggregates all payment states',
      () {
        final snapshot = InvoiceAnalyticsSnapshot.fromRows(
          [
            {
              'invoice_number': 'BILL-0001',
              'customer_name': 'Paid Customer',
              'customer_phone': '9876543210',
              'total_amount': 100.0,
              'paid_amount': 100.0,
            },
            {
              'invoice_number': 'BILL-0002',
              'customer_name': 'Partial Customer',
              'customer_phone': '9876543211',
              'total_amount': 80.0,
              'paid_amount': 30.0,
            },
            {
              'invoice_number': 'BILL-0003',
              'customer_name': 'Guest Customer',
              'total_amount': 25.0,
              'paid_amount': 0.0,
            },
          ],
          isValidCustomerPhone: (phone) =>
              RegExp(r'^[6-9][0-9]{9}$').hasMatch(phone),
        );

        expect(snapshot.invoices, hasLength(3));
        expect(snapshot.invoices.first['payment_status'], 'PAID');
        expect(snapshot.paidCount, 1);
        expect(snapshot.partialCount, 1);
        expect(snapshot.unpaidCount, 1);
        expect(snapshot.totalInvoiced, 205.0);
        expect(snapshot.totalPaid, 130.0);
        expect(snapshot.totalPending, 75.0);
        expect(snapshot.outstandingCreditInvoices, hasLength(1));
        expect(
          snapshot.outstandingCreditInvoices.single['invoice_number'],
          'BILL-0002',
        );
      },
    );

    test('event date helpers safely handle records without any timestamp', () {
      final engine = AnalyticsEngine();

      expect(engine.getLocalDate({}), DateTime(1970));
      expect(engine.getEventDate({}), DateTime(1970));
    });

    test(
      'lifetime sales cache excludes rows without a valid business date',
      () {
        final engine = AnalyticsEngine();
        final today = DateTime.now().toIso8601String();

        engine.recalculateAnalytics([
          {'sale_id': 'VALID-DATE', 'business_date': today, 'total_amount': 40},
          {'sale_id': 'MISSING-DATE', 'total_amount': 900},
        ], 0);

        expect(engine.totalTransactions, 1);
        expect(engine.lifetimeSalesCache, hasLength(engine.totalTransactions));
        expect(engine.totalSales, 40);
      },
    );

    test('headline dashboard metrics use one consistent selected-period set', () {
      final engine = AnalyticsEngine();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      String businessDate(DateTime value) {
        return DateTime(
          value.year,
          value.month,
          value.day,
          12,
        ).toIso8601String();
      }

      final rows = [
        {
          'sale_id': 'TODAY',
          'business_date': businessDate(today),
          'total_amount': 100.0,
        },
        {
          'sale_id': 'WEEK',
          'business_date': businessDate(
            today.subtract(const Duration(days: 3)),
          ),
          'total_amount': 50.0,
        },
        {
          'sale_id': 'MONTH',
          'business_date': businessDate(
            today.subtract(const Duration(days: 10)),
          ),
          'total_amount': 25.0,
        },
        {
          'sale_id': 'YEAR',
          'business_date': businessDate(DateTime(now.year, 1, 1)),
          'total_amount': 60.0,
        },
        {
          'sale_id': 'OLDER',
          'business_date': businessDate(
            DateTime(now.year - 1, now.month, now.day),
          ),
          'total_amount': 200.0,
        },
      ];

      void expectPeriod(int filter, double revenue, int transactions) {
        engine.recalculateAnalytics(rows, filter);
        expect(engine.displayRevenue, revenue);
        expect(engine.displayTransactions, transactions);
        expect(
          engine.filteredAverageSale,
          closeTo(transactions == 0 ? 0 : revenue / transactions, 0.001),
        );
      }

      expectPeriod(0, 100.0, 1);
      expectPeriod(1, 150.0, 2);
      expectPeriod(2, 175.0, 3);
      expectPeriod(3, 235.0, 4);

      // Lifetime totals remain separate from the selected-period headline KPIs.
      expect(engine.totalSales, 435.0);
      expect(engine.totalTransactions, 5);
      expect(engine.lifetimeSalesCache, hasLength(engine.totalTransactions));
    });
  });
}
