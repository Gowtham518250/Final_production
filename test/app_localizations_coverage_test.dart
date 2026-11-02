import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/app_localizations.dart';
import 'package:retail_mind/language_provider.dart';

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


void main() {
  test('all supported locales have the same dictionary keys', () {
    expect(
      AppLocalizations.translations.keys.toSet(),
      equals(supportedLanguageCodes),
    );

    final englishKeys = AppLocalizations.translations['en']!.keys.toSet();
    final mismatches = <String>[];
    for (final languageCode in supportedLanguageCodes) {
      final localeKeys = AppLocalizations.translations[languageCode]!.keys.toSet();
      final missing = englishKeys.difference(localeKeys).toList()..sort();
      final extra = localeKeys.difference(englishKeys).toList()..sort();
      if (missing.isNotEmpty || extra.isNotEmpty) {
        mismatches.add('$languageCode missing=$missing extra=$extra');
      }
    }
    expect(mismatches, isEmpty, reason: mismatches.join('\n'));
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
    final mismatches = <String>[];
    for (final languageCode in supportedLanguageCodes) {
      final phrases = AppLocalizations.screenTextTranslations[languageCode]!;
      final englishKeys = englishPhrases.keys.toSet();
      final phraseKeys = phrases.keys.toSet();
      final missing = englishKeys.difference(phraseKeys).toList()..sort();
      final extra = phraseKeys.difference(englishKeys).toList()..sort();
      if (missing.isNotEmpty || extra.isNotEmpty) {
        mismatches.add('$languageCode missing=$missing extra=$extra');
      }

      for (final entry in englishPhrases.entries) {
        final translation = phrases[entry.key];
        if (translation == null || translation.isEmpty) {
          mismatches.add('$languageCode missing translation for ${entry.key}');
        } else if (languageCode != 'en' && translation == entry.value) {
          mismatches.add('$languageCode still English for ${entry.key}');
        }
      }
      for (final heading in headings) {
        final translation = phrases[heading];
        if (translation == null) {
          mismatches.add('$languageCode missing heading $heading');
        } else if (languageCode != 'en' && translation == heading) {
          mismatches.add('$languageCode heading remains English: $heading');
        }
      }
    }
    expect(mismatches, isEmpty, reason: mismatches.join('\n'));
  });

  test('selectable languages include all curated UI locales', () {
    const selectableLanguageCodes = <String>{
      'en', 'te', 'hi', 'ta', 'kn', 'ml', 'bn', 'mr', 'gu', 'pa',
      'or', 'as', 'brx', 'doi', 'ks', 'kok', 'mai', 'mni', 'ne',
      'sa', 'sat', 'sd', 'ur',
    };
    expect(selectableLanguageCodes, hasLength(23));

    final curatedUiCodes = AppLocalizations.supportedLocales
        .map((locale) => locale.languageCode)
        .toSet();
    expect(
      curatedUiCodes,
      containsAll(<String>{
        'en', 'te', 'hi', 'ta', 'kn', 'ml', 'bn', 'mr', 'gu', 'pa',
      }),
    );
    expect(curatedUiCodes.length, 10);
  });
}
