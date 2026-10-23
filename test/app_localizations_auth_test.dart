import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/app_localizations.dart';
import 'package:retail_mind/language_provider.dart';

void main() {
  const loginKeys = [
    'usernameOrEmail',
    'easyBilling',
    'betterProfits',
    'signInGuidance',
    'voiceInstructionsLanguage',
    'continueWithGoogle',
    'noAccount',
    'listenRegisterGuidance',
    'dataProtected',
    'secureAndSafe',
    'growBusinessInLanguage',
    'or',
    'signingIn',
    'verifyingAccount',
    'creatingAccount',
    'registeringShopSync',
  ];

  test(
    'login and registration labels are translated in every supported language',
    () {
      final english = AppLocalizations(const Locale('en'));

      for (final language in LanguageProvider.languages) {
        final localizations = AppLocalizations(Locale(language['code']!));
        for (final key in loginKeys) {
          final value = localizations.translate(key);
          expect(value, isNotEmpty, reason: '$key in ${language['code']}');
          if (language['code'] != 'en') {
            expect(
              value,
              isNot(english.translate(key)),
              reason: '$key fell back to English in ${language['code']}',
            );
          }
        }
      }
    },
  );
}
