import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:retail_mind/language_provider.dart';
import 'package:retail_mind/language_selection_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Telugu Continue stays visible while language choices scroll', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final languageProvider = LanguageProvider();
    await languageProvider.initialized;

    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageProvider>.value(
        value: languageProvider,
        child: MaterialApp(
          home: LanguageSelectionPage(onContinue: (_, __) async {}),
        ),
      ),
    );

    final continueButton = find.widgetWithText(FilledButton, 'కొనసాగించండి');
    expect(continueButton, findsOneWidget);
    expect(tester.getRect(continueButton).bottom, lessThanOrEqualTo(600));
    expect(find.text('తెలుగు'), findsOneWidget);
  });

  testWidgets('passes selected language when continuing', (tester) async {
    final languageProvider = LanguageProvider();
    await languageProvider.initialized;
    String? selectedLanguage;

    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageProvider>.value(
        value: languageProvider,
        child: MaterialApp(
          home: LanguageSelectionPage(
            onContinue: (language, _) async {
              selectedLanguage = language;
            },
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('తెలుగు'));
    await tester.tap(find.text('తెలుగు'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'కొనసాగించండి'));
    await tester.pump();

    expect(selectedLanguage, 'te');
  });
}
