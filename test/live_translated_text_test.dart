import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/app_localizations.dart';
import 'package:retail_mind/live_translated_text.dart';
import 'package:retail_mind/shared_page_translations.dart';

void main() {
  test('sales entry labels are available offline in every locale', () {
    const labels = <String>[
      'Quantity',
      'Unit price (₹)',
      'Discount (₹)',
      'Subtotal',
      'GST',
      'Line total',
    ];

    for (final locale in AppLocalizations.supportedLocales) {
      final translations =
          SharedPageTranslations.salesEntryTerms[locale.languageCode]!;
      for (final label in labels) {
        expect(translations[label], isNotNull);
        if (locale.languageCode != 'en') {
          expect(translations[label], isNot(label));
        }
      }
    }
  });

  test('shared-page copy has complete locale coverage', () {
    final englishKeys = SharedPageTranslations.byLanguage['en']!.keys.toSet();

    for (final locale in AppLocalizations.supportedLocales) {
      final translations =
          SharedPageTranslations.byLanguage[locale.languageCode]!;
      expect(
        translations.keys.toSet(),
        equals(englishKeys),
        reason: 'Missing shared-page copy in ${locale.languageCode}',
      );
      if (locale.languageCode != 'en') {
        for (final phrase in englishKeys) {
          if (phrase == '+ ₹' || phrase == '− ₹') continue;
          expect(
            translations[phrase],
            isNot(phrase),
            reason: '$phrase is not translated in ${locale.languageCode}',
          );
        }
      }
    }
  });

  testWidgets('uses offline copy for the shared pages in every locale', (
    tester,
  ) async {
    const englishCopy = 'Every paid invoice remains safely available here.';

    for (final locale in AppLocalizations.supportedLocales) {
      final translated = SharedPageTranslations.lookup(
        englishCopy,
        locale.languageCode,
      );
      expect(translated, isNotNull, reason: 'Missing ${locale.languageCode}');
      if (locale.languageCode != 'en') {
        expect(translated, isNot(englishCopy));
      }

      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: LiveTranslatedText(englishCopy)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == translated,
        ),
        findsOneWidget,
        reason:
            '${locale.languageCode}: $translated; rendered: ${tester.widgetList<Text>(find.byType(Text)).map((text) => text.data).toList()}',
      );
    }
  });

  testWidgets('updates shared-page copy when the selected locale changes', (
    tester,
  ) async {
    var locale = const Locale('en');

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Column(
              children: [
                const LiveTranslatedText('Staff Login'),
                TextButton(
                  onPressed: () => setState(() => locale = const Locale('te')),
                  child: const Text('Switch language'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == 'Staff Login',
      ),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .toList()
          .toString(),
    );

    await tester.tap(find.text('Switch language'));
    await tester.pumpAndSettle();

    expect(
      find.text(SharedPageTranslations.lookup('Staff Login', 'te')!),
      findsOneWidget,
    );
  });

  testWidgets('uses offline screen translation for the selected locale', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('te'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(body: LiveTranslatedText('Daily Closing')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('రోజువారీ ముగింపు'), findsOneWidget);
  });

  testWidgets('renders the logout confirmation in the selected language', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('te'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(
          body: AlertDialog(
            title: LiveTranslatedText('Logout?'),
            content: LiveTranslatedText(
              'Are you sure you want to logout? Your synced data will safely return when you log back in.',
            ),
            actions: [
              TextButton(onPressed: null, child: LiveTranslatedText('Cancel')),
              TextButton(onPressed: null, child: LiveTranslatedText('Logout')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('లాగ్ అవుట్ చేయాలా?'), findsOneWidget);
    expect(
      find.text(
        'మీరు లాగ్ అవుట్ చేయాలనుకుంటున్నారా? మళ్లీ లాగిన్ అయినప్పుడు సమకాలీకరించిన మీ డేటా సురక్షితంగా తిరిగి వస్తుంది.',
      ),
      findsOneWidget,
    );
    expect(find.text('రద్దు చేయండి'), findsOneWidget);
    expect(find.text('లాగ్ అవుట్'), findsOneWidget);
  });
}
