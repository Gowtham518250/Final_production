import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'payment_announcement_service.dart';
import 'payment_detection_service.dart';
import 'payment_event.dart';
import 'online_payment_history_service.dart';

StreamSubscription<Map<String, dynamic>?>? _paymentEventSubscription;
StreamSubscription<PaymentEvent>? _paymentForwardSubscription;

Future<void> syncExpectedPaymentBill(double? amount) async {
  final service = FlutterBackgroundService();
  if (amount == null) {
    service.invoke('clear_expected_payment_bill');
    return;
  }
  if (!amount.isFinite || amount <= 0) {
    debugPrint('⚠️ Ignoring invalid expected payment bill amount: $amount');
    return;
  }
  service.invoke('sync_expected_payment_bill', {'amount': amount});
}

Future<void> syncRecordedBillPayment(double amount) async {
  if (!amount.isFinite || amount <= 0) {
    debugPrint('⚠️ Ignoring invalid recorded bill payment amount: $amount');
    return;
  }
  FlutterBackgroundService().invoke('sync_recorded_bill_payment', {
    'amount': amount,
  });
}

Future<void> restartBackgroundPaymentDetection() async {
  FlutterBackgroundService().invoke('restart_payment_detection');
}

void _listenForBackgroundPayments(FlutterBackgroundService service) {
  _paymentEventSubscription?.cancel();
  _paymentEventSubscription = service.on('payment_detected').listen((payload) {
    if (payload == null) return;
    try {
      PaymentDetectionService().forwardPaymentEvent(
        PaymentEvent.fromJson(Map<String, dynamic>.from(payload)),
      );
    } catch (error, stackTrace) {
      debugPrint('⚠️ Invalid background payment event: $error\n$stackTrace');
    }
  });
}


Future<void> _persistPaymentHistoryThenForward(
  ServiceInstance service,
  PaymentEvent event,
) async {
  try {
    await OnlinePaymentHistoryService.recordIncomingPayment(event);
  } catch (error, stackTrace) {
    debugPrint('⚠️ Could not save background payment receipt: $error');
    debugPrint(stackTrace.toString());
  }
  service.invoke('payment_detected', event.toJson());
}

Future<void> _ensurePaymentNotificationChannel() async {
  if (!Platform.isAndroid) return;
  final plugin = FlutterLocalNotificationsPlugin();
  final android = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  if (android == null) return;
  const channel = AndroidNotificationChannel(
    'payment_detection_channel',
    'Payment Detection',
    description: 'Foreground service notification for payment detection.',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
    showBadge: false,
  );
  await android.createNotificationChannel(channel);
}

@pragma('vm:entry-point')
Future<bool> onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  var hasNotificationPermission = true;
  try {
    final status = await Permission.notification.status;
    hasNotificationPermission = status.isGranted;
  } catch (_) {
    hasNotificationPermission = false;
  }

  if (service is AndroidServiceInstance && hasNotificationPermission) {
    service.setForegroundNotificationInfo(
      title: "Retail Mind",
      content: "Listening for payments...",
    );
  }

  try {
    try {
      await PaymentAnnouncementService().init(
        config: const AnnouncementConfig(volume: 1.0),
      );
    } catch (error, stackTrace) {
      debugPrint(
        '⚠️ Background announcement engine initialization failed: '
        '$error\n$stackTrace',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('payment_sound_lang') ?? 'en-US';

    final pds = PaymentDetectionService();
    // The foreground app and service isolates have separate voice settings.
    PdsConfig.isVoiceEnabled = true;
    pds.setLanguage(PaymentDetectionService.mapLanguage(langCode));

    pds.onSpeak = (text) async {
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString('payment_sound_lang') ?? 'en-US';
      PaymentAnnouncementService().speakSimple(text, lang);
    };

    await _paymentForwardSubscription?.cancel();
    _paymentForwardSubscription = pds.onPaymentDetected.listen((event) {
      // Preserve ordering: finish the local history write (or log its failure)
      // before forwarding the event to the UI isolate. A background shutdown
      // must not silently lose the history write after the event was forwarded.
      unawaited(_persistPaymentHistoryThenForward(service, event));
    });

    service.on('sync_expected_payment_bill').listen((event) {
      final amount = (event?['amount'] as num?)?.toDouble();
      if (amount == null || !amount.isFinite || amount <= 0) {
        debugPrint('⚠️ Ignoring invalid expected bill amount: $amount');
        return;
      }
      pds.setBillExpected(amount);
    });
    service.on('clear_expected_payment_bill').listen((event) {
      pds.clearBill();
    });
    service.on('sync_recorded_bill_payment').listen((event) {
      final amount = (event?['amount'] as num?)?.toDouble();
      if (amount == null || !amount.isFinite || amount <= 0) {
        debugPrint('⚠️ Ignoring invalid synced bill payment amount: $amount');
        return;
      }
      pds.recordBillPayment(amount);
    });

    await pds.start();

    // FIX: The UI isolate (dashboard) and this background isolate each hold
    // a *separate* PaymentDetectionService singleton instance. When the user
    // taps "Enable Payment Detection" and grants SMS/notification-listener
    // permission, that only affects the UI isolate's instance — this
    // background isolate (the one that actually keeps listening once the
    // app is backgrounded) never learns permissions changed and its
    // listeners stay dead. Listen for a signal from the UI isolate so the
    // detector can attach newly permitted channels without replacing its
    // payment event stream.
    bool restartInProgress = false;
    service.on('restart_payment_detection').listen((event) async {
      if (restartInProgress) {
        debugPrint(
          '⏳ Background isolate: restart already in progress; ignoring duplicate signal',
        );
        return;
      }

      restartInProgress = true;
      debugPrint(
        '🔁 Background isolate: attaching payment channels after permission grant',
      );
      try {
        await pds.ensureChannelsRunning();
        debugPrint('✅ Background payment channels are active');
      } catch (e) {
        debugPrint('⚠️ Background isolate: restart failed: $e');
      } finally {
        restartInProgress = false;
      }
    });

    try {
      final accessibilityEnabled =
          await FlutterAccessibilityService.isAccessibilityPermissionEnabled();
      debugPrint(
        accessibilityEnabled
            ? '✅ Accessibility service permission is enabled'
            : '⚠️ Accessibility service permission is NOT enabled',
      );
    } catch (e) {
      debugPrint('⚠️ Accessibility status check failed: $e');
    }

    // FIX (critical, part 2): lets the UI isolate promote this service to a
    // real foreground service the moment POST_NOTIFICATIONS is granted,
    // instead of requiring a full app reinstall to stop being killed by
    // Android. Without this, a service that started in background-only
    // mode on first launch (before permission was granted) stays
    // non-foreground — and therefore killable — forever.
    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        debugPrint('⬆️ Background isolate: promoting to foreground service');
        service.setAsForegroundService();
      });
      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    debugPrint('✅ Background payment services initialized');
  } catch (e) {
    debugPrint('⚠️ Background service init error: $e');
    return false;
  }

  // FIX (Issue 4.1): Removed Timer.periodic(1 second) that was calling
  // service.invoke('update') every second, causing constant CPU wake locks
  // and significant battery drain. The PaymentDetectionService is
  // event-driven (SMS/notifications), so no polling timer is required.

  return true;
}

Future<void> initializeBackgroundService() async {
  try {
    final service = FlutterBackgroundService();

    // The background-service plugin requires a custom channel to exist before
    // configure()/startForeground() when notificationChannelId is supplied.
    await _ensurePaymentNotificationChannel();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        autoStartOnBoot: true,
        // Android permits foreground services without notification permission
        // on Android 13+; the service notification remains visible in system
        // task manager even when it is hidden from the notification drawer.
        isForegroundMode: true,
        notificationChannelId: 'payment_detection_channel',
        initialNotificationTitle: 'Retail Mind',
        initialNotificationContent: 'Listening for payments...',
        foregroundServiceNotificationId: 888,
        // Android 14+ / target SDK 34+ requires an explicit FGS type.
        // Payment-notification monitoring is not data transfer, location, media,
        // or another predefined category, so use the documented specialUse type.
        foregroundServiceTypes: [AndroidForegroundType.specialUse],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onStart,
      ),
    );

    _listenForBackgroundPayments(service);
    await service.startService();
    debugPrint('✅ Background service started successfully (foreground=true)');
  } catch (e) {
    debugPrint('⚠️ Failed to start background service: $e');
    await _initializeFallback();
  }
}

Future<void> _initializeFallback() async {
  try {
    await PaymentAnnouncementService().init(
      config: const AnnouncementConfig(volume: 1.0),
    );

    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('payment_sound_lang') ?? 'en-US';

    final pds = PaymentDetectionService();
    // Keep announcements enabled in fallback mode as well.
    PdsConfig.isVoiceEnabled = true;
    pds.setLanguage(PaymentDetectionService.mapLanguage(langCode));

    pds.onSpeak = (text) async {
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString('payment_sound_lang') ?? 'en-US';
      PaymentAnnouncementService().speakSimple(text, lang);
    };

    await pds.start();
    debugPrint('✅ Payment services initialized (fallback mode)');
  } catch (e) {
    debugPrint('⚠️ Failed fallback initialization: $e');
  }
}
