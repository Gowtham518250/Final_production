import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'api_client.dart';
import 'local_storage_service.dart';
import 'secure_token_storage.dart';
import 'session_management.dart';
import 'shop_profile_persistence_service.dart';
import 'user_data_clear_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result of a Google Sign-In attempt.
class GoogleSignInResult {
  final bool success;
  final bool isFallback; // Legacy field retained for callers; backend failures are never treated as success.
  final bool isNewUser;
  final String? token;
  final String? email;
  final String? name;
  final String? photoUrl;
  final String? error;

  const GoogleSignInResult({
    required this.success,
    this.isFallback = false,
    this.isNewUser = false,
    this.token,
    this.email,
    this.name,
    this.photoUrl,
    this.error,
  });
}

class GoogleAuthService {
  // Load Google OAuth Client ID from environment - never hardcode
  static const String _googleClientId = String.fromEnvironment(
    'GOOGLE_OAUTH_CLIENT_ID',
    defaultValue: '', // If empty, fallback sign-in will be used
  );

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId: kIsWeb && _googleClientId.isNotEmpty ? _googleClientId : null,
    serverClientId: !kIsWeb && _googleClientId.isNotEmpty
        ? _googleClientId
        : null,
  );

  /// Sign in with Google and attempt backend authentication.
  /// Returns a [GoogleSignInResult] describing the outcome.
  static Future<GoogleSignInResult> signIn() async {
    try {
      // 1. Trigger native Google account picker
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        return const GoogleSignInResult(
          success: false,
          error: 'Sign-in was cancelled',
        );
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      // /auth/google verifies identity through Google's UserInfo endpoint, which
      // requires an OAuth access token (not the OpenID ID token).
      final String? googleAccessToken = auth.accessToken;
      if (googleAccessToken == null || googleAccessToken.trim().isEmpty) {
        return const GoogleSignInResult(
          success: false,
          error: 'Google did not provide an access token. Please try again.',
        );
      }
      final String email = account.email;
      final String name = account.displayName ?? '';
      final String? photoUrl = account.photoUrl;

      if (kDebugMode) {
        debugPrint('✅ Google Sign-In: $email');
      }

      
      // 2. Authenticate against the backend using Google's access token.
      // The backend matches the verified Google email to the existing database
      // user, or creates an owner account only when that email is not present.
      try {
        final response = await ApiClient.postJson('/auth/google', {
          'google_token': googleAccessToken,
          // These fields are hints only; the backend trusts Google's verified
          // UserInfo response, never the email/name supplied by this client.
          'email': email,
          'name': name,
          'photo_url': photoUrl ?? '',
        }).timeout(const Duration(seconds: 15));

        if (response.statusCode != 200) {
          String message =
              'Google sign-in could not be completed. Please try again.';
          try {
            final errorData = json.decode(response.body);
            if (errorData is Map && errorData['detail'] != null) {
              message = errorData['detail'].toString();
            }
          } catch (_) {}
          if (kDebugMode) {
            debugPrint(
              'Backend /auth/google rejected sign-in: ' +
                  response.statusCode.toString(),
            );
          }
          return GoogleSignInResult(success: false, error: message);
        }

        final decoded = json.decode(response.body);
        if (decoded is! Map) {
          return const GoogleSignInResult(
            success: false,
            error: 'Retail Mind returned an invalid sign-in response.',
          );
        }
        final data = Map<String, dynamic>.from(decoded);
        final token = (data['token'] ?? data['access_token'])?.toString();
        if (token == null || token.isEmpty) {
          return const GoogleSignInResult(
            success: false,
            error: 'Retail Mind did not return a login session. Please try again.',
          );
        }

        final extractedUserId =
            int.tryParse(data['user_id']?.toString() ?? '') ??
            ApiClient.extractUserIdFromJwtToken(token, responseData: data);
        if (extractedUserId <= 0) {
          return const GoogleSignInResult(
            success: false,
            error: 'Retail Mind returned an invalid account identity.',
          );
        }

        final databaseName =
            (data['username'] ?? data['user_name'] ?? name).toString().trim();
        final databaseEmail =
            (data['email'] ?? email).toString().trim().toLowerCase();
        final accountRole =
            (data['role'] ?? data['user_type'] ?? 'OWNER').toString();
        final normalizedAccountRole = accountRole.trim().toUpperCase();

        // Preserve same-account offline data and queued operations. Only clear
        // legacy session/cache state when the authenticated database identity
        // differs from the previous session (or cannot be established).
        final prefs = await SharedPreferences.getInstance();
        final previousUserId = int.tryParse(
              (prefs.get('user_id') ?? prefs.get('userId') ?? '').toString(),
            ) ??
            0;
        final previousRole = (
          prefs.getString('user_role') ??
          prefs.getString('user_type') ??
          prefs.getString('role') ??
          ''
        ).trim().toUpperCase();
        final sameAccount =
            previousUserId > 0 &&
            previousUserId == extractedUserId &&
            (previousRole.isEmpty || previousRole == normalizedAccountRole);

        if (!sameAccount) {
          if (kDebugMode) {
            debugPrint('Switching Google sign-in to a different account; resetting session cache.');
          }
          await UserDataClearService.clearAllUserData();
          await LocalStorageService.clearOrphanSalesBoxes();
        } else if (kDebugMode) {
          debugPrint('Same Google account re-authenticated; preserving user-scoped local data.');
        }

        if (kDebugMode) {
          debugPrint('Google identity authenticated by Retail Mind');
          debugPrint('User ID: ' + extractedUserId.toString());
        }

        final deviceId = await SessionManagementService.getDeviceId();
        await SessionManagementService.initializeSession(
          userId: extractedUserId,
          accessToken: token,
          refreshToken: data['refresh_token']?.toString(),
          userName: databaseName.isNotEmpty ? databaseName : email,
          userEmail: databaseEmail,
          role: accountRole,
          deviceId: deviceId,
        );

        await prefs.setString(
          'user_name',
          databaseName.isNotEmpty ? databaseName : email,
        );
        await prefs.setString('user_email', databaseEmail);
        await prefs.setString('email', databaseEmail);
        await prefs.setString('user_role', accountRole);
        await prefs.setString('user_type', accountRole);

        // Hydrate the existing database shop profile so the app immediately
        // shows saved shop details after Google sign-in.
        final rawProfile = data['shop_profile'];
        if (rawProfile is Map) {
          final profile = Map<String, dynamic>.from(rawProfile);
          await ShopProfilePersistenceService.saveProfileLocally(profile);
          await ShopProfilePersistenceService.applyProfileToPrefs(profile);
          final shopName = profile['shop_name']?.toString();
          if (shopName != null && shopName.trim().isNotEmpty) {
            await prefs.setString('shop_name', shopName);
          }
        } else if (data['shop_name'] != null) {
          await prefs.setString('shop_name', data['shop_name'].toString());
        }

        return GoogleSignInResult(
          success: true,
          isNewUser: data['is_new_user'] == true,
          token: token,
          email: databaseEmail,
          name: databaseName.isNotEmpty ? databaseName : name,
          photoUrl: photoUrl,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Backend Google authentication failed: ' + e.runtimeType.toString());
        }
        return const GoogleSignInResult(
          success: false,
          error: 'Unable to connect Google sign-in to Retail Mind. Check your connection and try again.',
        );
      }
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('❌ Google Sign-In error: $e');
      return GoogleSignInResult(
        success: false,
        error: 'Google Sign-In failed. Please try again.',
      );
    }
  }

  /// Sign out from Google
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  /// Check if a user is currently signed in via Google
  static Future<bool> isSignedIn() async {
    return _googleSignIn.isSignedIn();
  }
}
