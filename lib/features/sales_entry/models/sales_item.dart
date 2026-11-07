import '../../../gst_calculator.dart';

class SalesItem {
  final String id;
  final String itemName;
  final int? productId;
  final double quantity;
  final double price;
  final double gst;
  final double discount;

  const SalesItem({
    required this.id,
    this.itemName = '',
    this.productId,
    this.quantity = 1.0,
    this.price = 0.0,
    this.gst = 0.0,
    this.discount = 0.0,
  });

  SalesItem copyWith({
    String? itemName,
    int? productId,
    double? quantity,
    double? price,
    double? gst,
    double? discount,
  }) {
    return SalesItem(
      id: id,
      itemName: itemName ?? this.itemName,
      // If the cashier edits the product name, discard the old catalog ID.
      productId: itemName != null && itemName != this.itemName
          ? null
          : (productId ?? this.productId),
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      gst: gst ?? this.gst,
      discount: discount ?? this.discount,
    );
  }

  static double _money(double value) => double.parse(value.toStringAsFixed(2));

  double get billableQuantity {
    if (!quantity.isFinite || quantity <= 0) return 0.0;
    return double.parse(quantity.toStringAsFixed(3));
  }

  double get billablePrice {
    if (!price.isFinite || price <= 0) return 0.0;
    return _money(price);
  }

  double get subtotal {
    if (billableQuantity <= 0 || billablePrice <= 0) return 0.0;
    return _money(billableQuantity * billablePrice);
  }

  double get discountAmount {
    if (!discount.isFinite || discount <= 0) return 0.0;
    return _money(discount.clamp(0.0, subtotal).toDouble());
  }

  double get taxableAmount => _money(
    (subtotal - discountAmount).clamp(0.0, double.infinity).toDouble(),
  );

  double get effectiveGstRate {
    if (!gst.isFinite || gst <= 0) return 0.0;
    return gst.clamp(0.0, 100.0).toDouble();
  }

  double get totalGstAmount => GstCalculator.calculateItemGST(
    price: taxableAmount,
    quantity: 1,
    gstRate: effectiveGstRate,
  ).totalGST;

  double get finalAmount => _money(taxableAmount + totalGstAmount);
}
