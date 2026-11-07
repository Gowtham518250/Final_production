import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android AccessibilityService is bound with Play-safe limits', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(
      manifest.contains(
        'slayer.accessibility.service.flutter_accessibility_service.AccessibilityListener',
      ),
      isTrue,
    );
    expect(manifest.contains('BIND_ACCESSIBILITY_SERVICE'), isTrue);
    final accessibilityService = RegExp(
      r'<service[\s\S]*?flutter_accessibility_service\.AccessibilityListener[\s\S]*?</service>',
    ).firstMatch(manifest)?.group(0);
    expect(accessibilityService, isNotNull);
    expect(accessibilityService!.contains('android:exported="true"'), isTrue);
    expect(
      accessibilityService.contains('BIND_ACCESSIBILITY_SERVICE'),
      isTrue,
    );
    expect(
      manifest.contains('android.accessibilityservice.AccessibilityService'),
      isTrue,
    );
    expect(
      manifest.contains('android:resource="@xml/accessibilityservice"'),
      isTrue,
    );
    expect(manifest.contains('BIND_NOTIFICATION_LISTENER_SERVICE'), isTrue);
    expect(manifest.contains('RECEIVE_SMS'), isTrue);
    expect(manifest.contains('READ_SMS'), isTrue);
    expect(manifest.contains('@string/app_sensitive_access_purpose'), isTrue);
  });

  test('accessibility XML disables gestures and names payment apps only', () {
    final xml = File(
      'android/app/src/main/res/xml/accessibilityservice.xml',
    ).readAsStringSync();
    expect(xml.contains('android:canPerformGestures="false"'), isTrue);
    expect(xml.contains('android:canRetrieveWindowContent="true"'), isTrue);
    expect(xml.contains('com.phonepe.app'), isTrue);
    expect(xml.contains('@string/accessibility_service_description'), isTrue);
  });

  test('Play disclosure copy exists in Android strings and public privacy page', () {
    final strings = File(
      'android/app/src/main/res/values/strings.xml',
    ).readAsStringSync();
    expect(strings.contains('accessibility_service_description'), isTrue);
    expect(strings.contains('notification_listener_label'), isTrue);
    expect(strings.contains('does not tap, swipe, type'), isTrue);

    final privacy = File('web/privacy.html').readAsStringSync();
    expect(privacy.contains('Why we use Accessibility'), isTrue);
    expect(privacy.contains('Why we read SMS'), isTrue);
    expect(privacy.contains('notification access'), isTrue);
    expect(privacy.contains('matched to a bill'), isTrue);
    expect(privacy.contains('UTR/reference'), isTrue);
  });

  test('in-app Accessibility disclosure names bill matching and retained fields', () {
    final disclosure = File(
      'lib/notification_access_disclosure.dart',
    ).readAsStringSync();
    expect(disclosure.contains('matched to a bill'), isTrue);
    expect(disclosure.contains('UTR/reference'), isTrue);
    expect(disclosure.contains('synced with your shop records'), isTrue);
  });
}
