/// Aggregates invoice lines by catalog product identity AND unit selling price.
/// Repeated sales of the same product at the same price form one chart bucket;
/// a price change creates a distinct bucket.
class ProductPriceBucket {
  final String key;
  final String productName;
  final String label;
  final double unitPrice;
  final bool hasUnitPrice;
  final double revenue;
  final double quantity;

  const ProductPriceBucket({
    required this.key,
    required this.productName,
    required this.label,
    required this.unitPrice,
    required this.hasUnitPrice,
    required this.revenue,
    required this.quantity,
  });
}

class ProductPriceAnalytics {
  ProductPriceAnalytics._();

  static double _number(Object? value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0.0;
    return parsed.isFinite ? parsed : 0.0;
  }

  static double _firstPositive(Iterable<Object?> values) {
    for (final value in values) {
      final parsed = _number(value);
      if (parsed > 0 && parsed.isFinite) return parsed;
    }
    return 0.0;
  }

  static String _normalizedName(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static List<ProductPriceBucket> aggregateSales(Iterable<dynamic> sales) {
    final grouped = <String, Map<String, dynamic>>{};

    void addLine(Map<String, dynamic> line) {
      final rawName = (line['display_name'] ??
              line['product_name'] ??
              line['product'] ??
              line['item'] ??
              line['description'] ??
              line['name'] ??
              '')
          .toString()
          .trim();
      final name = rawName.isEmpty ? 'Unknown Product' : rawName;
      final normalizedName = _normalizedName(name);
      if (normalizedName.isEmpty || normalizedName == 'unknown product') return;

      String rawIdentity = '';
      for (final field in const ['product_id', 'barcode', 'sku']) {
        final candidate = (line[field] ?? '').toString().trim();
        if (candidate.isNotEmpty && candidate != '0') {
          rawIdentity = candidate;
          break;
        }
      }
      final productIdentity = rawIdentity.isNotEmpty
          ? 'id:${rawIdentity.toLowerCase()}'
          : 'name:$normalizedName';

      final quantity = _number(line['quantity'] ?? line['qty']);
      final revenue = _firstPositive([
        line['line_total'],
        line['total_with_tax'],
        line['total'],
        line['amount'],
      ]);
      var unitPrice = _firstPositive([
        line['unit_price'],
        line['price'],
        line['selling_price'],
      ]);
      if (unitPrice <= 0 && quantity > 0 && revenue > 0) {
        unitPrice = revenue / quantity;
      }

      final hasUnitPrice = unitPrice > 0 && unitPrice.isFinite;
      final priceIdentity =
          hasUnitPrice ? unitPrice.toStringAsFixed(2) : 'unknown-price';
      final key = '$productIdentity|$priceIdentity';
      final label = hasUnitPrice
          ? '$name · ₹${unitPrice.toStringAsFixed(2)}'
          : '$name · Price unavailable';

      final bucket = grouped.putIfAbsent(key, () => {
            'product_name': name,
            'label': label,
            'unit_price': hasUnitPrice ? unitPrice : 0.0,
            'has_unit_price': hasUnitPrice,
            'revenue': 0.0,
            'quantity': 0.0,
          });
      bucket['revenue'] = _number(bucket['revenue']) + revenue;
      bucket['quantity'] = _number(bucket['quantity']) + quantity;
    }

    for (final rawSale in sales) {
      if (rawSale is! Map) continue;
      final sale = Map<String, dynamic>.from(rawSale);
      final items = sale['items'];
      final lineItems = sale['line_items'];
      final rawLines = items is List && items.isNotEmpty
          ? items
          : lineItems is List
              ? lineItems
              : null;

      if (rawLines is List && rawLines.isNotEmpty) {
        for (final rawLine in rawLines) {
          if (rawLine is Map) addLine(Map<String, dynamic>.from(rawLine));
        }
      } else {
        addLine(sale);
      }
    }

    final result = grouped.entries.map((entry) {
      final row = entry.value;
      final name = row['product_name'].toString();
      final price = _number(row['unit_price']);
      return ProductPriceBucket(
        key: entry.key,
        productName: name,
        label: row['label'].toString(),
        unitPrice: price,
        hasUnitPrice: row['has_unit_price'] == true,
        revenue: _number(row['revenue']),
        quantity: _number(row['quantity']),
      );
    }).toList()
      ..sort((a, b) {
        final revenueOrder = b.revenue.compareTo(a.revenue);
        if (revenueOrder != 0) return revenueOrder;
        final quantityOrder = b.quantity.compareTo(a.quantity);
        if (quantityOrder != 0) return quantityOrder;
        return a.label.compareTo(b.label);
      });
    return result;
  }

  static bool hasPositiveMonthlyRevenue(Map<String, double> monthlyRevenue) =>
      monthlyRevenue.values.any((amount) => amount.isFinite && amount > 0);
}
