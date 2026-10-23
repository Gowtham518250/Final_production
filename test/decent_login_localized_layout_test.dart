import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:retail_mind/app_localizations.dart';
import 'package:retail_mind/decent_login_page.dart';
import 'package:retail_mind/language_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('localized login copy fits a narrow mobile viewport', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final languageProvider = LanguageProvider();
    await languageProvider.initialized;
    await languageProvider.setLanguage('ta');
    addTearDown(languageProvider.dispose);

    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final locale in AppLocalizations.supportedLocales) {
      await languageProvider.setLanguage(locale.languageCode);
      await tester.pumpWidget(
        ChangeNotifierProvider<LanguageProvider>.value(
          value: languageProvider,
          child: MaterialApp(
            locale: languageProvider.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const DecentLoginPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final layoutException = tester.takeException();
      expect(
        layoutException,
        isNull,
        reason: '${locale.languageCode}: $layoutException',
      );
      expect(
        find.text(AppLocalizations(locale).signIn),
        findsWidgets,
        reason: 'Missing sign-in label in ${locale.languageCode}',
      );
    }
  });
}
