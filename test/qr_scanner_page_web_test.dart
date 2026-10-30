import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/qr_scanner_page_stub.dart';

void main() {
  testWidgets('web QR scanner fallback explains the supported alternatives',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: QrScannerPage()),
    );
    await tester.pump();

    expect(find.text('Scanner Unavailable'), findsOneWidget);
    expect(
      find.textContaining('QR scanner is not available on web'),
      findsOneWidget,
    );
    expect(find.textContaining('Show QR'), findsOneWidget);
  });
}
