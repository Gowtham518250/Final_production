import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

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
