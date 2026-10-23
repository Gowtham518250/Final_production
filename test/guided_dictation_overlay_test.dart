import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:retail_mind/guided_dictation_overlay.dart';
import 'package:retail_mind/language_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<LanguageProvider> createLanguageProvider({
    required bool guidedModeEnabled,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final provider = LanguageProvider();
    await provider.initialized;
    if (guidedModeEnabled) {
      await provider.completeGuidanceSelection(guidedModeEnabled: true);
      await provider.setLanguage('te');
    }
    return provider;
  }

  testWidgets('shows selected-language dictation beside every visible field', (
    tester,
  ) async {
    final languageProvider = await createLanguageProvider(
      guidedModeEnabled: true,
    );
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageProvider>.value(
        value: languageProvider,
        child: MaterialApp(
          builder: (context, child) =>
              GuidedDictationOverlay(child: child ?? const SizedBox.shrink()),
          home: Scaffold(
            body: Column(
              children: [
                TextField(
                  key: const ValueKey('plain-text-field'),
                  controller: controller,
                  decoration: const InputDecoration(hintText: 'Search'),
                ),
                TextFormField(
                  key: ValueKey('form-text-field'),
                  decoration: const InputDecoration(hintText: 'Customer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.mic_none_rounded), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('plain-text-field')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.mic_none_rounded), findsNWidgets(2));
    expect(
      find.bySemanticsLabel('మాట్లాడి ఈ ఖాళీని పూరించండి'),
      findsNWidgets(2),
    );

    await tester.tap(find.byKey(const ValueKey('form-text-field')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.mic_none_rounded), findsNWidgets(2));
  });

  testWidgets('does not show app-wide dictation in normal mode', (
    tester,
  ) async {
    final languageProvider = await createLanguageProvider(
      guidedModeEnabled: false,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageProvider>.value(
        value: languageProvider,
        child: MaterialApp(
          builder: (context, child) =>
              GuidedDictationOverlay(child: child ?? const SizedBox.shrink()),
          home: const Scaffold(
            body: TextField(decoration: InputDecoration(hintText: 'Search')),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
  });

  testWidgets('does not overlay dictation on password fields', (tester) async {
    final languageProvider = await createLanguageProvider(
      guidedModeEnabled: true,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageProvider>.value(
        value: languageProvider,
        child: MaterialApp(
          builder: (context, child) =>
              GuidedDictationOverlay(child: child ?? const SizedBox.shrink()),
          home: const Scaffold(
            body: TextField(
              obscureText: true,
              decoration: InputDecoration(hintText: 'Password'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
  });

  testWidgets(
    'does not duplicate an inline microphone or add one in excluded sections',
    (tester) async {
      final languageProvider = await createLanguageProvider(
        guidedModeEnabled: true,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<LanguageProvider>.value(
          value: languageProvider,
          child: MaterialApp(
            builder: (context, child) =>
                GuidedDictationOverlay(child: child ?? const SizedBox.shrink()),
            home: Scaffold(
              body: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Already has a mic',
                      suffixIcon: Container(
                        padding: const EdgeInsets.all(4),
                        child: Tooltip(
                          message: 'Speak',
                          child: IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.mic),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const GuidedDictationExclusion(
                    child: TextField(
                      decoration: InputDecoration(hintText: 'Not dictatable'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
    },
  );
}
