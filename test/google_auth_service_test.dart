import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/google_auth_service.dart';

void main() {
  group('GoogleAuthService platform support', () {
    test('supports Google Sign-In on web and app platforms', () {
      expect(
        GoogleAuthService.isGoogleSignInSupported(
          isWeb: true,
          isAndroid: false,
          isIOS: false,
        ),
        isTrue,
      );

      expect(
        GoogleAuthService.isGoogleSignInSupported(
          isWeb: false,
          isAndroid: true,
          isIOS: false,
        ),
        isTrue,
      );

      expect(
        GoogleAuthService.isGoogleSignInSupported(
          isWeb: false,
          isAndroid: false,
          isIOS: true,
        ),
        isTrue,
      );
    });

    test('returns backend error details instead of a generic message', () {
      final text = GoogleAuthService.formatGoogleSignInError(
        statusCode: 401,
        responseBody: '{"detail":"Invalid Google token"}',
      );

      expect(text, contains('401'));
      expect(text, contains('Invalid Google token'));
    });
  });
}
