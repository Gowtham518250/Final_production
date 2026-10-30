import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/payment_background_service_web.dart';

void main() {
  test('web payment background APIs remain safe no-ops', () async {
    await initializeBackgroundService();
    await syncExpectedPaymentBill(500);
    await syncExpectedPaymentBill(null);
    await syncRecordedBillPayment(500);
    await restartBackgroundPaymentDetection();
    await refreshPaymentDetectionDedupState();

    expect(await takeServiceOutageNotice(), isNull);
  });
}
