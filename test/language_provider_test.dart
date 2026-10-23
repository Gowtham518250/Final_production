import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:retail_mind/guided_voice_service.dart';
import 'package:retail_mind/language_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LanguageProvider', () {
    test('persists completion of first-use guidance choice', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = LanguageProvider();
      await provider.initialized;

      expect(provider.hasCompletedGuidanceSelection, isFalse);

      await provider.completeGuidanceSelection(guidedModeEnabled: false);

      final prefs = await SharedPreferences.getInstance();
      expect(provider.hasCompletedGuidanceSelection, isTrue);
      expect(
        prefs.getBool(LanguageProvider.initialGuidanceSelectionKey),
        isTrue,
      );
      expect(
        prefs.getBool(GuidedVoiceService.guidedModePreferenceKey),
        isFalse,
      );
      expect(provider.isGuidedModeEnabled, isFalse);
    });

    test(
      'persists guided mode for users who request step-by-step help',
      () async {
        SharedPreferences.setMockInitialValues({});
        final provider = LanguageProvider();
        await provider.initialized;

        await provider.completeGuidanceSelection(guidedModeEnabled: true);

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool(GuidedVoiceService.guidedModePreferenceKey),
          isTrue,
        );
        expect(provider.isGuidedModeEnabled, isTrue);
      },
    );

    test('loads and saves the current account language separately', () async {
      SharedPreferences.setMockInitialValues({
        'user_id': 42,
        'user_role': 'OWNER',
        'language_code': 'te',
      });

      final provider = LanguageProvider();
      await provider.initialized;
      expect(provider.locale.languageCode, 'te');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('payment_sound_lang'), 'te-IN');

      await provider.setLanguage('hi');
      expect(prefs.getString('language_code'), 'hi');
      expect(prefs.getString('language_code_OWNER_42'), 'hi');
      expect(prefs.getString('payment_sound_lang'), 'hi-IN');
      expect(provider.locale.languageCode, 'hi');
    });

    test('prefers an existing account language over device fallback', () async {
      SharedPreferences.setMockInitialValues({
        'user_id': 8,
        'user_role': 'OWNER',
        'language_code': 'te',
        'language_code_OWNER_8': 'ta',
      });

      final provider = LanguageProvider();
      await provider.initialized;
      expect(provider.locale.languageCode, 'ta');
    });

    test(
      'account activation prefers that account language after account switching',
      () async {
        SharedPreferences.setMockInitialValues({
          'user_id': 1,
          'user_role': 'OWNER',
          'language_code': 'en',
          'language_code_OWNER_2': 'te',
        });

        final provider = LanguageProvider();
        await provider.initialized;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_id', 2);
        await prefs.setString('user_role', 'OWNER');

        await LanguageProvider.persistCurrentLanguageForAccount();
        await provider.activateAccountLanguage();

        expect(provider.locale.languageCode, 'te');
        expect(prefs.getString('language_code_OWNER_2'), 'te');
        expect(prefs.getString('language_code'), 'te');
        expect(prefs.getString('payment_sound_lang'), 'te-IN');
      },
    );

    test(
      'persisting a login never overwrites an existing account language',
      () async {
        SharedPreferences.setMockInitialValues({
          'user_id': 8,
          'user_role': 'OWNER',
          'language_code': 'en',
          'language_code_OWNER_8': 'ta',
        });

        await LanguageProvider.persistCurrentLanguageForAccount();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('language_code_OWNER_8'), 'ta');
      },
    );

    test(
      'new account does not inherit the previous account language',
      () async {
        SharedPreferences.setMockInitialValues({
          'user_id': 11,
          'user_role': 'OWNER',
          'language_code': 'te',
          'language_code_OWNER_11': 'te',
          LanguageProvider.lastActiveAccountLanguageKey:
              'language_code_OWNER_11',
        });

        final provider = LanguageProvider();
        await provider.initialized;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_id', 22);
        await LanguageProvider.persistCurrentLanguageForAccount();
        await provider.activateAccountLanguage();

        expect(prefs.getString('language_code_OWNER_11'), 'te');
        expect(prefs.getString('language_code_OWNER_22'), 'te');
        expect(provider.locale.languageCode, 'te');
        expect(
          prefs.getString(LanguageProvider.lastActiveAccountLanguageKey),
          'language_code_OWNER_22',
        );
      },
    );

    test(
      'explicit pre-login language is applied to the next new account',
      () async {
        SharedPreferences.setMockInitialValues({
          'user_id': 22,
          'user_role': 'OWNER',
          'language_code': 'en',
          LanguageProvider.pendingLanguageCodeKey: 'te',
          LanguageProvider.lastActiveAccountLanguageKey:
              'language_code_OWNER_11',
        });

        await LanguageProvider.persistCurrentLanguageForAccount();
        final prefs = await SharedPreferences.getInstance();

        expect(prefs.getString('language_code_OWNER_22'), 'te');
        expect(prefs.getString('language_code'), 'te');
        expect(
          prefs.containsKey(LanguageProvider.pendingLanguageCodeKey),
          isFalse,
        );
      },
    );

    test('a fresh install defaults to Telugu', () async {
      SharedPreferences.setMockInitialValues({});

      final provider = LanguageProvider();
      await provider.initialized;

      expect(provider.locale.languageCode, 'te');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('payment_sound_lang'), 'te-IN');
    });

    test('unsupported language codes safely fall back to Telugu', () async {
      SharedPreferences.setMockInitialValues({'language_code': 'xx'});

      final provider = LanguageProvider();
      await provider.initialized;
      expect(provider.locale.languageCode, 'te');

      await provider.setLanguage('xx');
      expect(provider.locale.languageCode, 'te');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('language_code'), 'te');
    });

    test(
      'syncs every app language to the announcement voice language',
      () async {
        SharedPreferences.setMockInitialValues({});
        final provider = LanguageProvider();
        await provider.initialized;
        final prefs = await SharedPreferences.getInstance();
        const expectedLocales = {
          'en': 'en-IN',
          'te': 'te-IN',
          'hi': 'hi-IN',
          'ta': 'ta-IN',
          'kn': 'kn-IN',
          'ml': 'ml-IN',
          'mr': 'mr-IN',
          'gu': 'gu-IN',
          'pa': 'pa-IN',
          'bn': 'bn-IN',
        };

        for (final entry in expectedLocales.entries) {
          await provider.setLanguage(entry.key);
          expect(
            prefs.getString('payment_sound_lang'),
            entry.value,
            reason: 'Selected ${entry.key} must select ${entry.value} speech',
          );
        }
      },
    );

    test('binds the pre-login language to the authenticated account', () async {
      SharedPreferences.setMockInitialValues({
        'language_code': 'te',
        'user_id': 73,
        'user_role': 'CUSTOMER',
      });

      await LanguageProvider.persistCurrentLanguageForAccount();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('language_code_CUSTOMER_73'), 'te');
    });
  });
}
