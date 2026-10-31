import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/app_localizations.dart';
import 'package:retail_mind/screens/owner/online_store_hub_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _stats = OnlineHubStats(
  pending: 3,
  todayOrders: 7,
  todayPaid: 5,
  todayRevenue: 4250,
  totalOrders: 1280,
  totalPaid: 1100,
  totalRevenue: 1234567,
);

Widget _host(Widget child) => MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

OnlineStoreHubView _view({
  OnlineStoreStatus status = OnlineStoreStatus.live,
  OnlineHubStats? stats = _stats,
  bool loading = false,
  bool loadFailed = false,
  VoidCallback? onOrders,
  VoidCallback? onSetup,
  Future<void> Function()? onRefresh,
}) =>
    OnlineStoreHubView(
      status: status,
      stats: stats,
      loading: loading,
      loadFailed: loadFailed,
      onRefresh: onRefresh ?? () async {},
      onOpenOrders: onOrders ?? () {},
      onOpenInventory: () {},
      onOpenSetup: onSetup ?? () {},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('rupees use Indian digit grouping', () {
    expect(formatHubRupees(0), '₹0');
    expect(formatHubRupees(4250), '₹4,250');
    expect(formatHubRupees(1234567), '₹12,34,567');
  });

  testWidgets('shows live status, pending orders and revenue', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var opened = 0;
    await tester.pumpWidget(_host(_view(onOrders: () => opened++)));
    await tester.pumpAndSettle();
    expect(find.text('Your online store is LIVE'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    expect(find.text('Waiting orders'), findsOneWidget);
    expect(find.text('₹4,250'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('View new orders'), 240);
    await tester.tap(find.text('View new orders'));
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline store offers one-tap setup', (tester) async {
    var setup = 0;
    await tester.pumpWidget(_host(_view(
      status: OnlineStoreStatus.offline,
      onSetup: () => setup++,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Your online store is OFFLINE'), findsOneWidget);
    await tester.tap(find.text('Set up online store'));
    expect(setup, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not present failed analytics as zero revenue', (tester) async {
    await tester.pumpWidget(_host(_view(
      status: OnlineStoreStatus.unknown,
      stats: null,
      loading: false,
      loadFailed: true,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Online store status unavailable'), findsOneWidget);
    expect(find.text('Some information could not be refreshed. Pull down to try again.'), findsOneWidget);
    expect(find.text('₹0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inventory action opens the supplied callback', (tester) async {
    var opened = 0;
    await tester.pumpWidget(_host(OnlineStoreHubView(
      status: OnlineStoreStatus.live,
      stats: _stats,
      loading: false,
      loadFailed: false,
      onRefresh: () async {},
      onOpenOrders: () {},
      onOpenInventory: () => opened++,
      onOpenSetup: () {},
    )));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Manage inventory'), 240);
    await tester.tap(find.text('Manage inventory'));
    expect(opened, 1);
  });
}
