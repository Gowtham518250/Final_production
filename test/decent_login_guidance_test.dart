import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:retail_mind/app_localizations.dart';
import 'package:retail_mind/decent_login_page.dart';
import 'package:retail_mind/guided_voice_service.dart';
import 'package:retail_mind/language_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('one tap plays guidance and the control shows speech state', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final languageProvider = LanguageProvider();
    await languageProvider.initialized;
    await languageProvider.completeGuidanceSelection(guidedModeEnabled: true);
    addTearDown(languageProvider.dispose);

    var speechCount = 0;
    const ttsChannel = MethodChannel('flutter_tts');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(ttsChannel, (call) async {
      switch (call.method) {
        case 'getLanguages':
          return <String>['te-IN', 'en-IN'];
        case 'isLanguageAvailable':
          return true;
        case 'speak':
          speechCount++;
          return 1;
        default:
          return 1;
      }
    });
    addTearDown(() => messenger.setMockMethodCallHandler(ttsChannel, null));

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

    final localizations = AppLocalizations(languageProvider.locale);
    expect(speechCount, 1);
    expect(find.byIcon(Icons.stop_circle_rounded), findsOneWidget);
    expect(
      find.byTooltip(localizations.translate('stopVoiceGuidance')),
      findsOneWidget,
    );

    await tester.tap(
      find.text(
        AppLocalizations(languageProvider.locale).translate('signInGuidance'),
      ),
    );
    await tester.pumpAndSettle();

    expect(speechCount, 2);
    expect(find.byIcon(Icons.stop_circle_rounded), findsOneWidget);
    expect(
      find.byTooltip(localizations.translate('stopVoiceGuidance')),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.stop_circle_rounded));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.play_circle_fill_rounded), findsOneWidget);
    expect(
      find.byTooltip(localizations.translate('playVoiceGuidance')),
      findsOneWidget,
    );
    await GuidedVoiceService.instance.stop();
  });
}
