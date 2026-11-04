import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/analytics_engine.dart';
import 'package:retail_mind/invoice_dedup_helper.dart';
import 'package:retail_mind/transaction_reconciliation_helper.dart';

Map<String, dynamic> _line() => {
  'product_id': 7,
  'product_name': 'Rice',
  'quantity': 1,
  'unit_price': 10,
  'line_total': 10,
  'total': 10,
};

void main() {
  group('Financial data consistency regression tests', () {
    test('anonymous identical purchases remain separate transactions', () {
      final engine = AnalyticsEngine();
      final today = DateTime.now().toIso8601String();
      engine.recalculateAnalytics([
        {'business_date': today, 'total_amount': 100, 'items': [_line()]},
        {'business_date': today, 'total_amount': 100, 'items': [_line()]},
      ], 0);

      expect(engine.totalTransactions, 2);
      expect(engine.totalSales, 200);
    });

    test('repeated identical lines within one bill are both counted', () {
      final engine = AnalyticsEngine();
      final today = DateTime.now().toIso8601String();
      engine.recalculateAnalytics([
        {
          'sale_id': 'SALE-DUP-LINES',
          'business_date': today,
          'total_amount': 20,
          'items': [_line(), _line()],
        },
      ], 0);

      expect(engine.totalTransactions, 1);
      expect(engine.productAnalyticsCache['7']?['quantity'], 2.0);
      expect(engine.productAnalyticsCache['7']?['total'], 20.0);
    });

    test('newer invoice correction can reduce total and paid amount', () {
      final rows = InvoiceDedupHelper.canonicalizeInvoices([
        {
          'invoice_number': 'BILL-REFUND-1',
          'updated_at': '2026-11-01T10:00:00Z',
          'total_amount': 100,
          'paid_amount': 100,
          'payment_status': 'PAID',
          'items': [_line()],
        },
        {
          'invoice_number': 'BILL-REFUND-1',
          'updated_at': '2026-11-02T10:00:00Z',
          'total_amount': 80,
          'paid_amount': 30,
          'items': [_line()],
        },
      ]);

      expect(rows, hasLength(1));
      expect(rows.single['total_amount'], 80.0);
      expect(rows.single['paid_amount'], 30.0);
      expect(rows.single['pending_amount'], 50.0);
      expect(rows.single['payment_status'], 'PARTIAL');
    });

    test('mirror invoices preserve duplicate lines with one-to-one matching', () {
      final rows = InvoiceDedupHelper.canonicalizeInvoices([
        {
          'invoice_number': 'BILL-DUP-LINES',
          'updated_at': '2026-11-01T10:00:00Z',
          'total_amount': 20,
          'items': [_line(), _line()],
        },
        {
          'invoice_number': 'BILL-DUP-LINES',
          'updated_at': '2026-11-01T10:01:00Z',
          'total_amount': 20,
          'items': [_line(), _line()],
        },
      ]);

      expect(rows, hasLength(1));
      expect(rows.single['items'], hasLength(2));
    });

    test('newer invoice line snapshot does not resurrect returned lines', () {
      final rows = InvoiceDedupHelper.canonicalizeInvoices([
        {
          'invoice_number': 'BILL-PARTIAL-RETURN',
          'updated_at': '2026-11-01T10:00:00Z',
          'total_amount': 30,
          'items': [_line(), _line(), {..._line(), 'product_id': 8, 'product_name': 'Oil'}],
        },
        {
          'invoice_number': 'BILL-PARTIAL-RETURN',
          'updated_at': '2026-11-02T10:00:00Z',
          'total_amount': 20,
          'items': [_line(), _line()],
        },
      ]);
      expect(rows, hasLength(1));
      expect(rows.single['items'], hasLength(2));
      expect(
        (rows.single['items'] as List).where((line) => (line as Map)['product_id'] == 8),
        isEmpty,
      );
    });

    test('generic row IDs alone do not merge unrelated records', () {
      final rows = InvoiceDedupHelper.canonicalizeInvoices([
        {'id': 77, 'total_amount': 10},
        {'id': 77, 'total_amount': 20},
      ]);
      expect(rows, hasLength(2));
    });

    test('alias bridge groups reconcile regardless of input order', () {
      final rows = TransactionReconciliationHelper.dedupe([
        {
          'id': 'BILL-1',
          'type': 'Invoice',
          'raw': {'invoice_number': 'BILL-1', 'total_amount': 25},
        },
        {
          'id': 'SALE-1',
          'type': 'Cash Sale',
          'raw': {'sale_id': 'SALE-1', 'total_amount': 25},
        },
        {
          'id': 'BILL-1',
          'type': 'Invoice',
          'raw': {
            'invoice_number': 'BILL-1',
            'sale_id': 'SALE-1',
            'total_amount': 25,
          },
        },
      ]);
      expect(rows, hasLength(1));
    });
  });
}
