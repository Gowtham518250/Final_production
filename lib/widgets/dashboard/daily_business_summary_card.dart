import 'package:flutter/material.dart';

import '../../api_client.dart';

/// Small owner dashboard card backed by the canonical daily report endpoint.
/// Profit is intentionally shown as unavailable until purchase-cost coverage
/// is complete; the UI never turns a missing estimate into a fabricated zero.
class DailyBusinessSummaryCard extends StatefulWidget {
  const DailyBusinessSummaryCard({super.key});

  @override
  State<DailyBusinessSummaryCard> createState() =>
      _DailyBusinessSummaryCardState();
}

class _DailyBusinessSummaryCardState extends State<DailyBusinessSummaryCard> {
  Map<String, dynamic>? _report;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<dynamic> _asList(Object? value) =>
      value is List ? value : const <dynamic>[];

  double _number(Object? value) {
    if (value is num && value.toDouble().isFinite) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(Object? value) => '₹${_number(value).toStringAsFixed(2)}';

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiClient.getJson('/api/reports/daily')
          .timeout(const Duration(seconds: 12));
      final report = _asMap(_asMap(response)['report']);
      if (report.isEmpty || report['report_date'] == null) {
        throw const FormatException('Daily summary response is incomplete.');
      }
      if (!mounted) return;
      setState(() => _report = report);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Daily summary is unavailable. Check connection and retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _metric({
    required IconData icon,
    required String label,
    required String value,
    String? detail,
    Color tint = const Color(0xFF4F46E5),
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.065),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tint.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tint),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (detail != null && detail.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _ids(List<dynamic> rows, {String key = 'id'}) {
    final ids = rows
        .map((row) {
          if (row is Map) return row[key] ?? row['invoice_id'] ?? row['id'];
          return row;
        })
        .where((value) => value != null)
        .take(12)
        .join(', ');
    if (ids.isEmpty) return 'None';
    return ids;
  }

  Widget _sourceDetails(Map<String, dynamic> report) {
    final sources = _asMap(report['sources']);
    final invoices = _asList(sources['invoice_ids']);
    final payments = _asList(sources['payment_ids']);
    final expenses = _asList(sources['expense_ids']);
    final returns = _asList(sources['return_ids']);
    final dueInvoices = _asList(report['outstanding_invoices']);
    final lowStock = _asList(report['low_stock_products']);

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: const Text(
        'Trace figures to source records',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      children: [
        _sourceLine('Sales invoice IDs', _ids(invoices)),
        _sourceLine('Payment IDs', _ids(payments)),
        _sourceLine('Expense IDs', _ids(expenses)),
        _sourceLine('Approved return IDs', _ids(returns)),
        _sourceLine(
          'Credit invoices',
          dueInvoices.isEmpty
              ? 'None outstanding'
              : dueInvoices.take(8).map((row) {
                  final item = _asMap(row);
                  return '${item['invoice_number'] ?? item['invoice_id']}: ${_money(item['outstanding_amount'])}';
                }).join(' · '),
        ),
        _sourceLine(
          'Low stock items',
          lowStock.isEmpty
              ? 'None'
              : lowStock.take(8).map((row) {
                  final item = _asMap(row);
                  return '${item['product_name'] ?? item['product_id']} (${item['current_stock']}/${item['minimum_stock']})';
                }).join(' · '),
        ),
        const SizedBox(height: 4),
        const Text(
          'Lists are capped by the API for response size; open the related invoice or inventory screen for full records.',
          style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _sourceLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 10, color: Color(0xFF334155)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final collections = _asMap(report?['payment_collections']);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 680 ? 4 : 2;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E7FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.point_of_sale_rounded,
                    color: Color(0xFF4338CA),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's business summary",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'From invoices, payments, expenses and inventory',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh summary',
                  onPressed: _loading ? null : _load,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            if (_loading && report == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (report == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _error ?? 'Loading daily summary…',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                    if (_error != null)
                      TextButton.icon(
                        onPressed: _loading ? null : _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                  ],
                ),
              )
            else ...[
              Text(
                'Business date: ${report['report_date']}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: width >= 680 ? 2.0 : 1.65,
                children: [
                  _metric(
                    icon: Icons.trending_up_rounded,
                    label: 'Gross sales',
                    value: _money(report['gross_sales']),
                    tint: const Color(0xFF2563EB),
                  ),
                  _metric(
                    icon: Icons.assignment_return_outlined,
                    label: 'Returns',
                    value: _money(report['returns']),
                    tint: const Color(0xFFB45309),
                  ),
                  _metric(
                    icon: Icons.payments_outlined,
                    label: 'Net sales',
                    value: _money(report['net_sales']),
                    tint: const Color(0xFF047857),
                  ),
                  _metric(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Payments collected',
                    value: _money(report['total_collected']),
                    tint: const Color(0xFF0F766E),
                  ),
                  _metric(
                    icon: Icons.menu_book_rounded,
                    label: 'Customer credit',
                    value: _money(report['customer_credit_outstanding']),
                    tint: const Color(0xFF7C3AED),
                  ),
                  _metric(
                    icon: Icons.receipt_long_rounded,
                    label: 'Expenses recorded',
                    value: _money(report['total_expenses']),
                    tint: const Color(0xFF475569),
                  ),
                  _metric(
                    icon: Icons.ssid_chart_rounded,
                    label: 'Estimated net profit',
                    value: report['profit_estimate_available'] == true
                        ? _money(report['estimated_net_profit'])
                        : 'Unavailable',
                    detail: report['profit_estimate_available'] == true
                        ? 'Cost coverage: ${_number(report['cost_coverage_percent']).toStringAsFixed(0)}%'
                        : 'Add purchase costs to sold products',
                    tint: const Color(0xFF9333EA),
                  ),
                  _metric(
                    icon: Icons.inventory_2_outlined,
                    label: 'Low-stock alerts',
                    value: '${_number(report['stock_alert_count']).toInt()}',
                    detail: _asList(report['low_stock_products'])
                        .take(2)
                        .map((row) => _asMap(row)['product_name']?.toString() ?? '')
                        .where((name) => name.isNotEmpty)
                        .join(', '),
                    tint: const Color(0xFFDC2626),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '${_number(report['bill_count']).toInt()} recognized invoices · Cash ${_money(collections['cash'])} · UPI/transfer ${_money(collections['upi'])} · Card ${_money(collections['card'])}',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
              if (_number(report['refund_required_collections']) > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Refund required: ${_money(report['refund_required_collections'])}. These receipts are not treated as sale revenue.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFB45309),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              _sourceDetails(report),
              if (_error != null)
                Text(
                  'Showing the last loaded figures; refresh failed.',
                  style: const TextStyle(fontSize: 10, color: Color(0xFFB45309)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
