import 'package:decimal/decimal.dart';

/// GST Calculator Service
/// Provides precise GST calculations using decimal arithmetic
/// to avoid floating-point errors in financial calculations
class GstCalculator {
  static Decimal _input(num value, String name) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, name, 'Must be finite.');
    }
    return Decimal.parse(value.toString());
  }

  static Decimal _roundCurrency(Decimal value) =>
      Decimal.parse(value.toStringAsFixed(2));

  static ({Decimal cgst, Decimal sgst, Decimal total}) _taxComponents(
    Decimal taxable,
    Decimal rate,
  ) {
    final total = _roundCurrency(
      (taxable * rate / Decimal.fromInt(100)).toDecimal(
        scaleOnInfinitePrecision: 10,
      ),
    );
    final cgst = _roundCurrency(
      (total / Decimal.fromInt(2)).toDecimal(scaleOnInfinitePrecision: 10),
    );
    return (cgst: cgst, sgst: total - cgst, total: total);
  }

  /// Calculate GST components for a single item
  static GstComponents calculateItemGST({
    required double price,
    required num quantity,
    required double gstRate,
  }) {
    final priceDecimal = _input(price, 'price');
    final quantityDecimal = _input(quantity, 'quantity');
    final gstRateDecimal = _input(gstRate, 'gstRate');
    if (priceDecimal < Decimal.zero ||
        quantityDecimal <= Decimal.zero ||
        gstRateDecimal < Decimal.zero) {
      throw ArgumentError(
        'Price, quantity, and GST rate must be non-negative.',
      );
    }

    final lineTotal = priceDecimal * quantityDecimal;
    final tax = _taxComponents(lineTotal, gstRateDecimal);

    return GstComponents(
      subtotal: lineTotal.toDouble(),
      cgst: tax.cgst.toDouble(),
      sgst: tax.sgst.toDouble(),
      totalGST: tax.total.toDouble(),
      grandTotal: (lineTotal + tax.total).toDouble(),
    );
  }

  /// Calculate GST for multiple items
  static GstComponents calculateBatchGST({required List<GstItem> items}) {
    Decimal totalSubtotal = Decimal.zero;
    Decimal totalCGST = Decimal.zero;
    Decimal totalSGST = Decimal.zero;

    for (final item in items) {
      final quantity = _input(item.quantity, 'quantity');
      final price = _input(item.price, 'price');
      if (quantity <= Decimal.zero || price < Decimal.zero) {
        throw ArgumentError(
          'Item price must be non-negative and quantity positive.',
        );
      }
      final lineTotal = quantity * price;

      totalSubtotal += lineTotal;

      if (item.gstRate != null) {
        final gstRate = _input(item.gstRate!, 'gstRate');
        if (gstRate < Decimal.zero) {
          throw ArgumentError.value(item.gstRate, 'gstRate');
        }
        final tax = _taxComponents(lineTotal, gstRate);
        totalCGST += tax.cgst;
        totalSGST += tax.sgst;
      }
    }

    // FIX: Derive totalGST from the rounded halves to ensure cgst + sgst == totalGST
    final displayTotalGST = totalCGST + totalSGST;

    return GstComponents(
      subtotal: totalSubtotal.toDouble(),
      cgst: totalCGST.toDouble(),
      sgst: totalSGST.toDouble(),
      totalGST: displayTotalGST.toDouble(),
      grandTotal: (totalSubtotal + displayTotalGST).toDouble(),
    );
  }

  /// Calculate discount-aware GST (discount applied before tax)
  static GstComponents calculateWithDiscount({
    required double price,
    required num quantity,
    required double discountPercent,
    required double gstRate,
  }) {
    final priceDecimal = _input(price, 'price');
    final quantityDecimal = _input(quantity, 'quantity');
    final discount = _input(discountPercent, 'discountPercent');
    final gstRateDecimal = _input(gstRate, 'gstRate');
    if (priceDecimal < Decimal.zero ||
        quantityDecimal <= Decimal.zero ||
        discount < Decimal.zero ||
        discount > Decimal.fromInt(100) ||
        gstRateDecimal < Decimal.zero) {
      throw ArgumentError(
        'Price and GST rate must be non-negative, quantity positive, and discount between 0 and 100.',
      );
    }

    final lineTotal = priceDecimal * quantityDecimal;
    final discountAmount = (lineTotal * discount / Decimal.fromInt(100))
        .toDecimal(scaleOnInfinitePrecision: 10);
    final discountedPrice = lineTotal - discountAmount;

    final tax = _taxComponents(discountedPrice, gstRateDecimal);
    final roundedDiscountedPrice = _roundCurrency(discountedPrice);
    final grandTotal = roundedDiscountedPrice + tax.total;

    return GstComponents(
      subtotal: lineTotal.toDouble(),
      discountAmount: discountAmount.toDouble(),
      discountedPrice: roundedDiscountedPrice.toDouble(),
      cgst: tax.cgst.toDouble(),
      sgst: tax.sgst.toDouble(),
      totalGST: tax.total.toDouble(),
      grandTotal: grandTotal.toDouble(),
    );
  }

  /// Round to 2 decimal places (paise)
  static double roundToPaise(double value) {
    return _roundCurrency(_input(value, 'value')).toDouble();
  }
}

/// GST calculation result components
class GstComponents {
  final double subtotal;
  final double cgst;
  final double sgst;
  final double totalGST;
  final double grandTotal;
  final double? discountAmount;
  final double? discountedPrice;

  GstComponents({
    required this.subtotal,
    required this.cgst,
    required this.sgst,
    required this.totalGST,
    required this.grandTotal,
    this.discountAmount,
    this.discountedPrice,
  });

  @override
  String toString() {
    return 'GstComponents(subtotal: $subtotal, cgst: $cgst, sgst: $sgst, totalGST: $totalGST, grandTotal: $grandTotal)';
  }
}

/// Item for GST calculation
class GstItem {
  final double price;
  final num quantity;
  final double? gstRate;

  GstItem({required this.price, required this.quantity, this.gstRate});
}
