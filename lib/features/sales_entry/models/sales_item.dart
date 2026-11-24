import '../../../gst_calculator.dart';

class SalesItem {
  final String id;
  final String itemName;
  final int? productId;
  /// null = ordinary/manual line; true = explicit catalogue authorization;
  /// false = voice/custom line that must never link to stock by name.
  final bool? catalogMatched;
  final double quantity;
  final double price;
  final double gst;
  final double discount;

  const SalesItem({
    required this.id,
    this.itemName = '',
    this.productId,
    this.catalogMatched,
    this.quantity = 1.0,
    this.price = 0.0,
    this.gst = 0.0,
    this.discount = 0.0,
  });

  SalesItem copyWith({
    String? itemName,
    int? productId,
    bool? catalogMatched,
    double? quantity,
    double? price,
    double? gst,
    double? discount,
  }) {
    final nameChanged = itemName != null && itemName != this.itemName;
    final nextProductId = nameChanged ? productId : (productId ?? this.productId);
    final nextCatalogMatched = catalogMatched ??
        (productId != null
            ? productId > 0
            : (nameChanged && this.catalogMatched == true
                ? false
                : this.catalogMatched));

    return SalesItem(
      id: id,
      itemName: itemName ?? this.itemName,
      // An explicit product selection authorizes the selected ID. Renaming a
      // previously matched voice line clears that authorization.
      productId: nextProductId,
      catalogMatched: nextCatalogMatched,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      gst: gst ?? this.gst,
      discount: discount ?? this.discount,
    );
  }

  /// Only a positive ID paired with an explicit backend/product selection is
  /// allowed to create a stock-backed invoice line.
  int? get catalogAuthorizedProductId {
    final id = productId;
    if (catalogMatched != true || id == null || id <= 0) return null;
    return id;
  }

  /// Legacy/manual lines remain stock-tracked. Voice lines explicitly marked
  /// unmatched (or carrying an invalid authorized ID) stay custom/untracked.
  bool get isStockTracked =>
      catalogMatched == null || catalogAuthorizedProductId != null;

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
