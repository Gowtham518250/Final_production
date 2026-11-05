class RecentBillData {
  const RecentBillData({
    required this.invoiceNumber,
    required this.customerName,
    required this.totalAmount,
    required this.items,
    required this.data,
  });

  final String invoiceNumber;
  final String customerName;
  final double totalAmount;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic> data;

  static List<RecentBillData> fromSales(List<Map<String, dynamic>> sales) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (var index = 0; index < sales.length; index++) {
      final sale = sales[index];
      final invoice = _firstText(sale, const [
        '_bill_id',
        'invoice_number',
        'sale_id',
        'id',
      ]);
      final key = invoice.isEmpty ? 'unidentified-$index' : invoice;
      grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(sale);
    }

    final bills = <RecentBillData>[];
    final sourceOrder = <RecentBillData, int>{};
    var order = 0;
    for (final entry in grouped.entries) {
      final rows = entry.value;
      final first = rows.first;
      final rawBill = rows
          .map((row) => _asMap(row['_bill_data']))
          .firstWhere(
            (bill) => bill.isNotEmpty,
            orElse: () => <String, dynamic>{},
          );
      final data = rawBill.isEmpty
          ? Map<String, dynamic>.from(first)
          : Map<String, dynamic>.from(rawBill);
      final invoiceKeys = const ['invoice_number', 'sale_id', '_bill_id', 'id'];
      final invoice = _firstText(data, invoiceKeys).isNotEmpty
          ? _firstText(data, invoiceKeys)
          : _firstText(first, invoiceKeys);
      final items = _readItems(data, rows);
      final total =
          _firstNumber(rawBill, const [
            'total_amount',
            'grand_total',
            'invoice_total',
            'total',
          ]) ??
          _firstNumber(first, const [
            'invoice_total',
            'total_amount',
            'grand_total',
          ]) ??
          (rows.length == 1 ? _firstNumber(first, const ['total']) : null) ??
          items.fold<double>(0, (sum, item) => sum + _lineAmount(item));
      const customerKeys = ['customer_name', 'customerName', 'customer'];
      final customer = _firstText(data, customerKeys).isNotEmpty
          ? _firstText(data, customerKeys)
          : _firstText(first, customerKeys);
      const statusKeys = [
        'payment_status_normalized',
        'payment_status',
        'invoice_status',
        'status',
      ];
      final status = _firstText(data, statusKeys).isNotEmpty
          ? _firstText(data, statusKeys)
          : _firstText(first, statusKeys);

      data['invoice_number'] = invoice.isEmpty ? entry.key : invoice;
      data['items'] = items;
      data['total_amount'] = total;
      if (status.isNotEmpty) data['payment_status_normalized'] = status;
      for (final key in const [
        'sale_timestamp',
        'invoice_timestamp',
        'created_at',
        'createdAt',
        'timestamp',
        'event_timestamp',
        'business_date',
        'sale_date',
        'invoice_date',
        'date',
      ]) {
        if (data[key] == null && first[key] != null) data[key] = first[key];
      }

      final bill = RecentBillData(
        invoiceNumber: invoice,
        customerName: customer,
        totalAmount: total,
        items: items,
        data: data,
      );
      bills.add(bill);
      sourceOrder[bill] = order++;
    }

    bills.sort((a, b) {
      final aDate = _sortDate(a);
      final bDate = _sortDate(b);
      if (aDate == null && bDate == null) {
        return sourceOrder[a]!.compareTo(sourceOrder[b]!);
      }
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      final byDate = bDate.compareTo(aDate);
      return byDate != 0 ? byDate : sourceOrder[a]!.compareTo(sourceOrder[b]!);
    });
    return bills;
  }

  static DateTime? _sortDate(RecentBillData bill) {
    for (final key in const [
      'sale_timestamp',
      'invoice_timestamp',
      'created_at',
      'createdAt',
      'timestamp',
      'event_timestamp',
      'business_date',
      'sale_date',
      'invoice_date',
      'date',
    ]) {
      final value = bill.data[key]?.toString().trim() ?? '';
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.toLocal();
    }
    return null;
  }

  static List<Map<String, dynamic>> _readItems(
    Map<String, dynamic> bill,
    List<Map<String, dynamic>> rows,
  ) {
    final rawItems = bill['items'] ?? bill['line_items'];
    if (rawItems is List) {
      final items = rawItems.whereType<Map>().map(_asMap).toList();
      if (items.isNotEmpty) return items;
    }

    final rowItems = rows
        .where(
          (row) => _firstText(row, const [
            'product_name',
            'product',
            'item',
            'description',
          ]).isNotEmpty,
        )
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    if (rowItems.isNotEmpty) return rowItems;

    if (_firstText(bill, const [
      'product_name',
      'product',
      'item',
      'description',
      'name',
    ]).isNotEmpty) {
      return [Map<String, dynamic>.from(bill)];
    }
    return const [];
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static String _firstText(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    return '';
  }

  static double? _firstNumber(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      final parsed = value is num
          ? value.toDouble()
          : double.tryParse(value?.toString() ?? '');
      if (parsed != null && parsed.isFinite) return parsed;
    }
    return null;
  }

  static double _lineAmount(Map<String, dynamic> item) {
    final explicit = _firstNumber(item, const [
      'total_with_tax',
      'line_total',
      'line_amount',
      'total',
    ]);
    if (explicit != null) return explicit;
    final quantity = _firstNumber(item, const ['quantity', 'qty']) ?? 1;
    final price = _firstNumber(item, const ['unit_price', 'price']) ?? 0;
    final discount =
        _firstNumber(item, const ['discount_amount', 'discount']) ?? 0;
    final tax = _firstNumber(item, const ['tax_amount']) ?? 0;
    return (quantity * price - discount).clamp(0, double.infinity) + tax;
  }
}
