import 'package:flutter/foundation.dart';

Future<void> initializeBackgroundService() async {
  debugPrint('⚠️ Background service not supported on web');
}

Future<void> syncExpectedPaymentBill(double? amount) async {}

Future<void> syncRecordedBillPayment(double amount) async {}

Future<void> restartBackgroundPaymentDetection() async {}

Future<(DateTime, DateTime)?> takeServiceOutageNotice() async => null;

Future<void> refreshPaymentDetectionDedupState() async {}
