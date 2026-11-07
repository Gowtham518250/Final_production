import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:retail_mind/export_service.dart';
import 'package:retail_mind/widgets/dashboard/recent_bill_details_dialog.dart';
import 'package:retail_mind/widgets/dashboard/recent_bill_data.dart';

void main() {
  group('RecentBillData', () {
    test('groups flattened product rows into one bill with its full items', () {
      final bills = RecentBillData.fromSales([
        {
          '_bill_id': 'B-101',
          'invoice_number': 'B-101',
          'product_name': 'Rice',
          'quantity': 2,
          'price': 50,
          'total': 100,
          'invoice_total': 145,
          '_bill_data': {
            'invoice_number': 'B-101',
            'customer_name': 'Anu',
            'total_amount': 145,
            'payment_status': 'PAID',
            'items': [
              {
                'product_name': 'Rice',
                'quantity': 2,
                'unit_price': 50,
                'line_total': 100,
              },
              {
                'product_name': 'Flour',
                'quantity': 1,
                'unit_price': 45,
                'line_total': 45,
              },
            ],
          },
        },
        {
          '_bill_id': 'B-101',
          'invoice_number': 'B-101',
          'product_name': 'Flour',
          'quantity': 1,
          'price': 45,
          'total': 45,
          'invoice_total': 145,
        },
        {
          '_bill_id': 'B-102',
          'invoice_number': 'B-102',
          'product_name': 'Tea',
          'quantity': 1,
          'price': 20,
          'total': 20,
        },
      ]);

      expect(bills, hasLength(2));
      expect(bills.first.invoiceNumber, 'B-101');
      expect(bills.first.customerName, 'Anu');
      expect(bills.first.totalAmount, 145);
      expect(bills.first.items.map((item) => item['product_name']), [
        'Rice',
        'Flour',
      ]);
    });

    test(
      'uses available actual product rows when raw bill items are absent',
      () {
        final bills = RecentBillData.fromSales([
          {
            '_bill_id': 'B-202',
            'invoice_number': 'B-202',
            'product_name': 'Apples',
            'quantity': 2,
            'price': 30,
            'total': 60,
          },
          {
            '_bill_id': 'B-202',
            'invoice_number': 'B-202',
            'product_name': 'Oranges',
            'quantity': 3,
            'price': 20,
            'total': 60,
          },
        ]);

        expect(bills, hasLength(1));
        expect(bills.single.totalAmount, 120);
        expect(bills.single.items.map((item) => item['product_name']), [
          'Apples',
          'Oranges',
        ]);
      },
    );

    test('sorts bills newest first and puts undated bills last', () {
      final bills = RecentBillData.fromSales([
        {
          'invoice_number': 'OLD',
          'created_at': '2026-11-03T10:00:00',
          'product_name': 'Milk',
          'total': 10,
        },
        {
          'invoice_number': 'UNKNOWN-DATE',
          'product_name': 'Bread',
          'total': 20,
        },
        {
          'invoice_number': 'NEW',
          'created_at': '2026-11-05T12:00:00',
          'product_name': 'Rice',
          'total': 30,
        },
      ]);

      expect(bills.map((bill) => bill.invoiceNumber), [
        'NEW',
        'OLD',
        'UNKNOWN-DATE',
      ]);
    });

    testWidgets('bill details show all products and the invoice total', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final bill = RecentBillData(
        invoiceNumber: 'INV-9',
        customerName: 'Anu',
        totalAmount: 145,
        items: [
          {
            'product_name': 'Rice',
            'quantity': 2,
            'unit_price': 50,
            'line_total': 100,
          },
          {
            'product_name': 'Flour',
            'quantity': 1,
            'unit_price': 45,
            'line_total': 45,
          },
        ],
        data: {'payment_status': 'PAID', 'paid_amount': 145},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => RecentBillDetailsDialog(bill: bill),
                ),
                child: const Text('Open bill'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open bill'));
      await tester.pumpAndSettle();

      expect(find.text('Rice'), findsOneWidget);
      expect(find.text('Flour'), findsOneWidget);
      expect(find.text('Grand total'), findsOneWidget);
      expect(find.text('₹145.00'), findsNWidgets(3));
    });

    testWidgets(
      'bill details use event time instead of date-only business date',
      (tester) async {
        const eventTimestamp = '2026-11-07T04:42:35Z';
        final bill = RecentBillData(
          invoiceNumber: 'B-121',
          customerName: 'Cash Customer',
          totalAmount: 100,
          items: const [],
          data: const {
            'business_date': '2026-11-07',
            'created_at': eventTimestamp,
          },
        );

        await tester.pumpWidget(
          MaterialApp(home: RecentBillDetailsDialog(bill: bill)),
        );

        final expectedTime = DateFormat(
          'dd MMM yyyy, hh:mm a',
        ).format(DateTime.parse(eventTimestamp).toLocal());
        expect(find.text(expectedTime), findsOneWidget);
        expect(find.text('07 Nov 2026, 12:00 AM'), findsNothing);
      },
    );

    testWidgets(
      'bill details use the same event-time precedence and timezone as the list',
      (tester) async {
        final bill = RecentBillData(
          invoiceNumber: 'B-129',
          customerName: 'Guest Customer',
          totalAmount: 9,
          items: const [],
          data: const {
            'business_date': '2026-11-07',
            'sale_timestamp': '2026-11-07T15:38:00',
            'event_timestamp': '2026-11-07T09:08:53',
            'created_at': '2026-11-07T09:08:53',
          },
        );

        await tester.pumpWidget(
          MaterialApp(home: RecentBillDetailsDialog(bill: bill)),
        );

        final listEventTime = ExportService.resolveSalesEventTime(bill.data);
        expect(listEventTime, isNotNull);
        final expected = DateFormat(
          'dd MMM yyyy, hh:mm a',
        ).format(listEventTime!);
        expect(find.text(expected), findsOneWidget);
        expect(find.text('07 Nov 2026, 03:38 PM'), findsNothing);
      },
    );
  });
}
