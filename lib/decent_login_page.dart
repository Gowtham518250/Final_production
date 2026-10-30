import 'live_translated_text.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'app_localizations.dart';
import 'visual_widgets.dart';
import 'language_provider.dart';
import 'guided_voice_service.dart';
import 'guided_field_controls.dart';
import 'sync_service.dart';
import 'sync_queue_manager.dart';
import 'local_storage_service.dart';
import 'user_data_clear_service.dart';
import 'role_selection_page.dart';
import 'secure_token_storage.dart';
import 'session_management.dart';
import 'scoped_shared_preferences.dart';
import 'google_auth_service.dart';
import 'online_orders_listener.dart';
import 'inventory_sync_service.dart';
import 'sales_restore_service.dart';
import 'shop_profile_persistence_service.dart';
import 'worker_verification_policy.dart';

// ─── Design tokens ───────────────────────────────────────────────────────────
class _C {
  static const navy = Color(0xFF0F2447);
  static const navyMid = Color(0xFF1B3A6B);
  static const navyBtn = Color(0xFF1E3A6E);
  static const teal = Color(0xFF2DD4BF);
  static const indigo = Color(0xFF4F46E5);
  static const lavender = Color(0xFFEEF0FF);
  static const fieldBg = Color(0xFFF7F9FE);
  static const fieldBorder = Color(0xFFE6EAF5);
  static const textDark = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const iconMuted = Color(0xFF94A3B8);
  static const pageBg = Color(0xFFE9EFFA);
  static const green = Color(0xFF16A34A);
}

class DecentLoginPage extends StatefulWidget {
  const DecentLoginPage({super.key});

  @override
  State<DecentLoginPage> createState() => _DecentLoginPageState();
}

class _DecentLoginPageState extends State<DecentLoginPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool _isGoogleLoading = false;
  bool isPasswordVisible = false;
  String errorMessage = '';

  late AnimationController _cardController;
  late Animation<double> _cardSlide;

  @override
  void initState() {
    super.initState();
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _cardSlide = CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutCubic,
    );
    _cardController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        GuidedVoiceService.instance.speakStepIfGuided(
          'login',
          context.read<LanguageProvider>().locale.languageCode,
        ),
      );
    });
  }

  /// Owners in shops without active workers do not need the extra
  /// Owner-vs-Staff gate. Only a server-confirmed empty roster skips it;
  /// unknown/offline rosters keep the verification flow enabled.
  Future<void> _routeAfterOwnerLogin({
    required int userId,
    required String email,
  }) async {
    final hasActiveWorkers =
        await WorkerVerificationPolicy.hasActiveWorkersForShop(userId: userId);
    if (!mounted) return;

    if (hasActiveWorkers == false) {
      // Prevent a stale Staff Mode preference from surviving after the
      // authoritative roster confirms that the shop no longer has staff.
      await ScopedSharedPreferences.setBool('is_staff_mode', false);
      await ScopedSharedPreferences.remove('active_staff_name');
      await ScopedSharedPreferences.remove('active_staff_worker_id');

      // Preserve the existing shop-setup requirement; bypass only the
      // extra Owner-vs-Staff verification screen.
      final prefs = await SharedPreferences.getInstance();
      final shopDetailsRequired =
          prefs.getBool('shop_details_required_$userId') ?? false;
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        shopDetailsRequired ? '/shop-details' : '/dashboard',
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (ctx) => RoleSelectionPage(email: email),
      ),
    );
  }

  // ─── Google Sign-In (logic unchanged) ──────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);

    try {
      final result = await GoogleAuthService.signIn();

      if (!mounted) return;

      if (result.success) {
        if (result.token == null || result.token!.isEmpty) {
          final prefs = await SharedPreferences.getInstance();
          final hadOwner =
              (prefs.getInt('user_id') ?? prefs.getInt('userId') ?? 0) > 0;
          if (hadOwner) {
            await UserDataClearService.clearAllUserData();
            await SecureTokenStorage.clearAll();
            await LocalStorageService.clearOrphanSalesBoxes();
          } else {
            await SecureTokenStorage.clearAll();
          }
        }

        if (result.isFallback) {
          setState(() {
            errorMessage =
                'Google verified your account, but automatic account setup is unavailable. Please try again later or contact support.';
          });
          return;
        }

        if (result.token != null && result.token!.isNotEmpty) {
          await context.read<LanguageProvider>().activateAccountLanguage();
        }
        if (!mounted) return;

        if (result.isNewUser) {
          final prefs = await SharedPreferences.getInstance();
          final userId = prefs.getInt('user_id') ?? prefs.getInt('userId') ?? 0;
          if (userId > 0) {
            await SessionManagementService.markIdentityVerified(
              userId: userId,
              role: 'OWNER',
            );
          }
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed('/dashboard');
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        final userId =
            prefs.getInt('user_id') ?? prefs.getInt('userId') ?? 0;
        await _routeAfterOwnerLogin(
          userId: userId,
          email: result.email ?? prefs.getString('user_email') ?? '',
        );
        return;
      }

      if (mounted) {
        setState(() {
          errorMessage = result.error ?? 'Google Sign-In failed.';
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Google Sign-In exception: $e');
      if (mounted) {
        setState(() {
          errorMessage =
              'Google Sign-In failed: ${e.toString().replaceAll('Exception:', '').trim()}';
        });
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  void dispose() {
    unawaited(GuidedVoiceService.instance.cancelForRouteChange());
    _cardController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ─── Email / password login (logic unchanged) ──────────────────────────────
  Future<void> loginUser() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      setState(() => errorMessage = 'Please fill in all fields');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final loginIdentifier = emailController.text.trim();
      final loginPassword = passwordController.text.trim();
      final primaryBody = ApiClient.buildOwnerLoginPayload(
        loginIdentifier,
        loginPassword,
      );

      var response = await ApiClient.postJson(
        ApiClient.loginEndpoint,
        primaryBody,
      ).timeout(const Duration(seconds: 20));

      if ((response.statusCode == 400 || response.statusCode == 422) &&
          loginIdentifier.contains('@')) {
        response = await ApiClient.postJson(
          ApiClient.loginEndpoint,
          ApiClient.buildOwnerLoginFallbackPayload(
            loginIdentifier,
            loginPassword,
          ),
        ).timeout(const Duration(seconds: 20));
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final accessToken = data['access_token']?.toString() ?? '';
        final refreshToken = data['refresh_token']?.toString() ?? '';
        final tokenType = data['token_type']?.toString() ?? 'bearer';
        final role = data['role']?.toString() ?? 'OWNER';

        if (accessToken.isEmpty) {
          setState(() {
            errorMessage = 'Login failed: No access token received';
          });
          return;
        }

        final userId = ApiClient.extractUserIdFromJwtToken(
          accessToken,
          responseData: data,
        );

        final existingToken = await SecureTokenStorage.getToken();
        if ((existingToken ?? '').isNotEmpty && existingToken != accessToken) {
          final existingPrefs = await SharedPreferences.getInstance();
          final rawPreviousUserId =
              existingPrefs.get('user_id') ?? existingPrefs.get('userId');
          var previousUserId =
              int.tryParse(rawPreviousUserId?.toString() ?? '') ?? 0;
          var previousRole =
              (existingPrefs.getString('user_role') ??
                      existingPrefs.getString('user_type') ??
                      existingPrefs.getString('role') ??
                      '')
                  .trim()
                  .toUpperCase();

          try {
            final parts = existingToken!.split('.');
            if (parts.length == 3) {
              final normalized = base64Url.normalize(parts[1]);
              final oldClaims = json.decode(
                utf8.decode(base64Url.decode(normalized)),
              );
              if (oldClaims is Map) {
                previousUserId = previousUserId > 0
                    ? previousUserId
                    : int.tryParse(oldClaims['sub']?.toString() ?? '') ?? 0;
                if (previousRole.isEmpty) {
                  previousRole =
                      (oldClaims['role'] ?? oldClaims['user_type'] ?? '')
                          .toString()
                          .trim()
                          .toUpperCase();
                }
              }
            }
          } catch (_) {}

          final newRole = role.trim().toUpperCase();
          final identityKnown = previousUserId > 0;
          final sameUser = identityKnown && previousUserId == userId;
          final sameRole =
              previousRole.isEmpty ||
              newRole.isEmpty ||
              previousRole == newRole;
          final identityChanged = !sameUser || !sameRole;

          if (identityChanged) {
            if (kDebugMode) {
              debugPrint(
                '🧹 Account identity changed; clearing legacy unscoped local cache '
                '(previous user=$previousUserId, new user=$userId).',
              );
            }
            try {
              await UserDataClearService.clearAllUserData().timeout(
                const Duration(seconds: 8),
              );
            } on TimeoutException {
              if (mounted) {
                setState(() {
                  errorMessage =
                      'Local session cleanup timed out. Please retry login.';
                });
              }
              if (kDebugMode) {
                debugPrint('⏱️ Login aborted: local session cleanup timed out');
              }
              return;
            }
          } else if (kDebugMode) {
            debugPrint(
              '✅ Same account re-authenticated; preserving local sales and pending sync queue.',
            );
          }
        }

        final deviceId = await SessionManagementService.getDeviceId();
        try {
          await SessionManagementService.initializeSession(
            userId: userId,
            accessToken: accessToken,
            refreshToken: refreshToken.isNotEmpty ? refreshToken : null,
            userName:
                data['username']?.toString() ??
                data['user_name']?.toString() ??
                '',
            userEmail: data['email']?.toString() ?? emailController.text.trim(),
            role: role,
            deviceId: deviceId,
          );
        } catch (sessionError) {
          if (kDebugMode) {
            debugPrint(
              '❌ Login session persistence failed: ${sessionError.runtimeType}',
            );
          }
          if (mounted) {
            setState(() {
              errorMessage =
                  'Login succeeded, but this device could not save the session. Please retry.';
            });
          }
          return;
        }

        await context.read<LanguageProvider>().activateAccountLanguage();

        final loginShopProfile = data['shop_profile'];
        if (loginShopProfile is Map) {
          final normalizedProfile = Map<String, dynamic>.from(loginShopProfile);
          await ShopProfilePersistenceService.saveProfileLocally(
            normalizedProfile,
          );
          await ShopProfilePersistenceService.applyProfileToPrefs(
            normalizedProfile,
          );
        }
        unawaited(ShopProfilePersistenceService.restoreProfile());

        final prefs = await SharedPreferences.getInstance();
        if (data['shop_name'] != null) {
          await prefs.setString('shop_name', data['shop_name'].toString());
          await ScopedSharedPreferences.setString(
            'shop_name',
            data['shop_name'].toString(),
          );
        }
        if (data['location'] != null) {
          await prefs.setString('location', data['location'].toString());
          await ScopedSharedPreferences.setString(
            'location',
            data['location'].toString(),
          );
        }
        if (data['shop_type'] != null) {
          await prefs.setString('shop_type', data['shop_type'].toString());
          await ScopedSharedPreferences.setString(
            'shop_type',
            data['shop_type'].toString(),
          );
        }

        if (kDebugMode) {
          debugPrint('✅ Login successful');
          debugPrint('   Token Type: $tokenType');
          debugPrint('   Role: $role');
          debugPrint('   User ID: $userId');
        }

        unawaited(_runPostLoginSyncInBackground(userId));
        if (!mounted) return;
        final normalizedRole = role.trim().toUpperCase();
        if (normalizedRole == 'CUSTOMER') {
          Navigator.of(context).pushReplacementNamed('/customer-verification');
        } else if (normalizedRole == 'OWNER') {
          await _routeAfterOwnerLogin(
            userId: userId,
            email: emailController.text.trim(),
          );
        } else {
          // Worker/unknown roles must not use the owner-with-no-workers bypass.
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (ctx) =>
                  RoleSelectionPage(email: emailController.text.trim()),
            ),
          );
        }
      } else {
        setState(() {
          errorMessage = _extractErrorMessage(response);
        });

        if (kDebugMode) {
          debugPrint(
            '❌ Login error: $errorMessage (Status: ${response.statusCode})',
          );
        }
      }
    } catch (e) {
      setState(() {
        errorMessage =
            'Connection error: ${e.toString().replaceAll('Exception:', '').trim()}';
      });
      if (kDebugMode) debugPrint('❌ Login exception: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _extractErrorMessage(http.Response response) {
    try {
      final data = json.decode(response.body);
      if (data is Map) {
        return data['detail']?.toString() ??
            data['message']?.toString() ??
            data['error']?.toString() ??
            'Login failed (Status: ${response.statusCode})';
      }
      return 'Login failed (Status: ${response.statusCode})';
    } catch (e) {
      if (response.body.isNotEmpty && response.body.length < 200) {
        return response.body;
      }
      return 'Connection error: ${e.toString().replaceAll('Exception:', '').trim()}';
    }
  }

  Future<void> _runPostLoginSyncInBackground(int userId) async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 [Background] Starting post-login sync flow...');
      }

      try {
        final profileResult =
            await ShopProfilePersistenceService.restoreProfile();
        if (!profileResult['success']) {
          final localProfile =
              await ShopProfilePersistenceService.loadProfileLocally();
          if (localProfile != null) {
            await ShopProfilePersistenceService.applyProfileToPrefs(
              localProfile,
            );
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ [Background] Shop profile restore error: $e');
        }
      }

      try {
        await SyncService.processQueueSafe();
        await SyncService.downloadUserDataSafe();
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ [Background] Sync queue error: $e');
      }

      try {
        final alreadyRestored =
            await SalesRestoreService.wasRestorationCompleted();
        if (!alreadyRestored) {
          final restorationResult =
              await SalesRestoreService.completeRestoration();
          if (restorationResult['success']) {
            await SalesRestoreService.markRestorationComplete();
          }
        } else if (kDebugMode) {
          debugPrint(
            'ℹ️ [Background] Skipping sales restore — already completed for this user',
          );
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ [Background] Sales restore error: $e');
      }

      try {
        final hasPendingMutation =
            await SyncQueueManager.hasAnyPendingAction(const [
              'save_sale',
              'sync_sale',
              'create_local_product',
              'update_local_product',
              'decrease_stock',
            ]);
        if (hasPendingMutation) {
          if (kDebugMode) {
            debugPrint(
              '⏭️ [Background] Inventory refresh skipped: pending mutation awaiting server ACK',
            );
          }
        } else {
          await InventorySyncService.refreshAllInventory();
          await InventorySyncService.updateLastSyncTimestamp();
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ [Background] Inventory refresh error: $e');
        }
      }

      try {
        await OnlineOrdersListener.instance.restartForCurrentUser();
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ [Background] Listener start error: $e');
      }

      if (kDebugMode) debugPrint('✅ [Background] Post-login sync complete');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [Background] Post-login sync failed: $e');
    }
  }

  // ─── UI ────────────────────────────────────────────────────────────────────
  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
    double? suffixMinWidth,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: _C.iconMuted, fontSize: 14),
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      prefixIcon: Icon(icon, color: _C.textMuted, size: 21),
      suffixIcon: suffix,
      suffixIconConstraints: suffixMinWidth != null
          ? BoxConstraints(minWidth: suffixMinWidth)
          : null,
    );
  }

  Widget _fieldShell(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: _C.fieldBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.fieldBorder),
      ),
      child: child,
    );
  }

  Widget _buildHeader() {
    final l = AppLocalizations.of(context);
    return SizedBox(
      height: 235,
      child: Stack(
        children: [
          // Branding (left)
          Positioned(
            left: 22,
            top: 18,
            right: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/shop_logo.png',
                      cacheWidth: 192,
                      cacheHeight: 192,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.storefront_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                    children: const [
                      TextSpan(
                        text: 'RETAIL ',
                        style: TextStyle(color: Colors.white),
                      ),
                      TextSpan(
                        text: 'MIND',
                        style: TextStyle(color: _C.teal),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                LiveTranslatedText(
                  'Smart Analytics & Billing Platform',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                LiveTranslatedText(
                  l.translate('growBusinessInLanguage'),
                  style: GoogleFonts.dancingScript(
                    fontSize: 20,
                    height: 1.15,
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 110,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: _C.teal,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),

          // Shopkeeper illustration (right)
          Positioned(
            right: 8,
            bottom: 0,
            child: SizedBox(
              width: 150,
              height: 170,
              child: Image.asset(
                'assets/shop_keeper.png',
                cacheWidth: 400,
                cacheHeight: 454,
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
                errorBuilder: (_, __, ___) => Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white70,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Speech bubble
          Positioned(
            right: 100,
            top: 8,
            child: Transform.rotate(
              angle: -0.08,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.translate('easyBilling'),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: _C.navy,
                      ),
                    ),
                    Text(
                      l.translate('betterProfits'),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: _C.navyMid,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecureBadge({required double width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.fieldBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_rounded, color: _C.green, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                LiveTranslatedText(
                  AppLocalizations.of(context).translate('secureAndSafe'),
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _C.navy,
                  ),
                ),
                LiveTranslatedText(
                  AppLocalizations.of(context).translate('dataProtected'),
                  style: GoogleFonts.inter(fontSize: 9, color: _C.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidanceTile() {
    final voice = GuidedVoiceService.instance;
    final languageCode = context.read<LanguageProvider>().locale.languageCode;
    final localizations = AppLocalizations.of(context);

    return Material(
      color: _C.lavender,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => voice.speakStep('login', languageCode),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.record_voice_over_rounded,
                color: _C.indigo,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LiveTranslatedText(
                      localizations.translate('signInGuidance'),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _C.indigo,
                      ),
                    ),
                    LiveTranslatedText(
                      localizations.translate('voiceInstructionsLanguage'),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _C.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: voice,
                builder: (context, _) {
                  if (voice.isStarting) {
                    return const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _C.indigo,
                      ),
                    );
                  }

                  return IconButton(
                    tooltip: localizations.translate(
                      voice.isSpeaking
                          ? 'stopVoiceGuidance'
                          : 'playVoiceGuidance',
                    ),
                    onPressed: voice.isSpeaking
                        ? voice.stop
                        : () => voice.speakStep('login', languageCode),
                    icon: Icon(
                      voice.isSpeaking
                          ? Icons.stop_circle_rounded
                          : Icons.play_circle_fill_rounded,
                      color: _C.indigo,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    final l = AppLocalizations.of(context);
    final guidedModeEnabled = context
        .watch<LanguageProvider>()
        .isGuidedModeEnabled;
    final langCode = context.read<LanguageProvider>().locale.languageCode;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _C.navy.withValues(alpha: 0.14),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 460;
              final badgeWidth = compact
                  ? constraints.maxWidth
                  : (constraints.maxWidth * 0.42).clamp(170.0, 190.0);
              final heading = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LiveTranslatedText(
                    l.signIn,
                    style: GoogleFonts.inter(
                      color: _C.navy,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  LiveTranslatedText(
                    l.enterCredentials,
                    style: GoogleFonts.inter(
                      color: _C.textMuted,
                      fontSize: 13.5,
                      height: 1.3,
                    ),
                  ),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    heading,
                    const SizedBox(height: 12),
                    _buildSecureBadge(width: badgeWidth),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _buildSecureBadge(width: badgeWidth),
                  ),
                ],
              );
            },
          ),

          if (guidedModeEnabled) ...[
            const SizedBox(height: 16),
            _buildGuidanceTile(),
          ],

          if (errorMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFEF4444),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LiveTranslatedText(
                      errorMessage,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFDC2626),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Username
          _fieldShell(
            TextField(
              controller: emailController,
              enabled: !isLoading,
              keyboardType: TextInputType.text,
              style: GoogleFonts.inter(color: _C.textDark, fontSize: 14.5),
              decoration: _fieldDecoration(
                hint: l.translate('usernameOrEmail'),
                icon: Icons.mail_outline_rounded,
                suffix: GuidedFieldControls(
                  step: 'usernameField',
                  controller: emailController,
                  languageCode: langCode,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Password
          _fieldShell(
            TextField(
              controller: passwordController,
              enabled: !isLoading,
              obscureText: !isPasswordVisible,
              style: GoogleFonts.inter(color: _C.textDark, fontSize: 14.5),
              decoration: _fieldDecoration(
                hint: l.password,
                icon: Icons.lock_outline_rounded,
                suffixMinWidth: 144,
                suffix: GuidedFieldControls(
                  step: 'passwordField',
                  controller: passwordController,
                  languageCode: langCode,
                  trailing: IconButton(
                    icon: Icon(
                      isPasswordVisible
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: _C.textMuted,
                      size: 20,
                    ),
                    onPressed: isLoading
                        ? null
                        : () => setState(
                            () => isPasswordVisible = !isPasswordVisible,
                          ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: isLoading
                  ? null
                  : () => Navigator.pushNamed(context, '/forgot-password'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: LiveTranslatedText(
                l.forgotPassword,
                style: GoogleFonts.inter(
                  color: _C.indigo,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Sign in button
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: isLoading ? null : loginUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.navyBtn,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _C.navyBtn.withValues(alpha: 0.7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: isLoading
                  ? const InfinityLoader(color: Colors.white, size: 28)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LiveTranslatedText(
                          l.signIn,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 14),

          // OR divider
          Row(
            children: [
              const Expanded(child: Divider(color: _C.fieldBorder)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: LiveTranslatedText(
                  l.translate('or'),
                  style: GoogleFonts.inter(
                    color: _C.iconMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: _C.fieldBorder)),
            ],
          ),

          const SizedBox(height: 14),

          // Google
          _isGoogleLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: InfinityLoader(color: _C.navyMid, size: 32),
                  ),
                )
              : SizedBox(
                  height: 58,
                  child: OutlinedButton(
                    onPressed: isLoading ? null : _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color(0xFFD5DBEA),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      backgroundColor: Colors.white,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CustomPaint(painter: _GoogleLogoPainter()),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: LiveTranslatedText(
                            l.translate('continueWithGoogle'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: _C.textDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

          const SizedBox(height: 12),

          // Register tile
          Material(
            color: _C.lavender.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: isLoading
                  ? null
                  : () => Navigator.pushNamed(context, '/register'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: _C.indigo,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          text: l.translate('noAccount'),
                          style: GoogleFonts.inter(
                            color: _C.textMuted,
                            fontSize: 13,
                          ),
                          children: [
                            const TextSpan(text: ' '),
                            TextSpan(
                              text: l.register,
                              style: GoogleFonts.inter(
                                color: _C.indigo,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: _C.indigo),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final topInset = MediaQuery.of(context).padding.top;
    const headerHeight = 235.0;
    const overlap = 36.0; // how far the white card rides up into the navy area

    return BackendLoadingOverlay(
      isVisible: isLoading || _isGoogleLoading,
      title: l.translate('signingIn'),
      subtitle: l.translate('verifyingAccount'),
      icon: Icons.security_rounded,
      accentColor: const Color(0xFF6366F1),
      child: Scaffold(
        backgroundColor: _C.pageBg,
        body: Stack(
          children: [
            // Navy header backdrop — sized exactly to the header + overlap
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topInset + headerHeight + overlap,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_C.navy, _C.navyMid, Color(0xFF0A1628)],
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: const _LoginLanguageSelector(),
                        ),
                        const SizedBox(height: 8),
                        _buildHeader(),
                        AnimatedBuilder(
                          animation: _cardSlide,
                          builder: (_, child) => Opacity(
                            opacity: _cardSlide.value.clamp(0.0, 1.0),
                            child: Transform.translate(
                              offset: Offset(0, 30 * (1 - _cardSlide.value)),
                              child: child,
                            ),
                          ),
                          child: _buildCard(),
                        ),
                        SizedBox(
                          height: 88,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Image.asset(
                                'assets/shop_bottom_left.png',
                                width: 132,
                                height: 82,
                                cacheWidth: 400,
                                cacheHeight: 250,
                                fit: BoxFit.contain,
                                alignment: Alignment.bottomLeft,
                                excludeFromSemantics: true,
                              ),
                              Image.asset(
                                'assets/bag_bottom_right.png',
                                width: 82,
                                height: 86,
                                cacheWidth: 250,
                                cacheHeight: 260,
                                fit: BoxFit.contain,
                                alignment: Alignment.bottomRight,
                                excludeFromSemantics: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginLanguageSelector extends StatelessWidget {
  const _LoginLanguageSelector();

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentCode = languageProvider.locale.languageCode;
    final current = LanguageProvider.languages.firstWhere(
      (l) => l['code'] == currentCode,
      orElse: () => LanguageProvider.languages.first,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _C.fieldBorder),
        boxShadow: [
          BoxShadow(
            color: _C.navy.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: PopupMenuButton<String>(
        onSelected: (code) => languageProvider.setLanguage(code),
        color: Colors.white,
        itemBuilder: (context) => LanguageProvider.languages
            .map(
              (lang) => PopupMenuItem<String>(
                value: lang['code']!,
                child: Row(
                  children: [
                    LiveTranslatedText(
                      lang['nativeName']!,
                      style: const TextStyle(color: _C.textDark),
                    ),
                    const SizedBox(width: 6),
                    if (lang['code'] == currentCode)
                      const Icon(Icons.check, size: 16, color: _C.indigo),
                  ],
                ),
              ),
            )
            .toList(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language_rounded, size: 20, color: _C.navy),
              const SizedBox(width: 8),
              LiveTranslatedText(
                AppLocalizations.of(context).language,
                style: GoogleFonts.inter(
                  color: _C.navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              LiveTranslatedText(
                current['nativeName']!,
                style: GoogleFonts.inter(color: _C.textMuted, fontSize: 12),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: _C.navy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws the Google 'G' logo using coloured arcs/paths.
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = Colors.white);
    _drawArc(canvas, cx, cy, r * 0.72, -30, -120, const Color(0xFFEA4335));
    _drawArc(canvas, cx, cy, r * 0.72, -30, 120, const Color(0xFF4285F4));
    _drawArc(canvas, cx, cy, r * 0.72, 90, 90, const Color(0xFFFBBC05));
    _drawArc(canvas, cx, cy, r * 0.72, 180, -90, const Color(0xFF34A853));
    canvas.drawCircle(Offset(cx, cy), r * 0.45, Paint()..color = Colors.white);
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - r * 0.13, r * 0.72, r * 0.26),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  void _drawArc(
    Canvas canvas,
    double cx,
    double cy,
    double r,
    double startDeg,
    double sweepDeg,
    Color color,
  ) {
    const double deg2rad = 3.14159265358979 / 180;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      startDeg * deg2rad,
      sweepDeg * deg2rad,
      true,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
