import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/voice_feedback_learning_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('learns a repeated Telugu correction without ASCII word-boundary regex', () async {
    for (var i = 0; i < 3; i++) {
      await VoiceFeedbackLearningService.recordCorrection(
        originalTranscript: 'బుబ్ట్',
        correctedItemName: 'బూస్ట్',
        languageCode: 'te',
        originalConfidence: 0.72,
        syncToShop: false,
      );
    }

    final corrected = await VoiceFeedbackLearningService.applyLearnedCorrections(
      transcript: '2 కిలోల బుబ్ట్',
      languageCode: 'te',
    );

    expect(corrected, '2 కిలోల బూస్ట్');
  });

  test('does not replace an alias embedded inside a longer Latin word', () async {
    for (var i = 0; i < 3; i++) {
      await VoiceFeedbackLearningService.recordCorrection(
        originalTranscript: 'soap',
        correctedItemName: 'dove',
        languageCode: 'en',
        originalConfidence: 0.8,
        syncToShop: false,
      );
    }

    final embedded = await VoiceFeedbackLearningService.applyLearnedCorrections(
      transcript: 'soapdish',
      languageCode: 'en',
    );
    final wholePhrase = await VoiceFeedbackLearningService.applyLearnedCorrections(
      transcript: '2 soap',
      languageCode: 'en',
    );

    expect(embedded, 'soapdish');
    expect(wholePhrase, '2 dove');
  });

  test('does not activate conflicting corrections tied for first place', () async {
    for (var i = 0; i < 3; i++) {
      await VoiceFeedbackLearningService.recordCorrection(
        originalTranscript: 'bubt',
        correctedItemName: 'boost',
        languageCode: 'en',
        originalConfidence: 0.6,
        syncToShop: false,
      );
      await VoiceFeedbackLearningService.recordCorrection(
        originalTranscript: 'bubt',
        correctedItemName: 'boosted',
        languageCode: 'en',
        originalConfidence: 0.6,
      );
    }

    final result = await VoiceFeedbackLearningService.applyLearnedCorrections(
      transcript: 'bubt',
      languageCode: 'en',
    );

    expect(result, 'bubt');
  });
}
