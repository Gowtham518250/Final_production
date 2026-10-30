import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:retail_mind/guided_voice_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('route transitions cancel only the guided-voice service', () async {
    var stopCalls = 0;
    final observer = GuidedVoiceRouteObserver(
      stopGuidance: () async {
        stopCalls++;
      },
    );
    final first = MaterialPageRoute<void>(
      builder: (_) => const SizedBox.shrink(),
    );
    final second = MaterialPageRoute<void>(
      builder: (_) => const SizedBox.shrink(),
    );

    observer.didPush(first, null);
    observer.didPush(second, first);
    observer.didPop(second, first);
    observer.didReplace(newRoute: second, oldRoute: first);
    observer.didRemove(first, null);

    expect(stopCalls, 5);
  });

  test('a pending guided prompt is discarded after a screen change', () async {
    SharedPreferences.setMockInitialValues({
      GuidedVoiceService.guidedModePreferenceKey: true,
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var speechCount = 0;
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'),
        (call) async {
      if (call.method == 'speak') speechCount++;
      if (call.method == 'getLanguages') return <String>['en-IN'];
      if (call.method == 'isLanguageAvailable') return true;
      return 1;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(
          const MethodChannel('flutter_tts'), null);
    });

    final service = GuidedVoiceService.instance;
    final pendingPrompt = service.speakStepIfGuided('login', 'en');
    await service.cancelForRouteChange();
    await pendingPrompt;

    expect(speechCount, 0);
  });
}
