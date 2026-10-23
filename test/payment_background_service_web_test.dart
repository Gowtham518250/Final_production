import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/payment_background_service_web.dart';

void main() {
  test('web payment background initialization is a safe no-op', () async {
    await initializeBackgroundService();
  });
}
