import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:retail_mind/secure_token_storage.dart';

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
    SecureTokenStorage.resetForTesting();
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
    'owner tokens remain isolated when accounts switch on one device',
    () async {
      await SecureTokenStorage.saveUserId(41);
      await SecureTokenStorage.saveRole(SessionRole.owner);
      await SecureTokenStorage.saveToken('owner-token-41');

      await SecureTokenStorage.saveUserId(72);
      await SecureTokenStorage.saveRole(SessionRole.owner);
      await SecureTokenStorage.saveToken('owner-token-72');
      expect(await SecureTokenStorage.getToken(), 'owner-token-72');

      await SecureTokenStorage.saveUserId(41);
      expect(await SecureTokenStorage.getToken(), 'owner-token-41');
    },
  );

  test(
    'secure token records contain ciphertext rather than the raw token',
    () async {
      await SecureTokenStorage.saveUserId(41);
      await SecureTokenStorage.saveRole(SessionRole.owner);
      await SecureTokenStorage.saveToken('private-owner-token');

      final stored = _secureValues['auth_token_enc_41'];
      expect(stored, isNotNull);
      expect(stored, isNot(contains('private-owner-token')));
      expect(stored, startsWith('v2.'));
    },
  );

  test(
    'legacy unscoped owner tokens are not used when the active user key is missing',
    () async {
      await SecureTokenStorage.saveUserId(41);
      await SecureTokenStorage.saveRole(SessionRole.owner);
      await SecureTokenStorage.saveToken('owner-token-41');

      final oldSharedToken = _secureValues['auth_token_enc_41'];
      expect(oldSharedToken, isNotNull);
      _secureValues['auth_token_enc'] = oldSharedToken!;
      _secureValues.remove('auth_token_enc_72');
      await SharedPreferences.getInstance().then(
        (prefs) => prefs.setString('auth_token', 'legacy-owner-token-41'),
      );

      await SecureTokenStorage.saveUserId(72);
      expect(await SecureTokenStorage.getToken(), isNull);
    },
  );

  test('owner session stays valid after a leftover SharedPreferences token is present', () async {
    await SecureTokenStorage.saveUserId(41);
    await SecureTokenStorage.saveRole(SessionRole.owner);
    await SecureTokenStorage.saveToken('owner-secure-token');
    await SharedPreferences.getInstance().then(
      (prefs) => prefs.setString('auth_token', 'stale-prefs-token'),
    );

    expect(await SecureTokenStorage.isSessionValid(), isTrue);
    expect(await SecureTokenStorage.getToken(), 'owner-secure-token');
  });

  test('customer and owner credentials remain role-isolated for matching IDs', () async {
    await SecureTokenStorage.saveUserId(41);
    await SecureTokenStorage.saveRole(SessionRole.owner);
    await SecureTokenStorage.saveToken('owner-token-41');

    await SecureTokenStorage.saveRole(SessionRole.customer);
    await SecureTokenStorage.saveCustomerToken('customer-token-41');
    expect(await SecureTokenStorage.getToken(), 'customer-token-41');

    await SecureTokenStorage.saveRole(SessionRole.owner);
    expect(await SecureTokenStorage.getToken(), 'owner-token-41');
  });

  test('tampered token payload is rejected and removed', () async {
    await SecureTokenStorage.saveUserId(41);
    await SecureTokenStorage.saveRole(SessionRole.owner);
    await SecureTokenStorage.saveToken('owner-token-41');
    final slot = 'auth_token_enc_41';
    final record = _secureValues[slot]!;
    _secureValues[slot] = '${record.substring(0, record.length - 1)}x';

    await expectLater(
      SecureTokenStorage.getToken(),
      throwsA(isA<SecureStorageException>()),
    );
    expect(_secureValues.containsKey(slot), isFalse);
  });

  test('copying an encrypted token into another user slot fails authentication', () async {
    await SecureTokenStorage.saveUserId(41);
    await SecureTokenStorage.saveRole(SessionRole.owner);
    await SecureTokenStorage.saveToken('owner-token-41');
    _secureValues['auth_token_enc_72'] = _secureValues['auth_token_enc_41']!;

    await SecureTokenStorage.saveUserId(72);
    await expectLater(
      SecureTokenStorage.getToken(),
      throwsA(isA<SecureStorageException>()),
    );
    expect(_secureValues.containsKey('auth_token_enc_72'), isFalse);
    await SecureTokenStorage.saveUserId(41);
    expect(await SecureTokenStorage.getToken(), 'owner-token-41');
  });

  test('key rotation keeps every users scoped token readable', () async {
    await SecureTokenStorage.saveUserId(41);
    await SecureTokenStorage.saveRole(SessionRole.owner);
    await SecureTokenStorage.saveToken('owner-token-41');

    await SecureTokenStorage.saveUserId(72);
    await SecureTokenStorage.saveRole(SessionRole.customer);
    await SecureTokenStorage.saveCustomerToken('customer-token-72');

    await SecureTokenStorage.rotateKey();
    expect(await SecureTokenStorage.getToken(), 'customer-token-72');

    await SecureTokenStorage.saveUserId(41);
    await SecureTokenStorage.saveRole(SessionRole.owner);
    expect(await SecureTokenStorage.getToken(), 'owner-token-41');
  });
}
