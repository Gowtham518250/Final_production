import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:permission_handler/permission_handler.dart';

import 'live_translated_text.dart';

/// Result of the user-controlled notification-access flow.
///
/// Opening Android Settings is never attempted until the user checks the
/// consent box and taps "Continue to Settings".
enum NotificationAccessDisclosureResult {
  alreadyEnabled,
  enabled,
  declined,
  notEnabled,
  unavailable,
}

/// Shows a just-in-time disclosure before opening Android's special-access
/// screen. The feature is optional; callers must retain a manual-billing path
/// for all non-success results.
Future<NotificationAccessDisclosureResult>
    requestNotificationAccessWithDisclosure(BuildContext context) async {
  if (kIsWeb || !Platform.isAndroid) {
    return NotificationAccessDisclosureResult.unavailable;
  }

  try {
    if (await NotificationListenerService.isPermissionGranted()) {
      return NotificationAccessDisclosureResult.alreadyEnabled;
    }
  } catch (_) {
    // Continue through disclosure; the permission check itself is not consent.
  }

  if (!context.mounted) {
    return NotificationAccessDisclosureResult.unavailable;
  }

  var consentChecked = false;
  final consent = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.notifications_active_outlined),
                SizedBox(width: 10),
                Expanded(child: LiveTranslatedText('Allow notification access?')),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LiveTranslatedText(
                      'Why Retail Mind asks',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    const LiveTranslatedText(
                      'Android notification access allows Retail Mind to read '
                      'notifications posted by apps on this device while access '
                      'is enabled. Retail Mind uses this feature to look for '
                      'eligible payment alerts. Notifications can contain '
                      'private messages or other sensitive information.',
                    ),
                    const SizedBox(height: 12),
                    const LiveTranslatedText(
                      'When a payment alert is identified, relevant extracted '
                      'transaction details may be recorded in Retail Mind and '
                      'synced according to your existing app settings. A '
                      'notification alone does not prove that funds have '
                      'settled; review uncertain payments before relying on them.',
                    ),
                    const SizedBox(height: 12),
                    const LiveTranslatedText(
                      'You can choose not to enable this feature and continue '
                      'recording sales manually. You can also turn notification '
                      'access off later in Android Settings.',
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: consentChecked,
                      onChanged: (value) {
                        setDialogState(() {
                          consentChecked = value ?? false;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const LiveTranslatedText(
                        'I understand and agree to enable notification access '
                        'for Retail Mind payment detection.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const LiveTranslatedText('Not now — use manual billing'),
              ),
              FilledButton.icon(
                onPressed: consentChecked
                    ? () => Navigator.of(dialogContext).pop(true)
                    : null,
                icon: const Icon(Icons.settings_outlined),
                label: const LiveTranslatedText('Continue to Settings'),
              ),
            ],
          );
        },
      );
    },
  );

  if (consent != true || !context.mounted) {
    return NotificationAccessDisclosureResult.declined;
  }

  try {
    final granted = await NotificationListenerService.requestPermission();
    return granted
        ? NotificationAccessDisclosureResult.enabled
        : NotificationAccessDisclosureResult.notEnabled;
  } catch (_) {
    return NotificationAccessDisclosureResult.unavailable;
  }
}

enum SmsAccessDisclosureResult {
  alreadyEnabled,
  enabled,
  declined,
  notEnabled,
  unavailable,
}

enum AccessibilityAccessDisclosureResult {
  alreadyEnabled,
  enabled,
  declined,
  notEnabled,
  unavailable,
}

Future<bool> _showSensitiveAccessConsentDialog({
  required BuildContext context,
  required IconData icon,
  required String title,
  required List<String> paragraphs,
  required String checkboxLabel,
  required String confirmLabel,
}) async {
  var consentChecked = false;
  final consent = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Expanded(child: LiveTranslatedText(title)),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < paragraphs.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      LiveTranslatedText(paragraphs[i]),
                    ],
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: consentChecked,
                      onChanged: (value) {
                        setDialogState(() {
                          consentChecked = value ?? false;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: LiveTranslatedText(
                        checkboxLabel,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const LiveTranslatedText('Not now — use manual billing'),
              ),
              FilledButton(
                onPressed: consentChecked
                    ? () => Navigator.of(dialogContext).pop(true)
                    : null,
                child: LiveTranslatedText(confirmLabel),
              ),
            ],
          );
        },
      );
    },
  );
  return consent == true;
}

/// Incoming bank/UPI SMS only. Consent is required before the system prompt.
Future<SmsAccessDisclosureResult> requestSmsAccessWithDisclosure(
  BuildContext context,
) async {
  if (kIsWeb || !Platform.isAndroid) {
    return SmsAccessDisclosureResult.unavailable;
  }

  try {
    if ((await Permission.sms.status).isGranted) {
      return SmsAccessDisclosureResult.alreadyEnabled;
    }
  } catch (_) {}

  if (!context.mounted) return SmsAccessDisclosureResult.unavailable;

  final consented = await _showSensitiveAccessConsentDialog(
    context: context,
    icon: Icons.sms_outlined,
    title: 'Allow SMS access?',
    paragraphs: const [
      'Retail Mind can read incoming SMS on this phone to look for bank and UPI payment confirmations. Other messages may be seen briefly while that filter runs. Inbox threads are not shown in the app.',
      'When a payment SMS is identified, amount and reference details may be saved in payment history. You can keep recording sales manually without SMS access.',
    ],
    checkboxLabel:
        'I understand and agree to enable SMS access for Retail Mind payment detection.',
    confirmLabel: 'Continue',
  );

  if (!consented || !context.mounted) {
    return SmsAccessDisclosureResult.declined;
  }

  try {
    final status = await Permission.sms.request();
    return status.isGranted
        ? SmsAccessDisclosureResult.enabled
        : SmsAccessDisclosureResult.notEnabled;
  } catch (_) {
    return SmsAccessDisclosureResult.unavailable;
  }
}

/// Restricted to bank/UPI packages in accessibilityservice.xml. No gestures.
Future<AccessibilityAccessDisclosureResult>
    requestAccessibilityAccessWithDisclosure(BuildContext context) async {
  if (kIsWeb || !Platform.isAndroid) {
    return AccessibilityAccessDisclosureResult.unavailable;
  }

  try {
    if (await FlutterAccessibilityService.isAccessibilityPermissionEnabled()) {
      return AccessibilityAccessDisclosureResult.alreadyEnabled;
    }
  } catch (_) {}

  if (!context.mounted) {
    return AccessibilityAccessDisclosureResult.unavailable;
  }

  final consented = await _showSensitiveAccessConsentDialog(
    context: context,
    icon: Icons.accessibility_new_outlined,
    title: 'Allow payment screen reader?',
    paragraphs: const [
      'Retail Mind uses Android Accessibility only to read payment confirmation text from bank and UPI apps. It cannot tap, swipe, or control other apps.',
      'Screen text from those apps can include amounts and account labels. You can turn this off in Android Settings and keep billing manually.',
    ],
    checkboxLabel:
        'I understand and agree to enable the payment screen reader for Retail Mind.',
    confirmLabel: 'Continue to Settings',
  );

  if (!consented || !context.mounted) {
    return AccessibilityAccessDisclosureResult.declined;
  }

  try {
    final granted =
        await FlutterAccessibilityService.requestAccessibilityPermission();
    return granted
        ? AccessibilityAccessDisclosureResult.enabled
        : AccessibilityAccessDisclosureResult.notEnabled;
  } catch (_) {
    return AccessibilityAccessDisclosureResult.unavailable;
  }
}
