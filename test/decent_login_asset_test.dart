import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('login illustrations are available in the asset bundle', () async {
    final assets = await Future.wait([
      rootBundle.load('assets/shop_keeper.png'),
      rootBundle.load('assets/shop_bottom_left.png'),
      rootBundle.load('assets/bag_bottom_right.png'),
    ]);

    expect(assets.every((asset) => asset.lengthInBytes > 0), isTrue);
  });
}
