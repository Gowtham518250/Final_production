import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/api_client.dart';

void main() {
  group('owner auth contract', () {
    test('uses email for email-shaped identifiers', () {
      final payload = ApiClient.buildOwnerLoginPayload(
        'owner@example.com',
        'secret',
      );

      expect(payload, {'email': 'owner@example.com', 'password': 'secret'});
    });

    test('uses username for a non-email identifier', () {
      final payload = ApiClient.buildOwnerLoginPayload('Gowtham', 'secret');

      expect(payload, {'username': 'Gowtham', 'password': 'secret'});
    });

    test('compatibility fallback uses the same supported request shape', () {
      final emailPayload = ApiClient.buildOwnerLoginFallbackPayload(
        'owner@example.com',
        'secret',
      );
      final usernamePayload = ApiClient.buildOwnerLoginFallbackPayload(
        'Gowtham',
        'secret',
      );

      expect(emailPayload, {
        'email': 'owner@example.com',
        'password': 'secret',
      });
      expect(usernamePayload, {'username': 'Gowtham', 'password': 'secret'});
    });

    test('extracts the user id from the JWT sub claim', () {
      final payload = {'sub': '42'};
      final encoded = base64UrlEncode(utf8.encode(jsonEncode(payload)));
      final token = 'header.$encoded.signature';

      expect(ApiClient.extractUserIdFromJwtToken(token), 42);
    });
  });
}
