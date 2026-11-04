import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/analytics_engine.dart';
import 'package:retail_mind/transaction_reconciliation_helper.dart';

String _ymd(DateTime t) =>
    '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

Map<String, dynamic> _flatRow(
  String invoice,
  String product,
  double lineTotal,
  double invoiceTotal,
  String date, {
  int? idx,
}) => {
  'business_date': date,
  'invoice_number': invoice,
  '_bill_id': invoice,
  if (idx != null) '_item_idx': idx,
  'product': product,
  'product_name': product,
  'product_id': 'p_$product',
  'quantity': 1.0,
  'price': lineTotal,
  'total': lineTotal,
  'invoice_total': invoiceTotal,
  'paid_amount': invoiceTotal,
  'payment_status': 'PAID',
};

void main() {
  final today = _ymd(DateTime.now());

  group('Dashboard totals consistency', () {
    test('multi-line bill counts invoice total, not last line', () {
      final rows = [
        _flatRow('INV-1', 'Milk', 100, 300, today, idx: 0),
        _flatRow('INV-1', 'Bread', 100, 300, today, idx: 1),
        _flatRow('INV-1', 'Eggs', 100, 300, today, idx: 2),
        _flatRow('INV-2', 'Rice', 50, 200, today, idx: 0),
        _flatRow('INV-2', 'Oil', 150, 200, today, idx: 1),
      ];
      final engine = AnalyticsEngine()..recalculateAnalytics(rows, 4);
      expect(engine.totalSales, 500.0);
      expect(engine.totalTransactions, 2);
      expect(engine.lifetimeRevenue, 500.0);
      expect(engine.todayRevenue, 500.0);
    });

    test('total does not depend on row order', () {
      final rows = [
        _flatRow('X', 'A', 10, 60, today, idx: 0),
        _flatRow('X', 'B', 20, 60, today, idx: 1),
        _flatRow('X', 'C', 30, 60, today, idx: 2),
      ];
      final forward = AnalyticsEngine()..recalculateAnalytics(rows, 4);
      final reversed = AnalyticsEngine()
        ..recalculateAnalytics(rows.reversed.toList(), 4);
      expect(forward.totalSales, 60.0);
      expect(reversed.totalSales, 60.0);
    });

    test('single-line bill with tax/discount uses invoice total', () {
      final rows = [_flatRow('T1', 'Soap', 100, 118, today, idx: 0)];
      final engine = AnalyticsEngine()..recalculateAnalytics(rows, 4);
      expect(engine.totalSales, 118.0);
    });

    test('identical bill lines are counted separately', () {
      final rows = [
        _flatRow('DUP', 'Tea', 100, 200, today, idx: 0),
        _flatRow('DUP', 'Tea', 100, 200, today, idx: 1),
      ];
      final engine = AnalyticsEngine()..recalculateAnalytics(rows, 4);
      expect(engine.totalSales, 200.0);
      final tea = engine.productAnalyticsCache.values.first;
      expect(tea['quantity'], 2.0);
      expect(tea['total'], 200.0);
    });

    test('local sale and cloud mirror sharing bill number count once', () {
      final local = {
        'offline_id': 'off-1',
        'invoice_number': 'INV-9',
        'business_date': today,
        'total_amount': 500.0,
        'paid_amount': 500.0,
        'items': [
          {'product_name': 'Soap', 'quantity': 1, 'unit_price': 500.0, 'line_total': 500.0},
        ],
      };
      final cloud = {
        'id': 77,
        'invoice_number': 'INV-9',
        'business_date': today,
        'total_amount': 500.0,
        'paid_amount': 500.0,
        'items': [
          {'product_name': 'Soap', 'quantity': 1, 'unit_price': 500.0, 'line_total': 500.0},
        ],
      };
      final engine = AnalyticsEngine()..recalculateAnalytics([local, cloud], 4);
      expect(engine.totalSales, 500.0);
      expect(engine.totalTransactions, 1);
    });

    test('rolling 12-month chart includes previous-year month values', () {
      final now = DateTime.now();
      final lastDec = DateTime(now.year - 1, 12, 15);
      Map<String, dynamic> sale(String id, String date, double amount) => {
        'invoice_number': id,
        'business_date': date,
        'total_amount': amount,
        'paid_amount': amount,
        'items': [
          {'product_name': 'P', 'quantity': 1, 'unit_price': amount, 'line_total': amount},
        ],
      };
      final engine = AnalyticsEngine()
        ..recalculateAnalytics([
          sale('D1', _ymd(lastDec), 1000.0),
          sale('N1', today, 200.0),
        ], 4);
      final chartSum = engine.salesByMonthCache.values.fold(0.0, (s, v) => s + v);
      expect(chartSum, 1200.0);
      expect(engine.totalSales, 1200.0);
    });

    test('cancelled/returned bills are excluded from totals', () {
      Map<String, dynamic> sale(String id, {String? status}) => {
        'invoice_number': id,
        'business_date': today,
        'total_amount': 100.0,
        'paid_amount': 100.0,
        if (status != null) 'status': status,
        'items': [
          {'product_name': 'A', 'quantity': 1, 'unit_price': 100.0, 'line_total': 100.0},
        ],
      };
      final engine = AnalyticsEngine()
        ..recalculateAnalytics([sale('V1'), sale('V2', status: 'RETURNED')], 4);
      expect(engine.totalSales, 100.0);
      expect(engine.totalTransactions, 1);
    });
  });

  group('History reconciliation', () {
    test('connected stable aliases reconcile and 20k records stay linear', () {
      final rows = <Map<String, dynamic>>[
        {'id': 'SALE_1', 'amount': 10.0, 'raw': {'invoice_number': 'INV-1', 'offline_id': 'o1'}},
        {'id': 'INV-1', 'amount': 10.0, 'raw': {'invoice_number': 'INV-1', 'id': 55}},
        {'id': 'INV-2', 'amount': 20.0, 'raw': {'invoice_number': 'INV-2'}},
      ];
      expect(TransactionReconciliationHelper.dedupe(rows), hasLength(2));

      final many = [
        for (var i = 0; i < 20000; i++)
          {'id': 'INV-$i', 'amount': 1.0, 'raw': {'invoice_number': 'INV-$i', 'id': i + 1}},
      ];
      final stopwatch = Stopwatch()..start();
      expect(TransactionReconciliationHelper.dedupe(many), hasLength(20000));
      expect(stopwatch.elapsedMilliseconds < 3000, isTrue);
    });
  });
}
