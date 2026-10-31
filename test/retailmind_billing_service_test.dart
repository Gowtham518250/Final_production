import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../lib/features/billing/retailmind_billing_service.dart';

void main() {
  group('RetailMindBillingException', () {
    test('extracts code and message from structured FastAPI detail', () {
      final error = RetailMindBillingException.fromResponse(
        http.Response(
          jsonEncode({
            'detail': {
              'code': 'ACTIVE_SUBSCRIPTION_EXISTS',
              'message': 'A paid plan is already active.',
            },
          }),
          409,
        ),
        fallback: 'Fallback message',
      );

      expect(error.statusCode, 409);
      expect(error.code, 'ACTIVE_SUBSCRIPTION_EXISTS');
      expect(error.message, 'A paid plan is already active.');
    });

    test('extracts a plain string FastAPI detail', () {
      final error = RetailMindBillingException.fromResponse(
        http.Response(jsonEncode({'detail': 'Try again later.'}), 503),
        fallback: 'Fallback message',
      );

      expect(error.code, isEmpty);
      expect(error.message, 'Try again later.');
    });

    test('uses fallback for non-JSON proxy responses', () {
      final error = RetailMindBillingException.fromResponse(
        http.Response('Service unavailable', 503),
        fallback: 'Billing service is unavailable (503).',
      );

      expect(error.statusCode, 503);
      expect(error.message, 'Billing service is unavailable (503).');
    });

    test('builds the authenticated feature-access endpoint path', () {
      expect(
        RetailMindBillingService.featureAccessPath('online_orders'),
        '/api/billing/feature-access/online_orders',
      );
    });
  });
}
