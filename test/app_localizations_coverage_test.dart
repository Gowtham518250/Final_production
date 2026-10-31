import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/app_localizations.dart';
import 'package:retail_mind/language_provider.dart';

void main() {
  test('all supported locales have the same dictionary keys', () {
    const supportedLanguageCodes = <String>{
      'en',
      'te',
      'hi',
      'ta',
      'kn',
      'ml',
      'mr',
      'gu',
      'pa',
      'bn',
    };

    expect(
      AppLocalizations.translations.keys.toSet(),
      equals(supportedLanguageCodes),
    );

    final englishKeys = AppLocalizations.translations['en']!.keys.toSet();

    for (final languageCode in supportedLanguageCodes) {
      final locale = AppLocalizations.translations[languageCode]!;
      expect(
        locale.keys.toSet(),
        equals(englishKeys),
        reason: 'Locale $languageCode must contain every English key.',
      );
    }
  });

  test('screen headings are translated in every supported locale', () {
    const headings = <String>[
      'Identity Verification',
      'Ask Retail Mind',
      'Daily Closing',
      'Online Orders',
      'More',
      'Retail Growth',
      'Khata & Udhar',
      'Khata & Pending Udhar',
      'Invoice Analytics',
      'Export Summary',
      'Paid Invoices',
      'Online Store',
      'Online Store Manager',
      'Bank Statement Parser',
      'Logout?',
      'Confirm Logout',
      'Are you sure you want to logout? Your synced data will safely return when you log back in.',
      'Are you sure you want to log out?',
      'Cancel',
      'CANCEL',
      'Logout',
      'LOGOUT',
      'Logging out...',
    ];

    expect(
      AppLocalizations.screenTextTranslations.keys.toSet(),
      equals(AppLocalizations.translations.keys.toSet()),
    );

    final englishPhrases = AppLocalizations.screenTextTranslations['en']!;
    for (final languageCode in supportedLanguageCodes) {
      final phrases = AppLocalizations.screenTextTranslations[languageCode]!;
      expect(
        phrases.keys.toSet(),
        equals(englishPhrases.keys.toSet()),
        reason:
            'Screen copy must have matching entries for ${languageCode}.',
      );
      for (final entry in englishPhrases.entries) {
        expect(
          phrases[entry.key],
          isNotEmpty,
          reason: '${entry.key} must be translated for ${languageCode}.',
        );
        if (languageCode != 'en') {
          expect(
            phrases[entry.key],
            isNot(entry.value),
            reason:
                '${entry.key} must not fall back to English for ${languageCode}.',
          );
        }
      }
      for (final heading in headings) {
        expect(
          phrases[heading],
          isNotNull,
          reason: '$heading must resolve for ${languageCode}',
        );
        if (languageCode != 'en') {
          expect(
            phrases[heading],
            isNot(heading),
            reason:
                '$heading must not remain English for ${languageCode}',
          );
        }
      }
    }
  });
  test('every voice language is registered as an application locale', () {
    final appLanguageCodes = AppLocalizations.supportedLocales
        .map((locale) => languageCode)
        .toSet();
    final selectableLanguageCodes = LanguageProvider.languages
        .map((language) => language['code']!)
        .toSet();

    expect(appLanguageCodes, containsAll(selectableLanguageCodes));
    expect(selectableLanguageCodes, containsAll(<String>{
      'en', 'te', 'hi', 'ta', 'kn', 'ml', 'bn', 'mr', 'gu', 'pa',
      'or', 'as', 'brx', 'doi', 'ks', 'kok', 'mai', 'mni', 'ne',
      'sa', 'sat', 'sd', 'ur',
    }));
  });

}
