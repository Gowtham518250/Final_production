import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/app_localizations.dart';

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

      for (final locale in AppLocalizations.supportedLocales) {
        final localizations = AppLocalizations(locale);
        for (final key in loginKeys) {
          final value = localizations.translate(key);
          expect(value, isNotEmpty, reason: '$key in ${locale.languageCode}');
          if (locale.languageCode != 'en') {
            expect(
              value,
              isNot(english.translate(key)),
              reason: '$key fell back to English in ${locale.languageCode}',
            );
          }
        }
      }
    },
  );
}
