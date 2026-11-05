import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'recent_bill_data.dart';

class RecentBillDetailsDialog extends StatelessWidget {
  const RecentBillDetailsDialog({super.key, required this.bill});

  final RecentBillData bill;

  static const _ink = Color(0xFF1F2937);
  static const _muted = Color(0xFF64748B);
  static const _accent = Color(0xFF6366F1);

  double _number(
    Map<String, dynamic> values,
    List<String> keys, {
    double fallback = 0,
  }) {
    for (final key in keys) {
      final value = values[key];
      final parsed = value is num
          ? value.toDouble()
          : double.tryParse(value?.toString() ?? '');
      if (parsed != null && parsed.isFinite) return parsed;
    }
    return fallback;
  }

  String _text(
    Map<String, dynamic> values,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = values[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    return fallback;
  }

  DateTime? _date() {
    final value = _text(bill.data, const [
      'business_date',
      'sale_date',
      'invoice_date',
      'created_at',
      'createdAt',
      'timestamp',
    ]);
    return DateTime.tryParse(value)?.toLocal();
  }

  double _itemAmount(Map<String, dynamic> item) {
    for (final key in const [
      'total_with_tax',
      'line_total',
      'line_amount',
      'total',
    ]) {
      final amount = _number(item, [key], fallback: double.nan);
      if (amount.isFinite) return amount;
    }
    final quantity = _number(item, const ['quantity', 'qty'], fallback: 1);
    final price = _number(item, const ['unit_price', 'price']);
    final discount = _number(item, const ['discount_amount', 'discount']);
    final tax = _number(item, const ['tax_amount']);
    return (quantity * price - discount).clamp(0, double.infinity) + tax;
  }

  @override
  Widget build(BuildContext context) {
    final date = _date();
    final status = _text(bill.data, const [
      'payment_status',
      'invoice_status',
      'status',
    ], fallback: 'N/A');
    final paid = _number(bill.data, const [
      'paid_amount',
      'amount_paid',
      'paid',
    ], fallback: double.nan);
    final itemSubtotal = bill.items.fold<double>(
      0,
      (sum, item) =>
          sum +
          _number(item, const ['quantity', 'qty'], fallback: 1) *
              _number(item, const ['unit_price', 'price']),
    );
    final itemDiscount = bill.items.fold<double>(
      0,
      (sum, item) => sum + _number(item, const ['discount_amount', 'discount']),
    );
    final discount = itemDiscount > 0
        ? itemDiscount
        : _number(bill.data, const ['discount_amount', 'total_discount']);
    final itemTax = bill.items.fold<double>(
      0,
      (sum, item) => sum + _number(item, const ['tax_amount']),
    );
    final tax = itemTax > 0
        ? itemTax
        : _number(
            bill.data,
            const ['tax_total', 'tax_amount', 'gst_amount'],
            fallback:
                _number(bill.data, const ['cgst_amount']) +
                _number(bill.data, const ['sgst_amount']),
          );
    final subtotal = _number(bill.data, const [
      'subtotal',
      'sub_total',
      'items_subtotal',
    ], fallback: itemSubtotal);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          maxWidth: 520,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, color: _accent, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bill ${bill.invoiceNumber.isEmpty ? '' : '#${bill.invoiceNumber}'}',
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            bill.customerName.isEmpty
                                ? 'Walk-in Customer'
                                : bill.customerName,
                            style: const TextStyle(color: _muted, fontSize: 13),
                          ),
                          if (date != null)
                            Text(
                              DateFormat('dd MMM yyyy, hh:mm a').format(date),
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close bill',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: _muted),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: Row(
                  children: [
                    const Expanded(
                      flex: 5,
                      child: Text('PRODUCT', style: _tableHeader),
                    ),
                    const Expanded(
                      flex: 2,
                      child: Text(
                        'QTY × RATE',
                        textAlign: TextAlign.right,
                        style: _tableHeader,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'AMOUNT',
                        textAlign: TextAlign.right,
                        style: _tableHeader,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: bill.items.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Item details are not available for this bill.',
                          style: TextStyle(color: _muted),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: bill.items.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: Color(0xFFE5E7EB)),
                        itemBuilder: (context, index) {
                          final item = bill.items[index];
                          final name = _text(item, const [
                            'product_name',
                            'product',
                            'item',
                            'description',
                            'name',
                            'title',
                          ], fallback: 'Item');
                          final quantity = _number(item, const [
                            'quantity',
                            'qty',
                          ], fallback: 1);
                          final rate = _number(item, const [
                            'unit_price',
                            'price',
                            'selling_price',
                          ]);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      color: _ink,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${_quantityText(quantity)} × ₹${rate.toStringAsFixed(2)}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '₹${_itemAmount(item).toStringAsFixed(2)}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      color: _ink,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                child: Column(
                  children: [
                    _totalRow('Subtotal', subtotal),
                    if (discount > 0) _totalRow('Discount', -discount),
                    if (tax > 0) _totalRow('Tax', tax),
                    const SizedBox(height: 5),
                    _totalRow('Grand total', bill.totalAmount, strong: true),
                    if (paid.isFinite) ...[
                      _totalRow('Paid', paid),
                      _totalRow(
                        'Balance due',
                        (bill.totalAmount - paid).clamp(0, double.infinity),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        status.toUpperCase(),
                        style: const TextStyle(
                          color: _accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _tableHeader = TextStyle(
    color: _muted,
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.4,
  );

  static String _quantityText(double value) => value == value.truncateToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();

  Widget _totalRow(String label, double amount, {bool strong = false}) {
    final style = TextStyle(
      color: strong ? _ink : _muted,
      fontSize: strong ? 15 : 12,
      fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '₹${amount.toStringAsFixed(2)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              textAlign: TextAlign.right,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}
