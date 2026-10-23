import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:retail_mind/guided_field_controls.dart';
import 'package:retail_mind/language_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('normal mode hides dictation but keeps essential field actions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final languageProvider = LanguageProvider();
    await languageProvider.initialized;
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageProvider>.value(
        value: languageProvider,
        child: MaterialApp(
          home: Scaffold(
            body: GuidedFieldControls(
              controller: controller,
              step: 'productName',
              languageCode: 'en',
              trailing: const Icon(Icons.qr_code_scanner),
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
    expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
    expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
  });

  testWidgets('guided mode shows field dictation without speaker playback', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final languageProvider = LanguageProvider();
    await languageProvider.initialized;
    await languageProvider.completeGuidanceSelection(guidedModeEnabled: true);
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageProvider>.value(
        value: languageProvider,
        child: MaterialApp(
          home: Scaffold(
            body: GuidedFieldControls(
              controller: controller,
              step: 'productName',
              languageCode: 'en',
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
  });

  testWidgets('guided field actions align to the trailing edge', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final languageProvider = LanguageProvider();
    await languageProvider.initialized;
    await languageProvider.completeGuidanceSelection(guidedModeEnabled: true);
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageProvider>.value(
        value: languageProvider,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              key: const Key('password-field'),
              width: 320,
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIconConstraints: const BoxConstraints(minWidth: 144),
                  suffixIcon: GuidedFieldControls(
                    controller: controller,
                    step: 'passwordField',
                    languageCode: 'en',
                    trailing: IconButton(
                      icon: const Icon(Icons.visibility_rounded),
                      onPressed: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final fieldRect = tester.getRect(find.byKey(const Key('password-field')));
    final visibilityRect = tester.getRect(
      find.byIcon(Icons.visibility_rounded),
    );
    expect(fieldRect.right - visibilityRect.right, lessThan(24));
  });
}
