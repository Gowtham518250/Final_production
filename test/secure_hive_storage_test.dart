import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:retail_mind/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'retail_mind_secure_hive_test_',
    );
    final hivePath = Directory('${hiveDirectory.path}/hive');
    await hivePath.create(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall call) async {
            if (call.method == 'getApplicationDocumentsDirectory') {
              return hiveDirectory.path;
            }
            return null;
          },
        );
    Hive.init(hivePath.path);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDownAll(() async {
    await Hive.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await hiveDirectory.delete(recursive: true);
  });

  test(
    'unauthenticated reads cannot access a legacy unscoped expenses box',
    () async {
      final legacyBox = await Hive.openBox('expenses_v2');
      await legacyBox.put('all_expenses', <Map<String, dynamic>>[
        <String, dynamic>{'id': 'another-account', 'amount': 99},
      ]);

      expect(await LocalStorageService.loadExpenses(), isEmpty);
      expect(legacyBox.get('all_expenses'), hasLength(1));
    },
  );

  test(
    'expense writes without an account do not create an unscoped record',
    () async {
      final legacyBox = await Hive.openBox('expenses_v2');
      await legacyBox.delete('all_expenses');

      await LocalStorageService.saveExpenses(<Map<String, dynamic>>[
        <String, dynamic>{'id': 'unauthenticated', 'amount': 12},
      ]);

      expect(legacyBox.get('all_expenses'), isNull);
      expect(await LocalStorageService.loadExpenses(), isEmpty);
    },
  );

  test(
    'schema migration retains legacy sales whose account owner is unknown',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', 72);
      final legacyBox = await Hive.openBox('sales_v2');
      await legacyBox.put('all_sales', <Map<String, dynamic>>[
        <String, dynamic>{'id': 'sale-without-owner'},
      ]);
      await legacyBox.close();

      await LocalStorageService.validateAndMigrateSchema();

      expect(await Hive.boxExists('sales_v2_72'), isFalse);
      expect(await Hive.boxExists('sales_v2'), isTrue);
      final retainedBox = await Hive.openBox('sales_v2');
      expect(retainedBox.get('all_sales'), hasLength(1));
    },
  );
}
