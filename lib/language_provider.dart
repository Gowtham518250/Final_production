import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'guided_voice_service.dart';
import 'payment_detection_service.dart';

class LanguageProvider extends ChangeNotifier {
  static const String defaultLanguageCode = 'te';

  Locale _locale = const Locale(defaultLanguageCode);
  bool _hasCompletedInitialSelection = false;
  bool _hasCompletedGuidanceSelection = false;
  bool _isGuidedModeEnabled = false;
  bool _isInitialized = false;

  static const String initialLanguageSelectionKey =
      'language_selection_completed_v1';
  static const String initialGuidanceSelectionKey =
      'guided_mode_selection_completed_v1';
  static const String pendingLanguageCodeKey =
      'language_code_pending_account_v1';
  static const String lastActiveAccountLanguageKey =
      'language_code_last_active_account_v1';

  Locale get locale => _locale;
  bool get hasCompletedInitialSelection => _hasCompletedInitialSelection;
  bool get hasCompletedGuidanceSelection => _hasCompletedGuidanceSelection;
  bool get isGuidedModeEnabled => _isGuidedModeEnabled;
  bool get isInitialized => _isInitialized;

  int _selectionVersion = 0;
  late final Future<void> initialized;

  LanguageProvider() {
    initialized = _loadSavedLanguage();
  }

  static String _preferenceKeyFor(SharedPreferences prefs) {
    final role =
        (prefs.getString('user_role') ??
                prefs.getString('user_type') ??
                prefs.getString('role') ??
                '')
            .trim()
            .toUpperCase();

    // Customer sessions sometimes keep their ID in customer_id while owner
    // sessions use user_id/userId. Include the role to prevent collisions.
    final rawId = role == 'CUSTOMER'
        ? (prefs.get('customer_id') ??
              prefs.get('user_id') ??
              prefs.get('userId') ??
              prefs.get('current_scoped_user_id'))
        : (prefs.get('user_id') ??
              prefs.get('userId') ??
              prefs.get('current_scoped_user_id'));
    final userId = int.tryParse(rawId?.toString() ?? '') ?? 0;
    if (userId > 0 && role.isNotEmpty) {
      return 'language_code_${role}_$userId';
    }
    // Before login there is no account identity yet, so keep a device-level
    // preference; it is copied into the account scope on the next app launch.
    return 'language_code';
  }

  static bool _isSupported(String languageCode) =>
      languages.any((language) => language['code'] == languageCode);

  /// Choose a safe language for an account that has no saved preference.
  ///
  /// The global language is treated as a legacy migration source only until
  /// the first account has been activated. After that, a different account
  /// starts in Telugu unless the user explicitly picked a language before
  /// signing in. This prevents shared devices from leaking language settings.
  static String _fallbackLanguageForAccount(
    SharedPreferences prefs,
    String scopedKey,
  ) {
    final pending = prefs.getString(pendingLanguageCodeKey);
    if (pending != null && _isSupported(pending)) return pending;

    final lastAccount = prefs.getString(lastActiveAccountLanguageKey);
    if (lastAccount == null || lastAccount == scopedKey) {
      final legacy = prefs.getString('language_code') ?? defaultLanguageCode;
      return _isSupported(legacy) ? legacy : defaultLanguageCode;
    }
    return defaultLanguageCode;
  }

  Future<void> _loadSavedLanguage() async {
    final selectionVersionAtStart = _selectionVersion;
    final prefs = await SharedPreferences.getInstance();
    // If a user chooses a language while startup is loading preferences, the
    // explicit choice wins instead of being overwritten by this async read.
    if (selectionVersionAtStart != _selectionVersion) return;
    final key = _preferenceKeyFor(prefs);
    final saved = key == 'language_code'
        ? (prefs.getString('language_code') ?? defaultLanguageCode)
        : (prefs.getString(key) ?? _fallbackLanguageForAccount(prefs, key));
    final languageCode = _isSupported(saved) ? saved : defaultLanguageCode;
    _locale = Locale(languageCode);
    await _syncSpeechLanguage(prefs, languageCode);
    _hasCompletedInitialSelection =
        prefs.getBool(initialLanguageSelectionKey) ?? false;
    _hasCompletedGuidanceSelection =
        prefs.getBool(initialGuidanceSelectionKey) ?? false;
    _isGuidedModeEnabled =
        prefs.getBool(GuidedVoiceService.guidedModePreferenceKey) ?? false;
    _isInitialized = true;

    if (key != 'language_code') {
      if (prefs.getString(key) == null) {
        await prefs.setString(key, languageCode);
      }
      await prefs.setString(lastActiveAccountLanguageKey, key);
      await prefs.remove(pendingLanguageCodeKey);
    }
    notifyListeners();
  }

  /// Completes the one-time language choice shown before the login/onboarding
  /// flow. This method intentionally does not notify listeners: the language
  /// selection page navigates immediately after this completes, avoiding a
  /// route rebuild while its button handler is still running.
  Future<void> completeInitialSelection(String languageCode) async {
    await setLanguage(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(initialLanguageSelectionKey, true);
    _hasCompletedInitialSelection = true;
  }

  /// Completes the language choice for independent or guided app use.
  /// Updates the saved mode and notifies field controls so they can show or
  /// hide guided dictation consistently.
  Future<void> completeGuidanceSelection({
    required bool guidedModeEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      GuidedVoiceService.guidedModePreferenceKey,
      guidedModeEnabled,
    );
    await prefs.setBool(initialGuidanceSelectionKey, true);
    _isGuidedModeEnabled = guidedModeEnabled;
    _hasCompletedGuidanceSelection = true;
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    _selectionVersion++;
    final safeCode = _isSupported(languageCode)
        ? languageCode
        : defaultLanguageCode;
    _locale = Locale(safeCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', safeCode);
    await _syncSpeechLanguage(prefs, safeCode);
    final scopedKey = _preferenceKeyFor(prefs);
    if (scopedKey != 'language_code') {
      await prefs.setString(scopedKey, safeCode);
      await prefs.setString(lastActiveAccountLanguageKey, scopedKey);
      await prefs.remove(pendingLanguageCodeKey);
    } else {
      // This is an explicit selection before authentication; consume it only
      // when the next account is established.
      await prefs.setString(pendingLanguageCodeKey, safeCode);
    }
    notifyListeners();
  }

  /// Seed an account with an explicitly selected pre-login language, or a
  /// migration fallback for the first account on this device.
  ///
  /// Never overwrite a saved account preference and never copy another
  /// account's global language into a new account. SessionManagementService
  /// calls this after the authenticated user ID and role have been persisted.
  static Future<void> persistCurrentLanguageForAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final scopedKey = _preferenceKeyFor(prefs);
    if (scopedKey == 'language_code') return;

    if (prefs.containsKey(scopedKey)) {
      await prefs.setString(lastActiveAccountLanguageKey, scopedKey);
      await prefs.remove(pendingLanguageCodeKey);
      return;
    }

    final selected = _fallbackLanguageForAccount(prefs, scopedKey);
    await prefs.setString(scopedKey, selected);
    await prefs.setString('language_code', selected);
    await prefs.setString(lastActiveAccountLanguageKey, scopedKey);
    await prefs.remove(pendingLanguageCodeKey);
  }

  /// Activate the new authenticated account's language immediately after a
  /// login or registration. A saved account language always wins over the
  /// device-level fallback used before authentication.
  Future<void> activateAccountLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final scopedKey = _preferenceKeyFor(prefs);
    if (scopedKey == 'language_code') return;

    final savedForAccount = prefs.getString(scopedKey);
    final savedCode = savedForAccount ?? '';
    final selected = _isSupported(savedCode)
        ? savedCode
        : _fallbackLanguageForAccount(prefs, scopedKey);

    _selectionVersion++;
    _locale = Locale(selected);
    _isInitialized = true;
    await _syncSpeechLanguage(prefs, selected);
    if (savedForAccount == null) {
      await prefs.setString(scopedKey, selected);
    }
    await prefs.setString('language_code', selected);
    await prefs.setString(lastActiveAccountLanguageKey, scopedKey);
    await prefs.remove(pendingLanguageCodeKey);
    notifyListeners();
  }

  Future<void> _syncSpeechLanguage(
    SharedPreferences prefs,
    String languageCode,
  ) async {
    final speechLocale = GuidedVoiceService.localeForLanguageCode(languageCode);
    if (speechLocale == null) return;
    await prefs.setString('payment_sound_lang', speechLocale);
    PaymentDetectionService().setLanguage(
      PaymentDetectionService.mapLanguage(speechLocale),
    );
  }

  /// Locale registry shared by the UI and voice stack.
  /// The UI can safely load any of these locales; untranslated keys fall back
  /// to the English getter defaults in AppLocalizations.
  static const List<Map<String, String>> languages = [
    {'code': 'en', 'name': 'English', 'nativeName': 'English'},
    {'code': 'te', 'name': 'Telugu', 'nativeName': 'తెలుగు'},
    {'code': 'hi', 'name': 'Hindi', 'nativeName': 'हिन्दी'},
    {'code': 'ta', 'name': 'Tamil', 'nativeName': 'தமிழ்'},
    {'code': 'kn', 'name': 'Kannada', 'nativeName': 'ಕನ್ನಡ'},
    {'code': 'ml', 'name': 'Malayalam', 'nativeName': 'മലയാളം'},
    {'code': 'mr', 'name': 'Marathi', 'nativeName': 'मराठी'},
    {'code': 'gu', 'name': 'Gujarati', 'nativeName': 'ગુજરાતી'},
    {'code': 'pa', 'name': 'Punjabi', 'nativeName': 'ਪੰਜਾਬੀ'},
    {'code': 'bn', 'name': 'Bengali', 'nativeName': 'বাংলা'},
  ];
}
