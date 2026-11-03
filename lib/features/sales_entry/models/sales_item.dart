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

  static double _money(double value) =>
      double.parse(value.toStringAsFixed(2));

  double get subtotal {
    if (!quantity.isFinite || !price.isFinite || quantity <= 0 || price <= 0) {
      return 0.0;
    }
    return _money(quantity * price);
  }

  double get discountAmount {
    if (!discount.isFinite || discount <= 0) return 0.0;
    return _money(discount.clamp(0.0, subtotal).toDouble());
  }

  double get taxableAmount =>
      _money((subtotal - discountAmount).clamp(0.0, double.infinity).toDouble());

  double get effectiveGstRate {
    if (!gst.isFinite || gst <= 0) return 0.0;
    return gst.clamp(0.0, 100.0).toDouble();
  }

  double get totalGstAmount => _money(taxableAmount * effectiveGstRate / 100);

  double get finalAmount => _money(taxableAmount + totalGstAmount);
}
