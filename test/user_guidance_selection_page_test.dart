import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/user_guidance_selection_page.dart';

void main() {
  testWidgets('first page starts in Telugu and offers guidance choices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('te'),
        home: UserGuidanceSelectionPage(onContinue: _ignoreSelection),
      ),
    );

    expect(
      find.text('మీరు యాప్‌ను ఎలా ఉపయోగించాలనుకుంటున్నారు?'),
      findsOneWidget,
    );
    expect(find.text('నేను యాప్‌ను స్వయంగా ఉపయోగించగలను'), findsOneWidget);
    expect(find.text('నాకు దశలవారీగా మార్గదర్శనం కావాలి'), findsOneWidget);
    expect(find.byTooltip('మీ భాషను ఎంచుకోండి'), findsOneWidget);
    expect(find.text('దశ 1 / 3'), findsOneWidget);
    expect(
      find.text('ఈ ఎంపికను తర్వాత సెట్టింగ్‌లలో మార్చవచ్చు.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.face_rounded), findsNothing);
    final continueButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('కొనసాగించండి'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(continueButton.onPressed, isNotNull);
    expect(tester.getRect(find.text('కొనసాగించండి')).bottom, lessThan(600));
  });

  testWidgets('sends selected guided-mode choice to the app', (tester) async {
    bool? selectedMode;
    String? selectedLanguage;
    await tester.pumpWidget(
      MaterialApp(
        home: UserGuidanceSelectionPage(
          onContinue: (guidedMode, languageCode, _) async {
            selectedMode = guidedMode;
            selectedLanguage = languageCode;
          },
        ),
      ),
    );

    await tester.ensureVisible(find.text('నాకు దశలవారీగా మార్గదర్శనం కావాలి'));
    await tester.tap(find.text('నాకు దశలవారీగా మార్గదర్శనం కావాలి'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'కొనసాగించండి'));
    await tester.pump();

    expect(selectedMode, isTrue);
    expect(selectedLanguage, 'te');
  });

  testWidgets('sends independent mode when user can use app alone', (
    tester,
  ) async {
    bool? selectedMode;
    await tester.pumpWidget(
      MaterialApp(
        home: UserGuidanceSelectionPage(
          onContinue: (guidedMode, _, _) async {
            selectedMode = guidedMode;
          },
        ),
      ),
    );

    await tester.ensureVisible(find.text('నేను యాప్‌ను స్వయంగా ఉపయోగించగలను'));
    await tester.tap(find.text('నేను యాప్‌ను స్వయంగా ఉపయోగించగలను'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'కొనసాగించండి'));
    await tester.pump();

    expect(selectedMode, isFalse);
  });

  testWidgets('language choice and Continue fit a narrow mobile viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool? selectedMode;
    String? selectedLanguage;
    await tester.pumpWidget(
      MaterialApp(
        home: UserGuidanceSelectionPage(
          onContinue: (guidedMode, languageCode, _) async {
            selectedMode = guidedMode;
            selectedLanguage = languageCode;
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('కొనసాగించండి'), findsOneWidget);
    expect(
      find.text('మీరు యాప్‌ను ఎలా ఉపయోగించాలనుకుంటున్నారు?'),
      findsOneWidget,
    );

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.textContaining('ಕನ್ನಡ'), findsOneWidget);
    expect(find.textContaining('മലയാളം'), findsOneWidget);
    expect(find.textContaining('मराठी'), findsOneWidget);
    expect(find.textContaining('ગુજરાતી'), findsOneWidget);
    expect(find.textContaining('ਪੰਜਾਬੀ'), findsOneWidget);
    expect(find.textContaining('বাংলা'), findsOneWidget);
    await tester.tap(find.text('తెలుగు  ·  Telugu'));
    await tester.pumpAndSettle();

    expect(
      find.text('మీరు యాప్‌ను ఎలా ఉపయోగించాలనుకుంటున్నారు?'),
      findsOneWidget,
    );
    expect(find.byTooltip('మీ భాషను ఎంచుకోండి'), findsOneWidget);
    expect(find.text('నేను యాప్‌ను స్వయంగా ఉపయోగించగలను'), findsOneWidget);
    expect(find.text('నాకు దశలవారీగా మార్గదర్శనం కావాలి'), findsOneWidget);
    expect(find.text('కొనసాగించండి'), findsOneWidget);
    expect(find.text('How would you like to use the app?'), findsNothing);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English  ·  English'));
    await tester.pumpAndSettle();
    expect(find.text('How would you like to use the app?'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('తెలుగు  ·  Telugu'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('నాకు దశలవారీగా మార్గదర్శనం కావాలి'));
    await tester.tap(find.text('నాకు దశలవారీగా మార్గదర్శనం కావాలి'));
    await tester.pump();
    await tester.tap(find.text('కొనసాగించండి'));
    await tester.pump();

    expect(selectedMode, isTrue);
    expect(selectedLanguage, 'te');
  });

  testWidgets('Skip continues without guided mode', (tester) async {
    bool? selectedMode;
    await tester.pumpWidget(
      MaterialApp(
        home: UserGuidanceSelectionPage(
          onContinue: (guidedMode, _, _) async {
            selectedMode = guidedMode;
          },
        ),
      ),
    );

    await tester.tap(find.text('దాటవేయి'));
    await tester.pump();

    expect(selectedMode, isFalse);
  });
}

Future<void> _ignoreSelection(bool _, String _, BuildContext _) async {}
