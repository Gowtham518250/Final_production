/// Keeps POS/search catalogs accurate while dropping photo blobs from RAM.
///
/// Billing still uses name, barcode, SKU, price, GST and stock. Images stay on
/// disk in Hive and are decoded only for the visible row.
class CatalogWorkingSet {
  CatalogWorkingSet._();

  static const _heavyKeys = <String>{
    'image_base64',
    'photo_base64',
    'image_bytes',
    'logo_base64',
    'thumbnail_base64',
    'product_image_base64',
    'images',
    'gallery',
  };

  static Map<String, dynamic> forBilling(Map<dynamic, dynamic> source) {
    final out = <String, dynamic>{};
    source.forEach((key, value) {
      final field = key.toString();
      if (_heavyKeys.contains(field)) return;
      if (field == 'image' || field == 'photo' || field == 'product_image') {
        if (_isInlineImage(value)) return;
      }
      out[field] = value;
    });
    return out;
  }

  static List<Map<String, dynamic>> listForBilling(Iterable<dynamic> products) {
    return products
        .whereType<Map>()
        .map((item) => forBilling(item))
        .toList(growable: false);
  }

  static bool _isInlineImage(dynamic value) {
    if (value is! String) return false;
    final text = value.trim();
    if (text.startsWith('http://') || text.startsWith('https://')) return false;
    if (text.startsWith('data:image')) return true;
    return text.length > 256 && !text.contains(' ');
  }
}
