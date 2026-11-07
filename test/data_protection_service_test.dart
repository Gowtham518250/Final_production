import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:retail_mind/data_protection_service.dart';

final Map<String, String> _secureValues = <String, String>{};

void _installSecureStorageMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall call) async {
          final args = call.arguments as Map<dynamic, dynamic>;
          switch (call.method) {
            case 'read':
              return _secureValues[args['key'] as String];
            case 'write':
              _secureValues[args['key'] as String] = args['value'] as String;
              return null;
            case 'delete':
              _secureValues.remove(args['key'] as String);
              return null;
            case 'deleteAll':
              _secureValues.clear();
              return null;
            case 'readAll':
              return Map<String, String>.from(_secureValues);
            case 'containsKey':
              return _secureValues.containsKey(args['key'] as String);
            default:
              return null;
          }
        },
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _secureValues.clear();
    _installSecureStorageMock();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });

  test(
    'sync without an auth token fails instead of reporting success',
    () async {
      await expectLater(
        DataProtectionService.syncAllData(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Sign in'),
          ),
        ),
      );
    },
  );

  test('sync rejects a zero retry count', () async {
    await expectLater(
      DataProtectionService.syncAllData(maxRetries: 0),
      throwsArgumentError,
    );
  });
}
