import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/spoken_language_typewriter.dart';
import 'package:retail_mind/voice_billing_display.dart';
import 'package:retail_mind/voice_billing_localization.dart';

void main() {
  test('live preview types known products in the spoken language', () {
    expect(
      VoiceBillingDisplay.liveTypedPreview('2 kg rice 60', 'te'),
      isNot(contains('rice')),
    );
    expect(
      VoiceBillingDisplay.liveTypedPreview('2 kg rice 60', 'te'),
      contains('బియ్యం'),
    );
  });

  test('spoken live labels follow the selected language', () {
    expect(
      VoiceBillingLocalization.label('Words appear here as you speak', 'te'),
      contains('అక్షరాలు'),
    );
    expect(
      VoiceBillingLocalization.label('Translating into your language', 'hi'),
      'आपकी भाषा में',
    );
  });

  testWidgets('placeholder types glyphs instead of appearing all at once', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SpokenLanguageTypewriter(
            text: '2 కిలో బియ్యం 60',
            loop: false,
            msPerGlyph: 20,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('2 కిలో బియ్యం 60'), findsNothing);

    await tester.pump(const Duration(milliseconds: 800));
    expect(find.textContaining('2'), findsOneWidget);
  });

  testWidgets('reduced motion shows the full spoken placeholder immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: SpokenLanguageTypewriter(
              text: '"2 కిలో పంచదార 60"',
              loop: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('"2 కిలో పంచదార 60"'), findsOneWidget);
  });
}
