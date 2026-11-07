import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:retail_mind/app_endpoints.dart';
import 'package:retail_mind/online_store_qr_page.dart';
import 'package:retail_mind/widgets/shop_logo_mark.dart';

void main() {
  testWidgets('shows the shop link QR, logo fallback, and actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var copied = 0;
    var printed = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: OnlineStoreQrPage(
          shopId: 42,
          shopName: 'Corner Shop',
          logoBytes: null,
          onCopyLink: () => copied++,
          onPrint: () => printed++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.byType(ShopLogoMark), findsOneWidget);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.text(AppEndpoints.customerShopUrl(42)), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Copy link'));
    await tester.tap(find.text('Print QR'));
    expect(copied, 1);
    expect(printed, 1);
  });
}
