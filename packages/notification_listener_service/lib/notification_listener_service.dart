import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:notification_listener_service/notification_event.dart';

const MethodChannel methodeChannel =
    MethodChannel('x-slayer/notifications_channel');
const EventChannel _eventChannel = EventChannel('x-slayer/notifications_event');
Stream<ServiceNotificationEvent>? _stream;

class NotificationListenerService {
  NotificationListenerService._();

  /// stream the incoming notifications events
  static Stream<ServiceNotificationEvent> get notificationsStream {
    if (Platform.isAndroid) {
      _stream ??=
          _eventChannel.receiveBroadcastStream().map<ServiceNotificationEvent>(
                (event) => ServiceNotificationEvent.fromMap(event),
              );
      return _stream!;
    }
    throw Exception("Notifications API exclusively available on Android!");
  }

  /// Opens Android notification-access settings and returns the actual
  /// permission state after the user returns to Retail Mind.
  static Future<bool> requestPermission() async {
    try {
      return await methodeChannel.invokeMethod<bool>('requestPermission') ??
          false;
    } on PlatformException catch (error) {
      log("requestPermission failed: $error");
      return false;
    } on MissingPluginException catch (error) {
      log("requestPermission unavailable: $error");
      return false;
    }
  }

  /// Checks whether Android notification access is currently enabled.
  static Future<bool> isPermissionGranted() async {
    try {
      return await methodeChannel.invokeMethod<bool>('isPermissionGranted') ??
          false;
    } on PlatformException catch (error) {
      log("isPermissionGranted failed: $error");
      return false;
    } on MissingPluginException catch (error) {
      log("isPermissionGranted unavailable: $error");
      return false;
    }
  }

  /// Atomically check/store an announcement candidate in Android SQLite.
  ///
  /// Returns true when this event is a duplicate and should be suppressed,
  /// false when it is the unique announcement candidate, or null when the
  /// native plugin is unavailable and the caller should use its local fallback.
  static Future<bool?> shouldSuppressPaymentAnnouncement(
    Map<String, dynamic> event,
  ) async {
    if (!Platform.isAndroid) return null;
    try {
      return await methodeChannel.invokeMethod<bool>(
        'shouldSuppressPaymentAnnouncement',
        event,
      );
    } on PlatformException catch (error) {
      log('Atomic payment announcement gate failed: $error');
      return null;
    } on MissingPluginException catch (error) {
      log('Atomic payment announcement gate unavailable: $error');
      return null;
    }
  }

  /// Acknowledge a durable native notification after the detector processed it.
  static Future<void> acknowledgeNotification(String? eventKey) async {
    if (!Platform.isAndroid || eventKey == null || eventKey.trim().isEmpty) {
      return;
    }
    try {
      await methodeChannel.invokeMethod<bool>('acknowledgeNotification', {
        'eventKey': eventKey,
      });
    } on PlatformException catch (error) {
      log('Notification acknowledgement failed: $error');
    } on MissingPluginException catch (error) {
      log('Notification acknowledgement unavailable: $error');
    }
  }

  /// get currently active notifications
  static Future<List<ServiceNotificationEvent>> getActiveNotifications() async {
    try {
      final List<dynamic> result =
      await methodeChannel.invokeMethod('getActiveNotifications');
      return result
          .map((item) => ServiceNotificationEvent.fromMap(item))
          .toList();
    } on PlatformException catch (error) {
      log("getActiveNotifications error: $error");
      return [];
    }
  }
}
