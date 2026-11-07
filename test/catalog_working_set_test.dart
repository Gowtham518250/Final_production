import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/catalog_working_set.dart';

void main() {
  test('billing catalog keeps price, stock, barcode and GST', () {
    final slim = CatalogWorkingSet.forBilling({
      'id': 41,
      'product_name': 'Tea powder',
      'barcode': '890123',
      'sku': '890123',
      'unit_price': 52,
      'gst_percent': 5,
      'current_stock': 3,
      'image_base64': 'AAAA' * 80,
      'photo_base64': 'BBBB' * 80,
      'image': 'data:image/png;base64,xxxx',
    });

    expect(slim['product_name'], 'Tea powder');
    expect(slim['barcode'], '890123');
    expect(slim['unit_price'], 52);
    expect(slim['gst_percent'], 5);
    expect(slim['current_stock'], 3);
    expect(slim.containsKey('image_base64'), isFalse);
    expect(slim.containsKey('photo_base64'), isFalse);
    expect(slim.containsKey('image'), isFalse);
  });

  test('http product photos stay available for posters', () {
    final slim = CatalogWorkingSet.forBilling({
      'name': 'RockerZ',
      'image': 'https://cdn.example/rockerz.png',
      'image_base64': 'CCCC' * 40,
    });
    expect(slim['image'], 'https://cdn.example/rockerz.png');
    expect(slim.containsKey('image_base64'), isFalse);
  });
}
