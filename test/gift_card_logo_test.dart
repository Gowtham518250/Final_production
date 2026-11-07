import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/gift_card_page.dart';
import 'package:retail_mind/scoped_shared_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads the active user scoped shop logo', () async {
    await ScopedSharedPreferences.setCurrentUserId(42);
    final logo = <int>[1, 2, 3, 4];
    await ScopedSharedPreferences.setString('logo_base64', base64Encode(logo));

    expect(await GiftCardPage.loadPersistedLogo(), logo);
  });

  test(
    'falls back to a legacy unscoped logo when no scoped logo exists',
    () async {
      SharedPreferences.setMockInitialValues({
        'current_scoped_user_id': 42,
        'logo_base64': base64Encode(<int>[5, 6, 7]),
      });

      expect(await GiftCardPage.loadPersistedLogo(), <int>[5, 6, 7]);
    },
  );
}
